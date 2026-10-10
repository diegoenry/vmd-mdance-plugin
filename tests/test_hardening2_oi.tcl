# What the second round of reviews found in the import of the MDANCE
# plugin's sessions (.mdance), each kept from coming back (text mode, the
# fake backend; the real one, when it is there, runs an imported request
# again; the window's import is test_gui's):
#   N19  a session is counted before its lists are made, against the frames
#        of the molecules it can be put on (a million labels cost seconds and
#        gigabytes before the molecule was looked for; merges too), a long
#        selection allowed for
#   N07  a HELM run started from a label file names the file (it was said
#        to start from a first clustering of 50, which a run then refused,
#        or made another clustering)
#   N08  HELM's merges that cannot be placed without the starting clusters
#        (a trimmed run's; the merge -eps refused, which an mdance-cli of
#        before CPP-MDANCE 4042c24 kept, or a last merge that may be it)
#        are left out, the tree the linkage: the clustering is imported (it
#        was refused whole, or a merge that never happened drawn); merges
#        are HELM's only
#   N11  a molecule of its name with frames added is taken when its
#        coordinates give the file's cluster MSDs (only the recorded number
#        of frames was); the message says what is loaded
#   N18  its number of clusters as the MDANCE plugin read it: a zero-padded
#        one by the clusters found (its library read 010 as 8, mdance-cli
#        as 10), +10 taken; NaN metric said as a metric
#   N20  a configuration of its sweep (no inputParams): the run says its
#        metric and parameters are not recorded, where MSD and the defaults
#        were shown as what was run; sessions keep it, and check it
# and what the review of those fixes found (R1-R4):
#   R1   the count sees \v and \f, which Tcl's lists split on too (a file of
#        labels so separated was parsed whole again: 390 MB, a second)
#   R2   HELM stopped by -eps whose rows and k make all of pre-k: also those
#        of one starting cluster fewer (NANI left it empty) and the merge -eps
#        refused, which was drawn (old_helm_eps_empty.mdance, written by the
#        plugin with the mdance-cli before 4042c24); frames in no cluster
#        without a trimming not said to be trimmed
#   R3   a long selection (an index list) counted apart from the clustering,
#        and bounded on its own (it was refused as "its molecule is not
#        loaded"; VMD fails on one of a few hundred thousand words)
#   R4   the other zero-padded numbers as the plugin took them (pre-k 06,
#        percentage 010 were refused, naming -initial for pre-k)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_oi.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_oi]
file delete -force $H
file mkdir $H

proc rss_mb {} {
    if {[catch {open /proc/self/status} fh]} { return -1 }
    set t [read $fh]; close $fh
    if {[regexp {VmHWM:\s+(\d+)} $t -> h]} { return [expr {$h / 1024}] }
    return -1
}
proc write_text {f t} {
    set fh [open $f w]
    puts $fh $t
    close $fh
    return $f
}
proc write_session {f d} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "VMDanceSession 1\n$d\n"] -level 9]
    close $fh
}
# An MDANCE plugin session as data with its results changed (key value ...).
proc old_with {f args} {
    set t [read_text $f]
    set r [dict get $t results]
    foreach {k v} $args { dict set r $k $v }
    dict replace $t results $r
}
# Import a session as the command does, without publishing: {result
# warnings ?refused?}, or {} when it fails.
proc import_job {f {mol auto}} {
    if {[catch {::VMDance::Job::run import [::VMDance::import_request $f $mol]} r]} { return {} }
    return $r
}
# The command's options of a request's parameters.
proc opts_of {p} {
    set o {}
    dict for {k v} $p { lappend o -$k $v }
    return $o
}

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
set of [file join $::fixtures old_kmeans.mdance]

# N19: counted before anything is made of it, against the frames loaded
# (first: the high-water mark of the memory is still VMD's own)
set m [load_system two_state]
set big [file join $H many.mdance]
set fh [open $big w]
puts -nonewline $fh "mdanceSession 1 molSignature {molKnown 1 molName two_state.pdb molFrames 24} results {algorithm kmeans nClusters 2 representatives {0 1} atomsel all labels {"
puts -nonewline $fh [string repeat "0 " 1000000]
puts $fh "}}"
close $fh
set hwm [rss_mb]
set e1 [err {::VMDance::Session::read_old $big}]
set e2 [err {vmdance session import $big}]
set e3 [err {vmdance session import $big -mol $m}]
set grew [expr {[rss_mb] - $hwm}]
check "N19: a million labels, its molecule's 24 frames loaded: refused before its lists are made (+$grew MB; it read them all, 400 MB, then looked)" [expr {
    [string match "*holds 1000* values, more than a clustering of the frames loaded can*not loaded" $e1] &&
    [string match "*not loaded: load it, or give its id (-mol)" $e2] &&
    [string match "*molecule $m has 24 frames, too few for*" $e3] && $grew < 100}]
# R1: separated by \v or \f, which Tcl's lists split on too
set hwm [rss_mb]
set es {}
foreach {name sep} [list vt \v ff \f] {
    set f [file join $H many_$name.mdance]
    set fh [open $f w]
    puts -nonewline $fh "mdanceSession 1 molSignature {molKnown 1 molName two_state.pdb molFrames 24} results {algorithm kmeans nClusters 2 representatives {0 1} atomsel all labels {"
    puts -nonewline $fh [string repeat "0$sep" 1000000]
    puts $fh "}}"
    close $fh
    lappend es [err {::VMDance::Session::read_old $f}]
}
set grew [expr {[rss_mb] - $hwm}]
check "R1: a million labels separated by \\v, or by \\f: refused before its lists are made (+$grew MB; parsed whole, 390 MB, then refused as not loaded)" [expr {
    [llength [lsearch -all -glob $es "*holds 1000* values, more than a clustering of the frames loaded can*"]] == 2 && $grew < 100 &&
    [::VMDance::Session::_values "0\v1\f2 3\t4\n5\r6"] == 6}]
set t [read_text [file join $::fixtures old_helm.mdance]]
set bulk [write_text [file join $H merges.mdance] [dict replace $t results [dict replace [dict get $t results] zMatrix [lrepeat 200000 {0 1 1 2}]]]]
check "  the frames fit, its merges 200 000 rows: refused before the job runs (the job ran, then publish refused)" [string match "*holds * values*" [err {::VMDance::Session::read_old $bulk}]]
check "  a session of its size imported as before" [expr {![catch {vmdance session import $of}] && [${R}::labels] eq [dict get [read_text $of] results labels]}]
set f [write_text [file join $H index_sel.mdance] [old_with $of atomsel "all or index [string trim [string repeat {0 } 3000]]"]]
check "  its selection an index list of 3000 words (8 frames clustered): imported, not counted as a clustering's" [expr {![catch {vmdance session import $f}]}]
# R3: a long selection, as the plugin writes it (in results and inputParams),
# counted apart from the clustering, and bounded on its own
set sel "all or index [string trim [string repeat {0 } 120000]]"
set t [old_with $of atomsel $sel]
dict set t results inputParams atomsel $sel
set f [write_text [file join $H long_sel.mdance] $t]
set e1 [err {vmdance session import $f}]
set s1 [::VMDance::_get [vmdance info] sel ""]
set e2 [err {vmdance session import $f -mol $m}]
check "R3: its selection an index list of 120 000 words: imported, with and without -mol, whole (refused: its molecule is not loaded, molecule $m too few frames)" [expr {
    $e1 eq "" && $s1 eq $sel && $e2 eq "" && [${R}::labels] eq [dict get [read_text $of] results labels]}]
set long "all or index [string trim [string repeat {0 } 250000]]"
set e1 [err {vmdance session import [write_text [file join $H longer_sel.mdance] [old_with $of atomsel $long]]}]
# (in quotes, which the plugin never writes: not seen by the count, but
# once read; with a molecule of a million frames, it was given to VMD)
set body [info body ::VMDance::Session::_old_most]
proc ::VMDance::Session::_old_most {mol} { list 1000000 "" }
set f [write_text [file join $H quoted_sel.mdance] [string map [list "atomsel all frames" "atomsel \"$long\" frames"] [read_text $of]]]
set e2 [err {::VMDance::Session::read_old $f}]
proc ::VMDance::Session::_old_most {mol} $body
check "  one of 250 000 words: refused, the message names the selection (\"not loaded\"; VMD fails on a few hundred thousand)" [expr {
    [string match "*: its selection is longer than an import takes (more than 200000 words)" $e1] &&
    [string match "*: its selection is longer than an import takes (more than 200000 words)" $e2]}]

# N07: HELM started from a label file (old_helm_labels.mdance, written by
# the plugin's HELM tab from a file named as typed)
set lf [file join $::fixtures old_helm_labels.mdance]
set i [vmdance session import $lf]
check "N07: HELM from a label file: the request names the file (it said a first clustering of 50)" [expr {
    [dict get $i params initial-labels] eq "tests/fixtures/old_helm_labels.txt" &&
    [${R}::labels] eq [dict get [read_text $lf] results labels]}]
check "  the exports' header names it" [string match "*initial-labels tests/fixtures/old_helm_labels.txt*" [::VMDance::Export::header]]
set abs [file join $::fixtures old_helm_labels.txt]
write_text [file join $H labels_abs.mdance] [string map [list tests/fixtures/old_helm_labels.txt $abs] [read_text $lf]]
vmdance session import [file join $H labels_abs.mdance]
set p [dict get [vmdance info] params]
set e [err {vmdance -mol $m -sel all -algorithm helm -k 2 {*}[opts_of $p] -quiet 1}]
check "  its request run again: from the file (refused: -initial 50 for 24 frames)" [expr {$e eq "" && [dict get [vmdance info] params initial-labels] eq $abs}]
if {[real_cli] ne ""} {
    use_cli
    set e [err {vmdance -mol $m -sel all -algorithm helm -k 2 {*}[opts_of $p] -quiet 1}]
    use_fake
    check "  with mdance-cli: the MDANCE plugin's labels again" [expr {$e eq "" && [${R}::labels] eq [dict get [read_text $lf] results labels]}]
} else {
    skip "  with mdance-cli: the MDANCE plugin's labels again" "no mdance-cli"
}
write_text [file join $H labels_gone.mdance] [string map [list tests/fixtures/old_helm_labels.txt [file join $H gone.txt]] [read_text $lf]]
set ok1 [expr {![catch {vmdance session import [file join $H labels_gone.mdance]}]}]
set p [dict get [vmdance info] params]
check "  its file gone: imported all the same, and a run of its request says the file cannot be read" [expr {$ok1 &&
    [string match "*-initial-labels: cannot read*" [err {vmdance -mol $m -sel all -algorithm helm -k 2 {*}[opts_of $p] -quiet 1}]]}]

# N08: HELM's merges the file cannot place
set tf [file join $::fixtures old_helm_trim.mdance]
set r [import_job $tf]
set e [err {vmdance session import $tf}]
check "N08: a trimmed HELM run: imported, its merges left out, said (refused whole: they do not fit)" [expr {$e eq "" &&
    [${R}::labels] eq [dict get [read_text $tf] results labels] && [dict get [vmdance tree] kind] eq "linkage" &&
    [string match "*merges left out*trimmed*" [::VMDance::_get $r warnings ""]]}]
set ef [file join $::fixtures old_helm_eps.mdance]
set z [dict get [read_text $ef] results zMatrix]
set r [import_job $ef]
set e [err {vmdance session import $ef}]
check "  HELM stopped by -eps, by an mdance-cli before 4042c24: the merge -eps refused (its last) left out, said (refused whole)" [expr {$e eq "" &&
    [dict get [vmdance tree] kind] eq "helm" && [dict get [vmdance tree] merges] eq [lrange $z 0 end-1] &&
    [string match "*last merge left out*-eps*" [::VMDance::_get $r warnings ""]]}]
vmdance session import [write_text [file join $H eps_now.mdance] [old_with $ef zMatrix [lrange $z 0 end-1]]]
check "  the same as mdance-cli writes it now: every merge kept" [expr {[dict get [vmdance tree] merges] eq [lrange $z 0 end-1]}]
check "  started from a label file (how many starting clusters not said): the reading that fits taken" [expr {
    ![catch {::VMDance::Session::old_merges [dict create zmatrix $z nclusters 3 labels {0 1 2}] {eps 0.1} ""} zw] &&
    [lindex $zw 0] eq [lrange $z 0 end-1] && [string match "*last merge left out*" [lindex $zw 1]]}]
# (a merge of two starting clusters into 2 clusters: 3 starting ones, or 2
# and the merge -eps refused)
set hf [file join $::fixtures old_helm.mdance]
set ip [dict replace [dict get [read_text $hf] results inputParams] nclusters 0 eps 0.1 pre-k 8]
set r [import_job [write_text [file join $H eps_either.mdance] [old_with $hf zMatrix {{0 1 1 2}} inputParams $ip]]]
set ok1 [expr {[::VMDance::_get $r result ""] ne "" && ![llength [dict get $r result zmatrix]] && [string match "*cannot be told*" [dict get $r warnings]]}]
set r [import_job [write_text [file join $H eps_all.mdance] [old_with $hf zMatrix {{0 1 1 2}} inputParams [dict replace $ip pre-k 3]]]]
# (R2: 3 asked is all of them, or 2, NANI having left one empty, and the
# merge -eps refused; 2 asked, the row is the refused merge)
set ok2 [expr {[::VMDance::_get $r result ""] ne "" && ![llength [dict get $r result zmatrix]] && [string match "*cannot be told*" [dict get $r warnings]]}]
set r [import_job [write_text [file join $H eps_two.mdance] [old_with $hf zMatrix {{0 1 1 2}} inputParams [dict replace $ip pre-k 02]]]]
check "  stopped by -eps, its one merge either way (8 starting clusters asked, NANI can leave some empty): left out, said (drawn); R2: 3 asked: left out too (kept); 02 asked: it is the refused one" [expr {
    $ok1 && $ok2 && [::VMDance::_get $r result ""] ne "" && ![llength [dict get $r result zmatrix]] && [string match "*last merge left out*-eps*" [dict get $r warnings]]}]
vmdance session import [write_text [file join $H km_merges.mdance] [old_with $of zMatrix {{0 1 1 2}}]]
check "  merges in a KMeans session: left out (drawn as HELM's tree)" [expr {[dict get [vmdance tree] kind] eq "linkage"}]
# R2: written by the plugin with an mdance-cli before 4042c24, of the
# trajectory read twice: NANI left one of the 25 starting clusters empty,
# and -eps refused the first merge (24 clusters, one row, no merge made)
set m2 [load_system two_state]
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m2
set xf [file join $::fixtures old_helm_eps_empty.mdance]
set r [import_job $xf]
set e [err {vmdance session import $xf}]
check "R2: HELM stopped by -eps, its one row the merge -eps refused, a starting cluster empty: left out, said (drawn, a tree of 25)" [expr {$e eq "" &&
    [dict get [vmdance tree] kind] eq "linkage" && [${R}::labels] eq [dict get [read_text $xf] results labels] &&
    [string match "*cannot be told*" [::VMDance::_get $r warnings ""]]}]
mol delete $m2
set cl [dict create zmatrix {{0 1 1 2}} nclusters 2 labels {0 -1 1}]
check "  frames in no cluster, nothing trimmed (that mdance-cli's, when NANI left starting clusters empty): left out, not said trimmed" [expr {
    [string match "*those of its frames in no cluster (-1) too*" [lindex [::VMDance::Session::old_merges $cl {eps 0.01 trim-start 0} ""] 1]] &&
    [string match "*the trimmed ones too*" [lindex [::VMDance::Session::old_merges $cl {eps -1 trim-start 1} ""] 1]]}]

# N11: frames added after the clustered ones
foreach x [molinfo list] { mol delete $x }
set m [load_system two_state]
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
set r [import_job $of]
check "N11: its molecule with frames added (48): taken, its coordinates checked, said (refused: \"not loaded\")" [expr {
    [::VMDance::_get $r result ""] ne "" && [dict get $r result request mol] == $m && [string match "*has 48 frames, the MDANCE plugin's 24*" [dict get $r warnings]]}]
set e [err {vmdance session import $of}]
set nomsd [write_text [file join $H nomsd.mdance] [dict replace [read_text $of] results [dict remove [dict get [read_text $of] results] clusterMSD]]]
check "  a file with nothing to compare: not taken for its name alone" [string match "*cannot be told*: give its id (-mol)" [err {vmdance session import $nomsd}]]
set m2 [load_system two_state]
check "  ... the one of its name and frames is, with the other loaded too" [expr {$e eq "" && ![catch {vmdance session import $nomsd} i] && [dict get $i molid] == $m2}]
mol delete $m2
animate delete beg 0 end 0 $m
check "  its frames shifted (the first deleted): refused, not taken by name" [string match "*no molecule loaded has the coordinates it clustered*load its molecule, or give its id (-mol)" [err {vmdance session import $of}]]
animate delete beg 12 end -1 $m
check "  a molecule of its name with too few frames: the message names it" [string match \
    "*its molecule (two_state.pdb, 24 frames) is not loaded (molecule $m has 12 frames: it clustered frames up to 18): load it, or give its id (-mol)" \
    [err {vmdance session import $of}]]
foreach x [molinfo list] { mol delete $x }

# N18: the number of clusters as the MDANCE plugin read it
set m [load_system two_state]
set r0 [dict get [read_text $of] results]
# (8 clusters of a frame each: nothing to compare, the molecule of its name and frames taken)
set one [dict create labels {0 1 2 3 4 5 6 7} clusterSizes {1 1 1 1 1 1 1 1} representatives {0 1 2 3 4 5 6 7} clusterMSD {0 0 0 0 0 0 0 0} nClusters 8]
set f [write_text [file join $H k010lib.mdance] [old_with $of {*}$one inputParams [dict replace [dict get $r0 inputParams] nclusters 010]]]
check "N18: k 010 that found 8 clusters (the library read it as 8): k 8 (10)" [expr {[dict get [vmdance session import $f] k] == 8}]
set ten [dict create labels [lmap i [lrange {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23} 0 end] {expr {$i % 10}}] \
    clusterSizes {3 3 3 3 2 2 2 2 2 2} representatives {0 1 2 3 4 5 6 7 8 9} nClusters 10 frames {0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23}]
set rt [dict remove [dict merge $r0 $ten] clusterMSD]
set t [read_text $of]
set f [write_text [file join $H k010cli.mdance] [dict replace $t results [dict replace $rt inputParams [dict replace [dict get $r0 inputParams] nclusters 010]]]]
check "  k 010 that found 10 (mdance-cli read it as 10): k 10" [expr {[dict get [vmdance session import $f] k] == 10}]
set f [write_text [file join $H kplus.mdance] [dict replace $t results [dict replace $rt inputParams [dict replace [dict get $r0 inputParams] nclusters +10]]]]
check "  k +10 (taken by the plugin and both its backends): k 10 (refused)" [expr {![catch {vmdance session import $f} i] && [dict get $i k] == 10}]
set f [write_text [file join $H metric.mdance] [old_with $of inputParams [dict replace [dict get $r0 inputParams] metric NaN]]]
check "  a metric NaN: refused as a metric (domain error)" [string match "*-metric must be one of*" [err {vmdance session import $f}]]
# R4: its other numbers as the plugin took them (string is integer, string
# is double): zero-padded, as mdance-cli read them
set f [write_text [file join $H pct010.mdance] [old_with $of inputParams [dict replace [dict get $r0 inputParams] percentage 010]]]
set r [import_job $f]
set e [err {vmdance session import $f}]
check "R4: percentage 010: 10, as mdance-cli read it, its library's 8 said (refused: -percentage must be a whole number)" [expr {$e eq "" &&
    [dict get [vmdance info] params percentage] == 10 &&
    [string match "*its percentage, \"010\", is 10 to mdance-cli and 8 to its library*taken as 10*" [::VMDance::_get $r warnings ""]]}]
set hf [file join $::fixtures old_helm.mdance]
set hp [dict get [read_text $hf] results inputParams]
set r [import_job [write_text [file join $H prek06.mdance] [old_with $hf inputParams [dict replace $hp pre-k 06]]]]
set e [err {vmdance session import [write_text [file join $H prekabc.mdance] [old_with $hf inputParams [dict replace $hp pre-k abc]]]}]
check "  HELM's pre-k 06: 6, nothing said (refused, naming -initial); one that is no number named as the file names it" [expr {
    [::VMDance::_get $r result ""] ne "" && [dict get $r result request params initial] == 6 && ![llength [dict get $r warnings]] &&
    [string match "*: its pre-k must be a whole number (got \"abc\")" $e]}]

# N20: a configuration of the plugin's sweep, loaded with Load Selected
set sf [file join $::fixtures old_sweep.mdance]
set r [import_job $sf]
set i [vmdance session import $sf]
set head [::VMDance::Export::header]
check "N20: a sweep's configuration (no inputParams): the run says its metric and parameters are not recorded (MSD, StratAll and 10% shown as run)" [expr {
    [::VMDance::_get $i unrecorded ""] eq {metric params} && [string match "*(imported; parameters not recorded)" [lindex [vmdance runs] end 1]] &&
    [string match "*metric and parameters not recorded*" $head] && ![string match "*kinit*" $head] &&
    [string match "*does not record its metric and parameters*" [::VMDance::_get $r warnings ""]] &&
    [${R}::labels] eq [dict get [read_text $sf] results labels]}]
set ss [file join $H sweep.vmdance]
vmdance session save $ss
vmdance run clear
vmdance session load $ss
check "  kept by a session" [expr {[::VMDance::_get [vmdance info] unrecorded ""] eq {metric params}}]
set d [::VMDance::Session::read_file $ss]
set runs [dict get $d runs]
set a [lindex $runs end 2]
dict set a unrecorded {metric {[exec touch pwned]}}
lset runs end 2 $a
dict set d runs $runs
write_session [file join $H bad.vmdance] $d
check "  a session whose run says another thing not recorded: refused, nothing evaluated" [expr {
    [string match "*unrecorded is corrupt*" [err {vmdance session load [file join $H bad.vmdance]}]] && ![file exists pwned]}]
check "  an import that records them: none said" [expr {[::VMDance::_get [vmdance session import $of] unrecorded x] eq ""}]

foreach x [molinfo list] { mol delete $x }
vmdance run clear
done

} err]} { puts "FAIL test_hardening2_oi crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
