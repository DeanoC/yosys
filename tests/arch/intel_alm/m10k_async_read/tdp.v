// Two-write, two-combinational-read Cyclone V M10K candidate.
// This is the native shape needed by asynchronous dual-port RAMs such as the
// ZX81 video capture buffer; each port has its own clock and whole-word write.
module tdp #(
    parameter WIDTH = 10,
    parameter ABITS = 10
) (
    input wire clk_a,
    input wire clk_b,
    input wire we_a,
    input wire we_b,
    input wire [ABITS-1:0] addr_a,
    input wire [ABITS-1:0] addr_b,
    input wire [WIDTH-1:0] data_a,
    input wire [WIDTH-1:0] data_b,
    output wire [WIDTH-1:0] q_a,
    output wire [WIDTH-1:0] q_b
);
    (* ramstyle = "M10K" *) reg [WIDTH-1:0] mem [0:(1 << ABITS)-1];
    integer address;

    initial
        for (address = 0; address < (1 << ABITS); address = address + 1)
            mem[address] = (address * 73) ^ (address >> 1) ^ 10'h2A;

    always @(posedge clk_a)
        if (we_a)
            mem[addr_a] <= data_a;

    always @(posedge clk_b)
        if (we_b)
            mem[addr_b] <= data_b;

    assign q_a = mem[addr_a];
    assign q_b = mem[addr_b];
endmodule
