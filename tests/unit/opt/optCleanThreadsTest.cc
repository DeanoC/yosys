#include <gtest/gtest.h>
#include "kernel/yosys.h"
#include "passes/opt/clean/opt_clean.h"

YOSYS_NAMESPACE_BEGIN

namespace {

RTLIL::Module *build_memories_module(RTLIL::Design *design, int num_mems, int reads_per_mem, int writes_per_mem)
{
	RTLIL::Module *mod = design->addModule("\\top");
	RTLIL::Wire *clk = mod->addWire("\\clk");
	clk->port_input = true;
	RTLIL::Wire *addr = mod->addWire("\\addr", 4);
	addr->port_input = true;
	RTLIL::Wire *din = mod->addWire("\\din", 8);
	din->port_input = true;
	RTLIL::Wire *wen = mod->addWire("\\wen");
	wen->port_input = true;

	for (int m = 0; m < num_mems; ++m) {
		std::string mem_name = stringf("\\mem_%d", m);
		RTLIL::Memory *mem = mod->addMemory(mem_name);
		mem->width = 8;
		mem->size = 16;

		for (int r = 0; r < reads_per_mem; ++r) {
			RTLIL::Wire *rdata = mod->addWire(stringf("\\rdata_%d_%d", m, r), 8);
			rdata->port_output = true;
			RTLIL::Cell *rd = mod->addCell(stringf("$rd_%d_%d", m, r), ID($memrd_v2));
			rd->setParam(ID::MEMID, RTLIL::Const(mem_name));
			rd->setParam(ID::ABITS, 4);
			rd->setParam(ID::WIDTH, 8);
			rd->setParam(ID::CLK_ENABLE, 0);
			rd->setParam(ID::CLK_POLARITY, 1);
			rd->setParam(ID::TRANSPARENCY_MASK, RTLIL::Const(0, 0));
			rd->setParam(ID::COLLISION_X_MASK, RTLIL::Const(0, 0));
			rd->setParam(ID::ARST_VALUE, RTLIL::Const(RTLIL::State::Sx, 8));
			rd->setParam(ID::SRST_VALUE, RTLIL::Const(RTLIL::State::Sx, 8));
			rd->setParam(ID::INIT_VALUE, RTLIL::Const(RTLIL::State::Sx, 8));
			rd->setParam(ID::CE_OVER_SRST, 0);
			rd->setPort(ID::CLK, RTLIL::State::S0);
			rd->setPort(ID::EN, RTLIL::State::S1);
			rd->setPort(ID::ARST, RTLIL::State::S0);
			rd->setPort(ID::SRST, RTLIL::State::S0);
			rd->setPort(ID::ADDR, addr);
			rd->setPort(ID::DATA, rdata);
		}

		for (int w = 0; w < writes_per_mem; ++w) {
			RTLIL::Wire *wdata = mod->addWire(stringf("\\wdata_%d_%d", m, w), 8);
			mod->addNot(stringf("$inv_%d_%d", m, w), din, wdata);

			RTLIL::Cell *wr = mod->addCell(stringf("$wr_%d_%d", m, w), ID($memwr_v2));
			wr->setParam(ID::MEMID, RTLIL::Const(mem_name));
			wr->setParam(ID::ABITS, 4);
			wr->setParam(ID::WIDTH, 8);
			wr->setParam(ID::CLK_ENABLE, 1);
			wr->setParam(ID::CLK_POLARITY, 1);
			wr->setParam(ID::PORTID, w);
			wr->setParam(ID::PRIORITY_MASK, RTLIL::Const(0, writes_per_mem));
			wr->setPort(ID::CLK, clk);
			wr->setPort(ID::EN, RTLIL::SigSpec(wen).repeat(8));
			wr->setPort(ID::ADDR, addr);
			wr->setPort(ID::DATA, wdata);
		}
	}

	mod->fixup_ports();
	return mod;
}

} // namespace

TEST(OptCleanThreadsTest, MemoriesAtRehashBoundary)
{
	// 12 memories leaves dict<std::string, int> at entries.size() == 12,
	// hashtable.size() == 23 (12 * hashtable_size_trigger > 23).
	for (int iter = 0; iter < 5; ++iter) {
		RTLIL::Design design;
		RTLIL::Module *mod = build_memories_module(&design, 12, 8, 4);
		int expected_cells = mod->cells_size();

		std::vector<RTLIL::Module*> selected_modules = {mod};
		CleanRunContext clean_ctx(&design, selected_modules, {true, false});
		ParallelDispatchThreadPool pool(4);
		ParallelDispatchThreadPool::Subpool subpool(pool, 4);

		rmunused_module_cells(mod, subpool, clean_ctx);

		EXPECT_EQ(GetSize(mod->memories), 12);
		EXPECT_EQ(mod->cells_size(), expected_cells);
		design.check();
	}
}

TEST(OptCleanThreadsTest, ModulesAtRehashBoundary)
{
	// 12 modules leaves design->modules_ at entries.size() == 12, hashtable.size() == 23.
	for (int iter = 0; iter < 5; ++iter) {
		RTLIL::Design design;
		RTLIL::Module *top = design.addModule("\\top");
		RTLIL::Wire *in = top->addWire("\\in");
		in->port_input = true;

		for (int m = 0; m < 11; ++m) {
			RTLIL::Module *sub = design.addModule(stringf("\\sub_%d", m));
			sub->set_bool_attribute(ID::blackbox, true);
			RTLIL::Wire *a = sub->addWire("\\A");
			a->port_input = true;
			RTLIL::Wire *y = sub->addWire("\\Y");
			y->port_output = true;
			sub->fixup_ports();

			for (int k = 0; k < 200; ++k) {
				RTLIL::Wire *out = top->addWire(stringf("\\out_%d_%d", m, k));
				out->port_output = true;
				RTLIL::Cell *c = top->addCell(stringf("$inst_%d_%d", m, k), sub->name);
				c->setPort(ID::A, in);
				c->setPort(ID::Y, out);
			}
		}
		top->fixup_ports();

		std::vector<RTLIL::Module*> selected_modules = {top};
		CleanRunContext clean_ctx(&design, selected_modules, {true, false});
		ParallelDispatchThreadPool pool(4);
		ParallelDispatchThreadPool::Subpool subpool(pool, 4);

		rmunused_module_cells(top, subpool, clean_ctx);

		EXPECT_EQ(top->cells_size(), 2200);
		design.check();
	}
}

YOSYS_NAMESPACE_END
