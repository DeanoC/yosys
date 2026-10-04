module tribuf_pads(input wire a, input wire en, output wire o_tri, inout wire io_rb, output wire rb);
    assign o_tri = en ? a : 1'bz;
    assign io_rb = en ? a : 1'bz;
    assign rb = io_rb;
endmodule
