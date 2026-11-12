module core(
    input logic clk,
    input logic reset,
    output logic [31:0] instr_addr,
    input  logic [31:0] instr,
    output logic [31:0] data_addr,
    output logic [31:0] data_write,
    input  logic [31:0] data_read,
    output logic        mem_read,
    output logic        mem_write,
    output logic [3:0]  data_byte_en
    );
    import cpu_pkg::*;
    // Program counter
    logic [31:0] pc_in, pc_out, pc_plus4;

    // Register file
    logic [31:0] rd1, rd2, write_data;

    // Immediate generator
    logic [31:0] imm;
    logic [2:0] imm_type;

    // ALU
    logic [31:0] alu_a, alu_b, alu_result;
    logic [3:0] alu_op;
    logic alu_src, alu_a_sel;

    // Decoder
    logic reg_write, branch, jump, jalr, valid;
    logic decoded_mem_read, decoded_mem_write;
    logic [1:0] wb_sel, mem_size;
    logic mem_unsigned;

    // Branch comparator
    logic branch_taken;

    // Load processing
    logic [31:0] load_shifted, load_data;

    pc pc_inst(
        .clk (clk),
        .reset(reset),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );
    assign instr_addr = pc_out;
    assign pc_plus4   = pc_out + 32'd4;`
    assign pc_in      = jalr ? (alu_result & 32'hFFFFFFFE) : (jump||(branch && branch_taken)) ? (pc_out+imm):pc_plus4;

    decoder decoder_inst(
        .instr        (instr),
        .alu_op       (alu_op),
        .imm_type     (imm_type),
        .alu_src      (alu_src),
        .alu_a_sel    (alu_a_sel),
        .reg_write    (reg_write),
        .mem_read     (decoded_mem_read),
        .mem_write    (decoded_mem_write),
        .mem_size     (mem_size),
        .mem_unsigned (mem_unsigned),
        .wb_sel       (wb_sel),
        .branch       (branch),
        .jump         (jump),
        .jalr         (jalr),
        .valid        (valid)
    );

    regfile regfile_inst (
        .clk (clk),
        .we  (reg_write && !reset),
        .rs1 (instr[19:15]),
        .rs2 (instr[24:20]),
        .rd  (instr[11:7]),
        .wd  (write_data),
        .rd1 (rd1),
        .rd2 (rd2)
    );
    imm_gen imm_inst (
        .instr(instr),
        .imm_type(imm_type),
        .imm(imm)
    );
    assign alu_a = alu_a_sel ? pc_out : rd1;
    assign alu_b = alu_src ? imm : rd2;

    alu alu_inst(
        .op(alu_op),
        .a (alu_a),
        .b (alu_b),
        .y (alu_result)
    );
    branch_comp branch_comp_inst(
        .a(rd1),
        .b(rd2),
        .branch_type(instr[14:12]),
        .taken(branch_taken)
    );
    always_comb begin
        case(wb_sel)
            WB_ALU: write_data = alu_result;
            WB_MEM: write_data = load_data;
            WB_PC4: write_data = pc_plus4;
            default: write_data = 32'd0;
        endcase
    end
    //DATA ASSIGNMENTS
    assign data_addr = alu_result;
    assign mem_read  = decoded_mem_read  && !reset;
    assign mem_write = decoded_mem_write && !reset; 
    assign load_shifted = data_read >> (data_addr[1:0] * 8);
    always_comb begin
        case (mem_size)
            2'b00: load_data = mem_unsigned
                ? {24'd0, load_shifted[7:0]}
                : {{24{load_shifted[7]}}, load_shifted[7:0]};

            2'b01: load_data = mem_unsigned
                ? {16'd0, load_shifted[15:0]}
                : {{16{load_shifted[15]}}, load_shifted[15:0]};

            2'b10: load_data = load_shifted;

            default: load_data = 32'd0;
        endcase
    end
    assign data_write = rd2 << (data_addr[1:0] * 8);

    always_comb begin
        data_byte_en = 4'b0000;

        if (mem_write) begin
            case (mem_size)
                2'b00: data_byte_en = 4'b0001 << data_addr[1:0]; // SB
                2'b01: data_byte_en = 4'b0011 << data_addr[1:0]; // SH
                2'b10: data_byte_en = 4'b1111;                  // SW
                default: data_byte_en = 4'b0000;
            endcase
        end
    end




endmodule
