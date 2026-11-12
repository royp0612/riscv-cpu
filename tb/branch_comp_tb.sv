`timescale 1ns/1ps
module branch_comp_tb;
    logic [31:0] a, b;
    logic [2:0] branch_type;
    logic taken;
    integer checks = 0;

    branch_comp dut(.a(a), .b(b), .branch_type(branch_type), .taken(taken));

    task automatic check(input logic [2:0] kind,
                         input logic [31:0] lhs, rhs,
                         input logic expected,
                         input string name);
        a = lhs;
        b = rhs;
        branch_type = kind;
        #1;
        if (taken !== expected)
            $fatal(1, "%s: a=%h b=%h expected=%b got=%b", name, a, b, expected, taken);
        checks = checks + 1;
    endtask

    initial begin
        check(3'b000, 1, 1, 1, "BEQ equal");
        check(3'b000, 1, 0, 0, "BEQ unequal");
        check(3'b001, 1, 0, 1, "BNE unequal");
        check(3'b001, 1, 1, 0, "BNE equal");
        check(3'b100, 32'hFFFFFFFF, 0, 1, "BLT negative");
        check(3'b100, 0, 32'hFFFFFFFF, 0, "BLT reversed");
        check(3'b100, 1, 1, 0, "BLT equal");
        check(3'b100, 32'h80000000, 32'h7FFFFFFF, 1, "BLT extremes");
        check(3'b101, 0, 32'hFFFFFFFF, 1, "BGE signed");
        check(3'b101, 32'hFFFFFFFF, 0, 0, "BGE reversed");
        check(3'b101, 1, 1, 1, "BGE equal");
        check(3'b101, 32'h80000000, 32'h7FFFFFFF, 0, "BGE extremes");
        check(3'b110, 0, 1, 1, "BLTU less");
        check(3'b110, 32'hFFFFFFFF, 0, 0, "BLTU unsigned");
        check(3'b110, 1, 1, 0, "BLTU equal");
        check(3'b110, 32'h7FFFFFFF, 32'h80000000, 1, "BLTU boundary");
        check(3'b111, 32'hFFFFFFFF, 0, 1, "BGEU unsigned");
        check(3'b111, 0, 1, 0, "BGEU less");
        check(3'b111, 1, 1, 1, "BGEU equal");
        check(3'b111, 32'h7FFFFFFF, 32'h80000000, 0, "BGEU boundary");
        check(3'b000, 0, 0, 1, "BEQ before invalid");
        check(3'b010, 0, 0, 0, "Invalid 010");
        check(3'b000, 0, 0, 1, "BEQ before second invalid");
        check(3'b011, 0, 0, 0, "Invalid 011");
        $display("PASS: all %0d branch comparator checks", checks);
        $finish;
    end
endmodule
