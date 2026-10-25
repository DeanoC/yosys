# Explicit opt_merge cell identity

`(* nomerge = 1 *)` on a process propagates to its emitted FF. On a
combinational process it is copied onto the wires that process drives.
On a latch process, `proc_dlatch` copies it onto the inferred latch and
the private enable and data cone that feeds that latch.
`(* nomerge *)` on a wire covers the private logic driving that wire, so
replicated cones stay distinct. Public nets and ports remain shared
boundaries. `opt_merge` excludes true-marked cells from duplicate matching
on either side. Absent or false attributes retain existing behavior, as
does `(* keep *)` on a wire. This is narrower than `keep`: unused marked
cells can still be removed. It is not a placement lock or timing
exception, and does not disable constant-state simplification.

The attribute name is looked up once on the design twine pool before workers
start. Worker threads must not intern twines. A missing name means no cell
carries the attribute.

`run.py YOSYS OUTPUT --share SHARE` tests 22 cases through proc/opt_merge and the
actual Intel ALM flow: absent/false/one/both marked, init0/init1, clock and logical
D/Q polarity, distinct observable FFs, neutral attributes, unused-cell removal.
The executable needs its normal share directory and yosys-abc runtime files.
`controls.py CANDIDATE PINNED_BASELINE MATRIX_OUTPUT OUTPUT` checks unannotated
results against the pinned binary and 2200-FF designs with one/four thread caps.
Only verified equivalent runtime share-path prefixes are normalized in JSON.

Scope: opt_merge duplicate identity plus this non-sequential-ABC Intel flow.
This does not claim support for independent opt_dff -sat equivalent-state
merging or ABC9 -dff retiming. No such passes were changed or globally disabled.

The normal test suite automatically discovers `tests/opt/opt_merge_nomerge.ys`.
These Python scripts are supplemental detailed native-flow and baseline/thread
controls; they require explicit binary/runtime/output paths and are not auto-run.
