Tools
=====

PRIME
-----

PRIME predicts the representative, native-like frame of an ensemble from
its clusters:

1. It takes the most populated cluster (c0).
2. It leaves out its least representative frames (``-trim-frac``, 10%).
3. It scores the rest by their n-ary similarity to the other clusters
   (``-metric RR``, Russell–Rao, or ``SM``, Sokal–Michener), weighted by
   the clusters' sizes (``-weighted 1``). It scores them four ways:
   pairwise, as a union, to their medoids, to their outliers.

With them come three baselines: the medoid of all frames, of c0, and of
c0 trimmed. ``vmdance prime`` returns the seven as VMD frames. They are
kept with the run and in sessions.

PRIME needs a cluster besides c0.

Similarity (iSIM)
-----------------

MDANCE's extended (n-ary) similarity of all the frames, and of each
cluster, with its least similar frame.

``-metric`` chooses the index, MSD by default. With MSD, lower is
tighter, and a cluster's iSIM is its MSD within: the same numbers as
Compactness shows by default.

The command is ``vmdance similarity``. The Compactness plot shows each
cluster's.

Pick frames
-----------

Frames chosen among the Setup's frames without clustering
(``vmdance pick``). They can be:

- **The most diverse** (``diversity``). ``-param`` is a whole percentage
  of the frames, 1 to 100: CPP-MDANCE reads a number below 1 as a share,
  and drops the decimals of the others. The window's field is then named
  *% of the frames* (*How many* for the others). It takes
  ``-metric MSD`` only, as CPP-MDANCE's diversity selection reads past its
  data with the other indices.
- **The outliers** (``outliers``): a number of frames, or a share below 1
  that holds a frame at least.
- **A representative sample** drawn over the similarity (``repsample``): a
  number of frames or a share below 1, one frame at least, with
  ``-nbins`` bins.
- **The medoid** or **the outlier** (one frame).

A frame picked twice is refused as the backend's error.

The 3D tab draws them, on their molecule. A double-click on the list goes
to one (``vmdance pick goto f``). **Save…** writes them
(``vmdance pick save file``):

- as PDB, a model each, named *picked frame f* in a ``REMARK``;
- or as DCD, with a PDB of the atoms beside it, of the same name. You are
  asked first when one is there: it may be the molecule's own file.

They keep what tells their frames, as a clustering does. Once their
molecule's frames are deleted before them, or loaded otherwise, they are
listed only: pick them again.
