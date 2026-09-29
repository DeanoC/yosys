/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2012  Claire Xenia Wolf <claire@yosyshq.com>
 *            (C) 2019  Eddie Hung    <eddie@fpgeh.com>
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

// [[CITE]] ABC
// Berkeley Logic Synthesis and Verification Group, ABC: A System for Sequential Synthesis and Verification
// http://www.eecs.berkeley.edu/~alanmi/abc/

#include "kernel/register.h"
#include "kernel/celltypes.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"
#include "kernel/log.h"

#include <algorithm>

// abc9_exe.cc
std::string fold_abc9_cmd(std::string str);

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

struct Abc9Pass : public ScriptPass
{
	Abc9Pass() : ScriptPass("abc9", "use ABC9 for technology mapping") { }
	void on_register() override
	{
		RTLIL::constpad["abc9.script.default"] = "+&scorr; &sweep; &dc2; &dch -f -r; &ps; &if {W} {D} {R} -v; &mfs";
		RTLIL::constpad["abc9.script.default.area"] = "+&scorr; &sweep; &dc2; &dch -f -r; &ps; &if {W} {D} {R} -a -v; &mfs";
		RTLIL::constpad["abc9.script.default.fast"] = "+&if {W} {D} {R} -v";
		// Based on ABC's &flow
		RTLIL::constpad["abc9.script.flow"] = "+&scorr; &sweep;" \
			"&dch -C 500;" \
			/* Round 1 */ \
			/* Map 1 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &dsdb;" \
			/* Map 2 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &syn2 -m -R 10; &dsdb;" \
			"&blut -a -K 6;" \
			/* Map 3 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			/* Round 2 */ \
			"&st; &sopb;" \
			/* Map 1 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &dsdb;" \
			/* Map 2 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &syn2 -m -R 10; &dsdb;" \
			"&blut -a -K 6;" \
			/* Map 3 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			/* Round 3 */ \
			/* Map 1 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &dsdb;" \
			/* Map 2 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;" \
			"&st; &syn2 -m -R 10; &dsdb;" \
			"&blut -a -K 6;" \
			/* Map 3 */ "&unmap; &if {W} {D} {R} -v; &save; &load; &mfs;";
		// Based on ABC's &flow2
		RTLIL::constpad["abc9.script.flow2"] = "+&scorr; &sweep;" \
			/* Comm1 */ "&synch2 -K 6 -C 500; &if -m {W} {D} {R} -v; &mfs "/*"-W 4 -M 500 -C 7000"*/"; &save;"\
			/* Comm2 */ "&dch -C 500; &if -m {W} {D} {R} -v; &mfs "/*"-W 4 -M 500 -C 7000"*/"; &save;"\
			"&load; &st; &sopb -R 10 -C 4; " \
			/* Comm3 */ "&synch2 -K 6 -C 500; &if -m "/*"-E 5"*/" {W} {D} {R} -v; &mfs "/*"-W 4 -M 500 -C 7000"*/"; &save;"\
			/* Comm2 */ "&dch -C 500; &if -m {W} {D} {R} -v; &mfs "/*"-W 4 -M 500 -C 7000"*/"; &save; "\
			"&load";
		// Based on ABC's &flow3 -m
		RTLIL::constpad["abc9.script.flow3"] = "+&scorr; &sweep;" \
			"&if {W} {D}; &save; &st; &syn2; &if {W} {D} {R} -v; &save; &load;"\
			"&st; &if -g -K 6; &dch -f; &if {W} {D} {R} -v; &save; &load;"\
			"&st; &if -g -K 6; &synch2; &if {W} {D} {R} -v; &save; &load;"\
			"&mfs";
		// As above, but with &mfs calls as in the original &flow3
		RTLIL::constpad["abc9.script.flow3mfs"] = "+&scorr; &sweep;" \
			"&if {W} {D}; &save; &st; &syn2; &if {W} {D} {R} -v; &save; &load;"\
			"&st; &if -g -K 6; &dch -f; &if {W} {D} {R} -v; &mfs; &save; &load;"\
			"&st; &if -g -K 6; &synch2; &if {W} {D} {R} -v; &mfs; &save; &load;"\
			"&mfs";
	}
	void help() override
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    abc9 [options] [selection]\n");
		log("\n");
		log("This script pass performs a sequence of commands to facilitate the use of the\n");
		log("ABC tool [1] for technology mapping of the current design to a target FPGA\n");
		log("architecture. Only fully-selected modules are supported.\n");
		log("\n");
		log("    -run <from_label>:<to_label>\n");
		log("        only run the commands between the labels (see below). an empty\n");
		log("        from label is synonymous to 'begin', and empty to label is\n");
		log("        synonymous to the end of the command list.\n");
		log("\n");
		log("    -exe <command>\n");
#ifdef ABCEXTERNAL
		log("        use the specified command instead of \"" ABCEXTERNAL "\" to execute ABC.\n");
#else
		log("        use the specified command instead of \"<yosys-bindir>/%syosys-abc\" to execute ABC.\n", proc_program_prefix());
#endif
		log("        This can e.g. be used to call a specific version of ABC or a wrapper.\n");
		log("\n");
		log("    -script <file>\n");
		log("        use the specified ABC script file instead of the default script.\n");
		log("\n");
		log("        if <file> starts with a plus sign (+), then the rest of the filename\n");
		log("        string is interpreted as the command string to be passed to ABC. The\n");
		log("        leading plus sign is removed and all commas (,) in the string are\n");
		log("        replaced with blanks before the string is passed to ABC.\n");
		log("\n");
		log("        if no -script parameter is given, the following scripts are used:\n");
		log("%s\n", fold_abc9_cmd(RTLIL::constpad.at("abc9.script.default").substr(1,std::string::npos)));
		log("\n");
		log("    -D <picoseconds>\n");
		log("        set delay target. the string {D} in the default scripts above is\n");
		log("        replaced by this option when used, and an empty string otherwise\n");
		log("        (indicating best possible delay).\n");
		log("\n");
		log("    -lut <width>\n");
		log("        generate netlist using luts of (max) the specified width.\n");
		log("\n");
		log("    -lut <w1>:<w2>\n");
		log("        generate netlist using luts of (max) the specified width <w2>. All\n");
		log("        luts with width <= <w1> have constant cost. for luts larger than <w1>\n");
		log("        the area cost doubles with each additional input bit. the delay cost\n");
		log("        is still constant for all lut widths.\n");
		log("\n");
		log("    -lut <file>\n");
		log("        pass this file with lut library to ABC.\n");
		log("\n");
		log("    -luts <cost1>,<cost2>,<cost3>,<sizeN>:<cost4-N>,..\n");
		log("        generate netlist using luts. Use the specified costs for luts with 1,\n");
		log("        2, 3, .. inputs.\n");
		log("\n");
		log("    -maxlut <width>\n");
		log("        when auto-generating the lut library, discard all luts equal to or\n");
		log("        greater than this size (applicable when neither -lut nor -luts is\n");
		log("        specified).\n");
		log("\n");
		log("    -dff\n");
		log("        also pass $_DFF_[NP]_ cells through to ABC. modules with many clock\n");
		log("        domains are supported and automatically partitioned by ABC.\n");
		log("\n");
		log("    -isolate\n");
		log("        map each disconnected combinational cone with its own ABC network so\n");
		log("        a change in one cone does not change the mapping of another. This is\n");
		log("        the default. Combinational abc9 boxes stay inside the cone that\n");
		log("        contains them. Common subexpressions that exist only after ABC's\n");
		log("        rewriting are not shared across cones. Ignored with -dff: sequential\n");
		log("        correspondence needs one network. Override the default with the\n");
		log("        abc9.isolate scratchpad.\n");
		log("\n");
		log("    -noisolate\n");
		log("        map each selected module as a single ABC network.\n");
		log("\n");
		log("    -nocleanup\n");
		log("        when this option is used, the temporary files created by this pass\n");
		log("        are not removed. this is useful for debugging.\n");
		log("\n");
		log("    -showtmp\n");
		log("        print the temp dir name in log. usually this is suppressed so that the\n");
		log("        command output is identical across runs.\n");
		log("\n");
		log("    -box <file>\n");
		log("        pass this file with box library to ABC.\n");
		log("\n");
		log("Note that this is a logic optimization pass within Yosys that is calling ABC\n");
		log("internally. This is not going to \"run ABC on your design\". It will instead run\n");
		log("ABC on logic snippets extracted from your design. You will not get any useful\n");
		log("output when passing an ABC script that writes a file. Instead write your full\n");
		log("design as an XAIGER file with `write_xaiger' and then load that into ABC\n");
		log("externally if you want to use ABC to convert your design into another format.\n");
		log("\n");
		log("[1] http://www.eecs.berkeley.edu/~alanmi/abc/\n");
		log("\n");
		help_script();
		log("\n");
	}

	std::stringstream exe_cmd;
	bool dff_mode, cleanup, isolate;
	bool lut_mode;
	int maxlut;
	std::string box_file;

	bool abc9_try_isolate(RTLIL::Module *mod);

	void clear_flags() override
	{
		exe_cmd.str("");
		exe_cmd << "abc9_exe";
		dff_mode = false;
		cleanup = true;
		isolate = true;
		lut_mode = false;
		maxlut = 0;
		box_file = "";
	}

	void execute(std::vector<std::string> args, RTLIL::Design *design) override
	{
		std::string run_from, run_to;
		clear_flags();

		// get arguments from scratchpad first, then override by command arguments
		dff_mode = design->scratchpad_get_bool("abc9.dff", dff_mode);
		cleanup = !design->scratchpad_get_bool("abc9.nocleanup", !cleanup);
		isolate = design->scratchpad_get_bool("abc9.isolate", isolate);

		if (design->scratchpad_get_bool("abc9.debug")) {
			cleanup = false;
			exe_cmd << " -showtmp";
		}

		size_t argidx;
		for (argidx = 1; argidx < args.size(); argidx++) {
			std::string arg = args[argidx];
			if ((arg == "-exe" || arg == "-script" || arg == "-D" ||
						arg == "-lut" || arg == "-luts" || arg == "-W") &&
					argidx+1 < args.size()) {
				if (arg == "-lut" || arg == "-luts")
					lut_mode = true;
				exe_cmd << " " << arg << " " << args[++argidx];
				continue;
			}
			if (arg == "-showtmp") {
				exe_cmd << " " << arg;
				continue;
			}
			if (arg == "-dff") {
				dff_mode = true;
				exe_cmd << " " << arg;
				continue;
			}
			if (arg == "-isolate") {
				isolate = true;
				continue;
			}
			if (arg == "-noisolate") {
				isolate = false;
				continue;
			}
			if (arg == "-nocleanup") {
				cleanup = false;
				continue;
			}
			if (arg == "-box" && argidx+1 < args.size()) {
				box_file = args[++argidx];
				continue;
			}
			if (arg == "-maxlut" && argidx+1 < args.size()) {
				maxlut = atoi(args[++argidx].c_str());
				continue;
			}
			if (arg == "-run" && argidx+1 < args.size()) {
				size_t pos = args[argidx+1].find(':');
				if (pos == std::string::npos)
					break;
				run_from = args[++argidx].substr(0, pos);
				run_to = args[argidx].substr(pos+1);
				continue;
			}
			break;
		}
		extra_args(args, argidx, design);

		// &scorr on a split network cannot see flops that were cut into primary pins.
		if (dff_mode)
			isolate = false;

		if (maxlut && lut_mode)
			log_cmd_error("abc9 '-maxlut' option only applicable without '-lut' nor '-luts'.\n");

		log_assert(design);
		if (design->selected_modules().empty()) {
			log_warning("No modules selected for ABC9 techmapping.\n");
			return;
		}

		log_header(design, "Executing ABC9 pass.\n");
		log_push();

		run_script(design, run_from, run_to);

		log_pop();
	}

	void script() override
	{
		if (check_label("check")) {
			if (help_mode)
				run("abc9_ops -check [-dff]", "(option if -dff)");
			else
				run(stringf("abc9_ops -check %s", dff_mode ? "-dff" : ""));
		}

		if (check_label("map")) {
			if (help_mode)
				run("abc9_ops -prep_hier [-dff]", "(option if -dff)");
			else
				run(stringf("abc9_ops -prep_hier %s", dff_mode ? "-dff" : ""));
			run("scc -specify -set_attr abc9_scc_id {}");
			if (help_mode)
				run("abc9_ops -prep_bypass [-prep_dff]", "(option if -dff)");
			else {
				active_design->scratchpad_unset("abc9_ops.prep_bypass.did_something");
				run(stringf("abc9_ops -prep_bypass %s", dff_mode ? "-prep_dff" : ""));
			}
			if (dff_mode) {
				run("design -copy-to $abc9_map @$abc9_flops", "(only if -dff)");
				run("select -unset $abc9_flops", "             (only if -dff)");
			}
			run("design -stash $abc9");
			run("design -load $abc9_map");
			if (help_mode) run("select =*");
			else active_design->push_complete_selection();
			run("wbflip");
			run("techmap -autoproc -wb -map %$abc9 -map +/techmap.v A:abc9_flop");
			run("opt -nodffe -nosdff");
			if (dff_mode || help_mode) {
				if (!help_mode)
					active_design->scratchpad_unset("abc9_ops.prep_dff_submod.did_something");
				run("abc9_ops -prep_dff_submod", "                                                 (only if -dff)"); // rewrite specify
				bool did_something = help_mode || active_design->scratchpad_get_bool("abc9_ops.prep_dff_submod.did_something");
				if (did_something) {
										// select all $_DFF_[NP]_
										// then select all its fanins
										// then select all fanouts of all that
										// lastly remove $_DFF_[NP]_ cells
					run("setattr -set submod \"$abc9_flop\" t:$_DFF_?_ %ci* %co* t:$_DFF_?_ %d", "       (only if -dff)");
					run("submod", "                                                                    (only if -dff)");
					run("setattr -mod -set whitebox 1 -set abc9_flop 1 -set abc9_box 1 *_$abc9_flop", "(only if -dff)");
					if (help_mode) {
						run("foreach module in design");
						run("    rename <module-name>_$abc9_flop _TECHMAP_REPLACE_", "                     (only if -dff)");
					}
					else {
						// Rename all submod-s to _TECHMAP_REPLACE_ to inherit name + attrs
						for (auto module : active_design->selected_modules()) {
							active_design->selected_active_module = module->name.str();
							if (module->cell(stringf("%s_$abc9_flop", module->name)))
								run(stringf("rename %s_$abc9_flop _TECHMAP_REPLACE_", module->name));
						}
						active_design->selected_active_module.clear();
					}
					run("abc9_ops -prep_dff_unmap", "                                                  (only if -dff)");
					run("design -copy-to $abc9 =*_$abc9_flop", "                                       (only if -dff)"); // copy submod out
					run("delete =*_$abc9_flop", "                                                      (only if -dff)");
				}
			}
			run("design -stash $abc9_map");
			run("design -load $abc9");
			run("design -delete $abc9");
			// Insert bypass modules (and perform +/abc9_map.v transformations), except for those cells part of a SCC
			if (help_mode)
				run("techmap -wb -max_iter 1 -map %$abc9_map -map +/abc9_map.v [-D DFF]", "(option if -dff)");
			else
				run(stringf("techmap -wb -max_iter 1 -map %%$abc9_map -map +/abc9_map.v %s a:abc9_scc_id %%n", dff_mode ? "-D DFF" : ""));
			run("design -delete $abc9_map");
		}

		if (check_label("pre")) {
			run("read_verilog -icells -lib -specify +/abc9_model.v");
			if (help_mode)
				run("abc9_ops -break_scc -prep_delays -prep_xaiger [-dff]", "(option for -dff)");
			else
				run("abc9_ops -break_scc -prep_delays -prep_xaiger" + std::string(dff_mode ? " -dff" : ""));
			if (help_mode)
				run("abc9_ops -prep_lut <maxlut>", "(skip if -lut or -luts)");
			else if (!lut_mode)
				run(stringf("abc9_ops -prep_lut %d", maxlut));
			if (help_mode)
				run("abc9_ops -prep_box", "(skip if -box)");
			else if (box_file.empty())
				run("abc9_ops -prep_box");
			if (saved_designs.count("$abc9_holes") || help_mode) {
				run("design -stash $abc9");
				run("design -load $abc9_holes");
				if (help_mode) run("select =*");
				else active_design->push_complete_selection();
				run("techmap -wb -map %$abc9 -map +/techmap.v");
				run("opt -purge");
				run("aigmap");
				run("design -stash $abc9_holes");
				run("design -load $abc9");
				run("design -delete $abc9");
			}
		}

		if (check_label("exe")) {
			run("aigmap");
			if (help_mode) {
				run("foreach module in selection");
				run("    abc9_ops -write_lut <abc-temp-dir>/input.lut", "(skip if '-lut' or '-luts')");
				run("    abc9_ops -write_box <abc-temp-dir>/input.box", "(skip if '-box')");
				run("    write_xaiger -map <abc-temp-dir>/input.sym [-dff] <abc-temp-dir>/input.xaig");
				run("    abc9_exe [options] -cwd <abc-temp-dir> -lut [<abc-temp-dir>/input.lut] -box [<abc-temp-dir>/input.box]");
				run("    read_aiger -xaiger -module_name <module-name>$abc9 <abc-temp-dir>/output.aig");
				run("    abc_ops_reintegrate -map <abc-temp-dir>/input.sym [-dff]");
			}
			else {
				auto selected_modules = active_design->selected_modules();
				active_design->push_empty_selection();

				for (auto mod : selected_modules) {
					if (mod->processes.size() > 0) {
						log("Skipping module %s as it contains processes.\n", mod);
						continue;
					}

					log_push();
					active_design->select(mod);

					// this check does nothing because the above line adds the whole module to the selection
					if (!active_design->selected_whole_module(mod))
						log_error("Can't handle partially selected module %s!\n", mod);

					if (isolate && abc9_try_isolate(mod)) {
						mod->check();
						active_design->selection().selected_modules.clear();
						log_pop();
						continue;
					}

					std::string tempdir_name;
					if (cleanup)
						tempdir_name = get_base_tmpdir() + "/";
					else
						tempdir_name = "_tmp_";
					tempdir_name += proc_program_prefix() + "yosys-abc-XXXXXX";
					tempdir_name = make_temp_dir(tempdir_name);

					if (!lut_mode)
						run_nocheck(stringf("abc9_ops -write_lut %s/input.lut", tempdir_name));
					if (box_file.empty())
						run_nocheck(stringf("abc9_ops -write_box %s/input.box", tempdir_name));
					run_nocheck(stringf("write_xaiger -map %s/input.sym %s %s/input.xaig", tempdir_name, dff_mode ? "-dff" : "", tempdir_name));

					int num_outputs = active_design->scratchpad_get_int("write_xaiger.num_outputs");

					log("Extracted %d AND gates and %d wires from module `%s' to a netlist network with %d inputs and %d outputs.\n",
							active_design->scratchpad_get_int("write_xaiger.num_ands"),
							active_design->scratchpad_get_int("write_xaiger.num_wires"),
							mod,
							active_design->scratchpad_get_int("write_xaiger.num_inputs"),
							num_outputs);
					if (num_outputs) {
						std::string abc9_exe_cmd;
						abc9_exe_cmd += stringf("%s -cwd %s", exe_cmd.str(), tempdir_name);
						if (!lut_mode)
							abc9_exe_cmd += stringf(" -lut %s/input.lut", tempdir_name);
						if (box_file.empty())
							abc9_exe_cmd += stringf(" -box %s/input.box", tempdir_name);
						else
							abc9_exe_cmd += stringf(" -box %s", box_file);
						run_nocheck(abc9_exe_cmd);
						run_nocheck(stringf("read_aiger -xaiger -module_name %s$abc9 %s/output.aig", mod, tempdir_name));
						run_nocheck(stringf("abc_ops_reintegrate -map %s/input.sym %s", tempdir_name, dff_mode ? "-dff" : ""));
					}
					else
						log("Don't call ABC as there is nothing to map.\n");

					if (cleanup) {
						log("Removing temp directory.\n");
						remove_directory(tempdir_name);
					}
					mod->check();
					active_design->selection().selected_modules.clear();
					log_pop();
				}

				active_design->pop_selection();
			}
		}

		if (check_label("unmap")) {
			run("techmap -wb -map %$abc9_unmap -map +/abc9_unmap.v"); 	// techmap user design from submod back to original cell
											//   ($_DFF_[NP]_ already shorted by -reintegrate)
			run("design -delete $abc9_unmap");
			if (saved_designs.count("$abc9_holes") || help_mode)
				run("design -delete $abc9_holes");
			if (help_mode || active_design->scratchpad_get_bool("abc9_ops.prep_bypass.did_something"))
				run("delete =*_$abc9_byp");
			run("setattr -mod -unset abc9_box_id");
		}
	}
} Abc9Pass;

// Lexicographic cell/port order. IdString::operator< follows intern order, which
// shifts when an unrelated name is created first.
struct Abc9BitKey {
	RTLIL::IdString cell, port;
	int index = 0;
};

static bool abc9_key_less(const Abc9BitKey &a, const Abc9BitKey &b)
{
	if (a.cell != b.cell)
		return a.cell.lt_by_name(b.cell);
	if (a.port != b.port)
		return a.port.lt_by_name(b.port);
	return a.index < b.index;
}

// Public net, port, or cell pin. Private aigmap names are not anchors: they
// move when an unrelated cone allocates a different number of ids.
struct Abc9Anchor {
	RTLIL::IdString name, port;
	int index = 0;
};

static bool abc9_anchor_less(const Abc9Anchor &a, const Abc9Anchor &b)
{
	if (a.name != b.name)
		return a.name.lt_by_name(b.name);
	if (a.port != b.port)
		return a.port.lt_by_name(b.port);
	return a.index < b.index;
}

static void abc9_sort_anchors(std::vector<Abc9Anchor> &anchors)
{
	std::sort(anchors.begin(), anchors.end(), abc9_anchor_less);
	anchors.erase(std::unique(anchors.begin(), anchors.end(), [](const Abc9Anchor &a, const Abc9Anchor &b) {
		return !abc9_anchor_less(a, b) && !abc9_anchor_less(b, a);
	}), anchors.end());
}

static bool abc9_anchors_less(const std::vector<Abc9Anchor> &a, const std::vector<Abc9Anchor> &b)
{
	int n = std::min(GetSize(a), GetSize(b));
	for (int i = 0; i < n; i++) {
		if (abc9_anchor_less(a[i], b[i]))
			return true;
		if (abc9_anchor_less(b[i], a[i]))
			return false;
	}
	return GetSize(a) < GetSize(b);
}

static RTLIL::IdString abc9_cone_wire_name(RTLIL::SigBit bit, const char *kind)
{
	std::string unescaped = bit.wire->name.unescape();
	return stringf("$abc9%s$%s$%d", kind, unescaped.c_str(), bit.offset);
}

bool Abc9Pass::abc9_try_isolate(RTLIL::Module *mod)
{
	// This pass keeps IdString values and cell pointers across nested
	// write_xaiger / abc9_exe / read_aiger calls. A collection between those
	// calls is unsafe, and on a large module it also dominates runtime.
	GarbageCollectionGuard gc_guard(false);

	// No new RTLIL ids on this path: a one-cone module must stay byte-identical.
	if (mod->memories.size() || mod->processes.size())
		return false;

	auto is_cone_cell = [&](RTLIL::Cell *cell) {
		if (cell->has_keep_attr())
			return false;
		if (cell->type.in(ID($_AND_), ID($_NOT_)))
			return true;
		if (!cell->attributes.count(ID::abc9_box_seq))
			return false;
		RTLIL::Module *inst = active_design->module(cell->type);
		if (!inst || !inst->get_bool_attribute(ID::abc9_box))
			return false;
		if (inst->get_bool_attribute(ID::abc9_flop))
			return false;
		return true;
	};

	std::vector<RTLIL::Cell*> cone_cells;
	for (auto cell : mod->cells())
		if (is_cone_cell(cell))
			cone_cells.push_back(cell);
	if (GetSize(cone_cells) <= 1)
		return false;

	SigMap sigmap(mod);
	for (auto wire : mod->wires())
		if (wire->name.isPublic())
			sigmap.add(wire);
	for (auto wire : mod->wires())
		if (wire->port_input)
			sigmap.add(wire);
	for (auto wire : mod->wires())
		if (wire->get_bool_attribute(ID::keep))
			sigmap.add(wire);

	pool<RTLIL::Cell*> cone_set;
	for (auto cell : cone_cells)
		cone_set.insert(cell);

	// A canonical bit escapes the cone when a port, a keep wire, or a
	// non-cone cell reads it. Flops and SCC breakers are those readers.
	pool<RTLIL::SigBit> external;
	dict<RTLIL::SigBit, std::vector<Abc9Anchor>> public_anchors, any_anchors;
	auto add_anchor = [&](RTLIL::SigBit canon, RTLIL::IdString name, RTLIL::IdString port, int index) {
		if (!canon.wire)
			return;
		Abc9Anchor anchor;
		anchor.name = name;
		anchor.port = port;
		anchor.index = index;
		any_anchors[canon].push_back(anchor);
		if (name.isPublic())
			public_anchors[canon].push_back(anchor);
	};
	for (auto wire : mod->wires()) {
		if (wire->port_output || wire->get_bool_attribute(ID::keep)) {
			for (int i = 0; i < GetSize(wire); i++) {
				RTLIL::SigBit bit = sigmap(RTLIL::SigBit(wire, i));
				if (bit.wire)
					external.insert(bit);
			}
		}
		if (!wire->name.isPublic())
			continue;
		RTLIL::IdString kind = wire->port_input && wire->port_output ? RTLIL::IdString("\\inout") :
				wire->port_input ? RTLIL::IdString("\\portin") :
				wire->port_output ? RTLIL::IdString("\\portout") : RTLIL::IdString("\\net");
		for (int i = 0; i < GetSize(wire); i++)
			add_anchor(sigmap(RTLIL::SigBit(wire, i)), wire->name, kind, i);
	}
	for (auto cell : mod->cells()) {
		if (cone_set.count(cell))
			continue;
		for (auto &conn : cell->connections()) {
			bool is_in = cell->input(conn.first);
			bool is_out = cell->output(conn.first);
			if (!is_in && !is_out)
				is_in = true;
			int index = 0;
			for (auto bit : conn.second) {
				int bit_index = index++;
				if (!bit.wire)
					continue;
				RTLIL::SigBit canon = sigmap(bit);
				if (!canon.wire)
					continue;
				if (is_in)
					external.insert(canon);
				add_anchor(canon, cell->name, conn.first, bit_index);
			}
		}
	}

	struct Pin {
		RTLIL::SigBit canon, orig;
		Abc9BitKey key;
		bool is_in = false, is_out = false;
	};
	std::vector<std::vector<Pin>> pins(cone_cells.size());
	RTLIL::IdString bad_cell, bad_port;
	bool bad = false;

	for (int ci = 0; ci < GetSize(cone_cells); ci++) {
		RTLIL::Cell *cell = cone_cells[ci];
		for (auto &conn : cell->connections()) {
			bool is_in = cell->input(conn.first);
			bool is_out = cell->output(conn.first);
			if (!is_in && !is_out) {
				if (!bad) {
					bad = true;
					bad_cell = cell->name;
					bad_port = conn.first;
				}
				continue;
			}
			for (int i = 0; i < GetSize(conn.second); i++) {
				RTLIL::SigBit orig = conn.second[i];
				if (!orig.wire)
					continue;
				RTLIL::SigBit canon = sigmap(orig);
				if (!canon.wire)
					continue;
				Pin pin;
				pin.canon = canon;
				pin.orig = orig;
				pin.key = {cell->name, conn.first, i};
				pin.is_in = is_in;
				pin.is_out = is_out;
				pins[ci].push_back(pin);
			}
		}
	}

	dict<RTLIL::SigBit, std::vector<int>> driver_cells, user_cells;
	for (int ci = 0; ci < GetSize(cone_cells); ci++) {
		for (auto &pin : pins[ci]) {
			if (pin.is_out)
				driver_cells[pin.canon].push_back(ci);
			if (pin.is_in)
				user_cells[pin.canon].push_back(ci);
		}
	}

	struct UnionFind {
		std::vector<int> parent, rank;
		UnionFind(int n) : parent(n), rank(n, 0) {
			for (int i = 0; i < n; i++)
				parent[i] = i;
		}
		int find(int x) {
			int root = x;
			while (parent[root] != root)
				root = parent[root];
			while (parent[x] != root) {
				int next = parent[x];
				parent[x] = root;
				x = next;
			}
			return root;
		}
		void unite(int a, int b) {
			a = find(a);
			b = find(b);
			if (a == b)
				return;
			if (rank[a] < rank[b])
				std::swap(a, b);
			parent[b] = a;
			if (rank[a] == rank[b])
				rank[a]++;
		}
	} uf(GetSize(cone_cells));

	for (auto &it : driver_cells) {
		auto &drivers = it.second;
		for (int i = 1; i < GetSize(drivers); i++)
			uf.unite(drivers[0], drivers[i]);
		auto users = user_cells.find(it.first);
		if (users == user_cells.end())
			continue;
		for (int user : users->second)
			uf.unite(drivers[0], user);
	}
	driver_cells.clear();
	user_cells.clear();

	dict<int, std::vector<int>> raw_groups;
	for (int ci = 0; ci < GetSize(cone_cells); ci++)
		raw_groups[uf.find(ci)].push_back(ci);
	if (GetSize(raw_groups) <= 1)
		return false;
	if (bad)
		log_error("ABC9 isolate: port %s on cell %s is neither an input nor an output.\n",
				bad_port, bad_cell);

	struct Group {
		RTLIL::IdString min_name;
		std::vector<int> members;
	};
	std::vector<Group> groups;
	groups.reserve(raw_groups.size());
	int largest = 0;
	for (auto &it : raw_groups) {
		Group group;
		group.members = std::move(it.second);
		group.min_name = cone_cells[group.members[0]]->name;
		for (int idx : group.members)
			if (cone_cells[idx]->name.lt_by_name(group.min_name))
				group.min_name = cone_cells[idx]->name;
		if (GetSize(group.members) > largest)
			largest = GetSize(group.members);
		groups.push_back(std::move(group));
	}
	std::sort(groups.begin(), groups.end(), [](const Group &a, const Group &b) {
		return a.min_name.lt_by_name(b.min_name);
	});

	struct PortInfo {
		bool is_output = false;
		Abc9BitKey key;
		RTLIL::Wire *cone_wire = nullptr;
		RTLIL::SigBit parent_bit;
		std::vector<RTLIL::SigBit> originals;
		std::vector<Abc9Anchor> anchors;
	};
	struct Cone {
		RTLIL::Module *mod = nullptr;
		int abc_index = -1;
		bool has_box = false;
		std::vector<PortInfo> ports;
		dict<RTLIL::SigBit, RTLIL::Wire*> canon_wire;
	};
	std::vector<Cone> cones;
	cones.reserve(groups.size());

	for (int gi = 0; gi < GetSize(groups); gi++) {
		Group &group = groups[gi];
		// Cell-dict order follows insertion and erasure, so an unrelated cone
		// can reshuffle it. Name order keeps this cone's AIG walk stable.
		std::sort(group.members.begin(), group.members.end(), [&](int a, int b) {
			return cone_cells[a]->name.lt_by_name(cone_cells[b]->name);
		});
		Cone cone;
		RTLIL::IdString cone_name = stringf("\\abc9cone_%d", gi);
		if (active_design->module(cone_name))
			log_error("ABC9 isolate: module %s already exists.\n", cone_name);
		cone.mod = active_design->addModule(cone_name);

		struct BitRec {
			RTLIL::SigBit canon;
			bool driven = false, used = false;
			bool have_driver = false, have_user = false;
			Abc9BitKey driver_key, user_key;
			std::vector<RTLIL::SigBit> originals;
		};
		dict<RTLIL::SigBit, BitRec> recs;
		for (int idx : group.members) {
			if (cone_cells[idx]->attributes.count(ID::abc9_box_seq))
				cone.has_box = true;
			for (auto &pin : pins[idx]) {
				BitRec &rec = recs[pin.canon];
				rec.canon = pin.canon;
				if (pin.is_out) {
					rec.driven = true;
					rec.originals.push_back(pin.orig);
					if (!rec.have_driver || abc9_key_less(pin.key, rec.driver_key)) {
						rec.driver_key = pin.key;
						rec.have_driver = true;
					}
				}
				if (pin.is_in) {
					rec.used = true;
					if (!rec.have_user || abc9_key_less(pin.key, rec.user_key)) {
						rec.user_key = pin.key;
						rec.have_user = true;
					}
				}
			}
		}

		auto anchors_for = [&](RTLIL::SigBit bit) {
			std::vector<Abc9Anchor> key;
			auto pub = public_anchors.find(bit);
			if (pub != public_anchors.end() && !pub->second.empty())
				key = pub->second;
			else {
				auto any = any_anchors.find(bit);
				if (any != any_anchors.end())
					key = any->second;
			}
			abc9_sort_anchors(key);
			return key;
		};
		std::vector<RTLIL::SigBit> internals;
		for (auto &it : recs) {
			BitRec &rec = it.second;
			if (rec.driven && external.count(rec.canon)) {
				log_assert(rec.have_driver);
				PortInfo port;
				port.is_output = true;
				port.key = rec.driver_key;
				port.parent_bit = rec.canon;
				port.originals = std::move(rec.originals);
				port.anchors = anchors_for(rec.canon);
				cone.ports.push_back(std::move(port));
			} else if (rec.driven) {
				internals.push_back(rec.canon);
			} else if (rec.used) {
				log_assert(rec.have_user);
				PortInfo port;
				port.is_output = false;
				port.key = rec.user_key;
				port.parent_bit = rec.canon;
				port.anchors = anchors_for(rec.canon);
				cone.ports.push_back(std::move(port));
			}
		}
		std::sort(cone.ports.begin(), cone.ports.end(), [](const PortInfo &a, const PortInfo &b) {
			if (a.is_output != b.is_output)
				return !a.is_output;
			// PI/PO order is part of the ABC network. Anchor it to public
			// nets and cell pins. aigmap's private wire names move when
			// another cone uses a different number of ids.
			if (abc9_anchors_less(a.anchors, b.anchors))
				return true;
			if (abc9_anchors_less(b.anchors, a.anchors))
				return false;
			RTLIL::IdString an, bn;
			if (a.parent_bit.wire)
				an = a.parent_bit.wire->name;
			if (b.parent_bit.wire)
				bn = b.parent_bit.wire->name;
			if (an != bn)
				return an.lt_by_name(bn);
			if (a.parent_bit.offset != b.parent_bit.offset)
				return a.parent_bit.offset < b.parent_bit.offset;
			return abc9_key_less(a.key, b.key);
		});

		int port_id = 1;
		for (auto &port : cone.ports) {
			RTLIL::IdString wname = abc9_cone_wire_name(port.parent_bit, "b");
			if (cone.mod->wire(wname))
				log_error("ABC9 isolate: duplicate boundary wire %s.\n", wname);
			RTLIL::Wire *wire = cone.mod->addWire(wname);
			wire->port_id = port_id++;
			wire->port_input = !port.is_output;
			wire->port_output = port.is_output;
			port.cone_wire = wire;
			cone.canon_wire[port.parent_bit] = wire;
		}
		for (auto bit : internals) {
			RTLIL::IdString wname = abc9_cone_wire_name(bit, "i");
			if (cone.mod->wire(wname))
				log_error("ABC9 isolate: duplicate internal wire %s.\n", wname);
			cone.canon_wire[bit] = cone.mod->addWire(wname);
		}
		cone.mod->fixup_ports();

		auto rewrite = [&](const RTLIL::SigSpec &sig) {
			RTLIL::SigSpec out;
			for (auto bit : sig) {
				if (!bit.wire) {
					out.append(bit);
					continue;
				}
				RTLIL::SigBit canon = sigmap(bit);
				if (!canon.wire) {
					out.append(canon);
					continue;
				}
				auto found = cone.canon_wire.find(canon);
				if (found == cone.canon_wire.end())
					log_error("ABC9 isolate: signal %s in %s has no cone wire.\n",
							log_signal(canon), cone.mod);
				out.append(RTLIL::SigBit(found->second, 0));
			}
			return out;
		};

		for (int idx : group.members) {
			RTLIL::Cell *cell = cone_cells[idx];
			RTLIL::Cell *created = cone.mod->addCell(cell->name, cell->type);
			created->parameters = cell->parameters;
			created->attributes = cell->attributes;
			for (auto &conn : cell->connections())
				created->setPort(conn.first, rewrite(conn.second));
		}
		for (int idx : group.members)
			mod->remove(cone_cells[idx]);

		if (cone.has_box) {
			std::vector<RTLIL::Cell*> boxes;
			for (auto cell : cone.mod->cells())
				if (cell->attributes.count(ID::abc9_box_seq))
					boxes.push_back(cell);
			std::sort(boxes.begin(), boxes.end(), [](RTLIL::Cell *a, RTLIL::Cell *b) {
				return a->attributes.at(ID::abc9_box_seq).as_int() <
						b->attributes.at(ID::abc9_box_seq).as_int();
			});
			for (int i = 0; i < GetSize(boxes); i++)
				boxes[i]->attributes[ID::abc9_box_seq] = i;
		}

		cones.push_back(std::move(cone));
	}

	std::string tempdir_name;
	if (cleanup)
		tempdir_name = get_base_tmpdir() + "/";
	else
		tempdir_name = "_tmp_";
	tempdir_name += proc_program_prefix() + "yosys-abc-XXXXXX";
	tempdir_name = make_temp_dir(tempdir_name);

	active_design->selection().clear();
	active_design->select(mod);
	if (!lut_mode)
		run_nocheck(stringf("abc9_ops -write_lut %s/input.lut", tempdir_name));
	if (box_file.empty())
		run_nocheck(stringf("abc9_ops -write_box %s/input.box", tempdir_name));

	int nmap = 0;
	for (auto &cone : cones) {
		RTLIL::Module *holes = nullptr;
		RTLIL::Design *holes_design = nullptr;
		if (cone.has_box) {
			auto stash = saved_designs.find("$abc9_holes");
			if (stash == saved_designs.end() || !stash->second)
				log_error("ABC9 isolate: module %s has abc9 boxes but no holes design.\n", mod);
			holes_design = stash->second;
			RTLIL::Module *parent_holes = holes_design->module(mod->name);
			if (!parent_holes)
				log_error("ABC9 isolate: module %s has abc9 boxes but no holes module.\n", mod);
			holes = parent_holes->clone();
			holes->name = cone.mod->name;
			holes_design->add(holes);

			pool<RTLIL::Wire*> keep;
			for (auto cell : cone.mod->cells()) {
				if (!cell->attributes.count(ID::abc9_box_seq))
					continue;
				RTLIL::Module *box_mod = active_design->module(cell->type);
				if (!box_mod)
					log_error("ABC9 isolate: missing box module %s for %s.\n", cell->type, cell);
				for (auto port_name : box_mod->ports) {
					RTLIL::Wire *port = box_mod->wire(port_name);
					if (!port || !port->port_output)
						continue;
					std::string port_un = port_name.unescape();
					RTLIL::IdString hname = stringf("$abc%s.%s", cell->name, port_un.c_str());
					RTLIL::Wire *hw = holes->wire(hname);
					if (!hw || !hw->port_output)
						log_error("ABC9 isolate: holes wire %s for %s is missing.\n", hname, cell);
					keep.insert(hw);
				}
			}
			if (keep.empty())
				log_error("ABC9 isolate: cone %s has boxes but no holes outputs.\n", cone.mod);

			std::vector<RTLIL::Wire*> hole_wires;
			for (auto wire : holes->wires())
				if (wire->port_output)
					hole_wires.push_back(wire);
			for (auto wire : hole_wires) {
				if (keep.count(wire))
					continue;
				wire->port_output = false;
				wire->port_id = 0;
			}
			holes->fixup_ports();
		}

		active_design->selection().clear();
		active_design->select(cone.mod);
		run_nocheck(stringf("write_xaiger -map %s/input%d.sym %s/input%d.xaig",
				tempdir_name, nmap, tempdir_name, nmap));
		int num_outputs = active_design->scratchpad_get_int("write_xaiger.num_outputs");
		if (holes) {
			holes_design->remove(holes);
			holes = nullptr;
		}
		if (num_outputs > 0)
			cone.abc_index = nmap++;
		else
			log("Skipping ABC for cone %s: no outputs.\n", cone.mod);
	}

	log("Isolating %d combinational cones in %s (largest %d cells, %d ABC networks).\n",
			GetSize(cones), mod, largest, nmap);

	if (nmap) {
		std::string abc9_exe_cmd = stringf("%s -cwd %s -cones %d", exe_cmd.str(), tempdir_name, nmap);
		if (!lut_mode)
			abc9_exe_cmd += stringf(" -lut %s/input.lut", tempdir_name);
		if (box_file.empty())
			abc9_exe_cmd += stringf(" -box %s/input.box", tempdir_name);
		else
			abc9_exe_cmd += stringf(" -box %s", box_file);
		run_nocheck(abc9_exe_cmd);

		for (auto &cone : cones) {
			if (cone.abc_index < 0)
				continue;
			active_design->selection().clear();
			active_design->select(cone.mod);
			run_nocheck(stringf("read_aiger -xaiger -module_name %s$abc9 %s/output%d.aig",
					cone.mod, tempdir_name, cone.abc_index));
			active_design->selection().clear();
			active_design->select(cone.mod);
			run_nocheck(stringf("abc_ops_reintegrate -map %s/input%d.sym",
					tempdir_name, cone.abc_index));
		}
	}

	// Drop parent assigns that drive a bit the cone used to drive. The mapped
	// signal is connected to every original driver bit below; leaving the old
	// assign would double-drive it, and deleting an alias would undrive the
	// other side.
	pool<RTLIL::SigBit> driven;
	for (auto &cone : cones)
		for (auto &port : cone.ports)
			if (port.is_output)
				for (auto bit : port.originals)
					if (bit.wire)
						driven.insert(bit);
	if (!driven.empty()) {
		std::vector<RTLIL::SigSig> kept;
		for (auto &conn : mod->connections()) {
			RTLIL::SigSpec lhs, rhs;
			for (int i = 0; i < GetSize(conn.first); i++) {
				if (driven.count(conn.first[i]))
					continue;
				lhs.append(conn.first[i]);
				rhs.append(conn.second[i]);
			}
			if (GetSize(lhs))
				kept.push_back(RTLIL::SigSig(lhs, rhs));
		}
		mod->new_connections(kept);
	}

	for (auto &cone : cones) {
		dict<RTLIL::Wire*, RTLIL::SigBit> input_of, output_of;
		for (auto &port : cone.ports) {
			if (port.is_output) {
				RTLIL::Wire *sig = mod->addWire(NEW_ID);
				output_of[port.cone_wire] = sig;
			} else
				input_of[port.cone_wire] = port.parent_bit;
		}
		dict<RTLIL::Wire*, RTLIL::Wire*> copied;
		auto map_sig = [&](const RTLIL::SigSpec &sig) {
			RTLIL::SigSpec out;
			for (auto bit : sig) {
				if (!bit.wire) {
					out.append(bit);
					continue;
				}
				auto in = input_of.find(bit.wire);
				if (in != input_of.end()) {
					out.append(in->second);
					continue;
				}
				auto outb = output_of.find(bit.wire);
				if (outb != output_of.end()) {
					out.append(outb->second);
					continue;
				}
				RTLIL::Wire *&parent_wire = copied[bit.wire];
				if (!parent_wire) {
					parent_wire = mod->addWire(NEW_ID, GetSize(bit.wire));
					parent_wire->start_offset = bit.wire->start_offset;
				}
				out.append(RTLIL::SigBit(parent_wire, bit.offset));
			}
			return out;
		};
		for (auto cell : cone.mod->cells().to_vector()) {
			RTLIL::Cell *created = mod->addCell(cell->name, cell->type);
			created->parameters = cell->parameters;
			created->attributes = cell->attributes;
			for (auto &conn : cell->connections())
				created->setPort(conn.first, map_sig(conn.second));
		}
		for (auto &conn : cone.mod->connections())
			mod->connect(map_sig(conn.first), map_sig(conn.second));
		for (auto &port : cone.ports) {
			if (!port.is_output)
				continue;
			RTLIL::SigBit sig = output_of.at(port.cone_wire);
			pool<RTLIL::SigBit> seen;
			for (auto bit : port.originals) {
				if (!bit.wire || !seen.insert(bit).second)
					continue;
				mod->connect(bit, sig);
			}
		}
	}

	for (auto &cone : cones) {
		RTLIL::IdString mapped_name = stringf("%s$abc9", cone.mod->name);
		if (RTLIL::Module *mapped = active_design->module(mapped_name))
			active_design->remove(mapped);
		active_design->remove(cone.mod);
		cone.mod = nullptr;
	}

	if (cleanup) {
		log("Removing temp directory.\n");
		remove_directory(tempdir_name);
	}
	active_design->selection().clear();
	return true;
}

PRIVATE_NAMESPACE_END
