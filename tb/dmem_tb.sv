module dmem_tb;
    logic        clk = 0;
    logic        we;
    logic [3:0]  be;
    logic [31:0] addr, wdata, rdata;
    int errors = 0;
    int tests  = 0;

    dmem dut (
        .clk        (clk),
        .mem_read   (1'b1),
        .mem_write  (we),
        .byte_en    (be),
        .addr       (addr),
        .write_data (wdata),
        .read_data  (rdata)
    );

    always #5 clk = ~clk;

    // write on the next clock edge, then turn write enable off
    task write_mem(input logic [31:0] t_addr, input logic [3:0] t_be, input logic [31:0] t_wdata);
        we = 1; be = t_be; addr = t_addr; wdata = t_wdata;
        @(posedge clk); 
        #1;
        we = 0;
    endtask

    // reads are combinational: set the address, wait, compare
    task check_read(input logic [31:0] t_addr, input logic [31:0] expected, input string msg);
        addr = t_addr;
        #1;
        tests++;
        if (rdata !== expected) begin
            $display("FAIL: %s: addr=%h got=%h expected=%h", msg, t_addr, rdata, expected);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("dmem.vcd");
        $dumpvars(0, dmem_tb);
        we = 0; be = 0; addr = 0; wdata = 0;
        @(posedge clk); #1;

        // 1. Full word write and read back (SW)
        write_mem(32'h0, 4'b1111, 32'h11223344);
        check_read(32'h0, 32'h11223344, "word write");

        // 2. Write one byte only (SB to byte 1): other bytes unchanged
        write_mem(32'h0, 4'b0010, 32'h0000AB00);
        check_read(32'h0, 32'h1122AB44, "byte 1 write");

        // 3. Write upper half only (SH to bytes 2-3)
        write_mem(32'h0, 4'b1100, 32'hCDEF0000);
        check_read(32'h0, 32'hCDEFAB44, "upper half write");

        // 4. No write when we = 0
        we = 0; be = 4'b1111; addr = 32'h0; wdata = 32'hFFFFFFFF;
        @(posedge clk); #1;
        check_read(32'h0, 32'hCDEFAB44, "we=0 does not write");

        // 5. A different word is independent
        write_mem(32'h4, 4'b1111, 32'hDEADBEEF);
        check_read(32'h4, 32'hDEADBEEF, "second word");
        check_read(32'h0, 32'hCDEFAB44, "first word unchanged");

        // 6. Low address bits are ignored for reads (same word)
        check_read(32'h2, 32'hCDEFAB44, "addr bits [1:0] ignored");

        if (errors == 0) $display("PASS: %0d tests", tests);
        else             $fatal(1, "FAIL: %0d tests, %0d errors", tests, errors);
        $finish;
    end
endmodule
