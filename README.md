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
- Color trajectories by cluster assignment
- Navigate to representative (medoid) frames
- Export cluster labels to CSV
- **Export representative structures** (PDB/DCD) and **per-cluster trajectory split**
- **Extended-similarity (iSIM) analysis** - ensemble similarity plus per-cluster
  compactness and outlier (least-representative) frames
- **Frame Tools** (Setup tab) - select frames without clustering: most-diverse
  subset, outlier frames, representative density sampling, or the single
  medoid/outlier; navigate to or export the selection
- **Cancellable runs with live progress** - long CLI runs (including the HELM
  pre-cluster step and the elbow K-scan) stream status and can be stopped mid-run;
  the parameter sweep reports per-configuration progress
- **Session save/load** - save a result (with its parameters and frame map) to a
  `.mdance` file and reopen it later
- **Interactive plot windows** with auto-resize, adjustable font size, and data/image export
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

- VMD (1.9.3 or later)
- CMake 3.15+
- C++ compiler with C++17 support
- Eigen3 library
- Tcl development headers (only for native library mode)

## Installation

### Standard (CLI mode)

```bash
cd vmd_plugin
./install.sh
```

This will:
1. Build the `mdance-cli` binary
2. Copy plugin files to `~/.vmd/plugins/`
3. Register the plugin in `~/.vmdrc`

### With native library (recommended)

```bash
cd vmd_plugin
./install.sh --with-library
```

This additionally builds and installs the Tcl extension (`mdance_tcl.so`/`.dylib`), which allows the plugin to pass coordinates directly to MDANCE in memory — no temp files, no subprocess overhead. The plugin automatically detects and prefers the library when available, falling back to the CLI binary.

### Custom install location

```bash
./install.sh --vmd-plugin-dir /path/to/vmd/plugins/noarch/tcl/mdance1.0
```

### Manual installation

1. Build the CLI:
   ```bash
   cmake -S .. -B ../build -DBUILD_CLI=ON
   cmake --build ../build --target mdance-cli
   ```

2. (Optional) Build the native library:
   ```bash
   cmake -S .. -B ../build -DBUILD_CLI=ON -DBUILD_SHARED=ON -DBUILD_TCL=ON
   cmake --build ../build --target mdance-cli mdance_tcl
   ```

3. Copy files to VMD plugin directory:
   ```bash
   mkdir -p ~/.vmd/plugins/noarch/tcl/mdance1.0
   cp mdance/*.tcl ~/.vmd/plugins/noarch/tcl/mdance1.0/
   cp ../build/cli/mdance-cli ~/.vmd/plugins/noarch/tcl/mdance1.0/
   # If library was built:
   cp ../build/tcl/mdance_tcl.* ~/.vmd/plugins/noarch/tcl/mdance1.0/
   ```

4. Add to `~/.vmdrc`:
   ```tcl
   lappend auto_path {~/.vmd/plugins/noarch/tcl}
   vmd_install_extension mdance mdance::gui "Analysis/MDANCE Clustering"
   ```

## Usage

### From VMD menu

**Extensions > Analysis > MDANCE Clustering**

### From VMD console

```tcl
package require mdance
mdance::gui
```

### Workflow

1. Load a molecule with trajectory in VMD
2. Open the MDANCE plugin
3. **Setup tab**: Set molecule ID and atom selection (e.g., `protein and name CA`).
   Optionally set a **Frame Range** (first/last/stride) to cluster a subset — `Last = -1`
   means the final frame; `Stride = 10` keeps every 10th frame. Click **Preview Selection**
   to see how many frames are selected.
4. Check the **MDANCE Backend** section — it shows whether the native library or CLI mode is active
5. Choose an algorithm tab (KMeans, DIVINE, or HELM), **or** use the **Sweep tab** to
   scan a grid of parameters at once
6. Configure parameters and click "Run"
7. **Results tab**: View scores, cluster sizes, and representative frames
8. Click "Color by Cluster" to visualize
9. Click "Go to Representative" to navigate to medoid frames
10. Use **Export Representatives...** to save each cluster's medoid as a PDB/DCD, or
    **Export Clusters...** to write one trajectory file per cluster. **Similarity** opens
    the iSIM compactness/outlier analysis.
11. Open any plot — each plot window includes a toolbar with:
    - **Font size** control to adjust text in the figure
    - **Export CSV** to save the underlying plot data
    - **Export PS** / **Export PNG** to save the figure as an image
12. Plot windows auto-resize when you resize the window

### Display Settings

The **Setup** tab includes a **Display Settings** section:

- **App font size** — adjusts the font size of all UI elements (labels, buttons, tabs)
- **Plot font size** — sets the default baseline font size for new plot windows (each plot window can also adjust its own font independently via the toolbar)

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

The plugin also searches for the binary and library in the plugin directory and common build paths. You can configure the path interactively from the Setup tab in the plugin GUI.

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
