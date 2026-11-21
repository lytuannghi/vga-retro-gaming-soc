// =============================================================================
// Project: Aether-AI Edge SoC
// File:    riscv_regfile.v
// Description: Dual-Read Single-Write 32x32-bit Register File (x0 hardwired to 0)
// =============================================================================

`timescale 1ns / 1ps

module riscv_regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    input  wire        wr_en,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data
);

    reg [31:0] registers [0:31];
    integer i;

    // Asynchronous Read (Internal Forwarding for zero latency)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                      (wr_en && rd_addr == rs1_addr) ? rd_data : registers[rs1_addr];

    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                      (wr_en && rd_addr == rs2_addr) ? rd_data : registers[rs2_addr];

    // Synchronous Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (wr_en && (rd_addr != 5'd0)) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule
