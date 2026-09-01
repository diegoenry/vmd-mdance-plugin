# 02_kmeans.tcl - KMeans NANI: the default partitional method.

::demo::scene kmeans "KMeans NANI" \
    "Partition the trajectory into k clusters, with n-ary similarity choosing the seeds"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::tab kmeans
}

::demo::beat intro \
    -caption "KMeans NANI" \
    -say "KMeans NANI is the method to reach for first. You tell it how many clusters you want,\
          and it partitions every frame into one of them." \
    -tab kmeans \
    -spotlight .mdance.nb.kmeans.params \
    -hold 0.4

::demo::beat whatsnani \
    -caption "NANI picks the seeds, instead of guessing them" \
    -say "The NANI part is what makes it different from ordinary k-means. Ordinary k-means starts\
          from random seeds, so you get a different answer every time you run it. NANI picks the\
          starting points from the data itself, using n-ary similarity." \
    -spotlight .mdance.nb.kmeans.params.w2 \
    -at 0.45f \
    -hold 0.6

::demo::beat kvalue \
    -caption "Number of clusters: 4" \
    -say "Let's ask for four clusters." \
    -spotlight .mdance.nb.kmeans.params.w0 \
    -do { ::demo::param km_nclusters 4 } \
    -at 0.5f \
    -hold 0.5

::demo::beat metric \
    -caption "Metric: MSD, the mean squared deviation" \
    -say "The metric stays on M S D, mean squared deviation. That is the right choice for\
          coordinates. The other ten metrics in this list are binary similarity indices, meant for\
          fingerprint data rather than for atom positions." \
    -spotlight .mdance.nb.kmeans.params.w1 \
    -do { ::demo::param km_metric MSD } \
    -at 0.25f \
    -hold 0.6

::demo::beat kinit \
    -caption "Initialisation: CompSim" \
    -say "For initialisation we use CompSim, complementary similarity. It seeds the clusters from\
          the densest, most mutually similar region of the trajectory. Sampling percentage sets how\
          much of the trajectory counts as that dense core." \
    -spotlight {.mdance.nb.kmeans.params.w2 .mdance.nb.kmeans.params.w3} \
    -do { ::demo::params km_kinit CompSim km_percentage 10 } \
    -at 0.3f \
    -hold 0.7

::demo::beat run \
    -caption "Run KMeans" \
    -say "Now run it. The plugin pulls the alpha carbon coordinates out of VMD, hands them to the\
          backend, and gets a label for every frame back." \
    -spotlight .mdance.nb.kmeans.run.btn \
    -do { ::demo::click .mdance.nb.kmeans.run.btn } \
    -at 0.5f \
    -hold 1.0

::demo::beat results \
    -caption "The Results tab, with scores and cluster sizes" \
    -say "The Results tab opens by itself. At the top are two quality scores. Calinski-Harabasz\
          rewards clusters that are tight and far apart, so higher is better. Davies-Bouldin\
          measures overlap, so lower is better." \
    -tab results \
    -spotlight .mdance.nb.results.summary \
    -at 0.2 \
    -hold 1.2

::demo::beat table \
    -caption "Four clusters, and the frame that best represents each" \
    -say "Underneath is one row per cluster: how many frames it holds, what fraction of the\
          trajectory that is, and the single frame that sits closest to the middle of it. That\
          frame is the cluster's representative, or medoid." \
    -spotlight .mdance.nb.results.table \
    -do {
        ::demo::note "Cluster sizes: [dict get $::mdance::results clusterSizes]"
        ::demo::note "Representative frames: [dict get $::mdance::results representatives]"
    } \
    -at 0.65f \
    -hold 1.2

::demo::beat color \
    -caption "Colour the trajectory by cluster" \
    -say "Colour by Cluster writes each frame's cluster into VMD's User field and paints the\
          structure with it. Now, as the trajectory plays, you can see which state the protein is\
          in at any moment." \
    -spotlight .mdance.nb.results.actions.color \
    -do { ::demo::click .mdance.nb.results.actions.color } \
    -at 0.45f \
    -hold 0.6

::demo::beat watchit \
    -caption "The colour changes as the protein changes state" \
    -say "Watch the colour as the trajectory runs. It is not flickering between clusters frame by\
          frame. It holds one colour for a long stretch, then changes and holds the next one." \
    -do { ::demo::vmd::sweep_frames 0 999 11.0 } \
    -at 0.1 \
    -hold 0.5

::demo::beat timeline \
    -caption "The timeline makes the structure obvious" \
    -say "The Timeline plot shows that directly: cluster assignment along the horizontal axis of\
          time. Four bands, in order, almost no interleaving. This trajectory is not sampling four\
          states at random. It is moving through them." \
    -tab results \
    -spotlight .mdance.nb.results.plots.timeline \
    -do { ::demo::vmd::sweep_stop ; ::demo::plot timeline } \
    -at 0.3f \
    -hold 3.0

::demo::beat goto \
    -caption "Jump to a cluster's representative structure" \
    -say "Select a cluster and press Go to Representative, and VMD jumps to that frame. This is how\
          you get from a thousand frames down to four structures worth actually looking at." \
    -spotlight .mdance.nb.results.actions.goto \
    -do {
        ::demo::select_cluster 0
        ::demo::click .mdance.nb.results.actions.goto
        ::demo::note "Jumped to frame [molinfo [::demo::vmd::molid] get frame]"
    } \
    -at 0.5f \
    -hold 1.0

::demo::beat compare \
    -caption "Step through all four representatives" \
    -say "Stepping through all four in turn, you are looking at the four conformations that best\
          summarise the whole simulation." \
    -do {
        ::demo::rep_tour 0 3 1600
    } \
    -at 0.15 \
    -hold 2.5

::demo::beat wrap \
    -caption "KMeans is the fast default" \
    -say "That is KMeans. It is fast, it is reproducible, and it needs you to know the number of\
          clusters in advance. The next three chapters are about what to do when you don't." \
    -do { ::demo::close_plots } \
    -at 0.9f \
    -hold 0.4
