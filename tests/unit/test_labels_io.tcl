# Unit tests for ::mdance::read_labels_file -- the reader for HELM's
# "Initial Labels -> Load from file" input.
#
# The dialects below are not hypothetical: they are the exact shapes emitted by
# the plugin itself and by the MDANCE reference pipeline. Two of them used to be
# rejected outright and one used to load with every label on the WRONG frame,
# so each dialect gets a test that fails without the current reader.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

# write_labels - drop $lines into a temp file and return its path.
proc write_labels {lines} {
    set p [::mdance::utils::mktmp "_labels.csv"]
    set fp [open $p w]
    foreach l $lines { puts $fp $l }
    close $fp
    return $p
}

th::section "dialect 1: one bare label per line (the plugin's own _init.csv)"
th::test "row order is frame order" {
    th::eq {0 1 1 2} [::mdance::read_labels_file [write_labels {0 1 1 2}]]
}
th::test "a non-integer label is reported with its line number" {
    th::throws {::mdance::read_labels_file [write_labels {0 not-a-label}]} \
        "*line 2 is not an integer label*"
}
th::test "an empty file is refused" {
    th::throws {::mdance::read_labels_file [write_labels {}]} "*contains no labels*"
}
th::test "a comment-only file is refused" {
    th::throws {::mdance::read_labels_file [write_labels {"# just a header"}]} \
        "*contains no labels*"
}

th::section "dialect 2: frame,cluster with a bare one-line header (export_labels)"
th::test "the header is skipped and the frame column honoured" {
    th::eq {5 6 7} [::mdance::read_labels_file \
        [write_labels {frame,cluster 0,5 1,6 2,7}]]
}
th::test "a bare header is only accepted as the first row, not deeper down" {
    # Without the $cand == 1 restriction this row would be swallowed as "another
    # header" and the file would load one label short.
    th::throws {::mdance::read_labels_file \
        [write_labels {frame,cluster 0,5 oops,bad 2,7}]} \
        "*non-integer frame index*"
}

th::section "dialect 3: MDANCE NANI output -- TWO '#' comment lines, frame-sorted"
th::test "both comment lines are skipped (line-1-only skip rejected this file)" {
    set p [write_labels [list \
        "# init_type: comp_sim, Number of clusters: 6" \
        "# Frame Index, Cluster Index" \
        "0,3" "1,3" "2,0"]]
    th::eq {3 3 0} [::mdance::read_labels_file $p]
}
th::test "a '#' comment is skipped wherever it appears, not just at the top" {
    set p [write_labels [list "# head" "0,1" "# a note mid-file" "1,2"]]
    th::eq {1 2} [::mdance::read_labels_file $p]
}

th::section "dialect 4: MDANCE HELM output -- rows GROUPED BY CLUSTER"
th::test "labels land on the frame named in column 0, not in row order" {
    # This is the silent-corruption case. The file lists cluster 0's frames
    # first, so a reader that trusts row order returns {0 0 0 ...} and puts
    # frame 0 in cluster 0 -- here frame 0 is really cluster 2. The row count
    # equals the frame count, so the caller's length check cannot catch it.
    set p [write_labels [list \
        "# Helm,number of clusters,3" \
        "# frame_index,cluster_index" \
        "3,0" "4,0" \
        "1,1" "5,1" \
        "0,2" "2,2"]]
    th::eq {2 1 2 0 0 1} [::mdance::read_labels_file $p]
}
th::test "the same file read in row order would have been wrong" {
    # Guards the test above against being trivially satisfied: assert the
    # buggy answer differs from the correct one.
    th::ne {0 0 1 1 2 2} [::mdance::read_labels_file [write_labels [list \
        "# Helm,number of clusters,3" "# frame_index,cluster_index" \
        "3,0" "4,0" "1,1" "5,1" "0,2" "2,2"]]]
}

th::section "partial coverage is refused, and named for what it is"
th::test "a trimmed result (gaps) is refused with an explanatory message" {
    # HELM trimming discards whole clusters, so its label CSV covers only the
    # surviving frames while the indices still span the full trajectory.
    set p [write_labels [list "# trimmed" "# frame_index,cluster_index" \
        "0,0" "1,0" "5,1"]]
    th::throws {::mdance::read_labels_file $p} "*TRIMMED*"
}
th::test "the message reports how many frames are unlabelled" {
    set p [write_labels [list "# f" "# frame_index,cluster_index" "0,0" "3,1"]]
    th::throws {::mdance::read_labels_file $p} "*2 frame(s) in 0..3 unlabelled*"
}
th::test "a duplicated frame index is refused" {
    set p [write_labels [list "# f" "# frame_index,cluster_index" "0,0" "1,1" "0,2"]]
    th::throws {::mdance::read_labels_file $p} "*frame 0 is listed twice*"
}
th::test "a negative frame index is refused" {
    th::throws {::mdance::read_labels_file [write_labels {frame,cluster -1,0}]} \
        "*negative frame index*"
}

th::section "malformed tables are refused rather than half-read"
th::test "three columns is not a label file" {
    th::throws {::mdance::read_labels_file [write_labels {0,1,2}]} \
        "*comma-separated*"
}
th::test "a ragged table is refused" {
    th::throws {::mdance::read_labels_file [write_labels {0,1 2}]} \
        "*not one consistent table*"
}

th::section "whitespace and blank lines are tolerated"
th::test "padded fields and blank lines do not break the reader" {
    set p [write_labels [list "# h" " 0 , 4 " "" "1,5" ""]]
    th::eq {4 5} [::mdance::read_labels_file $p]
}

::mdance::utils::cleanup
exit [th::done "unit:labels_io"]
