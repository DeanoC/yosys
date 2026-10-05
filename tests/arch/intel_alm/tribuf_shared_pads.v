module shared_alias(input wire d, en, output wire pad, a_rb);
    wire tri_alias;
    assign tri_alias = en ? d : 1'bz;
    assign pad = tri_alias;
    assign a_rb = tri_alias;
endmodule

module shared_alias_read(input wire d, en,
                         output wire pad, a_rb, pad_rb, other_rb);
    wire tri_alias, branch, alias1, alias2;
    assign tri_alias = en ? d : 1'bz;
    assign branch = tri_alias;
    assign pad = branch;
    assign a_rb = tri_alias;
    // These are actual pad reads, not additional sibling drivers.
    assign alias1 = pad;
    assign pad_rb = alias1;
    assign alias2 = a_rb;
    assign other_rb = alias2;
endmodule

module shared_alias_bus(input wire [1:0] d, input wire en,
                        output wire [1:0] pad, a_rb);
    wire [1:0] tri_alias, branch;
    assign tri_alias = en ? d : 2'bzz;
    assign branch = tri_alias;
    assign pad = branch;
    // Exercise bitwise alias tracing through a concatenation.
    assign a_rb = {tri_alias[0], tri_alias[1]};
endmodule
