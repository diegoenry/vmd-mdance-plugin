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
th::test "noise (-1) -> the neutral gray, whatever the palette says it is" {
    # Pinned to the palette variable rather than a literal: the point is that
    # noise is drawn in the ONE neutral the rest of the plugin uses, not that it
    # is any particular gray.
    th::eq $::mdance::plots::c_noise [::mdance::plots::cluster_color -1 5]
    th::true [is_hex6 [::mdance::plots::cluster_color -1 5]]
}
th::test "the ramp is muted: no channel is pinned to 0 or 255" {
    # What "less bright" means concretely. The old ramp was pure #0000ff ->
    # #00ff00 -> #ff0000, so every colour it produced had a dead channel and a
    # saturated one; this asserts the whole ramp now lives inside those bounds.
    for {set i 0} {$i < 7} {incr i} {
        set c [::mdance::plots::cluster_color $i 7]
        foreach ch [scan $c "#%2x%2x%2x"] {
            th::true [expr {$ch > 20 && $ch < 235}] "$c channel $ch out of bounds"
        }
    }
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

th::section "heatmap_color - muted cool/neutral/warm gradient"
th::test "valid 6-hex across the range" {
    foreach v {0.0 0.25 0.5 0.75 1.0} {
        th::true [is_hex6 [::mdance::plots::heatmap_color $v 0.0 1.0]] "v=$v"
    }
}
th::test "degenerate range -> the ramp's own midpoint, not white" {
    # An all-equal matrix used to come back white, which is the canvas colour:
    # the cells vanished and the grid read as empty rather than as uniform.
    set mid [::mdance::plots::heatmap_color 1.0 2.0 2.0]
    th::eq [::mdance::plots::heatmap_color 0.5 0.0 1.0] $mid
    th::ne "#ffffff" [string tolower $mid]
}
th::test "the ramp runs cool -> warm and stays muted" {
    set lo [::mdance::plots::heatmap_color 0.0 0.0 1.0]
    set hi [::mdance::plots::heatmap_color 1.0 0.0 1.0]
    lassign [scan $lo "#%2x%2x%2x"] lr lg lb
    lassign [scan $hi "#%2x%2x%2x"] hr hg hb
    th::true [expr {$lb > $lr}] "the low end must be the blue one ($lo)"
    th::true [expr {$hr > $hb}] "the high end must be the warm one ($hi)"
    foreach ch [list $lr $lg $lb $hr $hg $hb] {
        th::true [expr {$ch > 20 && $ch < 235}] "channel $ch is not muted"
    }
}
th::test "out-of-range values are clamped (still valid)" {
    th::true [is_hex6 [::mdance::plots::heatmap_color -5 0 1]]
    th::true [is_hex6 [::mdance::plots::heatmap_color 99 0 1]]
}

exit [th::done "unit:plot_math"]
