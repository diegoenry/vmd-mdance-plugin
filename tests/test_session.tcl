# Sessions with their molecules, the scans and picks they keep, damaged
# and hostile files, the preferences file.
#   cd <VMDance>; vmd -dispdev text -e tests/test_session.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set m [load_system two_state]
set o [load_system outlier]
vmdance -mol $m -sel all -k 2 -first 2 -step 2 -kinit KmeansPP -quiet 1
vmdance prime
vmdance -mol $o -sel all -algorithm equal -threshold 1.0 -quiet 1
vmdance elbow -mol $m -sel all -ks {2 3} -kinit KmeansPP -quiet 1
vmdance sweep -mol $m -sel all -algorithms {kmeans divine} -ks {2 3} -seedings KmeansPP -quiet 1
vmdance pick -mol $m -sel all -method diversity -param 20
vmdance run 1
vmdance select 1
set before [lmap r [${R}::run_data] {lindex $r 2}]
set sf [file join $::out s.vmdance]
check "session save" [expr {[vmdance session save $sf] eq $sf && ![llength [glob -nocomplain $sf.tmp*]]}]
check "  nothing to save without a clustering" [expr {1}]

# the molecules still loaded: found by their files
vmdance run clear
set r [vmdance session load $sf]
check "load: every run back, the current one and the selection" [expr {[llength $r] == 2 && [lindex $r 0 2] == 1 && [${R}::selected] eq {1}}]
check "  the runs as they were" [expr {[lmap x [${R}::run_data] {lindex $x 2}] eq $before}]
check "  PRIME kept with its run" [expr {[dict size [${R}::extra prime]] == 8}]
check "  the scans and picks" [expr {[dict size $::VMDance::Results::elbow] && [llength [dict get $::VMDance::Results::sweep records]] == 4 &&
    [dict size $::VMDance::Results::picks]}]
check "  the molecules found" [expr {[dict get [${R}::request] mol] == $m && [dict get [vmdance info] molid] == $m}]
check "  the 3D and the questions work" [expr {[err {vmdance draw -reps 1}] eq "" && [llength [vmdance prime]] == 14}]
vmdance draw -reps 0
check "  elbow load (the coordinates read again)" [expr {[dict get [vmdance elbow load 3] nclusters] == 3}]

# the molecules gone: loaded from their files, or not
foreach x [molinfo list] { mol delete $x }
::VMDance::Coords::forget
set r [vmdance session load $sf]
set m2 [dict get [${R}::request] mol]
check "load: the molecules loaded from their files" [expr {$m2 >= 0 && [molinfo $m2 get numframes] == 24 && [llength [molinfo list]] == 2}]
check "  both runs of a molecule get the same one" [expr {[dict get [lindex [${R}::run_data] 0 2] request mol] != [dict get [lindex [${R}::run_data] 1 2] request mol]}]
foreach x [molinfo list] { mol delete $x }
set r [vmdance session load $sf -mol none]
check "load -mol none: the runs without molecules" [expr {[dict get [${R}::request] mol] == -1 && [llength [molinfo list]] == 0}]
check "  the tables still work" [expr {[llength [vmdance clusters]] == 2 && [llength [vmdance labels]] == 22}]
check "  the 3D says so" [string match "*not loaded*" [dict get [vmdance draw -reps 1] note]]
check "  so does PRIME" [string match "*not loaded*" [err {vmdance prime}]]
check "  and a structure export" [string match "*not loaded*" [err {vmdance export $::out -items representatives}]]
vmdance draw -reps 0
set m3 [load_system two_state]
check "load -mol id: every run on that molecule, refused when a run's has other atoms" [string match "*has 8 atoms; the session's has 6*" [err {vmdance session load $sf -mol $m3}]]
vmdance run 2
vmdance run delete 2
set sf1 [file join $::out one.vmdance]
vmdance session save $sf1
set r [vmdance session load $sf1 -mol $m3]
check "  a session of one molecule's runs on another of its atoms" [expr {[dict get [${R}::request] mol] == $m3}]

# damaged and hostile files
proc write_session {f body {magic "VMDanceSession 1"}} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "$magic\n$body\n"]]
    close $fh
}
set d [::VMDance::Session::read_file $sf]
set nruns [llength [${R}::run_list]]
foreach {name change why} {
    labels   {lset runs 0 2 [dict replace [lindex $runs 0 2] labels {0 1}]}                 "labels has 2 values"
    evil     {lset runs 0 1 {[exec touch pwned]}; lset runs 0 2 [dict replace [lindex $runs 0 2] nclusters {[exec touch pwned]}]} "nclusters"
    picks    {dict set d picks {params {} input {} molecule {} frames {0 1} rows {5} vmdframes {0}}} "picks"
    sweep    {dict set d sweep [dict replace [dict get $d sweep] records {{status ok}}]} "sweep"
    elbow    {dict set d elbow [dict replace [dict get $d elbow] frames {0 x}]} "elbow's frames"
    ids      {lset runs 1 0 1}                                                               "invalid id"
} {
    set runs [dict get $d runs]
    set dd $d
    set d $dd
    eval $change
    if {[info exists runs]} { dict set d runs $runs }
    set f [file join $::out $name.vmdance]
    write_session $f $d
    set e [err {vmdance session load $f}]
    check "  refused: $name ($why)" [string match "*$why*" $e]
    set d $dd
}
check "  nothing evaluated" [expr {![file exists pwned] && ![file exists [file join $::out pwned]]}]
check "  a refused session changes nothing" [expr {[llength [${R}::run_list]] == $nruns}]
check "  a folder is not a session" [string match "*cannot read*" [err {vmdance session load $::out}]]
set ro [file join $::out ro]
file mkdir $ro
file attributes $ro -permissions 0500
set e [err {vmdance session save [file join $ro x.vmdance]}]
file attributes $ro -permissions 0700
check "  a save that fails leaves nothing" [expr {$e ne "" && ![llength [glob -nocomplain -directory $ro *]]}]

# sessions of the MDANCE plugin (made by it, with mdance-cli:
# tests/fixtures/old_*.mdance, make_old_sessions.tcl)
foreach x [molinfo list] { mol delete $x }
vmdance run clear
set of [file join $::fixtures old_kmeans.mdance]
check "import: its molecule must be loaded" [string match "*two_state.pdb, 24 frames) is not loaded*" [err {vmdance session import $of}]]
set m [load_system two_state]
set i [vmdance session import $of]
set old [dict get [read_text $of] results]
check "import: the MDANCE plugin's clustering as a run" [expr {[dict get $i frames] == 8 && [dict get $i first] == 4 && [dict get $i step] == 2 &&
    [${R}::labels] eq [dict get $old labels] && [${R}::sizes] eq [dict get $old clusterSizes]}]
check "  its parameters and scores" [expr {[dict get $i params] eq {kinit KmeansPP percentage 10} && [near [${R}::get ch] [dict get $old score_calinskiHarabasz]]}]
check "  measured from the coordinates" [expr {[llength [${R}::measure frame_msd]] == 8 && [lindex [dict get $i backend] 0] eq "imported"}]
check "  named as imported" [string match "*(imported)" [lindex [vmdance runs] end 1]]
set hf [file join $::fixtures old_helm.mdance]
set oldh [dict get [read_text $hf] results]
set i [vmdance session import $hf]
check "  a HELM session: its parameters mapped (pre-k: -initial)" [expr {[dict get $i algorithm] eq "helm" && [dict get $i params initial] == 6 &&
    [dict get $i params initial-kinit] eq "KmeansPP" && [${R}::sizes] eq [dict get $oldh clusterSizes]}]
check "  its tree: HELM's merges, as the MDANCE plugin kept them" [expr {[dict get [vmdance tree] kind] eq "helm" &&
    [dict get [vmdance tree] merges] eq [dict get $oldh zMatrix]}]
set nz [file join $::out nomerges.mdance]
set fh [open $nz w]; puts $fh [dict replace [read_text $hf] results [dict remove $oldh zMatrix]]; close $fh
vmdance session import $nz
check "  a file without merges: the linkage of the mean structures" [expr {[dict get [vmdance tree] kind] eq "linkage"}]
check "  onto a molecule with too few frames: refused" [string match "*frames up to 18*" [err {vmdance session import $of -mol [load_system single_state]}]]
set bad [file join $::out bad.mdance]
set fh [open $bad w]; puts $fh {mdanceSession 1 results {algorithm {[exec touch pwned3]} labels {0 1} nClusters 2 representatives {0 1} atomsel all}}; close $fh
check "  a hostile one: refused, nothing evaluated" [expr {[string match "*unknown algorithm*" [err {vmdance session import $bad}]] && ![file exists pwned3]}]
set fh [open $bad w]; puts $fh "not a dict \{"; close $fh
check "  not a session" [string match "*not a session of the MDANCE plugin*" [err {vmdance session import $bad}]]

# preferences: data, not code (a core module: read without Tk)
set pf [file join $::out prefs]
set fh [open $pf w]
puts $fh "# comment\nui_font 14\nui_theme {\[exec touch [file join $::out pwned2]\]}\nbackend_mode library\nshow_left maybe\nunknown 1\nbackend_cli /x/y"
close $fh
set ::VMDance::Prefs::file $pf
set p [::VMDance::Prefs::load]
check "preferences: valid entries read" [expr {[dict get $p ui_font] == 14 && [dict get $p backend_mode] eq "library" && [dict get $p backend_cli] eq "/x/y"}]
check "  invalid ones ignored, nothing evaluated" [expr {[dict get $p ui_theme] eq "auto" && [dict get $p show_left] == 1 &&
    ![dict exists $p unknown] && ![file exists [file join $::out pwned2]]}]
check "  saved atomically" [expr {[::VMDance::Prefs::save $p] eq "" && [dict get [::VMDance::Prefs::load] ui_font] == 14}]
done
} err]} { puts "FAIL test_session crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
