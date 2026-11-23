// GitHub issue #69: array select indices are self-determined (IEEE 1800-2017 Table 11-21).
// With a 2-bit `b`, `b + 2'd1` wraps at 2 bits so `b = 3` selects element 0.
module top (
	input  logic       sel,
	input  logic [1:0] b,
	input  logic [7:0] data,
	output logic [7:0] q_read,
	output logic [7:0] q_write,
	output logic [7:0] q_ternary,
	output logic [7:0] q_unpacked
);
	logic [3:0][7:0] arr_in;
	assign arr_in = {8'hD3, 8'hC2, 8'hB1, 8'hA0};

	// Read with self-determined wrapping index
	assign q_read = arr_in[b + 2'd1];

	// Write with self-determined wrapping index and ternary index
	logic [3:0][7:0] arr_wr;
	logic [3:0][7:0] arr_tern;
	logic [7:0]      unpacked_arr [0:7];
	logic [1:0]      idx_plus1;
	assign idx_plus1 = b + 2'd1;

	always_comb begin
		arr_wr = arr_in;
		arr_wr[b + 2'd1] = data;

		arr_tern = arr_in;
		arr_tern[sel ? b + 2'd1 : b] = data;

		for (int i = 0; i < 8; i++)
			unpacked_arr[i] = 8'hEE;
		unpacked_arr[b + 2'd1] = data;
	end

	assign q_write    = arr_wr[idx_plus1];
	assign q_ternary  = arr_tern[sel ? idx_plus1 : b];
	assign q_unpacked = unpacked_arr[{1'b0, idx_plus1}];

	always_comb assert(q_read == arr_in[idx_plus1]);
	always_comb assert(q_write == data);
	always_comb assert(q_ternary == data);
	always_comb assert(q_unpacked == data);
	always_comb assert(b != 2'd3 || arr_wr[0] == data);
	always_comb assert(b != 2'd3 || unpacked_arr[4] == 8'hEE);
endmodule
