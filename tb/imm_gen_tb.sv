
`timescale 1ns/1ps

module imm_gen_tb;

    logic [31:0] instr;
    logic [2:0] imm_type;
    logic [31:0] imm;

    imm_gen dut (
        .instr(instr),
        .imm_type(imm_type),
        .imm(imm)
    );

    initial begin
        // TEST 1: I-type (ADDI x1, x2, 10)
        instr = 32'h00A10093;
        imm_type = 3'd0;
        #1;

        if (imm !== 32'd10)
            $fatal(1, "FAIL: I-type");

        $display("PASS: I-type = 10");

        // TEST 2: S-type (SW x3, 8(x2))
        instr = 32'h00312423;
        imm_type = 3'd1;
        #1;

        if (imm !== 32'd8)
            $fatal(1, "FAIL: S-type");

        $display("PASS: S-type = 8");

        // TEST 3: B-type (BEQ x1, x2, 16)
        instr = 32'h00208863;
        imm_type = 3'd2;
        #1;

        if (imm !== 32'd16)
            $fatal(1, "FAIL: B-type");

        $display("PASS: B-type = 16");

        // TEST 4: U-type (LUI x1, 0x12345)
        instr = 32'h123450B7;
        imm_type = 3'd3;
        #1;

        if (imm !== 32'h12345000)
            $fatal(1, "FAIL: U-type");

        $display("PASS: U-type = 0x12345000");

        // TEST 5: J-type (JAL x1, 20)
        instr = 32'h014000EF;
        imm_type = 3'd4;
        #1;

        if (imm !== 32'd20)
            $fatal(1, "FAIL: J-type");

        $display("PASS: J-type = 20");

        $finish;
    end

endmodule
