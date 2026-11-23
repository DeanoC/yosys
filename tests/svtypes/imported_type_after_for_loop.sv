// GitHub issue #74: imported types must remain recognized as TOK_USER_TYPE
// in casts and declarations after a procedural `for (int ...)` loop.
package p;
	typedef enum logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2} e_t;
endpackage

module wildcard_header import p::*; (
	input  logic [1:0] sel,
	output e_t         y
);
	logic [1:0] tmp;
	always_comb begin
		tmp = 2'd0;
		for (int k = 0; k < 2; k++)
			tmp[k] = sel[k];
	end
	assign y = e_t'(tmp);
endmodule

module named_header import p::e_t; (
	input  logic [1:0] sel,
	output e_t         y
);
	always_comb begin
		for (int k = 0; k < 2; k++) ;
	end
	assign y = e_t'(sel);
endmodule

module body_import_decl (
	input  logic [7:0] i,
	output logic [7:0] o,
	output logic [1:0] q
);
	import p::*;
	always_comb for (int n = 0; n < 8; n++) o[n] = i[n];
	e_t x;
	assign x = B;
	assign q = x;
endmodule

module cast_in_for_init import p::*; (
	input  logic [1:0] sel,
	output logic [1:0] y
);
	always_comb begin
		y = 2'd0;
		for (int k = int'(e_t'(2'd0)); k < 2; k++)
			y[k] = sel[k];
	end
endmodule

module top (
	input  logic [1:0] sel,
	input  logic [7:0] i,
	output logic [1:0] y1,
	output logic [1:0] y2,
	output logic [7:0] o3,
	output logic [1:0] q3,
	output logic [1:0] y4
);
	wildcard_header u1 (.sel(sel), .y(y1));
	named_header    u2 (.sel(sel), .y(y2));
	body_import_decl u3 (.i(i), .o(o3), .q(q3));
	cast_in_for_init u4 (.sel(sel), .y(y4));

	always_comb assert(y1 == sel);
	always_comb assert(y2 == sel);
	always_comb assert(o3 == i);
	always_comb assert(q3 == 2'd1);
	always_comb assert(y4 == sel);
endmodule
