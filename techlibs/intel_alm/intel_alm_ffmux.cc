/*
 *  yosys -- Yosys Open SYnthesis Suite
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
 */

#include "kernel/celltypes.h"
#include "kernel/sigtools.h"
#include "kernel/yosys.h"

USING_YOSYS_NAMESPACE
PRIVATE_NAMESPACE_BEGIN

static bool protected_object(const RTLIL::AttrObject &object)
{
	return object.get_bool_attribute(ID::keep) || object.get_bool_attribute(ID(dont_touch)) ||
	       object.get_bool_attribute(ID(donttouch));
}

static bool exact_scalar_ports(Cell *cell, std::initializer_list<IdString> ports)
{
	if (!cell->parameters.empty() || cell->connections().size() != ports.size())
		return false;
	for (auto port : ports)
		if (!cell->hasPort(port) || GetSize(cell->getPort(port)) != 1)
			return false;
	return true;
}

// This pass relies on the native whitebox in intel_alm/common/dff_sim.v,
// including its fixed zero power-up state. Do not apply the transformation
// to an opaque or parameterized cell that happens to have the same name.
static bool native_ff_model(Design *design)
{
	Module *model = design->module(ID(MISTRAL_FF));
	if (!model || protected_object(*model) || !model->get_bool_attribute(ID::whitebox) ||
	    !model->get_bool_attribute(ID(abc9_box)) || model->ports.size() != 8 ||
	    !model->avail_parameters.empty() || !model->parameter_default_values.empty())
		return false;

	pool<IdString> model_ports;
	for (auto port : model->ports)
		model_ports.insert(port);
	for (auto port : {ID(DATAIN), ID(CLK), ID(ACLR), ID(ENA), ID(SCLR), ID(SLOAD), ID(SDATA), ID::Q}) {
		Wire *wire = model->wire(port);
		if (!model_ports.count(port) || !wire || wire->width != 1 || protected_object(*wire) ||
		    wire->port_input != (port != ID::Q) || wire->port_output != (port == ID::Q))
			return false;
	}
	Wire *q = model->wire(ID::Q);
	if (q->attributes.count(ID::init)) {
		const Const &init = q->attributes.at(ID::init);
		if (GetSize(init) != 1 || init[0] != State::S0)
			return false;
	}
	return true;
}

struct IntelALMFfMuxWorker
{
	Design *design;
	Module *module;
	const CellTypes &celltypes;
	SigMap sigmap;
	dict<SigBit, int> drivers;
	dict<SigBit, Cell *> muxes;
	pool<SigBit> unsafe_bits, protected_bits, raw_protected_bits, incompatible_init;

	IntelALMFfMuxWorker(Design *design, Module *module, const CellTypes &celltypes)
		: design(design), module(module), celltypes(celltypes), sigmap(module)
	{
		// Inventory every cell and alias, including unselected cells. A
		// partially selected design must not hide another driver or boundary.
		for (auto wire : module->wires()) {
			SigSpec bits = sigmap(wire);
			for (int i = 0; i < GetSize(bits); i++) {
				SigBit bit = bits[i];
				if (protected_object(*wire)) {
					// Keep raw protected constant aliases distinct from every
					// unrelated alias of the same canonical literal value.
					raw_protected_bits.insert(SigBit(wire, i));
					if (bit.wire)
						protected_bits.insert(bit);
				}
				if (wire->port_input) {
					if (wire->port_output)
						unsafe_bits.insert(bit);
					else
						add_driver(bit);
				}
				if (wire->attributes.count(ID::init)) {
					const Const &init = wire->attributes.at(ID::init);
					if (i < GetSize(init) && init[i] != State::S0 && init[i] != State::Sx)
						incompatible_init.insert(bit);
				}
			}
		}
		for (auto cell : module->cells()) {
			for (const auto &conn : cell->connections()) {
				bool input = celltypes.cell_input(cell->type, conn.first);
				bool output = celltypes.cell_output(cell->type, conn.first);
				for (auto bit : sigmap(conn.second)) {
					if (!celltypes.cell_known(cell->type) || input == output)
						unsafe_bits.insert(bit);
					else if (output)
						add_driver(bit);
				}
			}
			if (cell->type == ID($_MUX_) && exact_scalar_ports(cell, {ID::A, ID::B, ID::S, ID::Y}))
				muxes[sigmap(cell->getPort(ID::Y))[0]] = cell;
		}
	}

	void add_driver(SigBit bit)
	{
		// Two is sufficient to reject ambiguity; do not let a pathological
		// number of aliases or drivers overflow the counter.
		if (drivers[bit] < 2)
			drivers[bit]++;
	}

	bool ordinary(SigBit bit) const
	{
		if (unsafe_bits.count(bit) || protected_bits.count(bit))
			return false;
		if (!bit.wire)
			return bit == State::S0 || bit == State::S1;
		auto it = drivers.find(bit);
		return it != drivers.end() && it->second == 1;
	}

	SigBit port_bit(Cell *cell, IdString port) const
	{
		return sigmap(cell->getPort(port))[0];
	}

	bool protected_connection(Cell *cell) const
	{
		for (const auto &conn : cell->connections())
			for (auto bit : conn.second)
				if (raw_protected_bits.count(bit))
					return true;
		return false;
	}

	bool eligible_ff(Cell *ff) const
	{
		if (ff->type != ID(MISTRAL_FF) || protected_object(*ff) || ff->has_keep_attr() ||
		    !exact_scalar_ports(ff, {ID(DATAIN), ID(CLK), ID(ACLR), ID(ENA), ID(SCLR), ID(SLOAD), ID(SDATA), ID::Q}) ||
		    protected_connection(ff))
			return false;
		// Initial scope is the ordinary synchronous, unreset native flop.
		// In particular, introducing a shared LAB SLOAD beside an active
		// SCLR, or changing asynchronous-load/reset inference, is excluded.
		if (port_bit(ff, ID(ACLR)) != State::S1 || port_bit(ff, ID(SCLR)) != State::S0 ||
		    port_bit(ff, ID(SLOAD)) != State::S0 || port_bit(ff, ID(SDATA)) != State::S0)
			return false;
		if (!port_bit(ff, ID(CLK)).wire || !port_bit(ff, ID::Q).wire ||
		    incompatible_init.count(port_bit(ff, ID::Q)))
			return false;
		for (const auto &conn : ff->connections())
			if (!ordinary(sigmap(conn.second)[0]))
				return false;
		return true;
	}

	size_t run()
	{
		size_t converted = 0;
		for (auto ff : module->selected_cells()) {
			if (!eligible_ff(ff))
				continue;
			SigBit d = port_bit(ff, ID(DATAIN));
			auto it = muxes.find(d);
			if (!d.wire || it == muxes.end())
				continue;
			Cell *mux = it->second;
			if (!design->selected(module, mux) || protected_object(*mux) || mux->has_keep_attr() ||
			    protected_connection(mux))
				continue;
			SigBit a = port_bit(mux, ID::A), b = port_bit(mux, ID::B), s = port_bit(mux, ID::S);
			if (!s.wire || !ordinary(a) || !ordinary(b) || !ordinary(s) ||
			    a == b || a == d || b == d || s == d)
				continue;

			// Native priority is ACLR, ENA, SCLR, then the data selection.
			// Retain the same FF and its controls/initialization; move only
			// Y = S ? B : A into that final native synchronous-load choice.
			ff->setPort(ID(DATAIN), mux->getPort(ID::A));
			ff->setPort(ID(SDATA), mux->getPort(ID::B));
			ff->setPort(ID(SLOAD), mux->getPort(ID::S));
			log("  Absorbing data mux %s into %s in module %s.\n", log_id(mux), log_id(ff), log_id(module));
			converted++;
			// Keep the mux and every other consumer intact. The caller's
			// ordinary opt_clean removes it only if it has become unused.
		}
		return converted;
	}
};

struct IntelALMFfMuxPass : public Pass
{
	IntelALMFfMuxPass() : Pass("intel_alm_ffmux", "Intel ALM: absorb data muxes into native FF synchronous-load inputs") {}

	void help() override
	{
		log("\n");
		log("    intel_alm_ffmux [selection]\n");
		log("\n");
		log("Absorb a direct one-bit $_MUX_ into the unused SLOAD/SDATA inputs of a\n");
		log("MISTRAL_FF: DATAIN=A, SDATA=B, SLOAD=S. Run after native FF mapping and\n");
		log("before ABC9, with the native intel_alm/common/dff_sim.v whitebox loaded.\n");
		log("\n");
		log("Only zero-initializing, synchronous FFs with ACLR=1 and SCLR=SLOAD=SDATA=0\n");
		log("are eligible. Preserve the FF, clock, enable, output and initialization.\n");
		log("Reject ambiguous, undriven, unknown or protected signals/cells. Both the\n");
		log("FF and mux must be selected. Shared muxes and their other consumers remain;\n");
		log("run opt_clean afterward to remove muxes that have become unused.\n");
		log("\n");
		log("This is an opt-in mapping experiment. Native SLOAD is shared across a LAB\n");
		log("and SDATA consumes E/F routing resources; fewer muxes need not improve\n");
		log("packing or routed timing. No placement or timing constraint is changed.\n");
		log("\n");
	}

	void execute(std::vector<std::string> args, RTLIL::Design *design) override
	{
		extra_args(args, 1, design);
		log_header(design, "Executing INTEL_ALM_FFMUX pass (absorb native FF data muxes).\n");
		if (!native_ff_model(design)) {
			log("No compatible native MISTRAL_FF whitebox; leaving the design unchanged.\n");
			return;
		}
		CellTypes celltypes(design);
		size_t converted = 0;
		for (auto module : design->selected_modules()) {
			if (module->get_blackbox_attribute() || protected_object(*module))
				continue;
			IntelALMFfMuxWorker worker(design, module, celltypes);
			converted += worker.run();
		}
		log("Absorbed %zu data muxes into MISTRAL_FF synchronous-load inputs.\n", converted);
	}
} IntelALMFfMuxPass;

PRIVATE_NAMESPACE_END
