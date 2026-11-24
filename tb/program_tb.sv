`timescale 1ns/1ps

// Run from the repository root after building sw/prog.hex.
module program_tb;
    localparam int CLOCKS_PER_BIT = 434;

    logic clk = 0;
    logic reset = 1;
    logic [15:0] sw = 16'hA55A;
    logic [15:0] led;
    logic tx;
    bit saw_rom_read;

    soc #(.UART_CLOCKS_PER_BIT(CLOCKS_PER_BIT)) dut (
        .clk(clk), .reset(reset), .sw(sw), .led(led), .uart_tx(tx)
    );
    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (reset)
            saw_rom_read <= 1'b0;
        else if (dut.mem_read && dut.data_addr[31:12] == 20'h00002)
            saw_rom_read <= 1'b1;
    end

    task automatic receive_byte(input logic [7:0] expected);
        logic [7:0] received;
        @(negedge tx);
        repeat (CLOCKS_PER_BIT / 2) @(negedge clk);
        if (tx !== 1'b0)
            $fatal(1, "Firmware UART start bit was not low");
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            repeat (CLOCKS_PER_BIT) @(negedge clk);
            received[bit_index] = tx;
        end
        repeat (CLOCKS_PER_BIT) @(negedge clk);
        if (tx !== 1'b1 || received !== expected)
            $fatal(1, "Expected UART byte %h with a stop bit, got byte %h and stop bit %b",
                   expected, received, tx);
    endtask

    task automatic check_switches(input logic [15:0] value);
        @(negedge clk);
        sw = value;
        receive_byte(8'h48); // H
        receive_byte(8'h69); // i
        receive_byte(8'h0d); // CR
        receive_byte(8'h0a); // LF
        if (led !== (~value))
            $fatal(1, "Expected LEDs %h, got %h", ~value, led);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        if (led !== 16'd0 || tx !== 1'b1)
            $fatal(1, "Incorrect firmware SoC reset outputs");
        reset = 0;
        check_switches(16'hA55A);
        @(negedge clk);
        reset = 1;
        repeat (3) @(negedge clk);
        reset = 0;
        check_switches(16'h5AA5);
        check_switches(16'h0000);
        check_switches(16'hFFFF);
        if (!saw_rom_read)
            $fatal(1, "Firmware never loaded from the read-only ROM window");
        $display("PASS: compiled C firmware reads a ROM string, sends it over UART, and updates the LEDs");
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "Compiled program test timed out");
    end
endmodule
