# What the review of the clustered frames and their molecule (g5) found,
# each kept from coming back (text mode, the fake backend):
#   R1   frames_ok's kept answer, and a job's trusted state, are not taken
#        after frames are deleted back to a count seen while a trajectory
#        loaded (the count and the files are as they were; the frames at
#        the clustered numbers are not): the same of the picks
#   R2   two replicas loaded by the same relative names: each run of a
#        session goes to its own molecule (both went to the first's, and
#        -mol load loaded one)
#   R3   a session made after a cd loads its molecule by the names as typed
#        from VMD's folder of now (refused: "not a readable file"); reopened
#        after a cd with its molecule loaded, no false "not its files"
#   R4   a run whose molecule has more files than another run's: its own
#        files loaded (it was put on the other's molecule and refused)
#   R5   a session's picks whose VMD frames are not those of their rows are
#        refused as corrupt (other frames were drawn, gone to and saved)
#   R6   an import goes on past a molecule whose clustered frames cannot be
#        read (it stopped, naming -first, -last and -step)
#   R7   draw's note says the clusters are not drawn, not "nothing is drawn",
#        when the picks are
#   R8   the picks of a session made before they kept their digest are never
#        taken on their file names and count (another replica's frames were
#        saved and gone to): said, and listed only
#   R9   a session made before the names in full, opened from another
#        replica's folder: the files beside the session are tried next
#   R10  (F33's advice) the PDB's own frame read again: goto, frame, the
#        user field, the exports and PRIME say to delete it, not to cluster
#        again (deleting it gives every answer back)
#   R11  a molecule found by the names VMD keeps, its folder changed since:
#        no false warning, and of two replicas the one with the frames
#   R13  frames deleted after the last picked one leave the picks (refused:
#        the frames they were picked from)
# (R12, the window's import asking for the molecule, is test_gui's.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_fx_g5.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_fx_g5]
file delete -force $H
file mkdir $H

proc write_session {f d} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "VMDanceSession 1\n$d\n"] -level 9]
    close $fh
}
# A folder of two_state as sys.pdb (a frame) and traj.dcd (its 24 frames,
# in reverse order with rev: another trajectory of the same names).
proc fx_system {dir {rev 0}} {
    file mkdir $dir
    set t [mol new [file join $::fixtures two_state.pdb] waitfor all]
    set s [atomselect $t all]
    set n [molinfo $t get numframes]
    if {$rev} {
        set xyz {}
        for {set f 0} {$f < $n} {incr f} { $s frame $f; lappend xyz [$s get {x y z}] }
        for {set f 0} {$f < $n} {incr f} { $s frame $f; $s set {x y z} [lindex $xyz [expr {$n - 1 - $f}]] }
    }
    animate write pdb [file join $dir sys.pdb] beg 0 end 0 $t
    animate write dcd [file join $dir traj.dcd] $t
    $s delete
    mol delete $t
}
# sys.pdb then traj.dcd, by the names given (relative: of VMD's folder),
# the PDB's own frame deleted (drop).
proc fx_load {pdb dcd {drop 1}} {
    set m [mol new $pdb waitfor all]
    mol addfile $dcd waitfor all molid $m
    if {$drop} { animate delete beg 0 end 0 $m }
    return $m
}
# A session's dictionary as sessions made before g5 have it: no names in
# full, no atoms, and picks with nothing that tells their frames.
proc fx_old {d} {
    set runs {}
    foreach r [dict get $d runs] {
        lassign $r id label a
        dict set a molecule [dict remove [dict get $a molecule] paths]
        if {[dict exists $a shape]} { dict unset a shape }
        dict set a request [dict remove [dict get $a request] atoms fitatoms]
        lappend runs [list $id $label $a]
    }
    dict set d runs $runs
    set p [dict get $d picks]
    if {[dict size $p]} {
        dict set p molecule [dict remove [dict get $p molecule] paths]
        set p [dict remove $p digest shape]
        dict set p input [dict remove [dict get $p input] atoms fitatoms]
        dict set d picks $p
    }
    return $d
}
proc fx_clear {} {
    foreach x [molinfo list] { mol delete $x }
    vmdance run clear
}
# The RMSD between frame f1 of m1 and frame f2 of m2 (all atoms, no fit).
proc fx_rmsd {m1 f1 m2 f2} {
    set a [atomselect $m1 all frame $f1]; set b [atomselect $m2 all frame $f2]
    set r [measure rmsd $a $b]
    $a delete; $b delete
    return $r
}

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set here [pwd]
set A [file join $H A]
set B [file join $H B]
fx_system $A
fx_system $B 1

# --- R1: the answer kept, and the trust, for a count seen while a trajectory loaded -------
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set ::fxm $m
set ::seen ""
proc fx_ask_once {args} {
    if {[molinfo $::fxm get numframes] == 30 && $::seen eq ""} { set ::seen [::VMDance::Results::frames_ok] }
}
trace add variable ::vmd_frame($m) write fx_ask_once
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
trace remove variable ::vmd_frame($m) write fx_ask_once
set n1 [molinfo $m get numframes]
animate delete beg 0 end 17 $m
check "R1: frames_ok asked once while frames were added (at 30, nothing after), then frames deleted back to 30: refused (the answer kept for 30 was taken)" [expr {
    $::seen eq "1" && $n1 == 48 && [molinfo $m get numframes] == 30 && ![${R}::frames_ok] &&
    [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]}]
mol delete $m
vmdance run clear
# (a job's run whose molecule was recorded at 30 frames, as a trajectory loaded)
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 4
set ::fxa $::VMDance::Results::A
set ::fxp $::VMDance::Results::picks
set ::fxdone ""
proc fx_made_at_30 {args} {
    if {[molinfo $::fxm get numframes] != 30 || $::fxdone ne ""} return
    set rec [::VMDance::Mol::record $::fxm]
    set a $::fxa
    dict set a molecule $rec
    set p $::fxp
    dict set p molecule $rec
    set ::fxdone [::VMDance::Results::publish $a "made at 30"]
    ::VMDance::Results::set_picks $p
}
set ::fxm $m
trace add variable ::vmd_frame($m) write fx_made_at_30
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
trace remove variable ::vmd_frame($m) write fx_made_at_30
set ok1 [expr {$::fxdone ne "" && [lindex [dict get $::VMDance::Results::trusted $::fxdone] 1] == 30 &&
    [lindex $::VMDance::Results::picks_trusted 1] == 30 && [${R}::frames_ok] && [${R}::picks_ok]}]
animate delete beg 0 end 17 $m
check "  a job's run and picks made while a trajectory loaded (30 frames), then frames deleted back to 30: not trusted (taken as made)" [expr {
    $ok1 && ![${R}::frames_ok] && ![${R}::picks_ok] &&
    [string match "*have the clustered frames at their numbers*" [err {vmdance goto 0}]] &&
    [string match "*the frames the picks were made from*" [err {vmdance pick goto [lindex [vmdance pick show] 0]}]]}]
mol delete $m
vmdance run clear
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 4
set ::fxm $m
set ::seen ""
proc fx_ask_picks {args} {
    if {[molinfo $::fxm get numframes] == 30 && $::seen eq ""} { set ::seen [::VMDance::Results::picks_ok] }
}
# (their trust is not what answers: the answer kept is)
set ::VMDance::Results::picks_trusted ""
trace add variable ::vmd_frame($m) write fx_ask_picks
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
trace remove variable ::vmd_frame($m) write fx_ask_picks
animate delete beg 0 end 17 $m
check "  the picks' kept answer the same way: refused" [expr {$::seen eq "1" && ![${R}::picks_ok]}]
mol delete $m
vmdance run clear
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set g0 [vmdance goto 0]
set s [atomselect $m all]
for {set f 0} {$f < 24} {incr f} { $s frame $f; $s move [transaxis z [expr {7 * $f + 3}]]; $s moveby [list [expr {0.5 * $f}] -1.5 2.0] }
$s delete
check "  a job's run, its frames aligned in place since (no longer as it read them): still its frames, as their shapes tell" [expr {![catch {vmdance goto 0} r] && $r == $g0}]
fx_clear

# --- R2: two replicas loaded by the same relative names -------------------------------------
cd $A
set ma [fx_load sys.pdb traj.dcd]
vmdance -mol $ma -sel all -k 2 -kinit KmeansPP -quiet 1
set ga [vmdance goto 0]
cd $B
set mb [fx_load sys.pdb traj.dcd]
vmdance -mol $mb -sel all -k 2 -kinit KmeansPP -quiet 1
set gb [vmdance goto 0]
cd $here
set s2 [file join $H two.vmdance]
vmdance session save $s2
set ids [lmap r [vmdance runs] {lindex $r 0}]
fx_clear
set w [lindex [::VMDance::Session::load $s2 auto] 0]
set ok {}
foreach id $ids dir [list $A $B] g [list $ga $gb] {
    vmdance run $id
    set mm [dict get [${R}::request] mol]
    lappend ok [expr {$mm >= 0 && [lindex [molinfo $mm get filename] 0 0] eq [file normalize [file join $dir sys.pdb]] &&
        ![catch {vmdance goto 0} r] && $r == $g}]
}
# (the PDB's own frame, deleted when they were clustered, deleted again: F33)
proc fx_others {w} { lsearch -all -inline -not -glob $w "*: deleted again" }
check "R2: two replicas by the same relative names, nothing loaded: each run on its own files ([join $w {; }])" [expr {
    $ok eq "1 1" && ![llength [fx_others $w]] && [molinfo num] == 2}]
fx_clear
set w [lindex [::VMDance::Session::load $s2 load] 0]
set ok {}
foreach id $ids dir [list $A $B] {
    vmdance run $id
    set mm [dict get [${R}::request] mol]
    lappend ok [expr {$mm >= 0 && [lindex [molinfo $mm get filename] 0 0] eq [file normalize [file join $dir sys.pdb]] && ![catch {vmdance goto 0}]}]
}
check "  -mol load: both loaded, each run on its own ([join $w {; }])" [expr {$ok eq "1 1" && ![llength [fx_others $w]] && [molinfo num] == 2}]
fx_clear
cd $A
set ma [fx_load sys.pdb traj.dcd]
cd $B
set mb [fx_load sys.pdb traj.dcd]
cd $H
set w [lindex [::VMDance::Session::load $s2 auto] 0]
cd $here
set ok {}
foreach id $ids want [list $ma $mb] {
    vmdance run $id
    lappend ok [expr {[dict get [${R}::request] mol] == $want && ![catch {vmdance goto 0}]}]
}
check "  both loaded by the user, VMD's folder elsewhere: each run on its own, no warning (both went to the first, one refused)" [expr {
    $ok eq "1 1" && ![llength $w] && [molinfo num] == 2}]
fx_clear

# --- R3: a session made after a cd -----------------------------------------------------------
set D [file join $H data]
set Wk [file join $H work]
fx_system $D
file mkdir $Wk
cd $D
set m [fx_load sys.pdb traj.dcd 0]
cd $Wk
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set g0 [vmdance goto 0]
set s3 [file join $Wk s.vmdance]
vmdance session save $s3
fx_clear
cd $D
set w [lindex [::VMDance::Session::load $s3 auto] 0]
cd $here
set m3 [dict get [${R}::request] mol]
check "R3: clustered after a cd (its names in full of the wrong folder), opened from the folder of its names: loaded from there ([join $w {; }])" [expr {
    $m3 >= 0 && ![llength $w] && [lindex [molinfo $m3 get filename] 0 0] eq [file normalize [file join $D sys.pdb]] &&
    ![catch {vmdance goto 0} r] && $r == $g0}]
fx_clear
cd $D
set m [fx_load sys.pdb traj.dcd 0]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set s3b [file join $D s.vmdance]
vmdance session save $s3b
vmdance run clear
cd $Wk
set w [lindex [::VMDance::Session::load $s3b auto] 0]
cd $here
check "  reopened after a cd, its molecule loaded: taken, no warning (\"not its files\")" [expr {
    [dict get [${R}::request] mol] == $m && ![llength $w] && ![catch {vmdance goto 0}] && [molinfo num] == 1}]
fx_clear

# --- R4: a run with more files than another's ------------------------------------------------
set M4 [file join $H more]
fx_system $M4
file copy [file join $B traj.dcd] [file join $M4 traj2.dcd]
set m [fx_load [file join $M4 sys.pdb] [file join $M4 traj.dcd] 0]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
mol addfile [file join $M4 traj2.dcd] waitfor all molid $m
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1 -first 25
set g2 [vmdance goto 0]
set s4 [file join $H more.vmdance]
vmdance session save $s4
set ids [lmap r [vmdance runs] {lindex $r 0}]
fx_clear
set w [lindex [::VMDance::Session::load $s4 auto] 0]
vmdance run [lindex $ids 1]
set m4 [dict get [${R}::request] mol]
check "R4: a run of three files after a run of two of them, nothing loaded: its own files loaded ([join $w {; }])" [expr {
    ![llength $w] && [llength [lindex [molinfo $m4 get filename] 0]] == 3 && ![catch {vmdance goto 0} r] && $r == $g2}]
vmdance run [lindex $ids 0]
check "  and the first run on its own" [expr {![catch {vmdance goto 0}]}]
fx_clear

# --- R5: the picks' VMD frames are those of their rows ----------------------------------------
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 4
set s5 [file join $H p5.vmdance]
vmdance session save $s5
set d [::VMDance::Session::read_file $s5]
set p [dict get $d picks]
set rows [dict get $p rows]
dict set p vmdframes [lmap r $rows {expr {$r == 23 ? 0 : $r + 1}}]
dict set d picks $p
set s5b [file join $H p5b.vmdance]
write_session $s5b $d
check "R5: a session's picks whose VMD frames are not their rows' frames: refused as corrupt (they were drawn, gone to and saved)" [
    string match "*frame picks' VMD frames are not those of their rows*" [err {::VMDance::Session::read_file $s5b}]]
check "  the session as saved still opens" [expr {![catch {::VMDance::Session::read_file $s5}]}]
fx_clear

# --- R6: an import past a molecule whose frames cannot be read --------------------------------
set of [file join $::fixtures old_kmeans.mdance]
set d0 [load_system two_state]
set s [atomselect $d0 "index 0"]
$s frame 6
$s set x Inf
$s delete
set m [load_system two_state]
check "R6: an import, a molecule of its name first with a frame that cannot be read: onto the next (it stopped, naming -first, -last, -step)" [expr {
    ![catch {vmdance session import $of} i] && [dict get $i molid] == $m}]
set e [err {vmdance session import $of -mol $d0}]
check "  that one given with -mol: refused, naming the frame, not options an import has not ($e)" [expr {
    [string match "*molecule $d0: frame 6 has coordinates that are not numbers*" $e] && ![string match "*-first*" $e] && ![string match "*leave the frame out*" $e]}]
fx_clear

# --- R7: draw's note with the picks drawn ------------------------------------------------------
set m [load_system two_state]
vmdance pick -mol $m -sel all -method outliers -param 4
set n0 [molinfo $m get numreps]
set d [vmdance draw -reps 1 -picks 1]
check "R7: no clustering, the picks drawn: the note says the clusters are not drawn (\"nothing is drawn\")" [expr {
    [molinfo $m get numreps] == $n0 + 1 && [::VMDance::_get $d note ""] eq "no clustering: the clusters are not drawn"}]
vmdance draw -reps 0 -picks 0
fx_clear

# --- R8, R9: a session made before (names as typed, picks without digest) ----------------------
cd $A
set ma [fx_load sys.pdb traj.dcd 0]
vmdance -mol $ma -sel all -k 2 -kinit KmeansPP -quiet 1
set g0 [vmdance goto 0]
vmdance pick -mol $ma -sel all -method outliers -param 4
set pf [vmdance pick show]
set snew [file join $A new.vmdance]
vmdance session save $snew
set sold [file join $A old.vmdance]
write_session $sold [fx_old [::VMDance::Session::read_file $snew]]
cd $here
fx_clear
cd $B
set mb [fx_load sys.pdb traj.dcd 0]
set w [lindex [::VMDance::Session::load $sold auto] 0]
cd $here
set out8 [file join $H r8.pdb]
check "R8: the picks of a session made before, onto another replica of their names: said, listed only (saved and gone to: the other's frames)" [expr {
    [dict get $::VMDance::Results::picks input mol] == $mb && [lsearch -glob $w "the frame picks: *pick them again"] >= 0 &&
    ![${R}::picks_ok] && [string match "*the frames the picks were made from*" [err {vmdance pick goto [lindex $pf 0]}]] &&
    [string match "*the frames the picks were made from*" [err {vmdance pick save $out8}]] && ![file exists $out8] &&
    [string match "*the picked frames are not drawn*" [::VMDance::_get [vmdance draw -picks 1] note ""]]}]
vmdance draw -picks 0
fx_clear
cd $B
set w [lindex [::VMDance::Session::load $sold auto] 0]
cd $here
set m9 [dict get [${R}::request] mol]
check "R9: a session made before (names as typed), nothing loaded, opened from another replica's folder: the files beside it loaded ([join $w {; }])" [expr {
    $m9 >= 0 && [lindex [molinfo $m9 get filename] 0 0] eq [file normalize [file join $A sys.pdb]] && [molinfo num] == 1 &&
    ![catch {vmdance goto 0} r] && $r == $g0 && [lsearch -glob $w "run *"] < 0}]
fx_clear

# --- R11: names VMD keeps, its folder changed since -------------------------------------------
cd $A
set ma [fx_load sys.pdb traj.dcd 0]
vmdance -mol $ma -sel all -k 2 -kinit KmeansPP -quiet 1
set sa [file join $A a.vmdance]
vmdance session save $sa
vmdance run clear
cd $here
set w [lindex [::VMDance::Session::load $sa auto] 0]
check "R11: its molecule loaded by relative names, VMD's folder changed: taken, no warning (\"not its files\")" [expr {
    [dict get [${R}::request] mol] == $ma && ![llength $w] && [molinfo num] == 1}]
fx_clear
cd $B
set mb [fx_load sys.pdb traj.dcd 0]
cd $A
set ma [fx_load sys.pdb traj.dcd 0]
cd $B
set w [lindex [::VMDance::Session::load $sa auto] 0]
cd $here
check "  two replicas by the same relative names, VMD in the other's folder: the one with the frames (the first was taken, refused)" [expr {
    [dict get [${R}::request] mol] == $ma && ![llength $w] && ![catch {vmdance goto 0}] && [molinfo num] == 2}]
fx_clear

# --- R13: frames deleted after the last picked one --------------------------------------------
set m [load_system two_state]
vmdance pick -mol $m -sel all -method outliers -param 4
set pf [vmdance pick show]
set top [::tcl::mathfunc::max {*}$pf]
if {$top < 23} {
    animate delete beg [expr {$top + 1}] end 23 $m
    set out12 [file join $H r12.pdb]
    check "R13: frames deleted after the last picked one ($top): the picks still saved, gone to and drawn (refused)" [expr {
        [${R}::picks_ok] && ![catch {vmdance pick goto [lindex $pf 0]}] && ![catch {vmdance pick save $out12}] &&
        ![dict exists [vmdance draw -picks 1] note]}]
    vmdance draw -picks 0
    animate delete beg 0 end 0 $m
    check "  a frame deleted before them: refused" [expr {![${R}::picks_ok]}]
} else {
    skip "R13: frames deleted after the last picked one" "the last frame was picked"
}
fx_clear

# --- R10: the PDB's own frame read again: the advice -------------------------------------------
cd $A
set mt [fx_load sys.pdb traj.dcd 1]
vmdance -mol $mt -sel all -k 2 -kinit KmeansPP -quiet 1
set g0 [vmdance goto 0]
set st [file join $A t.vmdance]
vmdance session save $st
cd $here
fx_clear
set mu [fx_load [file join $A sys.pdb] [file join $A traj.dcd] 0]
set w [lindex [::VMDance::Session::load $st auto] 0]
set fix "*delete it (animate delete beg 0 end 0 $mu)"
set ok1 [expr {[string match $fix [err {vmdance goto 0}]] && [string match $fix [err {vmdance frame 3}]] &&
    [string match $fix [err {vmdance userfield}]] && [string match "$fix: the clusters are not drawn" [::VMDance::_get [vmdance draw -reps 1] note ""]] &&
    [string match $fix [err {vmdance export $H -prefix x -items representatives}]] && [string match $fix [err {vmdance prime}]] &&
    ![string match "*open the session again*" [join $w]]}]
vmdance draw -reps 0
animate delete beg 0 end 0 $mu
check "R10: the user's molecule with the PDB's own frame: every refusal says to delete it (\"cluster it again\", \"make it again\"); deleted, every answer back" [expr {
    $ok1 && ![catch {vmdance goto 0} r] && $r == $g0 && ![catch {vmdance prime}]}]
fx_clear

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_fx_g5 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
