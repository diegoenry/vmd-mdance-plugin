# Writing a walkthrough scene

A scene is one chapter. It is a **declaration**, not a script: the file is
sourced by a plain `tclsh` during the narration build (where the `-do` bodies are
never evaluated) and again inside VMD at run time (where they are). Keep the
top level of the file free of anything that needs VMD or Tk.

## The shape

```tcl
::demo::scene <id> "<Chapter title>" "<one-line subtitle>"

::demo::setup {
    # Puts the molecule and the plugin into the state beat 1 assumes.
    # MUST be enough for the chapter to be played on its own, from cold.
}

::demo::beat <local_id> \
    -caption "Short label on screen" \
    -say     "The sentence the narrator speaks." \
    -tab     kmeans \
    -spotlight .mdance.nb.kmeans.params.w0 \
    -do      { ::demo::param km_nclusters 4 } \
    -at      0.5f \
    -hold    1.0

::demo::teardown { ... }   ;# optional
```

### Beat options

| Option | Meaning |
|---|---|
| `-say` | **Required.** The only text that gets synthesized. |
| `-caption` | On-screen caption. 3–9 words. No trailing period. Defaults to `-say`, which is always too long — always write one. |
| `-do` | Tcl run while the narration plays. Runs at global scope. |
| `-at` | When `-do` fires. `1.5` = seconds. `0.5f` = halfway through the narration. **Prefer the fractional form** whenever the sentence explains something before the action shows it — it survives rewording, a different voice, and a different speaking rate. |
| `-hold` | Extra seconds after the narration ends. Give a plot 2–3s; give a plain statement 0.4s. |
| `-tab` | Notebook tab to select first: `setup kmeans divine helm equal sweep results prime`. |
| `-spotlight` | Widget path (or list) to frame with a pulsing highlight. |

Scene and beat ids must be `[a-z0-9_]+`. The beat's full id is `<scene>.<beat>`,
and that is also its audio filename — so renaming a beat orphans its WAV (which
is fine; the next build re-synthesizes it).

## Verbs available in `-do`

```tcl
::demo::param  km_nclusters 4              ;# set a plugin GUI variable (errors if it does not exist)
::demo::params km_metric MSD km_kinit CompSim
::demo::click  .mdance.nb.kmeans.run.btn   ;# invoke a button; logs and returns 0 if missing/disabled
::demo::tab    results
::demo::tab_tour {kmeans divine helm} 1500 setup   ;# non-blocking tab flip-through
::demo::select_cluster 2                   ;# select a row in the Results cluster list
::demo::rep_tour 0 3 1600                  ;# walk cluster 0..3, jumping to each representative
::demo::plot   timeline                    ;# open a result plot and park it in a free slot
::demo::plot_raw elbow { ... }             ;# open a plot whose proc is not results-shaped
::demo::close_plots
::demo::out    "labels.csv"                ;# a path under demo/out/
::demo::save_as [::demo::out labels.csv] .mdance.nb.results.actions.export
::demo::note   "text"                      ;# write a line to the control panel log
::demo::spin 1 / ::demo::frame_to 500 / ::demo::sweep_to 0 999 8.0
::demo::expect_results kmeans 4            ;# run a clustering if the chapter was started cold

::demo::vmd::align "protein and name CA"
::demo::vmd::style_default / show_peptide 1 / color_by_structure / smooth 3
::demo::vmd::reset_view / zoom 1.2 / goto_frame N / spin_start / spin_stop
::demo::vmd::rmsd_range "protein and name CA" 25   ;# -> {min max mean}
::demo::vmd::molid
```

Plot names for `::demo::plot`: `population timeline msd dendrogram transitions
residence distances reprmsd msdpop silhouette similarity elbow sweep`.

## Hard rules

1. **Never block the event loop.** No `after <ms>` with no script, no `update` in
   a loop, no `vwait`. Use `tab_tour` / `rep_tour` / `sweep_frames`, which chain
   `after` callbacks. Blocking freezes the caption, the narration cue and the
   plugin all at once.

   The one legitimate exception is a `-do` that invokes a run button. That
   genuinely blocks until the backend returns — the engine expects it and defers
   the end of the beat until it comes back.

2. **Every file dialog must be armed first.** Use `::demo::save_as`, or call
   `::demo::dialogs::arm <path>` immediately before the click. An unarmed dialog
   returns "" and the export silently does nothing.

3. **A chapter must stand alone.** Its `setup` re-establishes everything it needs
   — including running a clustering via `::demo::expect_results` if the chapter
   analyses a result it did not produce.

4. **Do not speak a computed number.** Frame counts, atom counts, `k`, and
   thresholds are ours to choose and are safe. Scores, cluster sizes and
   representative frame indices come from the backend — describe their *shape*
   ("the largest cluster holds about a third of the trajectory"), and let the
   GUI show the digits. Use `::demo::note` to put the real values in the log.

5. **Leave the stage tidy.** Close plots you opened (`::demo::close_plots` in the
   last beat or in `teardown`) and undo cluster colouring
   (`::demo::vmd::color_by_structure`) so the next chapter starts clean.

## Narration style

- Second person, present tense, conversational but exact.
- One idea per beat. 12–40 spoken words is the sweet spot; over ~55 the caption
  and the action drift apart.
- Say what the thing *is for* before saying what it *is called*.
- No hype, no "simply", no "as you can see".
- Spell out anything the text-to-speech will mangle in
  `narration/build_narration.py`'s `PRONOUNCE` table rather than contorting the
  prose.
- Prefer honest observations over flattering ones. If a score says the data has
  no clean elbow, say so — that is a real result about the trajectory, and a
  walkthrough that pretends otherwise teaches the wrong lesson.

## Checking your work

```bash
./demo/run_demo.sh --check                 # widgets, tabs, parse, durations
./demo/run_demo.sh --rehearse              # actually plays every beat, fast
./demo/run_demo.sh --rehearse --only equal # one chapter
```

`--check` catches a widget path that does not exist. `--rehearse` catches an
action that does not work. Both run headless; neither needs audio.
