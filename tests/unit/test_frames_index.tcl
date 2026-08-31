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

th::section "frame_list - non-numeric input must fail loudly, not string-compare"
# Regression: every guard in frame_list is an expr comparison, and expr falls
# back to STRING comparison on a non-numeric operand. A "1o" typo for "10" used
# to pass all of them and silently cluster the wrong frames, with the damage
# depending on the digits of the frame count (2 frames out of 500, but all 1000
# out of 1000). Silently clustering the wrong subset is the worst outcome here.
th::test "non-numeric last errors instead of silently selecting a subset" {
    th::throws {::mdance::frame_list 0 0 1o 1} "*whole number*"
}
th::test "non-numeric first is rejected" {
    th::throws {::mdance::frame_list 0 x 5 1} "*whole number*"
}
th::test "non-integer stride is rejected up front, not mid-extraction" {
    th::throws {::mdance::frame_list 0 0 -1 2.5} "*whole number*"
}
th::test "the string-compare trap itself: '1o' compares silently, and the result depends on the frame count" {
    # Pins WHY the guard is needed. None of these raise -- that is the whole
    # problem -- and "1o" sorts after "10" but before "500" as a string, which is
    # why the same typo selected every frame of a 10-frame trajectory but only
    # frames {0 1} of a 500-frame one.
    th::false [expr {"1o" < 0}]
    th::true  [expr {"1o" >= 10}]
    th::false [expr {"1o" >= 500}]
}
th::test "empty fields still mean the documented defaults" {
    th::eq {0 1 2 3 4 5 6 7 8 9} [::mdance::frame_list 0 {} {} {}]
}

exit [th::done "unit:frames"]
