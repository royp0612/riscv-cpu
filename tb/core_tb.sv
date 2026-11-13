`timescale 1ns/1ps

module core_tb;
    logic clk = 0;
    logic reset = 1;

    logic [31:0] instr_addr, instr;
    logic [31:0] data_addr, data_write, data_read;
    logic mem_read, mem_write;
    logic [3:0] data_byte_en;

    always #5 clk = ~clk;

    core dut (
        .clk(clk),
        .reset(reset),
        .instr_addr(instr_addr),
        .instr(instr),
        .data_addr(data_addr),
        .data_write(data_write),
        .data_read(data_read),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .data_byte_en(data_byte_en)
    );

    dmem memory_inst (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .addr(data_addr),
        .write_data(data_write),
        .byte_en(data_byte_en),
        .read_data(data_read)
    );

    integer extended_checks = 0;

    // Wait for the instruction to execute, then sample after <= updates settle.
    task automatic step_check(
        input logic [31:0] expected_pc,
        input logic [4:0] rd,
        input logic [31:0] expected_value,
        input string name
    );
        @(posedge clk);
        #1;
        if (instr_addr !== expected_pc)
            $fatal(1, "%s: expected PC=%h got=%h", name, expected_pc, instr_addr);
        if (rd != 0 && dut.regfile_inst.registers[rd] !== expected_value)
            $fatal(1, "%s: x%0d expected=%h got=%h", name, rd,
                   expected_value, dut.regfile_inst.registers[rd]);
        extended_checks++;
    endtask

    task automatic invalid_check(
        input logic [31:0] expected_pc,
        input string name
    );
        logic [31:0] saved_regs [0:31];
        logic [31:0] saved_word;
        // The preceding step already allowed combinational decode to settle.
        if (dut.valid !== 1'b0 ||
            {dut.reg_write, mem_read, mem_write, dut.branch, dut.jump, dut.jalr}
                !== 6'b0)
            $fatal(1, "%s: unsupported instruction enabled side effects", name);
        for (integer r = 0; r < 32; r++)
            saved_regs[r] = dut.regfile_inst.registers[r];
        saved_word = memory_inst.mem[0];
        step_check(expected_pc, 0, 0, name);
        for (integer r = 0; r < 32; r++)
            if (dut.regfile_inst.registers[r] !== saved_regs[r])
                $fatal(1, "%s: modified x%0d", name, r);
        if (memory_inst.mem[0] !== saved_word)
            $fatal(1, "%s: modified memory", name);
    endtask

    // Small instruction ROM, addressed in bytes.
    always_comb begin
        case (instr_addr)
            32'd0:  instr = 32'h00500093; // addi x1, x0, 5
            32'd4:  instr = 32'h00300113; // addi x2, x0, 3
            32'd8:  instr = 32'h002081B3; // add  x3, x1, x2
            32'd12: instr = 32'h00302023; // sw   x3, 0(x0)
            32'd16: instr = 32'h00002203; // lw   x4, 0(x0)
            32'd20: instr = 32'h00320463; // beq x4, x3, +8 → taken
            32'd24: instr = 32'h06300293; // addi x5, x0, 99 → skipped
            32'd28: instr = 32'h00700293; // addi x5, x0, 7
            32'd32: instr = 32'h00321463; // bne x4, x3, +8 → not taken
            32'd36: instr = 32'h00900313; // addi x6, x0, 9
            32'd40: instr = 32'h008003EF; // jal  x7, +8     → PC=48, x7=44
            32'd44: instr = 32'h06300513; // addi x10, x0, 99 → skipped
            32'd48: instr = 32'h04900413; // addi x8, x0, 73
            32'd52: instr = 32'h000404E7; // jalr x9, 0(x8)  → PC=72, x9=56
            32'd56: instr = 32'h06300513; // addi x10, x0, 99 → skipped
            32'd72: instr = 32'h00B00513; // addi x10, x0, 11
            32'd76:  instr = 32'hF8000593; // addi x11, x0, -128
            32'd80:  instr = 32'h00002223; // sw   x0, 4(x0)
            32'd84:  instr = 32'h00B002A3; // sb   x11, 5(x0)
            32'd88:  instr = 32'h00500603; // lb   x12, 5(x0)
            32'd92:  instr = 32'h00504683; // lbu  x13, 5(x0)
            32'd96:  instr = 32'h00B01323; // sh   x11, 6(x0)
            32'd100: instr = 32'h00601703; // lh   x14, 6(x0)
            32'd104: instr = 32'h00605783; // lhu  x15, 6(x0)
            32'd108: instr = 32'h12345837; // lui   x16, 0x12345
            32'd112: instr = 32'h00001897; // auipc x17, 0x1
            32'd116: instr = 32'h00300913; // addi x18, x0, 3
            32'd120: instr = 32'hFFF90913; // addi x18, x18, -1
            32'd124: instr = 32'hFE091EE3; // bne  x18, x0, -4 → back to 120
            32'd128: instr = 32'h06300013; // addi x0, x0, 99 → write ignored
            32'd132: instr = 32'h00100993; // addi x19, x0, 1 → must produce 1

            32'd136: instr = 32'hF8000A13; // addi x20, x0, -128
            32'd140: instr = 32'h00300A93; // addi x21, x0, 3
            32'd144: instr = 32'h80000B37; // lui x22, 0x80000
            32'd148: instr = 32'h01F00B93; // addi x23, x0, 31
            32'd152: instr = 32'h02100C13; // addi x24, x0, 33
            32'd156: instr = 32'hFFFB0C93; // addi x25, x22, -1 (wraparound)
            32'd160: instr = 32'h015A0DB3; // add signed
            32'd164: instr = 32'h40208DB3; // sub
            32'd168: instr = 32'h015A1DB3; // sll
            32'd172: instr = 32'h015A2DB3; // slt signed
            32'd176: instr = 32'h015A3DB3; // sltu unsigned
            32'd180: instr = 32'h015A4DB3; // xor
            32'd184: instr = 32'h015A5DB3; // srl
            32'd188: instr = 32'h415A5DB3; // sra
            32'd192: instr = 32'h015A6DB3; // or
            32'd196: instr = 32'h015A7DB3; // and
            32'd200: instr = 32'h018A9DB3; // sll masks shift count to five bits
            32'd204: instr = 32'h018A5DB3; // srl masks shift count to five bits
            32'd208: instr = 32'h418A5DB3; // sra masks shift count to five bits
            32'd212: instr = 32'h017A9DB3; // sll by 31
            32'd216: instr = 32'h000A1DB3; // sll by zero
            32'd220: instr = 32'h015AADB3; // slt equality
            32'd224: instr = 32'h015ABDB3; // sltu equality
            32'd228: instr = 32'h015B2DB3; // slt minimum signed
            32'd232: instr = 32'h015B3DB3; // sltu high bit
            32'd236: instr = 32'h013C8DB3; // add signed overflow wraps
            32'd240: instr = 32'h005A0D93; // addi negative operand
            32'd244: instr = 32'h000A2D93; // slti signed negative
            32'd248: instr = 32'h000A3D93; // sltiu unsigned
            32'd252: instr = 32'hFFFABD93; // sltiu sign extends immediate
            32'd256: instr = 32'hFFFA4D93; // xori negative immediate
            32'd260: instr = 32'h00FA6D93; // ori
            32'd264: instr = 32'h0FFA7D93; // andi
            32'd268: instr = 32'h003A9D93; // slli
            32'd272: instr = 32'h003A5D93; // srli
            32'd276: instr = 32'h403A5D93; // srai
            32'd280: instr = 32'h01FA5D93; // srli by 31
            32'd284: instr = 32'h41FA5D93; // srai by 31
            32'd288: instr = 32'h000A9D93; // slli by zero
            32'd292: instr = 32'h015A8463; // beq equal taken
            32'd300: instr = 32'h015A0463; // beq unequal not taken
            32'd304: instr = 32'h015A1463; // bne unequal taken
            32'd312: instr = 32'h015A9463; // bne equal not taken
            32'd316: instr = 32'h015A4463; // blt signed taken
            32'd324: instr = 32'h014AC463; // blt signed not taken
            32'd328: instr = 32'h015AC463; // blt equal not taken
            32'd332: instr = 32'h014AD463; // bge signed taken
            32'd340: instr = 32'h015A5463; // bge signed not taken
            32'd344: instr = 32'h015AD463; // bge equal taken
            32'd352: instr = 32'h014AE463; // bltu unsigned taken
            32'd360: instr = 32'h015A6463; // bltu unsigned not taken
            32'd364: instr = 32'h015AE463; // bltu equal not taken
            32'd368: instr = 32'h015A7463; // bgeu unsigned taken
            32'd376: instr = 32'h014AF463; // bgeu unsigned not taken
            32'd380: instr = 32'h015AF463; // bgeu equal taken
            32'd388: instr = 32'h019B4463; // blt signed extremes
            32'd396: instr = 32'h019B7463; // bgeu unsigned boundary
            32'd404: instr = 32'h12345A37; // lui memory pattern
            32'd408: instr = 32'h678A0A13; // addi memory pattern
            32'd412: instr = 32'h01402823; // sw memory pattern
            32'd416: instr = 32'h01004D83; // lbu lane 0
            32'd420: instr = 32'h01104D83; // lbu lane 1
            32'd424: instr = 32'h01204D83; // lbu lane 2
            32'd428: instr = 32'h01304D83; // lbu lane 3
            32'd432: instr = 32'h01001D83; // lh lower halfword
            32'd436: instr = 32'h01201D83; // lh upper halfword
            32'd440: instr = 32'hFFF00A93; // addi byte pattern
            32'd444: instr = 32'h01500823; // sb lane 0
            32'd448: instr = 32'h015008A3; // sb lane 1
            32'd452: instr = 32'h01500923; // sb lane 2
            32'd456: instr = 32'h015009A3; // sb lane 3
            32'd460: instr = 32'h01401823; // sh lower halfword
            32'd464: instr = 32'h01401923; // sh upper halfword
            32'd468: instr = 32'h01002D83; // lw after partial stores
            32'd472: instr = 32'h01800B13; // addi base for negative offset
            32'd476: instr = 32'hFF8B2D83; // lw negative offset
            32'd480: instr = 32'hFF4B2C23; // sw negative offset
            32'd484: instr = 32'hFFFFFFFF; // unknown opcode
            32'd488: instr = 32'h035A0DB3; // unsupported multiply encoding
            32'd492: instr = 32'h020A1D93; // illegal shift immediate
            32'd496: instr = 32'h00003D83; // illegal load size
            32'd500: instr = 32'h01403023; // illegal store size
            32'd504: instr = 32'h015A2463; // illegal branch condition
            32'd508: instr = 32'h000A1DE7; // illegal jalr funct3
            32'd512: instr = 32'h02A00093; // addi sentinel before reset
            32'd516: instr = 32'h00102023; // Pending store must be blocked by reset.
            default: instr = 32'h00000013; // nop
        endcase
    end

    initial begin
        // Hold reset through two rising edges.
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        // Execute the five instructions.
        repeat (5) @(posedge clk);
        #1; // Wait for clocked updates to settle.
        @(posedge clk);
        #1;
        if(instr_addr !== 32'd28)
            $fatal(1,"BEQ failed expected pc 28");
        @(posedge clk);
        @(posedge clk);
        #1;

        if (instr_addr!==32'd36)
            $fatal(1, "PC supposed to be 36");
        @(posedge clk);
        #1;
        if (memory_inst.mem[0] !== 32'd8)
            $fatal(1, "Store failed: expected memory[0] = 8");

        if (dut.regfile_inst.registers[4] !== 32'd8)
            $fatal(1, "Load failed: expected x4 = 8");

        if (dut.regfile_inst.registers[5] !== 32'd7)
            $fatal(1, "Expected x5 = 7");

        if (dut.regfile_inst.registers[6] !== 32'd9)
            $fatal(1, "Expected x6 = 9");
        // Execute JAL at address 40.
        @(posedge clk);
        #1;

        if (instr_addr !== 32'd48)
            $fatal(1, "JAL target should be 48");

        if (dut.regfile_inst.registers[7] !== 32'd44)
            $fatal(1, "JAL return address should be 44");

        // Execute ADDI at 48, then JALR at 52.
        @(posedge clk);
        @(posedge clk);
        #1;

        if (instr_addr !== 32'd72)
            $fatal(1, "JALR target should be 72");

        if (dut.regfile_inst.registers[9] !== 32'd56)
            $fatal(1, "JALR return address should be 56");

        // Execute the instruction at the jump target.
        @(posedge clk);
        #1;

        if (dut.regfile_inst.registers[10] !== 32'd11)
            $fatal(1, "Expected x10 = 11");
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;
        if (dut.regfile_inst.registers[12] !== 32'hFFFFFF80)
            $fatal(1, "LB failed");

        if (dut.regfile_inst.registers[13] !== 32'h00000080)
            $fatal(1, "LBU failed");

        if (dut.regfile_inst.registers[14] !== 32'hFFFFFF80)
            $fatal(1, "LH failed");

        if (dut.regfile_inst.registers[15] !== 32'h0000FF80)
            $fatal(1, "LHU failed");

        if (memory_inst.mem[1] !== 32'hFF808000)
            $fatal(1, "SB/SH memory contents incorrect");

        @(posedge clk);
        @(posedge clk);
        #1;

        if (dut.regfile_inst.registers[16] !== 32'h12345000)
            $fatal(1, "LUI failed");

        if (dut.regfile_inst.registers[17] !== 32'h00001070)
            $fatal(1, "AUIPC failed");
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1;

        if (dut.regfile_inst.registers[18] !== 32'd0)
            $fatal(1, "Loop failed: expected x18 = 0");

        if (instr_addr !== 32'd128)
            $fatal(1, "Loop failed: expected PC = 128");

        @(posedge clk);
        @(posedge clk);
        #1;
        if (dut.regfile_inst.registers[19] !== 32'd1)
            $fatal(1, "x0 test failed: expected x19 = 1");

        step_check(32'd140, 5'd20, 32'hFFFFFF80, "addi x20, x0, -128");
        step_check(32'd144, 5'd21, 32'h00000003, "addi x21, x0, 3");
        step_check(32'd148, 5'd22, 32'h80000000, "lui x22, 0x80000");
        step_check(32'd152, 5'd23, 32'h0000001F, "addi x23, x0, 31");
        step_check(32'd156, 5'd24, 32'h00000021, "addi x24, x0, 33");
        step_check(32'd160, 5'd25, 32'h7FFFFFFF, "addi x25, x22, -1 (wraparound)");
        step_check(32'd164, 5'd27, 32'hFFFFFF83, "add signed");
        step_check(32'd168, 5'd27, 32'h00000002, "sub");
        step_check(32'd172, 5'd27, 32'hFFFFFC00, "sll");
        step_check(32'd176, 5'd27, 32'h00000001, "slt signed");
        step_check(32'd180, 5'd27, 32'h00000000, "sltu unsigned");
        step_check(32'd184, 5'd27, 32'hFFFFFF83, "xor");
        step_check(32'd188, 5'd27, 32'h1FFFFFF0, "srl");
        step_check(32'd192, 5'd27, 32'hFFFFFFF0, "sra");
        step_check(32'd196, 5'd27, 32'hFFFFFF83, "or");
        step_check(32'd200, 5'd27, 32'h00000000, "and");
        step_check(32'd204, 5'd27, 32'h00000006, "sll masks shift count to five bits");
        step_check(32'd208, 5'd27, 32'h7FFFFFC0, "srl masks shift count to five bits");
        step_check(32'd212, 5'd27, 32'hFFFFFFC0, "sra masks shift count to five bits");
        step_check(32'd216, 5'd27, 32'h80000000, "sll by 31");
        step_check(32'd220, 5'd27, 32'hFFFFFF80, "sll by zero");
        step_check(32'd224, 5'd27, 32'h00000000, "slt equality");
        step_check(32'd228, 5'd27, 32'h00000000, "sltu equality");
        step_check(32'd232, 5'd27, 32'h00000001, "slt minimum signed");
        step_check(32'd236, 5'd27, 32'h00000000, "sltu high bit");
        step_check(32'd240, 5'd27, 32'h80000000, "add signed overflow wraps");
        step_check(32'd244, 5'd27, 32'hFFFFFF85, "addi negative operand");
        step_check(32'd248, 5'd27, 32'h00000001, "slti signed negative");
        step_check(32'd252, 5'd27, 32'h00000000, "sltiu unsigned");
        step_check(32'd256, 5'd27, 32'h00000001, "sltiu sign extends immediate");
        step_check(32'd260, 5'd27, 32'h0000007F, "xori negative immediate");
        step_check(32'd264, 5'd27, 32'hFFFFFF8F, "ori");
        step_check(32'd268, 5'd27, 32'h00000080, "andi");
        step_check(32'd272, 5'd27, 32'h00000018, "slli");
        step_check(32'd276, 5'd27, 32'h1FFFFFF0, "srli");
        step_check(32'd280, 5'd27, 32'hFFFFFFF0, "srai");
        step_check(32'd284, 5'd27, 32'h00000001, "srli by 31");
        step_check(32'd288, 5'd27, 32'hFFFFFFFF, "srai by 31");
        step_check(32'd292, 5'd27, 32'h00000003, "slli by zero");
        step_check(32'd300, 5'd0, 32'h00000000, "beq equal taken");
        step_check(32'd304, 5'd0, 32'h00000000, "beq unequal not taken");
        step_check(32'd312, 5'd0, 32'h00000000, "bne unequal taken");
        step_check(32'd316, 5'd0, 32'h00000000, "bne equal not taken");
        step_check(32'd324, 5'd0, 32'h00000000, "blt signed taken");
        step_check(32'd328, 5'd0, 32'h00000000, "blt signed not taken");
        step_check(32'd332, 5'd0, 32'h00000000, "blt equal not taken");
        step_check(32'd340, 5'd0, 32'h00000000, "bge signed taken");
        step_check(32'd344, 5'd0, 32'h00000000, "bge signed not taken");
        step_check(32'd352, 5'd0, 32'h00000000, "bge equal taken");
        step_check(32'd360, 5'd0, 32'h00000000, "bltu unsigned taken");
        step_check(32'd364, 5'd0, 32'h00000000, "bltu unsigned not taken");
        step_check(32'd368, 5'd0, 32'h00000000, "bltu equal not taken");
        step_check(32'd376, 5'd0, 32'h00000000, "bgeu unsigned taken");
        step_check(32'd380, 5'd0, 32'h00000000, "bgeu unsigned not taken");
        step_check(32'd388, 5'd0, 32'h00000000, "bgeu equal taken");
        step_check(32'd396, 5'd0, 32'h00000000, "blt signed extremes");
        step_check(32'd404, 5'd0, 32'h00000000, "bgeu unsigned boundary");
        step_check(32'd408, 5'd20, 32'h12345000, "lui memory pattern");
        step_check(32'd412, 5'd20, 32'h12345678, "addi memory pattern");
        step_check(32'd416, 5'd0, 32'h00000000, "sw memory pattern");
        if (memory_inst.mem[4] !== 32'h12345678)
            $fatal(1, "sw memory pattern: incorrect memory byte lanes");
        step_check(32'd420, 5'd27, 32'h00000078, "lbu lane 0");
        step_check(32'd424, 5'd27, 32'h00000056, "lbu lane 1");
        step_check(32'd428, 5'd27, 32'h00000034, "lbu lane 2");
        step_check(32'd432, 5'd27, 32'h00000012, "lbu lane 3");
        step_check(32'd436, 5'd27, 32'h00005678, "lh lower halfword");
        step_check(32'd440, 5'd27, 32'h00001234, "lh upper halfword");
        step_check(32'd444, 5'd21, 32'hFFFFFFFF, "addi byte pattern");
        step_check(32'd448, 5'd0, 32'h00000000, "sb lane 0");
        if (memory_inst.mem[4] !== 32'h123456FF)
            $fatal(1, "sb lane 0: incorrect memory byte lanes");
        step_check(32'd452, 5'd0, 32'h00000000, "sb lane 1");
        if (memory_inst.mem[4] !== 32'h1234FFFF)
            $fatal(1, "sb lane 1: incorrect memory byte lanes");
        step_check(32'd456, 5'd0, 32'h00000000, "sb lane 2");
        if (memory_inst.mem[4] !== 32'h12FFFFFF)
            $fatal(1, "sb lane 2: incorrect memory byte lanes");
        step_check(32'd460, 5'd0, 32'h00000000, "sb lane 3");
        if (memory_inst.mem[4] !== 32'hFFFFFFFF)
            $fatal(1, "sb lane 3: incorrect memory byte lanes");
        step_check(32'd464, 5'd0, 32'h00000000, "sh lower halfword");
        if (memory_inst.mem[4] !== 32'hFFFF5678)
            $fatal(1, "sh lower halfword: incorrect memory byte lanes");
        step_check(32'd468, 5'd0, 32'h00000000, "sh upper halfword");
        if (memory_inst.mem[4] !== 32'h56785678)
            $fatal(1, "sh upper halfword: incorrect memory byte lanes");
        step_check(32'd472, 5'd27, 32'h56785678, "lw after partial stores");
        step_check(32'd476, 5'd22, 32'h00000018, "addi base for negative offset");
        step_check(32'd480, 5'd27, 32'h56785678, "lw negative offset");
        step_check(32'd484, 5'd0, 32'h00000000, "sw negative offset");
        if (memory_inst.mem[4] !== 32'h12345678)
            $fatal(1, "sw negative offset: incorrect memory byte lanes");
        invalid_check(32'd488, "unknown opcode");
        invalid_check(32'd492, "unsupported multiply encoding");
        invalid_check(32'd496, "illegal shift immediate");
        invalid_check(32'd500, "illegal load size");
        invalid_check(32'd504, "illegal store size");
        invalid_check(32'd508, "illegal branch condition");
        invalid_check(32'd512, "illegal jalr funct3");
        step_check(32'd516, 5'd1, 32'h0000002A, "addi sentinel before reset");
        // Reset while a store is pending. Then hold reset while PC=0
        // presents an ADDI that would otherwise overwrite x1.
        @(negedge clk);
        reset = 1'b1;
        #1;
        if ({mem_read, mem_write, data_byte_en} !== 6'b0)
            $fatal(1, "Reset failed to suppress memory controls");
        repeat (2) begin
            @(posedge clk);
            #1;
            if (instr_addr !== 32'd0)
                $fatal(1, "Reset failed to return PC to zero");
            if (dut.regfile_inst.registers[1] !== 32'd42)
                $fatal(1, "Register write occurred during reset");
            if (memory_inst.mem[0] !== 32'd8)
                $fatal(1, "Memory write occurred during reset");
        end
        $display("PASS: core integration tests, including %0d extended instruction checks and reset", extended_checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Timeout");
    end
endmodule
