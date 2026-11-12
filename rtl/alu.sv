module alu(
    input logic [3:0] op,
    input logic [31:0] a,b,
    output logic [31:0] y
);
    import cpu_pkg::*;

    always_comb begin
        case(op)
            ALU_ADD: y = a + b;
            ALU_SUB: y = a-b;
            ALU_AND: y = a&b;
            ALU_OR: y = a|b;
            ALU_XOR: y=a^b;
            ALU_SLT: y = ($signed(a)<$signed(b))?32'd1:32'd0;
            ALU_SLL: y = a<<b[4:0];
            ALU_SRL: y = a>>b[4:0];
            ALU_SRA: y= $signed(a)>>>b[4:0];
            ALU_SLTU: y = (a<b)?32'd1:32'd0;
            ALU_PASSB: y = b;
            default: y = 32'd0;
        endcase
    end
endmodule
