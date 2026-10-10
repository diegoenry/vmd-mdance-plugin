# What the second round of reviews found in the window (g9). The findings
# are the window's, and so are their checks, in test_gui.tcl (its block
# "the window (hardening 2, g9)"):
#   F28  the Sweep's and the Elbow's k fields made every value of k before
#        counting them (each key typed in Sweep's "to", at 30000000, froze
#        VMD 4 s and took 2 GB): they ask the command's rule, which counts
#        first
#   F30  what is changed in Setup while a clustering runs is kept for the
#        next one, and said (it was replaced by the run's settings as it
#        ended, and the next Cluster ran them again)
#   F31  the 3D overlay's "frames" chosen before any is typed stays chosen,
#        and the line asks for them; typing frames chooses them (the radio
#        went back, and the frames typed were never drawn)
#   F41  a clustering from the window draws its plot once (three times)
#   F42  with VMD's colours, the plots, the table, the key and the figures
#        follow Graphics ▸ Colors (read once a session of VMD)
#   F64  in the timeline's distances, a dot's left half names its frame, and
#        a click there goes to it (the clustered frame before it)
#   F67  an Export or Figures dialog left open: its button is off while a
#        job runs, and says why when pressed (it did nothing, unsaid)
#   F68  an algorithm chosen while a job runs leaves the toolbar's Elbow off
#        (it came on, and a click did nothing)
#   F69  the window destroyed during its own job and opened again: the job
#        is still the window's, and its last line is kept (blanked)
# This suite (text mode, the fake backend) keeps what the window now asks of
# the core:
#   F28  the command's range of k, asked as the window asks it (its fields'
#        text, trimmed, and no -ks), is counted before the values are made,
#        for the sweep as for the elbow, with the command's answer
#   F30, F68  a job's caller is called once the job no longer runs: the
#        window's Setup and its Elbow button read busy as it publishes
# The review of those fixes:
#   F28  a k of ten digits was refused as "a whole number, 1 or more", which
#        it is: the range is said (-from -to -by, and -ks)
#   F30  a clustering of the command's is published once its end is told,
#        before the event loop runs again: the window keeps Setup's snapshot
#        that long (what was changed in Setup during it was replaced)
#   F31  a session's overlay of "frames" with none typed, drawn without the
#        window, is no overlay, as the window draws it (it was the selected
#        clusters')
# and in test_gui.tcl: F28's window checks bound the time too; F30 for
# the command's clusterings and a window opened during one; F31 "frames"
# with none typed draws no overlay, and frames typed and not yet sent stay
# chosen through a change of the drawing and a job's end.
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_g9.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

# The values of k as the window's Sweep and Elbow ask them (GUI::_grid_configs,
# GUI::elbow): the fields' text, trimmed.
proc g9_ks {what from to by limit} {
    ::VMDance::_ks $what [dict create -ks "" -from [string trim $from] -to [string trim $to] -by [string trim $by]] {} $limit
}

if {[catch {
package require vmdance
set ::VMDance::Prefs::file ""
use_fake
fake_env
set m [load_system two_state]

# --- F28: the range of k, counted before the values are made -----------------------------------
set t [lindex [time {set e [err {vmdance sweep -mol $m -sel all -from 2 -to 3000000}]}] 0]
check "F28: a sweep's -from -to of 2999999 values of k: refused before they are made ([expr {$t / 1000}] ms)" [expr {
    $e eq "vmdance sweep: -from -to -by give 2999999 values of k; at most 1000" && $t < 100000}]
set t [lindex [time {set e [err {g9_ks "vmdance elbow" 2 3000000 1 200}]}] 0]
check "  the window's Elbow fields at k to 3000000: the command's answer, before the values are made ([expr {$t / 1000}] ms)" [expr {
    $e eq "vmdance elbow: -from -to -by give 2999999 values of k; at most 200" && $t < 100000}]
# (F28, the review: refused as "a whole number, 1 or more", which it is)
check "  a value of ten digits: refused, saying the range" [expr {
    [err {g9_ks "vmdance sweep" 2 1000000000 1 1000}] eq "vmdance sweep: -to must be a whole number from 1 to 999999999 (got \"1000000000\")" &&
    [err {vmdance elbow -mol $m -sel all -ks {2 1000000000}}] eq "vmdance elbow: -ks: \"1000000000\" is not a whole number of clusters from 1 to 999999999"}]
check "  the fields' text with spaces around it: taken" [expr {[g9_ks "vmdance sweep" " 2" "4 " 1 1000] eq {2 3 4}}]

# --- F30, F68: a job's caller is called once the job no longer runs ----------------------------
set req [::VMDance::Job::check_cluster [dict create mol $m sel all fit "" first 0 last -1 step 1 \
    algorithm kmeans k 2 metric MSD params {kinit KmeansPP}]]
set ::g9_done ""
::VMDance::Job::start cluster $req "" [list apply {{st r} { set ::g9_done [list $st [::VMDance::Job::busy]] }}]
while {$::g9_done eq ""} { vwait ::g9_done }
check "F30, F68: a job's caller is called once it no longer runs (the window publishes then: its Setup and Elbow read busy)" [expr {
    $::g9_done eq {ok 0}}]

# --- F30 (the review): the command's clustering, published once its end is told ---------------
proc g9_job {what kind} { if {$what eq "end"} { set ::g9_idle 0; after idle {set ::g9_idle 1} } }
proc g9_results {what} { if {$what eq "analysis"} { lappend ::g9_seen $::g9_idle } }
::VMDance::Job::listen g9_job
::VMDance::Results::listen g9_results
set ::g9_seen {}
set ::g9_idle ""
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set at [list $::g9_seen $::g9_idle]
update
::VMDance::Job::unlisten g9_job
::VMDance::Results::unlisten g9_results
check "F30: a clustering of the command's: its end told, then published, before the event loop runs again ($at)" [expr {
    $at eq {0 0} && $::g9_idle == 1}]

# --- F31 (the review): a session's overlay of "frames" with none typed, without the window ---------
vmdance select 0
proc g9_overlays {} { llength [lsearch -all -index 2 $::VMDance::Viz::owned overlay] }
::VMDance::_draw_state {v3d_overlay 1 v3d_mode top}
set n0 [g9_overlays]
::VMDance::_draw_state {v3d_overlay 1 v3d_mode frames v3d_frames " "}
check "F31: a session's overlay of 'frames' with none typed, drawn without the window: no overlay (the selected clusters': $n0)" [expr {
    $n0 > 0 && [g9_overlays] == 0 && [dict get [::VMDance::Viz::get] overlay] == 0 && [dict get [::VMDance::Viz::get] frames] eq ""}]
::VMDance::_draw_state {v3d_overlay 1 v3d_mode frames v3d_frames 0-3}
check "  with frames typed: drawn" [expr {[g9_overlays] > 0 && [dict get [::VMDance::Viz::get] frames] eq "0-3"}]
vmdance draw -overlay 0 -frames ""

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_g9 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
