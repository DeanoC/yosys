# Registered ramstyle=M10K inference

This regression checks that a clocked-read `(* ramstyle = "M10K" *)` memory
stays a synchronous Mistral primitive. The Coleco 256×4 sprite line bank is
the motivating shape: two registered ports, one write enable, same clock.

The flow-through mapper (PR #13) previously selected `MISTRAL_M10K_TDP` with
`CFG_ASYNC_READ=1` and a constant `CLK2`, and left the output registers in
fabric. nextpnr rejects that contract. The registered libmap cells must win.

Run it with the built Yosys executable and matching `intel_alm` techlibs:

```sh
python3 tests/arch/intel_alm/m10k_registered/regression.py \
  --yosys /path/to/yosys --output /tmp/m10k-registered
```

Combinational-read coverage stays in `m10k_async_read`. This test does not
claim hardware acceptance.
