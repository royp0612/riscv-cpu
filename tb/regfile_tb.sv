module regfile_tb;
    logic clk = 0;
    logic we;
    logic [4:0] rs1,rs2,rd;
    logic [31:0] wd, rd1, rd2;

    regfile dut (
    .clk(clk),
    .we(we),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(wd),
    .rd1(rd1),
    .rd2(rd2)
);
    always #5 clk = ~clk;
    initial begin
        we = 0;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        wd = 0;

    //writing 10 to register 1
    @(negedge clk);
    we = 1;
    rd = 5'd1;
    wd = 32'd10;
    @(posedge clk);
    #1;
    rs1 = 5'd1;
    #1;
    if (rd1 !==32'd10)
        $fatal(1,"FAILED WRITE READ");
    $display("PASS rx1 = 10");
    //writing 20 to register 2
    @(negedge clk);
    rd = 5'd2;
    wd = 32'd20;
    @(posedge clk);
    #1;
    rs1 = 5'd1;
    rs2 = 5'd2;
    #1;
    if (rd1 != 32'd10 || rd2 != 32'd20)
        $fatal(1,"FAILED WRITE READ");
    $display("PASS rx2 = 20");
    //attempt to write to register 0
    @(negedge clk);
    rd = 5'd0;
    wd = 32'd1;
    @(posedge clk);
    #1;
    rs1 = 5'd0;
    #1;
    if (rd1 != 32'd0)
        $fatal(1,"FAILED: r0 is not 0");
    $display("PASS r0 = 0");
    
    //disable we
    @(negedge clk);
    we = 0;
    rd = 5'd1;
    @(posedge clk);
    #1;
    rs1 = 5'd1;
    #1;
    if (rd1 != 5'd10)
        $fatal(1,"not supposed to write");
    $display("PASS didn't write");
    $finish;
    end

endmodule