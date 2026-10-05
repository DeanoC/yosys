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
#include "kernel/sigtools.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

// Fold enable cones in isolation. Optimizing the live module here would
// canonicalize pad aliases before we have separated their physical drivers.
// Keep only incoming dependencies: unrelated outgoing pad assignments must
// not turn an enable input into a constant through SigMap aliasing.
pool<RTLIL::Cell *> disabled_tristate_drivers(RTLIL::Module *module, RTLIL::Design *design)
{
	RTLIL::Design analysis;
	auto copy = module->clone();
	analysis.add(copy);
	CellTypes celltypes(design);
	dict<RTLIL::SigBit, pool<RTLIL::SigBit>> incoming;
	dict<RTLIL::SigBit, pool<RTLIL::Cell *>> drivers;
	std::vector<std::pair<RTLIL::IdString, RTLIL::SigSpec>> enables;
	std::vector<RTLIL::SigBit> pending;
	for (const auto &conn : copy->connections())
		for (int i = 0; i < GetSize(conn.first); i++)
			incoming[conn.first[i]].insert(conn.second[i]);
	for (auto cell : copy->cells()) {
		for (const auto &conn : cell->connections())
			if (celltypes.cell_output(cell->type, conn.first))
				for (auto bit : conn.second)
					drivers[bit].insert(cell);
		if (cell->type.in(ID($tribuf), ID($_TBUF_))) {
			auto enable = cell->getPort(cell->type == ID($tribuf) ? ID::EN : ID::E);
			enables.emplace_back(cell->name, enable);
			for (auto bit : enable)
				pending.push_back(bit);
		}
	}
	pool<RTLIL::SigBit> visited;
	pool<RTLIL::Cell *> needed;
	while (!pending.empty()) {
		auto bit = pending.back();
		pending.pop_back();
		if (!visited.insert(bit).second)
			continue;
		if (incoming.count(bit))
			for (auto source : incoming.at(bit))
				pending.push_back(source);
		if (drivers.count(bit))
			for (auto cell : drivers.at(bit))
				if (needed.insert(cell).second)
					for (const auto &conn : cell->connections())
						if (celltypes.cell_input(cell->type, conn.first))
							for (auto source : conn.second)
								pending.push_back(source);
	}
	std::vector<RTLIL::SigSig> connections;
	for (const auto &conn : copy->connections())
		for (int i = 0; i < GetSize(conn.first); i++)
			if (visited.count(conn.first[i]))
				connections.emplace_back(conn.first[i], conn.second[i]);
	copy->new_connections(connections);
	std::vector<RTLIL::Cell *> unused;
	for (auto cell : copy->cells())
		if (!needed.count(cell))
			unused.push_back(cell);
	for (auto cell : unused)
		copy->remove(cell);
	Pass::call(&analysis, "opt_expr -keepdc");
	SigMap folded(copy);
	pool<RTLIL::Cell *> disabled;
	for (const auto &item : enables)
		if (folded(item.second).is_fully_zero())
			disabled.insert(module->cell(item.first));
		else if (folded(item.second) == RTLIL::State::S1) {
			auto cell = module->cell(item.first);
			cell->setPort(cell->type == ID($tribuf) ? ID::EN : ID::E, RTLIL::State::S1);
		}
	return disabled;
}

pool<RTLIL::SigBit> first_output_bits(RTLIL::SigBit start,
		const dict<RTLIL::SigBit, pool<RTLIL::SigBit>> &aliases,
		pool<std::pair<RTLIL::SigBit, RTLIL::SigBit>> *assignments = nullptr)
{
	std::vector<RTLIL::SigBit> pending = {start};
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
			for (auto next : aliases.at(bit)) {
				if (assignments != nullptr && next.wire != nullptr && next.wire->port_output)
					assignments->insert({next, bit});
				pending.push_back(next);
			}
	}
	return outputs;
}

// Continuous assignments from an internal tri-state source to sibling output
// ports drive independent pins. Split those drivers before opt_clean merges
// aliases. Stop at the first output on each path: assignments that read that
// output must remain on its pad read-back instead of becoming new drivers.
pool<RTLIL::SigBit> split_shared_tristate_outputs(RTLIL::Design *design)
{
	pool<RTLIL::SigBit> inactive_outputs;
	for (auto module : design->selected_unboxed_whole_modules()) {
		if (!module->get_bool_attribute(ID::top))
			continue;
		// The frontend may already have folded a literal-disabled driver
		// to a Z assignment. Analyze it as the same inactive contribution,
		// without letting SigMap short other drivers to that Z constant.
		std::vector<RTLIL::SigSig> non_z_connections;
		for (const auto &conn : module->connections()) {
			RTLIL::SigSpec lhs, rhs;
			for (int i = 0; i < GetSize(conn.first); i++) {
				if (conn.second[i] == RTLIL::State::Sz && conn.first[i].wire != nullptr) {
					module->addTribuf(NEW_ID, RTLIL::State::Sx, RTLIL::State::S0, conn.first[i]);
					continue;
				}
				lhs.append(conn.first[i]);
				rhs.append(conn.second[i]);
			}
			if (!lhs.empty())
				non_z_connections.emplace_back(lhs, rhs);
		}
		module->new_connections(non_z_connections);
		std::vector<RTLIL::Cell *> tristates;
		for (auto cell : module->selected_cells())
			if (cell->type.in(ID($tribuf), ID($_TBUF_)))
				tristates.push_back(cell);
		if (tristates.empty())
			continue;
		auto disabled = disabled_tristate_drivers(module, design);
		if (!disabled.empty()) {
			// A disabled source contributes Z. Disconnect it where it joins
			// another drive path, but retain it on otherwise undriven pads
			// so their physical OE remains zero and read-back is preserved.
			dict<RTLIL::SigBit, pool<RTLIL::SigBit>> aliases;
			std::vector<RTLIL::SigBit> active_pending, inactive_pending;
			for (const auto &conn : module->connections())
				for (int i = 0; i < GetSize(conn.first); i++) {
					aliases[conn.second[i]].insert(conn.first[i]);
					if (conn.second[i].wire == nullptr && conn.second[i].data != RTLIL::State::Sz)
						active_pending.push_back(conn.second[i]);
					// A read of another physical output supplies ordinary
					// pad data even when that pad's own driver is disabled.
					if (conn.second[i].wire != nullptr && conn.second[i].wire->port_output)
						active_pending.push_back(conn.first[i]);
				}
			for (auto wire : module->wires())
				if (wire->port_input && !wire->port_output)
					for (auto bit : RTLIL::SigSpec(wire))
						active_pending.push_back(bit);
			CellTypes celltypes(design);
			for (auto cell : module->cells())
				for (const auto &conn : cell->connections())
					if (celltypes.cell_output(cell->type, conn.first))
						for (auto bit : conn.second)
							(disabled.count(cell) ? inactive_pending : active_pending).push_back(bit);
			auto reachable = [&](std::vector<RTLIL::SigBit> pending) {
				pool<RTLIL::SigBit> reached;
				while (!pending.empty()) {
					auto bit = pending.back();
					pending.pop_back();
					if (!reached.insert(bit).second || (bit.wire != nullptr && bit.wire->port_output))
						continue;
					if (aliases.count(bit))
						for (auto next : aliases.at(bit))
							pending.push_back(next);
				}
				return reached;
			};
			auto active = reachable(active_pending), inactive = reachable(inactive_pending);
			for (auto bit : inactive)
				if (bit.wire != nullptr && bit.wire->port_output)
					inactive_outputs.insert(bit);
			std::vector<RTLIL::SigSig> connections;
			for (const auto &conn : module->connections()) {
				RTLIL::SigSpec lhs, rhs;
				for (int i = 0; i < GetSize(conn.first); i++) {
					if (inactive.count(conn.second[i]) && !active.count(conn.second[i]) && active.count(conn.first[i]) &&
							(conn.second[i].wire == nullptr || !conn.second[i].wire->port_output))
						continue;
					lhs.append(conn.first[i]);
					rhs.append(conn.second[i]);
				}
				if (!lhs.empty())
					connections.emplace_back(lhs, rhs);
			}
			module->new_connections(connections);
			for (auto cell : disabled) {
				auto y = cell->getPort(ID::Y);
				bool overlap = false;
				for (auto bit : y)
					overlap |= active.count(bit);
				if (!overlap)
					continue;
				for (int i = 0; i < GetSize(y); i++)
					if (!active.count(y[i]))
						module->addTribuf(NEW_ID, cell->getPort(ID::A)[i], RTLIL::State::S0, y[i])->attributes = cell->attributes;
				module->remove(cell);
			}
			tristates.clear();
			for (auto cell : module->selected_cells())
				if (cell->type.in(ID($tribuf), ID($_TBUF_)))
					tristates.push_back(cell);
			if (tristates.empty())
				continue;
		}
		dict<RTLIL::SigBit, pool<RTLIL::SigBit>> aliases, incoming;
		for (auto &conn : module->connections())
			for (int i = 0; i < GetSize(conn.first); i++) {
				aliases[conn.second[i]].insert(conn.first[i]);
				incoming[conn.first[i]].insert(conn.second[i]);
			}
		pool<RTLIL::SigBit> ordinary_drivers, tristate_outputs;
		for (auto wire : module->wires())
			if (wire->port_input && !wire->port_output)
				for (auto bit : RTLIL::SigSpec(wire))
					ordinary_drivers.insert(bit);
		CellTypes celltypes(design);
		for (auto cell : module->cells()) {
			if (cell->type.in(ID($tribuf), ID($_TBUF_)))
				continue;
			for (const auto &conn : cell->connections())
				if (celltypes.cell_output(cell->type, conn.first))
					for (auto bit : conn.second)
						ordinary_drivers.insert(bit);
		}
		struct DriverPaths {
			RTLIL::Cell *cell;
			int offset;
			pool<std::pair<RTLIL::SigBit, RTLIL::SigBit>> assignments;
		};
		std::vector<DriverPaths> paths;
		pool<std::pair<RTLIL::SigBit, RTLIL::SigBit>> split_assignments, z_assignments;
		for (auto cell : tristates) {
			auto sig_y = cell->getPort(ID::Y);
			for (int i = 0; i < GetSize(sig_y); i++) {
				pool<std::pair<RTLIL::SigBit, RTLIL::SigBit>> assignments;
				auto outputs = first_output_bits(sig_y[i], aliases, &assignments);
				tristate_outputs.insert(outputs.begin(), outputs.end());
				if (GetSize(outputs) >= 2)
					split_assignments.insert(assignments.begin(), assignments.end());
				paths.push_back({cell, i, std::move(assignments)});
			}
		}
		// tribuf -logic merges mutually exclusive tri-state drivers, not an
		// always-on driver contending with a tri-state driver. Reject this
		// unsupported combination before removing aliases or lowering the
		// internal buffers, which would otherwise drop or short drivers.
		for (auto output : tristate_outputs) {
			std::vector<RTLIL::SigBit> pending = {output};
			pool<RTLIL::SigBit> visited;
			while (!pending.empty()) {
				auto bit = pending.back();
				pending.pop_back();
				if (!visited.insert(bit).second)
					continue;
				// Reading a different output contributes its resolved pad
				// value, not its internal tri-state driver's enable.
				if (ordinary_drivers.count(bit) || (bit.wire == nullptr && bit.data != RTLIL::State::Sz) ||
						(bit != output && bit.wire != nullptr && bit.wire->port_output))
					log_error("Cannot map tri-state output %s.%s: alias %s has a non-tri-state driver. "
							"Use explicitly enabled tri-state drivers instead.\n",
							log_id(module), log_signal(output), log_signal(bit));
				if (incoming.count(bit))
					for (auto source : incoming.at(bit)) {
						// A Z assignment adds no driver. Leaving it as an
						// alias would make SigMap replace the driven net by Z.
						if (source == RTLIL::State::Sz)
							z_assignments.insert({bit, source});
						pending.push_back(source);
					}
			}
		}
		if (split_assignments.empty() && z_assignments.empty())
			continue;
		// An intermediate alias can have additional tri-state drivers that
		// reach just one pad. Clone every source contributing to a removed
		// edge, not just the sources that initially caused the split.
		pool<RTLIL::Cell *> bitwise_sources;
		for (const auto &path : paths) {
			pool<RTLIL::SigBit> outputs;
			for (auto &assignment : path.assignments)
				if (split_assignments.count(assignment))
					outputs.insert(assignment.first);
			for (auto bit : outputs) {
				auto cell = path.cell;
				auto clone = module->addTribuf(NEW_ID, cell->getPort(ID::A)[path.offset],
						cell->getPort(cell->type == ID($tribuf) ? ID::EN : ID::E), bit);
				clone->attributes = cell->attributes;
				if (GetSize(cell->getPort(ID::Y)) > 1)
					bitwise_sources.insert(cell);
			}
		}
		// tribuf -logic groups drivers by their entire Y vector. Normalize
		// affected original sources per bit so a scalar driver overlapping
		// part of a vector merges correctly on the remaining internal net.
		for (auto cell : bitwise_sources) {
			auto sig_y = cell->getPort(ID::Y);
			for (int i = 0; i < GetSize(sig_y); i++) {
				auto bit_driver = module->addTribuf(NEW_ID, cell->getPort(ID::A)[i],
						cell->getPort(ID::EN), sig_y[i]);
				bit_driver->attributes = cell->attributes;
			}
			module->remove(cell);
		}
		std::vector<RTLIL::SigSig> connections;
		for (auto &conn : module->connections()) {
			RTLIL::SigSpec lhs, rhs;
			for (int i = 0; i < GetSize(conn.first); i++) {
				// Remove only edges replaced by the cloned source, preserving
				// independent drivers assigned to the same output bit.
				if (split_assignments.count({conn.first[i], conn.second[i]}) ||
						z_assignments.count({conn.first[i], conn.second[i]}))
					continue;
				lhs.append(conn.first[i]);
				rhs.append(conn.second[i]);
			}
			if (!lhs.empty())
				connections.emplace_back(lhs, rhs);
		}
		module->new_connections(connections);
	}
	return inactive_outputs;
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

std::vector<PromotedTristateOutput> promote_read_tristate_outputs(RTLIL::Design *design,
		const pool<RTLIL::SigBit> *inactive_outputs = nullptr)
{
	std::vector<PromotedTristateOutput> promoted;
	if (design == nullptr)
		return promoted;
	for (auto module : design->selected_unboxed_whole_modules()) {
		// Match the A:top selection used by iopadmap, including -noflatten.
		if (!module->get_bool_attribute(ID::top))
			continue;
		dict<RTLIL::SigBit, pool<RTLIL::SigBit>> aliases;
		for (auto &conn : module->connections())
			for (int i = 0; i < GetSize(conn.first); i++)
				aliases[conn.second[i]].insert(conn.first[i]);
		pool<RTLIL::SigBit> tri_y;
		// An inactive driver may have been removed from an always-driven
		// pad, but reads of that output must still use physical pad O.
		if (inactive_outputs != nullptr)
			tri_y.insert(inactive_outputs->begin(), inactive_outputs->end());
		for (auto cell : module->selected_cells()) {
			if (!cell->type.in(ID($tribuf), ID($_TBUF_)))
				continue;
			for (auto bit : cell->getPort(ID::Y)) {
				// Follow arbitrary assignment chains, stopping at the pad.
				// Outputs that read that pad are not tri-state drivers.
				auto outputs = first_output_bits(bit, aliases);
				tri_y.insert(outputs.begin(), outputs.end());
			}
		}
		for (auto wire : module->selected_wires()) {
			if (!wire->port_output || wire->port_input || wire->width < 1)
				continue;
			bool any_read = false, inactive_pad = false;
			pool<int> tristate_bits;
			for (int i = 0; i < wire->width; i++) {
				RTLIL::SigBit bit(wire, i);
				if (!tri_y.count(bit))
					continue;
				tristate_bits.insert(i);
				inactive_pad |= inactive_outputs != nullptr && inactive_outputs->count(bit);
				for (auto cell : module->selected_cells()) {
					for (auto &conn : cell->connections())
						if (cell->input(conn.first) && sig_reads(conn.second, bit))
							any_read = true;
				}
				for (auto &conn : module->connections())
					if (sig_reads(conn.second, bit))
						any_read = true;
			}
			// Even an unread, completely inactive pad needs OE=0 rather
			// than an ordinary output buffer with an undefined data input.
			if (!any_read && !inactive_pad)
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
		SigMap aliases(item.module);
		pool<RTLIL::SigBit> expected;
		for (int offset : item.tristate_bits)
			expected.insert(aliases(RTLIL::SigBit(port, offset)));
		bool mapped = false;
		for (auto cell : item.module->cells()) {
			if (cell->type != io_type || !cell->hasPort(pad_port))
				continue;
			bool mine = false;
			for (auto bit : cell->getPort(pad_port))
				if (expected.count(aliases(bit)))
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

// iopadmap leaves O disconnected for an ordinary driven inout bit. Give
// formerly tri-state bits an explicit always-enabled buffer so their readers
// keep the same physical pad read-back after an inactive driver is removed.
void buffer_promoted_output_drivers(RTLIL::Design *design,
		const std::vector<PromotedTristateOutput> &promoted)
{
	CellTypes celltypes(design);
	for (const auto &item : promoted)
		for (int offset : item.tristate_bits) {
			auto module = item.module;
			RTLIL::SigBit bit(module->wire(item.name), offset);
			SigMap aliases(module);
			dict<RTLIL::SigBit, pool<RTLIL::SigBit>> outgoing;
			for (const auto &conn : module->connections())
				for (int i = 0; i < GetSize(conn.first); i++)
					outgoing[conn.second[i]].insert(conn.first[i]);
			bool buffered = false, driven = false;
			for (auto cell : module->cells()) {
				if (cell->type.in(ID($tribuf), ID($_TBUF_)) &&
						aliases(cell->getPort(cell->type == ID($tribuf) ? ID::EN : ID::E)) != RTLIL::State::S1)
					for (auto source : cell->getPort(ID::Y))
						if (first_output_bits(source, outgoing).count(bit))
							buffered = true;
				for (const auto &conn : cell->connections())
					if (celltypes.cell_output(cell->type, conn.first) && sig_reads(conn.second, bit))
						driven = true;
			}
			for (const auto &conn : module->connections())
				for (int i = 0; i < GetSize(conn.first); i++)
					if (conn.first[i] == bit && conn.second[i] != RTLIL::State::Sz)
						driven = true;
			if (buffered || !driven)
				continue;
			RTLIL::SigBit data(module->addWire(NEW_ID)), read(module->addWire(NEW_ID));
			for (auto cell : module->cells())
				for (const auto &conn : cell->connections()) {
						auto output = conn.second;
						output.replace(bit, celltypes.cell_output(cell->type, conn.first) ? data : read);
						cell->setPort(conn.first, output);
				}
			std::vector<RTLIL::SigSig> connections;
			for (const auto &conn : module->connections()) {
				auto lhs = conn.first, rhs = conn.second;
				lhs.replace(bit, data);
				rhs.replace(bit, read);
				connections.emplace_back(lhs, rhs);
			}
			module->new_connections(connections);
			auto buffer = module->addCell(NEW_ID, RTLIL::escape_id("MISTRAL_IO"));
			buffer->setPort(RTLIL::escape_id("I"), data);
			buffer->setPort(RTLIL::escape_id("OE"), RTLIL::State::S1);
			buffer->setPort(RTLIL::escape_id("O"), read);
			buffer->setPort(RTLIL::escape_id("PAD"), bit);
			buffer->set_bool_attribute(ID::keep);
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
			pool<RTLIL::SigBit> inactive_outputs;
			// Preserve directed driver paths until pad analysis. The default
			// proc opt_expr can replace cell outputs by a contending constant.
			run(noiopad ? "proc" : "proc -noopt");
			if (flatten || help_mode) {
				run("check");
				run("flatten", "(skip if -noflatten)");
			}
			if (!noiopad) {
				run("tribuf");
				if (!help_mode)
					inactive_outputs = split_shared_tristate_outputs(active_design);
			}
			run("tribuf -logic");
			run("deminout");
			if (!help_mode && !noiopad) {
				auto found = promote_read_tristate_outputs(active_design, &inactive_outputs);
				promoted_tristate.insert(promoted_tristate.end(), found.begin(), found.end());
				buffer_promoted_output_drivers(active_design, promoted_tristate);
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
