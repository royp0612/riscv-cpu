`timescale 1ns/1ps
module imem_tb; 
    logic [31:0] addr, instr;
    imem dut(
        .addr(addr),
        .instr(instr)
    );
    initial begin
        addr = 32'd0;
        #1;
        if (instr !== 32'h00500093)
            $fatal(1, "Wrong instruction at address 0");
        addr = 32'd4;
        #1;
        if (instr !== 32'h00300113)
            $fatal(1, "Wrong instruction at address 4");

        addr = 32'd8;
        #1;
        if (instr !== 32'h002081B3)
            $fatal(1, "Wrong instruction at address 8");

        addr = 32'd12;
        #1;
        if (instr !== 32'h00302023)
            $fatal(1, "Wrong instruction at address 12");

        addr = 32'd16;
        #1;
        if (instr !== 32'h00002203)
            $fatal(1, "Wrong instruction at address 16");

        addr = 32'd20;
        #1;
        if (instr !== 32'h100002B7)
            $fatal(1, "Wrong instruction at address 20");

        addr = 32'd24;
        #1;
        if (instr !== 32'h0102A303)
            $fatal(1, "Wrong instruction at address 24");

        addr = 32'd28;
        #1;
        if (instr !== 32'h0062A623)
            $fatal(1, "Wrong instruction at address 28");

        addr = 32'd32;
        #1;
        if (instr !== 32'hFF9FF06F)
            $fatal(1, "Wrong loop instruction at address 32");

        addr = 32'd36;
        #1;
        if (instr !== 32'h00000013)
            $fatal(1, "Expected NOP at unused address 36");
        
        addr = 32'd4;
        #1;
        if (instr !== 32'h00300113)
            $fatal(1, "Wrong instruction at address 4");
        $display("PASS: ALL INSTRUCTIONS GOOD");
        $finish;
    end
endmodule
