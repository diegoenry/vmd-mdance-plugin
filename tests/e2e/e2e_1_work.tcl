# End to end, phase 1 of 5 (text mode, the real backend): a session of
# work with the command on the heptapeptide (6001 frames) and 3ptb (a
# range, a step and a fit): elbow scan, a k of it made the clustering,
# HELM and eQUAL, PRIME, the similarity, picks, a sweep, the selection,
# 3D, the user field; every export checked against the command's answers
# and the structures against VMD's coordinates; the library against the
# program; the session saved with the state the next phases compare.
#   (run by tests/e2e/run_e2e.sh)
set ::phase work
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests e2e e2e_common.tcl]

if {[catch {
package require vmdance
# (text mode: no preferences are read)
if {[real_cli] eq "" || ![file isdirectory $::refruns]} {
    skip "the end-to-end session" "needs mdance-cli (MDANCE_CLI) and MDANCE's runs (MDANCE_REF_RUNS)"
    done
    quit
}
file delete -force [file join $::E timings.txt]
use_cli
set R $::R

# --- the heptapeptide --------------------------------------------------------------------
set mh [timed "load the heptapeptide (6001 frames)" { load_ref heptapeptide }]
set rows [timed "elbow scan k 2-10, KMeans NANI (6001 frames × 48 atoms)" { vmdance elbow -mol $mh -sel backbone -from 2 -to 10 -quiet 1 }]
check "elbow: every k clustered" [expr {[llength $rows] == 9 && [lsort -unique [lmap r $rows {dict get $r status}]] eq "ok"}]
set i [timed "elbow load 6 (measures of 6001 frames)" { vmdance elbow load 6 }]
set l6 [vmdance labels]
timed "cluster k 6 directly" { vmdance -mol $mh -sel backbone -k 6 -quiet 1 }
check "  k 6 of the scan made the clustering: the labels of clustering at k 6 directly" [expr {[vmdance labels] eq $l6}]
vmdance run delete [lindex [lindex [vmdance runs] end] 0]
vmdance run label [lindex [lindex [vmdance runs] end] 0] "NANI k 6 (from the elbow)"
timed "HELM k 6 from 60 starting clusters" { vmdance -mol $mh -sel backbone -algorithm helm -k 6 -initial 60 -quiet 1 }
check "HELM: 6 clusters of every frame, its tree HELM's" [expr {[${R}::nclusters] == 6 && [${R}::noise] == 0 && [dict get [vmdance tree] kind] eq "helm" &&
    [llength [dict get [vmdance tree] merges]] == 54}]
set nani [lindex [lindex [vmdance runs] 0] 0]
vmdance run $nani
set p [timed "PRIME (6001 frames)" { vmdance prime }]
set s [timed "similarity (iSIM)" { vmdance similarity }]
check "PRIME and the similarity kept with the run, PRIME's frames clustered ones" [expr {[dict size [${R}::extra prime]] > 0 &&
    [dict size [${R}::extra similarity]] > 0 && [llength [lmap f [dict values $p] {expr {$f in [dict keys [vmdance labels]] ? [continue] : $f}}]] == 0}]
set picks [timed "pick the most diverse 2% of the frames" { vmdance pick -mol $mh -sel backbone -method diversity -param 2 }]
check "picks: 2% of the frames, each once ([llength $picks])" [expr {[llength $picks] == 120 && [llength [lsort -unique $picks]] == 120}]
set sw [timed "sweep: KMeans NANI and HELM × k {4 6} × StratAll, KmeansPP" {
    vmdance sweep -mol $mh -sel backbone -algorithms {kmeans helm} -ks {4 6} -seedings {StratAll KmeansPP} -params {helm {initial 60}} -quiet 1
}]
check "sweep: 8 configurations, all ran" [expr {[llength $sw] == 8 && [lsort -unique [lmap r $sw {dict get $r status}]] eq "ok"}]
set b [vmdance sweep best db]
check "  its best Davies–Bouldin is the lowest" [expr {[dict get $b db] == [::tcl::mathfunc::min {*}[lmap r $sw {dict get $r db}]]}]
vmdance run $nani
vmdance select 0 2
check "the selection" [expr {[vmdance select] eq {0 2}}]
set n0 [molinfo $mh get numreps]
vmdance draw -colour 1 -reps 1
check "3D: colour and representatives drawn" [expr {[molinfo $mh get numreps] > $n0}]
vmdance draw -colour 0 -reps 0
check "  and taken away" [expr {[molinfo $mh get numreps] == $n0}]
set nf [timed "user field of 6001 frames" { vmdance userfield }]
set ok 1
foreach {f c} [lrange [vmdance labels] 0 39] {
    set a [atomselect $mh "index 0" frame $f]
    if {[lindex [$a get user] 0] != $c} { set ok 0 }
    $a delete
}
check "  the user field holds every frame's cluster" [expr {$nf == 6001 && $ok}]

# every export, checked against the command's answers
set dx [file join $::E export_hepta]
file delete -force $dx
file mkdir $dx
set files [timed "export every item (structures as DCD)" { vmdance export $dx -prefix hepta -items [::VMDance::Export::items] }]
check "export: every item written ([llength $files] files)" [expr {[llength $files] >= 17 && [llength [lmap f $files {expr {[file size $f] > 0 ? [continue] : $f}}]] == 0}]
set L [vmdance labels]
check "  labels.csv: every frame and its cluster" [expr {[concat {*}[lrange [table [file join $dx hepta_labels.csv]] 1 end]] eq $L}]
set T [lrange [table [file join $dx hepta_clusters.csv]] 1 end]
check "  clusters.csv: the sizes and representatives" [expr {[lmap r $T {lindex $r 1}] eq [${R}::sizes] &&
    [lmap r $T {lindex $r 5}] eq [lmap c {0 1 2 3 4 5} {${R}::rep_frame $c}]}]
set tr [lrange [table [file join $dx hepta_transitions.csv]] 1 end]
set C [vmdance transitions -counts 1]
set ok 1
foreach r $tr { lassign $r a b n; if {$a >= 0 && $b >= 0 && [lindex $C $a $b] != $n} { set ok 0 } }
check "  transitions.csv: the counts" [expr {$ok && [llength $tr] > 0}]
check "  top_frames.csv: rank 0 is each representative" [expr {[lsort -integer [lmap r [lrange [table [file join $dx hepta_top_frames.csv]] 1 end] {expr {[lindex $r 2] == 0 ? [lindex $r 0] : [continue]}}]] eq
    [lsort -integer [lmap c {0 1 2 3 4 5} {${R}::rep_frame $c}]]}]
check "  prime.csv: PRIME's frames" [expr {[lsort -integer [lmap r [lrange [table [file join $dx hepta_prime.csv]] 1 end] {lindex $r 1}]] eq [lsort -integer [dict values $p]]}]
check "  picks.csv, elbow.csv, sweep.csv: every row" [expr {[lmap r [lrange [table [file join $dx hepta_picks.csv]] 1 end] {lindex $r 1}] eq $picks &&
    [llength [table [file join $dx hepta_elbow.csv]]] == 10 && [llength [table [file join $dx hepta_sweep.csv]]] == 9}]
set mr [mol new [file join $dx hepta_representatives.pdb] waitfor all]
mol addfile [file join $dx hepta_representatives.dcd] waitfor all molid $mr
animate delete beg 0 end 0 $mr
set d 0.0
set reps [lmap c {0 1 2 3 4 5} {${R}::rep_frame $c}]
set j 0
foreach f $reps { set d [expr {max($d, [coord_diff $mr $j $mh $f])}]; incr j }
check "  the representatives' structures are the representatives' frames ([molinfo $mr get numframes] frames, largest difference [format %.1e $d] Å)" [expr {[molinfo $mr get numframes] == 6 && $d < 1e-3}]
mol delete $mr
set d 0.0; set nok 1
for {set c 0} {$c < 6} {incr c} {
    set mt [mol new [file join $dx hepta_cluster_$c.pdb] waitfor all]
    mol addfile [file join $dx hepta_cluster_$c.dcd] waitfor all molid $mt
    animate delete beg 0 end 0 $mt
    set fl [${R}::member_frames $c]
    if {[molinfo $mt get numframes] != [llength $fl]} { set nok 0 }
    foreach j [list 0 [expr {[llength $fl] / 2}] [expr {[llength $fl] - 1}]] { set d [expr {max($d, [coord_diff $mt $j $mh [lindex $fl $j]])}] }
    mol delete $mt
}
check "  each cluster's trajectory: its frames, VMD's coordinates (largest difference [format %.1e $d] Å)" [expr {$nok && $d < 1e-3}]
check "  the top molecule put back" [expr {[molinfo top] == $mh}]

# --- 3ptb: a range, a step, a fit -------------------------------------------------------
set mp [load_system 3ptb]
timed "3ptb Cα, frames 5-80 every 3, fit on the backbone, k 5" {
    vmdance -mol $mp -sel "name CA" -first 5 -last 80 -step 3 -fit backbone -k 5 -kinit KmeansPP -label "3ptb 5-80/3 fit" -quiet 1
}
set fr [dict keys [vmdance labels]]
check "3ptb: the frames clustered (5, 8 … 80)" [expr {[llength $fr] == 26 && [lindex $fr 0] == 5 && [lindex $fr end] == 80}]
check "  a frame between clustered ones is its predecessor's" [expr {[dict get [vmdance frame 7] clustered] == 5}]
set d3 [file join $::E export_3ptb]
file delete -force $d3
file mkdir $d3
vmdance export $d3 -prefix p -items {labels trajectories representatives} -format pdb -sel "protein"
set ok 1
for {set c 0} {$c < 5} {incr c} {
    set fl [${R}::member_frames $c]
    if {![llength $fl]} continue
    set mt [mol new [file join $d3 p_cluster_$c.pdb] waitfor all]
    if {[molinfo $mt get numframes] != [llength $fl] || [coord_diff $mt 0 $mp [lindex $fl 0] protein] > 1e-3} { set ok 0 }
    mol delete $mt
}
check "  PDB trajectories of the protein: each cluster's VMD frames, not fitted" $ok
timed "eQUAL on 3ptb Cα (radius 1.5)" { vmdance -mol $mp -sel "name CA" -algorithm equal -threshold 1.5 -quiet 1 }
check "  eQUAL: clusters and noise add up to the frames" [expr {[::tcl::mathop::+ {*}[${R}::sizes]] + [${R}::noise] == 100}]

# --- the library gives the program's answers ------------------------------------------------
if {[real_lib] ne ""} {
    use_lib
    set lib_labels [dict get [timed "the library: KMeans NANI k 6 of the heptapeptide" { vmdance -mol $mh -sel backbone -k 6 -quiet 1 }] nclusters]
    set ll [vmdance labels]
    vmdance run delete [lindex [lindex [vmdance runs] end] 0]
    use_cli
    vmdance run $nani
    check "the library's clustering of the heptapeptide is the program's" [expr {$ll eq [vmdance labels]}]
} else {
    skip "the library against the program" "no mdance_tcl library"
}

# --- the session, and what the next phases compare ----------------------------------------
vmdance run $nani
vmdance select 0 2
set sf [file join $::E work.vmdance]
timed "save the session ([llength [vmdance runs]] runs, 6001 frames)" { vmdance session save $sf }
check "session saved ([format %.1f [expr {[file size $sf] / 1e6}]] MB)" [file exists $sf]
timed "the state of every run (the command's answers)" { save_state work.state }
set fh [open [file join $::E work.molecules] w]
puts $fh [list hepta [::VMDance::Mol::record $mh] 3ptb [::VMDance::Mol::record $mp]]
close $fh
set left [lsearch -all -inline -not -glob [leftovers] *.csv]
check "no private file left but the kept coordinates ([join [lmap f $left {file tail $f}] {, }])" [expr {![llength $left]}]
check "no selection left" [expr {![llength [atomselect list]]}]
done
} err]} { puts "FAIL e2e work crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
