`timescale 1ns/1ps

module soc_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [15:0] sw = 16'hA55A;
    logic [15:0] led;

    soc #(.INIT_FILE("programs/demo.hex")) dut (
        .clk   (clk),
        .reset (reset),
        .sw    (sw),
        .led   (led)
    );

    always #5 clk = ~clk;

    task automatic check_switch_update(input logic [15:0] value);
        @(negedge clk);
        sw = value;

        for (int cycle = 0; cycle < 32 && (led !== value); cycle++) begin
            @(posedge clk);
            #1;
        end
        if (led !== value)
            $fatal(1, "Loop LED update failed: expected %h got %h", value, led);
        if (dut.core_inst.regfile_inst.registers[6] !== {16'd0, value})
            $fatal(1, "Loop switch read failed: expected %h", value);
    endtask

    initial begin
        repeat (2) @(posedge clk);
        #1;
        if (dut.instr_addr !== 32'd0)
            $fatal(1, "Reset failed: expected PC = 0");
        if (led !== 16'd0)
            $fatal(1, "Reset failed: expected LEDs off");

        @(negedge clk);
        reset = 1'b0;

        check_switch_update(16'hA55A);

        if (dut.core_inst.regfile_inst.registers[1] !== 32'd5)
            $fatal(1, "ADDI failed: expected x1 = 5");

        if (dut.core_inst.regfile_inst.registers[2] !== 32'd3)
            $fatal(1, "ADDI failed: expected x2 = 3");

        if (dut.core_inst.regfile_inst.registers[3] !== 32'd8)
            $fatal(1, "ADD failed: expected x3 = 8");

        if (dut.dmem_inst.mem[0] !== 32'd8)
            $fatal(1, "SW failed: expected memory[0] = 8");

        if (dut.core_inst.regfile_inst.registers[4] !== 32'd8)
            $fatal(1, "LW failed: expected x4 = 8");

        check_switch_update(16'h5AA5);
        check_switch_update(16'h0000);
        check_switch_update(16'hFFFF);

        if (dut.dmem_inst.mem[0] !== 32'd8)
            $fatal(1, "Switch/LED loop corrupted the RAM result");

        $display("PASS: SoC reset, arithmetic, RAM, and repeated switch-to-LED updates");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Timeout: SoC testbench did not finish");
    end
endmodule
