module flopwtithresetenable(input logic clk,
                            input logic [3:0] d,
                            input logic reset,
                            input logic en, 
                            output logic [3:0]q);
    always_ff@(posedge clk, posedge reset)
        if (reset) q<=0;
        else if (en)q<=d;
endmodule  