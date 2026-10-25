module top(
	input logic [3:0] x,
	output logic [3:0] y
);
	function automatic logic [3:0] f(input logic [3:0] value);
		(* sv_return *) f = 4'd1;
		f = 4'd2;
	endfunction

	assign y = f(x);

	always_comb assert(y == 4'd2);
endmodule
