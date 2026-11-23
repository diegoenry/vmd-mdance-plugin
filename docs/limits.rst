Notes and limits
================

What the plugin cannot do, or does at a cost, and where its results and
MDANCE's part.

- The library blocks VMD while it clusters; the status line says so. A
  call cannot be cancelled: Cancel acts when it ends. Use the program for
  long trajectories.
- A clustering writes every frame's coordinates to a file in the plugin's
  private folder: 3 × atoms numbers per frame. This is the program's
  input, written with the library too, and it is kept for the questions
  that follow. The plugin's measures read the coordinates again from VMD,
  in two passes. So a trajectory of any length takes the memory of a few
  frames (6002 frames of 217 atoms: 9 MB, 5.5 s with KMeans NANI and the
  measures). A folder that cannot take the file says so: free room there,
  or set ``TMPDIR``.
- The distances between the clusters (k × k: their mean structures and
  their representatives) and the tree of the mean structures are made for
  300 clusters or fewer. The thousands of clusters eQual makes at a small
  radius would take gigabytes of VMD's memory, kept until it quits.

  - ``vmdance distances`` and ``tree`` then say so. HELM's tree is its
    merges, at any number.
  - An export then leaves them out, and the transitions too unless named
    (k² rows).
  - The measures left grow with the frames and the clusters. A frame's
    silhouette needs the nearest other cluster's mean structure. It is
    looked for among those the triangle inequality leaves, not every one
    (4000 frames of 60 atoms in 1462 clusters: 14 s, 35 s against every
    one). These measures say how far they are, and the window's Cancel
    stops them.

- The library is given the coordinates as one Tcl list, the same for every
  call of a job; a scan reads the frames for it once. CPP-MDANCE's Tcl
  binding makes a text of that list once.

  - A call takes about 180 bytes of VMD's memory a coordinate at its peak.
    Tcl keeps about 120 of them until VMD quits, for the calls after.
  - Past 2 GB of text (about 110 million coordinates: 20,000 frames of
    1,900 atoms), Tcl ends VMD, whatever the memory.

  A library call that cannot fit (the memory available to VMD, its
  cgroup's too), or that would pass 2 GB, is refused. It is refused before
  the frames are read when that can be told. The program takes neither
  limit.
- The private folder is in ``TMPDIR``, readable by you only. It is named
  for the machine, its PID namespace and the VMD process, with a random
  part. So a ``TMPDIR`` shared by machines or containers is safe. What a
  VMD that was killed or crashed left there is removed by the next one of
  the same machine and namespace.

  VMD writes there too (structures, the 3D view). It opens a file by its
  name's UTF-8 bytes, where Tcl takes the locale's (iso8859-1 with
  ``LANG=C``). VMD is given the name whose UTF-8 bytes are the file's, so
  a ``TMPDIR``, or a session's molecule, outside ASCII works with
  ``LANG=C``. A ``TMPDIR`` whose name is not UTF-8, with a locale that is
  not, is passed over. This is said if no private folder can be made
  elsewhere.
- ``mdance-cli`` ended from outside (Ctrl+C at VMD's terminal, ``kill``)
  stops the whole job, a scan too, as Cancel does. What was there is kept.
  A crash of it fails that clustering, and a scan goes on.
- MDANCE's published runs cluster the Cα atoms. On those atoms the plugin
  reproduces exactly:

  - their populations: KMeans NANI k 6 with three seedings, and HELM
    merging ``Inter`` (as MDANCE's runs do; the default is ``Intra``) from
    MDANCE's 60 starting clusters. This is on the tau peptide, which the
    runs call the heptapeptide, and protein G.
  - their elbow screens' labels, but at two kinds of k. Scikit-learn's
    k-means (MDANCE's) stops at its tolerance, where CPP-MDANCE's goes on
    to convergence (the tau peptide, k 5). And CPP-MDANCE's leaves an
    emptied cluster empty (protein G from k 12: 1 to 6 empty).

  On the backbone the shares differ by up to 0.009 (CompSim: 0.086). This
  is another choice of atoms, not another program.
- The stratified seedings take frames at evenly spaced positions. Where one
  falls on a half (50 frames at 10%: 24.5), CPP-MDANCE rounds it away from
  zero and MDANCE (NumPy) to even. The seeds and clusters then differ
  (3ptb's Cα, frames 0–49, KMeans NANI k 4: 19 11 10 10 frames against
  25 11 10 4). DIVINE's splits of some sizes, and HELM's first clustering,
  differ too. It depends on the number of frames and of seeds: it happens
  more often with few frames or many seeds. The reference suite records
  it.
- DIVINE (a CPP-MDANCE built with it, main since its PR #52):

  - Refining a pair anchors' split, it seeds a side of two frames with the
    one its round-off makes their medoid, where MDANCE takes the first.
    This gives another clustering, now and then.
  - It crashes refining an OutlierPair split of identical frames. MDANCE
    fails there too; the plugin refuses it.
  - Its Tree is the average linkage of the mean structures, not its
    splits, which CPP-MDANCE does not return.
  - With ``-end-mode points`` it returns the last clustering only, not
    MDANCE's scores at every split. An elbow scan with ``-end-mode k``
    gives them.
  - A later split of a cluster too small to seed fails the run. With
    CompSim, it crashes the program: the library is refused CompSim below
    50% above k 2.

- KMeans NANI seeded by CompSim can end with an empty cluster.
  CPP-MDANCE's k-means does not move a cluster that loses its frames;
  scikit-learn's, in MDANCE's Python, does. On a constructed three-state
  trajectory whose densest frames are all in one state, it merges two
  states.

  The plugin shows the empty cluster, with no representative, MSD or
  similarity: the backend's 0 would read as the tightest. A scan's record
  counts the clusters with frames (``nclusters``, the tables' k_actual).
- ``-metric`` other than MSD is passed on as it is. Those indices are for
  binary or fingerprint data, not Cartesian coordinates. It is refused:

  - with the seedings and the pick that use the diversity selection
    (CompSim, DivSelect, eQual's comp_sim, the most diverse frames). On
    coordinates CPP-MDANCE reads past its data there (``mdance-cli``
    crashed, or every frame landed in one cluster), and MDANCE's Python
    stops.
  - with eQual, whatever the seeds. On coordinates every frame is within
    any radius of the seed by those indices, and all landed in one
    cluster.

- VMD crashes freeing a selection of about 100 000 separate values (VMD
  2.0 on Windows; about 700 000 on Linux). The plugin:

  - hands VMD its texts with the lists of whole numbers after ``index``,
    ``serial`` and ``residue`` written as ranges;
  - names its own atoms where it can (``name CA and index 4 to 99990``);
  - refuses a text of more than 50 000 separate values, saying what to
    select instead.

- It is developed and tested in VMD 2.1 on Linux.

  - On Windows (VMD 2.0) the text-mode suites run, but for what needs Unix
    (file permissions, FIFOs) and the shared test systems. The windowed
    suites are read in the system encoding there, and their checks of
    text outside ASCII fail.
  - macOS is untested. Its look comes from the reference plugins' theme
    code.
