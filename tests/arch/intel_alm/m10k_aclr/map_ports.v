// Exercise the reset-aware techmap wrapper with independent clock-enable and
// read-enable inputs.  The physical M10K SDP has one read enable, so both
// logical conditions must reach B1EN.
module top (
    input wr_clk, wr_clk_en, wr_en,
    input rd_clk, rd_clk_en, rd_en, arst,
    input [8:0] wr_addr, rd_addr,
    input [19:0] wr_data,
    output [19:0] rd_data
);
    \$__MISTRAL_M10K_ACLR_BYTE_ #(.INIT(0)) mem (
        .PORT_W_CLK(wr_clk), .PORT_W_CLK_EN(wr_clk_en),
        .PORT_W_ADDR(wr_addr), .PORT_W_WR_DATA(wr_data),
        .PORT_W_WR_EN(wr_en), .PORT_W_WR_BE({wr_en, wr_en}),
        .PORT_R_CLK(rd_clk), .PORT_R_CLK_EN(rd_clk_en),
        .PORT_R_ADDR(rd_addr), .PORT_R_RD_DATA(rd_data),
        .PORT_R_RD_EN(rd_en), .PORT_R_RD_ARST(arst)
    );
endmodule
