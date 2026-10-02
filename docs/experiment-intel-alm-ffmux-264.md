# Intel ALM native FF data-mux experiment

This is a generic, default-off compiler experiment for the investigation in
[FES issue 264](https://github.com/DeanoC/fes/issues/264). It has passed focused
host tests. No RAM-test synthesis, placement, route, timing gain or hardware
acceptance has been measured with this option.

## Mapping and safety contract

`synth_intel_alm -ffmux` runs `intel_alm_ffmux` after native FF mapping and
cleanup, before clock-buffer insertion and ABC9. The standalone pass accepts
the ordinary Yosys selection syntax. Without `-ffmux`, synthesis is unchanged.

For a direct scalar `$_MUX_` with `Y = S ? B : A` feeding `MISTRAL_FF.DATAIN`,
the pass changes only `DATAIN=A`, `SDATA=B`, and `SLOAD=S`. It retains the same
FF, `CLK`, `ENA`, `ACLR`, `SCLR`, `Q`, attributes and initialization. It keeps
the original mux and its other consumers; subsequent `opt_clean` removes only
muxes that have become unused.

Initial admission requires the native eight-port whitebox model, scalar
parameter-free primitives, `ACLR=1`, and `SCLR=SLOAD=SDATA=0`. Native Q has
zero initialization; incompatible explicit initialization is rejected. Driver
and alias analysis covers the entire module, including unselected cells.
Ambiguous, undriven, unknown, inout, protected or incompatible connections are
rejected. Both the mux and FF must be selected. Protection covers canonical
signal aliases and raw protected constant aliases without protecting every
unrelated use of the same constant.

The oracle is the actual `techlibs/intel_alm/common/dff_sim.v`, whose priority
is asynchronous clear, enable, synchronous clear, then synchronous data load.
This pass does not infer asynchronous loads or change reset priority. It has
no RAM-test hierarchy names, physical coordinates or constraint changes.

Fewer data-mux LUTs may improve a control/data path, but SLOAD is shared across
a LAB and SDATA consumes E/F routing resources. Packing, feedback paths and
other clock domains can regress. A functional proof does not establish a
routed timing benefit.

## Completed host validation

The final focused fixture completed normally with exit zero: 11 initialized
base proofs and 11 temporal-induction proofs, plus 54 pass invocations covering
full ABC9 flow, `-dff`, default-off behavior, shared consumers, aliases,
selection, protected constant aliases, malformed native shapes and control
exclusions. Existing `dffs.ys`, `adffs.ys`, and `fsm_init.ys` also passed.
Binary sequential equivalence uses defined arbitrary inputs and the native
models; it is not an X/Z or hardware proof.

Malformed internal mux fixtures are restored to a valid builtin shape before
the next script-line consistency check. Earlier failures exposed recursive
assertion reporting in Yosys's parallel internal-cell checker when a malformed
builtin escaped that boundary. The final fixture does not change the compiler
logger or internal-cell checker; the extra-port case reloads the native
snapshot instead of claiming same-object port removal.

The retained local evidence directory is
`/home/deano/kepler/worktrees/fes-fes-ramtest-compiler-gains-264-17a49c0d/out/ramtest-wide-reduction-264/capture-pipeline-264`
(below, `$RAW`). The source base was
`22bf145df1438aa46eb912beab5b5c19e491906a`; the compiler was built from selected
uncommitted production bytes. No compiled publication commit is asserted.

| Artifact | SHA-256 |
| --- | --- |
| `$RAW/yosys-ffmux-check-build-v1/record.json` | `cc6c95b085bf01303cca97d08864ea84614c3c91128ca2e43ea7087b38577533` |
| `$RAW/yosys-ffmux-test-current-ffmux-v5/record.json` | `fef0afa380add486268cc5bfa6276b47166f57a14832a8201f4c8b3b1bfefffe` |
| `build/toolchain-ramtest-timing/build/yosys-ffmux-264/yosys` under `sources/misteross` | `8ce1fe93a22e5be2db903aaf28b0c03e79a5d50d24d3a1fe4eb2d4e1cf514fc3` |
| The adjacent `yosys-abc` | `60db0250b9f637ff040d4b4d5858c4d578e3551d71909f50979f5587c4805fe9` |

The final focused test record is
`$RAW/yosys-ffmux-test-current-ffmux-v5/record.json`; its actual test log is
the adjacent `output.log`. The build record binds selected production source,
all ten initialized submodules, runtime share files, cache and compiler/ABC
bytes. Tests have separate recorded execution environments and source/test
inventories. Publication documentation and later commit metadata do not
inherit that historical build selection.

## Restart point

Keep the frozen RAM-test BUILD_ID `7168b508ab424b70f1c0f87b2035d821`. Its retained
inputs are `out/ramtest-merged-remap/measured-diagnostic/run-inputs.json`
(`1d5ec9f5e18bfffb6083860af8257bbfb5daf093014f20621a3b3bd623b189a8`), and
the previous synthesis is the adjacent `synth.json`
(`61ee68c657e49364425dd4ba4880a679e0759992f2750e284e256d1e4139de28`).
The 13 ordered RTL files, generated `fes_application.vh`, defines and original
one-shot command are recorded in the adjacent retained `yosys.log`.

Next, author a fresh paired producer with the actual selected compiler/ABC
and share closure: run the original one-shot synthesis twice, changing only
the `-ffmux` option. Do not regenerate BUILD_ID through the production recipe.
Use Yosys's generic `-P` header snapshots at the prepass boundary, immediately
after the pass and after cleanup; validate actual header IDs and names rather
than assuming numbering. The retained default-off boundary is header 15.41
`CLKBUFMAP`; the new enabled flow is expected to place `INTEL_ALM_FFMUX` there,
followed by `OPT_CLEAN` and `CLKBUFMAP` at 15.42 and 15.43.

`$RAW/trial_ramtest_ffmux_synth.py`
(`f6c3c9de1fb70697a84797ce91a4604283f9122cfa58cb91fcab494baee5cedd`)
is frozen and **unrun**. Its current strict
`-E` dependency audit is a known blocker: ABC9 registers temporary `input.xaig`
as an output and `output.aig` as an input, then removes the temporary directory.
The draft accepts only the final JSON output and declared RTL/share inputs,
so it would reject a normal ABC9 run. Fix this in a new reviewed producer;
do not silently relax the audit or invoke old operational entry points. Its
historical source/HEAD binding also needs explicit renewal after publication.

Prove the actual prepass delta and retention of FF controls, initialization,
shared consumers and protected boundaries before accepting the full mapped
netlist. Only then perform paired physical/timing qualification across every
required clock, phase window and final hold check. The 130 MHz goal remains
unresolved.
