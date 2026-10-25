module top;
	typedef struct packed { logic [1:0] a, b, c; } triple_t;

	function automatic logic out_of_range_read();
		triple_t s;
		s.a = 2'b01;
		s.b = 2'b00;
		s.c = 2'b00;
		out_of_range_read = s.b[2];
	endfunction

	function automatic triple_t out_of_range_write();
		triple_t s;
		s.a = 2'b00;
		s.b = 2'b00;
		s.c = 2'b00;
		s.b[2] = 1'b1;
		out_of_range_write = s;
	endfunction

	localparam logic read_result = out_of_range_read();
	localparam logic [5:0] write_result = out_of_range_write();

	always_comb assert(read_result === 1'bx);
	always_comb assert(write_result === 6'b0);
endmodule
