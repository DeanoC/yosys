// GitHub issue #73: concatenation of variable-index targets on LHS of `<=`
// (and `=`), both alone and alongside other variable-index NBA writes to the
// same array, plus mixed lookahead/non-lookahead constant-index LHS concats.
module top (
	input  logic       clk,
	input  logic       rst,
	input  logic [1:0] i,
	input  logic [8:0] d,
	output logic [7:0] q_repro,
	output logic       h_repro,
	output logic [7:0] q_alone,
	output logic       h_alone,
	output logic [7:0] q_mix,
	output logic       h_mix,
	output logic [7:0] q_ref,
	output logic       h_ref
);
	// Case 1: exact issue #73 repro
	logic [3:0][7:0] lo;
	logic [3:0]      hi;
	always_ff @(posedge clk) begin
		if (rst) lo[i] <= 8'd0;
		else {lo[i], hi[i]} <= d;
	end
	assign q_repro = lo[0];
	assign h_repro = hi[0];

	// Reference (split statements) for case 1
	logic [3:0][7:0] lo_ref;
	logic [3:0]      hi_ref;
	always_ff @(posedge clk) begin
		if (rst) lo_ref[i] <= 8'd0;
		else begin
			lo_ref[i] <= d[8:1];
			hi_ref[i] <= d[0];
		end
	end
	assign q_ref = lo_ref[0];
	assign h_ref = hi_ref[0];

	// Case 2: dynamic concat LHS alone (must not be silently dropped)
	logic [3:0][7:0] lo_alone;
	logic [3:0]      hi_alone;
	always_ff @(posedge clk) begin
		{lo_alone[i], hi_alone[i]} <= d;
	end
	assign q_alone = lo_alone[0];
	assign h_alone = hi_alone[0];

	// Case 3: constant-index concat mixing lookahead `lo_mix` and plain `hi_mix`
	logic [3:0][7:0] lo_mix;
	logic            hi_mix;
	always_ff @(posedge clk) begin
		if (rst) lo_mix[i] <= 8'd0;
		else {lo_mix[0], hi_mix} <= d;
	end
	assign q_mix = lo_mix[0];
	assign h_mix = hi_mix;

	// Combinational dynamic-concat equivalence check
	logic [3:0][7:0] c_lo, c_lo_ref;
	logic [3:0]      c_hi, c_hi_ref;
	always_comb begin
		c_lo = 32'h11223344;
		c_hi = 4'b1010;
		{c_lo[i], c_hi[i]} = d;

		c_lo_ref = 32'h11223344;
		c_hi_ref = 4'b1010;
		c_lo_ref[i] = d[8:1];
		c_hi_ref[i] = d[0];
	end
	always_comb assert(c_lo == c_lo_ref);
	always_comb assert(c_hi == c_hi_ref);
endmodule
