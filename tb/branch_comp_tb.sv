module branch_comp_tb;
    logic [31:0] a, b;
    logic [2:0] branch_type;
    logic taken;

    branch_comp dut(
            .a(a),
            .b(b),
            .branch_type(branch_type),
            .taken(taken)
        );
    initial begin
        a = 32'd1;
        b = 32'd1;
        branch_type = 3'b000;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL 1");
        $display("PASS: BEQ");
        a = 32'd1;
        b = 32'd0;
        branch_type = 3'b001;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL 1");
        $display("PASS: BNQ");
        //BLT
        a = 32'hFFFFFFFF;
        b = 32'd0;
        branch_type = 3'b100;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL BLT");
        $display("PASS: BLTU");
        //BGT
        a = 32'd0;
        b = 32'hFFFFFFFF;
        branch_type = 3'b101;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL BGT");
        $display("PASS: BGTU");
        //BLTU
        a = 32'd0;
        b = 32'd1;
        branch_type = 3'b110;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL BLT");
        $display("PASS: BLT");
        //BGT
        a = 32'd1;
        b = 32'd0;
        branch_type = 3'b111;
        #1;
        if(taken!=1'b1)
            $fatal(1,"DID NOT EQUAL BGT");
        $display("PASS: BGT");
    end
endmodule