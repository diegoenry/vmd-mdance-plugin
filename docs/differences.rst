Coming from the MDANCE plugin
=============================

VMDance replaces the MDANCE VMD plugin (``mdance::gui``, **Analysis ▸
MDANCE Clustering**). It drives the same backend with the same algorithms
and defaults, and measures the same things; what changed, and why:

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - 
     - MDANCE plugin
     - VMDance
   * - Scripting
     - ``mdance::gui`` and internal procedures
     - one command, ``vmdance``, for everything the window does
   * - Colour by cluster
     - wrote every atom's user field and redefined VMD's BGR colour scale
       (not put back); noise in the scale's lowest colour
     - a representation of the plugin's own, in the colour of the current
       frame's cluster, following the trajectory; noise grey. The user
       field is written only when asked (``userfield``)
   * - Results kept
     - one clustering
     - every clustering as a run (the last 25), with PRIME and the
       similarity asked of it; the elbow scan, the sweep and the picks
   * - Sessions
     - ``.mdance``: the current clustering
     - ``.vmdance``: every run, the scans, the picks, the selection, the
       plots' settings; the old ``.mdance`` imported
   * - Checks before running
     - numbers; a selection whose number of atoms changed
     - also NANI's seeding limit, HELM's starting clusters and trim,
       DIVINE's crash, metric, first split and smallest share, the
       diversity selection with an index other than
       MSD, eQUAL's radius, numbers the backend cannot read, coordinates
       that are not numbers, a selection whose atoms *could* change with
       the frame
   * - The backend's output
     - scraped with regular expressions; checked in the program's
       clustering only
     - read as JSON and checked whole in every mode, scan and question
   * - HELM's scores with a trim
     - CPP-MDANCE's: the trimmed frames counted as one more cluster
     - those of the clustered frames, as MDANCE's and eQUAL's
   * - Elbow scan
     - always StratAll 10% and MSD; HELM pre-clustered once
     - the Setup's parameters; HELM from the same starting clusters; a k
       that cannot run is recorded, the others go on; any k made the
       clustering
   * - Sweep
     - KMeans NANI and DIVINE
     - also HELM (its seeding: its first clustering's); a configuration
       that cannot run is recorded
   * - Silhouette
     - 200 frames per cluster at most; from the squared distances to the
       mean structures
     - every frame; from the RMSDs to the mean structures (lower values:
       0.39 against 0.62 on 3ptb's Cα at k 4); 0 for a frame alone in its
       cluster
   * - Label files
     - two columns read by VMD frame: the plugin's own export of a range or
       a step refused
     - two columns read by rows of the clustering (MDANCE's) or by VMD
       frames (the plugin's)
   * - HELM's tree
     - the backend's merge matrix as it is
     - the merges numbered as scipy numbers them: after trimming,
       CPP-MDANCE gives a merge and a starting cluster the same number, and
       the plugin tells them apart; the trimmed starting clusters left out
   * - Fit
     - none (the coordinates as they are)
     - optional: *Fit to the first frame*, on the values
   * - DIVINE
     - Refine on by default (it changed nothing with NANI's splits, and
       crashed the backend with the other anchors'); *Threshold*; any metric
     - Refine off and greyed; *Smallest share*, what a split leaves on each
       side, greyed with NANI; MSD
   * - Settings
     - lost when VMD quits; the text size could not reach the widgets
     - kept (``~/.vmdance.prefs``); the text size applies to the whole
       window
   * - Plots
     - tiles opening tabs; a font setting per plot
     - ten tabs with their options in one panel; Cluster MSD, MSD/Pop and
       the similarity are views of Compactness, the centroid distances and
       the representatives' RMSD views of Distances

Not carried over: the narrated walkthrough (``demo/``), the installer that
edited ``~/.vmdrc`` (two lines to add: :doc:`install`), and images named
PostScript (EPS instead).

The two plugins can be loaded side by side: they share no command,
namespace or file.
