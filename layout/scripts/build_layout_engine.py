#!/usr/bin/env python3
"""
Procedural SkyWater 130nm Multi-Layer GDSII Generator Template.
Builds a DRC-clean ASIC layout (NWELL, DIFF, POLY, CONTACT, M1..M5, VIA1..VIA4, PAD, DIEAREA)
with orthogonal power rings, non-overlapping signal tracks, and macro placement,
then invokes verify_gds_drc.verify_gds() to certify 0 geometric violations.
"""

import os
import struct
from verify_gds_drc import verify_gds


class GDSWriter:
    def __init__(self, filename, libname="ASIC_LIB"):
        self.filename = filename
        self.f = open(filename, "wb")
        self.write_record(0x0002, struct.pack(">h", 600))
        self.write_record(0x0102, b"\x00" * 24)
        nb = (libname + "\x00").encode("ascii")
        if len(nb) % 2 != 0:
            nb += b"\x00"
        self.write_record(0x0206, nb)
        self.write_record(0x0305, struct.pack(">dd", 0.001, 1e-9))

    def write_record(self, rec_type, data=b""):
        self.f.write(struct.pack(">HH", 4 + len(data), rec_type))
        if data:
            self.f.write(data)

    def start_structure(self, strname):
        self.write_record(0x0502, b"\x00" * 24)
        nb = (strname + "\x00").encode("ascii")
        if len(nb) % 2 != 0:
            nb += b"\x00"
        self.write_record(0x0606, nb)

    def end_structure(self):
        self.write_record(0x0700)

    def add_box(self, layer, datatype, x1, y1, x2, y2):
        coords = [int(x1), int(y1), int(x2), int(y1), int(x2), int(y2), int(x1), int(y2), int(x1), int(y1)]
        self.write_record(0x0800)
        self.write_record(0x0D02, struct.pack(">h", layer))
        self.write_record(0x0E02, struct.pack(">h", datatype))
        self.write_record(0x1003, struct.pack(f">{len(coords)}i", *coords))
        self.write_record(0x1100)

    def close(self):
        self.write_record(0x0400)
        self.f.close()


def build_asic_layout(
    gds_path,
    report_path,
    top_name="chip_top",
    libname="CHIP_LIB",
    die_w=400000,
    die_h=400000,
    macro_cols=4,
    macro_rows=4,
    pad_count_per_side=4,
    tech_name="SkyWater 130nm",
):
    os.makedirs(os.path.dirname(gds_path), exist_ok=True)
    os.makedirs(os.path.dirname(report_path), exist_ok=True)

    L_DIE_AREA = 235
    L_NWELL = 64
    L_DIFF = 65
    L_POLY = 66
    L_CONTACT = 67
    L_MET1 = 68
    L_VIA1 = 69
    L_MET2 = 70
    L_VIA2 = 71
    L_MET3 = 72
    L_VIA3 = 73
    L_MET4 = 74
    L_VIA4 = 75
    L_MET5 = 76
    L_PAD = 108

    gds = GDSWriter(gds_path, libname)
    gds.start_structure(top_name)
    gds.add_box(L_DIE_AREA, 0, 0, 0, die_w, die_h)

    # Ring geometry strictly orthogonal:
    # M5 horizontal top/bottom rails (stop cleanly inside die)
    # M4 vertical left/right rails bridged via VIA4 at corners
    RING_M = 28000
    RING_W = 5000
    CORE_X1, CORE_Y1 = RING_M + RING_W + 10000, RING_M + RING_W + 10000
    CORE_X2, CORE_Y2 = die_w - RING_M - RING_W - 10000, die_h - RING_M - RING_W - 10000

    # Top & Bottom M5 Power Rings
    gds.add_box(L_MET5, 0, RING_M, RING_M, die_w - RING_M, RING_M + RING_W)
    gds.add_box(L_MET5, 0, RING_M, die_h - RING_M - RING_W, die_w - RING_M, die_h - RING_M)

    # Left & Right M4 Power Rings (vertical edges)
    gds.add_box(L_MET4, 0, RING_M, RING_M, RING_M + RING_W, die_h - RING_M)
    gds.add_box(L_MET4, 0, die_w - RING_M - RING_W, RING_M, die_w - RING_M, die_h - RING_M)

    # VIA4 bridges at 4 corners inside overlap regions (no intra-layer overlap)
    for vx in (RING_M + 1000, die_w - RING_M - RING_W + 1000):
        for vy in (RING_M + 1000, die_h - RING_M - RING_W + 1000):
            gds.add_box(L_VIA4, 0, vx, vy, vx + 3000, vy + 3000)

    # Non-overlapping I/O Bond Pads strictly outside RING_M (corners kept clear!)
    PAD_W, PAD_H = 12000, 12000
    PAD_OFF = 6000
    span_x = (CORE_X2 - CORE_X1)
    span_y = (CORE_Y2 - CORE_Y1)
    for i in range(pad_count_per_side):
        px = CORE_X1 + int((i + 0.5) * span_x / pad_count_per_side) - PAD_W // 2
        py = CORE_Y1 + int((i + 0.5) * span_y / pad_count_per_side) - PAD_H // 2
        # South edge pad & feeder on M4 (wait: feeder enters M5 ring? Use M3 feeder up to core to avoid M4/M5 short)
        gds.add_box(L_PAD, 0, px, PAD_OFF, px + PAD_W, PAD_OFF + PAD_H)
        gds.add_box(L_PAD, 0, px, die_h - PAD_OFF - PAD_H, px + PAD_W, die_h - PAD_OFF)
        gds.add_box(L_PAD, 0, PAD_OFF, py, PAD_OFF + PAD_H, py + PAD_W)
        gds.add_box(L_PAD, 0, die_w - PAD_OFF - PAD_H, py, die_w - PAD_OFF, py + PAD_W)
        # Feeder traces strictly in M3 from pads into core boundary (M4/M5 sit above, no conflict!)
        gds.add_box(L_MET3, 0, px + 4000, PAD_OFF + PAD_H, px + 8000, CORE_Y1 - 2000)
        gds.add_box(L_MET3, 0, px + 4000, CORE_Y2 + 2000, px + 8000, die_h - PAD_OFF - PAD_H)
        gds.add_box(L_MET3, 0, PAD_OFF + PAD_H, py + 4000, CORE_X1 - 2000, py + 8000)
        gds.add_box(L_MET3, 0, CORE_X2 + 2000, py + 4000, die_w - PAD_OFF - PAD_H, py + 8000)

    # Core Macro Grid with Standard Cells & Multi-Layer Interconnect
    chan = 8000
    mw = (span_x - (macro_cols - 1) * chan) // macro_cols
    mh = (span_y - (macro_rows - 1) * chan) // macro_rows

    CELL_H = 3000
    CELL_W = 1800
    for mr in range(macro_rows):
        my = CORE_Y1 + mr * (mh + chan)
        for mc in range(macro_cols):
            mx = CORE_X1 + mc * (mw + chan)
            gds.add_box(L_NWELL, 0, mx, my, mx + mw, my + mh)

            # Horizontal M1 rail per cell row + active cells
            num_rows = min(8, (mh - 2000) // (CELL_H + 600))
            num_cols = min(14, (mw - 2000) // (CELL_W + 400))
            for r in range(num_rows):
                ry = my + 1200 + r * (CELL_H + 600)
                gds.add_box(L_MET1, 0, mx + 500, ry, mx + mw - 500, ry + 400)
                gds.add_box(L_MET1, 0, mx + 500, ry + CELL_H - 400, mx + mw - 500, ry + CELL_H)
                for c in range(num_cols):
                    cx = mx + 1000 + c * (CELL_W + 400)
                    gds.add_box(L_DIFF, 0, cx + 150, ry + 500, cx + CELL_W - 150, ry + 1300)
                    gds.add_box(L_DIFF, 0, cx + 150, ry + 1700, cx + CELL_W - 150, ry + 2500)
                    gds.add_box(L_POLY, 0, cx + 450, ry + 350, cx + 650, ry + CELL_H - 350)
                    gds.add_box(L_POLY, 0, cx + 1150, ry + 350, cx + 1350, ry + CELL_H - 350)
                    gds.add_box(L_CONTACT, 0, cx + 200, ry + 700, cx + 400, ry + 900)
                    gds.add_box(L_CONTACT, 0, cx + 1450, ry + 2000, cx + 1650, ry + 2200)

            # Horizontal neighbor M3 bus in channel
            if mc < macro_cols - 1:
                for b in range(4):
                    by = my + 4000 + b * 4000
                    if by + 800 < my + mh:
                        gds.add_box(L_MET3, 0, mx + mw - 1000, by, mx + mw + chan + 1000, by + 600)
                        gds.add_box(L_VIA2, 0, mx + mw - 800, by + 100, mx + mw - 400, by + 500)
                        gds.add_box(L_VIA2, 0, mx + mw + chan + 400, by + 100, mx + mw + chan + 800, by + 500)

            # Vertical neighbor M2 bus in channel
            if mr < macro_rows - 1:
                for b in range(4):
                    bx = mx + 4000 + b * 4000
                    if bx + 800 < mx + mw:
                        gds.add_box(L_MET2, 0, bx, my + mh - 1000, bx + 600, my + mh + chan + 1000)
                        gds.add_box(L_VIA1, 0, bx + 100, my + mh - 800, bx + 500, my + mh - 400)
                        gds.add_box(L_VIA1, 0, bx + 100, my + mh + chan + 400, bx + 500, my + mh + chan + 800)

    # Interior Vertical M4 Power Straps aligned inside macro columns (between rings)
    for mc in range(macro_cols):
        sx = CORE_X1 + mc * (mw + chan) + mw // 2 - 1000
        gds.add_box(L_MET4, 0, sx, CORE_Y1, sx + 2000, CORE_Y2)

    gds.end_structure()
    gds.close()
    print(f"[SUCCESS] Built GDSII layout: {gds_path}")
    v = verify_gds(gds_path, report_path=report_path, top_name=top_name, tech_name=tech_name)
    if v != 0:
        raise SystemExit(f"DRC failed with {v} violations!")
    return v
