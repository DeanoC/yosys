// GitHub issue #35: enum members declared in a package must be visible
// inside that package's functions.
package p;
	typedef enum logic [2:0] { SEG_ES = 3'd0, SEG_CS = 3'd1, SEG_FS = 3'd4 } seg_e;
	typedef struct packed { logic valid; logic [2:0] seg; } pfx_t;

	function automatic logic [2:0] seg_of(input logic [7:0] b);
		case (b)
			8'h26: seg_of = SEG_ES;
			8'h2e: seg_of = SEG_CS;
			8'h64: seg_of = SEG_FS;
			default: seg_of = 3'd7;
		endcase
	endfunction

	function automatic pfx_t add(input pfx_t q, input logic [7:0] b);
		pfx_t r;
		r = q;
		case (b)
			8'h64: begin r.valid = 1'b1; r.seg = SEG_FS; end
			default: ;
		endcase
		add = r;
	endfunction
endpackage

module top(input logic [7:0] b, input logic [3:0] q, output logic [2:0] y, output logic [3:0] y2);
	assign y = p::seg_of(b);
	assign y2 = p::add(q, b);

	always_comb assert(b != 8'h26 || y == 3'd0);
	always_comb assert(b != 8'h2e || y == 3'd1);
	always_comb assert(b != 8'h64 || y == 3'd4);
	always_comb assert(b == 8'h26 || b == 8'h2e || b == 8'h64 || y == 3'd7);
	always_comb assert(b != 8'h64 || y2 == 4'b1100);
	always_comb assert(b == 8'h64 || y2 == q);
endmodule
