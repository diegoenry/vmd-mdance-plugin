# CPP-MDANCE — Review Notes & Known Issues

Working notes for a later review/fix pass. Captures one confirmed crash bug,
some secondary issues, and the outstanding backlog. Nothing in here has been
"fixed" — these are flagged for you to review and apply fixes yourself.

Last updated alongside the eQUAL / PRIME / frame-tools / cancel / session work.

---

## 1. CONFIRMED BUG (high priority): DIVINE `refine=true` crashes for OutlierPair / SplinterPair anchors

### Symptom
`ctest` (target `mdance_tests`) aborts in `DivineTest.TestCombinations` with an
Eigen assertion:

```
Assertion failed: (m_xpr.rowIndices()[row] >= 0 && m_xpr.rowIndices()[row] < m_xpr.nestedExpression().rows() ...),
function coeff, file IndexedView.h, line 271.
```

This is a real out-of-bounds (undefined behavior; would corrupt/crash in a
release build with asserts off), not a test-only issue.

### Reproduce
- Via the test suite: `cd build && ctest -R mdance_tests` (aborts).
- Minimal: DIVINE with `anchor = OutlierPair` (or `SplinterPair`) **and**
  `refine = true`, on any clustering where the cluster being split is **not** a
  contiguous block starting at row 0 of the input — i.e. essentially always
  after the first split. The first failing combination in `TestCombinations` is
  `split=MSD, anchor=OutlierPair, refine=true`.
- A standalone probe that prints each combination before running (so the last
  printed line is the culprit) confirmed it: NANI combos pass; the crash is the
  first OutlierPair combo.

### Root cause — index-space conflation in `src/cluster/divine.cpp`
`splitCluster()` builds `subdata` as the rows of the *global* `data` matrix for
the cluster being split:

```cpp
// divine.cpp:106-111
Veci subdataIndices;                 // GLOBAL frame indices of this cluster
...
Mat subdata = data(subdataIndices, Eigen::placeholders::all);   // local rows 0..n-1
```

The **OutlierPair** branch then fills the masks with **global** indices:

```cpp
// divine.cpp:148-152
if (dA[i] < dB[i]) initialMask.push_back(clusters[clusterToSplit][i]);  // GLOBAL index
else               notInitialMask.push_back(clusters[clusterToSplit][i]);
```

…but in the `refine` block immediately uses those **global** indices to index
the **local** `subdata` matrix:

```cpp
// divine.cpp:156-157   <-- BUG
Mat groupA = subdata(initialMask,    Eigen::placeholders::all);
Mat groupB = subdata(notInitialMask, Eigen::placeholders::all);
```

`subdata` has only `clusters[clusterToSplit].size()` rows, but `initialMask`
holds global frame indices (up to `data.rows()-1`), so the row index is out of
range → the assertion.

The **SplinterPair** branch has the identical defect:

```cpp
// divine.cpp:218,231,233   masks hold GLOBAL indices (subdataIndices[i])
// divine.cpp:237-238       <-- BUG: indexes local subdata with global indices
Mat groupA = subdata(mainGroup,     Eigen::placeholders::all);
Mat groupB = subdata(splinterGroup, Eigen::placeholders::all);
```

The **NANI** branch (divine.cpp:113-127) is correct and is the reference for the
right pattern: it iterates local `i` over `sublabels` and only pushes the global
`clusters[clusterToSplit][i]` into the output cluster lists.

### Scope
- Crashes only when `refine == true`. The non-refine `else` paths
  (divine.cpp:197-205 and the SplinterPair equivalent) use the masks only as
  cluster-membership lists (global indices — correct) and do not crash.
- `anchor = NANI` is unaffected.
- Because the GUI defaults DIVINE to `refine` ON with the NANI anchor, the
  default path is safe; the crash is reachable by choosing OutlierPair or
  SplinterPair in the DIVINE tab (or `--anchors OutlierPair/SplinterPair` on the
  CLI) with refine enabled.

### Suggested minimal fix
The masks already hold valid **global** indices, and `data` is the full matrix,
so index `data` instead of `subdata` in the refine blocks:

```cpp
// OutlierPair (divine.cpp:156-157)
Mat groupA = data(initialMask,    Eigen::placeholders::all);
Mat groupB = data(notInitialMask, Eigen::placeholders::all);

// SplinterPair (divine.cpp:237-238)
Mat groupA = data(mainGroup,     Eigen::placeholders::all);
Mat groupB = data(splinterGroup, Eigen::placeholders::all);
```

`groupA.row(medoidA)` / `groupB.row(medoidB)` then remain valid because
`medoidA/medoidB` are local indices into `groupA/groupB`. Re-run
`ctest -R mdance_tests` to confirm `TestCombinations` passes for all 18 combos.

### Secondary issues in the same blocks (review while here)
- `Index medoidA = groupA.size() <= 2 ? 0 : calculateMedoid(...)` (divine.cpp:159,
  241) uses `.size()` (rows × cols), not `.rows()`. For 2-D data this means the
  "tiny group" guard triggers for groups with ≤1 row, not ≤2. Likely intended
  `.rows()`.
- divine.cpp:240 mixes units: `medoidA` guard tests `splinterGroup.size()` (a
  std::vector length) while `medoidB` tests `groupB.size()` (an Eigen size).
  Make both consistent (probably `groupA.rows()` / `groupB.rows()`).

---

## 2. Other backend items to review

- **`alignTraj` is a stub** (`src/tools/bts.cpp` ~500-529): the `uni`/`kron`
  branches fall through to `return data;` (no-op). eQUAL/PRISM `align` other than
  `none` is rejected at the parse layer so nothing silently mis-runs, but the
  Kronecker/uniform alignment from Klem et al. is not implemented.
- **`esim` index coverage**: `AC`, `CTn`, `Ja0` are marked "Not implemented" in
  `src/tools/types.h` and are not offered in any metric list. Implement only if a
  dataset needs them.

---

## 3. Backlog (intentionally not implemented — see memory `mdance-algorithm-port-scope`)

- **SHINE**: clusters whole *trajectories* against each other; needs a
  multi-trajectory segmentation input and a Ward-linkage-from-distance-matrix
  primitive that don't exist. Not portable to the single-molecule, per-frame
  coordinate model without a new input pipeline.
- **PRISM / CADENCE**: no public reference implementation (CADENCE is paper-only).
  MDANCE's density/quality clustering on a coordinate matrix is eQUAL (ported).
- **mdBIRCH** (streaming): poor fit for the load-whole-trajectory model.

---

## 4. Verification status

- **eQUAL / PRIME / frame-selection**: validated by `tests/validate_equal_prime.py`
  (registered as the `validate_equal_prime` ctest). It drives the built
  `mdance-cli` and cross-checks against an independent NumPy reimplementation of
  the formulas plus analytic expectations (16 checks). Run:
  `cd build && ctest -R validate_equal_prime` or
  `MDANCE_CLI=build/cli/mdance-cli python3 tests/validate_equal_prime.py`.
- **C-API export**: `nm -gU build/capi/libmdance.dylib | grep mdance_` should list
  the `mdance_*` symbols (visibility fix). The Tcl extension only links when these
  are exported.
- **VMD plugin (Tcl)**: covered by an automated suite — `./tests/run_tests.sh`
  runs 213 checks (104 unit under plain `tclsh` with VMD/Tk stubbed, 109 runtime
  scenarios inside headless VMD against `tests/fake_mdance_cli`). See
  `tests/README.md` for the layout and `notes/HARDENING_BACKLOG.md` for what the
  2026-08-31 review found and fixed. Trust that suite for verification status,
  not this file. The plots are exercised for "renders without error" and, where
  the arithmetic is checkable, for exact values via their exported CSV — but they
  have still **not** been eyeballed on a real display for visual correctness.
- **Upstream cross-check**: the installed `mdance` Python is only an empty
  namespace stub (no submodules), so there is no upstream comparison; the NumPy
  reference above stands in for it. If you install the real upstream MDANCE, add a
  cross-check (eQUAL `ExtendedQuality` is deterministic with `seed_method=medoid`;
  PRIME's pipeline is file-based and harder to drive).
- **Docs**: `vmd_plugin/README.md` is current; the Sphinx tree under `docs/` and
  `vmd_plugin/QUICK_START.*` have not been updated for the features added this
  session (eQUAL, PRIME, sweep, frame range/stride, structure export, iSIM,
  frame tools, cancel/progress, session save/load).
