// GitHub issue #52: arr[i].field on a packed array of packed structs.
// A constant or genvar index used to create an implicit wire. A variable
// index used to fail as a generate-block prefix.
module top(
	input logic [19:0] in,
	input logic [1:0] i,
	input logic [1:0] j,
	input logic [2:0] member_j,
	input logic signed [3:0] member_signed_j,
	input logic signed [2:0] outer_idx,
	input logic [1:0] multidim_j,
	output logic y_const,
	output logic [3:0] z_gen,
	output logic y_var,
	output logic y_dynamic_bit,
	output logic [3:0] z_lhs0,
	output logic [3:0] z_lhs1,
	input logic signed_i
);
	typedef struct packed { logic a; logic [3:0] b; } s_t; // a at bit 4, b at bits [3:0]
	s_t [3:0] arr;
	assign arr = in;
	localparam integer member_bits = $bits(arr[0].b);
	localparam integer member_size = $size(arr[0].b);
	localparam integer member_dimensions = $dimensions(arr[0].b);
	localparam integer selected_member_bits = $bits(arr[0].b[3:2]);
	assign y_const = arr[2].a;
	for (genvar k = 1; k < 2; k++) begin : g
		assign z_gen = arr[k].b;
	end
	assign y_var = arr[i].a;
	assign y_dynamic_bit = arr[i].b[j];
	logic dynamic_member_bit;
	assign dynamic_member_bit = arr[0].b[member_j];
	s_t [1:0] dynamic_write;

	typedef struct packed { logic a; logic [1:0][3:0] b; } multidim_s_t;
	multidim_s_t [1:0] multidim_arr;
	logic [3:0] multidim_dynamic_select;
	localparam integer multidim_dynamic_bits = $bits(multidim_arr[0].b[multidim_j]);
	assign multidim_arr = 18'h187a5;
	assign multidim_dynamic_select = multidim_arr[0].b[multidim_j];

	s_t [1:0] cls;
	for (genvar k = 0; k < 2; k++) begin : h
		assign cls[k].b = in[k * 4 +: 4];
	end
	assign z_lhs0 = cls[0].b;
	assign z_lhs1 = cls[1].b;

	typedef struct packed { logic signed [3:0] value; } signed_s_t;
	signed_s_t [1:0] signed_arr;
	logic [3:0] signed_shift;
	logic [4:0] signed_extend;
	logic [1:0] signed_bit_extend;
	logic [2:0] signed_part_extend;
	assign signed_arr = {4'b0100, 4'b1100};
	assign signed_shift = signed_arr[signed_i].value >>> 1;
	assign signed_extend = signed_arr[signed_i].value;
	assign signed_bit_extend = signed_arr[0].value[2];
	assign signed_part_extend = signed_arr[0].value[3:2];

	logic oob_read;
	logic oob_low_read;
	logic [2:0] oob_part_read;
	logic [2:0] oob_low_part_read;
	s_t [1:0] combo_arr;
	logic combo_const_neg_read;
	logic combo_const_pos_read;
	logic combo_dynamic_read;
	logic combo_const_neg_signed_read;
	logic combo_dynamic_signed_read;
	assign oob_read = arr[0].b[4];
	assign oob_low_read = arr[0].b[-1];
	assign oob_part_read = arr[0].b[4:2];
	assign oob_low_part_read = arr[0].b[1:-1];
	assign combo_arr = '0;
	assign combo_const_neg_read = combo_arr[-1].b[member_j];
	assign combo_const_pos_read = combo_arr[2].b[member_j];
	assign combo_dynamic_read = combo_arr[outer_idx].b[member_j];
	assign combo_const_neg_signed_read = combo_arr[-1].b[member_signed_j];
	assign combo_dynamic_signed_read = combo_arr[outer_idx].b[member_signed_j];
	s_t [1:0] oob_write;
	s_t [1:0] combo_const_neg_write;
	s_t [1:0] combo_const_pos_write;
	s_t [1:0] combo_dynamic_write;
	s_t [1:0] combo_const_neg_signed_write;
	s_t [1:0] combo_dynamic_signed_write;
	always_comb begin
		oob_write = '0;
		oob_write[0].b = 4'b0101;
		oob_write[0].b[4:2] = 3'b101;
		assert(oob_read === 1'bx);
		assert(oob_low_read === 1'bx);
		assert(oob_part_read === {1'bx, arr[0].b[3:2]});
		assert(oob_low_part_read === {arr[0].b[1:0], 1'bx});
		assert(oob_write[0].a == 1'b0);
		assert(oob_write[0].b[3:2] == 2'b01);
		assert(combo_const_neg_read === 1'bx);
		assert(combo_const_pos_read === 1'bx);
		assert((outer_idx >= 0 && outer_idx <= 1 && member_j < 4) || combo_dynamic_read === 1'bx);
		assert(combo_const_neg_signed_read === 1'bx);
		assert((outer_idx >= 0 && outer_idx <= 1 && member_signed_j >= 0 && member_signed_j < 4) || combo_dynamic_signed_read === 1'bx);

		combo_const_neg_write = '0;
		combo_const_neg_write[-1].b[member_j] = 1'b1;
		assert(combo_const_neg_write == '0);
		combo_const_pos_write = '0;
		combo_const_pos_write[2].b[member_j] = 1'b1;
		assert(combo_const_pos_write == '0);
		combo_dynamic_write = '0;
		combo_dynamic_write[outer_idx].b[member_j] = 1'b1;
		if (outer_idx < 0 || outer_idx > 1 || member_j >= 4)
			assert(combo_dynamic_write == '0);
		combo_const_neg_signed_write = '0;
		combo_const_neg_signed_write[-1].b[member_signed_j] = 1'b1;
		assert(combo_const_neg_signed_write == '0);
		combo_dynamic_signed_write = '0;
		combo_dynamic_signed_write[outer_idx].b[member_signed_j] = 1'b1;
		if (outer_idx < 0 || outer_idx > 1 || member_signed_j < 0 || member_signed_j >= 4)
			assert(combo_dynamic_signed_write == '0);
	end

	always_comb assert(y_const == in[14]);
	always_comb assert(z_gen == in[8:5]);
	always_comb assert(y_var == in[(i * 5) + 4]);
	always_comb assert(y_dynamic_bit == in[(i * 5) + j]);
	always_comb assert(member_j < 4 ? dynamic_member_bit == in[member_j] : dynamic_member_bit === 1'bx);
	always_comb assert(multidim_dynamic_bits == 4);
	always_comb assert(multidim_j == 0 ? multidim_dynamic_select == 4'h5 :
		multidim_j == 1 ? multidim_dynamic_select == 4'ha : multidim_dynamic_select === 4'bxxxx);
	always_comb begin
		dynamic_write = '0;
		dynamic_write[0].b[member_j] = 1'b1;
		assert(dynamic_write[0].a == 1'b0);
		assert(member_j < 4 ? dynamic_write[0].b == (4'b0001 << member_j) : dynamic_write[0].b == 4'b0000);
	end
	always_comb assert(z_lhs0 == in[3:0]);
	always_comb assert(z_lhs1 == in[7:4]);
	always_comb assert(member_bits == 4);
	always_comb assert(member_size == 4);
	always_comb assert(member_dimensions == 1);
	always_comb assert(selected_member_bits == 2);
	always_comb assert(signed_i ? signed_shift == 4'b0010 : signed_shift == 4'b1110);
	always_comb assert(signed_i ? signed_extend == 5'b00100 : signed_extend == 5'b11100);
	always_comb assert(signed_bit_extend == 2'b01);
	always_comb assert(signed_part_extend == 3'b011);
endmodule
