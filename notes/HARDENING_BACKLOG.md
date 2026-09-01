# Hardening backlog — VMD-MDANCE plugin

Record of the 2026-08-31 review of the Tcl plugin (9 dimension-scoped finders
over `mdance/*.tcl` + `tests/`; 74 raw findings, 55 after dedup) and the two
hardening passes that followed.

**Every finding from that review is now fixed.** Each was reproduced before
being changed, and each fix is pinned by a test that was confirmed to fail
without it. Test suite: 126 → 208 checks, all passing (`./tests/run_tests.sh`).

Baseline for a full diff of the work: `git diff 5251368..HEAD`.

## Pass 1 — the five high-severity defects and their neighbourhood

Commits `e2982a9`, `1124429`, `5cee1fa`, `acb0287`, `3c62958`, `5eee47f`, `3348261`.

| Area | Defect |
|---|---|
| `frame_list` | Non-numeric first/last/stride silently string-compared, clustering the wrong frames |
| `_frame_coords` | Frame-dependent atom selections produced a ragged matrix and silently wrong labels |
| Elbow plot | Failed K recorded as a real `(K, 0, 0)` point, rendering as the optimal K |
| HELM dendrogram | Z-matrix is a forest; only one tree was laid out, so the plot always failed for nClusters ≥ 2 |
| Sweep | No interlock with single runs; `kstep` 0 hung VMD; NaN marked a successful run ERR; heatmap crashed on missing scores |
| Backend discovery | `find_cli`/`find_library` resolved the plugin dir from a call-time `[info script]` |
| Sessions | Non-atomic save destroyed a good file; molid alone treated as molecule identity |
| Write paths | `close` errors swallowed, so a full disk yielded silently truncated CSVs |
| GUI | Unvalidated numeric fields reached the CLI; three re-entrancy holes; notebook touched after close |
| Plots | `msd_vs_population` missing `nClusters < 1` guard; RMSD matrix `atomselect` on an unloaded molecule |
| Diagnostics | Backend failures reported only "child process exited abnormally" |
| Test harness | `grep -q '0 failed'` also matched `10 failed` |

## Pass 2 — the remaining backlog

Commits `36a0790`, `ead60e9`, `84c90dc`.

**Correctness**
- `abs_frame` returned the sample index when the frame map did not reach it,
  pointing callers at an unrelated absolute frame. Returns `-1` now.
- `apply_cluster_colors` decided its reset pass from the frame map's *length*, so
  a trajectory that changed length kept stale colours; out-of-range samples were
  skipped silently. It now resolves the painted set, resets the exact complement,
  and returns/reports the number of samples it could not place.
- `load_session` accepted any file with the right four keys; inconsistent
  sessions died later inside a plot. Now validates nClusters against
  clusterSizes/representatives, label integrality, and the frame-map length.
- `run_clustering_cli` trusted `parse_json`, a regex scraper that returns a
  partial dict for truncated output. Required keys and the label/frame count are
  checked before anything downstream trusts the result.
- HELM initial-label files were read line-verbatim, so the plugin's own exported
  `frame,cluster` CSV fed back in became garbage. Both backends now go through
  `read_labels_file` (last column, header skipped, integers validated, count
  checked).
- Frame Tools export re-resolved `top` at export time. It now uses the molecule
  the selection actually ran against.
- `goto_prime_frame` validated against `::mdance::results`, which may have been
  replaced since PRIME ran, and never bounds-checked the frame.
- The transition heatmap left transitions into noise out of its row sums,
  inflating every displayed probability. Noise is counted, the title says rows
  sum to <1, and the CSV carries an explicit `-1` column.
- The residence chart labelled its axis "frames" while measuring samples.

**Robustness**
- `request_cancel` sent one TERM and waited; an unresponsive child froze VMD in
  `vwait` forever. Now escalates TERM → KILL → abandon the channel.
- No `WM_DELETE_WINDOW` handler: closing the window mid-run orphaned the child.
- The elbow scan never validated its K fields; a step of 0 looped forever.
- Degenerate elbow ranges drew the data off-canvas.
- The four synchronous backends exec'd an empty command word when `init` loaded
  the library instead of the CLI. Resolved via `_need_cli`.
- Y-tick gridlines were sized from the canvas `-width` *option*, not the plot.
- The timeline drew noise below the x-axis, over the frame labels.
- `on_plot_destroy` never released the `data()` cache.
- Residence bars could compute a negative width.
- The sweep heatmap's CH/DB toggle dereferenced a destroyed treeview.

**Security hardening**
- Intermediate files now live in a per-process `0700` directory instead of a
  world-writable `/tmp` under predictable names; `workdir` refuses a planted
  symlink or a directory owned by someone else.
- Derived outputs the user never named — a DCD's companion `.pdb`, the generated
  per-cluster set, the PostScript export fallback — confirm before overwriting.

**Test coverage**
- New scenarios: `backend_output` (truncated JSON, wrong label count),
  `helm_divine` (pre-cluster handoff, label files, DIVINE marshaling, the
  previously-unused `single_state.pdb`), `noise_math` (exact transition
  arithmetic, timeline lanes), plus sweep cancel/interlock/window-close, cancel
  escalation against a TERM-ignoring child, colouring a result that outruns the
  molecule, six inconsistent-session shapes, and the private workdir.
- The temp-file assertions no longer glob the shared system tmpdir, where they
  counted and deleted files belonging to concurrent VMD sessions.

## Known limitation, not a finding

The plots are exercised for "renders without error" and, where the arithmetic is
checkable, for exact values via their exported CSV. They have still **not** been
eyeballed on a real display for visual correctness.
