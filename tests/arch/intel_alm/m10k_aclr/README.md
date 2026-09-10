# M10K asynchronous clear ports

This regression checks the Mistral M10K primitive interface. `MISTRAL_M10K`
and `MISTRAL_M10K_TDP` expose `ACLR0`/`ACLR1` as active-high output-clear
controls so explicit primitive users can drive the physical clear inputs.
It also covers the standard `(* ramstyle = "M10K" *)` simple-dual-port
inference path: an active-high asynchronous reset of a registered read output
to zero is kept in the M10K and connected to physical `ACLR1`. `ACLR0` is tied
low, and the write/read enables remain connected to the primitive. Resets to a
nonzero value still require fabric emulation.
The simulation model's registered outputs are unchanged by this interface
extension; the paired Mistral backend regression checks the encoded clear
selection.

Run it with a Yosys installation containing the paired `intel_alm` techlibs:

```sh
python3 tests/arch/intel_alm/m10k_aclr/regression.py \
  --yosys /path/to/install/bin/yosys --output /tmp/m10k-aclr-yosys
```

The test covers explicit M10K and TDP primitives and checks that mapped JSON
retains both clear ports as inputs, then checks one inferred 512x20 M10K and
the techmap wrapper's independent read clock/read enables. This is
synthesis-interface coverage; nextpnr bitstream settings and hardware
behavior are tested in the paired Mistral regression.
