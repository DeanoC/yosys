// Map asynchronous-read M10K library cells to the Mistral primitive.  The
// physical read-enable is tied high because flow-through M10K output is not a
// clocked port; the nextpnr packer routes that constant to ENABLE[0].

module \$__MISTRAL_M10K_ASYNC_10_ (PORT_W_CLK, PORT_W_CLK_EN, PORT_W_ADDR,
    PORT_W_WR_DATA, PORT_W_WR_EN, PORT_R_ADDR, PORT_R_RD_DATA);
parameter INIT = 0;
input PORT_W_CLK, PORT_W_CLK_EN, PORT_W_WR_EN;
input [9:0] PORT_W_ADDR, PORT_R_ADDR;
input [9:0] PORT_W_WR_DATA;
output [9:0] PORT_R_RD_DATA;
wire write_enable = PORT_W_CLK_EN && PORT_W_WR_EN;
MISTRAL_M10K #(.CFG_ABITS(10), .CFG_DBITS(10), .CFG_ASYNC_READ(1),
    .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_W_CLK), .A1ADDR(PORT_W_ADDR), .A1DATA(PORT_W_WR_DATA),
    .A1EN(!write_enable), .B1ADDR(PORT_R_ADDR), .B1DATA(PORT_R_RD_DATA),
    .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0));
endmodule

module \$__MISTRAL_M10K_ASYNC_20_ (PORT_W_CLK, PORT_W_CLK_EN, PORT_W_ADDR,
    PORT_W_WR_DATA, PORT_W_WR_EN, PORT_R_ADDR, PORT_R_RD_DATA);
parameter INIT = 0;
input PORT_W_CLK, PORT_W_CLK_EN, PORT_W_WR_EN;
input [8:0] PORT_W_ADDR, PORT_R_ADDR;
input [19:0] PORT_W_WR_DATA;
output [19:0] PORT_R_RD_DATA;
wire write_enable = PORT_W_CLK_EN && PORT_W_WR_EN;
MISTRAL_M10K #(.CFG_ABITS(9), .CFG_DBITS(20), .CFG_ASYNC_READ(1),
    .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_W_CLK), .A1ADDR(PORT_W_ADDR), .A1DATA(PORT_W_WR_DATA),
    .A1EN(!write_enable), .B1ADDR(PORT_R_ADDR), .B1DATA(PORT_R_RD_DATA),
    .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0));
endmodule

module \$__MISTRAL_M10K_ASYNC_40_ (PORT_W_CLK, PORT_W_CLK_EN, PORT_W_ADDR,
    PORT_W_WR_DATA, PORT_W_WR_EN, PORT_R_ADDR, PORT_R_RD_DATA);
parameter INIT = 0;
input PORT_W_CLK, PORT_W_CLK_EN, PORT_W_WR_EN;
input [7:0] PORT_W_ADDR, PORT_R_ADDR;
input [39:0] PORT_W_WR_DATA;
output [39:0] PORT_R_RD_DATA;
wire write_enable = PORT_W_CLK_EN && PORT_W_WR_EN;
MISTRAL_M10K #(.CFG_ABITS(8), .CFG_DBITS(40), .CFG_ASYNC_READ(1),
    .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_W_CLK), .A1ADDR(PORT_W_ADDR), .A1DATA(PORT_W_WR_DATA),
    .A1EN(write_enable), .B1ADDR(PORT_R_ADDR), .B1DATA(PORT_R_RD_DATA),
    .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0));
endmodule

// Map the two-port flow-through form to the existing true-dual M10K
// primitive.  CFG_ASYNC_READ changes only the output timing; both CLK inputs
// remain live because each physical port can still perform a synchronous
// write.
module \$__MISTRAL_M10K_ASYNC_TDP_ (
    PORT_A_CLK, PORT_A_CLK_EN, PORT_A_ADDR, PORT_A_WR_DATA, PORT_A_WR_EN,
    PORT_A_RD_DATA, PORT_B_CLK, PORT_B_CLK_EN, PORT_B_ADDR,
    PORT_B_WR_DATA, PORT_B_WR_EN, PORT_B_RD_DATA);
parameter WIDTH = 10;
parameter INIT = 0;
localparam SHIFT = $clog2(WIDTH / 10);
input PORT_A_CLK, PORT_A_CLK_EN, PORT_A_WR_EN;
input PORT_B_CLK, PORT_B_CLK_EN, PORT_B_WR_EN;
input [9:0] PORT_A_ADDR, PORT_B_ADDR;
input [WIDTH-1:0] PORT_A_WR_DATA, PORT_B_WR_DATA;
output [WIDTH-1:0] PORT_A_RD_DATA, PORT_B_RD_DATA;
MISTRAL_M10K_TDP #(.CFG_ABITS(10-SHIFT), .CFG_DBITS(WIDTH),
    .CFG_ASYNC_READ(1), .INIT(INIT)) _TECHMAP_REPLACE_ (
    .CLK1(PORT_A_CLK), .CLK2(PORT_B_CLK),
    .A1EN(PORT_A_CLK_EN), .B1EN(PORT_B_CLK_EN),
    .A1WE(PORT_A_WR_EN), .B1WE(PORT_B_WR_EN),
    .A1ADDR(PORT_A_ADDR[9:SHIFT]), .B1ADDR(PORT_B_ADDR[9:SHIFT]),
    .A1DATA(PORT_A_WR_DATA), .B1DATA(PORT_B_WR_DATA),
    .A1Q(PORT_A_RD_DATA), .B1Q(PORT_B_RD_DATA),
    .ACLR0(1'b0), .ACLR1(1'b0));
endmodule
