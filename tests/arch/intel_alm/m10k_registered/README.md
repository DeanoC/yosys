# Registered ramstyle=M10K inference

This regression checks that a clocked-read `(* ramstyle = "M10K" *)` memory
stays a synchronous Mistral primitive. The Coleco 256×4 sprite line bank is
the motivating shape: two registered ports, one write enable, same clock.
It must use exactly one `MISTRAL_M10K_TDP`, with both clocks connected and
no fabric output registers; duplicating it into two SDP blocks wastes M10Ks.

The flow-through mapper (PR #13) previously selected `MISTRAL_M10K_TDP` with
`CFG_ASYNC_READ=1` and a constant `CLK2`, and left the output registers in
fabric. nextpnr rejects that contract. The registered libmap cells are kept
in `bram_m10k_sync.txt` and `bram_m10k_sync_map.v`, independently of the removed
asynchronous rules.

Run it with the built Yosys executable and matching `intel_alm` techlibs:

```sh
python3 tests/arch/intel_alm/m10k_registered/regression.py \
  --yosys /path/to/yosys --output /tmp/m10k-registered
```

The `m10k_async_read` regression checks that forced combinational-read
memories fail synthesis. This test does not claim hardware acceptance.
