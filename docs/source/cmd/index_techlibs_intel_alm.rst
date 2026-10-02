Intel ALM (Cyclone V, Arria V, Cyclone 10 GX)
---------------------------------------------

``synth_intel_alm -ffmux`` enables an experimental data-mux mapping before
ABC9. It moves a direct one-bit mux into the unused synchronous-load inputs
of an ordinary, zero-initializing native FF while preserving its clock,
enable and output. The default synthesis flow is unchanged.

The initial mapping requires ``ACLR=1`` and ``SCLR=SLOAD=SDATA=0``. It does
not infer asynchronous load, alter reset priority, or replace existing load
controls. Both the mux and FF must be selected, and protected or ambiguous
connections are excluded. Shared mux outputs remain available to their other
consumers; ordinary cleanup removes only newly unused muxes.

This mapping can reduce external data-selection logic, but ``SLOAD`` is
shared across a LAB and ``SDATA`` uses E/F routing resources. Packing and
routed timing must be checked independently. The standalone
``intel_alm_ffmux`` command requires the native
``intel_alm/common/dff_sim.v`` whitebox and belongs after native FF mapping
and before ABC9; follow it with ``opt_clean``.

.. autocmdgroup:: techlibs/intel_alm
   :members:
