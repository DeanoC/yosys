#!/usr/bin/env python3
"""Check the Mistral M10K primitive clear ports."""
import argparse
import json
from pathlib import Path
import subprocess


def run(yosys, script, log):
    with log.open("w") as stream:
        subprocess.run([str(yosys), "-Q", "-T", "-s", str(script)],
                       stdout=stream, stderr=subprocess.STDOUT, check=True)


def synthesize(yosys, source, output, top="top", params=""):
    output.mkdir(parents=True, exist_ok=True)
    script = output / "synth.ys"
    json_path = output / "mapped.json"
    script.write_text(
        f"read_verilog -sv {source}\n"
        f"{params}"
        f"synth_intel_alm -top {top} -nolutram -nodsp -noiopad -noclkbuf\n"
        f"write_json {json_path}\n"
    )
    run(yosys, script, output / "synth.log")
    return json.loads(json_path.read_text())["modules"][top]


def cells(module, cell_type):
    return [cell for cell in module["cells"].values() if cell["type"] == cell_type]


def check_port(cell, port, expected):
    assert cell["port_directions"].get(port) == "input", (port, cell)
    assert cell["connections"].get(port) == expected, (port, cell)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yosys", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).parent
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    explicit = synthesize(args.yosys, root / "top.v", out / "explicit")
    sdp = cells(explicit, "MISTRAL_M10K")
    tdp = cells(explicit, "MISTRAL_M10K_TDP")
    assert len(sdp) == len(tdp) == 1
    check_port(sdp[0], "ACLR0", explicit["ports"]["aclr0"]["bits"])
    check_port(sdp[0], "ACLR1", explicit["ports"]["aclr1"]["bits"])
    check_port(tdp[0], "ACLR0", explicit["ports"]["aclr0"]["bits"])
    check_port(tdp[0], "ACLR1", explicit["ports"]["aclr1"]["bits"])
    print("PASS: explicit MISTRAL_M10K and MISTRAL_M10K_TDP retain ACLR0/ACLR1 inputs")

if __name__ == "__main__":
    main()
