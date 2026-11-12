module decoder_tb;
    import cpu_pkg::*;

    logic [31:0] instr;
    logic [3:0] alu_op;
    logic [2:0] imm_type;
    logic alu_src, alu_a_sel;
    logic reg_write, mem_read, mem_write;
    logic [1:0] mem_size;
    logic mem_unsigned;
    logic [1:0] wb_sel;
    logic branch, jump, jalr, valid;
    decoder dut(
        .instr(instr),
        .alu_op(alu_op),
        .imm_type(imm_type),
        .alu_src(alu_src),
        .alu_a_sel(alu_a_sel),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_size(mem_size),
        .mem_unsigned(mem_unsigned),
        .wb_sel(wb_sel),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .valid(valid)
    );
    initial begin
        //ADDING x3 <- x1 x2
        instr = 32'h002081B3;
        #1;
        if(alu_op != ALU_ADD || alu_src !=1'b0 || reg_write !=1'b1 || valid!=1'b1)
            $fatal(1,"ADDITION FAILED");
        $display("PASS: ADDITION PASSED");
        instr = 32'h402081B3;
        #1;
        //SUBTRACTIOn
        if(alu_op!=ALU_SUB||alu_src!=1'b0||reg_write!=1'b1||valid!=1'b1)
            $fatal(1,"SUBTRACTION FAILED");
        $display("PASS: SUBTRACTION PASSED");
        //ADDING WITH IMMEDIATE VALUE
        instr = 32'h00A10093;
        #1;
        if(alu_op!=ALU_ADD||alu_src!=1'b1||reg_write !=1'b1||valid!=1'b1||imm_type!=IMM_I)
            $fatal(1, "ADDI FAILED");
        $display("PASS: ADDI PASSED");
        //STORING
        instr = 32'h00312423;
        #1;
        if(mem_write!=1'b1||imm_type!=IMM_S||mem_size!=2'b10||reg_write!=1'b0||alu_src!=1'b1||valid!=1'b1)
            $fatal(1,"SW FAILED");
        $display("PASS: SW PASSED");
        instr = 32'h00208863;
        #1;
        if(branch!=1'b1||imm_type!=IMM_B||reg_write!=1'b0||valid!=1'b1)
            $fatal(1, "BRANCH FAILED");
        $display("PASS: BRANCH PASSED");
        //JUMP AND LINK
        instr = 32'h014000EF;
        #1;
        if(jump!=1'b1||imm_type!=IMM_J||reg_write!=1'b1||jalr!=1'b0||valid!=1'b1||wb_sel!=WB_PC4)
            $fatal(1, "JAL FAILED");
        $display("PASS: JAL PASSED");
        //LOAD UPPER IMMEDIATE
        instr = 32'h123450B7;
        #1;
        if(imm_type!=IMM_U||alu_op!=ALU_PASSB||alu_src!=1'b1||reg_write!=1'b1||valid!=1'b1)
            $fatal(1, "LUI FAILED");
        $display("PASS: LUI PASSED");
        //INVALID INSTRUCTION
        instr = 32'hFFFFFFFF;
        #1;
        if (valid !== 1'b0 ||
            reg_write !== 1'b0 ||
            mem_write !== 1'b0 ||
            jump !== 1'b0)
            $fatal(1, "FAIL: invalid instruction");

        $display("PASS: invalid instruction");
        $finish;
    end
endmodule