#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Reject contention with an always-on driver before alias splitting or
# tribuf -logic can lose a source. Check single pads as well as siblings,
# scalar and partial-vector overlap, constants, and cell/module outputs.
for flatten in "" "-noflatten"; do
    for width in 1 2; do
        for shared in 0 1; do
            for position in 0 1 2 3; do
                for source in 0 1 2 3 4 5 7 8; do
                    "$YOSYS" -Q -T -p "
                        read_verilog tribuf_ordinary_driver.v
                        hierarchy -top tribuf_ordinary_driver -chparam WIDTH $width -chparam SHARED $shared -chparam POSITION $position -chparam SOURCE $source
                        logger -expect error \"Cannot map tri-state output .*non-tri-state driver\" 1
                        synth_intel_alm -top tribuf_ordinary_driver $flatten -noclkbuf
                        logger -check-expected
                    " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
                done
            done
        done
    done
done

# A Z assignment contributes no always-on drive and must remain accepted.
for position in 0 1 2 3; do
    "$YOSYS" -Q -T -p "
        read_verilog tribuf_ordinary_driver.v
        hierarchy -top tribuf_ordinary_driver -chparam WIDTH 2 -chparam POSITION $position -chparam SOURCE 6
        synth_intel_alm -top tribuf_ordinary_driver -noclkbuf
        select -assert-none t:\$_TBUF_
        select -assert-count 4 t:MISTRAL_IO
        select -assert-count 2 t:MISTRAL_OB
        select -assert-count 2 w:readback %x:+[PAD] t:MISTRAL_OB %i %ci1:+[I] w:* %i w:pad %x:+[PAD] t:MISTRAL_IO %i %co1:+[O] w:* %i %i
        check -assert
    " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
done
