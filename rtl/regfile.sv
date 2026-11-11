module regfile(
    input logic clk,
    input logic we,
    input logic [4:0] rs1,rs2,rd,
    input logic [31:0] wd,
    output logic [31:0] rd1, rd2
);
    logic [31:0] registers [0:31];
    assign rd1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];
    always_ff@(posedge clk)begin
        if(we && rd != 5'd0)
            registers[rd]<=wd;

    end


endmodule