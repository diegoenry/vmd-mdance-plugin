# Runtime scenario: HELM and DIVINE end to end, plus the degenerate single-state
# fixture. These paths (nested pre-cluster handoff, initial-label files, DIVINE's
# argument marshaling, k=1 data) had no automated coverage at all.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
proc base_params {} {
    upvar 1 mol mol
    return [dict create molid $mol atomsel "name CA" metric MSD \
        first 0 last -1 stride 1]
}

# ------------------------------------------------------------------
th::section "HELM: automatic KMeans pre-clustering"
# ------------------------------------------------------------------
set p [base_params]
dict set p nclusters 2
dict set p pre-k 4
dict set p merge-scheme centroid
set rh [::mdance::run_clustering helm $p]

th::test "the nested pre-cluster handoff produces one label per frame" {
    th::eq 24 [llength [dict get $rh labels]]
}
th::test "the run reports clusters and matching bookkeeping" {
    set k [dict get $rh nClusters]
    th::ge $k 1
    th::eq $k [llength [dict get $rh clusterSizes]]
    th::eq $k [llength [dict get $rh representatives]]
}
th::test "no temp files leak from the two-stage run" {
    th::eq 0 [llength [glob -nocomplain [file join [::mdance::utils::workdir] *]]]
}

# ------------------------------------------------------------------
th::section "HELM: an explicit initial-labels file, including our own export"
# ------------------------------------------------------------------
# export_labels writes "frame,cluster" with a header. Feeding that straight back
# used to push the header and the frame column through as cluster labels.
set lblfile [::mdance::utils::mktmp "_exported.csv"]
::mdance::export_labels $lblfile

th::test "the plugin's own exported CSV is accepted as initial labels" {
    set lines [read_lines $lblfile]
    th::eq "frame,cluster" [lindex $lines 0] "fixture check: the export has a header"
    th::eq 25 [llength $lines] "fixture check: header + 24 rows"
    set parsed [::mdance::read_labels_file $lblfile]
    th::eq 24 [llength $parsed] "header skipped, last column taken"
    foreach v $parsed { th::true [string is integer -strict $v] }
}
th::test "a plain one-label-per-line file also works" {
    set plain [::mdance::utils::mktmp "_plain.csv"]
    set fp [open $plain w]
    for {set i 0} {$i < 24} {incr i} { puts $fp [expr {$i % 3}] }
    close $fp
    th::eq 24 [llength [::mdance::read_labels_file $plain]]
    catch {file delete $plain}
}
th::test "a non-integer label is reported, not silently passed to the backend" {
    set bad [::mdance::utils::mktmp "_bad.csv"]
    set fp [open $bad w]
    puts $fp "0"
    puts $fp "not-a-label"
    close $fp
    th::throws {::mdance::read_labels_file $bad} "*not an integer label*"
    catch {file delete $bad}
}
th::test "HELM runs against the exported label file" {
    set p2 [base_params]
    dict set p2 nclusters 2
    dict set p2 merge-scheme centroid
    dict set p2 initial-labels $lblfile
    set r2 [::mdance::run_clustering helm $p2]
    th::eq 24 [llength [dict get $r2 labels]]
}
th::test "a label file of the wrong length is rejected up front" {
    set short [::mdance::utils::mktmp "_short.csv"]
    set fp [open $short w]
    for {set i 0} {$i < 5} {incr i} { puts $fp 0 }
    close $fp
    set p3 [base_params]
    dict set p3 nclusters 2
    dict set p3 merge-scheme centroid
    dict set p3 initial-labels $short
    # The message also names the Setup-tab frame range now, because that is the
    # usual cause of a count mismatch (labels computed over the whole trajectory
    # against a strided run, or vice versa).
    th::throws {::mdance::run_clustering helm $p3} "*5 label(s)*24 frame(s)*Stride*"
    catch {file delete $short}
}
catch {file delete $lblfile}

# ------------------------------------------------------------------
th::section "DIVINE: argument marshaling"
# ------------------------------------------------------------------
th::test "every DIVINE parameter reaches the backend without error" {
    set pd [base_params]
    dict set pd nclusters 3
    dict set pd split MSD
    dict set pd anchors NANI
    dict set pd kinit CompSim
    dict set pd threshold 0.5
    dict set pd end-mode nclusters
    dict set pd percentage 10
    dict set pd refine 0
    set rd [::mdance::run_clustering divine $pd]
    th::eq 24 [llength [dict get $rd labels]]
    th::ge [dict get $rd nClusters] 1
}

# ------------------------------------------------------------------
th::section "The degenerate single-state fixture (k=1 territory)"
# ------------------------------------------------------------------
set mol1 [load_fixture single_state.pdb]
th::test "a 10-frame single-conformation trajectory clusters at k=1" {
    set p1 [dict create molid $mol1 atomsel "name CA" metric MSD \
        nclusters 1 kinit CompSim percentage 10 first 0 last -1 stride 1]
    set r1 [::mdance::run_clustering kmeans $p1]
    th::eq 10 [llength [dict get $r1 labels]]
    th::eq 1 [dict get $r1 nClusters]
}
th::test "colouring a 1-cluster result keeps a non-degenerate colour scale" {
    th::eq 0 [::mdance::apply_cluster_colors] "no sample should fall outside the trajectory"
}
th::test "the population and MSD plots render for a single cluster" {
    th::ok { ::mdance::plots::population_chart $::mdance::results }
    catch {destroy .mdance_pop}
    th::ok { ::mdance::plots::msd_chart $::mdance::results }
    catch {destroy .mdance_msd}
}

exit [th::done "runtime:helm_divine"]
