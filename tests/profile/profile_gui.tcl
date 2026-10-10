# Where the time goes in the window (the real backend, the heptapeptide's
# backbone: 6001 frames): a clustering published with the window open,
# each plot drawn, the pointer over each plot, a selection, the trajectory
# played with the clusters coloured, figures, a session opened.
#   DISPLAY=:9 vmd -dispdev win -e tests/profile/profile_gui.tcl < /dev/null
#   (the report: tests/out/profile/gui.txt)
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
source [file join $::root tests profile prof.tcl]
set P [file join $::out profile]
file mkdir $P
set rep [file join $P gui.txt]
file delete $rep
proc say {s} { set fh [open $::rep a]; puts $fh $s; close $fh }
proc scenario {title script {n 15}} {
    set m0 [prof::rss]
    set t0 [clock microseconds]
    uplevel 1 $script
    set t [expr {([clock microseconds] - $t0) / 1000.0}]
    prof::report "$title: [format %.0f $t] ms, memory $m0 → [prof::rss] MB" $n $::rep
    return $t
}
proc tk_messageBox {args} { return ok }
set ::next_file ""
proc tk_getOpenFile {args} { return $::next_file }
if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
if {[real_cli] eq ""} { say "no mdance-cli"; quit }
use_cli
set G ::VMDance::GUI
set w [vmdance]
update
say "VMDance window profile, [clock format [clock seconds]], screen [winfo screenwidth $w]×[winfo screenheight $w], window [winfo width $w]×[winfo height $w]"
set mh [load_ref heptapeptide]
update
prof::start
scenario "cluster with the window open (KMeans NANI k 6, 6001 frames)" { vmdance -mol $mh -sel backbone -k 6 -quiet 1; update }
set times {}
foreach key [dict keys $::VMDance::GUI::tabs] {
    ${G}::show_tab $key
    update
    set t0 [clock microseconds]
    ${G}::redraw
    update
    lappend times $key [expr {([clock microseconds] - $t0) / 1000.0}]
}
prof::report "every plot drawn once: [join [lmap {k t} $times {format "%s %.0f ms" $k $t}] {, }]" 15 $rep
set times {}
foreach key [dict keys $::VMDance::GUI::tabs] {
    ${G}::show_tab $key
    update
    set c $w.pw.right.nb.$key.c
    lassign [::VMDance::Plot::size $c] W H
    set t0 [clock microseconds]
    set n 0
    for {set x 20} {$x < $W} {incr x 40} { for {set y 20} {$y < $H} {incr y 40} { ${G}::_hover $key $c $x $y; incr n } }
    lappend times $key [expr {([clock microseconds] - $t0) / double($n)}]
}
prof::report "the pointer over each plot, µs per motion: [join [lmap {k t} $times {format "%s %.0f" $k $t}] {, }]" 15 $rep
${G}::show_tab populations
update
scenario "select a cluster (the table, the populations plot)" { vmdance select 2; update }
${G}::show_tab timeline
set ::VMDance::GUI::S(v3d_colour) 1
${G}::draw_changed
update
set t [scenario "the trajectory played over 600 frames, coloured, the Timeline shown" {
    for {set f 0} {$f < 600} {incr f} { animate goto $f; display update; update }
}]
say "  → [format %.2f [expr {$t / 600}]] ms a frame"
set ::VMDance::GUI::S(v3d_colour) 0
${G}::draw_changed
set fd [file join $P figs]
file delete -force $fd
file mkdir $fd
scenario "figures: every plot, PDF and PNG" { vmdance figures $fd -formats {pdf png} }
set sf [file join $P w.vmdance]
vmdance session save $sf
set ::next_file $sf
scenario "open the session in the window" { ${G}::open_session_dialog; update }
} err]} { say "profile crashed: $err\n$::errorInfo" }
::VMDance::Backend::cleanup
quit
