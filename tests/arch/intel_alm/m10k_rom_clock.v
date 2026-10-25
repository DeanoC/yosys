module m10k_rom_clock (
    input clk,
    input [8:0] addr,
    output reg [9:0] q
);
    (* ramstyle = "M10K" *) reg [9:0] mem [0:511];
    integer i;
    initial
        for (i = 0; i < 512; i = i + 1)
            mem[i] = (i * 37) ^ (i >> 2);

    always @(posedge clk)
        q <= mem[addr];
endmodule

module m10k_const1_clock (
    input clk,
    output [9:0] q
);
    MISTRAL_M10K #(
        .CFG_ABITS(10), .CFG_DBITS(10), .CFG_DUAL_CLOCK(1)
    ) ram (
        .CLK1(1'b1), .CLK2(clk), .A1ADDR(10'b0), .A1DATA(10'b0),
        .A1EN(1'b1), .A1BE(2'b0), .B1ADDR(10'b0), .B1DATA(q),
        .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0)
    );
endmodule

module m10k_byte_enable_zero_mask_clock (
    input clk,
    output [19:0] q
);
    MISTRAL_M10K #(
        .CFG_ABITS(9), .CFG_DBITS(20), .CFG_BYTE_ENABLE(1), .CFG_DUAL_CLOCK(1)
    ) ram (
        .CLK1(1'b0), .CLK2(clk), .A1ADDR(9'b0), .A1DATA(20'b0),
        .A1EN(1'b1), .A1BE(2'b0), .B1ADDR(9'b0), .B1DATA(q),
        .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0)
    );
endmodule

module m10k_mixed_primitive_clock (
    input clk,
    output [39:0] q
);
    MISTRAL_M10K #(
        .CFG_ABITS(10), .CFG_DBITS(10), .CFG_RD_ABITS(8),
        .CFG_RD_DBITS(40), .CFG_MIXED_WIDTH(1), .CFG_DUAL_CLOCK(1)
    ) ram (
        .CLK1(1'b0), .CLK2(clk), .A1ADDR(10'b0), .A1DATA(10'b0),
        .A1EN(1'b0), .A1BE(2'b0), .B1ADDR(8'b0), .B1DATA(q),
        .B1EN(1'b1), .ACLR0(1'b0), .ACLR1(1'b0)
    );
endmodule
