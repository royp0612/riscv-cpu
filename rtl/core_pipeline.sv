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
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [31:0] rs1_value;
        logic [31:0] rs2_value;
        logic [31:0] imm;
        logic        use_rs2;
        logic [3:0]  alu_op;
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

    logic [3:0]  decode_alu_op;
    logic        decode_alu_src, decode_valid, decode_supported;
    logic [31:0] decode_rs1, decode_rs2, decode_imm, execute_result;
    logic [31:0] alu_a, decode_rs1_bypassed;
    logic [31:0] execute_rs2, decode_rs2_bypassed;

    // Fetch advances every cycle for straight-line execution.
    pc pc_inst (
        .clk(clk),
        .reset(reset),
        .pc_in(instr_addr + 32'd4),
        .pc_out(instr_addr)
    );

    decoder decoder_inst (
        .instr(if_id.instr),
        .alu_op(decode_alu_op),
        .alu_src(decode_alu_src),
        .valid(decode_valid)
    );

    // ADD, ADDI, and SUB all use funct3 == 000.
    assign decode_supported = decode_valid &&
                              if_id.instr[14:12] == 3'b000 &&
                              (if_id.instr[6:0] == cpu_pkg::OP_R ||
                               if_id.instr[6:0] == cpu_pkg::OP_I);

    imm_gen imm_inst (
        .instr(if_id.instr),
        .imm_type(cpu_pkg::IMM_I),
        .imm(decode_imm)
    );

    regfile regfile_inst (
        .clk(clk),
        .we(retire_rd_we),
        .rs1(if_id.instr[19:15]),
        .rs2(if_id.instr[24:20]),
        .rd(retire_rd),
        .wd(retire_rd_data),
        .rd1(decode_rs1),
        .rd2(decode_rs2)
    );

    alu alu_inst (
        .op(id_ex.alu_op),
        .a(alu_a),
        .b(id_ex.use_rs2 ? execute_rs2 : id_ex.imm),
        .y(execute_result)
    );

    always_comb begin
        alu_a = id_ex.rs1_value;

        if (mem_wb.valid && mem_wb.rd != 5'd0 && mem_wb.rd == id_ex.rs1)
            alu_a = mem_wb.result;

        // The newer EX/MEM result takes priority when both stages match.
        if (ex_mem.valid && ex_mem.rd != 5'd0 && ex_mem.rd == id_ex.rs1)
            alu_a = ex_mem.result;
    end

    always_comb begin
        execute_rs2 = id_ex.rs2_value;

        if (ex_mem.valid && ex_mem.rd != 5'd0 && ex_mem.rd == id_ex.rs2)
            execute_rs2 = ex_mem.result;
        else if (retire_rd_we && retire_rd == id_ex.rs2)
            execute_rs2 = retire_rd_data;
    end

    always_comb begin
        decode_rs1_bypassed = decode_rs1;
        if (retire_rd_we && retire_rd == if_id.instr[19:15])
            decode_rs1_bypassed = retire_rd_data;
    end

    assign decode_rs2_bypassed =
        (retire_rd_we && retire_rd == if_id.instr[24:20])
            ? retire_rd_data : decode_rs2;

    always_ff @(posedge clk) begin
        if (reset) begin
            if_id  <= '0;
            id_ex  <= '0;
            ex_mem <= '0;
            mem_wb <= '0;
        end else begin
            if_id <= {1'b1, instr_addr, instr};
            id_ex <= {if_id.valid && decode_supported,
                      if_id.pc,
                      if_id.instr[11:7],   // rd
                      if_id.instr[19:15],  // rs1
                      if_id.instr[24:20],
                      decode_rs1_bypassed,
                      decode_rs2_bypassed,
                      decode_imm,
                      !decode_alu_src,
                      decode_alu_op};
            ex_mem <= {id_ex.valid, id_ex.pc, id_ex.rd, execute_result};
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
