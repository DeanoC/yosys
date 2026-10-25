// GitHub issue #37: return in a function, including an early return.
module top(
	input logic [3:0] a,
	input logic [3:0] b,
	input logic c,
	output logic [3:0] y_inc,
	output logic [3:0] y_pick
);
	function automatic logic [3:0] inc(input logic [3:0] x);
		return x + 4'd1;
	endfunction

	function automatic logic [3:0] pick(input logic sel, input logic [3:0] x, input logic [3:0] y);
		if (sel)
			return x;
		return y;
	endfunction

	assign y_inc = inc(a);
	assign y_pick = pick(c, a, b);

	localparam logic [3:0] inc_c = inc(4'h5);
	localparam logic [3:0] pick_c = pick(1'b1, 4'hA, 4'h3);

	always_comb assert(y_inc == a + 4'd1);
	always_comb assert(c == 1'b0 || y_pick == a);
	always_comb assert(c == 1'b1 || y_pick == b);
	always_comb assert(inc_c == 4'h6);
	always_comb assert(pick_c == 4'hA);
endmodule
