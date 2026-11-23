// '{default: v} on package structs used through import pkg::*, mixed with
// pkg:: references, and with a module-local typedef that masks the imported
// member type name.
package pdp_imp;
	typedef struct packed { logic [3:0] a; logic [3:0] b; } pair_t;
	typedef pair_t alias_t;
	typedef struct packed { pair_t p0; pair_t p1; } quad_t;
	typedef struct packed { alias_t x0; alias_t x1; } aquad_t;
endpackage

module shadow (
	input pdp_imp::pair_t v
);
	import pdp_imp::*;
	// Local declaration masks the imported pair_t; quad_t's members are
	// still pdp_imp::pair_t.
	typedef struct packed { logic [7:0] z; } pair_t;
	quad_t q;
	assign q = '{default: v};
	always_comb assert(q == {v, v});
endmodule

module top (
	input pdp_imp::pair_t v
);
	import pdp_imp::*;
	pair_t vi;
	quad_t q, q_mixed;
	pdp_imp::quad_t q_qual;
	aquad_t aq;

	assign vi = v;
	assign q = '{default: vi};
	assign q_mixed = '{default: v};
	assign q_qual = '{default: vi};
	assign aq = '{default: vi};

	always_comb begin
		assert(q == {v, v});
		assert(q_mixed == {v, v});
		assert(q_qual == {v, v});
		assert(aq == {v, v});
	end

	shadow u_shadow (.v(v));
endmodule
