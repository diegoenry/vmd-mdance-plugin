VMDance
==========

**MDANCE clustering of a trajectory, inside VMD.**

VMDance is a Tcl/Tk plugin for `VMD <https://www.ks.uiuc.edu/Research/vmd/>`_.
It clusters the frames of a trajectory with the algorithms of
`MDANCE <https://github.com/mqcomplab/MDANCE>`_ — KMeans NANI, DIVINE, HELM
and eQUAL, run by their C++ port
`CPP-MDANCE <https://github.com/mqcomplab/CPP-MDANCE>`_ — and shows the
clusters in ten linked plots and on the structure in VMD's 3D window.

.. figure:: _static/figures/window.png
   :alt: The VMDance window with the table of clusters and their populations.
   :width: 100%

   MDANCE's tau peptide (6001 frames, the backbone): KMeans NANI, k 6,
   complementary-similarity seeding; cluster 2 selected.

.. list-table::
   :widths: 26 74

   * - **Cluster**
     - A molecule's frames — all, a range, every n-th — by the coordinates
       of the same atoms, with KMeans NANI, DIVINE, HELM (from a first NANI
       clustering or a label file) or eQUAL (clusters within a radius, and
       noise); optionally fitted to the first frame, on the values.
   * - **Compare**
     - The Calinski–Harabasz and Davies–Bouldin scores of every clustering;
       an elbow scan over k, a sweep over algorithms, k, metrics and
       seedings; any of them made the clustering with a double-click.
   * - **Explore**
     - The populations, the timeline of the clusters, their transitions and
       residence times, how tight and how far apart they are, the tree that
       joins them, every frame's silhouette. A cluster has one hue
       everywhere, in the plots and in VMD's 3D window.
   * - **Ask**
     - PRIME's native-like frame, MDANCE's extended similarity (iSIM),
       frames picked without clustering (the most diverse, the outliers …).
   * - **See it in 3D**
     - The structure coloured by the cluster of the current frame, following
       the trajectory; every representative at once; the selected clusters'
       frames overlaid.
   * - **Keep and share it**
     - Every clustering kept as a run; sessions (the MDANCE plugin's too);
       tables with a header that says how they were made; the
       representatives' structures and each cluster's trajectory; figures.
   * - **Script it**
     - One ``vmdance`` command that works in text-mode VMD.

Where to start
--------------

- New to the plugin: :doc:`install`, then :doc:`quickstart`.
- The window, tab by tab: :doc:`window`; the plots: :doc:`plots`.
- The algorithms and their checks: :doc:`algorithms`; every parameter:
  :doc:`parameters`.
- Scripts: :doc:`command`. Files: :doc:`files`.
- Coming from the MDANCE plugin: :doc:`differences`.

.. toctree::
   :maxdepth: 2
   :caption: Using it

   install
   quickstart
   window
   algorithms
   parameters
   plots
   scans
   tools
   threed
   files

.. toctree::
   :maxdepth: 2
   :caption: Reference

   command
   design
   internals
   differences
   tests
   faq
   glossary
