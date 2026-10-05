module alias_pad_read #(parameter WIDTH = 1)
    (input wire [WIDTH-1:0] d, input wire en,
     output wire [WIDTH-1:0] z_pad, a_rb);
    wire [WIDTH-1:0] t, branch;
    assign t = en ? d : {WIDTH{1'bz}};
    assign branch = t;
    assign z_pad = branch;
    // The earlier name must not take the tri-state driver during cleanup.
    assign a_rb = z_pad;
endmodule

module alias_pad_multiple(input wire d1, d2, en1, en2,
                          output wire z_pad, a_rb);
    wire t, branch;
    assign t = en1 ? d1 : 1'bz;
    assign t = en2 ? d2 : 1'bz;
    assign branch = t;
    assign z_pad = branch;
    assign a_rb = z_pad;
endmodule
