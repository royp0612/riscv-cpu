module uart_tx #(
    parameter int CLOCKS_PER_BIT = 434
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       start,
    input  logic [7:0] data,
    output logic       tx,
    output logic       busy
);
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state;

    localparam int COUNT_WIDTH = (CLOCKS_PER_BIT > 1) ? $clog2(CLOCKS_PER_BIT) : 1;
    logic [COUNT_WIDTH-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift;

    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            tx        <= 1'b1;
            clk_count <= '0;
            bit_index <= '0;
            shift     <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx        <= 1'b1;
                    clk_count <= '0;
                    bit_index <= '0;
                    if (start) begin
                        shift <= data;
                        state <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_count == CLOCKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        state     <= DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    tx <= shift[0];
                    if (clk_count == CLOCKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        shift     <= shift >> 1;
                        if (bit_index == 3'd7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (clk_count == CLOCKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state     <= IDLE;
                    tx        <= 1'b1;
                    clk_count <= '0;
                    bit_index <= '0;
                    shift     <= '0;
                end
            endcase
        end
    end

    assign busy = (state != IDLE);
endmodule
