#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Inactive drivers contribute no contention, even when their enables must
# first fold through aliases, masked inputs, or opaque module outputs.
for flatten in "" "-noflatten"; do
    for width in 1 2; do
        for shared in 0 1; do
            for position in 0 1 2 3; do
                for enable in 1 2 3 4 5 6 10; do
                    "$YOSYS" -Q -T -p "
                        read_verilog tribuf_ordinary_driver.v
                        hierarchy -top tribuf_ordinary_driver -chparam WIDTH $width -chparam SHARED $shared -chparam POSITION $position -chparam ENABLE $enable
                        synth_intel_alm -top tribuf_ordinary_driver $flatten -noclkbuf
                        cd tribuf_ordinary_driver
                        select -assert-none t:\$_TBUF_
                        splitnets -ports
                        select -assert-count 1 w:pad[0] %x:+[PAD] t:MISTRAL_OB t:MISTRAL_IO %u %i %ci1:+[I] w:* %i %ci* w:d2 %i
                        select -assert-count $width w:readback* %x:+[PAD] t:MISTRAL_OB %i %ci1:+[I] w:* %i w:pad* %x:+[PAD] t:MISTRAL_IO %i %co1:+[O] w:* %i %i
                        check -assert
                    " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
                done
            done
        done
    done
done

# Literal-disabled sources can arrive as Z assignments with no tribuf cell.
cat > "$WORK/literal.v" <<'VERILOG'
module literal_disabled(input d, d2, output pad, other_pad, readback);
    wire t, branch;
    assign t = 1'b0 ? d : 1'bz;
    assign branch = t;
    assign branch = d2;
    assign pad = branch;
    assign other_pad = t;
    assign readback = pad;
endmodule
VERILOG
"$YOSYS" -Q -T -p "
    read_verilog $WORK/literal.v
    synth_intel_alm -top literal_disabled -noclkbuf
    write_json $WORK/literal.json
    check -assert
" > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
python3 - "$WORK/literal.json" <<'PYTHON'
import json, sys
module = json.load(open(sys.argv[1]))['modules']['literal_disabled']
for port, enable in [('pad', '1'), ('other_pad', '0')]:
    cells = [c for c in module['cells'].values()
             if c['type'] == 'MISTRAL_IO'
             and c['connections']['PAD'] == module['ports'][port]['bits']]
    assert len(cells) == 1, (port, cells)
    assert cells[0]['connections']['OE'] == [enable], (port, cells[0])
PYTHON

# A disabled sibling can still be read as ordinary data by another pad.
# Keep that read path on O and drive its destination with OE=1.
"$YOSYS" -Q -T -p "
    read_verilog tribuf_ordinary_driver.v
    hierarchy -top tribuf_ordinary_driver -chparam WIDTH 2 -chparam ENABLE 3 -chparam SOURCE 8
    synth_intel_alm -top tribuf_ordinary_driver -noclkbuf
    cd tribuf_ordinary_driver
    splitnets -ports
    select -assert-count 1 w:pad[0] %x:+[PAD] t:MISTRAL_IO %i %ci1:+[I] w:* %i w:other_pad* %x:+[PAD] t:MISTRAL_IO %i %co1:+[O] w:* %i %i
    check -assert
" > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }

# Neither an active enable nor an unknown enable proves inactivity. Case
# equality must not mistake an unknown input for a literal X constant.
for enable in 7 8 9; do
    "$YOSYS" -Q -T -p "
        read_verilog tribuf_ordinary_driver.v
        hierarchy -top tribuf_ordinary_driver -chparam ENABLE $enable
        logger -expect error \"Cannot map tri-state output .*non-tri-state driver\" 1
        synth_intel_alm -top tribuf_ordinary_driver -noclkbuf
        logger -check-expected
    " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
done
