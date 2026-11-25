#!/usr/bin/env python3
"""
Standalone Geometric GDSII DRC & Structural Integrity Verifier.
Parses GDSII binary stream records, checks bounding containment, minimum width,
intra-layer overlaps/shorts, and minimum spacing via O(N log N) sweep-line checks.
"""

import os
import struct
import sys

def verify_gds(gds_path, layer_rules=None, report_path=None, top_name=None, tech_name="SkyWater 130nm"):
    if layer_rules is None:
        # SkyWater 130nm default rules in nm: (name, min_w, min_s, check_overlap)
        layer_rules = {
            64:  ("NWELL",    840, 1270, False),
            65:  ("DIFF",     150,  270, True),
            66:  ("POLY",     150,  210, True),
            67:  ("CONTACT",  170,  170, True),
            68:  ("METAL1",   140,  140, True),
            69:  ("VIA1",     150,  170, True),
            70:  ("METAL2",   140,  140, True),
            71:  ("VIA2",     200,  200, True),
            72:  ("METAL3",   300,  300, True),
            73:  ("VIA3",     200,  200, True),
            74:  ("METAL4",   300,  300, True),
            75:  ("VIA4",     800,  800, True),
            76:  ("METAL5",  1600, 1600, True),
            108: ("PAD",     4000, 1000, True),
            125: ("ESD",    10000, 2000, True),
            235: ("DIEAREA", 1000,    0, False),
        }

    with open(gds_path, "rb") as f:
        data = f.read()

    pos = 0
    boxes_by_layer = {}
    structs = []
    cur_layer = None
    in_bnd = False
    has_endlib = False

    while pos + 4 <= len(data):
        rlen, rtype_dt = struct.unpack(">HH", data[pos:pos+4])
        if rlen < 4 or pos + rlen > len(data):
            raise ValueError(f"Corrupt GDSII record at offset {pos}: rlen={rlen}")
        rtype = (rtype_dt >> 8) & 0xFF
        payload = data[pos+4:pos+rlen]
        if rtype == 0x06:
            structs.append(payload.rstrip(b"\x00").decode("ascii", errors="replace"))
        elif rtype == 0x08:
            in_bnd = True
            cur_layer = None
        elif rtype == 0x0D and in_bnd and len(payload) >= 2:
            cur_layer = struct.unpack(">h", payload[:2])[0]
        elif rtype == 0x10 and in_bnd and cur_layer is not None:
            pts = struct.unpack(f">{len(payload)//4}i", payload)
            xs = pts[0::2]
            ys = pts[1::2]
            boxes_by_layer.setdefault(cur_layer, []).append((min(xs), min(ys), max(xs), max(ys)))
        elif rtype == 0x11:
            in_bnd = False
        elif rtype == 0x04:
            has_endlib = True
        pos += rlen

    if not has_endlib:
        raise ValueError("Missing ENDLIB record in GDSII stream")

    # Determine die bounding box from layer 235 or 100, else global bbox
    die_layer = 235 if 235 in boxes_by_layer else (100 if 100 in boxes_by_layer else None)
    if die_layer:
        die_x1, die_y1, die_x2, die_y2 = boxes_by_layer[die_layer][0]
    else:
        all_b = [b for bs in boxes_by_layer.values() for b in bs]
        die_x1 = min(b[0] for b in all_b)
        die_y1 = min(b[1] for b in all_b)
        die_x2 = max(b[2] for b in all_b)
        die_y2 = max(b[3] for b in all_b)

    die_area = max(1, (die_x2 - die_x1) * (die_y2 - die_y1))
    total_violations = 0
    summary_lines = []

    for layer in sorted(boxes_by_layer.keys()):
        boxes = boxes_by_layer[layer]
        lname, min_w_req, min_s_req, chk_ov = layer_rules.get(layer, (f"L{layer}", 100, 100, True))
        w_viols = 0
        s_viols = 0
        ov_viols = 0
        oob_viols = 0
        area_sum = 0

        for x1, y1, x2, y2 in boxes:
            w = x2 - x1
            h = y2 - y1
            area_sum += w * h
            if min(w, h) < min_w_req:
                w_viols += 1
            if x1 < die_x1 or y1 < die_y1 or x2 > die_x2 or y2 > die_y2:
                oob_viols += 1

        if chk_ov and len(boxes) > 1:
            bs = sorted(boxes)
            n = len(bs)
            for i in range(n):
                ax1, ay1, ax2, ay2 = bs[i]
                for j in range(i + 1, n):
                    bx1, by1, bx2, by2 = bs[j]
                    if bx1 >= ax2 + min_s_req:
                        break
                    # Check overlap or spacing in Y
                    y_ov = min(ay2, by2) - max(ay1, by1)
                    if bx1 < ax2 and y_ov > 0:
                        ov_viols += 1
                    elif min_s_req > 0:
                        # Separated in X by dx >= 0 and y_ov > -min_s_req, or separated in Y by dy >= 0 and bx1 < ax2
                        dx = max(0, bx1 - ax2)
                        dy = max(0, max(ay1 - by2, by1 - ay2))
                        if dx < min_s_req and dy < min_s_req:
                            s_viols += 1

        layer_viols = w_viols + s_viols + ov_viols + oob_viols
        total_violations += layer_viols
        density_pct = min(100.0, (area_sum * 100.0) / die_area)
        status = "PASSED" if layer_viols == 0 else "FAILED"
        summary_lines.append(
            f"  L{layer:<3d} ({lname:<8s}): polys={len(boxes):6d}, density={density_pct:5.2f}%, "
            f"width_err={w_viols}, space_err={s_viols}, overlap_err={ov_viols}, oob_err={oob_viols} -> {status}"
        )

    lines = [
        "=" * 84,
        "GEOMETRIC GDSII DESIGN RULE CHECK (DRC) VERIFICATION REPORT",
        f"Technology      : {tech_name}",
        f"Top Cell        : {top_name or (structs[0] if structs else 'unknown')}",
        f"GDSII File      : {os.path.relpath(gds_path)}",
        f"GDSII Size      : {os.path.getsize(gds_path):,} bytes | ENDLIB={has_endlib}",
        f"Die Bounding Box: ({die_x1/1000:.2f}, {die_y1/1000:.2f}) um to ({die_x2/1000:.2f}, {die_y2/1000:.2f}) um "
        f"[{(die_x2-die_x1)/1000:.2f} um x {(die_y2-die_y1)/1000:.2f} um]",
        "Checker Engine  : Python Geometric GDSII Sweep-Line DRC Verifier (Reference Deck)",
        "=" * 84,
        "LAYER-BY-LAYER GEOMETRIC CHECKS:",
        *summary_lines,
        "-" * 84,
        f"TOTAL GEOMETRIC DRC VIOLATIONS: {total_violations}",
        f"DRC STATUS: {'CLEAN (0 VIOLATIONS)' if total_violations == 0 else 'FAILED'}",
        "=" * 84,
    ]
    report_txt = "\n".join(lines) + "\n"
    if report_path:
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as rf:
            rf.write(report_txt)
    print(report_txt)
    return total_violations
