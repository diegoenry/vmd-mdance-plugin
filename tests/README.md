# MDANCE VMD plugin — test suite

Two layers of tests:

- **Unit tests** (`unit/`) run under a plain `tclsh` with VMD/Tk stubbed. They
  exercise the pure-Tcl logic in isolation — fast, no display, no backend.
- **Runtime scenarios** (`runtime/`) run inside real **VMD** against a real test
  trajectory and a deterministic *fake backend*, driving the plugin end-to-end
  the way a user would (load → cluster → color → navigate → export → plot →
  sweep → cancel → analyze → save/load).

Because this is the standalone plugin copy (no compiled `mdance-cli` /
`mdance_tcl` backend), the runtime tests use **`fake_mdance_cli`**: a small,
deterministic Python stand-in that reads the coordinate CSV the plugin extracts,
performs a trivial-but-real medoid clustering / analysis, and writes JSON in
exactly the shape `parse_json` expects. This lets the *whole* CLI data path run
without the C++ project. Library mode is covered by defining Tcl procs that
mimic the loaded C extension.

## Running

```sh
./tests/run_tests.sh            # everything (unit + runtime)
./tests/run_tests.sh unit       # unit only (fast, no VMD)
./tests/run_tests.sh runtime    # runtime only (needs VMD)
```

Config via environment:

| var           | default                                   | meaning                         |
|---------------|-------------------------------------------|---------------------------------|
| `TCLSH`       | `tclsh8.6` (else `tclsh`)                 | interpreter for unit tests      |
| `VMD`         | the VMD2.app path (else `vmd`)            | VMD binary for runtime tests    |
| `VMD_TIMEOUT` | `180`                                     | per-scenario safety timeout (s) |

The driver exits non-zero if any test fails, so it is CI-friendly.

### Notes on running under VMD

- VMD's `-e script` does **not** set `info script`, so the driver passes the
  tests directory via `MDANCE_TESTS_DIR`.
- VMD's Tk console swallows `puts`/stdout unpredictably, so the harness writes
  results to the file named by `MDANCE_TEST_OUT` (the driver sets this per
  scenario and prints the file).
- Dialog procs (`tk_messageBox`, `tk_getSaveFile`, …) are stubbed **after** the
  plugin is sourced, because `package require Tk` re-installs the real ones.

## Layout

```
tests/
  harness.tcl            portable assert harness (th::test / th::eq / th::throws / ...)
  stubs.tcl              VMD/Tk stubs so the plugin loads under plain tclsh
  fake_mdance_cli        deterministic Python backend (clustering/analysis/prime/select)
  run_tests.sh           driver (unit via tclsh, runtime via VMD)
  fixtures/
    make_fixtures.py     regenerates the PDB trajectories
    two_state.pdb        24 frames, 8 CA, two conformational states
    outlier.pdb          12 frames, 6 CA, one large outlier frame
    single_state.pdb     10 frames, 5 CA, one state (degenerate / k=1)
  unit/
    test_utils.tcl       parse_json (incl. NaN/Infinity/sci-notation), mktmp/cleanup,
                         tmpdir, the private 0700 workdir, find_cli/find_library
    test_frames_index.tcl frame_list, range_params, abs_frame (subset/stride mapping)
    test_validation.tcl  _chknum, fmt_score, _busy_guard
    test_plot_math.tcl   cluster_color, nice_ticks (integer-range regression), heatmap_color
    test_session.tcl     save_session / load_session round-trip + rejection
  runtime/
    _setup.tcl           shared runtime setup (fake backend, fixture loader)
    scenario_workflow.tcl    KMeans -> color -> goto -> export; + frame range/stride mapping
    scenario_equal_plots.tcl eQUAL noise (-1) -> every plot renders without crashing
    scenario_sweep.tcl       parameter sweep with one failing config (isolation + best-pick)
    scenario_cancel.tcl      cancel a long run; backend failure; no temp/process leaks
    scenario_extras.tcl      library mode (no temp files), iSIM / PRIME / Frame-Tools, sessions
    scenario_selection.tcl   frame-dependent atom selections are refused, not mis-extracted
    scenario_dendrogram.tcl  HELM's zMatrix is a FOREST; every tree must be laid out
    scenario_helm_divine.tcl HELM pre-cluster handoff + initial-label files, DIVINE args, k=1
    scenario_backend_output.tcl  backend exits 0 with truncated JSON / a wrong label count
    scenario_noise_math.tcl  transition probabilities and timeline lanes account for noise
```

## Fake backend test hooks

`fake_mdance_cli` honors these env vars (set by scenarios):

- `MDANCE_FAKE_FAIL=1`     — exit non-zero (simulate a crashed backend)
- `MDANCE_FAKE_FAIL_K=<k>` — fail only for `--nclusters <k>` (one bad sweep config)
- `MDANCE_FAKE_SLEEP=<s>`  — stream progress to stderr for `<s>` seconds (so a run
                              can be cancelled mid-flight)
- `MDANCE_FAKE_IGNORE_TERM=1` — ignore SIGTERM, so the cancel escalation
                              (TERM → KILL) is exercised rather than assumed
- `MDANCE_FAKE_TRUNCATE=1` — exit 0 having written only HALF a JSON document,
                              the way a backend killed mid-write leaves it
- `MDANCE_FAKE_EXTRA_LABELS=<n>` — exit 0 with `<n>` more labels than frames

## What the scenarios cover (and which hardening they guard)

- **workflow** — the everyday path, plus the load-bearing subset→absolute frame
  mapping (labels/representatives/coloring/export all map back to true VMD frames).
- **equal_plots** — eQUAL produces `-1` noise labels; `cluster_color`,
  `compute_centroids` and every plot must handle them (regression for the
  `-1`-sentinel crashes).
- **sweep** — one failing configuration becomes an `ERR` row instead of wedging
  the whole sweep; a missing score never wins "best".
- **cancel** — a long run is interrupted cleanly from the event loop; a non-zero
  backend exit surfaces a clear error; neither leaks temp files or child
  processes; confirms the streaming pipe and the `exec`-based paths both work
  with the GUI open.
- **extras** — native library mode creates **no** temp files; iSIM / PRIME /
  Frame-Tools analyses; session save/load with a live molecule.

## Regenerating fixtures

```sh
python3 tests/fixtures/make_fixtures.py
```
(The driver does this automatically before the runtime scenarios.)
