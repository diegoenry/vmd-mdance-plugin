The algorithms
==============

The clustering is MDANCE's, as its C++ port CPP-MDANCE runs it: the plugin
passes the coordinates and the parameters, and reads the answer. Every
parameter, with its default and limits, is on :doc:`parameters`.

What is clustered
-----------------

Each frame is one row: the x, y, z of every atom of the selection, in the
selection's order (3 × atoms numbers). The same atoms are read at every
frame. The rows are clustered as they are — MDANCE expects an aligned
trajectory — unless *Fit to the first frame* (``-fit selection``)
superposes each frame on the first clustered one by those atoms first; the
fit is computed on the values (VMD's ``measure fit``), and VMD's own
coordinates never move. Coordinates that are not numbers (NaN or infinite:
a simulation that blew up, a damaged file) are refused as they are read,
naming the VMD frame and its first such atom: leave the frame out
(``-first``, ``-last``, ``-step``) or delete it. (``mdance-cli`` named a
row of its input, and the library took an infinity and answered.)

The metric
----------

``MSD``, the mean square deviation, is the metric of Cartesian coordinates:
MDANCE's extended MSD of a set of frames is the mean over every pair of
frames, each with itself too, of their squared distance per atom — twice
the mean squared distance from their mean structure, and for two frames
half their RMSD². The other ten indices (``BUB Fai
Gle Ja JT RT RR SM SS1 SS2``) are binary and extended similarities, meant
for fingerprint-like data; Settings unlock them in the window, and the
command takes them as they are — but with what uses CPP-MDANCE's diversity
selection: the seedings ``CompSim`` and ``DivSelect`` (KMeans NANI's, HELM's
first clustering's), eQUAL's ``comp_sim`` seeds and the most diverse frames
(:doc:`tools`). On coordinates its indices fall below what the selection
starts from, and it reads past its data (``mdance-cli`` crashed, or every
frame landed in one cluster that looked a success); MDANCE's Python stops
there too. The plugin refuses those, and says what to use instead. eQUAL
takes MSD only: by the other indices every frame is within any radius of
the seed on coordinates, and all landed in one cluster, whatever the seeds.
DIVINE takes MSD only (below).

KMeans NANI
-----------

k-means with *N-ary natural initiation*: the k seeds are chosen by
MDANCE's extended similarity — stratified over all the frames
(``StratAll``, the default), stratified among the densest (``StratReduced``),
by complementary similarity (``CompSim``), by diversity selection
(``DivSelect``) — or by k-means++ and at random. The extended-similarity
seedings draw the seeds from a share of the frames (``-percentage``, 10%):
k must be at most that share of the frames (k 10 at 10% needs 100 frames).
The plugin checks it and says what to raise. The stratified seedings take
the frames at evenly spaced positions of that share: CPP-MDANCE rounds a
position half away from zero where MDANCE (NumPy) rounds half to even, so
when one falls on a half among the first k (50 frames at 10%: 24.5, at k 3
or more) the seeds, and the clusters, differ from MDANCE's (3ptb's Cα,
frames 0–49, k 4: 19 11 10 10 frames against 25 11 10 4). The reference
suite records it.

DIVINE
------

Divisive: the whole trajectory split in two, then the cluster chosen by
``-split`` (the largest weighted MSD, the largest MSD, the widest), until k
clusters. A split is a two-cluster NANI (``-anchors NANI``, seeded by
``-kinit`` from the densest ``-percentage`` of the cluster's frames) or
starts from the cluster's two most distant frames (``OutlierPair``,
``SplinterPair``). It splits by MSD: MDANCE's DIVINE has no metric, and
CPP-MDANCE's would use another only to choose the representatives, so
``-metric`` is MSD (another is refused; a sweep keeps DIVINE with another
metric as *not run*).

``-threshold`` is the smallest share of all the frames each side of a split
keeps (MDANCE's minimum size of a cluster; 0: no limit): DIVINE stops before
k when no cluster can be split so, and the summary says so. CPP-MDANCE
applies it to the OutlierPair and SplinterPair splits only — with NANI it is
refused — and rounds share × frames where MDANCE truncates (0.035 of 100
frames: 4 frames, MDANCE's 3); a share that no split can leave on both
sides (above 0.5, or 0.5 of an odd number of frames) is refused.
``-end-mode points`` does not use k: the splits go on until none leaves
that share on each side, MDANCE's stopping rule. It takes the pair anchors
and a share of 2 frames or more (else every frame ends alone: NANI's splits
are not stopped by the share, and fail first on clusters too small to
seed; the refusal suggests 0.05, at most 20 clusters, as CPP-MDANCE's
splits slow with the square of their number); a scan does not take it.

MDANCE refines the pair anchors' splits with k-means (``-refine``);
CPP-MDANCE's DIVINE reads out of bounds when it does, so they run
unrefined: ``-refine 1`` with them is refused, and Refine is off by
default. A NANI split is a k-means already, which ``-refine`` does not
change.

With the extended-similarity seedings (StratAll, StratReduced, CompSim,
DivSelect), a NANI split of m frames draws its two seeds from
floor(m × percentage / 100) of them, so a cluster of fewer than 200 /
percentage frames (20 at 10%) cannot be split. The plugin checks the first
split, of every frame; a later one fails the run ("DIVINE chose to split a
cluster of fewer than 20 frames …"): raise the percentage, seed with
KmeansPP or Random, or ask for fewer clusters. With CompSim a cluster of
fewer than 100 / percentage frames crashes CPP-MDANCE instead: the program
fails that clustering, saying so, and the library, which would take VMD
with it, is refused CompSim below 50% above k 2 (the first split alone,
which the plugin checks); a scan keeps such a k or configuration as *not
run*.

The Tree plot of a DIVINE clustering is the average linkage of its
clusters' mean structures, not its splits, which CPP-MDANCE does not
return. CPP-MDANCE builds DIVINE only with ``BUILD_DIVINE``.

HELM
----

Agglomerative: HELM starts from many small clusters — those of a first
NANI clustering (``-initial`` 50 of them, seeded ``StratAll``), or a label
file's (``-initial-labels``: one label per clustered frame, or
``frame,label`` rows as MDANCE writes them) — and merges the most similar
pair (``Inter``), the pair whose union stays most compact (``Intra``), or a
mix (``Half``), until k remain (``-eps -1``), or until the closest pair is
farther than ``-eps`` (``-k 0``): one of the two. It can first leave out the loosest starting clusters
(``-trim-start 1`` with ``-trim-k``, a number, or ``-trim-val``, an MSD) and
those smaller than ``-min-samples``. The starting clusters are counted as
the backend gets them, before HELM runs: more than k must have frames (a
first clustering can leave some empty), and with a trim, more than k must
be left by ``-min-samples`` (first) and ``-trim-k``; else the request is
refused, naming what to change (a scan keeps that k as not run).
``-trim-val``'s cut is an MSD the backend computes: what it left is
counted once HELM has run, and refused so too. Its
merges make the Tree plot: a forest when it stops at k.

eQUAL
-----

Extended quality: a cluster grows from a seed (the medoid of what is left,
or the frames of highest complementary similarity) and takes the frames
within ``-threshold`` (the radius: MDANCE's MSD of the frame and the seed,
Å², half their RMSD²: a frame joins when its RMSD² to the seed is at most
twice the radius) of it; the next cluster
grows from what is left. The number of clusters follows from the radius;
frames outside every cluster are *noise* (label -1, grey everywhere).
Optionally small clusters are rejected as noise (``-reject-lowd``), and the
growth stops at the first cluster whose MSD is above ``-sim-threshold``
(``-check-sim``: a ceiling; that cluster and every frame left become noise,
and 0 is refused, as it makes every frame noise). eQUAL never places its
last frame or two: they are noise too. There is no k.

What comes back
---------------

For every frame its cluster; for every cluster its size, its
representative (MDANCE's medoid, by complementary similarity: nearly always
the frame nearest the cluster's mean structure), and its MSD within
(MDANCE's; none for a cluster without frames, for which CPP-MDANCE writes
0); the Calinski–Harabasz score (between-cluster over within-cluster
dispersion: higher is better) and the Davies–Bouldin score (the mean, over
the clusters, of the worst ratio of spreads to separation: lower is
better) of the clustered frames, as scikit-learn computes them — none with
fewer than two clusters, nor with every cluster a frame alone
(scikit-learn takes 2 to n − 1 clusters: CPP-MDANCE's 0, or 1 and 0, are
not kept as scores); eQUAL's noise is left out by the backend, HELM's
trimmed frames by the plugin, which scores HELM's clustered frames itself
(CPP-MDANCE counts the trimmed frames as one more cluster); for HELM its
merges. The plugin checks it all before
publishing: as many labels as frames, each a cluster or noise, the sizes
those of the labels, every representative a frame of its own cluster, the
numbers numbers (a score that is not finite is no score).

What the plugin measures
------------------------

From the same rows, once per clustering, and kept with it:

- every frame's **RMSD² from its cluster's representative** (Å², per atom,
  no fit: twice MDANCE's MSD of the pair);
- the RMSD² between every two **representatives**, and between every two
  clusters' **mean structures** (the mean of their frames' rows);
- every frame's **silhouette** from the mean structures: a the RMSD from
  its own cluster's mean, b from the nearest other one, (b − a) / max(a,
  b), from -1 (closer to another cluster) to 1 (well inside its own); 0
  for a frame alone in its cluster. It is not scikit-learn's, which
  averages the distances to every frame of each cluster: this one reads
  higher (0.39 against 0.19 on 3ptb's Cα at k 4), and the MDANCE plugin's
  squared a and b (0.62 there).

From the labels alone: the **runs** of consecutive clustered frames in one
cluster (visits and residence), the **transitions** between clusters.
