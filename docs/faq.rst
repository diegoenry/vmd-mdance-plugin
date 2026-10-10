Questions
=========

**"no MDANCE backend was found"** — build CPP-MDANCE (:doc:`install`) and
set ``MDANCE_CLI`` to its ``mdance-cli``, in ``~/.vmdrc`` (``set
env(MDANCE_CLI) …``) or with **Settings ▸ Backend** (scripts use it too;
in one, ``vmdance backend -mode cli -cli path``).

**DIVINE is not offered.** Your CPP-MDANCE was built without it
(``BUILD_DIVINE``); the note under the algorithm says so. A program rebuilt
with it at the same path (or behind a launcher) is asked again when the
algorithm chooser opens, and by a run.

**"DIVINE chose to split a cluster of fewer than 20 frames"** — each split
with NANI's anchors is a 2-cluster NANI, seeded from the densest share of
the cluster's frames: a small cluster gives fewer than its two seeds. Raise
*Seeds from %*, seed with k-means++, or ask for fewer clusters (an elbow
scan shows where it stops).

**"-k 10: NANI … seeds its 10 clusters from the densest 10% of the 60
frames"** — the extended-similarity seedings draw k seeds from that share
of the frames. Raise *Seeds from %*, cluster more frames, use fewer
clusters, or seed with k-means++.

**Should I fit the frames?** MDANCE clusters coordinates as they are: a
trajectory aligned on the atoms that matter (the backbone, say) clusters
shapes. If yours is not aligned, tick *Fit to the first frame*: otherwise
frames also separate by where the molecule drifted.

**Which k?** Scan it: **Scans ▸ Elbow**. Look for a knee in
Calinski–Harabasz, a low Davies–Bouldin, and clusters' shares that are not
one large cluster and crumbs (hover the plot). Then look at the clusters:
their Compactness, Silhouette and Timeline.

**A cluster has a large MSD and few frames.** It is often a bin of
outliers, not a state: Compactness ▸ MSD against size shows it; eQUAL at a
radius leaves such frames as noise instead.

**My clusters differ from MDANCE's Python.** Compare the same atoms first:
MDANCE's published runs cluster the Cα, and on those VMDance reproduces
their populations exactly (KMeans NANI, HELM); on the backbone they differ
by up to 0.09. Three things of the backend differ still: a stratified seed's
position on a half (50 frames at 10%: 24.5), which CPP-MDANCE rounds away
from zero and MDANCE to even; scikit-learn's k-means (MDANCE's) stops at its
tolerance, CPP-MDANCE's at convergence; and CPP-MDANCE leaves an emptied
cluster empty, where scikit-learn reseeds it. The seeds, and the clusters,
differ then.

**The library froze VMD.** A library call blocks VMD until it returns, and
cannot be cancelled (Cancel acts when it ends): choose the program in
Settings for long trajectories. The line at the bottom says so through the
call, and Setup says when *Automatic* took the library, having found no
program.

**"the library would need about … GB more in VMD"**, or **"cannot take …
frames × … atoms"** — the library is given the coordinates in VMD's own
memory (about 180 bytes a coordinate at its peak), and Tcl ends VMD when
their text passes 2 GB: use the program (it takes neither), or fewer atoms
or frames. In *Automatic*, the library is used only when no program was
found: set ``MDANCE_CLI``.

**"frame 5 of molecule 0 has coordinates that are not numbers"** — that
frame holds NaN or an infinity (a simulation that blew up, a file damaged
or converted): leave it out (``-first``, ``-last``, ``-step``) or delete it
(``animate delete beg 5 end 5 0``).

**"-metric BUB with -kinit CompSim …"** — the seedings, eQUAL's seeds and
the pick that use CPP-MDANCE's diversity selection read past its data with
an index other than MSD: use MSD, or another seeding.

**"-metric BUB with eQUAL …"** — eQUAL takes MSD only: by the other
indices every frame is within any radius of the seed on coordinates, and
all land in one cluster.

**Settings says the program "did not answer within 3 s".** It starts
slowly (a container, a network disk, a script that loads modules): its
algorithms are not known, so all are offered, and a run says if one is
missing. **Detect again** asks it again.

**A script as the program** (to set ``LD_LIBRARY_PATH``, or start a
container) works, and Cancel stops what it started too. Run ``mdance-cli``
in the foreground, best with ``exec``: one started in the background, by a
script that then ends, is out of the plugin's reach once Cancelled.
A docker or podman container runs under their daemon, not under the
script: run it with ``--init``, which passes Cancel's stop on to its
program (an Apptainer or Singularity container is the script's own).

**Colour by cluster shows grey.** The frame is noise (eQUAL), or outside
the clustered frames (before the first, after the last).

**My representations changed colour.** They did not: the plugin draws with
representations of its own. **3D ▸ Write the clusters to the user field**
is the one thing that changes the molecule's data, and only when asked.

**Can I open a session of the MDANCE plugin?** **File ▸ Import a session of
the MDANCE plugin**, with its molecule loaded (frames added after the
clustered ones are fine): the one whose coordinates give the file's cluster
MSDs is taken, and the status names it. When none does (a trajectory
aligned in VMD before it was clustered, a molecule renamed), the window
offers the molecule chosen in Setup; the command takes it with
``vmdance session import file.mdance -mol id``.

**A session says a molecule "does not have the clustered frames".** The
molecule it was put on is not the trajectory that was clustered: another
of the same file names (a replica's folder), files written over since, or
frames deleted or added before the clustered ones. Its tables still answer;
the 3D views, goto and the exports are refused. Load the files that were
clustered and open the session again (a session opened with nothing loaded
loads them by their names in full, from beside the session file, or as
typed), or delete the frames the warning names.

**The 3D drawing went away after I deleted frames.** It is drawn only while
the molecule has the frames that were clustered, at their numbers; the 3D
tab says why. Cluster the frames as they are now.
