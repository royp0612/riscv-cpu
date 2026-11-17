`timescale 1ns/1ps
module uart_tx_tb;
    localparam int CLOCKS_PER_BIT = 4;
    logic clk = 0;
    logic reset = 1;
    logic start = 0;
    logic [7:0] data = 0;
    logic tx, busy;

    uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) dut (
        .clk(clk), .reset(reset), .start(start), .data(data),
        .tx(tx), .busy(busy)
    );
    always #5 clk = ~clk;

    task automatic check_frame(input logic [7:0] value);
        logic [9:0] frame;
        frame = {1'b1, value, 1'b0}; 
        @(negedge clk);
        data = value;
        start = 1;
        @(posedge clk);
        #1;
        if (busy !== 1'b1)
            $fatal(1, "UART did not become busy");
        @(negedge clk);
        start = 0;
        data = ~value;
        for (int bit_num = 0; bit_num < 10; bit_num++) begin
            for (int tick = 0; tick < CLOCKS_PER_BIT; tick++) begin
                @(posedge clk);
                #1;
                if (tx !== frame[bit_num])
                    $fatal(1, "Byte %h: wrong bit %0d at tick %0d", value, bit_num, tick);
                if (busy !== ((bit_num == 9 && tick == CLOCKS_PER_BIT - 1) ? 1'b0 : 1'b1))
                    $fatal(1, "Incorrect UART busy timing");
            end
        end
        @(posedge clk);
        #1;
        if (tx !== 1'b1 || busy !== 1'b0)
            $fatal(1, "UART did not return to idle");
    endtask

    initial begin
        repeat (2) @(negedge clk);
        if (tx !== 1'b1 || busy !== 1'b0)
            $fatal(1, "Incorrect UART reset outputs");
        reset = 0;
        check_frame(8'h55);
        check_frame(8'hA6);
        check_frame(8'h00);
        check_frame(8'hFF);
        $display("PASS: UART reset, byte latching, LSB-first frames, bit timing and busy");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "UART test timed out");
    end
endmodule
