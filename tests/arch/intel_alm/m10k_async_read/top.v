// A single-write, combinational-read Cyclone V M10K candidate.
module top #(
    parameter WIDTH = 20,
    parameter ABITS = 9
) (
    input wire clk,
    input wire wr_en,
    input wire [ABITS-1:0] wr_addr,
    input wire [WIDTH-1:0] wr_data,
    input wire [ABITS-1:0] rd_addr,
    output wire [WIDTH-1:0] rd_data
);
    (* ramstyle = "M10K" *) reg [WIDTH-1:0] mem [0:(1 << ABITS)-1];
    integer address;

    initial
        for (address = 0; address < (1 << ABITS); address = address + 1)
            mem[address] = (address * 73) ^ (address >> 1) ^ 20'h00A6;

    always @(posedge clk)
        if (wr_en)
            mem[wr_addr] <= wr_data;

    assign rd_data = mem[rd_addr];
endmodule
