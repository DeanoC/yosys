#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

synth() {
    local top="$1"
    local json="$2"
    "$YOSYS" -q -p "
        read_verilog m10k_rom_clock.v
        synth_intel_alm -family cyclonev -top ${top} -noiopad -noclkbuf
        write_json ${json}
    "
}

check_rom() {
    python3 - "$@" <<'PY'
import json
import sys

path, top, kind = sys.argv[1], sys.argv[2], sys.argv[3]
mixed = kind == "mixed"
cells = json.load(open(path))["modules"][top]["cells"].values()
m10ks = [cell for cell in cells if cell["type"] == "MISTRAL_M10K"]
assert len(m10ks) == 1, len(m10ks)
ram = m10ks[0]
clk1 = ram["connections"]["CLK1"]
clk2 = ram["connections"]["CLK2"]
assert clk1 == clk2, (clk1, clk2)
assert clk1 not in (["0"], ["1"], ["x"], ["z"]), clk1
expected_a1en = ["0"] if kind in ("memory", "mixed") else ["1"]
assert ram["connections"]["A1EN"] == expected_a1en, ram
if mixed:
    assert int(ram["parameters"]["CFG_MIXED_WIDTH"], 2) == 1, ram["parameters"]
    assert int(ram["parameters"]["CFG_DBITS"], 2) == 10, ram["parameters"]
    assert int(ram["parameters"]["CFG_RD_DBITS"], 2) == 40, ram["parameters"]
elif kind == "memory":
    assert int(ram["parameters"]["CFG_BYTE_ENABLE"], 2) == 1, ram["parameters"]
elif kind == "byte_enable_zero_mask":
    assert int(ram["parameters"]["CFG_BYTE_ENABLE"], 2) == 1, ram["parameters"]
    assert int(ram["parameters"]["CFG_DBITS"], 2) == 20, ram["parameters"]
    assert ram["connections"]["A1BE"] == ["0", "0"], ram
print(f"PASS: {top} maps one registered ROM with CLK1 tied to CLK2")
PY
}

synth m10k_rom_clock "$WORK/standard.json"
check_rom "$WORK/standard.json" m10k_rom_clock memory

synth m10k_const1_clock "$WORK/const1.json"
check_rom "$WORK/const1.json" m10k_const1_clock const1

synth m10k_byte_enable_zero_mask_clock "$WORK/byte_enable_zero_mask.json"
check_rom "$WORK/byte_enable_zero_mask.json" m10k_byte_enable_zero_mask_clock byte_enable_zero_mask

synth m10k_mixed_primitive_clock "$WORK/mixed_primitive.json"
check_rom "$WORK/mixed_primitive.json" m10k_mixed_primitive_clock mixed
