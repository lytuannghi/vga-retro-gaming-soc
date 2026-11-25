#!/usr/bin/env python3
"""
Portable Simulation Runner for RetroPlay VGA Gaming SoC.
Compiles RTL and Testbench using Icarus Verilog (-Wall) and executes with vvp.
"""

import os
import shutil
import subprocess
import sys


def resolve_tool(name, repo_dir):
    found = shutil.which(name)
    if found:
        return found
    sibling = os.path.join(os.path.dirname(repo_dir), "iverilog", "bin", name + ".exe")
    return sibling if os.path.exists(sibling) else name


def run():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_dir)
    os.makedirs("sim", exist_ok=True)

    iverilog_exe = resolve_tool("iverilog", repo_dir)
    vvp_exe = resolve_tool("vvp", repo_dir)

    rtl_files = [
        "rtl/cpu/riscv_alu.v",
        "rtl/cpu/alu_mul_div.v",
        "rtl/cpu/riscv_regfile.v",
        "rtl/cpu/riscv_core.v",
        "rtl/bus/soc_interconnect.v",
        "rtl/mem/boot_rom.v",
        "rtl/mem/system_sram.v",
        "rtl/video/vga_timing_gen.v",
        "rtl/video/sprite_engine.v",
        "rtl/video/vga_subsystem_top.v",
        "rtl/audio/chiptune_audio.v",
        "rtl/peripherals/gamepad_controller.v",
        "rtl/peripherals/uart_controller.v",
        "rtl/padframe/chip_padring.v",
        "rtl/vga_game_soc_top.v",
        "tb/tb_vga_game_soc.v",
    ]

    include_dirs = [
        "-Irtl/cpu", "-Irtl/bus", "-Irtl/video", "-Irtl/audio",
        "-Irtl/mem", "-Irtl/peripherals", "-Irtl/padframe", "-Irtl",
    ]

    sim_bin = "sim/vga_game_soc_sim.vvp"
    cmd_compile = [iverilog_exe, "-Wall", "-g2005"] + include_dirs + ["-o", sim_bin] + rtl_files
    print("[RUN] Compiling Verilog RTL with iverilog (-Wall)...")
    res = subprocess.run(cmd_compile, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if res.returncode != 0 or res.stderr.strip():
        print("[ERROR] Compilation failed or emitted -Wall warnings:")
        print(res.stderr)
        sys.exit(1)
    print("[OK] Compilation Clean (0 warnings).")

    print("[RUN] Running simulation with vvp...")
    res_run = subprocess.run([vvp_exe, sim_bin], capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(res_run.stdout)
    if res_run.stderr:
        print(res_run.stderr)

    if res_run.returncode == 0 and "[STATUS] RETROPLAY SOC VERIFICATION: 100% PASSED" in res_run.stdout and "[FAIL]" not in res_run.stdout:
        print("[SUCCESS] All test assertions verified!")
    else:
        print("[ERROR] Simulation did not return 100% PASS.")
        sys.exit(1)


if __name__ == "__main__":
    run()
