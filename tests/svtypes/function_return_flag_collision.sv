module top(
	input logic sel,
	input logic [3:0] value,
	input logic [3:0] other,
	output logic [3:0] result
);
	function automatic logic [3:0] pick(
		input logic choose_value,
		input logic [3:0] \$sv_return_flag ,
		input logic [3:0] fallback_value
	);
		if (choose_value)
			return \$sv_return_flag ;
		return fallback_value;
	endfunction

	assign result = pick(sel, value, other);

	always_comb assert(sel ? result == value : result == other);
endmodule
