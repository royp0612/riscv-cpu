`timescale 1ns/1ps

module soc_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [15:0] sw = 16'hA55A;
    logic [15:0] led;

    soc dut (
        .clk   (clk),
        .reset (reset),
        .sw    (sw),
        .led   (led)
    );

    always #5 clk = ~clk;

    // Enter with PC=32, just after the previous LED store.
    task automatic check_switch_update(input logic [15:0] value);
        logic [15:0] previous_led;
        previous_led = led;
        @(negedge clk);
        sw = value;

        @(posedge clk); // JAL at 32 returns to the switch load at 24.
        #1;
        if (dut.instr_addr !== 32'd24)
            $fatal(1, "Loop jump failed: expected PC = 24");
        if (led !== previous_led)
            $fatal(1, "LEDs changed before the CPU store");

        @(posedge clk); // LW reads the new switch value.
        #1;
        if (dut.core_inst.regfile_inst.registers[6] !== {16'd0, value})
            $fatal(1, "Loop switch read failed: expected %h", value);
        if (led !== previous_led)
            $fatal(1, "Switch load unexpectedly changed LEDs");

        @(posedge clk); // SW updates the LED register.
        #1;
        if (dut.instr_addr !== 32'd32)
            $fatal(1, "Expected PC = 32 after loop store");
        if (led !== value)
            $fatal(1, "Loop LED update failed: expected %h got %h", value, led);
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

        repeat (5) @(posedge clk);
        #1;

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

        if (dut.instr_addr !== 32'd20)
            $fatal(1, "Expected PC = 20 after five instructions");

        // Read switches through the CPU, then store their value to the LEDs.
        repeat (3) @(posedge clk);
        #1;

        if (dut.core_inst.regfile_inst.registers[6] !== 32'h0000A55A)
            $fatal(1, "Switch read failed: expected x6 = 0000A55A");

        if (led !== 16'hA55A)
            $fatal(1, "LED write failed: expected A55A");

        check_switch_update(16'h5AA5);
        check_switch_update(16'h0000);
        check_switch_update(16'hFFFF);

        if (dut.dmem_inst.mem[0] !== 32'd8)
            $fatal(1, "Switch/LED loop corrupted the RAM result");

        $display("PASS: SoC reset, arithmetic, RAM, and repeated switch-to-LED updates");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Timeout: SoC testbench did not finish");
    end
endmodule
