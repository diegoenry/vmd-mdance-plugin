The plots
=========

Every plot draws the current clustering. The elbow and sweep plots draw
the last scans. The selected clusters are drawn on top, the others paler.
A cluster is drawn in a darker tone of its hue in VMD's 3D window
(:doc:`threed`), or in VMD's own colour (*Cluster colours* in the plot
options). Noise is grey.

Hover a plot: the line under it says what the pointer is on. A plot's tab
says its name and what it shows when the pointer rests on it.

The **Plot options** panel (the toolbar's last button) holds every setting
of the current plot. It also holds those shared by all (*All plots*): grid
lines, legends, the line width, the distances' unit, the time per frame
and the cluster colours.

Two of the shared options change what the plots read in:

- **Distances as**: *Squared* (the default) or *Lengths*. *Squared* is in
  Å², as the distances are measured: RMSD², and MDANCE's MSD. *Lengths* is
  in Å: their square roots, RMSD and √MSD, the unit RMSD cut-offs are
  given in. Compactness, the Distances between mean structures, the
  Timeline's distances, the Tree's heights, the readouts and the table of
  clusters follow it. The exports keep the values as measured.
- **Time per frame**: the time between two frames of the molecule, with
  its unit: ``0.1 ns``, ``2 ps`` (fs, ps, ns, µs, ms or s). The Timeline
  and the Residence then read in time (*Time (ns)*, *Mean stay (ns)*). A
  frame's readout gives its time too (*frame 50 (5 ns)*). Left empty, the
  plots read in frames. The Timeline's option row has the field too (*A
  frame:*).

There are 29 cluster colours (10 for the groups). Past them, the colours
come again in the plots, lighter the second time and darker the third. So
clusters 0, 29 and 58 are not one blue. A group given a colour of its own
keeps it.

Populations
-----------

.. image:: _static/figures/plot_populations.png
   :width: 100%

The frames of each cluster, or their share of the clustered frames. The
bars are in the clusters' order, or largest first. eQual's noise is a grey
bar. Click a bar: select the cluster (Shift: add or remove it).
Double-click: go to its representative.

Make-up
-------

.. image:: _static/figures/plot_makeup.png
   :width: 100%

Each cluster's frames by group (Results ▸ Groups: the method, replica or
condition each came from), stacked in the groups' colours. Or each group's
frames by cluster. Noise and frames of no group are left out.

The bars show counts, or shares (of the cluster, or of the group). The
shares' axis ends at 100. With shares, each bar's frames are written above
it too (*n = 1508*), since a bar of 16 frames is then as tall as one of
3000.

The readout gives the slice under the pointer first, then the bar's
largest. Click a bar: select the cluster. Double-click: go to its
representative.

Timeline
--------

.. image:: _static/figures/plot_timeline.png
   :width: 100%

A lane per cluster (noise at the bottom), with a bar wherever the
trajectory is in it. With more frames than pixels, each pixel of a lane is
shaded by the share of the frames under it that are in the cluster. There
are five tones: the darker, the larger the share. A note above the lanes
says so. This way, a trajectory that changes cluster every other frame
does not look as if it were in every cluster all the time.

Three other views (*Show*):

- **Each cluster's share, window by window**: the trajectory is cut in
  windows as equal as can be. Each window is a stacked bar of the
  clusters' shares of its frames, noise too. *Windows* in the plot options
  sets their number (0: about 120, of 10 frames at least).
- **Each cluster's share so far**: a line per cluster, its share of the
  frames up to each frame. Lines that have settled say that the
  populations have. A dotted line marks the frame by which every cluster
  has been seen. With more than 40 clusters, it draws the 40 largest, and
  the selected ones.
- **Distance to its representative**: every frame's RMSD² from its
  cluster's representative, coloured by its cluster. With 400 frames or
  fewer, it is a line. Above, it is a dot per frame, with the running
  median of the frames around as a line.

The red line is VMD's current frame (*Current-frame marker* in the
Timeline's options). Click: go to that frame. Shift-click: also select its
cluster.

The readout says:

- the frame under the pointer and its cluster;
- where a pixel holds several frames, those frames and how many are in
  each cluster;
- in the shares' views, the window's frames, or the frames so far, and
  each cluster's share of them.

``vmdance timeline`` gives the windows' counts, and the frame each cluster
is first seen at.

Transitions
-----------

.. image:: _static/figures/plot_transitions.png
   :width: 100%

From each cluster (rows) to the cluster of the clustered frame *lag* later
(columns): the share of the frames that go there, or their number.

With noise, a row's shares into the clusters sum to less than one. The
rest went into noise, which has no column. The colour bar's title says how
many frames did.

*Staying* off leaves the diagonal out of the colours, which then show the
moves only. Click a cell: select its two clusters. The matrix is drawn for
300 clusters or fewer. **Export** writes it for any number: above 300,
when it is ticked.

Residence
---------

.. image:: _static/figures/plot_residence.png
   :width: 100%

Either:

- how long the trajectory stays in a cluster once it enters it: the mean
  of its runs of consecutive clustered frames. The longest is written
  beside it, above the bar (*2.15 · longest 20*). It reads in clustered
  frames, or VMD frames (× the step), or in time when the time per frame
  is given.
- or how many times it enters it (visits).

Click a bar: select the cluster. Double-click: go to its representative.

Compactness
-----------

.. image:: _static/figures/plot_compactness.png
   :width: 100%

How tight each cluster is, by one of:

- the backend's MSD within. It is MDANCE's: the mean RMSD² over every pair
  of its frames, each with itself too. That is twice the mean squared
  distance from its mean structure.
- the mean RMSD² of its frames from its representative. It is lower for
  the same spread: half the MSD within, plus the representative's RMSD²
  from the mean structure. With the metric MSD, it is between half the MSD
  within and all of it (all of it for two frames).
- the MSD within against the cluster's size. The dashed lines are the
  medians. A small, loose cluster is often one of outliers, not a state.
- MDANCE's extended similarity (iSIM) of each cluster, once
  **Tools ▸ Similarity** has computed it.

The bars' values are written to three significant digits. The scatter
writes a cluster's number where it has room, the selected clusters' first.
It draws smaller dots above 40 clusters. With *Distances as: Lengths*, the
plots show √MSD and the root mean square distance from the representative,
in Å.

Distances
---------

.. image:: _static/figures/plot_distances.png
   :width: 100%

Between every two clusters, either:

- the RMSD² between their mean structures (the RMSD, with *Distances as:
  Lengths*);
- or the RMSD between their representatives (no fit).

The cells' values are written to three significant digits, as plain
numbers. Click a cell: select its two clusters. The distances are measured
and drawn for 300 clusters or fewer. For thousands, the 2k² distances
would take gigabytes.

Tree
----

.. image:: _static/figures/plot_tree.png
   :width: 100%

How the clusters join:

- For HELM, its merges of its starting clusters. The height is the merge's
  rank. It is a forest when HELM stops at k clusters, each tree in the
  colour of the cluster it ends in. The starting clusters HELM trimmed
  (their frames are noise) are left out, and counted in the corner. A HELM
  run that merged nothing (k starting clusters) shows them as k leaves.
- For the others, the average linkage (UPGMA) of the clusters' mean
  structures. The height is their RMSD². It is made and drawn for 300
  clusters or fewer. DIVINE gets it too: it is not its splits (CPP-MDANCE
  does not return them), and can join its clusters across them.

The axis says which tree it is. The leaves' labels are written side by
side when they fit. When they do not, they are written upright, read from
below. When not even a line's height fits between two leaves, every n-th
is written. Click a leaf: select its cluster.

.. image:: _static/figures/plot_tree_heights.png
   :width: 100%

The **merges' heights** (*Show* in the Tree's options): each merge's
height against the number of clusters before it. The height is:

- for HELM, the MSD within the cluster it makes (MDANCE's, measured when
  it clustered);
- for the others, the average linkage's RMSD² between the mean structures
  it joins.

A merge much higher than the one before joins clusters far apart: the k
before it is a natural place to stop. A jump is a merge's height over the
one before. The one before counts as 5% of the highest at least, so merges
of near-identical clusters are not jumps.

The largest jump is circled only when it stands out:

- twice the merge before, at least;
- half as much again as the next largest jump;
- and among the coarser half of the merges. Among dozens of starting
  clusters, two of the first merges always differ by some factor.

Otherwise a note above the plot says that no merge stands out from the one
before it.

With HELM, cluster to fewer clusters than you mean to keep (a small k),
and read the heights back. ``vmdance tree`` gives them too (``heights``),
and the tree export a column of them.

Silhouette
----------

.. image:: _static/figures/plot_silhouette.png
   :width: 100%

Every frame's silhouette, cluster by cluster, sorted from its best to its
worst, with the mean (written above the plot). There are two kinds
(*From*):

- **The clusters' mean structures** (the default): a is the frame's RMSD
  from its own cluster's mean structure, and b from the nearest other one.
  The silhouette is (b − a) / max(a, b). This is the *simplified*
  silhouette. It is never below zero for k-means, which puts each frame in
  the cluster of the nearest mean. With the other algorithms, a frame
  below zero sits closer to another cluster's mean structure than to its
  own's.
- **Every frame (squared distances)**: a is the mean squared distance
  (RMSD²) from the frame to the other frames of its cluster. b is the
  smallest such mean to the frames of another cluster. This is the
  *classic* silhouette, of the squared distances. It gives the same
  numbers as scikit-learn's ``silhouette_samples(metric="sqeuclidean")``
  on the clustered coordinates. A frame below zero is nearer another
  cluster's frames than its own's. k-means has such frames too.

The axis starts at the lowest value (at 0 when no frame is below it). Its
title says which kind is shown. The readout gives a frame's silhouette of
both kinds. A run made before the second kind was measured has the first
only: cluster again for the other.
``vmdance silhouette -kind centroid|pairs`` gives either, and the export's
table both.

Click: go to that frame and select its cluster (Shift: add or remove it).
With many clusters, the gaps between them shrink (a quarter of the axis at
most). The clusters' numbers are written where they fit, the selected ones
first.

Map
---

.. image:: _static/figures/plot_map.png
   :width: 100%

Every clustered frame on the first two principal components of the
clustered coordinates (Results ▸ Map), in Å. Each axis gives its share of
the variance. The frames are coloured by group, or by cluster. Asked by
group when the frames have none, they are coloured by cluster, and a note
says so.

The two components are drawn to one scale, an ångström as long on both: a
round cloud looks round. Each cluster's representative is ringed, with its
number while there are 30 clusters or fewer (*The representatives*, in
the Map's options).

The frames are drawn in a mixed order, so that no group or cluster covers
the others. Noise comes first, the selected clusters' frames last. The
dots are as large as their number and the plot's size allow.

Frames close on the map have close structures. The reverse need not hold:
two components are a shadow of all of them. Click a frame: go to it and
select its cluster.

Profiles
--------

.. image:: _static/figures/plot_profiles.png
   :width: 100%

Atom by atom of the selection, measured by Results ▸ Profiles. The axis is
by residue, with a gap between chains. The curves are one of:

- each group's fluctuations (RMSF about its own mean structure, Å);
- each cluster's;
- each cluster's mean structure's distance from the reference cluster's.
  The reference is the most populated, unless another is given.

Where groups or clusters differ shows as a stretch of residues apart from
the rest. Over several atoms, a residue's value is their root mean square.
The residues' ticks are at round numbers (50, 100 …).

With more than 12 clusters' curves, the selected clusters are in colour
(the 8 largest, when none is selected), and the others grey behind them. A
note above the plot says which. The readout names the curve under the
pointer, and a click on a cluster's curve selects the cluster.

Elbow
-----

.. image:: _static/figures/plot_elbow.png
   :width: 100%

The Calinski–Harabasz and Davies–Bouldin scores at every k of the elbow
scan, each on its own axis. A cross marks a k that failed or was not run.
The dotted line is at the current clustering's k.

*Scores* shows both, one, or a third curve: the **variance the clusters
explain**, in %. It comes from the Calinski–Harabasz score: SSR/SST = CH
(k − 1) / (n − k + CH (k − 1)), k being the clusters with frames and n
their frames. It is the curve that has an elbow, where another cluster
stops adding much. It is cpptraj's SSR/SST.

Rings mark what the scan points to:

- on Davies–Bouldin, its lowest value and its sharpest dip (the local
  minimum that bends most). These are MDANCE's two criteria: the lowest DB
  and the maximum second derivative of DB.
- on Calinski–Harabasz, its highest value.

A line above the plot says them in words, with the k the seedings agree on
(a stability of 0.9 or more). The Scans box says the same. The readings
need not agree, and the plot does not choose between them (:doc:`scans`).

The scan's stability (how alike NANI's seedings cluster) is drawn in a
strip of its own under the scores, with a scale from 0 to 1. It has a bar
at each k, with its value above it.

An eQual scan is by radius: the x axis is the radius, and the strip's bars
say how many clusters each gave.

Hover a k, over the scores or the strip, to see its clusters' shares. The
readout gives its scores, the variance explained and its stability.
Double-click: make it the clustering.

Sweep
-----

.. image:: _static/figures/plot_sweep.png
   :width: 100%

The chosen score of every configuration of the sweep. There is a row per
algorithm, metric and seeding, and a column per k. The best is outlined.
For Davies–Bouldin the palette is reversed, so that the best is the same
colour. Double-click a cell: make it the clustering.

Figures
-------

**File ▸ Create figures** (or ``vmdance figures``) draws the plots again at
a size of their own. The text is at the size figures are laid out for
(``-text``: another). The figures are written as EPS, and through
Ghostscript as PDF and PNG.

- ``-size column``, ``two-columns`` or ``slide`` sets the width, the height
  and the text for a paper's column, its two columns or a slide.
- ``-width`` and ``-height`` take a unit (``85mm``): :doc:`files`.

In a figure, the red line at VMD's current frame is left out unless asked
(``-cursor 1``). The Timeline's lanes are drawn as shapes, not as an
image: sharp at any resolution. A plot that has only a message to show
(*No similarity yet*) gets no figure, and is named.
