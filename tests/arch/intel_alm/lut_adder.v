// Issue #39: a 5-bit add. Default synthesis maps it to a carry chain.
module top(input [4:0] a, input [4:0] b, output [4:0] y);
    assign y = a + b;
endmodule

module narrow_sub(input [4:0] a, input [4:0] b, output [4:0] y);
    assign y = a - b;
endmodule

// Wider than -lutadders 5, so it stays on the carry chain.
module wide_add(input [15:0] a, input [15:0] b, output [15:0] y);
    assign y = a + b;
endmodule

// Same module: the narrow sum follows -lutadders, the wide sum does not.
module mixed(input [4:0] a, input [4:0] b, input [15:0] c, input [15:0] d,
             output [4:0] y, output [15:0] z);
    assign y = a + b;
    assign z = c + d;
endmodule

// 8 bits would be a carry chain at the default threshold.
module attr_soft(input [7:0] a, input [7:0] b, output [7:0] y);
    assign y = a + (* no_carry *) b;
endmodule

module attr_carry(input [4:0] a, input [4:0] b, output [4:0] y);
    assign y = a + (* use_carry *) b;
endmodule

module wire_soft(input [7:0] a, input [7:0] b, (* no_carry *) output [7:0] y);
    assign y = a + b;
endmodule
