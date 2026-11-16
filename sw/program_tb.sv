`timescale 1ns/1ps

// Run from the repository root after building sw/prog.hex.
module program_tb;
    logic clk = 0;
    logic reset = 1;
    logic [15:0] sw = 0;
    logic [15:0] led;

    soc dut (.clk(clk), .reset(reset), .sw(sw), .led(led));
    always #5 clk = ~clk;

    task automatic check_switches(input logic [15:0] value);
        @(negedge clk);
        sw = value;
        // Allow startup and multiple iterations without assuming compiler timing.
        repeat (50) @(posedge clk);
        #1;
        if (led !== value)
            $fatal(1, "Expected LEDs %h, got %h", value, led);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        if (led !== 16'd0)
            $fatal(1, "LEDs did not reset");
        reset = 0;
        check_switches(16'hA55A);
        check_switches(16'h5AA5);
        check_switches(16'h0000);
        check_switches(16'hFFFF);
        $display("PASS: compiled C program copies switches to LEDs");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Compiled program test timed out");
    end
endmodule
