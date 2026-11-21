// =============================================================================
// Project: Aether-AI Edge SoC
// File:    alu_mul_div.v
// Description: RV32M Hardware Multiplication and Division Extension Coprocessor
// =============================================================================

`timescale 1ns / 1ps
`include "riscv_defines.vh"

module alu_mul_div (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [2:0]  funct3,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    output reg  [31:0] result,
    output reg         ready
);

    wire signed [31:0] s_op_a = operand_a;
    wire signed [31:0] s_op_b = operand_b;

    // Full 64-bit products for signed and unsigned multiplications
    wire signed [63:0] prod_ss  = s_op_a * s_op_b;
    wire signed [63:0] prod_su  = s_op_a * $signed({1'b0, operand_b});
    wire        [63:0] prod_uu  = operand_a * operand_b;

    // 1-cycle pipelined multiplication & division unit
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            ready  <= 1'b0;
        end else if (start) begin
            ready <= 1'b1;
            case (funct3)
                `M_OP_MUL:    result <= prod_ss[31:0];
                `M_OP_MULH:   result <= prod_ss[63:32];
                `M_OP_MULHSU: result <= prod_su[63:32];
                `M_OP_MULHU:  result <= prod_uu[63:32];
                `M_OP_DIV:    result <= (operand_b == 32'd0) ? -32'd1 : (s_op_a / s_op_b);
                `M_OP_DIVU:   result <= (operand_b == 32'd0) ? 32'hFFFFFFFF : (operand_a / operand_b);
                `M_OP_REM:    result <= (operand_b == 32'd0) ? operand_a : (s_op_a % s_op_b);
                `M_OP_REMU:   result <= (operand_b == 32'd0) ? operand_a : (operand_a % operand_b);
                default:      result <= 32'd0;
            endcase
        end else begin
            ready <= 1'b0;
        end
    end

endmodule
