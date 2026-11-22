`timescale 1ns/1ps

module core_pipeline_tb;
    localparam logic [31:0] NOP = 32'h00000013;
    localparam logic [31:0] RS2_CHECK_PC = 32'd20;

    logic clk = 0;
    logic reset = 1;
    logic [31:0] instr_addr, instr;
    logic retire_valid, retire_rd_we;
    logic [31:0] retire_pc, retire_rd_data;
    logic [4:0] retire_rd;
    bit rs2_checked;

    core_pipeline dut (
        .clk(clk),
        .reset(reset),
        .instr_addr(instr_addr),
        .instr(instr),
        .data_read(32'd0),
        .retire_valid(retire_valid),
        .retire_pc(retire_pc),
        .retire_rd_we(retire_rd_we),
        .retire_rd(retire_rd),
        .retire_rd_data(retire_rd_data)
    );

    always #5 clk = ~clk;

    function automatic logic [31:0] encode_addi(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [11:0] imm
    );
        return {imm, rs1, 3'b000, rd, cpu_pkg::OP_I};
    endfunction

    function automatic logic [31:0] encode_add(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2
    );
        return {7'b0000000, rs2, rs1, 3'b000, rd, cpu_pkg::OP_R};
    endfunction

    always_comb begin
        case (instr_addr)
            32'd0:  instr = 32'h00500093; // addi x1, x0, 5
            32'd4:  instr = 32'hffd00113; // addi x2, x0, -3
            32'd8:  instr = 32'h00c00193; // addi x3, x0, 12
            32'd12: instr = 32'h00700013; // addi x0, x0, 7
            RS2_CHECK_PC: instr = 32'h00208213; // addi x4, x1, 2

            // Adjacent dependency uses EX/MEM forwarding.
            32'd28: instr = encode_addi(5'd5, 5'd0, 12'd10);
            32'd32: instr = encode_addi(5'd6, 5'd5, 12'd1);

            // One NOP moves the producer to MEM/WB during Execute.
            32'd36: instr = encode_addi(5'd5, 5'd0, 12'd20);
            32'd40: instr = NOP;
            32'd44: instr = encode_addi(5'd6, 5'd5, 12'd1);

            // Two NOPs make Decode and Writeback use x5 on the same edge.
            32'd48: instr = encode_addi(5'd5, 5'd0, 12'd30);
            32'd52, 32'd56: instr = NOP;
            32'd60: instr = encode_addi(5'd6, 5'd5, 12'd1);

            // Both forwarding stages match x5. The newer value wins.
            32'd64: instr = encode_addi(5'd5, 5'd0, 12'd40);
            32'd68: instr = encode_addi(5'd5, 5'd0, 12'd50);
            32'd72: instr = encode_addi(5'd6, 5'd5, 12'd1);

            // Writes targeting x0 cannot affect the forwarded operand.
            32'd76: instr = encode_addi(5'd0, 5'd0, 12'd7);
            32'd80: instr = encode_addi(5'd0, 5'd0, 12'd9);
            32'd84: instr = encode_addi(5'd6, 5'd0, 12'd1);

            // ADD gets rs1 from MEM/WB and rs2 from EX/MEM on the same cycle.
            32'd88: instr = encode_addi(5'd7, 5'd0, 12'd5);
            32'd92: instr = encode_addi(5'd8, 5'd0, 12'd7);
            32'd96: instr = encode_add(5'd9, 5'd7, 5'd8);

            // One NOP exercises MEM/WB forwarding for rs2.
            32'd100: instr = encode_addi(5'd8, 5'd0, 12'd9);
            32'd104: instr = NOP;
            32'd108: instr = encode_add(5'd9, 5'd7, 5'd8);

            // Two NOPs exercise the Writeback-to-Decode bypass for rs2.
            32'd112: instr = encode_addi(5'd8, 5'd0, 12'd11);
            32'd116, 32'd120: instr = NOP;
            32'd124: instr = encode_add(5'd9, 5'd7, 5'd8);

            // SUB uses forwarded operands, then forwards its own result to ADDI.
            32'd128: instr = encode_addi(5'd10, 5'd0, 12'd9);
            32'd132: instr = encode_addi(5'd11, 5'd0, 12'd4);
            32'd136: instr = 32'h40b50633; // sub x12, x10, x11
            32'd140: instr = encode_addi(5'd13, 5'd12, 12'd1);

            // A negative operand distinguishes signed compares and right shifts.
            // The register shift count of 35 also checks that only its low five bits are used.
            32'd144: instr = encode_addi(5'd14, 5'd0, 12'hff1); // x14 = -15
            32'd148: instr = encode_addi(5'd15, 5'd0, 12'd35);  // x15 = 35
            32'd152: instr = 32'h00f71833; // sll  x16, x14, x15
            32'd156: instr = 32'h00f72833; // slt  x16, x14, x15
            32'd160: instr = 32'h00f73833; // sltu x16, x14, x15
            32'd164: instr = 32'h00f74833; // xor  x16, x14, x15
            32'd168: instr = 32'h00f75833; // srl  x16, x14, x15
            32'd172: instr = 32'h40f75833; // sra  x16, x14, x15
            32'd176: instr = 32'h00f76833; // or   x16, x14, x15
            32'd180: instr = 32'h00f77833; // and  x16, x14, x15

            32'd184: instr = 32'h00371813; // slli  x16, x14, 3
            32'd188: instr = 32'h00372813; // slti  x16, x14, 3
            32'd192: instr = 32'h00373813; // sltiu x16, x14, 3
            32'd196: instr = 32'hffe74813; // xori  x16, x14, -2
            32'd200: instr = 32'h00375813; // srli  x16, x14, 3
            32'd204: instr = 32'h40375813; // srai  x16, x14, 3
            32'd208: instr = 32'h00376813; // ori   x16, x14, 3
            32'd212: instr = 32'h00377813; // andi  x16, x14, 3
            32'd216: instr = 32'hfff73813; // sltiu x16, x14, -1
            32'd220: instr = 32'h02371813; // Reserved RV32I shift-immediate encoding.
            default: instr = 32'd0;      // Unsupported encoding creates a bubble.
        endcase
    end

    task automatic expect_bubble;
        @(posedge clk);
        if (retire_valid !== 1'b0 || retire_rd_we !== 1'b0)
            $fatal(1, "Expected no retirement, got PC %h", retire_pc);
    endtask

    task automatic expect_retirement(
        input logic [31:0] expected_pc,
        input logic [4:0]  expected_rd,
        input logic [31:0] expected_data
    );
        // Sample Writeback at the edge that commits the register write.
        @(posedge clk);
        if (retire_valid !== 1'b1 || retire_pc !== expected_pc ||
            retire_rd !== expected_rd || retire_rd_we !== (expected_rd != 5'd0))
            $fatal(1, "Expected PC %h and rd x%0d, got PC %h, rd x%0d, valid=%b, we=%b",
                   expected_pc, expected_rd, retire_pc, retire_rd, retire_valid, retire_rd_we);
        if (retire_rd_we && retire_rd_data !== expected_data)
            $fatal(1, "PC %h: expected %h, got %h", expected_pc, expected_data, retire_rd_data);
    endtask

    // The low immediate bits select x2 on the second read port. x2 already holds -3.
    always @(negedge clk) begin
        if (!reset && dut.id_ex.valid && dut.id_ex.pc == RS2_CHECK_PC) begin
            if (dut.id_ex.rs2 !== 5'd2 || dut.id_ex.rs2_value !== 32'hfffffffd)
                $fatal(1, "ID/EX expected rs2 = x2 and value -3, got rs2 = x%0d and value %h",
                       dut.id_ex.rs2, dut.id_ex.rs2_value);
            rs2_checked = 1'b1;
        end
    end

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;

        repeat (4) expect_bubble();
        expect_retirement(32'd0,  5'd1, 32'd5);
        expect_retirement(32'd4,  5'd2, 32'hfffffffd);
        expect_retirement(32'd8,  5'd3, 32'd12);
        expect_retirement(32'd12, 5'd0, 32'd0);
        expect_bubble();
        expect_retirement(RS2_CHECK_PC, 5'd4, 32'd7);
        expect_bubble();

        expect_retirement(32'd28, 5'd5, 32'd10);
        expect_retirement(32'd32, 5'd6, 32'd11);

        expect_retirement(32'd36, 5'd5, 32'd20);
        expect_retirement(32'd40, 5'd0, 32'd0);
        expect_retirement(32'd44, 5'd6, 32'd21);

        expect_retirement(32'd48, 5'd5, 32'd30);
        expect_retirement(32'd52, 5'd0, 32'd0);
        expect_retirement(32'd56, 5'd0, 32'd0);
        expect_retirement(32'd60, 5'd6, 32'd31);

        expect_retirement(32'd64, 5'd5, 32'd40);
        expect_retirement(32'd68, 5'd5, 32'd50);
        expect_retirement(32'd72, 5'd6, 32'd51);

        expect_retirement(32'd76, 5'd0, 32'd0);
        expect_retirement(32'd80, 5'd0, 32'd0);
        expect_retirement(32'd84, 5'd6, 32'd1);

        expect_retirement(32'd88, 5'd7, 32'd5);
        expect_retirement(32'd92, 5'd8, 32'd7);
        expect_retirement(32'd96, 5'd9, 32'd12);

        expect_retirement(32'd100, 5'd8, 32'd9);
        expect_retirement(32'd104, 5'd0, 32'd0);
        expect_retirement(32'd108, 5'd9, 32'd14);

        expect_retirement(32'd112, 5'd8, 32'd11);
        expect_retirement(32'd116, 5'd0, 32'd0);
        expect_retirement(32'd120, 5'd0, 32'd0);
        expect_retirement(32'd124, 5'd9, 32'd16);

        expect_retirement(32'd128, 5'd10, 32'd9);
        expect_retirement(32'd132, 5'd11, 32'd4);
        expect_retirement(32'd136, 5'd12, 32'd5);
        expect_retirement(32'd140, 5'd13, 32'd6);

        expect_retirement(32'd144, 5'd14, 32'hfffffff1);
        expect_retirement(32'd148, 5'd15, 32'd35);
        expect_retirement(32'd152, 5'd16, 32'hffffff88);
        expect_retirement(32'd156, 5'd16, 32'd1);
        expect_retirement(32'd160, 5'd16, 32'd0);
        expect_retirement(32'd164, 5'd16, 32'hffffffd2);
        expect_retirement(32'd168, 5'd16, 32'h1ffffffe);
        expect_retirement(32'd172, 5'd16, 32'hfffffffe);
        expect_retirement(32'd176, 5'd16, 32'hfffffff3);
        expect_retirement(32'd180, 5'd16, 32'h00000021);

        expect_retirement(32'd184, 5'd16, 32'hffffff88);
        expect_retirement(32'd188, 5'd16, 32'd1);
        expect_retirement(32'd192, 5'd16, 32'd0);
        expect_retirement(32'd196, 5'd16, 32'h0000000f);
        expect_retirement(32'd200, 5'd16, 32'h1ffffffe);
        expect_retirement(32'd204, 5'd16, 32'hfffffffe);
        expect_retirement(32'd208, 5'd16, 32'hfffffff3);
        expect_retirement(32'd212, 5'd16, 32'h00000001);
        expect_retirement(32'd216, 5'd16, 32'd1);
        expect_bubble(); // Reserved shift-immediate encoding.
        expect_bubble();

        if (!rs2_checked)
            $fatal(1, "The rs2 capture check never ran");
        $display("PASS: ID/EX captures the rs2 register number and read value");
        $display("PASS: ADDI retirement, EX/MEM and MEM/WB forwarding, Decode bypass, and x0 protection");
        $display("PASS: ADD retirement with rs2 forwarding and Decode bypass");
        $display("PASS: SUB uses forwarded operands and forwards its result to ADDI");
        $display("PASS: register and immediate shifts, comparisons, and bitwise operations");
        $finish;
    end
endmodule
