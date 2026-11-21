`ifndef RISCV_DEFINES_VH
`define RISCV_DEFINES_VH

// RISC-V RV32IM Instruction Opcodes (Base 32-bit Integer + M-Extension)
`define OPCODE_R_TYPE       7'b0110011  // ALU Reg-Reg & M-extension (MUL/DIV)
`define OPCODE_I_TYPE       7'b0010011  // ALU Reg-Imm (ADDI, ANDI, etc.)
`define OPCODE_LOAD         7'b0000011  // LW, LH, LB, LBU, LHU
`define OPCODE_STORE        7'b0100011  // SW, SH, SB
`define OPCODE_BRANCH       7'b1100011  // BEQ, BNE, BLT, BGE, BLTU, BGEU
`define OPCODE_JAL          7'b1101111  // Jump and Link
`define OPCODE_JALR         7'b1100111  // Jump and Link Register
`define OPCODE_LUI          7'b0110111  // Load Upper Immediate
`define OPCODE_AUIPC        7'b0010111  // Add Upper Immediate to PC
`define OPCODE_SYSTEM       7'b1110011  // ECALL, EBREAK, CSR

// ALU Operation Codes
`define ALU_ADD             4'b0000
`define ALU_SUB             4'b0001
`define ALU_SLL             4'b0010
`define ALU_SLT             4'b0011
`define ALU_SLTU            4'b0100
`define ALU_XOR             4'b0101
`define ALU_SRL             4'b0110
`define ALU_SRA             4'b0111
`define ALU_OR              4'b1000
`define ALU_AND             4'b1001

// M-Extension Operations (funct7 == 7'b0000001 with OPCODE_R_TYPE)
`define M_OP_MUL            3'b000
`define M_OP_MULH           3'b001
`define M_OP_MULHSU         3'b010
`define M_OP_MULHU          3'b011
`define M_OP_DIV            3'b100
`define M_OP_DIVU           3'b101
`define M_OP_REM            3'b110
`define M_OP_REMU           3'b111

`endif // RISCV_DEFINES_VH
