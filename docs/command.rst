The command
===========

One command, ``vmdance``, does everything the window does, and works in
text-mode VMD (but ``figures``: Tk draws them, and needs a display, which
text-mode VMD has not). With no argument it opens the window. Every option is
checked before anything changes, and an error names the option and what to
change; a failed, cancelled or refused job keeps what was there. The
window, when it is open, shows what the command did. The answers are Tcl
lists and dictionaries (``dict get`` reads them). A *cluster* is its number
(0, 1 …); a *frame* is VMD's frame number.

Clustering
----------

.. code-block:: tcl

   vmdance -mol top -sel "name CA" -fit "" -first 0 -last -1 -step 1 \
       -algorithm kmeans|divine|helm|equal -k n -metric MSD ?parameters? \
       ?-label text? ?-quiet 0?

The parameters are the algorithm's, named as ``mdance-cli`` names them
(:doc:`parameters`); ``-fit selection`` superposes every frame on the first
clustered one first. The clustering is published as a new :term:`run`, the
current one, named ``-label`` (else after its algorithm and clusters); the
command returns ``info``. Progress is printed every 10 % unless ``-quiet 1``.

.. code-block:: tcl

   vmdance info            ;# run molid sel fit frames first last step natoms algorithm k metric
                              ;# params nclusters sizes noise ch db selected backend seconds
                              ;# unrecorded (an import's: metric params, when its file has none)
   vmdance algorithms      ;# name {label about k available} ...
   vmdance parameters helm ;# -name {type default limits label tip} ... (also prime, similarity, pick)
   vmdance backend         ;# mode cli library loaded using {kind path} algorithms error note
   vmdance backend -mode cli -cli /path/to/mdance-cli -library /path/to/mdance_tcl.so
   vmdance backend try -cli /path/to/mdance-cli   ;# what it would give, the backend kept
   vmdance cancel          ;# stop the job running in the background (the window's)

The command's job runs to its end before the command returns; the
window's runs in the background, and while it runs the command refuses
everything that reads or replaces the results ("wait for it or cancel
it"). While the command waits, VMD's text console reads nothing: a
backend that hangs is stopped with the window's Cancel, or by ending the
``mdance-cli`` process (Ctrl+C at VMD's terminal ends it): the whole job
stops, a scan too, and what was there is kept ("cancelled: mdance-cli was
stopped (interrupt)"). After the backend, the plugin measures the clusters
itself (every frame against the clusters' mean structures): with thousands
of clusters it takes long, and the console says how far it is every 10 s; the window's
Cancel stops it (ending ``mdance-cli`` does not: it has ended), or a script's
``vmdance cancel`` from an ``after``. Quitting VMD ends a job of the
window's; a ``quit``
run while the command waits takes effect when its job has ended. In
``backend``, ``note`` says what the program's probe could not tell (it did
not answer within 3 s: every algorithm is offered). The backend is the one
chosen in Settings (kept in ``~/.vmdance.prefs``), else found as
:doc:`install` says; ``backend -mode … -cli … -library …`` chooses over it
for this VMD (a ``-cli`` alone keeps the mode: give ``-mode cli`` with it),
and ``backend try`` says what a choice would give without making it, as
Settings does until OK (a job running is not refused it). Options are given once
each, and so are the names in a sweep's ``-params`` and figures'
``-options``; a sweep's seedings are those of ``-seedings`` (none in
``-params``); a name that is no option of the command nor any algorithm's
parameter is refused as such.

Reading the clustering
----------------------

.. code-block:: tcl

   vmdance clusters ?-sort cluster|size|msd?
       ;# {cluster frames percent msd msd_to_representative representative_frame} ...
   vmdance get 2           ;# cluster frames percent msd msd_to_representative representative
                              ;# vmd_colour silhouette visits mean_residence longest_residence members
   vmdance labels          ;# {frame cluster ...}, -1 for noise
   vmdance frame 1234      ;# frame 1234 clustered 1230 cluster 3 (the clustered frame at or before it)
   vmdance transitions ?-lag 1? ?-counts 0?   ;# k × k: probabilities (the share into noise left out;
                              ;# "" in a row with nothing counted) or counts
   vmdance residence       ;# {cluster visits mean min max} ... (clustered frames)
   vmdance silhouette      ;# mean m clusters {c mean ...} frames {frame s ...}
   vmdance distances       ;# centroids {k × k RMSD²} representatives {k × k RMSD}
   vmdance tree            ;# kind helm|linkage merges {{left right distance count} ...} leaves {...}

The tables are the clustering's record, in its own frame numbers: they
answer whether or not its molecule is loaded. ``distances`` and the average
linkage ``tree`` are made for 300 clusters or fewer: with more, they say so
(a smaller k, a larger eQUAL radius); HELM's tree is its merges, at any
number. ``frame`` reads VMD's frame
number as the clustered one, as ``goto``, ``draw``, ``userfield`` and the
structure exports do: only while the clustered molecule has the frames it
had (frames added after them change nothing); after frames deleted before
them, or a trajectory loaded otherwise, it is refused, saying why.

Scans
-----

.. code-block:: tcl

   vmdance elbow ?-ks {k ...} | -from 2 -to 15 -by 1? ?-stability 0|1|{seedings}? \
       ?clustering options but -k? ?-quiet 0?
       ;# {index k nclusters ch db sizes status message ?stability?} ...
   vmdance elbow -algorithm equal -radii {0.5 1 2 4} ?clustering options?
       ;# {index radius nclusters ch db sizes status message} ...
   vmdance elbow show      ;# the last scan's records
   vmdance elbow load 6    ;# that k (or radius) made the clustering (a new run): info
   vmdance elbow clear     ;# the scan dropped (sweep clear, pick clear: theirs)
   vmdance sweep ?input options? -algorithms {kmeans} -ks {...} | -from -to -by \
       -metrics {MSD} -seedings {StratAll} ?-params {algorithm {name value ...} ...}? ?-quiet 0?
       ;# {index algorithm k metric seeding nclusters ch db sizes status message} ...
   vmdance sweep show | sweep best ?ch|db? | sweep load n | sweep clear

A scan takes its own input and clustering options, as a clustering does:
an option not given is the command's default (``-mol top -sel "name CA"``,
no fit, every frame, KMeans NANI with its defaults), never the current
run's. To scan what a run clustered, give its options again
(``vmdance elbow -sel backbone -kinit CompSim -from 2 -to 12``). A scan
says what it reads (unless ``-quiet 1``), and notes when that is not what
the current run clustered. A record's ``nclusters`` counts the clusters
with frames. A sweep's seedings are ``-seedings`` (HELM's: its first
clustering's): ``-params`` with a seeding is refused. HELM from a label file
and DIVINE with pair anchors use none: one configuration at each k, its
seeding ``none``.

``-stability 1`` clusters every k again from NANI's four seedings that draw
no random number (StratAll, StratReduced, CompSim, DivSelect; or the list
given, two at least), and gives each record the mean adjusted Rand index of
every two of them (1: the same clusters whatever the seeding; 0: as alike as
chance); k-means NANI only. eQUAL is given no k: its elbow scans its radius
(``-radii``, MDANCE's MSD, two values at least), and a record's
``nclusters`` is what that radius gave (:doc:`scans`).

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

PRIME and the similarity read the coordinates again: the clustered
molecule must be loaded, with the frames that were clustered, and its
atoms (those the selection held then: ``-sel "beta > 0"`` is read as the
atoms it selected when it was clustered). The picks need no clustering:
``pick goto``, ``pick save`` and ``draw -picks 1`` work on their own
molecule, while it has the frames they were picked from. A pick's
``-param`` is, for ``diversity``, a whole percentage of the frames (1 to
100; with ``-metric MSD`` only), for ``outliers`` and ``repsample`` a
number of frames or a share below 1 (the outliers' holds a frame at least;
a sample is one frame at least) (:doc:`tools`).

Groups, map and profiles
------------------------

.. code-block:: tcl

   vmdance groups -ranges {original 0-63 moderate 64-127 aggressive 128-191}
   vmdance groups -file groups.csv       ;# frame,group lines (a header, # comments)
   vmdance groups -names {...}           ;# a name for each clustered frame
   vmdance groups -colours {original #3d5a80 moderate #c09a45}   ;# with the above, or alone
   vmdance groups          ;# names {...} sizes {...} none n colours {...}
   vmdance groups clear
   vmdance makeup ?-by cluster|group?    ;# {cluster {n ...}} ... or {group {n ...}} ...
   vmdance map ?-sample 500?             ;# sample m variance {v1 v2} total t
   vmdance map show                      ;# {frame {pc1 pc2}} ...
   vmdance profiles ?-reference c?       ;# reference c atoms n clusters k groups {...}
   vmdance profiles show                 ;# residues chains clusters groups differences ...

The groups say where each clustered frame came from (the method, replica or
condition that made it): up to 256, each name 1 to 64 characters; a frame
given none has none. They are kept with the run, in sessions too, and a new
clustering of the same frames of the same molecule takes them over. A
group's colour in the plots is its index's in a muted palette, or the one
``-colours`` gives its name (``#rrggbb``; ``""``: the palette's again): a
name the groups do not have is passed over, so that one list colours the
groups of several molecules alike, and new groups keep the colours of their
names. ``makeup`` counts each cluster's frames by group (noise and frames of
no group left out).

``map`` places every clustered frame on the first two principal components
of the clustered coordinates (classical scaling of their squared distances,
after the clustering's fit; the axes from ``-sample`` frames spread evenly
over them, 2 to 5000, every frame projected on them), in Å, with each axis's
share of the variance. ``profiles`` measures, atom by atom of the selection,
each cluster's and each group's RMSF about its own mean structure, and each
cluster's mean structure's distance from ``-reference``'s (by default the
most populated cluster). Both read the coordinates again (the molecule
loaded, with its frames), are kept with the run and in sessions, and are
made again when asked; profiles made with other groups are dropped when the
groups change.

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

``draw`` returns its options, and a ``note`` of what is on but not drawn,
and why (no clustering, its molecule not loaded or without its frames;
the picks' the same), and of what is drawn otherwise than asked, said on
the console too: a ``-sel`` that selects nothing there, or is no selection
(given with no molecule loaded, it was kept unchecked), is drawn as the
residues of the atoms clustered, and ``-frames`` past the molecule's last
are left out. ``-sel`` is checked on the clustered molecule, else on the
top one. A session that saved such a ``-sel`` or ``-frames`` loses it
alone when it is opened, with a warning; the rest of its drawing is kept.

Runs
----

.. code-block:: tcl

   vmdance runs            ;# {id label current} ... (the last 25)
   vmdance run 2           ;# back to run 2
   vmdance run label 2 "the long one"
   vmdance run delete 2
   vmdance run clear       ;# every run, scan and pick

Files
-----

.. code-block:: tcl

   vmdance export dir ?-prefix vmdance? ?-items {...}? ?-top 10? ?-lag 1? ?-format dcd|pdb? ?-sel all?
   vmdance session save file.vmdance
   vmdance session load file.vmdance ?-mol auto|load|none|id?
   vmdance session import file.mdance ?-mol auto|id? ?-label text?
   vmdance figures dir ?-plots {...}? ?-formats {pdf png}? ?-width 900? ?-height 560? \
       ?-dpi 300? ?-text 12? ?-prefix vmdance? ?-options {setting value ...}? ?-3d 0|1? ?-renderer auto?
   vmdance figures dir -plots {} -3d 1   ;# the 3D view alone

:doc:`files` describes them. ``export`` and ``figures`` make their folder
when it does not exist; an export writes all its files, or none. Without
``-items``, above 300 clusters, an export leaves out the transitions (k²
rows: written when named) and the distances and the tree, which are not
made then.
