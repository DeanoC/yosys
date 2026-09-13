// Standard ramstyle=M10K SDP with a registered read-output asynchronous
// clear.  The physical M10K output-clear lane for this SDP configuration is
// ACLR1; ACLR0 is explicitly inactive.
module \$__MISTRAL_M10K_ACLR_BYTE_ (PORT_W_CLK, PORT_W_CLK_EN, PORT_W_ADDR,
    PORT_W_WR_DATA, PORT_W_WR_EN, PORT_W_WR_BE, PORT_R_CLK, PORT_R_CLK_EN,
    PORT_R_ADDR, PORT_R_RD_DATA, PORT_R_RD_EN, PORT_R_RD_ARST);
parameter INIT = 0;
input PORT_W_CLK, PORT_W_CLK_EN, PORT_R_CLK, PORT_R_CLK_EN;
input PORT_W_WR_EN, PORT_R_RD_EN, PORT_R_RD_ARST;
input [1:0] PORT_W_WR_BE;
input [8:0] PORT_W_ADDR, PORT_R_ADDR;
input [19:0] PORT_W_WR_DATA;
output [19:0] PORT_R_RD_DATA;
// MISTRAL_M10K has one active-high write-enable input rather than separate
// clock and write enables, so preserve both logical conditions here.
wire write_enable = PORT_W_CLK_EN && PORT_W_WR_EN;
MISTRAL_M10K #(.CFG_ABITS(9), .CFG_DBITS(20), .CFG_BYTE_ENABLE(1),
    .CFG_DUAL_CLOCK(1), .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_W_CLK), .CLK2(PORT_R_CLK),
    .A1EN(write_enable), .A1BE(PORT_W_WR_BE),
    .A1ADDR(PORT_W_ADDR), .A1DATA(PORT_W_WR_DATA),
    .B1EN(PORT_R_CLK_EN && PORT_R_RD_EN), .B1ADDR(PORT_R_ADDR),
    .B1DATA(PORT_R_RD_DATA), .ACLR0(1'b0), .ACLR1(PORT_R_RD_ARST));
endmodule

// Whole-word SDP with independently selected 10/20/40-bit port widths.
module \$__MISTRAL_M10K_ACLR_ (PORT_W_CLK, PORT_W_CLK_EN, PORT_W_ADDR,
    PORT_W_WR_DATA, PORT_W_WR_EN, PORT_R_CLK, PORT_R_CLK_EN, PORT_R_ADDR,
    PORT_R_RD_DATA, PORT_R_RD_EN, PORT_R_RD_ARST);
parameter PORT_W_WIDTH = 10;
parameter PORT_R_WIDTH = 40;
parameter INIT = 0;
localparam WSHIFT = $clog2(PORT_W_WIDTH / 10);
localparam RSHIFT = $clog2(PORT_R_WIDTH / 10);
input PORT_W_CLK, PORT_W_CLK_EN, PORT_R_CLK, PORT_R_CLK_EN;
input PORT_W_WR_EN, PORT_R_RD_EN, PORT_R_RD_ARST;
input [9:0] PORT_W_ADDR, PORT_R_ADDR;
input [PORT_W_WIDTH-1:0] PORT_W_WR_DATA;
output [PORT_R_WIDTH-1:0] PORT_R_RD_DATA;
// The physical SDP write lane likewise combines the logical clock and write
// enables before driving A1EN.
wire write_enable = PORT_W_CLK_EN && PORT_W_WR_EN;
MISTRAL_M10K #(.CFG_ABITS(10-WSHIFT), .CFG_DBITS(PORT_W_WIDTH),
    .CFG_RD_ABITS(10-RSHIFT), .CFG_RD_DBITS(PORT_R_WIDTH),
    .CFG_MIXED_WIDTH(1), .CFG_DUAL_CLOCK(1), .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_W_CLK), .CLK2(PORT_R_CLK),
    .A1EN(write_enable), .A1ADDR(PORT_W_ADDR[9:WSHIFT]),
    .A1DATA(PORT_W_WR_DATA), .B1EN(PORT_R_CLK_EN && PORT_R_RD_EN),
    .B1ADDR(PORT_R_ADDR[9:RSHIFT]), .B1DATA(PORT_R_RD_DATA),
    .ACLR0(1'b0), .ACLR1(PORT_R_RD_ARST));
endmodule
