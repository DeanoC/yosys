// GitHub issue #63: localparam and parameter declarations with packed
// multidimensional types (e.g. localparam logic [3:0][3:0] T = ...).
module sub_req #(
	parameter logic [1:0][3:0] REQ_P
) (
	input  logic       sel,
	output logic [3:0] out
);
	assign out = REQ_P[sel];
endmodule

module top #(
	parameter logic [1:0][1:0][3:0] P3 = {4'hA, 4'hB, 4'hC, 4'hD}
) (
	input  logic [1:0] a,
	input  logic [1:0] b,
	output logic       o_dyn,
	output logic [3:0] o_row,
	output logic       o_upto,
	output logic [3:0] o_p3,
	output logic [3:0] o_req
);
	localparam logic [3:0][3:0] T = {4'b0111, 4'b0101, 4'b0001, 4'b0000};
	localparam [3:0][3:0] T_imp = {4'b1100, 4'b1010, 4'b0110, 4'b0011};
	localparam logic [0:3][0:3] T_upto = {4'b0111, 4'b0101, 4'b0001, 4'b0000};

	// Reference flat vector for T
	localparam logic [15:0] T_flat = {4'b0111, 4'b0101, 4'b0001, 4'b0000};

	// Submodule with required (no-default) multidimensional parameter
	sub_req #(.REQ_P({4'h5, 4'h9})) u_req (.sel(a[0]), .out(o_req));

	assign o_dyn  = T[a][b];
	assign o_row  = T[a];
	assign o_upto = T_upto[a][b];
	assign o_p3   = P3[a[0]][b[0]];

	// Dynamic 2-D and 1-D indexing against flat reference
	always_comb assert(o_dyn == T_flat[{a, b}]);
	always_comb assert(o_row == T_flat[a * 4 +: 4]);

	// Constant 2-D and 1-D indexing
	always_comb assert(T[3] == 4'b0111);
	always_comb assert(T[2] == 4'b0101);
	always_comb assert(T[1] == 4'b0001);
	always_comb assert(T[0] == 4'b0000);
	always_comb assert(T[3][2] == 1'b1 && T[3][3] == 1'b0);
	always_comb assert(T[2][0] == 1'b1 && T[2][1] == 1'b0);

	// Implicit-type 2-D localparam
	always_comb assert(T_imp[a][b] == (({4'b1100, 4'b1010, 4'b0110, 4'b0011} >> {a, b}) & 1'b1));

	// Ascending (upto) packed 2-D localparam: T_upto[0] is MSB nibble (4'b0111), bit 0 is MSB (0)
	always_comb assert(T_upto[0] == 4'b0111);
	always_comb assert(T_upto[3] == 4'b0000);
	always_comb assert(T_upto[0][0] == 1'b0 && T_upto[0][1] == 1'b1);
	always_comb assert(o_upto == T_flat[15 - {a, b}]);

	// 3-D packed parameter
	always_comb assert(P3[1][1] == 4'hA && P3[1][0] == 4'hB && P3[0][1] == 4'hC && P3[0][0] == 4'hD);
	always_comb assert(o_p3 == (a[0] ? (b[0] ? 4'hA : 4'hB) : (b[0] ? 4'hC : 4'hD)));

	// Required no-default multidimensional parameter override
	always_comb assert(o_req == (a[0] ? 4'h5 : 4'h9));

	// Array query functions on multidimensional parameters
	localparam int D_T    = $dimensions(T);
	localparam int S_T1   = $size(T, 1);
	localparam int S_T2   = $size(T, 2);
	localparam int L_T2   = $left(T, 2);
	localparam int R_T2   = $right(T, 2);
	localparam int B_T    = $bits(T);
	localparam int D_TR   = $dimensions(T[3]);
	localparam int S_TR   = $size(T[3]);
	localparam int B_TR   = $bits(T[3]);
	localparam int D_P3   = $dimensions(P3);
	localparam int S_P3_3 = $size(P3, 3);
	localparam int D_P3_1 = $dimensions(P3[1]);
	localparam int S_P311 = $size(P3[1], 1);
	localparam int S_P312 = $size(P3[1], 2);
	localparam int B_P3_1 = $bits(P3[1]);
	localparam int L_U1   = $left(T_upto, 1);
	localparam int R_U1   = $right(T_upto, 1);

	always_comb assert(D_T == 2);
	always_comb assert(S_T1 == 4);
	always_comb assert(S_T2 == 4);
	always_comb assert(L_T2 == 3);
	always_comb assert(R_T2 == 0);
	always_comb assert(B_T == 16);
	always_comb assert(D_TR == 1);
	always_comb assert(S_TR == 4);
	always_comb assert(B_TR == 4);
	always_comb assert(D_P3 == 3);
	always_comb assert(S_P3_3 == 4);
	always_comb assert(D_P3_1 == 2);
	always_comb assert(S_P311 == 2);
	always_comb assert(S_P312 == 4);
	always_comb assert(B_P3_1 == 8);
	always_comb assert(L_U1 == 0 && R_U1 == 3);
endmodule
