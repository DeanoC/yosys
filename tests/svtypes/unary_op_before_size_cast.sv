// GitHub issue #65: unary operators before a size cast must bind to the
// cast result (e.g. -12'(q) == -(12'(q))), not to the cast size.
module top #(parameter int W = 11) (
	input  logic [7:0]         q,
	output logic signed [11:0] o_neg,
	output logic [11:0]        o_inv,
	output logic [11:0]        o_pos,
	output logic               o_not,
	output logic               o_xor,
	output logic [11:0]        o_param
);
	typedef logic [11:0] u12_t;

	assign o_neg   = -12'(q);
	assign o_inv   = ~12'(q);
	assign o_pos   = +12'(q);
	assign o_not   = !12'(q);
	assign o_xor   = ^12'(q);
	assign o_param = -(W + 1)'(q);

	wire signed [11:0] ref_neg = -(12'(q));
	wire [11:0]        ref_inv = ~(12'(q));
	wire [11:0]        ref_pos = +(12'(q));
	wire               ref_not = !(12'(q));
	wire               ref_xor = ^(12'(q));
	wire [11:0]        ref_td  = -u12_t'(q);

	always_comb assert(o_neg == ref_neg);
	always_comb assert(o_inv == ref_inv);
	always_comb assert(o_pos == ref_pos);
	always_comb assert(o_not == ref_not);
	always_comb assert(o_xor == ref_xor);
	always_comb assert(o_param == ref_neg);
	always_comb assert(ref_td == ref_neg);
endmodule
