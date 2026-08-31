# Unit tests for the pure plot-math helpers: cluster_color, nice_ticks, heatmap_color.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

# A well-formed Tk color is "#rrggbb" -- exactly 6 lowercase hex digits.
proc is_hex6 {c} {
    return [string match {#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]} $c]
}

th::section "cluster_color - never emits a malformed color"
th::test "noise (-1) -> neutral gray" {
    th::eq "#808080" [::mdance::plots::cluster_color -1 5]
}
th::test "in-range ids are valid 6-hex colors" {
    for {set i 0} {$i < 5} {incr i} {
        th::true [is_hex6 [::mdance::plots::cluster_color $i 5]] "cid=$i"
    }
}
th::test "out-of-range id is clamped to a valid color (was malformed)" {
    th::true [is_hex6 [::mdance::plots::cluster_color 99 5]]
}
th::test "single-cluster case is valid" {
    th::true [is_hex6 [::mdance::plots::cluster_color 0 1]]
}

th::section "nice_ticks - axis ticks (integer-range regression)"
th::test "integer range 0..3 does NOT raise a domain error" {
    # Regression: range/nticks was integer 3/6 = 0 -> log10(0) -> 0.0/0.0 crash.
    th::ok { ::mdance::plots::nice_ticks 0 3 6 }
    set ticks [::mdance::plots::nice_ticks 0 3 6]
    th::gt [llength $ticks] 0
}
th::test "integer range 0..1 does NOT raise" {
    th::ok { ::mdance::plots::nice_ticks 0 1 6 }
}
th::test "float range produces ascending ticks" {
    set ticks [::mdance::plots::nice_ticks 0 0.5 6]
    th::gt [llength $ticks] 1
    th::true [expr {[lindex $ticks 0] <= [lindex $ticks end]}]
}
th::test "degenerate range (vmin == vmax) is handled" {
    th::ok { ::mdance::plots::nice_ticks 5 5 6 }
}
th::test "larger integer range works" {
    set ticks [::mdance::plots::nice_ticks 0 100 5]
    th::gt [llength $ticks] 1
}

th::section "heatmap_color - blue/white/red gradient"
th::test "valid 6-hex across the range" {
    foreach v {0.0 0.25 0.5 0.75 1.0} {
        th::true [is_hex6 [::mdance::plots::heatmap_color $v 0.0 1.0]] "v=$v"
    }
}
th::test "degenerate range -> white" {
    th::eq "#FFFFFF" [::mdance::plots::heatmap_color 1.0 2.0 2.0]
}
th::test "out-of-range values are clamped (still valid)" {
    th::true [is_hex6 [::mdance::plots::heatmap_color -5 0 1]]
    th::true [is_hex6 [::mdance::plots::heatmap_color 99 0 1]]
}

exit [th::done "unit:plot_math"]
