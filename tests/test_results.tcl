# The command's questions, the runs, the 3D window and the files, with
# the fake backend.
#   cd <VMDance>; vmd -dispdev text -e tests/test_results.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set m [load_system two_state]
set o [load_system outlier]

check "no clustering: the questions say so" [expr {[string match "*no clustering*" [err {vmdance clusters}]] &&
    [vmdance info] eq "" && [string match "*no clustering*" [err {vmdance get 0}]]}]
check "an unknown subcommand names the valid ones" [string match "*unknown subcommand \"clusterz\" (valid: help, info*" [err {vmdance clusterz}]]
set al [vmdance algorithms]
check "algorithms: labels, defaults, availability" [expr {[dict get $al kmeans label] eq "KMeans NANI" && [dict get $al equal k] == 0 && [dict get $al divine available]}]
check "parameters: the catalog" [expr {[lindex [dict get [vmdance parameters helm] -merge-scheme] 1] eq "Intra" &&
    [dict exists [vmdance parameters prime] -trim-frac] && [string match "*no algorithm*" [err {vmdance parameters xyz}]]}]
set b [vmdance backend]
check "backend: which is used" [expr {[lindex [dict get $b using] 0] eq "cli" && [dict get $b error] eq ""}]

set i [vmdance -mol $m -sel all -k 2 -label "two states" -quiet 1]
check "info: the clustering" [expr {[dict get $i run] == 1 && [dict get $i frames] == 24 && [dict get $i natoms] == 8 && [dict get $i sizes] eq {12 12}}]
check "  the label given" [expr {[lindex [vmdance runs] 0 1] eq "two states"}]
set cl [vmdance clusters]
check "clusters: {cluster frames percent msd spread representative}" [expr {[llength $cl] == 2 && [lrange [lindex $cl 0] 0 2] eq {0 12 50.0}}]
check "  sorted by size" [expr {[llength [vmdance clusters -sort size]] == 2 && [string match "*-sort must be*" [err {vmdance clusters -sort x}]]}]
set g [vmdance get 1]
check "get: a cluster in full" [expr {[dict get $g frames] == 12 && [llength [dict get $g members]] == 12 && [dict get $g visits] == 1 &&
    [dict get $g longest_residence] == 12 && [dict get $g vmd_colour] == 1}]
check "  no cluster 2" [string match "*no cluster \"2\" (clusters: 0 to 1)*" [err {vmdance get 2}]]
check "labels: frame cluster pairs" [expr {[llength [vmdance labels]] == 48}]
check "frame: the cluster of a VMD frame" [expr {[dict get [vmdance frame 13] cluster] == 1}]
check "  outside" [string match "*outside the clustered frames*" [err {vmdance frame 99}]]
set T [vmdance transitions]
check "transitions: rows sum to 1" [expr {[near [::tcl::mathop::+ {*}[lindex $T 0]] 1.0] && [near [::tcl::mathop::+ {*}[lindex $T 1]] 1.0]}]
check "  counts, lag 5" [expr {[::tcl::mathop::+ {*}[concat {*}[vmdance transitions -counts 1 -lag 5]]] == 19}]
check "residence" [expr {[vmdance residence] eq {{0 1 12.00 12 12} {1 1 12.00 12 12}}}]
set s [vmdance silhouette]
check "silhouette: mean, per cluster, per frame" [expr {[dict get $s mean] > 0.8 && [dict size [dict get $s clusters]] == 2 && [llength [dict get $s frames]] == 48}]
set d [vmdance distances]
check "distances: k × k, zero on the diagonal" [expr {[lindex [dict get $d centroids] 0 0] == 0 && [lindex [dict get $d representatives] 1 0] > 0}]
check "tree: average linkage of the mean structures" [expr {[dict get [vmdance tree] kind] eq "linkage" && [llength [dict get [vmdance tree] merges]] == 1 &&
    [dict get [vmdance tree] leaves] eq {0 1}}]
set tb1 [${R}::table]; set rs1 [vmdance residence]

# --- the selection ------------------------------------------------------------------------
check "select: set, add, toggle, all, clear" [expr {[vmdance select 1] eq {1} && [vmdance select add 0] eq {0 1} &&
    [vmdance select toggle 1] eq {0} && [vmdance select all] eq {0 1} && [vmdance select clear] eq {}}]
check "  an unknown cluster" [string match "*no cluster*" [err {vmdance select 7}]]

# --- runs -----------------------------------------------------------------------------------
vmdance -mol $o -sel all -algorithm equal -threshold 1.0 -quiet 1
check "runs: kept, the new one current" [expr {[llength [vmdance runs]] == 2 && [lindex [vmdance runs] 1 2] == 1}]
check "  what was made from the last clustering is made again from this one (the table, the residence, the tree)" [expr {
    [${R}::table] ne $tb1 && [llength [${R}::table]] == [${R}::nclusters] && [vmdance residence] ne $rs1 &&
    [llength [dict get [vmdance tree] leaves]] == [llength [lmap v [${R}::sizes] {expr {$v ? 1 : [continue]}}]]}]
vmdance run 1
check "  run 1 again" [expr {[${R}::nclusters] == 2 && [dict get [vmdance info] molid] == $m}]
vmdance run label 2 "eQual, noise"
check "  renamed" [expr {[lindex [vmdance runs] 1 1] eq "eQual, noise"}]
check "  an unknown run" [string match "*no run \"9\"*" [err {vmdance run 9}]]
for {set k 0} {$k < 26} {incr k} { vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1 }
check "  the last 25 are kept" [expr {[llength [vmdance runs]] == 25 && [lindex [vmdance runs] 0 0] == 4}]
vmdance run delete [lindex [vmdance runs] end 0]
check "  deleted: the newest left is current" [expr {[llength [vmdance runs]] == 24 && [lindex [vmdance runs] end 2] == 1}]
vmdance run clear
check "  cleared" [expr {![llength [vmdance runs]] && ![${R}::has_data]}]

# --- the 3D window --------------------------------------------------------------------------
mol addrep $m
set user_reps [molinfo $m get numreps]
set user_names [lmap i [lsort -integer -decreasing [lmap i [lsearch -all [lrepeat $user_reps x] x] {set i}]] {mol repname $m $i}]
vmdance -mol $m -sel all -k 2 -quiet 1
vmdance draw -colour 1
check "draw -colour: one representation of the plugin's" [expr {[molinfo $m get numreps] == $user_reps + 1}]
set rep [expr {[molinfo $m get numreps] - 1}]
animate goto 3
check "  in the colour of the frame's cluster (blue: 0)" [expr {[lindex [molinfo $m get "{color $rep}"] 0] eq "ColorID 0"}]
animate goto 20
check "  it follows the frame (red: 1)" [expr {[lindex [molinfo $m get "{color $rep}"] 0] eq "ColorID 1"}]
vmdance draw -reps 1
check "draw -reps: one per cluster, at its representative" [expr {[molinfo $m get numreps] == $user_reps + 3 &&
    [lsort [lmap i {1 2} {mol drawframes $m [expr {$user_reps + $i}]}]] eq [lsort [list [${R}::rep_frame 0] [${R}::rep_frame 1]]]}]
vmdance select 1
vmdance draw -reps 0 -colour 0 -overlay 1 -top 3
set rep [expr {[molinfo $m get numreps] - 1}]
check "draw -overlay: the selected cluster's 3 nearest frames" [expr {[molinfo $m get numreps] == $user_reps + 1 &&
    [spec_frames [mol drawframes $m $rep]] eq [lsort -integer [${R}::top 1 3]] && [frames_drawn $m $rep] == 3}]
vmdance draw -frames "0-2,20"
set n [expr {[molinfo $m get numreps] - $user_reps}]
# (the four frames, all drawn: VMD takes a list separated by spaces, and drew
# the first frame alone of one separated by commas)
set typed 0
for {set i $user_reps} {$i < [molinfo $m get numreps]} {incr i} { set typed [expr {$typed + [frames_drawn $m $i]}] }
check "  frames typed: one representation per cluster" [expr {$n == 2 && $typed == 4}]
check "  a range that is not one" [string match "*not a frame or a range*" [err {vmdance draw -frames "1..5"}]]
check "  spaces and leading zeros taken" [expr {[::VMDance::Viz::parse_frames "008-010, 3 - 4"] eq {3 4 8 9 10}}]
check "  a frame past the last one" [string match "*frame 30 is past the last frame of the molecule (23)*" [err {vmdance draw -frames "20-30"}]]
check "  one that runs backwards" [string match "*ends before it starts*" [err {vmdance draw -frames "9-3"}]]
check "  an unknown style" [string match "*-style must be one of*" [err {vmdance draw -style Cartoonish}]]
check "  an unknown option" [string match "*unknown option -glow*" [err {vmdance draw -glow 1}]]
vmdance pick -mol $m -sel all -method diversity -param 20
vmdance draw -overlay 0 -picks 1
check "draw -picks" [expr {[molinfo $m get numreps] == $user_reps + 1 &&
    [frames_drawn $m $user_reps] == [llength [dict get [set ${R}::picks] vmdframes]] && [llength [dict get [set ${R}::picks] vmdframes]] > 1}]
vmdance draw -picks 0
check "everything off: only the user's representations are left, unchanged" [expr {[molinfo $m get numreps] == $user_reps &&
    [lmap i [lsort -integer -decreasing [lmap i [lsearch -all [lrepeat $user_reps x] x] {set i}]] {mol repname $m $i}] eq $user_names}]
vmdance draw -reps 1
mol delrep 0 $m
check "  the plugin finds its own by name after the user deletes one of theirs" [expr {[err {vmdance draw -reps 0}] eq "" &&
    [molinfo $m get numreps] == $user_reps - 1}]
mol addrep $m
set g [vmdance goto 1]
check "goto: the representative's frame" [expr {$g == [${R}::rep_frame 1] && [molinfo $m get frame] == $g}]
check "  goto -frame" [expr {[vmdance goto -frame 7] == 7 && [molinfo $m get frame] == 7}]
check "  a frame that is not there" [string match "*has no frame*" [err {vmdance goto -frame 99}]]
set n [vmdance userfield]
set sa [atomselect $m all frame 20]
check "userfield: every clustered frame's cluster in the user field (asked for)" [expr {$n == 24 && [lsort -unique [$sa get user]] eq {1.0}}]
$sa delete
set before [lindex [molinfo $m get "{color 0}"] 0]
vmdance draw -colour 1 -style Licorice -material Transparent
check "  the user's representation untouched by drawing" [expr {[lindex [molinfo $m get "{color 0}"] 0] eq $before}]
vmdance draw -colour 0
mol new atoms 1
check "a new molecule: the drawing keeps to the clustered one" [expr {[err {vmdance draw -reps 1}] eq "" && [molinfo top get numreps] <= 1}]
vmdance draw -reps 0

# --- files --------------------------------------------------------------------------------
set dir [file join $::out export]
file delete -force $dir
file mkdir $dir
vmdance -mol $m -sel all -k 2 -first 4 -last 19 -step 2 -kinit KmeansPP -quiet 1
vmdance prime
vmdance similarity
set files [vmdance export $dir -prefix t -items {summary clusters labels top timeline transitions residence silhouette distances tree prime similarity picks} -top 2]
check "export: the tables written" [expr {[llength $files] == 13 && [lsort -unique [lmap f $files {file exists $f}]] eq {1}}]
set rows [csv_rows [file join $dir t_labels.csv]]
check "  labels: frame,cluster by VMD frame (a subset: 4 to 18)" [expr {[lindex $rows 0] eq {frame cluster} && [lindex $rows 1 0] == 4 && [lindex $rows end 0] == 18 && [llength $rows] == 9}]
set head [read_text [file join $dir t_clusters.csv]]
check "  a header says what was clustered and how" [expr {[string match "*# selection: all (8 atoms)*" $head] && [string match "*# algorithm: KMeans NANI, k 2, metric MSD*" $head] &&
    [string match "*# frames: 8 (4 to 18, step 2)*" $head]}]
set rows [csv_rows [file join $dir t_top_frames.csv]]
check "  the nearest frames: rank 0 is the representative" [expr {[llength $rows] == 5 && [lindex $rows 1 0] == [${R}::rep_frame [lindex $rows 1 1]] && [lindex $rows 1 2] == 0}]
set rows [csv_rows [file join $dir t_transitions.csv]]
check "  transitions: from, to, count, probability" [expr {[lindex $rows 0] eq {from_cluster to_cluster count probability} && [llength $rows] == 5}]
set rows [csv_rows [file join $dir t_prime.csv]]
check "  PRIME: seven rows" [expr {[llength $rows] == 8}]
check "  no file half written" [expr {![llength [glob -nocomplain -directory $dir *.tmp*]]}]
check "  an unknown item" [string match "*unknown item \"everything\"*" [err {vmdance export $dir -items everything}]]
check "  a prefix with a folder" [string match "*plain file name*" [err {vmdance export $dir -prefix ../x}]]
set files [vmdance export $dir -prefix s -items {representatives trajectories} -format pdb]
check "structures: the representatives (PDB), each cluster's trajectory" [expr {[llength $files] == 3}]
set t [mol new [file join $dir s_representatives.pdb] waitfor all]
check "  the representatives: one frame per cluster" [expr {[molinfo $t get numframes] == 2 && [molinfo $t get numatoms] == 8}]
mol delete $t
set files [vmdance export $dir -prefix d -items trajectories -format dcd -sel "index 0 to 3"]
set c0 [${R}::size 0]
set t [mol new [file join $dir d_cluster_0.pdb] waitfor all]
mol addfile [file join $dir d_cluster_0.dcd] waitfor all molid $t
check "  DCD with a PDB of its atoms: the cluster's frames" [expr {[molinfo $t get numatoms] == 4 && [molinfo $t get numframes] == $c0 + 1}]
mol delete $t
check "  VMD's top molecule is put back" [expr {[molinfo top] == [lindex [molinfo list] end]}]
set v0 [molinfo $m get {center_matrix rotate_matrix scale_matrix global_matrix}]
vmdance export $dir -prefix v -items representatives -format pdb
check "  and VMD's view" [expr {[molinfo $m get {center_matrix rotate_matrix scale_matrix global_matrix}] eq $v0}]
vmdance elbow -mol $m -sel all -ks {2 3} -kinit KmeansPP -quiet 1
set files [vmdance export $dir -prefix e -items elbow]
check "  the elbow scan's scores" [expr {[lindex [csv_rows [lindex $files 0]] 0] eq {k k_actual calinski_harabasz davies_bouldin cluster_sizes status}}]
vmdance run clear
check "  without a clustering, only scans and picks" [string match "*no clustering*" [err {vmdance export $dir -items clusters}]]

# --- selections VMD can take ------------------------------------------------------
# (VMD crashes freeing a selection of about 100 000 single values, and adding
# one as a representation: 120 000 on Windows' stack; Mol::vmd_text)
set long "all or index [string trim [string repeat {0 } 120000]]"
check "a selection of 120 000 index words: its atoms, and VMD goes on" [expr {
    [::VMDance::Mol::atoms $m $long] eq [::VMDance::Mol::atoms $m all]}]
set nr [molinfo $m get numreps]
mol selection [::VMDance::Mol::vmd_text $m $long]
mol representation Lines
mol addrep $m
check "  as a representation" [expr {[molinfo $m get numreps] == $nr + 1}]
mol delrep $nr $m
check "  deleted" [expr {[molinfo $m get numreps] == $nr}]
# (the plugin's own index list, still too long once in ranges: its atoms
# named, where that selects them exactly; max_values lowered to make one)
set a [atomselect $m all]
set names0 [$a get name]
$a set name {N CA C O N CA C O}
set keep $::VMDance::Mol::max_values
set ::VMDance::Mol::max_values 1
check "an index list too long: named by its atoms' names in its range" [expr {
    [::VMDance::Mol::vmd_text $m "index 1 5"] eq "name CA and index 1 to 5" &&
    [::VMDance::Mol::atoms $m "index 1 5"] eq {1 5} &&
    [::VMDance::Mol::vmd_text $m "index 5 2 1"] eq "name C CA and index 1 to 5" &&
    [::VMDance::Mol::atoms $m [::VMDance::Mol::index_text {1 2 5}]] eq {1 2 5}}]
check "  refused where the names select others too (index 6 is a C after 5's CA)" [string match "*separate values*select the atoms by name, residue or range*" [err {::VMDance::Mol::atoms $m "index 1 2 6"}]]
check "  a text of the user's that is still too long: refused, never named" [string match "*separate values*" [err {::VMDance::Mol::atoms $m "name N CA C O"}]]
set ::VMDance::Mol::max_values $keep
$a set name $names0
$a delete
check "  the names put back" [expr {[lsort -unique [[set s [atomselect $m all]] get name]] eq {CA}}]
$s delete
mol selection all
mol representation VDW
mol addrep $m
set fl {0 1 2 3 10 12 14 20}
mol drawframes $m $nr [::VMDance::Viz::_drawframes $fl]
check "frames as ranges: \"[mol drawframes $m $nr]\" draws the 8 frames" [expr {
    [mol drawframes $m $nr] eq "0:3 10:2:14 20" && [frames_drawn $m $nr] == 8}]
mol delrep $nr $m

# --- the fit: the plugin's (Coords::fit_matrix) against VMD's measure fit ----------
# (VMD's stops after 1000 iterations, "Matrix: Warning: no convergence", with
# a rotation that is not the best)
proc fit_rmsd_vmd {M X Y} {
    set s 0.0
    foreach p $X q $Y { set s [expr {$s + [veclength2 [vecsub [coordtrans $M $p] $q]]}] }
    expr {sqrt($s / [llength $X])}
}
set worse 0; set gain 0.0; set nfits 0
foreach fx {two_state outlier single_state} {
    set mf [load_system $fx]
    set rf [atomselect $mf all frame 0]
    set cf [atomselect $mf all frame 0]
    set Y [$rf get {x y z}]
    set refc [::VMDance::Coords::fit_ref $Y]
    for {set f 0} {$f < [molinfo $mf get numframes]} {incr f} {
        $cf frame $f
        set X [$cf get {x y z}]
        set ours [fit_rmsd_vmd [::VMDance::Coords::fit_matrix $X $refc] $X $Y]
        set vmds [fit_rmsd_vmd [measure fit $cf $rf] $X $Y]
        if {$ours > $vmds + 1e-6} { incr worse }
        set gain [expr {max($gain, $vmds - $ours)}]
        incr nfits
    }
    $rf delete; $cf delete
    mol delete $mf
}
check "fit: the plugin's at least as close as VMD's measure fit on the fixtures' $nfits frames (VMD's up to [format %.3f $gain] Å RMSD above)" [expr {
    $nfits == 46 && $worse == 0 && $gain > 0.01}]
# a clustering with a fit reads rows superposed by it: each frame's row as
# close to the first's as a fit can make it
set mf [load_system two_state]
set c [::VMDance::Coords::extract [::VMDance::Job::check_input [list mol $mf sel all fit all]]]
set rows [lmap r [csv_rows [::VMDance::Coords::csv $c]] {
    set p {}; foreach {x y z} $r { lappend p [list $x $y $z] }; set p}]
set r0 [lindex $rows 0]
set refc [::VMDance::Coords::fit_ref $r0]
set far 0.0
foreach r [lrange $rows 1 end] {
    set best [fit_rmsd_vmd [::VMDance::Coords::fit_matrix $r $refc] $r $r0]
    set s 0.0; foreach p $r q $r0 { set s [expr {$s + [veclength2 [vecsub $p $q]]}] }
    set far [expr {max($far, sqrt($s / [llength $r]) - $best)}]
}
check "  a clustering with -fit: its rows superposed on the first as closely as a fit can ([format %.1e $far] Å from the least RMSD)" [expr {
    [llength $rows] == 24 && $far < 1e-4}]
mol delete $mf
done
} err]} { puts "FAIL test_results crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
