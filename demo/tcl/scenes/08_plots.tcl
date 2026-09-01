# 08_plots.tcl - the plot gallery: twelve ways of reading one clustering.

::demo::scene plots "Reading the results" \
    "Twelve plot windows, each asking a different question about the same set of labels"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    # The Setup tab values above are set before the run because the Elbow scan
    # later in this chapter reads them directly, not the results dict.
    ::demo::expect_results kmeans 4
    ::demo::tab results
}

::demo::beat intro \
    -caption "Twelve views of one clustering" \
    -say "The labels are where the analysis starts, not where it ends. Every button in this\
          Visualizations panel opens a plot of the same result, and each one asks a different\
          question about it." \
    -tab results \
    -spotlight .mdance.nb.results.plots \
    -at 0.35f \
    -hold 0.6

::demo::beat population \
    -caption "Population: how the frames divide up" \
    -say "Population first. One bar per cluster, and its height is the number of frames that landed\
          in it. What you are asking is whether one state dominates. Here the four are fairly even,\
          and none of them is a sliver." \
    -spotlight .mdance.nb.results.plots.pop \
    -do { ::demo::plot population } \
    -at 0.3f \
    -hold 3.0

::demo::beat clustermsd \
    -caption "Cluster MSD: how tight each cluster is" \
    -say "Cluster MSD asks the opposite question: not how big a cluster is, but how tight. Each bar\
          is the mean squared deviation of a cluster's frames about its own centre. A tight cluster\
          is a real state. A loose one is usually a bag of leftovers." \
    -spotlight .mdance.nb.results.plots.msd \
    -do { ::demo::plot msd } \
    -at 0.3f \
    -hold 3.0

::demo::beat msdpop \
    -caption "Size against tightness, in quadrants" \
    -say "MSD against Population puts both of those on one scatter, with dashed lines at the median\
          of each. Bottom right, large and tight, is the state you trust. The corner to worry about\
          is top right: a cluster that is big and loose at the same time." \
    -spotlight .mdance.nb.results.plots.msdpop \
    -do { ::demo::plot msdpop } \
    -at 0.35f \
    -hold 3.2

::demo::beat timeline \
    -caption "Timeline: cluster against frame number" \
    -say "The Timeline puts cluster on the vertical axis and frame number on the horizontal.\
          Sequential bands mean a trajectory moving through states in order. Salt and pepper, with\
          the colours interleaved everywhere, means one basin that has been chopped up. This is\
          bands." \
    -spotlight .mdance.nb.results.plots.timeline \
    -do { ::demo::plot timeline } \
    -at 0.3f \
    -hold 3.0

::demo::beat transitions \
    -caption "Transitions: what follows what" \
    -say "Transitions is a heatmap of what follows what. The cell in row i, column j is the chance\
          that a frame in cluster i is followed by a frame in cluster j. Weight off the diagonal is\
          interconversion. A near-diagonal matrix means the states are kinetically separated on\
          this timescale." \
    -spotlight .mdance.nb.results.plots.trans \
    -do { ::demo::plot transitions } \
    -at 0.3f \
    -hold 3.2

::demo::beat residence \
    -caption "Residence: how long a visit lasts" \
    -say "Residence times ask how long the trajectory stays in a state before it leaves. The bar is\
          the mean uninterrupted run, in frames, and the whisker reaches the longest single visit.\
          A short mean under a long whisker means one real visit plus a lot of brief returns." \
    -spotlight .mdance.nb.results.plots.residence \
    -do { ::demo::plot residence } \
    -at 0.3f \
    -hold 3.0

::demo::beat distances \
    -caption "Distances: are the states really distinct" \
    -say "Distances compares the clusters with each other. Each cell is the mean squared deviation\
          between two cluster centroids, blue for close and red for far. If a whole row comes out\
          blue, that cluster is not actually distinct from its neighbours." \
    -spotlight .mdance.nb.results.plots.cdist \
    -do { ::demo::plot distances } \
    -at 0.25f \
    -hold 3.0

::demo::beat reprmsd \
    -caption "Rep. RMSD: the number you can quote" \
    -say "Rep. RMSD drops the ensemble entirely and compares only the representatives, one medoid\
          per cluster, against each other. This is the one to quote in a paper, because angstroms\
          between two structures is a unit a structural biologist reads directly." \
    -spotlight .mdance.nb.results.plots.reprmsd \
    -do {
        ::demo::plot reprmsd
        ::demo::note "Rep. RMSD is a direct coordinate RMSD - the plugin does not re-superpose\
                      here, which is why the trajectory was aligned first."
    } \
    -at 0.3f \
    -hold 3.2

::demo::beat silhouette \
    -caption "Silhouette: one score per frame" \
    -say "Silhouette scores every frame on how much better it fits its own cluster than the nearest\
          alternative. Bars to the right of zero are frames that are where they belong. Bars\
          crossing to the left are frames that would be happier in another cluster." \
    -spotlight .mdance.nb.results.plots.silhouette \
    -do {
        # The most expensive plot in the gallery: a centroid pass over every
        # clustered frame, then a second coordinate pass per sampled frame. It
        # blocks, so fire it early and let the freeze land under the narration.
        ::demo::plot silhouette
    } \
    -at 0.2 \
    -hold 3.2

::demo::beat dendrogram \
    -caption "Dendrogram: a merge tree, or a stand-in" \
    -say "The Dendrogram needs a caveat. For HELM it is the real merge tree, the one the HELM\
          chapter opened. For every other method, including this KMeans run, the plugin builds the\
          tree afterwards from the distances between cluster centroids: a picture of the result,\
          not a record of how it was made." \
    -spotlight .mdance.nb.results.plots.dendro \
    -do { ::demo::plot dendrogram } \
    -at 0.3f \
    -hold 3.0

::demo::beat elbowrun \
    -caption "Elbow: quality against k" \
    -say "The Elbow plot is the only one here that does new work. It clusters the trajectory again,\
          once for every k from two to ten, and plots both scores against k: Calinski-Harabasz on\
          the left axis where higher is better, Davies-Bouldin on the right where lower is better." \
    -spotlight .mdance.nb.results.plots.elbow \
    -do {
        # plot_raw, not plot: the elbow chart is drawn from a scan rather than
        # from the results dict, and this parks it in a free layout slot.
        ::demo::plot_raw elbow {
            # elbow_plot re-declares its four namespace variables with their
            # defaults on every call, so the range has to be written AFTER the
            # configuration window is built, never before it.
            ::mdance::plots::elbow_plot
            set ::mdance::plots::elbow::algorithm kmeans
            set ::mdance::plots::elbow::k_min  2
            set ::mdance::plots::elbow::k_max  10
            set ::mdance::plots::elbow::k_step 1
            update idletasks
            ::demo::click .mdance_elbow_cfg.btns.run
        }
    } \
    -at 0.55f \
    -hold 1.2

::demo::beat elbowread \
    -caption "No sharp elbow, and that is a result" \
    -say "Now read it honestly. Calinski-Harabasz falls the whole way as k rises, and\
          Davies-Bouldin is already at its lowest at two. There is no knee. This trajectory is a\
          fairly continuous ensemble, not a set of sharply separated basins, so k is a choice about\
          resolution rather than a number the data hands you." \
    -hold 2.5

::demo::beat toolbar \
    -caption "Every plot window has the same toolbar" \
    -say "Every one of these windows carries the same strip along the top: a font size control, so\
          a figure stays readable on a projector, and three export buttons for CSV, PostScript and\
          PNG." \
    -do {
        # Font size is per window and is seeded only when the window is created,
        # so the global default cannot change an open plot - set the window's
        # own entry and push it through on_font_change.
        set ::mdance::plots::font_sizes(mdance_timeline) 14
        ::mdance::plots::on_font_change mdance_timeline
    } \
    -at 0.45f \
    -hold 1.2

::demo::beat exportcsv \
    -caption "Export CSV gives you the plot's data" \
    -say "Export CSV writes the numbers behind the plot rather than a picture of it. For the\
          Timeline that is one row per frame with the cluster it was assigned to. Every figure in\
          this gallery is reproducible outside VMD, straight from its own CSV." \
    -do {
        # The Timeline is still open from earlier in the chapter, but re-opening
        # it costs one pass over the labels and guarantees the toolbar is on
        # screen, and in front, when the export button is clicked.
        ::demo::plot timeline
        ::demo::save_as [::demo::out "timeline.csv"] .mdance_timeline.toolbar.csv
        ::demo::note "Timeline data written to [::demo::out timeline.csv]"
    } \
    -at 0.55f \
    -hold 1.4

::demo::beat wrap \
    -caption "Twelve questions, one clustering" \
    -say "That is the gallery. Every window but the Elbow came out of the single run you had\
          already paid for, and the twelfth plot, Similarity, gets a chapter of its own. Labels are\
          cheap. These windows are how you decide whether to believe them." \
    -do { ::demo::close_plots } \
    -at 0.85f \
    -hold 0.4
