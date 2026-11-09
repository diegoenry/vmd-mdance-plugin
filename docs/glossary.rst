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
      of the pair. The plots and the table show them, and the MSD, as
      lengths (Å: RMSD, √MSD) when *Distances as* asks for lengths.

   silhouette
      How well a frame sits in its cluster, (b − a) / max(a, b), from -1 to
      1. The plugin measures two. From the clusters' mean structures (the
      *simplified* silhouette, the default): a is the frame's RMSD from its
      own cluster's mean structure, b from the nearest other one; never
      below 0 for k-means. From every frame (the *classic* silhouette, of
      the squared distances): a is its mean RMSD² from the other frames of
      its cluster, b the smallest mean from the frames of another cluster;
      scikit-learn's ``silhouette_samples(metric="sqeuclidean")``. Their
      values are not on one scale: say which you report.

   variance explained
      The share of the frames' variance that the clusters account for:
      SSR/SST, the sum of squares between the clusters over the total. The
      plugin has it from the Calinski–Harabasz score, CH (k − 1) / (n − k +
      CH (k − 1)). It rises with k; the k where it bends is the elbow.

   Jensen–Shannon divergence
      How unlike two distributions are; here, two groups' shares of the
      clusters. 0: the same share of their frames in every cluster; ln 2
      (0.69): no cluster in common. ``vmdance groups compare`` and the line
      under the Groups box give it.

   stability
      Of a k in an elbow scan: how alike the clusterings from NANI's four
      seedings that draw no random number are (the mean adjusted Rand index
      of every two: 1, the same clusters). The seedings *agree* at 0.9 or
      more.

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

   time per frame
      The time between two frames of the molecule, given in the plot
      options (``0.1 ns``): the Timeline and the Residence then read in
      time. The plugin knows only frames otherwise.
