package p;
	typedef logic T;
endpackage

module bare_wire(input logic d, output logic q);
	import p::*;
	wire T;
	assign T = d;
	assign q = T;
endmodule

module ansi_wire import p::*; (input wire T, output logic q);
	assign q = T;
endmodule

module top(input logic d, output logic q_bare, output logic q_ansi);
	bare_wire u_bare(.d(d), .q(q_bare));
	ansi_wire u_ansi(.T(d), .q(q_ansi));
	always_comb assert(q_bare == d);
	always_comb assert(q_ansi == d);
endmodule
