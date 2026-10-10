# End to end, phase 3 of 4 (the window, the real backend): 3ptb clustered
# from the window's fields (a range, a step, a fit) and compared with the
# command; an elbow scan and a k of it made the clustering; a sweep; PRIME,
# the similarity, picks; HELM with trimmed starting clusters; every plot
# drawn and hovered; figures in PDF, PNG and EPS; every export; the 3D
# view rendered; the library chosen in Settings gives the program's
# answer; the session saved from the window for phase 4.
#   (run by tests/e2e/run_e2e.sh, on a display)
set ::phase window
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests e2e e2e_common.tcl]
set ::logf [open [file join $::E window.log] w]
fconfigure $::logf -buffering line
rename puts _puts
proc puts {args} { if {[llength $args] == 1} { _puts $::logf [lindex $args 0] } else { _puts {*}$args } }
set ::bgerrors {}
proc bgerror {msg} { lappend ::bgerrors $msg; puts "BGERROR $msg\n$::errorInfo" }
set ::messages {}
proc tk_messageBox {args} {
    lappend ::messages [dict get $args -message]
    puts "  (message: [dict get $args -message])"
    return [expr {[dict exists $args -type] && [dict get $args -type] eq "okcancel" ? "ok" : "yes"}]
}
set ::next_file ""
proc tk_getSaveFile {args} { return $::next_file }
proc tk_getOpenFile {args} { return $::next_file }
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}
proc plot_ok {key} {
    set c .vmdance.pw.right.nb.$key.c
    ::VMDance::GUI::show_tab $key
    update
    foreach id [$c find all] {
        if {[$c type $id] eq "text" && [$c itemcget $id -text] eq "Plot error"} { puts "  plot error in $key: [$c itemcget [expr {$id + 1}] -text]"; return 0 }
    }
    expr {[llength [$c find all]] > 0}
}
proc hovers {key} {
    set c .vmdance.pw.right.nb.$key.c
    set n 0
    lassign [::VMDance::Plot::size $c] W H
    for {set x 30} {$x < $W} {incr x 25} {
        for {set y 30} {$y < $H} {incr y 30} {
            ::VMDance::GUI::_hover $key $c $x $y
            if {$::VMDance::GUI::S(readout) ne [dict get $::VMDance::GUI::hints $key]} { incr n }
        }
    }
    return $n
}
proc run_labels {id} { set cur [dict get [vmdance info] run]; vmdance run $id; set l [vmdance labels]; vmdance run $cur; return $l }

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
if {[real_cli] eq ""} { skip "the window with the real backend" "no mdance-cli"; done; exit }
set G ::VMDance::GUI
set S ${G}::S
set R $::R
set mp [load_system 3ptb]
set w [timed "open the window" { vmdance }]
use_cli
${G}::backend_changed
update

# --- the Setup's fields, and the command ------------------------------------------------
array set $S [list molid $mp sel "name CA" framemode range first 5 last 80 step 3 fit 1 fitsel backbone algorithm kmeans k_kmeans 5 p_kmeans_kinit KmeansPP]
${G}::refresh_molecules
${G}::_frames_changed
${G}::_fit_changed
${G}::_algorithm_changed
update
timed "cluster from the window (3ptb Cα 5-80/3, fit)" { ${G}::cluster; wait_idle }
set win [dict get [vmdance info] run]
check "the window's clustering: 26 frames, 5 clusters" [expr {[${R}::nframes] == 26 && [${R}::nclusters] == 5 && [llength [[set ${G}::tree] children {}]] == 5}]
vmdance -mol $mp -sel "name CA" -first 5 -last 80 -step 3 -fit backbone -k 5 -kinit KmeansPP -quiet 1
check "  the command with the same options: the same labels" [expr {[vmdance labels] eq [run_labels $win]}]
vmdance run delete [dict get [vmdance info] run]
vmdance run $win
array set $S {eb_from 2 eb_to 8 eb_by 1}
timed "elbow scan from the window (k 2-8)" { ${G}::elbow; wait_idle }
check "elbow: 7 values of k, the plot drawn" [expr {[llength [dict get $::VMDance::Results::elbow records]] == 7 && [plot_ok elbow] && [hovers elbow] > 0}]
timed "k 4 of the scan made the clustering" { ${G}::adopt elbow 4; wait_idle }
set l4 [vmdance labels]
vmdance -mol $mp -sel "name CA" -first 5 -last 80 -step 3 -fit backbone -k 4 -kinit KmeansPP -quiet 1
check "  the labels of clustering at k 4 directly" [expr {[vmdance labels] eq $l4}]
vmdance run delete [dict get [vmdance info] run]
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a eq "kmeans"}] }
foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k in {KmeansPP Random}}] }
array set $S {gr_from 3 gr_to 6 gr_by 1}
${G}::_grid_count
timed "sweep from the window (8 configurations)" { ${G}::sweep; wait_idle }
check "sweep: 8 configurations, the table and the plot" [expr {[llength [[set ${G}::swtree] children {}]] == 8 && [plot_ok sweep] && [hovers sweep] > 0}]
vmdance run $win
timed "PRIME from the window" { ${G}::prime; wait_idle }
timed "similarity from the window" { ${G}::similarity; wait_idle }
array set $S {pk_method outliers pk_param 5}
timed "pick from the window" { ${G}::pick; wait_idle }
check "PRIME, the similarity and the picks shown" [expr {[llength [[set ${G}::prtree] children {}]] == 7 &&
    [string match "All frames:*" [set ${S}(si_info)]] && [[set ${G}::picklist] size] == 5}]
set ok 1; set hv {}
foreach key {populations timeline transitions residence compactness distances tree silhouette} {
    if {![plot_ok $key]} { set ok 0 }
    lappend hv $key [hovers $key]
}
check "every plot of the clustering drawn, and hovered ([join $hv { }])" [expr {$ok && [llength [lmap {k n} $hv {expr {$n > 0 ? [continue] : $k}}]] == 0}]

# HELM with trimmed starting clusters, from the window
array set $S [list framemode all fit 0 algorithm helm k_helm 4 p_helm_initial 20 p_helm_initial-kinit KmeansPP p_helm_trim-start 1 p_helm_trim-k 5]
${G}::_frames_changed
${G}::_fit_changed
${G}::_algorithm_changed
${G}::_params_sync
timed "HELM from the window (20 starting clusters, 5 trimmed)" { ${G}::cluster; wait_idle }
set cv $w.pw.right.nb.tree.c
check "HELM trimmed: its tree drawn, the trimmed ones counted" [expr {[${R}::nclusters] == 4 && [${R}::noise] > 0 && [plot_ok tree] &&
    [llength [lmap id [$cv find withtag label] {expr {[string match "*5 starting clusters trimmed*" [$cv itemcget $id -text]] ? $id : [continue]}}]] == 1}]
vmdance run $win

# --- figures, exports, the 3D view --------------------------------------------------------------
set fd [file join $::E figures]
file delete -force $fd
file mkdir $fd
array set $S [list fig_dir $fd fig_pdf 1 fig_png 1 fig_eps 1 fig_prefix f]
${G}::figure_dialog
update
foreach k [dict keys $::VMDance::GUI::tabs] { set ${G}::F($k) 1 }
timed "create every figure (10 plots × PDF, PNG, EPS)" { ${G}::_figures_go }
set bad {}
foreach k [dict keys $::VMDance::GUI::tabs] {
    foreach {ext head} {pdf %PDF eps %!PS} {
        set f [file join $fd f_$k.$ext]
        if {![file exists $f] || [string range [read_text $f] 0 3] ne $head} { lappend bad f_$k.$ext }
    }
    set f [file join $fd f_$k.png]
    if {![file exists $f] || [catch {image create photo -file $f} img]} { lappend bad f_$k.png; continue }
    # (900 × 560 points at 300 dpi)
    if {abs([image width $img] - 3750) > 10 || abs([image height $img] - 2333) > 10} { lappend bad "f_$k.png [image width $img]×[image height $img]" }
    image delete $img
}
check "figures: every plot as PDF, EPS, and PNG at 300 dpi ([expr {[llength $bad] ? [join $bad {, }] : "all 30"}])" [expr {![llength $bad]}]
set xd [file join $::E export_window]
file delete -force $xd
file mkdir $xd
array set $S [list out_dir $xd out_prefix x]
${G}::export_dialog
update
foreach {it lab} $::VMDance::GUI::export_items { set ${G}::X($it) [::VMDance::GUI::_exportable $it] }
timed "export everything from the window" { ${G}::_export_go }
set n [llength [glob -nocomplain -directory $xd *]]
check "export from the window: every item ($n files)" [expr {$n >= 20 && [concat {*}[lrange [table [file join $xd x_labels.csv]] 1 end]] eq [vmdance labels]}]
set png [file join $::E view3d.png]
file delete $png
vmdance draw -colour 1 -reps 1
set r [expr {"TachyonInternal" in [render list] ? "TachyonInternal" : "snapshot"}]
timed "render the 3D view ($r)" { ::VMDance::Figures::render_3d $png $r }
check "the 3D view rendered with the clusters drawn ($r)" [expr {[file exists $png] && [file size $png] > 1000}]
vmdance draw -colour 0 -reps 0

# --- the library, chosen in Settings ----------------------------------------------------------
if {[real_lib] ne ""} {
    array set $S [list molid $mp sel "name CA" framemode range first 5 last 80 step 3 fit 1 fitsel backbone algorithm kmeans k_kmeans 5 p_kmeans_kinit KmeansPP]
    ${G}::_frames_changed
    ${G}::_fit_changed
    ${G}::_algorithm_changed
    ${G}::settings_dialog
    update
    array set ${G}::E [list mode library lib [real_lib]]
    ${G}::_settings_apply
    update
    check "Settings: the library in use" [expr {[lindex [dict get [vmdance backend] using] 0] eq "library" && ![winfo exists $w.settings]}]
    timed "cluster from the window with the library" { ${G}::cluster; wait_idle }
    check "  the library's labels are the program's" [expr {[vmdance labels] eq [run_labels $win]}]
    vmdance run delete [dict get [vmdance info] run]
    ${G}::settings_dialog
    update
    array set ${G}::E [list mode cli cli [real_cli]]
    ${G}::_settings_apply
    update
    vmdance run $win
} else {
    skip "the library from Settings" "no mdance_tcl library"
}

# --- the session, from the window ----------------------------------------------------------
array set $S {tl_view msd ds_show representatives sw_score db}
vmdance select 1 3
set ::next_file [file join $::E window.vmdance]
file delete $::next_file
timed "save the session from the window" { ${G}::save_session 1 }
check "session saved from the window" [file exists $::next_file]
save_state window.state
check "no background error" [expr {![llength $::bgerrors]}]
done
} err]} { puts "FAIL e2e window crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
close $::logf
quit
