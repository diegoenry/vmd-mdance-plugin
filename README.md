# MDANCE VMD Plugin

A VMD plugin for running MDANCE clustering algorithms on molecular dynamics trajectories and visualizing results interactively.

## Features

- **KMeans NANI** - Fast partitional clustering with multiple initialization strategies
- **DIVINE** - Divisive hierarchical clustering (top-down)
- **HELM** - Hierarchical agglomerative clustering (bottom-up)
- **eQUAL** - Extended-quality radial/threshold clustering; the cluster count
  emerges automatically from a radial threshold (no preset *k*)
- **PRIME** - Protein Retrieval via Integrative Molecular Ensembles: predicts the
  representative / "native"-like frame of a clustered ensemble (4 PRIME scorers +
  3 medoid baselines) from extended (n-ary) similarity
- **Parameter Sweep** - run a grid of {algorithm × K × metric × init}, tabulate
  Calinski-Harabasz / Davies-Bouldin scores, highlight the best run, view a score
  heatmap, and load any configuration back into the Results tab
- **Frame range / stride** - cluster a subset of the trajectory (skip equilibration,
  decimate dense trajectories); all coloring, navigation, plots and exports map back
  to true VMD frame numbers
- Cluster quality scores (Calinski-Harabasz, Davies-Bouldin)
- **Sortable cluster table** - cluster, size, % of frames, MSD and representative
  frame, sortable by any column
- Color trajectories by cluster assignment
- Navigate to representative (medoid) frames
- **Multi-frame overlay** - show the top *N* frames of a cluster (ranked by MSD
  from its representative) simultaneously for direct comparison, or overlay
  arbitrary frame ranges such as `0-100,500,900-1000`; export the top-*N* frame
  indices and labels
- **Elbow K-scan** on each algorithm's panel (KMeans, DIVINE and HELM), keeping every
  K's partition so hovering a point shows that K's population split
- Export cluster labels to CSV
- **Clear Results** - purge a result and everything derived from it (table, open
  plot tabs, sweep table, PRIME / Frame Tools selections, overlay)
- **Export representative structures** (PDB/DCD) and **per-cluster trajectory split**
- **Extended-similarity (iSIM) analysis** - ensemble similarity plus per-cluster
  compactness and outlier (least-representative) frames
- **Frame Tools** (left column) - select frames without clustering: most-diverse
  subset, outlier frames, representative density sampling, or the single
  medoid/outlier; navigate to or export the selection
- **Cancellable runs with live progress** - coordinate extraction reports
  per-frame progress on a determinate progress bar and can be aborted; long CLI
  runs (including the HELM pre-cluster step and the elbow K-scan) stream status
  and can be stopped mid-run; the parameter sweep reports per-configuration
  progress
- **Session save/load** - save a result (with its parameters and frame map) to a
  `.mdance` file and reopen it later
- **Plots as tabs** in the Figures view, with auto-resize and one shared bar for
  font size and CSV / PS / PNG export; each launcher button carries a thumbnail of
  the plot it opens
- **One toolbar** carrying Run (which names the selected algorithm), Cancel, Clear,
  Help and Settings, and a toggle that folds the whole input column away
- **Foldable parameter sections** — the algorithms ship usable defaults, so the
  details stay out of the way until you open them
- **Validated selection** — the molecule chooser lists what is actually loaded, and
  the atom selection reports its atom count as you type
- **Native library mode** - pass coordinates directly in memory (no temp files)

> **Scope note.** MDANCE's *SHINE* (pathway/ensemble) method clusters *whole
> trajectories* against each other and needs a multi-trajectory segmentation that
> a single VMD molecule does not provide, so it is intentionally not exposed here.
> *PRISM/CADENCE* has no public reference implementation; MDANCE's density/quality
> clustering on a coordinate matrix is **eQUAL**, which is included above.

## Guided walkthrough

`demo/` contains a live, narrated tour of everything above. It opens this plugin
in a real VMD session and drives it — setting parameters, running the backend,
opening plots — while a synthesized voice-over explains what is happening and
captions track along the bottom of the screen. Nothing is pre-recorded; every
clustering it shows is computed live.

```bash
./demo/bootstrap.sh      # once: Python env + local text-to-speech + narration
./demo/run_demo.sh       # launch
```

Twelve chapters, ~40 minutes in total, each playable on its own — one per
clustering method, plus Setup, PRIME, Sweep, the plot gallery, Frame Tools and
exports. See [demo/README.md](demo/README.md).

## Prerequisites

- **VMD** — verified against 1.9.4 and 2.0.0a7
- **CMake** 3.15+, a **C++17** compiler, and **git**
- **Python 3** with numpy — optional, enables one extra backend validation test

Eigen and GoogleTest are fetched automatically by the backend build if they are not
already installed. Tcl development headers are needed only for the optional
native-library mode.

## Installation

**See [INSTALL.md](INSTALL.md) for the full step-by-step guide.** In short:

```bash
# 1. build the backend (separate repository -- the plugin will not run without it)
git clone -b feat-vmd-backend https://github.com/diegoenry/CPP-MDANCE.git
cd CPP-MDANCE
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
ctest --test-dir build --output-on-failure          # expect 2/2 (or 1/1 without numpy)
export MDANCE_CLI="$PWD/build/cli/mdance-cli"

# 2. install the plugin
cd .. && git clone -b feat-reviewer-feedback https://github.com/diegoenry/vmd-mdance-plugin.git
cd vmd-mdance-plugin
./tests/run_tests.sh                                 # expect 334 checks passing
./install.sh
```

Then in VMD: **Extensions → Analysis → MDANCE Clustering**.

`install.sh` prints `Skipping build: no CMakeLists.txt` — that is correct here. The C++
backend lives in `CPP-MDANCE`, which you built in step 1; this repository is the plugin
only. See [STANDALONE.md](STANDALONE.md).

Custom install location:

```bash
./install.sh --vmd-plugin-dir /path/to/vmd/plugins/noarch/tcl/mdance1.0
```

Native library mode (`--with-library`, or `-DBUILD_TCL=ON` in the backend) passes
coordinates in memory with no temp files, but is **experimental and unverified inside a
running VMD process** — see INSTALL.md step 5. CLI mode is the tested path.

## Usage

### From VMD menu

**Extensions > Analysis > MDANCE Clustering**

### From VMD console

```tcl
package require mdance
mdance::gui
```

### The window

```
 ◧ Hide setup │ ▶ Run KMeans │ ■ Cancel │ ↻ Clear        ℹ Help   ⚙ Settings
├──────────────────────┬────────────────────────────────────────────────────┤
│  Molecule            │  Results │ Figures │ Sweep │ PRIME │ Help          │
│  ▶ Frame Range       │                                                    │
│  Preview  Frame Tools│    the result of the run, and the plots it feeds    │
│  Algorithm  ( ) ...  │                                                    │
│  ▶ KMeans Parameters │                                                    │
│  Elbow Plot...       │                                                    │
│  ▶ MDANCE Backend    │                                                    │
├──────────────────────┴────────────────────────────────────────────────────┤
│ Done: 6 clusters found                                                    │
```

Everything you set is in the left column, everything a run produces is on the right,
one toolbar across the top and one status band along the bottom.

- **Run** sits in the toolbar and names the algorithm it will run, following the
  **Algorithm** selection in the left column. **Cancel** is beside it and becomes
  live while a run is going.
- **Hide setup** folds the whole left column away, and brings it back with
  everything still typed into it.
- Sections marked **▶** are folded. Click the header to open one. The algorithm
  parameters ship folded because every algorithm has usable defaults — the common
  case is pick one and Run.
- The **Results**, **PRIME** and **Help** views scroll, so a small window hides
  nothing.

### Workflow

1. Load a molecule with a trajectory in VMD
2. Open the MDANCE plugin
3. **Molecule** (left column): pick the molecule from the chooser — it lists what is
   actually loaded, with its frame count — and type an atom selection (e.g.
   `protein and name CA`). The line under the field reports how many atoms match as
   you type, so a typo or an empty selection is visible before you run rather than
   after.
4. Optionally open **Frame Range** and set first/last/stride to cluster a subset —
   `Last = -1` means the final frame; `Stride = 10` keeps every 10th frame.
   **Preview Selection** reports how many frames are selected.
5. Open **MDANCE Backend** to check whether native library or CLI mode is active
6. Pick an algorithm in the **Algorithm** list (KMeans, DIVINE, HELM, eQUAL). The
   parameter section below it becomes that algorithm's; what you typed into the
   others is kept. For a batch scan use the **Sweep** view on the right instead.
7. Open the parameter section if you want to change anything, then press **Run** in
   the toolbar
8. **Results** (right): scores and the cluster table (cluster, size, % of frames, MSD,
   representative frame) — click any column heading to sort by it
9. Click "Color by Cluster" to visualize. Note this colours *frames*, not atoms, so a
   single rendered frame comes out in that frame's cluster colour.
10. Click "Go to Representative" to navigate to medoid frames, or use **Frame
    Overlay** to show the selected cluster's top *N* frames at once
11. Use **Export Representatives...** to save each cluster's medoid as a PDB/DCD,
    **Export Clusters...** to write one trajectory file per cluster, or **Export Top
    Frames...** for the top-*N* frame indices of every cluster. **Similarity** opens
    the iSIM compactness/outlier analysis.
12. **Figures** (right): each button carries a thumbnail of the plot it opens, and
    every plot opens as a tab in this view rather than as a separate window. One
    shared bar above the tabs carries:
    - **Font size** for the selected plot
    - **⇩ CSV** for the underlying plot data
    - **⇩ PS** / **⇩ PNG** for the figure
    - **✖ Close** / **✖ All** for the open plots
13. Plots redraw to fit whenever the pane is resized
14. **Help** (right) carries the Quick Start and the credits

### Settings

**Settings...** in the toolbar opens a small dialog. What works in it applies live —
there is nothing to confirm.

- **App font size** — *currently has no effect, and is left here as a known gap.*
  VMD's ttk theme pins every widget class to a literal `TkDefaultFont 10`, so
  reconfiguring the named font never reaches a widget; making this work needs the
  plugin to own a named font across every widget class, which it does so far only
  for the tables
- **Plot font size** — the baseline font size new plots start at (the shared bar on
  the Figures view sets the size of the plot you are looking at)
- **Titles inside plots** — off by default, since the tab already names the plot.
  Informational captions (a skipped-K caveat, a units qualifier, a computed mean) are
  always drawn regardless, and exported images re-enable the title because an exported
  figure has no tab to identify it by.

The dialog's **Advanced** group holds one switch:

- **Unlock metric selection** — clustering runs on MSD, the only metric with a
  physical meaning for Cartesian MD frames, so the metric selectors are hidden by
  default. The other ten indices are binary/extended-similarity measures intended
  for fingerprint-style data; unlock only if your input suits them. (PRIME is
  unaffected: its metric is an n-ary similarity index, not a distance.)

### Environment variables

- `MDANCE_CLI` - Path to the `mdance-cli` binary (overrides automatic detection)
- `MDANCE_LIB` - Path to the `mdance_tcl` shared library (overrides automatic detection)

Set these in your shell profile (e.g., `~/.bashrc` or `~/.zshrc`):
```bash
export MDANCE_CLI="/path/to/mdance-cli"
export MDANCE_LIB="/path/to/mdance_tcl.so"
```

Or in your `~/.vmdrc`:
```tcl
set env(MDANCE_CLI) "/path/to/mdance-cli"
set env(MDANCE_LIB) "/path/to/mdance_tcl.so"
```

The plugin also searches for the binary and library in the plugin directory and common build paths. You can configure the path interactively from the **MDANCE Backend** group in the plugin's left column.

## Architecture

The plugin supports two execution modes:

### Native library mode (preferred)

```
VMD (Tcl/Tk) --> extract coordinates --> flat Tcl list
                                          |
                                     mdance_tcl.so (Tcl extension)
                                          |
                                     Tcl dict results
                                          |
VMD (Tcl/Tk) <-- visualize <--------------+
```

Coordinates stay in memory. No file I/O, no process spawning.

### CLI mode (fallback)

```
VMD (Tcl/Tk) --> extract coordinates --> CSV file
                                          |
                                     mdance-cli (C++)
                                          |
                                     JSON results
                                          |
VMD (Tcl/Tk) <-- parse & visualize <------+
```

This design ensures compatibility with any VMD version and allows the CLI tool to be used independently in scripts and pipelines.

## C API

The shared library also exposes a C API (`mdance_capi.h`) that can be used from any language with C FFI support (Python ctypes, Julia ccall, etc.):

```c
#include "mdance_capi.h"

mdance_result_t* r = mdance_kmeans(coords, nframes, ncols, natoms, 10, "MSD", "CompSim", 10);
if (mdance_result_error(r)) {
    fprintf(stderr, "Error: %s\n", mdance_result_error(r));
} else {
    const int* labels = mdance_result_labels(r);
    // use labels...
}
mdance_result_free(r);
```

## Credits

This repository is the **VMD plugin layer** only — the Tcl/Tk interface, the
visualisation and export code, the test suite, and the narrated walkthrough. The
clustering itself is not ours.

| Component | Project | License |
|---|---|---|
| The algorithms — KMeans NANI, DIVINE, HELM, eQUAL, PRIME, and the extended (n-ary) similarity they are built on | [MDANCE](https://github.com/mqcomplab/MDANCE) by the [Miranda-Quintana group](https://github.com/mqcomplab) ([docs](https://mdance.readthedocs.io)) | MIT |
| The C++ backend this plugin drives (`mdance-cli`, the C API and the Tcl extension) | [CPP-MDANCE](https://github.com/mqcomplab/CPP-MDANCE) — © 2025 Andrey Nikitin | MIT |
| The host application | [VMD](https://www.ks.uiuc.edu/Research/vmd/), Theoretical and Computational Biophysics Group, University of Illinois at Urbana-Champaign | see VMD's own license |
| This plugin and its walkthrough | © 2026 Diego Gomes | MIT |

If you use MDANCE or VMD in published work, please follow each project's own
guidance on how to cite it.
