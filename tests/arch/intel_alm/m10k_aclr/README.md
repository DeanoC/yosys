# M10K asynchronous clear ports

This regression checks the Mistral M10K primitive interface. `MISTRAL_M10K`
and `MISTRAL_M10K_TDP` expose `ACLR0`/`ACLR1` as active-high output-clear
controls so explicit primitive users can drive the physical clear inputs.
Inferred Verilog asynchronous read-output resets remain outside the current
memory mapper; they are intentionally implemented as fabric registers until a
dedicated reset-aware memory rule is added.
The simulation model's registered outputs are unchanged by this interface
extension; the paired Mistral backend regression checks the encoded clear
selection.

Run it with a Yosys installation containing the paired `intel_alm` techlibs:

```sh
python3 tests/arch/intel_alm/m10k_aclr/regression.py \
  --yosys /path/to/install/bin/yosys --output /tmp/m10k-aclr-yosys
```

The test covers explicit M10K and TDP primitives and checks that mapped JSON
retains both clear ports as inputs. This is synthesis-interface coverage;
nextpnr bitstream settings and hardware behavior are tested in the paired
Mistral regression.
