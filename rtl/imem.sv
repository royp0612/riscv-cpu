module imem #(
    parameter INIT_FILE = "C:/Users/melon/OneDrive/Documents/riscv-cpu/sw/prog.hex"
) (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] rom [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++)
            rom[i] = 32'h00000013;
        $readmemh(INIT_FILE, rom);
    end

    assign instr = rom[addr[11:2]];
endmodule
