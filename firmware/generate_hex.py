#!/usr/bin/env python3
"""
Generate boot_rom.hex for RetroPlay VGA Gaming SoC.
Assembles raw RV32I instructions matching the hardware memory map.
"""

def encode_lui(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37

def encode_addi(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0x0 << 12) | (rd << 7) | 0x13

def encode_sw(rs2, rs1, imm12):
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0 = imm12 & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0x2 << 12) | (imm_4_0 << 7) | 0x23

def encode_lw(rd, rs1, imm12):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (0x2 << 12) | (rd << 7) | 0x03

def encode_jal(rd, imm21):
    imm20 = (imm21 >> 20) & 0x1
    imm10_1 = (imm21 >> 1) & 0x3FF
    imm11 = (imm21 >> 11) & 0x1
    imm19_12 = (imm21 >> 12) & 0xFF
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd << 7) | 0x6F

# Registers: x0=0, x1=ra, x2=sp, x5=t0, x6=t1, x7=t2
instructions = [
    # 0x00: lui sp, 0x10002 -> sp = 0x10002000
    encode_lui(2, 0x10002),
    # 0x04: addi sp, sp, -16 -> sp = 0x10001FF0
    encode_addi(2, 2, -16),

    # --- Test 1: UART Initial Print ---
    # lui t0, 0x60000 -> t0 = 0x60000000
    encode_lui(5, 0x60000),
    # addi t1, x0, 0x56 ('V')
    encode_addi(6, 0, 0x56),
    # sw t1, 0(t0) -> UART TX = 'V'
    encode_sw(6, 5, 0),

    # --- Test 2: System SRAM Access ---
    # lui t0, 0x10000 -> t0 = 0x10000000
    encode_lui(5, 0x10000),
    # addi t1, x0, 0x42
    encode_addi(6, 0, 0x42),
    # sw t1, 4(t0) -> sram.mem[1] = 0x42
    encode_sw(6, 5, 4),
    # lw t2, 4(t0)
    encode_lw(7, 5, 4),

    # --- Test 3: VRAM Tilemap Write ---
    # lui t0, 0x20000 -> t0 = 0x20000000
    encode_lui(5, 0x20000),
    # addi t1, x0, 0x7E
    encode_addi(6, 0, 0x7E),
    # sw t1, 0(t0) -> vram[0] = 0x7E
    encode_sw(6, 5, 0),

    # --- Test 4: Sprite Engine Config ---
    # lui t0, 0x30000 -> t0 = 0x30000000
    encode_lui(5, 0x30000),
    # Sprite 0 Position: Y=100 (0x64), X=100 (0x64) -> 0x6464 (25700)
    # lui t1, 6 (0x6000), addi t1, t1, 0x464 (1124) -> 0x6464
    encode_lui(6, 6),
    encode_addi(6, 6, 0x464),
    encode_sw(6, 5, 0x00), # spr_pos[0] = {100, 100}

    # Sprite 0 Config: EN=1, Color=0xE0 -> 0x01E0 (480)
    encode_addi(6, 0, 0x1E0),
    encode_sw(6, 5, 0x20), # spr_cfg[0] = {EN=1, Color=0xE0}

    # Sprite 1 Position: Y=105 (0x69), X=105 (0x69) -> 0x6969
    # In RISC-V, 0x969 has bit 11 set (-1687), so lui must be 7 (0x7000 - 0x697 = 0x6969)
    encode_lui(6, 7),
    encode_addi(6, 6, 0x969),
    encode_sw(6, 5, 0x04), # spr_pos[1] = {105, 105}

    # Sprite 1 Config: EN=1, Color=0x1C -> 0x011C (284)
    encode_addi(6, 0, 0x11C),
    encode_sw(6, 5, 0x24), # spr_cfg[1] = {EN=1, Color=0x1C}

    # --- Test 5: Chiptune Audio Config ---
    # lui t0, 0x40000 -> t0 = 0x40000000
    encode_lui(5, 0x40000),
    # addi t1, x0, 1136
    encode_addi(6, 0, 1136),
    # sw t1, 0(t0) -> ch1_freq = 1136
    encode_sw(6, 5, 0),

    # --- Test 6: Gamepad Read ---
    # lui t0, 0x50000 -> t0 = 0x50000000
    encode_lui(5, 0x50000),
    # lw t2, 0(t0)
    encode_lw(7, 5, 0),

    # Infinite Loop: jal x0, 0
    encode_jal(0, 0)
]

hex_lines = [f"{instr:08x}" for instr in instructions]
while len(hex_lines) < 2048:
    hex_lines.append("00000013")

with open("boot_rom.hex", "w") as f:
    f.write("\n".join(hex_lines) + "\n")

print(f"Generated boot_rom.hex with {len(instructions)} active instructions.")
