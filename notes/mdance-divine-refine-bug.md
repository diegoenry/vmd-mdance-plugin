---
name: mdance-divine-refine-bug
description: Known DIVINE crash (OutlierPair/SplinterPair + refine) and where the review doc lives
metadata: 
  node_type: memory
  type: project
  originSessionId: 42b79370-5dc3-4d30-97e2-6f8ad5cafee7
---

CPP-MDANCE `src/cluster/divine.cpp` has a confirmed out-of-bounds crash: with `anchor = OutlierPair` or `SplinterPair` AND `refine = true`, the refine block indexes the LOCAL `subdata` matrix with GLOBAL frame indices (the masks `initialMask`/`notInitialMask`/`mainGroup`/`splinterGroup` hold `clusters[...][i]` global indices, but lines ~156-157 and ~237-238 do `subdata(mask, all)`). Crashes once a split cluster isn't a row-0 prefix (i.e. after the first split). Eigen `IndexedView.h` assertion in `DivineTest.TestCombinations`.

**Why:** index-space conflation; the NANI branch (divine.cpp:113-127) is the correct reference pattern. Non-refine paths and the NANI anchor are unaffected; the GUI default (NANI + refine) is safe.

**How to apply:** minimal fix is to index `data` instead of `subdata` in those 4 lines (masks are already global). Also review the `.size()` vs `.rows()` guards at divine.cpp:159,240-241. NOT a regression from the eQUAL/PRIME work — divine.cpp was untouched.

Full write-up (repro, exact lines, suggested patch, plus the broader backlog) is checked into the repo at **`REVIEW_NOTES.md`** (repo root). See [[mdance-algorithm-port-scope]].
