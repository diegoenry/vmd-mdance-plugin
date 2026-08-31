# Runtime scenario: a parameter sweep where one configuration fails mid-grid.
#
#   build the GUI -> select KMeans, K = 2..4, MSD, CompSim -> run the sweep with
#   the backend rigged to fail for K=3 -> the failing config becomes an ERR row
#   while the others succeed, the sweep finalizes, and run-state is restored.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]

# Build the real GUI (notebook + sweep tab + treeview).
::mdance::gui::create_window

# Configure the sweep selection the way a user would via the widgets.
set ::mdance::gui::mol_selection  $mol
set ::mdance::gui::atom_selection "name CA"
set ::mdance::gui::frame_first 0
set ::mdance::gui::frame_last -1
set ::mdance::gui::frame_stride 1
set ::mdance::gui::sweep_kmin 2
set ::mdance::gui::sweep_kmax 4
set ::mdance::gui::sweep_kstep 1
array set ::mdance::gui::sweep_algo   {kmeans 1 divine 0}
array set ::mdance::gui::sweep_metric {MSD 1 BUB 0 Fai 0 Gle 0 Ja 0 JT 0 RT 0 RR 0 SM 0 SS1 0 SS2 0}
array set ::mdance::gui::sweep_kinit  {StratAll 0 StratReduced 0 CompSim 1 DivSelect 0 KmeansPP 0 Random 0 VanillaKmeansPP 0}

# Rig the backend to fail only for K=3.
set ::env(MDANCE_FAKE_FAIL_K) 3

::mdance::gui::run_parameter_sweep

set tv .mdance.nb.sweep.res.tv
set items [$tv children {}]

# index rows by their requested K
array set rowByK {}
foreach it $items {
    set r $::mdance::gui::sweep_rows($it)
    set rowByK([dict get $r K]) $it
}

th::section "Sweep completes the whole grid despite a failing config"
th::test "all three K configurations produced a row" {
    th::eq 3 [llength $items]
    th::true [info exists rowByK(2)]
    th::true [info exists rowByK(3)]
    th::true [info exists rowByK(4)]
}
th::test "the K=3 config is recorded as failed" {
    th::eq failed [dict get $::mdance::gui::sweep_rows($rowByK(3)) status]
}
th::test "the other configs succeeded" {
    th::eq ok [dict get $::mdance::gui::sweep_rows($rowByK(2)) status]
    th::eq ok [dict get $::mdance::gui::sweep_rows($rowByK(4)) status]
}
th::test "successful configs carry a loadable full result" {
    th::true [info exists ::mdance::gui::sweep_full($rowByK(2))]
    th::true [info exists ::mdance::gui::sweep_full($rowByK(4))]
    th::false [info exists ::mdance::gui::sweep_full($rowByK(3))] "failed config stores no result"
}

th::section "Run-state and best-pick are sane after a partial failure"
th::test "sweep_running is restored to 0 (not wedged)" {
    th::eq 0 $::mdance::gui::sweep_running
}
th::test "the failed row is not mistaken for a best run" {
    set tags [$tv item $rowByK(3) -tags]
    th::true [expr {"failed" in $tags}]
    th::false [expr {"bestCH" in $tags || "bestDB" in $tags}] "a failed row must never win best"
}
th::test "exactly one successful row is tagged best-CH" {
    set n 0
    foreach it $items { if {"bestCH" in [$tv item $it -tags]} { incr n } }
    th::eq 1 $n
}

th::section "Load a sweep result into the Results tab"
th::test "loading the K=2 run populates ::mdance::results" {
    $tv selection set $rowByK(2)
    ::mdance::gui::sweep_load_selected
    th::eq 2 [dict get $::mdance::results nClusters]
}

::mdance::utils::cleanup
exit [th::done "runtime:sweep"]
