`timescale 1ns/1ps

module core_pipeline_tb;
    localparam logic [31:0] NOP = 32'h00000013;

    logic clk = 0;
    logic reset = 1;
    logic [31:0] instr_addr, instr;
    logic retire_valid, retire_rd_we;
    logic [31:0] retire_pc, retire_rd_data;
    logic [4:0] retire_rd;

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

    always_comb begin
        case (instr_addr)
            32'd0:  instr = 32'h00500093; // addi x1, x0, 5
            32'd4:  instr = 32'hffd00113; // addi x2, x0, -3
            32'd8:  instr = 32'h00c00193; // addi x3, x0, 12
            32'd12: instr = 32'h00700013; // addi x0, x0, 7
            32'd20: instr = 32'h00208213; // addi x4, x1, 2

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

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;

        repeat (4) expect_bubble();
        expect_retirement(32'd0,  5'd1, 32'd5);
        expect_retirement(32'd4,  5'd2, 32'hfffffffd);
        expect_retirement(32'd8,  5'd3, 32'd12);
        expect_retirement(32'd12, 5'd0, 32'd0);
        expect_bubble();
        expect_retirement(32'd20, 5'd4, 32'd7);
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
        expect_bubble();

        $display("PASS: ADDI retirement, EX/MEM and MEM/WB forwarding, Decode bypass, and x0 protection");
        $finish;
    end
endmodule
