module alu_tb;
    import cpu_pkg::*;

    logic [3:0] op;
    logic [31:0] a,b,y;
    //instantiate alu testbench
    alu dut(op,a,b,y);
    int errors = 0;
    int tests = 0;
    task CHECK(input logic [3:0] t_op, input logic [31:0] t_a,t_b,expected);
        op=t_op; a=t_a; b=t_b;
        #1;
        tests++;
        if (y!=expected) begin
            $display("FAIL: op=%0d a=%h b=%h  got=%h  expected=%h", t_op, t_a, t_b, y, expected);
            errors++;
        end
    endtask
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        //addition
        CHECK(ALU_ADD, 32'd1, 32'd3, 32'd4);
        CHECK(ALU_ADD, 32'hFFFFFFFF, 32'd1, 32'd0);
        
        //subtraction
        CHECK(ALU_SUB, 32'd4, 32'd3, 32'd1);
        CHECK(ALU_SUB, 32'd0,32'd1, 32'hFFFFFFFF);
        //bitwise
        CHECK(ALU_AND, 32'hF0F0F0F0, 32'hF000000F, 32'hF0000000);
        CHECK(ALU_OR, 32'hF0F0F0F0, 32'hF000000F, 32'hF0F0F0FF);
        CHECK(ALU_XOR, 32'hF0F0F0F0, 32'hF000000F, 32'h00F0F0FF);

        CHECK(ALU_SLL, 32'h00000001, 32'd4, 32'h00000010);
        CHECK(ALU_SRL, 32'h00000010, 32'd4, 32'h00000001);
        CHECK(ALU_SRA, 32'h10000000, 32'd4, 32'h01000000);
        CHECK(ALU_SRA, 32'h80000000, 32'd4, 32'hF8000000);
        CHECK(ALU_SRL, 32'h80000000, 32'd4, 32'h08000000);
        CHECK(ALU_SLT, 32'hFFFFFFFF, 32'd2, 32'd1);
        CHECK(ALU_SLT, 32'hFFFFFFFE, 32'd2, 32'd1);
        CHECK(ALU_SLT, 32'd2, 32'hFFFFFFFE, 32'd0);
        CHECK(ALU_SLT, 32'd2, 32'd1, 32'd0);
        
        CHECK(ALU_SLTU, 32'd2, 32'd1, 32'd0);
        CHECK(ALU_SLTU, 32'hFFFFFFFE, 32'd2, 32'd0);
        CHECK(ALU_SLTU, 32'd2, 32'hFFFFFFFE, 32'd1);

        CHECK(ALU_PASSB, 32'd5,32'hFFFFFFFF, 32'hFFFFFFFF);
        CHECK(ALU_PASSB, 32'd1,32'd0,32'd0);


        if (errors==0) $display("PASS: %0d tests", tests);
        else $display("FAIL: %0d tests, %0d errors", tests, errors);
    end

endmodule   
    