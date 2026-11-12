module decoder (
    input  logic [31:0] instr,

    output logic [3:0] alu_op,
    output logic [2:0] imm_type,
    output logic       alu_src,
    output logic       alu_a_sel,
    output logic       reg_write,
    output logic       mem_read,
    output logic       mem_write,
    output logic [1:0] mem_size,
    output logic       mem_unsigned,
    output logic [1:0] wb_sel,
    output logic       branch,
    output logic       jump,
    output logic       jalr,
    output logic       valid
);

    import cpu_pkg::*;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always_comb begin

        alu_op       = ALU_ADD;
        imm_type     = IMM_I;
        alu_src      = 1'b0;
        alu_a_sel    = 1'b0;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_size     = 2'b10;
        mem_unsigned = 1'b0;
        wb_sel       = WB_ALU;
        branch       = 1'b0;
        jump         = 1'b0;
        jalr         = 1'b0;
        valid        = 1'b1;

        case (opcode)
            OP_R: begin   //RTYPE
                reg_write = 1'b1;
                alu_src = 1'b0;

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SUB;
                        else
                            valid = 1'b0;
                    end

                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                        else
                            valid = 1'b0;
                    end

                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;

                    default: valid = 1'b0;
                endcase

                if (funct3 != 3'b000 && funct3 != 3'b101 &&
                    funct7 != 7'b0000000)
                    valid = 1'b0;
            end
            OP_I: begin   //ITYPE
                reg_write = 1'b1;
                alu_src = 1'b1;
                imm_type = IMM_I;

                case (funct3)
                    3'b000: alu_op = ALU_ADD;  // ADDI
                    3'b010: alu_op = ALU_SLT;  // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b100: alu_op = ALU_XOR;  // XORI
                    3'b110: alu_op = ALU_OR;   // ORI
                    3'b111: alu_op = ALU_AND;  // ANDI

                    3'b001: begin               // SLLI
                        alu_op = ALU_SLL;
                        if (funct7 != 7'b0000000)
                            valid = 1'b0;
                    end

                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;  // SRLI
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;  // SRAI
                        else
                            valid = 1'b0;
                    end

                    default: valid = 1'b0;
                endcase
            end
            OP_LOAD: begin   //LOAD INSTRUCTION
                alu_op = ALU_ADD;
                alu_src = 1'b1;
                imm_type = IMM_I;

                reg_write = 1'b1;
                mem_read = 1'b1;
                wb_sel = WB_MEM;

                case (funct3)
                    3'b000: begin // LB
                        mem_size = 2'b00;
                    end
                    3'b001: begin // LH
                        mem_size = 2'b01;
                    end
                    3'b010: begin // LW
                        mem_size = 2'b10;
                    end
                    3'b100: begin // LBU
                        mem_size = 2'b00;
                        mem_unsigned = 1'b1;
                    end
                    3'b101: begin // LHU
                        mem_size = 2'b01;
                        mem_unsigned = 1'b1;
                    end
                    default: valid = 1'b0;
                endcase
            end
            OP_STORE: begin //STORE INSTRUCTION
                alu_op = ALU_ADD;
                alu_src = 1'b1;
                imm_type = IMM_S;
                mem_write = 1'b1;

                case (funct3)
                    3'b000: mem_size = 2'b00; // SB
                    3'b001: mem_size = 2'b01; // SH
                    3'b010: mem_size = 2'b10; // SW
                    default: valid = 1'b0;
                endcase
            end
            OP_BRANCH: begin //BRANCH
                branch = 1'b1;
                imm_type = IMM_B;

                case (funct3)
                    3'b000, 3'b001,
                    3'b100, 3'b101,
                    3'b110, 3'b111: begin
                        // Comparator uses funct3 directly
                    end
                    default: valid = 1'b0;
                endcase
            end
            OP_JAL: begin //JUMP AND LINK
                jump = 1'b1;
                reg_write = 1'b1;
                imm_type = IMM_J;
                wb_sel = WB_PC4;
            end
            OP_JALR: begin //JUMP VIA REGISTER
                if (funct3 == 3'b000) begin
                    jump = 1'b1;
                    jalr = 1'b1;
                    reg_write = 1'b1;
                    imm_type = IMM_I;
                    wb_sel = WB_PC4;
                    alu_op = ALU_ADD;
                    alu_src = 1'b1;
                end
                else
                    valid = 1'b0;
            end

            OP_LUI: begin //LOAD UPPER IMMEDIATE
                imm_type = IMM_U;
                alu_op = ALU_PASSB;
                alu_src = 1'b1;
                reg_write = 1'b1;
            end

            OP_AUIPC: begin //UPPER IMMEDIATE TO PC
                imm_type = IMM_U;
                alu_op = ALU_ADD;
                alu_a_sel = 1'b1;
                alu_src = 1'b1;
                reg_write = 1'b1;
            end

            default: valid = 1'b0;

        endcase

        // Disable state-changing controls
        // for unsupported instruction encodings.
        if (!valid) begin
            reg_write = 1'b0;
            mem_read = 1'b0;
            mem_write = 1'b0;
            branch = 1'b0;
            jump = 1'b0;
            jalr = 1'b0;
        end

    end

endmodule
