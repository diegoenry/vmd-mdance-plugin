Scans
=====

A scan clusters the same frames many times, and keeps every clustering: its
scores and its clusters' sizes in the table and the plots, its labels to
make it the clustering later (measured then). The coordinates are read once
for the whole scan (twice more for HELM's scores with a trim, every k's
together; the library is given one list of them for every clustering, made
once). A value that its parameters cannot take (NANI's seeds
at a larger k, HELM's starting clusters: counted after its first
clustering, and its trim, ``-trim-val``'s once HELM has run; with the
library, DIVINE seeded by CompSim below 50% above k 2, which would take VMD
with it) is kept as *not run*, with the reason, and the scan goes on (a
scan where none can run is refused, and the one there was is kept); a
clustering that fails is kept as *failed*,
with the backend's message (a crash of ``mdance-cli`` too). ``mdance-cli``
ended from outside (Ctrl+C at VMD's terminal, ``kill``) stops the scan, as
Cancel does, and the scan that was there is kept.

Elbow
-----

The Setup's algorithm and parameters at every k of a range. From the
command a scan takes its own options, as a clustering does: one not given
is the command's default (Cα, KMeans NANI seeded ``StratAll``), not the
current run's — ``vmdance elbow -sel backbone -kinit CompSim -from 2 -to
15 -by 1`` (or ``-ks {…}``) follows a backbone clustering seeded by
CompSim; the scan says what it reads, and notes when that is not what the
current run clustered. HELM starts from the same clusters at every k (its
first NANI clustering is made once); a record's number of clusters counts
those with frames. The Elbow
plot shows the two scores; a knee in Calinski–Harabasz, or a low point of
Davies–Bouldin, suggests a k. Hover a k for its clusters' shares — a k at
which one cluster takes nearly everything, or several hold a few frames, is
seldom the one. ``vmdance elbow load 6`` (or a double-click) makes that
k the clustering.

Sweep
-----

Every combination of algorithms (KMeans NANI, DIVINE, HELM), values of k,
metrics and seedings, in that order: ``vmdance sweep -algorithms {kmeans
helm} -from 2 -to 10 -metrics MSD -seedings {StratAll CompSim}`` (DIVINE
with a metric other than MSD is kept as *not run*: it splits by MSD; and
neither scan takes its ``-end-mode points``, which does not use k). The
other parameters are the Setup's (``-params {kmeans {percentage 20}}`` in a
script, where a seeding is refused: it is ``-seedings``), and the input the
options given (as the elbow's). HELM's seeding is its first clustering's;
HELM from a label file (no first clustering) and DIVINE with pair anchors
(no NANI) use none, and are run once at each k, their seeding *none*.
The table marks the best Calinski–Harabasz (green) and the best
Davies–Bouldin (blue): a failed configuration, or one without scores (one
cluster, or every cluster a frame alone), is never best, and of equal
scores the first wins.
``vmdance sweep best db`` names it; ``sweep load n`` (or a double-click)
makes a configuration the clustering. More than 50 configurations are
confirmed first; Cancel stops the sweep between clusterings or during one
(with the library, VMD waits for each, and Cancel acts when it ends).
