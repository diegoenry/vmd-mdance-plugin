.. This page is written by docs/tools/gen_parameters.tcl from the plugin's
   table of parameters (lib/algorithms.tcl): edit that, and run it again.

Parameters
==========

Every parameter is an option of the command (``-name value``), a field of
the window's Setup tab, and — but for the few that are the plugin's own —
an option of ``mdance-cli`` of the same name (``--name``). Its default is
the MDANCE plugin's (but DIVINE's Refine: :doc:`algorithms`).
``vmdance parameters algorithm`` lists them in a
script. A number is 0, or between 1.2e-38 and 3.4e38 in size:
``mdance-cli`` reads HELM's as C floats, the others as doubles, and fails
on one beyond (a session's run that holds one still opens).

KMeans NANI
-----------

K-means with N-ary natural initiation: k clusters, seeded by extended similarity.

``-k``: the number of clusters (default 10). ``-metric``: see :doc:`algorithms`.

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-kinit``
     - ``StratAll``
     - ``StratAll``, ``StratReduced``, ``CompSim``, ``DivSelect``, ``KmeansPP``, ``Random``, ``VanillaKmeansPP``
     - **Seeding**: How the k initial centres are chosen: NANI's stratified and complementary-similarity schemes, diversity selection, or the usual k-means++ and random
   * - ``-percentage``
     - ``10``
     - whole number, 1 to 100
     - **Seeds from %**: The share of the frames the seeds are drawn from (the extended-similarity seedings: StratAll, StratReduced, CompSim, DivSelect; k-means++ and random do not use it): k must be at most this share of the frames

DIVINE
------

Divisive hierarchical clustering: the trajectory split in two, cluster by cluster, until k clusters.

``-k``: the number of clusters (default 3). ``-metric``: MSD only (see :doc:`algorithms`).

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-split``
     - ``WeightedMSD``
     - ``WeightedMSD``, ``MSD``, ``Radius``
     - **Split**: Which cluster is split next: the largest mean square deviation weighted by size, the largest one, or the widest
   * - ``-anchors``
     - ``NANI``
     - ``NANI``, ``OutlierPair``, ``SplinterPair``
     - **Anchors**: How a cluster is split in two: by a 2-cluster NANI, or from its two most distant frames
   * - ``-kinit``
     - ``StratAll``
     - ``StratAll``, ``StratReduced``, ``CompSim``, ``DivSelect``, ``KmeansPP``, ``Random``, ``VanillaKmeansPP``
     - **Seeding**: NANI's seeding for the splits (Anchors: NANI)
   * - ``-refine``
     - ``0``
     - 0 or 1
     - **Refine with k-means**: MDANCE refines the OutlierPair and SplinterPair splits with k-means; CPP-MDANCE's DIVINE reads out of bounds when it does, so they run unrefined. A NANI split is a k-means already: Refine changes nothing there
   * - ``-threshold``
     - ``0``
     - number, at least 0
     - **Smallest share**: A split is made only when each side keeps at least this share of all the frames (0: no limit; at most 0.5, below it for an odd number of frames). CPP-MDANCE applies it with Anchors OutlierPair and SplinterPair only, and rounds share × frames where MDANCE truncates
   * - ``-end-mode``
     - ``k``
     - ``k``, ``points``
     - **Stop when**: k clusters are reached, or (points: k not used) no cluster can be split leaving the smallest share on each side
   * - ``-percentage``
     - ``10``
     - whole number, 1 to 100
     - **Seeds from %**: The share of a cluster's frames NANI's seeds are drawn from, at each split (StratAll, StratReduced, CompSim, DivSelect): a cluster of fewer than 200 / this many frames cannot be split

HELM
----

Hierarchical agglomerative clustering: the many small clusters of a first NANI clustering merged until k remain.

``-k``: the number of clusters (default 10; 0: stop by ``-eps`` only). ``-metric``: see :doc:`algorithms`.

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-initial``
     - ``50``
     - whole number, at least 2
     - **Start from**: The number of clusters of the first NANI clustering, which HELM merges down to k (the plugin's own: not passed to the backend)
   * - ``-initial-kinit``
     - ``StratAll``
     - ``StratAll``, ``StratReduced``, ``CompSim``, ``DivSelect``, ``KmeansPP``, ``Random``, ``VanillaKmeansPP``
     - **Their seeding**: The seeding of the first NANI clustering (the plugin's own: not passed to the backend)
   * - ``-initial-percentage``
     - ``10``
     - whole number, 1 to 100
     - **Their seeds from %**: The share of the frames the first NANI clustering's seeds are drawn from: the starting clusters must be at most this share of the frames (extended-similarity seedings) (the plugin's own: not passed to the backend)
   * - ``-initial-labels``
     - (none)
     - a file
     - **Or from a file**: Start from the clusters of a label file instead (one label per clustered frame, or frame,label rows; # comments) (the plugin's own: not passed to the backend)
   * - ``-merge-scheme``
     - ``Inter``
     - ``Inter``, ``Intra``, ``Half``
     - **Merge**: Which two clusters merge next: the most similar pair (Inter), the pair whose union stays most compact (Intra), or a mix (Half)
   * - ``-eps``
     - ``-1``
     - number
     - **Stop at**: Stop merging when the closest pair is less similar than this, with k 0 (-1: merge until k; one of the two stops HELM, not both)
   * - ``-trim-start``
     - ``0``
     - 0 or 1
     - **Trim first**: Leave out the loosest starting clusters before merging
   * - ``-trim-k``
     - ``0``
     - whole number, at least 0
     - **Leave out**: Trim: the number of loosest starting clusters (largest MSD) left out
   * - ``-trim-val``
     - ``0``
     - number, at least 0
     - **Or above MSD**: Trim: leave out the starting clusters whose MSD is above this
   * - ``-min-samples``
     - ``0.01``
     - number, at least 0
     - **And smaller than**: Trim: also leave out starting clusters smaller than this (below 1: a share of the frames)

eQUAL
-----

Extended quality clustering: clusters grown within a radius, their number following from it; frames outside every one are noise.

No ``-k``: the number of clusters follows from the radius. ``-metric``: MSD only (see :doc:`algorithms`).

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-threshold``
     - (needed)
     - number, at least 0
     - **Radius**: MDANCE's MSD (Å²) within which a frame joins a cluster's seed — for two frames half their RMSD²: a frame joins when its RMSD² to the seed is at most twice the radius; the number of clusters follows from it (try 1)
   * - ``-seed-method``
     - ``medoid``
     - ``medoid``, ``comp_sim``
     - **Seeds**: Where each cluster starts: the medoid of what is left, or the frames of highest complementary similarity
   * - ``-n-seeds``
     - ``1``
     - number, at least 0
     - **Seeds tried**: How many seeds are tried for each cluster (below 1: a share of the frames)
   * - ``-percentage``
     - ``10``
     - whole number, 1 to 100
     - **Seeds from %**: The share of the densest frames the seeds come from (comp_sim)
   * - ``-reject-lowd``
     - ``0``
     - 0 or 1
     - **Reject small clusters**: Leave clusters smaller than Min. size as noise
   * - ``-min-samples``
     - ``10``
     - number, at least 0
     - **Min. size**: The smallest cluster kept (Reject small clusters; below 1: a share of the frames)
   * - ``-check-sim``
     - ``0``
     - 0 or 1
     - **Check similarity**: Stop at the first cluster whose MSD is above the value below: it and every frame left become noise
   * - ``-sim-threshold``
     - ``0``
     - number
     - **Largest MSD**: The largest MSD (Å², MDANCE's) a cluster may have (Check similarity): a ceiling; 0 makes every frame noise

PRIME
-----

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-metric``
     - ``RR``
     - ``RR``, ``SM``
     - **Similarity**: The n-ary similarity index PRIME scores frames with: Russell–Rao or Sokal–Michener
   * - ``-trim-frac``
     - ``0.1``
     - number, 0 to 0.99
     - **Trim**: The share of the largest cluster's (c0's) least representative frames left out before its frames are scored; the other clusters are used whole
   * - ``-weighted``
     - ``1``
     - 0 or 1
     - **Weight by size**: Weight each cluster's score by its number of frames

Similarity (iSIM)
-----------------

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-metric``
     - ``MSD``
     - ``MSD``, ``BUB``, ``Fai``, ``Gle``, ``Ja``, ``JT``, ``RT``, ``RR``, ``SM``, ``SS1``, ``SS2``
     - **Metric**: The extended similarity index (MSD: the mean square deviation)

Frame picks
-----------

.. list-table::
   :header-rows: 1
   :widths: 18 12 22 48

   * - Option
     - Default
     - Values
     - Meaning
   * - ``-method``
     - ``diversity``
     - ``diversity``, ``outliers``, ``repsample``, ``medoid``, ``outlier``
     - **Method**: Most diverse: a subset spread over the conformations; outliers: the least similar frames; representative sample: frames drawn evenly over the similarity; the medoid or the outlier: one frame
   * - ``-param``
     - ``10``
     - number, at least 0
     - **How many**: Most diverse: a whole percentage of the frames (1–100); outliers: a number of frames, or a share (below 1) that holds one at least; representative sample: a number of frames, or a share (below 1; one frame at least)
   * - ``-nbins``
     - ``10``
     - whole number, 2 to 100
     - **Bins**: Representative sample: the number of similarity bins
   * - ``-metric``
     - ``MSD``
     - ``MSD``, ``BUB``, ``Fai``, ``Gle``, ``Ja``, ``JT``, ``RT``, ``RR``, ``SM``, ``SS1``, ``SS2``
     - **Metric**: The extended similarity index

