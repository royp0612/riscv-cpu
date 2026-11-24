`timescale 1ns/1ps
module soc_uart_tb;
    localparam int CLOCKS_PER_BIT = 4;
    logic clk = 0;
    logic reset = 1;
    logic tx;
    logic [15:0] led;
    logic saw_busy = 0;
    logic saw_idle = 0;

    soc #(
        .INIT_FILE("programs/uart_test.hex"),
        .UART_CLOCKS_PER_BIT(CLOCKS_PER_BIT)
    ) dut (
        .clk(clk), .reset(reset), .sw(16'd0), .led(led), .uart_tx(tx)
    );
    always #5 clk = ~clk;

    // Observe status as actually read by the executing program.
    always @(posedge clk) begin
        if (!reset && dut.mem_read && dut.data_addr == 32'h10000018) begin
            if (dut.data_read === 32'd1) saw_busy <= 1;
            if (dut.data_read === 32'd0) saw_idle <= 1;
        end
    end

    task automatic receive_byte(input logic [7:0] expected);
        logic [9:0] frame;
        frame = {1'b1, expected, 1'b0};
        @(negedge tx);
        #1;
        for (int bit_num = 0; bit_num < 10; bit_num++) begin
            for (int tick = 0; tick < CLOCKS_PER_BIT; tick++) begin
                if (tx !== frame[bit_num])
                    $fatal(1, "Expected UART byte %h: wrong bit %0d", expected, bit_num);
                @(posedge clk);
                #1;
            end
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        if (tx !== 1'b1 || led !== 16'd0)
            $fatal(1, "Incorrect SoC UART reset outputs");
        reset = 0;
        receive_byte(8'h48);
        receive_byte(8'h69);
        repeat (100) begin
            @(posedge clk);
            #1;
            if (tx !== 1'b1)
                $fatal(1, "Unexpected extra UART transmission");
        end
        if (!saw_busy || !saw_idle)
            $fatal(1, "CPU did not observe both busy and idle status");
        if (led !== 16'd0)
            $fatal(1, "UART writes changed LEDs");
        $display("PASS: CPU UART word/byte writes, polling, byte-lane gating, and wrong-path store flushing");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "SoC UART test timed out");
    end
endmodule
