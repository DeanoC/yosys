#!/usr/bin/env bash
# A 128-entry case ROM must not reach nextpnr with CLK1 left at 1'x.
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

synth() {
    local top="$1"
    local extra="$2"
    local json="$3"
    "$YOSYS" -q -p "
        read_verilog case_rom.v
        synth_intel_alm -family cyclonev -top ${top} ${extra}
        write_json ${json}
    "
}

python_check() {
    python3 - "$@" <<'PY'
import json
import sys

path, kind = sys.argv[1], sys.argv[2]
cells = list(json.load(open(path))["modules"][kind if kind != "issue" else "rom_repro"]["cells"].values())
counts = {}
for cell in cells:
    counts[cell["type"]] = counts.get(cell["type"], 0) + 1
m10k = [cell for cell in cells if cell["type"] == "MISTRAL_M10K"]

def clocks(cell):
    clk1 = cell["connections"]["CLK1"]
    clk2 = cell["connections"]["CLK2"]
    assert "x" not in clk1 and "x" not in clk2, (clk1, clk2)
    return clk1, clk2

if kind == "rom_repro":
    assert counts == {
        "MISTRAL_ALUT4": 1,
        "MISTRAL_ALUT5": 1,
        "MISTRAL_FF": 10,
        "MISTRAL_M10K": 1,
        "MISTRAL_NOT": 1,
    }, counts
    clk1, clk2 = clocks(m10k[0])
    assert clk1 == clk2, (clk1, clk2)
    assert m10k[0]["connections"]["A1EN"] == ["0"]
elif kind == "issue":
    assert counts == {
        "MISTRAL_ALUT4": 1,
        "MISTRAL_ALUT5": 1,
        "MISTRAL_CLKBUF": 1,
        "MISTRAL_FF": 10,
        "MISTRAL_IB": 1,
        "MISTRAL_M10K": 1,
        "MISTRAL_NOT": 1,
        "MISTRAL_OB": 1,
    }, counts
    clk1, clk2 = clocks(m10k[0])
    assert clk1 == clk2, (clk1, clk2)
elif kind in ("narrow_rom", "async_rom"):
    assert "MISTRAL_M10K" not in counts, counts
elif kind == "sdp_ram":
    assert counts.get("MISTRAL_M10K") == 1, counts
    clk1, clk2 = clocks(m10k[0])
    assert clk1 != clk2, (clk1, clk2)
else:
    raise SystemExit(kind)
print(kind, "ok", counts)
PY
}

synth rom_repro "-noiopad -noclkbuf" "$WORK/rom_repro.json"
python_check "$WORK/rom_repro.json" rom_repro

synth rom_repro "" "$WORK/issue.json"
python_check "$WORK/issue.json" issue

synth narrow_rom "-noiopad -noclkbuf" "$WORK/narrow.json"
python_check "$WORK/narrow.json" narrow_rom

synth async_rom "-noiopad -noclkbuf" "$WORK/async.json"
python_check "$WORK/async.json" async_rom

synth sdp_ram "-noiopad -noclkbuf" "$WORK/sdp.json"
python_check "$WORK/sdp.json" sdp_ram
