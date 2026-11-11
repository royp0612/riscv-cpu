module pc_tb;
    logic clk=0;
    logic reset;
    logic [31:0] pc_in, pc_out;
    pc dut (
    .clk(clk),
    .reset(reset),
    .pc_in(pc_in),
    .pc_out(pc_out)
);
    always #5 clk = ~clk;
    initial begin
        reset = 1;
        pc_in = 32'd0;
        @(posedge clk);
        #1;
        if(pc_out !=32'd0)
            $fatal(1,"didn't reset");
        $display("PASS: pc reset");
        //pc updates to 4
        reset = 0;
        pc_in = 32'd4;
        @(posedge clk)
        #1;
        if(pc_out !=32'd4)
            $fatal(1,"NOT 4");
        $display("PASS: IT IS 4!!!!!!!");
        //pc updates to addr 100
        pc_in = 32'd100;
        @(posedge clk)
        #1;
        if(pc_out !=32'd100)
            $fatal(1,"NOT 4");
        $display("PASS: IT IS 100!!!!!!!");
        $finish;
    end

endmodule