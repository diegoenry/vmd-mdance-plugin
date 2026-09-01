# 10_exports.tcl - getting the results out: four exports and a session file.

::demo::scene exports "Getting the results out" \
    "Labels, representatives, per-cluster trajectories, and a session you can reopen next week"

# A session file's extension is ".mdance", which is also the plugin's toplevel
# window name. The selfcheck scans every -do body for literal widget paths, so a
# filename written inline would be reported as a widget that does not exist yet.
# Building the two paths here keeps those literals out of the beats.
proc ::demo::exports_session {} { return [::demo::out "session.mdance"] }
proc ::demo::exports_dir {} { return [file dirname [::demo::out "x"]] }

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::expect_results kmeans 4
    ::demo::tab results
}

::demo::beat whyexport \
    -caption "A session is not a result" \
    -say "Everything so far has lived inside this VMD session. Close the window and it is gone. The\
          Results tab has four export buttons, and between them they cover almost everything you\
          would want to do next." \
    -tab results \
    -spotlight .mdance.nb.results.actions \
    -at 0.4f \
    -hold 0.6

::demo::beat labels \
    -caption "Export Labels: one row per frame" \
    -say "Export Labels is the smallest of the four and the one you will use most. It writes a two\
          column CSV: one row per clustered frame, the frame number and the cluster it landed in." \
    -spotlight .mdance.nb.results.actions.export \
    -do { ::demo::save_as [::demo::out "labels.csv"] .mdance.nb.results.actions.export } \
    -at 0.55f \
    -hold 1.2

::demo::beat readback \
    -caption "The frame column is a real VMD frame" \
    -say "Here are the first lines of what it just wrote, down in the log. That first column is the\
          real VMD frame number, not a row index. Cluster every tenth frame instead and the numbers\
          still line up with the original trajectory." \
    -spotlight .mdance.nb.results.actions.export \
    -do {
        set exp_csv [::demo::out "labels.csv"]
        if {[file readable $exp_csv]} {
            set exp_fh [open $exp_csv r]
            set exp_lines [split [string trim [read $exp_fh]] "\n"]
            close $exp_fh
            ::demo::note "labels.csv: [llength $exp_lines] lines\
                          - [join [lrange $exp_lines 0 4] { / }] ..."
            ::demo::note "last row: [lindex $exp_lines end]\
                          (the frame map turns each row back into an absolute VMD frame)"
        } else {
            ::demo::note "labels.csv was not written - was the save dialog armed?" warn
        }
    } \
    -at 0.25f \
    -hold 2.2

::demo::beat helmreuse \
    -caption "HELM will read this file back in" \
    -say "The plugin also reads its own export. Point HELM's initial labels box at this CSV and HELM\
          starts from your KMeans partition instead of pre-clustering for itself. The header row is\
          skipped for you." \
    -tab helm \
    -spotlight .mdance.nb.helm.labels.fentry \
    -do {
        # Only the path entry is filled in. Flipping the radio button to "file"
        # as well would change what a later HELM run actually does, which is not
        # something a walkthrough should leave behind.
        ::demo::param helm_labels_file [::demo::out "labels.csv"]
    } \
    -at 0.45f \
    -hold 1.4

::demo::beat reps \
    -caption "Export Representatives: one structure per cluster" \
    -say "Export Representatives writes the medoid of every cluster as a structure. Four clusters,\
          four models in one file. This is the handful of conformations you actually take away from\
          a thousand frames." \
    -tab results \
    -spotlight .mdance.nb.results.actions.reps \
    -do {
        ::demo::save_as [::demo::out "representatives.pdb"] .mdance.nb.results.actions.reps
        ::demo::note "Representative frames: [dict get $::mdance::results representatives]"
    } \
    -at 0.5f \
    -hold 1.4

::demo::beat dcdchoice \
    -caption "The extension picks the format" \
    -say "The file extension decides the format, and nothing else does. A PDB name gives you a\
          multi-model PDB that opens anywhere. A DCD name gives you a trajectory, and because a DCD\
          carries no atom names of its own, the plugin writes a companion PDB topology beside it." \
    -spotlight .mdance.nb.results.actions.reps \
    -at 0.3f \
    -hold 0.8

::demo::beat split \
    -caption "Export Clusters: one file per state" \
    -say "Export Clusters is the opposite move. Instead of one frame per cluster, it writes every\
          frame of every cluster, one trajectory per cluster, into a directory you choose. It asks\
          for the directory first, then for the format." \
    -spotlight .mdance.nb.results.actions.split \
    -do {
        # This dialog asks twice: tk_chooseDirectory, then a yes/no format
        # question. Only the directory can be armed; the demo's message-box
        # stand-in answers yes, which is the DCD branch - so every cluster gets
        # a .dcd plus the companion .pdb topology described in the last beat.
        #
        # It is also the most expensive action in the walkthrough: one temporary
        # molecule per cluster with one duplicated timestep per member frame,
        # a thousand frames in total. It blocks, so fire it early and let the
        # freeze land under the narration rather than after it.
        set exp_dir [::demo::exports_dir]
        ::demo::dialogs::arm $exp_dir
        ::demo::click .mdance.nb.results.actions.split
        set exp_split [lsort [glob -nocomplain -tails -directory $exp_dir cluster_*]]
        ::demo::note "Per-cluster files written: [llength $exp_split]\
                      - [join $exp_split {, }]"
    } \
    -at 0.15 \
    -hold 1.6

::demo::beat session \
    -caption "Save Session: everything in one file" \
    -say "The three exports so far each throw something away. Save Session throws nothing away: the\
          labels, the parameters that produced them, the scores, and the frame map, all written to\
          a single MDANCE session file." \
    -spotlight .mdance.nb.results.actions.save \
    -do { ::demo::save_as [::demo::exports_session] .mdance.nb.results.actions.save } \
    -at 0.6f \
    -hold 1.2

::demo::beat framemap \
    -caption "Without the frame map, the labels point nowhere" \
    -say "The frame map is the part that is easy to overlook. It is the list that turns row\
          seventeen of the labels back into a frame number in your trajectory. Without it, a\
          reloaded result is a column of integers pointing at nothing." \
    -do {
        # Read the session back as the plain Tcl dict it is, so the log shows
        # what is really in the file rather than a description of it.
        set exp_ses [::demo::exports_session]
        if {[file readable $exp_ses]} {
            set exp_fh [open $exp_ses r]
            set exp_sess [read $exp_fh]
            close $exp_fh
            set exp_res [dict get $exp_sess results]
            ::demo::note "Session results hold: [join [lsort [dict keys $exp_res]] {, }]"
            set exp_map [dict get $exp_res frames]
            ::demo::note "Frame map: [llength $exp_map] entries,\
                          first [lrange $exp_map 0 2] ... last [lindex $exp_map end]"
        } else {
            ::demo::note "the session file was not written" warn
        }
    } \
    -at 0.3f \
    -hold 2.0

::demo::beat load \
    -caption "Load Session brings it all back" \
    -say "Load Session takes it back. The Results tab repopulates: same scores, same table, same\
          representatives. The plugin also checks that the molecule the session was computed from is\
          the one currently loaded, and warns you if it is not." \
    -spotlight .mdance.nb.results.actions.load \
    -do {
        ::demo::dialogs::arm [::demo::exports_session]
        ::demo::click .mdance.nb.results.actions.load
        ::demo::note "Reloaded [dict get $::mdance::results algorithm]:\
                      [dict get $::mdance::results nClusters] clusters,\
                      sizes [dict get $::mdance::results clusterSizes]"
    } \
    -at 0.5f \
    -hold 1.8

::demo::beat outputs \
    -caption "What this chapter actually wrote" \
    -say "That is everything this chapter put on disk, listed in the log: a label CSV, a\
          representatives PDB, one trajectory per cluster with its topology, and the session file.\
          None of it needs the plugin to read it back." \
    -spotlight .mdance.nb.results.summary \
    -do {
        set exp_dir [::demo::exports_dir]
        set exp_all [lsort [glob -nocomplain -tails -directory $exp_dir *]]
        ::demo::note "[file nativename $exp_dir] now holds [llength $exp_all] file(s):"
        ::demo::note [join $exp_all ", "]
    } \
    -at 0.3f \
    -hold 2.4

::demo::beat wrap \
    -caption "Four exports, four different next steps" \
    -say "So: labels for whatever you analyse next, representatives for structural work, per-cluster\
          trajectories when you want to treat each state as its own ensemble, and a session file so\
          the analysis survives closing VMD." \
    -do { ::demo::close_plots } \
    -at 0.85f \
    -hold 0.5

::demo::teardown {
    # The HELM tab was left pointing at this chapter's CSV. Clear it so a later
    # HELM run is not silently seeded from a file the viewer has forgotten about.
    ::demo::param helm_labels_file ""
}
