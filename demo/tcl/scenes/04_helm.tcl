# 04_helm.tcl - HELM: agglomerative clustering, and the only real merge tree.

::demo::scene helm "HELM" \
    "Merge from the bottom up, and keep the whole merge history as a dendrogram"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::vmd::goto_frame 0
    # Every chapter clusters the same aligned coordinates. Guarded because a
    # re-fit of all thousand frames is pure waste when the Setup chapter has
    # already done it, and unguarded when this chapter is played cold.
    if {!$::demo::vmd::aligned} { ::demo::vmd::align "protein and name CA" }
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::tab helm
}

::demo::beat intro \
    -caption "HELM merges from the bottom up" \
    -say "HELM is hierarchical clustering run the other way round from DIVINE. Instead of splitting\
          one big group downwards, it starts with many small groups and merges the two most similar\
          ones, over and over." \
    -tab helm \
    -spotlight .mdance.nb.helm.params \
    -hold 0.5

::demo::beat needslabels \
    -caption "HELM needs a starting partition" \
    -say "Which means HELM cannot start from raw frames. It needs something to merge: an initial\
          partition, deliberately over-split, that it can work its way down from." \
    -spotlight .mdance.nb.helm.labels \
    -at 0.5f \
    -hold 0.6

::demo::beat prek \
    -caption "Auto pre-cluster: fifty micro-clusters with KMeans" \
    -say "Agglomerating a thousand individual frames one pair at a time would be wasteful, so the\
          plugin seeds the run for you. Auto pre-cluster runs KMeans first, at a pre-cluster K of\
          fifty, and HELM merges those fifty micro-clusters instead of the frames." \
    -spotlight {.mdance.nb.helm.labels.auto .mdance.nb.helm.labels.prek} \
    -do { ::demo::params helm_labels_source auto helm_pre_k 50 } \
    -at 0.45f \
    -hold 0.7

# The Browse button is an inline tk_getOpenFile with no dialog stand-in behind
# it, so this beat describes the file option and never clicks it.
::demo::beat fromfile \
    -caption "Or load a starting partition from file" \
    -say "The other option is to supply that partition yourself. It takes one cluster label per\
          frame, and it accepts the two-column C S V that the Results tab exports, so any run you\
          have already done can become HELM's starting point." \
    -spotlight {.mdance.nb.helm.labels.file .mdance.nb.helm.labels.fentry} \
    -at 0.55f \
    -hold 0.6

::demo::beat merge \
    -caption "Merge scheme: what the comparison measures" \
    -say "Merge scheme decides which pair merges next. Intra scores the union, how tight the two\
          groups would be once combined. Inter subtracts each group's own internal similarity and\
          scores only what happens between them. Half splits the difference. Inter is the default,\
          and the one to keep." \
    -spotlight {.mdance.nb.helm.params.w2 .mdance.nb.helm.params.w3} \
    -do { ::demo::params helm_metric MSD helm_merge Inter } \
    -at 0.3f \
    -hold 0.7

::demo::beat stop \
    -caption "Stop on a cluster count, or on epsilon" \
    -say "Merging has to stop somewhere. Either you name the number of clusters you want left, or\
          you give an epsilon, a similarity cutoff, and let the count fall out of wherever merging\
          stops being worthwhile. We will ask for four." \
    -spotlight {.mdance.nb.helm.params.stopn .mdance.nb.helm.params.stope} \
    -do { ::demo::params helm_stop_mode nclusters helm_nclusters 4 helm_eps -1 } \
    -at 0.6f \
    -hold 0.6

# Left OFF deliberately. The backend validates this pair strictly (helm.cpp:322,
# 325): trimStart with both trimVal and trimK at zero is rejected outright, and
# so is setting both of them at once. Enabling it here without also setting one
# of the two would abort the run in the middle of the chapter.
::demo::beat trim \
    -caption "Trimming drops the weakest micro-clusters first" \
    -say "Trim options throw part of the starting partition away before any merging happens, the\
          sparsest and the loosest micro-clusters. Worth turning on for a noisy trajectory. If you\
          do, set exactly one of Trim value or Trim K alongside it. The backend rejects the run if\
          you set neither, and also if you set both." \
    -spotlight {.mdance.nb.helm.trim.enable .mdance.nb.helm.trim.w1} \
    -do { ::demo::param helm_trim_start 0 } \
    -at 0.35f \
    -hold 0.6

::demo::beat run \
    -caption "Run HELM: pre-cluster, then merge" \
    -say "Run it. This is two backend passes rather than one, and the status line at the bottom of\
          the window names them in turn: pre-clustering with KMeans first, then the merging. Both\
          finish in well under a second on this trajectory." \
    -spotlight {.mdance.nb.helm.run.btn .mdance.status.label} \
    -do { ::demo::click .mdance.nb.helm.run.btn } \
    -at 0.55f \
    -hold 1.0

::demo::beat results \
    -caption "Results: four clusters, the usual two scores" \
    -say "The Results tab opens by itself, with the same two scores on it as every other method:\
          Calinski-Harabasz for separation, Davies-Bouldin for overlap. But the interesting thing\
          here is not the scores. It is the size column." \
    -tab results \
    -spotlight .mdance.nb.results.summary \
    -at 0.25 \
    -hold 1.0

::demo::beat sizes \
    -caption "The cluster sizes are badly lopsided" \
    -say "Two of the four clusters between them own most of the trajectory. The third holds about a\
          tenth of it. The fourth is a sliver, a few dozen frames. KMeans and DIVINE both cut this\
          trajectory into four blocks of comparable size. HELM did not." \
    -spotlight .mdance.nb.results.table \
    -do {
        ::demo::plot population
        ::demo::note "HELM k=4 sizes: [dict get $::mdance::results clusterSizes]"
    } \
    -at 0.5f \
    -hold 2.5

::demo::beat lopsided \
    -caption "Lopsided is what merging does" \
    -say "That is characteristic of merging, not a mistake. A small, genuinely distinct group gets\
          left alone right to the end, because nothing is similar enough to absorb it. If you are\
          hunting a rare state, that is exactly what you want. If you wanted balanced clusters, it\
          is a nuisance." \
    -spotlight .mdance.nb.results.actions.color \
    -do { ::demo::click .mdance.nb.results.actions.color } \
    -at 0.75f \
    -hold 0.8

::demo::beat dendro \
    -caption "The dendrogram: HELM's real merge history" \
    -say "Now the payoff. HELM is the only method here that hands back a genuine merge tree, one row\
          per merge, recorded as it went. The others have to reconstruct a tree afterwards from\
          their cluster centroids. Open the Dendrogram." \
    -tab results \
    -spotlight .mdance.nb.results.plots.dendro \
    -do {
        ::demo::close_plots
        set top [::demo::plot dendrogram]
        # Fifty leaves make the canvas about 870 pixels wide; the standard plot
        # slot is 660, which would hide a third of the forest behind a scrollbar.
        if {$top ne ""} { catch {wm geometry $top "900x520+40+50"} }
        ::demo::note "Merges recorded: [llength [dict get $::mdance::results zMatrix]]"
    } \
    -at 0.75f \
    -hold 2.5

::demo::beat readtree \
    -caption "Leaves at the bottom, merges going up" \
    -say "Along the bottom are the fifty micro-clusters HELM started from. Every join above them is\
          one merge. Height is the merge step, so joins low down happened first, between the most\
          similar pairs, and joins near the top happened last. Read the ordering, not the spacing." \
    -hold 3.5

::demo::beat fourtrees \
    -caption "Four separate trees, because we stopped at four" \
    -say "And notice this is four separate trees, not one. HELM stopped when four clusters were\
          left, so the joins that would have tied those four to each other were never made. Ask for\
          fewer clusters and the trees grow together; ask for more and you stop sooner, with a\
          wider forest." \
    -hold 2.0

::demo::beat wrap \
    -caption "Reach for HELM when you want the tree" \
    -say "So: HELM when you want the merge history itself, when you are refining a deliberately\
          over-split partition, or when the small, rare states are the point. KMeans or DIVINE when\
          you want clusters of comparable size." \
    -do {
        ::demo::close_plots
        ::demo::vmd::color_by_structure
    } \
    -at 0.85f \
    -hold 0.5
