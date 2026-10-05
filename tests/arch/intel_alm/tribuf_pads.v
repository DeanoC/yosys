module tribuf_pads(input wire a, en, io_a, io_en, read_a, read_en,
                      output wire o_tri, inout wire io_rb, output wire rb,
                      output wire o_read, output wire o_rb);
    assign o_tri = en ? a : 1'bz;
    assign io_rb = io_en ? io_a : 1'bz;
    assign rb = io_rb;
    // An output that is also read must return the pad, not the driven data.
    assign o_read = read_en ? read_a : 1'bz;
    assign o_rb = o_read;
endmodule
