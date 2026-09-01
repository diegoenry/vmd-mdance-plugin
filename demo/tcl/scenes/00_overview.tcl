# 00_overview.tcl - orientation: the system, the plugin, the backend.

::demo::scene overview "Welcome to MDANCE" \
    "What the plugin does, the trajectory we will cluster, and how the backend is wired up"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::style_default
    ::demo::vmd::show_peptide 0
    ::demo::vmd::goto_frame 0
    ::demo::tab setup
}

::demo::beat welcome \
    -caption "MDANCE clustering, inside VMD" \
    -say "Welcome. This is MDANCE, a clustering toolkit for molecular dynamics, running as a\
          plugin inside VMD. Over the next few chapters we will cluster a real trajectory four\
          different ways, and look at what each method tells us." \
    -tab setup \
    -do { ::demo::vmd::spin_start y 0.28 } \
    -hold 0.8

::demo::beat thesystem \
    -caption "A protein-peptide complex with a bound calcium ion" \
    -say "The system on the left is a protein of three hundred and twenty one residues, bound to a\
          thirty one residue peptide, with a single calcium ion. One thousand frames of dynamics." \
    -do {
        ::demo::vmd::show_peptide 1
        ::demo::note "Loaded [molinfo [::demo::vmd::molid] get numframes] frames,\
                      [molinfo [::demo::vmd::molid] get numatoms] atoms."
    } \
    -at 0.55f \
    -hold 1.4

::demo::beat theproblem \
    -caption "A thousand frames is too many to look at" \
    -say "A thousand structures is far too many to inspect by eye. What you actually want is a\
          handful of representative conformations, and some idea of how the trajectory moves\
          between them. That is what clustering is for." \
    -do { ::demo::vmd::sweep_frames 0 240 6.0 } \
    -hold 0.6

::demo::beat whatsdifferent \
    -caption "MDANCE clusters on n-ary similarity" \
    -say "MDANCE is not just another k-means wrapper. It compares whole sets of frames at once,\
          using extended, or n-ary, similarity, instead of building a pairwise distance matrix.\
          That is what lets it scale to long trajectories." \
    -do { ::demo::vmd::sweep_stop ; ::demo::vmd::goto_frame 0 } \
    -hold 0.8

::demo::beat thetabs \
    -caption "Eight tabs: Setup, four methods, Sweep, Results, PRIME" \
    -say "The plugin window is on the right. Setup describes what to cluster. Then there are four\
          clustering methods, a parameter sweep, a results tab, and PRIME." \
    -spotlight .mdance.nb \
    -at 0.3 \
    -hold 0.5

::demo::beat tourtabs \
    -caption "Each method is a separate chapter of this walkthrough" \
    -say "KMeans partitions the frames into a number you choose. DIVINE splits the ensemble from\
          the top down. HELM merges from the bottom up. And eQUAL finds the cluster count for\
          itself, from a distance threshold." \
    -do { ::demo::tab_tour {kmeans divine helm equal} 1500 setup } \
    -at 0.15 \
    -hold 0.4

::demo::beat backend \
    -caption "The backend: native library or command-line" \
    -say "The clustering itself happens in a C plus plus backend. The Setup tab shows which one is\
          live: a native library loaded straight into VMD, or the command line binary as a\
          fallback. Everything else in the plugin works the same either way." \
    -tab setup \
    -spotlight .mdance.nb.setup.cli \
    -do {
        ::demo::note "Backend: [expr {$::mdance::use_library ? {native library, in-process} \
                                                            : {mdance-cli subprocess}}]"
    } \
    -at 0.6f \
    -hold 1.2

::demo::beat roadmap \
    -caption "Setup first, then the methods" \
    -say "We will start with Setup, because one choice there matters more than any clustering\
          parameter you will touch afterwards. Let's go." \
    -do { ::demo::vmd::spin_stop } \
    -hold 0.4
