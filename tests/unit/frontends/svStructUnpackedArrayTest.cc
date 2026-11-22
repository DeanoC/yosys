#include <gtest/gtest.h>
#include <sstream>
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/yosys.h"

YOSYS_NAMESPACE_BEGIN

namespace {

struct ScopedLogCapture {
	std::ostringstream buf;
	LogManager::Scoped guard;
	ScopedLogCapture() : guard(logger()) {
		logger().add_sink<StreamLogSink>(buf);
		logger().add_sink<StderrLogSink>(false);
	}
	std::string str() const { return buf.str(); }
};

std::string elaborate_to_verilog(const std::string &sv_source, const std::string &top, std::string &logs)
{
	ScopedLogCapture capture;
	autoidx = 1;
	RTLIL::Design design;
	std::istringstream in(sv_source);
	Frontend::frontend_call(&design, &in, "<test.sv>", "verilog -sv");
	Pass::call(&design, "hierarchy -top " + top);
	Pass::call(&design, "proc -norom");
	Pass::call(&design, "flatten");
	Pass::call(&design, "opt_expr");
	Pass::call(&design, "opt_clean -purge");
	std::ostringstream out;
	Backend::backend_call(&design, &out, "<out.v>", "verilog");
	logs = capture.str();
	return out.str();
}

} // namespace

TEST(SvStructUnpackedArrayTest, Issue79PipelineStageRepro)
{
	const std::string sv_source = R"(
module repro (
	input  logic       clk,
	input  logic [7:0] in,
	output logic [7:0] out,
	output logic [7:0] ok_out
);
	typedef struct packed { logic [7:0] value; logic flag; } item_t;
	item_t stage [1:2];
	item_t copy2;
	assign copy2 = stage[2];
	always_ff @(posedge clk) begin
		stage[1].value <= in;
		stage[1].flag  <= 1'b1;
		stage[2] <= stage[1];
		out    <= stage[2].value;
		ok_out <= copy2.value;
	end
endmodule
)";

	std::string logs;
	std::string verilog = elaborate_to_verilog(sv_source, "repro", logs);

	EXPECT_EQ(logs.find("implicitly declared"), std::string::npos) << logs;
	EXPECT_EQ(verilog.find("assign ok_out = 8'h00"), std::string::npos) << verilog;
	EXPECT_EQ(verilog.find("assign out = 8'h00"), std::string::npos) << verilog;
	EXPECT_EQ(verilog.find("assign out[7:1] = 7'h00"), std::string::npos) << verilog;

	// Verify both out and ok_out are driven by $dff cells (not constant zeros).
	autoidx = 1;
	RTLIL::Design design;
	std::istringstream in(sv_source);
	Frontend::frontend_call(&design, &in, "<test.sv>", "verilog -sv");
	Pass::call(&design, "hierarchy -top repro");
	Pass::call(&design, "proc -norom");
	Pass::call(&design, "opt_expr");
	Pass::call(&design, "opt_clean -purge");

	RTLIL::Module *mod = design.module(design.twines().find("\\repro"));
	ASSERT_NE(mod, nullptr);

	int dff_count = 0;
	for (auto cell : mod->cells()) {
		if (cell->type == ID($dff))
			++dff_count;
	}
	// Expect at least stage[1] (value), stage[2] (value), out, ok_out DFFs.
	EXPECT_GE(dff_count, 3) << verilog;
}

TEST(SvStructUnpackedArrayTest, VariableIndexedMemoryReadAndWrite)
{
	const std::string sv_source = R"(
module ram_top (
	input  logic       clk,
	input  logic [1:0] waddr,
	input  logic [1:0] raddr,
	input  logic [7:0] wval,
	input  logic       wflag,
	output logic [7:0] rval,
	output logic       rflag
);
	typedef struct packed {
		logic [7:0] value;
		logic       flag;
	} item_t;
	item_t mem [0:3];
	always_ff @(posedge clk) begin
		mem[waddr].value <= wval;
		mem[waddr].flag  <= wflag;
	end
	assign rval  = mem[raddr].value;
	assign rflag = mem[raddr].flag;
endmodule
)";

	ScopedLogCapture capture;
	autoidx = 1;
	RTLIL::Design design;
	std::istringstream in(sv_source);
	Frontend::frontend_call(&design, &in, "<ram.sv>", "verilog -sv");
	Pass::call(&design, "hierarchy -top ram_top");
	Pass::call(&design, "proc -norom");
	Pass::call(&design, "opt_expr");
	Pass::call(&design, "opt_clean -purge");

	std::string logs = capture.str();
	EXPECT_EQ(logs.find("implicitly declared"), std::string::npos) << logs;

	RTLIL::Module *mod = design.module(design.twines().find("\\ram_top"));
	ASSERT_NE(mod, nullptr);
	RTLIL::IdString mem_id = mod->twines().find("\\mem");
	ASSERT_TRUE(mod->memories.count(mem_id));
	RTLIL::Memory *mem = mod->memories.at(mem_id);
	EXPECT_EQ(mem->width, 9);
	EXPECT_EQ(mem->size, 4);

	int memwr_count = 0, memrd_count = 0;
	for (auto cell : mod->cells()) {
		if (cell->type.in(ID($memwr), ID($memwr_v2)))
			++memwr_count;
		if (cell->type == ID($memrd))
			++memrd_count;
	}
	EXPECT_EQ(memwr_count, 2);
	EXPECT_GE(memrd_count, 1);
}

TEST(SvStructUnpackedArrayTest, NestedSignedSubselectAndQueryFunctions)
{
	const std::string sv_source = R"(
module detail_top (
	input  logic              clk,
	input  logic signed [3:0] din,
	input  logic [1:0]        bit_idx,
	output logic signed [4:0] sext_out,
	output logic [1:0]        part_out,
	output logic              dyn_bit_out,
	output logic [3:0]        nested_out,
	output logic [7:0]        bits_val,
	output logic [7:0]        size_val
);
	typedef struct packed {
		logic [3:0] hi;
		logic [3:0] lo;
	} sub_t;
	typedef struct packed {
		logic signed [3:0] sval;
		sub_t              sub;
	} outer_t;

	outer_t arr [1:2];
	localparam int LP_BITS = $bits(arr[1].sval);
	localparam int LP_SIZE = $size(arr[1].sub.lo);

	always_ff @(posedge clk) begin
		arr[1].sval   <= din;
		arr[1].sub.lo <= 4'hA;
		arr[1].sub.hi <= 4'h5;
		arr[2]        <= arr[1];
	end

	assign sext_out    = arr[2].sval;
	assign part_out    = arr[2].sub.lo[3:2];
	assign dyn_bit_out = arr[2].sub.lo[bit_idx];
	assign nested_out  = arr[2].sub.hi;
	assign bits_val    = LP_BITS[7:0];
	assign size_val    = LP_SIZE[7:0];
endmodule
)";

	std::string logs;
	std::string verilog = elaborate_to_verilog(sv_source, "detail_top", logs);
	EXPECT_EQ(logs.find("implicitly declared"), std::string::npos) << logs;
	EXPECT_NE(verilog.find("assign bits_val = 8'h04;"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("assign size_val = 8'h04;"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("\\arr[1]  <= { din, 8'h5a };"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("\\arr[2]  <= \\arr[1] ;"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("assign nested_out = \\arr[2] [7:4];"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("assign part_out = \\arr[2] [3:2];"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("assign sext_out = { \\arr[2] [11], \\arr[2] [11:8] };"), std::string::npos) << verilog;
}

TEST(SvStructUnpackedArrayTest, PackedAndUnpackedSideBySide)
{
	const std::string sv_source = R"(
module both_top (
	input  logic       clk,
	input  logic [7:0] in,
	output logic [7:0] u_out,
	output logic [7:0] p_out
);
	typedef struct packed { logic [7:0] value; logic flag; } item_t;
	item_t u_stage [1:2];
	item_t [1:2] p_stage;
	always_ff @(posedge clk) begin
		u_stage[1].value <= in;
		u_stage[1].flag  <= 1'b1;
		u_stage[2]       <= u_stage[1];
		u_out            <= u_stage[2].value;

		p_stage[1].value <= in;
		p_stage[1].flag  <= 1'b1;
		p_stage[2]       <= p_stage[1];
		p_out            <= p_stage[2].value;
	end
endmodule
)";

	std::string logs;
	std::string verilog = elaborate_to_verilog(sv_source, "both_top", logs);
	EXPECT_EQ(logs.find("implicitly declared"), std::string::npos) << logs;
	EXPECT_EQ(verilog.find("assign u_out = 8'h00"), std::string::npos) << verilog;
	EXPECT_EQ(verilog.find("assign p_out = 8'h00"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("u_out <= \\u_stage[2] [8:1];"), std::string::npos) << verilog;
	EXPECT_NE(verilog.find("p_out <= p_stage[8:1];"), std::string::npos) << verilog;
}

YOSYS_NAMESPACE_END
