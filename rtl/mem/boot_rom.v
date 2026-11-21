// =============================================================================
// File: boot_rom.v
// Module: boot_rom
// Project: RetroPlay VGA Gaming SoC
// Description: 8KB Boot ROM (2048 x 32-bit) with combinational instruction
//              fetch and memory-mapped bus access.
// =============================================================================

`timescale 1ns / 1ps

module boot_rom #(
    parameter MEM_DEPTH = 2048 // 8KB
)(
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Port (Read Only, Combinational)
    input  wire [31:0] instr_addr,
    output wire [31:0] instr_data,

    // Data Port (Bus Read Only)
    input  wire        data_req,
    input  wire [31:0] data_addr,
    output reg  [31:0] data_rdata,
    output reg         data_ready
);

    reg [31:0] mem [0:MEM_DEPTH-1];

    // Word addresses
    wire [10:0] i_word_addr = instr_addr[12:2];
    wire [10:0] d_word_addr = data_addr[12:2];

    // Combinational instruction output
    assign instr_data = mem[i_word_addr];

    // Bus Data Read Port (1 cycle acknowledge)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_rdata <= 32'd0;
            data_ready <= 1'b0;
        end else begin
            if (data_req && !data_ready) begin
                data_rdata <= mem[d_word_addr];
                data_ready <= 1'b1;
            end else begin
                data_ready <= 1'b0;
            end
        end
    end

    // Initial load from hex if present
    initial begin
        // default NOPs
        integer i;
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            mem[i] = 32'h00000013; // nop (addi x0, x0, 0)
        end
        $readmemh("boot_rom.hex", mem);
    end

endmodule
