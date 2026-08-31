# Hardening backlog — VMD-MDANCE plugin

Output of the 2026-08-31 review of the Tcl plugin (9 dimension-scoped finders
over `mdance/*.tcl` + `tests/`, 74 raw findings, 55 after dedup). Everything in
"Fixed" was reproduced first and is now pinned by a test; everything under
"Open" is a real finding that has **not** been touched.

Fixes landed in commits `e2982a9`, `1124429`, `5cee1fa`, `acb0287`, `3c62958`,
`5eee47f`. Test suite went 126 → 162 checks, all passing.

## Fixed

All five high-severity findings, plus:

| Area | Defect |
|---|---|
| `frame_list` | Non-numeric first/last/stride silently string-compared, clustering the wrong frames |
| `_frame_coords` | Frame-dependent atom selections produced a ragged matrix and silently wrong labels |
| Elbow plot | Failed K recorded as a real `(K, 0, 0)` point, rendering as the optimal K |
| HELM dendrogram | Z-matrix is a forest; only one tree was laid out, so the plot always failed for nClusters ≥ 2 |
| Sweep | No interlock with single runs (cross-deleted temp files); `kstep` 0 hung VMD; NaN score marked a successful run as ERR; heatmap crashed on missing scores |
| Backend discovery | `find_cli`/`find_library` resolved the plugin dir from a call-time `[info script]`, i.e. relative to the working directory |
| Sessions | Non-atomic save destroyed a good file on failure; molid alone was treated as molecule identity |
| Write paths | `close` errors swallowed, so a full disk yielded silently truncated CSVs |
| GUI | Unvalidated numeric fields reached the CLI command line; three re-entrancy holes; notebook touched after window close |
| Plots | `msd_vs_population` missing the `nClusters < 1` guard; RMSD matrix `atomselect` on an unloaded molecule |
| Diagnostics | Backend failures reported only "child process exited abnormally" |
| Test harness | `grep -q '0 failed'` also matched `10 failed`, so a scenario with 10+ failures passed |

## Open — worth doing next

**Correctness**
- `mdance.tcl` `apply_cluster_colors`: silently skips samples whose mapped frame
  is out of range, and skips the unassigned-reset pre-pass when the frame count
  changed after analysis. Should count and report skips.
- `mdance.tcl` `load_session`: validates key *presence* only. An internally
  inconsistent session (nClusters ≠ llength clusterSizes, labels longer than the
  frame map) loads cleanly and crashes a plot later.
- `mdance_gui.tcl` `frame_tools_export`: re-resolves `top` at export time, so
  frame indices computed against one molecule can be written from another.
  Store the resolved molid alongside `ft_frames`.
- `mdance_plots.tcl` `transition_heatmap`: transitions to/from noise (−1) are
  dropped from the row sums, inflating the displayed probabilities. Either
  include a noise row/column or say the probabilities are conditional.
- `mdance_plots.tcl` residence chart: reports run lengths in samples but labels
  them "frames" — off by the stride factor.
- `mdance.tcl` HELM initial-labels reader: takes each line verbatim, so the
  plugin's own exported `frame,cluster` CSV is mis-parsed (header + two columns).

**Robustness**
- `mdance_gui.tcl`: no `WM_DELETE_WINDOW` handler. Closing the window mid-run
  orphans an uncancellable backend child.
- `mdance.tcl` `request_cancel`: signals only the direct child, no process-group
  kill, so a wrapper script leaves the pipe open and wedges the `vwait`.
- `mdance_plots.tcl` elbow: K step of 0 loops forever (the sweep equivalent is
  fixed; this one is not).
- `mdance_plots.tcl` elbow: a single data point, or all-equal nonzero scores,
  resets the axis to [0,1] and draws the data off-canvas.
- `mdance_utils.tcl` `parse_json`: a regex parser that returns a partial dict for
  truncated output. Nothing validates that `llength labels` matches the frame
  map before those labels are used to colour frames.
- `mdance.tcl`: `run_analysis`/`run_prime`/`run_select`/`run_one_config` re-`init`
  on an empty `cli_path` but ignore `init` flipping to library mode, then exec an
  empty command word.
- `mdance_plots.tcl` `on_plot_destroy`: never releases the `data()` cache, pinning
  large matrices for the rest of the VMD session.

**Security hardening** (local, low severity on a single-user workstation)
- `mdance_utils.tcl` `mktmp`: predictable names (`mdance_<pid>_<ms>_<seq>`) in a
  world-writable `/tmp`, created without `O_EXCL`. Put everything in a per-run
  `0700` directory instead. *Note: `tests/runtime/scenario_extras.tcl` globs
  `tmpdir/mdance_*`, so that assertion has to move with it.*
- Export paths overwrite without prompting: DCD export clobbers the companion
  `.pdb`, and the PNG-export fallback silently writes a `.ps` the user never chose.

**Test coverage gaps**
- HELM end-to-end (nested pre-cluster handoff, zMatrix parsing) and DIVINE
  argument marshaling are untested.
- No test for a backend that exits 0 with truncated/garbage JSON.
- Sweep cancel and window-close-mid-sweep are untested (only failure isolation
  is covered).
- `tests/fixtures/single_state.pdb` — the documented degenerate/k=1 fixture — is
  generated but never loaded by any test.
- `scenario_cancel.tcl` glob-deletes `mdance_*` in the shared system tmpdir,
  which would interfere with a concurrent VMD session.
