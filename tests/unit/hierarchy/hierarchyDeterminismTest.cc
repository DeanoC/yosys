#include <gtest/gtest.h>
#include <sstream>
#include "kernel/register.h"
#include "kernel/yosys.h"

YOSYS_NAMESPACE_BEGIN

namespace {

std::string elaborate_to_verilog(const std::string &sv_source)
{
	autoidx = 1;
	RTLIL::Design design;
	std::istringstream in(sv_source);
	Frontend::frontend_call(&design, &in, "<test.sv>", "verilog -sv");
	Pass::call(&design, "hierarchy -top top");
	Pass::call(&design, "flatten");
	Pass::call(&design, "opt_clean -purge");
	std::ostringstream out;
	Backend::backend_call(&design, &out, "<out.v>", "verilog");
	return out.str();
}

} // namespace

TEST(HierarchyDeterminismTest, ExpansionOrderIndependentOfHeapLayout)
{
	const std::string sv_source = R"(
module leaf #(parameter int W = 4) (
	input  logic [W-1:0] a,
	output logic [W-1:0] y
);
	function automatic logic [W-1:0] transform(input logic [W-1:0] x);
		transform = x ^ {W{1'b1}};
	endfunction
	assign y = transform(a) + W[W-1:0];
endmodule

module mid_a (input logic [3:0] a, output logic [3:0] y);
	leaf #(.W(4)) u0 (.a(a), .y(y));
endmodule

module mid_b (input logic [4:0] a, output logic [4:0] y);
	leaf #(.W(5)) u0 (.a(a), .y(y));
endmodule

module mid_c (input logic [5:0] a, output logic [5:0] y);
	leaf #(.W(6)) u0 (.a(a), .y(y));
endmodule

module mid_d (input logic [6:0] a, output logic [6:0] y);
	leaf #(.W(7)) u0 (.a(a), .y(y));
endmodule

module top (
	input  logic [3:0] a,
	input  logic [4:0] b,
	input  logic [5:0] c,
	input  logic [6:0] d,
	output logic [3:0] ya,
	output logic [4:0] yb,
	output logic [5:0] yc,
	output logic [6:0] yd
);
	mid_a ua (.a(a), .y(ya));
	mid_b ub (.a(b), .y(yb));
	mid_c uc (.a(c), .y(yc));
	mid_d ud (.a(d), .y(yd));
endmodule
)";

	std::string baseline = elaborate_to_verilog(sv_source);
	ASSERT_FALSE(baseline.empty());

	// Scramble heap layout between runs (including varying string allocations
	// analogous to differing CLI/log/script paths) so RTLIL::Module* addresses
	// change relative order.
	memhasher_on();
	for (int iter = 0; iter < 16; ++iter) {
		std::vector<std::string> path_noise;
		for (int k = 0; k < 32; ++k)
			path_noise.emplace_back(static_cast<size_t>((iter * 17 + k * 7) % 128 + 1), 'x');
		for (int j = 0; j < 256; ++j)
			memhasher_do();
		std::string actual = elaborate_to_verilog(sv_source);
		EXPECT_EQ(actual, baseline) << "Verilog output changed on heap-scrambled iteration " << iter;
	}
	memhasher_off();
}

TEST(HierarchyDeterminismTest, BlackboxDerivativesOrderIndependentOfHeapLayout)
{
	const std::string sv_source = R"(
(* blackbox, dynports *)
module bb #(parameter int W = 4) (
	input  logic [W-1:0] a,
	output logic [W-1:0] y
);
endmodule

module wrap_a (input logic [3:0] a, output logic [3:0] y);
	bb #(.W(4)) u0 (.*);
endmodule

module wrap_b (input logic [4:0] a, output logic [4:0] y);
	bb #(.W(5)) u0 (.*);
endmodule

module wrap_c (input logic [5:0] a, output logic [5:0] y);
	bb #(.W(6)) u0 (.*);
endmodule

module top (
	input  logic [3:0] a,
	input  logic [4:0] b,
	input  logic [5:0] c,
	output logic [3:0] ya,
	output logic [4:0] yb,
	output logic [5:0] yc
);
	wrap_a ua (.a(a), .y(ya));
	wrap_b ub (.a(b), .y(yb));
	wrap_c uc (.a(c), .y(yc));
endmodule
)";

	auto run_hierarchy_modules = [&](const std::string &src) {
		autoidx = 1;
		RTLIL::Design design;
		std::istringstream in(src);
		Frontend::frontend_call(&design, &in, "<bb.sv>", "verilog -sv");
		Pass::call(&design, "hierarchy -top top");
		std::vector<std::string> mod_names;
		for (auto mod : design.modules())
			mod_names.push_back(mod->name.str());
		return mod_names;
	};

	auto baseline = run_hierarchy_modules(sv_source);
	ASSERT_FALSE(baseline.empty());

	memhasher_on();
	for (int iter = 0; iter < 16; ++iter) {
		for (int j = 0; j < 256; ++j)
			memhasher_do();
		auto actual = run_hierarchy_modules(sv_source);
		EXPECT_EQ(actual, baseline) << "Module order changed on heap-scrambled iteration " << iter;
	}
	memhasher_off();
}

YOSYS_NAMESPACE_END
