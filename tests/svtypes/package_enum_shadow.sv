package p;
	typedef enum logic [1:0] { E = 2'd1 } e_t;

	function automatic logic [1:0] f(input logic [1:0] E);
		f = p::E;
	endfunction
endpackage

module top(output logic [1:0] result);
	assign result = p::f(2'd0);
	always_comb assert(result == 2'd1);
endmodule
