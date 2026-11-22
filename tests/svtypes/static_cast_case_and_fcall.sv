// GitHub issue #72: static cast of a non-constant expression to a typedef
// (enum, vector, struct, or atom type) in a case selector or function call.
package p;
	typedef enum logic [1:0] {A = 2'd0, B = 2'd1, C = 2'd2} e_t;
endpackage

module top (
	input  logic [1:0] sel,
	output logic [7:0] y_pkg_enum,
	output logic [7:0] y_local_vec,
	output logic [7:0] y_atom,
	output logic [7:0] y_fcall
);
	typedef logic [1:0] w_t;

	function automatic logic [7:0] decode_enum(input p::e_t e);
		case (e)
			p::A: decode_enum = 8'h11;
			p::B: decode_enum = 8'h22;
			p::C: decode_enum = 8'h33;
			default: decode_enum = 8'h00;
		endcase
	endfunction

	always_comb begin
		case (p::e_t'(sel))
			p::A: y_pkg_enum = 8'h01;
			p::B: y_pkg_enum = 8'h02;
			default: y_pkg_enum = 8'h00;
		endcase

		case (w_t'(sel))
			2'd0: y_local_vec = 8'h01;
			2'd1: y_local_vec = 8'h02;
			default: y_local_vec = 8'h00;
		endcase

		case (int'(sel))
			0: y_atom = 8'h01;
			1: y_atom = 8'h02;
			default: y_atom = 8'h00;
		endcase

		y_fcall = decode_enum(p::e_t'(sel));
	end

	always_comb assert(y_pkg_enum == (sel == 2'd0 ? 8'h01 : sel == 2'd1 ? 8'h02 : 8'h00));
	always_comb assert(y_local_vec == y_pkg_enum);
	always_comb assert(y_atom == y_pkg_enum);
	always_comb assert(y_fcall == (sel == 2'd0 ? 8'h11 : sel == 2'd1 ? 8'h22 : sel == 2'd2 ? 8'h33 : 8'h00));
endmodule
