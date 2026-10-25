Files
=====

Sessions
--------

A session (``.vmdance``) keeps every run — its request, its clustering,
the plugin's measures, and what was asked of it (PRIME, the similarity, the
groups and their colours, the map, the profiles) —
the elbow scan, the sweep, the picked frames, the selection, and the plots'
and 3D settings of the window. It is gzip-compressed UTF-8 text:
``VMDanceSession 1`` on the first line, then a Tcl dictionary that is
read as data, never evaluated. Every run is checked as a new clustering is
(the labels and sizes, the representatives, the measures' sizes, the
numbers), and so are the scans and the picks, before anything is replaced:
a damaged file changes nothing. A session is read up to 400 MB unpacked and
50 million values (lists are counted before they are made, because a few
kilobytes of text can otherwise allocate gigabytes: a value takes about 120
bytes once read). A run takes some 40 bytes a frame, and for ``k``
clusters, 300 or fewer, two ``k×k`` tables of the distances between them,
about ``16·k²`` bytes (1.5 MB at 300; a session made before keeps them for
more, which are left out as it opens), and a sweep every configuration's
labels, so sessions of many runs, or of large sweeps, are large; a **save
that would be larger than can be read back is refused, and the file is left
as it was**, naming what to drop, the largest first: runs to delete
(``vmdance run delete id``, or **Clustering ▸ Delete this run**), the
scans or the picks to clear (``vmdance elbow clear``, ``sweep clear``,
``pick clear``), or what is too large alone to keep, whose tables can be
exported. The limits are ``::VMDance::Session::max_bytes`` and
``max_values``: raised where a session is saved and where it is opened
(``set ::VMDance::Session::max_values 60000000``), a larger one is saved
and opened.

A session keeps each molecule's files as VMD keeps them (as typed) and by
their names in full, made in the folder VMD is in when it clusters (VMD
does not keep the folder a name was typed in). On opening, each run's
molecule is the first that has its frames among those loaded (its files,
in full or as typed; then the same name and number of atoms), else among
its files loaded (``-mol auto``, the default): by their names in full, from
the session's folder (a session moved with its files), or as typed, from
VMD's folder; a molecule of the user's from its files that has not is
taken as it is (said below), not loaded again. ``-mol load`` always loads
the files; ``-mol none`` does not look for the molecule (the tables and
plots work, the 3D drawing and the questions that read the coordinates
again wait for it); ``-mol id`` puts every run on one molecule (which must
have the same number of atoms).

Every run, the scans and the picks are then checked against the molecule
they are put on: the coordinates at their frames must be those they were
made from (their digest), or the same frames moved in place rigidly since
(each frame's radius of gyration: a trajectory aligned before it was
clustered). Another trajectory of the same file names (a replica's
folder), files written over since, or frames deleted or added before them
are said in a warning, and that run's frames are refused (no 3D views,
goto, ``frame``, user field, structure exports, PRIME or similarity: its
tables still answer). A molecule the session loaded itself with frames
before the clustered ones that it did not have then — a PDB's own frame,
deleted after loading, as MDANCE's tutorial does — gets them deleted
again; one of the user's is never changed: the warning, and every refusal
then, says which frames to delete (``animate delete beg 0 end 0 m``), and
once they are deleted its frames are the clustered ones again. The picks
of a session made before they kept what tells their frames are listed
only (pick them again).

A molecule is loaded from its files only when every file is a
regular, non-empty file (or a DESRES trajectory's folder) of one of VMD's
own file readers, with no FIFO or device beside it, or in the folders of a
DESRES trajectory (a reader opens files beside the one named: VASP's
POTCAR, a DESRES trajectory's own), and, for the AMBER and NetCDF readers,
which give its name to a shell, named without the characters a shell acts
on; a session from someone else cannot make VMD run a file through an
external converter (the Babel formats), download it (``webpdb``), give its
name to a shell, or block on a FIFO or device. The molecule is then left
unloaded, with a warning that says why.

A session saved by an earlier version opens as one saved now would: the
backend's placeholders it kept are left out (a cluster without frames had
an MSD and an iSIM of 0, every cluster a frame alone the scores 1 and 0,
and a scan's record counted the clusters without frames). HELM's scores
with a trim are kept as they were made: CPP-MDANCE's, which count the
trimmed frames as one more cluster (cluster again for those of the
clustered frames).

Sessions of the MDANCE plugin
-----------------------------

**File ▸ Import a session of the MDANCE plugin** (``vmdance session
import file.mdance``) reads the old plugin's session as data: its
clustering, its frames (every n-th of a range), its selection and
parameters (HELM's ``pre-k`` becomes ``-initial``, and its label file
``-initial-labels``, named as the file names it: a run of the imported
request reads it again, or says it cannot), and the name and frames of its
molecule, which must be loaded (or given with ``-mol``). Its values are
counted before any list is made of them: a file that holds more than a
clustering of the frames loaded is refused at once (its selection, which an
index list can make long, is counted apart, and refused past 200 000
words: VMD's own parser fails on a few hundred thousand). Its molecule is a
loaded one of that name (any, when the file does not know it) with the
frames clustered, whose coordinates give the clusters' MSDs the file holds
(MDANCE's, which its backend computed): those of the number of frames the
file recorded first (with frames added since, a warning says so), the
molecule id the file names first among them, and when none agrees the
import is refused, naming them (a molecule whose clustered frames cannot be
read is passed over); when the file holds no MSD to compare,
only the one molecule of its name and number of frames is taken. A
molecule given with ``-mol`` is taken, with a warning when its coordinates
do not agree; the window offers the molecule chosen in Setup when it finds
none. The plugin's measures are computed from the coordinates, and the
clustering becomes a run, named *(imported)*; the window's status names
the molecule taken.

The old plugin kept less than a run needs, and the import says so rather
than make it up:

- **HELM's merges** are numbered among its starting clusters, which the
  file does not keep. After a trimming they cannot be placed (nor when
  frames are in no cluster). Stopped by
  ``-eps``, an ``mdance-cli`` built before CPP-MDANCE 4042c24 kept, as its
  last merge, the one ``-eps`` refused: it is left out when the merges tell
  it (each one's count of starting clusters, and the ``pre-k`` asked for),
  and when they cannot, so are the others (merges of all ``pre-k`` starting
  clusters are also those of one fewer, which NANI can leave empty, and the
  refused one). Merges left out are said in a
  warning: the tree is then the linkage of the mean structures, and the
  clustering is imported.
- **A configuration of its sweep**, made the results with *Load Selected*,
  was saved without its parameters. MSD and the defaults are taken, and the
  run says they are not recorded: its name ends *(imported; parameters not
  recorded)*, the tables' ``#`` header says so in place of them, ``info``
  has ``unrecorded {metric params}``, and Setup keeps its own.
- **Its numbers** are read as the plugin took them (``+10``, and a
  zero-padded ``010``, which ``mdance-cli`` read as 10 and its library as
  8): the number of clusters by the reading that is the clusters it found,
  the others as ``mdance-cli`` read them, with a warning when its library
  read them otherwise.

Export
------

**File ▸ Export results** (``vmdance export dir -prefix name -items
{…}``) writes, as ``name_item``:

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Item
     - Content
   * - ``summary``
     - what was clustered, how, and the clusters (text)
   * - ``clusters``
     - ``cluster,frames,percent,msd,msd_to_representative,representative_frame,mean_silhouette``
       (``msd`` MDANCE's, within the cluster; ``msd_to_representative`` the
       mean RMSD² of its frames from the representative)
   * - ``labels``
     - ``frame,cluster`` of every clustered frame (-1: noise); HELM reads it
       back as starting clusters
   * - ``top``
     - ``frame,cluster,rank,msd_to_representative``: each cluster's
       ``-top`` frames nearest its representative (rank 0 is the
       representative)
   * - ``timeline``
     - ``frame,cluster,msd_to_representative``
   * - ``transitions``
     - ``from_cluster,to_cluster,count,probability`` (lag ``-lag``; a
       column -1 when there is noise, so that each row sums to 1; no
       probability in a row with nothing counted; k² rows: above 300
       clusters, written only when named)
   * - ``residence``
     - ``cluster,visits,mean_frames,min_frames,max_frames`` (in clustered
       frames)
   * - ``silhouette``
     - ``frame,cluster,silhouette``
   * - ``distances``
     - ``cluster_i,cluster_j,centroid_msd,representative_rmsd``
       (``centroid_msd`` the RMSD² between the mean structures; 300
       clusters or fewer: not measured above)
   * - ``tree``
     - ``left,right,distance,count``: the dendrogram's merges (the average
       linkage: 300 clusters or fewer; HELM's: any number)
   * - ``representatives``
     - the representatives' structures, one frame per cluster with frames,
       in the clusters' order (an empty cluster has none: the frames are
       then fewer than k); ``-format dcd`` with a PDB of the atoms, or
       ``pdb``; ``-sel`` the atoms
   * - ``trajectories``
     - each cluster's frames as a trajectory of its own
       (``name_cluster_c.dcd`` and ``.pdb``, or ``.pdb``); those an
       earlier export left under the name that this one does not write (a
       larger k, the other format) are deleted, the window asking first
   * - ``prime``, ``similarity``
     - PRIME's seven frames; each cluster's iSIM and least similar frame
   * - ``groups``
     - ``frame,cluster,group`` of every clustered frame (no group: empty)
   * - ``makeup``
     - ``cluster,group,frames,share_of_cluster,share_of_group``
   * - ``map``
     - ``frame,cluster,group,pc1,pc2`` (Å; the ``#`` lines give each axis's
       share of the variance)
   * - ``profiles``
     - ``atom,residue,chain``, then each cluster's and each group's RMSF
       (``rmsf_cluster_c``, ``rmsf_group_name``) and each cluster's mean
       structure's distance from the reference's
       (``distance_cluster_c_from_r``), atom by atom (Å)
   * - ``elbow``, ``sweep``
     - every k or configuration and its scores (the elbow's stability, when
       it was measured; an eQUAL scan's radius in place of k)
   * - ``picks``
     - the picked frames

Every table starts with ``#`` lines that say what was clustered (the
molecule and its files, the atoms, the frames), how (the algorithm, k, the
metric, every parameter; a sweep's, each algorithm's but the seeding, which
is a column), what came out (the clusters, the scores, the noise), with
which backend and when (a scan's and the picks' too). Each ``#`` line is
one line: a selection written over several lines is joined with spaces.
Frames are VMD's frame numbers.

An export is checked whole before anything is written: each item has what
it needs (a clustering, PRIME, a scan, the molecule with its frames),
``-sel`` holds atoms at the first frame of each structure, and no file it
writes is a folder or read-only. The folder is made when it does not
exist (and deleted again when the export fails). Every file is written
under a temporary name beside it that only the plugin made (a link put
there is never followed), and an export's files are renamed into place
once all of them are written: a failure, a full disk too, changes none
(only a rename the system refuses at the end can leave some in place: the
error names them). A file replaced keeps its permissions, where the system
allows it; a link of the user's stays a link, and the file it points to is
written; a link of another user's is replaced, and what it points to left
alone, its permissions too. Sessions, the preferences and figures are
written the same way.

The structures are written as VMD writes them, from the clustered
molecule (no molecule is made): a DCD keeps every frame's unit cell; a PDB
is VMD's PDB writer's, frame by frame (residues past 9999 in its
hexadecimal, each frame's unit cell). A PDB holds coordinates from -999.999
to 9999.999 Å: a frame beyond them is refused, naming it (a DCD holds it,
but for the file's first frame, which the PDB beside a DCD has); so is an
occupancy or a beta beyond them, in either format (leave those atoms out).

**File ▸ Quick export** writes one table: the clusters, or the data of the
plot shown.

Figures
-------

**File ▸ Create figures** (``vmdance figures dir -plots {…} -formats {pdf
png eps} -width -height -dpi -text -prefix``): the plots, drawn again at the
size asked, as EPS, and through Ghostscript as PDF and PNG, their text at
``-text`` points (8 to 24; 12 by default); ``-options {setting value …}``
sets plot options for these figures only (``tl_view msd``, ``ds_show
representatives``, ``mu_view groups``, ``mp_colour cluster``, ``pf_show
differences``, ``td_view heights`` …); ``-3d 1`` renders the 3D view too
(``-plots {} -3d 1``: it alone), with ``-renderer auto`` (TachyonInternal,
else a snapshot), ``snapshot`` or another of VMD's internal ray tracers
(OptiXInternal, ANARIInternal): VMD's exporters (POV3, Tachyon, Wavefront
…) write no image, and are refused before any figure is written. The
folder is made when it does not exist. Tk draws the figures: they need a
display, which text-mode VMD has not (its launcher unsets ``DISPLAY``);
make them in VMD with its window, from a session saved in text mode if
need be (``vmdance session load file -mol none``, then ``vmdance
figures dir``).
**File ▸ Quick export ▸ 3D view** renders it as a PNG (TachyonInternal, or
a snapshot).
