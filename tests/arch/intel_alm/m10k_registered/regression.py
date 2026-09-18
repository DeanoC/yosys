#!/usr/bin/env python3
"""Require registered ramstyle=M10K memories to stay synchronous."""

import argparse
import json
from pathlib import Path
import subprocess


def synthesize(yosys, source, output, top):
    output.mkdir(parents=True, exist_ok=True)
    script = output / "synth.ys"
    mapped = output / "mapped.json"
    script.write_text(
        f"read_verilog -sv {source}\n"
        f"synth_intel_alm -family cyclonev -nolutram -nodsp -noiopad -noclkbuf -top {top}\n"
        f"write_json {mapped}\n"
    )
    with (output / "synth.log").open("w") as log:
        subprocess.run(
            [str(yosys.resolve()), "-Q", "-T", "-s", str(script)],
            stdout=log,
            stderr=subprocess.STDOUT,
            check=True,
        )
    return json.loads(mapped.read_text())["modules"][top]


def is_const(bits):
    return bool(bits) and all(bit in ("0", "1") for bit in bits)


def async_flag(cell):
    raw = cell.get("parameters", {}).get("CFG_ASYNC_READ")
    if raw is None:
        return 0
    return int(raw, 2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yosys", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    linebank = synthesize(args.yosys, root / "linebank.v", out / "linebank", "linebank")
    assert not any(cell["type"] == "MISTRAL_FF" for cell in linebank["cells"].values()), linebank
    rams = [cell for cell in linebank["cells"].values() if "M10K" in cell["type"]]
    assert rams, linebank
    for ram in rams:
        assert async_flag(ram) == 0, ram
        clk2 = ram["connections"].get("CLK2")
        assert clk2 is not None and not is_const(clk2), ram["connections"]
    print("PASS: Coleco 256x4 registered line bank stays synchronous with a live CLK2")

    sdp = synthesize(args.yosys, root / "sdp.v", out / "sdp", "sdp")
    assert not any(cell["type"] == "MISTRAL_FF" for cell in sdp["cells"].values()), sdp
    sdp_rams = [cell for cell in sdp["cells"].values() if cell["type"] == "MISTRAL_M10K"]
    assert len(sdp_rams) == 1, sdp
    ram = sdp_rams[0]
    assert async_flag(ram) == 0, ram
    assert int(ram["parameters"].get("CFG_DUAL_CLOCK", "0"), 2) == 1, ram
    assert ram["connections"]["CLK1"] == sdp["ports"]["wr_clk"]["bits"]
    assert ram["connections"]["CLK2"] == sdp["ports"]["rd_clk"]["bits"]
    print("PASS: registered SDP keeps CFG_DUAL_CLOCK and independent live clocks")


if __name__ == "__main__":
    main()
