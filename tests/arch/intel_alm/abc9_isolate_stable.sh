#!/usr/bin/env bash
# A BUILD_ID change must not retarget the unrelated payload cone.
set -euo pipefail
cd "$(dirname "$0")"
YOSYS="${YOSYS:-yosys}"
HERE="$(pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

synth_one() {
    local id="$1"
    local json="$2"
    local log="$3"
    "$YOSYS" -q -l "$log" -p "
        read_verilog -defer ${HERE}/abc9_isolate_stable.v
        hierarchy -chparam BUILD_ID ${id} -top top
        synth_intel_alm -family cyclonev -nobram -nolutram -nodsp -noiopad -noclkbuf -top top
        write_json ${json}
    "
}

synth_one "128'h0" "$WORK/old.json" "$WORK/old.log"
synth_one "128'h1" "$WORK/new.json" "$WORK/new.log"

for log in "$WORK/old.log" "$WORK/new.log"; do
    if ! grep -q "Isolating .* combinational cones" "$log"; then
        echo "expected cone isolation in $log" >&2
        exit 1
    fi
    networks="$(sed -n 's/.*Isolating \([0-9][0-9]*\) combinational cones.*(largest [0-9][0-9]* cells, \([0-9][0-9]*\) ABC networks).*/\2/p' "$log" | head -n 1)"
    if [ -z "$networks" ] || [ "$networks" -lt 2 ]; then
        echo "expected at least two ABC networks in $log" >&2
        exit 1
    fi
done

python3 "${HERE}/abc9_isolate_stable.py" "$WORK/old.json" "$WORK/new.json"
