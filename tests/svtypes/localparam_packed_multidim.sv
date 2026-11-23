// GitHub issue #63: localparam and parameter declarations with packed
// multidimensional types (e.g. localparam logic [3:0][3:0] T = ...).
module top #(
	parameter logic [1:0][1:0][3:0] P3 = {4'hA, 4'hB, 4'hC, 4'hD}
) (
	input  logic [1:0] a,
	input  logic [1:0] b,
	output logic       o_dyn,
	output logic [3:0] o_row,
	output logic       o_upto,
	output logic [3:0] o_p3
);
	localparam logic [3:0][3:0] T = {4'b0111, 4'b0101, 4'b0001, 4'b0000};
	localparam [3:0][3:0] T_imp = {4'b1100, 4'b1010, 4'b0110, 4'b0011};
	localparam logic [0:3][0:3] T_upto = {4'b0111, 4'b0101, 4'b0001, 4'b0000};

	// Reference flat vector for T
	localparam logic [15:0] T_flat = {4'b0111, 4'b0101, 4'b0001, 4'b0000};

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
endmodule
