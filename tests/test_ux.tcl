# What the review of the window's use added to the core and the command
# (text mode; the real backend):
#   cd <VMDance>; vmd -dispdev text -e tests/test_ux.tcl < /dev/null
# whether the frames look superposed (alignment), the clusters' frames
# along the trajectory (timeline), the silhouette from every frame (against
# every pair, counted here), what an elbow scan suggests and the variance
# its clusters explain, the groups by blocks and how unlike they are, the
# clusters numbered by size, a range for eQUAL's radius, the structures as
# models of a PDB, the summaries of clusters without frames, and help.
source [file join [pwd] tests common.tcl]
package require vmdance
set ::VMDance::Prefs::file ""
set R ::VMDance::Results
set M ::VMDance::Measure

if {[real_cli] eq ""} {
    skip "every check" "no mdance-cli (MDANCE_CLI, or CPP-MDANCE beside the plugin)"
    done
    quit
}
use_cli

proc rows_of {m sel frames} {
    set s [atomselect $m $sel]
    set out {}
    foreach f $frames { $s frame $f; lappend out [concat {*}[$s get {x y z}]] }
    $s delete
    return $out
}
# the squared distance of two rows (not per atom)
proc d2 {a b} { set v [veclength [vecsub $a $b]]; expr {$v * $v} }

set m [load_system 3ptb]
set nf [molinfo $m get numframes]

#---------------------------------------------------------------------------
# Whether the frames look superposed
#---------------------------------------------------------------------------
set al [vmdance alignment -mol $m -sel "protein and name CA"]
check "alignment: a trajectory as it is and fitted, a sample of 21 frames and 223 atoms" [expr {
    [dict get $al frames] == 21 && [dict get $al atoms] == 223 && [dict get $al fitted] <= [dict get $al as_is] + 1e-6}]
check "  one that was aligned looks superposed" [expr {[dict get $al superposed] == 1 && [string match "*they look superposed" [dict get $al words]]}]
# (the same frames, each moved as a rigid body, farther with every frame)
set m2 [load_system 3ptb]
set all [atomselect $m2 all]
for {set f 1} {$f < $nf} {incr f} {
    $all frame $f
    $all move [transmult [transoffset [list [expr {0.4 * $f}] 0 0]] [transaxis z [expr {3.0 * $f}] deg]]
}
$all delete
set al2 [vmdance alignment -mol $m2 -sel "protein and name CA"]
check "  one whose frames tumble does not: far as they are, as near as before once fitted" [expr {
    [dict get $al2 superposed] == 0 && [dict get $al2 as_is] > 5 * [dict get $al2 fitted] &&
    [near [dict get $al2 fitted] [dict get $al fitted] 1e-2] && [string match "*do not look superposed*-fit*" [dict get $al2 words]]}]
check "  the rule: a fit that halves the distance and takes an ångström off" [expr {
    ![::VMDance::Coords::superposed 4.0 1.5] && [::VMDance::Coords::superposed 4.0 3.5] && [::VMDance::Coords::superposed 1.2 0.5]}]
check "  fewer than 3 atoms, or options it does not take: refused" [expr {
    [string match "*fewer than 3 atoms*" [err {vmdance alignment -mol $m -sel "index 0 1"}]] &&
    [string match "*its options are -mol, -sel*" [err {vmdance alignment -mol $m -fit "name CA"}]] &&
    [string match "*its options are*" [err {vmdance alignment -mol $m -k 3}]]}]
# (coordinates that are not numbers: no fit is asked of VMD, whose answer would not be numbers)
set m3 [load_system two_state]
set one [atomselect $m3 "index 0" frame 3]
$one set x Inf
$one delete
check "  a frame whose coordinates are not numbers: an error, VMD's fit not called" [string match "*cannot be fitted*" [err {vmdance alignment -mol $m3 -sel all}]]
mol delete $m3
# the clustering's note
set lines {}
rename puts _puts
proc puts {args} { if {[llength $args] == 1} { lappend ::lines [lindex $args 0] }; _puts {*}$args }
vmdance -mol $m2 -sel "protein and name CA" -k 3 -kinit KmeansPP
set noted [lsearch -glob $lines "VMDance) note: not fitted, and the frames are * Å from the first as they are*do not look superposed*"]
set lines {}
vmdance -mol $m2 -sel "protein and name CA" -k 3 -kinit KmeansPP -fit "protein and name CA"
set fitted [lsearch -glob $lines "*note: not fitted*"]
set lines {}
vmdance -mol $m -sel "protein and name CA" -k 3 -kinit KmeansPP
set aligned [lsearch -glob $lines "*note: not fitted*"]
rename puts {}
rename _puts puts
check "a clustering of frames that are not superposed says so; fitted, or superposed, it does not" [expr {$noted >= 0 && $fitted < 0 && $aligned < 0}]
check "  a fitted run's name says it" [expr {
    [string match "*, fitted" [lindex [lindex [vmdance runs] end-1] 1]] && ![string match "*fitted*" [lindex [lindex [vmdance runs] end] 1]]}]
mol delete $m2

#---------------------------------------------------------------------------
# The clusters' frames along the trajectory
#---------------------------------------------------------------------------
vmdance -mol $m -sel "protein and name CA" -k 4 -kinit KmeansPP -quiet 1
set labels [dict values [vmdance labels]]
set sizes [dict get [vmdance info] sizes]
set t [vmdance timeline -windows 5]
set sum [lrepeat 4 0]
foreach row [dict get $t counts] { set c 0; foreach v $row { lset sum $c [expr {[lindex $sum $c] + $v}]; incr c } }
check "timeline: 5 windows of 20 frames, their counts the clusters' sizes" [expr {
    [dict get $t windows] eq {{0 19} {20 39} {40 59} {60 79} {80 99}} && $sum eq $sizes && [dict get $t noise] eq {0 0 0 0 0}}]
set ok 1
dict for {c f} [dict get $t first_seen] { if {$f ne [lsearch -exact $labels $c]} { set ok 0 } }
check "  first_seen: the first frame of each cluster" $ok
check "  the windows by default: of 10 frames at least" [expr {[llength [dict get [vmdance timeline] windows]] == 10}]
check "  -windows out of range: refused" [expr {
    [string match "*-windows must be a whole number from 1 to the frames clustered (100)*" [err {vmdance timeline -windows 0}]] &&
    [string match "*-windows must be*" [err {vmdance timeline -windows 010}]] && [string match "*-windows must be*" [err {vmdance timeline -windows 101}]]}]
check "  shares: windows as equal as can be, noise apart" [expr {
    [${M}::shares {0 0 1 -1 1 1 0} 2 3] eq {{0 1 {2 0} 0} {2 3 {0 1} 1} {4 6 {1 2} 0}} && [${M}::first_seen {1 1 -1 0 1} 3] eq {3 0 -1}}]

#---------------------------------------------------------------------------
# The silhouette from every frame (of the squared distances)
#---------------------------------------------------------------------------
set frames [dict keys [vmdance labels]]
set rows [rows_of $m "protein and name CA" $frames]
# (as it is defined: a the mean squared distance from the other frames of
# its cluster, b the smallest mean from the frames of another)
set direct {}
set n [llength $rows]
for {set i 0} {$i < $n} {incr i} {
    array unset tot; array unset cnt
    for {set j 0} {$j < $n} {incr j} {
        if {$j == $i} continue
        set l [lindex $labels $j]
        set tot($l) [expr {[info exists tot($l)] ? $tot($l) + [d2 [lindex $rows $i] [lindex $rows $j]] : [d2 [lindex $rows $i] [lindex $rows $j]]}]
        incr cnt($l)
    }
    set own [lindex $labels $i]
    if {![info exists cnt($own)]} { lappend direct 0.0; continue }
    set a [expr {$tot($own) / $cnt($own)}]
    set b Inf
    foreach l [array names cnt] { if {$l != $own} { set b [expr {min($b, $tot($l) / $cnt($l))}] } }
    lappend direct [expr {($b - $a) / max($a, $b)}]
}
set sp [dict values [dict get [vmdance silhouette -kind pairs] frames]]
set worst 0.0
foreach a $sp b $direct { set worst [expr {max($worst, abs($a - $b))}] }
check "silhouette -kind pairs: every frame's, as every pair of frames gives it (worst difference [format %.2g $worst])" [expr {$worst < 1e-4}]
set sc [vmdance silhouette]
check "  the default is the one from the mean structures, as before; both say their kind" [expr {
    [dict get $sc kind] eq "centroid" && [dict get [vmdance silhouette -kind centroid] mean] eq [dict get $sc mean] &&
    [dict get [vmdance silhouette -kind pairs] kind] eq "pairs"}]
set neg 0
foreach v [dict values [dict get $sc frames]] { if {$v < 0} { incr neg } }
check "  from the mean structures k-means has no frame below 0 (each is in the cluster of the nearest mean)" [expr {$neg == 0}]
check "  -kind: one of the two" [string match "*-kind must be centroid*or pairs*" [err {vmdance silhouette -kind classic}]]
# (with many clusters the nearest other cluster is looked for among those
# the triangle inequality leaves: the same number as trying every one)
expr {srand(7)}
set cents {}; set spreads {}
for {set i 0} {$i < 90} {incr i} {
    set c {}
    for {set d 0} {$d < 9} {incr d} { lappend c [expr {20.0 * rand()}] }
    lappend cents $c
    lappend spreads [expr {30.0 * rand()}]
}
set ix [${M}::_near_index $cents [lrepeat 90 1]]
set ws {}; set wmin {}
foreach g $ix {
    set w [lmap id [lindex $g 2] {lindex $spreads $id}]
    lappend ws $w; lappend wmin [::tcl::mathfunc::min {*}$w]
}
set bad 0
for {set t 0} {$t < 200} {incr t} {
    set r {}
    for {set d 0} {$d < 9} {incr d} { lappend r [expr {20.0 * rand()}] }
    set l [expr {int(90 * rand())}]
    set best Inf
    for {set c 0} {$c < 90} {incr c} { if {$c != $l} { set best [expr {min($best, [d2 $r [lindex $cents $c]] + [lindex $spreads $c])}] } }
    if {abs([${M}::_near_pairs $ix $ws $wmin $r $l] - $best) > 1e-9 * $best} { incr bad }
}
check "  among 90 clusters: the smallest squared distance plus spread, as trying every one finds it (200 frames)" [expr {$bad == 0}]
# the export has both
set dir [file join $::out ux_export]
file delete -force $dir
vmdance export $dir -items silhouette
set csv [csv_rows [file join $dir vmdance_silhouette.csv]]
check "  the silhouette's table has both columns" [expr {
    [lindex $csv 0] eq {frame cluster silhouette silhouette_pairs} && [llength $csv] == $n + 1 &&
    [near [lindex $csv 1 3] [lindex $sp 0] 1e-5]}]
# a run made before it was measured
set a $::VMDance::Results::A
dict unset a measures silhouette_pairs
${R}::publish $a "before"
check "  a run made before: refused with what to do; its table has the first column only" [expr {
    [string match "*made before*cluster again*" [err {vmdance silhouette -kind pairs}]] &&
    [lindex [split [lindex [split [::VMDance::Export::table_silhouette] \n] end-[llength $frames]] ,] end] eq "silhouette"}]
vmdance run delete [lindex [lindex [vmdance runs] end] 0]

#---------------------------------------------------------------------------
# What an elbow scan suggests
#---------------------------------------------------------------------------
proc scan_of {dbs chs {stab {}}} {
    set recs {}
    set k 2
    foreach db $dbs ch $chs st $stab {
        set r [dict create k $k status ok nclusters $k db $db ch $ch sizes [lrepeat $k 10]]
        if {$st ne ""} { dict set r stability $st }
        lappend recs $r
        incr k
    }
    dict create request {ks {} radii {}} records $recs
}
# (MDANCE's two criteria, examples/analysis_db.py: the lowest DB, and its
# local minimum of the largest second difference)
set g [${R}::elbow_suggest [scan_of {1.56 2.02 2.06 2.12 2.00 2.15 2.07 2.04 2.06} {2360 1654 1326 1135 990 927 856 793 734} {1.00 0.99 0.75 0.68 0.69 0.63 0.52 0.55 0.52}]]
check "elbow suggest: Davies–Bouldin's lowest and next, its sharpest dip and the next" [expr {
    [dict get $g db_lowest] == 2 && [dict get $g db_second] == 6 && [dict get $g db_dip] == 6 && [dict get $g db_dip2] == 9}]
check "  Calinski–Harabasz's highest; no peak inside a curve that only falls" [expr {[dict get $g ch_highest] == 2 && [dict get $g ch_peak] eq ""}]
check "  the values the seedings agree on, and the most stable" [expr {[dict get $g stable] eq {2 3} && [dict get $g most_stable] == 2}]
set g2 [${R}::elbow_suggest [scan_of {2.0 1.5 1.9 1.4 1.8} {10 30 20 40 5}]]
check "  a peak of Calinski–Harabasz, the sharpest; no stability without one" [expr {
    [dict get $g2 ch_highest] == 5 && [dict get $g2 ch_peak] == 5 && [dict get $g2 db_dip] == 5 && [dict get $g2 stable] eq {} && [dict get $g2 most_stable] eq ""}]
check "  a failed record is passed over; an empty scan suggests nothing" [expr {
    [dict get [${R}::elbow_suggest [dict create request {} records [list {k 2 status failed message x} {k 3 status ok nclusters 3 db 1.0 ch 5 sizes {1 1 1}}]]] db_lowest] == 3 &&
    [dict get [${R}::elbow_suggest {}] db_lowest] eq ""}]
# the variance explained, from the score, against the coordinates
vmdance elbow -mol $m -sel "protein and name CA" -from 2 -to 6 -kinit KmeansPP -quiet 1
set mean [lindex $rows 0]
foreach r [lrange $rows 1 end] { set mean [vecadd $mean $r] }
set mean [vecscale [expr {1.0 / $n}] $mean]
set sst 0.0
foreach r $rows { set sst [expr {$sst + [d2 $r $mean]}] }
set worst 0.0
foreach rec [dict get $::VMDance::Results::elbow records] {
    vmdance elbow load [dict get $rec k]
    set lab [dict values [vmdance labels]]
    set sse 0.0
    for {set c 0} {$c < [dict get $rec k]} {incr c} {
        set mine [lmap r $rows l $lab {expr {$l == $c ? $r : [continue]}}]
        if {![llength $mine]} continue
        set mu [lindex $mine 0]
        foreach r [lrange $mine 1 end] { set mu [vecadd $mu $r] }
        set mu [vecscale [expr {1.0 / [llength $mine]}] $mu]
        foreach r $mine { set sse [expr {$sse + [d2 $r $mu]}] }
    }
    set worst [expr {max($worst, abs([${R}::explained $rec] - (1.0 - $sse / $sst)))}]
}
check "explained: the share of the variance the clusters explain, from the score, as the coordinates give it (worst [format %.2g $worst])" [expr {$worst < 1e-4}]
check "  none for one cluster, or without a score" [expr {
    [${R}::explained {status ok nclusters 1 ch 5 sizes {10}}] eq "" && [${R}::explained {status ok nclusters 3 ch {} sizes {4 3 3}}] eq "" &&
    [${R}::explained {status failed}] eq ""}]
set sug [vmdance elbow suggest]
check "  vmdance elbow suggest: the suggestions, and in words" [expr {
    [dict get $sug db_lowest] ne "" && [string match "Davies–Bouldin: lowest at k *Calinski–Harabasz: highest at k *" [dict get $sug words]]}]
vmdance elbow clear
check "  no scan: refused" [string match "*no elbow scan*" [err {vmdance elbow suggest}]]

#---------------------------------------------------------------------------
# Groups by blocks, and how unlike the groups are
#---------------------------------------------------------------------------
vmdance -mol $m -sel "protein and name CA" -k 4 -kinit KmeansPP -quiet 1
set gi [vmdance groups -blocks 2]
check "groups -blocks 2: the halves, first and second" [expr {[dict get $gi names] eq {first second} && [dict get $gi sizes] eq {50 50} && [dict get $gi none] == 0}]
set gi [vmdance groups -blocks 3]
check "  3 blocks: part1 to part3, as equal as can be" [expr {[dict get $gi names] eq {part1 part2 part3} && [dict get $gi sizes] eq {33 33 34}}]
check "  a number of blocks out of range, or with -ranges: refused" [expr {
    [string match "*-blocks: a whole number of blocks from 2 to 100*" [err {vmdance groups -blocks 1}]] &&
    [string match "*-blocks: a whole number*" [err {vmdance groups -blocks 101}]] &&
    [string match "*give one of -ranges, -file, -names or -blocks*" [err {vmdance groups -blocks 2 -ranges {a 0-9}}]]}]
# the divergence
set d [${M}::divergence {{10 10} {20 20} {5 5}}]
check "divergence: the same shares of the clusters, 0" [expr {[lindex [dict get $d most] 2] == 0 && [lindex [dict get $d most] 3] == 0}]
set d [${M}::divergence {{10 0} {0 7}}]
check "  no cluster in common: ln 2, and a share that differs by all of it" [expr {[near [lindex [dict get $d most] 2] [expr {log(2)}] 1e-3] && [lindex [dict get $d most] 3] == 1}]
# (scipy.spatial.distance.jensenshannon([.5,.5,0],[.25,.25,.5])**2 = 0.2157615543388357)
set d [${M}::divergence {{2 1 0} {2 1 0} {0 2 0}}]
check "  a worked example; a group without frames is left out; the pair most unlike" [expr {
    [llength [dict get $d pairs]] == 1 && [near [lindex [dict get $d most] 2] 0.2157615543388357 1e-3] &&
    [lrange [dict get $d most] 0 1] eq {0 1} && [lindex [dict get $d most] 4] == 2}]
vmdance groups -blocks 2
set cmp [vmdance groups compare]
check "  vmdance groups compare: the groups by name, and in words" [expr {
    [lrange [lindex [dict get $cmp pairs] 0] 0 1] eq {first second} && [string match "first and second: divergence *cluster * differs most*" [dict get $cmp words]]}]
vmdance groups clear
check "  without groups: refused" [string match "*the frames have no groups*" [err {vmdance groups compare}]]

#---------------------------------------------------------------------------
# The clusters numbered by size
#---------------------------------------------------------------------------
vmdance -mol $m -sel "protein and name CA" -k 5 -kinit KmeansPP -quiet 1
set before [vmdance clusters]
set lab0 [vmdance labels]
set run0 [dict get [vmdance info] run]
vmdance groups -blocks 2
vmdance profiles
vmdance similarity
set sim0 [dict get [${R}::extra similarity] cluster]
vmdance renumber
set after [vmdance clusters]
set s [dict get [vmdance info] sizes]
check "renumber: a new run, its clusters by size, the largest 0" [expr {
    [dict get [vmdance info] run] != $run0 && $s eq [lsort -integer -decreasing $s] && [string match "*, by size" [lindex [lindex [vmdance runs] end] 1]]}]
# (the same clusters under other numbers: each row of the table but its number)
check "  the same clusters: every row of the table, under its new number" [expr {
    [lsort [lmap r $before {lrange $r 1 end}]] eq [lsort [lmap r $after {lrange $r 1 end}]]}]
set map {}
set ok 1
dict for {f l} $lab0 {
    set nl [dict get [vmdance labels] $f]
    if {[dict exists $map $l] && [dict get $map $l] != $nl} { set ok 0 }
    dict set map $l $nl
}
check "  every frame's cluster renumbered the same way" [expr {$ok && [llength [lsort -unique [dict values $map]]] == [dict size $map]}]
set ok 1
dict for {old new} $map { if {[lindex $sim0 $old] ne [lindex [dict get [${R}::extra similarity] cluster] $new]} { set ok 0 } }
check "  its extras follow: the clusters' similarity, the profiles' reference, the groups" [expr {
    $ok && [dict get [${R}::extra profiles] reference] == 0 && [dict get [vmdance groups] names] eq {first second}}]
check "  the run before keeps the backend's numbers; numbered by size already: refused" [expr {
    [string match "*numbered by size already*" [err {vmdance renumber}]] && [vmdance run $run0] ne "" && [vmdance clusters] eq $before}]
# HELM: its merges still fit its clusters
vmdance -mol $m -sel "protein and name CA" -algorithm helm -k 3 -initial 12 -initial-kinit KmeansPP -quiet 1
set merges [llength [dict get [vmdance tree] merges]]
set s0 [dict get [vmdance info] sizes]
if {$s0 eq [lsort -integer -decreasing $s0]} {
    skip "HELM renumbered" "its clusters are by size already"
} else {
    vmdance renumber
    check "  HELM renumbered: its tree is kept" [expr {[llength [dict get [vmdance tree] merges]] == $merges && [dict get [vmdance info] sizes] eq [lsort -integer -decreasing $s0]}]
}

#---------------------------------------------------------------------------
# A range for eQUAL's radius
#---------------------------------------------------------------------------
set r [vmdance radii -mol $m -sel "protein and name CA"]
set pc [dict values [dict get $r percentiles]]
check "radii: the distances between the frames (100: all of them), a range from the 2% to the 50% nearest pairs" [expr {
    [dict get $r sample] == 100 && [dict get $r pairs] == 4950 && $pc eq [lsort -real $pc] &&
    [dict get $r from] > 0 && [dict get $r from] < [dict get $r to] && [dict get $r by] > 0}]
# (MDANCE's MSD of two frames: half their RMSD²)
set half [lsort -real [lmap j {1 2 3 4 5 6 7 8 9} {expr {[d2 [lindex $rows 0] [lindex $rows $j]] / 223 / 2.0}}]]
check "  in MDANCE's MSD: half the RMSD² of two frames" [expr {[lindex $half 0] > [lindex $pc 0] / 100.0 && [lindex $half end] < 100 * [lindex $pc end]}]
set e [vmdance elbow -mol $m -sel "protein and name CA" -algorithm equal -radii [list [dict get $r from] [dict get $r to]] -quiet 1]
check "  eQUAL at its ends: more clusters at the smaller radius" [expr {[dict get [lindex $e 0] nclusters] > [dict get [lindex $e 1] nclusters]}]
vmdance elbow clear
check "  its options are the input's" [string match "*its options are -mol, -sel, -fit*" [err {vmdance radii -mol $m -k 3}]]

#---------------------------------------------------------------------------
# Structures as the models of a PDB
#---------------------------------------------------------------------------
vmdance -mol $m -sel "protein and name CA" -k 3 -kinit KmeansPP -quiet 1
set dir [file join $::out ux_pdb]
file delete -force $dir
vmdance export $dir -items {representatives trajectories} -format pdb -sel "protein and name CA"
set t [read_text [file join $dir vmdance_representatives.pdb]]
set reps [lmap c {0 1 2} {dict get [vmdance get $c] representative}]
set ok 1
foreach c {0 1 2} f $reps { if {![regexp -line "^REMARK     VMDance: cluster $c's representative, frame $f \\(\[0-9\]+ frames\\)\$" $t]} { set ok 0 } }
check "export: the representatives as models, each named by a REMARK" [expr {
    $ok && [regexp -all -line {^MODEL +[0-9]+$} $t] == 3 && [regexp -all -line {^ENDMDL$} $t] == 3 && [regexp -all -line {^END$} $t] == 1 &&
    [string match "*ENDMDL\nEND\n" $t]}]
set mr [mol new [file join $dir vmdance_representatives.pdb] waitfor all]
set a [atomselect $m "protein and name CA" frame [lindex $reps 1]]
set b [atomselect $mr all frame 1]
check "  VMD reads them back as frames, the second the second cluster's" [expr {[molinfo $mr get numframes] == 3 && [measure rmsd $a $b] < 1e-2}]
$a delete; $b delete
mol delete $mr
set t1 [read_text [file join $dir vmdance_cluster_1.pdb]]
check "  a cluster's frames: a model each, named" [expr {
    [regexp -all -line {^MODEL} $t1] == [lindex [dict get [vmdance info] sizes] 1] && [regexp -line {^REMARK     VMDance: cluster 1, frame [0-9]+$} $t1]}]
# (a DCD's PDB of the atoms: one frame, as VMD writes it)
file delete -force $dir
vmdance export $dir -items trajectories -format dcd -sel "protein and name CA"
check "  the PDB beside a DCD: one frame, no model" [expr {![regexp -line {^MODEL} [read_text [file join $dir vmdance_cluster_0.pdb]]]}]

#---------------------------------------------------------------------------
# Clusters without frames in the summaries
#---------------------------------------------------------------------------
set a $::VMDance::Results::A
set labs [lmap l [dict get $a labels] {expr {$l == 2 ? 1 : $l}}]
dict set a labels $labs
dict set a sizes [list [lindex [dict get $a sizes] 0] [expr {[lindex [dict get $a sizes] 1] + [lindex [dict get $a sizes] 2]}] 0]
dict set a representatives [lreplace [dict get $a representatives] 2 2 -1]
${R}::publish $a
check "a cluster without frames: the run's name and the summary say it" [expr {
    [string match "* → 3 clusters (1 empty)" [lindex [lindex [vmdance runs] end] 1]] && [string match "3 clusters (1 with no frames: 2)*" [::VMDance::_summary]] &&
    [${R}::empty_clusters] eq {2}}]

#---------------------------------------------------------------------------
# Help
#---------------------------------------------------------------------------
set h [vmdance help]
set missing {}
if {![regexp {set cmds \{([^\}]*)\}} [read_text [file join $::root vmdance vmdance.tcl]] -> cmds]} { set cmds {} }
foreach c $cmds { if {![dict exists $::VMDance::help_text $c]} { lappend missing $c } }
check "help: every subcommand has its usage ([llength $cmds] of them)[expr {[llength $missing] ? ": not $missing" : ""}]" [expr {[llength $cmds] > 30 && ![llength $missing]}]
check "  the list names them; one's usage; an unknown one" [expr {
    [string match "*  elbow *\n  sweep *" $h] && [string match "vmdance silhouette ?-kind centroid|pairs?\n*" [vmdance help silhouette]] &&
    [string match "vmdance -mol top*" [vmdance help -k]] && [string match "*no subcommand \"nope\"*" [err {vmdance help nope}]]}]
set bad {}
dict for {c d} $::VMDance::help_text {
    if {$c eq "cluster"} continue
    if {[info commands ::VMDance::_api_$c] eq ""} { lappend bad $c }
}
check "  and every one it names is a subcommand[expr {[llength $bad] ? ": not $bad" : ""}]" [expr {![llength $bad]}]

done
quit
