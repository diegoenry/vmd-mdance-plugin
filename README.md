<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/_static/logo/vmdance_dark.svg">
    <img src="docs/_static/logo/vmdance.svg" alt="VMDance" width="440">
  </picture>
</p>

# VMDance — MDANCE clustering of a trajectory, in VMD

VMD and MDANCE share their MD, molecular dynamics: VMDance is the two in
one, as its logo draws it. A VMD Tcl/Tk plugin that clusters the frames of a
trajectory with the algorithms of
[MDANCE](https://github.com/mqcomplab/MDANCE) — KMeans NANI, DIVINE, HELM
and eQUAL, run by their C++ port
[CPP-MDANCE](https://github.com/mqcomplab/CPP-MDANCE) — and shows the
clusters: how many frames each holds, when the trajectory visits it, how it
moves between them, how tight and how far apart they are, how they join, and
their representative structures in VMD's 3D window. PRIME predicts the
native-like frame of the clusters; MDANCE's extended similarity (iSIM)
measures each cluster; frames can be picked without clustering; elbow scans
and sweeps compare values of k and parameters.

![The VMDance window](docs/_static/figures/window.png)

VMDance replaces, rewritten from scratch, the MDANCE VMD plugin this
repository held before (its last version is commit `bf6fd41`; the rewrite
was called MDANCEView until it took its place). It keeps its science — the
same backend, the same algorithms and defaults, the same kinds of measures
(the silhouette computed otherwise: see *Differences*) — and follows the
design of the DihedralView, InteractionView and Molywood Studio plugins: one
Tcl package with a single command that scripts everything the window does, a
Tk-free core tested in text-mode VMD against the backend itself and MDANCE's
published runs, a lazily loaded window with the same look, and tests that
run inside VMD. See *Design* below.

**Full documentation** (Sphinx) is in `docs/`: `cd docs && make html`, then
open `docs/_build/html/index.html`.

## Install

VMDance needs a build of CPP-MDANCE: its program `mdance-cli`, its
library `mdance_tcl`, or both.

```sh
git clone https://github.com/mqcomplab/CPP-MDANCE.git
cd CPP-MDANCE
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TCL=ON && cmake --build build -j
export MDANCE_CLI=$PWD/build/cli/mdance-cli           # the program
export MDANCE_LIB=$PWD/build/tcl/mdance_tcl.so        # the library (optional)
```

Then add the plugin to `~/.vmdrc`:

```tcl
lappend auto_path /path/to/vmd-mdance-plugin/vmdance
package require vmdance   ;# registers Extensions > Analysis > VMDance
```

and open **Extensions ▸ Analysis ▸ VMDance**, or type `vmdance` in
VMD's console. It needs a VMD built with Tcl/Tk 8.6, as VMD 2 is (`info
patchlevel` in VMD's console says which: VMD 1.9.3 and the Linux 1.9.4
alphas have Tcl 8.5, and cannot load it); it is
tested in VMD 2.1 (Linux). The backend is found through `MDANCE_CLI` and
`MDANCE_LIB`, the plugin's folder, the `PATH`, or a CPP-MDANCE build beside
the plugin's folder; **Settings ▸ Backend** chooses another and keeps it,
for the command too (`vmdance backend -mode … -cli …` chooses for this
VMD only).
(`~/.bashrc` reaches only a VMD started from a shell: `set env(MDANCE_CLI)
/path/to/mdance-cli` in `~/.vmdrc` reaches every one.) Figures in PDF and
PNG use Ghostscript (EPS works without it). `make distrib PLUGINDIR=…`
copies the plugin into a VMD plugin tree as `vmdance1.0`.

**The backend, two ways.** The program (`mdance-cli`) runs in the
background: the window and VMD stay usable, and Cancel stops it (it can be
a script that runs `mdance-cli`, to set `LD_LIBRARY_PATH` or start a
container: Cancel stops what the script started too, an Apptainer or
Singularity container with it, but a docker or podman container only when
run with `--init`, which passes the stop on to its program; a program that takes
more than 3 s to answer when run without arguments is offered every
algorithm, and Settings says so). The library runs inside VMD, with the
coordinates passed to it in memory (no program is started), but a call
blocks VMD until it returns, cannot be cancelled, and takes about 180
bytes of VMD's memory a coordinate: a call that cannot fit, or whose
coordinates' text would pass Tcl's 2 GB (which ends VMD), is refused, and
the program named. Either way the coordinates are written to a file of the
plugin's private folder. *Automatic* (the default) uses the program when
there is one, else the library, and Setup then says so; through a library
call the status line says that VMD waits for it. CPP-MDANCE builds DIVINE only
with `BUILD_DIVINE` on a tree that has it; the window offers only the
algorithms the backend was built with, and says which are missing.

## What it clusters

A molecule's frames — all of them, a range, every n-th — each read as the
x, y, z of the same atoms (Cα atoms by default; a selection whose atoms can
change with the frame, such as `within`, is refused, but not a value in
quotes: `chain "x"`). The coordinates are
clustered as they are: an aligned trajectory, as MDANCE expects. *Fit to
the first frame on* superposes every frame on the first clustered one
before clustering; it is computed on the values, and VMD's own coordinates
are never moved.

| Algorithm | What it does | Given |
|---|---|---|
| **KMeans NANI** | k-means with N-ary natural initiation: the seeds from MDANCE's extended-similarity schemes (stratified, complementary similarity, diversity selection) or k-means++ | k (10), the seeding (stratified, all frames), the high-density share (10%) |
| **DIVINE** | divisive hierarchical: the trajectory split in two, cluster by cluster, until k | k (3), the split criterion, the anchors (a 2-cluster NANI, or the two most distant frames), the smallest share a split leaves, when to stop |
| **HELM** | agglomerative hierarchical: the many small clusters of a first NANI clustering (or of a label file, such as MDANCE's own) merged until k remain | k (10), the starting clusters (50, stratified), the merge scheme, the trim |
| **eQUAL** | extended quality: clusters grown within a radius; their number follows from it, and frames outside every one are noise | the radius (MDANCE's MSD, Å²: half the RMSD² to the seed), the seeds, the rejection of small or loose clusters |

The metric is the mean square deviation (MSD) of the coordinates; the ten
binary and extended-similarity indices of MDANCE are there for
fingerprint-like data (**Settings ▸ Unlock the metrics**). The defaults are
those of the MDANCE plugin's window (but DIVINE's Refine, off). Checks come
before the backend runs, and say what to change: NANI's seedings by
extended similarity draw k seeds from the densest share of the frames, so
k 10 at 10% needs 100 frames; DIVINE's OutlierPair and SplinterPair anchors
with refinement crash CPP-MDANCE's DIVINE, and are refused (Refine is off:
a NANI split is a k-means already), DIVINE splits by MSD (another metric
would only choose its representatives), its first NANI split needs two
seeds, its smallest share is not for NANI's splits (CPP-MDANCE ignores it
there) and no more than a split can leave, and `-end-mode points` needs the
pair anchors and a share of 2 frames or more (else every frame ends alone);
HELM merges more starting clusters than k (those its first clustering
leaves with frames; what `-min-samples` and `-trim-k` leave too; what
`-trim-val`'s cut, an MSD the backend computes, leaves once HELM has run),
stops at k or at `-eps` (one of the two),
and trims by a number of clusters or an MSD, not both; eQUAL's similarity
ceiling is above 0; a metric other than MSD with the seedings that use the
diversity selection (CompSim, DivSelect) makes CPP-MDANCE read past its
data, and with eQUAL puts every frame in one cluster: both are refused; a
number is 0, or 1.2e-38 to 3.4e38 in size (what the backend can read).
Coordinates that are not numbers (NaN, infinite: a run that blew up) are
refused as they are read, naming the frame.

For every clustering the backend gives each frame's cluster, each cluster's
representative (MDANCE's medoid), its MSD within (MDANCE's: the mean over
every pair of its frames, each with itself too, of their squared distance
per atom — twice the mean squared distance from the mean structure; none
for a cluster without frames), and the Calinski–Harabasz (higher: better)
and Davies–Bouldin (lower: better) scores of the clustered frames (none
with fewer than two clusters, or with every cluster a frame alone; HELM's
with a trim the plugin computes, as CPP-MDANCE counts the trimmed frames as
one more cluster); HELM its merges. The plugin
measures, from the same coordinates, squared distances per atom between two
structures (RMSD², no fit: twice MDANCE's MSD of the pair): every frame's
from its cluster's representative, and between every two representatives
and every two clusters' mean structures; and every frame's silhouette from
the mean structures ((b − a) / max(a, b), a and b RMSDs; 0 for a frame
alone in its cluster).

## The window

A toolbar sits on top (sessions, export and figures, Cluster, Elbow and
Cancel with a progress ring, the thirteen plots, the 3D drawing, settings and
help). The left panel has five tabs:

- **Setup**: the molecule; the atoms, with a menu of common selections and
  their number of atoms; the frames (all, or a range) and every n-th, with
  their number; the fit; the algorithm, with a note of those the backend
  lacks (and of the library, when it is the one in use); its parameters
  (greyed when they do not apply); **Cluster** runs in the background (with
  the library, VMD waits for it).
- **Results**: the run shown (every clustering is kept: the last 25), in
  words; the table of clusters (frames, share, MSD within, RMSD² from the
  representative, the representative's frame; click a heading to sort,
  right-click for more); the selected clusters in words; Go to
  representative, Overlay in 3D.
- **Scans**: the **Elbow** scan (the Setup's clustering at every k of a
  range) and the **Sweep** (every combination of algorithms, k, metrics and
  seedings), with its table, the best configurations marked.
- **Tools**: **PRIME** (the native-like frame: its four predictions and
  three medoid baselines, double-click to go to one), the **similarity**
  (iSIM of the frames and of each cluster), **Pick frames** (the most
  diverse, the outliers, a representative sample, the medoid or the
  outlier, without clustering; shown in 3D and gone to on their molecule,
  saved as PDB or DCD).
- **3D**: colour by cluster, every representative, an overlay (the selected
  clusters' frames nearest their representative, or frames typed as
  `0-100,500`), the picked frames; the style, atoms and material; the key
  of the clusters' colours.

The plots fill the right side; the **Plot options** panel holds every
setting of the current plot. Both side panels can be hidden. **Settings**
chooses the backend, unlocks the metrics, and sets the text size (8–24
pt), the window size and the theme (automatic, macOS native, flat, VMD's
own — as in DihedralView, InteractionView and Molywood Studio); they are
kept between sessions of VMD.

A cluster has one hue everywhere — blue, red, green, orange, purple, teal …
— drawn in the plots in darker tones (InteractionView's) and in the 3D
window in VMD's colour of that hue, which the plugin never changes (**Plot
options ▸ Cluster colours ▸ VMD's** draws the plots in VMD's own colours
instead); noise is grey. Selecting clusters in the table or a plot draws
them on top in every plot (the others paler), and the 3D overlay follows
the selection.

## Plots

| Tab | Shows |
|---|---|
| **Populations** | the frames of each cluster, or their share; in order or largest first; eQUAL's noise; click to select, double-click to go to the representative |
| **Make-up** | each cluster's frames by group (the method, replica or condition each came from), or each group's by cluster; counts or shares |
| **Timeline** | the cluster of every frame, a lane per cluster (noise at the bottom); or every frame's RMSD² from its representative, coloured by cluster; click to go to a frame |
| **Transitions** | from each cluster to the one lag frames later: probabilities (the share into noise left out of the columns) or counts; the diagonal (staying) on or off |
| **Residence** | how long the trajectory stays in a cluster once it enters it: the mean of its runs of frames, a whisker to the longest; or the number of visits |
| **Compactness** | the MSD within each cluster (MDANCE's), the RMSD² from its representative, the MSD against its size (the medians dashed), or its extended similarity (iSIM) |
| **Distances** | between every two clusters: their mean structures (RMSD²) or their representatives (RMSD) |
| **Tree** | how the clusters join: HELM's merges of its starting clusters (a forest when it stops at k, coloured by the cluster each ends in), or the average linkage of the clusters' mean structures (DIVINE's too, not its splits: the axis says which); or the merges' heights, the largest jump circled |
| **Silhouette** | every frame's silhouette, cluster by cluster, sorted, with the mean |
| **Map** | every frame on the first two principal components of the clustered coordinates, by group or by cluster |
| **Profiles** | atom by atom: each group's or cluster's fluctuations (RMSF), or each cluster's mean structure against the most populated one's |
| **Elbow** | Calinski–Harabasz and Davies–Bouldin at every k of the scan, each on its own axis, and the stability as bars (how alike NANI's seedings cluster); eQUAL by radius; hover a k for its clusters' shares, double-click to make it the clustering |
| **Sweep** | the chosen score of every configuration, a row per algorithm, metric and seeding and a column per k, the best outlined; double-click to make one the clustering |

## Scripting (works in text mode)

```tcl
package require vmdance
# MDANCE's example (pip install mdance): mdance/data/aligned_tau.pdb, aligned_original_tau_6K.dcd, labels_60.csv
mol new aligned_tau.pdb
mol addfile aligned_original_tau_6K.dcd waitfor all
animate delete beg 0 end 0             ;# the PDB's own frame: cluster the DCD's 6001 (VMD's frame = MDANCE's)
vmdance -sel backbone -algorithm kmeans -k 6 -kinit CompSim
# -> run 1 molid 0 sel backbone fit {} frames 6001 ... nclusters 6 sizes {691 1178 985 1177 1149 821} noise 0 ch 1036.1 db 2.04 ...
vmdance clusters                    ;# {cluster frames percent msd msd_to_representative representative} ...
vmdance get 2                       ;# frames, share, representative, silhouette, visits, members ...
vmdance labels                      ;# {frame cluster ...}
vmdance transitions -lag 10         ;# probabilities, k × k
vmdance -sel backbone -algorithm helm -k 6 -initial-labels labels_60.csv
vmdance -sel backbone -algorithm equal -threshold 10
vmdance elbow -sel backbone -kinit CompSim -from 2 -to 15   ;# {index k nclusters ch db sizes status message} ...
vmdance elbow -sel backbone -from 2 -to 15 -stability 1      ;# and each k's stability across NANI's seedings
vmdance elbow load 6                ;# that k made the clustering
vmdance sweep -sel backbone -algorithms {kmeans helm} -from 2 -to 10 -seedings {StratAll CompSim}
vmdance sweep best db
vmdance prime                       ;# {pairwise frame union frame ... medoidAll frame ...}
vmdance similarity                  ;# {isim x clusters {...} least_similar {...}}
vmdance groups -ranges {first 0-2999 second 3000-6000}   ;# where each frame came from (or -file, -names; -colours)
vmdance makeup                      ;# each cluster's frames by group
vmdance map                         ;# the frames on their first two principal components
vmdance profiles                    ;# atom by atom: each group's and cluster's RMSF, each cluster against the largest
vmdance pick -sel backbone -method diversity -param 10
vmdance select 0 3
vmdance draw -colour 1 -overlay 1 -top 10
vmdance goto 3                      ;# VMD's frame to cluster 3's representative
vmdance export results -prefix hepta -items {summary clusters labels representatives trajectories}
vmdance session save hepta.vmdance
```

The clustering options: `-mol -sel -fit -first -last -step -algorithm -k
-metric`, the algorithm's parameters named as `mdance-cli` names them
(`-kinit -percentage -split -anchors -refine -threshold -end-mode
-merge-scheme -eps -trim-start -trim-k -trim-val -min-samples -seed-method
-n-seeds -check-sim -sim-threshold -reject-lowd`, HELM's `-initial
-initial-kinit -initial-percentage -initial-labels`), `-label -quiet`.
`vmdance parameters helm` lists an algorithm's with their defaults and
limits. Subcommands: `info algorithms parameters backend cancel clusters get
labels frame transitions residence silhouette distances tree elbow sweep
prime similarity groups makeup map profiles pick select draw goto userfield
runs run export session figures`. Every option is checked before anything changes, and an error
names the option; a failed, cancelled or refused job keeps what was there.
If the window is open, it shows what the command did. A scan or a pick
takes its own options, the command's defaults where none is given, not the
current run's (the window's Setup follows the run); a scan says what it
reads, and notes when that is not what the current run clustered.
`figures` needs a display (Tk draws them), which text-mode VMD has not:
make them in VMD with its window, from a session saved in text mode if
need be.

## Sessions, export and figures

- **Sessions** (`.vmdance`, gzip-compressed text): every run with what
  was asked of it (PRIME, the similarity), the elbow scan, the sweep, the
  picked frames, the selection and the plots' settings; reopened with their
  molecules (the first that has their frames, among those loaded, or
  loaded from their files, by their names in full, from beside the
  session or as typed) or without them (the
  tables and plots work; the 3D drawing and the questions that read the
  coordinates again wait for the molecule). Each run is checked against
  the molecule it is put on: another trajectory of the same file names, or
  a file written over, is said and its frames refused; the PDB's own frame,
  deleted when it was clustered, is deleted again. Session files are
  data: they are read and checked, never evaluated — the lists counted
  before they are made, held to 400 MB unpacked, and the molecule loaded
  from its files only when they are regular files of one of VMD's own
  readers (never a converter, a download, a shell or a device). A run takes
  some 40 bytes a frame, and `16·k²` bytes for the distances between its `k`
  clusters (300 or fewer: none above), so a **save that would be too large
  to read back is refused and the file left as it was**, naming what to
  drop (runs to delete, the scans or the picks to clear). **File ▸ Import a
  session of the MDANCE plugin** reads the old
  plugin's `.mdance` files the same way and makes each a run, measured from
  its molecule: the one loaded whose coordinates give the file's cluster
  MSDs (the window offers the molecule of Setup when none does). What the
  old plugin did not keep is said, not made up: HELM's merges after a
  trimming are left out (the tree is the linkage), and a configuration of
  its sweep is marked *parameters not recorded*.
- **Export**: a summary; the table of clusters with a `#` header that says
  what was clustered, how and when; every clustered frame's cluster
  (`frame,cluster`: MDANCE's labels, and HELM's starting clusters again);
  each cluster's frames nearest its representative, ranked; the timeline,
  the transitions, the residence, the silhouettes, the distances, the
  tree's merges; PRIME, the similarity, the elbow scan, the sweep, the
  picked frames; the representatives' structures (one per cluster) and each
  cluster's frames as a trajectory of its own (DCD with a PDB of its atoms,
  or PDB, as VMD's writers write them: a DCD keeps every frame's unit
  cell). Frames are VMD's frame numbers; every scan's and the picks' table
  names its backend too. An export is checked whole first, its folder made
  when it does not exist, and its files renamed into place only once all
  are written (a failure changes none), each under a temporary name of its
  own beside it: a link put there is never followed, a file replaced keeps
  its permissions, a read-only one is refused.
- **Figures**: the plots as PDF, PNG or EPS at any size, and the 3D view as
  a PNG (snapshot, TachyonInternal or another of VMD's internal ray tracers).

## Design

VMDance follows DihedralView's, InteractionView's and Molywood Studio's
principles:

- **One package, one command.** `vmdance` opens the window, and its
  options and subcommands do everything the window does.
- **The core without Tk.** `json.tcl`, `molecule.tcl`, `algorithms.tcl`,
  `backend.tcl`, `coords.tcl`, `measures.tcl`, `analysis.tcl`,
  `results.tcl`, `session.tcl`, `export.tcl` and `viz3d.tcl` never use Tk;
  the window's modules are loaded only when it opens. The core is tested in
  `vmd -dispdev text` (the parts that need no molecule in plain `tclsh`
  too).
- **One job at a time, published whole.** A clustering is one value (a
  dict), checked and published at once; a failed, cancelled or refused job
  leaves the current one untouched. The runs, the scans, the picks and the
  selection live in the core too: the window listens to them; it holds no
  results.
- **Never trust what is read.** The backend's output is parsed as JSON (a
  reader of the plugin's own: no regular expressions over the text) and
  checked — as many labels as frames, the sizes those of the labels, every
  representative in its own cluster, numbers that are numbers — before
  anything is published; sessions, the old plugin's sessions, label files
  and preferences are parsed as data, never evaluated.
- **VMD state is borrowed, not taken.** A job never moves VMD's frame or
  its coordinates (a fit is computed on the values); every atom selection
  is made and deleted at the global level, also on errors and on Cancel;
  the plugin draws with representations of its own, found again by their
  names, and deletes only those; it never writes the molecule's data unless
  asked (`vmdance userfield`, **3D ▸ Write the clusters to the user
  field**); structure exports make no molecule (VMD's top one and its view
  are left alone).
- **Responsive.** A job runs in a coroutine: the frames are read in slices
  of 40 ms, `mdance-cli` runs in the background (Cancel stops it and what
  it started: TERM, then KILL 1.5 s later if it is still the same job, so
  that a finished job's process numbers are never signalled; what it prints
  is read 16 KB at a time, and the job ends when its processes have, even
  one that closed its output first), the plugin's measures after it run in
  slices too (long with thousands of clusters: they say how far they are,
  and Cancel stops them), and the plots' frame markers are refreshed at
  most every 120 ms.

Choices of this plugin:

- **The backend's science, as the reference.** The clusterings are
  CPP-MDANCE's; the tests run `mdance-cli` directly on the coordinates the
  plugin gives it and compare every label, compare the library with the
  program, the plugin's measures with direct computations, and the plugin's
  clusterings with MDANCE's published runs (the Python reference: a
  tau peptide, 6001 frames, and protein G, 1923), on the atoms those runs
  cluster (the Cα).
- **The frames are VMD's.** A result holds the VMD frames it clustered, and
  every per-frame list is in their order: a range or a step never shifts a
  label onto another frame, and every table, plot and export says VMD's
  frame numbers.
- **Measured once.** The plugin's measures are computed when the
  clustering is made, from the coordinates the backend clustered (VMD's
  vector commands, in C, in two passes over the frames: the memory of 2k
  frames, and of the k × k distances between the clusters, made for 300
  clusters or fewer), and kept with it: a session reopened without its
  molecule still shows every plot. A scan's records keep the clustering; a
  record made the clustering is measured then.

## Differences from the MDANCE plugin

- **One command**, `vmdance`, instead of `mdance::gui` and internal
  procedures; the menu entry is **Analysis ▸ VMDance**. The two plugins
  can be loaded side by side.
- **Colour by cluster** draws a representation of the plugin's own in the
  colour of the current frame's cluster (VMD's colour of its id), which
  follows the trajectory; the old plugin wrote every atom's user field and
  redefined VMD's BGR colour scale, and did not put them back. Writing the
  user field is still there, asked for (`userfield`), and noise is grey,
  not the lowest colour of the scale.
- **Every clustering is kept** as a run (the old plugin kept one), with
  PRIME and the similarity asked of it; sessions keep every run, the scans
  and the picks (`.vmdance`; the old `.mdance` files are imported).
- **Checked before running**: NANI's seeding limit (k seeds from the
  densest share of the frames), HELM's starting clusters and trim, DIVINE's
  crashing combination, its first split's seeds, its metric, its smallest
  share and `-end-mode points`, eQUAL's radius, a metric other than MSD
  with the
  diversity selection, numbers the backend cannot read, the frames,
  coordinates that are not numbers, and a selection whose atoms could
  change with the frame (the old plugin noticed only a change in their
  number).
- **The backend's output is checked whole** in every mode (the old plugin
  skipped the checks in library mode, in the sweep and in the elbow scan),
  by a JSON reader rather than regular expressions.
- **HELM's scores with a trim** are those of its clustered frames, as
  MDANCE's and eQUAL's are: CPP-MDANCE's, which the old plugin showed,
  count the trimmed frames as one more cluster.
- **Scans**: the elbow scan uses the Setup's parameters (the old one always
  StratAll 10% and MSD), keeps every k's clustering, and runs HELM from the
  same starting clusters at every k; a value its parameters cannot take is
  recorded as not run, and the others go on. The sweep can include HELM,
  and reads its seedings for HELM's first clustering (HELM from a label
  file, which makes none, is run once at each k, its seeding *none*). Any
  record can be made the clustering.
- **The measures**: the silhouette of every frame (the old plugin sampled
  200 per cluster), from the RMSD to the mean structures (the old plugin
  squared them: its values read higher, 0.62 against 0.39 on 3ptb's Cα at
  k 4), 0 for a frame alone in its cluster; every frame's RMSD² from its representative, kept (the
  old plugin computed it for the overlay only); the representatives' and
  the mean structures' distances, kept.
- **Label files**: two-column files are read by the rows of the clustering
  (MDANCE's own) or by VMD's frames (the plugin's export of a range or a
  step, which the old plugin refused).
- **HELM's tree** numbers the merges as scipy numbers a linkage (merge j
  is node n + j, n the starting clusters). CPP-MDANCE numbers them from the
  starting clusters left after trimming, so that a merge and a starting
  cluster can have the same number; the plugin tells them apart (by what is
  still unmerged and by the row's count) for the Tree plot, the `tree`
  command and the export. The result keeps the backend's rows (`zmatrix`).
- **Fit to the first frame** is new (the old plugin clustered the
  coordinates as they were, which is still the default).
- **DIVINE's Refine** is off and greyed (the old plugin's was on): it
  changed nothing with NANI's splits, which are k-means already, and
  CPP-MDANCE's DIVINE crashes refining the other anchors'. Its metric is
  MSD, and its *Threshold* is the smallest share of the frames a split
  leaves on each side (*Smallest share*), greyed with NANI.
- **Settings are kept** between sessions of VMD (the backend, the metrics'
  lock, the text size, the theme); the text size applies to the whole
  window (the old one could not reach VMD's ttk widgets).
- **Plots** are thirteen tabs of one window with their options in one panel;
  the Cluster MSD, MSD/Pop and similarity plots are the views of
  Compactness, and the centroid distances and representatives' RMSD the
  views of Distances.

Not carried over: the narrated walkthrough (`demo/`), the installer that
edited `~/.vmdrc` (a line to add, above), and PostScript output under that
name (EPS instead).

## Layout

```
vmdance/
  pkgIndex.tcl, vmdance.tcl   package, menu entry, scripting command
  lib/json.tcl         the backend's JSON, read as data
  lib/molecule.tcl     reading VMD: selections at the global level, frames, molecule records
  lib/algorithms.tcl   the algorithms: parameters with defaults and limits, their checks, the backend's arguments, label files
  lib/prefs.tcl        the preferences kept between sessions of VMD (the window's, the backend chosen in Settings), read as data
  lib/backend.tcl      finding CPP-MDANCE (the preferences' first), what it was built with, running mdance-cli in the background, private files
  lib/coords.tcl       the coordinates clustered: the same atoms at every frame, the fit, the rows kept
  lib/measures.tcl     the plugin's measures: RMSD² from the representatives, distances, silhouettes, runs, transitions, linkage
  lib/analysis.tcl     requests and their checks; the jobs (cluster, elbow, sweep, adopt, import, PRIME, similarity, pick); the backend's output checked
  lib/results.tcl      the clusterings in memory, runs, scans, picks, the selection, queries
  lib/session.tcl      session files; the MDANCE plugin's, imported
  lib/export.tcl       result files: tables, structures
  lib/viz3d.tcl        the 3D drawing: colour by cluster, representatives, overlay, picks
  lib/fonts.tcl        one font family and size
  lib/theme.tcl        the window's looks: native, flat, VMD's own
  lib/tooltip.tcl, lib/icons.tcl, lib/colormaps.tcl, lib/plotlib.tcl   (InteractionView's)
  lib/plots.tcl        the plots of the clusters and the scans
  lib/plots_groups.tcl the plots of the groups and the coordinates: make-up, map, profiles
  lib/figures.tcl      figures (PostScript, Ghostscript) and the 3D view as a picture
  lib/gui.tcl          main window: menus, toolbar, the Setup, Results, Scans, Tools and 3D tabs, running jobs
  lib/gui_opts.tcl     the Plot options panel; showing and hiding the side panels
  lib/gui_io.tcl       sessions, import, export, figures and render dialogs
  icons/               icon PNGs; make_icons.py draws them (the application's, app_*: docs/tools/make_logo.py)
tests/
  common.tcl           shared: paths, the systems, the backends, check
  fake_mdance_cli      a deterministic stand-in for mdance-cli, with hooks for failures
  fixtures/            small multi-model PDBs; sessions of the MDANCE plugin (make_old_sessions.tcl)
  test_core.tcl        the JSON reader, parameters and checks, arguments, label files, a result's checks, runs, sessions as data (tclsh or VMD)
  test_jobs.tcl        the jobs with the fake backend: requests, frames, output checks, failures, Cancel, scans, questions, the coordinates
  test_results.tcl     the command's questions, runs, the 3D drawing, exports and structures
  test_session.tcl     sessions with their molecules, hostile files, imported sessions, preferences
  test_reference.tcl   the real backend: its own labels, program and library, measures by hand, MDANCE's published runs
  test_hardening.tcl   what the reviews found, kept from coming back: files, inputs, the lifecycle, the science
  test_hardening2.tcl  sessions' security and limits: molecule files checked, lists counted, saves bounded, no expr ?: on typed strings;
                       the backend's process: its private folder, Cancel through a launcher, its output, a stop from outside;
                       what reaches the backend: coordinates that are not numbers, numbers out of its range, the metric with
                       the diversity selection, the picks' counts; the library's limits; the preferences in a script; Settings' trial;
                       files and exports; the clustered frames and their molecule: sessions checked against it, frames moved
                       or deleted under a clustering, the drawing and the picks, a selection's atoms, imports
  test_hardening2_*.tcl  what the reviews of the second round's fixes found, a suite each (fx_g1 to fx_g5, g6 to g9, h1, oi, h3,
                       h4: docs/tests.rst says what each keeps); g9's, what the window's fixes ask of the core
  test_groups.tcl      the groups and their colours, the make-up, the map (numpy's PCA), the profiles, the scans' stability,
                       eQUAL's radius scan, HELM's merges' heights, each against a direct computation (the real backend)
  test_gui.tcl         windowed: the window, clustering, cancelling, every plot, scans, tools, 3D, files, figures, themes
  run_all.sh           every suite
docs/                  Sphinx documentation
  _static/logo/        the logo: the wordmark (light and dark backgrounds) and its mark, SVG and PNG
  tools/make_logo.py   draws them, and the window's icon
TESTING.md             what to check by hand
```

## Tests

Run from the repository's root:

```sh
tclsh tests/test_core.tcl | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_core.tcl      < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_jobs.tcl      < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_results.tcl   < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_session.tcl   < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_reference.tcl < /dev/null | grep -E "FAIL|SKIP|RESULT"
vmd -dispdev text -e tests/test_hardening.tcl < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_hardening2.tcl < /dev/null | grep -E "FAIL|RESULT"
vmd -dispdev text -e tests/test_groups.tcl    < /dev/null | grep -E "FAIL|SKIP|RESULT"
for g in fx_g1 fx_g2 fx_g3 fx_g4 fx_g5 g6 g7 g8 g9 h1 oi h3 h4; do vmd -dispdev text -e tests/test_hardening2_$g.tcl < /dev/null | grep -E "FAIL|RESULT"; done
VMDANCE_OUT=/tmp/mdv vmd -dispdev win -e tests/test_gui.tcl < /dev/null; grep -E "FAIL|RESULT" /tmp/mdv/gui.log
sh tests/run_all.sh                           # all of them
```

The fake backend (`tests/fake_mdance_cli`, Python 3) drives the jobs,
results, session and window suites. The jobs, reference and hardening
suites load the shared test systems (`VMDANCE_SYSTEMS`: 3ptb, 100 frames).
The reference suite needs a real CPP-MDANCE build (`MDANCE_CLI`,
`MDANCE_LIB`, else the build beside the plugin's folder) and MDANCE's
reference runs (`MDANCE_REF_RUNS`: `inputs/` and `results/` of the tau
peptide, which the runs call the heptapeptide, and protein G); g8 checks
README's numbers on MDANCE's data (`MDANCE_DATA`, the package's
`mdance/data`). What is missing there is skipped, and says so; so are a
few checks of g7, g8 and h4 that read files kept outside the repository.
The windowed suite needs a display (`Xephyr :9 -screen 1600x1200x24 -ac &`
then `DISPLAY=:9`). Current results: 140, 110, 67, 42, 33, 31, 194 and 219
checks (core, jobs, results, session, reference, hardening, hardening2,
gui), 384 in the second round's thirteen group suites, and 99 in the
groups suite (the real backend), all passing in
VMD 2.1 (Linux); the core suite also in `tclsh` 8.6. End to end
(`DISPLAY=:9 sh tests/e2e/run_e2e.sh`: four phases, each in a new VMD, with
the real backend): 29, 14, 15 and 10 checks, passing. The reference suite skips
three: DIVINE's comparisons with the program and the library (not in this
CPP-MDANCE build), and one of MDANCE's results that CPP-MDANCE does not
reproduce, KMeans NANI seeded at a stratified position on a half (3ptb's
Cα, frames 0–49, k 4): recorded, not asserted. What no suite can decide is in
`TESTING.md`.

## Notes and limits

- The library blocks VMD while it clusters (the status line says so), and
  a call cannot be cancelled (Cancel acts when it ends): use the program
  for long trajectories.
- A clustering writes every frame's coordinates to a file of the plugin's
  private folder (3 × atoms numbers per frame: the program's input, written
  with the library too), kept for the questions that follow; the plugin's
  measures read them again from VMD in two passes, so a trajectory of any
  length takes the memory of a few frames (6002 frames of 217 atoms: 9 MB,
  5.5 s with KMeans NANI and the measures). A folder that cannot take the
  file says so (free room there, or set `TMPDIR`).
- The distances between the clusters (k × k: their mean structures and
  their representatives) and the tree of the mean structures are made for
  300 clusters or fewer: the thousands of clusters eQUAL makes at a small
  radius would take gigabytes of VMD's memory, kept until it quits
  (`vmdance distances` and `tree` then say so; HELM's tree is its
  merges, at any number). An export then leaves them out, and the
  transitions too unless named (k² rows). The measures left grow with the
  frames and the clusters: a frame's silhouette needs the nearest other
  cluster's mean structure, looked for among those the triangle inequality
  leaves, not every one (4000 frames of 60 atoms in 1462 clusters: 14 s,
  35 s against every one); they say how far they are, and the window's
  Cancel stops them.
- The library is given the coordinates as one Tcl list, the same for every
  call of a job (a scan reads the frames for it once), of which
  CPP-MDANCE's Tcl binding makes a text once: a call takes about 180 bytes of
  VMD's memory a coordinate at its peak, and Tcl keeps about 120 of them
  until VMD quits (for the calls after); past 2 GB of text (about 110
  million coordinates: 20,000 frames of 1,900 atoms) Tcl ends VMD, whatever
  the memory. A library call that cannot fit (the memory available to VMD,
  its cgroup's too) or would pass 2 GB is refused, before the frames are
  read when it can be told: the program takes neither.
- The private folder (in `TMPDIR`, readable by you only) is named for the
  machine, its PID namespace and the VMD process, with a random part: a
  `TMPDIR` shared by machines or containers is safe, and what a VMD that
  was killed or crashed left there is removed by the next one of the same
  machine and namespace. VMD writes there too (structures, the 3D view),
  and opens a file by its name's UTF-8 bytes, where Tcl takes the locale's
  (iso8859-1 with `LANG=C`): VMD is given the name whose UTF-8 bytes are
  the file's, so a `TMPDIR`, or a session's molecule, outside ASCII works
  with `LANG=C`. A `TMPDIR` whose name is not UTF-8, with a locale that is
  not, is passed over (said if no private folder can be made elsewhere).
- `mdance-cli` ended from outside (Ctrl+C at VMD's terminal, `kill`) stops
  the whole job, a scan too, as Cancel does, and what was there is kept; a
  crash of it fails that clustering, and a scan goes on.
- MDANCE's published runs cluster the Cα atoms. On those atoms the plugin
  reproduces their populations exactly (KMeans NANI k 6 with three seedings,
  HELM from MDANCE's 60 starting clusters; the tau peptide, which the runs
  call the heptapeptide, and protein G) and their elbow screens' labels,
  but at two kinds of k: scikit-learn's k-means (MDANCE's) stops at its
  tolerance where CPP-MDANCE's goes on to convergence (the tau peptide,
  k 5), and CPP-MDANCE's leaves an emptied cluster empty (protein G from
  k 12: 1 to 6 empty). On the backbone the shares differ by up to 0.009
  (CompSim: 0.086): another choice of atoms, not another program.
- The stratified seedings take frames at evenly spaced positions: where
  one falls on a half (50 frames at 10%: 24.5), CPP-MDANCE rounds it away
  from zero and MDANCE (NumPy) to even, and the seeds and clusters differ
  (3ptb's Cα, frames 0–49, KMeans NANI k 4: 19 11 10 10 frames against
  25 11 10 4; DIVINE's splits of some sizes, and HELM's first clustering,
  too). It depends on the number of frames and of seeds: more often with
  few frames or many seeds. The reference suite records it.
- DIVINE (a CPP-MDANCE built with it): its smallest share is applied to
  the pair anchors' splits only, and rounded where MDANCE truncates it (0.035
  of 100 frames: 4 frames, MDANCE's 3, and another clustering); its Tree is
  the average linkage of the mean structures, not its splits, which
  CPP-MDANCE does not return; with `-end-mode points` it returns the last
  clustering only, not MDANCE's scores at every split (an elbow scan with
  `-end-mode k` gives them). A later split of a cluster too small to seed
  fails the run (with CompSim, crashes the program: the library is refused
  CompSim below 50% above k 2).
- KMeans NANI seeded by CompSim can end with an empty cluster: CPP-MDANCE's
  k-means does not move a cluster that loses its frames (scikit-learn's, in
  MDANCE's Python, does). On a constructed three-state trajectory whose
  densest frames are all in one state, it merges two states. The plugin
  shows the empty cluster, with no representative, MSD or similarity (the
  backend's 0 would read as the tightest), and a scan's record counts the
  clusters with frames (`nclusters`, the tables' k_actual).
- `-metric` other than MSD is passed on as it is: those indices are for
  binary or fingerprint data, not Cartesian coordinates. With the seedings
  and the pick that use the diversity selection (CompSim, DivSelect,
  eQUAL's comp_sim, the most diverse frames) it is refused: on coordinates
  CPP-MDANCE reads past its data there (`mdance-cli` crashed, or every
  frame landed in one cluster), and MDANCE's Python stops. With eQUAL it is
  refused whatever the seeds: on coordinates every frame is within any
  radius of the seed by those indices, and all landed in one cluster.
- Only VMD 2.1 on Linux has been tried; the window's macOS and Windows looks
  come from the reference plugins' theme code but are untested here.

## Credits

The clustering is not this plugin's: the algorithms — KMeans NANI, DIVINE,
HELM, eQUAL, PRIME and the extended (n-ary) similarity — are
[MDANCE](https://github.com/mqcomplab/MDANCE)'s (the Miranda-Quintana
group, MIT), run by [CPP-MDANCE](https://github.com/mqcomplab/CPP-MDANCE)
(© 2025 Andrey Nikitin, MIT). The host is
[VMD](https://www.ks.uiuc.edu/Research/vmd/) (Theoretical and Computational
Biophysics Group, UIUC). This plugin © 2026 Diego Gomes (MIT). If you use
MDANCE or VMD in published work, cite them as each project asks.
