Glossary
========

.. glossary::

   run
      A clustering kept by the plugin: its request, its clusters, the
      plugin's measures and what was asked of it. The last 25 are kept; one
      is current.

   representative
      A cluster's medoid as MDANCE finds it (by complementary similarity:
      nearly always the frame nearest the cluster's mean structure); the
      backend's.

   noise
      Frames in no cluster, label -1, grey everywhere: eQUAL's outside every
      cluster (and its last frames or two, which it never places), and the
      frames of the starting clusters HELM trims.

   MSD
      MDANCE's mean square deviation of a set of frames: the mean, over
      every pair of its frames (each with itself too), of their squared
      distance per atom — twice the mean squared distance from the set's
      mean structure; for two frames, half their RMSD². The backend's
      clusters' MSD, eQUAL's radius and the similarity ceiling are this.

   RMSD²
      The squared distance per atom between two structures (no fit): the
      plugin's own measures (a frame from its representative, two
      representatives, two mean structures) are these — twice MDANCE's MSD
      of the pair.

   row
      A frame of the clustering, by its place in the clustered frames: the
      backend's indices are rows; the plugin gives VMD's frames.

   scan
      Many clusterings of the same frames: an elbow scan (one algorithm at
      several k) or a sweep (a grid of algorithms, k, metrics and seedings).

   seeding
      How NANI chooses its k initial centres (``-kinit``).

   visit
      A run of consecutive clustered frames in one cluster; its length is a
      residence.
