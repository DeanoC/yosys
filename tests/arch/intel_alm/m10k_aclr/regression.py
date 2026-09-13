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


def techmap_ports(yosys, source, output, top="top"):
    output.mkdir(parents=True, exist_ok=True)
    script = output / "techmap.ys"
    json_path = output / "mapped.json"
    script.write_text(
        f"read_verilog -sv +/intel_alm/common/bram_m10k_aclr_map.v {source}\n"
        f"hierarchy -top {top}\n"
        "techmap -map +/intel_alm/common/bram_m10k_aclr_map.v\n"
        "flatten\n"
        "opt\n"
        f"write_json {json_path}\n"
    )
    run(yosys, script, output / "techmap.log")
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

    inferred = synthesize(args.yosys, root / "inferred.v", out / "inferred")
    inferred_sdp = cells(inferred, "MISTRAL_M10K")
    assert len(inferred_sdp) == 1, inferred
    assert not cells(inferred, "MISTRAL_FF"), inferred
    check_port(inferred_sdp[0], "ACLR0", ["0"])
    check_port(inferred_sdp[0], "ACLR1", inferred["ports"]["arst"]["bits"])
    check_port(inferred_sdp[0], "A1EN", inferred["ports"]["wr_en"]["bits"])
    check_port(inferred_sdp[0], "B1EN", inferred["ports"]["rd_en"]["bits"])
    print("PASS: inferred ramstyle=M10K maps zero read-output async reset to ACLR1")

    direct = techmap_ports(args.yosys, root / "map_ports.v", out / "map_ports")
    direct_sdp = cells(direct, "MISTRAL_M10K")
    assert len(direct_sdp) == 1, direct
    ram = direct_sdp[0]
    assert ram["connections"]["ACLR0"] == ["0"]
    assert ram["connections"]["ACLR1"] == direct["ports"]["arst"]["bits"]
    b1en = ram["connections"]["B1EN"]
    read_gate = [
        cell for cell in direct["cells"].values()
        if cell["type"] in ("$and", "$logic_and")
        and cell["connections"].get("Y") == b1en
    ]
    assert len(read_gate) == 1, direct
    assert sorted(read_gate[0]["connections"]["A"] + read_gate[0]["connections"]["B"]) == sorted(
        direct["ports"]["rd_clk_en"]["bits"] + direct["ports"]["rd_en"]["bits"]
    ), direct
    print("PASS: M10K SDP techmap combines independent read clock/read enables")

if __name__ == "__main__":
    main()
