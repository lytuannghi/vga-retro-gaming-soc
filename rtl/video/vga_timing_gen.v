// =============================================================================
// Project: RetroPlay Gaming SoC
// File:    vga_timing_gen.v
// Description: Standard Industry 640x480 @ 60Hz VGA Timing Generator
//              Pixel Clock = 25.175 MHz (Derived from 100MHz system clock / 4)
//              Horizontal: Visible 640, Front Porch 16, Sync 96, Back Porch 48 -> Total 800
//              Vertical:   Visible 480, Front Porch 10, Sync 2,  Back Porch 33 -> Total 525
// =============================================================================

`timescale 1ns / 1ps

module vga_timing_gen (
    input  wire        clk,          // 100 MHz Master System Clock
    input  wire        rst_n,

    output reg         pixel_tick,   // 25.0 MHz Pixel Clock Enable
    output reg  [9:0]  pixel_x,      // 0 .. 639
    output reg  [9:0]  pixel_y,      // 0 .. 479
    output reg         hsync,        // Active Low Horizontal Sync
    output reg         vsync,        // Active Low Vertical Sync
    output wire        video_active  // High when inside 640x480 visible area
);

    // 100MHz to 25MHz Clock Divider (Divide by 4)
    reg [1:0] div_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt    <= 2'b00;
            pixel_tick <= 1'b0;
        end else begin
            div_cnt    <= div_cnt + 1'b1;
            pixel_tick <= (div_cnt == 2'b11);
        end
    end

    // VGA Timing Parameters
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // Horizontal & Vertical Beam Counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt   <= 10'd0;
            v_cnt   <= 10'd0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
            hsync   <= 1'b1;
            vsync   <= 1'b1;
        end else if (pixel_tick) begin
            // Horizontal Counter
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                // Vertical Counter
                if (v_cnt == V_TOTAL - 1) begin
                    v_cnt <= 10'd0;
                end else begin
                    v_cnt <= v_cnt + 1'b1;
                end
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end

            // Coordinate generation
            pixel_x <= (h_cnt < H_VISIBLE) ? h_cnt : 10'd0;
            pixel_y <= (v_cnt < V_VISIBLE) ? v_cnt : 10'd0;

            // Sync pulse generation (Active Low)
            hsync <= ~((h_cnt >= (H_VISIBLE + H_FRONT)) && (h_cnt < (H_VISIBLE + H_FRONT + H_SYNC)));
            vsync <= ~((v_cnt >= (V_VISIBLE + V_FRONT)) && (v_cnt < (V_VISIBLE + V_FRONT + V_SYNC)));
        end
    end

    assign video_active = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

endmodule
