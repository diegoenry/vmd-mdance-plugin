# End to end, phase 4 of 4 (the window, a new VMD, no molecule loaded):
# phase 3's session opened from File ▸ Open session: its molecule loaded
# from its files, every answer of the command equal to phase 3's, the
# window's plot settings and selection back, every plot drawn, the 3D
# drawing on the loaded molecule, going to a representative, and PRIME
# asked again from the window giving what was kept.
#   (run by tests/e2e/run_e2e.sh, on a display)
set ::phase window-reopen
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests e2e e2e_common.tcl]
set ::logf [open [file join $::E window_reopen.log] w]
fconfigure $::logf -buffering line
rename puts _puts
proc puts {args} { if {[llength $args] == 1} { _puts $::logf [lindex $args 0] } else { _puts {*}$args } }
set ::bgerrors {}
proc bgerror {msg} { lappend ::bgerrors $msg; puts "BGERROR $msg\n$::errorInfo" }
proc tk_messageBox {args} { puts "  (message: [dict get $args -message])"; return [expr {[dict exists $args -type] && [dict get $args -type] eq "okcancel" ? "ok" : "yes"}] }
set ::next_file ""
proc tk_getOpenFile {args} { return $::next_file }
proc wait_idle {} { while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }; update }
proc plot_ok {key} {
    set c .vmdance.pw.right.nb.$key.c
    ::VMDance::GUI::show_tab $key
    update
    foreach id [$c find all] { if {[$c type $id] eq "text" && [$c itemcget $id -text] eq "Plot error"} { return 0 } }
    expr {[llength [$c find all]] > 0}
}

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
set sf [file join $::E window.vmdance]
if {[real_cli] eq "" || ![file exists $sf]} { skip "reopening phase 3's session in the window" "no mdance-cli, or phase 3 did not run"; done; exit }
set G ::VMDance::GUI
set S ${G}::S
set R $::R
set w [vmdance]
use_cli
update
check "no molecule loaded" [expr {[molinfo num] == 0}]
set ::next_file $sf
timed "open the session from the window (its molecule loaded from its files)" { ${G}::open_session_dialog; update }
check "  3ptb loaded, the runs back" [expr {[molinfo num] == 1 && [molinfo [molinfo top] get numframes] == 100 && [llength [vmdance runs]] == 3}]
set diff [diff_state [read_state window.state] [state_of]]
check "  every answer of every run, the scans, the picks and the selection are phase 3's ([expr {[llength $diff] ? [join $diff {, }] : "no difference"}])" [expr {![llength $diff]}]
check "  the window's plot settings back" [expr {[set ${S}(tl_view)] eq "msd" && [set ${S}(ds_show)] eq "representatives" && [set ${S}(sw_score)] eq "db"}]
check "  the selection in the table" [expr {[[set ${G}::tree] selection] eq {c1 c3}}]
set ok 1
foreach key [dict keys $::VMDance::GUI::tabs] { if {![plot_ok $key]} { set ok 0; puts "  $key not drawn" } }
check "every plot drawn" $ok
set m [molinfo top]
set n0 [molinfo $m get numreps]
set ${S}(v3d_colour) 1
${G}::draw_changed
check "3D: colour by cluster on the loaded molecule" [expr {[molinfo $m get numreps] == $n0 + 1}]
set ${S}(v3d_colour) 0
${G}::draw_changed
vmdance select 1
${G}::goto_selected
check "  go to the selected cluster's representative" [expr {[molinfo $m get frame] == [${R}::rep_frame 1]}]
set p0 [${R}::extra prime]
timed "PRIME again from the window" { ${G}::prime; wait_idle }
check "PRIME asked again of the reopened run: what was kept" [expr {[${R}::extra prime] eq $p0 && [dict size $p0] > 0}]
check "no background error" [expr {![llength $::bgerrors]}]
done
} err]} { puts "FAIL e2e window-reopen crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
close $::logf
quit
