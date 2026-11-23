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
        logic        alu_a_sel;
        logic        mem_read;
        logic        mem_write;
        logic        reg_write;
    } decode_execute_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [4:0]  rd;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [31:0] result;
        logic [31:0] store_data;
    } execute_memory_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [4:0]  rd;
        logic        reg_write;
        logic [31:0] result;
    } memory_writeback_t;

    fetch_decode_t if_id;
    decode_execute_t id_ex;
    execute_memory_t ex_mem;
    memory_writeback_t mem_wb;

    logic [6:0]  decode_opcode;
    logic [3:0]  decode_alu_op;
    logic [2:0]  decode_imm_type;
    logic        decode_alu_src, decode_alu_a_sel, decode_valid, decode_supported;
    logic        decode_mem_read, decode_mem_write, decode_reg_write;
    logic        decode_uses_rs1, decode_uses_rs2, load_use_stall;
    logic        ex_mem_can_forward;
    logic [31:0] decode_rs1, decode_rs2, decode_imm, execute_result;
    logic [31:0] alu_a, decode_rs1_bypassed;
    logic [31:0] execute_rs2, decode_rs2_bypassed;

    pc pc_inst (
        .clk(clk),
        .reset(reset),
        .pc_in(load_use_stall ? instr_addr : instr_addr + 32'd4),
        .pc_out(instr_addr)
    );

    decoder decoder_inst (
        .instr(if_id.instr),
        .alu_op(decode_alu_op),
        .alu_src(decode_alu_src),
        .alu_a_sel(decode_alu_a_sel),
        .imm_type(decode_imm_type),
        .valid(decode_valid),
        .mem_read(decode_mem_read),
        .mem_write(decode_mem_write),
        .reg_write(decode_reg_write)
    );

    assign decode_opcode = if_id.instr[6:0];
    assign decode_supported = decode_valid &&
                              (decode_opcode == cpu_pkg::OP_R ||
                               decode_opcode == cpu_pkg::OP_I ||
                               decode_opcode == cpu_pkg::OP_LUI ||
                               decode_opcode == cpu_pkg::OP_AUIPC ||
                               ((decode_mem_read || decode_mem_write) &&
                                if_id.instr[14:12] == 3'b010));

    assign decode_uses_rs1 = decode_opcode == cpu_pkg::OP_R ||
                             decode_opcode == cpu_pkg::OP_I ||
                             decode_mem_read || decode_mem_write;
    assign decode_uses_rs2 = decode_opcode == cpu_pkg::OP_R || decode_mem_write;
    assign load_use_stall = if_id.valid && decode_supported &&
                            id_ex.valid && id_ex.mem_read && id_ex.rd != 5'd0 &&
                            ((decode_uses_rs1 && if_id.instr[19:15] == id_ex.rd) ||
                             (decode_uses_rs2 && if_id.instr[24:20] == id_ex.rd));

    imm_gen imm_inst (
        .instr(if_id.instr),
        .imm_type(decode_imm_type),
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
        .a(id_ex.alu_a_sel ? id_ex.pc : alu_a),
        .b(id_ex.use_rs2 ? execute_rs2 : id_ex.imm),
        .y(execute_result)
    );

    // A load carries its address through EX/MEM and its loaded value through MEM/WB.
    assign ex_mem_can_forward = ex_mem.valid && ex_mem.reg_write &&
                                !ex_mem.mem_read && ex_mem.rd != 5'd0;

    always_comb begin
        alu_a = id_ex.rs1_value;

        if (retire_rd_we && retire_rd == id_ex.rs1)
            alu_a = retire_rd_data;

        // The newer EX/MEM result takes priority when both stages match.
        if (ex_mem_can_forward && ex_mem.rd == id_ex.rs1)
            alu_a = ex_mem.result;
    end

    always_comb begin
        execute_rs2 = id_ex.rs2_value;

        if (ex_mem_can_forward && ex_mem.rd == id_ex.rs2)
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
            if (load_use_stall) begin
                id_ex <= '0;
            end else begin
                if_id <= {1'b1, instr_addr, instr};
                id_ex <= {if_id.valid && decode_supported,
                          if_id.pc,
                          if_id.instr[11:7],   // rd
                          if_id.instr[19:15],  // rs1
                          if_id.instr[24:20],  // rs2
                          decode_rs1_bypassed,
                          decode_rs2_bypassed,
                          decode_imm,
                          !decode_alu_src,
                          decode_alu_op,
                          decode_alu_a_sel,
                          decode_mem_read,
                          decode_mem_write,
                          decode_reg_write};
            end

            ex_mem <= {id_ex.valid, id_ex.pc, id_ex.rd, id_ex.reg_write,
                       id_ex.mem_read, id_ex.mem_write, execute_result, execute_rs2};
            mem_wb <= {ex_mem.valid, ex_mem.pc, ex_mem.rd, ex_mem.reg_write,
                       (ex_mem.mem_read ? data_read : ex_mem.result)};
        end
    end

    assign data_addr    = ex_mem.result;
    assign data_write   = ex_mem.store_data;
    assign mem_read     = ex_mem.valid && ex_mem.mem_read && !reset;
    assign mem_write    = ex_mem.valid && ex_mem.mem_write && !reset;
    assign data_byte_en = mem_write ? 4'b1111 : 4'b0000;

    assign retire_valid   = mem_wb.valid && !reset;
    assign retire_pc      = mem_wb.pc;
    assign retire_rd_we   = retire_valid && mem_wb.reg_write && mem_wb.rd != 5'd0;
    assign retire_rd      = mem_wb.rd;
    assign retire_rd_data = mem_wb.result;
endmodule
