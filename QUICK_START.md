# MDANCE Quick Start Guide

This guide covers the four clustering algorithms in the MDANCE VMD plugin and the
`mdance-cli` command-line tool — **KMeans NANI**, **DIVINE**, **HELM** and **eQUAL** —
together with the analysis tools built around them: **PRIME** representative-frame
prediction, **iSIM** extended-similarity analysis, **Frame Tools** selection, and the
**Parameter Sweep**.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Frame Range and Stride](#frame-range-and-stride)
3. [Input Data Format](#input-data-format)
4. [KMeans NANI](#kmeans-nani)
5. [DIVINE](#divine)
6. [HELM](#helm)
7. [eQUAL](#equal)
8. [Distance Metrics](#distance-metrics)
9. [Quality Scores](#quality-scores)
10. [Parameter Sweep](#parameter-sweep)
11. [PRIME Representative Frame Prediction](#prime-representative-frame-prediction)
12. [iSIM Similarity Analysis](#isim-similarity-analysis)
13. [Frame Tools](#frame-tools)
14. [Visualizations](#visualizations)
15. [Exports and Sessions](#exports-and-sessions)
16. [Algorithm Selection Guide](#algorithm-selection-guide)
17. [Recommended Parameters by Dataset Size](#recommended-parameters-by-dataset-size)
18. [Troubleshooting](#troubleshooting)

---

## Getting Started

### VMD Plugin

Open VMD, then go to **Extensions > Analysis > MDANCE Clustering**, or from the VMD console:

```tcl
package require mdance
mdance::gui
```

The window has eight tabs: **Setup**, **KMeans**, **DIVINE**, **HELM**, **eQUAL**,
**Sweep**, **Results** and **PRIME**.

1. Load a molecule with a trajectory in VMD.
2. In the **Setup** tab, set the molecule ID (`top` for the current molecule) and an
   atom selection (e.g. `protein and name CA`).
3. (Optional) Set a **Frame Range** — see [Frame Range and Stride](#frame-range-and-stride).
4. Check the two live counts before you run: the line under the atom selection reports
   how many atoms it matches, and the line beside **Frame Tools** how many frames the
   range keeps.
5. Open **Settings** (the gear in the toolbar) if you want to check the backend: its
   **MDANCE Backend** group reports whether native library mode or CLI mode is active.
6. (Optional) Adjust the same dialog's **Display** group: app font size, and the default
   plot font size.
7. Select an algorithm tab, configure parameters, and click **Run** — or use the **Sweep**
   tab to scan a whole grid of parameters at once.
8. Inspect results in the **Results** tab.

> **The atom selection must have the same atoms in every frame.** A coordinate-based
> selection such as `within 5 of resname LIG` gains and loses atoms as the trajectory
> moves, which cannot produce a fixed-width coordinate matrix. The plugin refuses such a
> selection with an explicit message rather than clustering misaligned data. Use a static
> selection like `protein and name CA`.

### Execution modes

The plugin picks a backend automatically and shows which one is in use:

| Mode | How it works | Notes |
|------|--------------|-------|
| **Native library** (preferred) | Coordinates are passed to MDANCE directly in memory through the `mdance_tcl` Tcl extension. | No temp files, no subprocess. Install with `./install.sh --with-library`. |
| **CLI** (fallback) | Coordinates are written to a CSV, `mdance-cli` runs as a subprocess, results come back as JSON. | Works with any VMD build. Runs are cancellable and stream live progress. |

### Cancelling a run

In CLI mode, long runs stream progress into the status bar and a **Cancel** button
appears beside it. This covers the HELM pre-clustering step and the elbow K-scan as well
as ordinary runs. The parameter sweep has its own Cancel, which takes effect after the
current configuration finishes. Library-mode runs execute in-process and cannot be
interrupted; the plugin says so in the status bar rather than offering a Cancel that
would not work.

### Command-Line Tool

```bash
mdance-cli --algorithm {kmeans|divine|helm|equal} \
            --input <coordinates.csv> \
            --output <results.json> \
            --natoms <int> \
            [--nclusters <int>] \
            [--metric MSD] \
            [algorithm-specific options...]
```

`--natoms` is the number of atoms per frame. It normalizes MSD so results are comparable
across systems of different sizes. For general (non-MD) data, set `--natoms 1`.

Three further modes operate on an existing clustering:

```bash
mdance-cli --analysis --input C.csv --output out.json --natoms N --metric M --labels L.csv
mdance-cli --prime    --input C.csv --output out.json --natoms N --metric M --labels L.csv \
                      --trim-frac 0.1 [--weighted]
mdance-cli --select   --input C.csv --output out.json --natoms N --metric M \
                      --method {diversity|outliers|repsample|medoid|outlier} --param P --nbins B
```

---

## Frame Range and Stride

The **Setup** tab's Frame Range controls let you cluster a subset of the trajectory —
to skip equilibration, or to decimate a long dense run.

| Field | Meaning |
|-------|---------|
| **First** | First frame to include (0-based). |
| **Last** | Last frame to include. `-1` means the final frame. |
| **Stride** | Keep every Nth frame. `1` keeps all of them. |

All three must be whole numbers; the plugin rejects anything else by name rather than
guessing.

Everything downstream — cluster colouring, Go to Representative, every plot's frame axis,
label export and structure export — maps back to **true VMD frame numbers**, not to
positions within the subset. Frames outside the selected subset are marked unassigned
(`User = -1`) when you colour by cluster, so they are visibly distinct from cluster 0.

> One consequence worth knowing: with a stride, a "residence time" of 3 samples spans
> 3 × stride frames. The Residence chart labels its axis in samples and states the
> conversion in its title.

---

## Input Data Format

### Coordinate CSV

Each row is one frame. Each column is a coordinate value. For a system with N atoms each
row has 3N columns (x1, y1, z1, x2, y2, z2, …, xN, yN, zN). No header row.

```
1.234,5.678,9.012,3.456,...
1.240,5.690,9.001,3.461,...
```

When using the VMD plugin this CSV is generated automatically from the loaded trajectory
and atom selection (or skipped entirely in library mode).

### Label CSV

`--labels` (and HELM's `--initial-labels`) take one integer cluster label per line,
in the same row order as the coordinate CSV:

```
0
0
1
```

The plugin also accepts its own exported `frame,cluster` file here — the header is
skipped and the last column is used — so you can round-trip an Export Labels result
straight back in.

### Output JSON

Clustering runs produce:

| Field | Description |
|-------|-------------|
| `algorithm` | Algorithm name |
| `nFrames` | Number of frames processed |
| `nClusters` | Final number of clusters |
| `labels` | Cluster assignment per frame (array of integers; `-1` means noise/unassigned) |
| `clusterSizes` | Number of frames in each cluster |
| `representatives` | Index of the medoid (most central) frame per cluster |
| `clusterMSD` | Within-cluster mean square deviation per cluster (compactness) |
| `scores.calinskiHarabasz` | Calinski-Harabasz index |
| `scores.daviesBouldin` | Davies-Bouldin index |
| `zMatrix` | Merge linkage matrix (HELM only) |

`--analysis` produces `isim`, `clusterISIM` and `clusterOutliers`; `--prime` produces the
PRIME and baseline frame predictions; `--select` produces `indices`.

---

## KMeans NANI

**Type**: Partitional (flat) clustering

**How it works**: Assigns every frame to the nearest of K cluster centers, then recomputes
centers as the mean of assigned frames. Repeats until convergence. NANI provides
intelligent initialization strategies that consistently outperform random seeding.

**When to use**: When you know (or want to specify) the number of clusters and need fast
results. Best for an initial exploratory pass.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Number of clusters | `--nclusters` | 2 – 200 | *(required)* | How many clusters to partition the data into. The single most important parameter. Start with the expected number of conformational states. |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. Fixed to MSD in the GUI (Setup > Advanced > *Unlock metric selection* to change it); MSD is the only metric with a physical meaning for Cartesian coordinates. |
| Initialization | `--kinit` | See below | `StratAll` | How initial cluster centers are chosen. Strongly affects result quality and reproducibility. |
| Sampling % | `--percentage` | 1 – 100 | `10` | Fraction of data used during initialization. Higher is more robust but slower. |

### Initialization Strategies (`--kinit`)

| Strategy | Description | When to use |
|----------|-------------|-------------|
| `CompSim` | Identifies high-density regions via complementary similarity, then selects diverse centers from them. | Robust for MD trajectories, but roughly 9-12x slower than `StratAll` at comparable quality on benchmark trajectories. |
| `StratAll` | Stratified sampling across the full dataset; first K stratified points become centers. | Good general-purpose choice. Fast. |
| `StratReduced` | Stratified sampling on the high-density subset only. | When data has many outlier frames. |
| `DivSelect` | Pure diversity selection on a subset. Maximizes spread of initial centers. | When clusters are expected to be well-separated. |
| `KmeansPP` | Greedy K-means++ (Arthur & Vassilvitskii). | Industry-standard initialization. Slightly slower than Strat methods. |
| `VanillaKmeansPP` | Standard (non-greedy) K-means++. | When `KmeansPP` is too aggressive. |
| `Random` | Random center selection. | Baseline comparison only. Not recommended for production. |

### Example

```bash
mdance-cli --algorithm kmeans \
    --input trajectory.csv \
    --output kmeans_result.json \
    --natoms 352 \
    --nclusters 10 \
    --metric MSD \
    --kinit CompSim \
    --percentage 10
```

---

## DIVINE

**Type**: Divisive (top-down) hierarchical clustering

**How it works**: Starts with all frames in one cluster. At each step it selects the
cluster with the highest internal variance (by the chosen split criterion), splits it into
two sub-clusters using anchor points, and repeats until the stopping condition is met.
Optionally refines the final partition with KMeans.

**When to use**: When you want a hierarchical decomposition of the trajectory, or when the
natural number of clusters is unknown and you want to watch how the data splits.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Number of clusters | `--nclusters` | 2 – 200 | `3` | Target cluster count (when stopping on K). |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. Fixed to MSD in the GUI — see the KMeans table. |
| Split criterion | `--split` | `MSD`, `Radius`, `WeightedMSD` | `WeightedMSD` | How the next cluster to split is chosen. |
| Anchor method | `--anchors` | `NANI`, `OutlierPair`, `SplinterPair` | `NANI` | How the two seed points for a split are picked. **`OutlierPair` and `SplinterPair` crash the backend when Refine is on** (an out-of-bounds read in `divine.cpp`), so the plugin refuses that combination: turn Refine off to use them, or keep Refine on with `NANI`. |
| Initialization | `--kinit` | See KMeans table | `StratAll` | Used by the NANI anchor and by refinement. |
| Refine | `--refine` | flag | on | Refine the final partition with KMeans. |
| Threshold | `--threshold` | ≥ 0 | `0.0` | Minimum split quality; stops splitting clusters below it. |
| Stopping mode | `--end-mode` | `k`, `points` | `k` | Stop at a cluster count, or when clusters get too small. |
| Sampling % | `--percentage` | 1 – 100 | `10` | Initialization sampling fraction. |

> **Known backend bug.** `OutlierPair` and `SplinterPair` anchors crash when **Refine** is
> enabled — an out-of-bounds index in the backend's `divine.cpp`, not a plugin issue. The
> default combination (`NANI` + refine) is unaffected. Until the backend is patched, turn
> Refine off if you need those anchor methods. Details and a proposed fix are in
> `notes/REVIEW_NOTES.md`.

### Split Criteria (`--split`)

| Criterion | Description |
|-----------|-------------|
| `MSD` | Split the cluster with the highest mean square deviation. |
| `Radius` | Split the cluster with the largest radius (furthest member from the centroid). |
| `WeightedMSD` | MSD weighted by cluster population, so large loose clusters are preferred over small ones. **Recommended default.** |

### Anchor Methods (`--anchors`)

| Method | Description |
|--------|-------------|
| `NANI` | Uses NANI initialization to pick the two seeds. **Recommended default.** |
| `OutlierPair` | Uses the two most extreme outliers as seeds. *(See the refine caveat above.)* |
| `SplinterPair` | Splinter-group approach: grows a dissenting group away from the main body. *(See the refine caveat above.)* |

### Example

```bash
mdance-cli --algorithm divine \
    --input trajectory.csv \
    --output divine_result.json \
    --natoms 352 \
    --nclusters 8 \
    --metric MSD \
    --split WeightedMSD \
    --anchors NANI \
    --kinit CompSim \
    --threshold 0.1 \
    --refine
```

---

## HELM

**Type**: Agglomerative (bottom-up) hierarchical clustering

**How it works**: Starts from an initial over-partition (many small clusters) and
repeatedly merges the two most similar clusters until the stopping criterion is met,
recording the merge history as a Z-matrix.

**When to use**: When you want a genuine dendrogram, or to refine a deliberately over-split
partition down to meaningful states.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. Fixed to MSD in the GUI — see the KMeans table. |
| Merge scheme | `--merge-scheme` | `Intra`, `Inter`, `Half` | `Inter` | Which inter-cluster similarity drives the merge choice. |
| Number of clusters | `--nclusters` | 2 – 200 | `10` | Target count when stopping on K. |
| Epsilon | `--eps` | float | `-1` | Similarity cutoff when stopping on ε instead of K. |
| Enable trimming | `--trim-start` | flag | off | Discard poor pre-clusters before merging. **The three settings below only apply while this is on.** |
| Discard the loosest *N* clusters | `--trim-k` | int | `0` | Drop the *N* pre-clusters with the highest MSD. Choose this **or** the MSD ceiling, never both — the backend refuses both together. |
| Discard clusters with MSD above | `--trim-val` | float | `0` | Keep only pre-clusters whose MSD is below this ceiling. |
| Also discard clusters smaller than | `--min-samples` | float | `0.01` | Below 1 this is a fraction of the total frames (`0.01` = 1%); 1 or more is an absolute frame count. |
| Initial labels | `--initial-labels` | file | *(auto)* | Starting partition. |
| Pre-cluster K | *(plugin only)* | 2 – 200 | `50` | K for the automatic KMeans pre-clustering step. |

### Stopping Criteria

Choose one in the GUI (**Stop on**):

- **Number of clusters** — merge until exactly K clusters remain.
- **Epsilon** — merge while similarity stays above ε; the cluster count emerges.

### Pre-Clustering

HELM needs a starting partition. The plugin offers two sources:

- **Automatic** (default): runs KMeans with **Pre-cluster K** first, then merges down.
  In CLI mode this is a second subprocess, so it also streams progress and can be
  cancelled.
- **From file**: supply a label file. The plugin validates it and checks the label count
  against the number of extracted frames before the run starts.

### Example: K-based stopping

```bash
mdance-cli --algorithm helm \
    --input trajectory.csv \
    --output helm_result.json \
    --natoms 352 \
    --nclusters 8 \
    --metric MSD \
    --merge-scheme Inter \
    --initial-labels prelabels.csv
```

### Example: Epsilon stopping with trimming

```bash
mdance-cli --algorithm helm \
    --input trajectory.csv \
    --output helm_result.json \
    --natoms 352 \
    --eps 0.35 \
    --metric MSD \
    --merge-scheme Inter \
    --trim-start \
    --min-samples 0.01 \
    --initial-labels prelabels.csv
```

---

## eQUAL

**Type**: Extended-quality radial / threshold clustering

**How it works**: Grows clusters radially from seed frames, admitting frames within a
similarity **threshold**. Frames that join no cluster are labelled **noise** (`-1`).

**When to use**: When you do *not* want to preset the number of clusters. The cluster count
emerges from the threshold, and genuine outlier frames are set aside as noise instead of
being forced into a cluster.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Threshold | `--threshold` | ≥ 0 | *(required)* | Radial admission threshold. The controlling parameter: smaller means tighter, more numerous clusters. |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. Fixed to MSD in the GUI — see the KMeans table. |
| Seed method | `--seed-method` | `medoid`, `comp_sim` | `medoid` | How each new cluster's seed frame is chosen. |
| Seeds per iteration | `--n-seeds` | ≥ 1 | `1` | Seeds attempted per pass. |
| Sampling % | `--percentage` | 1 – 100 | `10` | Sampling fraction for seed selection. |
| Min samples | `--min-samples` | ≥ 0 | `10` | Minimum members for a cluster to be kept. |
| Sim threshold | `--sim-threshold` | float | `0` | Secondary similarity gate. |
| Check similarity | `--check-sim` | flag | off | Verify similarity before admitting a frame. |
| Reject low density | `--reject-lowd` | flag | off | Discard low-density candidate clusters. |
| Align method | `--align` | `none` | `none` | Trajectory alignment. |

> **Alignment is not implemented.** The backend's `alignTraj` is a stub for its `uni` and
> `kron` branches, so only `none` is offered — the parse layer rejects the others rather
> than silently doing nothing. Align your trajectory in VMD before clustering if you need it.

**Noise handling.** eQUAL is the only algorithm here that produces `-1` labels. Everything
in the plugin understands them: noise frames get a neutral colour and an unassigned `User`
value, the Timeline gives them their own lane at the bottom, and the Transition heatmap
counts transitions into noise in its denominators (so its rows legitimately sum to less
than 1, which the plot states).

### Example

```bash
mdance-cli --algorithm equal \
    --input trajectory.csv \
    --output equal_result.json \
    --natoms 352 \
    --threshold 1.0 \
    --metric MSD \
    --seed-method medoid \
    --n-seeds 1 \
    --min-samples 10
```

---

## Distance Metrics

All algorithms accept a `--metric` parameter.

| Metric | Full Name | Best For |
|--------|-----------|----------|
| `MSD` | Mean Square Deviation | **Atomic coordinates (default).** Standard Euclidean-family distance, normalized by atom count. Use this for MD trajectory clustering. |
| `BUB` | Baroni-Urbani-Buser | Binary fingerprint data. |
| `Fai` | Faith | Binary fingerprint data. |
| `Gle` | Gleason | Extended similarity for mixed data. |
| `Ja` | Jaccard | Binary presence/absence data. Ignores joint absences. |
| `JT` | Jaccard-Tanimoto | Chemical fingerprint similarity. Standard in cheminformatics. |
| `RT` | Rogers-Tanimoto | Binary data. Penalizes mismatches more than Jaccard. |
| `RR` | Russel-Rao | Binary data. Considers only joint presences. |
| `SM` | Sokal-Michener | Binary data. Treats presences and absences symmetrically. |
| `SS1` | Sokal-Sneath 1 | Binary data. Variant of Jaccard. |
| `SS2` | Sokal-Sneath 2 | Binary data. Variant of SM. |

For molecular dynamics trajectory clustering, **use `MSD`**. The others are intended for
binary or fingerprint representations and are generally not meaningful on raw XYZ
coordinates — the Sweep tab says so next to its metric list.

PRIME is the exception: it defaults to `RR`, because its scoring works on the
extended-similarity side.

---

## Quality Scores

Every clustering run reports two quality metrics:

### Calinski-Harabasz Index (CH)

Ratio of between-cluster dispersion to within-cluster dispersion.

- **Higher is better.** Dense clusters, well separated from each other.
- Useful for comparing different K values on the same dataset.
- Not comparable across different datasets.

### Davies-Bouldin Index (DB)

Average similarity ratio between each cluster and its most similar neighbour.

- **Lower is better.** Compact clusters, far apart.
- Less sensitive to the number of clusters than CH.
- Values close to 0 indicate excellent separation.

A degenerate clustering can make either score non-finite (`NaN`/`Infinity`). The plugin
treats such a value as "no score" — it appears as `n/a` or `-` rather than being plotted
as a number.

### Using Scores to Choose K

Run **Elbow Plot...** from the algorithm's own tab (KMeans, DIVINE or HELM) to plot CH and DB
across a range of K. Look for a peak in CH, a valley in DB, and the "elbow" where more clusters
stop paying. Hover any K on the curve to see that K's population split, and use
**Export Scores...** to save the scores and partitions as CSV.

For HELM the scan pre-clusters **once** with KMeans (using the HELM tab's pre-cluster settings)
and then cuts the dendrogram at each K, so every point comes from the same starting partition.
K values whose run fails or returns a non-finite score are **skipped and reported**, not
plotted as zero — the chart title lists any that were left out.

For a broader search than one K axis, use the [Parameter Sweep](#parameter-sweep).

---

## Parameter Sweep

The **Sweep** tab runs a grid over {algorithm × K × metric × initialization} and tabulates
the results, so you can compare configurations instead of guessing one.

1. Tick the algorithms (**KMeans**, **DIVINE**), metrics and initializations to include.
2. Set the **K range**: min, max, step.
3. Click **Run Sweep**. The plugin confirms the total configuration count first.

Results appear in a sortable table — click any column header to sort. The best run by CH
is highlighted green, the best by DB blue; failed configurations become a red `ERR` row
and do not abort the rest of the grid.

| Action | Effect |
|--------|--------|
| **Load Selected into Results** | Publishes that configuration's result into the Results tab, where every plot and export applies to it. |
| **Score Heatmap** | Grid of (algorithm\|metric\|init) × K, shaded by score, with a **Toggle CH/DB** button. Configurations with no usable score render grey. |
| **Export CSV...** | Writes the whole table. |

Coordinates are extracted **once** and reused for every configuration, so a sweep costs far
less than running each configuration by hand. **Cancel** takes effect after the current
configuration finishes. A sweep and a single run cannot run at the same time — each would
delete the other's working files — and the plugin says so rather than letting them collide.

---

## PRIME Representative Frame Prediction

The **PRIME** tab (Protein Retrieval via Integrative Molecular Ensembles) predicts which
frame of a clustered ensemble is the most "native-like", using extended (n-ary) similarity
rather than a plain medoid.

Run a clustering first, then open the PRIME tab and click **Run PRIME**.

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| Metric | See [metrics](#distance-metrics) | `RR` | Extended-similarity index for scoring. |
| Trim fraction | 0 – 0.5 | `0.1` | Fraction of the least representative frames trimmed before scoring. |
| Weighted | on/off | on | Weight contributions by cluster population. |

The table reports seven frames — four PRIME predictions and three medoid baselines, so you
can see whether PRIME actually disagrees with the naive answer:

| Row | Kind |
|-----|------|
| **Pairwise** | PRIME prediction |
| **Union** | PRIME prediction |
| **Medoid** | PRIME prediction |
| **Outlier** | PRIME prediction |
| **Medoid (all frames)** | Baseline |
| **Medoid (c0)** | Baseline |
| **Medoid (c0 trimmed)** | Baseline |

Double-click a row (or select it and click **Go to Frame**) to navigate VMD to that frame.
Frame numbers are absolute VMD frames, honouring any frame range/stride.

---

## iSIM Similarity Analysis

**Results tab → Similarity** computes extended-similarity (iSIM) statistics for the current
clustering:

- **Ensemble iSIM** — how self-similar the whole selected ensemble is.
- **Per-cluster iSIM** — compactness of each cluster in similarity terms, a complement to
  the MSD view.
- **Per-cluster outlier frame** — the *least* representative member of each cluster, which
  is often where a cluster is really two states.

Results are shown as a chart plus a table, and the underlying numbers export as CSV like
any other plot.

---

## Frame Tools

**Setup tab → Frame Tools...** selects frames *without* clustering. Useful for picking a
representative subset for expensive downstream work (QM, docking, figure-making).

| Method | Selects |
|--------|---------|
| `diversity` | The most diverse subset of frames — maximum spread. |
| `outliers` | The most extreme / least representative frames. |
| `repsample` | A representative density sample across the ensemble. |
| `medoid` | The single most central frame. |
| `outlier` | The single most extreme frame. |

`Param` sets the count (or fraction, per method) and `Bins` the histogram resolution for
density-based methods. The result is a list of absolute VMD frame numbers: double-click one
to jump to it, or use **Export Selected...** to write the selection as PDB or DCD.

---

## Visualizations

The Results tab provides twelve visualizations. Every plot window includes a toolbar with:

- **Font size spinner** — adjust text size within the figure (per window)
- **Export CSV** — save the underlying data
- **Export PS** — save the figure as PostScript (always available)
- **Export PNG** — save as PNG (requires ImageMagick or GraphicsMagick; offers a
  PostScript fallback, asking first if that would overwrite an existing file)

All plot windows **auto-resize**. Expensive plots (Silhouette, Distances, Rep. RMSD,
Dendrogram) cache their computation so resizing stays fast; the cache is released when the
window closes.

### Core Plots

| Plot | Description |
|------|-------------|
| **Population** | Bar chart of cluster sizes, coloured by cluster. Reveals imbalanced partitions. |
| **Timeline** | Cluster assignment vs. frame number, showing transitions between states along the trajectory. Noise (`-1`) gets its own labelled lane at the bottom. |
| **Cluster MSD** | Bar chart of within-cluster MSD. Lower bars are tighter clusters. |
| **Dendrogram** | Merge tree. For HELM this is the native merge history from the Z-matrix — which is a *forest* of one tree per final cluster, and all of them are drawn. For KMeans/DIVINE/eQUAL a post-hoc tree is computed from centroid distances with average linkage. |
| **Elbow Plot** | CH and DB against K, across a K range, launched from each algorithm's own tab. Hover a K for its population split; **Export Scores...** writes the scores and partitions. Failed or non-finite K values are skipped and named, never plotted as zero. |
| **Silhouette** | Per-frame silhouette coefficients grouped by cluster, with a dashed line at the mean. Centroid-based approximation; frames are sampled above 2000. |

### Analysis Plots

| Plot | Description |
|------|-------------|
| **Distances** | Heatmap of pairwise inter-cluster centroid MSD. Shows merge candidates and well-separated pairs. |
| **MSD/Pop** | Within-cluster MSD (y) vs. population (x). Large + high MSD suggests a cluster to split; tiny clusters may be noise. Dashed lines mark the medians. |
| **Rep. RMSD** | Pairwise RMSD between representative frames — how structurally distinct the cluster centres are. Needs the source molecule loaded. |
| **Transitions** | Cluster-to-cluster transition probabilities from consecutive frame pairs. Transitions into noise are counted in each row's denominator but have no column, so rows sum to less than 1 when noise is present; the plot says so and the CSV carries an explicit `-1` column. |
| **Residence** | Mean residence time per cluster with min/max whiskers. Measured in **samples**; under a stride the title gives the frame conversion. |
| **Similarity** | iSIM ensemble/per-cluster compactness and outlier frames — see [iSIM Similarity Analysis](#isim-similarity-analysis). |

---

## Exports and Sessions

### Exports

| Action | Output |
|--------|--------|
| **Export Labels...** | `frame,cluster` CSV over absolute VMD frame numbers. Re-importable as HELM initial labels. |
| **Export Representatives...** | Each cluster's medoid frame as a single multi-model **PDB** or **DCD**. A DCD has no topology, so a companion `.pdb` is written alongside it. |
| **Export Clusters...** | One trajectory file per cluster (`cluster_<id>.<fmt>`) in a directory you choose. |
| **Export Selected...** | The Frame Tools selection as PDB or DCD. |
| Plot toolbars | Per-plot CSV, PS and PNG. |

Files the plugin derives rather than you naming them — a DCD's companion `.pdb`, the
generated per-cluster set, a PostScript fallback — ask before overwriting anything.

### Sessions

**Save Session...** writes the current result, its input parameters, its frame map and a
signature of the source molecule to a `.mdance` file. **Load Session...** restores it.

Score, table and label-based views work from a loaded session on their own. Views that
re-read coordinates — Color by Cluster, Go to Representative, structure export, and the
centroid/silhouette/RMSD/similarity plots — need the original molecule loaded. The plugin
checks the molecule's identity, not just its ID number: if the ID now holds a *different*
molecule (VMD reuses IDs), the session is reported as not-live rather than silently
colouring the wrong trajectory.

---

## Algorithm Selection Guide

| Scenario | Recommended | Reasoning |
|----------|-------------|-----------|
| Quick exploration of a new trajectory | **KMeans NANI** | Fast and simple. Use the Elbow Plot to find K. |
| You do not want to preset K | **eQUAL** | The cluster count emerges from a radial threshold, and outliers become noise rather than being forced into a cluster. |
| Unknown number of conformational states | **DIVINE** | Hierarchical splitting reveals natural structure. Start with a large K and use `--threshold` to control minimum cluster quality. |
| Refining a coarse partition | **HELM** | Merges over-split clusters while keeping meaningful distinctions. Pre-cluster with KMeans (K=50), then merge down. |
| Noisy trajectory with outliers | **HELM** with trimming, or **eQUAL** | HELM trims noise clusters before merging; eQUAL labels outliers as noise directly. |
| Dendrogram needed | **HELM** | Native Z-matrix, exact merge history. The others get a post-hoc tree from centroid distances. |
| Reproducibility across runs | **KMeans NANI** with `StratAll` (the default) or `CompSim` | Deterministic given the same data. |
| Very large trajectories (>10K frames) | **KMeans NANI** | Scales as O(n·k·iterations). Consider a stride as well. |
| Comparing many settings at once | **Sweep tab** | Extracts coordinates once and scores the whole grid. |
| Choosing a frame for downstream work | **PRIME**, or **Frame Tools** | PRIME for the most native-like frame of a clustering; Frame Tools for a diverse subset without clustering at all. |
| Coarse-to-fine pipeline | **KMeans** then **HELM** | Fast initial partition, then hierarchical refinement with a dendrogram. |

---

## Recommended Parameters by Dataset Size

### Small trajectories (< 500 frames)

```
KMeans:  --nclusters 3-5   --kinit CompSim  --percentage 10
DIVINE:  --nclusters 2-4   --split WeightedMSD  --anchors NANI  --refine
HELM:    --nclusters 2-5   (pre-cluster K=15-25)
eQUAL:   --threshold (start near the median pairwise MSD)  --min-samples 5
```

### Medium trajectories (500 – 5,000 frames)

```
KMeans:  --nclusters 5-15  --kinit CompSim  --percentage 10
DIVINE:  --nclusters 3-10  --split WeightedMSD  --anchors NANI  --refine  --threshold 0.1
HELM:    --nclusters 5-15  --merge-scheme Inter  (pre-cluster K=30-50)
eQUAL:   --threshold tuned to give 5-15 clusters  --min-samples 10
```

### Large trajectories (5,000 – 50,000 frames)

```
KMeans:  --nclusters 10-30 --kinit CompSim  --percentage 10
DIVINE:  --nclusters 5-20  --split WeightedMSD  --anchors NANI  --refine  --threshold 0.2
HELM:    --nclusters 5-20  --merge-scheme Inter  --trim-start  --min-samples 0.01
         (pre-cluster K=50-100)
eQUAL:   --threshold tuned  --min-samples 25  --percentage 10
```

For very long trajectories, a **stride** on the Setup tab is usually a better first move
than a bigger K: clustering every 10th frame of a 100k-frame run is 10× cheaper and rarely
changes the conformational picture.

Start with the defaults and iterate on the quality scores plus a look at the Timeline and
Population plots.

---

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| *"Atom selection '…' is frame-dependent"* | The selection changes membership between frames (e.g. `within 5 of …`). Use a static selection such as `protein and name CA`. |
| *"First frame / Last frame / Stride must be a whole number"* | A Frame Range field contains something that is not an integer. These are rejected rather than guessed, because a silent misread would cluster the wrong frames. |
| *"Backend output is missing 'labels'"* or *"returned N labels for M extracted frames"* | The backend exited without writing a complete result. The run is refused rather than mapped onto the trajectory; check the accompanying backend message. |
| *"This operation needs the mdance-cli backend"* | Library mode is active but this feature needs the CLI. Set `MDANCE_CLI` to the binary. |
| DIVINE crashes with `OutlierPair`/`SplinterPair` | Known backend bug; turn **Refine** off, or use the `NANI` anchor. See `notes/REVIEW_NOTES.md`. |
| "The OutlierPair anchor combined with Refine crashes the MDANCE backend" | A known backend defect, not a configuration mistake. Turn Refine off, or use the `NANI` anchor. |
| HELM's "Min samples" appears to do nothing | It only applies while **Enable trimming** is on *and* a trim criterion (loosest-*N* or MSD ceiling) is set; the controls grey out when inert. |
| Elbow chart is missing some K values | Those runs failed or produced a non-finite score. The caption above the chart names them. |
| Transition probabilities do not sum to 1 | Expected when noise is present: transitions into noise are counted but have no column. |
| A session loads but Color by Cluster is disabled | The source molecule is not loaded, or the ID now holds a different molecule. Reload the original trajectory. |
| PNG export says ImageMagick is required | Install ImageMagick (`magick`/`convert`) or GraphicsMagick (`gm`), or accept the PostScript fallback. |
