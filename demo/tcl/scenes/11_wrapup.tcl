# 11_wrapup.tcl - choosing a method, and the two rules that outrank the choice.

::demo::scene wrapup "Choosing a method" \
    "Which of the four to reach for, what PRIME adds, and the two habits that matter more than either"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::style_default
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::vmd::reset_view
    ::demo::vmd::goto_frame 0
    # This chapter drives nothing but the notebook, so it needs no result of its
    # own - but it still points the plugin at the live molecule, so a cold play
    # lands on a coherent Setup tab rather than a stale molecule id.
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::tab results
}

::demo::beat recap \
    -caption "One trajectory, four ways to cluster it" \
    -say "That is the whole tour. One trajectory, aligned once, clustered four different ways, and\
          reduced at the end to a single structure. What is left is the question you started with:\
          which method do you actually reach for?" \
    -tab results \
    -spotlight .mdance.nb \
    -do {
        # Played cold there is no standing result, and `algorithm` is one of the
        # few keys the plugin itself treats as optional - so guard both.
        if {$::mdance::results ne "" && [dict exists $::mdance::results nClusters]} {
            set _alg "?"
            catch {set _alg [dict get $::mdance::results algorithm]}
            ::demo::note "Standing result: $_alg,\
                          [dict get $::mdance::results nClusters] clusters"
        }
    } \
    -at 0.5f \
    -hold 0.6

::demo::beat kmeans \
    -caption "KMeans NANI: the default choice" \
    -say "Reach for KMeans NANI first. It suits you when you already know roughly how many states\
          you want. It is the quickest of the four, and because NANI seeds it from the data rather\
          than at random, the same input gives the same answer every time." \
    -tab kmeans \
    -spotlight .mdance.nb.kmeans.params \
    -hold 0.5

::demo::beat hierarchies \
    -caption "DIVINE and HELM: two hierarchies, opposite directions" \
    -say "The two hierarchical methods pull in opposite directions. Take DIVINE when you want a\
          hierarchy, and clusters of roughly comparable size. Take HELM when you want the merge\
          tree itself, or when you are hunting a small, distinct state a partitional method would\
          swallow whole." \
    -tab divine \
    -do { ::demo::tab helm } \
    -at 0.55f \
    -hold 0.6

::demo::beat equal \
    -caption "eQUAL: when you do not know k" \
    -say "eQUAL is for when you do not know k and would rather not invent it. You say how similar\
          two frames have to be to count as the same state, and that threshold settles the cluster\
          count for you." \
    -tab equal \
    -spotlight .mdance.nb.equal.params.w1 \
    -hold 0.6

::demo::beat prime \
    -caption "PRIME answers the next question" \
    -say "Whichever of the four you use, PRIME picks up where it stops. Clustering tells you how\
          many states there are. PRIME tells you which single structure to take forward, and it\
          runs on labels you already have, so it costs you one more click." \
    -tab prime \
    -spotlight .mdance.nb.prime.banner \
    -hold 0.6

::demo::beat tworules \
    -caption "Two rules that outrank the method" \
    -say "Two habits matter more than which method you pick. Align the trajectory before you\
          cluster anything, because MDANCE compares raw coordinates and will happily cluster your\
          tumbling. And look at the timeline before you believe any cluster count." \
    -tab results \
    -spotlight .mdance.nb.results.plots.timeline \
    -hold 0.8

::demo::beat agreement \
    -caption "No sharp elbow, but one clear transition" \
    -say "Be honest about this trajectory. The scores never gave a sharp elbow: quality drifts as k\
          rises instead of turning a corner, which is what a continuous ensemble looks like. But\
          every method found the same slow transition through the middle of the run, and agreement\
          between methods beats any single score." \
    -spotlight .mdance.nb.results.summary \
    -hold 1.0

::demo::beat next \
    -caption "Sweep, QUICK_START.md, and Export CSV" \
    -say "Where to go next. The Sweep tab runs that grid for you, so k and metric come from evidence\
          rather than habit. The Quick Start file in the repository is the written short version of\
          all this. And every plot has an Export CSV button, so nothing here is trapped in a\
          picture." \
    -tab sweep \
    -spotlight .mdance.nb.sweep.grid \
    -hold 0.8

::demo::beat thanks \
    -caption "Thanks for watching" \
    -say "That is MDANCE inside VMD. A thousand frames in, a handful of states out, and one\
          structure you can defend. Thank you for watching." \
    -do {
        # Last chapter: hand the display back the way we found it, and leave the
        # molecule turning under the closing caption.
        ::demo::close_plots
        ::demo::vmd::color_by_structure
        ::demo::vmd::reset_view
        ::demo::vmd::spin_start y 0.18
    } \
    -at 0.2 \
    -hold 3.0
