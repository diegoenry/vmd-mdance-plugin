# What the review of DIVINE, and of what the backend was built with, found
# (h1), each kept from coming back (text mode, the fake backend; DIVINE
# against the real program, the library and MDANCE is the reference
# suite's, when the build has it: N16, N05, and the numbers of N06, N10,
# N23; the window's fields and Tree plot are test_gui's: N23, N22):
#   N09  DIVINE splits by MSD whatever -metric (CPP-MDANCE used another only
#        to choose the representatives, worse ones, while the run said
#        "metric RR", and a sweep listed each clustering once a metric):
#        refused before running, a sweep's DIVINE × another metric not run,
#        a session's run that has one still opens
#   N10  -threshold is the smallest share of the frames each side of a split
#        keeps (it said a spread): refused with NANI, whose splits
#        CPP-MDANCE makes without it, and above what any split can leave
#        (one cluster); a clustering that stops before k says why
#   N06  -end-mode points is refused where it can only fail or leave every
#        frame alone (NANI's splits, a share of one frame; the measures of
#        thousands of one-frame clusters froze VMD), and in scans (k is not
#        used there: every k the same clustering)
#   N21  DIVINE's first split is checked for its NANI's two seeds, as
#        KMeans's k seeds are (it failed in the backend naming a kClusters
#        never set, or crashed it with CompSim); a later split's failure is
#        said in DIVINE's terms; the library is not given CompSim splits
#        that crash it, and VMD with it
#   N23  Refine is off by default (it changes nothing with NANI, and the
#        pair anchors, where it would act, crash the backend with it): the
#        pair anchors run as they are
#   N22  the tree of a DIVINE clustering is said to be the average linkage
#        of the mean structures, not DIVINE's splits (the export here)
#   N24  a program rebuilt or replaced at the same path is asked again what
#        it was built with (DIVINE stayed refused after a rebuild with it)
# And what the review of these fixes found (the window's: test_gui):
#   N06  the share points' refusal advised was refused again for half the
#        frame counts, and split nearly every frame apart where taken
#   N10  "use at most 0.5" for an odd number of frames, where 0.5 is
#        refused; the note of a clustering short of k blamed -threshold
#        where it does nothing (NANI's splits, a share of one frame)
#   N21  the library refused DIVINE seeded by CompSim at k 2 too (one
#        split, which cannot crash); the program's crash with it was said
#        bare; the sweep's and elbow's guard in Job::_call had no check
#   N24  a program rebuilt behind a launcher (whose stamp stays the same)
#        stayed "not in this build": asked again before a refusal
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_h1.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_h1]
file delete -force $H
file mkdir $H

# A program at path, as a build that names algs: the fake, or one that
# fails with the message fail.
proc write_prog {path algs {fail ""}} {
    set fh [open $path w]
    puts $fh "#!/bin/sh"
    puts $fh "if \[ \$# -eq 0 \]; then echo 'Usage: mdance-cli --algorithm {$algs}' >&2; exit 1; fi"
    if {$fail ne ""} {
        puts $fh "echo 'Error: $fail' >&2; exit 1"
    } else {
        puts $fh "exec '$::fake' \"\$@\""
    }
    close $fh
    file attributes $path -permissions 0755
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set A ::VMDance::Algo
set J ::VMDance::Job
set ::VMDance::Prefs::file ""
use_fake
fake_env
set m [load_system two_state]
set dv [${A}::defaults divine]

# N09: MDANCE's DIVINE has no metric, and CPP-MDANCE's splits by MSD: the
# metric reached only the representatives' choice (worse ones), and was
# recorded as the clustering's. Refused before running (check_combination:
# new requests only, so a session's run with one still opens).
check "N09: DIVINE takes MSD only, the others every metric" [expr {![catch {list [${A}::metrics_of divine] [${A}::metrics_of kmeans]} ms] &&
    [lindex $ms 0] eq {MSD} && [lindex $ms 1] eq $::VMDance::Algo::metrics}]
check "  -metric RR refused, saying why and what to use" [string match "-metric RR: DIVINE splits by MSD*use -metric MSD" [err {
    ${A}::check_combination divine 3 $dv 100 "" RR}]]
set c0 $::VMDance::Backend::counter
check "  the command: refused with no run of the backend" [expr {
    [string match "vmdance: -metric JT: DIVINE splits by MSD*" [err {vmdance -mol $m -sel all -algorithm divine -metric JT -quiet 1}]] &&
    $::VMDance::Backend::counter == $c0}]
check "  an elbow scan too" [string match "*-metric JT: DIVINE splits by MSD*" [err {vmdance elbow -mol $m -sel all -algorithm divine -metric JT -ks {2 3} -quiet 1}]]
set rows [vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -ks {2 3} -metrics {MSD JT} -seedings KmeansPP -quiet 1]
set dj [lmap r $rows {expr {[dict get $r algorithm] eq "divine" && [dict get $r metric] eq "JT" ? [dict get $r message] : [continue]}}]
set others [lmap r $rows {expr {[dict get $r algorithm] ne "divine" || [dict get $r metric] ne "JT" ? [dict get $r status] : [continue]}}]
check "  a sweep: DIVINE × JT not run (each with the reason), the rest run" [expr {[llength $rows] == 8 && [llength $dj] == 2 &&
    [lsort -unique [lmap x $dj {string match "not run: -metric JT: DIVINE splits by MSD*" $x}]] eq {1} && [lsort -unique $others] eq {ok}}]
vmdance -mol $m -sel all -algorithm divine -k 2 -quiet 1
set a $::VMDance::Results::A
dict set a request metric RR
check "  a stored run of DIVINE with another metric (a session's) still opens" [expr {[err {${R}::check $a}] eq ""}]

# N10: -threshold is the smallest share of all the frames each side of a
# split keeps (MDANCE's minimum size of a cluster; CPP-MDANCE: round(t × n),
# tested by the pair anchors only). It was described as a spread.
set pp [dict get [vmdance parameters divine] -threshold]
check "N10: -threshold described as the smallest share each side of a split keeps, not a spread" [expr {
    [lindex $pp 3] eq "Smallest share" && [string match "*each side keeps at least this share of all the frames*" [lindex $pp 4]] &&
    ![string match "*spread*" [lindex $pp 4]]}]
check "  with Anchors NANI, whose splits CPP-MDANCE makes without it: refused" [string match "-threshold 0.3 with -anchors NANI: CPP-MDANCE's DIVINE does not apply it*" [err {
    ${A}::check_combination divine 6 [dict replace $dv threshold 0.3] 100}]]
set op [dict replace $dv anchors OutlierPair refine 0]
check "  with OutlierPair: taken up to what a split can leave on both sides (0.5 of 100 frames)" [expr {
    [err {${A}::check_combination divine 6 [dict replace $op threshold 0.3] 100}] eq "" &&
    [err {${A}::check_combination divine 6 [dict replace $op threshold 0.5] 100}] eq ""}]
check "  above it (no split can be made: one cluster) refused, 2 too" [expr {
    [string match "-threshold 0.6: each side of a split must keep 60 of the 100 frames, so no split can be made*at most 0.5*" [err {
        ${A}::check_combination divine 6 [dict replace $op threshold 0.6] 100}]] &&
    [string match "-threshold 2: *" [err {${A}::check_combination divine 6 [dict replace $op threshold 2] 100}]]}]
check "  k 1, which makes no split: taken" [expr {[err {${A}::check_combination divine 1 [dict replace $op threshold 0.9] 100}] eq ""}]
vmdance -mol $m -sel all -algorithm divine -k 2 -anchors SplinterPair -refine 0 -threshold 0.3 -quiet 1
set a $::VMDance::Results::A
dict set a request k 6
dict set a request params threshold 2
check "  a stored run with -threshold 2 (a session's) still opens" [expr {[err {${R}::check $a}] eq ""}]
dict set a request params threshold 0.3
${R}::publish $a
check "  a clustering that stops before k says why (the backend's line was dropped)" [string match "*2 clusters*fewer than the 6 asked: no split left 7 frames or more on each side (-threshold 0.3)" [::VMDance::_summary]]
vmdance -mol $m -sel all -algorithm kmeans -k 2 -kinit KmeansPP -quiet 1
check "  (no such note for a clustering of k)" [expr {![string match "*fewer than*" [::VMDance::_summary]]}]

# N06: -end-mode points does not use k; with NANI's splits (no smallest
# share in CPP-MDANCE) or a share of one frame it can only fail or leave
# every frame alone, and the measures of 6001 one-frame clusters froze VMD.
check "N06: -end-mode points with Anchors NANI: refused, saying what works" [string match "-end-mode points with -anchors NANI: *use -anchors OutlierPair or SplinterPair (with -refine 0) and -threshold, or -end-mode k" [err {
    ${A}::check_combination divine 3 [dict replace $dv end-mode points] 100}]]
set sp [dict replace $dv anchors SplinterPair refine 0 end-mode points]
check "  with a pair of anchors and a share of one frame (0, 0.01 of 100): refused (up to 100 clusters)" [expr {
    [string match "-end-mode points with -threshold 0: *the splits go on to single frames (up to 100 clusters); give -threshold*e.g. 0.05: 5 frames or more each, 20 clusters at most*" [err {${A}::check_combination divine 3 $sp 100}]] &&
    [string match "*the splits go on to single frames*" [err {${A}::check_combination divine 3 [dict replace $sp threshold 0.01] 100}]]}]
check "  with a share of 2 frames or more: taken (MDANCE's stopping rule)" [expr {[err {${A}::check_combination divine 3 [dict replace $sp threshold 0.1] 100}] eq ""}]
check "  an elbow scan with it refused (every k the same clustering)" [string match "*-end-mode points: DIVINE does not use k then*scan with -end-mode k" [err {
    vmdance elbow -mol $m -sel all -algorithm divine -anchors SplinterPair -refine 0 -end-mode points -threshold 0.2 -ks {2 3} -quiet 1}]]
set rows [vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -ks {2 3} -seedings KmeansPP -params {divine {anchors SplinterPair refine 0 end-mode points threshold 0.2}} -quiet 1]
check "  a sweep's: not run, with the reason; the others run" [expr {[llength $rows] == 4 &&
    [lsort -unique [lmap r $rows {expr {[dict get $r algorithm] eq "divine" ? [string match "not run: -end-mode points: DIVINE does not use k*" [dict get $r message]] : [continue]}}]] eq {1} &&
    [lsort -unique [lmap r $rows {expr {[dict get $r algorithm] eq "kmeans" ? [dict get $r status] : [continue]}}]] eq {ok}}]
check "  one clustering with it runs" [expr {[err {vmdance -mol $m -sel all -algorithm divine -anchors SplinterPair -refine 0 -end-mode points -threshold 0.2 -quiet 1}] eq ""}]

# N21: each split of NANI's anchors is a 2-cluster NANI of the cluster's m
# frames, seeded from floor(m × p / 100) of them. KMeans's k seeds were
# checked before running, DIVINE's not: it failed in the backend naming a
# kClusters never set (or crashed it with CompSim, the library VMD).
set e [err {${A}::check_combination divine 2 $dv 10}]
check "N21: the first split of 10 frames at 10% (1 seed of 2): refused, naming -percentage and its value" [string match "-percentage 10: DIVINE's first split is a 2-cluster NANI (-kinit StratAll) seeded from the densest 10% of the 10 frames (1 of them), and it needs 2; raise -percentage to 20, or seed with KmeansPP or Random" $e]
check "  not in KMeans's words (-k, fewer clusters)" [expr {![string match "*-k *" $e] && ![string match "*fewer clusters*" $e]}]
check "  at 20%, with KmeansPP or Random, with the pair anchors, or k 1 (no split): taken" [expr {
    [err {${A}::check_combination divine 2 [dict replace $dv percentage 20] 10}] eq "" &&
    [err {${A}::check_combination divine 2 [dict replace $dv kinit KmeansPP] 10}] eq "" &&
    [err {${A}::check_combination divine 2 [dict replace $dv kinit Random] 10}] eq "" &&
    [err {${A}::check_combination divine 2 [dict replace $dv anchors OutlierPair refine 0] 10}] eq "" &&
    [err {${A}::check_combination divine 1 $dv 10}] eq ""}]
check "  19 frames refused, 20 taken (StratAll, StratReduced, CompSim, DivSelect)" [expr {
    [lsort -unique [lmap ki {StratAll StratReduced CompSim DivSelect} {string match "*raise -percentage to 11*" [err {${A}::check_combination divine 3 [dict replace $dv kinit $ki] 19}]}]] eq {1} &&
    [lsort -unique [lmap ki {StratAll StratReduced CompSim DivSelect} {expr {[err {${A}::check_combination divine 3 [dict replace $dv kinit $ki] 20}] eq ""}}]] eq {1}}]
check "  CompSim on 9 frames (no seed at all: the backend crashed): refused" [string match "*(0 of them)*" [err {${A}::check_combination divine 2 [dict replace $dv kinit CompSim] 9}]]
set m1 [load_system single_state]
set c0 $::VMDance::Backend::counter
check "  the command: refused before running" [expr {[string match "vmdance: -percentage 10: DIVINE's first split*" [err {vmdance -mol $m1 -sel all -algorithm divine -k 2 -quiet 1}]] &&
    $::VMDance::Backend::counter == $c0}]
mol delete $m1
# a later split, which the backend refuses: said in DIVINE's terms
set P [file join $H failing-cli]
write_prog $P {kmeans|divine|helm|equal} "Initialization produced fewer centers than kClusters; increase percentage or reduce kClusters."
::VMDance::Backend::configure -mode cli -cli $P
set e [err {vmdance -mol $m -sel all -algorithm divine -k 3 -quiet 1}]
check "  a later split's cluster too small to seed: said in DIVINE's terms, not kClusters" [expr {
    [string match "*DIVINE chose to split a cluster of fewer than 20 frames: its 2-cluster NANI (-kinit StratAll) seeds from the densest 10% *raise -percentage, seed with KmeansPP or Random, or ask for fewer clusters" $e] &&
    ![string match "*kClusters*" $e]}]
set rows [vmdance elbow -mol $m -sel all -algorithm divine -ks {2 3} -quiet 1]
check "  in a scan's records too" [expr {[lsort -unique [lmap r $rows {string match "DIVINE chose to split a cluster of fewer than 20 frames*" [dict get $r message]}]] eq {1}}]
check "  (KMeans's failure is left as it is)" [string match "*fewer centers than kClusters*" [err {vmdance -mol $m -sel all -k 2 -quiet 1}]]
use_fake
# (the library: NANI seeded by CompSim reads an empty matrix on a cluster of
# fewer than 100 / p frames, which DIVINE can choose at any split)
check "  the library is not given DIVINE's CompSim splits below 50%: the program named" [expr {
    [string match "-kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes when it splits a cluster of fewer than 10 frames, and the library takes VMD with it; use the program*" [err {
        ${J}::_library_divine divine 3 [dict replace $dv kinit CompSim]}]] &&
    [err {${J}::_library_divine divine 3 [dict replace $dv kinit CompSim percentage 50]}] eq "" &&
    [err {${J}::_library_divine divine 3 $dv}] eq "" &&
    [err {${J}::_library_divine divine 3 [dict replace $dv kinit CompSim anchors OutlierPair]}] eq "" &&
    [err {${J}::_library_divine kmeans 3 [dict create kinit CompSim percentage 10]}] eq ""}]

# N23: Refine acts only on the pair anchors' splits (a NANI split is a
# k-means already), which crash CPP-MDANCE's DIVINE with it: on by default,
# it did nothing, and made the pair anchors need -refine 0.
check "N23: Refine off by default, and not passed on" [expr {[dict get $dv refine] == 0 &&
    [lsearch [${A}::cli_args divine 3 MSD [${A}::check_params divine {}] 10 a b] --refine] < 0 &&
    [lsearch [${A}::cli_args divine 3 MSD [${A}::check_params divine {refine 1}] 10 a b] --refine] >= 0}]
check "  the pair anchors taken as they are; with -refine 1 still refused (the crash)" [expr {
    [err {${J}::check_cluster [list mol $m sel all algorithm divine params {anchors SplinterPair}]}] eq "" &&
    [string match "*-anchors OutlierPair with -refine 1 crashes*" [err {${J}::check_cluster [list mol $m sel all algorithm divine params {anchors OutlierPair refine 1}]}]]}]
check "  its tip says where it acts, and that NANI's splits do not use it" [string match "*OutlierPair and SplinterPair*A NANI split is a k-means already*" [lindex [dict get [vmdance parameters divine] -refine] 4]]

# N22: the tree of anything but HELM is the average linkage of the mean
# structures, which can join DIVINE's clusters across its first split.
vmdance -mol $m -sel all -algorithm divine -k 3 -quiet 1
vmdance export $H -items tree -prefix dv
set hd [lindex [split [read_text [file join $H dv_tree.csv]] \n] 0]
# (the distance is their RMSD², which the header calls so since h4's N17)
check "N22: DIVINE's tree export says it is a linkage, not DIVINE's splits" [string match "*average linkage of the clusters' mean structures (distance: their RMSD², Å²), not DIVINE's splits" $hd]
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance export $H -items tree -prefix km
check "  (KMeans's names no algorithm's splits)" [expr {![string match "*splits*" [lindex [split [read_text [file join $H km_tree.csv]] \n] 0]]}]

# N24: what the program was built with was kept for its path: rebuilt there
# with DIVINE (as the refusal advised), it stayed "not in this build".
set P [file join $H rebuilt-cli]
write_prog $P {kmeans|helm|equal}
::VMDance::Backend::configure -mode cli -cli $P
check "N24: a program built without DIVINE: so said, DIVINE refused" [expr {[::VMDance::Backend::algorithms] eq {kmeans helm equal} &&
    [string match "*DIVINE is not in this build*" [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}]]}]
write_prog $P {kmeans|divine|helm|equal}
check "  rebuilt at the same path with DIVINE: asked again, and DIVINE runs" [expr {
    [::VMDance::Backend::algorithms] eq {kmeans divine helm equal} &&
    [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}] eq "" && [dict get [vmdance algorithms] divine available]}]
write_prog $P {kmeans|helm|equal}
check "  rebuilt without: the plugin's own refusal again" [string match "*DIVINE is not in this build*" [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}]]
# (the probes counted: the renamed one kept in its namespace)
set ::probes 0
rename ::VMDance::Backend::_probe ::VMDance::Backend::_probe_counted
proc ::VMDance::Backend::_probe {path} { incr ::probes; _probe_counted $path }
for {set i 0} {$i < 5} {incr i} { ::VMDance::Backend::algorithms }
set p1 $::probes
write_prog $P {kmeans|divine|helm|equal}
::VMDance::Backend::algorithms
check "  unchanged, it is not asked again; changed, once ($p1, then [expr {$::probes - $p1}])" [expr {$p1 == 0 && $::probes == 1}]
rename ::VMDance::Backend::_probe {}
rename ::VMDance::Backend::_probe_counted ::VMDance::Backend::_probe
use_fake

# --- what the review of these fixes found ---------------------------------
# N06 (review): -end-mode points' refusal advised the least share holding 2
# frames, 1.5 / n to 3 digits: rounded down, it was refused again for about
# half of all frame counts (7 frames: 0.214; 1923: 0.00078), and where taken
# it split nearly every frame apart (3ptb: 43 clusters of 100 frames; the
# tau peptide ran 16 minutes). It suggests 0.05 (at most 20 clusters), or 2
# frames where that holds fewer: taken for every number of frames.
set pts [dict replace $dv anchors OutlierPair refine 0 end-mode points]
set bad {}
for {set n 4} {$n <= 5000} {incr n} {
    if {![regexp {e\.g\. ([0-9.e-]+): ([0-9]+) frames or more each} [err {${A}::check_combination divine 3 $pts $n}] -> eg mf] ||
            $mf < 2 || ($n >= 40 && $eg != 0.05) || [err {${A}::check_combination divine 3 [dict replace $pts threshold $eg] $n}] ne ""} {
        lappend bad $n
    }
}
check "review N06: the share points' refusal suggests is taken, 4 to 5000 frames (0.05, or 2 frames where it holds fewer)[expr {[llength $bad] ? ": not for [lrange $bad 0 5]" : ""}]" [expr {![llength $bad]}]
check "  7 frames: 0.286 (0.214 was refused again); 1923: 0.05, 96 frames or more each" [expr {
    [string match "*e.g. 0.286: 2 frames or more each, 3 clusters at most*" [err {${A}::check_combination divine 3 $pts 7}]] &&
    [string match "*e.g. 0.05: 96 frames or more each, 20 clusters at most*" [err {${A}::check_combination divine 3 $pts 1923}]]}]
check "  2 and 3 frames, where no split leaves 2 on each side: -end-mode k" [expr {
    [lsort -unique [lmap n {2 3} {string match "*; use -end-mode k (no split of $n frames leaves 2 on each side)" [err {${A}::check_combination divine 3 $pts $n}]}]] eq {1}}]

# N10 (review): 0.5 of an odd number of frames rounds up, past half (in
# CPP-MDANCE too), and was refused with "use at most 0.5". The refusal gives
# the largest share that leaves a split, and the tip says it.
set op [dict replace $dv anchors OutlierPair refine 0 threshold 0.5]
set bad {}
for {set n 2} {$n <= 5001} {incr n} {
    set e [err {${A}::check_combination divine 6 $op $n}]
    if {$n % 2 == 0} {
        if {$e ne ""} { lappend bad $n }
    } elseif {![regexp {use at most ([0-9.]+) \(0: no limit\)$} $e -> most] || $most >= 0.5 ||
            [err {${A}::check_combination divine 6 [dict replace $op threshold $most] $n}] ne ""} {
        lappend bad $n
    }
}
check "review N10: -threshold 0.5 taken for an even number of frames, refused for an odd one with a share that is taken (2 to 5001)[expr {[llength $bad] ? ": not for [lrange $bad 0 5]" : ""}]" [expr {![llength $bad]}]
check "  99 frames: at most 0.494; 1923: 0.499" [expr {
    [string match "*must keep 50 of the 99 frames*; use at most 0.494 (0: no limit)" [err {${A}::check_combination divine 6 $op 99}]] &&
    [string match "*must keep 962 of the 1923 frames*; use at most 0.499 (0: no limit)" [err {${A}::check_combination divine 6 $op 1923}]]}]
check "  the tip: below 0.5 for an odd number of frames" [string match "*(0: no limit; at most 0.5, below it for an odd number of frames)*" [lindex [dict get [vmdance parameters divine] -threshold] 4]]
# (the note of a clustering short of k named -threshold whatever the
# anchors: NANI's splits never apply it, nor does a share of one frame
# stop one; those stop short only where the frames left are the same)
proc short_of {args} {
    vmdance -mol $::m -sel all -algorithm divine -k 2 {*}$args -quiet 1
    set a $::VMDance::Results::A
    dict set a request k 6
    ::VMDance::Results::publish $a
    ::VMDance::_summary
}
set s1 [short_of -kinit KmeansPP]
set s2 [short_of -anchors OutlierPair]
set s3 [short_of -anchors SplinterPair -threshold 0.3]
check "review N10: short of k with NANI, or a share of one frame: the frames left the same, not -threshold" [expr {
    [string match "*2 clusters*fewer than the 6 asked: the clusters left could not be split (their frames are the same)" $s1] &&
    [string match "*fewer than the 6 asked: the clusters left could not be split (their frames are the same)" $s2] &&
    ![string match "*threshold*" $s1$s2]}]
check "  with the pair anchors and a share of 2 frames or more: the share" [string match "*fewer than the 6 asked: no split left 7 frames or more on each side (-threshold 0.3)" $s3]

# N21 (review): the library was refused DIVINE seeded by CompSim below 50%
# at any k, though k 2 is the first split alone, of every frame, which
# check_combination checks (it ran before; a scan's k 2 failed too).
check "review N21: the library takes DIVINE's CompSim below 50% at k 1 and 2, not above" [expr {
    [err {${J}::_library_divine divine 2 [dict replace $dv kinit CompSim]}] eq "" &&
    [err {${J}::_library_divine divine 1 [dict replace $dv kinit CompSim]}] eq "" &&
    [string match "-kinit CompSim with -percentage 10: *" [err {${J}::_library_divine divine 3 [dict replace $dv kinit CompSim]}]]}]
# (a sweep's configurations and an elbow's k after the first have no guard
# but Job::_call's: the library as a DIVINE build, whose ::mdance::divine
# notes the k it is called at; the real one would take VMD with it at 3)
set L [real_lib]
if {$L eq "" || [catch {::VMDance::Backend::load_lib $L}]} {
    skip "review N21: the library's guard in a sweep and an elbow" "no CPP-MDANCE library (MDANCE_LIB)"
} else {
    use_lib
    set ::VMDance::Backend::caps([lindex [::VMDance::Backend::current] 1]) [list "" {kmeans divine helm equal}]
    rename ::mdance::divine ::mdance::divine_kept
    proc ::mdance::divine {co nf natoms k args} { lappend ::lib_ks $k; ::mdance::kmeans $co $nf $natoms $k -metric MSD -kinit KmeansPP }
    # (each k: {k status refused-by-the-library}; a scan refused whole: the error)
    set refused {apply {{scan} {
        if {[catch {uplevel #0 $scan} rows]} { return $rows }
        lmap r $rows {list [dict get $r k] [dict get $r status] [string match "not run: -kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes*" [dict get $r message]]}
    }}}
    set ::lib_ks {}
    set sw [{*}$refused {vmdance sweep -mol $m -sel all -algorithms divine -ks {2 3 4} -seedings CompSim -quiet 1}]
    set ks1 $::lib_ks
    set ::lib_ks {}
    set eb [{*}$refused {vmdance elbow -mol $m -sel all -algorithm divine -kinit CompSim -ks {2 3 4} -quiet 1}]
    set ks2 $::lib_ks
    set ::lib_ks {}
    set e2 [err {vmdance -mol $m -sel all -algorithm divine -kinit CompSim -k 2 -quiet 1}]
    set e3 [err {vmdance -mol $m -sel all -algorithm divine -kinit CompSim -k 3 -quiet 1}]
    set ks3 $::lib_ks
    rename ::mdance::divine {}
    rename ::mdance::divine_kept ::mdance::divine
    use_fake
    check "review N21: a library sweep of DIVINE × CompSim, k 2 to 4: k 2 run, 3 and 4 kept as not run with the library's refusal, uncalled ($sw; called at $ks1)" [expr {
        $sw eq {{2 ok 0} {3 error 1} {4 error 1}} && $ks1 eq {2}}]
    check "  an elbow scan likewise ($eb; called at $ks2)" [expr {$eb eq {{2 ok 0} {3 error 1} {4 error 1}} && $ks2 eq {2}}]
    check "  a clustering: k 2 runs, k 3 refused before the call" [expr {$e2 eq "" &&
        [string match "vmdance: -kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes*" $e3] && $ks3 eq {2}}]
}
# (the program: a later split of a cluster under 100 / p frames seeded by
# CompSim crashes mdance-cli, which was said as "mdance-cli crashed
# (segmentation violation)" alone; a program here that crashes so)
set P [file join $H crashing-cli]
set fh [open $P w]
puts $fh "#!/bin/sh"
puts $fh "if \[ \$# -eq 0 \]; then echo 'Usage: mdance-cli --algorithm {kmeans|divine|helm|equal}' >&2; exit 1; fi"
puts $fh "ulimit -c 0; kill -SEGV \$\$"
close $fh
file attributes $P -permissions 0755
::VMDance::Backend::configure -mode cli -cli $P
check "review N21: DIVINE seeded by CompSim crashing the program: said in DIVINE's terms, with what to change" [string match "vmdance: DIVINE chose to split a cluster of fewer than 10 frames, and mdance-cli crashed: its 2-cluster NANI (-kinit CompSim) seeds from the densest 10% of the cluster's frames, none there; raise -percentage to 50 or more, seed with KmeansPP or Random, or ask for fewer clusters" [err {
    vmdance -mol $m -sel all -algorithm divine -k 3 -kinit CompSim -quiet 1}]]
set rows [vmdance elbow -mol $m -sel all -algorithm divine -kinit CompSim -ks {3 4} -quiet 1]
check "  in a scan's records too" [expr {[lsort -unique [lmap r $rows {string match "DIVINE chose to split a cluster of fewer than 10 frames, and mdance-cli crashed*" [dict get $r message]}]] eq {1}}]
check "  a crash at k 2 (the first split alone, checked), with another seeding, at 50%, or of KMeans: left as it is" [expr {
    [string match "vmdance: mdance-cli failed: mdance-cli crashed (*)" [err {vmdance -mol $m -sel all -algorithm divine -k 2 -kinit CompSim -quiet 1}]] &&
    [string match "vmdance: mdance-cli failed: mdance-cli crashed (*)" [err {vmdance -mol $m -sel all -algorithm divine -k 3 -kinit KmeansPP -quiet 1}]] &&
    [string match "vmdance: mdance-cli failed: mdance-cli crashed (*)" [err {vmdance -mol $m -sel all -algorithm divine -k 3 -kinit CompSim -percentage 50 -quiet 1}]] &&
    [string match "vmdance: mdance-cli failed: mdance-cli crashed (*)" [err {vmdance -mol $m -sel all -k 2 -kinit CompSim -quiet 1}]]}]
use_fake

# N24 (review): the stamp is the configured path's: a launcher that runs
# mdance-cli keeps its own when the program is rebuilt with DIVINE, which
# stayed "not in this build". The program is asked again before an
# algorithm is refused (the command, a sweep, vmdance algorithms).
set Q [file join $H launched-cli]
set W [file join $H launcher]
set fh [open $W w]
puts $fh "#!/bin/sh"
puts $fh "exec '$Q' \"\$@\""
close $fh
file attributes $W -permissions 0755
proc launched {algs} {
    write_prog $::Q {kmeans|helm|equal}
    ::VMDance::Backend::configure -mode cli -cli $::W
    set have [::VMDance::Backend::algorithms]
    write_prog $::Q $algs
    return $have
}
set h0 [launched {kmeans|divine|helm|equal}]
set e [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}]
check "review N24: a program rebuilt with DIVINE behind its launcher: asked again, DIVINE runs" [expr {$h0 eq {kmeans helm equal} && $e eq ""}]
launched {kmeans|divine|helm|equal}
set rows [vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -ks {2 3} -seedings KmeansPP -quiet 1]
check "  a sweep runs its DIVINE configurations" [expr {[lsort -unique [lmap r $rows {dict get $r status}]] eq {ok}}]
launched {kmeans|divine|helm|equal}
check "  vmdance algorithms says it has it" [dict get [vmdance algorithms] divine available]
launched {kmeans|helm|equal}
check "  not rebuilt: still refused, the plugin's own message" [string match "*DIVINE is not in this build*" [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}]]
set ::probes 0
rename ::VMDance::Backend::_probe ::VMDance::Backend::_probe_counted
proc ::VMDance::Backend::_probe {path} { incr ::probes; _probe_counted $path }
for {set i 0} {$i < 3} {incr i} { ::VMDance::Job::check_available kmeans }
set p0 $::probes
catch {::VMDance::Job::check_available divine}
check "  asked again only to refuse, once a refusal ($p0, then [expr {$::probes - $p0}])" [expr {$p0 == 0 && $::probes == 1}]
rename ::VMDance::Backend::_probe {}
rename ::VMDance::Backend::_probe_counted ::VMDance::Backend::_probe
use_fake

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_h1 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
