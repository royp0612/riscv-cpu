module alu(
    input logic [3:0] op,
    input logic [31:0] a,b,
    output logic [31:0] y
);
    localparam ADD  = 4'd0,  SUB  = 4'd1,  AND_ = 4'd2,  OR_   = 4'd3,
                XOR_ = 4'd4,  SLL  = 4'd5,  SRL  = 4'd6,  SRA   = 4'd7,
                SLT  = 4'd8,  SLTU = 4'd9,  PASSB = 4'd10;
    always_comb begin
        case(op)
            ADD: y = a + b;
            SUB: y = a-b;
            AND_: y = a&b;
            OR_: y = a|b;
            XOR_: y=a^b;
            SLT: y = ($signed(a)<$signed(b))?32'd1:32'd0;
            SLL: y = a<<b[4:0];
            SRL: y = a>>b[4:0];
            SRA: y= $signed(a)>>>b[4:0];
            default: y = 32'd0;
        endcase
    end
endmodule
