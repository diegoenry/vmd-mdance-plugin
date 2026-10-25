# The frames' groups, the map, the profiles, the scans' stability, eQUAL's
# radius scan and HELM's merge heights (text mode; the real backend):
#   cd <VMDance>; vmd -dispdev text -e tests/test_groups.tcl < /dev/null
# Each is checked against a direct computation: the map against numpy's PCA
# (tests/fixtures/pca_two_state.txt, make_pca_fixture.py) and the Gram
# matrix's own eigenvectors; the profiles, the make-up, the heights and the
# stability against what the coordinates and labels give when counted here.
source [file join [pwd] tests common.tcl]
package require vmdance
set ::VMDance::Prefs::file ""
set R ::VMDance::Results

if {[real_cli] eq ""} {
    skip "every check" "no mdance-cli (MDANCE_CLI, or CPP-MDANCE beside the plugin)"
    done
    quit
}
use_cli

# the clustered rows as the plugin reads them (no fit): one list per frame
proc rows_of {m sel frames} {
    set s [atomselect $m $sel]
    set out {}
    foreach f $frames { $s frame $f; lappend out [concat {*}[$s get {x y z}]] }
    $s delete
    return $out
}
proc mean_rows {rows} {
    set sum [lindex $rows 0]
    foreach r [lrange $rows 1 end] { set sum [vecadd $sum $r] }
    vecscale [expr {1.0 / [llength $rows]}] $sum
}

#---------------------------------------------------------------------------
# The adjusted Rand index (Measure::ari)
#---------------------------------------------------------------------------
# (scikit-learn's adjusted_rand_score([0,0,0,1,1,1], [0,0,1,1,2,2]) = 0.2424…)
check "ari: a worked example" [near [::VMDance::Measure::ari {0 0 0 1 1 1} {0 0 1 1 2 2}] 0.24242424242424243 1e-12]
check "ari: the same clusters, renumbered" [near [::VMDance::Measure::ari {0 0 1 1 2 2} {2 2 0 0 1 1}] 1.0 1e-12]
check "ari: both one cluster" [expr {[::VMDance::Measure::ari {0 0 0} {1 1 1}] eq ""}]
check "ari: one frame" [expr {[::VMDance::Measure::ari {0} {0}] eq ""}]

#---------------------------------------------------------------------------
# Groups
#---------------------------------------------------------------------------
set m [load_system two_state]
vmdance -mol $m -sel "name CA" -k 2 -kinit KmeansPP -quiet 1
set nf [llength [${R}::frames]]
check "no groups at first" [expr {[vmdance groups] eq {} && [${R}::group_names] eq {}}]
check "makeup without groups: refused" [string match "*no groups*" [err {vmdance makeup}]]
set g [vmdance groups -ranges {first 0-11 second 12-23}]
check "groups by ranges" [expr {[dict get $g names] eq {first second} && [dict get $g sizes] eq {12 12} && [dict get $g none] == 0}]
set mu [vmdance makeup]
set direct [dict create]
foreach l [${R}::labels] g [${R}::group_of] { dict incr direct $l,$g }
set ok 1
dict for {c row} $mu { foreach n $row j {0 1} { if {$n != [::VMDance::_get $direct $c,$j 0]} { set ok 0 } } }
check "makeup: the counts of the labels and groups" $ok
set byg [vmdance makeup -by group]
check "makeup by group: the transpose" [expr {[lindex [dict get $byg first] 0] == [lindex [dict get $mu 0] 0] && [dict keys $byg] eq {first second}}]
check "makeup -by: checked" [string match "*-by must be*" [err {vmdance makeup -by frame}]]
check "ranges: a frame in two groups refused" [string match "*frame 5 is in two groups*" [err {vmdance groups -ranges {a 0-5 b 5-9}}]]
check "ranges: not pairs refused" [string match "*name and frames pairs*" [err {vmdance groups -ranges {a 0-5 b}}]]
check "ranges: a name too long refused" [string match "*not a group's name*" [err {vmdance groups -ranges [list [string repeat x 65] 0-5]}]]
check "ranges: a frame not clustered gives no group" [expr {[dict get [vmdance groups -ranges {a 0-3 b 100-200}] none] == 20}]
check "ranges: no frame of the clustering refused" [string match "*none of the*" [err {vmdance groups -ranges {a 500-600}}]]
# a file of frame,group lines
set f [file join $::out groups.csv]
set ch [open $f w]
puts $ch "frame,group\n# a comment"
for {set i 0} {$i < $nf} {incr i} { puts $ch "$i,[expr {$i % 3 ? "odd one" : "third"}]" }
close $ch
set g [vmdance groups -file $f]
check "groups from a file (a header, a comment, a name with a space)" [expr {[dict get $g names] eq {third {odd one}} && [dict get $g sizes] eq {8 16}}]
set ch [open $f w]; puts $ch "0,a,b"; close $ch
check "file: three columns refused" [string match "*more than two columns*" [err {vmdance groups -file $f}]]
check "file: none there refused" [string match "*cannot read*" [err {vmdance groups -file [file join $::out nothere.csv]}]]
set g [vmdance groups -names [lrepeat $nf one]]
check "groups by names" [expr {[dict get $g names] eq {one} && [dict get $g sizes] eq [list $nf]}]
check "names: one per frame" [string match "*a name for each*" [err {vmdance groups -names {a b}}]]
check "one way at a time" [string match "*give one of*" [err {vmdance groups -ranges {a 0-3} -names {x}}]]
check "an unknown option refused" [string match "*unknown option*" [err {vmdance groups -frames 1}]]
vmdance groups clear
check "groups clear" [expr {[vmdance groups] eq {}}]

# each group's colour: the palette's by its index, else its own by name
check "colours without groups: refused" [string match "*no groups to colour*" [err {vmdance groups -colours {a #102030}}]]
set g [vmdance groups -ranges {first 0-11 second 12-23}]
check "colours: the palette's at first" [expr {[dict get $g colours] eq [lrange [set ${R}::group_palette] 0 1] && ![dict exists [${R}::groups] colours]}]
set g [vmdance groups -colours {second #A3483B absent #102030}]
check "colours by name, a name not there passed over" [expr {[dict get $g colours] eq [list [lindex [set ${R}::group_palette] 0] #a3483b] && [dict get [${R}::groups] colours] eq {{} #a3483b}}]
check "colours: the plots' colour" [expr {[${R}::group_colour 1] eq "#a3483b" && [${R}::group_colour -1] eq ""}]
set g [vmdance groups -ranges {zero 0-3 second 4-23}]
check "new groups keep the colours of their names" [expr {[lindex [dict get $g colours] 1] eq "#a3483b" && [lindex [dict get $g colours] 0] eq [lindex [set ${R}::group_palette] 0]}]
set g [vmdance groups -ranges {first 0-11 second 12-23} -colours {first #102030}]
check "colours with new groups, the others kept" [expr {[dict get $g colours] eq [list #102030 #a3483b]}]
set g [vmdance groups -colours {first "" second ""}]
check "colours \"\": the palette's again" [expr {[dict get $g colours] eq [lrange [set ${R}::group_palette] 0 1] && ![dict exists [${R}::groups] colours]}]
check "colours: not a colour refused" [string match "*is not a colour*" [err {vmdance groups -colours {first red}}]]
check "colours: not pairs refused" [string match "*group and colour pairs*" [err {vmdance groups -colours {first}}]]
check "colours: no groups changed by a refusal" [expr {![dict exists [${R}::groups] colours]}]
vmdance groups -colours {second #a3483b}

# a new clustering of the same frames takes the groups over
vmdance -mol $m -sel "name CA" -k 3 -kinit KmeansPP -quiet 1
check "a new clustering takes the groups" [expr {[dict get [vmdance groups] names] eq {first second}}]
check "and their colours" [expr {[dict get [${R}::groups] colours] eq {{} #a3483b}}]
vmdance -mol $m -sel "name CA" -first 2 -k 2 -kinit KmeansPP -quiet 1
check "of fewer frames: theirs" [expr {[dict get [vmdance groups] sizes] eq {10 12}}]
set m2 [load_system two_state]
vmdance -mol $m2 -sel "name CA" -k 2 -kinit KmeansPP -quiet 1
check "another molecule's clustering: none" [expr {[vmdance groups] eq {}}]

#---------------------------------------------------------------------------
# The map: numpy's PCA of the same rows
#---------------------------------------------------------------------------
vmdance run [lindex [lsearch -index 1 -inline [vmdance runs] "*k 2*"] 0]
mol delete $m2
vmdance -mol $m -sel "name CA" -k 2 -kinit KmeansPP -quiet 1
set mp [vmdance map]
set ref [lmap l [split [string trim [read_text [file join $::fixtures pca_two_state.txt]]] \n] {expr {[string index $l 0] eq "#" ? [continue] : $l}}]
lassign [lindex $ref 0] v1 v2
check "map: the variance's shares are numpy's" [expr {[near [lindex [dict get $mp variance] 0] $v1 1e-5] && [near [lindex [dict get $mp variance] 1] $v2 1e-3]}]
set shown [vmdance map show]
set worst1 0.0; set worst2 0.0
foreach f [${R}::frames] r [lrange $ref 1 end] {
    lassign [dict get $shown $f] a b
    set worst1 [expr {max($worst1, abs($a - [lindex $r 0]))}]
    set worst2 [expr {max($worst2, abs($b - [lindex $r 1]))}]
}
check "map: PC1 is numpy's (within 1e-4 Å, $worst1)" [expr {$worst1 < 1e-4}]
check "map: PC2 is numpy's (within 1e-3 Å, $worst2)" [expr {$worst2 < 1e-3}]
check "map: every frame" [expr {[dict size $shown] == $nf && [dict get $mp sample] == $nf}]
# from a sample of the frames: the axes nearly the same, every frame placed
set ms [vmdance map -sample 12]
check "map from 12 frames: every frame placed" [expr {[dict get $ms sample] == 12 && [llength [dict get [${R}::extra map] pc1]] == $nf}]
check "map from 12 frames: PC1 nearly the same" [expr {abs([lindex [dict get $ms variance] 0] - $v1) < 0.01}]
check "map: -sample checked" [string match "*-sample*" [err {vmdance map -sample 1}]]
check "map show without a map: refused" [expr {[err {vmdance map show}] eq ""}]

# on 3ptb's Cα (100 frames, 223 atoms): the Gram matrix's full
# eigen-decomposition gives the same scores as the subspace iteration
set p [load_system 3ptb]
vmdance -mol $p -sel "protein and name CA" -k 4 -kinit CompSim -quiet 1
vmdance map
set rows [rows_of $p "protein and name CA" [${R}::frames]]
set mu [mean_rows $rows]
set xs [lmap r $rows {vecsub $r $mu}]
set G [lmap a $xs {lmap b $xs {vecdot $a $b}}]
lassign [::VMDance::Measure::_jacobi $G] vals vecs
set order [lsort -real -decreasing -indices $vals]
set ok 1
foreach k {0 1} key {pc1 pc2} {
    set o [lindex $order $k]
    set u [lindex $vecs $o]
    set sc [lmap x $u {expr {$x * sqrt([lindex $vals $o])}}]
    set big 0.0; foreach x $sc { if {abs($x) > abs($big)} { set big $x } }
    if {$big < 0} { set sc [lmap x $sc {expr {-$x}}] }
    foreach a $sc b [dict get [${R}::extra map] $key] { if {abs($a - $b) > 1e-3 * max(1.0, abs($a))} { set ok 0 } }
}
check "map: 3ptb's scores are the Gram matrix's eigenvectors'" $ok

#---------------------------------------------------------------------------
# The profiles: the RMSF and the mean structures' distances, counted here
#---------------------------------------------------------------------------
vmdance groups -ranges {early 0-49 late 50-99}
set pr [vmdance profiles]
set P [${R}::extra profiles]
check "profiles: the most populated cluster is the reference" [expr {[dict get $pr reference] == [::VMDance::Job::largest [${R}::sizes]]}]
check "profiles: every atom, the residues and chains" [expr {[dict get $pr atoms] == 223 && [llength [dict get $P residues]] == 223 && [lindex [dict get $P chains] 0] ne ""}]
proc rmsf_direct {rows} {
    set mu [mean_rows $rows]
    set acc {}
    foreach r $rows {
        set i 0
        foreach {x y z} [vecsub $r $mu] {
            set v [expr {$x * $x + $y * $y + $z * $z}]
            if {[llength $acc] <= $i} { lappend acc $v } else { lset acc $i [expr {[lindex $acc $i] + $v}] }
            incr i
        }
    }
    lmap v $acc {expr {sqrt($v / [llength $rows])}}
}
proc worst {a b} { set w 0.0; foreach x $a y $b { set w [expr {max($w, abs($x - $y))}] }; return $w }
set w [worst [rmsf_direct [lrange $rows 0 49]] [lindex [dict get $P groups] 0]]
check "profiles: the early group's RMSF (within 1e-4 Å, $w)" [expr {$w < 1e-4}]
set c0 [lmap i [${R}::members 0] {lindex $rows $i}]
set w [worst [rmsf_direct $c0] [lindex [dict get $P clusters] 0]]
check "profiles: cluster 0's RMSF (within 1e-4 Å, $w)" [expr {$w < 1e-4}]
set ref [dict get $P reference]
set other [expr {$ref == 0 ? 1 : 0}]
set ma [mean_rows [lmap i [${R}::members $other] {lindex $rows $i}]]
set mb [mean_rows [lmap i [${R}::members $ref] {lindex $rows $i}]]
set d [lmap {x y z} [vecsub $ma $mb] {expr {sqrt($x * $x + $y * $y + $z * $z)}}]
set w [worst $d [lindex [dict get $P differences] $other]]
check "profiles: cluster $other's mean structure from cluster $ref's (within 1e-4 Å, $w)" [expr {$w < 1e-4}]
check "profiles: the reference's own difference is zero" [expr {[::tcl::mathfunc::max {*}[lindex [dict get $P differences] $ref]] == 0}]
check "profiles: -reference checked" [string match "*no cluster*" [err {vmdance profiles -reference 99}]]
vmdance profiles -reference $other
check "profiles: -reference" [expr {[dict get [${R}::extra profiles] reference] == $other}]
# groups changed: the profiles made with the others go
vmdance groups -ranges {a 0-9 b 10-99}
check "profiles of other groups dropped" [expr {[dict size [${R}::extra profiles]] == 0}]
vmdance profiles
vmdance groups -ranges {a 0-9 b 10-99}
check "the same groups again: kept" [expr {[dict size [${R}::extra profiles]] > 0}]
set keep $::VMDance::Measure::profiles_most
set ::VMDance::Measure::profiles_most 1000
check "profiles: too many numbers refused" [string match "*take more than 1000 numbers*" [err {vmdance profiles}]]
set ::VMDance::Measure::profiles_most $keep

#---------------------------------------------------------------------------
# Exports and sessions
#---------------------------------------------------------------------------
vmdance map
set d [file join $::out groups_export]
file delete -force $d
set files [vmdance export $d -prefix g -items {groups makeup map profiles}]
check "export: four files" [expr {[llength $files] == 4}]
set rows_g [csv_rows [file join $d g_groups.csv]]
check "export groups: frame,cluster,group" [expr {[lindex $rows_g 0] eq {frame cluster group} && [llength $rows_g] == 101}]
set rows_m [csv_rows [file join $d g_makeup.csv]]
check "export makeup: a row per cluster and group, shares" [expr {[llength $rows_m] == 1 + 4 * 2 && [lindex $rows_m 0 4] eq "share_of_group"}]
check "export makeup: shares with four decimals" [regexp {^[01]\.[0-9]{4}$} [lindex $rows_m 1 3]]
set rows_p [csv_rows [file join $d g_map.csv]]
check "export map: every frame" [expr {[llength $rows_p] == 101 && [lindex $rows_p 0] eq {frame cluster group pc1 pc2}}]
set rows_f [csv_rows [file join $d g_profiles.csv]]
check "export profiles: an atom a row, a column per cluster, group and difference" [expr {[llength $rows_f] == 224 && [llength [lindex $rows_f 0]] == 3 + 4 + 2 + 4}]
vmdance groups clear
check "export groups without groups: refused, nothing written" [expr {[string match "*no groups*" [err {vmdance export [file join $::out g2] -items {groups}}]] && ![file exists [file join $::out g2]]}]
vmdance groups -ranges {early 0-49 late 50-99} -colours {late #4f7a5a}
vmdance profiles
set s [file join $::out groups.vmdance]
vmdance session save $s
set before [dict get $::VMDance::Results::A extras]
vmdance run clear
vmdance session load $s
check "session: the groups, the map and the profiles come back" [expr {[dict get $::VMDance::Results::A extras] eq $before && [dict get [${R}::groups] colours] eq {{} #4f7a5a}}]
# a session's extras are checked as data
proc corrupt {key script} {
    set a $::VMDance::Results::A
    dict set a extras $key [apply [list v $script] [dict get $a extras $key]]
    err {::VMDance::Results::check $a}
}
check "check: groups' names alike" [string match "*same name*" [corrupt groups {dict set v names {a a}}]]
check "check: a group's index past the names" [string match "*outside*" [corrupt groups {dict set v of [lreplace [dict get $v of] 0 0 5]}]]
check "check: groups of too few frames" [string match "*values, not*" [corrupt groups {dict set v of {0 1}}]]
check "check: a name with a line break" [string match "*not a group's name*" [corrupt groups {dict set v names [list "a\nb" c]}]]
check "check: a colour not #rrggbb" [string match "*not a group's colour*" [corrupt groups {dict set v colours {red {}}}]]
check "check: colours not one a group" [string match "*colours are corrupt*" [corrupt groups {dict set v colours {#102030}}]]
check "check: the map's scores too few" [string match "*values, not*" [corrupt map {dict set v pc1 {1 2}}]]
check "check: the map's score not a number" [string match "*holds*" [corrupt map {dict set v pc2 [lreplace [dict get $v pc2] 0 0 NaN]}]]
check "check: the profiles' clusters too few" [string match "*are not 4*" [corrupt profiles {dict set v clusters {{} {}}}]]
check "check: the profiles' reference past k" [string match "*outside*" [corrupt profiles {dict set v reference 9}]]
check "check: a profile too short" [string match "*values, not*" [corrupt profiles {dict set v groups [list {1 2} [lindex [dict get $v groups] 1]]}]]

#---------------------------------------------------------------------------
# Stability: the agreement between NANI's seedings at each k
#---------------------------------------------------------------------------
set recs [vmdance elbow -mol $p -sel "protein and name CA" -from 2 -to 5 -percentage 50 -stability 1 -quiet 1]
check "stability: a value at each k, 0 to 1" [expr {[llength [lmap r $recs {expr {[dict get $r stability] ne "" && [dict get $r stability] >= -1 && [dict get $r stability] <= 1 ? 1 : [continue]}}]] == 4}]
# at k 3: the mean of the six pairs of the four seedings, clustered here
set labs {}
foreach kin $::VMDance::Algo::deterministic_kinits {
    vmdance -mol $p -sel "protein and name CA" -k 3 -kinit $kin -percentage 50 -quiet 1
    lappend labs [vmdance labels]
}
set sum 0.0
for {set a 0} {$a < 4} {incr a} {
    for {set b [expr {$a + 1}]} {$b < 4} {incr b} {
        set la [dict values [lindex $labs $a]]; set lb [dict values [lindex $labs $b]]
        set v [::VMDance::Measure::ari $la $lb]
        set sum [expr {$sum + ($v eq "" ? 1.0 : $v)}]
    }
}
set at3 [dict get [lindex $recs 1] stability]
check "stability at k 3: the mean of the six pairs ([format %.4f [expr {$sum / 6}]], $at3)" [near $at3 [expr {$sum / 6}] 1e-3]
check "stability: two seedings at least" [string match "*two seedings*" [err {vmdance elbow -mol $p -from 2 -to 3 -stability {CompSim} -quiet 1}]]
check "stability: a seeding named twice" [string match "*given twice*" [err {vmdance elbow -mol $p -from 2 -to 3 -stability {CompSim CompSim} -quiet 1}]]
check "stability: no seeding of that name" [string match "*not a seeding*" [err {vmdance elbow -mol $p -from 2 -to 3 -stability {CompSim Nope} -quiet 1}]]
check "stability: k-means NANI's only" [string match "*k-means NANI*" [err {vmdance elbow -mol $p -algorithm helm -from 2 -to 3 -stability 1 -quiet 1}]]
vmdance elbow -mol $p -sel "protein and name CA" -from 2 -to 5 -percentage 50 -stability {StratAll CompSim} -quiet 1
set d [file join $::out stability_export]
file delete -force $d
vmdance export $d -prefix s -items {elbow}
set er [csv_rows [file join $d s_elbow.csv]]
check "export elbow: the stability column" [expr {[lindex $er 0 4] eq "stability" && [string is double -strict [lindex $er 1 4]]}]
check "export elbow: the seedings said" [string match "*# stability: * StratAll, CompSim*" [read_text [file join $d s_elbow.csv]]]
set s [file join $::out stability.vmdance]
vmdance session save $s
set before $::VMDance::Results::elbow
vmdance run clear
vmdance session load $s
check "session: the stability comes back" [expr {[lmap r [dict get $::VMDance::Results::elbow records] {dict get $r stability}] eq [lmap r [dict get $before records] {dict get $r stability}]}]

#---------------------------------------------------------------------------
# eQUAL: the radius scan
#---------------------------------------------------------------------------
set recs [vmdance elbow -mol $p -sel "protein and name CA" -algorithm equal -radii {2 1 4} -quiet 1]
check "radius scan: sorted, a record each" [expr {[lmap r $recs {dict get $r radius}] eq {1.0 2.0 4.0} || [lmap r $recs {dict get $r radius}] eq {1 2 4}}]
set ok 1
foreach r $recs {
    vmdance -mol $p -sel "protein and name CA" -algorithm equal -threshold [dict get $r radius] -quiet 1
    if {[dict get [vmdance info] nclusters] != [dict get $r nclusters]} { set ok 0 }
}
check "radius scan: each radius's clusters as eQUAL's alone" $ok
set info [vmdance elbow load 2]
check "radius scan: elbow load a radius" [expr {[dict get $info algorithm] eq "equal" && [dict get $info params threshold] == 2}]
check "radius scan: no such radius" [string match "*no radius 3*" [err {vmdance elbow load 3}]]
check "radius scan: two radii at least" [string match "*two radii*" [err {vmdance elbow -mol $p -algorithm equal -radii {1} -quiet 1}]]
check "radius scan: above 0" [string match "*above 0*" [err {vmdance elbow -mol $p -algorithm equal -radii {0 1} -quiet 1}]]
check "radius scan: not k" [string match "*given no k*" [err {vmdance elbow -mol $p -algorithm equal -ks {2 3} -quiet 1}]]
check "radius scan: -radii is eQUAL's" [string match "*-radii is eQUAL's*" [err {vmdance elbow -mol $p -radii {1 2} -quiet 1}]]
vmdance session save $s
vmdance run clear
vmdance session load $s
check "session: the radius scan comes back" [expr {[llength [dict get $::VMDance::Results::elbow records]] == 3 && [${R}::by_radius $::VMDance::Results::elbow]}]
set d [file join $::out radius_export]
file delete -force $d
vmdance export $d -prefix r -items {elbow}
check "export elbow: a radius column" [expr {[lindex [csv_rows [file join $d r_elbow.csv]] 0 0] eq "radius"}]

#---------------------------------------------------------------------------
# HELM: its merges' heights, the MSD of the frames each joins
#---------------------------------------------------------------------------
vmdance -mol $p -sel "protein and name CA" -algorithm helm -k 2 -initial 12 -initial-percentage 20 -quiet 1
set hs [dict get $::VMDance::Results::A measures merge_msd]
lassign [::VMDance::Measure::helm_tree [${R}::get zmatrix] [${R}::get initial] [${R}::labels] [${R}::nclusters]] trows leaves n0
check "heights: one per merge" [expr {[llength $hs] == [llength $trows] && [llength $hs] > 0}]
# the frames under each node, and their MSD (MDANCE's: twice the mean
# squared deviation from their mean, per atom)
set init [${R}::get initial]
set labs [${R}::labels]
foreach l $leaves { set under($l) [lmap i [lsearch -all -exact $init $l] {expr {[lindex $labs $i] >= 0 ? $i : [continue]}}] }
set ok 1; set j 0
foreach row $trows h $hs {
    lassign $row a b
    set nd [expr {$n0 + $j}]
    set under($nd) [concat $under($a) $under($b)]
    set fr [lmap i $under($nd) {lindex $rows $i}]
    set mu [mean_rows $fr]
    set q 0.0
    foreach r $fr { set v [veclength [vecsub $r $mu]]; set q [expr {$q + $v * $v}] }
    set msd [expr {2.0 * $q / ([llength $fr] * 223)}]
    if {![near $h $msd 1e-4]} { set ok 0; puts "  merge $j: $h, here $msd" }
    incr j
}
check "heights: each merge's MSD, counted here" $ok
vmdance session save $s
vmdance run clear
vmdance session load $s
check "session: the heights come back" [expr {[dict get $::VMDance::Results::A measures merge_msd] eq $hs}]
set a $::VMDance::Results::A
dict set a measures merge_msd [lrange $hs 1 end]
check "check: heights not one per merge" [string match "*values, not*" [err {::VMDance::Results::check $a}]]

done
quit
