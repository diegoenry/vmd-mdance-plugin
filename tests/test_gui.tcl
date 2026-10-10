# Windowed test of the VMDance window: clustering from the window (in
# the background, cancelled, refused), the table and the selection kept
# with the command's, every plot with hovering and clicking, the scans and
# tools, the 3D drawing, runs, files, figures, settings and themes, a
# deleted molecule.
#   cd <VMDance>
#   VMDANCE_OUT=/tmp/mdv vmd -dispdev win -e tests/test_gui.tcl < /dev/null
#   grep -E "FAIL|RESULT" /tmp/mdv/gui.log
# (windowed VMD does not reliably show stdout: everything goes to gui.log)
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::logf [open [file join $::out gui.log] w]
fconfigure $::logf -buffering line
rename puts _puts
proc puts {args} {
    if {[llength $args] == 1} { _puts $::logf [lindex $args 0] } else { _puts {*}$args }
}
set ::bgerrors {}
proc bgerror {msg} { lappend ::bgerrors $msg; puts "BGERROR $msg\n$::errorInfo" }
set ::messages {}
# (an okcancel question answered ok, or ::answer when it is set)
set ::answer ""
proc tk_messageBox {args} {
    lappend ::messages [dict get $args -message]
    puts "  (message: [dict get $args -message])"
    if {[dict exists $args -type] && [dict get $args -type] eq "okcancel"} {
        if {$::answer ne ""} { return $::answer }
        return ok
    }
    return yes
}
set ::next_file ""
proc tk_getSaveFile {args} { return $::next_file }
proc tk_getOpenFile {args} { return $::next_file }
proc tk_chooseDirectory {args} { return $::next_file }
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}
proc plot_ok {key} {
    set c .vmdance.pw.right.nb.$key.c
    ::VMDance::GUI::show_tab $key
    update
    ::VMDance::GUI::redraw
    update
    set bad 0
    foreach id [$c find all] {
        if {[$c type $id] eq "text" && [$c itemcget $id -text] eq "Plot error"} { set bad 1; puts "  plot error in $key: [$c itemcget [expr {$id + 1}] -text]" }
    }
    expr {!$bad && [llength [$c find all]] > 0}
}
proc every_plot_ok {} {
    set ok 1
    foreach key [dict keys $::VMDance::GUI::tabs] { if {![plot_ok $key]} { set ok 0 } }
    return $ok
}
# Hover over a grid of points of a plot: some readout that is not the hint.
proc hover_says {key} {
    set c .vmdance.pw.right.nb.$key.c
    set hint [dict get $::VMDance::GUI::hints $key]
    lassign [::VMDance::Plot::size $c] W H
    for {set x 20} {$x < $W} {incr x 17} {
        for {set y 20} {$y < $H} {incr y 23} {
            ::VMDance::GUI::_hover $key $c $x $y
            if {$::VMDance::GUI::S(readout) ne $hint && $::VMDance::GUI::S(readout) ne ""} { return 1 }
        }
    }
    return 0
}

if {[catch {
# a user's globals of common names are left alone by loading the plugin and
# its window
set ::guard {a b c d e f g h i j k l m n o p q r s t u v w x y z id key name}
foreach ::gv $::guard { set ::$::gv SENTINEL }
package require vmdance
::VMDance::_load_tk
set ::touched [lmap ::gv $::guard {expr {[info exists ::$::gv] && [set ::$::gv] eq "SENTINEL" ? [continue] : $::gv}}]
foreach ::gv $::guard { unset -nocomplain ::$::gv }
set ::VMDance::Prefs::file ""
use_fake
fake_env
set G ::VMDance::GUI
set S ${G}::S
set R ::VMDance::Results
set m [load_system two_state]
set w [vmdance]
update
check "window open" [winfo exists $w]
check "  the backend the command chose is kept (not the preferences')" [expr {[lindex [dict get [vmdance backend] using] 1] eq $::fake}]
check "loading the plugin and its window leaves a user's globals alone ([join $::touched { }])" [expr {![llength $::touched]}]
check "no clustering: the table says so" [string match "No clustering*" [set ${S}(summary)]]
check "every plot draws its empty message" [expr {[every_plot_ok] && ![llength $::bgerrors]}]

# --- setup -------------------------------------------------------------------------
set mx [load_system single_state]
set ${S}(molid) $mx
${G}::refresh_molecules
mol addfile [file join $::fixtures single_state.pdb] waitfor all molid $mx
${G}::_count
check "frames added to a molecule: its line in the chooser follows" [string match "*(20 frames)" [set ${S}(molname)]]
mol delete $mx
set ${S}(molid) $m
${G}::refresh_molecules
set ${S}(sel) all
${G}::_count
check "the atom count under the selection" [expr {[set ${S}(count)] eq "8 atoms" && [set ${S}(nframes)] eq "24 of 24 frames"}]
set ${S}(sel) "x > 1"
${G}::_count
check "  a selection that changes with the frame says so" [string match "changes with the frame*" [set ${S}(count)]]
set ${S}(sel) "all and ("
${G}::_count
check "  an invalid one" [expr {[set ${S}(count)] eq "invalid selection"}]
# (hardening 2, g8 F55: a quoted value is no keyword: chain "x" was said to
# change with the frame)
set ${S}(sel) {not resname "x" "within"}
${G}::_count
check "  a quoted value that is a keyword's name: counted" [expr {[set ${S}(count)] eq "8 atoms"}]
set ${S}(sel) {chain "x}
${G}::_count
check "  a quote left open: invalid (not 'changes with the frame')" [expr {[set ${S}(count)] eq "invalid selection"}]
# (g8 F54: the 3D tab's atoms are checked with no clustering too: a typo
# was kept, then drawn as other atoms without a word)
set ${S}(v3d_sel) "nmae CA"
${G}::draw_changed
check "  3D atoms mistyped before a clustering: said, and not kept" [expr {
    [string match "3D: -sel: invalid atom selection*" [set ${S}(status)]] && [dict get [::VMDance::Viz::get] sel] eq ""}]
set ${S}(v3d_sel) ""
${G}::draw_changed
set ${S}(sel) all
set ${S}(framemode) range
set ${S}(step) 0
${G}::_count
check "  a step of 0" [string match "*1 or more*" [set ${S}(nframes)]]
set ${S}(step) 1
set ${S}(framemode) all
set ${S}(algorithm) helm
${G}::_algorithm_changed
update
set pb [set ${G}::parambox]
check "HELM chosen: its parameters shown, the others' not" [expr {[winfo ismapped $pb.helm] && ![winfo ismapped $pb.kmeans]}]
check "  the trim values greyed until Trim first" [expr {[$pb.helm.ptrim_k instate disabled]}]
set ${S}(p_helm_trim-start) 1
${G}::_params_sync
check "  and live with it" [expr {![$pb.helm.ptrim_k instate disabled]}]
set ${S}(p_helm_trim-start) 0
set ${S}(algorithm) equal
${G}::_algorithm_changed
update
check "eQUAL: no k, and the toolbar's Elbow off" [expr {![winfo exists $pb.equal.k] && [$w.tb.elbow instate disabled]}]
set ${S}(algorithm) divine
${G}::_algorithm_changed
set ${S}(p_divine_anchors) OutlierPair
set ${S}(p_divine_refine) 1
${G}::_params_sync
check "DIVINE with pair anchors: Refine greyed, and sent off (the request is taken)" [expr {[$pb.divine.prefine instate disabled] &&
    [dict get [${G}::_params_of divine] refine] == 0 && ![catch {::VMDance::Job::check_cluster [${G}::request]}]}]
# (h1: N23, Refine changes nothing with NANI either; N10, NANI's splits do
# not use the smallest share; N09, DIVINE's metric is MSD)
check "  h1 N10: the smallest share live with them" [expr {![$pb.divine.pthreshold instate disabled]}]
set ${S}(p_divine_anchors) NANI
${G}::_params_sync
check "  h1 N23: with NANI Refine greyed and sent off too, and the smallest share greyed (not sent)" [expr {[$pb.divine.prefine instate disabled] &&
    [dict get [${G}::_params_of divine] refine] == 0 && [$pb.divine.pthreshold instate disabled] && ![dict exists [${G}::_params_of divine] threshold]}]
${G}::param_defaults
check "  h1 N23: its default unticked" [expr {[set ${S}(p_divine_refine)] == 0}]
set ${S}(unlock_metrics) 1
${G}::_metric_lock
set ${S}(metric) JT
check "  h1 N09: the metrics unlocked: DIVINE's still MSD (shown, and sent), KMeans's chosen" [expr {
    [winfo manager $pb.divine.met.l] eq "pack" && [winfo manager $pb.divine.met.c] eq "" && [winfo manager $pb.kmeans.met.c] eq "pack" &&
    [dict get [${G}::request] metric] eq "MSD" && ![catch {::VMDance::Job::check_cluster [${G}::request]}]}]
# (the final review: eQUAL takes MSD only too, which check_combination
# alone said: the chooser offered it every metric, and Cluster refused all
# but MSD)
set ${S}(algorithm) equal
${G}::_algorithm_changed
set ${S}(metric) SM
set th0 [set ${S}(p_equal_threshold)]
set ${S}(p_equal_threshold) 1
check "  the metrics unlocked: eQUAL's MSD too (shown, saying why, and sent), as the table has it" [expr {
    [winfo manager $pb.equal.met.l] eq "pack" && [winfo manager $pb.equal.met.c] eq "" &&
    [$pb.divine.met.l cget -text] eq "MSD (DIVINE splits by MSD)" && [$pb.equal.met.l cget -text] eq "MSD (eQUAL's radius is an MSD)" &&
    [dict get [${G}::request] metric] eq "MSD" && ![catch {::VMDance::Job::check_cluster [${G}::request]}]}]
set ${S}(p_equal_threshold) $th0
set ${S}(unlock_metrics) 0
${G}::_metric_lock
set ${S}(algorithm) equal
${G}::_algorithm_changed
${G}::cluster
check "  eQUAL without a radius is refused (the message says why)" [expr {![set ${S}(busy)] && [string match "*-threshold is needed*" [lindex $::messages end]]}]
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
set ${S}(k_kmeans) 30
${G}::cluster
check "  k above the frames: refused" [string match "*-k must be from 1*" [lindex $::messages end]]
set ${S}(k_kmeans) 2
set ${S}(p_kmeans_kinit) CompSim
${G}::param_defaults
check "Defaults" [expr {[set ${S}(k_kmeans)] == 10 && [set ${S}(p_kmeans_kinit)] eq "StratAll"}]
set ${S}(k_kmeans) 2

# --- clustering in the background --------------------------------------------------------
fake_env MDANCE_FAKE_SLEEP 1.5
${G}::cluster
update
check "a clustering runs in the background: Cancel on, Cluster off" [expr {[set ${S}(busy)] && [$w.tb.cancel instate !disabled] && [$w.tb.cluster instate disabled]}]
set P3 [set ${G}::page(v3d)]
check "  the 3D toggles, the 3D tab and menu, Settings off too" [expr {[$w.tb.colour instate disabled] && [$w.tb.reps instate disabled] &&
    [$w.tb.settings instate disabled] && [$P3.ov.col instate disabled] && [$w.menu.v3d entrycget 0 -state] eq "disabled"}]
set ${S}(v3d_colour) 1
${G}::toggle_reps
check "  the window answers (a redraw returns at once)" [expr {[catch {${G}::redraw}] == 0}]
wait_idle
check "  done: the table of clusters" [expr {[llength [[set ${G}::tree] children {}]] == 2 && [string match "KMeans NANI, k 2*2 clusters*" [set ${S}(summary)]]}]
check "  the 3D tab back on, showing what is drawn (nothing changed meanwhile)" [expr {[$P3.ov.col instate !disabled] && [$w.tb.colour instate !disabled] &&
    ![set ${S}(v3d_colour)] && ![set ${S}(v3d_reps)] && ![dict get [::VMDance::Viz::get] colour]}]
check "  the Results tab shown" [expr {[[set ${G}::leftnb] select] eq "[set ${G}::leftnb].results"}]
fake_env MDANCE_FAKE_SLEEP 6
set ${S}(k_kmeans) 2
set nruns [llength [${R}::run_list]]
${G}::cluster
after 700 {::VMDance::GUI::cancel}
wait_idle
check "Cancel: stopped, the clustering there kept" [expr {[string match "Cancelled*" [set ${S}(status)]] && [llength [${R}::run_list]] == $nruns}]
${G}::cluster
after 700 { if {[::VMDance::Backend::running]} { catch {exec kill -INT {*}[dict get $::VMDance::Backend::job pids]} } }
wait_idle
check "  the program stopped from outside (Ctrl+C at VMD's terminal): stopped, said how, the clustering there kept" [expr {
    [string match "Cancelled: mdance-cli was stopped (interrupt); what was there is kept*" [set ${S}(status)]] && [llength [${R}::run_list]] == $nruns}]
fake_env MDANCE_FAKE_FAIL 1
${G}::cluster
wait_idle
check "  a failure: said, the clustering kept" [expr {[string match "*simulated backend failure*" [lindex $::messages end]] && [llength [${R}::run_list]] == $nruns}]
fake_env

# --- the table and the selection ------------------------------------------------------------
set tree [set ${G}::tree]
${G}::sort_by frames
set a [$tree children {}]
${G}::sort_by frames
check "sort by a column, and back" [expr {[lreverse $a] eq [$tree children {}] || [llength [lsort -unique $a]] == 2}]
$tree selection set c1
update; after 100; update
check "selecting a row selects the cluster" [expr {[${R}::selected] eq {1}}]
vmdance select 0
update
check "  the command's selection shows in the table" [expr {[$tree selection] eq {c0}}]
check "  and in words" [string match "Cluster 0: 12 frames*" [set ${S}(detail)]]
check "every plot draws the clustering" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
foreach key {populations timeline transitions residence compactness distances tree silhouette} {
    ::VMDance::GUI::show_tab $key
    update
    check "  $key: the readout says what is under the pointer" [hover_says $key]
}
::VMDance::GUI::show_tab populations
update
set c $w.pw.right.nb.populations.c
set b [lindex [set ::VMDance::Plots::H($c,bars)] 1]
${G}::_click populations $c [expr {([lindex $b 0] + [lindex $b 1]) / 2}] [expr {[winfo height $c] - 60}] 0
check "  a click on a bar selects its cluster" [expr {[${R}::selected] eq {1}}]
${G}::_dclick populations $c [expr {([lindex $b 0] + [lindex $b 1]) / 2}] [expr {[winfo height $c] - 60}]
check "  a double-click goes to its representative" [expr {[molinfo $m get frame] == [${R}::rep_frame 1]}]
::VMDance::GUI::show_tab timeline
update
set c $w.pw.right.nb.timeline.c
lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
${G}::_click timeline $c [expr {$x0 + 3}] [expr {($y0 + $y1) / 2}] 0
check "timeline: a click goes to that frame" [expr {[molinfo $m get frame] == 0}]
animate goto 20
update; after 200; update
check "  the red line follows VMD's frame" [expr {[llength [$c find withtag cursor]] == 1}]
# (hardening 2, F27: frames read into the clustered molecule, the Timeline
# shown, read every clustered frame again at each new count of frames, for
# a frame past them that has no line)
rename ::VMDance::Coords::_fp ::VMDance::Coords::_fp_counted
set ::fp_reads 0
proc ::VMDance::Coords::_fp {args} { incr ::fp_reads; ::VMDance::Coords::_fp_counted {*}$args }
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
animate goto [expr {[molinfo $m get numframes] - 1}]
update; after 300; update
set n1 $::fp_reads
animate goto 20
update; after 300; update
check "  frames added to the clustered molecule, VMD at the last: no frame read again for the line ($n1); back among the clustered ones: read once, the line drawn" [expr {
    $n1 == 0 && $::fp_reads == 24 && [llength [$c find withtag cursor]] == 1}]
rename ::VMDance::Coords::_fp ""
rename ::VMDance::Coords::_fp_counted ::VMDance::Coords::_fp
animate delete beg 24 end 47 $m

# every kind of result
vmdance -mol $m -sel all -algorithm helm -k 2 -initial 6 -initial-kinit KmeansPP -quiet 1
check "HELM: every plot, the tree HELM's" [expr {[every_plot_ok] && [lindex [set ::VMDance::Plots::H($w.pw.right.nb.tree.c,tree)] 0] eq "helm"}]
# (h1 N22: a linkage of the mean structures can join DIVINE's clusters
# across its first split: the plot says which tree it is)
proc tree_texts {} {
    set c .vmdance.pw.right.nb.tree.c
    lmap i [$c find all] {expr {[$c type $i] eq "text" ? [$c itemcget $i -text] : [continue]}}
}
vmdance -mol $m -sel all -algorithm divine -k 3 -quiet 1
set dt [expr {[plot_ok tree] ? [tree_texts] : {}}]
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
set kt [expr {[plot_ok tree] ? [tree_texts] : {}}]
check "h1 N22: DIVINE's tree says it is the average linkage of the mean structures, not DIVINE's splits; KMeans's the linkage alone" [expr {
    [lsearch -glob $dt "*average linkage of the mean structures, not DIVINE's splits*"] >= 0 &&
    [lsearch -glob $kt "*average linkage of the mean structures*"] >= 0 && [lsearch -glob $kt "*DIVINE*"] < 0}]
# (h1 review N22: that axis title, too long for a figure narrower than about
# 405 pt, was cut at its edge, "not DIVINE's splits" lost: it wraps, under
# the plot and within the figure)
vmdance -mol $m -sel all -algorithm divine -k 3 -quiet 1
set fc [::VMDance::Figures::render_plot tree 240 240]
set ti [lindex [lmap i [$fc find all] {expr {[$fc type $i] eq "text" && [string match "Cluster (*not DIVINE's splits)" [$fc itemcget $i -text]] ? $i : [continue]}}] 0]
set tb [expr {$ti ne "" ? [$fc bbox $ti] : {}}]
check "h1 review N22: a 240-pt figure of DIVINE's tree: its axis title whole, under the plot and within the figure ($tb)" [expr {$ti ne "" &&
    [lindex $tb 0] >= 0 && [lindex $tb 2] <= 240 && [lindex $tb 3] <= 240 && [lindex $tb 1] >= [lindex [::VMDance::Plot::area $fc] 3]}]
destroy $fc
# (h1 review N10: the Results pane's summary, the only text of a run opened
# from a session or switched to, did not say why DIVINE stopped short of k)
vmdance -mol $m -sel all -algorithm divine -k 2 -anchors SplinterPair -threshold 0.3 -quiet 1
set a $::VMDance::Results::A
dict set a request k 6
${R}::publish $a
update
check "h1 review N10: the Results summary says why DIVINE has fewer clusters than asked" [string match "DIVINE, k 6 of * frames × * atoms: 2 clusters — fewer than the 6 asked: no split left * frames or more on each side (-threshold 0.3). Calinski–Harabasz *" [set ${S}(summary)]]
set o [load_system outlier]
vmdance -mol $o -sel all -algorithm equal -threshold 1.0 -quiet 1
check "eQUAL with noise: every plot" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
set s1 [load_system single_state]
vmdance -mol $s1 -sel all -k 1 -quiet 1
check "one cluster: every plot (no silhouette, no tree)" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
# every frame noise: the plots between clusters say there is none, and
# figures leave them out
set a $::VMDance::Results::A
set n [llength [dict get $a frames]]
foreach {k v} [list nclusters 0 labels [lrepeat $n -1] sizes {} representatives {} msd {} ch "" db "" zmatrix {} initial {} extras {}] { dict set a $k $v }
dict set a measures [dict create frame_msd [lrepeat $n ""] silhouette [lrepeat $n ""] rep_msd {} centroid_msd {}]
${R}::publish $a "every frame noise"
check "every frame noise: every plot" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
check "  the figures by default: the populations and the timeline" [expr {
    [lmap p [dict keys $::VMDance::GUI::tabs] {expr {[::VMDance::Plots::has_data $p] ? $p : [continue]}}] eq {populations timeline}}]
set figs [vmdance figures $::out -prefix allnoise -formats eps -width 400 -height 300]
check "  vmdance figures: those two" [expr {[lmap f $figs {file rootname [file tail $f]}] eq {allnoise_populations allnoise_timeline}}]
if {[real_cli] ne ""} {
    use_cli
    vmdance -mol $o -sel all -algorithm equal -threshold 0.0001 -reject-lowd 1 -min-samples 3 -quiet 1
    check "  the backend's own (eQUAL, a tiny radius: [${R}::noise] of [${R}::nframes] frames noise): every plot" [expr {
        [${R}::nclusters] == 0 && [every_plot_ok] && ![llength $::bgerrors]}]
    use_fake
} else {
    skip "  the backend's own all-noise eQUAL" "no mdance-cli (set MDANCE_CLI)"
}
vmdance run 1
set ::VMDance::Measure::maxk 1
check "more clusters than the matrices and the tree are drawn for: they say so" [expr {[plot_ok transitions] && [plot_ok distances] && [plot_ok tree] &&
    [string match "2 clusters" [$w.pw.right.nb.tree.c itemcget [lindex [$w.pw.right.nb.tree.c find all] 0] -text]]}]
set ::VMDance::Measure::maxk 300
# a job of the command's: the window is busy while it runs
fake_env MDANCE_FAKE_SLEEP 1
set ::during {}
after 500 {set ::during [list [set ::VMDance::GUI::S(busy)] [.vmdance.tb.cancel instate !disabled] [.vmdance.tb.cluster instate disabled]]}
vmdance -mol $m -sel all -k 2 -quiet 1
update
fake_env
check "a job of the command's: the window busy while it runs ($::during), idle after" [expr {$::during eq {1 1 1} && ![set ${S}(busy)] &&
    [$w.tb.cluster instate !disabled] && [$w.tb.cancel instate disabled]}]
vmdance run 1

# --- the plot options -------------------------------------------------------------------
set ${S}(show_opts) 1
${G}::panels_changed
update
check "the plot options panel shown, the option row above the plot hidden" [expr {[winfo ismapped $w.pw.opts] && ![winfo ismapped $w.pw.right.nb.timeline.opts]}]
foreach key [dict keys $::VMDance::GUI::tabs] {
    ::VMDance::GUI::show_tab $key
    update
    if {![winfo ismapped $w.pw.opts.body.${key}_sec]} { puts "  options of $key not shown" }
}
check "  each plot's own section" [winfo ismapped $w.pw.opts.body.sweep_sec]
set ${S}(tn_show) counts
${G}::show_tab transitions
${G}::reset_plot_options
check "  Reset this plot" [expr {[set ${S}(tn_show)] eq "probability"}]
foreach {k v} {po_show percent po_sort size tl_view msd tn_show counts tn_self 0 rs_show visits rs_unit vmd cp_show scatter
               cp_show spread ds_show representatives td_labels 0 sl_sort 0 eb_show db sw_score db plot_grid 0 plot_legend 0} {
    set ${S}($k) $v
}
check "  every plot with other settings" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
set ${S}(show_opts) 0
set ${S}(show_left) 0
${G}::panels_changed
update
check "the left panel hidden" [expr {![winfo ismapped $w.pw.left]}]
set ${S}(show_left) 1
${G}::panels_changed

# --- scans --------------------------------------------------------------------------------
foreach a {po_show po_sort tl_view tn_show tn_self rs_show rs_unit cp_show ds_show td_labels sl_sort eb_show sw_score plot_grid plot_legend} {
    set ${S}($a) [dict get [set ${G}::optdefaults] $a]
}
set ${S}(molid) $m
${G}::refresh_molecules
set ${S}(sel) all
set ${S}(algorithm) kmeans
set ${S}(p_kmeans_kinit) KmeansPP
set ${S}(eb_from) 2
set ${S}(eb_to) 5
${G}::elbow
wait_idle
check "Elbow from the window: the elbow plot" [expr {[llength [dict get $::VMDance::Results::elbow records]] == 4 && [${G}::_current_tab] eq "elbow"}]
update
set c $w.pw.right.nb.elbow.c
set px [::VMDance::Plot::X $c 3]
lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
${G}::_hover elbow $c $px [expr {($y0 + $y1) / 2}]
check "  hover: the shares of the clusters at that k" [expr {[llength [$c find withtag partition]] > 3 && [string match "k = 3*" [set ${S}(readout)]]}]
${G}::_leave elbow $c
check "  gone when the pointer leaves" [expr {![llength [$c find withtag partition]]}]
# (g7's F15: a record's nclusters counts the clusters with frames)
::VMDance::Plots::_partition $c $px [expr {($y0 + $y1) / 2}] 3 {status ok nclusters 2 sizes {3 0 3}}
check "  a k whose clustering left a cluster empty: the box says how many it found" [expr {
    [lsearch -exact [lmap i [$c find withtag partition] {if {[$c type $i] ne "text"} continue; $c itemcget $i -text}] "k = 3 (found 2)"] >= 0}]
$c delete partition
# (g7's F47: the RMSD² from the representative is lower than the MSD within)
check "the tips of the RMSD² from the representative: from half the MSD to all of it (they said twice as large)" [expr {
    [string match "*from half the MSD to all of it*" [dict get [set ${G}::opttips] cp_show]] && ![string match "*twice*" [dict get [set ${G}::opttips] cp_show]] &&
    [string match "*from half the MSD to all of it*" $::VMDance::Tip::text([set ${G}::tree])] && ![string match "*twice*" $::VMDance::Tip::text([set ${G}::tree])]}]
set n [llength [${R}::run_list]]
${G}::_dclick elbow $c $px [expr {($y0 + $y1) / 2}]
wait_idle
check "  a double-click makes it the clustering" [expr {[llength [${R}::run_list]] == $n + 1 && [${R}::nclusters] == 3}]
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a ne "helm"}] }
set ${S}(gr_seed_StratAll) 0
set ${S}(gr_seed_KmeansPP) 1
set ${S}(gr_from) 2
set ${S}(gr_to) 3
${G}::_grid_count
check "Sweep: the configurations counted" [expr {[set ${S}(gr_count)] eq "4 configurations"}]
${G}::sweep
wait_idle
set swt [set ${G}::swtree]
check "  the table of the sweep, the best marked" [expr {[llength [$swt children {}]] == 4 &&
    [llength [$swt tag has bestch]] + [llength [$swt tag has bestboth]] == 1 && [llength [$swt tag has bestdb]] + [llength [$swt tag has bestboth]] == 1}]
check "  the sweep plot" [plot_ok sweep]
${G}::show_pane scans
update
set n [llength [${R}::run_list]]
set db [bind $swt <Double-1>]
set hy 4
while {$hy < 40 && [$swt identify region 20 $hy] ne "heading"} { incr hy }
uplevel #0 [string map [list %W $swt %x 20 %y $hy] $db]
update
check "  a double-click on a heading: nothing made the clustering" [expr {[llength [${R}::run_list]] == $n && ![set ${S}(busy)]}]
$swt selection set r1
${G}::adopt_sweep_selected
wait_idle
check "  a configuration made the clustering" [expr {[dict get [${R}::request] k] == 3 && [dict get [${R}::request] algorithm] eq "kmeans"}]
set keep_sweep $::VMDance::Results::sweep
fake_env MDANCE_FAKE_FAIL 1
${G}::sweep
wait_idle
fake_env
check "  a sweep where every configuration failed says so" [string match "*every configuration failed*" [set ${S}(status)]]
${R}::set_sweep $keep_sweep
fake_env MDANCE_FAKE_NO_DIVINE 1
${G}::backend_changed
set PS [set ${G}::page(setup)]; set PC [set ${G}::page(scans)]
check "a backend without DIVINE: not offered, in Setup or the sweep" [expr {"DIVINE" ni [$PS.alg.c cget -values] &&
    [$PC.gr.alg.divine instate disabled] && ![set ${S}(gr_alg_divine)]}]
fake_env
${G}::backend_changed
check "  with it again: offered" [expr {"DIVINE" in [$PS.alg.c cget -values] && [$PC.gr.alg.divine instate !disabled]}]
# (h1 N24: a program rebuilt at its path with DIVINE, the window open: the
# chooser asks again as it opens)
set rb [file join $::out rebuilt-cli]
proc write_prog {path algs} {
    set fh [open $path w]
    puts $fh "#!/bin/sh"
    puts $fh "if \[ \$# -eq 0 \]; then echo 'Usage: mdance-cli --algorithm {$algs}' >&2; exit 1; fi"
    puts $fh "exec '$::fake' \"\$@\""
    close $fh
    file attributes $path -permissions 0755
}
write_prog $rb {kmeans|helm|equal}
::VMDance::Backend::configure -mode cli -cli $rb
${G}::backend_changed
set before [expr {"DIVINE" ni [$PS.alg.c cget -values] && [$PC.gr.alg.divine instate disabled]}]
write_prog $rb {kmeans|divine|helm|equal}
uplevel #0 [$PS.alg.c cget -postcommand]
check "h1 N24: a program rebuilt with DIVINE at its path: the chooser, opened, offers it, and the sweep" [expr {$before &&
    "DIVINE" in [$PS.alg.c cget -values] && [$PC.gr.alg.divine instate !disabled]}]
# (h1 review N24: rebuilt behind a launcher, whose stamp stays the same)
set rq [file join $::out launched-cli]
set rl [file join $::out launcher]
write_prog $rq {kmeans|helm|equal}
set fh [open $rl w]
puts $fh "#!/bin/sh\nexec '$rq' \"\$@\""
close $fh
file attributes $rl -permissions 0755
::VMDance::Backend::configure -mode cli -cli $rl
${G}::backend_changed
set before [expr {"DIVINE" ni [$PS.alg.c cget -values] && [$PC.gr.alg.divine instate disabled]}]
write_prog $rq {kmeans|divine|helm|equal}
${G}::_availability
set still [expr {"DIVINE" ni [$PS.alg.c cget -values]}]
uplevel #0 [$PS.alg.c cget -postcommand]
check "h1 review N24: a program rebuilt with DIVINE behind its launcher: the chooser, opened, offers it, and the sweep (not each refresh)" [expr {
    $before && $still && "DIVINE" in [$PS.alg.c cget -values] && [$PC.gr.alg.divine instate !disabled]}]
use_fake
${G}::backend_changed

# --- tools ------------------------------------------------------------------------------
${G}::prime
wait_idle
check "PRIME from the window: seven rows" [expr {[llength [[set ${G}::prtree] children {}]] == 7}]
${G}::similarity
wait_idle
check "Similarity: the compactness plot shows it" [expr {[set ${S}(cp_show)] eq "isim" && [plot_ok compactness] && [string match "All frames:*" [set ${S}(si_info)]]}]
set ${S}(pk_method) outliers
set ${S}(pk_param) 4
fake_env MDANCE_FAKE_SLEEP 0.5
${G}::show_tab populations
update
${G}::pick
$w.pw.right.nb.tree.c delete all
${G}::show_tab tree
update
wait_idle
fake_env
check "Pick frames: the list" [expr {[[set ${G}::picklist] size] == 4}]
check "  a tab shown while it ran is drawn after" [expr {[llength [$w.pw.right.nb.tree.c find all]] > 0}]
# (hardening 2, F19: the list's double-click went through the clustering,
# needed one, and said nothing when it went)
set pm [dict get $::VMDance::Results::picks input mol]
set pf [dict get $::VMDance::Results::picks vmdframes]
[set ${G}::picklist] selection clear 0 end
[set ${G}::picklist] selection set 1
${G}::_pick_goto
check "  a double-click on the list: VMD's frame there, on the picks' molecule, and said" [expr {
    [molinfo $pm get frame] == [lindex $pf 1] && [set ${S}(status)] eq "Frame [lindex $pf 1] of molecule $pm: a picked frame."}]

# --- 3D -------------------------------------------------------------------------------
set n0 [molinfo $m get numreps]
set ${S}(v3d_colour) 1
${G}::draw_changed
check "3D: colour by cluster" [expr {[molinfo $m get numreps] == $n0 + 1}]
set ${S}(v3d_overlay) 1
vmdance select clear
${G}::draw_changed
check "  an overlay with no selection says to select" [string match "*select one*" [set ${S}(status)]]
set ${S}(v3d_colour) 0
set ${S}(v3d_overlay) 0
${G}::draw_changed
check "  off: the user's representations only" [expr {[molinfo $m get numreps] == $n0}]
# (hardening 2, F19: the picks were drawn on the clustered molecule only)
set pn0 [molinfo $pm get numreps]
set ${S}(v3d_picks) 1
${G}::draw_changed
check "  the picked frames: drawn on their molecule, and said" [expr {
    [molinfo $pm get numreps] == $pn0 + 1 && [string match "*the picked frames drawn in molecule $pm*" [set ${S}(status)]]}]
set ${S}(v3d_picks) 0
${G}::draw_changed
${G}::_colour_key
check "  the key of the colours" [winfo exists [set ${G}::keybox].c0]
vmdance draw -overlay 1 -frames 0-5
check "  an overlay of frames from the command: the window's too" [expr {[set ${S}(v3d_mode)] eq "frames" && [set ${S}(v3d_frames)] eq "0-5"}]
vmdance draw -frames ""
check "  cleared by the command: the window's overlay is the selected clusters' again" [expr {[set ${S}(v3d_mode)] eq "top"}]
vmdance draw -overlay 0
check "  (and Colour then sends no frames)" [expr {[dict get [::VMDance::Viz::get] frames] eq ""}]

# --- what is typed, taken as typed (hardening 2, F49: never through expr's ?:) ----------------
set ${S}(k_kmeans) 010
${G}::cluster
check "k typed 010: refused as the command refuses it (not k 8)" [expr {![set ${S}(busy)] && [string match "*-k must be a whole number*" [lindex $::messages end]]}]
set ${S}(k_kmeans) 2
set ${S}(v3d_mode) frames
set ${S}(v3d_frames) 010
${G}::draw_changed
check "  overlay frames typed 010: frame 10, not 8" [expr {[dict get [::VMDance::Viz::get] frames] eq "010"}]
set ${S}(v3d_mode) top
${G}::draw_changed
after 300 {set ::VMDance::GUI::ask(v) 0x10; set ::VMDance::GUI::ask(ok) 1; destroy .vmdance.ask}
${G}::rename_run
check "  a run renamed 0x10: named 0x10, not 16" [expr {[lindex [lsearch -inline -index 0 [${R}::run_list] $::VMDance::Results::current] 1] eq "0x10"}]

# --- files --------------------------------------------------------------------------------
set sf [file join $::out gui.vmdance]
set ::next_file $sf
set ${S}(tl_view) msd
${G}::save_session 1
check "save the session (dialog)" [file exists $sf]
set ${S}(tl_view) lanes
set ${S}(show_opts) 1
${G}::panels_changed
${G}::show_tab timeline
${G}::_rows_changed
update
foreach e [set ${G}::optwhen] { lassign $e wids cond; if {[string match *tl_view* $cond]} { set tlw [lindex $wids 0] } }
set shown_before [winfo ismapped $tlw]
${G}::open_session_dialog
update
check "  open it: asked first, the plot settings back" [expr {[set ${S}(tl_view)] eq "msd" && [string match "Open *in place of what is here?" [lindex $::messages end]]}]
check "  the plot options follow them (the timeline's bar height hidden)" [expr {$shown_before && ![winfo ismapped $tlw]}]
set sf2 [file join $::out gui_other.vmdance]
vmdance session save $sf2
set t2 [file mtime $sf2]
after 1100
${G}::save_session 0
check "  Save writes the session last saved or opened, by the command too" [expr {[file mtime $sf2] > $t2}]
set ::next_file [file join $::fixtures old_kmeans.mdance]
set nr [llength [${R}::run_list]]
${G}::import_session_dialog
wait_idle
check "Import a session of the MDANCE plugin (dialog)" [expr {[llength [${R}::run_list]] == $nr + 1 && [string match "*(imported)" [lindex [${R}::run_list] end 1]]}]
# (hardening 2, the review of g5, R12: an import whose molecule auto cannot
# tell is put on the molecule asked for, as -mol does; it was refused,
# naming -mol, which the window has not. With oi's N11 the window offers
# the molecule of Setup, and never says -mol)
set t [read_text [file join $::fixtures old_kmeans.mdance]]
set nf0 $::next_file
set ::next_file [file join $::out gui_nosig.mdance]
set fh [open $::next_file w]; puts $fh [dict replace [dict remove $t molSignature] results [dict remove [dict get $t results] clusterMSD]]; close $fh
set ${S}(molid) $m
${G}::refresh_molecules
set nr [llength [${R}::run_list]]
set ::answer cancel
${G}::import_session_dialog
wait_idle
set asked [lindex $::messages end]
set ok1 [expr {[llength [${R}::run_list]] == $nr && [string match "Not imported*" [set ${S}(status)]]}]
set ::answer ""
set n0 [llength $::messages]
${G}::import_session_dialog
wait_idle
wait_idle
check "  one whose molecule cannot be told (no name, no cluster MSD): the molecule of Setup offered, and imported onto it, said unchecked (Cancel: nothing)" [expr {
    $ok1 && [string match "Import gui_nosig.mdance onto molecule $m, the molecule of Setup?" $asked] &&
    [llength [${R}::run_list]] == $nr + 1 && [dict get [${R}::request] mol] == $m && [llength $::messages] == $n0 + 1 &&
    [string match "*molecule $m was taken as asked, unchecked*" [set ${S}(status)]] &&
    ![llength [lsearch -all -glob [lrange $::messages $n0 end] "*-mol*"]]}]
set ::next_file $nf0
# (hardening 2, N11: its molecule with frames added is taken; with none of
# its name, the molecule of Setup is offered: the window never says -mol)
mol rename $m gui_renamed
set m2 [load_system two_state]
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m2
set nr [llength [${R}::run_list]]
set n0 [llength $::messages]
${G}::import_session_dialog
wait_idle
check "  its molecule with frames added (48): taken, said (refused, naming -mol)" [expr {
    [llength [${R}::run_list]] == $nr + 1 && [dict get [${R}::request] mol] == $m2 && [llength $::messages] == $n0 &&
    [string match "*has 48 frames*" [set ${S}(status)]]}]
mol delete $m2
set ${S}(molid) $m
${G}::refresh_molecules
set ::answer cancel
${G}::import_session_dialog
wait_idle
set asked [lindex $::messages end]
set ::answer ""
${G}::import_session_dialog
wait_idle
check "  none of its name: the molecule of Setup offered (Cancel: nothing), and taken" [expr {
    [string match "Import old_kmeans.mdance onto molecule $m, the molecule of Setup?" $asked] &&
    [llength [${R}::run_list]] == $nr + 2 && [dict get [${R}::request] mol] == $m}]
set sm [load_system single_state]
set ${S}(molid) $sm
${G}::refresh_molecules
${G}::import_session_dialog
wait_idle
check "  the molecule of Setup without its frames: not offered, said what to do" [expr {[llength [${R}::run_list]] == $nr + 2 &&
    [string match "*is not loaded.\nLoad its molecule, or choose it in Setup, and import again." [lindex $::messages end]] &&
    ![llength [lsearch -all -glob [lrange $::messages $n0 end] "*-mol*"]]}]
mol delete $sm
mol rename $m two_state.pdb
set ${S}(molid) $m
${G}::refresh_molecules
# (N20: an import that does not record its parameters leaves the Setup's)
set ${S}(p_kmeans_kinit) KmeansPP
set ${S}(p_kmeans_percentage) 20
set ::next_file [file join $::fixtures old_sweep.mdance]
${G}::import_session_dialog
wait_idle
check "  a configuration of the MDANCE plugin's sweep: its parameters said not recorded, the Setup's left (made StratAll, 10%)" [expr {
    [llength [${R}::run_list]] == $nr + 3 && [string match "*parameters not recorded)" [lindex [${R}::run_list] end 1]] &&
    [set ${S}(p_kmeans_kinit)] eq "KmeansPP" && [set ${S}(p_kmeans_percentage)] == 20}]
set dir [file join $::out gui_export]
file delete -force $dir
file mkdir $dir
set ${S}(out_dir) $dir
${G}::export_dialog
update
${G}::_export_go
check "Export results" [expr {[llength [glob -nocomplain -directory $dir *]] >= 8}]
# (hardening 2, F20: what the dialog offered when it opened may be gone, a
# run switched: refused as the command refuses it, before Replace is asked
# and anything written; it said "Not exported" after writing 10 files)
${G}::export_dialog
update
set ${G}::X(prime) 1
set n0 [llength $::messages]
${G}::_export_go
check "  an item the run no longer has, ticked when the dialog opened (PRIME): refused before Replace is asked, nothing written" [expr {
    [llength $::messages] == $n0 + 1 && [string match "Not exported:*no PRIME prediction*" [lindex $::messages end]] &&
    ![file exists [file join $dir vmdance_prime.csv]]}]
set ${G}::X(prime) 0
destroy $w.export
set ${S}(fig_dir) $dir
${G}::figure_dialog
update
foreach k [dict keys $::VMDance::GUI::tabs] { set ${G}::F($k) [expr {$k in {populations timeline elbow}}] }
${G}::_figures_go
check "Create figures: PDF and PNG" [expr {[file exists [file join $dir vmdance_populations.pdf]] && [file exists [file join $dir vmdance_elbow.png]]}]
set ::next_file [file join $dir quick.csv]
${G}::quick_table
check "Quick export: the table" [expr {[llength [csv_rows [file join $dir quick.csv]]] == [${R}::nclusters] + 1}]
set ::next_file [file join $dir plot.csv]
${G}::show_tab residence
${G}::save_plot_data
check "  this plot's data" [string match "*residence*" [read_text [file join $dir plot.csv]]]
set figs [vmdance figures $dir -plots {tree silhouette} -formats eps -width 400 -height 300]
check "vmdance figures: EPS without Ghostscript's help" [expr {[llength $figs] == 2 && [file size [lindex $figs 0]] > 1000}]
# (hardening 2, F03: the figures' temporaries were <base>.tmp<pid>.eps and
# <name>.tmp<pid>.ppm beside them, opened following a link put there)
set sent [file join $::out gui_sentinel]
set fh [open $sent w]; puts -nonewline $fh PRECIOUS; close $fh
file link -symbolic [file join $dir lk_populations.tmp[pid].eps] $sent
file link -symbolic [file join $dir lk_3d.tmp[pid].ppm] $sent
set figs [vmdance figures $dir -prefix lk -plots populations -formats {pdf png} -3d 1]
check "  links at the names their temporaries had (EPS, PPM): none written through; each figure a file of its own" [expr {
    [read_text $sent] eq "PRECIOUS" && [llength $figs] == 3 && [lsort -unique [lmap f $figs {file type $f}]] eq "file"}]
# (hardening 2, F72: the folder must have existed)
set figs [vmdance figures [file join $dir newfigs sub] -plots populations -formats eps -width 400 -height 300]
set e [err {vmdance figures [file join $dir nofigs] -plots nothing -formats eps}]
check "  into a folder that does not exist: made; a refused call makes none" [expr {
    [llength $figs] == 1 && [file isfile [lindex $figs 0]] && [string match "*unknown plot*" $e] && ![file exists [file join $dir nofigs]]}]
# (g8 F59: the 3D view alone, as the window renders it: "-plots {}" said
# "no clustering, no scan" with one)
set rc [catch {vmdance figures $dir -prefix only -plots {} -3d 1} figs]
check "vmdance figures -plots {} -3d 1: the 3D view alone" [expr {
    !$rc && [llength $figs] == 1 && [file tail [lindex $figs 0]] eq "only_3d.png" && [file size [lindex $figs 0]] > 0}]
check "  -plots {} without -3d: said to be empty (not 'no clustering')" [string match "*-plots is empty*-3d 1*" [err {vmdance figures $dir -plots {}}]]
# (g8 F17: the lag as a person writes it: 010 drew lag 8, titled "lag 010")
check "  -options {tn_lag 010}, {tn_lag 0x8}: refused" [expr {
    [string match "*tn_lag cannot be \"010\"" [err {vmdance figures $dir -plots transitions -formats eps -options {tn_lag 010}}]] &&
    [string match "*tn_lag cannot be \"0x8\"" [err {vmdance figures $dir -plots transitions -formats eps -options {tn_lag 0x8}}]] &&
    [llength [vmdance figures $dir -plots transitions -formats eps -options {tn_lag 8}]] == 1}]
set ${S}(tn_lag) 3
${G}::apply_session_state {tn_lag 010}
check "  a session's window state with tn_lag 010: not taken" [expr {[set ${S}(tn_lag)] eq "3"}]
set ${S}(tn_lag) " 5"
${G}::_opt_entry tn_lag
check "  a lag typed with spaces: kept as checked (a session would refuse \" 5\")" [expr {[set ${S}(tn_lag)] eq "5"}]
set ${S}(tn_lag) 010
check "  a lag typed 010, not yet confirmed: the plot's is 1, not 8" [expr {[lindex [::VMDance::Plots::_transitions] 2] == 1}]
# (review of g8, R5: the lag box kept " 5" as typed until g8: a session
# saved then lost its lag on reopening, without a word)
set ${S}(tn_lag) 3
${G}::apply_session_state [list tn_lag " 5"]
check "  a session's window state with tn_lag \" 5\" (the lag box kept it so): lag 5" [expr {[set ${S}(tn_lag)] eq "5"}]
set ${S}(tn_lag) 1
# (review of g8, R3: -options kept the last of a setting given twice, the
# first never checked)
check "  -options {tn_lag BOGUS tn_lag 5}: the first checked, refused; {tn_lag 5 tn_lag 6}: a setting given twice" [expr {
    [err {vmdance figures $dir -prefix twice -plots transitions -formats eps -options {tn_lag BOGUS tn_lag 5}}] eq "vmdance figures: tn_lag cannot be \"BOGUS\"" &&
    [err {vmdance figures $dir -prefix twice -plots transitions -formats eps -options {tn_lag 5 tn_lag 6}}] eq "vmdance figures: -options: tn_lag is given twice" &&
    ![llength [glob -nocomplain -directory $dir twice_*]]}]
# (hardening 2, h4 N25: -renderer took any of VMD's renderers: an exporter
# (POV3, Tachyon, Wavefront …) failed once the plots were written,
# Wavefront with no message and its temporary left; an interactive one
# waited for a person)
set rd [file join $dir rend]
set bad {}
foreach r [concat {POV3 Tachyon Wavefront NoSuch} [lsearch -all -inline [render list] *Interactive]] {
    set e [err {vmdance figures $rd -plots populations -formats eps -width 400 -height 300 -3d 1 -renderer $r}]
    if {![string match "*-renderer: *$r*(use auto, *snapshot*" $e] || [file exists $rd]} { lappend bad $r }
}
check "figures -3d with a renderer that writes no image, or none of VMD's: refused before any figure is written, naming -renderer" [expr {
    ![llength $bad] && [string match "*POV3 writes a scene for another program*" [err {::VMDance::Figures::render_3d [file join $dir r.png] POV3}]]}]
set figs [vmdance figures $rd -plots populations -formats eps -width 400 -height 300 -3d 1 -renderer snapshot]
check "  snapshot: the 3D view written, no temporary left" [expr {
    [llength $figs] == 2 && [file isfile [file join $rd vmdance_3d.png]] &&
    ![llength [glob -nocomplain -directory $::VMDance::Backend::workdir *.ppm *.png]]}]
set bg [colorinfo category Display Background]
rename ::render ::_h4_render
proc ::render {args} {
    if {[lindex $args 0] eq "list"} { return [::_h4_render list] }
    set fh [open [lindex $args 1] w]; puts $fh P6; close $fh
    error ""
}
try {
    set e [err {::VMDance::Figures::render_3d [file join $rd failed_3d.png] snapshot}]
    # (the final review: the 3D view alone, -plots {}, into folders to make:
    # the render failing left them, empty; a failed plot takes them back)
    set e3 [err {vmdance figures [file join $rd new3d sub] -plots {} -3d 1 -renderer snapshot}]
} finally {
    rename ::render ""
    rename ::_h4_render ::render
}
check "  a render that fails with no message: said, its temporary removed, the background put back" [expr {
    [string match "*snapshot rendered no image*" $e] && ![file exists [file join $rd failed_3d.png]] &&
    ![llength [glob -nocomplain -directory $::VMDance::Backend::workdir *.ppm *.png]] && [colorinfo category Display Background] eq $bg}]
check "  figures -plots {} -3d 1 into folders it makes, the render failing: said, and the folders taken back" [expr {
    [string match "vmdance figures: 3D: *snapshot rendered no image*" $e3] && ![file exists [file join $rd new3d]] && [file isdirectory $rd]}]
# (h4 N15, its review: with LANG=C a TMPDIR whose name is not ASCII was
# passed over for /tmp, which then had to be writable: it is kept, and VMD
# renders into it by its name of the file, Backend::vmd_name; the name as
# Tcl reads it with LANG=C: its UTF-8 bytes, each a character)
set enc [encoding system]
set env0 {}
foreach v {TMPDIR TEMP TMP} { if {[info exists ::env($v)]} { dict set env0 $v $::env($v) } }
set wd0 $::VMDance::Backend::workdir
set wd1 ""
set tmp [file join $::out [encoding convertfrom iso8859-1 [encoding convertto utf-8 "gui_tmp_ü"]]]
encoding system iso8859-1
try {
    file delete -force $tmp
    file mkdir $tmp
    foreach v {TMPDIR TEMP TMP} { unset -nocomplain ::env($v) }
    set ::env(TMPDIR) $tmp
    set ::VMDance::Backend::workdir ""
    set e [err {::VMDance::Figures::render_3d [file join $rd lc_3d.png] snapshot}]
    set wd1 $::VMDance::Backend::workdir
    set left [glob -nocomplain -directory $wd1 *]
} finally {
    encoding system $enc
    foreach v {TMPDIR TEMP TMP} { unset -nocomplain ::env($v) }
    dict for {v x} $env0 { set ::env($v) $x }
    if {$wd1 ne "" && $wd1 ne $wd0} { file delete -force $wd1 }
    set ::VMDance::Backend::workdir $wd0
}
check "  with LANG=C, a TMPDIR whose name is not ASCII: kept, VMD rendering into it (snapshot), the PNG written ($e)" [expr {
    $e eq "" && [file isfile [file join $rd lc_3d.png]] && [file size [file join $rd lc_3d.png]] > 0 &&
    [string match $tmp/vmdance-* $wd1] && ![llength $left]}]
# (hardening 2, F34: Save picks as a DCD replaced the PDB of its name
# beside it, unasked: Tk asks of the file named only)
set pd [file join $::out gui_picks]
file delete -force $pd
file mkdir $pd
file copy [file join $::fixtures two_state.pdb] [file join $pd sys.pdb]
set keep [read_text [file join $pd sys.pdb]]
set ::next_file [file join $pd sys.dcd]
set n0 [llength $::messages]
set ::answer cancel
${G}::save_picks_dialog
set ::answer ""
check "Save picks as a DCD beside a PDB of its name: asked first; Cancel: nothing written" [expr {
    [llength $::messages] == $n0 + 1 && [lindex $::messages end] eq "Replace sys.pdb?" &&
    [read_text [file join $pd sys.pdb]] eq $keep && ![file exists [file join $pd sys.dcd]]}]
${G}::save_picks_dialog
set t [mol new [file join $pd sys.pdb] waitfor all]
mol addfile [file join $pd sys.dcd] waitfor all molid $t
set np [expr {[molinfo $t get numframes] - 1}]
mol delete $t
check "  OK: the DCD and the PDB of its atoms written ($np frames)" [expr {$np == [llength [dict get $::VMDance::Results::picks vmdframes]]}]
set ::next_file [file join $pd new.dcd]
set n0 [llength $::messages]
${G}::save_picks_dialog
check "  a DCD with no PDB of its name: nothing asked" [expr {[llength $::messages] == $n0 && [file exists [file join $pd new.pdb]]}]
# (the review of hardening 2's files: a space pasted after the folder made
# a folder of its own; the clusters an earlier export of trajectories left
# that this one does not write were neither said nor deleted; figures that
# failed left the folder they made)
set td [file join $::out gui_trim]
file delete -force $td "$td "
file mkdir $td
# (the dialog's ticks and format are the session's: given back after)
set x0 [array get ${G}::X]
set of0 [set ${S}(out_format)]
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
${G}::export_dialog
update
foreach {it lab} [set ${G}::export_items] { set ${G}::X($it) [expr {$it in {labels trajectories}}] }
set ${S}(out_dir) "$td "
set ${S}(out_prefix) t
set ${S}(out_format) dcd
set n0 [llength $::messages]
${G}::_export_go
check "Export with a space after the folder: written in it, no folder of that name made" [expr {
    [llength $::messages] == $n0 && [file isfile [file join $td t_labels.csv]] && [file isfile [file join $td t_cluster_2.dcd]] && ![file exists "$td "]}]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
${G}::export_dialog
update
foreach {it lab} [set ${G}::export_items] { set ${G}::X($it) [expr {$it in {labels trajectories}}] }
set ::answer cancel
${G}::_export_go
set ::answer ""
check "  at k 2 over k 3's: asked to replace the files and delete the third cluster's; Cancel: all kept ([lindex $::messages end])" [expr {
    [string match "Replace * files, and delete 2 of an earlier export?" [lindex $::messages end]] &&
    [file exists [file join $td t_cluster_2.dcd]] && [file exists [file join $td t_cluster_2.pdb]]}]
${G}::_export_go
check "  OK: written, and the third cluster's deleted" [expr {![winfo exists $w.export] &&
    ![file exists [file join $td t_cluster_2.dcd]] && ![file exists [file join $td t_cluster_2.pdb]] && [file exists [file join $td t_cluster_1.dcd]]}]
array unset ${G}::X
array set ${G}::X $x0
set ${S}(out_format) $of0
set ${S}(out_prefix) vmdance
set ${S}(out_dir) $dir
set fig0 [lmap fm {pdf png eps} {set ${S}(fig_$fm)}]
set ${S}(fig_dir) "$td "
${G}::figure_dialog
update
foreach k [dict keys $::VMDance::GUI::tabs] { set ${G}::F($k) [expr {$k eq "populations"}] }
foreach fm {pdf png eps} v {0 0 1} { set ${S}(fig_$fm) $v }
${G}::_figures_go
check "Figures with a space after the folder: written in it, no folder of that name made" [expr {
    ![winfo exists $w.figures] && [file isfile [file join $td vmdance_populations.eps]] && ![file exists "$td "]}]
foreach fm {pdf png eps} v $fig0 { set ${S}(fig_$fm) $v }
set ${S}(fig_dir) $dir
set gs0 $::VMDance::Figures::gs
set ::VMDance::Figures::gs [lindex [auto_execok false] 0]
set e [err {vmdance figures [file join $td nogs sub] -plots populations -formats pdf -width 400 -height 300}]
set ::VMDance::Figures::gs $gs0
check "  figures that fail (Ghostscript failing) take back the folder they made, and its parent ($e)" [expr {
    [string match "*Ghostscript failed*" $e] && ![file exists [file join $td nogs]]}]

# --- settings, themes, sizes -------------------------------------------------------------------
${G}::settings_dialog
update
set ${G}::E(unlock) 1
${G}::_settings_apply
update
check "Settings: the metrics unlocked" [expr {[set ${S}(unlock_metrics)] && [winfo manager $pb.kmeans.met.c] ne "" && [winfo manager $pb.kmeans.met.l] eq ""}]
set ${S}(unlock_metrics) 0
${G}::_metric_lock
set mode0 $::VMDance::Backend::mode
${G}::settings_dialog
update
set ${G}::E(mode) library
${G}::_settings_backend
${G}::_settings_cancel
check "  a backend tried, then Cancel: the one in use kept" [expr {$::VMDance::Backend::mode eq $mode0 && ![winfo exists $w.settings]}]
# (a backend tried is not applied before OK: a job started meanwhile runs
# on the one in use, and Cancel during it has nothing to put back; the
# library writes the coordinates' file too, as the Use tip now says)
set copy [file join $::out gui_copy_cli]
file copy -force $::fake $copy
array set $S [list molid $m sel all framemode all fit 0 algorithm kmeans k_kmeans 2 p_kmeans_kinit KmeansPP]
${G}::_frames_changed
${G}::_fit_changed
${G}::_algorithm_changed
set before [::VMDance::Backend::settings]
${G}::settings_dialog
update
set tip $::VMDance::Tip::text($w.settings.f.bk.mode)
check "  the Use tip: the coordinates are written with the library too (it said no files)" [expr {![string match "*no files*" $tip] && [string match "*private folder*" $tip]}]
array set ${G}::E [list mode cli cli $copy]
${G}::_settings_backend
check "  a program tried: not applied, the dialog says it is for OK" [expr {[::VMDance::Backend::settings] eq $before &&
    [string match "On OK: the program $copy*" [$w.settings.f.bk.st cget -text]]}]
fake_env MDANCE_FAKE_SLEEP 1.5
set nruns [llength [${R}::run_list]]
${G}::cluster
update
set busy [::VMDance::Job::busy]
${G}::_settings_cancel
wait_idle
fake_env
check "  a clustering started meanwhile runs on the backend in use; Cancel during it keeps that one" [expr {$busy && ![winfo exists $w.settings] &&
    [::VMDance::Backend::settings] eq $before && [llength [${R}::run_list]] == $nruns + 1 && [${R}::meta backend] eq [list cli $::fake]}]
set bm [list [set ${S}(backend_mode)] [set ${S}(backend_cli)] [set ${S}(backend_lib)]]
${G}::settings_dialog
update
array set ${G}::E [list mode cli cli $copy]
${G}::_settings_backend
fake_env MDANCE_FAKE_SLEEP 1.5
${G}::cluster
update
${G}::_settings_apply
set during [expr {[winfo exists $w.settings] && [::VMDance::Backend::settings] eq $before && [string match "*a job is running*" [lindex $::messages end]]}]
wait_idle
fake_env
${G}::_settings_apply
check "  OK while a job runs: not applied, said, the dialog kept; after it: applied, and kept for the preferences" [expr {$during && ![winfo exists $w.settings] &&
    [lindex [dict get [vmdance backend] using] 1] eq $copy && [set ${S}(backend_cli)] eq $copy}]
use_fake
lassign $bm ${S}(backend_mode) ${S}(backend_cli) ${S}(backend_lib)
${G}::backend_changed
# (a program that did not answer the probe within 3 s: Settings says so)
set fakepath [lindex [::VMDance::Backend::current] 1]
::VMDance::Backend::algorithms
set ::VMDance::Backend::notes($fakepath) "\"$fakepath\" did not answer within 3 s when run without arguments: its algorithms are not known, so all are offered"
${G}::settings_dialog
update
check "  a program slow to start: Settings says its algorithms are not known" [string match "*Algorithms: *\n*did not answer within 3 s*all are offered." [$w.settings.f.bk.st cget -text]]
${G}::_settings_cancel
unset -nocomplain ::VMDance::Backend::notes($fakepath)
${G}::settings_dialog
update
set bm [set ${S}(backend_mode)]
array set ${G}::E {font abc mode library unlock 1}
${G}::_settings_apply
check "  a text size that is not one: nothing applied" [expr {[set ${S}(backend_mode)] eq $bm && ![set ${S}(unlock_metrics)] &&
    $::VMDance::Backend::mode eq $mode0 && [winfo exists $w.settings] && [string match "*text size*" [lindex $::messages end]]}]
${G}::_settings_cancel
foreach th [::VMDance::Theme::available] {
    ${G}::set_appearance 12 compact $th
    update
    if {![every_plot_ok]} { puts "  plots failed in theme $th" }
}
check "every theme ([join [::VMDance::Theme::available] {, }])" [expr {![llength $::bgerrors]}]
${G}::set_appearance 12 compact auto
update
set lw12 [winfo reqwidth $w.pw.left]
set eh12 [winfo reqheight [set ${G}::molcombo]]
${G}::set_appearance 24 compact flat
update
lassign [${G}::needed_size] nw nh
check "text size 24: the window is as large as its widgets need" [expr {[winfo width $w] >= $nw - 2 || [winfo width $w] >= [winfo screenwidth $w] - 60}]
check "  the fields as tall as their text" [expr {[winfo reqheight [set ${G}::molcombo]] >= [font metrics MdvUI -linespace] + 2}]
${G}::set_appearance 12 compact auto
update
check "  back at 12: the left panel as narrow as before ($lw12, [winfo reqwidth $w.pw.left])" [expr {abs([winfo reqwidth $w.pw.left] - $lw12) <= 2 &&
    abs([winfo reqheight [set ${G}::molcombo]] - $eh12) <= 1}]
# a short window: the left pages scroll, and the mouse wheel scrolls them
set g0 [wm geometry $w]
lassign [wm minsize $w] mw0 mh0
wm minsize $w 200 200
wm geometry $w 980x520
${G}::show_pane tools
update
${G}::_pages_fit
update
set PT [set ${G}::page(tools)]
set cv [winfo parent $PT]
check "a short window: the Tools page scrolls" [expr {[winfo manager [winfo parent $cv].sb] ne "" && [winfo height $cv] < [winfo reqheight $PT]}]
${G}::_page_wheel $PT.pk.note -1
update
check "  the wheel scrolls it" [expr {[lindex [$cv yview] 0] > 0}]
$cv yview moveto 1
update
set bs $PT.pk.bt.save
check "  its last buttons can be reached" [expr {[winfo rooty $bs] + [winfo height $bs] <= [winfo rooty $cv] + [winfo height $cv] + 1}]
wm minsize $w $mw0 $mh0
wm geometry $w $g0
${G}::apply_appearance
update
check "  a tall one again: no scroll bar" [expr {[winfo manager [winfo parent $cv].sb] eq ""}]
set ${S}(readout) [string repeat "a long readout " 80]
update
check "the readout is cut to its line, ending in …" [string match "*…" [set ${S}(readout_shown)]]
set ${S}(readout) ""

foreach key [dict keys $::VMDance::GUI::tabs] { $w.pw.right.nb.$key.c delete all }
set t [lindex [time {for {set i 0} {$i < 300} {incr i} { font measure MdvSmall $i }}] 0]
check "the plot fonts stay open with every plot cleared (300 labels measured in [expr {$t / 1000}] ms)" [expr {$t < 150000}]
${G}::redraw

# --- many clusters (g6) -------------------------------------------------------------------
# (F04: a message the window's 250 ms throttle held back is shown when they
# are up: the backend's last line stayed up the minutes the measures took.
# A new step is shown at once since h3: the throttle holds back the counts
# of a step, and the last one held is shown then)
set ${G}::last_progress 0
${G}::_progress 0.40 "measuring the clusters (frame 1 of 99)"
${G}::_progress 0.97 "measuring the clusters (frame 98 of 99)"
set held [set ${S}(status)]
after 400 {set ::g6_wait 1}; vwait ::g6_wait
check "F04: the progress message held back by the throttle is shown when it is up" [expr {
    $held eq "measuring the clusters (frame 1 of 99)…" && [set ${S}(status)] eq "measuring the clusters (frame 98 of 99)…"}]
set ${S}(progress) 0
${G}::status ""
# (F10: above Measure::maxk the distances and the tree of the mean
# structures are not made, and the transitions are k² rows: the Export
# dialog leaves them unticked, the two not made greyed, saying why; the
# plots say so)
proc g6_find {top pattern} {
    foreach c [winfo children $top] {
        if {[string match $pattern $c]} { return $c }
        set f [g6_find $c $pattern]
        if {$f ne ""} { return $f }
    }
    return ""
}
set ::VMDance::Measure::maxk 1
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set big $::VMDance::Results::current
foreach it {transitions distances tree} { set ${G}::X($it) 1 }
${G}::export_dialog
update
set d $w.export
check "F10: Export with more clusters than maxk: the transitions unticked, the distances and the tree greyed" [expr {
    ![set ${G}::X(transitions)] && ![set ${G}::X(distances)] && ![set ${G}::X(tree)] &&
    [[g6_find $d *.ctransitions] instate !disabled] && [[g6_find $d *.cdistances] instate disabled] && [[g6_find $d *.ctree] instate disabled] &&
    [string match "Not made: the distances between the clusters are measured for 1 clusters or fewer*" [set ::VMDance::Tip::text([g6_find $d *.cdistances])]]}]
set dir [file join $::out gui_export_big]
file delete -force $dir
set ${S}(out_dir) $dir
${G}::_export_go
check "  exported without them" [expr {![winfo exists $d] && [llength [glob -nocomplain -directory $dir *]] >= 6 &&
    ![llength [glob -nocomplain -directory $dir *_transitions.csv *_distances.csv *_tree.csv]]}]
check "  the Distances and Tree plots say they are not made" [expr {[plot_ok distances] && [plot_ok tree] &&
    [llength [lsearch -all [lmap i [$w.pw.right.nb.distances.c find all] {expr {[$w.pw.right.nb.distances.c type $i] eq "text" ? [$w.pw.right.nb.distances.c itemcget $i -text] : [continue]}}] "*measured for 1 clusters or fewer*"]] &&
    [llength [lsearch -all [lmap i [$w.pw.right.nb.tree.c find all] {expr {[$w.pw.right.nb.tree.c type $i] eq "text" ? [$w.pw.right.nb.tree.c itemcget $i -text] : [continue]}}] "*made for 1 clusters or fewer*"]]}]
# (the review: File ▸ Quick export ▸ This plot's data said "This plot has no
# data yet." there, and the plots did not say what to change)
set said {}
foreach key {distances tree} {
    ::VMDance::GUI::show_tab $key
    update
    ${G}::status ""
    ${G}::save_plot_data
    lappend said [set ${S}(status)]
}
set texts [lmap key {distances tree} {join [lmap i [$w.pw.right.nb.$key.c find all] {expr {[$w.pw.right.nb.$key.c type $i] eq "text" ? [$w.pw.right.nb.$key.c itemcget $i -text] : [continue]}}]}]
check "  review: This plot's data on those tabs says why, and what to change, and so do the plots ([join $said { | }])" [expr {
    [string match "Not saved: the distances between the clusters are measured for 1 clusters or fewer, and this clustering has 2: cluster into fewer*" [lindex $said 0]] &&
    [string match "Not saved: the tree of the clusters' mean structures is made for 1 clusters or fewer, and this clustering has 2: cluster into fewer*" [lindex $said 1]] &&
    [string match "*cluster into fewer (a smaller k, a larger eQUAL radius).*" [lindex $texts 0]] &&
    [string match "*cluster into fewer (a smaller k, a larger eQUAL radius).*" [lindex $texts 1]]}]
${G}::status ""
vmdance run delete $big
set ::VMDance::Measure::maxk 300
# (the review: the dialog's unticking was kept as the user's choice: every
# later clustering, of any size, offered the three unticked; a tick taken
# off by hand stays off)
update
${G}::export_dialog
update
set back [lmap it {transitions distances tree} {set ${G}::X($it)}]
destroy $w.export
set ${G}::X(tree) 0
set ::VMDance::Measure::maxk 1
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set big $::VMDance::Results::current
update
${G}::export_dialog
update
set off [lmap it {transitions distances tree} {set ${G}::X($it)}]
destroy $w.export
vmdance run delete $big
set ::VMDance::Measure::maxk 300
update
${G}::export_dialog
update
set back2 [lmap it {transitions distances tree} {set ${G}::X($it)}]
destroy $w.export
set ${G}::X(tree) 1
check "  review: then a clustering of maxk or fewer: the three ticked again ($back), and after a tick taken off by hand ($off, then $back2)" [expr {
    $back eq {1 1 1} && $off eq {0 0 0} && $back2 eq {1 1 0}}]
# (F57: the Transitions plot keeps the lag it shows, not one matrix per lag)
::VMDance::GUI::show_tab transitions
foreach l {1 2 3 4 5} {
    set ${S}(tn_lag) $l
    ${G}::redraw
    update
}
${G}::_hover transitions $w.pw.right.nb.transitions.c {*}[lrange [set ::VMDance::Plots::H($w.pw.right.nb.transitions.c,mx)] 1 2]
check "F57: the lag shown changed five times: one plot matrix kept ([llength [array names ${R}::memo plot_transitions*]]), the readout of lag 5" [expr {
    [llength [array names ${R}::memo plot_transitions*]] == 1 && [string match "*, lag 5" [set ${S}(readout)]]}]
set ${S}(tn_lag) 1
${G}::redraw
# (F65: the silhouette of many clusters: gaps of a quarter of the axis at
# most, the clusters' numbers where they fit; a few clusters as before)
vmdance -mol $m -sel all -k 12 -kinit KmeansPP -quiet 1
set c [::VMDance::Figures::render_plot silhouette 400 140 0]
lassign [set ::VMDance::Plots::H($c,sil)] ytot hit
set rows 0; foreach h $hit { set rows [expr {$rows + [lindex $h 2] - [lindex $h 1]}] }
set ys [lsort -real [lmap i [$c find withtag label] {expr {[lindex [$c bbox $i] 0] < [lindex [::VMDance::Plot::area $c] 0] ? [lindex [$c bbox $i] 1] : [continue]}}]]
set over 0
foreach a [lrange $ys 0 end-1] b [lrange $ys 1 end] { if {$b - $a < [::VMDance::Plot::lh] - 1} { incr over } }
# (the pointer, on a taller one: every pixel row)
set c [::VMDance::Figures::render_plot silhouette 400 700 0]
lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
set found 0; set py 0
for {set y [expr {int(ceil($y0))}]} {$y < $y1} {incr y} {
    incr py
    if {[llength [::VMDance::Plots::_sil_at $c [expr {($x0 + $x1) / 2}] $y]]} { incr found }
}
check "F65: the silhouette of [llength $hit] clusters: the frames [format %.0f [expr {100.0 * $rows / $ytot}]]% of the axis, [llength $ys] numbers written, $over over another, a frame under [expr {100 * $found / $py}]% of the rows" [expr {
    [llength $hit] >= 10 && $rows >= 0.74 * $ytot && [llength $ys] >= 3 && !$over && $found >= 0.7 * $py}]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set c [::VMDance::Figures::render_plot silhouette 400 200 0]
check "  two clusters: the gap as before (2 rows, a 60th of the frames at least)" [expr {[lindex [set ::VMDance::Plots::H($c,sil)] 0] == 24 + 2}]
destroy $c
# (F29: thin bars name the bar drawn under the pointer: the first whose
# extent widened by 2 px held it named the bar on its left)
canvas .g6bars -width 522 -height 400
foreach n {20 120 400} {
    set items {}
    for {set i 0} {$i < $n} {incr i} { lappend items [list $i [expr {1 + $i % 5}]] }
    ::VMDance::Plots::_bars .g6bars $items Frames
    lassign [::VMDance::Plot::area .g6bars] x0 y0 x1 y1
    set bad 0; set on 0
    for {set x [expr {int(ceil($x0))}]} {$x <= $x1} {incr x} {
        # (Tk fills the pixels whose centre is in a rectangle; the later is on top)
        set top ""
        foreach b [set ::VMDance::Plots::H(.g6bars,bars)] { lassign $b xa xb cl; if {$x + 0.5 > $xa && $x + 0.5 <= $xb} { set top $cl } }
        if {$top eq ""} continue
        incr on
        if {[::VMDance::Plots::_bar_at .g6bars $x [expr {$y1 - 2}]] ne $top} { incr bad }
    }
    check "F29: $n bars: every pixel on a bar names the bar drawn there ($bad of $on wrong)" [expr {$on > 0 && !$bad}]
    .g6bars delete all
}
destroy .g6bars
array unset ::VMDance::Plots::H .g6bars,*
array unset ::VMDance::Plot::G .g6bars,*
# (F66: leaving the 3D fields unchanged makes nothing again: every
# representation was made again, seconds with a thousand)
set ::g6_draws 0
proc g6_draw_counted {args} { incr ::g6_draws }
trace add execution ::VMDance::Viz::draw enter g6_draw_counted
set ${S}(v3d_colour) 1
${G}::draw_changed
set ::g6_draws 0
event generate $P3.ov.sel <FocusOut>
set n0 $::g6_draws
set ${S}(v3d_sel) "name CA"
event generate $P3.ov.sel <FocusOut>
set n1 $::g6_draws
set ${S}(v3d_sel) ""
event generate $P3.ov.sel <FocusOut>
set ${S}(v3d_mode) frames
set ${S}(v3d_frames) "0-2"
event generate $P3.ov.fr.e <FocusOut>
set n2 $::g6_draws
event generate $P3.ov.fr.e <FocusOut>
set n3 $::g6_draws
check "F66: the 3D fields left unchanged draw nothing again; changed, they draw ($n0 $n1 $n2 $n3)" [expr {
    $n0 == 0 && $n1 == 1 && [dict get [::VMDance::Viz::get] frames] eq "0-2" && $n2 == 3 && $n3 == 3}]
trace remove execution ::VMDance::Viz::draw enter g6_draw_counted
set ${S}(v3d_mode) top
set ${S}(v3d_colour) 0
${G}::draw_changed

# --- a session's drawing with the window open, and a clustering's notes (review of g8, R2) ---------
# (a session whose -sel or -frames was refused lost its whole drawing, the
# tab showing the session's values, not drawn)
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance draw -colour 1 -reps 0 -overlay 0 -sel "" -frames ""
${G}::apply_session_state {v3d_sel {nmae CA} v3d_reps 1 v3d_colour 0}
set v [::VMDance::Viz::get]
check "a session's 3D drawing, the window open: a -sel refused left out alone, said; the rest drawn, the tab as drawn" [expr {
    [dict get $v reps] == 1 && [dict get $v colour] == 0 && [dict get $v sel] eq "" &&
    [set ${S}(v3d_reps)] == 1 && [set ${S}(v3d_colour)] == 0 && [set ${S}(v3d_sel)] eq "" &&
    [string match "3D: the session's drawing: -sel: invalid atom selection \"nmae CA\"*: left out." [set ${S}(status)]]}]
${G}::apply_session_state {v3d_overlay 1 v3d_mode frames v3d_frames 0-50 v3d_reps 0}
set v [::VMDance::Viz::get]
check "  -frames past the molecule's last: left out alone" [expr {
    [dict get $v overlay] == 1 && [dict get $v reps] == 0 && [dict get $v frames] eq "" && [set ${S}(v3d_mode)] eq "top" &&
    [string match "3D: the session's drawing: frames: frame 50 is past the last frame*: left out." [set ${S}(status)]]}]
vmdance draw -overlay 0 -reps 0 -colour 0
# (what a clustering then draws otherwise than asked was said on the
# console only: the window's status stayed empty)
vmdance run clear
vmdance draw -overlay 1 -frames 0-50
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
update
check "a clustering drawn otherwise than asked (-frames given before it): said in the window" [string match \
    "3D: *-frames: 27 frames are past the last of molecule $m (23): not drawn." [set ${S}(status)]]
vmdance draw -overlay 0 -frames ""

# --- the window (hardening 2, g9) ---------------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
array set $S [list molid $m sel all framemode all fit 0 step 1 algorithm kmeans k_kmeans 2 p_kmeans_kinit KmeansPP]
${G}::_frames_changed
${G}::_fit_changed
${G}::_algorithm_changed
# (F28: the Sweep's and the Elbow's k fields made every value of k before
# counting them: each key typed in Sweep's "to" field, at 30000000, froze
# VMD 4 s and took 2 GB; the command's rule now, which counts first)
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a eq "kmeans"}] }
foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k eq "KmeansPP"}] }
set ${S}(gr_from) 2
set ${S}(gr_to) 3000000
# (F28, the review: the time too, or a window that made the values before
# asking the command would pass on its message: 351 ms, 3M values)
set t [lindex [time {${G}::_grid_count}] 0]
check "F28: Sweep, k to 3000000: refused as the command refuses it, counted before the values are made ([expr {$t / 1000}] ms)" [expr {
    [set ${S}(gr_count)] eq "vmdance sweep: -from -to -by give 2999999 values of k; at most 1000" && $t < 100000}]
set ${S}(gr_to) " 3 "
${G}::_grid_count
check "  a value with spaces around it: taken" [expr {[set ${S}(gr_count)] eq "2 configurations"}]
set ${S}(gr_to) 12
${G}::_grid_count
set ${S}(eb_to) 3000000
set n0 [llength $::messages]
set t [lindex [time {${G}::elbow}] 0]
check "  Elbow, k to 3000000: refused the same way, nothing started ([expr {$t / 1000}] ms)" [expr {![set ${S}(busy)] && [llength $::messages] == $n0 + 1 &&
    [lindex $::messages end] eq "No elbow scan:\nvmdance elbow: -from -to -by give 2999999 values of k; at most 200" && $t < 100000}]
# (F28, the review: a k of ten digits was refused as "a whole number, 1
# or more", at every key typed in Sweep's fields)
set ${S}(gr_to) 1000000000
${G}::_grid_count
check "  k to of ten digits: the range said" [expr {[set ${S}(gr_count)] eq "vmdance sweep: -to must be a whole number from 1 to 999999999 (got \"1000000000\")"}]
set ${S}(gr_to) 12
${G}::_grid_count
set ${S}(eb_to) 5
# (F31: "frames" chosen for the overlay before they were typed went back to
# the selected clusters', and the frames typed after it were never drawn)
vmdance select 0
${G}::show_pane v3d
update
set O [set ${G}::page(v3d)].ov
set ${S}(v3d_frames) ""
set ${S}(v3d_mode) top
$O.ov invoke
$O.fr.r invoke
set chosen [list [set ${S}(v3d_mode)] [set ${S}(status)]]
$O.fr.e insert end 0-3,5
uplevel #0 [bind $O.fr.e <Return>]
check "F31: the overlay's 'frames' chosen with the field empty: kept, the line asks for them; typed, then Return: drawn" [expr {
    [lindex $chosen 0] eq "frames" && [string match "*type the overlay's frames*" [lindex $chosen 1]] &&
    [dict get [::VMDance::Viz::get] frames] eq "0-3,5" && [set ${S}(v3d_mode)] eq "frames"}]
$O.fr.e delete 0 end
uplevel #0 [bind $O.fr.e <Return>]
${G}::_busy 1
${G}::_busy 0
check "  the field emptied, then a job's end: still 'frames'" [expr {[set ${S}(v3d_mode)] eq "frames"}]
$O.top.r invoke
$O.fr.e insert end 1-2
uplevel #0 [bind $O.fr.e <Return>]
check "  frames typed with the selected clusters' chosen: 'frames' chosen, and drawn" [expr {
    [set ${S}(v3d_mode)] eq "frames" && [dict get [::VMDance::Viz::get] frames] eq "1-2" && [$O.fr.e cget -validate] eq "key"}]
vmdance draw -frames ""
check "  cleared by the command: the selected clusters' again" [expr {[set ${S}(v3d_mode)] eq "top"}]
# (F31, the review: "frames" chosen with none typed left the selected
# clusters' overlay drawn while the radio said "frames"; frames typed and
# not yet sent went back to "the selected clusters'" at any change of the
# drawing or a job's end, and Return then drew the selected clusters')
proc g9_overlays {} { llength [lsearch -all -index 2 $::VMDance::Viz::owned overlay] }
set n0 [g9_overlays]
$O.fr.e delete 0 end
$O.fr.r invoke
check "  'frames' chosen with none typed: no overlay drawn (the selected clusters' were: $n0), the box ticked, the line asks for them" [expr {
    $n0 > 0 && [g9_overlays] == 0 && [set ${S}(v3d_overlay)] == 1 && [set ${S}(v3d_mode)] eq "frames" &&
    [dict get [::VMDance::Viz::get] overlay] == 0 && [string match "*type the overlay's frames*" [set ${S}(status)]]}]
vmdance draw -overlay 1
check "  then the command's -overlay 1: the selected clusters' drawn, and shown" [expr {
    [g9_overlays] > 0 && [set ${S}(v3d_overlay)] == 1 && [set ${S}(v3d_mode)] eq "top"}]
$O.fr.e insert end 2-4
vmdance draw -colour 1
set a [list [set ${S}(v3d_mode)] [set ${S}(v3d_frames)]]
${G}::cluster
wait_idle
set b [list [set ${S}(v3d_mode)] [set ${S}(v3d_frames)]]
uplevel #0 [bind $O.fr.e <Return>]
check "  frames typed, not sent: still chosen after a change of the drawing ($a) and a job's end ($b); Return draws them" [expr {
    $a eq {frames 2-4} && $b eq {frames 2-4} && [dict get [::VMDance::Viz::get] frames] eq "2-4" && [set ${S}(v3d_mode)] eq "frames"}]
vmdance draw -colour 0 -frames ""
${G}::apply_session_state {v3d_overlay yes}
check "  a session's overlay 'yes': drawn, the box ticked" [expr {[set ${S}(v3d_overlay)] eq "1" && [dict get [::VMDance::Viz::get] overlay] == 1}]
vmdance draw -overlay 0
# (F64: in the timeline's distances, the left half of each dot named, and a
# click there went to, the clustered frame before it)
set ${S}(tl_view) msd
${G}::show_tab timeline
update
${G}::redraw
update
set c $w.pw.right.nb.timeline.c
set fr [${R}::frames]
set fm [${R}::measure frame_msd]
set bad {}
for {set i 1} {$i < [llength $fr]} {incr i} {
    if {[lindex $fm $i] eq ""} continue
    ${G}::_hover timeline $c [expr {int(floor([::VMDance::Plot::X $c [lindex $fr $i]])) - 1}] [expr {int([::VMDance::Plot::Y $c [lindex $fm $i]])}]
    if {![string match "frame [lindex $fr $i]:*" [set ${S}(readout)]]} { lappend bad [lindex $fr $i] }
}
animate goto 0
${G}::_click timeline $c [expr {int(floor([::VMDance::Plot::X $c [lindex $fr 12]])) - 1}] [expr {int([::VMDance::Plot::Y $c [lindex $fm 12]])}] 0
check "F64: the timeline's distances: 1 px left of a dot names its frame (others: $bad), a click there goes to it" [expr {
    ![llength $bad] && [molinfo $m get frame] == [lindex $fr 12]}]
set ${S}(tl_view) lanes
# (F42: with VMD's colours, the plots, the table and the key kept VMD's
# colour of before Graphics ▸ Colors changed it, for the whole session; so
# did the figures)
set old [colorinfo rgb 0]
vmdance select clear
set ${S}(plot_ccol) vmd
${G}::_rows_changed
update
color change rgb 0 0.2 0.4 0.6
plot_ok populations
set pc $w.pw.right.nb.populations.c
proc g9_colours {pc} {
    list [$pc itemcget [lindex [$pc find withtag bar] 0] -fill] [[set ::VMDance::GUI::tree] tag configure c0 -background] \
        [[set ::VMDance::GUI::keybox].c0 cget -background]
}
set seen [g9_colours $pc]
check "F42: VMD's colours, one changed: the plot, the table and the key in it ($seen)" [expr {
    $seen eq [list #336699 [::VMDance::Cmap::tint #336699 0.82] #336699]}]
color change rgb 0 0.6 0.4 0.2
event generate $w <FocusIn>
update
set seen [g9_colours $pc]
check "  changed again: the window back in focus follows ($seen)" [expr {$seen eq [list #996633 [::VMDance::Cmap::tint #996633 0.82] #996633]}]
set figs [vmdance figures $::out -prefix g9vmd -plots populations -formats eps -width 400 -height 300 -options {plot_ccol vmd}]
check "  and a figure" [string match "*0.600 0.400 0.200 setrgbcolor*" [read_text [lindex $figs 0]]]
color change rgb 0 {*}$old
set ${S}(plot_ccol) muted
${G}::_rows_changed
# (F41: a clustering from the window drew its plot three times: the idle
# draw its notice asked for, _job_done's own, and the panels' 60 ms after)
${G}::show_tab timeline
fake_env MDANCE_FAKE_SLEEP 0.3
${G}::cluster
wait_idle
after 300
update
set d0 [set ${G}::redraws]
${G}::cluster
wait_idle
after 300
update
fake_env
check "F41: a clustering from the window draws its plot once ([expr {[set ${G}::redraws] - $d0}])" [expr {[set ${G}::redraws] - $d0 == 1}]
# (F30: what was changed in Setup while a clustering ran was replaced by its
# settings as it ended, unsaid, and the next Cluster ran them again)
fake_env MDANCE_FAKE_SLEEP 1
${G}::cluster
update
array set $S {sel "index 0 to 5" k_kmeans 3 p_kmeans_kinit Random}
wait_idle
fake_env
set id [lindex [${R}::run_list] end 0]
check "F30: Setup changed while a clustering ran: kept, and said" [expr {[set ${S}(sel)] eq "index 0 to 5" && [set ${S}(k_kmeans)] == 3 &&
    [set ${S}(p_kmeans_kinit)] eq "Random" && [dict get [${R}::request] sel] eq "all" &&
    [string match "* — in * s. Setup keeps what was changed while it ran." [set ${S}(status)]]}]
${G}::cluster
wait_idle
check "  the next Cluster sends it; Setup left alone meanwhile: no note" [expr {[dict get [${R}::request] sel] eq "index 0 to 5" &&
    [dict get [${R}::request] k] == 3 && [dict get [${R}::request] params kinit] eq "Random" && [string match "* — in * s." [set ${S}(status)]]}]
${G}::switch_run $id
check "  a run chosen: Setup shows its settings" [expr {[set ${S}(sel)] eq "all" && [set ${S}(k_kmeans)] == 2 && [set ${S}(p_kmeans_kinit)] eq "KmeansPP"}]
# (F30, the review: a clustering of the command's still replaced what was
# changed in Setup while it ran, unsaid, though the docs say it is kept)
fake_env MDANCE_FAKE_SLEEP 1
after 300 [list array set $S {sel "index 0 to 5" k_kmeans 3 p_kmeans_kinit Random}]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
update
set kept [list [set ${S}(sel)] [set ${S}(k_kmeans)] [set ${S}(p_kmeans_kinit)] [set ${S}(status)]]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
update
fake_env
check "  changed while a clustering of the command's ran: kept, and said ($kept); left alone during the next: it follows it" [expr {
    [lrange $kept 0 2] eq {{index 0 to 5} 3 Random} && [lindex $kept 3] eq "Setup keeps what was changed while the command's job ran." &&
    [set ${S}(sel)] eq "all" && [set ${S}(k_kmeans)] == 2 && [set ${S}(p_kmeans_kinit)] eq "KmeansPP" &&
    ![string match "Setup keeps*" [set ${S}(status)]] && [set ${G}::setup0] eq ""}]
# (F68: another algorithm chosen while a job ran turned the toolbar's Elbow
# on again, and a click on it did nothing)
set ac [set ${G}::page(setup)].alg.c
fake_env MDANCE_FAKE_SLEEP 1
${G}::cluster
update
$ac set [::VMDance::Algo::label helm]
event generate $ac <<ComboboxSelected>>
set during [$w.tb.elbow instate disabled]
$ac set [::VMDance::Algo::label kmeans]
event generate $ac <<ComboboxSelected>>
wait_idle
fake_env
check "F68: an algorithm chosen while a job runs: the toolbar's Elbow stays off, and is on after it" [expr {$during && [$w.tb.elbow instate !disabled]}]
# (F67: Export and Create in their dialogs, left open as a job started, did
# nothing and said nothing)
set dir [file join $::out gui_g9]
file delete -force $dir
file mkdir $dir
array set $S [list out_dir $dir fig_dir $dir]
${G}::export_dialog
${G}::figure_dialog
update
fake_env MDANCE_FAKE_SLEEP 1
${G}::cluster
update
set during [list [$w.export.f.b.ok instate disabled] [$w.figures.f.b.ok instate disabled] [$w.export cget -cursor] [$w.figures cget -cursor]]
set n0 [llength $::messages]
${G}::_export_go
${G}::_figures_go
set said [lrange $::messages $n0 end]
wait_idle
fake_env
check "F67: a job running: the open dialogs' Export and Create off ($during); pressed anyway: said why, nothing written" [expr {
    $during eq {1 1 watch watch} && [llength $said] == 2 && [string match "A job is running: export *" [lindex $said 0]] &&
    [string match "A job is running: create the figures *" [lindex $said 1]] && ![llength [glob -nocomplain -directory $dir *]]}]
check "  on again after it" [expr {[$w.export.f.b.ok instate !disabled] && [$w.figures.f.b.ok instate !disabled] && [$w.export cget -cursor] eq ""}]
destroy $w.export $w.figures
# (F69: the window destroyed during its own job and opened again while it
# ran took the job for the command's, and its last line was blanked)
fake_env MDANCE_FAKE_SLEEP 2
${G}::cluster
update
destroy $w
update
set w [vmdance]
update
set during [list [set ${S}(busy)] [set ${G}::console_job]]
wait_idle
check "F69: the window opened again during its own job: busy, not the command's ($during); its last line kept" [expr {
    $during eq {1 0} && [string match "2 clusters* — in * s." [set ${S}(status)]]}]
${G}::cluster
update
destroy $w
update
set w [vmdance]
update
${G}::cancel
wait_idle
fake_env
check "  cancelled from it: said" [string match "Cancelled*" [set ${S}(status)]]
destroy $w
update
fake_env MDANCE_FAKE_SLEEP 1
set ::during {}
after 300 {vmdance; update; set ::during [list [set ::VMDance::GUI::console_job] [set ::VMDance::GUI::S(status)]]}
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
update
fake_env
check "  opened as a job of the command's runs: the command's, and said ($::during)" [expr {
    [lindex $::during 0] == 1 && [string match "A job of the command's is running (cluster)*" [lindex $::during 1]]}]
# (F30, the review: and Setup changed in a window opened during it is kept)
destroy $w
update
fake_env MDANCE_FAKE_SLEEP 1
after 300 {vmdance; update; set ::VMDance::GUI::S(sel) "index 0 to 7"}
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
update
fake_env
check "  Setup changed in it: kept, and said" [expr {[set ${S}(sel)] eq "index 0 to 7" &&
    [set ${S}(status)] eq "Setup keeps what was changed while the command's job ran."}]

# --- the library in the window (hardening 2, N13: the status showed the reading's last line through a
# library call, which VMD waits for; Automatic took the library unsaid; the texts promised the background)
# (the throttle let a message in 250 ms through and dropped the rest: the step posted just before the
# library's call, and "measuring the clusters" after the program's last line)
array set $S [list molid $m sel all framemode all fit 0 algorithm kmeans k_kmeans 2 p_kmeans_kinit KmeansPP]
${G}::_frames_changed
${G}::_fit_changed
${G}::_algorithm_changed
set ${G}::last_progress 0
${G}::_progress 0.1 "reading frame 3 of 24"
set ${G}::last_progress [expr {[clock milliseconds] + 60000}]
${G}::_progress 0.2 "reading frame 9 of 24"
set same [set ${S}(status)]
${G}::_progress 0.4 "KMeans NANI, k = 2"
check "N13: progress within 250 ms: the same step's count dropped, a new step shown at once" [expr {
    $same eq "reading frame 3 of 24…" && [set ${S}(status)] eq "KMeans NANI, k = 2…" && [set ${S}(progress)] == 40.0}]
set ${G}::last_progress 0
proc ::status_said {args} { lappend ::said $::VMDance::GUI::S(status) }
set ::said {}
trace add variable ${S}(status) write ::status_said
${G}::cluster
wait_idle
trace remove variable ${S}(status) write ::status_said
check "  the program's clustering: \"measuring the clusters\" shown after its last line" [expr {"measuring the clusters…" in $::said}]
${G}::help
update
set guide [$w.help.t get 1.0 end]
destroy $w.help
check "  the Cluster button's tip and the quick guide say what the library does (they promised the background)" [expr {
    [string match "*in the background (with the library, VMD waits until it ends)" $::VMDance::Tip::text($w.tb.cluster)] &&
    [string match "*runs in the background; Cancel stops it and keeps what was there (with the library, VMD waits until each clustering ends, and Cancel acts then).*" $guide]}]
if {[real_lib] eq ""} {
    skip "N13: the library in the window" "no mdance_tcl library"
} else {
    use_lib
    ${G}::backend_changed
    rename ::mdance::kmeans ::mdance::kmeans_gui
    proc ::mdance::kmeans {args} {
        lappend ::lib_status $::VMDance::GUI::S(status)
        ::mdance::kmeans_gui {*}$args
    }
    set ::lib_status {}
    ::VMDance::Coords::forget
    ${G}::cluster
    wait_idle
    rename ::mdance::kmeans {}
    rename ::mdance::kmeans_gui ::mdance::kmeans
    check "N13: through the library's call the status says the step, that the library runs it and that VMD waits ([lindex $::lib_status 0])" [expr {
        $::lib_status eq [list "KMeans NANI, k = 2, in the library: VMD does not respond until it ends…"] && [lindex [${R}::meta backend] 0] eq "library"}]
    # (Automatic with no program found: the library, said nowhere but in Settings)
    ::VMDance::Backend::configure -mode auto -cli ""
    rename ::VMDance::Backend::find_cli ::VMDance::Backend::find_cli_gui
    proc ::VMDance::Backend::find_cli {} { return "" }
    ${G}::backend_changed
    set note [set ${S}(unavailable)]
    set keep [array get $S gr_*]
    foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a eq "kmeans"}] }
    foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k in {KmeansPP Random VanillaKmeansPP}}] }
    foreach mt $::VMDance::Algo::metrics { set ${S}(gr_met_$mt) [expr {$mt eq "MSD"}] }
    array set $S {gr_from 2 gr_to 20 gr_by 1}
    rename tk_messageBox tk_messageBox_gui
    proc tk_messageBox {args} { set ::asked $args; return cancel }
    set ::asked {}
    ${G}::sweep
    rename tk_messageBox {}
    rename tk_messageBox_gui tk_messageBox
    array set $S $keep
    ${G}::_grid_count
    rename ::VMDance::Backend::find_cli {}
    rename ::VMDance::Backend::find_cli_gui ::VMDance::Backend::find_cli
    use_fake
    ${G}::backend_changed
    check "  Automatic with no program found: Setup says it took the library, and that VMD waits ($note)" [string match \
        "*The library clusters, in VMD, which does not respond during a clustering (Automatic found no mdance-cli: Settings ▸ Backend)." $note]
    check "  a sweep of more than 50 clusterings in the library: its question says VMD waits for each, and Cancel stops between two (it said the background)" [expr {
        [::VMDance::_get $::asked -detail ""] eq "Each clustering runs in the library, in VMD, which does not respond during one; Cancel stops the sweep between two." &&
        ![set ${S}(busy)]}]
}
# (the review of N13: Cancel clicked during a library call, which VMD reads as the call ends, came to no
# job when the job ended right after its call, and PRIME, a pick, a scan's last k were kept all the same)
if {[real_lib] eq ""} {
    skip "N13 (review): Cancel clicked during a library call" "no mdance_tcl library"
} else {
    use_lib
    ${G}::backend_changed
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    rename ::mdance::prime ::mdance::prime_gui
    proc ::mdance::prime {args} {
        # (the click waits in the queue while VMD waits for the call)
        event generate $::w.tb.cancel <ButtonPress-1> -when tail -x 5 -y 5
        event generate $::w.tb.cancel <ButtonRelease-1> -when tail -x 5 -y 5
        ::mdance::prime_gui {*}$args
    }
    ${G}::prime
    wait_idle
    rename ::mdance::prime {}
    rename ::mdance::prime_gui ::mdance::prime
    use_fake
    ${G}::backend_changed
    check "N13 (review): Cancel clicked during PRIME's library call cancels it as the call ends: PRIME not kept (it was, and the status gave its frame)" [expr {
        [set ${S}(status)] eq "Cancelled; what was there is kept." && ![dict size [${R}::extra prime]] && ![set ${S}(busy)]}]
}

# --- the final review: a job of the command's, then in the same script a run chosen or a session
# opened, before the event loop runs: Setup stayed with the job's settings, the line said it kept a
# change no one made, and the next Cluster ran them -----------------------------------------------
fake_env
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set id1 $::VMDance::Results::current
set sf [file join $::out gui_setup_follows.vmdance]
vmdance session save $sf
update
vmdance -mol $m -sel all -k 3 -kinit Random -quiet 1
vmdance run $id1
set a1 [list [set ${S}(k_kmeans)] [set ${S}(p_kmeans_kinit)] [dict get [${G}::request] k] [dict get [${G}::request] params kinit]]
update
set st1 [set ${S}(status)]
vmdance -mol $m -sel all -k 4 -kinit Random -quiet 1
vmdance session load $sf
set a2 [list [set ${S}(k_kmeans)] [set ${S}(p_kmeans_kinit)] [dict get [${G}::request] k] [dict get [${G}::request] params kinit]]
update
set st2 [set ${S}(status)]
check "final review: a clustering of the command's, then a run chosen in the same script: Setup shows that run's ($a1), and says nothing kept" [expr {
    $a1 eq {2 KmeansPP 2 KmeansPP} && ![string match "Setup keeps*" $st1]}]
check "  then a session opened: Setup, the next Cluster's, is its run's ($a2)" [expr {$a2 eq {2 KmeansPP 2 KmeansPP} && ![string match "Setup keeps*" $st2] &&
    [set ${G}::setup0] eq ""}]

# --- frames deleted under the drawing and the picks (hardening 2, F26, F18: the drawing stayed, at
# other frames, and the picks were saved and gone to: other conformations) -----------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 4
set ${S}(v3d_colour) 1
${G}::draw_changed
set nr [molinfo $m get numreps]
animate delete beg 0 end 1 $m
animate goto 3
update; after 500; update
check "frames deleted under the 3D drawing: withdrawn at the next frame, and said" [expr {
    [molinfo $m get numreps] == $nr - 1 && [string match "3D: *no longer has the clustered frames*" [set ${S}(status)]]}]
set n0 [llength $::messages]
set ::next_file [file join $::out gui_stale_picks.pdb]
file delete $::next_file
${G}::save_picks_dialog
[set ${G}::picklist] selection clear 0 end
[set ${G}::picklist] selection set 0
${G}::_pick_goto
check "  the picks of those frames: Save… and the list's double-click refused, saying why" [expr {
    [llength $::messages] == $n0 + 1 && [string match "Not written: *the frames the picks were made from*" [lindex $::messages end]] &&
    ![file exists $::next_file] && [string match "*the frames the picks were made from*" [set ${S}(status)]]}]
set ${S}(v3d_colour) 0
${G}::draw_changed

# --- the molecule deleted -----------------------------------------------------------------
mol delete $m
update; after 200; update
check "molecule deleted: the plots still drawn" [expr {[every_plot_ok] && ![llength $::bgerrors]}]
set ${S}(v3d_colour) 1
${G}::draw_changed
check "  3D says the molecule is gone" [string match "*not loaded*" [set ${S}(status)]]
set ${S}(v3d_colour) 0
${G}::close_window
check "closed" [expr {![${G}::shown]}]
vmdance
check "reopened" [${G}::shown]
check "no background error at all" [expr {[llength $::bgerrors] == 0}]
done
} err]} { puts "FAIL test_gui crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
close $::logf
quit
