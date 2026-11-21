// =============================================================================
// File: bus_defines.vh
// Module: System Bus Address Map & Defines
// Project: RetroPlay VGA Gaming SoC (RV32IM + 2D GPU + Chiptune Audio)
// =============================================================================

`ifndef BUS_DEFINES_VH
`define BUS_DEFINES_VH

// Base Addresses
`define ADDR_ROM_BASE       32'h0000_0000
`define ADDR_ROM_MASK       32'hF000_0000 // Match 0x0000_0000

`define ADDR_SRAM_BASE      32'h1000_0000
`define ADDR_SRAM_MASK      32'hF000_0000 // Match 0x1000_0000

`define ADDR_VRAM_BASE      32'h2000_0000
`define ADDR_VRAM_MASK      32'hF000_0000 // Match 0x2000_0000

`define ADDR_SPRITE_BASE    32'h3000_0000
`define ADDR_SPRITE_MASK    32'hF000_0000 // Match 0x3000_0000

`define ADDR_AUDIO_BASE     32'h4000_0000
`define ADDR_AUDIO_MASK     32'hF000_0000 // Match 0x4000_0000

`define ADDR_GAMEPAD_BASE   32'h5000_0000
`define ADDR_GAMEPAD_MASK   32'hF000_0000 // Match 0x5000_0000

`define ADDR_UART_BASE      32'h6000_0000
`define ADDR_UART_MASK      32'hF000_0000 // Match 0x6000_0000

`endif // BUS_DEFINES_VH
