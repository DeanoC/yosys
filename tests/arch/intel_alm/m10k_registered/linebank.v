// Coleco sprite line-bank shape: 256x4, registered reads, one write port,
// second port read-only, both clocks the same.
module linebank (
    input wire clk,
    input wire [7:0] address_a,
    input wire [3:0] data_a,
    input wire wren_a,
    output wire [3:0] q_a,
    input wire [7:0] address_b,
    output wire [3:0] q_b
);
    (* ramstyle = "M10K" *) reg [3:0] ram [0:255];
    reg [3:0] q_a_r;
    reg [3:0] q_b_r;

    always @(posedge clk) begin
        if (wren_a)
            ram[address_a] <= data_a;
        q_a_r <= ram[address_a];
    end

    always @(posedge clk)
        q_b_r <= ram[address_b];

    assign q_a = q_a_r;
    assign q_b = q_b_r;
endmodule
