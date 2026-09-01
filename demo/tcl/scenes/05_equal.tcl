# 05_equal.tcl - eQUAL: threshold-driven clustering, with no k to choose.

::demo::scene equal "eQUAL" \
    "Give it a radius instead of a cluster count, and let the number of clusters fall out of the data"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    # Every threshold in this chapter is a distance on ALIGNED coordinates and
    # means nothing on a tumbling trajectory, so guarantee the fit is in place
    # when the chapter is played cold. Chapter one already did it otherwise.
    if {!$::demo::vmd::aligned} { ::demo::vmd::align "protein and name CA" }
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    # Restore the tab's shipped defaults, including the deliberately EMPTY
    # threshold, so a replay tells the same story as a cold start.
    ::demo::params eq_metric MSD eq_threshold "" eq_seed medoid eq_nseeds 1 \
                   eq_percentage 10 eq_minsamples 10 eq_simthreshold 0 \
                   eq_align none eq_reject_lowd 0 eq_check_sim 0
    ::demo::tab equal
}

::demo::beat intro \
    -caption "eQUAL: the cluster count is an output" \
    -say "KMeans, DIVINE and HELM all make you name the number of clusters. In practice you rarely\
          know it. eQUAL is the honest answer to that: you give it a radius, and the number of\
          clusters falls out of the data." \
    -tab equal \
    -spotlight .mdance.nb.equal.params \
    -hold 0.5

::demo::beat threshold \
    -caption "Threshold is required, and starts empty" \
    -say "Threshold is that radius, and it is the one parameter eQUAL cannot do without. The plugin\
          ships it empty on purpose. There is no sensible default, because the right value depends\
          entirely on your trajectory." \
    -tab equal \
    -spotlight .mdance.nb.equal.params.w1 \
    -do { ::demo::note "eq_threshold starts empty; Run eQUAL refuses until it is set." } \
    -at 0.4f \
    -hold 0.5

::demo::beat scale \
    -caption "A radial cutoff, in the same units as iSIM" \
    -say "It is a radial cutoff in mean squared deviation, in the same units the Similarity analysis\
          reports for the whole ensemble. That ensemble number is your scale: below it the\
          trajectory splits, above it everything stays together." \
    -tab equal \
    -spotlight {.mdance.nb.equal.params.w0 .mdance.nb.equal.params.w1} \
    -at 0.5f \
    -hold 0.6

::demo::beat seed \
    -caption "Seed method: medoid or comp sim" \
    -say "Seed method decides where each new cluster starts. Medoid starts from the most central\
          frame still unassigned. Comp sim starts from the densest region instead, and Sampling\
          percentage sets how much of the data counts as dense." \
    -tab equal \
    -spotlight {.mdance.nb.equal.params.w2 .mdance.nb.equal.params.w4} \
    -do { ::demo::params eq_metric MSD eq_seed medoid eq_nseeds 1 eq_percentage 10 } \
    -at 0.35f \
    -hold 0.6

::demo::beat run09 \
    -caption "Run at threshold zero point nine" \
    -say "Start generous. Zero point nine is comfortably under the ensemble scale, so it should cut\
          the trajectory without shredding it. Set the threshold, and run." \
    -tab equal \
    -spotlight .mdance.nb.equal.run.btn \
    -do {
        ::demo::param eq_threshold 0.9
        ::demo::click .mdance.nb.equal.run.btn
    } \
    -at 0.6f \
    -hold 1.0

::demo::beat results09 \
    -caption "The cluster count is a result now" \
    -say "The Results tab opens by itself, and look at what is in the Number of clusters row. Nobody\
          typed that. At this radius the trajectory comes apart into a handful of groups, and the\
          scores and sizes read exactly as they did for KMeans." \
    -tab results \
    -spotlight .mdance.nb.results.summary \
    -do {
        ::demo::note "threshold 0.9 -> [dict get $::mdance::results nClusters] clusters,\
                      sizes [dict get $::mdance::results clusterSizes]"
    } \
    -at 0.55f \
    -hold 1.4

::demo::beat run07 \
    -caption "Tighten the threshold to zero point seven" \
    -say "Now tighten it. A smaller radius means a frame has to be more similar to a seed before it\
          is allowed to join, so the same trajectory has to be cut into more pieces." \
    -tab equal \
    -spotlight .mdance.nb.equal.params.w1 \
    -do {
        ::demo::param eq_threshold 0.7
        ::demo::click .mdance.nb.equal.run.btn
        ::demo::note "threshold 0.7 -> [dict get $::mdance::results nClusters] clusters"
    } \
    -at 0.55f \
    -hold 1.2

::demo::beat run055 \
    -caption "Tighten it again, to zero point five five" \
    -say "Tighter still, and the count climbs again. Nothing about the trajectory changed between\
          these three runs. Only the radius did." \
    -tab equal \
    -spotlight .mdance.nb.equal.params.w1 \
    -do {
        ::demo::param eq_threshold 0.55
        ::demo::click .mdance.nb.equal.run.btn
        ::demo::note "threshold 0.55 -> [dict get $::mdance::results nClusters] clusters"
    } \
    -at 0.5f \
    -hold 1.2

::demo::beat tradeoff \
    -caption "The trade-off, drawn as a population chart" \
    -say "That is the whole trade-off. Tighten the radius and you get more, tighter clusters, plus a\
          long tail of tiny ones that are really just a few frames each. Loosen it and they merge,\
          until eventually everything collapses into one." \
    -tab results \
    -spotlight .mdance.nb.results.plots.pop \
    -do { ::demo::plot population } \
    -at 0.3f \
    -hold 3.0

::demo::beat noise \
    -caption "Frames eQUAL refuses to place" \
    -say "eQUAL is also allowed to give up on a frame. Anything it cannot place gets the label minus\
          one. The plugin paints those frames grey, and every plot treats minus one as unassigned\
          rather than as one more cluster." \
    -tab equal \
    -spotlight .mdance.nb.equal.note \
    -do {
        ::demo::note "Unassigned frames (label -1):\
                      [llength [lsearch -all -exact [dict get $::mdance::results labels] -1]]"
    } \
    -at 0.6f \
    -hold 0.8

::demo::beat minsamples \
    -caption "Min samples, and rejecting low-density clusters" \
    -say "Min samples is the floor. On its own it is only advice. Tick Reject low-density clusters\
          and eQUAL throws away any winner smaller than that floor, instead of handing you a cluster\
          of two frames. Those frames become noise." \
    -tab equal \
    -spotlight {.mdance.nb.equal.params.w5 .mdance.nb.equal.params.reject} \
    -do { ::demo::param eq_minsamples 10 } \
    -at 0.3f \
    -hold 0.6

::demo::beat checksim \
    -caption "Checking that a cluster is similar to itself" \
    -say "Check intra-cluster similarity is stricter again. With it on, eQUAL measures how similar a\
          finished cluster is to itself, and stops the entire run the first time one fails the Sim\
          threshold beside it. We will leave it off." \
    -tab equal \
    -spotlight {.mdance.nb.equal.params.w6 .mdance.nb.equal.params.checksim} \
    -at 0.5f \
    -hold 0.6

::demo::beat align \
    -caption "Align method: none, and only none" \
    -say "Align method offers exactly one choice. The backend's other two alignment branches are not\
          implemented, and it rejects them outright rather than quietly doing nothing. So alignment\
          stays your job, which is why we fitted this trajectory before we began." \
    -tab equal \
    -spotlight .mdance.nb.equal.params.w7 \
    -do { ::demo::param eq_align none } \
    -at 0.25f \
    -hold 0.7

::demo::beat final \
    -caption "Settle on zero point seven" \
    -say "For this trajectory zero point seven is the useful setting: enough clusters to see real\
          structure, few enough to actually look at. Set it, and run one last time." \
    -tab equal \
    -spotlight .mdance.nb.equal.run.btn \
    -do {
        # The population chart on screen belongs to the 0.55 run; drop it before
        # the results underneath it change.
        ::demo::close_plots
        ::demo::param eq_threshold 0.7
        ::demo::click .mdance.nb.equal.run.btn
        ::demo::note "final run: threshold 0.7 ->\
                      [dict get $::mdance::results nClusters] clusters,\
                      sizes [dict get $::mdance::results clusterSizes]"
    } \
    -at 0.6f \
    -hold 1.0

::demo::beat color \
    -caption "Colour the structure by cluster" \
    -say "Colour by Cluster paints the trajectory exactly as it did for KMeans, with one difference.\
          Any frame eQUAL left unassigned comes out neutral grey, instead of taking a colour from\
          the cluster ramp." \
    -tab results \
    -spotlight .mdance.nb.results.actions.color \
    -do { ::demo::click .mdance.nb.results.actions.color } \
    -at 0.5f \
    -hold 0.6

::demo::beat timeline \
    -caption "Finer structure, and a lane for noise" \
    -say "And the timeline. Set it beside the four clean bands KMeans gave us: eQUAL has found finer\
          structure inside the same trajectory, and the frames it would not place sit in their own\
          lane at the bottom, labelled noise. Same data, a different question asked of it." \
    -tab results \
    -spotlight .mdance.nb.results.plots.timeline \
    -do { ::demo::plot timeline } \
    -at 0.3f \
    -hold 3.0

::demo::teardown {
    ::demo::close_plots
    ::demo::vmd::color_by_structure
}
