module tribuf_mixed_pads(input wire d, en, x,
                        output wire [1:0] pad, pad_hi,
                        output wire rb, rb_hi);
    assign pad[0] = en ? d : 1'bz;
    assign pad[1] = x;
    assign rb = pad[0];
    // Also cover a tri-state bit encountered after an always-driven bit.
    assign pad_hi[0] = x;
    assign pad_hi[1] = en ? d : 1'bz;
    assign rb_hi = pad_hi[1];
endmodule
