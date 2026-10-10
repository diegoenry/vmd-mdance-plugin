# The core without VMD's molecules: the JSON reader, the parameters and
# their checks, the backend's arguments, label files, a result's checks,
# the labels' measures, sessions read as data.
#   cd <VMDance>; tclsh tests/test_core.tcl
#   or: vmd -dispdev text -e tests/test_core.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

if {[catch {
package require vmdance
set J ::VMDance::Json::parse
set A ::VMDance::Algo

# --- JSON ------------------------------------------------------------------------
check "json: an object of arrays, numbers, null, NaN, booleans, escapes" [expr {
    [$J {{"a": [1, 2.5e3, -0.5], "b": {"c": null, "d": NaN, "e": true, "f": false}, "s": "x\"yé\n"}}] eq
    [list a {1 2.5e3 -0.5} b {c {} d {} e 1 f 0} s "x\"yé\n"]}]
check "  -Infinity and -NaN are \"\" (not there)" [expr {[$J {[-Infinity, 1, -NaN, Infinity]}] eq {{} 1 {} {}}}]
check "  an empty array, a nested one" [expr {[$J {{"z": [], "m": [[1,2],[3,4]]}}] eq {z {} m {{1 2} {3 4}}}}]
foreach {bad why} [list "" empty "\{\"a\": \[1, 2\}" "\]" \
        "\{\"algorithm\": \"kmeans\", \"labels\": \[0, 1, 0" "ends too early" "\[1,\]" unexpected \
        "\{\"a\" 1\}" ":" "\"abc" "does not end" "\[1 2\]" "expected" "\{\"a\":1\}x" "after the value" \
        "\[010\]" "bad number" "\[1.\]" "bad number" "\[+1\]" "bad number" "\[e\]" "bad number"] {
    check "  refused: [list $bad] ($why)" [string match "*$why*" [err {$J $bad}]]
}
set big "\{\"labels\": \[[join [lrepeat 50000 3] {, }]\]\}"
set t [lindex [time {set v [$J $big]}] 0]
check "  50 000 labels in under 2 s ([expr {$t / 1000}] ms)" [expr {[llength [dict get $v labels]] == 50000 && $t < 2000000}]
set deep "[string repeat \[ 100]1[string repeat \] 100]"
check "  nesting deeper than 64 refused" [string match "*deeply*" [err {$J $deep}]]

# --- parameters -------------------------------------------------------------------
check "the algorithms, in order" [expr {[${A}::all] eq {kmeans divine helm equal}}]
check "  those given k" [expr {[${A}::with_k] eq {kmeans divine helm}}]
check "  the window's defaults: KMeans k 10, DIVINE 3, HELM 10 from 50 (StratAll 10%)" [expr {
    [${A}::default_k kmeans] == 10 && [${A}::default_k divine] == 3 && [${A}::default_k helm] == 10 &&
    [dict get [${A}::defaults helm] initial] == 50 && [dict get [${A}::defaults helm] initial-kinit] eq "StratAll"}]
set p [${A}::check_params kmeans {kinit CompSim}]
check "check_params completes the defaults" [expr {$p eq {kinit CompSim percentage 10}}]
check "  an unknown parameter names the valid ones" [string match "*-kinitt is not a parameter of KMeans NANI*-kinit, -percentage*" [err {${A}::check_params kmeans {kinitt x}}]]
check "  a choice out of its values" [string match "*-kinit must be one of StratAll*" [err {${A}::check_params kmeans {kinit Nope}}]]
foreach {v why} {1o "whole number" 2.5 "whole number" 010 "whole number" "" "whole number" 0 "at least 1" 101 "at most 100" ">f" "whole number" "|id" "whole number"} {
    check "  -percentage \"$v\" refused ($why)" [string match "*$why*" [err {${A}::check_params kmeans [list percentage $v]}]]
}
foreach {v ok} {1.5 1 .5 1 -1 1 1e3 1 1e400 0 NaN 0 Inf 0 1,5 0 0x10 0 01.5 0} {
    check "  -eps \"$v\" [expr {$ok ? "taken" : "refused"}]" [expr {[err {${A}::check_params helm [list eps $v]}] eq "" ? $ok : !$ok}]
}
check "  eQUAL needs -threshold" [string match "*-threshold is needed*" [err {${A}::check_params equal {}}]]
check "  booleans become 0 and 1" [expr {[dict get [${A}::check_params divine {refine yes}] refine] == 1}]
check "  a stored request's label file need not exist" [expr {[err {${A}::check_params helm {initial-labels /no/such.csv} 1}] eq "" &&
    [string match "*cannot read*" [err {${A}::check_params helm {initial-labels /no/such.csv}}]]}]
check "metric: MSD and the ten indices" [expr {[${A}::check_metric SM] eq "SM" && [string match "*must be one of MSD*" [err {${A}::check_metric msd}]]}]

# the checks across parameters
set dv [${A}::check_params divine {anchors OutlierPair refine 1}]
check "DIVINE: OutlierPair with refine refused (it crashes the backend)" [string match "*crashes*" [err {${A}::check_combination divine 3 $dv 100}]]
check "  with refine 0 taken" [expr {[err {${A}::check_combination divine 3 [dict replace $dv refine 0] 100}] eq ""}]
set hp [${A}::check_params helm {}]
check "HELM: 50 starting clusters need 50 frames" [string match "*-initial must be at most*" [err {${A}::check_combination helm 10 $hp 40}]]
check "  more than k" [string match "*-initial (50) must be more than -k (60)*" [err {${A}::check_combination helm 60 $hp 1000}]]
check "  k 0 needs -eps" [string match "*-k 0 needs -eps*" [err {${A}::check_combination helm 0 $hp 1000}]]
check "  StratAll 10% of 100 frames seeds at most 10 clusters" [string match "*raise -initial-percentage to 50*" [err {${A}::check_combination helm 10 $hp 100}]]
check "  (with 500 frames, taken)" [expr {[err {${A}::check_combination helm 10 $hp 500}] eq ""}]
set tp [${A}::check_params helm {trim-start 1}]
check "  trimming needs -trim-k or -trim-val" [string match "*needs -trim-k*" [err {${A}::check_combination helm 10 $tp 1000}]]
check "  not both" [string match "*one of them*" [err {${A}::check_combination helm 10 [dict merge $tp {trim-k 2 trim-val 1}] 1000}]]
check "  49 of 50 starting clusters left out: refused; 48: taken" [expr {
    [string match "*nothing to merge*" [err {${A}::check_combination helm 1 [dict replace $tp trim-k 49] 1000}]] &&
    [err {${A}::check_combination helm 1 [dict replace $tp trim-k 48] 1000}] eq ""}]
check "  what is left must be more than k: 40 of 50 at k 10 refused, 39 taken" [expr {
    [string match "*leaves 10, not more than -k (10)*" [err {${A}::check_combination helm 10 [dict replace $tp trim-k 40] 1000}]] &&
    [err {${A}::check_combination helm 10 [dict replace $tp trim-k 39] 1000}] eq ""}]
check "KMeans: k 11 with StratAll 10% of 100 frames refused" [string match "*-k 11: NANI*raise -percentage to 11*" [err {${A}::check_combination kmeans 11 [${A}::defaults kmeans] 100}]]
check "  with KmeansPP taken" [expr {[err {${A}::check_combination kmeans 11 {kinit KmeansPP percentage 10} 100}] eq ""}]

# the backend's arguments
set argv [${A}::cli_args kmeans 5 MSD [${A}::check_params kmeans {}] 10 in.csv out.json]
check "cli_args: KMeans" [expr {$argv eq {--algorithm kmeans --input in.csv --output out.json --natoms 10 --metric MSD --nclusters 5 --kinit StratAll --percentage 10}}]
set argv [${A}::cli_args helm 4 MSD [${A}::check_params helm {}] 10 in.csv out.json init.csv]
check "  HELM: the starting labels file, not the plugin's own parameters, no trim when not trimming" [expr {
    [lsearch $argv --initial-labels] >= 0 && [lsearch $argv --initial] < 0 && [lsearch $argv --initial-kinit] < 0 &&
    [lsearch $argv --trim-start] < 0 && [lsearch $argv --min-samples] < 0 && [lsearch $argv --trim-k] < 0 && [lsearch $argv --eps] >= 0}]
set argv [${A}::cli_args helm 4 MSD [${A}::check_params helm {trim-start 1 trim-k 3}] 10 in.csv out.json init.csv]
check "  trimming by k: --trim-start --trim-k --min-samples, not --trim-val" [expr {
    [lsearch $argv --trim-start] >= 0 && [lsearch $argv --trim-k] >= 0 && [lsearch $argv --min-samples] >= 0 && [lsearch $argv --trim-val] < 0}]
set argv [${A}::cli_args divine 3 MSD [${A}::check_params divine {refine 0}] 10 in.csv out.json]
check "  DIVINE: --refine only when on" [expr {[lsearch $argv --refine] < 0 && [lsearch [${A}::cli_args divine 3 MSD [${A}::check_params divine {refine 1}] 10 a b] --refine] >= 0}]
set argv [${A}::cli_args equal "" MSD [${A}::check_params equal {threshold 2}] 10 in.csv out.json]
check "  eQUAL: no --nclusters" [expr {[lsearch $argv --nclusters] < 0 && [lsearch $argv --threshold] >= 0}]
check "lib_args: the same options with one dash" [expr {[${A}::lib_args kmeans [${A}::check_params kmeans {}] MSD] eq {-metric MSD -kinit StratAll -percentage 10}}]

# label files
set lf [file join $::out labels_1.csv]
set fh [open $lf w]; puts $fh "# a comment\n3\n1\n\n2"; close $fh
check "read_labels: one label per line, comments and blank lines" [expr {[${A}::read_labels $lf {0 1 2}] eq {3 1 2}}]
check "  the wrong number" [string match "*3 labels for the 4 frames*" [err {${A}::read_labels $lf {0 1 2 3}}]]
set fh [open $lf w]; puts $fh "# init_type: comp_sim\n# Frame Index, Cluster Index\n2,7\n0,5\n1,6"; close $fh
check "  MDANCE's frame,label rows (rows 0..n-1, any order)" [expr {[${A}::read_labels $lf {10 20 30}] eq {5 6 7}}]
set fh [open $lf w]; puts $fh "frame,cluster\n14,1\n10,0\n12,1"; close $fh
check "  the plugin's own export (VMD frames, a header)" [expr {[${A}::read_labels $lf {10 12 14}] eq {0 1 1}}]
check "  frames that are neither" [string match "*neither rows 0 to 2 nor the 3 frames*" [err {${A}::read_labels $lf {10 12 16}}]]
set fh [open $lf w]; puts $fh "08\n09\n010"; close $fh
check "  leading zeros are decimal (not octal)" [expr {[${A}::read_labels $lf {0 1 2}] eq {8 9 10}}]
set fh [open $lf w]; puts $fh "0,1\n0,2\n1,1"; close $fh
check "  a frame listed twice" [string match "*twice*" [err {${A}::read_labels $lf {0 1 2}}]]
set fh [open $lf w]; puts $fh "0,1,2\n1,1,1"; close $fh
check "  three columns" [string match "*3 comma-separated fields*" [err {${A}::read_labels $lf {0 1}}]]
set fh [open $lf w]; puts $fh "1\n0,1"; close $fh
check "  ragged rows" [string match "*has 2 fields, not 1*" [err {${A}::read_labels $lf {0 1}}]]
set fh [open $lf w]; puts $fh "1\nx"; close $fh
check "  a word" [string match "*\"x\" is not a whole number*" [err {${A}::read_labels $lf {0 1}}]]

# --- the labels' measures -------------------------------------------------------------
set M ::VMDance::Measure
check "runs: consecutive frames in one cluster" [expr {[${M}::runs {0 0 1 -1 1 1 0}] eq {{0 0 2} {1 2 1} {-1 3 1} {1 4 2} {0 6 1}}}]
check "transitions: noise frames left out" [expr {[${M}::transitions {0 0 1 -1 1 0} 2] eq {{1 1} {1 0}}}]
check "  lag 2" [expr {[${M}::transitions {0 1 0 1 0} 2 2] eq {{2 0} {0 1}}}]
set L [${M}::linkage {{0 1 4} {1 0 3} {4 3 0}}]
check "linkage: average linkage, merges numbered k, k+1 ..." [expr {[llength $L] == 2 && [lrange [lindex $L 0] 0 1] eq {0 1} &&
    [lindex $L 0 2] == 1 && [lrange [lindex $L 1] 0 1] eq {2 3} && [near [lindex $L 1 2] 3.5] && [lindex $L 1 3] == 3}]
set L [${M}::linkage {{0 "" 2} {"" "" ""} {2 "" 0}}]
check "  an empty cluster is left out" [expr {[llength $L] == 1 && [lrange [lindex $L 0] 0 1] eq {0 2}}]
# the linkage searches again only where a merge took a node's nearest: the
# same merges as the search of every pair (ties too, and empty clusters)
proc naive_linkage {M} {
    set k [llength $M]
    set active {}
    for {set i 0} {$i < $k} {incr i} {
        if {[lindex $M $i $i] ne ""} { lappend active $i; set cnt($i) 1 }
        for {set j 0} {$j < $k} {incr j} { set D($i,$j) [lindex $M $i $j] }
    }
    set rows {}; set next $k
    while {[llength $active] > 1} {
        set best ""
        foreach i $active { foreach j $active {
            if {$j <= $i || $D($i,$j) eq ""} continue
            if {$best eq "" || $D($i,$j) < $best} { set best $D($i,$j); set bi $i; set bj $j }
        } }
        if {$best eq ""} break
        set n [expr {$cnt($bi) + $cnt($bj)}]
        lappend rows [list $bi $bj $best $n]
        set cnt($next) $n
        foreach o $active {
            if {$o == $bi || $o == $bj} continue
            set a $D($o,$bi); set b $D($o,$bj)
            set d [expr {$a eq "" || $b eq "" ? "" : ($a * $cnt($bi) + $b * $cnt($bj)) / double($n)}]
            set D($o,$next) $d; set D($next,$o) $d
        }
        set D($next,$next) 0.0
        set active [lmap o $active {expr {$o == $bi || $o == $bj ? [continue] : $o}}]
        lappend active $next
        incr next
    }
    return $rows
}
expr {srand(7)}
set same 1
foreach {k ties empty} {2 0 0 5 0 0 12 1 0 17 0 1 30 1 1 40 0 0} {
    set X {}
    for {set i 0} {$i < $k} {incr i} { lappend X [lrepeat $k 0.0] }
    for {set i 0} {$i < $k} {incr i} {
        for {set j [expr {$i + 1}]} {$j < $k} {incr j} {
            set d [expr {$ties ? double(1 + int(rand() * 4)) : 0.1 + rand() * 10}]
            lset X $i $j $d; lset X $j $i $d
        }
    }
    if {$empty} {
        foreach e {1 4} { lset X $e [lrepeat $k ""]; for {set i 0} {$i < $k} {incr i} { lset X $i $e "" } }
    }
    if {[${M}::linkage $X] ne [naive_linkage $X]} { set same 0; puts "  linkage differs at k $k" }
}
check "  the same merges as the search of every pair (k 2 to 40, ties, empty clusters)" $same
set X {}
for {set i 0} {$i < 300} {incr i} { set row {}; for {set j 0} {$j < 300} {incr j} { lappend row [expr {abs($i - $j) + 0.001 * (($i * 7 + $j * 13) % 11)}] }; lappend X $row }
for {set i 0} {$i < 300} {incr i} { for {set j 0} {$j < $i} {incr j} { lset X $i $j [lindex $X $j $i] } }
set t [lindex [time {set L [${M}::linkage $X]}] 0]
check "  300 clusters in under 10 s ([expr {$t / 1000}] ms)" [expr {[llength $L] == 299 && $t < 10000000}]

# HELM's merges, numbered as scipy numbers them. CPP-MDANCE numbers a merge
# from the starting clusters kept after trimming: here 6 kept of 8 (0 and
# 1 trimmed), so that its first merge is "6", as starting cluster 6 is.
set T [${M}::helm_tree {{4 5 1 2} {0 4 2 3} {2 5 3 4}} {0 1 2 3 4 5} {0 -1 0 -1 0 0} 1]
check "helm_tree: the leaves kept, the merges from the starting clusters' number" [expr {
    $T eq {{{4 5 1 2} {0 6 2 3} {2 7 3 4}} {0 2 4 5} 6}}]
set T [${M}::helm_tree {{1 2 1 2} {5 3 2 2} {5 4 3 3}} {0 1 2 3 4 5} {-1 0 0 1 0 1} 2]
check "  a number both a merge and a starting cluster: the row's count tells" [expr {
    [lindex $T 0] eq {{1 2 1 2} {5 3 2 2} {6 4 3 3}} && [lindex $T 1] eq {1 2 3 4 5}}]
set T [${M}::helm_tree {{2 3 1 2} {4 5 2 2} {6 7 3 3} {6 8 4 5}} {0 1 2 3 4 5 6 7} {-1 -1 0 0 0 0 0 1} 2]
check "  both readings of a row fit its count: the one the next rows fit" [expr {
    [lindex $T 0] eq {{2 3 1 2} {4 5 2 2} {6 9 3 3} {8 10 4 5}} && [lindex $T 1] eq {2 3 4 5 6 7} && [lindex $T 2] == 8}]
set T [${M}::helm_tree {{0 1 1 2} {2 3 2 2}} {0 1 2 3} {0 0 0 0} 2]
check "  nothing trimmed: the backend's numbers" [expr {[lindex $T 0] eq {{0 1 1 2} {2 3 2 2}}}]
check "  no merge (k starting clusters): the leaves alone" [expr {[${M}::helm_tree {} {0 1 2 0} {0 1 2 0} 3] eq {{} {0 1 2} 3}}]
check "  merges that do not fit the starting clusters: refused" [string match "*do not*" [err {${M}::helm_tree {{0 1 1 2} {0 1 2 2}} {0 1 2} {0 0 1} 1}]]

# --- the plots' ticks (no Tk needed) ------------------------------------------------------
source -encoding utf-8 [file join $::root vmdance lib plotlib.tcl]
set t0 [clock microseconds]
set tk [::VMDance::Plot::nice_ticks 0.3 0.30000000000000004]
check "ticks of a span within the numbers' precision: one, at once ([expr {[clock microseconds] - $t0}] µs)" [expr {$tk eq {0.3}}]
check "  ticks of 1e-15: not all zero" [expr {[::VMDance::Plot::nice_ticks -1e-15 1e-15] eq {-1e-15 -5e-16 0.0 5e-16 1e-15}}]
check "  1.05 and 1.1 are two labels, 1.25e+06 and 1.3e+06 too" [expr {
    [lmap t {1.0 1.05 1.1 1.15} {::VMDance::Plot::_stepfmt 1.0 1.2 5 $t}] eq {1 1.05 1.1 1.15} &&
    [::VMDance::Plot::_stepfmt 1.2e6 1.4e6 5 1.25e6] eq "1.25e+06"}]

# --- a result's checks ------------------------------------------------------------------
# a small, consistent result (what Job::_result makes)
set a [dict create format 1 request {mol 0 sel {name CA} fit {} first 0 last -1 step 1 algorithm kmeans k 2 metric MSD params {kinit StratAll percentage 10}} \
    molecule {name t.pdb numatoms 3 numframes 4 files t.pdb types pdb} frames {0 1 2 3} natoms 3 \
    nclusters 2 labels {0 0 1 1} sizes {2 2} representatives {1 2} msd {0.5 0.4} ch 12.5 db 0.3 zmatrix {} initial {} \
    measures {frame_msd {0.1 0 0 0.2} silhouette {0.5 0.6 0.4 0.3} rep_msd {{0 2} {2 0}} centroid_msd {{0 1.5} {1.5 0}}} \
    extras {} backend {cli /x} seconds 0.1 created 2026-09-29T00:00:00]
check "Results::check takes a consistent result" [expr {[err {::VMDance::Results::check $a}] eq ""}]
foreach {key val why} {
    labels {0 0 1} "labels has 3 values, not 4"
    labels {0 0 1 2} "outside"
    labels {0 0 x 1} "labels holds"
    sizes {3 1} "the sizes are not those of the labels"
    representatives {1 0} "is not one of its frames"
    representatives {1 7} "outside"
    msd {0.5} "has 1 values"
    ch NaN "the scores hold"
    nclusters x "nclusters is"
    format 2 "format"
    frames {0 1 2 x} "frames holds"
    natoms 0 "natoms"
    zmatrix {{0 1 1}} "merge matrix"
    initial {0 0 -1 1} "starting clusters"
    extras {evil {[exec rm]}} "unknown extra"
} {
    check "  refused: $key \"$val\" ($why)" [string match "*$why*" [err {::VMDance::Results::check [dict replace $a $key $val]}]]
}
# (a changed copy: dict set would change a itself)
proc dset {d args} { dict set d {*}$args }
check "  refused: measures of the wrong size" [string match "*not 2 × 2*" [err {::VMDance::Results::check [dset $a measures rep_msd {{0}}]}]]
check "  refused: a request without its algorithm" [string match "*no \"algorithm\"*" [err {::VMDance::Results::check [dset $a request [dict remove [dict get $a request] algorithm]]}]]
check "  refused: bad PRIME extras" [string match "*PRIME*" [err {::VMDance::Results::check [dset $a extras prime {pairwise 9}]}]]

# publishing, runs, the selection
set ::heard {}
::VMDance::Results::listen {lappend ::heard}
set id [::VMDance::Results::publish $a]
check "publish: a run, the listeners told" [expr {$id == 1 && "analysis" in $::heard && [::VMDance::Results::nclusters] == 2}]
check "  the frame queries" [expr {[::VMDance::Results::cluster_at 2] == 1 && [::VMDance::Results::frame_index 3] == 3 &&
    [::VMDance::Results::rep_frame 1] == 2 && [::VMDance::Results::members 1] eq {2 3}}]
check "  the table" [expr {[lindex [::VMDance::Results::table] 0] eq {0 2 50.0 0.5 0.05 1}}]
check "  the frames nearest the representative" [expr {[::VMDance::Results::top 0 5] eq {1 0} && [::VMDance::Results::top 1 1] eq {2}}]
check "  a refused result changes nothing" [expr {[err {::VMDance::Results::publish [dset $a sizes {1 3}]}] ne "" && $::VMDance::Results::current == 1}]
::VMDance::Results::set_selection {1}
check "selection: set, toggle, add" [expr {[::VMDance::Results::selected] eq {1} &&
    [::VMDance::Results::set_selection {0 1} toggle] eq {0} && [::VMDance::Results::set_selection {1} add] eq {0 1}}]
check "  an unknown cluster" [string match "*no cluster \"5\"*" [err {::VMDance::Results::set_selection {5}}]]
set b [dict replace $a labels {0 1 1 1} sizes {1 3} representatives {0 2}]
::VMDance::Results::publish $b "second"
check "runs: the new one is current, the selection cleared" [expr {$::VMDance::Results::current == 2 && ![llength [::VMDance::Results::selected]]}]
::VMDance::Results::run_switch 1
check "  switching back" [expr {[::VMDance::Results::sizes] eq {2 2}}]
::VMDance::Results::run_label 1 "first"
check "  renamed" [expr {[lindex [::VMDance::Results::run_list] 0] eq {1 first}}]
::VMDance::Results::run_delete 1
check "  the current deleted: the newest left is current" [expr {$::VMDance::Results::current == 2 && [::VMDance::Results::sizes] eq {1 3}}]
::VMDance::Results::attach prime {pairwise 1 union 1 medoid 2 outlier 3 medoidAll 0 medoidC0 1 medoidC0Trimmed 1 params {metric RR trim-frac 0.1 weighted 1}}
check "attach: kept with its run" [expr {[dict get [::VMDance::Results::extra prime] medoid] == 2 &&
    [dict get [lindex [::VMDance::Results::run_data] 0 2] extras prime medoid] == 2}]
check "  refused when inconsistent" [expr {[err {::VMDance::Results::attach prime {pairwise 9}}] ne ""}]
::VMDance::Results::publish $a "third"
set p3 {pairwise 1 union 1 medoid 3 outlier 3 medoidAll 0 medoidC0 1 medoidC0Trimmed 1 params {metric RR trim-frac 0.1 weighted 1}}
::VMDance::Results::attach prime $p3 2
check "attach to a run that is not current: kept with it, not the current one's" [expr {
    [dict get [lindex [::VMDance::Results::run_data] 0 2] extras prime medoid] == 3 && ![dict size [::VMDance::Results::extra prime]]}]
::VMDance::Results::run_delete $::VMDance::Results::current

# --- sessions ---------------------------------------------------------------------------
set sf [file join $::out core.vmdance]
::VMDance::Session::save $sf
check "a session is gzip-compressed" [expr {[string range [read [set fh [open $sf rb]]] 0 1] eq "\x1f\x8b"}]
close $fh
set d [::VMDance::Session::read_file $sf]
check "  and reads back" [expr {[llength [dict get $d runs]] == 1 && [dict get $d current] == 2}]
proc write_session {f body {magic "VMDanceSession 1"}} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "$magic\n$body\n"]]
    close $fh
}
set good [dict get $d runs]
foreach {name body magic why} [list \
        magic {} "SomethingElse 1" "not a VMDance session" \
        future {} "VMDanceSession 9" "session format 9" \
        notdict "\{runs" "VMDanceSession 1" "not a dictionary" \
        incomplete {runs {} current 1} "VMDanceSession 1" "incomplete" \
        noruns {runs {} current 1 selection {} elbow {} sweep {} picks {} gui {}} "VMDanceSession 1" "no run" \
        badrun [list runs [list [list 1 x [dict replace $a sizes {9 9}]]] current 1 selection {} elbow {} sweep {} picks {} gui {}] "VMDanceSession 1" "sizes" \
        current [list runs $good current 7 selection {} elbow {} sweep {} picks {} gui {}] "VMDanceSession 1" "current run" \
        evil [list runs $good current 2 selection {[exec touch [file join $::out pwned]]} elbow {} sweep {} picks {} gui {}] "VMDanceSession 1" "selection" \
        scan [list runs $good current 2 selection {} elbow {kind elbow} sweep {} picks {} gui {}] "VMDanceSession 1" "elbow"] {
    set f [file join $::out $name.vmdance]
    write_session $f $body $magic
    check "  refused: $name ($why)" [string match "*$why*" [err {::VMDance::Session::read_file $f}]]
}
check "  nothing was evaluated" [expr {![file exists [file join $::out pwned]]}]
set f [file join $::out text.vmdance]
set fh [open $f w]; puts $fh "not gzip at all"; close $fh
check "  refused: plain text" [string match "*not a VMDance session*" [err {::VMDance::Session::read_file $f}]]
set fh [open $f wb]; puts -nonewline $fh "\x1f\x8b\x08\x00garbage"; close $fh
check "  refused: bad gzip" [string match "*corrupt*" [err {::VMDance::Session::read_file $f}]]
# (MDANCEView was the plugin's name before VMDance: its sessions and
# preferences are read too)
set f [file join $::out old_name.mdvsession]
write_session $f [list runs $good current 2 selection {} elbow {} sweep {} picks {} gui {}] "MDANCEViewSession 1"
check "  a session saved by MDANCEView reads" [expr {![catch {::VMDance::Session::read_file $f} d2] && [dict get $d2 current] == 2}]
set pd [file join $::out prefs_home]
file delete -force $pd; file mkdir $pd
set keep $::VMDance::Prefs::file
set ::VMDance::Prefs::file [file join $pd .vmdance.prefs]
set fh [open [file join $pd .mdanceview.prefs] w]; puts $fh "# MDANCEView preferences\nui_font 15"; close $fh
check "preferences: MDANCEView's are read while VMDance has none" [expr {[dict get [::VMDance::Prefs::load] ui_font] == 15}]
::VMDance::Prefs::save [dict replace [::VMDance::Prefs::load] ui_font 11]
check "  saved as VMDance's, which are read from then on" [expr {[file isfile [file join $pd .vmdance.prefs]] && [dict get [::VMDance::Prefs::load] ui_font] == 11}]
set ::VMDance::Prefs::file $keep
done
} err]} { puts "FAIL test_core crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
if {[info commands quit] ne ""} { quit }
