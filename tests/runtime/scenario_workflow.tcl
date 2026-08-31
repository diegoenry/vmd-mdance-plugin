# Runtime scenario: the everyday KMeans workflow a user runs.
#
#   load trajectory -> select CA -> run KMeans -> inspect results ->
#   color by cluster -> go to a representative -> export labels / structures,
#   then the same on a frame-range/stride subset (verifying the index mapping).
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]   ;# 24 frames, 8 CA atoms, 2 states

# ------------------------------------------------------------------
th::section "KMeans on the full trajectory"
# ------------------------------------------------------------------
set params [dict create molid $mol atomsel "name CA" \
    nclusters 2 metric MSD kinit CompSim percentage 10 first 0 last -1 stride 1]
set r [::mdance::run_clustering kmeans $params]

th::test "result has the requested cluster count" {
    th::eq 2 [dict get $r nClusters]
}
th::test "one label per frame, each in range 0..k-1" {
    th::eq 24 [llength [dict get $r labels]]
    foreach l [dict get $r labels] { th::true [expr {$l >= 0 && $l < 2}] "label=$l" }
}
th::test "cluster sizes sum to the frame count" {
    set sizes [dict get $r clusterSizes]
    th::eq 24 [expr {[lindex $sizes 0] + [lindex $sizes 1]}]
}
th::test "both clusters are non-empty (the two states separate)" {
    foreach s [dict get $r clusterSizes] { th::gt $s 0 }
}
th::test "one representative per cluster, each a real frame" {
    set reps [dict get $r representatives]
    th::eq 2 [llength $reps]
    foreach rp $reps { th::true [expr {$rp >= 0 && $rp < 24}] "rep=$rp" }
}
th::test "quality scores are present" {
    th::true [dict exists $r score_calinskiHarabasz]
    th::true [dict exists $r score_daviesBouldin]
}
th::test "the frame map covers all 24 frames (full run)" {
    th::eq 24 [llength [dict get $r frames]]
}

# ------------------------------------------------------------------
th::section "Color by cluster writes the User field per frame"
# ------------------------------------------------------------------
th::test "apply_cluster_colors sets User == label on each frame" {
    ::mdance::apply_cluster_colors
    set labels [dict get $::mdance::results labels]
    set sel [atomselect $mol all]
    foreach f {0 11 12 23} {
        $sel frame $f
        set u [lindex [$sel get user] 0]
        th::near [lindex $labels $f] $u 1e-6 "frame $f"
    }
    $sel delete
}

# ------------------------------------------------------------------
th::section "Navigate to a representative frame"
# ------------------------------------------------------------------
th::test "goto_representative jumps to the medoid frame" {
    set reps [dict get $::mdance::results representatives]
    ::mdance::goto_representative 0
    th::eq [lindex $reps 0] [molinfo $mol get frame]
}
th::test "an out-of-range cluster index errors cleanly" {
    th::throws {::mdance::goto_representative 99} "*Invalid cluster*"
}

# ------------------------------------------------------------------
th::section "Export: labels CSV, representative PDB, per-cluster split"
# ------------------------------------------------------------------
th::test "export_labels writes frame,cluster for every frame" {
    set f [::mdance::utils::mktmp _labels.csv]
    ::mdance::export_labels $f
    set lines [read_lines $f]
    th::eq "frame,cluster" [lindex $lines 0]
    th::eq 25 [llength $lines] "header + 24 rows"
    th::match "0,*" [lindex $lines 1]
    catch {file delete $f}
}
th::test "export_representatives writes one model per cluster" {
    set f [::mdance::utils::mktmp _reps.pdb]
    set n [::mdance::export_representatives $f pdb all]
    th::eq 2 $n
    set rmol [mol new $f waitfor all]
    th::eq 2 [molinfo $rmol get numframes]
    mol delete $rmol
    catch {file delete $f}
}
th::test "export_clusters_split writes one file per non-empty cluster" {
    set dir [::mdance::utils::mktmp _clusters]
    file mkdir $dir
    set n [::mdance::export_clusters_split $dir pdb all]
    th::eq 2 $n
    th::true [file exists [file join $dir cluster_0.pdb]]
    th::true [file exists [file join $dir cluster_1.pdb]]
    catch {file delete -force $dir}
}

# ------------------------------------------------------------------
th::section "Frame range + stride subset: index mapping is preserved"
# ------------------------------------------------------------------
# Cluster only frames 4..19 with stride 2 -> samples come from absolute frames
# {4 6 8 10 12 14 16 18}. Labels/representatives index this subset and must map
# back to absolute VMD frames.
set sub [dict create molid $mol atomsel "name CA" \
    nclusters 2 metric MSD kinit CompSim percentage 10 first 4 last 19 stride 2]
set rs [::mdance::run_clustering kmeans $sub]

th::test "subset frame map is exactly {4 6 8 10 12 14 16 18}" {
    th::eq {4 6 8 10 12 14 16 18} [dict get $rs frames]
}
th::test "one label per *sampled* frame (8), not the whole trajectory" {
    th::eq 8 [llength [dict get $rs labels]]
}
th::test "abs_frame maps sample indices back to absolute frames" {
    th::eq 4  [::mdance::abs_frame $rs 0]
    th::eq 18 [::mdance::abs_frame $rs 7]
}
th::test "representatives map into the sampled absolute frames" {
    foreach rp [dict get $rs representatives] {
        set af [::mdance::abs_frame $rs $rp]
        th::true [expr {$af in {4 6 8 10 12 14 16 18}}] "rep sample $rp -> abs $af"
    }
}
th::test "subset coloring marks non-sampled frames as unassigned (-1)" {
    ::mdance::apply_cluster_colors
    set sel [atomselect $mol all]
    $sel frame 5    ;# 5 is NOT in the stride-2 subset
    set u [lindex [$sel get user] 0]
    $sel delete
    th::near -1.0 $u 1e-6 "non-sampled frame keeps the unassigned sentinel"
}
th::test "exported labels for the subset carry absolute frame numbers" {
    set f [::mdance::utils::mktmp _sublabels.csv]
    ::mdance::export_labels $f
    set lines [read_lines $f]
    th::eq 9 [llength $lines] "header + 8 sampled rows"
    th::match "4,*"  [lindex $lines 1]
    th::match "18,*" [lindex $lines 8]
    catch {file delete $f}
}

# leave no temp files behind
::mdance::utils::cleanup
exit [th::done "runtime:workflow"]
