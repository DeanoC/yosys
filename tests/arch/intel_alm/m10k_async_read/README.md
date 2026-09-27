# Cyclone V M10K asynchronous read rejection

Cyclone V M10K has registered read-address inputs. Its optional unregistered
output is still a synchronous memory read. The [device handbook](https://docs.altera.com/r/docs/683375/current/cyclone-v-device-handbook-volume-1-device-interfaces-and-integration/embedded-memory-features)
lists asynchronous flow-through memory only for MLAB, not M10K.

`synth_intel_alm` rejects an inferred memory that requests an unclocked read
port together with `ramstyle="M10K"` or `ram_style="M10K"`. That explicit
resource request cannot be implemented with the requested read semantics;
choose MLAB or logic, or register the read address and align the pipeline.
The invalid async M10K library entries and techmap modules have been removed.

The regression checks 1024x10, 512x20 and 256x40 simple-dual memories plus a
true-dual memory. The paired nextpnr regression rejects direct primitive
instances that bypass inference. It also checks that the same 256x40 logical
memory maps to 320 one-bit-wide `MISTRAL_MLAB` cells when explicitly styled
MLAB and LUT RAM is enabled. Placement, timing and hardware behavior of that
wide MLAB design require separate validation. Run this test with the built
Yosys binary:

```sh
python3 tests/arch/intel_alm/m10k_async_read/regression.py \
  --yosys /path/to/yosys --output /tmp/m10k-async-reject
```
