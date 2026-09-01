# Runtime scenario: the "extras" a user reaches for once they have a clustering --
# native library mode (in-memory, no temp files), iSIM / PRIME / Frame-Tools
# analyses, and saving/reloading a session.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]

proc tmp_count {} {
    # Count inside the plugin's OWN private scratch dir. Globbing the shared
    # system tmpdir also saw (and the cleanup below also deleted) files belonging
    # to any other VMD session running at the same time.
    return [llength [glob -nocomplain [file join [::mdance::utils::workdir] *]]]
}
foreach f [glob -nocomplain [file join [::mdance::utils::workdir] *]] { catch {file delete -force $f} }

# ------------------------------------------------------------------
th::section "Native library mode passes coordinates in memory (no temp files)"
# ------------------------------------------------------------------
# Simulate the loaded C extension with a Tcl proc of the same name/signature.
proc ::mdance::kmeans {flat nframes natoms k args} {
    set labels {}
    for {set i 0} {$i < $nframes} {incr i} { lappend labels [expr {$i % $k}] }
    set sizes {}; for {set c 0} {$c < $k} {incr c} { lappend sizes 0 }
    foreach l $labels { lset sizes $l [expr {[lindex $sizes $l] + 1}] }
    set reps {}
    for {set c 0} {$c < $k} {incr c} {
        set idx [lsearch -exact $labels $c]
        lappend reps [expr {$idx < 0 ? -1 : $idx}]
    }
    set cmsd {}; for {set c 0} {$c < $k} {incr c} { lappend cmsd 0.1 }
    return [dict create algorithm kmeans nClusters $k nFrames $nframes \
        labels $labels clusterSizes $sizes representatives $reps clusterMSD $cmsd \
        score_calinskiHarabasz 10.0 score_daviesBouldin 0.5]
}

set ::mdance::use_library 1
set lib_params [dict create molid $mol atomsel "name CA" nclusters 2 \
    metric MSD kinit CompSim percentage 10 first 0 last -1 stride 1]
set rl [::mdance::run_clustering kmeans $lib_params]

th::test "library run returns a valid clustering" {
    th::eq 2 [dict get $rl nClusters]
    th::eq 24 [llength [dict get $rl labels]]
}
th::test "library mode writes NO temp files (in-memory data path)" {
    th::eq 0 [tmp_count]
}
th::test "library result still carries the molecule/frame context" {
    th::eq $mol [dict get $rl molid]
    th::eq 24 [llength [dict get $rl frames]]
}

# Back to CLI mode for the analysis helpers.
set ::mdance::use_library 0

# Get a real CLI clustering to analyze.
set r [::mdance::run_clustering kmeans $lib_params]
set frames [dict get $r frames]
set labels [dict get $r labels]

# ------------------------------------------------------------------
th::section "Extended-similarity (iSIM) analysis"
# ------------------------------------------------------------------
th::test "run_analysis returns an ensemble iSIM plus per-cluster data" {
    set a [::mdance::run_analysis $mol "name CA" $frames $labels MSD]
    th::true [dict exists $a isim]
    th::true [string is double -strict [dict get $a isim]]
    th::eq 2 [llength [dict get $a clusterISIM]]
}

# ------------------------------------------------------------------
th::section "PRIME representative-frame prediction"
# ------------------------------------------------------------------
th::test "run_prime returns predicted and baseline frame indices" {
    set p [::mdance::run_prime $mol "name CA" $frames $labels RR 0.1 1]
    foreach key {pairwise union medoid outlier medoidAll medoidC0 nClusters} {
        th::true [dict exists $p $key] "missing $key"
    }
    # the predicted sample indices map to real absolute frames
    set af [::mdance::abs_frame [dict create frames $frames] [dict get $p medoid]]
    th::true [expr {$af >= 0 && $af < 24}] "medoid maps into the trajectory"
}

# ------------------------------------------------------------------
th::section "Frame Tools: select a diverse subset without clustering"
# ------------------------------------------------------------------
th::test "run_select returns a non-empty subset of valid sample indices" {
    set idxs [::mdance::run_select $mol "name CA" $frames diversity MSD 50 10]
    th::gt [llength $idxs] 0
    foreach i $idxs { th::true [expr {$i >= 0 && $i < [llength $frames]}] "idx=$i" }
}

# ------------------------------------------------------------------
th::section "Session save / load round-trip with a live molecule"
# ------------------------------------------------------------------
th::test "a saved session reloads and reports the molecule as live" {
    set ::mdance::results $r
    set f [::mdance::utils::mktmp .mdance]
    ::mdance::save_session $f
    set ::mdance::results ""
    set live [::mdance::load_session $f]
    th::true $live "molecule $mol is loaded -> live"
    th::eq 2 [dict get $::mdance::results nClusters]
    th::eq $frames [dict get $::mdance::results frames]
    catch {file delete $f}
}

::mdance::utils::cleanup
exit [th::done "runtime:extras"]
