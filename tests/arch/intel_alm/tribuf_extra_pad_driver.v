module extra_pad_driver #(parameter WIDTH = 1, INTERMEDIATE = 0)
    (input wire [WIDTH-1:0] d1, input wire d2, en1, en2,
     output wire [WIDTH-1:0] pad, other_pad);
    wire [WIDTH-1:0] t, branch;
    assign t = en1 ? d1 : {WIDTH{1'bz}};
    assign branch = t;
    assign pad = branch;
    assign other_pad = t;
    // This driver belongs only to pad and must survive sibling splitting.
    generate
        if (INTERMEDIATE)
            assign branch[0] = en2 ? d2 : 1'bz;
        else
            assign pad[0] = en2 ? d2 : 1'bz;
    endgenerate
endmodule
