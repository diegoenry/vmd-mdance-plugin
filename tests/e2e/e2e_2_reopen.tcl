# End to end, phase 2 of 5 (text mode, a new VMD): phase 1's session
# opened again. First with the heptapeptide loaded with one frame too many
# (its PDB's): the session finds it by its files, and the questions that
# read the coordinates again must refuse rather than answer for other
# frames. Then as phase 1 had it (the heptapeptide found among the loaded
# molecules, 3ptb loaded from its files): every answer of the command for
# every run, the scans and the picks equal phase 1's; PRIME and the
# similarity asked again give what was kept; -mol none opens it without
# molecules.
set ::phase reopen
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests e2e e2e_common.tcl]

if {[catch {
package require vmdance
set sf [file join $::E work.vmdance]
if {[real_cli] eq "" || ![file exists $sf]} {
    skip "reopening phase 1's session" "no mdance-cli, or phase 1 did not run"
    done
    quit
}
use_cli
set R $::R
set want [read_state work.state]

# the heptapeptide with its PDB's frame: the same files, other frames
set d [file join $::refruns inputs 1_heptapeptide]
set bad [mol new [file join $d aligned_tau.pdb] waitfor all]
mol addfile [file join $d backbone_aligned.dcd] waitfor all molid $bad
set w [timed "open the session (3ptb loaded from its files)" { vmdance session load $sf }]
check "session opened: 4 runs, the current one NANI k 6" [expr {[llength [vmdance runs]] == 4 &&
    [dict get [vmdance info] algorithm] eq "kmeans" && [dict get [vmdance info] molid] == $bad}]
set e1 [err {vmdance prime}]
check "  PRIME on a molecule with a frame more, first: refused ($e1)" [string match "*changed since*" $e1]
check "  going to a representative too" [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]
check "  (the tables still answer)" [expr {[llength [vmdance labels]] == 12002}]
# as many frames as were clustered, each the one before it
animate delete beg 6001 end 6001 $bad
set e1 [err {vmdance prime}]
check "  as many frames, but shifted by one: PRIME refused ($e1)" [string match "*changed since*" $e1]
set e2 [err {vmdance similarity}]
check "  the similarity too" [string match "*changed since*" $e2]
mol delete all
vmdance run clear

# as phase 1 had it
set mh [load_ref heptapeptide]
set n0 [molinfo num]
set w [timed "open the session again" { vmdance session load $sf }]
check "the heptapeptide found among the loaded molecules, 3ptb loaded from its files ([join $w {; }])" [expr {
    [molinfo num] == $n0 + 1 && [dict get [vmdance info] molid] == $mh}]
set got [timed "the state of every run" { state_of }]
set diff [diff_state $want $got]
check "every answer of every run, the scans, the picks and the selection are phase 1's ([expr {[llength $diff] ? [join $diff {, }] : "no difference"}])" [expr {![llength $diff]}]
set p0 [${R}::extra prime]
set s0 [${R}::extra similarity]
set p [timed "PRIME again" { vmdance prime }]
check "  PRIME asked again: what was kept" [expr {[${R}::extra prime] eq $p0}]
vmdance similarity
check "  the similarity asked again: what was kept" [expr {[${R}::extra similarity] eq $s0}]
set runs [vmdance runs]
vmdance run [lindex [lindex $runs 2] 0]
set l1 [vmdance labels]
set i [timed "cluster 3ptb again as phase 1 did" {
    vmdance -mol [dict get [vmdance info] molid] -sel "name CA" -first 5 -last 80 -step 3 -fit backbone -k 5 -kinit KmeansPP -quiet 1
}]
check "  3ptb clustered again from its loaded files: phase 1's labels" [expr {[vmdance labels] eq $l1}]
vmdance run clear
mol delete all

# no molecule at all
set w [vmdance session load $sf -mol none]
check "-mol none: the tables and the scans without molecules" [expr {[llength [vmdance runs]] == 4 &&
    [llength [vmdance clusters]] == 6 && [llength [vmdance elbow show]] == 9}]
check "  the questions wait for the molecule, and say so" [string match "*not loaded*" [err {vmdance prime}]]
check "no selection left" [expr {![llength [atomselect list]]}]
done
} err]} { puts "FAIL e2e reopen crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
