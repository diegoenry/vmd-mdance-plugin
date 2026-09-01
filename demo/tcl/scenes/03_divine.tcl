# 03_divine.tcl - DIVINE: divisive, top-down hierarchical clustering.

::demo::scene divine "DIVINE" \
    "Start with one cluster, split the worst one, repeat - and get a hierarchy on the way"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    # Fitting an already-aligned trajectory onto its own first frame is a no-op,
    # so this is safe to repeat - and it is what lets this chapter be played on
    # its own without the Setup chapter in front of it.
    ::demo::vmd::align "protein and name CA"
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::tab divine
}

::demo::beat intro \
    -caption "DIVINE splits from the top down" \
    -say "KMeans decides all four clusters at once. DIVINE works the other way round. It starts\
          with every frame in a single cluster, finds the worst one, and splits it in two. Then it\
          does that again, and again." \
    -tab divine \
    -spotlight .mdance.nb.divine.params \
    -hold 0.5

::demo::beat hierarchy \
    -caption "Every split is a level of a hierarchy" \
    -say "Because it cuts one cluster at a time, you get a hierarchy for free. Stopping at four\
          means it passed through two and three on the way, and each of those is a coarser version\
          of the same answer." \
    -hold 0.5

::demo::beat kvalue \
    -caption "Same k, same metric as KMeans" \
    -say "Ask for four clusters again, and leave the metric on mean squared deviation. Same target,\
          same distance function as the last chapter, so whatever comes out is directly\
          comparable." \
    -spotlight {.mdance.nb.divine.params.w0 .mdance.nb.divine.params.w1} \
    -do { ::demo::params div_nclusters 4 div_metric MSD } \
    -at 0.5f \
    -hold 0.5

::demo::beat split \
    -caption "Split criterion: which cluster gets cut next" \
    -say "The split criterion decides which cluster gets cut next. Plain M S D picks the one with\
          the widest internal spread. Radius picks the one with the furthest-out member. We use\
          weighted M S D, which scales spread by population, so the algorithm does not spend every\
          split pulling apart a handful of scattered frames." \
    -spotlight .mdance.nb.divine.params.w2 \
    -do { ::demo::param div_split WeightedMSD } \
    -at 0.3f \
    -hold 0.7

::demo::beat anchors \
    -caption "Anchor method: seeding the two halves" \
    -say "Once a cluster is chosen, the anchor method seeds the two halves of the split. NANI does\
          it with n-ary similarity, the same way the KMeans tab chose its starting points, and the\
          Initialization row underneath is what feeds it." \
    -spotlight {.mdance.nb.divine.params.w3 .mdance.nb.divine.params.w4} \
    -do {
        # Set explicitly rather than relying on the tab defaults: a sweep result
        # loaded earlier in a session can leave these on something else.
        ::demo::params div_anchors NANI div_kinit StratAll div_percentage 10
    } \
    -at 0.35f \
    -hold 0.6

::demo::beat otheranchors \
    -caption "The other two anchors, and one caveat" \
    -say "The other two anchors pick extreme frames as the poles of a split. Outlier Pair takes the\
          two most distant frames. Splinter Pair grows a dissenting group away from the main body.\
          Both crash the current backend when refinement is on, so turn refinement off if you use\
          them." \
    -spotlight .mdance.nb.divine.params.w3 \
    -do {
        # Deliberately no parameter change here: OutlierPair/SplinterPair with
        # div_refine on is a known backend crash (notes/REVIEW_NOTES.md), so the
        # walkthrough describes them and never runs them.
        ::demo::note "OutlierPair / SplinterPair + refine is a known backend crash - described, not run."
    } \
    -at 0.7f \
    -hold 0.6

::demo::beat refine \
    -caption "Refine with KMeans tidies the boundaries" \
    -say "Refine with KMeans stays on. When the splitting is finished, a local k-means pass cleans\
          up the boundaries, so a frame that ended up on the wrong side of an early cut can move\
          back. With the NANI anchor that is safe, and it is the default." \
    -spotlight .mdance.nb.divine.params.refine \
    -do { ::demo::param div_refine 1 } \
    -at 0.3f \
    -hold 0.6

::demo::beat stopcond \
    -caption "Stop condition, and the quality threshold" \
    -say "K clusters reached stops at the number you asked for. All points separated keeps splitting\
          until there is nothing left worth splitting. The threshold underneath is a floor on split\
          quality: a cluster already tighter than that is left alone. Zero means no floor." \
    -spotlight {.mdance.nb.divine.params.endk .mdance.nb.divine.params.endp \
                .mdance.nb.divine.params.w5} \
    -do { ::demo::params div_end_mode k div_threshold 0.0 } \
    -at 0.25f \
    -hold 0.7

::demo::beat run \
    -caption "Run DIVINE" \
    -say "Run it. Three splits, each one seeded and then refined. On a thousand frames of alpha\
          carbons that finishes in well under a second." \
    -spotlight .mdance.nb.divine.run.btn \
    -do { ::demo::click .mdance.nb.divine.run.btn } \
    -at 0.5f \
    -hold 1.0

::demo::beat results \
    -caption "Four clusters, scored the same way" \
    -say "The Results tab again, with the same two scores. Calinski-Harabasz comes out just below\
          what KMeans managed at the same k. That is what you would expect: k-means optimises\
          within-cluster spread directly, and DIVINE arrives by a different route." \
    -tab results \
    -spotlight .mdance.nb.results.summary \
    -do {
        ::demo::note "DIVINE k=4: CH [dict get $::mdance::results score_calinskiHarabasz],\
                      DB [dict get $::mdance::results score_daviesBouldin]"
    } \
    -at 0.25 \
    -hold 1.2

::demo::beat population \
    -caption "Compare the cluster sizes with KMeans" \
    -say "This is how many frames landed in each cluster. Because splitting always attacks the worst\
          cluster, DIVINE rarely finishes with one huge cluster and a scatter of crumbs, which is\
          what merging from the bottom up tends to give you. Here it lands on much the same shape\
          KMeans did." \
    -spotlight .mdance.nb.results.plots.pop \
    -do {
        ::demo::plot population
        ::demo::note "DIVINE cluster sizes: [dict get $::mdance::results clusterSizes]"
    } \
    -at 0.3f \
    -hold 2.5

::demo::beat timeline \
    -caption "The same blocks of time, found differently" \
    -say "And the timeline. The same ordered blocks of trajectory time, found by an algorithm that\
          shares almost nothing with k-means except the metric. That agreement is the real evidence:\
          the structure is in the data, not in the choice of method." \
    -spotlight .mdance.nb.results.plots.timeline \
    -do { ::demo::plot timeline } \
    -at 0.3f \
    -hold 3.0

::demo::beat color \
    -caption "Colour by cluster, jump to a representative" \
    -say "The result behaves like any other. Colour by Cluster paints the structure with DIVINE's\
          labels, and Go to Representative jumps to the frame sitting at the centre of whichever\
          cluster is selected. Same two buttons, a different partition underneath them." \
    -spotlight {.mdance.nb.results.actions.color .mdance.nb.results.actions.goto} \
    -do {
        ::demo::click .mdance.nb.results.actions.color
        ::demo::select_cluster 0
        ::demo::click .mdance.nb.results.actions.goto
        ::demo::note "Cluster 0 representative: frame [molinfo [::demo::vmd::molid] get frame]"
    } \
    -at 0.4f \
    -hold 1.4

::demo::beat wrap \
    -caption "When to reach for DIVINE" \
    -say "Reach for DIVINE when you want the hierarchy as well as the partition, when you do not\
          trust a single value of k and would rather watch the ensemble come apart, or when a\
          partitional run keeps handing you one dominant cluster. Next, the same problem from the\
          bottom up." \
    -do {
        ::demo::close_plots
        ::demo::vmd::color_by_structure
    } \
    -at 0.85f \
    -hold 0.4
