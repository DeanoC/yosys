// GitHub issue #66: concurrent assertions with clocking events, disable iff,
// and overlapping implication |->.
module repro (
	input wire clk,
	input wire a,
	input wire b
);
	assert property (@(posedge clk) a |-> b);
endmodule

module edge_clk (
	input wire clk,
	input wire a,
	input wire b
);
	p_paren: assert property (@(clk) a |-> b);
	p_bare:  assert property (@clk a |-> b);
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

	// Labeled with disable iff
	a_dis: assert property (@(posedge clk) disable iff (rst) a |-> b);

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

// Every property in `top` holds however it is lowered, because b == a there.
// The modules below pin the lowering down: the `strict_*` properties only hold
// under the correct lowering, and each `fail_*` module has one violated
// property that sat must find a counterexample for, so a check that never
// fires (EN stuck at 0) cannot pass unnoticed.
module strict_impl (
	input  wire clk,
	input  wire rst,
	input  wire a,
	input  wire c,
	output wire b,
	output wire d,
	output wire e
);
	assign b = a || c;     // a implies b, b does not imply a
	assign d = a && !rst;  // d follows a only while rst is low
	assign e = a && c;     // e needs both a and c

	// Fail if antecedent and consequent are swapped
	s_dir:   assert property (@(posedge clk) a |-> b);
	s_unclk: assert property (a |-> b);
	// Fails if disable iff is ignored or inverted
	s_dis:   assert property (@(posedge clk) disable iff (rst) a |-> d);
	// Fails if either antecedent of the chain is dropped
	s_chain: assert property (@(negedge clk) a |-> c |-> e);
endmodule

// The sampled value of clk is 0 just before a rising edge and 1 just before a
// falling edge, so these only hold if each check fires on its own edge.
module strict_edge (
	input wire clk
);
	s_pos: assert property (@(posedge clk) !clk);
	s_neg: assert property (@(negedge clk) clk);
endmodule

module fail_impl (
	input wire clk,
	input wire a,
	input wire b
);
	assert property (@(posedge clk) a |-> b);
endmodule

module fail_dis (
	input wire clk,
	input wire rst,
	input wire a,
	input wire b
);
	assert property (@(posedge clk) disable iff (rst) a |-> b);
endmodule

module fail_unclk (
	input wire a,
	input wire b
);
	assert property (a |-> b);
endmodule

module fail_edge (
	input wire clk
);
	assert property (@(posedge clk) clk);
endmodule
