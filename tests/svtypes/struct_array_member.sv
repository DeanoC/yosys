// GitHub issue #52: arr[i].field on a packed array of packed structs.
// A constant or genvar index used to create an implicit wire. A variable
// index used to fail as a generate-block prefix.
module top(
	input logic [19:0] in,
	input logic [1:0] i,
	output logic y_const,
	output logic [3:0] z_gen,
	output logic y_var,
	output logic [3:0] z_lhs0,
	output logic [3:0] z_lhs1
);
	typedef struct packed { logic a; logic [3:0] b; } s_t; // a at bit 4, b at bits [3:0]
	s_t [3:0] arr;
	assign arr = in;
	assign y_const = arr[2].a;
	for (genvar k = 1; k < 2; k++) begin : g
		assign z_gen = arr[k].b;
	end
	assign y_var = arr[i].a;

	s_t [1:0] cls;
	for (genvar k = 0; k < 2; k++) begin : h
		assign cls[k].b = in[k * 4 +: 4];
	end
	assign z_lhs0 = cls[0].b;
	assign z_lhs1 = cls[1].b;

	always_comb assert(y_const == in[14]);
	always_comb assert(z_gen == in[8:5]);
	always_comb assert(y_var == in[(i * 5) + 4]);
	always_comb assert(z_lhs0 == in[3:0]);
	always_comb assert(z_lhs1 == in[7:4]);
endmodule
