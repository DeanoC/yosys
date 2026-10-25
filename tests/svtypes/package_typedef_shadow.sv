package p;
	typedef logic [7:0] T;

	function automatic logic [7:0] local_type_sign_extend(input logic [3:0] value);
		begin
			typedef logic signed [3:0] T;
			T x;
			x = value;
			local_type_sign_extend = x;
		end
	endfunction
endpackage

module top(input logic [3:0] value, output logic [7:0] result);
	assign result = p::local_type_sign_extend(value);
	always_comb assert(result == {{4{value[3]}}, value});
endmodule
