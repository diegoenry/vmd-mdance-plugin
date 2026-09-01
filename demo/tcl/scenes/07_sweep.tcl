# 07_sweep.tcl - the Sweep tab: run the grid instead of guessing one configuration.

::demo::scene sweep "Parameter sweep" \
    "Run a whole grid of configurations and tabulate the scores, so the choice comes from evidence"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::vmd::align "protein and name CA"
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1

    # The tick boxes are array elements, and the sweep builds its grid by
    # walking those arrays. A metric or an initialisation left ticked by an
    # earlier chapter would multiply the run count with nothing on screen to
    # explain it, so zero everything this chapter does not ask for.
    foreach m {BUB Fai Gle Ja JT RT RR SM SS1 SS2} { ::demo::param sweep_metric($m) 0 }
    foreach ki {StratAll StratReduced DivSelect KmeansPP Random VanillaKmeansPP} {
        ::demo::param sweep_kinit($ki) 0
    }
    # The heatmap opens on whichever score this variable holds; the toggle beat
    # assumes it starts on Calinski-Harabasz.
    ::demo::param sweep_score CH

    # The toggle beat clicks a button on the heatmap's toolbar, which does not
    # exist until the heatmap is open. It takes that path from what plot_raw
    # returns, so the variable has to exist even if the plot never opens.
    set ::demo::sweep_hm ""

    ::demo::tab sweep
}

::demo::beat why \
    -caption "Too many combinations to try one at a time" \
    -say "Every chapter so far chose the number of clusters and the metric by hand, and then argued\
          about whether the choice was right. There are four algorithms, eleven metrics, seven\
          initialisations, and any k you like. You cannot work through that one run at a time." \
    -tab sweep \
    -hold 0.6

::demo::beat algos \
    -caption "Algorithms: KMeans, and DIVINE cleared" \
    -say "The Sweep tab builds a grid over four things. First the algorithms: the two that take a\
          cluster count up front, KMeans and DIVINE. We tick KMeans on its own and clear DIVINE,\
          because every extra tick multiplies the number of runs." \
    -spotlight .mdance.nb.sweep.grid \
    -do {
        ::demo::param sweep_algo(kmeans) 1
        ::demo::param sweep_algo(divine) 0
    } \
    -at 0.55f \
    -hold 0.5

::demo::beat krange \
    -caption "K range: 2 to 8, step 1" \
    -say "Second, the range of k: a minimum, a maximum and a step. Two to eight in steps of one is\
          seven values of k, which is about the span you would grind through by hand over an\
          afternoon." \
    -spotlight {.mdance.nb.sweep.grid.kmin .mdance.nb.sweep.grid.kmax .mdance.nb.sweep.grid.kstep} \
    -do { ::demo::params sweep_kmin 2 sweep_kmax 8 sweep_kstep 1 } \
    -at 0.4f \
    -hold 0.5

::demo::beat metrics \
    -caption "Metric: MSD, and the tab's own warning" \
    -say "Third, the metrics, and we tick MSD alone. The tab carries its own warning in orange: the\
          other ten are binary and extended-similarity indices, meant for fingerprint data. On raw\
          atom positions they may not mean anything at all." \
    -spotlight {.mdance.nb.sweep.met.mMSD .mdance.nb.sweep.met.note} \
    -do { ::demo::param sweep_metric(MSD) 1 } \
    -at 0.3f \
    -hold 0.8

::demo::beat inits \
    -caption "Initialisation: CompSim - seven runs in all" \
    -say "Fourth, the initialisations. CompSim, one box. So the grid is KMeans, times seven values\
          of k, times MSD, times CompSim: seven runs. The coordinates leave VMD once and are reused\
          for all seven, so a sweep costs seven clusterings, not seven extractions." \
    -spotlight .mdance.nb.sweep.init \
    -do {
        ::demo::param sweep_kinit(CompSim) 1
        ::demo::note "Grid: KMeans x K 2..8 step 1 x MSD x CompSim = 7 configurations"
    } \
    -at 0.35f \
    -hold 0.6

::demo::beat run \
    -caption "Run Sweep" \
    -say "Run Sweep. It confirms before it starts, telling you exactly how many runs you just\
          ordered, and warning that Cancel, which goes live beside it, only takes effect between\
          configurations and never in the middle of one." \
    -spotlight .mdance.nb.sweep.run \
    -do {
        # This blocks until the last configuration is done, and only the status
        # label refreshes meanwhile - so fire it at the end of the sentence.
        ::demo::click .mdance.nb.sweep.run.go
    } \
    -at 0.8f \
    -hold 1.0

::demo::beat table \
    -caption "One row per configuration, both scores" \
    -say "Seven rows come back, one per configuration: the algorithm, the k you asked for, the k you\
          actually got, the metric, the initialisation, both quality scores, and the size of the\
          largest cluster. The best Calinski-Harabasz row is green, the best Davies-Bouldin row\
          blue." \
    -spotlight .mdance.nb.sweep.res \
    -do {
        set tv .mdance.nb.sweep.res.tv
        set line {}
        foreach it [$tv children {}] {
            lappend line "k=[$tv set $it K] CH=[$tv set $it CH] DB=[$tv set $it DB]"
        }
        ::demo::note "Sweep: [join $line {; }]"
    } \
    -at 0.55f \
    -hold 1.4

::demo::beat sort \
    -caption "Sort by any column heading" \
    -say "Every heading sorts the table. The sort is ascending only, so clicking Calinski-Harabasz,\
          where higher is better, sends the winning green row to the bottom, while sorting on\
          Davies-Bouldin brings its winner to the top." \
    -spotlight .mdance.nb.sweep.res.tv \
    -do {
        # A treeview heading is not a widget with a path to invoke, so fire the
        # command the heading is bound to instead of clicking one.
        ::mdance::gui::sweep_sort_by CH
    } \
    -at 0.5f \
    -hold 1.2

::demo::beat honest \
    -caption "Calinski-Harabasz falls with every added cluster" \
    -say "And here is the honest result. Calinski-Harabasz falls with every cluster you add, so the\
          winning row is k equals two. That is not the sweep failing. It is the sweep telling you\
          this trajectory is a fairly continuous ensemble with one dominant split, rather than a\
          handful of well separated basins." \
    -spotlight .mdance.nb.sweep.res.tv \
    -at 0.5f \
    -hold 1.2

::demo::beat heatmap \
    -caption "Score Heatmap: configuration against k" \
    -say "Score Heatmap draws the same numbers as a picture: a row for each algorithm, metric and\
          initialisation combination, a column for each k, shaded blue through white to red. Ours\
          is a single row of seven cells; tick more boxes and it grows a row for each." \
    -spotlight .mdance.nb.sweep.resbtns.hm \
    -do {
        # plot_raw returns the toplevel it opened. The toggle beat needs that
        # path and cannot write it literally, because the heatmap's toolbar
        # does not exist until this beat has run.
        set ::demo::sweep_hm [::demo::plot_raw sweep { ::mdance::gui::sweep_heatmap }]
    } \
    -at 0.35f \
    -hold 2.5

::demo::beat toggle \
    -caption "Toggle CH/DB - and read the colours carefully" \
    -say "The button on its toolbar flips the whole heatmap to the other score. Watch the colours\
          when it does: the ramp does not invert. Red is the best cell under Calinski-Harabasz, and\
          the worst one under Davies-Bouldin, where lower wins." \
    -do { ::demo::click $::demo::sweep_hm.toolbar.sw } \
    -at 0.45f \
    -hold 2.5

::demo::beat load \
    -caption "Load Selected into Results" \
    -say "Select a row, press Load Selected into Results, and that configuration's clustering\
          becomes the current result. The plugin switches to the Results tab with it, and every\
          plot, every export and every frame tool from the earlier chapters now applies to it." \
    -tab sweep \
    -spotlight .mdance.nb.sweep.resbtns.load \
    -do {
        set tv .mdance.nb.sweep.res.tv
        # Load Selected refuses an empty selection with a dialog, so choose a
        # row first - the green best-CH one. Not row zero: the table is sorted
        # ascending on CH, which puts the worst configuration at the top.
        set pick [lindex [$tv children {}] 0]
        foreach it [$tv children {}] {
            if {[lsearch -exact [$tv item $it -tags] bestCH] >= 0} { set pick $it }
        }
        $tv selection set $pick
        $tv focus $pick
        $tv see $pick
        update idletasks
        ::demo::click .mdance.nb.sweep.resbtns.load
    } \
    -at 0.5f \
    -hold 1.2

::demo::beat export \
    -caption "Export the whole table as CSV" \
    -say "Export CSV writes every row, in whatever order the table is sorted right now, with the\
          scores at full precision instead of the two decimals on screen. That file is the record\
          of what you tried, not only of what won." \
    -tab sweep \
    -spotlight .mdance.nb.sweep.resbtns.csv \
    -do { ::demo::save_as [::demo::out "sweep_scores.csv"] .mdance.nb.sweep.resbtns.csv } \
    -at 0.55f \
    -hold 1.0

::demo::beat wrap \
    -caption "Choose from evidence, not from habit" \
    -say "That is the sweep. Instead of defending one configuration, you run the grid and read the\
          table. A sweep that crowned the same answer on every dataset would be worthless. The\
          value of this one is that it can tell you something you did not want to hear." \
    -do { ::demo::close_plots } \
    -at 0.85f \
    -hold 0.5
