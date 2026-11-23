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
	logic [2:0][3:0]       row;
	logic [2:0][3:0]       other_row;
	logic [1:0][2:0][3:0]  c3d_row;
	logic [1:0][2:0][3:0]  c3d_idx_row;
	logic [1:0][2:0][3:0]  c3d_idx_leaf;
	logic [1:0][1:0][2:0][3:0] c4d_row;
	logic [7:0]            v_ps;
	logic [7:0]            v_ps_idx;
	logic [2:0][3:0]       c2d_ps;
	logic [2:0][3:0]       c2d_outer_ps;
	logic [2:0][3:0]       c2d_ps_idx;
	logic [2:0][3:0]       c2d_outer_idx;
	logic [1:0][2:0][3:0]  c3d_cast_row;

	typedef logic [2:0][3:0] arr3x4_t;
	arr3x4_t c_cast;

	typedef struct packed {
		logic [2:0][3:0] arr;
		logic            en;
	} wrap_t;
	wrap_t c_struct;
	wrap_t c_struct_sub;

	always_comb begin
		row          = 12'h123;
		other_row    = 12'hABC;
		c2d          = '{default: 4'd5};
		c3d          = '{default: 4'hA};
		c3d_nested   = '{default: '{default: 4'hC}};
		c_idx        = '{0: 4'h1, 2: 4'h3, default: 4'h5};
		c_upto       = '{0: 4'h1, 2: 4'h3, default: 4'h5};
		c1d          = '{default: 1'b1};
		c_sub        = '{default: 4'h0};
		c_sub[1]     = '{default: 4'h7};
		c_cast       = arr3x4_t'('{default: 4'h9});
		c_struct     = '{arr: '{default: 4'h6}, en: 1'b1};
		c_struct_sub = '0;
		c_struct_sub.arr[1] = '{default: 1'b1};
		c3d_row      = '{default: row};
		c3d_idx_row  = '{0: other_row, default: row};
		c3d_idx_leaf = '{0: other_row, default: 4'h5};
		c4d_row      = '{default: row};
		c3d_cast_row = '{default: arr3x4_t'(12'h123)};
		v_ps         = 8'h00;
		v_ps[3:0]    = '{default: 1'b1};
		v_ps_idx     = 8'hFF;
		v_ps_idx[5:2] = '{5: 1'b1, default: 1'b0};
		c2d_ps       = 12'h000;
		c2d_ps[1][2:1] = '{default: 1'b1};
		c2d_outer_ps = 12'h000;
		c2d_outer_ps[2:1] = '{default: 4'h7};
		c2d_ps_idx   = 12'h000;
		c2d_ps_idx[1][2:1] = '{2: 1'b1, default: 1'b0};
		c2d_outer_idx = 12'h000;
		c2d_outer_idx[2:1] = '{2: 4'hA, default: 4'h7};
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
	always_comb assert(c_struct_sub.arr == 12'h0F0 && c_struct_sub.en == 1'b0);
	always_comb assert(c3d_row == {12'h123, 12'h123});
	always_comb assert(c3d_idx_row == {12'h123, 12'hABC});
	always_comb assert(c3d_idx_leaf == {12'h555, 12'hABC});
	always_comb assert(c4d_row == {4{12'h123}});
	always_comb assert(c3d_cast_row == {12'h123, 12'h123});
	always_comb assert(v_ps == 8'h0F);
	always_comb assert(v_ps_idx == 8'b1110_0011);
	always_comb assert(c2d_ps == 12'h060);
	always_comb assert(c2d_outer_ps == 12'h770);
	always_comb assert(c2d_ps_idx == 12'h040);
	always_comb assert(c2d_outer_idx == 12'hA70);
endmodule
