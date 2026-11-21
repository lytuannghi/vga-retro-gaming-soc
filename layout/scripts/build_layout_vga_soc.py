#!/usr/bin/env python3
"""
Physical Layout Generator for RetroPlay VGA Gaming SoC.
Generates binary GDSII layout viewable in KLayout without external dependencies.
"""

import struct
import os
import time

class GDSWriter:
    def __init__(self, filename, libname="VGA_SOC_LIB"):
        self.f = open(filename, "wb")
        self.libname = libname
        self._write_header()

    def _write_record(self, rec_type, data_type, data=b""):
        rec_len = len(data) + 4
        self.f.write(struct.pack(">HH", rec_len, (rec_type << 8) | data_type))
        if data:
            self.f.write(data)

    def _write_header(self):
        # HEADER (version 3)
        self._write_record(0x00, 0x02, struct.pack(">H", 600))
        # BGNLIB
        t = time.localtime()
        time_data = struct.pack(">12H", t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec,
                                       t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec)
        self._write_record(0x01, 0x02, time_data)
        # LIBNAME
        libname_bytes = self.libname.encode("ascii")
        if len(libname_bytes) % 2 != 0:
            libname_bytes += b"\0"
        self._write_record(0x02, 0x06, libname_bytes)
        # UNITS: user unit = 1e-6 (um), database unit = 1e-9 (nm)
        self._write_record(0x03, 0x05, struct.pack(">dd", 0.001, 1e-9))

    def bgn_str(self, strname):
        t = time.localtime()
        time_data = struct.pack(">12H", t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec,
                                       t.tm_year, t.tm_mon, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec)
        self._write_record(0x05, 0x02, time_data)
        str_bytes = strname.encode("ascii")
        if len(str_bytes) % 2 != 0:
            str_bytes += b"\0"
        self._write_record(0x06, 0x06, str_bytes)

    def end_str(self):
        self._write_record(0x07, 0x00)

    def add_box(self, layer, datatype, x1, y1, x2, y2):
        self._write_record(0x08, 0x00) # BOUNDARY
        self._write_record(0x0D, 0x02, struct.pack(">H", layer))
        self._write_record(0x0E, 0x02, struct.pack(">H", datatype))
        # 5 points in database units (nm = um * 1000)
        pts = [
            (int(x1 * 1000), int(y1 * 1000)),
            (int(x2 * 1000), int(y1 * 1000)),
            (int(x2 * 1000), int(y2 * 1000)),
            (int(x1 * 1000), int(y2 * 1000)),
            (int(x1 * 1000), int(y1 * 1000))
        ]
        xy_data = b"".join(struct.pack(">ii", p[0], p[1]) for p in pts)
        self._write_record(0x10, 0x03, xy_data)
        self._write_record(0x11, 0x00) # ENDEL

    def close(self):
        self._write_record(0x04, 0x00) # ENDLIB
        self.f.close()


def generate_vga_soc_layout():
    out_dir = "layout/gds"
    os.makedirs(out_dir, exist_ok=True)
    gds_path = os.path.join(out_dir, "vga_game_soc_top.gds")

    gds = GDSWriter(gds_path, libname="RETROPLAY_VGA_SOC")
    gds.bgn_str("vga_game_soc_top")

    # Layer convention:
    # Layer 100: PR Boundary (Die edge: 1300um x 1300um)
    # Layer 108: Pad cells (80um x 80um)
    # Layer 21: Metal 1 (Standard cell rows)
    # Layer 31: Metal 2 (Power stripes vertical)
    # Layer 41: Metal 3 (Power stripes horizontal)
    # Layer 51: Metal 4 (Clock mesh & Top power rings)

    # 1. Die Boundary
    gds.add_box(100, 0, 0, 0, 1300, 1300)

    # 2. I/O Pad Ring (64 pads around perimeter)
    pad_w = 60
    pad_h = 75
    # Bottom & Top pads
    for i in range(16):
        x = 100 + i * 70
        gds.add_box(108, 0, x, 10, x + pad_w, 10 + pad_h)       # Bottom
        gds.add_box(108, 0, x, 1215, x + pad_w, 1215 + pad_h)  # Top
    # Left & Right pads
    for i in range(16):
        y = 100 + i * 70
        gds.add_box(108, 0, 10, y, 10 + pad_h, y + pad_w)       # Left
        gds.add_box(108, 0, 1215, y, 1215 + pad_h, y + pad_w)  # Right

    # 3. Core Power Ring (Metal 4 / Metal 3)
    gds.add_box(51, 0, 110, 110, 1190, 125) # Bottom ring
    gds.add_box(51, 0, 110, 1175, 1190, 1190) # Top ring
    gds.add_box(51, 0, 110, 110, 125, 1190) # Left ring
    gds.add_box(51, 0, 1175, 110, 1190, 1190) # Right ring

    # 4. Functional IP Macros Floorplan:
    # Macro A: RV32IM CPU Core (300um x 350um)
    gds.add_box(100, 1, 150, 150, 480, 520)
    # CPU sub-blocks
    gds.add_box(21, 0, 160, 160, 300, 320) # ALU & Control
    gds.add_box(21, 0, 310, 160, 470, 320) # Register File
    gds.add_box(21, 0, 160, 330, 470, 510) # Hardware Mul/Div (M-Extension)

    # Macro B: VGA Video Subsystem (400um x 400um)
    gds.add_box(100, 2, 520, 150, 950, 580)
    # VGA sub-blocks
    gds.add_box(21, 0, 530, 160, 710, 340) # Dual-Port VRAM
    gds.add_box(21, 0, 720, 160, 940, 340) # VGA Timing Generator & DAC
    gds.add_box(21, 0, 530, 350, 940, 570) # 8x Hardware Sprite Engine

    # Macro C: On-Chip Memories (Boot ROM & SRAM)
    gds.add_box(100, 3, 150, 560, 480, 880)
    gds.add_box(21, 0, 160, 570, 470, 710) # 8KB Boot ROM
    gds.add_box(21, 0, 160, 720, 470, 870) # 8KB System SRAM

    # Macro D: Chiptune Audio Synthesizer (250um x 200um)
    gds.add_box(100, 4, 520, 620, 790, 850)
    gds.add_box(21, 0, 530, 630, 780, 730) # Tone Generators & LFSR
    gds.add_box(21, 0, 530, 740, 780, 840) # Mixer & PWM DAC Modulator

    # Macro E: System Interconnect & Peripherals (Gamepad, UART)
    gds.add_box(100, 5, 830, 620, 1140, 850)
    gds.add_box(21, 0, 840, 630, 970, 730) # Crossbar Interconnect
    gds.add_box(21, 0, 980, 630, 1130, 730) # Retro Gamepad Controller
    gds.add_box(21, 0, 840, 740, 1130, 840) # Full-Duplex UART

    # 5. Core Standard Cell Rows (Metal 1 fill)
    for row in range(50):
        y = 150 + row * 20
        gds.add_box(21, 1, 150, y, 1140, y + 8)

    # 6. Power Grid (Metal 3 Horizontal & Metal 2 Vertical stripes)
    for sx in range(12):
        x = 180 + sx * 80
        gds.add_box(31, 0, x, 140, x + 6, 1160) # Vertical VDD/VSS
    for sy in range(12):
        y = 180 + sy * 80
        gds.add_box(41, 0, 140, y, 1160, y + 6) # Horizontal VDD/VSS

    # 7. Clock Distribution Network (H-Tree Trunk Metal 4)
    gds.add_box(51, 1, 640, 150, 660, 1150) # Vertical main trunk
    gds.add_box(51, 1, 150, 640, 1150, 660) # Horizontal branch

    gds.end_str()
    gds.close()

    print(f"[OK] Generated GDSII: {gds_path} ({os.path.getsize(gds_path)} bytes)")

if __name__ == "__main__":
    generate_vga_soc_layout()
