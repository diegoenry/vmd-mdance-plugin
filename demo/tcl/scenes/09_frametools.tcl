# 09_frametools.tcl - extended similarity, and picking frames without clustering.
#
# HEADS-UP for run_demo.sh --check: the .mdance.ftools.* paths below are real
# (they are in the verified widget map) but they only exist while the Frame
# Tools dialog is open. --check validates paths against a freshly built GUI with
# no dialogs open, so it reports them as missing, exactly as it does for the
# elbow chapter's .mdance_elbow_cfg.* paths. --rehearse is the check that
# matters here.

::demo::scene frametools "Frame tools and extended similarity" \
    "One similarity number for a whole ensemble, and five ways to pick frames without clustering at all"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    ::demo::vmd::color_by_structure
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    # A dialog left open by an aborted run would still hold the previous
    # chapter's list; start from a closed one so beat 6 builds it fresh.
    catch {destroy .mdance.ftools}
    # The Similarity button is disabled until a clustering exists.
    ::demo::expect_results kmeans 4
    ::demo::tab results
}

::demo::beat whatis \
    -caption "One number for a whole ensemble" \
    -say "Everything else in MDANCE rests on this. Comparing frames two at a time gives you a matrix\
          that grows with the square of the trajectory. Extended similarity reads the whole set in a\
          single pass, in linear time." \
    -tab results \
    -spotlight .mdance.nb.results.plots.isim \
    -hold 0.6

::demo::beat isim \
    -caption "Results tab, Similarity" \
    -say "The Similarity button turns that idea into a measurement. It sends every clustered frame\
          back to the backend in analysis mode and returns one iSIM number for the whole ensemble,\
          and one for each cluster." \
    -spotlight .mdance.nb.results.plots.isim \
    -do {
        # run_similarity_analysis opens the chart itself, so go through plot_raw
        # rather than plot: that still parks the window in a tidy slot.
        ::demo::plot_raw similarity { ::demo::click .mdance.nb.results.plots.isim }
    } \
    -at 0.5f \
    -hold 2.5

::demo::beat compactness \
    -caption "Compactness: lower bars are tighter clusters" \
    -say "Each bar is a cluster's compactness, and lower means tighter. The ensemble value is printed\
          in the title. All four bars sit well below it, and within a whisker of each other: four\
          equally tight slices of one continuous ensemble." \
    -do {
        # The analysis dict is never stored anywhere public. The plot's own
        # redraw command is the one place it survives, as the two arguments of
        # {similarity_chart $results $analysis}.
        if {[catch {
            set a [lindex $::mdance::plots::redraw_cmds(mdance_isim) 2]
            ::demo::note "Ensemble iSIM [format %.4g [dict get $a isim]];\
                          per-cluster [dict get $a clusterISIM]"
        } err]} {
            ::demo::note "iSIM values unavailable: $err" warn
        }
    } \
    -at 0.6f \
    -hold 2.0

::demo::beat clusteroutliers \
    -caption "Each cluster's least representative frame" \
    -say "The analysis also hands back, for every cluster, the single frame least like the rest of\
          it. That is the first place to look when you suspect a cluster is really two states run\
          together." \
    -do {
        if {[catch {
            set a [lindex $::mdance::plots::redraw_cmds(mdance_isim) 2]
            ::demo::note "Per-cluster outlier frames: [dict get $a clusterOutliers]"
        } err]} {
            ::demo::note "cluster outliers unavailable: $err" warn
        }
    } \
    -at 0.7f \
    -hold 1.2

::demo::beat premise \
    -caption "Sometimes you want frames, not clusters" \
    -say "Now the other half of this chapter. Sometimes you do not want clusters at all, you want\
          frames: a diverse handful to run something expensive on, the outliers to check for\
          artefacts, or a sample that follows the density." \
    -tab setup \
    -spotlight .mdance.nb.setup.frames.tools \
    -do { ::demo::close_plots } \
    -at 0.15 \
    -hold 0.5

::demo::beat inherits \
    -caption "Frame Tools borrows the Setup tab's inputs" \
    -say "Frame Tools lives on the Setup tab for a reason. It has no molecule, selection or frame\
          range of its own, so whatever these two boxes say is exactly what it works on." \
    -spotlight {.mdance.nb.setup.mol .mdance.nb.setup.range} \
    -do {
        ::demo::click .mdance.nb.setup.frames.tools
        # frame_tools_dialog sets a size but no position, so the window manager
        # would drop it wherever it likes. Park it over the free left side,
        # clear of the plugin window and the caption bar.
        catch {
            wm geometry .mdance.ftools 420x460+48+80
            raise .mdance.ftools
        }
    } \
    -at 0.8f \
    -hold 0.8

::demo::beat diversity \
    -caption "Diversity: the most spread-out five percent" \
    -say "Diversity is the first method. Param is a percentage here, so five asks for the fifty most\
          spread-out frames in the trajectory. That is the subset you seed replica runs from, or\
          hand to a docking calculation." \
    -spotlight .mdance.ftools.p.method \
    -do {
        ::demo::params ft_method diversity ft_metric MSD ft_param 5
        ::demo::click .mdance.ftools.run.go
        ::demo::note "diversity 5% -> [llength [set ::mdance::gui::ft_frames]] frames"
    } \
    -at 0.45f \
    -hold 1.2

::demo::beat outliers \
    -caption "Outliers: the ten least representative frames" \
    -say "Switch to outliers and Param becomes a count instead. Ten gives the ten least\
          representative frames. Read the list though: they are not scattered, they fall into two\
          short runs of consecutive frames, which says brief excursion rather than noise." \
    -spotlight .mdance.ftools.p.param \
    -do {
        ::demo::params ft_method outliers ft_param 10
        ::demo::click .mdance.ftools.run.go
        ::demo::note "outliers -> [set ::mdance::gui::ft_frames]"
    } \
    -at 0.25f \
    -hold 1.6

::demo::beat repsample \
    -caption "Repsample: a sample that follows the density" \
    -say "Repsample is the middle ground. It bins the ensemble by similarity and draws from every\
          bin, so you get a sample that follows the density instead of one that lives at the\
          extremes. Bins sets how fine that histogram is." \
    -spotlight .mdance.ftools.p.nbins \
    -do {
        ::demo::params ft_method repsample ft_param 20 ft_nbins 10
        ::demo::click .mdance.ftools.run.go
        ::demo::note "repsample -> [llength [set ::mdance::gui::ft_frames]] frames across 10 bins"
    } \
    -at 0.5f \
    -hold 1.4

::demo::beat single \
    -caption "Medoid and outlier: one frame each" \
    -say "The last two methods return one frame each. Medoid is the frame closest to the middle of\
          the whole trajectory; outlier is its opposite, the single most extreme structure in the\
          run. Param is ignored by both." \
    -spotlight .mdance.ftools.p.method \
    -do {
        ::demo::param ft_method medoid
        ::demo::click .mdance.ftools.run.go
        ::demo::note "trajectory medoid -> [set ::mdance::gui::ft_frames]"
        # Leave the extreme frame in the list: the next beat jumps to it.
        ::demo::param ft_method outlier
        ::demo::click .mdance.ftools.run.go
        ::demo::note "trajectory outlier -> [set ::mdance::gui::ft_frames]"
    } \
    -at 0.35f \
    -hold 1.2

::demo::beat jump \
    -caption "Double-click a frame to jump there" \
    -say "Every entry in that list is an absolute VMD frame, and double-clicking one jumps the\
          display straight to it. We will do it from script instead, and there is the strangest\
          structure in the run." \
    -spotlight .mdance.ftools.res.lb \
    -do {
        set fl [set ::mdance::gui::ft_frames]
        ::demo::note "Frame Tools list: $fl"
        if {[llength $fl]} { ::demo::frame_to [lindex $fl 0] }
    } \
    -at 0.65f \
    -hold 2.0

::demo::beat export \
    -caption "Export Selected writes PDB or DCD" \
    -say "Export Selected writes the current list to a PDB or a DCD. Set the method back to\
          diversity first, so what lands on disk is the fifty-frame spread rather than one lone\
          outlier." \
    -spotlight .mdance.ftools.btns.export \
    -do {
        ::demo::params ft_method diversity ft_param 5
        ::demo::click .mdance.ftools.run.go
        # The export dialog must be armed before the click or it returns "" and
        # writes nothing. save_as does both in the right order.
        ::demo::save_as [::demo::out "diverse_frames.pdb"] .mdance.ftools.btns.export
    } \
    -at 0.5f \
    -hold 1.4

::demo::beat wrap \
    -caption "Close Frame Tools" \
    -say "Close the dialog, and that is analysis without clustering: one number for how self-similar\
          an ensemble is, and five ways to pull frames out of it without ever assigning a label." \
    -spotlight .mdance.ftools.btns.close \
    -do {
        ::demo::click .mdance.ftools.btns.close
        ::demo::close_plots
        ::demo::vmd::color_by_structure
        ::demo::vmd::goto_frame 0
    } \
    -at 0.35f \
    -hold 0.5

::demo::teardown {
    # Insurance for an aborted run: the dialog is a child of .mdance, so it
    # would otherwise sit on top of the next chapter.
    catch {destroy .mdance.ftools}
    ::demo::close_plots
}
