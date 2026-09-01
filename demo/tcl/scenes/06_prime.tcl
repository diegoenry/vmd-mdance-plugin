# 06_prime.tcl - PRIME: predicting the native-like frame from a clustered ensemble.

::demo::scene prime "PRIME" \
    "Given a clustering, which single frame is the most native-like structure"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1

    # PRIME never clusters anything itself, so this chapter needs labels on the
    # table before it starts.
    ::demo::expect_results kmeans 4

    # expect_results is a no-op when ANY result is standing - which, played in
    # sequence, is whatever the previous chapter left behind. The narration below
    # talks about four clusters, so re-run KMeans when the standing result is not
    # a four-cluster one.
    set sizes {}
    catch {set sizes [dict get $::mdance::results clusterSizes]}
    if {[llength $sizes] != 4} {
        ::demo::params km_nclusters 4 km_metric MSD km_kinit CompSim km_percentage 10
        ::demo::click .mdance.nb.kmeans.run.btn
    }

    ::demo::params prime_metric RR prime_trim 0.1 prime_weighted 1
    ::demo::tab prime
}

::demo::beat intro \
    -caption "PRIME asks which frame is the real one" \
    -say "Clustering tells you how many states a trajectory has. PRIME asks something different:\
          out of a thousand frames, which single structure is the most native-like one. The name\
          stands for Protein Retrieval via Integrative Molecular Ensembles." \
    -tab prime \
    -spotlight .mdance.nb.prime.banner \
    -hold 0.8

::demo::beat notmedoid \
    -caption "Not just the biggest cluster's medoid" \
    -say "The obvious answer is the medoid of the largest cluster, and PRIME starts there. But it\
          does not stop there. It takes its candidates from that cluster and scores each one\
          against every other cluster in the ensemble. It weighs evidence across the whole\
          trajectory, not just inside one state." \
    -spotlight .mdance.nb.prime \
    -at 0.4f \
    -hold 0.8

::demo::beat needslabels \
    -caption "PRIME runs on a clustering you already have" \
    -say "So PRIME needs labels. Everything it knows about the ensemble comes from a clustering you\
          ran first. We will use the four-cluster KMeans result: those assignments are the evidence\
          PRIME is going to weigh." \
    -tab results \
    -spotlight .mdance.nb.results.table \
    -do { ::demo::note "PRIME will score against cluster sizes:\
                        [dict get $::mdance::results clusterSizes]" } \
    -at 0.45f \
    -hold 1.0

::demo::beat metric \
    -caption "Similarity: Russell-Rao, not the clustering's MSD" \
    -say "Back on the PRIME tab. The similarity index is Russell-Rao, with Sokal-Michener as the\
          alternative. Note what it is not: this is not the M S D distance the clustering used.\
          PRIME scores on raw n-ary similarity, so it is a genuinely different calculation, not a\
          re-run of the same one." \
    -tab prime \
    -spotlight .mdance.nb.prime.opts.metric \
    -do { ::demo::param prime_metric RR } \
    -at 0.3f \
    -hold 0.8

::demo::beat trim \
    -caption "Trim the least representative tail first" \
    -say "Trim fraction throws away the least representative frames before any scoring happens. At\
          zero point one, the outermost tenth goes. That way a few stragglers on the edge of the\
          cluster can neither be nominated themselves nor drag the answer outwards." \
    -spotlight .mdance.nb.prime.opts.trim \
    -do { ::demo::param prime_trim 0.1 } \
    -at 0.4f \
    -hold 0.7

::demo::beat weighted \
    -caption "Weight by cluster population" \
    -say "Weight by cluster population decides whether a large cluster's opinion counts for more\
          than a small one's. Leave it on. A state the trajectory spends most of its time in should\
          matter more than one it barely visits." \
    -spotlight .mdance.nb.prime.opts.w \
    -do { ::demo::param prime_weighted 1 } \
    -at 0.35f \
    -hold 0.7

::demo::beat run \
    -caption "Predict Representative Frame" \
    -say "Now run it. PRIME pulls the same alpha carbon coordinates, scores every surviving\
          candidate against every other cluster in four different ways, and comes back with seven\
          frames." \
    -spotlight .mdance.nb.prime.run.btn \
    -do { ::demo::click .mdance.nb.prime.run.btn } \
    -at 0.5f \
    -hold 1.2

::demo::beat baselines \
    -caption "Three medoid baselines to judge against" \
    -say "The first three rows are baselines, not predictions. The medoid of all thousand frames.\
          The medoid of the most populated cluster. And the medoid of that cluster after trimming.\
          They are here so you can see whether PRIME actually disagrees with the naive answer." \
    -spotlight .mdance.nb.prime.res.tv \
    -do {
        # The treeview already holds absolute VMD frames; the dict behind it holds
        # sample indices, so read the rows rather than prime_results.
        set tv .mdance.nb.prime.res.tv
        set prime_rows [$tv children {}]
        set out {}
        foreach it [lrange $prime_rows 0 2] {
            lappend out "[$tv set $it method] -> [$tv set $it frame]"
        }
        if {[llength $out]} { ::demo::note "Baselines: [join $out {, }]" }
    } \
    -at 0.3f \
    -hold 1.4

::demo::beat predictions \
    -caption "Four PRIME predictions, tagged green" \
    -say "The four green rows are the predictions. Pairwise averages the candidate against every\
          frame of another cluster. Union scores it against that cluster taken as a whole. Medoid\
          compares it to that cluster's centre, and Outlier to that cluster's worst member." \
    -spotlight .mdance.nb.prime.res.tv \
    -do {
        set tv .mdance.nb.prime.res.tv
        set prime_rows [$tv children {}]
        set out {}
        foreach it [lrange $prime_rows 3 end] {
            lappend out "[$tv set $it method] -> [$tv set $it frame]"
        }
        if {[llength $out]} { ::demo::note "PRIME predictions: [join $out {, }]" }
    } \
    -at 0.25f \
    -hold 1.6

::demo::beat agreement \
    -caption "Four criteria, one answer" \
    -say "Four independent criteria, and here they land on just two neighbouring frames. That\
          convergence is the signal. When the four scatter instead, the ensemble has no one\
          structure that represents it. The baselines land there too, so on this trajectory PRIME\
          is confirming the simple answer rather than overturning it." \
    -spotlight .mdance.nb.prime.res \
    -at 0.2f \
    -hold 1.2

::demo::beat goto \
    -caption "Jump to the predicted frame" \
    -say "Select a prediction and press Go to Selected Frame, and VMD jumps there. This is the\
          structure the whole analysis has been pointing at." \
    -spotlight .mdance.nb.prime.res.goto \
    -do {
        # Row 3 is the first green row, Pairwise. goto_prime_frame pops a modal
        # dialog when nothing is selected, so never click it on an empty table.
        set tv .mdance.nb.prime.res.tv
        set prime_rows [$tv children {}]
        if {[llength $prime_rows] > 3} {
            set it [lindex $prime_rows 3]
            $tv selection set $it
            $tv see $it
            ::demo::click .mdance.nb.prime.res.goto
            ::demo::note "PRIME frame: [molinfo [::demo::vmd::molid] get frame]"
        } else {
            ::demo::note "PRIME table has no prediction rows to select" warn
        }
    } \
    -at 0.5f \
    -hold 1.6

::demo::beat wrap \
    -caption "The one structure you take forward" \
    -say "That frame is the one you would deposit, dock into, or hand to whatever comes next. A\
          thousand structures in, one structure out, chosen by an argument you can explain." \
    -do { ::demo::close_plots } \
    -at 0.85f \
    -hold 0.5
