module top(
    input logic clk,
    input logic btnC, //this is reset
    input logic [15:0] sw,
    output logic [15:0] led
);
    // 50 MHz clock for the CPU
    logic cpu_clk, locked;

    clk_wiz_0 clk_inst (
        .clk_in1 (clk),
        .reset   (1'b0),
        .clk_out1(cpu_clk),
        .locked  (locked)
    );

    logic rst_req;
    assign rst_req = btnC | ~locked;

    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe = 2'b11;
    (* ASYNC_REG = "TRUE" *) logic [15:0] sw_meta, sw_sync;

    logic reset;
    always_ff @(posedge cpu_clk or posedge rst_req) begin
        if (rst_req)
            reset_pipe <= 2'b11;
        else
            reset_pipe <= {reset_pipe[0], 1'b0};
    end

    assign reset = reset_pipe[1];

    always_ff @(posedge cpu_clk) begin
        if (reset) begin
            sw_meta <= 16'd0;
            sw_sync <= 16'd0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;
        end
    end

    soc soc_inst (
        .clk   (cpu_clk),
        .reset (reset),
        .sw    (sw_sync),
        .led   (led)
    );

endmodule