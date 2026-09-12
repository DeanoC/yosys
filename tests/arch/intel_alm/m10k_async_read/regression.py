#!/usr/bin/env python3
"""Require native MISTRAL_M10K inference for a combinational read port."""

import argparse
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yosys", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).with_name("top.v").resolve()
    script = output / "synth.ys"
    mapped = output / "mapped.json"
    script.write_text(
        f"read_verilog -sv {source}\n"
        "synth_intel_alm -family cyclonev -nolutram -nodsp -noiopad -noclkbuf -top top\n"
        f"write_json {mapped}\n"
    )
    with (output / "synth.log").open("w") as log:
        subprocess.run([str(args.yosys.resolve()), "-Q", "-T", "-s", str(script)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)

    design = json.loads(mapped.read_text())
    cells = design["modules"]["top"]["cells"]
    memories = [cell for cell in cells.values() if cell["type"] == "MISTRAL_M10K"]
    assert len(memories) == 1, cells
    ram = memories[0]
    assert int(ram["parameters"]["CFG_ABITS"], 2) == 9
    assert int(ram["parameters"]["CFG_DBITS"], 2) == 20
    assert int(ram["parameters"]["CFG_ASYNC_READ"], 2) == 1
    assert ram["port_directions"]["CLK1"] == "input"
    assert ram["port_directions"]["A1EN"] == "input"
    assert ram["port_directions"]["B1EN"] == "input"
    assert ram["connections"]["B1EN"] == ["1"]
    assert ram["port_directions"]["B1DATA"] == "output"
    assert "CLK2" not in ram["connections"]

    init = ram["parameters"]["INIT"][::-1]
    for address in (0, 1, 7, 511):
        word = init[address * 20:(address + 1) * 20][::-1]
        expected = ((address * 73) ^ (address >> 1) ^ 0xA6) & ((1 << 20) - 1)
        assert int(word, 2) == expected, (address, word, expected)
    assert not any(cell["type"] == "$mem_v2" for cell in cells.values())
    print("PASS: native async M10K inference, constant-high B1EN, INIT and directions")

    # Exercise every fixed Cyclone V M10K SDP geometry.  The explicit library
    # entries avoid asking nextpnr to pack unsupported narrow or mixed widths.
    for width, abits in ((10, 10), (40, 8)):
        shape_output = output / f"shape{width}"
        shape_output.mkdir(exist_ok=True)
        shape_script = shape_output / "synth.ys"
        shape_json = shape_output / "mapped.json"
        shape_script.write_text(
            f"read_verilog -sv {source}\n"
            f"chparam -set WIDTH {width} -set ABITS {abits} top\n"
            "synth_intel_alm -family cyclonev -nolutram -nodsp -noiopad -noclkbuf -top top\n"
            f"write_json {shape_json}\n"
        )
        with (shape_output / "synth.log").open("w") as log:
            subprocess.run([str(args.yosys.resolve()), "-Q", "-T", "-s", str(shape_script)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        shape_cells = json.loads(shape_json.read_text())["modules"]["top"]["cells"]
        shape_memories = [cell for cell in shape_cells.values() if cell["type"] == "MISTRAL_M10K"]
        assert len(shape_memories) == 1, shape_cells
        shape_ram = shape_memories[0]
        assert int(shape_ram["parameters"]["CFG_ABITS"], 2) == abits
        assert int(shape_ram["parameters"]["CFG_DBITS"], 2) == width
        assert int(shape_ram["parameters"]["CFG_ASYNC_READ"], 2) == 1
        assert shape_ram["connections"]["B1EN"] == ["1"]
        assert "CLK2" not in shape_ram["connections"]
        print(f"PASS: native async {1 << abits}x{width} M10K geometry")

    simulation = output / "sim"
    simulation.mkdir(exist_ok=True)
    mem_sim = Path(__file__).resolve().parents[4] / "techlibs/intel_alm/common/mem_sim.v"
    testbench = Path(__file__).with_name("tb.v").resolve()
    vcd = simulation / "m10k_async.vcd"
    sim_script = simulation / "sim.ys"
    sim_script.write_text(
        f"read_verilog -sv {mem_sim} {testbench}\n"
        "hierarchy -top tb\n"
        "proc\n"
        "opt\n"
        f"sim -q -n 6 -clock clk -vcd {vcd} -a\n"
    )
    subprocess.run(
        [str(args.yosys.resolve()), "-Q", "-T", "-s", str(sim_script)],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    vcd_text = vcd.read_text()
    match = re.search(r"\$var\s+\w+\s+\d+\s+(\S+)\s+rd_data\s+\[19:0\]\s+\$end", vcd_text)
    assert match, vcd_text[:2000]
    value_id = match.group(1)
    samples = {}
    timestamp = None
    for line in vcd_text.splitlines():
        if line.startswith("#"):
            timestamp = int(line[1:])
        elif timestamp is not None and line.endswith(f" {value_id}"):
            bits = line.split()[0]
            if bits.startswith("b"):
                samples[timestamp] = int(bits[1:], 2)
    assert samples.get(0) == 0xA6, samples
    assert samples.get(20) == 0, samples
    assert samples.get(30) == 0x54321, samples
    assert samples.get(40) == 0, samples
    print("PASS: async M10K model reads INIT, writes on CLK1, and reads combinationally")

    # A pair of independent write/read ports must use the native true-dual-port
    # shape.  This catches accidental fallback to the registered TDP mapper,
    # which cannot represent a combinational read result.
    tdp_source = Path(__file__).with_name("tdp.v").resolve()
    tdp_output = output / "tdp"
    tdp_output.mkdir(exist_ok=True)
    tdp_script = tdp_output / "synth.ys"
    tdp_json = tdp_output / "mapped.json"
    tdp_script.write_text(
        f"read_verilog -sv {tdp_source}\n"
        "synth_intel_alm -family cyclonev -nolutram -nodsp -noiopad -noclkbuf -top tdp\n"
        f"write_json {tdp_json}\n"
    )
    with (tdp_output / "synth.log").open("w") as log:
        subprocess.run([str(args.yosys.resolve()), "-Q", "-T", "-s", str(tdp_script)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    tdp_design = json.loads(tdp_json.read_text())
    tdp_module = tdp_design["modules"]["tdp"]
    tdp_cells = [cell for cell in tdp_module["cells"].values()
                 if cell["type"] == "MISTRAL_M10K_TDP"]
    assert len(tdp_cells) == 1, tdp_module
    tdp_ram = tdp_cells[0]
    assert int(tdp_ram["parameters"]["CFG_ABITS"], 2) == 10
    assert int(tdp_ram["parameters"]["CFG_DBITS"], 2) == 10
    assert int(tdp_ram["parameters"]["CFG_ASYNC_READ"], 2) == 1
    # memory_libmap may exchange the physical ports to satisfy a primitive
    # polarity or geometry rule.  Check that each physical side keeps its
    # complete logical clock/address/data/write/read relationship.
    logical = {
        "a": {name: tdp_module["ports"][f"{name}_a"]["bits"]
              for name in ("clk", "we", "addr", "data", "q")},
        "b": {name: tdp_module["ports"][f"{name}_b"]["bits"]
              for name in ("clk", "we", "addr", "data", "q")},
    }
    assert {tuple(tdp_ram["connections"][port]) for port in ("CLK1", "CLK2")} == {
        tuple(logical[side]["clk"]) for side in logical
    }
    side_for_physical = {
        physical: next(side for side in logical
                       if tdp_ram["connections"][clock] == logical[side]["clk"])
        for physical, clock in (("A", "CLK1"), ("B", "CLK2"))
    }
    assert tdp_ram["connections"]["A1EN"] == ["1"]
    assert tdp_ram["connections"]["B1EN"] == ["1"]
    for physical, side in side_for_physical.items():
        assert tdp_ram["connections"][f"{physical}1ADDR"] == logical[side]["addr"]
        assert tdp_ram["connections"][f"{physical}1DATA"] == logical[side]["data"]
        assert tdp_ram["connections"][f"{physical}1WE"] == logical[side]["we"]
        assert tdp_ram["connections"][f"{physical}1Q"] == logical[side]["q"]
    assert not any(cell["type"] == "$mem_v2" for cell in tdp_module["cells"].values())
    print("PASS: native async TDP M10K inference, independent clocks and both read outputs")


if __name__ == "__main__":
    main()
