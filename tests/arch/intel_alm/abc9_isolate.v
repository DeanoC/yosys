// Two combinational cones cut by registers: a carry chain and an xor.
// The alias forces the xor result through a connection as well as a cell port.
module top (input clk, input [3:0] a, b, c, d, output [3:0] sum, output [3:0] xr);
	reg [3:0] a_q, b_q, c_q, d_q, sum_q, xr_q;
	wire [3:0] sum_i, xr_i, xr_alias;

	always @(posedge clk) begin
		a_q <= a;
		b_q <= b;
		c_q <= c;
		d_q <= d;
		sum_q <= sum_i;
		xr_q <= xr_alias;
	end

	assign sum_i = a_q + b_q;
	assign xr_i = c_q ^ d_q;
	assign xr_alias = xr_i;
	assign sum = sum_q;
	assign xr = xr_q;
endmodule
