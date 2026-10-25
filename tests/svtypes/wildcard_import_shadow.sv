package p;
	typedef logic [7:0] T;
endpackage

module m(input logic x, output logic y);
	import p::*;
	logic T;
	assign T = x;
        assign y = T;
endmodule
