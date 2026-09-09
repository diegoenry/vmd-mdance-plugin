# Runtime scenario: noise (-1) must be counted, not quietly dropped.
#
# The transition heatmap summed only columns 0..nClusters-1 when normalizing each
# row, so every transition INTO noise vanished from the denominator and every
# probability on display was inflated -- in the worst case a coin-flip rendered
# as a certainty. The timeline had the mirror-image problem: it plotted noise at
# lane index -1, i.e. below the x-axis, on top of the frame-number labels.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

# Synthetic labels with a known transition structure, so the arithmetic can be
# checked exactly rather than eyeballed.
#   frames:      0  0  1 -1  1  0
#   from 0: ->0, ->1                 (2 transitions, none into noise)
#   from 1: ->noise, ->0             (2 transitions, HALF into noise)
set res [dict create \
    algorithm equal nClusters 2 nFrames 6 \
    labels {0 0 1 -1 1 0} clusterSizes {3 2} representatives {0 2} \
    clusterMSD {0.1 0.1}]

proc csv_prob {csv from to} {
    foreach line [split [string trim $csv] "\n"] {
        set f [split $line ","]
        if {[lindex $f 0] eq $from && [lindex $f 1] eq $to} { return [lindex $f 2] }
    }
    return ""
}

th::section "Transition probabilities count transitions into noise"
::mdance::plots::transition_heatmap $res
set csv $::mdance::plots::csv_data(mdance_trans)

th::test "a row with half its transitions into noise is not inflated to certainty" {
    # Cluster 1 goes to noise once and to cluster 0 once. Dropping the noise
    # transition made P(1->0) read as 1.000000.
    th::near 0.5 [csv_prob $csv 1 0] 0.0001
    th::near 0.0 [csv_prob $csv 1 1] 0.0001
}
th::test "the noise destination is exported explicitly" {
    th::near 0.5 [csv_prob $csv 1 -1] 0.0001
}
th::test "a row with no noise transitions is unaffected" {
    th::near 0.5 [csv_prob $csv 0 0] 0.0001
    th::near 0.5 [csv_prob $csv 0 1] 0.0001
    th::near 0.0 [csv_prob $csv 0 -1] 0.0001
}
th::test "every row of the exported matrix now sums to 1" {
    foreach i {0 1} {
        set sum 0.0
        foreach j {0 1 -1} { set sum [expr {$sum + [csv_prob $csv $i $j]}] }
        th::near 1.0 $sum 0.0001 "row $i must be a complete probability distribution"
    }
}
catch {destroy [::mdance::plots::plot_widget mdance_trans]}

th::section "The timeline gives noise its own lane instead of drawing off-axis"
::mdance::plots::timeline_chart $res
th::test "a 'noise' lane label is drawn" {
    set c [::mdance::plots::plot_widget mdance_timeline].c
    set found 0
    foreach id [$c find all] {
        if {[$c type $id] eq "text" && [$c itemcget $id -text] eq "noise"} { set found 1 }
    }
    th::true $found "noise needs a labelled lane of its own"
}
th::test "no plotted band is drawn below the x-axis" {
    # Lane -1 put noise bands underneath y1, over the frame-number labels.
    set c [::mdance::plots::plot_widget mdance_timeline].c
    set maxy 0
    foreach id [$c find all] {
        if {[$c type $id] ne "rectangle"} continue
        set y1r [lindex [$c coords $id] 3]
        if {$y1r > $maxy} { set maxy $y1r }
    }
    # bottom_margin is 50; the axis sits at canvas height - 50.
    set axis_y [expr {[winfo height $c] - 50}]
    th::true [expr {$maxy <= $axis_y + 1}] "lowest band $maxy must not pass the axis at $axis_y"
}
catch {destroy [::mdance::plots::plot_widget mdance_timeline]}

th::section "A result with no noise is unchanged"
set clean [dict create \
    algorithm kmeans nClusters 2 nFrames 6 \
    labels {0 0 1 1 1 0} clusterSizes {3 3} representatives {0 2} \
    clusterMSD {0.1 0.1}]
::mdance::plots::transition_heatmap $clean
th::test "no -1 column is emitted when there is no noise" {
    th::eq "" [csv_prob $::mdance::plots::csv_data(mdance_trans) 0 -1]
}
catch {destroy [::mdance::plots::plot_widget mdance_trans]}

exit [th::done "runtime:noise_math"]
