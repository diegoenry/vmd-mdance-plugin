The command
===========

One command, ``vmdance``, does everything the window does. It works in
text-mode VMD too, except ``figures``: Tk draws the figures, and Tk needs a
display, which text-mode VMD has not. With no argument the command opens
the window.

- Every option is checked before anything changes. An error names the
  option and what to change.
- A failed, cancelled or refused job keeps what was there.
- When the window is open, it shows what the command did.
- The answers are Tcl lists and dictionaries (``dict get`` reads them).
- A *cluster* is its number (0, 1 …). A *frame* is VMD's frame number.

``vmdance help`` lists the subcommands, a line each.
``vmdance help subcommand`` gives one's usage and what it does
(``vmdance help figures``).

A whole script
--------------

MDANCE's own example, clustered and asked about from start to end. The
sections below say what each subcommand takes and answers:

.. code-block:: tcl

   package require vmdance
   # MDANCE's example (pip install mdance): mdance/data/aligned_tau.pdb, aligned_original_tau_6K.dcd, labels_60.csv
   mol new aligned_tau.pdb
   mol addfile aligned_original_tau_6K.dcd waitfor all
   animate delete beg 0 end 0             ;# the PDB's own frame: cluster the DCD's 6001 (VMD's frame = MDANCE's)
   set sel "resid 3 to 12 and name CA N C O H"   ;# the atoms MDANCE's own tutorial clusters (50)
   vmdance -sel $sel -algorithm kmeans -k 6 -kinit CompSim
   # -> run 1 molid 0 sel {resid 3 to 12 and name CA N C O H} fit {} frames 6001 ... nclusters 6 sizes {699 1093 1223 1292 721 973} noise 0 ch 1005.6 db 2.01 ...
   vmdance help                        ;# the subcommands, a line each (vmdance help elbow: its usage)
   vmdance alignment -sel $sel         ;# do the frames look superposed? as_is 3.711 fitted 3.304 ... superposed 1
   vmdance clusters                    ;# {cluster frames percent msd msd_to_representative representative_frame} ...
   vmdance get 2                       ;# frames, share, representative, silhouette, visits, members ...
   vmdance labels                      ;# {frame cluster ...}
   vmdance timeline -windows 20        ;# each cluster's frames window by window, and the frame it is first seen at
   vmdance transitions -lag 10         ;# probabilities, k × k
   vmdance silhouette -kind pairs      ;# every frame's silhouette from every frame (-kind centroid: from the mean structures)
   vmdance renumber                    ;# the clusters numbered by size, the largest 0: a new run
   vmdance -sel $sel -algorithm helm -k 6 -initial-labels labels_60.csv
   vmdance radii -sel $sel             ;# a range for eQual's radius, from the frames: ... from 3.4 to 10 by 0.73
   vmdance -sel $sel -algorithm equal -threshold 10
   vmdance elbow -sel $sel -kinit CompSim -from 2 -to 15   ;# {index k nclusters ch db sizes status message} ...
   vmdance elbow -sel $sel -kinit CompSim -from 2 -to 15 -stability 1   ;# again, with each k's stability across NANI's seedings (it replaces the last scan)
   vmdance elbow suggest               ;# where the scores point: db_lowest, db_dip, ch_highest, stable ... and in words
   vmdance elbow load 6                ;# that k made the clustering
   vmdance sweep -sel $sel -algorithms {kmeans helm} -from 2 -to 10 -seedings {StratAll CompSim}
   vmdance sweep best db
   vmdance prime                       ;# {pairwise frame union frame ... medoidAll frame ...}
   vmdance similarity                  ;# {isim x clusters {...} least_similar {...}}
   vmdance groups -ranges {first 0-2999 second 3000-6000}   ;# where each frame came from (or -file, -names, -blocks 2; -colours)
   vmdance makeup                      ;# each cluster's frames by group
   vmdance groups compare              ;# how unlike the groups' shares of the clusters are (0: the same; 0.69: none in common)
   vmdance map                         ;# the frames on their first two principal components
   vmdance profiles                    ;# atom by atom: each group's and cluster's RMSF (how far each atom moves about its mean position), each cluster against the largest
   vmdance pick -sel $sel -method diversity -param 10
   vmdance select 0 3
   vmdance draw -colour 1 -overlay 1 -top 10
   vmdance goto 3                      ;# VMD's frame to cluster 3's representative
   vmdance export results -prefix hepta -items {summary clusters labels representatives trajectories}
   vmdance session save hepta.vmdance
   vmdance figures figs -plots {populations elbow} -size column   ;# 85 mm wide, 8-point text (needs VMD's window)

Clustering
----------

.. code-block:: tcl

   vmdance -mol top -sel "name CA" -fit "" -first 0 -last -1 -step 1 \
       -algorithm kmeans|divine|helm|equal -k n -metric MSD ?parameters? \
       ?-label text? ?-quiet 0?

The parameters are the algorithm's, named as ``mdance-cli`` names them
(:doc:`parameters`). ``-k`` is 6 by default. eQual takes no k: its
``-threshold``, the radius, is 2. ``-fit selection`` first superposes
every frame on the first clustered one.

The clustering is published as a new :term:`run`, the current one, and
the command returns ``info``. The run is named ``-label``. Without it, the
name is its algorithm and clusters, with the clusters that have no frames,
and *fitted* when it was fitted: ``KMeans NANI, k 6 → 6 clusters (1
empty), fitted``. Progress is printed every 10 % unless ``-quiet 1``.

Without ``-fit`` the frames are clustered as they are. When they do not
look superposed, the command says so before it clusters, unless
``-quiet 1``. The note reads ``note: not fitted, and the frames are … Å
from the first as they are, … Å once fitted on these atoms: they do not
look superposed (-fit <selection> fits them before they are
clustered)``. The command then clusters them all the same: the fit stays
off unless asked. ``alignment`` returns the numbers behind the note, for
any input:

.. code-block:: tcl

   vmdance alignment ?-mol top? ?-sel "name CA"? ?-first 0? ?-last -1? ?-step 1?
       ;# as_is 3.711 fitted 3.304 frames 21 atoms 50 superposed 1 words {the frames are …}
   vmdance radii ?-mol top? ?-sel "name CA"? ?-fit ""? ?-first 0? ?-last -1? ?-step 1?
       ;# sample 147 pairs 10731 percentiles {2 3.42 5 4.5 10 5.57 25 7.56 50 10.3} from 3.4 to 10 by 0.73

``alignment`` takes a sample of the frames: the first and 20 others at
most, evenly taken, and 300 of the atoms at most. It gives their mean RMSD
from the first frame (Å):

- ``as_is``: as they are;
- ``fitted``: once each is fitted on the first frame by those atoms.

``superposed`` is 0 when a fit halves the distance and takes an ångström
off it. Such frames were not aligned. Clustered as they are, they separate
by where the molecule is, not by its shape.

``radii`` proposes a range to scan eQual's radius over
(``vmdance elbow -algorithm equal -radii``). It measures MDANCE's MSD (Å²,
half the RMSD²) of every two of about 150 frames, evenly taken. It gives
the values that 2, 5, 10, 25 and 50% of the pairs are within. It also
gives a range in ten values, ``from`` the 2% value ``to`` the 50% one
(``by``: nine steps).

.. code-block:: tcl

   vmdance help ?subcommand?   ;# the subcommands, or one's usage
   vmdance info            ;# run molid sel fit frames first last step natoms algorithm k metric
                              ;# params nclusters sizes noise ch db selected backend seconds
                              ;# unrecorded (an import's: metric params, when its file has none)
   vmdance algorithms      ;# name {label about k available} ...
   vmdance parameters helm ;# -name {type default limits label tip} ... (also prime, similarity, pick)
   vmdance backend         ;# mode cli library loaded using {kind path} algorithms error note
   vmdance backend -mode cli -cli /path/to/mdance-cli -library /path/to/mdance_tcl.so
   vmdance backend try -cli /path/to/mdance-cli   ;# what it would give, the backend kept
   vmdance cancel          ;# stop the job running in the background (the window's)

The command's job runs to its end before the command returns. The
window's job runs in the background. While it runs, the command refuses
everything that reads or replaces the results ("wait for it or cancel
it").

While the command waits, VMD's text console reads nothing. A backend that
hangs is stopped with the window's Cancel, or by ending the
``mdance-cli`` process (Ctrl+C at VMD's terminal ends it). The whole job
then stops, a scan too, and what was there is kept ("cancelled:
mdance-cli was stopped (interrupt)").

After the backend, the plugin measures the clusters itself: every frame
against the clusters' mean structures. With thousands of clusters this
takes long, and the console says how far it is every 10 s. The window's
Cancel stops it, or a script's ``vmdance cancel`` from an ``after``.
Ending ``mdance-cli`` does not: it has ended.

Quitting VMD ends a job of the window's. A ``quit`` run while the command
waits takes effect when its job has ended.

The backend:

- It is the one chosen in Settings (kept in ``~/.vmdance.prefs``), else
  the one found as :doc:`install` says.
- ``backend -mode … -cli … -library …`` chooses over it for this VMD. A
  ``-cli`` alone keeps the mode: give ``-mode cli`` with it.
- ``backend try`` says what a choice would give without making it, as
  Settings does until OK. It is not refused while a job runs.
- In ``backend``, ``note`` says what the program's probe could not tell
  (the program did not answer within 3 s: every algorithm is offered).

Options are given once each. So are the names in a sweep's ``-params``
and in figures' ``-options``. A sweep's seedings are those of
``-seedings`` (none in ``-params``). A name that is no option of the
command, nor any algorithm's parameter, is refused as such.

Reading the clustering
----------------------

.. code-block:: tcl

   vmdance clusters ?-sort cluster|size|msd?
       ;# {cluster frames percent msd msd_to_representative representative_frame} ...
   vmdance get 2           ;# cluster frames percent msd msd_to_representative representative
                              ;# vmd_colour silhouette visits mean_residence longest_residence members
   vmdance labels          ;# {frame cluster ...}, -1 for noise
   vmdance frame 1234      ;# frame 1234 clustered 1230 cluster 3 (the clustered frame at or before it)
   vmdance timeline ?-windows n?   ;# windows {{first last} ...} counts {{n ...} ...} noise {n ...}
                              ;# first_seen {cluster frame ...}
   vmdance transitions ?-lag 1? ?-counts 0?   ;# k × k: probabilities (the share into noise left out;
                              ;# "" in a row with nothing counted) or counts
   vmdance residence       ;# {cluster visits mean min max} ... (clustered frames)
   vmdance silhouette ?-kind centroid|pairs?
                              ;# mean m clusters {c mean ...} frames {frame s ...} kind centroid
   vmdance distances       ;# centroids {k × k RMSD²} representatives {k × k RMSD}
   vmdance tree            ;# kind helm|linkage merges {{left right distance count} ...} leaves {...} heights {...}

The tables are the clustering's record, in its own frame numbers. They
answer whether or not its molecule is loaded.

``distances`` and the average linkage ``tree`` are made for 300 clusters
or fewer. With more, they say so (a smaller k, a larger eQual radius).
HELM's tree is its merges, at any number of clusters.

``heights`` is each merge's height, the Tree plot's heights view:

- HELM's: the MSD (MDANCE's, Å²) of the cluster the merge makes;
- the linkage's: the RMSD² between the mean structures it joins (its
  distance).

A merge far above the one before joins clusters far apart: the k before it
is a natural place to stop.

``timeline`` cuts the clustered frames in ``-windows`` windows, as equal
as can be. By default there are about 120, of 10 frames at least; there
can be 1 to the number of frames. It counts each cluster's frames in each
window:

- ``windows``: their first and last VMD frames;
- ``counts``: a count a cluster for each window;
- ``noise``: the frames in no cluster;
- ``first_seen``: the frame each cluster is first seen at (empty: never).

The Timeline's shares views draw them.

``silhouette`` gives every frame's silhouette in one of two ways:

- ``-kind centroid``, the default: from the clusters' mean structures.
  This is the simplified silhouette, never below 0 for k-means.
- ``-kind pairs``: from every frame, of the squared distances. This is the
  classic one, scikit-learn's ``silhouette_samples(metric="sqeuclidean")``.

A run made before the second was measured is refused it, with a message
saying to cluster again (:doc:`plots`).

``frame`` reads VMD's frame number as the clustered one, as ``goto``,
``draw``, ``userfield`` and the structure exports do. It does so only
while the clustered molecule has the frames it had. Frames added after
them change nothing. After frames deleted before them, or a trajectory
loaded otherwise, it is refused, saying why.

Scans
-----

.. code-block:: tcl

   vmdance elbow ?-ks {k ...} | -from 2 -to 15 -by 1? ?-stability 0|1|{seedings}? \
       ?clustering options but -k? ?-quiet 0?
       ;# {index k nclusters ch db sizes status message ?stability compared?} ...
   vmdance elbow -algorithm equal -radii {0.5 1 2 4} ?clustering options but -threshold?
       ;# {index k {} radius nclusters ch db sizes status message} ...
   vmdance elbow show      ;# the last scan's records
   vmdance elbow suggest   ;# db_lowest db_second db_dip db_dip2 ch_highest ch_peak stable most_stable words
   vmdance elbow load 6    ;# that k (or radius) made the clustering (a new run): info
   vmdance elbow clear     ;# the scan dropped (sweep clear, pick clear: theirs)
   vmdance sweep ?input options? -algorithms {kmeans} -ks {...} | -from -to -by \
       -metrics {MSD} -seedings {StratAll} ?-params {algorithm {name value ...} ...}? ?-quiet 0?
       ;# {index algorithm k metric seeding nclusters ch db sizes status message} ...
   vmdance sweep show | sweep best ?ch|db? | sweep load n | sweep clear

A scan takes its own input and clustering options, as a clustering does.
An option not given is the command's default, never the current run's:
``-mol top -sel "name CA"``, no fit, every frame, KMeans NANI with its
defaults. To scan what a run clustered, give its options again
(``vmdance elbow -sel $sel -kinit CompSim -from 2 -to 12``). A scan says
what it reads (unless ``-quiet 1``). It notes when that is not what the
current run clustered.

A record's ``nclusters`` counts the clusters with frames. A sweep's
seedings are ``-seedings`` (HELM's: its first clustering's), and
``-params`` with a seeding is refused. HELM from a label file and DIVINE
with pair anchors use none: one configuration at each k, its seeding
``none``.

``-stability 1`` clusters every k again from NANI's four seedings that
draw no random number: StratAll, StratReduced, CompSim and DivSelect (or
the list given, two at least). It gives each record the mean adjusted Rand
index of every two of them (1: the same clusters whatever the seeding; 0:
as alike as chance). It is for k-means NANI only.

A seeding that cannot seed k is left out at that k (StratAll draws k seeds
from the densest share of the frames). ``compared`` says how many were
compared. With fewer than two, the stability is ``""``.

eQual is given no k: its elbow scans its radius (``-radii``). The radii
are MDANCE's MSD, two values at least. Each radius is the clustering's
``-threshold``, which is not given. A record's ``nclusters`` is what that
radius gave (:doc:`scans`).

``elbow load`` takes a k as a whole number (``010`` is not 8) and a radius
as a decimal number.

``elbow suggest`` says where the last scan's scores point. Each is a k (or
a radius), empty where the scan does not say:

- ``db_lowest`` and ``db_second``: the lowest Davies–Bouldin score, and
  the next;
- ``db_dip`` and ``db_dip2``: its local minimum that bends most (the score
  before plus the score after, less twice its own, is largest), and the
  next;
- ``ch_highest`` and ``ch_peak``: the highest Calinski–Harabasz score, and
  its sharpest peak;
- ``stable``: the values whose stability is 0.9 or more, and
  ``most_stable``;
- ``words``: the sentence the window shows.

MDANCE's two criteria are ``db_lowest`` and ``db_dip``. The readings need
not agree: the command says each, and leaves the choice (:doc:`scans`).

Questions after a clustering
----------------------------

.. code-block:: tcl

   vmdance prime ?-metric RR|SM? ?-trim-frac 0.1? ?-weighted 1?
       ;# pairwise f union f medoid f outlier f medoidAll f medoidC0 f medoidC0Trimmed f (VMD frames)
   vmdance similarity ?-metric MSD?
       ;# metric m isim x clusters {c isim ...} least_similar {c frame ...}
   vmdance pick ?input options? -method diversity|outliers|repsample|medoid|outlier \
       -param 10 -nbins 10 -metric MSD    ;# VMD frames
   vmdance pick show | pick clear
   vmdance pick goto 1234  ;# VMD's frame to a picked one, on the picks' molecule
   vmdance pick save file.pdb ?-format pdb|dcd? ?-sel all?   ;# their structures

PRIME and the similarity read the coordinates again. The clustered
molecule must be loaded, with the frames that were clustered and its
atoms. These are the atoms the selection held then: ``-sel "beta > 0"``
is read as the atoms it selected when it was clustered.

The picks need no clustering. ``pick goto``, ``pick save`` and
``draw -picks 1`` work on their own molecule, while it has the frames
they were picked from. A pick's ``-param`` is (:doc:`tools`):

- for ``diversity``, a whole percentage of the frames (1 to 100; with
  ``-metric MSD`` only);
- for ``outliers`` and ``repsample``, a number of frames or a share
  below 1. The outliers' share holds a frame at least. A sample is one
  frame at least.

Groups, map and profiles
------------------------

.. code-block:: tcl

   vmdance groups -ranges {original 0-63 moderate 64-127 aggressive 128-191}
   vmdance groups -file groups.csv       ;# frame,group lines (# comments; a header may name the columns: frame,cluster,group reads back)
   vmdance groups -names {...}           ;# a name for each clustered frame
   vmdance groups -blocks 2              ;# the clustered frames in n blocks: first second (more: part1 part2 …)
   vmdance groups -colours {original #3d5a80 moderate #c09a45 aggressive #a3483b}   ;# with the above, or alone
   vmdance groups          ;# names {...} sizes {...} none n colours {...}
   vmdance groups compare  ;# pairs {{group group divergence difference cluster} ...} words {...}
   vmdance groups clear
   vmdance makeup ?-by cluster|group?    ;# {cluster {n ...}} ... or {group {n ...}} ...
   vmdance map ?-sample 500?             ;# sample m variance {v1 v2} total t
   vmdance map show                      ;# {frame {pc1 pc2}} ...
   vmdance profiles ?-reference c?       ;# reference c atoms n clusters k groups {...}
   vmdance profiles show                 ;# residues chains clusters groups differences ...

The groups say where each clustered frame came from: the method, replica
or condition that made it. There can be up to 256, each name 1 to 64
characters. A frame given none has none. The groups are kept with the
run, in sessions too. A new clustering of the same frames of the same
molecule takes them over.

A group's colour in the plots is its index's in a muted palette, or the
one ``-colours`` gives its name (``#rrggbb``; ``""``: the palette's
again). A name the groups do not have is passed over. So one list colours
the groups of several molecules alike, and new groups keep the colours of
their names.

``-blocks n`` cuts the clustered frames in n blocks as equal as can be, a
group each (2 to 256, and no more than the frames). These are the halves
or quarters of a trajectory, to see whether each part visits the same
clusters.

``makeup`` counts each cluster's frames by group. Noise and frames of no
group are left out.

``groups compare`` says how unlike the groups' shares of the clusters are.
For every two groups with frames, it gives:

- the Jensen–Shannon divergence of their shares (0: the same; 0.693,
  ln 2: no cluster in common);
- the largest difference in a cluster's share between them (0 to 1);
- that cluster.

``words`` names the two most unlike (:doc:`groups`).

``map`` places every clustered frame on the first two principal
components of the clustered coordinates, in Å, with each axis's share of
the variance. It uses classical scaling of their squared distances, after
the clustering's fit. The axes come from ``-sample`` frames spread evenly
over them (2 to 5000), and every frame is projected on the axes.

``profiles`` measures, atom by atom of the selection, each cluster's and
each group's RMSF about its own mean structure. It also measures each
cluster's mean structure's distance from ``-reference``'s (by default the
most populated cluster).

Both ``map`` and ``profiles``:

- read the coordinates again (the molecule loaded, with its frames);
- are kept with the run and in sessions;
- are made again when asked.

Profiles made with other groups are dropped when the groups change. A new
clustering of the same frames and atoms of the same molecule, fitted the
same, takes the map over: it is of the frames, not of their clusters.

The selection and the 3D window
-------------------------------

.. code-block:: tcl

   vmdance select          ;# the selected clusters
   vmdance select 0 3 | select add 4 | select toggle 3 | select all | select clear
   vmdance draw ?-colour 0|1? ?-reps 0|1? ?-overlay 0|1? ?-picks 0|1? \
       ?-style NewCartoon? ?-sel ""? ?-top 10? ?-frames "0-100,500"? ?-material Opaque?
   vmdance goto 3          ;# VMD's frame to cluster 3's representative
   vmdance goto -frame 120
   vmdance userfield ?-sel all?   ;# the clusters into the user field: the frames written (-sel of no atom: refused)

``draw`` returns its options, and a ``note``. The note says what is on
but not drawn, and why: no clustering, or its molecule not loaded or
without its frames (the same for the picks). It also says what is drawn
otherwise than asked, which the console says too:

- a ``-sel`` that selects nothing there, or is no selection, is drawn as
  the residues of the atoms clustered (a ``-sel`` given with no molecule
  loaded was kept unchecked);
- ``-frames`` past the molecule's last are left out.

``-sel`` is checked on the clustered molecule, else on the top one. A
session that saved such a ``-sel`` or ``-frames`` loses it alone when it
is opened, with a warning. The rest of its drawing is kept.

Runs
----

.. code-block:: tcl

   vmdance runs            ;# {id label current} ... (the last 25)
   vmdance run 2           ;# back to run 2
   vmdance run label 2 "the long one"
   vmdance run delete 2
   vmdance run clear       ;# every run, scan and pick
   vmdance renumber        ;# the current clustering, its clusters numbered by size: a new run (info)

The backend numbers the clusters, and the plugin keeps its numbers: every
label is MDANCE's.

``renumber`` makes a new run of the current clustering, named *…, by
size*, with its clusters numbered by size:

- the largest is 0;
- equal sizes keep the order they had;
- those without frames come last.

Its table, its measures, its similarity, its profiles and its groups
follow. The run it is made of keeps the backend's numbers. Clusters
already in that order are refused.

Files
-----

.. code-block:: tcl

   vmdance export dir ?-prefix vmdance? ?-items {...}? ?-top 10? ?-lag 1? ?-format dcd|pdb? ?-sel all?
   vmdance session save file.vmdance
   vmdance session load file.vmdance ?-mol auto|load|none|id?
   vmdance session import file.mdance ?-mol auto|id? ?-label text?
   vmdance figures dir ?-plots {...}? ?-formats {pdf png}? ?-size column|two-columns|slide|screen? \
       ?-width 85mm? ?-height 60mm? ?-text 8? ?-dpi 300? ?-prefix vmdance? ?-cursor 0|1? \
       ?-options {setting value ...}? ?-3d 0|1? ?-renderer auto?
   vmdance figures dir -plots {} -3d 1   ;# the 3D view alone

:doc:`files` describes them. ``export`` and ``figures`` make their folder
when it does not exist. An export writes all its files, or none.

A figure's ``-size`` is where it goes:

- ``column``: a paper's column;
- ``two-columns``: its two columns;
- ``slide``: a slide;
- ``screen``, the default: 900 × 560 points with 12-point text.

``-width`` and ``-height`` are points, or a number with its unit
(``85mm``, ``8.5cm``, ``3.35in``).

Without ``-items``, above 300 clusters, an export leaves out:

- the transitions (k² rows: written when named);
- the distances and the tree, which are not made then.
