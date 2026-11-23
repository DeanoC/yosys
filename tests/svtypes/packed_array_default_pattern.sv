// GitHub issue #62: '{default: v} (and keyed/nested patterns) on packed
// multidimensional arrays, packed vectors, struct packed-array members, and typedef casts.
module top (
	input  logic       clk,
	input  logic [3:0] i,
	output logic [3:0] o_repro,
	output logic [3:0] o_repro_ref
);
	// Case 1: exact issue #62 repro
	logic [2:0][3:0] r = '{default: 4'd5};
	always_ff @(posedge clk) r <= {r[1:0], i};
	assign o_repro = r[2];

	logic [2:0][3:0] r_ref;
	initial r_ref = {4'd5, 4'd5, 4'd5};
	always_ff @(posedge clk) r_ref <= {r_ref[1:0], i};
	assign o_repro_ref = r_ref[2];

	// Case 2: combinational 2-D, 3-D, nested default, indexed+default, ascending, 1-D vector
	logic [2:0][3:0]       c2d;
	logic [1:0][2:0][3:0]  c3d;
	logic [1:0][2:0][3:0]  c3d_nested;
	logic [2:0][3:0]       c_idx;
	logic [0:2][3:0]       c_upto;
	logic [7:0]            c1d;
	logic [1:0][2:0][3:0]  c_sub;

	typedef logic [2:0][3:0] arr3x4_t;
	arr3x4_t c_cast;

	typedef struct packed {
		logic [2:0][3:0] arr;
		logic            en;
	} wrap_t;
	wrap_t c_struct;

	always_comb begin
		c2d        = '{default: 4'd5};
		c3d        = '{default: 4'hA};
		c3d_nested = '{default: '{default: 4'hC}};
		c_idx      = '{0: 4'h1, 2: 4'h3, default: 4'h5};
		c_upto     = '{0: 4'h1, 2: 4'h3, default: 4'h5};
		c1d        = '{default: 1'b1};
		c_sub      = '{default: 4'h0};
		c_sub[1]   = '{default: 4'h7};
		c_cast     = arr3x4_t'('{default: 4'h9});
		c_struct   = '{arr: '{default: 4'h6}, en: 1'b1};
	end

	always_comb assert(c2d == {4'd5, 4'd5, 4'd5});
	always_comb assert(c3d == {6{4'hA}});
	always_comb assert(c3d_nested == {6{4'hC}});
	always_comb assert(c_idx[2] == 4'h3 && c_idx[1] == 4'h5 && c_idx[0] == 4'h1);
	always_comb assert(c_upto[0] == 4'h1 && c_upto[1] == 4'h5 && c_upto[2] == 4'h3);
	always_comb assert(c1d == 8'hFF);
	always_comb assert(c_sub[1] == {3{4'h7}} && c_sub[0] == 12'h000);
	always_comb assert(c_cast == {3{4'h9}});
	always_comb assert(c_struct.arr == {3{4'h6}} && c_struct.en == 1'b1);
endmodule
