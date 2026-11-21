// =============================================================================
// Project: RetroPlay Gaming SoC
// File:    vga_subsystem_top.v
// Description: Complete VGA Video Subsystem
//              Integrates Timing Generator, Dual-Port VRAM, Sprite Engine, and DAC
// =============================================================================

`timescale 1ns / 1ps

module vga_subsystem_top (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Bus Access to Video RAM (Port A)
    input  wire        vram_cs,
    input  wire        vram_wr,
    input  wire [12:0] vram_addr,
    input  wire [7:0]  vram_wdata,
    output wire [7:0]  vram_rdata,

    // Sprite Engine APB Config
    input  wire        spr_psel,
    input  wire        spr_penable,
    input  wire        spr_pwrite,
    input  wire [7:0]  spr_paddr,
    input  wire [31:0] spr_pwdata,
    output wire [31:0] spr_prdata,
    output wire        collision_irq,

    // Physical VGA Output Pins
    output wire        vga_hsync,
    output wire        vga_vsync,
    output reg  [2:0]  vga_r,
    output reg  [2:0]  vga_g,
    output reg  [1:0]  vga_b
);

    wire       pixel_tick;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_active;

    vga_timing_gen u_timing (
        .clk         (clk),
        .rst_n       (rst_n),
        .pixel_tick  (pixel_tick),
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y),
        .hsync       (vga_hsync),
        .vsync       (vga_vsync),
        .video_active(video_active)
    );

    // Dual-Port Video RAM (4096 bytes = 80x60 text/tile buffer)
    reg [7:0] vram_mem [0:4095];
    wire [11:0] beam_addr = (pixel_y[9:3] * 80) + pixel_x[9:3];
    reg [7:0]   bg_tile_code;

    // Port A (CPU Write/Read)
    always @(posedge clk) begin
        if (vram_cs && vram_wr) begin
            vram_mem[vram_addr[11:0]] <= vram_wdata;
        end
    end
    assign vram_rdata = vram_cs ? vram_mem[vram_addr[11:0]] : 8'd0;

    // Port B (VGA Beam Read)
    always @(posedge clk) begin
        if (pixel_tick) begin
            bg_tile_code <= vram_mem[beam_addr];
        end
    end

    // Sprite Engine
    wire       sprite_hit;
    wire [7:0] sprite_color;

    sprite_engine u_sprites (
        .clk          (clk),
        .rst_n        (rst_n),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .video_active (video_active),
        .psel         (spr_psel),
        .penable      (spr_penable),
        .pwrite       (spr_pwrite),
        .paddr        (spr_paddr),
        .pwdata       (spr_pwdata),
        .prdata       (spr_prdata),
        .sprite_hit   (sprite_hit),
        .sprite_color (sprite_color),
        .collision_irq(collision_irq)
    );

    // Color Multiplexer (Sprite over Background Tile)
    wire [7:0] final_pixel = (!video_active) ? 8'h00 :
                             (sprite_hit)    ? sprite_color :
                             (bg_tile_code == 8'h00) ? 8'h03 : // Dark Blue Background
                             8'h1C; // Green ground/tiles

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 3'b000;
            vga_g <= 3'b000;
            vga_b <= 2'b00;
        end else if (pixel_tick) begin
            vga_r <= final_pixel[7:5];
            vga_g <= final_pixel[4:2];
            vga_b <= final_pixel[1:0];
        end
    end

endmodule
