module top (
    input clk, aclr0, aclr1,
    input [8:0] addr,
    input [19:0] data,
    output [19:0] sdp_q, tdp_aq, tdp_bq
);
    (* keep *) MISTRAL_M10K #(.CFG_ABITS(9), .CFG_DBITS(20)) sdp (
        .CLK1(clk), .CLK2(clk), .A1ADDR(addr), .A1DATA(data), .A1EN(1'b1),
        .A1BE(2'b11), .B1ADDR(addr), .B1DATA(sdp_q), .B1EN(1'b1),
        .ACLR0(aclr0), .ACLR1(aclr1)
    );
    (* keep *) MISTRAL_M10K_TDP #(.CFG_ABITS(9), .CFG_DBITS(20)) tdp (
        .CLK1(clk), .CLK2(clk), .A1ADDR(addr), .B1ADDR(addr),
        .A1DATA(data), .B1DATA(data), .A1Q(tdp_aq), .B1Q(tdp_bq),
        .A1EN(1'b1), .B1EN(1'b1), .A1WE(1'b0), .B1WE(1'b0),
        .A1BE(2'b11), .B1BE(2'b11), .ACLR0(aclr0), .ACLR1(aclr1)
    );
endmodule
