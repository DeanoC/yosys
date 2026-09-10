// A standard ramstyle=M10K simple dual-port memory with an asynchronous
// active-high clear on its registered read output.
module top (
    input wr_clk, rd_clk, arst, wr_en, rd_en,
    input [8:0] wr_addr, rd_addr,
    input [19:0] wr_data,
    output reg [19:0] rd_data
);
    (* ramstyle = "M10K" *) reg [19:0] mem [0:511];

    always @(posedge wr_clk)
        if (wr_en)
            mem[wr_addr] <= wr_data;

    always @(posedge rd_clk or posedge arst)
        if (arst)
            rd_data <= 20'd0;
        else if (rd_en)
            rd_data <= mem[rd_addr];
endmodule
