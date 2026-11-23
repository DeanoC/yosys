// GitHub issue #66: concurrent assertions with clocking events, disable iff,
// overlapping implication |->, and action blocks.
module repro (
	input wire clk,
	input wire a,
	input wire b
);
	assert property (@(posedge clk) a |-> b);
endmodule

module top (
	input  wire clk,
	input  wire rst,
	input  wire en,
	input  wire a,
	output wire b
);
	assign b = a;

	// Exact issue #66 form
	assert property (@(posedge clk) a |-> b);

	// Labeled with disable iff and else action block
	a_dis: assert property (@(posedge clk) disable iff (rst) a |-> b)
		else $error("expected b when a is asserted");

	// Clocked boolean property without implication
	a_bool: assert property (@(posedge clk) !(a && !b));

	// Chained overlapping implication and negedge clocking
	a_chain: assert property (@(negedge clk) en |-> a |-> b);

	// Unclocked overlapping implication
	a_unclk: assert property (a |-> b);

	// assume / cover / restrict concurrent properties
	m_assume: assume property (@(posedge clk) disable iff (rst) en |-> (a || !a));
	c_cover:  cover  property (@(posedge clk) a |-> b);
	r_restr:  restrict property (@(posedge clk) en |-> (b == a));

	// Verify no grammar ambiguity with generate if/else
	generate
		if (1)
			g_assert: assert property (@(posedge clk) a |-> b);
		else
			assign b = 1'b0;
	endgenerate
endmodule
