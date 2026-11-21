#!/usr/bin/env python3
"""
Automated Simulation Script for RetroPlay VGA Gaming SoC.
Compiles RTL and Testbench using Icarus Verilog and executes with vvp.
"""

import subprocess
import sys
import os

def run():
    repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(repo_dir)

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
        "tb/tb_vga_game_soc.v"
    ]

    include_dirs = [
        "-Irtl/cpu",
        "-Irtl/bus",
        "-Irtl/video",
        "-Irtl/audio",
        "-Irtl/mem",
        "-Irtl/peripherals",
        "-Irtl/padframe",
        "-Irtl"
    ]

    sim_bin = "sim/vga_game_soc_sim.vvp"
    os.makedirs("sim", exist_ok=True)

    cmd_compile = ["iverilog", "-g2005-sv"] + include_dirs + ["-o", sim_bin] + rtl_files
    print("[RUN] Compiling Verilog RTL with iverilog...")
    res = subprocess.run(cmd_compile, capture_output=True, text=True)
    if res.returncode != 0:
        print("[ERROR] Compilation failed:")
        print(res.stderr)
        sys.exit(1)
    print("[OK] Compilation successful.")

    print("[RUN] Running simulation with vvp...")
    res_run = subprocess.run(["vvp", sim_bin], capture_output=True, text=True)
    print(res_run.stdout)
    if res_run.stderr:
        print(res_run.stderr)

    if "[STATUS] RETROPLAY SOC VERIFICATION: 100% PASSED" in res_run.stdout:
        print("[SUCCESS] All test assertions verified!")
    else:
        print("[WARNING] Simulation did not return 100% PASS.")

if __name__ == "__main__":
    run()
