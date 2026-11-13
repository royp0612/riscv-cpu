module soc(
    input logic clk,
    input logic reset,
    input logic[15:0] sw,
    output logic [15:0] led
);
    logic [31:0] instr_addr, instr;
    logic [31:0] data_addr, data_write, data_read;
    logic mem_read, mem_write;
    logic [3:0] data_byte_en;
    logic [31:0] dmem_rdata;
    logic is_mmio;

    assign is_mmio = (data_addr[31:28] == 4'h1);

    core core_inst (
        .clk          (clk),
        .reset        (reset),
        .instr_addr   (instr_addr),
        .instr        (instr),
        .data_addr    (data_addr),
        .data_write   (data_write),
        .data_read    (data_read),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .data_byte_en (data_byte_en)
    );

    imem imem_inst (
        .addr  (instr_addr),
        .instr (instr)
    );

    dmem dmem_inst (
        .clk        (clk),
        .mem_read   (mem_read && !is_mmio),
        .mem_write  (mem_write && !is_mmio),
        .addr       (data_addr),
        .write_data (data_write),
        .byte_en    (data_byte_en),
        .read_data  (dmem_rdata)
    );
    always_comb begin
        data_read = 32'd0;

        if (!is_mmio)
            data_read = dmem_rdata;
        else if (mem_read &&
                data_addr[31:2] == (32'h10000010 >> 2))
            data_read = {16'd0, sw};
    end
    always_ff @(posedge clk) begin
        if (reset)
            led <= 16'd0;
        else if (mem_write &&
                data_addr[31:2] == (32'h1000000C >> 2)) begin
            if (data_byte_en[0])
                led[7:0] <= data_write[7:0];

            if (data_byte_en[1])
                led[15:8] <= data_write[15:8];
        end
    end

endmodule
