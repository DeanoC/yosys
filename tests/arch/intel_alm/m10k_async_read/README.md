# Native asynchronous-read M10K inference

This regression checks the Cyclone V M10K flow-through shape used by
combinational-read memories.  A single-write/simple-dual memory maps to one
`MISTRAL_M10K` with `CFG_ASYNC_READ=1`, a constant-high read enable, and no
second clock.  A two-write/two-read memory maps to one
`MISTRAL_M10K_TDP` with both write clocks and both flow-through outputs.

Run it with the built Yosys executable and matching `intel_alm` techlibs:

```sh
python3 tests/arch/intel_alm/m10k_async_read/regression.py \
  --yosys /path/to/yosys --output /tmp/m10k-async-read
```

The test covers the 1024x10, 512x20, and 256x40 simple-dual geometries,
canonical initialization, the simulation model's write/comb-read behavior,
and the native true-dual shape with independent clocks.  Placement, routing,
encoded selectors, and timing are checked by the paired nextpnr Mistral
regression; these tests do not claim hardware acceptance.
