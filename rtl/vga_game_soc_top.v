// =============================================================================
// File: vga_game_soc_top.v
// Module: vga_game_soc_top
// Project: RetroPlay VGA Gaming SoC (Full-Flow ASIC Tape-Out)
// Description: Complete System-on-Chip Top-Level integrating RV32IM CPU Core,
//              Crossbar Bus Interconnect, 8KB ROM, 8KB SRAM, VGA 2D Subsystem,
//              Chiptune Audio Synthesizer, Retro Gamepad, UART, and I/O Padframe.
// =============================================================================

`timescale 1ns / 1ps
`include "bus_defines.vh"

module vga_game_soc_top (
    // Physical Chip I/O Pins
    input  wire        pad_clk,
    input  wire        pad_rst_n,

    // VGA DAC Interface (8-bit color R3:G3:B2 + sync)
    output wire [2:0]  pad_vga_r,
    output wire [2:0]  pad_vga_g,
    output wire [1:0]  pad_vga_b,
    output wire        pad_vga_hsync,
    output wire        pad_vga_vsync,

    // Audio PWM Pin
    output wire        pad_audio_pwm,

    // Gamepad Pins
    input  wire [7:0]  pad_gamepad_btn_n,

    // UART Serial Pins
    output wire        pad_uart_tx,
    input  wire        pad_uart_rx
);

    // Internal Core Signals
    wire        clk;
    wire        rst_n;

    wire [2:0]  core_vga_r;
    wire [2:0]  core_vga_g;
    wire [1:0]  core_vga_b;
    wire        core_vga_hsync;
    wire        core_vga_vsync;
    wire        core_audio_pwm;
    wire [7:0]  core_gamepad_btn_n;
    wire        core_uart_tx;
    wire        core_uart_rx;

    // Padframe Instance
    chip_padring u_padring (
        .pad_ext_clk       (pad_clk),
        .pad_ext_rst_n     (pad_rst_n),
        .pad_vga_r         (pad_vga_r),
        .pad_vga_g         (pad_vga_g),
        .pad_vga_b         (pad_vga_b),
        .pad_vga_hsync     (pad_vga_hsync),
        .pad_vga_vsync     (pad_vga_vsync),
        .pad_audio_pwm     (pad_audio_pwm),
        .pad_gamepad_btn_n (pad_gamepad_btn_n),
        .pad_uart_tx       (pad_uart_tx),
        .pad_uart_rx       (pad_uart_rx),

        .core_clk          (clk),
        .core_rst_n        (rst_n),
        .core_vga_r        (core_vga_r),
        .core_vga_g        (core_vga_g),
        .core_vga_b        (core_vga_b),
        .core_vga_hsync    (core_vga_hsync),
        .core_vga_vsync    (core_vga_vsync),
        .core_audio_pwm    (core_audio_pwm),
        .core_gamepad_btn_n(core_gamepad_btn_n),
        .core_uart_tx      (core_uart_tx),
        .core_uart_rx      (core_uart_rx)
    );

    // CPU Bus Signals
    wire [31:0] cpu_pc;
    wire [31:0] instr_addr;
    wire [31:0] instr_data;

    wire        cpu_data_req;
    wire        cpu_data_wr;
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_wdata;
    wire [3:0]  cpu_data_wstrb;
    wire [31:0] cpu_data_rdata;
    wire        cpu_data_ready;

    // RV32IM CPU Core
    riscv_core u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .instr_addr (instr_addr),
        .instr_data (instr_data),
        .data_req   (cpu_data_req),
        .data_wr    (cpu_data_wr),
        .data_addr  (cpu_data_addr),
        .data_wdata (cpu_data_wdata),
        .data_wstrb (cpu_data_wstrb),
        .data_rdata (cpu_data_rdata),
        .data_ready (cpu_data_ready),
        .curr_pc    (cpu_pc)
    );

    // Interconnect Signals
    wire        rom_req;
    wire [31:0] rom_addr;
    wire [31:0] rom_rdata;
    wire        rom_ready;

    wire        sram_req;
    wire        sram_wr;
    wire [31:0] sram_addr;
    wire [31:0] sram_wdata;
    wire [3:0]  sram_wstrb;
    wire [31:0] sram_rdata;
    wire        sram_ready;

    wire        vram_req;
    wire        vram_wr;
    wire [31:0] vram_addr;
    wire [31:0] vram_wdata;
    wire [3:0]  vram_wstrb;
    wire [31:0] vram_rdata;
    reg         vram_ready;

    wire        sprite_req;
    wire        sprite_wr;
    wire [31:0] sprite_addr;
    wire [31:0] sprite_wdata;
    wire [31:0] sprite_rdata;
    reg         sprite_ready;

    wire        audio_req;
    wire        audio_wr;
    wire [31:0] audio_addr;
    wire [31:0] audio_wdata;
    wire [31:0] audio_rdata;
    reg         audio_ready;

    wire        gamepad_req;
    wire        gamepad_wr;
    wire [31:0] gamepad_addr;
    wire [31:0] gamepad_wdata;
    wire [31:0] gamepad_rdata;
    wire        gamepad_ready;

    wire        uart_req;
    wire        uart_wr;
    wire [31:0] uart_addr;
    wire [31:0] uart_wdata;
    wire [31:0] uart_rdata;
    wire        uart_ready;

    // Bus Crossbar Interconnect
    soc_interconnect u_bus (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_req       (cpu_data_req),
        .cpu_wr        (cpu_data_wr),
        .cpu_addr      (cpu_data_addr),
        .cpu_wdata     (cpu_data_wdata),
        .cpu_wstrb     (cpu_data_wstrb),
        .cpu_rdata     (cpu_data_rdata),
        .cpu_ready     (cpu_data_ready),

        .rom_req       (rom_req),
        .rom_addr      (rom_addr),
        .rom_rdata     (rom_rdata),
        .rom_ready     (rom_ready),

        .sram_req      (sram_req),
        .sram_wr       (sram_wr),
        .sram_addr     (sram_addr),
        .sram_wdata    (sram_wdata),
        .sram_wstrb    (sram_wstrb),
        .sram_rdata    (sram_rdata),
        .sram_ready    (sram_ready),

        .vram_req      (vram_req),
        .vram_wr       (vram_wr),
        .vram_addr     (vram_addr),
        .vram_wdata    (vram_wdata),
        .vram_wstrb    (vram_wstrb),
        .vram_rdata    (vram_rdata),
        .vram_ready    (vram_ready),

        .sprite_req    (sprite_req),
        .sprite_wr     (sprite_wr),
        .sprite_addr   (sprite_addr),
        .sprite_wdata  (sprite_wdata),
        .sprite_rdata  (sprite_rdata),
        .sprite_ready  (sprite_ready),

        .audio_req     (audio_req),
        .audio_wr      (audio_wr),
        .audio_addr    (audio_addr),
        .audio_wdata   (audio_wdata),
        .audio_rdata   (audio_rdata),
        .audio_ready   (audio_ready),

        .gamepad_req   (gamepad_req),
        .gamepad_wr    (gamepad_wr),
        .gamepad_addr  (gamepad_addr),
        .gamepad_wdata (gamepad_wdata),
        .gamepad_rdata (gamepad_rdata),
        .gamepad_ready (gamepad_ready),

        .uart_req      (uart_req),
        .uart_wr       (uart_wr),
        .uart_addr     (uart_addr),
        .uart_wdata    (uart_wdata),
        .uart_rdata    (uart_rdata),
        .uart_ready    (uart_ready)
    );

    // Boot ROM (8KB)
    boot_rom u_rom (
        .clk        (clk),
        .rst_n      (rst_n),
        .instr_addr (instr_addr),
        .instr_data (instr_data),
        .data_req   (rom_req),
        .data_addr  (rom_addr),
        .data_rdata (rom_rdata),
        .data_ready (rom_ready)
    );

    // System SRAM (8KB)
    system_sram u_sram (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (sram_req),
        .wr    (sram_wr),
        .addr  (sram_addr),
        .wdata (sram_wdata),
        .wstrb (sram_wstrb),
        .rdata (sram_rdata),
        .ready (sram_ready)
    );

    // VGA Subsystem Ready generation
    wire [7:0] vram_byte_rdata;
    assign vram_rdata = {24'd0, vram_byte_rdata};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vram_ready   <= 1'b0;
            sprite_ready <= 1'b0;
            audio_ready  <= 1'b0;
        end else begin
            vram_ready   <= vram_req && !vram_ready;
            sprite_ready <= sprite_req && !sprite_ready;
            audio_ready  <= audio_req && !audio_ready;
        end
    end

    wire collision_irq;

    // VGA Video Subsystem
    vga_subsystem_top u_vga (
        .clk           (clk),
        .rst_n         (rst_n),

        .vram_cs       (vram_req),
        .vram_wr       (vram_wr),
        .vram_addr     (vram_addr[12:0]),
        .vram_wdata    (vram_wdata[7:0]),
        .vram_rdata    (vram_byte_rdata),

        .spr_psel      (sprite_req),
        .spr_penable   (1'b1),
        .spr_pwrite    (sprite_wr),
        .spr_paddr     (sprite_addr[7:0]),
        .spr_pwdata    (sprite_wdata),
        .spr_prdata    (sprite_rdata),
        .collision_irq (collision_irq),

        .vga_hsync     (core_vga_hsync),
        .vga_vsync     (core_vga_vsync),
        .vga_r         (core_vga_r),
        .vga_g         (core_vga_g),
        .vga_b         (core_vga_b)
    );

    // Chiptune Audio Subsystem
    chiptune_audio u_audio (
        .clk       (clk),
        .rst_n     (rst_n),
        .psel      (audio_req),
        .penable   (1'b1),
        .pwrite    (audio_wr),
        .paddr     (audio_addr[7:0]),
        .pwdata    (audio_wdata),
        .prdata    (audio_rdata),
        .audio_pwm (core_audio_pwm)
    );

    // Gamepad Controller
    wire pad_irq;
    gamepad_controller u_gamepad (
        .clk           (clk),
        .rst_n         (rst_n),
        .req           (gamepad_req),
        .wr            (gamepad_wr),
        .addr          (gamepad_addr),
        .wdata         (gamepad_wdata),
        .rdata         (gamepad_rdata),
        .ready         (gamepad_ready),
        .pad_buttons_n (core_gamepad_btn_n),
        .pad_latch     (),
        .pad_clk       (),
        .pad_data_in   (1'b0),
        .irq           (pad_irq)
    );

    // UART Controller
    wire uart_tx_irq;
    uart_controller u_uart (
        .clk     (clk),
        .rst_n   (rst_n),
        .req     (uart_req),
        .wr      (uart_wr),
        .addr    (uart_addr),
        .wdata   (uart_wdata),
        .rdata   (uart_rdata),
        .ready   (uart_ready),
        .uart_tx (core_uart_tx),
        .uart_rx (core_uart_rx),
        .tx_irq  (uart_tx_irq)
    );

endmodule
