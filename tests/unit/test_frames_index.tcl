# Unit tests for the frame-index abstraction: frame_list, range_params, abs_frame.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

set ::vmdstub::numframes 10

th::section "frame_list - ranges & stride"
th::test "all frames (defaults)" {
    th::eq {0 1 2 3 4 5 6 7 8 9} [::mdance::frame_list 0 0 -1 1]
}
th::test "stride keeps every Nth frame" {
    th::eq {0 2 4 6 8} [::mdance::frame_list 0 0 -1 2]
    th::eq {0 3 6 9}   [::mdance::frame_list 0 0 -1 3]
}
th::test "explicit first..last" {
    th::eq {2 3 4 5} [::mdance::frame_list 0 2 5 1]
}
th::test "last = -1 means the final frame" {
    th::eq {5 6 7 8 9} [::mdance::frame_list 0 5 -1 1]
}
th::test "last past the end is clamped" {
    th::eq {0 1 2 3 4 5 6 7 8 9} [::mdance::frame_list 0 0 999 1]
}
th::test "negative first is treated as 0" {
    th::eq {0 1 2 3 4 5 6 7 8 9} [::mdance::frame_list 0 -5 -1 1]
}
th::test "stride < 1 is treated as 1" {
    th::eq {0 1 2 3 4 5 6 7 8 9} [::mdance::frame_list 0 0 -1 0]
}
th::test "first > last is an error" {
    th::throws {::mdance::frame_list 0 8 3 1} "*invalid*"
}
th::test "a molecule with no frames is an error" {
    set ::vmdstub::numframes 0
    th::throws {::mdance::frame_list 0 0 -1 1} "*no frames*"
    set ::vmdstub::numframes 10
}

th::section "range_params - defaults from a params dict"
th::test "empty dict -> all frames defaults" {
    th::eq {0 -1 1} [::mdance::range_params {}]
}
th::test "explicit values are passed through" {
    th::eq {5 20 3} [::mdance::range_params {first 5 last 20 stride 3}]
}
th::test "partial dict fills only missing defaults" {
    th::eq {0 -1 4} [::mdance::range_params {stride 4}]
}

th::section "abs_frame - sample index -> absolute VMD frame"
set res {frames {10 13 16 19}}
th::test "maps sample index through the frame map" {
    th::eq 10 [::mdance::abs_frame $res 0]
    th::eq 16 [::mdance::abs_frame $res 2]
}
th::test "preserves the -1 empty-cluster sentinel" {
    th::eq -1 [::mdance::abs_frame $res -1]
}
th::test "empty sample index -> -1" {
    th::eq -1 [::mdance::abs_frame $res ""]
}
th::test "identity fallback when no frame map present" {
    th::eq 7 [::mdance::abs_frame {nClusters 2} 7]
}

exit [th::done "unit:frames"]
