# What the second round of reviews found in what the numbers mean (g7),
# each kept from coming back (text mode: the fake backend, and the real one
# where only it can tell, skipped without it):
#   F07  HELM's starting clusters are counted as the backend gets them: the
#        first clustering's empty ones left out, and with a trim those that
#        -min-samples leaves out (HELM merged all into one cluster, which was
#        published, and an elbow kept as "ok"; a -trim-k the checks took
#        failed "trimK is too large!")
#   F15  a cluster without frames has no MSD and no iSIM (the backend's 0
#        read as the tightest cluster), and a scan's record counts the
#        clusters with frames (k_actual said k)
#   F16  HELM's scores with a trim are those of its clustered frames, as
#        MDANCE's and eQUAL's (the trimmed frames were one more cluster)
#   F13  every cluster a frame alone has no scores (CPP-MDANCE's CH 1 and
#        DB 0 were published, and the best of a sweep)
#   F12  eQUAL's -min-samples is checked only with -reject-lowd, as the
#        backend reads it (2 to 9 frames were refused)
#   F46  transitions: a row with nothing counted is "", as in the export and
#        the plot (it was 0, a probability)
#   F47  the RMSD² from the representative is between half the MSD within
#        and all of it (said to be twice as large; the tip is test_gui's)
#   F70  PRIME's -trim-frac trims the largest cluster only (said: each)
#   F71  a run keeps PRIME and the similarity asked of it; the scans and the
#        picks are the last ones, beside the runs (the papers and decks said
#        each run kept its own)
#   F32  a scan says what it reads, and when it is not what the current run
#        clustered (the documented elbow after a backbone run scanned Cα
#        with StratAll); the listings give a scan its options
#   F56  a sweep's seeding given in -params is refused: it is -seedings (it
#        was replaced by StratAll without a word)
# And what the review of those fixes found:
#   sweep-refused  a sweep where nothing ran is refused, as an elbow is (it
#                  replaced the sweep there was with records not run)
#   scan-ks        a scan's messages name its -ks, not -k (which an elbow
#                  ignores); with -eps (k 0) "two or more", not "more than -k (0)"
#   trim-val       what -trim-val's cut left is counted once HELM has run
#                  (runs of one cluster or none were published, elbow
#                  records of one cluster kept as ok)
#   passes         HELM's scores of a scan's every k are made in two passes
#                  over the frames (two at every k: an elbow 2.4 times as long)
#   import         an imported HELM session with a trim is scored as a run is
#   sessions       a session saved before opens without the backend's
#                  placeholders (an empty cluster's MSD and iSIM, the scores
#                  of single frames, a record's count of clusters)
#   docs           README's listing gives its clustering's scores; the
#                  paper's HELM scores are the program's without a trim; the
#                  decks and the design figure made again from their sources
# (The papers and the decks are kept beside the repository, in folders git
# ignores: their checks run where they are, and skip where they are not. The
# constructed states3, the papers' data, is looked for in VMDANCE_CONSTRUCTED,
# else manuscripts/shared/data/constructed.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_g7.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set G7 [file join $::out hardening2_g7]
file delete -force $G7
file mkdir $G7

# A multi-model PDB of frames, each a list of atoms' {x y z}.
proc g7_pdb {f frames} {
    set fh [open $f w]
    set i 0
    foreach fr $frames {
        puts $fh [format "MODEL     %4d" [incr i]]
        set a 0
        foreach xyz $fr {
            incr a
            lassign $xyz x y z
            puts $fh [format "ATOM  %5d  CA  ALA A%4d    %8.3f%8.3f%8.3f  1.00  0.00           C" $a $a $x $y $z]
        }
        puts $fh ENDMDL
    }
    puts $fh END
    close $fh
}
# Squared distance of two rows.
proc g7_d2 {a b} {
    set s 0.0
    foreach x $a y $b { set s [expr {$s + ($x - $y) * ($x - $y)}] }
    return $s
}
# Calinski–Harabasz and Davies–Bouldin of rows by labels as scikit-learn
# computes them, in plain Tcl: the frames labelled 0 or more (noise 1: -1
# one more cluster, as CPP-MDANCE's HELM scores them).
proc g7_scores {rows labels {noise 0}} {
    set dim [llength [lindex $rows 0]]
    set N 0
    foreach r $rows l $labels {
        if {$l < 0 && !$noise} continue
        if {![info exists cnt($l)]} { set cnt($l) 0; set sum($l) [lrepeat $dim 0.0] }
        set sum($l) [lmap a $sum($l) x $r {expr {$a + $x}}]
        incr cnt($l)
        incr N
    }
    set ls [lsort -integer [array names cnt]]
    set K [llength $ls]
    set all [lrepeat $dim 0.0]
    foreach l $ls {
        set cen($l) [lmap a $sum($l) {expr {$a / $cnt($l)}}]
        set all [lmap a $all x $sum($l) {expr {$a + $x}}]
    }
    set mean [lmap a $all {expr {$a / $N}}]
    set B 0.0
    foreach l $ls { set B [expr {$B + $cnt($l) * [g7_d2 $cen($l) $mean]}] }
    set W 0.0
    foreach l $ls { set S($l) 0.0 }
    foreach r $rows l $labels {
        if {$l < 0 && !$noise} continue
        set d2 [g7_d2 $r $cen($l)]
        set W [expr {$W + $d2}]
        set S($l) [expr {$S($l) + sqrt($d2)}]
    }
    set ch [expr {$W == 0 ? 1.0 : $B * ($N - $K) / ($W * ($K - 1.0))}]
    set db 0.0
    foreach a $ls {
        set worst 0.0
        foreach b $ls {
            if {$a == $b} continue
            set d [expr {sqrt([g7_d2 $cen($a) $cen($b)])}]
            if {$d > 0} { set worst [expr {max($worst, ($S($a) / $cnt($a) + $S($b) / $cnt($b)) / $d)}] }
        }
        set db [expr {$db + $worst}]
    }
    list $ch [expr {$db / $K}]
}
# The rows the current clustering was made from.
proc g7_rows {} { ::VMDance::Coords::rows $::VMDance::Coords::C }
# What the command said (_say), whatever -quiet, while script runs.
proc g7_said {script} {
    set ::g7said {}
    rename ::VMDance::_say ::VMDance::_say_g7
    proc ::VMDance::_say {quiet msg} { lappend ::g7said $msg }
    try { uplevel 1 $script } finally {
        rename ::VMDance::_say {}
        rename ::VMDance::_say_g7 ::VMDance::_say
    }
    return $::g7said
}
# A file of the repository's text, "" when it is not there (an install).
proc g7_text {rel} {
    set f [file join $::root {*}[split $rel /]]
    if {![file isfile $f]} { return "" }
    read_text $f
}
# The papers' files of a name, beside the repository (none in a clone).
proc g7_papers {name} { lsort [glob -nocomplain -tails -directory $::root manuscripts/*/$name] }

if {[catch {
package require vmdance
set R ::VMDance::Results
set J ::VMDance::Job
set A ::VMDance::Algo
set ::VMDance::Prefs::file ""
use_fake
fake_env

# Six frames of four atoms: frames 0-2 the same, 3-5 near each other
# elsewhere. The fake backend's KMeans seeds k = 3 at frames 0, 2 and 5:
# its cluster 1, seeded on a copy of frame 0, keeps no frame.
set six [file join $G7 six.pdb]
set fa {{0 0 0} {1.5 0 0} {3 0 0} {4.5 0 0}}
set frames [list $fa $fa $fa]
foreach d {0.0 0.2 0.4} { lappend frames [lmap a $fa {lassign $a x y z; list $x [expr {6 + $d}] [expr {$z + $d / 2}]}] }
g7_pdb $six $frames
set m6 [mol new $six waitfor all]
set m [load_system two_state]

# --- F15: a cluster without frames ---------------------------------------------------------------------
vmdance -mol $m6 -sel all -k 3 -kinit KmeansPP -quiet 1
check "F15: (the fake leaves the middle cluster empty)" [expr {[dict get [vmdance info] sizes] eq {3 0 3}}]
set g [vmdance get 1]
check "  an empty cluster has no MSD (the backend's 0 read as the tightest); the others keep theirs" [expr {
    [dict get $g msd] eq "" && [dict get [vmdance get 0] msd] ne "" && [dict get [vmdance get 2] msd] > 0}]
check "  clusters -sort msd lists it last" [expr {[lindex [vmdance clusters -sort msd] end 0] == 1}]
set s [vmdance similarity]
check "  and it has no iSIM, nor a least similar frame, before the last cluster too (the fake gives it 1)" [expr {
    [dict get $s clusters 1] eq "" && [dict get $s least_similar 1] == -1 && [dict get $s clusters 0] ne ""}]
set o [${J}::output {nClusters 4 labels {0 0 2 3 3} clusterSizes {2 0 1 2} representatives {0 -1 2 3} clusterMSD {0.5 0.0 0.0 0.4} scores {calinskiHarabasz 3.0 daviesBouldin 0.5}} 5]
check "  the backend's answer: the empty cluster's MSD \"\", a frame alone keeps MDANCE's 0" [expr {[dict get $o msd] eq {0.5 {} 0.0 0.4}}]
check "  a scan's record counts the clusters with frames" [expr {[dict get [${J}::_record $o] nclusters] == 3 && [dict get $o nclusters] == 4}]
set e [vmdance elbow -mol $m6 -sel all -kinit KmeansPP -ks {2 3} -quiet 1]
check "  an elbow at k 3 found 2 clusters (k_actual 3 before)" [expr {[dict get [lindex $e 1] nclusters] == 2 && [dict get [lindex $e 0] nclusters] == 2}]
vmdance export $G7 -prefix f15 -items elbow
set rows [csv_rows [file join $G7 f15_elbow.csv]]
check "  and the export's k_actual says so" [expr {[lindex $rows 2 0] == 3 && [lindex $rows 2 1] == 2}]
check "  the record made the clustering keeps the backend's k" [expr {[dict get [vmdance elbow load 3] nclusters] == 3}]
vmdance run clear

# --- F13: every cluster a frame alone -------------------------------------------------------------------
set rows [vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 24} -seedings KmeansPP -quiet 1]
check "F13: k 24 of 24 frames has no scores (the backend's placeholders)" [expr {
    [dict get [lindex $rows 1] ch] eq "" && [dict get [lindex $rows 1] db] eq "" && [dict get [lindex $rows 0] db] ne ""}]
check "  and is never the best of a sweep" [expr {[dict get [vmdance sweep best db] k] == 2 && [dict get [vmdance sweep best ch] k] == 2}]
set i [vmdance -mol $m -sel all -k 24 -kinit KmeansPP -quiet 1]
check "  nor of a clustering" [expr {[dict get $i ch] eq "" && [dict get $i db] eq ""}]
set o [${J}::output {nClusters 3 labels {0 1 -1 2} representatives {0 1 3} score_calinskiHarabasz 1.0 score_daviesBouldin 0.0} 4]
set o2 [${J}::output {nClusters 3 labels {0 0 1 2} representatives {0 2 3} scores {calinskiHarabasz 7.5 daviesBouldin 0.3}} 4]
check "  every clustered frame alone, noise beside: none; a pair beside single frames keeps them" [expr {
    [dict get $o ch] eq "" && [dict get $o db] eq "" && [dict get $o2 ch] == 7.5 && [dict get $o2 db] == 0.3}]
vmdance run clear

# --- F12: eQUAL's -min-samples ---------------------------------------------------------------------------
check "F12: eQUAL on 5 frames with the defaults is taken (-min-samples 10 is read only with -reject-lowd)" [expr {
    ![catch {vmdance -mol $m -sel all -algorithm equal -threshold 1 -last 4 -quiet 1} r] && [dict get $r frames] == 5}]
check "  with -reject-lowd 1 it is refused, naming -min-samples" [string match "*-min-samples 10: at most the 5 frames*" \
    [err {vmdance -mol $m -sel all -algorithm equal -threshold 1 -last 4 -reject-lowd 1 -quiet 1}]]
check "  and -n-seeds still is, whatever -reject-lowd" [string match "*-n-seeds 20: at most the 5 frames*" \
    [err {vmdance -mol $m -sel all -algorithm equal -threshold 1 -last 4 -n-seeds 20 -quiet 1}]]
vmdance run clear

# --- F46: transitions with nothing counted ----------------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set n [llength [vmdance labels]]
set n [expr {$n / 2}]
check "F46: transitions at a lag of every clustered frame: \"\" (nothing counted), counts 0" [expr {
    [vmdance transitions -lag $n] eq {{{} {}} {{} {}}} && [vmdance transitions -lag $n -counts 1] eq {{0 0} {0 0}}}]
set first [lindex [vmdance labels] 1]
set lag [expr {$n / 2 + 1}]
set t [vmdance transitions -lag $lag]
set other [expr {1 - $first}]
check "  a row with nothing counted is \"\", the other sums to 1" [expr {
    [lindex $t $other] eq {{} {}} && abs([::tcl::mathop::+ {*}[lindex $t $first]] - 1) < 1e-3}]
vmdance export $G7 -prefix f46 -items transitions -lag $lag
set same 1
foreach r [csv_rows [file join $G7 f46_transitions.csv]] {
    lassign $r a b cnt p
    if {![string is integer -strict $a] || $b < 0} continue
    set v [lindex $t $a $b]
    if {($v eq "") != ($p eq "") || ($v ne "" && abs($v - $p) > 1e-4)} { set same 0 }
}
check "  every cell as the export's probability" $same
vmdance run clear

# --- F56: a sweep's seeding in -params ---------------------------------------------------------------------
check "F56: a seeding in a sweep's -params is refused, naming -seedings (it was replaced by StratAll)" [expr {
    [string match "*-params of KMeans NANI gives -kinit Random*-seedings*" [err {vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -params {kmeans {kinit Random}} -quiet 1}]] &&
    [string match "*-params of HELM gives -initial-kinit KmeansPP*-seedings*first clustering*" [err {vmdance sweep -mol $m -sel all -algorithms helm -ks {2 3} -params {helm {initial 8 initial-kinit KmeansPP}} -quiet 1}]] &&
    [string match "*-seedings*" [err {vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -seedings CompSim -params {kmeans {kinit Bogus}} -quiet 1}]]}]
check "  the other parameters are still taken (-params {kmeans {percentage 50}}), and the seedings swept" [expr {
    ![catch {vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -seedings {StratAll KmeansPP} -params {kmeans {percentage 50}} -quiet 1} r] &&
    [lmap x $r {dict get $x seeding}] eq {StratAll StratAll KmeansPP KmeansPP} && [lmap x $r {dict get $x status}] eq {ok ok ok ok}}]

# --- F07: HELM's starting clusters as the backend gets them -----------------------------------------------
# (the first clustering of 3 on the six frames leaves 2 with frames)
set e [err {vmdance -mol $m6 -sel all -algorithm helm -k 2 -initial 3 -initial-kinit KmeansPP -quiet 1}]
check "F07: HELM refused when the first clustering leaves k or fewer starting clusters, naming -initial" [expr {
    [string match "*-initial 3: the first clustering left 2 starting clusters with frames*-k (2)*" $e] && ![string match "*-initial-kinit KmeansPP*" $e]}]
check "  and nothing was published" [expr {![${R}::has_data]}]
set e [vmdance elbow -mol $m6 -sel all -algorithm helm -ks {1 2} -initial 3 -initial-kinit KmeansPP -quiet 1]
check "  an elbow keeps such a k as not run, and runs the others" [expr {
    [dict get [lindex $e 0] status] eq "ok" && [string match "not run: -initial 3*" [dict get [lindex $e 1] message]]}]
check "  and refuses a scan where no k can be run" [string match "*no value of k can be run: -initial 4: the first clustering left 3*" \
    [err {vmdance elbow -mol $m6 -sel all -algorithm helm -ks {3 4} -initial 4 -initial-kinit KmeansPP -quiet 1}]]
set r [vmdance sweep -mol $m6 -sel all -algorithms helm -ks {1 2} -seedings KmeansPP -params {helm {initial 3}} -quiet 1]
check "  a sweep too" [expr {[dict get [lindex $r 0] status] eq "ok" && [string match "not run: -initial 3*" [dict get [lindex $r 1] message]]}]
# a label file of 24 frames: three clusters of 6 frames, three of 2
set lf [file join $G7 starts.csv]
set fh [open $lf w]
foreach l {0 0 0 0 0 0 1 1 1 1 1 1 2 2 2 2 2 2 3 3 4 4 5 5} { puts $fh $l }
close $fh
check "  a trim: -min-samples leaves out the small ones first (\"trimK is too large!\" in the backend)" [string match \
    "*-trim-k 2: -min-samples 5: HELM trims from the starting clusters of 5 frames or more, 3 of the 6*" \
    [err {vmdance -mol $m -sel all -algorithm helm -k 1 -initial-labels $lf -trim-start 1 -trim-k 2 -min-samples 5 -quiet 1}]]
check "  -trim-k 1 there is taken, as is -trim-k 2 without them" [expr {
    ![catch {vmdance -mol $m -sel all -algorithm helm -k 1 -initial-labels $lf -trim-start 1 -trim-k 1 -min-samples 5 -quiet 1}] &&
    ![catch {vmdance -mol $m -sel all -algorithm helm -k 1 -initial-labels $lf -trim-start 1 -trim-k 2 -min-samples 2 -quiet 1}]}]
check "  -trim-val with too few left after -min-samples is refused too" [string match "*-min-samples 6:*3 of the 6, not more than -k (3)*" \
    [err {vmdance -mol $m -sel all -algorithm helm -k 3 -initial-labels $lf -trim-start 1 -trim-val 1.0 -min-samples 6 -quiet 1}]]
set e [vmdance elbow -mol $m -sel all -algorithm helm -ks {1 2} -initial-labels $lf -trim-start 1 -trim-k 1 -min-samples 5 -quiet 1]
check "  an elbow's k beyond them is not run" [expr {[dict get [lindex $e 0] status] eq "ok" && [string match "not run: -trim-k 1*" [dict get [lindex $e 1] message]]}]
# (-min-samples below 1: a share of the frames, in C floats as the backend
# has it: 0.29 of 100 frames is 29, which a double makes 28)
set p [${A}::check_params helm {trim-start 1 trim-k 1 min-samples 0.29}]
check "  -min-samples a share, counted as the backend counts it (0.29 of 100 frames: 29)" [expr {
    [string match "*of 29 frames or more, 2 of the 3*" [err {${A}::check_starting 1 $p {28 30 42} 100}]] &&
    [err {${A}::check_starting 1 [dict replace $p min-samples 0.28] {28 30 42} 100}] eq ""}]
vmdance run clear

# --- what the review of these fixes found ------------------------------------------------------------------
# (sweep-refused: a sweep where nothing ran is refused, as an elbow is; it
# replaced the sweep there was with a table of records not run)
vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -seedings KmeansPP -quiet 1
set before [vmdance sweep show]
set e [err {vmdance sweep -mol $m6 -sel all -algorithms helm -ks {2 3} -seedings KmeansPP -params {helm {initial 3}} -quiet 1}]
check "review: a sweep where no configuration can run is refused, and the sweep there was is kept" [expr {
    [string match "vmdance sweep: no configuration can be run: -initial*" $e] && [llength $before] == 2 && [vmdance sweep show] eq $before}]
fake_env MDANCE_FAKE_NO_DIVINE 1
set e [err {vmdance sweep -mol $m -sel all -algorithms divine -ks {2 3} -quiet 1}]
fake_env
check "  one of an algorithm the backend was not built with too" [expr {
    [string match "*no configuration can be run: DIVINE is not in this build of the backend" $e] && [vmdance sweep show] eq $before}]
# (scan-ks: a scan's refusal names its -ks, which it takes, not -k, which an
# elbow ignores (a record names its own k); with -eps, k 0, HELM merges two
# or more: "1, not more than -k (0)" was said)
set e [err {vmdance elbow -mol $m6 -sel all -algorithm helm -ks {2 3} -initial 3 -initial-kinit KmeansPP -quiet 1}]
check "review: a scan's refusal names its -ks, not -k" [expr {
    [string match "*no value of k can be run: -initial 3: *more than -ks (2): use -ks below 2, or more starting clusters*" $e] && ![regexp {(^|[ (])-k[ )]} $e]}]
set e [vmdance elbow -mol $m6 -sel all -algorithm helm -ks {1 2 3} -initial 3 -initial-kinit KmeansPP -quiet 1]
check "  its records not run name their own k, before it runs and once HELM's first clustering is made" [expr {
    [string match "not run: *more than -k (2)*" [dict get [lindex $e 1] message]] && [string match "not run: *-k (3)*" [dict get [lindex $e 2] message]]}]
set e [err {vmdance sweep -mol $m6 -sel all -algorithms helm -ks {2 3} -seedings KmeansPP -params {helm {initial 3}} -quiet 1}]
check "  a sweep's too" [expr {[string match "*no configuration can be run: *-ks (3)*" $e] && ![regexp {(^|[ (])-k[ )]} $e]}]
set e [err {vmdance -mol $m -sel all -algorithm helm -k 0 -eps 0.5 -initial-labels $lf -trim-start 1 -trim-k 2 -min-samples 5 -quiet 1}]
check "  with -eps (k 0) what is left must be two or more, said so" [expr {
    [string match "*-trim-k 2: -min-samples 5: *3 of the 6; 2 fewer leaves 1: HELM merges two or more (use -trim-k below 2, *" $e] && ![string match "*-k (0)*" $e]}]
set p [${A}::check_params helm {trim-start 1 trim-val 1.0 min-samples 5}]
check "  -trim-val's too" [string match "*5 frames or more, 1 of the 3: HELM merges two or more (use a smaller -min-samples*" [err {${A}::check_starting 0 $p {6 2 2} 10}]]
# (trim-val: what -trim-val's cut left, an MSD the backend computes, is
# counted once HELM has run: runs of one cluster or none were published, and
# an elbow kept such k as ok)
set p [${A}::check_params helm {trim-start 1 trim-val 0.5}]
set init {0 0 1 1 2 2 3 3 4 4}
check "review: what -trim-val left is counted once HELM has run" [expr {
    [err {${A}::check_trimmed 2 $p $init {0 0 -1 -1 1 1 -1 -1 -1 -1}}] eq
        "-trim-val 0.5: the trim kept 2 of HELM's 5 starting clusters, not more than -k (2): HELM had nothing to merge (use a larger -trim-val)" &&
    [string match "*kept 0 of HELM's 5 *" [err {${A}::check_trimmed 2 $p $init [lrepeat 10 -1]}]] &&
    [string match "*kept 1 of HELM's 5 starting clusters: HELM merges two or more*" [err {${A}::check_trimmed 0 $p $init {0 0 -1 -1 -1 -1 -1 -1 -1 -1}}]] &&
    [err {${A}::check_trimmed 2 $p $init {0 0 -1 -1 1 1 2 2 -1 -1}}] eq "" &&
    [err {${A}::check_trimmed 2 [dict replace $p trim-start 0] $init [lrepeat 10 -1]}] eq "" &&
    [err {${A}::check_trimmed 2 [dict replace $p trim-val 0 trim-k 1] $init [lrepeat 10 -1]}] eq ""}]
# (passes: the scores of HELM's clustered frames, of a scan's every k, are
# made in two passes over the frames, each cluster that several have once:
# two at every k made a HELM elbow with a trim 2.4 times as long)
proc g7_sizes {labels k} {
    set s [lrepeat $k 0]
    foreach l $labels { if {$l >= 0} { lset s $l [expr {[lindex $s $l] + 1}] } }
    return $s
}
proc g7_pass {args} { incr ::g7passes }
proc g7_passes {script} {
    set ::g7passes 0
    trace add execution ::VMDance::Coords::each enter g7_pass
    try { uplevel 1 $script } finally { trace remove execution ::VMDance::Coords::each enter g7_pass }
    return $::g7passes
}
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
set L [${R}::labels]
set rows [g7_rows]
set C $::VMDance::Coords::C
# (three clusterings with noise: the second merges the first's clusters 1
# and 2, and has its cluster 0)
set L1 [lreplace $L 0 1 -1 -1]
set L2 [lmap l $L1 {expr {$l == 2 ? 1 : $l}}]
set L3 [lreplace $L end end -1]
set cls [list [list $L1 3] [list $L2 2] [list $L3 3]]
set ok [expr {[g7_passes {set sc [::VMDance::Measure::scores $C $cls]}] == 2 && [llength $sc] == 3}]
foreach s $sc c $cls {
    lassign [g7_scores $rows [lindex $c 0]] ch db
    if {$ch eq "" || ![near [lindex $s 0] $ch 1e-9] || ![near [lindex $s 1] $db 1e-9]} { set ok 0 }
}
check "review: the scores of three clusterings in two passes over the frames, each as scikit-learn has it" $ok
set ::VMDance::Measure::sums_most 1
set n [g7_passes {set sc2 [::VMDance::Measure::scores $C $cls]}]
set ::VMDance::Measure::sums_most 2000000
check "  two more for each share of the clusters' sums that fit in memory (the same scores)" [expr {$n == 6 && $sc2 eq $sc}]
set recs {}
foreach c $cls k {3 4 5} status {ok ok error} {
    lassign $c l nk
    set cl [dict create labels $l nclusters $nk sizes [g7_sizes $l $nk] ch 9.0 db 9.0]
    lappend recs [dict create k $k status $status nclusters $nk ch 9.0 db 9.0 sizes [dict get $cl sizes] clustering $cl]
}
set n [g7_passes {set out [${J}::_scan_scores $C $recs helm 0.9]}]
set ok [expr {$n == 2 && [lindex $out 2] eq [lindex $recs 2]}]
foreach r [lrange $out 0 1] s [lrange $sc 0 1] {
    if {[dict get $r ch] != [lindex $s 0] || [dict get $r db] != [lindex $s 1] || [dict get $r clustering ch] != [lindex $s 0] || [dict get $r clustering db] != [lindex $s 1]} { set ok 0 }
}
check "  a scan's HELM records scored so, with their clusterings (a record that failed left as it was)" $ok
check "  a sweep's of another algorithm are the backend's" [expr {
    [${J}::_scan_scores $C [lmap r $recs {dict set r algorithm kmeans}] "" 0.9] eq [lmap r $recs {dict set r algorithm kmeans}]}]
vmdance run clear
# (import: an imported HELM session with a trim is scored as a run is, its
# clustered frames: the file's scores are CPP-MDANCE's)
set text [read_text [file join $::fixtures old_helm.mdance]]
set res [dict get $text results]
dict set res labels {0 0 0 0 0 0 0 0 0 0 -1 -1 1 1 1 1 1 1 1 1 1 1 -1 -1}
dict set res clusterSizes {10 10}
dict set res representatives {0 12}
dict set res score_calinskiHarabasz 999.0
dict set res score_daviesBouldin 9.0
dict set res inputParams [dict merge [dict get $res inputParams] {trim-start 1 trim-k 1}]
dict set text results $res
set hf [file join $G7 trimmed_helm.mdance]
set fh [open $hf w]
puts $fh $text
close $fh
set i [vmdance session import $hf -mol $m]
lassign [g7_scores [g7_rows] [${R}::labels]] ch db
check "review: an imported HELM session with a trim is scored on its clustered frames (the file's CH 999, DB 9 were kept)" [expr {
    [dict get $i noise] == 4 && [near [dict get $i ch] $ch 1e-9] && [near [dict get $i db] $db 1e-9] && ![near [dict get $i ch] 999.0 1e-3]}]
vmdance run clear
# (sessions: one saved before opens without the backend's placeholders: an
# empty cluster's MSD and iSIM of 0, the scores of single frames, a scan's
# record counting its empty clusters)
vmdance -mol $m6 -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance similarity
vmdance elbow -mol $m6 -sel all -kinit KmeansPP -ks {2 3} -quiet 1
vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 24} -seedings KmeansPP -quiet 1
set sf [file join $G7 before.vmdance]
vmdance session save $sf
set fh [open $sf rb]
set text [encoding convertfrom utf-8 [zlib gunzip [read $fh]]]
close $fh
set nl [string first \n $text]
set d [string range $text [expr {$nl + 1}] end]
# (as the plugin saved them before: the backend's placeholders back in)
set runs [dict get $d runs]
lassign [lindex $runs end] id label a
dict set a msd [lreplace [dict get $a msd] 1 1 0.0]
dict set a extras similarity cluster [lreplace [dict get $a extras similarity cluster] 1 1 1.0]
dict set a extras similarity outliers [lreplace [dict get $a extras similarity outliers] 1 1 0]
lset runs end [list $id $label $a]
dict set d runs $runs
set recs [dict get $d elbow records]
lset recs 1 [dict replace [lindex $recs 1] nclusters 3]
dict set d elbow records $recs
set recs [dict get $d sweep records]
set r [lindex $recs 1]
dict set r ch 1.0; dict set r db 0.0; dict set r clustering ch 1.0; dict set r clustering db 0.0
lset recs 1 $r
dict set d sweep records $recs
set fh [open $sf wb]
puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "[string range $text 0 [expr {$nl - 1}]]\n$d"]]
close $fh
vmdance run clear
vmdance session load $sf
set s [::VMDance::similarity_info]
check "review: a session saved before opens without the backend's placeholders: an empty cluster's MSD and iSIM" [expr {
    [${R}::sizes] eq {3 0 3} && [dict get [vmdance get 1] msd] eq "" && [dict get $s clusters 1] eq "" && [dict get $s least_similar 1] == -1 &&
    [dict get $s clusters 0] ne ""}]
check "  a scan's record counts the clusters with frames" [expr {[dict get [lindex [vmdance elbow show] 1] nclusters] == 2}]
check "  every cluster a frame alone has no scores, and is not the best of the sweep" [expr {
    [dict get [lindex [vmdance sweep show] 1] ch] eq "" && [dict get [lindex [vmdance sweep show] 1] db] eq "" &&
    [dict get [vmdance sweep best db] k] == 2}]
vmdance run clear

# --- F70: PRIME's trim --------------------------------------------------------------------------------------
set tip [lindex [dict get [vmdance parameters prime] -trim-frac] 4]
check "F70: PRIME's -trim-frac is the largest cluster's (c0), the others used whole" [expr {
    [string match "*largest cluster*" $tip] && [string match "*other clusters are used whole*" $tip] && ![string match "*each cluster*" $tip]}]
set doc [g7_text docs/parameters.rst]
if {$doc eq ""} { skip "  the parameters' page" "docs/parameters.rst not there" } else {
    check "  the parameters' page says the same (made from the table)" [expr {[string first $tip $doc] >= 0}]
}

# --- F32: what a scan reads ---------------------------------------------------------------------------------
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set said [g7_said {vmdance elbow -mol $m -ks {2 3} -quiet 1}]
check "F32: a scan says the atoms, frames and molecule it reads" [string match "scanning KMeans NANI at k = 2, 3: 24 frames of name CA (8 atoms) of molecule $m" [lindex $said 0]]
check "  and that it is not what the current run clustered, which it does not follow" [string match \
    "note: not what run * clustered (all (8 atoms) of molecule $m, KMeans NANI -kinit KmeansPP): a scan takes its own options*" [lindex $said 1]]
set said [g7_said {vmdance elbow -mol $m -sel all -kinit KmeansPP -ks {2 3} -quiet 1}]
check "  no note when it is the run's" [expr {[llength $said] == 1 && [string match "scanning KMeans NANI -kinit KmeansPP at k = 2, 3: 24 frames of all*" [lindex $said 0]]}]
set said [g7_said {vmdance sweep -mol $m -sel all -first 2 -algorithms kmeans -ks {2 3} -seedings KmeansPP -quiet 1}]
check "  a sweep too" [expr {[string match "sweeping 2 configurations: 22 frames of all (8 atoms)*" [lindex $said 0]] && [string match "note: not what run *" [lindex $said 1]]}]
# (the listings give the scans the clustering's options)
set bad {}
foreach f [list docs/quickstart.rst README.md {*}[g7_papers manuscript.tex] presentation/make_guide.js presentation/make_deck.js] {
    foreach line [split [g7_text $f] \n] {
        if {[regexp {vmdance elbow -(from|ks)} $line] && ![string match "*-sel *" $line]} { lappend bad "$f: [string trim $line]" }
    }
}
check "  the listings' elbow scans give their atoms ([join $bad {; }])" [expr {![llength $bad]}]
vmdance run clear

# --- F71: what a run keeps ----------------------------------------------------------------------------------
set r1 [dict get [vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1] run]
vmdance prime
vmdance elbow -mol $m -sel all -kinit KmeansPP -ks {2 3} -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 2
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance elbow -mol $m -sel all -kinit KmeansPP -ks {4 5} -quiet 1
vmdance pick -mol $m -sel all -method outliers -param 5
vmdance run $r1
check "F71: back to run 1: its PRIME, but the last elbow scan and picks (beside the runs)" [expr {
    [dict size [${R}::extra prime]] && [lmap r [vmdance elbow show] {dict get $r k}] eq {4 5} && [llength [vmdance pick show]] == 5}]
set bad {}
set read 0
set said {}
foreach f [g7_papers manuscript.tex] { lappend said $f "*each with its elbow scan*" }
foreach f [g7_papers figures/fig_design.tex] { lappend said $f "*each with its scans*" }
lappend said presentation/make_guide.js "*each keeps its scans*" presentation/make_deck.js "*each with its scans*"
foreach {f pat} $said {
    set t [g7_text $f]
    if {$t ne ""} { incr read }
    if {[string match $pat $t]} { lappend bad $f }
}
if {!$read} { skip "  the papers and decks" "not beside the repository here" } else {
    check "  the papers and decks do not say each run keeps its scans and picks ([join $bad {, }])" [expr {![llength $bad]}]
}
# (built: the decks and the paper's design figure are made of those sources,
# and were not made again)
set bad {}
set seen 0
foreach f [list presentation/VMDance.pptx presentation/VMDance_guide.pptx {*}[g7_papers figures/fig_design.pdf]] {
    set path [file join $::root {*}[split $f /]]
    if {![file isfile $path]} continue
    if {[file extension $f] eq ".pdf"} { set cmd [list pdftotext $path -] } else { set cmd [list unzip -p $path {ppt/slides/*.xml}] }
    if {[auto_execok [lindex $cmd 0]] eq "" || [catch {exec {*}$cmd 2>/dev/null} t]} continue
    incr seen
    regsub -all {\s+} $t " " t
    foreach pat {"each with its scans" "each keeps its scans" "elbow -from 2 -to 15 ;"} { if {[string first $pat $t] >= 0} { lappend bad "$f: $pat" } }
}
if {!$seen} { skip "  the built decks and design figure" "no unzip or pdftotext, or no deck" } else {
    check "  nor the decks and the design figure built from them ([join $bad {; }])" [expr {![llength $bad]}]
}
# (README's listing gave the scores of name CA seeded StratAll as its
# backbone CompSim clustering's; the paper's HELM scores are the program's
# without a trim: with one the plugin scores the clustered frames)
# (the listing loads MDANCE's packaged files since g8, whose backbone
# CompSim scores are 1036.1 and 2.04: test_hardening2_g8 runs it on them)
set t [g7_text README.md]
check "review: README's listing gives its backbone CompSim clustering's scores" [expr {
    [string match "*-kinit CompSim\n# -> run 1 molid 0 sel backbone fit {} frames 6001 * ch 1036.1 db 2.04 *" $t] && [string first "1139.6" $t] < 0}]
set ms ""
foreach f [g7_papers manuscript.tex] { append ms " " [g7_text $f] }
regsub -all {\s+} $ms " " ms
if {[string trim $ms] eq ""} { skip "  the paper's validation" "not beside the repository here" } else {
    check "  the paper's HELM is without a trim" [expr {
        [string match "*HELM without a trim, and eQUAL, the plugin's labels and scores are the program's*" $ms] &&
        ![string match "*HELM and eQUAL, the plugin's labels are the program's*" $ms]}]
}
vmdance run clear
foreach x [list $m $m6] { mol delete $x }

# --- the real backend ----------------------------------------------------------------------------------------
if {[real_cli] eq ""} {
    skip "F16, F47, F07 with the real backend" "no mdance-cli (MDANCE_CLI)"
} else {
    use_cli
    set p [load_system 3ptb]
    # --- F16: HELM's scores with a trim
    set i [vmdance -mol $p -sel "name CA" -algorithm helm -k 4 -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-k 5 -quiet 1]
    set labels [${R}::labels]
    set rows [g7_rows]
    lassign [g7_scores $rows $labels] ch db
    lassign [g7_scores $rows $labels 1] chn dbn
    check "F16: (the trim left noise, and the two scorings differ)" [expr {[dict get $i noise] > 0 && !([near $ch $chn 1e-3] || [near $db $dbn 1e-3])}]
    check "  HELM's published scores are its clustered frames', as scikit-learn computes them (not the trimmed as a cluster)" [expr {
        [near [dict get $i ch] $ch 1e-9] && [near [dict get $i db] $db 1e-9]}]
    set e [vmdance elbow -mol $p -sel "name CA" -algorithm helm -ks {3 4} -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-k 5 -quiet 1]
    set rec [lindex $e 1]
    lassign [g7_scores $rows [dict get [lindex [dict get $::VMDance::Results::elbow records] 1] clustering labels]] ech edb
    check "  an elbow's records are scored so too" [expr {[dict get $rec status] eq "ok" && [near [dict get $rec ch] $ech 1e-9] && [near [dict get $rec db] $edb 1e-9]}]
    # (passes: every k's in the same two passes over the frames, not two at
    # every k)
    set n [g7_passes {set e [vmdance elbow -mol $p -sel "name CA" -algorithm helm -ks {3 4 5} -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-k 5 -quiet 1]}]
    set ok [expr {$n == 2}]
    foreach rec $e r [dict get $::VMDance::Results::elbow records] {
        lassign [g7_scores $rows [dict get $r clustering labels]] ech edb
        if {[dict get $rec status] ne "ok" || ![near [dict get $rec ch] $ech 1e-9] || ![near [dict get $rec db] $edb 1e-9] ||
            [dict get $r clustering ch] ne [dict get $rec ch] || [dict get $r clustering db] ne [dict get $rec db]} { set ok 0 }
    }
    check "review: (real) an elbow of HELM with a trim reads the frames twice for the scores of its three k ($n), each k scored, and its clustering" $ok
    check "  the run made of one has those scores" [expr {[dict get [vmdance elbow load 5] ch] eq [dict get [lindex $e 2] ch]}]
    set args [list -mol $p -sel "name CA" -algorithm helm -k 4 -initial 10 -initial-percentage 50 -trim-start 1 -trim-k 2 -quiet 1]
    set ic [vmdance {*}$args]
    set lc [${R}::labels]
    if {[real_lib] eq ""} {
        skip "  the library's HELM with a trim" "no mdance_tcl (MDANCE_LIB)"
    } else {
        use_lib
        set il [vmdance {*}$args]
        lassign [g7_scores [g7_rows] [${R}::labels]] ch db
        check "  the library's too (its trimmed frames are one more cluster as well)" [expr {[${R}::labels] eq $lc && [dict get $il noise] > 0 &&
            [near [dict get $il ch] $ch 1e-9] && [near [dict get $il db] $db 1e-9] && [near [dict get $ic ch] $ch 1e-9] && [near [dict get $ic db] $db 1e-9]}]
        use_cli
    }
    # (the reference: the backend's own scores where there is no noise, and eQUAL's)
    set i [vmdance -mol $p -sel "name CA" -k 4 -kinit KmeansPP -quiet 1]
    lassign [g7_scores [g7_rows] [${R}::labels]] ch db
    lassign [lindex [::VMDance::Measure::scores $::VMDance::Coords::C [list [list [${R}::labels] 4]]] 0] mch mdb
    check "  the scoring is the backend's: KMeans' scores (no noise), the test's and the plugin's" [expr {
        [near [dict get $i ch] $ch 1e-7] && [near [dict get $i db] $db 1e-7] && [near $mch $ch 1e-9] && [near $mdb $db 1e-9]}]
    set i [vmdance -mol $p -sel "name CA" -algorithm equal -threshold 0.4 -quiet 1]
    lassign [g7_scores [g7_rows] [${R}::labels]] ch db
    check "  and eQUAL's, its noise left out" [expr {[dict get $i noise] > 0 && [near [dict get $i ch] $ch 1e-7] && [near [dict get $i db] $db 1e-7]}]
    # --- F47: the two compactness measures, with the metric MSD
    set ok 1; set seen 0
    foreach run {{-k 4 -kinit KmeansPP} {-algorithm equal -threshold 0.3}} {
        vmdance -mol $p -sel "name CA" {*}$run -quiet 1
        foreach row [vmdance clusters] {
            lassign $row c n pct msd spread
            if {$n < 2} continue
            incr seen
            if {$spread < $msd / 2 * (1 - 1e-5) || $spread > $msd * (1 + 1e-5)} { set ok 0 }
            if {$n == 2 && ![near $spread $msd 1e-4]} { set ok 0 }
        }
    }
    check "F47: the RMSD² from the representative is between half the MSD within and all of it (all of it for two frames)" [expr {$ok && $seen > 4}]
    # --- F07: with the real backend
    check "F07: (real) -min-samples's starting clusters checked before HELM (\"trimK is too large!\" before)" [string match "*-trim-k 10: -min-samples 5:*" \
        [err {vmdance -mol $p -sel "name CA" -algorithm helm -k 10 -initial 30 -initial-kinit KmeansPP -trim-start 1 -trim-k 10 -min-samples 5 -quiet 1}]]
    # (trim-val: no starting cluster of two frames or more has an MSD below
    # 1e-6: HELM had none; 0 clusters were published)
    set nr [llength [${R}::run_list]]
    set before [vmdance elbow show]
    check "review: (real) a run whose -trim-val left HELM nothing to merge is refused, nothing published" [expr {
        [string match "*-trim-val 1e-6: the trim kept 0 of HELM's * starting clusters, not more than -k (4)*" \
            [err {vmdance -mol $p -sel "name CA" -algorithm helm -k 4 -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-val 1e-6 -min-samples 2 -quiet 1}]] &&
        [llength [${R}::run_list]] == $nr}]
    check "  an elbow where it leaves no k anything to merge is refused, naming -ks, and the elbow there was kept" [expr {
        [string match "*no value of k can be run: -trim-val 1e-6: the trim kept 0 of HELM's * starting clusters, not more than -ks (4)*" \
            [err {vmdance elbow -mol $p -sel "name CA" -algorithm helm -ks {3 4} -initial 20 -initial-kinit KmeansPP -trim-start 1 -trim-val 1e-6 -min-samples 2 -quiet 1}]] &&
        [vmdance elbow show] eq $before}]
    set cdir [_env VMDANCE_CONSTRUCTED [file join $::root manuscripts shared data constructed]]
    if {![file isfile [file join $cdir states3.dcd]]} {
        skip "  states3: the first clustering's empty clusters" "no states3.dcd in $cdir"
    } else {
        set s3 [mol new [file join $cdir states3.pdb] waitfor all]
        mol addfile [file join $cdir states3.dcd] waitfor all molid $s3
        animate delete beg 0 end 0 $s3
        check "  states3: -initial 30 -k 27 is refused, naming -initial (one cluster of 4000 frames was published)" [string match \
            "*-initial 30: the first clustering left 2? starting clusters with frames*" \
            [err {vmdance -mol $s3 -sel all -algorithm helm -k 27 -initial 30 -quiet 1}]]
        check "review: states3: -trim-val 0.3, which kept none of HELM's starting clusters, is refused (0 clusters, 4000 noise frames, were published)" [string match \
            "*-trim-val 0.3: the trim kept 0 of HELM's 2? starting clusters, not more than -k (3)*" \
            [err {vmdance -mol $s3 -sel all -algorithm helm -k 3 -initial 30 -trim-start 1 -trim-val 0.3 -quiet 1}]]
        mol delete $s3
    }
    vmdance run clear
    mol delete $p
    use_fake
}

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_g7 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
