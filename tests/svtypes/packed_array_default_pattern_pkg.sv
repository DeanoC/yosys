// '{default: v} on structs declared in a package and used through pkg::.
// The member types (pair_t, alias_t) are package typedefs, so a struct-typed
// default must be assigned whole to the matching members: q == {v, v}, not
// {4{v[3:0]}}.
package pdp_qual;
	typedef struct packed { logic [3:0] a; logic [3:0] b; } pair_t;
	typedef pair_t alias_t;
	typedef struct packed { pair_t p0; pair_t p1; } quad_t;
	typedef struct packed { alias_t x0; alias_t x1; } aquad_t;
endpackage

module top (
	input pdp_qual::pair_t v
);
	pdp_qual::alias_t av;
	pdp_qual::quad_t q, q_cast, q_mref;
	pdp_qual::aquad_t aq, aq_alias;

	assign av = v;
	assign q = '{default: v};
	assign q_cast = pdp_qual::quad_t'('{default: v});
	assign q_mref = '{default: q.p1};
	assign aq = '{default: v};
	assign aq_alias = '{default: av};

	always_comb begin
		assert(q == {v, v});
		assert(q_cast == {v, v});
		assert(q_mref == {v, v});
		assert(aq == {v, v});
		assert(aq_alias == {v, v});
	end
endmodule
