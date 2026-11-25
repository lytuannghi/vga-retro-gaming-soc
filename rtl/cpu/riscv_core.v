// =============================================================================
// Project: Aether-AI Edge SoC
// File:    riscv_core.v
// Description: Synthesizable 32-bit RV32IM Pipelined Processor Core
// =============================================================================

`timescale 1ns / 1ps
`include "riscv_defines.vh"

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Memory Bus
    output reg  [31:0] instr_addr,
    input  wire [31:0] instr_data,

    // Data Memory Bus (AXI4-Lite Master Interface)
    output reg         data_req,
    output reg         data_wr,
    output reg  [31:0] data_addr,
    output reg  [31:0] data_wdata,
    output reg  [3:0]  data_wstrb,
    input  wire [31:0] data_rdata,
    input  wire        data_ready,

    // Core Control / Status
    output wire [31:0] curr_pc
);

    // Program Counter and Pipeline Registers
    reg [31:0] pc;
    assign curr_pc = pc;

    // Decode Signals
    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd     = instr_data[11:7];
    wire [2:0] funct3 = instr_data[14:12];
    wire [4:0] rs1    = instr_data[19:15];
    wire [4:0] rs2    = instr_data[24:20];
    wire [6:0] funct7 = instr_data[31:25];

    // Immediate Decoding
    wire [31:0] imm_i = {{20{instr_data[31]}}, instr_data[31:20]};
    wire [31:0] imm_s = {{20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]};
    wire [31:0] imm_b = {{19{instr_data[31]}}, instr_data[31], instr_data[7], instr_data[30:25], instr_data[11:8], 1'b0};
    wire [31:0] imm_u = {instr_data[31:12], 12'd0};
    wire [31:0] imm_j = {{11{instr_data[31]}}, instr_data[31], instr_data[19:12], instr_data[20], instr_data[30:21], 1'b0};

    // Register File Signals
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    reg         reg_wr_en;
    reg  [31:0] reg_wr_data;

    riscv_regfile u_regfile (
        .clk     (clk),
        .rst_n   (rst_n),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .wr_en   (reg_wr_en),
        .rd_addr (rd),
        .rd_data (reg_wr_data)
    );

    // ALU Signals & Combinational Control
    wire [31:0] alu_in_a = rs1_data;
    wire [31:0] alu_in_b = (opcode == `OPCODE_I_TYPE) ? imm_i : rs2_data;
    reg  [3:0]  alu_ctrl;
    wire [31:0] alu_result;
    wire        alu_zero;

    always @(*) begin
        case (opcode)
            `OPCODE_I_TYPE: begin
                case (funct3)
                    3'b000: alu_ctrl = `ALU_ADD;
                    3'b010: alu_ctrl = `ALU_SLT;
                    3'b011: alu_ctrl = `ALU_SLTU;
                    3'b100: alu_ctrl = `ALU_XOR;
                    3'b110: alu_ctrl = `ALU_OR;
                    3'b111: alu_ctrl = `ALU_AND;
                    3'b001: alu_ctrl = `ALU_SLL;
                    3'b101: alu_ctrl = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    default: alu_ctrl = `ALU_ADD;
                endcase
            end
            `OPCODE_R_TYPE: begin
                case (funct3)
                    3'b000: alu_ctrl = funct7[5] ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_ctrl = `ALU_SLL;
                    3'b010: alu_ctrl = `ALU_SLT;
                    3'b011: alu_ctrl = `ALU_SLTU;
                    3'b100: alu_ctrl = `ALU_XOR;
                    3'b101: alu_ctrl = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_ctrl = `ALU_OR;
                    3'b111: alu_ctrl = `ALU_AND;
                    default: alu_ctrl = `ALU_ADD;
                endcase
            end
            default: alu_ctrl = `ALU_ADD;
        endcase
    end

    riscv_alu u_alu (
        .alu_op   (alu_ctrl),
        .operand_a(alu_in_a),
        .operand_b(alu_in_b),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // Multi-cycle execution FSM: FETCH -> EXECUTE -> MEM_WAIT / M_WAIT
    localparam S_FETCH    = 2'b00;
    localparam S_EXEC     = 2'b01;
    localparam S_MEM_WAIT = 2'b10;
    localparam S_M_WAIT   = 2'b11;

    reg [1:0] state;

    // Hardware Multiplier / Divider (M-Extension)
    wire is_m_extension = (opcode == `OPCODE_R_TYPE) && (funct7 == 7'b0000001);
    wire mul_div_start  = (state == S_EXEC) && is_m_extension;
    wire [31:0] mul_div_result;
    wire        mul_div_ready;

    alu_mul_div u_mul_div (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (mul_div_start),
        .funct3   (funct3),
        .operand_a(rs1_data),
        .operand_b(rs2_data),
        .result   (mul_div_result),
        .ready    (mul_div_ready)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc         <= 32'h00000000;
            instr_addr <= 32'h00000000;
            state      <= S_FETCH;
            data_req   <= 1'b0;
            data_wr    <= 1'b0;
            data_addr  <= 32'd0;
            data_wdata <= 32'd0;
            data_wstrb <= 4'b0000;
            reg_wr_en  <= 1'b0;
            reg_wr_data<= 32'd0;
        end else begin
            case (state)
                S_FETCH: begin
                    reg_wr_en  <= 1'b0;
                    data_req   <= 1'b0;
                    instr_addr <= pc;
                    state      <= S_EXEC;
                end

                S_EXEC: begin
                    case (opcode)
                        `OPCODE_LUI: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= imm_u;
                            pc          <= pc + 4;
                            state       <= S_FETCH;
                        end

                        `OPCODE_AUIPC: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= pc + imm_u;
                            pc          <= pc + 4;
                            state       <= S_FETCH;
                        end

                        `OPCODE_JAL: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= pc + 4;
                            pc          <= pc + imm_j;
                            state       <= S_FETCH;
                        end

                        `OPCODE_JALR: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= pc + 4;
                            pc          <= (rs1_data + imm_i) & ~32'd1;
                            state       <= S_FETCH;
                        end

                        `OPCODE_BRANCH: begin
                            case (funct3)
                                3'b000: pc <= (rs1_data == rs2_data) ? pc + imm_b : pc + 4; // BEQ
                                3'b001: pc <= (rs1_data != rs2_data) ? pc + imm_b : pc + 4; // BNE
                                3'b100: pc <= ($signed(rs1_data) < $signed(rs2_data)) ? pc + imm_b : pc + 4; // BLT
                                3'b101: pc <= ($signed(rs1_data) >= $signed(rs2_data)) ? pc + imm_b : pc + 4; // BGE
                                3'b110: pc <= (rs1_data < rs2_data) ? pc + imm_b : pc + 4; // BLTU
                                3'b111: pc <= (rs1_data >= rs2_data) ? pc + imm_b : pc + 4; // BGEU
                                default: pc <= pc + 4;
                            endcase
                            state <= S_FETCH;
                        end

                        `OPCODE_I_TYPE: begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= alu_result;
                            pc          <= pc + 4;
                            state       <= S_FETCH;
                        end

                        `OPCODE_R_TYPE: begin
                            if (is_m_extension) begin
                                state <= S_M_WAIT;
                            end else begin
                                reg_wr_en   <= 1'b1;
                                reg_wr_data <= alu_result;
                                pc          <= pc + 4;
                                state       <= S_FETCH;
                            end
                        end

                        `OPCODE_LOAD: begin
                            data_req   <= 1'b1;
                            data_wr    <= 1'b0;
                            data_addr  <= rs1_data + imm_i;
                            state      <= S_MEM_WAIT;
                        end

                        `OPCODE_STORE: begin
                            data_req   <= 1'b1;
                            data_wr    <= 1'b1;
                            data_addr  <= rs1_data + imm_s;
                            data_wdata <= rs2_data;
                            data_wstrb <= (funct3 == 3'b000) ? 4'b0001 : // SB
                                          (funct3 == 3'b001) ? 4'b0011 : // SH
                                                               4'b1111;  // SW
                            state      <= S_MEM_WAIT;
                        end

                        default: begin
                            pc    <= pc + 4;
                            state <= S_FETCH;
                        end
                    endcase
                end

                S_MEM_WAIT: begin
                    if (data_ready) begin
                        data_req <= 1'b0;
                        data_wr  <= 1'b0;
                        if (opcode == `OPCODE_LOAD) begin
                            reg_wr_en   <= 1'b1;
                            reg_wr_data <= data_rdata;
                        end
                        pc    <= pc + 4;
                        state <= S_FETCH;
                    end
                end

                S_M_WAIT: begin
                    if (mul_div_ready) begin
                        reg_wr_en   <= 1'b1;
                        reg_wr_data <= mul_div_result;
                        pc          <= pc + 4;
                        state       <= S_FETCH;
                    end
                end
            endcase
        end
    end

endmodule
