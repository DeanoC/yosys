// '{default: v} on nested package structs (struct of struct of struct) with a
// typedef-of-typedef member, used through pkg::. The default must be assigned
// whole to the members whose type matches it.
package pdp_nest;
	typedef struct packed { logic [3:0] a; logic [3:0] b; } pair_t;
	typedef struct packed { pair_t p0; pair_t p1; } quad_t;
	typedef quad_t quad_alias_t;
	typedef struct packed { quad_t q0; quad_alias_t q1; } oct_t;
endpackage

module top (
	input pdp_nest::pair_t v,
	input pdp_nest::quad_t qv
);
	pdp_nest::oct_t o_pair, o_quad;

	assign o_pair = '{q0: '{default: v}, q1: '{default: v}};
	assign o_quad = '{default: qv};

	always_comb begin
		assert(o_pair == {4{v}});
		assert(o_quad == {qv, qv});
	end
endmodule
