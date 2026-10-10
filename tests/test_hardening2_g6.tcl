# What the review found with many clusters (g6: thousands of clusters, which
# eQUAL makes at a small radius), kept from coming back (text mode, the fake
# backend):
#   F04  the plugin's measures after the backend (every frame against every
#        cluster, every two clusters) let VMD work and say how far they are:
#        Cancel during them stops the job (it was taken once the job had
#        ended, and the run published); the console says where a long step
#        is (it stayed at 97% for minutes)
#   F06  the distances between the clusters (k × k) are made for
#        Measure::maxk clusters or fewer (thousands took gigabytes, kept
#        until VMD quits), each pair once and rounded as it is made
#   F10  the tree of the mean structures and the distances are refused above
#        maxk, saying why; an export's defaults leave them and the
#        transitions (k² rows: written when named) out
#   F57  one lag of the transitions kept, not a k × k matrix per lag asked
#   F66  a selection change makes the overlay again, not every
#        representation (seconds with a thousand representatives); with
#        frames typed, nothing
# (F65 and F29, and the window's parts of F04, F10, F57 and F66, are
# test_gui's.) And what the review of these fixes found: the MSDs between
# the clusters counted (each pair once, not every pair twice); a session made
# before with the distances of more than maxk clusters (left out as it
# opens: they were exported by default); elbow load, sweep load and session
# import said nothing on the console for the minutes the measures take.
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_g6.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_g6]
file delete -force $H
file mkdir $H

# The plugin's representations of some roles on molecule m: their names.
proc g6_reps {m roles} {
    lmap e $::VMDance::Viz::owned {expr {[lindex $e 0] == $m && [lindex $e 2] in $roles ? [lindex $e 1] : [continue]}}
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set M ::VMDance::Measure
use_fake
fake_env
set m [load_system 3ptb]

# --- F04: the measures breathe, say how far they are, and stop on Cancel -----------------
# (each distance made slower, 2 ms: the measures take long whatever the load)
rename ${M}::msd ${M}::msd_g6
set ::g6_msd 0
proc ${M}::msd {a b natoms} { incr ::g6_msd; after 2; ::VMDance::Measure::msd_g6 $a $b $natoms }
set req [::VMDance::Job::check_cluster [list mol $m sel "name CA" k 20 params {kinit KmeansPP}]]
set ::g6_said {}
proc g6_progress {f msg} {
    lappend ::g6_said $msg
    if {[string match "*distances between the clusters*" $msg] && ![::VMDance::Job::cancel]} { lappend ::g6_said "cancel refused" }
}
set nruns [llength [${R}::run_list]]
set ::bgdone ""
::VMDance::Job::start cluster $req g6_progress {apply {{st r} { set ::bgdone [list $st $r] }}}
set id [after 120000 {set ::bgdone timeout}]
while {$::bgdone eq ""} { vwait ::bgdone }
after cancel $id
# (100 frames from their representative, then 210 pairs of each kind: 520)
set made $::g6_msd
check "F04: the distances between the clusters say how far they are, and Cancel during them stops the job ($made of 520 distances made; [lindex $::bgdone 0])" [expr {
    [lindex $::bgdone 0] eq "cancelled" && [llength [lsearch -all $::g6_said "*distances between the clusters (* of 20)"]] &&
    "cancel refused" ni $::g6_said && $made < 520 && ![::VMDance::Job::busy] && [llength [${R}::run_list]] == $nruns}]
rename ${M}::msd ""
rename ${M}::msd_g6 ${M}::msd
# the console: every 10% and every 10 s
proc ::VMDance::puts {args} { lappend ::g6_console [lindex $args end] }
set ::g6_console {}
unset -nocomplain ::VMDance::last_pct
::VMDance::_console_progress 0.97 "measuring the clusters"
::VMDance::_console_progress 0.98 "measuring the clusters (frame 50 of 100)"
set ::VMDance::last_said [expr {[clock milliseconds] - 11000}]
::VMDance::_console_progress 0.99 "measuring the distances between the clusters (5 of 20)"
rename ::VMDance::puts ""
check "F04: the console says where a long step is (every 10 s, within the same 10%)" [expr {[llength $::g6_console] == 2 &&
    [string match "*97%*measuring the clusters" [lindex $::g6_console 0]] && [string match "*distances between the clusters (5 of 20)" [lindex $::g6_console 1]]}]
# each pair measured once: the numbers of every pair measured, and (the
# review: the numbers alone pass with every pair measured twice) the MSDs
# made counted
rename ${M}::msd ${M}::msd_g6
set ::g6_msd 0
proc ${M}::msd {a b natoms} { incr ::g6_msd; ::VMDance::Measure::msd_g6 $a $b $natoms }
set req [::VMDance::Job::check_cluster [list mol $m sel "name CA" k 6 params {kinit KmeansPP}]]
set a [::VMDance::Job::run cluster $req]
set made $::g6_msd
rename ${M}::msd ""
rename ${M}::msd_g6 ${M}::msd
set rows [::VMDance::Coords::rows [::VMDance::Coords::cached $req]]
set n [dict get $a natoms]
set k [dict get $a nclusters]
set sums [lrepeat $k ""]; set cnt [lrepeat $k 0]
foreach r $rows l [dict get $a labels] {
    if {$l < 0} continue
    if {[lindex $sums $l] eq ""} { lset sums $l $r } else { lset sums $l [vecadd [lindex $sums $l] $r] }
    lset cnt $l [expr {[lindex $cnt $l] + 1}]
}
set er {}; set ec {}
for {set p 0} {$p < $k} {incr p} {
    set ra {}; set ca {}
    for {set q 0} {$q < $k} {incr q} {
        set rp [lindex [dict get $a representatives] $p]; set rq [lindex [dict get $a representatives] $q]
        lappend ra [if {$rp < 0 || $rq < 0} { list } else { format %.6g [${M}::msd [lindex $rows $rp] [lindex $rows $rq] $n] }]
        lappend ca [if {![lindex $cnt $p] || ![lindex $cnt $q]} { list } else { format %.6g [${M}::msd \
            [vecscale [expr {1.0 / [lindex $cnt $p]}] [lindex $sums $p]] [vecscale [expr {1.0 / [lindex $cnt $q]}] [lindex $sums $q]] $n] }]
    }
    lappend er $ra; lappend ec $ca
}
check "F04/F06: each pair measured once, the same numbers as every pair measured" [expr {
    [dict get $a measures rep_msd] eq $er && [dict get $a measures centroid_msd] eq $ec}]
# (a frame from its representative, then each pair p <= q of representatives
# and of mean structures)
set reps [dict get $a representatives]
set nf [llength [lmap l [dict get $a labels] {expr {$l >= 0 && [lindex $reps $l] >= 0 ? 1 : [continue]}}]]
set nr [llength [lmap r $reps {expr {$r >= 0 ? 1 : [continue]}}]]
set nc [llength [lmap x $cnt {expr {$x > 0 ? 1 : [continue]}}]]
set want [expr {$nf + $nr * ($nr + 1) / 2 + $nc * ($nc + 1) / 2}]
check "  review: $made MSDs made for $k clusters of $nf frames, $want with each pair once ([expr {$nf + $nr * $nr + $nc * $nc}] with every pair)" [expr {
    $k == 6 && $made == $want}]

# --- F06: no distances between the clusters above maxk ------------------------------------
# (400 frames of 2 atoms, each its own cluster: 400 > maxk, read from the file)
set f [file join $H rows.csv]
set fh [open $f w]
for {set i 0} {$i < 400} {incr i} { puts $fh [join [list [expr {0.1 * $i}] 0.0 0.0 0.0 [expr {0.01 * $i * $i}] 1.0] ,] }
close $fh
set c [dict create mol -1 key {} csv $f natoms 2]
set ids {}; for {set i 0} {$i < 400} {incr i} { lappend ids $i }
set t0 [clock milliseconds]
set mm [${M}::compute $c $ids 400 $ids 2]
check "F06: 400 clusters (more than maxk, [set ${M}::maxk]): the distances between them not made ([expr {[clock milliseconds] - $t0}] ms), the frames' measures made" [expr {
    [dict get $mm rep_msd] eq "" && [dict get $mm centroid_msd] eq "" && [llength [dict get $mm frame_msd]] == 400 && [lindex [dict get $mm silhouette] 7] == 0}]
# a whole clustering above it (maxk lowered: 5 clusters)
set ${M}::maxk 3
vmdance -mol $m -sel "name CA" -k 5 -quiet 1
set a $::VMDance::Results::A
check "F06: a clustering above maxk: no distances between its clusters, the result whole" [expr {[${R}::nclusters] == 5 &&
    [dict get $a measures rep_msd] eq "" && [dict get $a measures centroid_msd] eq "" && [llength [dict get $a measures silhouette]] == 100 &&
    ![catch {${R}::check $a}]}]
check "F06: vmdance distances says why, and what to change" [string match \
    "vmdance distances: the distances between the clusters are measured for 3 clusters or fewer, and this clustering has 5: cluster into fewer*" \
    [err {vmdance distances}]]
check "F10: vmdance tree (the mean structures') says why" [string match \
    "vmdance tree: the tree of the clusters' mean structures is made for 3 clusters or fewer, and this clustering has 5*" [err {vmdance tree}]]
set files [vmdance export [file join $H big]]
check "F10: an export's defaults leave the k × k tables and the tree out ([llength $files] files)" [expr {
    ![llength [lsearch -all -regexp $files {_(transitions|distances|tree)\.csv$}]] &&
    [llength [lsearch -all -regexp $files {_(summary\.txt|clusters\.csv|labels\.csv|silhouette\.csv)$}]] == 4}]
set tf [vmdance export [file join $H big] -prefix named -items transitions]
check "  the transitions written when named (k² rows)" [expr {[llength [csv_rows [lindex $tf 0]]] == 1 + 25}]
check "  the distances, or the tree, named: refused, saying why, nothing written" [expr {
    [string match "*distances between the clusters are measured for 3 clusters or fewer*" [err {vmdance export [file join $H big3] -items distances}]] &&
    [string match "*tree of the clusters' mean structures is made for 3 clusters or fewer*" [err {vmdance export [file join $H big3] -items tree}]] &&
    ![file exists [file join $H big3]]}]
check "  the table alone (the window's plot data) refused too" [string match "*measured for 3 clusters or fewer*" [err {::VMDance::Export::table_distances}]]
set sf [file join $H big.vmdance]
vmdance session save $sf
vmdance run clear
vmdance session load $sf -mol none
check "F06: a session keeps a clustering without its distances" [expr {[${R}::nclusters] == 5 && [${R}::measure rep_msd] eq "" &&
    [string match "*measured for 3*" [err {vmdance distances}]]}]
vmdance -mol $m -sel "name CA" -algorithm helm -k 4 -initial 8 -initial-kinit KmeansPP -quiet 1
check "F10: HELM's tree (its merges) is made above maxk too" [expr {[${R}::nclusters] == 4 && [dict get [vmdance tree] kind] eq "helm" &&
    "tree" in [lmap f [vmdance export [file join $H helm]] {expr {[string match *_tree.csv $f] ? "tree" : [continue]}}]}]
vmdance run clear
set ${M}::maxk 300
vmdance -mol $m -sel "name CA" -k 5 -quiet 1
set a $::VMDance::Results::A
set b $a
dict set b measures rep_msd {}
check "F06: at maxk or fewer, k × k (none is refused)" [expr {[llength [dict get $a measures rep_msd]] == 5 &&
    [string match "*the measure rep_msd is not 5 × 5*" [err {${R}::check $b}]] && [llength [vmdance distances]] == 4 &&
    [llength [lsearch -all -regexp [vmdance export [file join $H small]] {_(transitions|distances|tree)\.csv$}]] == 3}]
unset b
# (the review: a session made before 8b2e016 keeps the distances of more
# than maxk clusters; they were exported by default, and given by
# vmdance distances while the plot and the tree said they were not made.
# One saved at maxk 300 and opened at maxk 3 is such a session.)
set of [file join $H old.vmdance]
vmdance session save $of
set ${M}::maxk 3
vmdance session load $of
set files [vmdance export [file join $H old]]
check "review (F06/F10): a session made before, 5 × 5 distances of 5 clusters, opened at maxk 3: left out as it opens, so not exported, and refused, saying why" [expr {
    [${R}::nclusters] == 5 && [${R}::measure rep_msd] eq "" && [${R}::measure centroid_msd] eq "" &&
    "distances" ni [::VMDance::Export::defaults] && [llength $files] >= 6 && ![llength [lsearch -all -regexp $files {_distances\.csv$}]] &&
    [string match "vmdance distances: the distances between the clusters are measured for 3 clusters or fewer*" [err {vmdance distances}]]}]
set ${M}::maxk 300
vmdance session load $of
check "  opened at maxk 300, the same session keeps them" [expr {[llength [${R}::measure rep_msd]] == 5 && [llength [vmdance distances]] == 4}]

# --- the review (F04): elbow load, sweep load and session import say how far a long step is --------
# (they ran their job with no progress: the console said nothing for the
# minutes the measures of thousands of clusters take. A step made long: 11 s
# gone by as the measures start; a quick one says nothing, as before)
rename ::VMDance::Job::_result ::VMDance::Job::_result_g6
proc ::VMDance::Job::_result {args} {
    if {$::g6_long} { set ::VMDance::last_said [expr {[clock milliseconds] - 11000}] }
    ::VMDance::Job::_result_g6 {*}$args
}
proc ::VMDance::puts {args} { lappend ::g6_console [lindex $args end] }
set ::g6_long 0
vmdance elbow -mol $m -sel "name CA" -ks {2 3} -kinit KmeansPP -quiet 1
vmdance sweep -mol $m -sel "name CA" -ks {2 3} -seedings KmeansPP -quiet 1
set ::g6_console {}
vmdance elbow load 3
vmdance sweep load 1
set quick $::g6_console
set ::g6_long 1
set said {}
foreach cmd {{vmdance elbow load 2} {vmdance sweep load 0}} {
    set ::g6_console {}
    {*}$cmd
    lappend said [lindex $::g6_console 0]
}
set t [load_system two_state]
set ::g6_console {}
vmdance session import [file join $::fixtures old_kmeans.mdance]
lappend said [lindex $::g6_console 0]
set ::g6_long 0
rename ::VMDance::puts ""
rename ::VMDance::Job::_result ""
rename ::VMDance::Job::_result_g6 ::VMDance::Job::_result
mol delete $t
check "review (F04): elbow load, sweep load and session import: a long step says how far it is ([join $said { | }]), a quick one nothing ([llength $quick] lines)" [expr {
    [llength [lsearch -all $said "VMDance)*%  measuring the clusters"]] == 3 && ![llength $quick]}]

# --- F57: one lag of the transitions kept -------------------------------------------------------
foreach l {1 2 3 4 5 6 7 8 9 10} { vmdance transitions -lag $l }
check "F57: lags asked one after the other: one lag's matrix kept ([llength [array names ${R}::memo transitions*]])" [expr {
    [llength [array names ${R}::memo transitions*]] == 1}]
set ok 1
foreach l {5 7 5 1} {
    if {[vmdance transitions -lag $l -counts 1] ne [${M}::transitions [${R}::labels] [${R}::nclusters] $l]} { set ok 0 }
}
check "  each lag's matrix its own, asked again or not" $ok

# --- F66: a selection change makes the overlay again, not every representation ----------------
set t [load_system two_state]
vmdance -mol $t -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance select 1
vmdance draw -colour 1 -reps 1 -overlay 1 -top 3
set keep [g6_reps $t {colour reps}]
set ov [g6_reps $t overlay]
vmdance select 2
set ov2 [g6_reps $t overlay]
check "F66: a selection change: the representatives and the colouring left as they are, the overlay made again" [expr {
    [llength $keep] == 4 && [g6_reps $t {colour reps}] eq $keep && [llength $ov2] == 1 && $ov2 ne $ov &&
    [mol drawframes $t [mol repindex $t [lindex $ov2 0]]] eq [join [${R}::top 2 3] ,]}]
set hid [lindex [g6_reps $t reps] 0]
mol showrep $t [mol repindex $t $hid] off
vmdance select 0
set i [mol repindex $t $hid]
check "  a representative the user hid stays hidden" [expr {$i >= 0 && ![mol showrep $t $i]}]
if {$i >= 0} { mol showrep $t $i on }
vmdance draw -frames "0-2,20"
set all [g6_reps $t {colour reps overlay}]
vmdance select 1
check "  an overlay of frames typed: a selection change makes nothing again" [expr {[g6_reps $t {colour reps overlay}] eq $all}]
vmdance draw -frames ""
mol delrep [mol repindex $t [lindex [g6_reps $t reps] 0]] $t
set n [molinfo $t get numreps]
vmdance draw
check "  vmdance draw with nothing changed draws again (a representation deleted by hand is back)" [expr {[molinfo $t get numreps] == $n + 1}]
# (frames deleted under the drawing: the selection change still withdraws all)
animate delete beg 0 end 0 $t
after cancel $::VMDance::Viz::pending
vmdance select 2
check "  the frames deleted under the drawing: a selection change withdraws it all, not the overlay alone" [expr {
    ![llength [g6_reps $t {colour reps overlay}]]}]
vmdance draw -colour 0 -reps 0 -overlay 0
mol delete $t

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_g6 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
