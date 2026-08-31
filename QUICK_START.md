# MDANCE Quick Start Guide

This guide covers all three clustering algorithms available in the MDANCE VMD plugin and the `mdance-cli` command-line tool: **KMeans NANI**, **DIVINE**, and **HELM**.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Input Data Format](#input-data-format)
3. [KMeans NANI](#kmeans-nani)
4. [DIVINE](#divine)
5. [HELM](#helm)
6. [Distance Metrics](#distance-metrics)
7. [Quality Scores](#quality-scores)
8. [Visualizations](#visualizations)
9. [Algorithm Selection Guide](#algorithm-selection-guide)
10. [Recommended Parameters by Dataset Size](#recommended-parameters-by-dataset-size)

---

## Getting Started

### VMD Plugin

Open VMD, then go to **Extensions > Analysis > MDANCE Clustering**, or from the VMD console:

```tcl
package require mdance
mdance::gui
```

1. Load a molecule with a trajectory in VMD.
2. In the **Setup** tab, set the molecule ID (`top` for the current molecule) and an atom selection (e.g., `protein and name CA`).
3. Click **Preview** to verify atom count and frame count.
4. (Optional) Adjust **Display Settings**: set the app font size and the default plot font size.
5. Select an algorithm tab, configure parameters, and click **Run**.
6. Inspect results in the **Results** tab.

### Command-Line Tool

```bash
mdance-cli --algorithm {kmeans|divine|helm} \
            --input <coordinates.csv> \
            --output <results.json> \
            --natoms <int> \
            --nclusters <int> \
            [--metric MSD] \
            [algorithm-specific options...]
```

The `--natoms` parameter is the number of atoms per frame in the coordinate data. It normalizes MSD so that results are comparable across systems of different sizes. For general (non-MD) data, set `--natoms 1`.

---

## Input Data Format

### Coordinate CSV

Each row is one frame (snapshot). Each column is a coordinate value. For a molecular system with N atoms, each row has 3N columns (x1, y1, z1, x2, y2, z2, ..., xN, yN, zN). No header row.

```
1.234,5.678,9.012,3.456,...
1.240,5.690,9.001,3.461,...
```

When using the VMD plugin, this CSV is generated automatically from the loaded trajectory and atom selection.

### Output JSON

All algorithms produce a JSON file containing:

| Field | Description |
|-------|-------------|
| `algorithm` | Algorithm name |
| `nFrames` | Total number of frames processed |
| `nClusters` | Final number of clusters |
| `labels` | Cluster assignment for each frame (array of integers) |
| `clusterSizes` | Number of frames in each cluster |
| `representatives` | Index of the medoid (most central) frame per cluster |
| `clusterMSD` | Within-cluster mean square deviation per cluster (compactness) |
| `scores.calinskiHarabasz` | Calinski-Harabasz index |
| `scores.daviesBouldin` | Davies-Bouldin index |
| `zMatrix` | Dendrogram linkage matrix (HELM only) |

---

## KMeans NANI

**Type**: Partitional (flat) clustering

**How it works**: Assigns every frame to the nearest of K cluster centers, then recomputes centers as the mean of assigned frames. Repeats until convergence. NANI provides intelligent initialization strategies that consistently outperform random seeding.

**When to use**: When you know (or want to specify) the number of clusters and need fast results. Best for an initial exploratory pass.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Number of clusters | `--nclusters` | 2 -- 200 | *(required)* | How many clusters to partition the data into. The single most important parameter. Start with the expected number of conformational states. |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. MSD (mean square deviation) is standard for atomic coordinates. Other metrics are designed for binary fingerprint data. |
| Initialization | `--kinit` | See below | `StratAll` | How initial cluster centers are chosen. Strongly affects result quality and reproducibility. |
| Sampling % | `--percentage` | 1 -- 100 | `10` | Fraction of data used during initialization. Higher values give more robust initialization at the cost of speed. 10% is a good default. |

### Initialization Strategies (`--kinit`)

| Strategy | Description | When to use |
|----------|-------------|-------------|
| `CompSim` | Identifies high-density regions via complementary similarity, then selects diverse centers from them. | **Recommended default.** Most robust for MD trajectories. |
| `StratAll` | Stratified sampling across the full dataset; first K stratified points become centers. | Good general-purpose choice. Fast. |
| `StratReduced` | Stratified sampling on the high-density subset only. | When data has many outlier frames. |
| `DivSelect` | Pure diversity selection on a subset. Maximizes spread of initial centers. | When clusters are expected to be well-separated. |
| `KmeansPP` | Greedy K-means++ (Arthur & Vassilvitskii). Probabilistically selects distant centers. | Industry-standard initialization. Slightly slower than Strat methods. |
| `VanillaKmeansPP` | Standard (non-greedy) K-means++. | When `KmeansPP` is too aggressive. |
| `Random` | Random center selection. | Baseline comparison only. Not recommended for production use. |

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

**How it works**: Starts with all frames in one cluster. At each step, selects the cluster with the highest internal variance (by the chosen split criterion), splits it into two sub-clusters using anchor points, and repeats until the target cluster count is reached. Optionally refines the final partition with KMeans.

**When to use**: When you want a hierarchical decomposition of the trajectory, or when the natural number of clusters is unknown and you want to observe how the data splits.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Number of clusters | `--nclusters` | 2 -- 200 | *(required)* | Target number of clusters. |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. |
| Split criterion | `--split` | `MSD`, `Radius`, `WeightedMSD` | `WeightedMSD` | How to score clusters for splitting (which cluster to split next). |
| Anchor method | `--anchors` | `NANI`, `OutlierPair`, `SplinterPair` | `NANI` | How to choose the two seed points when splitting a cluster. |
| Initialization | `--kinit` | Same as KMeans | `StratAll` | Initialization strategy for the KMeans refinement step. Only used when `--refine` is set. |
| Refine | `--refine` | *(flag)* | off | Apply a KMeans refinement pass after splitting. Produces cleaner cluster boundaries. Recommended for final results. |
| Threshold | `--threshold` | 0.0 -- 1.0 | `0` | Minimum cluster size as a fraction of total frames. A value of 0.2 prevents splitting clusters below 20% of total. Useful to avoid very small clusters. |
| End mode | `--end-mode` | `k`, `points` | `k` | Stopping rule. `k`: stop when K clusters are reached. `points`: keep splitting until every frame is isolated (useful for full hierarchical decomposition). |
| Sampling % | `--percentage` | 1 -- 100 | `10` | Fraction of data used during anchor selection and initialization. |

### Split Criteria (`--split`)

| Criterion | Description | When to use |
|-----------|-------------|-------------|
| `WeightedMSD` | MSD weighted by cluster size. Balances splitting large and high-variance clusters. | **Recommended.** Most stable across datasets. |
| `MSD` | Raw mean square deviation within the cluster. Always splits the highest-variance cluster. | When variance is the primary concern. |
| `Radius` | Maximum distance from center to any member. Splits the most spread-out cluster. | When spatial extent matters more than variance. |

### Anchor Methods (`--anchors`)

| Method | Description | When to use |
|--------|-------------|-------------|
| `NANI` | Uses complementary similarity and diversity selection to find two representative anchors. | **Recommended.** Most robust, avoids outlier-driven splits. |
| `OutlierPair` | Selects the two most dissimilar points in the cluster as anchors. | When clusters are well-separated and outliers are informative. |
| `SplinterPair` | Selects points at the periphery of the cluster. | Alternative when `OutlierPair` produces uneven splits. |

### Example

```bash
mdance-cli --algorithm divine \
    --input trajectory.csv \
    --output divine_result.json \
    --natoms 352 \
    --nclusters 5 \
    --metric MSD \
    --split WeightedMSD \
    --anchors NANI \
    --refine \
    --threshold 0.1 \
    --end-mode k \
    --percentage 10
```

---

## HELM

**Type**: Agglomerative (bottom-up) hierarchical clustering

**How it works**: Starts from a set of initial clusters (typically produced by KMeans pre-clustering) and iteratively merges the two most similar clusters until a stopping criterion is met. Produces a dendrogram (merge tree) showing the full merge history. Includes trimming options for removing small or diffuse clusters before merging.

**When to use**: When you want to merge an existing partition into coarser clusters, when you want a dendrogram to visualize hierarchical relationships, or when the dataset has outlier frames that need trimming.

### Parameters

| Parameter | CLI Flag | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| Number of clusters | `--nclusters` | 0 -- 200 | `10` | Target cluster count. Set to 0 to use epsilon-based stopping instead. |
| Metric | `--metric` | See [metrics](#distance-metrics) | `MSD` | Distance function. |
| Merge scheme | `--merge-scheme` | `Intra`, `Inter`, `Half` | `Inter` | Linkage criterion for deciding which clusters to merge. |
| Epsilon | `--eps` | > 0 or -1 | `-1` | Distance threshold. When set, merging stops when all pairwise distances exceed this value. Set to -1 to disable (use `--nclusters` instead). |
| Initial labels | `--initial-labels` | CSV path | *(auto)* | Pre-computed cluster labels. If omitted in the VMD plugin, KMeans pre-clustering runs automatically. |
| Trim start | `--trim-start` | *(flag)* | off | Enable trimming of initial clusters before merging. |
| Min samples | `--min-samples` | 0.0 -- 1.0 | `0.01` | Minimum population fraction. Clusters with fewer frames than `min-samples * total_frames` are removed during trimming. 0.01 = 1%. |
| Trim value | `--trim-val` | >= 0 | `0` | Maximum allowed within-cluster MSD. Clusters with higher MSD are removed during trimming. 0 = disabled. |
| Trim K | `--trim-k` | >= 0 | `0` | Remove the K most diffuse initial clusters during trimming. 0 = disabled. |

### Merge Schemes (`--merge-scheme`)

| Scheme | Description | When to use |
|--------|-------------|-------------|
| `Inter` | Merges clusters with the smallest between-cluster distance. Similar to single linkage. | **Recommended.** Finds well-separated clusters. |
| `Intra` | Merges clusters that produce the smallest increase in within-cluster variance. Similar to Ward linkage. | When you want compact, equally-sized clusters. |
| `Half` | Hybrid of Intra and Inter. | When neither pure Inter nor Intra gives satisfactory results. |

### Stopping Criteria

HELM supports two mutually exclusive stopping modes:

1. **K-based**: Set `--nclusters N` and `--eps -1`. Merging stops when exactly N clusters remain.
2. **Distance-based**: Set `--nclusters 0` and `--eps VALUE`. Merging stops when all remaining pairwise distances exceed VALUE.

Use the **Elbow Plot** visualization to determine a good value for K or epsilon.

### Trimming

Trimming removes problematic initial clusters *before* the main merging phase. Enable with `--trim-start` and configure with:

- `--min-samples 0.025`: Remove clusters with < 2.5% of total frames (good for removing noise clusters).
- `--trim-val 5.0`: Remove clusters with internal MSD > 5.0 (good for removing diffuse clusters).
- `--trim-k 3`: Remove the 3 most diffuse clusters (simple, size-independent approach).

These options can be combined. Trimming is particularly useful when the pre-clustering step produces many tiny or scattered clusters.

### Pre-Clustering

HELM requires an initial partition as input. Two approaches:

1. **Automatic** (VMD plugin default): The plugin runs KMeans with K=50 before HELM. Configurable via the "Pre-cluster K" spinbox. Higher K gives finer initial granularity but slower HELM.
2. **Manual**: Provide a CSV file of labels via `--initial-labels`. The file should have one label per line (or two columns: frame index and label). You can use the output of a previous KMeans or DIVINE run.

### Example: K-based stopping

```bash
mdance-cli --algorithm helm \
    --input trajectory.csv \
    --output helm_result.json \
    --natoms 352 \
    --nclusters 8 \
    --metric MSD \
    --merge-scheme Inter \
    --initial-labels kmeans_labels.csv
```

### Example: Epsilon stopping with trimming

```bash
mdance-cli --algorithm helm \
    --input trajectory.csv \
    --output helm_result.json \
    --natoms 352 \
    --nclusters 0 \
    --eps 15.0 \
    --metric MSD \
    --merge-scheme Inter \
    --trim-start \
    --min-samples 0.025 \
    --trim-k 2 \
    --initial-labels kmeans_labels.csv
```

---

## Distance Metrics

All three algorithms accept a `--metric` parameter. The choice of metric depends on the type of data.

| Metric | Full Name | Best For |
|--------|-----------|----------|
| `MSD` | Mean Square Deviation | **Atomic coordinates (default).** Standard Euclidean-family distance, normalized by number of atoms. Use this for MD trajectory clustering. |
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

For molecular dynamics trajectory clustering, **use `MSD`**. The other metrics are intended for binary or fingerprint-based data representations.

---

## Quality Scores

Every clustering run reports two quality metrics:

### Calinski-Harabasz Index (CH)

Ratio of between-cluster dispersion to within-cluster dispersion.

- **Higher is better.** A high CH score means clusters are dense internally and well-separated from each other.
- Useful for comparing different K values on the same dataset.
- Not comparable across different datasets.

### Davies-Bouldin Index (DB)

Average similarity ratio between each cluster and its most similar neighbor.

- **Lower is better.** A low DB score means clusters are compact and far from each other.
- Less sensitive to the number of clusters than CH.
- Values close to 0 indicate excellent separation.

### Using Scores to Choose K

Run the **Elbow Plot** (available in the Visualizations section of the Results tab) to plot CH and DB across a range of K values. Look for:
- A peak in the CH curve (maximum separation/compactness ratio).
- A valley in the DB curve (minimum cluster overlap).
- The "elbow" where adding more clusters yields diminishing returns.

---

## Visualizations

The Results tab provides eleven visualization options, organized in two rows of buttons. Every plot window includes an interactive toolbar with:

- **Font size spinner** — adjust the text size within the figure (each window has its own setting)
- **Export CSV** — save the underlying data (cluster IDs, scores, distances, etc.) as a comma-separated file
- **Export PS** — save the figure as a PostScript file (always available)
- **Export PNG** — save the figure as a PNG image (requires ImageMagick or GraphicsMagick; falls back to PostScript if unavailable)

All plot windows **auto-resize**: when you drag the window border, the figure redraws to fill the new dimensions. Computationally expensive plots (Silhouette, Distances, Rep. RMSD, Dendrogram) cache their results so resizing is fast.

### Core Plots

| Plot | Description | Available For |
|------|-------------|---------------|
| **Population** | Bar chart of cluster sizes, colored by cluster. Reveals imbalanced partitions. | All algorithms |
| **Timeline** | Cluster assignment vs. frame number. Shows temporal transitions between conformational states along the trajectory. | All algorithms |
| **Cluster MSD** | Bar chart of within-cluster MSD. Lower bars indicate tighter, more homogeneous clusters. | All algorithms |
| **Dendrogram** | Hierarchical merge tree. For HELM, shows the native merge history from the Z-matrix. For KMeans and DIVINE, computes a post-hoc dendrogram from centroid distances using average linkage. | All algorithms |
| **Elbow Plot** | CH and DB scores plotted against K. Runs clustering for a range of K values to find the optimal number of clusters. | All algorithms |
| **Silhouette** | Per-frame silhouette coefficients grouped by cluster. Each horizontal bar shows how well a frame fits its assigned cluster vs. the nearest neighbor cluster. A vertical red dashed line marks the mean silhouette value. Uses a centroid-based approximation for speed; frames are sampled if the trajectory exceeds 2000 frames. | All algorithms |

### Analysis Plots

| Plot | Description | Available For |
|------|-------------|---------------|
| **Distances** | Heatmap of pairwise inter-cluster distances (centroid MSD). Quickly shows which clusters are similar (potential merge candidates) and which are well-separated. | All algorithms |
| **MSD/Pop** | Scatter plot of within-cluster MSD (y) vs. cluster population (x). Identifies problematic clusters: large + high MSD suggests a cluster should be split; tiny clusters may be noise. Dashed lines mark the median on each axis. | All algorithms (requires MSD) |
| **Rep. RMSD** | Heatmap of pairwise RMSD between representative (medoid) frames. Shows how structurally distinct the cluster centers are. Cheap to compute since only one frame per cluster is compared. | All algorithms |
| **Transitions** | Heatmap of cluster-to-cluster transition probabilities computed from consecutive frame pairs. Reveals kinetic relationships: which conformational states interconvert directly. | All algorithms |
| **Residence** | Bar chart of mean residence time (consecutive frames) per cluster, with min/max whiskers. Distinguishes stable conformational states (long residence) from transient visits. | All algorithms |

---

## Algorithm Selection Guide

| Scenario | Recommended | Reasoning |
|----------|-------------|-----------|
| Quick exploration of a new trajectory | **KMeans NANI** | Fast, simple, gives immediate results. Use the Elbow Plot to determine K. |
| Unknown number of conformational states | **DIVINE** | Hierarchical splitting reveals natural cluster structure. Start with a large K and use threshold to control minimum cluster size. |
| Refining a coarse partition | **HELM** | Merges over-split clusters while preserving meaningful distinctions. Pre-cluster with KMeans (K=50), then merge down. |
| Noisy trajectory with outliers | **HELM** with trimming | Trim options remove noise clusters before merging, producing cleaner results. |
| Dendrogram visualization needed | **HELM** | HELM produces a native Z-matrix for exact merge history. KMeans/DIVINE can also show post-hoc dendrograms from centroid distances. |
| Reproducibility across runs | **KMeans NANI** with `CompSim` | CompSim initialization is deterministic given the same data. |
| Very large trajectories (>10K frames) | **KMeans NANI** | O(n * k * iterations) scales well. HELM's pairwise distance matrix is O(k^2) on initial clusters, not on frames. |
| Pipeline: coarse-to-fine analysis | **KMeans** then **HELM** | KMeans for fast initial partition, HELM for hierarchical refinement with dendrogram. |

---

## Recommended Parameters by Dataset Size

### Small trajectories (< 500 frames)

```
KMeans:  --nclusters 3-5   --kinit CompSim  --percentage 10
DIVINE:  --nclusters 2-4   --split WeightedMSD  --anchors NANI  --refine
HELM:    --nclusters 2-5   (pre-cluster K=15-25)
```

### Medium trajectories (500 -- 5,000 frames)

```
KMeans:  --nclusters 5-15  --kinit CompSim  --percentage 10
DIVINE:  --nclusters 3-10  --split WeightedMSD  --anchors NANI  --refine  --threshold 0.1
HELM:    --nclusters 5-15  --merge-scheme Inter  (pre-cluster K=30-50)
```

### Large trajectories (5,000 -- 50,000 frames)

```
KMeans:  --nclusters 10-30 --kinit CompSim  --percentage 10
DIVINE:  --nclusters 5-20  --split WeightedMSD  --anchors NANI  --refine  --threshold 0.2
HELM:    --nclusters 5-20  --merge-scheme Inter  --trim-start  --min-samples 0.01
         (pre-cluster K=50-100)
```

For all sizes, start with the defaults and iterate based on quality scores and visual inspection of the timeline and population plots.
