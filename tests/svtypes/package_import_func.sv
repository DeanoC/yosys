// GitHub issue #55: a package function imported by bare name must be callable.
package p;
	function automatic logic is_odd(input logic [7:0] b);
		is_odd = b[0];
	endfunction
endpackage

module hdr_call import p::*; (
	input  logic [7:0] b,
	output logic       y
);
	assign y = is_odd(b);
endmodule

module body_call(
	input  logic [7:0] b,
	output logic       y
);
	import p::*;
	assign y = is_odd(b);
endmodule

module gen_call import p::*; (
	input  logic [7:0] b,
	output logic [7:0] y
);
	genvar k;
	generate
		for (k = 0; k < 8; k = k + 1) begin : g
			assign y[k] = is_odd(b[k]);
		end
	endgenerate
endmodule

module qual_call import p::*; (
	input  logic [7:0] b,
	output logic       y
);
	assign y = p::is_odd(b);
endmodule

module spec_call(
	input  logic [7:0] b,
	output logic       y
);
	import p::is_odd;
	assign y = is_odd(b);
endmodule
