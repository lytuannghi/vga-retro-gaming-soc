// =============================================================================
// File: soc_interconnect.v
// Module: soc_interconnect
// Project: RetroPlay VGA Gaming SoC
// Description: Multi-slave crossbar interconnect routing CPU data requests
//              to ROM, SRAM, VRAM, Sprites, Chiptune Audio, Gamepad, UART.
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module soc_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Data Master Interface
    input  wire        cpu_req,
    input  wire        cpu_wr,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata,
    output reg         cpu_ready,

    // Slave 0: ROM (0x0000_0000)
    output wire        rom_req,
    output wire [31:0] rom_addr,
    input  wire [31:0] rom_rdata,
    input  wire        rom_ready,

    // Slave 1: System SRAM (0x1000_0000)
    output wire        sram_req,
    output wire        sram_wr,
    output wire [31:0] sram_addr,
    output wire [31:0] sram_wdata,
    output wire [3:0]  sram_wstrb,
    input  wire [31:0] sram_rdata,
    input  wire        sram_ready,

    // Slave 2: VGA VRAM (0x2000_0000)
    output wire        vram_req,
    output wire        vram_wr,
    output wire [31:0] vram_addr,
    output wire [31:0] vram_wdata,
    output wire [3:0]  vram_wstrb,
    input  wire [31:0] vram_rdata,
    input  wire        vram_ready,

    // Slave 3: Sprite Engine Registers (0x3000_0000)
    output wire        sprite_req,
    output wire        sprite_wr,
    output wire [31:0] sprite_addr,
    output wire [31:0] sprite_wdata,
    input  wire [31:0] sprite_rdata,
    input  wire        sprite_ready,

    // Slave 4: Chiptune Audio Registers (0x4000_0000)
    output wire        audio_req,
    output wire        audio_wr,
    output wire [31:0] audio_addr,
    output wire [31:0] audio_wdata,
    input  wire [31:0] audio_rdata,
    input  wire        audio_ready,

    // Slave 5: Gamepad Controller (0x5000_0000)
    output wire        gamepad_req,
    output wire        gamepad_wr,
    output wire [31:0] gamepad_addr,
    output wire [31:0] gamepad_wdata,
    input  wire [31:0] gamepad_rdata,
    input  wire        gamepad_ready,

    // Slave 6: UART Controller (0x6000_0000)
    output wire        uart_req,
    output wire        uart_wr,
    output wire [31:0] uart_addr,
    output wire [31:0] uart_wdata,
    input  wire [31:0] uart_rdata,
    input  wire        uart_ready
);

    // Address Decoding (Top 4 bits [31:28])
    wire sel_rom     = (cpu_addr[31:28] == 4'h0);
    wire sel_sram    = (cpu_addr[31:28] == 4'h1);
    wire sel_vram    = (cpu_addr[31:28] == 4'h2);
    wire sel_sprite  = (cpu_addr[31:28] == 4'h3);
    wire sel_audio   = (cpu_addr[31:28] == 4'h4);
    wire sel_gamepad = (cpu_addr[31:28] == 4'h5);
    wire sel_uart    = (cpu_addr[31:28] == 4'h6);

    // Slave Request Demux
    assign rom_req     = cpu_req & sel_rom;
    assign rom_addr    = cpu_addr;

    assign sram_req    = cpu_req & sel_sram;
    assign sram_wr     = cpu_wr;
    assign sram_addr   = cpu_addr;
    assign sram_wdata  = cpu_wdata;
    assign sram_wstrb  = cpu_wstrb;

    assign vram_req    = cpu_req & sel_vram;
    assign vram_wr     = cpu_wr;
    assign vram_addr   = cpu_addr;
    assign vram_wdata  = cpu_wdata;
    assign vram_wstrb  = cpu_wstrb;

    assign sprite_req   = cpu_req & sel_sprite;
    assign sprite_wr    = cpu_wr;
    assign sprite_addr  = cpu_addr;
    assign sprite_wdata = cpu_wdata;

    assign audio_req   = cpu_req & sel_audio;
    assign audio_wr    = cpu_wr;
    assign audio_addr  = cpu_addr;
    assign audio_wdata = cpu_wdata;

    assign gamepad_req   = cpu_req & sel_gamepad;
    assign gamepad_wr    = cpu_wr;
    assign gamepad_addr  = cpu_addr;
    assign gamepad_wdata = cpu_wdata;

    assign uart_req    = cpu_req & sel_uart;
    assign uart_wr     = cpu_wr;
    assign uart_addr   = cpu_addr;
    assign uart_wdata  = cpu_wdata;

    // Response Multiplexing
    always @(*) begin
        if (sel_rom) begin
            cpu_rdata = rom_rdata;
            cpu_ready = rom_ready;
        end else if (sel_sram) begin
            cpu_rdata = sram_rdata;
            cpu_ready = sram_ready;
        end else if (sel_vram) begin
            cpu_rdata = vram_rdata;
            cpu_ready = vram_ready;
        end else if (sel_sprite) begin
            cpu_rdata = sprite_rdata;
            cpu_ready = sprite_ready;
        end else if (sel_audio) begin
            cpu_rdata = audio_rdata;
            cpu_ready = audio_ready;
        end else if (sel_gamepad) begin
            cpu_rdata = gamepad_rdata;
            cpu_ready = gamepad_ready;
        end else if (sel_uart) begin
            cpu_rdata = uart_rdata;
            cpu_ready = uart_ready;
        end else begin
            cpu_rdata = 32'hDEAD_BEEF;
            cpu_ready = cpu_req; // immediate ACK for unmapped address
        end
    end

endmodule
