// =============================================================================
// File: system_sram.v
// Module: system_sram
// Project: RetroPlay VGA Gaming SoC
// Description: 8KB Synchronous Static RAM with byte-level write enables.
// =============================================================================

`timescale 1ns / 1ps

module system_sram #(
    parameter MEM_DEPTH = 2048 // 8KB
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        req,
    input  wire        wr,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg  [31:0] rdata,
    output reg         ready
);

    reg [31:0] mem [0:MEM_DEPTH-1];
    wire [10:0] word_addr = addr[12:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 32'd0;
            ready <= 1'b0;
        end else begin
            if (req && !ready) begin
                if (wr) begin
                    if (wstrb[0]) mem[word_addr][7:0]   <= wdata[7:0];
                    if (wstrb[1]) mem[word_addr][15:8]  <= wdata[15:8];
                    if (wstrb[2]) mem[word_addr][23:16] <= wdata[23:16];
                    if (wstrb[3]) mem[word_addr][31:24] <= wdata[31:24];
                end else begin
                    rdata <= mem[word_addr];
                end
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end
        end
    end

endmodule
