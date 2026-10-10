# The science, with the real backend (a CPP-MDANCE build): the plugin's
# clusterings equal the backend's own on the same coordinates (DIVINE's too,
# when the build has it), the program and the library agree, the plugin's
# measures equal direct computations, MDANCE's own labels of 3ptb
# (tests/fixtures/mdance_3ptb.txt) are reproduced or their difference
# recorded, and MDANCE's published runs (the Python reference: a
# heptapeptide and protein G) are reproduced on the atoms they cluster, the
# Cα.
#   cd <VMDance>; vmd -dispdev text -e tests/test_reference.tcl < /dev/null
# MDANCE_CLI, MDANCE_LIB: the backend (else the CPP-MDANCE build beside
# the plugin's folder); MDANCE_REF_RUNS: the reference runs (inputs/,
# results/). What is not there is skipped, and says so.
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

proc ref_rows {path} {
    lmap l [split [read_text $path] \n] {
        set l [string trim $l]
        expr {$l eq "" || [string index $l 0] eq "#" ? [continue] : [split $l ,]}
    }
}
proc ref_fractions {path} { lsort -real -decreasing [lmap r [ref_rows $path] {expr {[llength $r] >= 3 ? [lindex $r 1] : [continue]}}] }
proc fractions {} {
    set n [::VMDance::Results::nframes]
    lsort -real -decreasing [lmap s [::VMDance::Results::sizes] {expr {double($s) / $n}}]
}
proc maxdiff {a b} {
    set m 0.0
    foreach x $a y $b { set m [expr {max($m, abs($x - $y))}] }
    return $m
}
proc pct {got exp} { expr {abs(double($got) - $exp) / abs(double($exp)) * 100.0} }
# Labels as a partition (numbered by first appearance), and its populations.
proc partition {labels} {
    set map {}
    lmap l $labels {
        if {![dict exists $map $l]} { dict set map $l [dict size $map] }
        dict get $map $l
    }
}
proc pops {labels} {
    foreach l $labels { incr n($l) }
    lsort -integer -decreasing [lmap {l c} [array get n] {set c}]
}
# MDANCE's own labels of 3ptb's Calpha atoms (tests/fixtures/mdance_3ptb.txt):
# {case labels ...}.
proc mdance_3ptb {} {
    set f [file join $::fixtures mdance_3ptb.txt]
    if {![file exists $f]} { return {} }
    set out {}
    foreach l [split [read_text $f] \n] {
        if {$l eq "" || [string index $l 0] eq "#"} continue
        dict set out [lindex $l 0] [lrange $l 1 end]
    }
    return $out
}
# The plugin's clustering against MDANCE's where CPP-MDANCE is known to
# differ (why): the same partition passes, another is recorded with the
# numbers, not asserted (the plugin's labels are the program's, checked
# apart).
proc against_mdance {what why theirs} {
    set mine [::VMDance::Results::labels]
    if {[partition $mine] eq [partition $theirs]} {
        check "$what: MDANCE's partition" 1
    } else {
        skip "$what: MDANCE's partition" "$why (populations [pops $mine], MDANCE's [pops $theirs]): a difference of the backend, recorded, not asserted"
    }
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set cli [real_cli]
set lib [real_lib]
if {$cli eq ""} {
    skip "every comparison with the backend" "no mdance-cli (set MDANCE_CLI)"
} else {
use_cli
set m [load_system 3ptb]
set have [::VMDance::Backend::algorithms]

# --- the plugin's clustering is the backend's -----------------------------------------------
set req [::VMDance::Job::check_cluster [list mol $m sel "name CA" algorithm kmeans k 5]]
set c [::VMDance::Coords::extract $req]
set csv [::VMDance::Coords::csv $c]
set jout [file join $::out direct.json]
exec $cli --algorithm kmeans --input $csv --output $jout --natoms [dict get $c natoms] --nclusters 5 --metric MSD --kinit StratAll --percentage 10 2>@1
set direct [::VMDance::Json::parse [read_text $jout]]
vmdance -mol $m -sel "name CA" -k 5 -quiet 1
check "KMeans NANI: the plugin's labels are the program's on the same coordinates" [expr {[${R}::labels] eq [dict get $direct labels]}]
check "  and its scores" [expr {[near [${R}::get ch] [dict get $direct scores calinskiHarabasz] 1e-9] && [near [${R}::get db] [dict get $direct scores daviesBouldin] 1e-9]}]
check "  the CSV holds VMD's coordinates, in the selection's order" [expr {
    [lrange [split [lindex [split [read_text $csv] \n] 3] ,] 0 2] eq [lindex [[set s [atomselect $m "name CA" frame 3]] get {x y z}] 0]}]
$s delete
set labels_cli [${R}::labels]

foreach {a args} {helm {-k 4 -initial 20 -initial-kinit KmeansPP} equal {-threshold 1.5}} {
    if {$a ni $have} { skip "$a against the program" "not in this build"; continue }
    vmdance -mol $m -sel "name CA" -algorithm $a {*}$args -quiet 1
    set ok [expr {[llength [${R}::labels]] == 100 && [${R}::nclusters] >= 1}]
    if {$a eq "helm"} {
        set init [file join $::out init.csv]
        ::VMDance::Backend::write_column $init [${R}::get initial]
        exec $cli --algorithm helm --input $csv --output $jout --natoms [dict get $c natoms] --nclusters 4 --metric MSD --initial-labels $init --merge-scheme Inter --eps -1 2>@1
    } else {
        exec $cli --algorithm equal --input $csv --output $jout --natoms [dict get $c natoms] --metric MSD --threshold 1.5 --seed-method medoid --n-seeds 1 --percentage 10 2>@1
    }
    set direct [::VMDance::Json::parse [read_text $jout]]
    check "[::VMDance::Algo::label $a]: the plugin's labels are the program's" [expr {$ok && [${R}::labels] eq [dict get $direct labels]}]
}
# DIVINE: the plugin's labels and scores are the program's, every parameter
# at another value than its default once, with mdance-cli's arguments
# written out (a mapping made by cli_args would prove nothing)
set dlabels {}
if {"divine" ni $have} {
    skip "DIVINE against the program, the library and MDANCE" "this build of CPP-MDANCE has no DIVINE (BUILD_DIVINE)"
} else {
    foreach {opts argv} {
        {-k 4} {--nclusters 4 --split WeightedMSD --anchors NANI --kinit StratAll --threshold 0 --end-mode k --percentage 10}
        {-k 5 -refine 1} {--nclusters 5 --split WeightedMSD --anchors NANI --kinit StratAll --refine --threshold 0 --end-mode k --percentage 10}
        {-k 6 -anchors OutlierPair -split Radius} {--nclusters 6 --split Radius --anchors OutlierPair --kinit StratAll --threshold 0 --end-mode k --percentage 10}
        {-k 6 -anchors SplinterPair -split MSD -threshold 0.05} {--nclusters 6 --split MSD --anchors SplinterPair --kinit StratAll --threshold 0.05 --end-mode k --percentage 10}
        {-k 5 -kinit CompSim -percentage 20} {--nclusters 5 --split WeightedMSD --anchors NANI --kinit CompSim --threshold 0 --end-mode k --percentage 20}
        {-anchors OutlierPair -threshold 0.2 -end-mode points} {--nclusters 3 --split WeightedMSD --anchors OutlierPair --kinit StratAll --threshold 0.2 --end-mode points --percentage 10}
    } {
        vmdance -mol $m -sel "name CA" -algorithm divine {*}$opts -quiet 1
        exec $cli --algorithm divine --input $csv --output $jout --natoms [dict get $c natoms] --metric MSD {*}$argv 2>@1
        set direct [::VMDance::Json::parse [read_text $jout]]
        check "DIVINE $opts: the plugin's labels and scores are the program's ([${R}::nclusters] clusters)" [expr {
            [${R}::labels] eq [dict get $direct labels] && [${R}::nclusters] >= 2 &&
            [near [${R}::get ch] [dict get $direct scores calinskiHarabasz] 1e-9] && [near [${R}::get db] [dict get $direct scores daviesBouldin] 1e-9]}]
        lappend dlabels $opts [${R}::labels]
    }
    # what the plugin's checks and the window rely on
    vmdance -mol $m -sel "name CA" -algorithm divine -k 5 -quiet 1
    check "  NANI's splits: Refine changes nothing (the window greys it)" [expr {[${R}::labels] eq [lindex $dlabels 3]}]
    exec $cli --algorithm divine --input $csv --output $jout --natoms [dict get $c natoms] --metric RR --nclusters 4 --split WeightedMSD --anchors NANI --kinit StratAll --threshold 0 --end-mode k --percentage 10 2>@1
    check "  another metric changes none of its labels (the plugin takes MSD only)" [expr {[dict get [::VMDance::Json::parse [read_text $jout]] labels] eq [lindex $dlabels 1]}]
    vmdance -mol $m -sel "name CA" -algorithm divine -k 6 -anchors OutlierPair -threshold 0.3 -quiet 1
    check "  -k 6 with the smallest share 0.3: 2 clusters, and the summary says why" [expr {[${R}::nclusters] == 2 &&
        [string match "*fewer than the 6 asked: no split left 30 frames or more on each side (-threshold 0.3)" [::VMDance::_summary]]}]
    set rows [vmdance elbow -mol $m -sel "name CA" -algorithm divine -ks {10 11} -quiet 1]
    check "  a later split's cluster too small for NANI's seeds (k 11 at 10%): said in DIVINE's terms" [expr {
        [dict get [lindex $rows 0] status] eq "ok" && [string match "DIVINE chose to split a cluster of fewer than 20 frames*" [dict get [lindex $rows 1] message]]}]
}

# HELM's tree after trimming: CPP-MDANCE numbers its merges from the
# starting clusters kept, so that its numbers repeat those of kept starting
# clusters; the plugin's tree has each node once, and each of its trees
# ends in one cluster, the one its starting clusters' frames are in
if {"helm" in $have} {
    vmdance -mol $m -sel "name CA" -algorithm helm -k 4 -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-k 5 -quiet 1
    set z [${R}::get zmatrix]
    set init [${R}::get initial]
    foreach s $init l [${R}::labels] { set fin($s) $l }
    set kept [lsort -integer [lmap s [array names fin] {expr {$fin($s) >= 0 ? $s : [continue]}}]]
    set raw [lsort -integer -unique [concat {*}[lmap r $z {lrange $r 0 1}]]]
    set clash [llength [lmap x $raw {expr {$x >= [llength $kept] && $x in $kept ? $x : [continue]}}]]
    set t [vmdance tree]
    set n0 [expr {[::tcl::mathfunc::max {*}$init] + 1}]
    set used {}
    set ok [expr {[dict get $t kind] eq "helm" && [dict get $t leaves] eq $kept && [llength [dict get $t merges]] == [llength $kept] - 4}]
    set j 0
    foreach r [dict get $t merges] {
        lassign $r a b
        foreach x [list $a $b] {
            if {$x in $used || !($x in $kept || ($x >= $n0 && $x < $n0 + $j))} { set ok 0 }
            lappend used $x
        }
        set under([expr {$n0 + $j}]) [concat [expr {[info exists under($a)] ? $under($a) : $a}] [expr {[info exists under($b)] ? $under($b) : $b}]]
        incr j
    }
    set ends {}
    foreach nd [concat $kept [lmap j [lsearch -all [dict get $t merges] *] {expr {$n0 + $j}}]] {
        if {$nd in $used} continue
        set leaves [expr {[info exists under($nd)] ? $under($nd) : $nd}]
        set fs [lsort -unique [lmap s $leaves {set fin($s)}]]
        if {[llength $fs] != 1} { set ok 0 }
        lappend ends {*}$fs
    }
    check "HELM trimmed ([expr {$n0 - [llength $kept]}] of $n0 starting clusters; $clash of the backend's numbers are both a merge's and a starting cluster's): each node once, each tree one cluster" [expr {
        $ok && [lsort -integer $ends] eq {0 1 2 3}}]
}

# --- the program and the library agree -------------------------------------------------------
if {$lib eq ""} {
    skip "the library" "no mdance_tcl library (set MDANCE_LIB)"
} else {
    use_lib
    vmdance -mol $m -sel "name CA" -k 5 -quiet 1
    check "the library's KMeans NANI labels are the program's" [expr {[${R}::labels] eq $labels_cli}]
    check "  it writes no file" [expr {[llength [lsearch -all -inline -not -glob [leftovers] *.csv]] == 0}]
    set p1 [vmdance prime]
    set s1 [vmdance similarity]
    use_cli
    vmdance -mol $m -sel "name CA" -k 5 -quiet 1
    set p2 [vmdance prime]
    set s2 [vmdance similarity]
    check "  PRIME's frames are the program's" [expr {$p1 eq $p2}]
    check "  and the similarity" [expr {[near [dict get $s1 isim] [dict get $s2 isim] 1e-6] && [dict get $s1 least_similar] eq [dict get $s2 least_similar]}]
    use_lib
    set e1 [err {vmdance -mol $m -sel "name CA" -algorithm equal -threshold 0.3 -reject-lowd 1 -min-samples 50 -quiet 1}]
    set n1 [expr {$e1 eq "" ? [${R}::nclusters] : "error"}]
    use_cli
    set e2 [err {vmdance -mol $m -sel "name CA" -algorithm equal -threshold 0.3 -reject-lowd 1 -min-samples 50 -quiet 1}]
    set n2 [expr {$e2 eq "" ? [${R}::nclusters] : "error"}]
    check "  an answer with no cluster: the library's as the program's ($n1, $n2)" [expr {$n1 eq $n2 && $n1 ne "error"}]
    check "  another library, once one is loaded, is refused" [string match "*restart VMD*" [err {::VMDance::Backend::configure -library $::fake}]]
    use_lib
    set f1 [vmdance pick -mol $m -sel "name CA" -method outliers -param 5]
    use_cli
    set f2 [vmdance pick -mol $m -sel "name CA" -method outliers -param 5]
    check "  and the picked frames" [expr {$f1 eq $f2 && [llength $f1] == 5}]
    # (the library is a build of its own: what it has is asked of it)
    use_lib
    if {"divine" ni [::VMDance::Backend::algorithms] || ![llength $dlabels]} {
        skip "DIVINE: the library against the program" "[expr {[llength $dlabels] ? "this library" : "this program"}] has no DIVINE (BUILD_DIVINE)"
    } else {
        set ok 1; set n 0
        foreach {opts l} $dlabels {
            # (CompSim below 50%: refused by the library, below)
            set e [err {vmdance -mol $m -sel "name CA" -algorithm divine {*}$opts -quiet 1}]
            if {[string match "*the library takes VMD with it*" $e]} continue
            if {$e ne "" || [${R}::labels] ne $l} { set ok 0 }
            incr n
        }
        check "  DIVINE: the library's labels are the program's ($n cases)" [expr {$ok && $n}]
        check "  DIVINE seeded by CompSim below 50%: the library refuses it (a split can crash it, and VMD)" [string match "*the library takes VMD with it*" [err {
            vmdance -mol $m -sel "name CA" -algorithm divine -kinit CompSim -quiet 1}]]
    }
    use_cli
}

# --- MDANCE's own labels, on the same coordinates -----------------------------------------------
# (tests/fixtures/mdance_3ptb.txt: MDANCE 0.4 run on the plugin's CSV by
# make_mdance_3ptb.tcl)
set ref [mdance_3ptb]
if {![dict size $ref]} {
    skip "MDANCE's labels of 3ptb" "no tests/fixtures/mdance_3ptb.txt"
} else {
    # KMeans NANI seeded at a stratified position on a half: frames 0-49 at
    # 10% are 5 positions 12.25 apart, the third 24.5
    set q50 [::VMDance::Job::check_cluster [list mol $m sel "name CA" last 49 algorithm kmeans k 4]]
    set c50 [::VMDance::Coords::extract $q50]
    exec $cli --algorithm kmeans --input [::VMDance::Coords::csv $c50] --output $jout --natoms [dict get $c50 natoms] --nclusters 4 --metric MSD --kinit StratAll --percentage 10 2>@1
    vmdance -mol $m -sel "name CA" -last 49 -k 4 -quiet 1
    check "KMeans NANI k 4 of frames 0-49: the plugin's labels are the program's" [expr {[${R}::labels] eq [dict get [::VMDance::Json::parse [read_text $jout]] labels]}]
    against_mdance "  KMeans NANI k 4 of frames 0-49" "CPP-MDANCE rounds a stratified seed's position half away from zero, MDANCE (NumPy) half to even: 24.5 is its row 25 of the frames by similarity, MDANCE's 24" [dict get $ref kmeans_first50_k4]
    if {"divine" in $have} {
        vmdance -mol $m -sel "name CA" -algorithm divine -k 4 -quiet 1
        check "DIVINE k 4: MDANCE's partition" [expr {[partition [${R}::labels]] eq [partition [dict get $ref divine_k4]]}]
        vmdance -mol $m -sel "name CA" -algorithm divine -k 5 -quiet 1
        against_mdance "DIVINE k 5" "its 34-frame cluster is split from a seed at a stratified position on a half, 16.5: CPP-MDANCE's row 17, MDANCE's 16" [dict get $ref divine_k5]
        vmdance -mol $m -sel "name CA" -algorithm divine -k 6 -anchors OutlierPair -threshold 0.3 -quiet 1
        check "DIVINE OutlierPair, smallest share 0.3 (k 6, 2 clusters): MDANCE's partition" [expr {[partition [${R}::labels]] eq [partition [dict get $ref divine_outlier_t0.3_k6]]}]
        vmdance -mol $m -sel "name CA" -algorithm divine -anchors OutlierPair -threshold 0.2 -end-mode points -quiet 1
        check "DIVINE -end-mode points, OutlierPair, smallest share 0.2: MDANCE's partition" [expr {[partition [${R}::labels]] eq [partition [dict get $ref divine_outlier_t0.2_points]]}]
        vmdance -mol $m -sel "name CA" -algorithm divine -k 6 -anchors SplinterPair -threshold 0.035 -quiet 1
        against_mdance "DIVINE SplinterPair, smallest share 0.035 (k 6)" "CPP-MDANCE rounds the share's frames, 3.5 of 100 to 4, where MDANCE truncates them to 3" [dict get $ref divine_splinter_t0.035_k6]
    }
}

# --- the plugin's measures, against direct computations ----------------------------------------
vmdance -mol $m -sel "name CA" -k 5 -quiet 1
set fm [${R}::measure frame_msd]
set ok 1
set sa [atomselect $m "name CA"]; set sb [atomselect $m "name CA"]
foreach i {0 17 42 99} {
    set l [lindex [${R}::labels] $i]
    $sa frame [lindex [${R}::frames] $i]; $sb frame [${R}::rep_frame $l]
    set r [measure rmsd $sa $sb]
    if {![near [lindex $fm $i] [expr {$r * $r}] 1e-4]} { set ok 0 }
}
check "a frame's MSD from its representative is VMD's RMSD squared (no fit)" $ok
set RM [${R}::measure rep_msd]
$sa frame [${R}::rep_frame 0]; $sb frame [${R}::rep_frame 3]
set r [measure rmsd $sa $sb]
check "  between two representatives too" [near [lindex $RM 0 3] [expr {$r * $r}] 1e-4]
# the mean structures, computed here from VMD's coordinates
foreach cl {0 1} {
    set sum [lrepeat [expr {3 * [$sa num]}] 0.0]
    foreach f [${R}::member_frames $cl] {
        $sa frame $f
        set sum [vecadd $sum [join [$sa get {x y z}]]]
    }
    set cen($cl) [vecscale [expr {1.0 / [${R}::size $cl]}] $sum]
}
set d [vecdist $cen(0) $cen(1)]
check "  between two clusters' mean structures" [near [lindex [${R}::measure centroid_msd] 0 1] [expr {$d * $d / [$sa num]}] 1e-4]
# a silhouette, by hand
set i 17
set l [lindex [${R}::labels] $i]
$sa frame [lindex [${R}::frames] $i]
set x [join [$sa get {x y z}]]
set dists {}
for {set cl 0} {$cl < 5} {incr cl} {
    set sum [lrepeat [expr {3 * [$sa num]}] 0.0]
    foreach f [${R}::member_frames $cl] { $sb frame $f; set sum [vecadd $sum [join [$sb get {x y z}]]] }
    lappend dists [expr {[vecdist $x [vecscale [expr {1.0 / [${R}::size $cl]}] $sum]] / sqrt([$sa num])}]
}
set a [lindex $dists $l]
set b [::tcl::mathfunc::min {*}[lreplace $dists $l $l]]
check "  a frame's silhouette from the mean structures" [near [lindex [${R}::measure silhouette] $i] [expr {($b - $a) / max($a, $b)}] 1e-4]
$sa delete; $sb delete
set T [vmdance transitions -counts 1]
set n 0
foreach l1 [lrange [${R}::labels] 0 end-1] l2 [lrange [${R}::labels] 1 end] { if {$l1 == 0 && $l2 == 1} { incr n } }
check "  the transitions counted" [expr {[lindex $T 0 1] == $n && [::tcl::mathop::+ {*}[concat {*}$T]] == 99}]
mol delete $m
::VMDance::Coords::forget

# --- MDANCE's reference runs -------------------------------------------------------------------
if {![file isdirectory [file join $::refruns results]]} {
    skip "MDANCE's reference runs" "not found (set MDANCE_REF_RUNS)"
} else {
    # (MDANCE's runs cluster the Cα atoms: their starting clusters' sums are
    # those of the Cα coordinates. On those atoms the two programs agree to
    # the last digit; on the backbone they are another clustering.)
    set mh [load_ref heptapeptide]
    set ca "name CA"
    check "the heptapeptide: 6001 frames, 48 backbone atoms, 12 Cα (the atoms MDANCE's runs cluster)" [expr {
        [molinfo $mh get numframes] == 6001 && [llength [::VMDance::Mol::atoms $mh backbone]] == 48 && [llength [::VMDance::Mol::atoms $mh $ca]] == 12}]
    foreach {kinit dir} {StratAll strat_all_6 StratReduced strat_reduced_6 CompSim comp_sim_6} {
        set f [lindex [glob -nocomplain [file join $::refruns results nani 1_heptapeptide $dir summary_6_*.csv]] 0]
        if {$f eq ""} { skip "NANI k 6 $kinit" "no reference summary"; continue }
        set t0 [clock milliseconds]
        vmdance -mol $mh -sel $ca -k 6 -kinit $kinit -quiet 1
        set d [maxdiff [fractions] [ref_fractions $f]]
        check "NANI k 6 $kinit on the Cα: MDANCE's cluster populations ([expr {([clock milliseconds] - $t0) / 1000.0}] s)" [expr {$d < 1e-9}]
    }
    set sc [ref_rows [file join $::refruns results nani 1_heptapeptide screen_strat_all_summary.csv]]
    set rows [vmdance elbow -mol $mh -sel $ca -ks {5 6 7 8 10} -quiet 1]
    foreach r $rows {
        set k [dict get $r k]
        set ref [lsearch -inline -index 0 -real $sc [expr {double($k)}]]
        if {$ref eq ""} continue
        set dch [pct [dict get $r ch] [lindex $ref 2]]; set ddb [pct [dict get $r db] [lindex $ref 3]]
        # (at k 5 MDANCE's scikit-learn stops at its tolerance, 1e-4, before
        # the k-means has converged; CPP-MDANCE goes on: 0.04%, and the labels
        # are scikit-learn's with tol=0)
        set tol [expr {$k == 5 ? 0.1 : 1e-4}]
        check "  the elbow scan at k $k: MDANCE's Calinski–Harabasz and Davies–Bouldin (within [format %.1e [expr {max($dch, $ddb)}]]%)" [expr {$dch <= $tol && $ddb <= $tol}]
    }
    # HELM whose first clustering has an empty cluster (starting cluster 16
    # of 100): its leaves numbered without gaps, as CPP-MDANCE numbers them
    if {"helm" in [::VMDance::Backend::algorithms]} {
        vmdance -mol $mh -sel backbone -algorithm helm -k 6 -initial 100 -initial-kinit StratAll -quiet 1
        set ns [llength [lsort -unique [${R}::get initial]]]
        set t [err {vmdance tree}]
        set t [expr {$t eq "" ? [vmdance tree] : {}}]
        check "HELM from 100 starting clusters, one of them empty ($ns left): its tree ([expr {[dict size $t] ? [llength [dict get $t merges]] : "none"}] merges)" [expr {
            [dict size $t] && [llength [dict get $t merges]] == $ns - 6 && [lindex [lsort -integer [${R}::get initial]] end] == $ns - 1}]
    }
    # HELM from MDANCE's own starting clusters
    set lf [file join $::refruns results helm 1_betaheptapeptide labels_60_comp_sim.csv]
    set hs [file join $::refruns results helm 1_betaheptapeptide inter_6 inter_helm_summary_6.csv]
    if {"helm" in [::VMDance::Backend::algorithms] && [file exists $lf]} {
        vmdance -mol $mh -sel $ca -algorithm helm -k 6 -initial-labels $lf -quiet 1
        check "HELM from MDANCE's 60 starting clusters (its label file read as is): 6 clusters of every frame" [expr {
            [${R}::nclusters] == 6 && [::tcl::mathop::+ {*}[${R}::sizes]] == 6001 && [llength [${R}::get zmatrix]] == 54 &&
            [llength [lsort -unique [${R}::get initial]]] == 60}]
        if {[file exists $hs]} {
            set d [maxdiff [fractions] [ref_fractions $hs]]
            check "  HELM Inter k 6 on the Cα: MDANCE's populations (to its summary's 6 decimals)" [expr {$d < 5e-7}]
        }
    }
    mol delete $mh
    ::VMDance::Coords::forget
    set mp [load_ref proteing]
    set f [file join $::refruns results nani 2_protein-g strat_all_6 summary_6_strat_all.csv]
    check "protein G: 1923 frames, 225 backbone atoms, 56 Cα" [expr {
        [molinfo $mp get numframes] == 1923 && [llength [::VMDance::Mol::atoms $mp backbone]] == 225 && [llength [::VMDance::Mol::atoms $mp $ca]] == 56}]
    if {[file exists $f]} {
        vmdance -mol $mp -sel $ca -k 6 -quiet 1
        set d [maxdiff [fractions] [ref_fractions $f]]
        check "  NANI k 6 StratAll on the Cα: MDANCE's populations" [expr {$d < 1e-9}]
    }
    mol delete $mp
}
}
done
} err]} { puts "FAIL test_reference crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
