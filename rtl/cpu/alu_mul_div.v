// =============================================================================
// File:    alu_mul_div.v
// Description: Synthesizable RV32M Hardware Multiplier & 32-Cycle Restoring
//              Divider Coprocessor (0 combinational / or % operators).
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

    wire signed [63:0] prod_ss  = s_op_a * s_op_b;
    wire signed [63:0] prod_su  = s_op_a * $signed({1'b0, operand_b});
    wire        [63:0] prod_uu  = operand_a * operand_b;

    localparam S_IDLE = 1'b0;
    localparam S_DIV  = 1'b1;

    reg        div_state;
    reg [2:0]  div_funct3;
    reg [4:0]  bit_cnt;
    reg        quot_neg;
    reg        rem_neg;
    reg [31:0] abs_divisor;
    reg [31:0] quot_reg;
    reg [32:0] rem_reg;

    wire is_div_op = funct3[2];
    wire is_signed = !funct3[0];
    wire a_neg     = is_signed && operand_a[31];
    wire b_neg     = is_signed && operand_b[31];
    wire [31:0] a_mag = a_neg ? (~operand_a + 32'd1) : operand_a;
    wire [31:0] b_mag = b_neg ? (~operand_b + 32'd1) : operand_b;

    wire [32:0] shifted_rem = {rem_reg[31:0], quot_reg[31]};
    wire [32:0] div_ext     = {1'b0, abs_divisor};
    wire        sub_ok      = (shifted_rem >= div_ext);
    wire [32:0] next_rem    = sub_ok ? (shifted_rem - div_ext) : shifted_rem;
    wire [31:0] next_quot   = {quot_reg[30:0], sub_ok ? 1'b1 : 1'b0};

    wire [31:0] signed_quot = quot_neg ? (~next_quot + 32'd1) : next_quot;
    wire [31:0] signed_rem  = rem_neg  ? (~next_rem[31:0] + 32'd1) : next_rem[31:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result      <= 32'd0;
            ready       <= 1'b0;
            div_state   <= S_IDLE;
            div_funct3  <= 3'd0;
            bit_cnt     <= 5'd0;
            quot_neg    <= 1'b0;
            rem_neg     <= 1'b0;
            abs_divisor <= 32'd0;
            quot_reg    <= 32'd0;
            rem_reg     <= 33'd0;
        end else begin
            ready <= 1'b0;
            case (div_state)
                S_IDLE: begin
                    if (start) begin
                        if (!is_div_op) begin
                            ready <= 1'b1;
                            case (funct3)
                                `M_OP_MUL:    result <= prod_ss[31:0];
                                `M_OP_MULH:   result <= prod_ss[63:32];
                                `M_OP_MULHSU: result <= prod_su[63:32];
                                `M_OP_MULHU:  result <= prod_uu[63:32];
                                default:      result <= 32'd0;
                            endcase
                        end else if (operand_b == 32'd0) begin
                            ready <= 1'b1;
                            if (funct3[1]) begin
                                result <= operand_a;
                            end else begin
                                result <= 32'hFFFFFFFF;
                            end
                        end else begin
                            div_state   <= S_DIV;
                            div_funct3  <= funct3;
                            bit_cnt     <= 5'd0;
                            quot_neg    <= a_neg ^ b_neg;
                            rem_neg     <= a_neg;
                            abs_divisor <= b_mag;
                            quot_reg    <= a_mag;
                            rem_reg     <= 33'd0;
                        end
                    end
                end

                S_DIV: begin
                    rem_reg  <= next_rem;
                    quot_reg <= next_quot;
                    if (bit_cnt == 5'd31) begin
                        div_state <= S_IDLE;
                        ready     <= 1'b1;
                        case (div_funct3)
                            `M_OP_DIV, `M_OP_DIVU: result <= signed_quot;
                            `M_OP_REM, `M_OP_REMU: result <= signed_rem;
                            default:               result <= 32'd0;
                        endcase
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
