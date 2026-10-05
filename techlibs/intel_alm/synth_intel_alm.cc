/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Claire Xenia Wolf <claire@yosyshq.com>
 *  Copyright (C) 2019  Hannah Ravensloft <dan.ravensloft@gmail.com>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// Continuous assignments from an internal tri-state source to sibling output
// ports drive independent pins. Split those drivers before opt_clean merges
// aliases. Stop at the first output on each path: assignments that read that
// output must remain on its pad read-back instead of becoming new drivers.
void split_shared_tristate_outputs(RTLIL::Design *design)
{
	for (auto module : design->selected_unboxed_whole_modules()) {
		if (!module->get_bool_attribute(ID::top))
			continue;
		std::vector<RTLIL::Cell *> tristates;
		for (auto cell : module->selected_cells())
			if (cell->type.in(ID($tribuf), ID($_TBUF_)))
				tristates.push_back(cell);
		if (tristates.empty())
			continue;
		dict<RTLIL::SigBit, pool<RTLIL::SigBit>> aliases;
		for (auto &conn : module->connections())
			for (int i = 0; i < GetSize(conn.first); i++)
				aliases[conn.second[i]].insert(conn.first[i]);
		pool<RTLIL::SigBit> split_outputs;
		for (auto cell : tristates) {
			auto sig_y = cell->getPort(ID::Y);
			for (int i = 0; i < GetSize(sig_y); i++) {
				std::vector<RTLIL::SigBit> pending = {sig_y[i]};
				pool<RTLIL::SigBit> visited, outputs;
				while (!pending.empty()) {
					auto bit = pending.back();
					pending.pop_back();
					if (!visited.insert(bit).second || bit.wire == nullptr)
						continue;
					if (bit.wire->port_output) {
						outputs.insert(bit);
						continue;
					}
					if (aliases.count(bit))
						for (auto next : aliases.at(bit))
							pending.push_back(next);
				}
				if (GetSize(outputs) < 2)
					continue;
				for (auto bit : outputs) {
					auto clone = module->addTribuf(NEW_ID, cell->getPort(ID::A)[i],
							cell->getPort(cell->type == ID($tribuf) ? ID::EN : ID::E), bit);
					clone->attributes = cell->attributes;
					split_outputs.insert(bit);
				}
			}
		}
		if (split_outputs.empty())
			continue;
		std::vector<RTLIL::SigSig> connections;
		for (auto &conn : module->connections()) {
			RTLIL::SigSpec lhs, rhs;
			for (int i = 0; i < GetSize(conn.first); i++) {
				if (split_outputs.count(conn.first[i]))
					continue;
				lhs.append(conn.first[i]);
				rhs.append(conn.second[i]);
			}
			if (!lhs.empty())
				connections.emplace_back(lhs, rhs);
		}
		module->new_connections(connections);
	}
}

// iopadmap -toutpad has no pad read-back port: it connects an output net to the
// data input. A tri-state output that is also read must take the -tinoutpad
// path (OE, O, I, PAD) so the read sees MISTRAL_IO.O. Promote those ports to
// inout before opt_clean, then restore the output direction after iopadmap.
// opt_clean keeps a port_input wire, and otherwise the lexicographically
// smaller public name, so a reader named o_rb would take the driver from
// o_read if the port were still output-only.
struct PromotedTristateOutput
{
	RTLIL::Module *module;
	RTLIL::IdString name;
	pool<int> tristate_bits;
};

bool sig_reads(const RTLIL::SigSpec &sig, RTLIL::SigBit bit)
{
	for (auto other : sig)
		if (other == bit)
			return true;
	return false;
}

std::vector<PromotedTristateOutput> promote_read_tristate_outputs(RTLIL::Design *design)
{
	std::vector<PromotedTristateOutput> promoted;
	if (design == nullptr)
		return promoted;
	for (auto module : design->selected_unboxed_whole_modules()) {
		pool<RTLIL::SigBit> tri_y;
		for (auto cell : module->selected_cells()) {
			if (!cell->type.in(ID($tribuf), ID($_TBUF_)))
				continue;
			for (auto bit : cell->getPort(ID::Y))
				if (bit.wire != nullptr)
					tri_y.insert(bit);
		}
		for (auto wire : module->selected_wires()) {
			if (!wire->port_output || wire->port_input || wire->width < 1)
				continue;
			bool any_read = false;
			pool<int> tristate_bits;
			for (int i = 0; i < wire->width; i++) {
				RTLIL::SigBit bit(wire, i);
				bool driven = tri_y.count(bit);
				if (!driven) {
					for (auto &conn : module->connections()) {
						for (int k = 0; k < GetSize(conn.first) && k < GetSize(conn.second); k++)
							if (conn.first[k] == bit && tri_y.count(conn.second[k]))
								driven = true;
					}
				}
				if (!driven)
					continue;
				tristate_bits.insert(i);
				for (auto cell : module->selected_cells()) {
					for (auto &conn : cell->connections())
						if (cell->input(conn.first) && sig_reads(conn.second, bit))
							any_read = true;
				}
				for (auto &conn : module->connections())
					if (sig_reads(conn.second, bit))
						any_read = true;
			}
			if (!any_read)
				continue;
			// Port direction applies to the whole bus. iopadmap uses OE=1
			// for its always-driven bits; only tri-state bits need read-back.
			wire->port_input = true;
			promoted.push_back({module, wire->name, tristate_bits});
		}
	}
	return promoted;
}

void restore_promoted_tristate_outputs(const std::vector<PromotedTristateOutput> &promoted)
{
	RTLIL::IdString io_type = RTLIL::escape_id("MISTRAL_IO");
	RTLIL::IdString pad_port = RTLIL::escape_id("PAD");
	RTLIL::IdString read_port = RTLIL::escape_id("O");
	for (const auto &item : promoted) {
		RTLIL::Wire *port = item.module->wire(item.name);
		if (port == nullptr || !port->port_output)
			log_error("tri-state output %s disappeared during pad mapping\n", log_id(item.name));
		port->port_input = false;
		bool mapped = false;
		for (auto cell : item.module->cells()) {
			if (cell->type != io_type || !cell->hasPort(pad_port))
				continue;
			bool mine = false;
			for (auto bit : cell->getPort(pad_port))
				if (bit.wire == port && item.tristate_bits.count(bit.offset))
					mine = true;
			if (!mine)
				continue;
			mapped = true;
			if (!cell->hasPort(read_port) || GetSize(cell->getPort(read_port)) == 0)
				log_error("tri-state output %s is read, but its MISTRAL_IO has no O read-back\n",
						log_id(item.name));
		}
		if (!mapped)
			log_error("tri-state output %s was not mapped to MISTRAL_IO\n", log_id(item.name));
		item.module->fixup_ports();
	}
}

struct SynthIntelALMPass : public ScriptPass {
	SynthIntelALMPass() : ScriptPass("synth_intel_alm", "synthesis for ALM-based Intel (Altera) FPGAs.") {}

	void help() override
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    synth_intel_alm [options]\n");
		log("\n");
		log("This command runs synthesis for ALM-based Intel FPGAs.\n");
		log("\n");
		log("    -top <module>\n");
		log("        use the specified module as top module\n");
		log("\n");
		log("    -family <family>\n");
		log("        target one of:\n");
		log("        \"cyclonev\"    - Cyclone V (default)\n");
		log("\n");
		log("    -noflatten\n");
		log("        do not flatten design before synthesis; useful for per-module area\n");
		log("        statistics\n");
		log("\n");
		log("    -dff\n");
		log("        pass DFFs to ABC to perform sequential logic optimisations\n");
		log("        (EXPERIMENTAL)\n");
		log("\n");
		log("    -run <from_label>:<to_label>\n");
		log("        only run the commands between the labels (see below). an empty\n");
		log("        from label is synonymous to 'begin', and empty to label is\n");
		log("        synonymous to the end of the command list.\n");
		log("\n");
		log("    -nolutram\n");
		log("        do not use LUT RAM cells in output netlist\n");
		log("\n");
		log("    -nobram\n");
		log("        do not use block RAM cells in output netlist\n");
		log("\n");
		log("    -nodsp\n");
		log("        do not map multipliers to MISTRAL_MUL cells\n");
		log("\n");
		log("    -noiopad\n");
		log("        do not instantiate IO buffers\n");
		log("\n");
		log("    -noclkbuf\n");
		log("        do not insert global clock buffers\n");
		log("\n");
		log("The following commands are executed by this synthesis command:\n");
		help_script();
		log("\n");
	}

	string top_opt, family_opt, bram_type;
	bool flatten, nolutram, nobram, dff, nodsp, noiopad, noclkbuf;

	void clear_flags() override
	{
		top_opt = "-auto-top";
		family_opt = "cyclonev";
		bram_type = "m10k";
		flatten = true;
		nolutram = false;
		nobram = false;
		dff = false;
		nodsp = false;
		noiopad = false;
		noclkbuf = false;
	}

	void execute(std::vector<std::string> args, RTLIL::Design *design) override
	{
		string run_from, run_to;
		clear_flags();

		size_t argidx;
		for (argidx = 1; argidx < args.size(); argidx++) {
			if (args[argidx] == "-family" && argidx + 1 < args.size()) {
				family_opt = args[++argidx];
				continue;
			}
			if (args[argidx] == "-top" && argidx + 1 < args.size()) {
				top_opt = "-top " + args[++argidx];
				continue;
			}
			if (args[argidx] == "-run" && argidx + 1 < args.size()) {
				size_t pos = args[argidx + 1].find(':');
				if (pos == std::string::npos)
					break;
				run_from = args[++argidx].substr(0, pos);
				run_to = args[argidx].substr(pos + 1);
				continue;
			}
			if (args[argidx] == "-nolutram") {
				nolutram = true;
				continue;
			}
			if (args[argidx] == "-nobram") {
				nobram = true;
				continue;
			}
			if (args[argidx] == "-nodsp") {
				nodsp = true;
				continue;
			}
			if (args[argidx] == "-noflatten") {
				flatten = false;
				continue;
			}
			if (args[argidx] == "-dff") {
				dff = true;
				continue;
			}
			if (args[argidx] == "-noiopad") {
				noiopad = true;
				continue;
			}
			if (args[argidx] == "-noclkbuf") {
				noclkbuf = true;
				continue;
			}
			break;
		}
		extra_args(args, argidx, design);

		if (!design->full_selection())
			log_cmd_error("This command only operates on fully selected designs!\n");

		log_header(design, "Executing SYNTH_INTEL_ALM pass.\n");
		log_push();

		run_script(design, run_from, run_to);

		log_pop();
	}

	void script() override
	{
		if (help_mode) {
			family_opt = "<family>";
			bram_type = "<bram_type>";
		}

		if (check_label("begin")) {
			if (family_opt == "cyclonev")
				run(stringf("read_verilog -sv -lib +/intel_alm/%s/cells_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s +/intel_alm/common/alm_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s +/intel_alm/common/dff_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s +/intel_alm/common/dsp_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s +/intel_alm/common/mem_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s +/intel_alm/common/misc_sim.v", family_opt));
			run(stringf("read_verilog -specify -lib -D %s -icells +/intel_alm/common/abc9_model.v", family_opt));
			// Misc and common cells
			run("read_verilog -lib +/intel/common/altpll_bb.v");
			run("read_verilog -lib +/intel_alm/common/megafunction_bb.v");
			run(stringf("hierarchy -check %s", help_mode ? "-top <top>" : top_opt));
		}

		if (check_label("coarse")) {
			// Filled before opt_clean and consumed after iopadmap.
			std::vector<PromotedTristateOutput> promoted_tristate;
			run("proc");
			if (flatten || help_mode) {
				run("check");
				run("flatten", "(skip if -noflatten)");
			}
			if (!noiopad) {
				run("tribuf");
				if (!help_mode)
					split_shared_tristate_outputs(active_design);
			}
			run("tribuf -logic");
			run("deminout");
			if (!help_mode && !noiopad) {
				auto found = promote_read_tristate_outputs(active_design);
				promoted_tristate.insert(promoted_tristate.end(), found.begin(), found.end());
			}
			run("opt_expr");
			run("check");
			run("opt_clean");
			run("opt -nodffe -nosdff");
			// Capture tagged TDP read/write registers before constant write bits
			// become synchronous-reset FF slices in the general opt pass.
			// The opt-in style excludes cross-port collisions; retain explicit
			// own-port write-through while relaxing other read/write collisions.
			if (!nobram && bram_type == "m10k") {
				run("opt_dff -nosdff a:ram_style=m10k_tdp a:ram_style=m10k_tdp_byte %u a:ram_style=m10k_tdp_mixed %u %m");
				run("opt_clean a:ram_style=m10k_tdp a:ram_style=m10k_tdp_byte %u a:ram_style=m10k_tdp_mixed %u %m");
				run("memory_dff -no-rw-check a:ram_style=m10k_tdp a:ram_style=m10k_tdp_byte a:ram_style=m10k_tdp_mixed");
				// Standard M10K SDP memories can retain a zero-valued asynchronous
				// read-output reset in the block instead of extracting a fabric FF.
				// Cover both Intel spelling variants and their usual upper-case value.
				run("opt_dff -nosdff a:ramstyle=M10K a:ramstyle=m10k a:ram_style=M10K a:ram_style=m10k");
				run("opt_clean a:ramstyle=M10K a:ramstyle=m10k a:ram_style=M10K a:ram_style=m10k");
				run("memory_dff -no-rw-check a:ramstyle=M10K a:ramstyle=m10k a:ram_style=M10K a:ram_style=m10k");
			}
			run("fsm");
			run("opt");
			run("wreduce");
			run("peepopt");
			run("opt_clean");
			run("share");
			run("techmap -map +/cmp2lut.v -D LUT_WIDTH=6");
			run("opt_expr");
			run("opt_clean");
			if (help_mode) {
				run("techmap -map +/mul2dsp.v [...]", "(unless -nodsp)");
			} else if (!nodsp) {
				run("techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=27 -D DSP_B_MAXWIDTH=27  -D DSP_A_MINWIDTH=19 -D DSP_B_MINWIDTH=4 -D DSP_NAME=__MUL27X27");
				run("chtype -set $mul t:$__soft_mul");
				run("techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=27 -D DSP_B_MAXWIDTH=27  -D DSP_A_MINWIDTH=4 -D DSP_B_MINWIDTH=19 -D DSP_NAME=__MUL27X27");
				run("chtype -set $mul t:$__soft_mul");
				run("techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=18 -D DSP_B_MAXWIDTH=18  -D DSP_A_MINWIDTH=10 -D DSP_B_MINWIDTH=4 -D DSP_NAME=__MUL18X18");
				run("chtype -set $mul t:$__soft_mul");
				run("techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=18 -D DSP_B_MAXWIDTH=18  -D DSP_A_MINWIDTH=4 -D DSP_B_MINWIDTH=10 -D DSP_NAME=__MUL18X18");
				run("chtype -set $mul t:$__soft_mul");
				run("techmap -map +/mul2dsp.v -D DSP_A_MAXWIDTH=9 -D DSP_B_MAXWIDTH=9  -D DSP_A_MINWIDTH=4 -D DSP_B_MINWIDTH=4 -D DSP_NAME=__MUL9X9");
				run("chtype -set $mul t:$__soft_mul");
			}
			run("alumacc");
			if (!noiopad) {
				// iopadmap merges only fine-grained $_TBUF_ cells, so lower the
				// top-level tri-state drivers first. Only do so when there are
				// any: techmap advances the auto-generated names even when it
				// maps nothing. MISTRAL_IO takes the driven value on I and
				// returns the pad value on O.
				bool tribufs = help_mode;
				for (auto module : help_mode ? std::vector<RTLIL::Module*>() : active_design->selected_whole_modules())
					for (auto cell : module->selected_cells())
						tribufs |= cell->type == ID($tribuf);
				if (tribufs)
					run("techmap t:$tribuf", "(unless -noiopad, if the design has tri-state drivers)");
				// -toutpad wires the output net to I. Promote a tri-state output
				// that is read inside the module so iopadmap uses -tinoutpad and
				// the read stays on O, then make the port an output again.
				if (!help_mode) {
					auto found = promote_read_tristate_outputs(active_design);
					promoted_tristate.insert(promoted_tristate.end(), found.begin(), found.end());
				}
				run("iopadmap -bits -outpad MISTRAL_OB I:PAD -inpad MISTRAL_IB O:PAD -toutpad MISTRAL_IO OE:I:PAD -tinoutpad MISTRAL_IO OE:O:I:PAD A:top", "(unless -noiopad)");
				if (!help_mode)
					restore_promoted_tristate_outputs(promoted_tristate);
			}
			run("techmap -map +/intel_alm/common/arith_alm_map.v -map +/intel_alm/common/dsp_map.v");
			run("opt");
			run("memory -nomap");
			run("opt_clean");
		}

		if (!nobram && check_label("map_bram", "(skip if -nobram)")) {
			if (bram_type == "m10k") {
				// Cyclone V M10K always registers its read address. The
				// optional unregistered output is still a synchronous read;
				// only MLAB implements a flow-through asynchronous read.
				// Fail forced M10K memories before an unsupported library rule
				// or a large, silent logic fallback can hide the mismatch.
				for (auto module : active_design->selected_whole_modules())
				for (auto cell : module->selected_cells()) {
					if (cell->type != ID($mem_v2))
						continue;
					std::string style = cell->get_string_attribute(ID(ramstyle));
					if (style.empty())
						style = cell->get_string_attribute(ID(ram_style));
					if (style != "M10K" && style != "m10k")
						continue;
					auto read_clocks = cell->getParam(ID::RD_CLK_ENABLE);
					for (int i = 0; i < read_clocks.size(); i++)
						if (read_clocks[i] != State::S1)
							log_error("Cyclone V M10K cannot implement an asynchronous read port in memory %s.%s; use MLAB, logic, or register the read address.\n",
									log_id(module), log_id(cell));
				}
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_aclr.txt -lib +/intel_alm/common/bram_m10k_sync.txt a:ramstyle=M10K");
				run("techmap -map +/intel_alm/common/bram_m10k_aclr_map.v -map +/intel_alm/common/bram_m10k_sync_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_aclr.txt -lib +/intel_alm/common/bram_m10k_sync.txt a:ramstyle=m10k");
				run("techmap -map +/intel_alm/common/bram_m10k_aclr_map.v -map +/intel_alm/common/bram_m10k_sync_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_aclr.txt -lib +/intel_alm/common/bram_m10k_sync.txt a:ram_style=M10K");
				run("techmap -map +/intel_alm/common/bram_m10k_aclr_map.v -map +/intel_alm/common/bram_m10k_sync_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_aclr.txt -lib +/intel_alm/common/bram_m10k_sync.txt a:ram_style=m10k");
				run("techmap -map +/intel_alm/common/bram_m10k_aclr_map.v -map +/intel_alm/common/bram_m10k_sync_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_tdp_mixed.txt a:ram_style=m10k_tdp_mixed");
				run("techmap -map +/intel_alm/common/bram_m10k_tdp_mixed_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_tdp_byte.txt a:ram_style=m10k_tdp_byte");
				run("techmap -map +/intel_alm/common/bram_m10k_tdp_byte_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_tdp.txt a:ram_style=m10k_tdp");
				run("techmap -map +/intel_alm/common/bram_m10k_tdp_map.v");
				run("memory_libmap -lib +/intel_alm/common/bram_m10k_mixed.txt a:ram_style=m10k_mixed");
				run("techmap -map +/intel_alm/common/bram_m10k_mixed_map.v");
			}
			run(stringf("memory_bram -rules +/intel_alm/common/bram_%s.txt", bram_type));
			run(stringf("techmap -map +/intel_alm/common/bram_%s_map.v", bram_type));
		}

		if (!nolutram && check_label("map_lutram", "(skip if -nolutram)")) {
			run("memory_bram -rules +/intel_alm/common/lutram_mlab.txt", "(for Cyclone V)");
		}

		if (check_label("map_ffram")) {
			run("memory_map");
			run("opt -full");
		}

		if (check_label("map_ffs")) {
			run("techmap");
			run("dfflegalize -cell $_DFFE_PN0P_ 0 -cell $_SDFFCE_PP0P_ 0");
			run("techmap -map +/intel_alm/common/dff_map.v");
			run("opt -full -undriven -mux_undef");
			run("clean -purge");
			if (!noclkbuf)
				run("clkbufmap -buf MISTRAL_CLKBUF Q:A", "(unless -noclkbuf)");
		}

		if (check_label("map_luts")) {
			run("techmap -map +/intel_alm/common/abc9_map.v");
			run(stringf("abc9 %s -maxlut 6 -W 600", help_mode ? "[-dff]" : dff ? "-dff" : ""));
			run("techmap -map +/intel_alm/common/abc9_unmap.v");
			run("techmap -map +/intel_alm/common/alm_map.v");
			run("opt -fast");
			run("autoname");
			run("clean");
		}

		if (check_label("check")) {
			run("hierarchy -check");
			run("stat");
			run("check");
			run("blackbox =A:whitebox");
		}
	}
} SynthIntelALMPass;

PRIVATE_NAMESPACE_END
