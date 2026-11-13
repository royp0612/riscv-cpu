module imem (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] rom [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++)
            rom[i] = 32'h00000013;

        rom[0] = 32'h00500093; // addi x1, x0, 5
        rom[1] = 32'h00300113; // addi x2, x0, 3
        rom[2] = 32'h002081B3; // add  x3, x1, x2
        rom[3] = 32'h00302023; // sw   x3, 0(x0)
        rom[4] = 32'h00002203; // lw   x4, 0(x0)
        rom[5] = 32'h100002B7; // lui  x5, 0x10000 (I/O base)
        rom[6] = 32'h0102A303; // lw   x6, 16(x5) (switches)
        rom[7] = 32'h0062A623; // sw   x6, 12(x5) (LEDs)
        rom[8] = 32'hFF9FF06F; // jal  x0, -8 (back to switch load)
    end

    assign instr = rom[addr[11:2]];
endmodule
