// GitHub issue #64: $bits of a type (typedef, built-in, struct) and of a part/bit select
// in constant expressions (localparam, parameter override, and runtime assignments).
package bits_pkg;
	typedef logic [4:0] pkg_u5_t;
endpackage

module sub #(parameter int W = 0, parameter int V = 0) (
	output logic [7:0] ow,
	output logic [7:0] ov
);
	assign ow = W;
	assign ov = V;
endmodule

module top (
	input  logic [9:0] f,
	input  logic [2:0] idx,
	output logic [7:0] o,
	output logic [7:0] p,
	output logic [7:0] sub_w,
	output logic [7:0] sub_v
);
	// Exact issue #64 repro
	typedef enum logic [2:0] {A, B} t_t;
	localparam W = $bits(t_t);
	localparam V = $bits(f[9:8]);
	assign o = W;
	assign p = V;

	// Parameter overrides using $bits(type) and $bits(part_select)
	sub #(.W($bits(t_t)), .V($bits(f[9:8]))) u_sub (.ow(sub_w), .ov(sub_v));

	// Typedefs: struct, union, packed 2-D array, unpacked array, package typedef
	typedef struct packed { logic a; logic [5:0] b; } s_t;
	typedef union packed { logic [3:0] a; logic [3:0] b; } u_t;
	typedef logic [2:0][3:0] arr2d_t;
	typedef logic [7:0] uarr_t [0:3];

	localparam int B_ENUM   = $bits(t_t);
	localparam int B_STRUCT = $bits(s_t);
	localparam int B_UNION  = $bits(u_t);
	localparam int B_ARR2D  = $bits(arr2d_t);
	localparam int B_UARR   = $bits(uarr_t);
	localparam int B_PKG    = $bits(bits_pkg::pkg_u5_t);
	localparam int B_TD_ARR = $bits(t_t [3:0]);
	localparam int B_ST_ARR = $bits(s_t [1:0]);
	localparam int B_INT    = $bits(int);
	localparam int B_BYTE   = $bits(byte);
	localparam int B_LOGIC  = $bits(logic);
	localparam int B_VEC    = $bits(logic [5:0]);
	localparam int B_MAT    = $bits(logic [2:0][3:0]);
	localparam int B_INLINE = $bits(struct packed { logic x; logic [3:0] y; });

	// Part/bit selects and indexed slices
	logic [3:0][7:0] p2d;
	logic [7:0]      mem [0:3];
	s_t              s_inst;

	localparam int B_BIT    = $bits(f[3]);
	localparam int B_IDXPS  = $bits(f[idx +: 4]);
	localparam int B_P2D_E  = $bits(p2d[1]);
	localparam int B_P2D_SL = $bits(p2d[2:1]);
	localparam int B_P2D_PS = $bits(p2d[1][5:2]);
	localparam int B_P2D_B  = $bits(p2d[1][3]);
	localparam int B_MEM_E  = $bits(mem[0]);
	localparam int B_MEM_PS = $bits(mem[0][3:2]);
	localparam int B_MEM_W  = $bits(mem);
	localparam int B_SMEM   = $bits(s_inst.b[4:1]);
	localparam int S_PS     = $size(f[9:8]);
	localparam int S_ARR1   = $size(arr2d_t, 1);
	localparam int S_ARR2   = $size(arr2d_t, 2);
	localparam int B_ARR3D  = $bits(arr2d_t [1:0]);
	localparam int S_ARR3_1 = $size(arr2d_t [1:0], 1);
	localparam int S_ARR3_2 = $size(arr2d_t [1:0], 2);
	localparam int S_ARR3_3 = $size(arr2d_t [1:0], 3);

	// Wider LHS context must not pollute $bits width_hint
	logic [31:0] wide_bits;
	assign wide_bits = $bits(f[9:8]);

	always_comb assert(o == 8'd3);
	always_comb assert(p == 8'd2);
	always_comb assert(sub_w == 8'd3);
	always_comb assert(sub_v == 8'd2);
	always_comb assert(B_ENUM == 3);
	always_comb assert(B_STRUCT == 7);
	always_comb assert(B_UNION == 4);
	always_comb assert(B_ARR2D == 12);
	always_comb assert(B_UARR == 32);
	always_comb assert(B_PKG == 5);
	always_comb assert(B_TD_ARR == 12);
	always_comb assert(B_ST_ARR == 14);
	always_comb assert(B_INT == 32);
	always_comb assert(B_BYTE == 8);
	always_comb assert(B_LOGIC == 1);
	always_comb assert(B_VEC == 6);
	always_comb assert(B_MAT == 12);
	always_comb assert(B_INLINE == 5);
	always_comb assert(B_BIT == 1);
	always_comb assert(B_IDXPS == 4);
	always_comb assert(B_P2D_E == 8);
	always_comb assert(B_P2D_SL == 16);
	always_comb assert(B_P2D_PS == 4);
	always_comb assert(B_P2D_B == 1);
	always_comb assert(B_MEM_E == 8);
	always_comb assert(B_MEM_PS == 2);
	always_comb assert(B_MEM_W == 32);
	always_comb assert(B_SMEM == 4);
	always_comb assert(S_PS == 2);
	always_comb assert(S_ARR1 == 3);
	always_comb assert(S_ARR2 == 4);
	always_comb assert(B_ARR3D == 24);
	always_comb assert(S_ARR3_1 == 2);
	always_comb assert(S_ARR3_2 == 3);
	always_comb assert(S_ARR3_3 == 4);
	always_comb assert(wide_bits == 32'd2);
endmodule
