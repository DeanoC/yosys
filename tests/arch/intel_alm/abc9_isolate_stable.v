// Large combinational payload between registers, plus a separate cone whose
// gate count depends on BUILD_ID. Mapping of `y` must not follow BUILD_ID.
module top #(parameter [127:0] BUILD_ID = 128'd0) (
	input wire clk,
	input wire [31:0] a,
	input wire [31:0] b,
	input wire [127:0] id_in,
	output reg [31:0] y,
	output reg idbit
);
	localparam N = 64;
	reg [31:0] a_q, b_q;
	reg [127:0] id_q;

	always @(posedge clk) begin
		a_q <= a;
		b_q <= b;
		id_q <= id_in;
	end

	wire [31:0] stage_b [0:N];
	assign stage_b[0] = a_q ^ b_q;
	genvar i;
	generate
		for (i = 0; i < N; i = i + 1) begin : g
			wire [31:0] sum = stage_b[i] + {stage_b[i][30:0], stage_b[i][31]};
			assign stage_b[i+1] = sum ^ {sum[7:0], sum[31:8]} ^ (i * 32'h9E3779B9);
		end
	endgenerate

	always @(posedge clk) begin
		y <= stage_b[N];
		idbit <= &(id_q | BUILD_ID);
	end
endmodule
