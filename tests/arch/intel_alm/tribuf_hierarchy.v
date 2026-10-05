module tribuf_child(input wire d, en, output wire pad, rb);
    assign pad = en ? d : 1'bz;
    assign rb = pad;
endmodule

module tribuf_hierarchy(input wire d, en,
                        output wire child_pad, child_rb, top_pad, top_rb);
    tribuf_child child(d, en, child_pad, child_rb);
    assign top_pad = en ? d : 1'bz;
    assign top_rb = top_pad;
endmodule
