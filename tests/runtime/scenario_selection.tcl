# Runtime scenario: the atom-selection contract for coordinate extraction.
#
# `$sel update` re-evaluates the selection TEXT for each frame, so a
# coordinate-based selection ("x > 1", "within 5 of resname LIG") gains and loses
# atoms as the trajectory moves. The extracted matrix has one fixed-width row per
# frame and the backend is handed a single natoms, so a changing count used to
# produce a ragged matrix that still clustered "successfully" -- on misaligned
# coordinates. Extraction must refuse such a selection instead.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]

# ------------------------------------------------------------------
th::section "A frame-dependent selection is refused, not silently mis-extracted"
# ------------------------------------------------------------------

# Confirm the fixture genuinely makes this selection frame-dependent, so the
# tests below cannot start passing vacuously if the fixture geometry changes.
set probe [atomselect $mol "x > 1"]
set counts {}
for {set f 0} {$f < [molinfo $mol get numframes]} {incr f} {
    $probe frame $f
    $probe update
    lappend counts [$probe num]
}
$probe delete

th::test "fixture sanity: 'x > 1' really does change atom count across frames" {
    th::gt [llength [lsort -unique $counts]] 1 "counts were: $counts"
}
th::test "CLI extraction refuses a frame-dependent selection" {
    th::throws {::mdance::extract_coordinates $mol "x > 1" 0 -1 1} "*frame-dependent*"
}
th::test "library-mode extraction refuses it too" {
    th::throws {::mdance::extract_coordinates_flat $mol "x > 1" 0 -1 1} "*frame-dependent*"
}
th::test "extract_csv_for_frames refuses it" {
    th::throws {::mdance::extract_csv_for_frames $mol "x > 1" {0 1 2 20 21}} "*frame-dependent*"
}
th::test "a full clustering run surfaces the error instead of clustering garbage" {
    set params [dict create molid $mol atomsel "x > 1" nclusters 2 metric MSD \
        first 0 last -1 stride 1]
    th::throws {::mdance::run_clustering kmeans $params} "*frame-dependent*"
}
th::test "the run flag is released after the refusal" {
    th::eq 0 $::mdance::running
}

# ------------------------------------------------------------------
th::section "A static selection is unaffected by the guard"
# ------------------------------------------------------------------
th::test "name CA extracts one full-width row per frame" {
    lassign [::mdance::extract_coordinates $mol "name CA" 0 -1 1] csv natoms nframes frames
    th::eq 24 $nframes
    set lines [read_lines $csv]
    th::eq 24 [llength $lines]
    set widths {}
    foreach line $lines { lappend widths [llength [split $line ","]] }
    th::eq [list [expr {$natoms * 3}]] [lsort -unique $widths] "every row must be natoms*3 wide"
    catch {file delete $csv}
}
th::test "a static selection still clusters end to end" {
    set params [dict create molid $mol atomsel "name CA" nclusters 2 metric MSD \
        first 0 last -1 stride 1]
    set r [::mdance::run_clustering kmeans $params]
    th::eq 24 [llength [dict get $r labels]]
}

exit [th::done "runtime:selection"]
