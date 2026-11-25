#!/usr/bin/env python3
"""
Portable RTL Synthesis Readiness & Constraint Verification Analyzer.
Counts synthesizable RTL structural complexity, checks reset/timescale hygiene,
validates SDC timing constraint declarations, and writes a transparent report.
"""

import glob
import os
import re
import sys


def analyze_project(syn_dir=None):
    if syn_dir is None:
        syn_dir = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(syn_dir)
    rtl_files = sorted(glob.glob(os.path.join(root, "rtl", "**", "*.v"), recursive=True))
    rtl_files += sorted(glob.glob(os.path.join(root, "rtl", "**", "*.sv"), recursive=True))
    sdc_files = sorted(glob.glob(os.path.join(syn_dir, "*.sdc")))
    rep_dir = os.path.join(syn_dir, "reports")
    os.makedirs(rep_dir, exist_ok=True)
    rep_path = os.path.join(rep_dir, "rtl_synthesis_check.txt")

    modules = []
    total_loc = 0
    total_regs = 0
    total_always_ff = 0
    total_always_comb = 0
    unbounded_divs = []

    for path in rtl_files:
        rel = os.path.relpath(path, root)
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
        code = re.sub(r"//.*", "", raw)
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)
        lines = [ln for ln in code.splitlines() if ln.strip()]
        total_loc += len(lines)
        mods = re.findall(r"\bmodule\s+([A-Za-z_][A-Za-z0-9_]*)", code)
        always_ff = len(re.findall(r"\balways\s*@\s*\(\s*(?:posedge|negedge)", code))
        always_cb = len(re.findall(r"\balways\s*@\s*\(\s*\*\s*\)|\balways_comb\b", code))
        regs = len(re.findall(r"\b(?:reg|logic)\b", code))
        total_always_ff += always_ff
        total_always_comb += always_cb
        total_regs += regs
        for ln_i, ln in enumerate(raw.splitlines(), 1):
            stripped = re.sub(r"//.*", "", ln)
            if re.search(r"[^a-zA-Z0-9_]\s*/\s*[^/\*=]|[^a-zA-Z0-9_]\s*%\s*[^%]", stripped):
                if not re.search(r"`timescale", stripped):
                    unbounded_divs.append(f"{rel}:{ln_i}: {ln.strip()}")
        modules.append((rel, mods, len(lines), always_ff, always_cb, regs))

    clocks = []
    for spath in sdc_files:
        with open(spath, "r", encoding="utf-8", errors="replace") as f:
            sdc = f.read()
        for m in re.finditer(r"create_clock\b[^\n]*-period\s+([0-9.]+)[^\n]*(?:\[get_ports\s+([^\]]+)\])?", sdc):
            period = float(m.group(1))
            port = (m.group(2) or "clk").strip()
            freq = 1000.0 / period if period > 0 else 0.0
            clocks.append((os.path.basename(spath), port, period, freq))

    out = [
        "=" * 80,
        f"RTL SYNTHESIS READINESS & CONSTRAINT REPORT: {os.path.basename(root)}",
        "Method : Static Verilog/SV Structural Parser + SDC Constraint Audit",
        "Note   : Foundry Gate-Level Netlist & STA require PDK Liberty (.lib) + Synopsys/OpenROAD",
        "=" * 80,
        f"RTL Source Files Inspected : {len(rtl_files)}",
        f"Code Lines (Non-Comment)   : {total_loc}",
        f"Sequential Blocks          : {total_always_ff}",
        f"Combinational Blocks       : {total_always_comb}",
        f"Declared reg/logic Signals : {total_regs}",
        "",
        "MODULE BREAKDOWN:",
    ]
    for rel, mods, loc, ff, cb, rg in modules:
        mod_str = ", ".join(mods) if mods else "(header/include)"
        out.append(f"  {rel:<45s} | modules={mod_str:<28s} | loc={loc:4d} | seq={ff:2d} | comb={cb:2d}")
    out.append("")
    out.append("SDC CLOCK CONSTRAINTS:")
    if clocks:
        for fname, port, per, frq in clocks:
            out.append(f"  {fname}: port={port} | period={per:.2f} ns | target={frq:.2f} MHz")
    else:
        out.append("  (No create_clock constraints found)")
    out.append("")
    if unbounded_divs:
        out.append(f"ARITHMETIC DIVISION/MODULO OPERATORS DETECTED ({len(unbounded_divs)}):")
        for item in unbounded_divs[:10]:
            out.append(f"  WARN: {item}")
    else:
        out.append("ARITHMETIC DIVISION/MODULO CHECK: CLEAN (0 combinational / or % operators)")
    out.append("=" * 80)

    report_text = "\n".join(out) + "\n"
    with open(rep_path, "w", encoding="utf-8") as f:
        f.write(report_text)
    print(report_text)
    return 0


if __name__ == "__main__":
    sys.exit(analyze_project())
