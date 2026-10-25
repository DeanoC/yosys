// GitHub issue #33: a constant-argument call of a function that builds a
// packed struct by member assignment must keep every member, not only the last.
module top(input logic ia, output logic [3:0] y_wire, output logic [3:0] y_const);
	typedef struct packed { logic a; logic b; logic [1:0] e; } form_t;
	typedef struct packed { logic [1:0] a; logic [1:0] b; logic [1:0] e; } wide_t;

	function automatic form_t form(input logic xa, input logic xb, input logic [1:0] xe);
		form_t f;
		f.a = xa;
		f.b = xb;
		f.e = xe;
		form = f;
	endfunction

	function automatic wide_t wide(input logic [1:0] xa, input logic [1:0] xb, input logic [1:0] xe);
		wide_t f;
		f.a = xa;
		f.b = xb;
		f.e = xe;
		// Reading a member back must see the value just written.
		wide = {f.a, f.b, f.e};
	endfunction

	function automatic form_t sliced(input logic [1:0] xe);
		form_t f;
		f.a = 1'b1;
		f.b = 1'b0;
		f.e = xe;
		f.e[0] = 1'b1;
		sliced = f;
	endfunction

	assign y_wire  = form(ia, 1'b0, 2'b10);
	assign y_const = form(1'b1, 1'b0, 2'b10);

	localparam logic [3:0] folded = form(1'b1, 1'b0, 2'b10);
	localparam logic [5:0] wide_c = wide(2'b11, 2'b01, 2'b10);
	localparam logic [3:0] slice_c = sliced(2'b10);

	always_comb assert(y_const == 4'b1010);
	always_comb assert(ia == 1'b0 || y_wire == 4'b1010);
	always_comb assert(ia == 1'b1 || y_wire == 4'b0010);
	always_comb assert(folded == 4'b1010);
	always_comb assert(wide_c == 6'b110110);
	always_comb assert(slice_c == 4'b1011);
endmodule
