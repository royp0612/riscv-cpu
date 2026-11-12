module pc(
    input logic clk,
    input logic reset,
    input logic [31:0] pc_in,
    output logic [31:0] pc_out
);
    always_ff@(posedge clk)
        if (reset)  pc_out <= 32'd0;
        else        pc_out <= pc_in;
endmodule
