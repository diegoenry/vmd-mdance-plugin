# Runtime scenario: the elbow scan after being moved onto the algorithm tabs --
# HELM support, the per-K partitions kept for inspection, the scores export, and
# the in-plot title switch.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
::mdance::gui::create_window
set ::mdance::gui::mol_selection $mol
set ::mdance::gui::atom_selection "name CA"
set ::mdance::gui::frame_first 0
set ::mdance::gui::frame_last -1
set ::mdance::gui::frame_stride 1

# A real result, so the result-driven plots further down have something to draw.
set params [dict create molid $mol atomsel "name CA" nclusters 2 \
    metric MSD kinit StratAll percentage 10 first 0 last -1 stride 1]
::mdance::run_clustering kmeans $params
::mdance::gui::update_results_tab

# ------------------------------------------------------------------
th::section "The Elbow button lives on each algorithm tab, not on Results"
# ------------------------------------------------------------------
th::test "KMeans, DIVINE and HELM each have one" {
    foreach tab {kmeans divine helm} {
        th::true [winfo exists .mdance.nb.$tab.run.elbow] "$tab needs an elbow button"
    }
}
th::test "the shared plot grid no longer has one" {
    # It sat in column 4 of a 6-wide grid and was clipped until the window was
    # resized, which is what the reviewer actually hit. That grid has since moved
    # off Results onto its own Figures tab; it must not reacquire an elbow button
    # there either, because the algorithm it would scan is ambiguous.
    th::false [winfo exists .mdance.nb.figures.plots.elbow]
}
th::test "launching from a tab fixes the algorithm and hides the chooser" {
    ::mdance::plots::elbow_plot helm
    th::eq "helm" $::mdance::plots::elbow::algorithm
    th::false [winfo exists .mdance_elbow_cfg.params.algo] \
        "no algorithm dropdown when the tab already chose"
    destroy .mdance_elbow_cfg
}
th::test "launching with no argument still offers all three algorithms" {
    ::mdance::plots::elbow_plot
    th::true [winfo exists .mdance_elbow_cfg.params.algo]
    th::eq {kmeans divine helm} [.mdance_elbow_cfg.params.algo cget -values]
    destroy .mdance_elbow_cfg
}

# ------------------------------------------------------------------
th::section "HELM is scanned from ONE shared pre-cluster partition"
# ------------------------------------------------------------------
th::test "elbow_prepare derives initial labels for HELM only" {
    lassign [::mdance::extract_coordinates $mol "name CA" 0 -1 1] csv natoms nf frames
    th::eq {} [::mdance::elbow_prepare kmeans $csv $natoms {}] "KMeans needs nothing"
    th::eq {} [::mdance::elbow_prepare divine $csv $natoms {}] "DIVINE needs nothing"
    set extra [::mdance::elbow_prepare helm $csv $natoms \
        [dict create pre-k 4 pre-kinit StratAll pre-percentage 10 merge-scheme Inter]]
    th::true [dict exists $extra initial-labels] "CLI mode needs a labels FILE"
    th::eq "Inter" [dict get $extra merge-scheme]
    th::eq $nf [llength [::mdance::read_labels_file [dict get $extra initial-labels]]] \
        "one label per extracted frame"
    catch {file delete $csv}
    ::mdance::utils::cleanup
}
th::test "HELM refuses to run a config with no initial labels" {
    # Better a clear error than the backend's own complaint about a missing flag.
    set ex [dict create mode cli csv /nonexistent natoms 3]
    th::throws {::mdance::run_one_config $ex [dict create algorithm helm nclusters 2]} \
        "*needs initial labels*"
}
th::test "run_one_config passes the labels and merge scheme through for HELM" {
    lassign [::mdance::extract_coordinates $mol "name CA" 0 -1 1] csv natoms nf frames
    set extra [::mdance::elbow_prepare helm $csv $natoms [dict create pre-k 4]]
    set r [::mdance::run_single_k helm $csv $natoms 2 $extra]
    th::eq 2 [dict get $r nClusters]
    th::eq $nf [llength [dict get $r labels]]
    catch {file delete $csv}
    ::mdance::utils::cleanup
}

# ------------------------------------------------------------------
th::section "A full scan keeps every K's partition, not just its scores"
# ------------------------------------------------------------------
::mdance::plots::elbow_plot kmeans
set ::mdance::plots::elbow::k_min 2
set ::mdance::plots::elbow::k_max 4
set ::mdance::plots::elbow::k_step 1
::mdance::plots::run_elbow_analysis .mdance_elbow_cfg

th::test "the chart was drawn" {
    th::true [winfo exists .mdance_elbow]
}
th::test "one stored partition per K, with its cluster sizes" {
    # The scan used to keep only (K, CH, DB) and discard each partition, so the
    # population split at a given K was unrecoverable.
    foreach k {2 3 4} {
        th::true [info exists ::mdance::plots::elbow_partitions($k)] "K=$k missing"
        lassign $::mdance::plots::elbow_partitions($k) kact sizes
        th::eq $k [llength $sizes] "K=$k must have $k cluster sizes"
        set total 0
        foreach n $sizes { incr total $n }
        th::eq 24 $total "the sizes must account for every frame"
    }
}
th::test "the exported CSV carries the partitions alongside the scores" {
    set csv $::mdance::plots::csv_data(mdance_elbow)
    set lines [split [string trimright $csv "\n"] "\n"]
    th::eq "k,k_actual,calinski_harabasz,davies_bouldin,cluster_sizes" [lindex $lines 0]
    th::eq 4 [llength $lines] "header + 3 K values"
    foreach l [lrange $lines 1 end] {
        th::match "*\"*\"*" $l "each row must carry a quoted cluster-size list"
    }
}
th::test "the scores export button is named, not just a generic Export CSV" {
    th::true [winfo exists .mdance_elbow.toolbar.scores]
    th::eq "Export Scores..." [.mdance_elbow.toolbar.scores cget -text]
}
th::test "hovering a K draws its population split, and leaving removes it" {
    set c .mdance_elbow.c
    th::eq 0 [llength [$c find withtag elbowpart]] "nothing before hovering"
    ::mdance::plots::elbow_show_partition $c 3 200 50
    th::gt [llength [$c find withtag elbowpart]] 3 "a panel with bars appears"
    ::mdance::plots::elbow_hide_partition $c
    th::eq 0 [llength [$c find withtag elbowpart]] "and is removed again"
}
th::test "hovering a K that was never scanned draws nothing" {
    set c .mdance_elbow.c
    ::mdance::plots::elbow_show_partition $c 99 200 50
    th::eq 0 [llength [$c find withtag elbowpart]]
}
th::test "a redraw rebuilds the chart without any hover state" {
    set c .mdance_elbow.c
    ::mdance::plots::elbow_show_partition $c 3 200 50
    ::mdance::plots::do_redraw mdance_elbow
    th::eq 0 [llength [$c find withtag elbowpart]] \
        "an exported image must never depend on a hover"
}

# ------------------------------------------------------------------
th::section "In-plot titles are off, but captions are never suppressed"
# ------------------------------------------------------------------
proc canvas_text {c} {
    set out {}
    foreach id [$c find all] {
        if {[$c type $id] eq "text"} { lappend out [$c itemcget $id -text] }
    }
    return $out
}
th::test "the plot name is not drawn on the canvas by default" {
    th::false $::mdance::plots::plot_titles "off by default"
    ::mdance::plots::population_chart $::mdance::results
    th::false [expr {[lsearch -exact [canvas_text .mdance_pop.c] \
        "Cluster Population Distribution"] >= 0}] \
        "the window title bar already shows it"
}
th::test "the window title still names the plot" {
    th::eq "Cluster Population Distribution" [wm title .mdance_pop]
}
th::test "enabling the preference brings the title back" {
    set ::mdance::plots::plot_titles 1
    ::mdance::plots::redraw_all
    th::true [expr {[lsearch -exact [canvas_text .mdance_pop.c] \
        "Cluster Population Distribution"] >= 0}]
    set ::mdance::plots::plot_titles 0
    ::mdance::plots::redraw_all
}
th::test "a skipped-K caveat is drawn even with titles off" {
    # This warning exists nowhere else on the canvas, so suppressing it with the
    # title would silently ship an incomplete curve as if it were complete.
    ::mdance::plots::draw_elbow_chart {{2 10.0 0.5} {3 9.0 0.6}} {4 5}
    set txt [canvas_text .mdance_elbow.c]
    th::false [expr {[lsearch -exact $txt "Cluster Quality vs. K"] >= 0}] \
        "the name is still suppressed"
    set found 0
    foreach t $txt { if {[string match "*K = 4, 5 skipped*" $t]} { set found 1 } }
    th::true $found "the caveat must survive"
}

# ------------------------------------------------------------------
th::section "Timeline bars are thinner, and adjustable"
# ------------------------------------------------------------------
th::test "the default thickness is well under the old fixed 0.7" {
    th::true [expr {$::mdance::plots::timeline_thickness < 0.5}]
}
th::test "the thickness control is on the timeline's own window" {
    ::mdance::plots::timeline_chart $::mdance::results
    th::true [winfo exists .mdance_timeline.toolbar.th]
}
th::test "changing it changes the drawn bar height" {
    proc bar_height {} {
        set c .mdance_timeline.c
        foreach id [$c find all] {
            if {[$c type $id] eq "rectangle"} {
                lassign [$c coords $id] x0 y0 x1 y1
                return [expr {$y1 - $y0}]
            }
        }
        return 0
    }
    set ::mdance::plots::timeline_thickness 0.2
    ::mdance::plots::do_redraw mdance_timeline
    set thin [bar_height]
    set ::mdance::plots::timeline_thickness 0.8
    ::mdance::plots::do_redraw mdance_timeline
    set thick [bar_height]
    th::gt $thick $thin "a larger fraction must draw taller bars"
    set ::mdance::plots::timeline_thickness 0.35
}
th::test "a bar never vanishes, however thin the setting" {
    set ::mdance::plots::timeline_thickness 0.001
    ::mdance::plots::do_redraw mdance_timeline
    th::ge [bar_height] 2 "the 2px floor must hold"
    set ::mdance::plots::timeline_thickness 0.35
    ::mdance::plots::do_redraw mdance_timeline
}

exit [th::done "runtime:elbow"]
