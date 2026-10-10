Tools
=====

PRIME
-----

PRIME predicts the representative, native-like frame of an ensemble from
its clusters: it takes the most populated cluster (c0), leaves out its
least representative frames (``-trim-frac``, 10%), and scores the rest by
their n-ary similarity (``-metric RR``, Russell–Rao, or ``SM``,
Sokal–Michener) to the other clusters — pairwise, as a union, to their
medoids, to their outliers — weighted by the clusters' sizes
(``-weighted 1``). With them, three baselines: the medoid of all frames, of
c0, and of c0 trimmed. ``vmdance prime`` returns the seven as VMD frames;
they are kept with the run and in sessions. PRIME needs a cluster besides
c0.

Similarity (iSIM)
-----------------

MDANCE's extended (n-ary) similarity of all the frames, and of each
cluster, with its least similar frame (``-metric``, MSD by default: then
lower is tighter, and a cluster's iSIM is its MSD within, the same numbers
as Compactness shows by default). ``vmdance similarity``; the Compactness plot shows
each cluster's.

Pick frames
-----------

Frames chosen among the Setup's frames without clustering (``vmdance
pick``): the most diverse (``diversity``, ``-param`` a whole percentage of
the frames, 1 to 100: CPP-MDANCE reads a number below 1 as a share, and
drops the decimals of the others; with ``-metric MSD`` only, as its
diversity selection reads past its data with the other indices), the
outliers (``outliers``, a number of frames, or a share below 1 that holds a
frame at least), a representative sample drawn over the similarity
(``repsample``, a number of frames or a share below 1, one frame at least,
with ``-nbins`` bins), the medoid or the outlier
(one frame). A frame picked twice is refused as the backend's error. The
3D tab draws them, on their molecule; a double-click on the list goes to
one (``vmdance pick goto f``); **Save…** writes them as PDB, or DCD with a
PDB of the atoms beside it, of the same name (asked first when one is
there: the molecule's own file may be; ``vmdance pick save file``).
They keep what tells their frames, as a clustering does: once their
molecule's frames are deleted before them, or loaded otherwise, they are
listed only (pick them again).
