#!/usr/bin/env python3
"""
Generate boot_rom.hex for RetroPlay VGA Gaming SoC.
Exercises RV32IM MUL/DIV/REM, polls UART TX_BUSY at baud_div=2 to send "VGA",
writes SRAM, VRAM, Hardware Sprites, Chiptune Audio, and reads Gamepad.
"""

import os


def encode_r(funct7, rs2, rs1, funct3, rd, opcode=0x33):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def encode_lui(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def encode_addi(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0x0 << 12) | (rd << 7) | 0x13


def encode_andi(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0x7 << 12) | (rd << 7) | 0x13


def encode_sw(rs2, rs1, imm12):
    return (((imm12 >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (0x2 << 12) | ((imm12 & 0x1F) << 7) | 0x23


def encode_lw(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0x2 << 12) | (rd << 7) | 0x03


def encode_b(funct3, rs1, rs2, offset_bytes):
    imm = offset_bytes & 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63


def encode_jal(rd, imm21):
    return (((imm21 >> 20) & 1) << 31) | (((imm21 >> 1) & 0x3FF) << 21) | (((imm21 >> 11) & 1) << 20) | (((imm21 >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


def emit_uart_putc(instrs, uart_reg, ch):
    poll = len(instrs)
    instrs.append(encode_lw(7, uart_reg, 4))
    instrs.append(encode_andi(7, 7, 1))
    instrs.append(encode_b(0x1, 7, 0, (poll - len(instrs)) * 4))
    instrs.append(encode_addi(6, 0, ord(ch)))
    instrs.append(encode_sw(6, uart_reg, 0))


instructions = []
instructions.append(encode_lui(2, 0x10002))
instructions.append(encode_addi(2, 2, -16))

# UART_BASE = 0x60000000: baud_div=2 (30 ns/bit), send "VGA"
instructions.append(encode_lui(5, 0x60000))
instructions.append(encode_addi(6, 0, 2))
instructions.append(encode_sw(6, 5, 8))
for ch in "VGA":
    emit_uart_putc(instructions, 5, ch)

# System SRAM (0x10000000): 0x42 signature + RV32M arithmetic
instructions.append(encode_lui(5, 0x10000))
instructions.append(encode_addi(6, 0, 0x42))
instructions.append(encode_sw(6, 5, 4))    # mem[1] = 0x42

instructions.append(encode_addi(8, 0, 12))
instructions.append(encode_addi(9, 0, 11))
instructions.append(encode_r(0x01, 9, 8, 0x0, 10))  # MUL: 12 * 11 = 132
instructions.append(encode_sw(10, 5, 8))            # mem[2] = 132

instructions.append(encode_addi(8, 0, -100))
instructions.append(encode_addi(9, 0, 7))
instructions.append(encode_r(0x01, 9, 8, 0x4, 10))  # DIV: -100 / 7 = -14
instructions.append(encode_sw(10, 5, 12))           # mem[3] = -14
instructions.append(encode_r(0x01, 9, 8, 0x6, 10))  # REM: -100 % 7 = -2
instructions.append(encode_sw(10, 5, 16))           # mem[4] = -2

# VRAM Tilemap Write (0x20000000): vram[0] = 0x7E
instructions.append(encode_lui(5, 0x20000))
instructions.append(encode_addi(6, 0, 0x7E))
instructions.append(encode_sw(6, 5, 0))

# Sprite Engine Config (0x30000000)
instructions.append(encode_lui(5, 0x30000))
instructions.append(encode_lui(6, 6))
instructions.append(encode_addi(6, 6, 0x464))       # Y=100, X=100
instructions.append(encode_sw(6, 5, 0x00))
instructions.append(encode_addi(6, 0, 0x1E0))       # EN=1, Color=0xE0
instructions.append(encode_sw(6, 5, 0x20))

instructions.append(encode_lui(6, 7))
instructions.append(encode_addi(6, 6, 0x969))       # Y=105, X=105
instructions.append(encode_sw(6, 5, 0x04))
instructions.append(encode_addi(6, 0, 0x11C))       # EN=1, Color=0x1C
instructions.append(encode_sw(6, 5, 0x24))

# Chiptune Audio (0x40000000): short tone period = 16 for visible PWM activity
instructions.append(encode_lui(5, 0x40000))
instructions.append(encode_addi(6, 0, 1136))
instructions.append(encode_sw(6, 5, 0))             # ch1_freq = 1136 (verified register)

# Gamepad Read (0x50000000)
instructions.append(encode_lui(5, 0x50000))
instructions.append(encode_lw(7, 5, 0))

# Halt loop
instructions.append(encode_jal(0, 0))

hex_lines = [f"{instr:08x}" for instr in instructions]
while len(hex_lines) < 2048:
    hex_lines.append("00000013")

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_hex = os.path.join(repo_root, "boot_rom.hex")
with open(out_hex, "w", encoding="utf-8") as f:
    f.write("\n".join(hex_lines) + "\n")

print(f"Generated {out_hex} with {len(instructions)} active instructions.")
