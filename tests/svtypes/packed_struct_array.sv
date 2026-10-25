// GitHub issue #34: a packed array of packed structs must elaborate to
// element-width times the array length, not a single element.
module top(
	input logic [79:0] in,
	output logic [79:0] out,
	output logic [4:0] elem0,
	output logic [4:0] elem3,
	output logic [4:0] elem15,
	output logic [31:0] nbits
);
	typedef struct packed { logic [3:0] len; logic pfx; } e_t; // 5 bits
	e_t [15:0] arr; // 16 x 5 = 80 bits
	assign arr = in;
	assign out = arr;
	assign elem0 = arr[0];
	assign elem3 = arr[3];
	assign elem15 = arr[15];
	assign nbits = $bits(arr);

	always_comb assert(nbits == 32'd80);
	always_comb assert(elem0 == in[4:0]);
	always_comb assert(elem3 == in[19:15]);
	always_comb assert(elem15 == in[79:75]);
	always_comb assert(out == in);
endmodule
