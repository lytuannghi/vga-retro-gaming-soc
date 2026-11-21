// =============================================================================
// Project: RetroPlay Gaming SoC
// File:    sprite_engine.v
// Description: 8-Channel Hardware Sprite Engine with Real-Time Collision Detection
//              Each sprite has X, Y coordinates, size, color, and visibility
// =============================================================================

`timescale 1ns / 1ps

module sprite_engine (
    input  wire        clk,
    input  wire        rst_n,

    // Video Beam Coordinates
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        video_active,

    // APB Sprite Configuration Bus
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [7:0]  paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,

    // Sprite Output Color (8-bit: R3:G3:B2)
    output reg         sprite_hit,
    output reg  [7:0]  sprite_color,

    // Real-Time Hardware Collision Flag (e.g. Sprite 0 hit Sprite 1)
    output reg         collision_irq
);

    // 8 Sprites: 16x16 pixels each
    reg [9:0] spr_x     [0:7];
    reg [9:0] spr_y     [0:7];
    reg [7:0] spr_color [0:7];
    reg       spr_en    [0:7];

    integer i;

    // Sprite Match Logic
    wire [7:0] in_sprite;
    genvar s;
    generate
        for (s = 0; s < 8; s = s + 1) begin : GEN_SPR
            assign in_sprite[s] = spr_en[s] && video_active &&
                                  (pixel_x >= spr_x[s]) && (pixel_x < (spr_x[s] + 10'd16)) &&
                                  (pixel_y >= spr_y[s]) && (pixel_y < (spr_y[s] + 10'd16));
        end
    endgenerate

    // Hardware Collision Detection (Sprite 0 vs Sprite 1..7)
    wire coll_detected = in_sprite[0] && (|in_sprite[7:1]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            collision_irq <= 1'b0;
            sprite_hit    <= 1'b0;
            sprite_color  <= 8'd0;
        end else begin
            if (coll_detected) collision_irq <= 1'b1;

            // Priority sprite rendering (Sprite 0 has highest priority)
            if (in_sprite[0]) begin
                sprite_hit   <= 1'b1;
                sprite_color <= spr_color[0];
            end else if (in_sprite[1]) begin
                sprite_hit   <= 1'b1;
                sprite_color <= spr_color[1];
            end else if (in_sprite[2]) begin
                sprite_hit   <= 1'b1;
                sprite_color <= spr_color[2];
            end else if (in_sprite[3]) begin
                sprite_hit   <= 1'b1;
                sprite_color <= spr_color[3];
            end else begin
                sprite_hit   <= 1'b0;
                sprite_color <= 8'd0;
            end
        end
    end

    // APB Register Interface:
    // 0x00 - 0x1C: Sprite 0..7 Position {16'd0, Y[7:0], X[7:0]}
    // 0x20 - 0x3C: Sprite 0..7 Config {23'd0, EN, COLOR[7:0]}
    // 0x40: COLLISION_STATUS (Read/Clear)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                spr_x[i]     <= 10'd0;
                spr_y[i]     <= 10'd0;
                spr_color[i] <= 8'hE0; // Default Red
                spr_en[i]    <= 1'b0;
            end
            prdata <= 32'd0;
        end else if (psel && penable) begin
            if (pwrite) begin
                if (paddr >= 8'h00 && paddr < 8'h20) begin
                    spr_x[paddr[4:2]] <= {2'b00, pwdata[7:0]};
                    spr_y[paddr[4:2]] <= {2'b00, pwdata[15:8]};
                end else if (paddr >= 8'h20 && paddr < 8'h40) begin
                    spr_color[(paddr - 8'h20) >> 2] <= pwdata[7:0];
                    spr_en[(paddr - 8'h20) >> 2]    <= pwdata[8];
                end else if (paddr == 8'h40) begin
                    collision_irq <= 1'b0; // Clear collision
                end
            end else begin
                case (paddr)
                    8'h40: prdata <= {31'd0, collision_irq};
                    default: prdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
