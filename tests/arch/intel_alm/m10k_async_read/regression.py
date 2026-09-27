#!/usr/bin/env python3
"""Forced Cyclone V M10K memories must have clocked read addresses."""

import argparse
import json
from pathlib import Path
import subprocess


ERROR = "Cyclone V M10K cannot implement an asynchronous read port"


def check(args, name, source, top, parameters=""):
    case = args.output / name
    case.mkdir(parents=True, exist_ok=True)
    script = case / "synth.ys"
    script.write_text(
        f"read_verilog -sv {source}\n"
        f"{parameters}"
        f"synth_intel_alm -family cyclonev -nolutram -nodsp -noiopad -noclkbuf "
        f"-top {top} -run begin:map_lutram\n"
    )
    result = subprocess.run([str(args.yosys.resolve()), "-Q", "-T", "-s", str(script)],
                            capture_output=True, text=True, timeout=120)
    log = result.stdout + result.stderr
    (case / "synth.log").write_text(log)
    assert result.returncode != 0, (name, log[-1500:])
    assert ERROR in log, (name, log[-1500:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yosys", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).parent
    for width, abits in ((10, 10), (20, 9), (40, 8)):
        check(args, f"sdp{width}", root / "top.v", "top",
              f"chparam -set WIDTH {width} -set ABITS {abits} top\n")
    alias = args.output / "top_ram_style.v"
    alias.write_text((root / "top.v").read_text().replace('ramstyle = "M10K"',
                                                        'ram_style = "m10k"'))
    check(args, "sdp20-alias", alias, "top")
    check(args, "tdp", root / "tdp.v", "tdp")

    # The same logical 256x40 async memory has a legal MLAB implementation
    # when LUT RAM is allowed. It uses forty 1-bit-wide lanes across eight
    # 32-word depth banks, or 320 logical MLAB cells.
    mlab = args.output / "top_mlab.v"
    mlab.write_text((root / "top.v").read_text().replace('ramstyle = "M10K"',
                                                       'ramstyle = "MLAB"'))
    case = args.output / "mlab40"
    case.mkdir(exist_ok=True)
    mapped = case / "mapped.json"
    script = case / "synth.ys"
    script.write_text(
        f"read_verilog -sv {mlab}\n"
        "chparam -set WIDTH 40 -set ABITS 8 top\n"
        "synth_intel_alm -family cyclonev -nodsp -noiopad -noclkbuf "
        "-top top -run begin:map_ffram\n"
        f"select -module top\nwrite_json -selected {mapped}\n"
    )
    with (case / "synth.log").open("w") as stream:
        subprocess.run([str(args.yosys.resolve()), "-Q", "-T", "-s", str(script)],
                       stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
    cells = json.loads(mapped.read_text())["modules"]["top"]["cells"].values()
    assert sum(c["type"] == "MISTRAL_MLAB" for c in cells) == 320
    assert not any(c["type"] == "MISTRAL_M10K" for c in cells)
    print("PASS: async M10K inference rejected; 256x40 MLAB alternative maps")


if __name__ == "__main__":
    main()
