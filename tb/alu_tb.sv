module alu_tb;
    localparam ADD  = 4'd0,  SUB  = 4'd1,  AND_ = 4'd2,  OR_   = 4'd3,
                XOR_ = 4'd4,  SLL  = 4'd5,  SRL  = 4'd6,  SRA   = 4'd7,
                SLT  = 4'd8,  SLTU = 4'd9,  PASSB = 4'd10;
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
        //addition
        CHECK(ADD, 32'd1, 32'd3, 32'd4);
        CHECK(ADD, 32'hFFFFFFFF, 32'd1, 32'd0);
        
        //subtraction
        CHECK(SUB, 32'd4, 32'd3, 32'd1);
        CHECK(SUB, 32'd0,32'd1, 32'hFFFFFFFF);
        //bitwise
        CHECK(AND_, 32'hF0F0F0F0, 32'hF000000F, 32'hF0000000);
        CHECK(OR_, 32'hF0F0F0F0, 32'hF000000F, 32'hF0F0F0FF);
        CHECK(XOR_, 32'hF0F0F0F0, 32'hF000000F, 32'h00F0F0FF);

        CHECK(SLL, 32'h00000001, 32'd4, 32'h00000010);
        CHECK(SRL, 32'h00000010, 32'd4, 32'h00000001);
        CHECK(SRA, 32'h10000000, 32'd4, 32'h01000000);
        CHECK(SLT, 32'hFFFFFFFF, 32'd2, 32'd1);
        CHECK(SLT, 32'hFFFFFFFE, 32'd2, 32'd0);
        CHECK(SLTU, 32'd1, 32'd2, 32'd1);
        CHECK(SLTU, 32'd2, 32'd1, 32'd0);


        if (errors==0) $display("PASS: %0d tests", tests);
        else $display("FAIL: %0d tests, %0d errors", tests, errors);
    end

endmodule   
    