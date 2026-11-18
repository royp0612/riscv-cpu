`timescale 1ns/1ps

module core_pipeline_tb;
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

    always_comb begin
        case (instr_addr)
            32'd0:  instr = 32'h00500093; // addi x1, x0, 5
            32'd4:  instr = 32'hffd00113; // addi x2, x0, -3
            32'd8:  instr = 32'h00c00193; // addi x3, x0, 12
            32'd12: instr = 32'h00700013; // addi x0, x0, 7
            32'd20: instr = 32'h00208213; // addi x4, x1, 2
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

        $display("PASS: ADDI pipeline fills, retires in order, and writes the register file");
        $finish;
    end
endmodule
