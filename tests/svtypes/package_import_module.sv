// GitHub issue #36: import is legal in a module body and in an ANSI header.
package p;
	typedef logic [3:0] nib_t;
endpackage

module hdr import p::*; (input nib_t a, output nib_t y);
	assign y = a;
endmodule

module body_m(input logic [3:0] a, output logic [3:0] y);
	import p::*;
	nib_t t;
	assign t = a;
	assign y = t;
endmodule

module spec_m(input logic [3:0] a, output logic [3:0] y);
	import p::nib_t;
	nib_t t;
	assign t = a;
	assign y = t;
endmodule

module top(input logic [3:0] a, output logic [3:0] y_hdr, output logic [3:0] y_body, output logic [3:0] y_spec);
	hdr u_hdr(a, y_hdr);
	body_m u_body(a, y_body);
	spec_m u_spec(a, y_spec);

	always_comb assert(y_hdr == a);
	always_comb assert(y_body == a);
	always_comb assert(y_spec == a);
endmodule
