# HANDOFF — VMD-MDANCE plugin

Single entry point for picking this work back up with no prior conversation
context. Written 2026-08-31.

---

## 1. What this is

`/Users/deb0054/work/vmd-plugin-projects/VMD-MDANCE` — the **standalone,
plugin-only Tcl/Tk copy** of the MDANCE VMD plugin. ~6.4k lines of Tcl in
`mdance/`, plus a test suite in `tests/`.

It drives the MDANCE clustering backend two ways:

- **Library mode** (preferred) — a loaded Tcl C extension, `load … Mdance`
- **CLI mode** (fallback) — `exec`ing `mdance-cli`, CSV in / JSON out

The backend itself lives in a different checkout: `/Users/deb0054/github/CPP-MDANCE`.

---

## 2. Current state

- **Git repo**, branch `main`, **no remote**. 16 commits.
- Commit **`5251368`** is the untouched pre-hardening baseline.
  `git diff 5251368 HEAD` = the whole body of work (25 files, +3163/-553).
- Working tree **clean**.
- **`./tests/run_tests.sh` passes 213 checks** (104 unit under plain `tclsh`
  with VMD/Tk stubbed, 109 runtime scenarios inside headless VMD against
  `tests/fake_mdance_cli`).

Count tests correctly — do not sum every `N run` line, that double-counts the
per-suite summaries:

```bash
./tests/run_tests.sh | grep -oE '^== [a-z:_]+: [0-9]+ run' | awk '{s+=$3} END {print s}'
```

Read the commit messages for the reasoning behind each fix; they are written to
be the record.

---

## 3. What was done

Three passes, all findings closed. `notes/HARDENING_BACKLOG.md` is the full
record — read that before re-reviewing anything.

**Pass 1** — a 9-dimension review produced 55 deduped findings. Fixed all five
high-severity ones and their neighbourhood: `frame_list` silently clustering the
wrong frames on a typo (Tcl `expr` falls back to *string* comparison on a
non-numeric operand); the elbow plot drawing failed K values as `(K, 0, 0)`,
which rendered as the visually optimal K; the HELM dendrogram never rendering for
`nClusters >= 2` (its Z-matrix is a *forest*, only one tree was laid out);
frame-dependent atom selections producing a ragged matrix; and sweeps having no
interlock with single runs.

**Pass 2** — the remaining ~30 backlog items: session validation, backend-output
validation, HELM label-file parsing, cancel escalation, window-close handling,
a private `0700` temp directory, overwrite prompts, and every flagged test gap.

**Pass 3** — an adversarial review *of the hardening diff* found seven defects in
the fixes themselves. Two were serious and mine:

- the cancel escalation timer **killed the next run** (it keyed on the Tcl
  channel name, and Tcl recycles those);
- the sweep heatmap's CH/DB toggle **relabelled cached values**, showing one
  score's numbers under the other's legend.

**The lesson worth keeping: review the hardening diff as adversarially as the
code it hardens.** Two of those regressions were worse than the bugs being fixed.

**Docs** — `README.md`, `QUICK_START.md` and `QUICK_START.html` are all current.

---

## 4. Conventions new code must follow

Each exists because of a specific bug. Breaking one reintroduces it.

| Convention | Why |
|---|---|
| `::mdance::utils::is_finite` is the "safe to plot / safe to do arithmetic on" test | `string is double` **accepts** `NaN`/`Infinity`, which then make `expr` raise "domain error" and `format %f` raise |
| Every coordinate-extraction loop goes through `::mdance::_frame_coords` | It refuses a frame-dependent selection instead of silently building a ragged matrix |
| Temp files come from `::mdance::utils::mktmp` | Puts them in the private 0700 `workdir`. Never write directly to `tmpdir` |
| `::mdance::abs_frame` may return `-1` | Means "the frame map does not reach this sample". Callers must handle it, not assume a valid frame |
| Validate with `::mdance::gui::_chknum` before anything reaches the CLI | A validated number can never begin with a redirection token like `>f` |
| Never `expr`-compare user input before validating it | `expr` falls back to STRING comparison on a non-numeric operand — this is how `"1o"` silently clustered the wrong frames |
| Backend output goes through `::mdance::_require_valid_result` | `parse_json` is a regex scraper; truncated output yields a *partial* dict, not an error |

**The load-bearing invariant** across the whole plugin is the sample-index →
absolute-VMD-frame mapping through `::mdance::abs_frame`. Frame range/stride,
colouring, navigation, export and every plot depend on it.

---

## 5. How to verify a change

```bash
cd /Users/deb0054/work/vmd-plugin-projects/VMD-MDANCE
./tests/run_tests.sh            # everything (needs VMD)
./tests/run_tests.sh unit       # fast, no VMD
./tests/run_tests.sh runtime    # headless VMD scenarios
```

`tests/README.md` documents the layout and the `fake_mdance_cli` env hooks
(`MDANCE_FAKE_FAIL`, `MDANCE_FAKE_FAIL_K`, `MDANCE_FAKE_SLEEP`,
`MDANCE_FAKE_IGNORE_TERM`, `MDANCE_FAKE_TRUNCATE`, `MDANCE_FAKE_EXTRA_LABELS`).

**When you add a regression test, prove it is load-bearing**: revert the fix,
confirm the test goes red, restore. One test in this repo passed anyway when
checked that way and had to be rewritten (`84c90dc`).

Tcl semantics questions: settle them by running `/usr/bin/tclsh8.5` or `tclsh8.6`
(what VMD embeds), not from memory. VMD headless:
`vmd -dispdev text -eofexit -e script.tcl`.

---

## 6. Open items — none in this repo

Everything below is outside this repo or is a standing limitation.

1. **CPP-MDANCE PR is still unpushed.** Verified 2026-08-31: branch
   `feat-vmd-plugin` exists locally at commit `15875f3` in
   `/Users/deb0054/github/CPP-MDANCE`, and `git ls-remote --heads origin` shows
   no such branch on the remote. It is based on `origin/feat-divine`
   — PR target is `feat-divine`, **not** `main`. Resume from
   `CPP-MDANCE/TODO_vmd_plugin.md`. Re-confirm the base before pushing: `main`
   has since moved divine to a dev branch.

2. **DIVINE `refine=true` + `OutlierPair`/`SplinterPair` crashes** — backend bug,
   out-of-bounds index in `divine.cpp`. Diagnosis and a proposed fix are in
   `notes/REVIEW_NOTES.md` §1. The GUI default (`NANI` + refine) is safe, and
   `QUICK_START` documents the workaround.

3. **`alignTraj` is a stub** for its `uni`/`kron` branches, so eQUAL offers only
   `align=none`. Rejected at the parse layer, so nothing silently no-ops.

4. **The Sphinx tree under `docs/` in the parent repo has not been refreshed.**
   This repo's docs are current.

**Standing limitation:** plots are tested for "renders without error" and, where
the arithmetic is checkable, for exact values via their exported CSV — but they
have **never been eyeballed on a real display**. The refreshed
`QUICK_START.html` was likewise validated only statically (well-formed, no broken
anchors, every CSS class defined); the Chrome extension was not connected.

---

## 7. Map of the repo

```
mdance/
  mdance.tcl         core: backend detection, extraction, job control, frame mapping,
                     sessions, exports          (1528 lines)
  mdance_gui.tcl     Tk GUI, 8 tabs             (1558)
  mdance_plots.tcl   12 plot windows + export   (2452)
  mdance_sweep.tcl   parameter sweep + heatmap  (589)
  mdance_utils.tcl   parse_json, discovery, temp files, is_finite  (282)
notes/
  HARDENING_BACKLOG.md   what the review found and fixed — READ FIRST
  REVIEW_NOTES.md        backend bug write-ups (DIVINE crash) + verification status
  *.md                   background notes on port scope, C-API, headless verification
tests/
  README.md          layout + fake-backend hooks
  run_tests.sh       driver
  unit/              5 files, plain tclsh with VMD/Tk stubbed
  runtime/           10 scenarios inside headless VMD
QUICK_START.md/.html   user guide (current)
README.md              feature list + install (current)
STANDALONE.md          what this standalone copy is
install.sh             builds mdance-cli, installs into ~/.vmd/plugins
```
