// GitHub issue #61: initializers on anonymous enum and packed struct/union variables.
module top (
	input  logic       clk,
	output logic       o,
	output logic [1:0] o_enum,
	output logic [3:0] o_struct_pat,
	output logic [3:0] o_union,
	output logic       o_ref,
	output logic [1:0] o_enum_ref,
	output logic [3:0] o_struct_pat_ref,
	output logic [3:0] o_union_ref
);
	// Case 1: exact issue #61 repro (anonymous enum & packed struct with mixed initialized/uninitialized vars)
	enum {A, B} state = A, next_state;
	struct packed { logic a; logic [2:0] b; } self = 0, next_self;
	always_comb begin
		next_state = state == A ? B : A;
		next_self = self;
		next_self.b = self.b + 1'b1;
	end
	always_ff @(posedge clk) begin
		state <= next_state;
		self <= next_self;
	end
	assign o = state == B && (self.a || self.b[0]);

	// Reference using separate initial blocks
	enum {AR, BR} state_r, next_state_r;
	struct packed { logic a; logic [2:0] b; } self_r, next_self_r;
	initial state_r = AR;
	initial self_r = 0;
	always_comb begin
		next_state_r = state_r == AR ? BR : AR;
		next_self_r = self_r;
		next_self_r.b = self_r.b + 1'b1;
	end
	always_ff @(posedge clk) begin
		state_r <= next_state_r;
		self_r <= next_self_r;
	end
	assign o_ref = state_r == BR && (self_r.a || self_r.b[0]);

	// Case 2: anonymous typed enum with multiple initializers
	enum logic [1:0] {S0 = 2'd1, S1 = 2'd2, S2 = 2'd3} cur = S1, alt = S2;
	always_ff @(posedge clk) begin
		cur <= alt;
		alt <= cur;
	end
	assign o_enum = cur;

	logic [1:0] cur_r, alt_r;
	initial cur_r = 2'd2;
	initial alt_r = 2'd3;
	always_ff @(posedge clk) begin
		cur_r <= alt_r;
		alt_r <= cur_r;
	end
	assign o_enum_ref = cur_r;

	// Case 3: anonymous packed struct initialized with named assignment pattern
	struct packed { logic hi; logic [2:0] lo; } sp = '{hi: 1'b1, lo: 3'd5};
	always_ff @(posedge clk) sp <= {sp.lo, sp.hi};
	assign o_struct_pat = sp;

	logic [3:0] sp_r;
	initial sp_r = 4'b1101;
	always_ff @(posedge clk) sp_r <= {sp_r[2:0], sp_r[3]};
	assign o_struct_pat_ref = sp_r;

	// Case 4: anonymous packed union with initializer
	union packed { logic [3:0] raw; struct packed { logic [1:0] hi; logic [1:0] lo; } parts; } u = 4'hA;
	always_ff @(posedge clk) u.raw <= u.raw + 4'd1;
	assign o_union = u.raw;

	logic [3:0] u_r;
	initial u_r = 4'hA;
	always_ff @(posedge clk) u_r <= u_r + 4'd1;
	assign o_union_ref = u_r;
endmodule
