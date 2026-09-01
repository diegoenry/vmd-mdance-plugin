# MDANCE walkthrough

A live, narrated tour of the MDANCE VMD plugin. It opens the real plugin GUI in
a real VMD session and drives it — setting parameters, pressing buttons, running
the backend, opening plots — while a synthesized voice-over explains what is
happening and a caption bar tracks along the bottom of the screen.

Nothing here is a recording. Every clustering the walkthrough shows is computed
live, on the trajectory you point it at.

```
┌──────────────────────────────┐  ┌──────────────────────┐
│                              │  │  MDANCE Clustering   │
│   VMD  ── the molecule,      │  │  (the real plugin,   │
│          coloured by cluster │  │   driven live)       │
│                              │  ├──────────────────────┤
│   plot windows open here     │  │  MDANCE Walkthrough  │
│                              │  │  (chapter list,      │
└──────────────────────────────┘  │   transport, log)    │
┌─────────────────────────────────────────────────────┐  │
│  CHAPTER 3 OF 12                     beat 7 / 14    │  │
│  The timeline makes the structure obvious           │  │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  │
└─────────────────────────────────────────────────────┘  ┘
```

---

## Quick start

```bash
./demo/bootstrap.sh      # once: Python env + Kokoro TTS + synthesize narration
./demo/run_demo.sh       # launch
```

Then press **Play all**, or pick a single chapter and press **Play chapter**.
Every chapter stands on its own — "show me eQUAL" does not mean "sit through
KMeans first".

`bootstrap.sh` takes a few minutes the first time: it installs PyTorch and
downloads the Kokoro-82M model (~330 MB, cached in `~/.cache/huggingface`) and
then synthesizes about 38 minutes of speech. Everything runs locally on CPU.

**Without narration** the walkthrough still works — it paces itself from
reading-rate estimates and shows captions only. So `./demo/run_demo.sh` on its
own is a valid way to try it before committing to the TTS install.

---

## The chapters

| # | Chapter | What it covers |
|---|---|---|
| 0 | Welcome to MDANCE | The system, the plugin, the eight tabs, the two backend modes |
| 1 | Setting up the analysis | Molecule, atom selection, **alignment**, frame range/stride, display settings |
| 2 | KMeans NANI | k, metric, initialisation strategies, results, colouring, representatives |
| 3 | DIVINE | Divisive top-down splitting: split criterion, anchors, refinement |
| 4 | HELM | Agglomerative bottom-up merging, initial labels, merge schemes, the dendrogram |
| 5 | eQUAL | Threshold-driven clustering with no k, and the noise label |
| 6 | PRIME | Predicting the native-like structure from a clustered ensemble |
| 7 | Parameter sweep | Running the grid, reading the score table, the heatmap |
| 8 | Reading the results | The twelve plot windows and what each one answers |
| 9 | Frame tools & iSIM | Selecting frames without clustering; extended similarity |
| 10 | Getting the results out | Label/structure/trajectory exports and saved sessions |
| 11 | Choosing a method | Which algorithm for which question |

157 beats, 38 minutes of narration in total — but the chapters are the unit, not
the whole thing. Most are 3–5 minutes.

---

## Controls

| Control | Effect |
|---|---|
| **Play all** | The whole walkthrough, start to finish |
| **Play chapter** | Just the selected chapter (double-clicking a row does the same) |
| **From here** | The selected chapter and everything after it |
| **Pause / Resume** | Stops the narration; resuming restarts the current beat from its beginning |
| **< Beat / Beat >** | Step by beat. Works while paused — this is how you drive it by hand during a talk |
| **Chapter >** | Skip to the next chapter |
| **Mute narration** | Captions and timing continue; the voice stops |

The log pane at the bottom shows what each beat actually did, including the real
numbers the backend returned.

---

## Command-line options

```bash
./demo/run_demo.sh                 # launch the walkthrough
./demo/run_demo.sh --step 10       # load every 10th frame (faster to load)
./demo/run_demo.sh --check         # headless: validate scenes and widget paths
./demo/run_demo.sh --rehearse      # headless: play every beat fast, report errors
./demo/run_demo.sh --rehearse --only equal    # rehearse one chapter
./demo/run_demo.sh --narrate       # rebuild the narration audio, then launch
```

`--check` proves every widget a scene names exists. `--rehearse` proves every
action a scene takes actually works — it runs the real backend, opens the real
plots and writes the real exports, at about 0.35 s per beat.

### Environment

| Variable | Default | Meaning |
|---|---|---|
| `VMD` | first VMD found | VMD binary to use |
| `DEMO_PSF` / `DEMO_DCD` | `~/work/VMD_tests/RMSX_test/solute.*` | The trajectory |
| `DEMO_STEP` | `1` | Load every Nth frame |
| `DEMO_OUT` | `demo/out` | Where the walkthrough writes exports |
| `MDANCE_CLI` | CPP-MDANCE build tree | The backend binary |
| `DEMO_LIBRARY` | unset | Set to 1 to use in-process library mode (see below) |

**Why CLI mode by default.** A CLI run parks in a live event loop, so the status
bar streams progress and the Cancel button works — which the walkthrough shows
off. A library-mode run blocks VMD outright and cannot be cancelled, and library
mode has a known abort (not an error — an abort, which takes VMD with it) on
degenerate HELM input. Not a risk worth taking in front of an audience.

---

## Using your own trajectory

```bash
DEMO_PSF=/path/to/system.psf DEMO_DCD=/path/to/traj.dcd ./demo/run_demo.sh
```

The chapters are written around a protein–peptide complex with a bound calcium
ion, so some narration will not match another system exactly — but every action
is generic, and nothing is hard-coded to a frame count. Chapter 1 aligns
whatever it is given and the rest follow from that.

---

## How it fits together

```
tcl/scenes/*.tcl   the walkthrough itself: each beat pairs a spoken line with
                   the Tcl that drives the plugin while it plays
       │
       ├──> narration/export_beats.tcl   (plain tclsh; -do bodies never run)
       │        └──> narration/beats.json
       │                 └──> narration/build_narration.py   (Kokoro-82M)
       │                          ├──> narration/audio/<beat>.wav
       │                          └──> narration/manifest.tcl   (MEASURED durations)
       │
       └──> tcl/demo_engine.tcl          plays each beat against those durations
```

The scene file is the single source of truth for both the voice and the actions,
which is the point: the narration cannot describe a step the demo does not
perform, because they are the same declaration.

Timing comes from the *measured* length of each synthesized line, never from a
word-count estimate — so rewording a sentence re-times the demo automatically.

| File | Role |
|---|---|
| `tcl/demo_dsl.tcl` | `scene` / `beat` / `setup` / `teardown` declarations |
| `tcl/demo_engine.tcl` | The sequencer: cues, pacing, pause/step, re-entrancy guards |
| `tcl/demo_caption.tcl` | Caption bar, chapter title cards, widget spotlight |
| `tcl/demo_control.tcl` | The walkthrough's control panel |
| `tcl/demo_actions.tcl` | The verbs a scene uses (`param`, `click`, `plot`, …) |
| `tcl/demo_dialogs.tcl` | Non-blocking stand-ins for Tk's modal dialogs |
| `tcl/demo_vmd.tcl` | Loading, alignment, representations, camera, window layout |
| `tcl/demo_config.tcl` | Path and backend resolution |
| `tcl/demo_main.tcl` | Entry point + headless self-check |
| `tcl/demo_rehearse.tcl` | Headless full-speed rehearsal harness |

Writing or editing a chapter: see **[SCENE_AUTHORING.md](SCENE_AUTHORING.md)**.

---

## Notes on the awkward bits

These are the things that made this harder than it looks, recorded so the next
person does not rediscover them.

- **Modal dialogs would freeze the walkthrough.** Tk's `tk_messageBox` and the
  file dialogs park in their own event loop until a human clicks. While the demo
  is playing, `demo_dialogs.tcl` replaces all four with non-blocking stand-ins
  that show the real message as a floating toast and return a sensible answer.
  They must be installed *after* the plugin is sourced, because
  `package require Tk` reinstalls the real `tk_messageBox` over any earlier stub.

- **The plugin runs a nested event loop.** A CLI clustering run sits in
  `vwait ::mdance::async_done`, so the engine's own timers keep firing *inside*
  it. Every scheduling callback in `demo_engine.tcl` therefore defers while an
  action is in flight or the plugin is busy; otherwise the end-of-beat timer
  would start the next run on top of the previous one.

- **A background error is completely invisible under VMD.** An error inside an
  `after` script reports through `bgerror`, whose output goes nowhere once the
  Tk console exists — the demo would simply stop, with a live GUI and no
  diagnosis. `demo_engine.tcl` installs its own `bgerror` before arming a single
  timer.

- **`puts` disappears too**, for the same reason, which is why the self-check and
  the rehearsal write to a file channel named by an environment variable rather
  than to stdout.

- **`info script` is empty under `vmd -e`**, so the demo locates itself from
  `DEMO_ROOT`, which `run_demo.sh` sets.

- **`-eofexit` needs stdin actually to reach EOF.** Run from a terminal, stdin is
  already at EOF and headless VMD exits when the script finishes. Run detached —
  a background job, CI, a trailing `&` — stdin stays open and VMD sits at its
  console prompt forever with the work long since done. `run_demo.sh` runs the
  headless modes through `run_headless`, which redirects `</dev/null` and wraps
  the call in a `timeout` (`DEMO_VMD_TIMEOUT`, default 1800 s) as a backstop.

- **Alignment is not optional.** MDANCE's MSD compares raw coordinates and has
  no superposition step of its own. On the demo trajectory, unaligned CA RMSD
  reaches ~8 Å of pure tumbling against ~1.4 Å of real conformational change —
  cluster the raw coordinates and you cluster the tumbling. Chapter 1 is built
  around demonstrating exactly this.
