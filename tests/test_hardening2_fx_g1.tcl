# What the review of the sessions' fixes (security and limits, g1) found,
# each kept from coming back (text mode, the fake backend):
#   F50  a session's values are counted whatever separates them: a vertical
#        tab or a form feed (which Tcl's lists split on) and an escape (\n
#        in a word) no longer pass the value cap; a list of numbers is
#        counted whatever its white space (a doubled space, a tab or a line
#        end skipped the count); frames whose digits are too few for
#        different numbers (a value repeated) are refused unread; a scan's
#        records and each record, a failed record's sizes and the picks'
#        rows are counted before they are made (40 KB files allocated GBs)
#   F05  a save refused names what to drop, the scans and the picks too
#        (elbow clear, sweep clear, pick clear: new), says when one part
#        alone is too large (export its tables) and how to raise the limit;
#        a session over the value cap says how to open it; the numbers
#        never read "50 million, more than the 50 million"
#   N01  a molecule under a folder named with ' or & reloads (the shell
#        characters refuse only a reader that gives the name to a shell:
#        parm, parm7, netcdf), and the message names the path
#   F37  a DESRES trajectory's folder holding a FIFO or a device (or a link
#        to one, or a folder of them) no longer blocks Open, nor does a FIFO
#        beside a file whose reader opens files beside it (VASP's POTCAR)
#   F49  an MDANCE plugin session's representatives and cluster MSDs are
#        read as they are (010 was frame 8; NaN a bare domain error)
# (test_hardening2's weak checks, Results::meta's, N01's parm7 and F37's
# /dev/zero, are made able to fail there.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_fx_g1.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_fx_g1]
file delete -force $H
file mkdir $H

proc rss_mb {} {
    if {[catch {open /proc/self/status} fh]} { return -1 }
    set t [read $fh]; close $fh
    if {[regexp {VmHWM:\s+(\d+)} $t -> h]} { return [expr {$h / 1024}] }
    return -1
}
proc write_session {f d} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "VMDanceSession 1\n$d\n"] -level 9]
    close $fh
}
# A session written, then opened without its molecule: {error growth},
# growth the MB the high-water mark rose by (a list of 20M values made costs
# over 2 GB; the text itself, 40 to 80 MB, some hundreds).
proc bomb {name d} {
    set f [file join $::H $name.vmdance]
    write_session $f $d
    set r0 [rss_mb]
    set e [err [list vmdance session load $f -mol none]]
    list $e [expr {[rss_mb] - $r0}]
}
proc bounded {grew} { expr {$grew < 1000} }
proc load_warn {f {mol load}} {
    lindex [lindex [::VMDance::Session::load $f $mol] 0] 0
}
proc with_molecule {d rec} {
    set runs [dict get $d runs]
    set a [lindex $runs 0 2]
    dict set a molecule $rec
    lset runs 0 2 $a
    dict set d runs $runs
    return $d
}
proc session_values {f} {
    set fh [open $f rb]; zlib push gunzip $fh; set raw [read $fh]; close $fh
    ::VMDance::Session::_values $raw
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set S ::VMDance::Session
use_fake
fake_env
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance elbow -mol $m -sel all -ks {2 3} -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method diversity -param 10
set base [file join $H base.vmdance]
vmdance session save $base
set bd [${S}::read_file $base]
set rec [dict remove [dict get [lindex [dict get $bd runs] 0 2] molecule] paths]
set n20 20000000

# --- F50: every separator counted, every list counted before it is made --------------------------
check "F50: _values counts the vertical tab, the form feed and an escape as separators" [expr {
    [${S}::_values "0\v1\f2 3\t4\r5\n6"] == 6 && [${S}::_values "0\\n1\\n2"] == 2}]
check "  _count counts a list of numbers whatever its white space; \"\" for braces, quotes, escapes" [expr {
    [${R}::_count "0\v1\f2"] == 3 && [${R}::_count "  0  1\t\t2\n"] == 3 && [${R}::_count ""] == 0 &&
    [${R}::_count "{0} 1"] eq "" && [${R}::_count "0\\ 1"] eq ""}]
set l1 "{a {b c}} \"d e\" f\\ g"; set l2 "\{a\\\} b\} c"; set l3 "{a}b"; set l4 "\{a"
check "  _elements counts a list's values as Tcl does, at most most + 1, without making them" [expr {
    [${R}::_elements $l1 10] == 3 && [${R}::_elements $l2 10] == 2 &&
    [${R}::_elements "a b c d e" 2] == 3 && [${R}::_elements $l3 10] eq "" && [${R}::_elements $l4 10] eq ""}]
# the original bomb (20M frames in a 40 KB file), its separators changed:
# a doubled space, a leading space, a tab, form feeds (the count was skipped,
# and the frames made whole)
set a [lindex [dict get $bd runs] 0 2]
foreach {name fr} [list double "0  [string repeat {0 } [expr {$n20 - 1}]]" lead " [string repeat {0 } $n20]" \
        tab [string repeat "0\t" $n20] ff [string repeat "0\f" $n20]] {
    dict set a frames $fr
    set d $bd; dict set d runs [list [list 1 x $a]]
    lassign [bomb frames_$name $d] e grew
    check "F50: 20M frames separated ($name): refused on their count, before they are made (+$grew MB)" [expr {
        [string match "*labels has 24 values, not 20000000*" $e] && [bounded $grew]}]
    unset d fr
}
# frames and labels whose counts agree, separated by vertical tabs (both
# counted 1 before; the frames were then made)
dict set a frames [string repeat "0\v" $n20]
dict set a labels [string repeat "0\v" $n20]
set d $bd; dict set d runs [list [list 1 x $a]]
lassign [bomb fc $d] e grew
check "F50: frames and labels of 20M values each (\\v): the frames refused unread, too few digits (+$grew MB)" [expr {
    [string match "*frames are not in increasing order (their 20000000 values have fewer digits than 0 to 19999999)*" $e] && [bounded $grew]}]
unset a d
# the value cap sees the form feed: a consistent 5100 × 5100 session of
# form-feed separated values (52 million; 15 thousand counted before)
set a [lindex [dict get $bd runs] 0 2]
set k 5100
set lab [join [lrepeat $k 0] \f]
set rows [lrepeat $k $lab]
dict set a nclusters $k
dict set a labels $lab; dict set a sizes $lab; dict set a representatives $lab; dict set a msd $lab
dict set a frames [join [lrepeat $k 3] \f]
dict set a measures rep_msd $rows; dict set a measures centroid_msd $rows
set d $bd; dict set d runs [list [list 1 x $a]]
set f [file join $H kkff.vmdance]
write_session $f $d
unset a d rows lab
set r0 [rss_mb]
set e [err {${S}::read_file $f}]
check "F50: a consistent 5100×5100 session separated by form feeds: refused by the value cap (+[expr {[rss_mb] - $r0}] MB)" [expr {
    [string match "*holds 52 million values, more than the 50 million*" $e] && [bounded [expr {[rss_mb] - $r0}]]}]
# a scan's frames, a value repeated
set e0 [dict get $bd elbow]
set d [dict replace $bd elbow [dict replace $e0 frames [string trimright [string repeat "0 " $n20]]]]
lassign [bomb elbow_frames $d] e grew
check "F50: an elbow's frames of 20M zeros: refused unread (+$grew MB)" [expr {
    [string match "*the elbow's frames are not in increasing order (their 20000000 values have fewer digits*" $e] && [bounded $grew]}]
# the picks' frames, the same
set p0 [dict get $bd picks]
set d [dict replace $bd picks [dict replace $p0 frames [string trimright [string repeat "0 " $n20]]]]
lassign [bomb picks_frames $d] e grew
check "F50: the picks' frames of 20M zeros: refused unread (+$grew MB)" [expr {
    [string match "*the frame picks' frames are not in increasing order (their 20000000*" $e] && [bounded $grew]}]
# 20M records, of an elbow of 10000 frames (a bound made of the frames let
# them all be made: 200 × 10 values a frame)
set fr10k {}; for {set i 0} {$i < 10000} {incr i} { lappend fr10k $i }
set big [dict replace [dict remove $e0 shape] frames $fr10k records [string trimright [string repeat "{} " $n20]]]
set d [dict replace $bd elbow $big]
lassign [bomb elbow_records $d] e grew
check "F50: an elbow of 20M records: refused on their count, before they are made (+$grew MB)" [expr {
    [string match "*the elbow has more records than a scan makes (at most 200)*" $e] && [bounded $grew]}]
# one record of 20M values
set d [dict replace $bd elbow [dict replace $e0 records [list [string trimright [string repeat "k 2 " [expr {$n20 / 2}]]]]]]
lassign [bomb elbow_record $d] e grew
check "F50: an elbow record of 20M values: refused before it is made (+$grew MB)" [expr {
    [string match "*the elbow's record 1 is corrupt*" $e] && [bounded $grew]}]
# a failed record with 20M sizes (it was kept, 3 GB resident)
set r1 [lindex [dict get $e0 records] 0]
set r1 [dict replace $r1 status error message failed nclusters "" clustering {} sizes [string trimright [string repeat "0 " $n20]]]
set d [dict replace $bd elbow [dict replace $e0 records [list $r1]]]
lassign [bomb failed_sizes $d] e grew
check "F50: a failed elbow record with 20M sizes: refused (a size a cluster, none when it failed) (+$grew MB)" [expr {
    [string match "*the elbow's record 1 is corrupt*" $e] && [bounded $grew]}]
check "  a failed record as the plugin writes it still loads" [expr {
    [err [list ${S}::check_scan [dict replace $e0 records [list [dict replace $r1 sizes {}]]] elbow]] eq ""}]
# the picks' rows and VMD frames, 20M each (they were kept, 4 GB resident)
set z [string trimright [string repeat "0 " $n20]]
set d [dict replace $bd picks [dict replace $p0 rows $z vmdframes $z]]
lassign [bomb picks_rows $d] e grew
check "F50: picks of 20M rows on 24 frames: refused on their count (+$grew MB)" [expr {
    [string match "*the frame picks have more rows (20000000) than frames (24)*" $e] && [bounded $grew]}]
unset d z big e0 p0 r1
check "  the session they were made from still opens" [expr {[err {vmdance session load $base -mol none}] eq ""}]
vmdance run clear

# --- F05: what to drop, the scans too; the limit raised -------------------------------------------
check "F05: the numbers compared differ in what is said (never \"50 million, more than the 50 million\")" [expr {
    [${S}::_mb 50198363 50000000] eq "50.2" && [${S}::_mb 50000000 50198363] eq "50.0" && [${S}::_mb 20000] eq "0.02"}]
foreach x [molinfo list] { mol delete $x }
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance sweep -mol $m -sel all -algorithms {kmeans} -ks {2 3 4 5 6} -seedings {KmeansPP} -quiet 1
vmdance elbow -mol $m -sel all -ks {2 3} -kinit KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method diversity -param 10
set sf [file join $H scans.vmdance]
vmdance session save $sf
set fh [open $sf rb]; set sf_bytes [read $fh]; close $fh
set nall [session_values $sf]
set nsweep [${S}::_values $::VMDance::Results::sweep]
set nrun [${S}::_values [zlib decompress [lindex $::VMDance::Results::runs 0 2]]]
set ${S}::max_values [expr {$nall - 1}]
set e [err {vmdance session save $sf}]
set fh [open $sf rb]; set now [read $fh]; close $fh
check "F05: a session over the value cap whose sweep holds the most: refused, the file as it was" [expr {
    [string match "*nothing was written*" $e] && $now eq $sf_bytes && $nsweep > $nrun}]
check "  it says to clear the sweep first, how, and the scans' and picks' shares" [expr {
    [string match "*. Clear the sweep first (vmdance sweep clear)*" $e] && [string match "*clear the elbow scan (vmdance elbow clear)*" $e] &&
    [string match "*: the sweep * million values*" $e] && [string match "*the frame picks * million values*" $e]}]
check "  and how to raise the limit, here and where it is opened" [string match "*set ::VMDance::Session::max_values $nall;*" $e]
# the sweep alone over the cap: its tables can be exported, not kept
set ${S}::max_values [expr {$nsweep - 1}]
set e [err {vmdance session save $sf}]
check "F05: the sweep alone over the cap: said, with how to export its tables" [expr {
    [string match "*The sweep alone is more than a session can hold, and cannot be kept in one: export its tables first (vmdance export dir -items sweep)*" $e] &&
    [err {vmdance export [file join $H sweepout] -items sweep}] eq "" && [llength [glob -nocomplain -directory [file join $H sweepout] *sweep*]]}]
# the scans and the picks cleared: the save then fits
set ${S}::max_values [expr {$nall - 1}]
vmdance sweep clear
vmdance elbow clear
vmdance pick clear
check "F05: sweep clear, elbow clear, pick clear: the scans and the picks gone" [expr {
    ![dict size $::VMDance::Results::sweep] && ![dict size $::VMDance::Results::elbow] && ![dict size $::VMDance::Results::picks] &&
    [string match "*no sweep*" [err {vmdance sweep show}]] && [string match "*no elbow scan*" [err {vmdance elbow show}]] &&
    [string match "usage: *" [err {vmdance sweep clear x}]]}]
check "  and the save that was refused succeeds, and reads back" [expr {
    [err {vmdance session save $sf}] eq "" && [err {${S}::read_file $sf}] eq ""}]
# a session over the cap where it is opened: said how to open it
set ${S}::max_values 50000000
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance session save $sf
set nv [session_values $sf]
set ${S}::max_values [expr {$nv - 1}]
set e [err {${S}::read_file $sf}]
check "F05: a session over the value cap where it is opened: says how to raise it" [string match "*to open it, raise the limit: set ::VMDance::Session::max_values $nv)*" $e]
set ${S}::max_values $nv
check "  and it opens once raised as said" [expr {[err {${S}::read_file $sf}] eq ""}]
set ${S}::max_values 50000000
vmdance run clear

# --- N01: the shell characters refuse only what gives the name to a shell ------------------------
foreach x [molinfo list] { mol delete $x }
foreach dir {"o'brien data" "R&D"} {
    set dd [file join $H $dir]
    file mkdir $dd
    file copy -force [file join $::fixtures two_state.pdb] $dd
    set m [mol new [file join $dd two_state.pdb] waitfor all]
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    set sf [file join $H n01.vmdance]
    vmdance session save $sf
    mol delete $m
    vmdance run clear
    vmdance session load $sf
    set mm [dict get [vmdance info] molid]
    check "N01: a molecule in the folder \"$dir\" reloads with its session" [expr {
        $mm >= 0 && [molinfo $mm get numatoms] == 8 && [string first $dd [lindex [molinfo $mm get filename] 0 0]] >= 0}]
    foreach x [molinfo list] { mol delete $x }
    vmdance run clear
}
set p7 [file join $H "R&D" top.parm7]
set fh [open $p7 w]; puts $fh x; close $fh
set w [${S}::_unloadable [list $p7] {parm7}]
check "N01: a parm7 file there (its reader gives the name to a shell): refused, the path named, what to do" [expr {
    [string match "the name \"*R&D/top.parm7\" has a character a shell would act on, and reading it as parm7 gives the name to one (rename it, or its folder,*" $w]}]

# --- F37: a DESRES folder, or a reader's neighbour, that is a FIFO or a device ---------------------
if {[catch {exec mkfifo [file join $H fifo_probe]}]} {
    skip "F37: a DESRES folder holding a FIFO does not hang Open" "mkfifo is not available"
} else {
    file delete [file join $H fifo_probe]
    set dtr [file join $H trap.dtr]
    file mkdir $dtr
    set fh [open [file join $dtr metadata] w]; puts $fh x; close $fh
    set fh [open [file join $dtr clickme.dtr] w]; puts $fh x; close $fh
    exec mkfifo [file join $dtr timekeys]
    set d [with_molecule $bd [dict replace $rec files [list $dtr] types {dtr}]]
    write_session [file join $H dtr.vmdance] $d
    # (a bounded writer: an unfixed load returns, its warning another)
    exec sh -c {sleep 3; : <> "$0"} [file join $dtr timekeys] &
    set w [load_warn [file join $H dtr.vmdance]]
    check "F37: a .dtr folder holding a FIFO: not loaded, said, never opened" [expr {
        [dict get [${R}::request] mol] == -1 && [string match "*timekeys\" with it, a FIFO or a device*" $w]}]
    check "  the clickme.dtr in it: refused the same" [string match "*a FIFO or a device*" [${S}::_unloadable [list [file join $dtr clickme.dtr]] {dtr}]]
    set clean [file join $H clean.dtr]
    file mkdir [file join $clean sub]
    set fh [open [file join $clean sub frame000] w]; puts $fh x; close $fh
    check "  a .dtr folder of files: taken" [expr {[${S}::_unloadable [list $clean] {dtr}] eq ""}]
    exec mkfifo [file join $clean sub frame001]
    check "  one with a FIFO in a folder of it: refused" [string match "*frame001\" with it, a FIFO*" [${S}::_unloadable [list $clean] {dtr}]]
    file delete [file join $clean sub frame001]
    set far [file join $H far]
    file mkdir $far
    exec mkfifo [file join $far timekeys]
    file link -symbolic [file join $clean hashed] $far
    check "  one with a link to a folder holding a FIFO: refused (a reader follows it)" [string match "*a FIFO or a device*" [${S}::_unloadable [list $clean] {dtr}]]
    file delete [file join $clean hashed]
    file link -symbolic [file join $clean timekeys] /dev/zero
    check "  one with a link to /dev/zero: refused" [string match "*a FIFO or a device*" [${S}::_unloadable [list $clean] {dtr}]]
    file delete [file join $clean timekeys]
    file link -symbolic [file join $clean loop] $clean
    check "  one with a link to itself: looked at once, taken" [expr {[${S}::_unloadable [list $clean] {dtr}] eq ""}]
    # VASP's readers open the POTCAR beside the file named
    set vasp [file join $H vasp]
    file mkdir $vasp
    set fh [open [file join $vasp POSCAR] w]; puts $fh x; close $fh
    check "F37: a POSCAR in a folder of files: taken" [expr {[${S}::_unloadable [list [file join $vasp POSCAR]] {POSCAR}] eq ""}]
    exec mkfifo [file join $vasp POTCAR]
    check "  with a FIFO POTCAR beside it: refused" [string match "*POTCAR\" with it, a FIFO*" [${S}::_unloadable [list [file join $vasp POSCAR]] {POSCAR}]]
}
check "F37: the plugin's own molecule files: taken" [expr {[${S}::_unloadable [list [file join $::fixtures two_state.pdb]] {pdb}] eq ""}]

# --- F49: an MDANCE plugin session's representatives and MSDs as they are --------------------------
foreach x [molinfo list] { mol delete $x }
set m [load_system two_state]
proc old_session {f reps msd} {
    set frames {}; set labels {}
    for {set i 0} {$i < 24} {incr i} { lappend frames $i; lappend labels 0 }
    set r [dict create algorithm kmeans nFrames 8 nClusters 1 labels $labels clusterSizes 24 representatives $reps \
        clusterMSD $msd molid 0 atomsel all frames $frames \
        inputParams {molid 0 atomsel all nclusters 1 metric MSD kinit KmeansPP percentage 10 first 0 last 23 stride 1}]
    set fh [open $f w]
    puts $fh [list mdanceSession 1 savedAt {2026-10-08 17:24:11} molSignature {molKnown 1 molName two_state.pdb molFrames 24} results $r]
    close $fh
}
set of [file join $H one.mdance]
old_session $of 10 0.5
check "F49: an import of one cluster, its representative 10: frame 10" [expr {
    [err {vmdance session import $of -mol $m}] eq "" && [${R}::rep_frame 0] == 10}]
vmdance run clear
old_session $of 010 0.5
set e [err {vmdance session import $of -mol $m}]
check "F49: its representative 010: refused as written (it was read as octal: frame 8)" [expr {
    [string match "*\"010\"*" $e] && ![${R}::has_data]}]
old_session $of 10 NaN
set e [err {vmdance session import $of -mol $m}]
check "F49: its cluster MSD NaN: no MSD, taken unchecked (it failed with a bare domain error)" [expr {
    $e eq "" && [${R}::rep_frame 0] == 10 && ![string match "*domain error*" $e]}]
vmdance run clear

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_fx_g1 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
