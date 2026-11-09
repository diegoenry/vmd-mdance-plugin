Questions
=========

**"no MDANCE backend was found"** — build CPP-MDANCE (:doc:`install`) and
set ``MDANCE_CLI`` to its ``mdance-cli``, in ``~/.vmdrc`` (``set
env(MDANCE_CLI) …``) or with **Settings ▸ Backend** (scripts use it too;
in one, ``vmdance backend -mode cli -cli path``).

**VMD has no Extensions menu.** VMD 2's main window has none: the plugin
is under **Analysis ▸ VMDance** there (**Extensions ▸ Analysis ▸ VMDance**
in VMD 1.9). ``vmdance`` in VMD's console opens it in either.

**DIVINE is not offered.** Your CPP-MDANCE was built without it (a tree
before its PR #52 of 1 October 2026, or ``BUILD_DIVINE`` off); the note
under the algorithm says so. A program rebuilt
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
frames also separate by where the molecule drifted. The fit is off unless
ticked; a run's summary and name say whether it was fitted.

**Is my trajectory aligned?** Setup says. With the fit off, the note under
*Fit to the first frame* gives how far a sample of the frames is from the
first, as they are and once fitted, and warns (in a red-brown tone) when
they do not look superposed: when a fit halves that distance and takes an
ångström off it. ``vmdance alignment`` returns the same numbers, and the
command notes it when it clusters such frames unfitted. A flexible
molecule can be far from its first frame both ways (the tau peptide: 4.15
Å as it is, 3.96 Å fitted): that is its motion, and no warning. Frames
that were not aligned, clustered as they are, give clusters of where the
molecule is, not of its shape.

**Which k?** Scan it: **Scans ▸ Elbow**, with *Stability* ticked. The
Elbow plot rings where the scores point — Davies–Bouldin's lowest value
and its sharpest dip (MDANCE's two criteria), Calinski–Harabasz's highest
— and the Scans box says them, with the k the four seedings agree on.
They need not agree: the lowest value is the best-separated partition,
often the coarsest; the dip is where the score bends; the stability says
up to which k the clusters are the same whatever the seeding
(:doc:`tutorial` reads a scan where the three differ). Then look: at the
clusters' shares (hover the plot: not one large cluster and crumbs), at
the Map (do the frames gather in groups at all?), and at the clusters,
their Compactness, Silhouette and Timeline. Report which reading you took.

**Å or Å²?** The distances are squared as they are measured: the RMSD²
between two structures, and MDANCE's MSD of a cluster (Å²). **Plot options
▸ All plots ▸ Distances as ▸ Lengths** shows their square roots, in Å, in
the plots and the table of clusters: RMSD and √MSD, the unit RMSD cut-offs
are given in. The exported tables keep the values as measured, and their
columns' names say which they are. eQUAL's radius stays MDANCE's MSD (Å²:
half the RMSD² of a frame and its seed); Setup writes the RMSD it stands
for, √(2 × radius), under the field.

**Can the plots read in ns?** Give the time between two frames of the
molecule: **Plot options ▸ All plots ▸ Time per frame** (``0.1 ns``, ``2
ps``; the Timeline's option row has the field too). The Timeline and the
Residence then read in time. The transitions' lag stays in clustered
frames.

**Which silhouette?** The one from the clusters' mean structures is the
default: cheap, and never below zero for
k-means, so that it cannot flag a frame on a border there. The one from
every frame, of the squared distances, is the classic silhouette (**Plot
options ▸ Silhouette ▸ From**; ``vmdance silhouette -kind pairs``): it can
be below zero, and it is the number scikit-learn gives with
``metric="sqeuclidean"`` (its default metric, ``euclidean``, gives
another). On the tau peptide at k 3 they are 0.25 and 0.27, with 537
frames below zero by the second. Say which one you report.

**Has my run converged?** **Results ▸ Groups ▸ Halves** makes the two
halves of the clustered frames two groups: the Make-up plot shows each
cluster by half, and the line under the box how unlike the halves are (the
Jensen–Shannon divergence of their shares of the clusters: 0, the same;
0.69, no cluster in common). The Timeline's *Each cluster's share so far*
draws the populations along the run: lines that have settled say they
have.

**The clusters are not numbered by size.** They have the backend's
numbers, which are MDANCE's: every label is the one MDANCE gives. The
Populations plot can order them largest first; **Results ▸ Run ▾ ▸ Number
its clusters by size** (``vmdance renumber``) makes a new run numbered
from the largest, and leaves the original as it was.

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
