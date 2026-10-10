# What the reviews of files, inputs, the lifecycle and the science found,
# each kept from coming back (text mode, the fake backend): sessions that
# must reopen, file names that are files, sizes and numbers from files,
# frames that moved under a clustering, atoms that changed under a
# selection, a program that is not mdance-cli, jobs within jobs, scores of
# one cluster, a lone frame's silhouette, label files of the plugin's own.
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening]
file delete -force $H
file mkdir $H
proc bg {kind req} {
    set ::bgdone ""
    ::VMDance::Job::start $kind $req "" {apply {{st r} { set ::bgdone [list $st $r] }}}
}
proc wait_bg {{ms 60000}} {
    set id [after $ms {set ::bgdone timeout}]
    while {$::bgdone eq ""} { vwait ::bgdone }
    after cancel $id
    return $::bgdone
}

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set m [load_system two_state]

# --- sessions the plugin writes reopen ---------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -ks {2 3} -seedings {KmeansPP Nope} -quiet 1
set sf [file join $H refused.vmdance]
vmdance session save $sf
check "a sweep with refused configurations: its session reopens" [expr {![catch {vmdance session load $sf} e] && [llength [vmdance sweep show]] == 8}]
fake_env MDANCE_FAKE_SLEEP 1
set m2 [load_system two_state]
after 400 [list mol delete $m2]
catch {vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1}
fake_env
set sf2 [file join $H deleted.vmdance]
vmdance session save $sf2
check "a molecule deleted while it was clustered: its session reopens, said" [expr {![catch {vmdance session load $sf2} e] && [llength [vmdance runs]] >= 1}]
check "  the session's file is the core's: set by load, forgotten when the runs are cleared" [expr {$::VMDance::Session::current_file eq [file normalize $sf2]}]
vmdance run clear
check "    (cleared)" [expr {$::VMDance::Session::current_file eq ""}]

# --- a file name is a file's ----------------------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set here [pwd]
cd $H
catch {vmdance session save {|touch PWNED}}
set made [file exists [file join $H PWNED]]
cd $here
check "a session named \"|touch PWNED\" is a file of that name, not a command" [expr {!$made && [file exists [file join $H {|touch PWNED}]]}]
set fifo [file join $H fifo.vmdance]
catch {exec mkfifo $fifo}
check "a FIFO is no session (not read without end)" [expr {![file exists $fifo] || [string match "*not a readable file*" [err {vmdance session load $fifo}]]}]
set bomb [file join $H bomb.vmdance]
set fh [open $bomb wb]
zlib push gzip $fh -level 9
puts -nonewline $fh "VMDanceSession 1\n"
set chunk [string repeat a 1000000]
for {set i 0} {$i < 420} {incr i} { puts -nonewline $fh $chunk }
close $fh
set t0 [clock milliseconds]
set e [err {vmdance session load $bomb}]
check "a small file that unpacks to 420 MB is refused ([format %.1f [expr {[file size $bomb] / 1e6}]] MB, [expr {[clock milliseconds] - $t0}] ms)" [string match "*more than 400 MB*" $e]
check "a prefix starting with ~ is refused (Tcl would read a home)" [string match "*not starting with ~*" [err {vmdance export $H -prefix ~x -items labels}]]

# --- numbers from files and the backend ----------------------------------------------------------------
check "the backend's nClusters above the frames: refused before anything is made that long" [string match "*more than the 3 frames*" [err {
    ::VMDance::Job::output {nClusters 500000000 labels {0 0 0}} 3}]]
check "  numbers beyond a double: no score" [expr {[::VMDance::Job::_num 1e999] eq "" && [::VMDance::Job::_num 2.5] eq "2.5"}]
check "cluster 010 is not cluster 8, nor frame 010 frame 8" [expr {[string match "*no cluster*" [err {vmdance get 010}]] &&
    [string match "*usage*" [err {vmdance frame 010}]] && [string match "*no frame*" [err {vmdance goto -frame 010}]]}]
check "picks: a percentage above 100, more frames than there are: refused" [expr {
    [string match "*at most 100*" [err {vmdance pick -mol $m -sel all -method diversity -param 150}]] &&
    [string match "*at most the 24 frames*" [err {vmdance pick -mol $m -sel all -method outliers -param 3000}]]}]
check "eQUAL: more seeds than frames refused" [string match "*-n-seeds 50: at most the 24 frames*" [err {vmdance -mol $m -sel all -algorithm equal -threshold 1 -n-seeds 50}]]

# --- scores of one cluster, a lone frame's silhouette ----------------------------------------------------
set sw [vmdance sweep -mol $m -sel all -algorithms kmeans -ks {1 2 3} -seedings KmeansPP -quiet 1]
check "one cluster has no scores, and is never the best" [expr {[dict get [lindex $sw 0] ch] eq "" && [dict get [lindex $sw 0] db] eq "" &&
    [dict get [vmdance sweep best db] k] != 1}]
set req [::VMDance::Job::check_input [list mol $m sel all]]
set c [::VMDance::Coords::extract $req]
set labs [concat [lrepeat 12 0] [lrepeat 11 1] 2]
set ms [::VMDance::Measure::compute $c $labs 3 {0 12 23} 8]
check "a frame alone in its cluster: silhouette 0" [expr {[lindex [dict get $ms silhouette] 23] == 0 && [lindex [dict get $ms silhouette] 0] > 0}]

# --- frames that moved under a clustering -------------------------------------------------------------------
set mf [load_system two_state]
vmdance -mol $mf -sel all -k 2 -kinit KmeansPP -quiet 1
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $mf
check "frames added after those clustered: PRIME, goto and the exports still work" [expr {
    [dict size [vmdance prime]] == 7 && ![catch {vmdance goto 0}] && ![catch {vmdance export $H -prefix added -items representatives -format pdb}]}]
animate delete beg 0 end 2 $mf
set why "*no longer has the clustered frames*"
check "frames deleted before them: goto, the drawing, the user field and the structures refused" [expr {
    [string match $why [err {vmdance goto 0}]] && [string match $why [err {vmdance userfield}]] &&
    [string match $why [err {vmdance export $H -prefix gone -items representatives}]] &&
    [string match $why [dict get [vmdance draw -colour 1] note]]}]
vmdance draw -colour 0
check "  and PRIME (the coordinates' digest)" [string match "*changed since*" [err {vmdance prime}]]
mol delete $mf

# --- atoms that changed under a selection text --------------------------------------------------------------------
set mb [load_system two_state]
set a [atomselect $mb all]
$a set beta 0
set a2 [atomselect $mb "index 0 to 3"]
$a2 set beta 1
set i1 [vmdance -mol $mb -sel "beta > 0" -k 2 -kinit KmeansPP -quiet 1]
$a set beta 1
set i2 [vmdance -mol $mb -sel "beta > 0" -k 2 -kinit KmeansPP -quiet 1]
$a delete; $a2 delete
check "the same selection text on other atoms: the atoms of now (4, then 8)" [expr {[dict get $i1 natoms] == 4 && [dict get $i2 natoms] == 8}]
mol delete $mb

# --- the plugin's own label file, of other frames --------------------------------------------------------------------
vmdance -mol $m -sel all -last 11 -k 2 -kinit KmeansPP -quiet 1
vmdance export $H -prefix first -items labels
set lf [file join $H first_labels.csv]
check "a label file of the plugin's for frames 0-11 is not read as rows of frames 12-23" [string match "*labels VMD frames 0 to 11*" [err {
    vmdance -mol $m -sel all -first 12 -algorithm helm -k 2 -initial-labels $lf -quiet 1}]]
check "  and is read for its own frames" [expr {![catch {vmdance -mol $m -sel all -last 11 -algorithm helm -k 1 -initial-labels $lf -quiet 1}]}]

# --- structures exported as VMD has them --------------------------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set f [vmdance export $H -prefix exact -items representatives]
set mr [mol new [file join $H exact_representatives.pdb] waitfor all]
mol addfile [file join $H exact_representatives.dcd] waitfor all molid $mr
set s1 [atomselect $mr all frame 1]; set s0 [atomselect $m all frame [${R}::rep_frame 0]]
set d [vecdist [concat {*}[$s1 get {x y z}]] [concat {*}[$s0 get {x y z}]]]
$s1 delete; $s0 delete
mol delete $mr
check "the first frame of an exported DCD as VMD had it (not the PDB's 3 decimals: [format %.1e $d])" [expr {$d < 1e-4}]

# --- a program that is not mdance-cli -----------------------------------------------------------------------------
set hang [file join $H hangcli]
set fh [open $hang w]; puts $fh "#!/bin/sh\nexec sleep 30"; close $fh
file attributes $hang -permissions 0755
set t0 [clock milliseconds]
set b [::VMDance::Backend::configure -mode cli -cli $hang]
set t [expr {[clock milliseconds] - $t0}]
# (offered, with a note: a program slow to start is mdance-cli all the same)
check "a program that waits when run without arguments: VMD waits for it 3 s at most ($t ms), and says it did not answer" [expr {
    [dict get $b error] eq "" && [string match "*did not answer within 3 s*" [dict get $b note]] && $t < 6000}]
bg cluster [::VMDance::Job::check_cluster [list mol $m sel all k 2 params {kinit KmeansPP}]]
after 500 ::VMDance::Job::cancel
set t0 [clock milliseconds]
lassign [wait_bg 10000] st r
check "  a job with it runs in the background, and Cancel stops it ([expr {[clock milliseconds] - $t0}] ms)" [expr {$st eq "cancelled" && [clock milliseconds] - $t0 < 5000}]
set yes [auto_execok yes]
if {$yes ne ""} {
    set b [::VMDance::Backend::configure -mode cli -cli [lindex $yes 0]]
    check "a program that prints without end: not taken" [string match "*printed more than 64 KB*" [dict get $b error]]
}
use_fake
# the program chosen, deleted while a scan runs: an error, not another program
set copy [file join $H fakecopy]
file copy -force $::fake $copy
file attributes $copy -permissions 0755
::VMDance::Backend::configure -mode cli -cli $copy
fake_env MDANCE_FAKE_SLEEP 0.4
set ereq [::VMDance::Job::check_elbow [list mol $m sel all ks {2 3 4 5} params {kinit KmeansPP}]]
bg elbow $ereq
after 600 [list file delete $copy]
lassign [wait_bg] st r
fake_env
set bks [lmap x [dict get $r records] {expr {[dict get $x status] eq "ok" ? [lindex [dict get $x clustering backend] 1] : "error"}}]
check "the program deleted during a scan: the rest fail, and no other program runs ([join $bks {, }])" [expr {$st eq "ok" &&
    [lindex $bks end] eq "error" && [llength [lsearch -all -inline -glob $bks *mdance-cli*]] == 0}]
use_fake

# --- jobs within jobs ---------------------------------------------------------------------------------------------
set ::inner ""
proc again {what kind} {
    if {$what ne "end" || $::inner ne ""} return
    set ::inner [dict get [vmdance -mol $::m -sel all -k 3 -kinit KmeansPP -quiet 1] nclusters]
}
set ::m $m
::VMDance::Job::listen again
set outer [dict get [vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1] nclusters]
update
::VMDance::Job::unlisten again
check "a job started as another ends gets its own answer (2, then $::inner)" [expr {$outer == 2 && $::inner == 3}]

# --- the package, loaded again ---------------------------------------------------------------------------------------
set n0 [llength [vmdance runs]]
package forget vmdance
package require vmdance
check "the package loaded again: the runs are still there ([llength [vmdance runs]])" [expr {[llength [vmdance runs]] == $n0 && $n0 > 0}]

# --- VMD's leftovers ------------------------------------------------------------------------------------------------------
set dead [file join [file dirname $::VMDance::Backend::workdir] "vmdance-[::VMDance::Backend::_user]-[::VMDance::Backend::_where]-999999999-0badf00d"]
file mkdir $dead
::VMDance::Backend::_reap_dead [file dirname $::VMDance::Backend::workdir] [::VMDance::Backend::_user]
check "the private folder of a VMD that no longer runs is removed" [expr {![file exists $dead] && [file isdirectory $::VMDance::Backend::workdir]}]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
mol inactive $m
vmdance goto 1
check "go to a representative of an inactive molecule" [expr {[molinfo $m get frame] == [${R}::rep_frame 1]}]
mol active $m
check "no selection left" [expr {![llength [atomselect list]]}]
done
} err]} { puts "FAIL test_hardening crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
