
package cpu_pkg;

    // ALU operations
    parameter logic [3:0]
        ALU_ADD   = 4'd0,
        ALU_SUB   = 4'd1,
        ALU_AND   = 4'd2,
        ALU_OR    = 4'd3,
        ALU_XOR   = 4'd4,
        ALU_SLL   = 4'd5,
        ALU_SRL   = 4'd6,
        ALU_SRA   = 4'd7,
        ALU_SLT   = 4'd8,
        ALU_SLTU  = 4'd9,
        ALU_PASSB = 4'd10;

    // Immediate types
    parameter logic [2:0]
        IMM_I = 3'd0,
        IMM_S = 3'd1,
        IMM_B = 3'd2,
        IMM_U = 3'd3,
        IMM_J = 3'd4;

    // Writeback selection
    parameter logic [1:0]
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC4 = 2'd2;

    // Opcodes
    parameter logic [6:0]
        OP_R     = 7'b0110011,
        OP_I     = 7'b0010011,
        OP_LOAD  = 7'b0000011,
        OP_STORE = 7'b0100011,
        OP_BRANCH= 7'b1100011,
        OP_JAL   = 7'b1101111,
        OP_JALR  = 7'b1100111,
        OP_LUI   = 7'b0110111,
        OP_AUIPC = 7'b0010111;

endpackage
