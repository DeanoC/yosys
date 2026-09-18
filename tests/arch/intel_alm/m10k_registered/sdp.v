// Single-write, registered-read SDP. Must not become CFG_ASYNC_READ.
module sdp (
    input wire wr_clk,
    input wire rd_clk,
    input wire wr_en,
    input wire [9:0] wr_addr,
    input wire [9:0] wr_data,
    input wire [9:0] rd_addr,
    output wire [9:0] rd_data
);
    (* ramstyle = "M10K" *) reg [9:0] ram [0:1023];
    reg [9:0] q_r;

    always @(posedge wr_clk)
        if (wr_en)
            ram[wr_addr] <= wr_data;

    always @(posedge rd_clk)
        q_r <= ram[rd_addr];

    assign rd_data = q_r;
endmodule
