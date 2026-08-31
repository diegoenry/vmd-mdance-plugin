# Runtime scenario: eQUAL produces noise (-1) labels, then every visualization
# must render those without crashing (regression for the -1-sentinel bugs).
#
#   load a trajectory with an outlier frame -> run eQUAL (radial threshold) ->
#   the outlier becomes noise (-1) -> color + all plots handle it cleanly.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture outlier.pdb]   ;# 12 frames, frame 6 is a large outlier

set params [dict create molid $mol atomsel "name CA" metric MSD \
    threshold 1.0 seed-method medoid n-seeds 1 percentage 10 \
    min-samples 2 sim-threshold 0 align none first 0 last -1 stride 1]
set r [::mdance::run_clustering equal $params]

proc count_noise {labels} {
    set n 0
    foreach l $labels { if {$l < 0} { incr n } }
    return $n
}

th::section "eQUAL yields real -1 noise labels"
th::test "the outlier frame (6) is labeled noise" {
    th::eq -1 [lindex [dict get $r labels] 6]
}
th::test "exactly one noise frame, the rest clustered" {
    th::eq 1 [count_noise [dict get $r labels]]
}
th::test "at least one real cluster emerged" {
    th::gt [dict get $r nClusters] 0
}

th::section "Color by cluster tolerates -1 (neutral, not a crash)"
th::test "apply_cluster_colors runs; noise frame keeps an unassigned marker" {
    th::ok { ::mdance::apply_cluster_colors }
}

th::section "Bar / timeline / heatmap plots render with noise present"
foreach {label proc} {
    "population chart"   population_chart
    "timeline chart"     timeline_chart
    "within-cluster MSD" msd_chart
    "transition heatmap" transition_heatmap
    "residence chart"    residence_chart
} {
    th::test "$label does not crash on -1 labels" \
        "th::ok { ::mdance::plots::$proc \$::mdance::results }"
}

th::section "Centroid-based plots skip -1 instead of crashing (was the bug)"
th::test "compute_centroids returns one centroid per cluster, ignoring noise" {
    ::mdance::plots::compute_centroids $::mdance::results CC NA
    th::eq [dict get $r nClusters] [array size CC]
}
foreach {label proc} {
    "dendrogram"              dendrogram
    "cluster distance heatmap" cluster_distance_heatmap
    "silhouette plot"         silhouette_plot
    "representative RMSD"     representative_rmsd_matrix
} {
    th::test "$label does not crash on -1 labels" \
        "th::ok { ::mdance::plots::$proc \$::mdance::results }"
}

::mdance::utils::cleanup
exit [th::done "runtime:equal_plots"]
