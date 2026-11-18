module core_pipeline (
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] instr_addr,
    input  logic [31:0] instr,
    output logic [31:0] data_addr,
    output logic [31:0] data_write,
    input  logic [31:0] data_read,
    output logic        mem_read,
    output logic        mem_write,
    output logic [3:0]  data_byte_en,
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic        retire_rd_we,
    output logic [4:0]  retire_rd,
    output logic [31:0] retire_rd_data
);
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instr;
    } fetch_decode_t;
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [4:0]  rd;
        logic [31:0] rs1_value;
        logic [31:0] imm;
    } decode_execute_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [4:0]  rd;
        logic [31:0] result;
    } execute_result_t;

    fetch_decode_t if_id;
    decode_execute_t id_ex;
    execute_result_t ex_mem, mem_wb;

    logic        decode_addi;
    logic [31:0] decode_rs1, decode_imm, execute_result;

    // Fetch advances every cycle for this straight-line ADDI milestone.
    pc pc_inst (
        .clk(clk),
        .reset(reset),
        .pc_in(instr_addr + 32'd4),
        .pc_out(instr_addr)
    );

    assign decode_addi = if_id.instr[6:0] == cpu_pkg::OP_I &&
                         if_id.instr[14:12] == 3'b000;

    imm_gen imm_inst (
        .instr(if_id.instr),
        .imm_type(cpu_pkg::IMM_I),
        .imm(decode_imm)
    );

    regfile regfile_inst (
        .clk(clk),
        .we(retire_rd_we),
        .rs1(if_id.instr[19:15]),
        .rs2(5'd0),
        .rd(retire_rd),
        .wd(retire_rd_data),
        .rd1(decode_rs1),
        .rd2()
    );

    alu alu_inst (
        .op(cpu_pkg::ALU_ADD),
        .a(id_ex.rs1_value),
        .b(id_ex.imm),
        .y(execute_result)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            if_id  <= '0;
            id_ex  <= '0;
            ex_mem <= '0;
            mem_wb <= '0;
        end else begin
            if_id <= {1'b1, instr_addr, instr};
            id_ex <= {if_id.valid && decode_addi, if_id.pc, if_id.instr[11:7],
                      decode_rs1, decode_imm};
            ex_mem <= {id_ex.valid, id_ex.pc, id_ex.rd, execute_result};
            // ADDI passes through Memory on its way to Writeback.
            mem_wb <= ex_mem;
        end
    end

    assign data_addr    = 32'd0;
    assign data_write   = 32'd0;
    assign mem_read     = 1'b0;
    assign mem_write    = 1'b0;
    assign data_byte_en = 4'd0;

    assign retire_valid   = mem_wb.valid && !reset;
    assign retire_pc      = mem_wb.pc;
    assign retire_rd_we   = retire_valid && mem_wb.rd != 5'd0;
    assign retire_rd      = mem_wb.rd;
    assign retire_rd_data = mem_wb.result;
endmodule
