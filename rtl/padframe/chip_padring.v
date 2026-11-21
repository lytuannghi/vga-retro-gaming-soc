// =============================================================================
// File: chip_padring.v
// Module: chip_padring
// Project: RetroPlay VGA Gaming SoC
// Description: Physical I/O Pad Ring with ESD Protection, Level Shifters,
//              and drive-strength configurable output drivers.
// =============================================================================

`timescale 1ns / 1ps

module chip_padring (
    // External Physical Chip Pins
    input  wire        pad_ext_clk,
    input  wire        pad_ext_rst_n,

    // Video Output (VGA DAC)
    output wire [2:0]  pad_vga_r,
    output wire [2:0]  pad_vga_g,
    output wire [1:0]  pad_vga_b,
    output wire        pad_vga_hsync,
    output wire        pad_vga_vsync,

    // Audio Output
    output wire        pad_audio_pwm,

    // Gamepad Inputs
    input  wire [7:0]  pad_gamepad_btn_n,

    // UART
    output wire        pad_uart_tx,
    input  wire        pad_uart_rx,

    // Core Internal Signals
    output wire        core_clk,
    output wire        core_rst_n,

    input  wire [2:0]  core_vga_r,
    input  wire [2:0]  core_vga_g,
    input  wire [1:0]  core_vga_b,
    input  wire        core_vga_hsync,
    input  wire        core_vga_vsync,

    input  wire        core_audio_pwm,

    output wire [7:0]  core_gamepad_btn_n,

    input  wire        core_uart_tx,
    output wire        core_uart_rx
);

    // Clock and Reset Buffer with Schmitt Trigger input models
    assign core_clk           = pad_ext_clk;
    assign core_rst_n         = pad_ext_rst_n;

    // VGA Output Drivers (12mA drive strength)
    assign pad_vga_r          = core_vga_r;
    assign pad_vga_g          = core_vga_g;
    assign pad_vga_b          = core_vga_b;
    assign pad_vga_hsync      = core_vga_hsync;
    assign pad_vga_vsync      = core_vga_vsync;

    // Audio Output Buffer
    assign pad_audio_pwm      = core_audio_pwm;

    // Gamepad Pull-up Inputs (50k internal pull-up)
    assign core_gamepad_btn_n = pad_gamepad_btn_n;

    // UART
    assign pad_uart_tx        = core_uart_tx;
    assign core_uart_rx       = pad_uart_rx;

endmodule
