# The jobs with the fake backend (tests/fake_mdance_cli): requests and
# their checks, frame subsets, selections refused, what the backend
# returns checked, failures, Cancel, scans, the questions after a
# clustering, the capability probe, the coordinates kept.
#   cd <VMDance>; vmd -dispdev text -e tests/test_jobs.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set m [load_system two_state]
set o [load_system outlier]
set s1 [load_system single_state]

# --- requests ---------------------------------------------------------------------
check "a clustering request is checked whole" [expr {[dict get [::VMDance::Job::check_cluster [list mol $m sel all k 2]] natoms] == 8}]
check "  NANI's seeds: k 10 from 10% of 24 frames refused" [string match "*-k 10: NANI*raise -percentage to 42*" [err {::VMDance::Job::check_cluster [list mol $m sel all]}]]
foreach {req why} [list \
        [list mol 99 sel all] "no molecule \"99\"" \
        [list mol $m sel "x > 1"] "can match other atoms in other frames (\"x\")" \
        [list mol $m sel "within 3 of index 0"] "(\"within\")" \
        [list mol $m sel "resname XYZ"] "matches no atom" \
        [list mol $m sel "name CA and ("] "invalid atom selection" \
        [list mol $m sel all first 1o] "-first must be a whole number (got \"1o\")" \
        [list mol $m sel all step 010] "-step must be a whole number (got \"010\")" \
        [list mol $m sel all first 0x10] "-first must be a whole number" \
        [list mol $m sel all first 30] "-first must be a frame" \
        [list mol $m sel all first 5 last 3] "-last must be a frame from -first" \
        [list mol $m sel all step 0] "-step must be 1 or more" \
        [list mol $m sel all first 3 last 3] "at least 2 frames" \
        [list mol $m sel all k 25] "-k must be from 1 to the number of frames (24)" \
        [list mol $m sel all k 2x] "-k must be a whole number" \
        [list mol $m sel all algorithm xyz] "-algorithm must be one of" \
        [list mol $m sel all algorithm equal k 3] "finds its own number of clusters" \
        [list mol $m sel all algorithm equal] "-threshold is needed" \
        [list mol $m sel all metric Tanimoto] "-metric must be one of" \
        [list mol $m sel all fit "x < 3"] "-fit: the fit selection" \
        [list mol $m sel all fit "index 0 1"] "a fit needs at least 3 atoms" \
        [list mol $m sel all algorithm divine params {anchors SplinterPair refine 1}] "crashes" \
        [list mol $m sel all k 2 params {kinit Stratt}] "-kinit must be one of"] {
    check "  refused: $why" [string match "*$why*" [err {::VMDance::Job::check_cluster $req}]]
}
check "the command names the option" [string match "vmdance: -step must be 1 or more*" [err {vmdance -mol $m -sel all -step 0}]]
check "  an unknown option" [string match "*unknown option -bogus*" [err {vmdance -mol $m -sel all -bogus 1}]]
check "  another algorithm's parameter" [string match "*-threshold is not a parameter of KMeans NANI*" [err {vmdance -mol $m -sel all -threshold 1}]]
check "  an option given twice" [string match "*-k is given twice*" [err {vmdance -mol $m -sel all -k 2 -k 3}]]
check "  eQUAL's similarity ceiling 0 (every frame noise) refused" [string match "*-check-sim 1 needs -sim-threshold above 0*" [err {vmdance -mol $m -sel all -algorithm equal -threshold 1 -check-sim 1 -sim-threshold 0}]]
check "  HELM stopped by -k and -eps at once refused" [string match "*not both*" [err {vmdance -mol $m -sel all -algorithm helm -k 2 -eps 0.5 -initial 6 -initial-kinit KmeansPP}]]

# --- a clustering ---------------------------------------------------------------------
set i [vmdance -mol $m -sel all -k 2 -quiet 1]
check "KMeans with the fake: two clusters of 12" [expr {[dict get $i nclusters] == 2 && [dict get $i sizes] eq {12 12}}]
set all {}; for {set f 0} {$f < 24} {incr f} { lappend all $f }
check "  the frames are VMD's" [expr {[${R}::frames] eq $all}]
check "  the representatives in their clusters" [expr {[${R}::cluster_at [${R}::rep_frame 0]] == 0 && [${R}::cluster_at [${R}::rep_frame 1]] == 1}]
check "  the backend is recorded" [expr {[lindex [dict get $i backend] 0] eq "cli" && [file tail [lindex [dict get $i backend] 1]] eq "fake_mdance_cli"}]
set fm [${R}::measure frame_msd]
check "  every frame's MSD from its representative (0 for the representatives)" [expr {[llength $fm] == 24 &&
    [lindex $fm [${R}::rep 0]] == 0 && [lindex $fm [${R}::rep 1]] == 0}]
set sil [${R}::measure silhouette]
check "  two well separated states: silhouettes near 1" [expr {[::tcl::mathfunc::min {*}$sil] > 0.8}]
check "  no file left but the coordinates kept" [expr {[llength [leftovers]] <= 1 && [lsearch -glob -not [leftovers] *.csv] < 0}]

# frames subset
set i [vmdance -mol $m -sel all -k 2 -first 4 -last 19 -step 2 -kinit KmeansPP -quiet 1]
check "a subset: frames 4, 6 ... 18" [expr {[${R}::frames] eq {4 6 8 10 12 14 16 18} && [llength [${R}::labels]] == 8}]
check "  representatives among them" [expr {[${R}::rep_frame 0] in [${R}::frames] && [${R}::rep_frame 1] in [${R}::frames]}]
check "  a frame between two clustered ones: that of the one before" [expr {[${R}::cluster_at 5] eq [${R}::cluster_at 4] && [${R}::row_of 5] == -1}]
check "  outside the clustered frames: none" [expr {[${R}::cluster_at 3] eq "" && [${R}::cluster_at 20] eq ""}]
set lab [vmdance labels]
check "  the labels, by VMD frame" [expr {[lindex $lab 0] == 4 && [lindex $lab end-1] == 18}]

# --- what the backend returns, checked ---------------------------------------------------
set before $::VMDance::Results::current
fake_env MDANCE_FAKE_TRUNCATE 1
set e [err {vmdance -mol $m -sel all -k 2 -first 0 -quiet 1}]
check "truncated JSON refused" [string match "*not valid JSON*ends too early*" $e]
fake_env MDANCE_FAKE_EXTRA_LABELS 3
set e [err {vmdance -mol $m -sel all -k 2 -first 0 -quiet 1}]
check "extra labels refused" [string match "*returned 27 labels, not 24*" $e]
fake_env MDANCE_FAKE_FAIL 1
set e [err {vmdance -mol $m -sel all -k 2 -quiet 1}]
check "a failure says the backend's message" [string match "*mdance-cli failed*simulated backend failure*" $e]
check "  the clustering there is kept" [expr {$::VMDance::Results::current == $before && ![::VMDance::Job::busy]}]
check "  no file left but the coordinates kept" [expr {[llength [lsearch -all -inline -not -glob [leftovers] *.csv]] == 0}]
fake_env
# NaN scores
vmdance -mol $s1 -sel all -k 1 -quiet 1
check "one cluster: the NaN Davies–Bouldin is no score" [expr {[${R}::get db] eq "" && [${R}::nclusters] == 1}]
check "  and no silhouette" [expr {[lsort -unique [${R}::measure silhouette]] eq {{}}}]

# eQUAL: noise
vmdance -mol $o -sel all -algorithm equal -threshold 1.0 -quiet 1
check "eQUAL: the far frame is noise" [expr {[lindex [${R}::labels] 6] == -1 && [${R}::noise] == 1 && [${R}::nclusters] > 0}]
check "  noise has no MSD from a representative" [expr {[lindex [${R}::measure frame_msd] 6] eq ""}]
set T [vmdance transitions]
check "  transition rows sum to 1 with the share into noise" [expr {[near [::tcl::mathop::+ {*}[lindex $T [lindex [${R}::labels] 5]]] [expr {1 - 1.0 / [::tcl::mathop::+ {*}[lindex [vmdance transitions -counts 1] [lindex [${R}::labels] 5]] 1]}] 1e-3]}]

# HELM
vmdance -mol $m -sel all -algorithm helm -k 2 -initial 6 -initial-kinit KmeansPP -quiet 1
set z [${R}::get zmatrix]
check "HELM: its merges (4 of 6 starting clusters)" [expr {[llength $z] == 4 && [llength [${R}::get initial]] == 24}]
check "  the tree is HELM's" [expr {[dict get [vmdance tree] kind] eq "helm"}]
set lf [file join $::out helm_init.csv]
vmdance -mol $m -sel all -k 4 -quiet 1 -kinit KmeansPP
::VMDance::Export::_write $lf "[::VMDance::Export::table_labels]\n"
vmdance -mol $m -sel all -algorithm helm -k 2 -initial-labels $lf -quiet 1
set lf1 [file join $::out helm_1based.csv]
set fh [open $lf1 w]; for {set i 0} {$i < 24} {incr i} { puts $fh [expr {$i / 4 + 1}] }; close $fh
check "  a label file numbered from 1: its starting clusters numbered 0 …" [expr {[::VMDance::Algo::starting_labels $lf1 [${R}::frames]] eq
    [lmap i [lrepeat 24 x] {set i}] || [lsort -integer -unique [::VMDance::Algo::starting_labels $lf1 [lrange {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23} 0 end]]] eq {0 1 2 3 4 5}}]
check "  as many starting clusters as k: refused" [string match "*the file has 6 starting clusters; HELM merges more than -k (6)*" [err {vmdance -mol $m -sel all -algorithm helm -k 6 -initial-labels $lf1 -quiet 1}]]
check "  from a label file (the plugin's own export)" [expr {[llength [${R}::get zmatrix]] == 2 && [${R}::get initial] eq [dict get [lindex [${R}::run_data] end-1 2] labels]}]

# --- Cancel ---------------------------------------------------------------------------
proc bg {kind req} {
    set ::bgdone ""
    ::VMDance::Job::start $kind $req "" {apply {{st r} { set ::bgdone [list $st $r] }}}
}
proc wait_bg {{ms 60000}} {
    set id [after $ms {set ::bgdone timeout}]
    while {$::bgdone eq ""} { vwait ::bgdone }
    after cancel $id
    return $::bgdone
}
fake_env MDANCE_FAKE_SLEEP 6
set req [::VMDance::Job::check_cluster [list mol $m sel all k 2]]
set t0 [clock milliseconds]
bg cluster $req
after 1000 {::VMDance::Job::cancel}
lassign [wait_bg] st r
check "Cancel stops a running backend ([expr {[clock milliseconds] - $t0}] ms)" [expr {$st eq "cancelled" && [clock milliseconds] - $t0 < 5000 && ![::VMDance::Job::busy]}]
fake_env MDANCE_FAKE_SLEEP 30 MDANCE_FAKE_IGNORE_TERM 1
set t0 [clock milliseconds]
bg cluster $req
after 800 {::VMDance::Job::cancel}
lassign [wait_bg] st r
check "  even one that ignores TERM ([expr {[clock milliseconds] - $t0}] ms)" [expr {$st eq "cancelled" && [clock milliseconds] - $t0 < 8000}]
fake_env MDANCE_FAKE_SLEEP 2
bg cluster $req
after 300 {::VMDance::Job::cancel}
lassign [wait_bg] st r
fake_env MDANCE_FAKE_SLEEP 2.5
bg cluster $req
lassign [wait_bg] st r
check "  a job started right after a cancelled one runs to its end" [expr {$st eq "ok" && [dict get $r nclusters] == 2}]
fake_env
check "  one job at a time" [string match "*a job is running*" [err {
    bg cluster $req
    ::VMDance::Job::start cluster $req "" {apply {{st r} {}}}
}]]
wait_bg
check "  the command refuses while one runs" [expr {1}]
bg cluster $req
check "    (vmdance clusters: wait or cancel)" [string match "*running a job*" [err {vmdance clusters}]]
wait_bg
# cancelled while the coordinates are read (a long selection: every frame read in slices)
::VMDance::Coords::forget
set big [load_system 3ptb]
set req [::VMDance::Job::check_cluster [list mol $big sel "all" k 2]]
bg cluster $req
after 30 {::VMDance::Job::cancel}
lassign [wait_bg] st r
check "  Cancel while the frames are read" [expr {$st eq "cancelled" && ![dict size [::VMDance::Coords::cached $req]]}]
mol delete $big

# the kept rows dropped while a job reads them (a molecule loaded meanwhile)
fake_env MDANCE_FAKE_SLEEP 0.4
set ereq [::VMDance::Job::check_elbow [list mol $m sel all ks {2 3 4} params {kinit KmeansPP}]]
bg elbow $ereq
after 300 {::VMDance::Coords::forget}
lassign [wait_bg] st r
set csvs [glob -nocomplain -directory $::VMDance::Backend::workdir *.csv]
check "  the rows dropped during a scan: every k still clustered, the file deleted after" [expr {$st eq "ok" &&
    [lsort -unique [lmap x [dict get $r records] {dict get $x status}]] eq {ok} && ![llength $csvs]}]
fake_env

# --- scans ---------------------------------------------------------------------------
fake_env MDANCE_FAKE_FAIL_K 3
set rows [vmdance elbow -mol $m -sel all -from 2 -to 5 -kinit KmeansPP -quiet 1]
check "elbow: every k, the failed one kept" [expr {[llength $rows] == 4 && [dict get [lindex $rows 1] status] eq "error" &&
    [dict get [lindex $rows 0] status] eq "ok" && [string match "*simulated failure*" [dict get [lindex $rows 1] message]]}]
fake_env
check "  a failed k cannot be loaded" [string match "*failed*" [err {vmdance elbow load 3}]]
set i [vmdance elbow load 4]
check "  load k 4: the clustering at k 4, measured" [expr {[dict get $i nclusters] == 4 && [llength [${R}::measure frame_msd]] == 24}]
set rows [vmdance elbow -mol $m -sel all -from 2 -to 4 -quiet 1]
check "  a k its seeding cannot take is not run (and says why)" [expr {[dict get [lindex $rows 0] status] eq "ok" &&
    [string match "not run: -k 3: NANI*" [dict get [lindex $rows 1] message]]}]
check "  a scan where no k can run is refused" [string match "*-ks 3: NANI*" [err {vmdance elbow -mol $m -sel all -from 3 -to 4 -quiet 1}]]
check "  eQUAL has no elbow" [string match "*finds its own number*" [err {vmdance elbow -mol $m -sel all -algorithm equal -threshold 1}]]
check "  -from above -to" [string match "*-from must not be above -to*" [err {vmdance elbow -mol $m -sel all -from 6 -to 5}]]
check "  one value of k is no scan" [string match "*at least two values of k*" [err {vmdance elbow -mol $m -sel all -from 5 -to 5}]]
check "  -ks, or -from -to -by: not both" [string match "*not both*" [err {vmdance elbow -mol $m -sel all -ks {2 3} -to 5}]]
set t [lindex [time {set e [err {vmdance elbow -mol $m -sel all -from 2 -to 3000000}]}] 0]
check "  too many values of k: refused before they are made ([expr {$t / 1000}] ms)" [expr {[string match "*at most 200*" $e] && $t < 100000}]
check "  a sweep's -params for an algorithm not swept" [string match "*not swept*" [err {vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -params {divine {split MSD}}}]]
set rows [vmdance elbow -mol $m -sel all -algorithm helm -initial 8 -initial-kinit KmeansPP -ks {2 3 4} -quiet 1]
check "  HELM: the same starting clusters at every k" [expr {[llength $rows] == 3 &&
    [llength [lsort -unique [lmap r [dict get $::VMDance::Results::elbow records] {dict get $r clustering initial}]]] == 1}]

fake_env MDANCE_FAKE_FAIL_K 3
set rows [vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -from 2 -to 4 -seedings {StratAll KmeansPP} -quiet 1]
check "sweep: algorithms × seedings × k" [expr {[llength $rows] == 12}]
set failed [lmap r $rows {expr {[dict get $r status] eq "error" ? [dict get $r index] : [continue]}}]
set notrun [lmap r $rows {expr {[string match "not run*" [dict get $r message]] ? "[dict get $r algorithm] [dict get $r seeding] [dict get $r k]" : [continue]}}]
check "  the k = 3 runs failed" [expr {[lsort -unique [lmap r $rows {expr {[dict get $r k] == 3 ? [dict get $r status] : [continue]}}]] eq {error}}]
check "  NANI's StratAll at k 3 and 4 not run (24 frames), DIVINE's run" [expr {[lsort $notrun] eq {{kmeans StratAll 3} {kmeans StratAll 4}}}]
set b [vmdance sweep best ch]
check "  the best is never a failed one" [expr {[dict get $b status] eq "ok" && [dict get $b index] ni $failed}]
set chs [lmap r $rows {expr {[dict get $r status] eq "ok" && [dict get $r ch] ne "" ? [dict get $r ch] : [continue]}}]
check "  the best Calinski–Harabasz is the highest" [expr {[dict get $b ch] == [::tcl::mathfunc::max {*}$chs]}]
fake_env
set i [vmdance sweep load [dict get $b index]]
check "  load the best" [expr {[dict get $i k] == [dict get $b k] && [dict get $i algorithm] eq [dict get $b algorithm]}]
check "  eQUAL is not swept" [string match "*not given k*" [err {vmdance sweep -mol $m -sel all -algorithms equal}]]

# --- questions after a clustering -----------------------------------------------------------
vmdance -mol $m -sel all -k 2 -first 4 -last 19 -step 2 -kinit KmeansPP -quiet 1
set p [vmdance prime]
check "PRIME: seven frames, VMD's" [expr {[dict size $p] == 7 && [lsort -unique [lmap {k f} $p {expr {$f in [${R}::frames]}}]] eq {1}}]
check "  kept with the run" [expr {[dict size [${R}::extra prime]] == 8}]
set s [vmdance similarity]
check "similarity: the clusters' iSIM and least similar frames" [expr {[dict size [dict get $s clusters]] == 2 &&
    [lsort -unique [lmap {c f} [dict get $s least_similar] {expr {$f in [${R}::frames]}}]] eq {1}}]
set f [vmdance pick -mol $m -sel all -method diversity -param 25]
check "pick: frames among those of the request" [expr {[llength $f] >= 1 && [lsort -unique [lmap x $f {expr {$x >= 0 && $x < 24}}]] eq {1}}]
set f [vmdance pick -mol $m -sel all -method medoid -first 10 -last 20]
check "  a subset's rows are VMD's frames" [expr {[llength $f] == 1 && [lindex $f 0] >= 10 && [lindex $f 0] <= 20}]
check "  an unknown method" [string match "*-method must be one of*" [err {vmdance pick -mol $m -sel all -method best}]]
set sa [atomselect $m all frame 6]
set xyz0 [$sa get {x y z}]
$sa moveby {50 0 0}
check "  PRIME on coordinates moved since the clustering: refused" [string match "*changed since the clustering was made*" [err {vmdance prime}]]
# (moved back exactly: +50 then -50 is not the same float)
$sa set {x y z} $xyz0
check "    (put back, taken again)" [expr {[dict size [vmdance prime]] == 7}]
$sa delete

# --- the capability probe ---------------------------------------------------------------------
fake_env MDANCE_FAKE_NO_DIVINE 1
check "a backend without DIVINE says so" [expr {[::VMDance::Backend::algorithms] eq {kmeans helm equal}}]
check "  DIVINE is refused before running" [string match "*DIVINE is not in this build*BUILD_DIVINE*" [err {vmdance -mol $m -sel all -algorithm divine -quiet 1}]]
fake_env
check "  with it, all four" [expr {[::VMDance::Backend::algorithms] eq {kmeans divine helm equal}}]
check "a program that is not one" [string match "*not an executable*" [err {::VMDance::Backend::configure -cli /etc/hosts}]]
use_fake
set before [dict get [::VMDance::Backend::status] mode]
err {::VMDance::Backend::configure -mode library -cli /etc/hosts}
check "  refused whole: the mode given with it is not kept" [expr {[dict get [::VMDance::Backend::status] mode] eq $before}]
fake_env MDANCE_FAKE_SLEEP 1
set req [::VMDance::Job::check_cluster [list mol $m sel all k 2]]
set ::told {}
proc tell {what kind} { lappend ::told $what $kind }
::VMDance::Job::listen tell
bg cluster $req
check "the backend is not changed under a running job" [string match "*a job is running*" [err {::VMDance::Backend::configure -mode library}]]
check "  (the same backend again is no change)" [expr {![catch {::VMDance::Backend::configure -mode $before}]}]
lassign [wait_bg] st r
update
::VMDance::Job::unlisten tell
check "  a job's listeners are told when it starts and ends" [expr {$st eq "ok" && $::told eq {start cluster end cluster}}]
fake_env

# --- the coordinates -------------------------------------------------------------------------
set req [::VMDance::Job::check_input [list mol $m sel all]]
set c1 [::VMDance::Coords::extract $req]
check "the rows: one per frame, 3 × natoms numbers" [expr {[llength [::VMDance::Coords::rows $c1]] == 24 && [llength [lindex [::VMDance::Coords::rows $c1] 0]] == 24}]
check "  kept for the next job" [expr {[dict size [::VMDance::Coords::cached $req]] > 0}]
set labs [lrepeat 24 0]; for {set i 12} {$i < 24} {incr i} { lset labs $i 1 }
set mv [::VMDance::Measure::compute $c1 $labs 2 {3 15} 8]
set mf [::VMDance::Measure::compute [dict replace $c1 mol -1] $labs 2 {3 15} 8]
check "  the measures from VMD's coordinates are those from the file's" [expr {$mv eq $mf}]
set a0 [[set sa [atomselect $m all frame 5]] get {x y z}]
set freq [::VMDance::Job::check_input [list mol $m sel all fit all]]
set c2 [::VMDance::Coords::extract $freq]
check "  a fit: VMD's coordinates are not moved" [expr {[$sa get {x y z}] eq $a0}]
$sa delete
set r0 [lindex [::VMDance::Coords::rows $c2] 0]; set r5 [lindex [::VMDance::Coords::rows $c2] 5]
set q0 [lindex [::VMDance::Coords::rows $c1] 0]; set q5 [lindex [::VMDance::Coords::rows $c1] 5]
check "  the fitted rows are closer to the first frame" [expr {[vecdist $r0 $r5] <= [vecdist $q0 $q5] + 1e-6}]
# coordinates moved in place (an alignment): the kept rows are not used
set c0 [::VMDance::Coords::extract $req]
set sa [atomselect $m all frame 7]
$sa moveby {100 0 0}
check "  coordinates moved in place: the kept rows are dropped" [expr {![dict size [::VMDance::Coords::cached $req]]}]
set c3 [::VMDance::Coords::extract $req]
check "    and read again" [expr {[lindex [::VMDance::Coords::rows $c3] 7 0] > 50}]
check "  the measures refuse rows that changed during the job" [string match "*coordinates of frame 7*changed*" [err {
    $sa moveby {-1 0 0}
    ::VMDance::Measure::compute $c3 $labs 2 {3 15} 8
}]]
$sa delete
# two atoms that swap places: every sum of the coordinates stays the same
set c4 [::VMDance::Coords::extract $req]
set s2 [atomselect $m "index 0 1" frame 3]
set x2 [$s2 get {x y z}]
$s2 set {x y z} [lreverse $x2]
check "  two atoms that swap places: the kept rows are dropped" [expr {![dict size [::VMDance::Coords::cached $req]]}]
$s2 set {x y z} $x2
$s2 delete
::VMDance::Coords::forget
# (not "animate dup": VMD crashes later)
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
check "  the molecule changed (frames added): the kept rows are dropped" [expr {![dict size [::VMDance::Coords::cached $req]]}]
done
} err]} { puts "FAIL test_jobs crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
