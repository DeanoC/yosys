#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/check_pads.py" <<'PYTHON'
import json, re, sys

module = json.load(open(sys.argv[1]))['modules'][sys.argv[2]]
cells = list(module['cells'].values())
for spec in sys.argv[3:]:
    port, sources = spec.split('=')
    sources = sources.split(',')
    bits = module['ports'][port]['bits']
    assert len(bits) == len(sources), (port, bits, sources)
    for index, (bit, source) in enumerate(zip(bits, sources)):
        context = (sys.argv[2], port, index, source)
        pads = [c for c in cells if c['type'] in ('MISTRAL_OB', 'MISTRAL_IO')
                and c['connections']['PAD'] == [bit]]
        assert len(pads) == 1, (context, pads)
        pad = pads[0]
        enable = '0' if source == 'z' else '1'
        if pad['type'] == 'MISTRAL_IO':
            assert pad['connections']['OE'] == [enable], (context, pad)
        else:
            # MISTRAL_OB is implicitly always enabled; disabled pads need IO.
            assert enable == '1', (context, pad)
        if source == 'z':
            continue
        match = re.fullmatch(r'(\w+)(?:\[(\d+)\])?', source)
        assert match, source
        input_port, input_index = match.groups()
        input_bit = module['ports'][input_port]['bits'][int(input_index or 0)]
        inputs = [c for c in cells if c['type'] == 'MISTRAL_IB'
                  and c['connections']['PAD'] == [input_bit]]
        assert len(inputs) == 1, (context, inputs)
        assert pad['connections']['I'] == inputs[0]['connections']['O'], (context, pad, inputs[0])
PYTHON

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
                        write_json $WORK/sweep.json
                        cd tribuf_ordinary_driver
                        select -assert-none t:\$_TBUF_
                        splitnets -ports
                        select -assert-count 1 w:pad[0] %x:+[PAD] t:MISTRAL_OB t:MISTRAL_IO %u %i %ci1:+[I] w:* %i %ci* w:d2 %i
                        select -assert-count $width w:readback* %x:+[PAD] t:MISTRAL_OB %i %ci1:+[I] w:* %i w:pad* %x:+[PAD] t:MISTRAL_IO %i %co1:+[O] w:* %i %i
                        check -assert
                    " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
                    pad_sources="d2"
                    other_sources="d[0]"
                    if [ "$width" = 2 ]; then
                        pad_sources+=",z"
                        other_sources+=",d[1]"
                    fi
                    if [ "$shared" = 1 ]; then
                        other_sources="z"
                        if [ "$position" = 0 ]; then
                            other_sources="d2"
                        fi
                        if [ "$width" = 2 ]; then
                            other_sources+=",z"
                        fi
                    fi
                    python3 "$WORK/check_pads.py" "$WORK/sweep.json" tribuf_ordinary_driver \
                        "pad=$pad_sources" "other_pad=$other_sources"
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
python3 "$WORK/check_pads.py" "$WORK/literal.json" literal_disabled 'pad=d2' 'other_pad=z'

# Bits 0 and 2 are disabled, but an ordinary driver keeps bit 0 enabled.
# Bits 1 and 3 retain their tri-state data with constant-high OE. Exercise
# both polarities so active-low enables must fold through an inversion.
cat > "$WORK/mixed.v" <<'VERILOG'
module mixed_disabled #(parameter ACTIVE_LOW = 0) (
    input wire [3:0] d,
    input wire d2, en,
    output wire [3:0] pad, other_pad, readback
);
    wire [3:0] driver_en, t, branch;
    assign driver_en = ACTIVE_LOW ? (({4{en}} | 4'b1111) & 4'b0101)
                                 : (({4{en}} & 4'b0000) | 4'b1010);
    genvar i;
    generate for (i = 0; i < 4; i = i + 1) begin
        if (ACTIVE_LOW) assign t[i] = driver_en[i] ? 1'bz : d[i];
        else assign t[i] = driver_en[i] ? d[i] : 1'bz;
    end endgenerate
    assign branch = t;
    assign branch[0] = d2;
    assign pad = branch;
    assign other_pad = t;
    assign readback = pad;
endmodule
VERILOG
for flatten in "" "-noflatten"; do
    for active_low in 0 1; do
        "$YOSYS" -Q -T -p "
            read_verilog $WORK/mixed.v
            hierarchy -top mixed_disabled -chparam ACTIVE_LOW $active_low
            synth_intel_alm -top mixed_disabled $flatten -noclkbuf
            write_json $WORK/mixed.json
            cd mixed_disabled
            select -assert-none t:\$_TBUF_
            splitnets -ports
            select -assert-count 4 w:readback* %x:+[PAD] t:MISTRAL_OB %i %ci1:+[I] w:* %i w:pad* %x:+[PAD] t:MISTRAL_IO %i %co1:+[O] w:* %i %i
            check -assert
        " > "$WORK/test.log" 2>&1 || { cat "$WORK/test.log"; exit 1; }
        python3 "$WORK/check_pads.py" "$WORK/mixed.json" mixed_disabled \
            'pad=d2,d[1],z,d[3]' 'other_pad=z,d[1],z,d[3]'
    done
done

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
