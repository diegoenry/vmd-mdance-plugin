# The tutorial's numbers (docs/tutorial.rst): its steps run with the
# command on MDANCE's example, the tau peptide that MDANCE's Python package
# ships (mdance/data: aligned_tau.pdb and aligned_original_tau_6K.dcd).
# Writes docs/_static/data/tutorial_numbers.txt (key, value, what it is).
#   cd <VMDance>
#   MDANCE_DATA=<mdance>/data vmd -dispdev text -e docs/tools/tutorial_numbers.tcl < /dev/null
set root [pwd]
lappend auto_path [file join $root vmdance]
package require vmdance
set ::VMDance::Prefs::file ""
set data [expr {[info exists env(MDANCE_DATA)] ? $env(MDANCE_DATA) : [file join $root .. MDANCE src mdance data]}]
set out [file join $root docs _static data]
file mkdir $out
set rows {}
proc keep {key value what} { lappend ::rows [list $key $value $what]; puts [format "%-24s %-14s %s" $key $value $what] }

if {[catch {
    set m [mol new [file join $data aligned_tau.pdb] waitfor all]
    mol addfile [file join $data aligned_original_tau_6K.dcd] waitfor all molid $m
    animate delete beg 0 end 0 $m
    keep frames [molinfo $m get numframes] "the frames clustered (the DCD's)"
    set n [[atomselect $m backbone] num]
    keep atoms $n "the backbone's atoms"
    # whether the frames look superposed (the note under Setup's Fit box)
    set al [vmdance alignment -mol $m -sel backbone]
    keep alignment "[dict get $al as_is] [dict get $al fitted] [dict get $al superposed]" "the frames from the first: Å as they are, Å fitted, superposed (1) or not"
    # the elbow scan, with the stability of NANI's four seedings
    set t0 [clock milliseconds]
    set rec [vmdance elbow -mol $m -sel backbone -kinit CompSim -from 2 -to 12 -stability 1 -quiet 1]
    keep elbow_seconds [format %.0f [expr {([clock milliseconds] - $t0) / 1000.0}]] "the elbow scan with the stability, k 2-12"
    foreach r $rec {
        set k [dict get $r k]
        keep elbow_k$k "[format %.0f [dict get $r ch]] [format %.3f [dict get $r db]] [dict get $r stability]" "k $k: Calinski-Harabasz, Davies-Bouldin, stability"
        keep explained_k$k [format %.0f [expr {100 * [::VMDance::Results::explained $r]}]] "k $k: % of the variance the clusters explain"
    }
    # what the scan points to
    set sg [vmdance elbow suggest]
    foreach key {db_lowest db_dip ch_highest stable most_stable} { keep suggest_$key [dict get $sg $key] "elbow suggest: $key" }
    # the clustering at k 3, the stable one
    vmdance elbow load 3
    set sz [::VMDance::Results::sizes]
    keep k3_sizes [join $sz " "] "k 3: the clusters' frames"
    keep k3_silhouette [format %.2f [dict get [vmdance silhouette] mean]] "k 3: the mean silhouette (from the clusters' mean structures)"
    set sp [vmdance silhouette -kind pairs]
    set neg 0
    foreach v [dict values [dict get $sp frames]] { if {$v < 0} { incr neg } }
    keep k3_silhouette_pairs "[format %.2f [dict get $sp mean]] $neg" "k 3: the mean silhouette from every frame, and the frames below 0"
    foreach r [vmdance residence] {
        keep residence_c[lindex $r 0] [format %.1f [lindex $r 2]] "cluster [lindex $r 0]: its mean stay (frames)"
        keep longest_c[lindex $r 0] [lindex $r 4] "cluster [lindex $r 0]: its longest stay (frames)"
    }
    keep all_seen_by [::tcl::mathfunc::max {*}[dict values [dict get [vmdance timeline] first_seen]]] "the frame by which every cluster has been seen"
    # the two halves of the trajectory as groups
    vmdance groups -ranges {first 0-2999 second 3000-6000}
    set mk [vmdance makeup]
    dict for {c row} $mk {
        lassign $row a b
        keep halves_c$c "$a $b" "cluster $c: frames of the first and the second half"
    }
    set cmp [lindex [dict get [vmdance groups compare] pairs] 0]
    keep halves_divergence "[format %.3f [lindex $cmp 2]] [lindex $cmp 4] [format %.3f [lindex $cmp 3]]" "the halves: their divergence, the cluster whose share differs most, by how much"
    set mp [vmdance map]
    lassign [dict get $mp variance] v1 v2
    keep map_variance "[format %.0f [expr {100 * $v1}]] [format %.0f [expr {100 * $v2}]]" "the map's two axes: % of the variance"
    set pf [vmdance profiles]
    keep profiles_reference [dict get $pf reference] "the profiles' reference: the most populated cluster"
    # HELM, and its merges' heights
    vmdance -mol $m -sel backbone -algorithm helm -k 3 -initial 60 -quiet 1
    set hs [dict get [vmdance tree] heights]
    keep helm_merges [llength $hs] "HELM's merges, from its starting clusters to 3"
    set last [lrange $hs end-7 end]
    keep helm_last_heights [join [lmap h $last {format %.3g $h}] " "] "the last eight merges' heights (k 11 to 4)"
    # eQUAL's radius: a range from the frames, and the clusters at five radii
    set rd [vmdance radii -mol $m -sel backbone]
    keep radii_suggested "[dict get $rd from] [dict get $rd to] [dict get $rd by] [dict get $rd sample]" "vmdance radii: from, to, by, and the frames sampled"
    set radii {4 6 8 10 12}
    set rr [vmdance elbow -mol $m -sel backbone -algorithm equal -radii $radii -quiet 1]
    keep equal_radii [join [lmap r $rr {dict get $r nclusters}] " "] "eQUAL's clusters at radius [join $radii {, }]"
} err]} { puts "ERROR $err\n$::errorInfo" }
set fh [open [file join $out tutorial_numbers.txt] w]
puts $fh "# The numbers of docs/tutorial.rst, made by docs/tools/tutorial_numbers.tcl."
foreach r $rows { puts $fh [join $r "\t"] }
close $fh
::VMDance::Backend::cleanup
quit
