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
    # the elbow scan, with the stability of NANI's four seedings
    set t0 [clock milliseconds]
    set rec [vmdance elbow -mol $m -sel backbone -kinit CompSim -from 2 -to 12 -stability 1 -quiet 1]
    keep elbow_seconds [format %.0f [expr {([clock milliseconds] - $t0) / 1000.0}]] "the elbow scan with the stability, k 2-12"
    foreach r $rec {
        set k [dict get $r k]
        keep elbow_k$k "[format %.0f [dict get $r ch]] [format %.3f [dict get $r db]] [dict get $r stability]" "k $k: Calinski-Harabasz, Davies-Bouldin, stability"
    }
    # the clustering at k 3, the stable one
    vmdance elbow load 3
    set sz [::VMDance::Results::sizes]
    keep k3_sizes [join $sz " "] "k 3: the clusters' frames"
    keep k3_silhouette [format %.2f [dict get [vmdance silhouette] mean]] "k 3: the mean silhouette"
    foreach r [vmdance residence] { keep residence_c[lindex $r 0] [format %.1f [lindex $r 2]] "cluster [lindex $r 0]: its mean stay (frames)" }
    # the two halves of the trajectory as groups
    vmdance groups -ranges {first 0-2999 second 3000-6000}
    set mk [vmdance makeup]
    dict for {c row} $mk {
        lassign $row a b
        keep halves_c$c "$a $b" "cluster $c: frames of the first and the second half"
    }
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
    # eQUAL's radius
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
