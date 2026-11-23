#include <gtest/gtest.h>
#include <sstream>
#include "kernel/register.h"
#include "kernel/yosys.h"

YOSYS_NAMESPACE_BEGIN

namespace {

std::string run_write_verilog(const std::string &sv_source, const std::string &backend_cmd = "verilog")
{
	autoidx = 1;
	RTLIL::Design design;
	std::istringstream in(sv_source);
	Frontend::frontend_call(&design, &in, "<test.sv>", "verilog -sv");
	Pass::call(&design, "proc -norom");
	std::ostringstream out;
	Backend::backend_call(&design, &out, "<out.v>", backend_cmd);
	return out.str();
}

size_t count_occurrences(const std::string &haystack, const std::string &needle)
{
	size_t count = 0;
	size_t pos = 0;
	while ((pos = haystack.find(needle, pos)) != std::string::npos) {
		++count;
		pos += needle.size();
	}
	return count;
}

} // namespace

TEST(VerilogBackendTest, PmuxDoesNotDuplicateParallelCaseAttribute)
{
	const std::string sv_with_attr = R"(
module top (
	input  logic [2:0] sel,
	input  logic [7:0] a,
	input  logic [7:0] b,
	input  logic [7:0] c,
	output logic [7:0] y
);
	always_comb begin
		(* full_case, parallel_case *)
		case (sel)
			3'b001: y = a;
			3'b010: y = b;
			3'b100: y = c;
			default: y = 8'h00;
		endcase
	end
endmodule
)";

	std::string out = run_write_verilog(sv_with_attr);
	size_t func_pos = out.find("function ");
	ASSERT_NE(func_pos, std::string::npos) << out;
	size_t endfunc_pos = out.find("endfunction", func_pos);
	ASSERT_NE(endfunc_pos, std::string::npos) << out;
	std::string func_body = out.substr(func_pos, endfunc_pos - func_pos);

	ASSERT_NE(func_body.find("casez (s)"), std::string::npos) << func_body;
	EXPECT_NE(func_body.find("(* parallel_case = 32'd1 *)"), std::string::npos) << func_body;
	EXPECT_EQ(func_body.find("(* parallel_case *)"), std::string::npos)
		<< "Duplicate bare (* parallel_case *) emitted alongside valued attribute:\n" << func_body;
	EXPECT_EQ(count_occurrences(func_body, "parallel_case"), 1u) << func_body;

	// With -attr2comment, cell attributes become /* ... */ comments, so bare
	// (* parallel_case *) is not a duplicate attribute and should still be emitted.
	std::string out_comment = run_write_verilog(sv_with_attr, "verilog -attr2comment");
	ASSERT_NE(out_comment.find("casez (s)"), std::string::npos) << out_comment;
	EXPECT_NE(out_comment.find("/* parallel_case = 32'd1 */"), std::string::npos) << out_comment;
	EXPECT_NE(out_comment.find("(* parallel_case *)"), std::string::npos) << out_comment;

	// With -noattr, no (* ... *) attributes are emitted and synopsys comment is kept.
	std::string out_noattr = run_write_verilog(sv_with_attr, "verilog -noattr");
	EXPECT_EQ(out_noattr.find("(*"), std::string::npos) << out_noattr;
	EXPECT_NE(out_noattr.find("// synopsys parallel_case"), std::string::npos) << out_noattr;
}

TEST(VerilogBackendTest, PmuxWithoutAttributeStillEmitsParallelCase)
{
	const std::string sv_plain = R"(
module top (
	input  logic [1:0] sel,
	input  logic [7:0] a,
	input  logic [7:0] b,
	input  logic [7:0] c,
	output logic [7:0] y
);
	always_comb begin
		case (sel)
			2'b00: y = a;
			2'b01: y = b;
			2'b10: y = c;
			default: y = 8'h00;
		endcase
	end
endmodule
)";

	std::string out = run_write_verilog(sv_plain);
	ASSERT_NE(out.find("casez (s)"), std::string::npos) << out;
	EXPECT_NE(out.find("(* parallel_case *)"), std::string::npos) << out;
	EXPECT_EQ(count_occurrences(out, "parallel_case"), 1u) << out;
}

TEST(VerilogBackendTest, PmuxWithFalseParallelCaseAttributeEmitsTrueMarkerWithoutConflict)
{
	const std::string sv_false_attr = R"(
module top (
	input  logic [1:0] sel,
	input  logic [7:0] a,
	input  logic [7:0] b,
	input  logic [7:0] c,
	output logic [7:0] y
);
	always_comb begin
		(* full_case, parallel_case = 0 *)
		case (sel)
			2'b00: y = a;
			2'b01: y = b;
			2'b10: y = c;
			default: y = 8'h00;
		endcase
	end
endmodule
)";

	std::string out = run_write_verilog(sv_false_attr);
	size_t func_pos = out.find("function ");
	ASSERT_NE(func_pos, std::string::npos) << out;
	size_t endfunc_pos = out.find("endfunction", func_pos);
	ASSERT_NE(endfunc_pos, std::string::npos) << out;
	std::string func_body = out.substr(func_pos, endfunc_pos - func_pos);

	ASSERT_NE(func_body.find("casez (s)"), std::string::npos) << func_body;
	EXPECT_NE(func_body.find("(* full_case = 32'd1 *)"), std::string::npos) << func_body;
	EXPECT_NE(func_body.find("(* parallel_case *)"), std::string::npos) << func_body;
	EXPECT_EQ(func_body.find("parallel_case = 32'd0"), std::string::npos) << func_body;
	EXPECT_EQ(count_occurrences(func_body, "parallel_case"), 1u) << func_body;
}

YOSYS_NAMESPACE_END
