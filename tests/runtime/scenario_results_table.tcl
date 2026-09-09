# Runtime scenario: the Results tab's sortable cluster table, the multi-frame
# overlay, the top-frames export, and Clear Results.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
::mdance::gui::create_window
set ::mdance::gui::mol_selection $mol
set ::mdance::gui::atom_selection "name CA"

set params [dict create molid $mol atomsel "name CA" nclusters 2 \
    metric MSD kinit StratAll percentage 10 first 0 last -1 stride 1]
::mdance::run_clustering kmeans $params
::mdance::gui::update_results_tab

set TV .mdance.nb.results.table.list.tv

# ------------------------------------------------------------------
th::section "The cluster table is a treeview with an MSD column"
# ------------------------------------------------------------------
th::test "one row per cluster, keyed by cluster index" {
    th::eq 2 [llength [$TV children {}]]
    th::eq {0 1} [$TV children {}] "the item id must BE the cluster index"
}
th::test "the columns include MSD" {
    th::eq {id size pct msd rep} [$TV cget -columns]
    th::eq "MSD" [$TV heading msd -text]
}
th::test "the MSD cell carries the per-cluster MSD from the result" {
    set msds [dict get $::mdance::results clusterMSD]
    for {set i 0} {$i < 2} {incr i} {
        th::near [lindex $msds $i] [$TV set $i msd] 0.0001
    }
}
th::test "numeric cells are bare numbers so they sort numerically" {
    # A formatted "20.2%" would fall back to a lexical sort that puts 9 after 10.
    foreach col {id size pct} {
        th::true [string is double -strict [$TV set 0 $col]] \
            "$col must be a bare number"
    }
}
th::test "sizes and percentages agree with the result" {
    set sizes [dict get $::mdance::results clusterSizes]
    set nf [dict get $::mdance::results nFrames]
    for {set i 0} {$i < 2} {incr i} {
        th::eq [lindex $sizes $i] [$TV set $i size]
        th::near [expr {100.0 * [lindex $sizes $i] / $nf}] [$TV set $i pct] 0.05
    }
}
th::test "a result with no clusterMSD shows n/a instead of failing" {
    set saved $::mdance::results
    set ::mdance::results [dict remove $saved clusterMSD]
    th::ok { ::mdance::gui::update_results_tab }
    th::eq "n/a" [$TV set 0 msd]
    # ...and the MSD-dependent plots go back to disabled.
    th::true [.mdance.nb.figures.plots.msd instate disabled]
    set ::mdance::results $saved
    ::mdance::gui::update_results_tab
}

# ------------------------------------------------------------------
th::section "Columns sort, and a selection still means the same cluster"
# ------------------------------------------------------------------
th::test "sorting by size orders the rows numerically" {
    ::mdance::gui::sort_cluster_table size
    set order {}
    foreach it [$TV children {}] { lappend order [$TV set $it size] }
    th::eq [lsort -real $order] $order "ascending on the first click"
}
th::test "clicking the same column again reverses it" {
    ::mdance::gui::sort_cluster_table size
    set order {}
    foreach it [$TV children {}] { lappend order [$TV set $it size] }
    th::eq [lsort -real -decreasing $order] $order
}
th::test "an n/a MSD column sorts without error" {
    set saved $::mdance::results
    set ::mdance::results [dict remove $saved clusterMSD]
    ::mdance::gui::update_results_tab
    th::ok { ::mdance::gui::sort_cluster_table msd }
    set ::mdance::results $saved
    ::mdance::gui::update_results_tab
}
th::test "Go to Representative follows the SELECTED cluster, not the row position" {
    # The old listbox returned a row index, so this silently pointed at the
    # wrong cluster the moment any column was sorted.
    ::mdance::gui::sort_cluster_table size
    ::mdance::gui::sort_cluster_table size          ;# descending
    set first [lindex [$TV children {}] 0]
    $TV selection set $first
    th::eq $first [::mdance::gui::selected_cluster] \
        "the reported cluster must be the item id, whatever row it sits in"
    # And it really navigates to that cluster's representative.
    set want [::mdance::abs_frame $::mdance::results \
        [lindex [dict get $::mdance::results representatives] $first]]
    ::mdance::gui::goto_selected_rep
    th::eq $want [molinfo $mol get frame]
}
th::test "with nothing selected the selection reader reports empty" {
    $TV selection remove [$TV children {}]
    th::eq "" [::mdance::gui::selected_cluster 1]
}

# ------------------------------------------------------------------
th::section "top_frames ranks a cluster's frames by MSD from its medoid"
# ------------------------------------------------------------------
th::test "the representative itself ranks first" {
    set rep [::mdance::abs_frame $::mdance::results \
        [lindex [dict get $::mdance::results representatives] 0]]
    th::eq $rep [lindex [::mdance::top_frames $::mdance::results 0 5] 0]
}
th::test "N=1 yields the medoid alone" {
    th::eq 1 [llength [::mdance::top_frames $::mdance::results 0 1]]
}
th::test "every returned frame really belongs to that cluster" {
    set labels [dict get $::mdance::results labels]
    foreach af [::mdance::top_frames $::mdance::results 1 6] {
        set sample [lsearch -exact [dict get $::mdance::results frames] $af]
        th::eq 1 [lindex $labels $sample] "frame $af must be in cluster 1"
    }
}
th::test "asking for more frames than the cluster holds returns what exists" {
    set n [lindex [dict get $::mdance::results clusterSizes] 0]
    th::eq $n [llength [::mdance::top_frames $::mdance::results 0 9999]]
}
th::test "the ranking is by ascending MSD from the representative" {
    # Recompute independently and compare the ordering.
    set frames [::mdance::top_frames $::mdance::results 0 99]
    set sel [atomselect $mol "name CA"]
    set natoms [$sel num]
    set ref {}
    foreach a [::mdance::_frame_coords $sel "name CA" [lindex $frames 0] $natoms] {
        foreach v $a { lappend ref $v }
    }
    set prev -1
    foreach af $frames {
        set sum 0.0; set k 0
        foreach a [::mdance::_frame_coords $sel "name CA" $af $natoms] {
            foreach v $a {
                set d [expr {$v - [lindex $ref $k]}]
                set sum [expr {$sum + $d * $d}]; incr k
            }
        }
        set msd [expr {$sum / $natoms}]
        th::ge $msd $prev "MSD must not decrease along the ranking"
        set prev $msd
    }
    $sel delete
}
th::test "a bad cluster index is refused" {
    th::throws {::mdance::top_frames $::mdance::results 99 5} "*No such cluster*"
    th::throws {::mdance::top_frames $::mdance::results 0 0} "*at least 1*"
}
th::test "a result whose molecule is gone is refused with a clear message" {
    set orphan [dict replace $::mdance::results molid 987]
    th::throws {::mdance::top_frames $orphan 0 5} "*no longer loaded*"
}

# ------------------------------------------------------------------
th::section "The overlay owns exactly one representation"
# ------------------------------------------------------------------
th::test "showing an overlay adds one rep and draws the ranked frames" {
    ::mdance::gui::clear_overlay 1
    set before [molinfo $mol get numreps]
    $TV selection set 0
    set ::mdance::gui::overlay_m 4
    ::mdance::gui::show_cluster_overlay
    th::eq [expr {$before + 1}] [molinfo $mol get numreps]
    th::ne "" $::mdance::gui::overlay_rep
    set want [join [::mdance::top_frames $::mdance::results 0 4] ","]
    th::eq $want [mol drawframes $mol [::mdance::gui::overlay_index]]
}
th::test "the overlay is tracked by repname, so renumbering cannot misdirect it" {
    # VMD renumbers representations when one is deleted. With the overlay at
    # index 2 and a user rep at 3, deleting the user's rep 0 shifts the overlay
    # to 1 and the user's to 2 -- so a remembered index made "Clear Overlay"
    # delete the USER's representation and strand the overlay on screen.
    ::mdance::gui::clear_overlay 1
    while {[molinfo $mol get numreps] > 1} { mol delrep 1 $mol }
    mol addrep $mol                                   ;# user rep 1
    $TV selection set 0
    set ::mdance::gui::overlay_m 3
    ::mdance::gui::show_cluster_overlay                ;# overlay lands at 2
    th::eq 2 [::mdance::gui::overlay_index] "fixture check: overlay at index 2"
    mol addrep $mol                                   ;# user rep 3, after it
    set user_after [mol repname $mol 3]
    mol delrep 0 $mol                                 ;# user deletes their rep 0
    th::eq 1 [::mdance::gui::overlay_index] "the overlay is now at 1, not 2"
    set before [molinfo $mol get numreps]
    ::mdance::gui::clear_overlay 1
    th::eq [expr {$before - 1}] [molinfo $mol get numreps] "exactly one rep removed"
    # The user's later representation must have survived.
    set survivors {}
    for {set r 0} {$r < [molinfo $mol get numreps]} {incr r} {
        lappend survivors [mol repname $mol $r]
    }
    th::true [expr {[lsearch -exact $survivors $user_after] >= 0}] \
        "the user's own representation must NOT be the one deleted"
}
th::test "overlay_index reports empty once the molecule is gone" {
    set saved $::mdance::gui::overlay_molid
    set ::mdance::gui::overlay_rep "rep0"
    set ::mdance::gui::overlay_molid 987
    th::eq "" [::mdance::gui::overlay_index]
    th::ok { ::mdance::gui::clear_overlay 1 }
    set ::mdance::gui::overlay_molid $saved
}
th::test "showing a second overlay replaces the first rather than stacking" {
    ::mdance::gui::clear_overlay 1
    $TV selection set 0
    ::mdance::gui::show_cluster_overlay          ;# first overlay
    set before [molinfo $mol get numreps]
    $TV selection set 1
    ::mdance::gui::show_cluster_overlay          ;# second replaces it
    th::eq $before [molinfo $mol get numreps] "no rep leak per click"
}
th::test "clearing removes the overlay's rep and leaves the user's alone" {
    set before [molinfo $mol get numreps]
    ::mdance::gui::clear_overlay
    th::eq [expr {$before - 1}] [molinfo $mol get numreps]
    th::eq "" $::mdance::gui::overlay_rep
    th::ge [molinfo $mol get numreps] 1 "the molecule's original rep survives"
}
th::test "clearing twice is harmless" {
    th::ok { ::mdance::gui::clear_overlay 1 }
    th::ok { ::mdance::gui::clear_overlay 1 }
}
th::test "a range overlay draws exactly the requested frames" {
    set ::mdance::gui::overlay_ranges "0-3,10"
    ::mdance::gui::show_range_overlay
    th::eq "0,1,2,3,10" [mol drawframes $mol [::mdance::gui::overlay_index]]
    ::mdance::gui::clear_overlay 1
}
th::test "a malformed range is reported and draws nothing" {
    ::mdance::gui::clear_overlay 1
    set ::mdance::gui::overlay_ranges "nonsense"
    ::mdance::gui::show_range_overlay
    th::eq "" $::mdance::gui::overlay_rep "no overlay may be created"
}

# ------------------------------------------------------------------
th::section "Exporting the top frames of every cluster"
# ------------------------------------------------------------------
th::test "the CSV carries frame, cluster and rank for each cluster" {
    set out [::mdance::utils::mktmp "_top.csv"]
    set n [::mdance::export_top_frames $out $::mdance::results 3]
    set lines [read_lines $out]
    set data {}
    foreach l $lines { if {[string index $l 0] ne "#"} { lappend data $l } }
    th::eq "frame,cluster,rank" [lindex $data 0]
    th::eq $n [expr {[llength $data] - 1}]
    th::eq 6 $n "3 frames x 2 clusters"
    # Ranks restart at 0 for each cluster, and rank 0 is the representative.
    set reps [dict get $::mdance::results representatives]
    foreach l [lrange $data 1 end] {
        lassign [split $l ","] frame cluster rank
        if {$rank == 0} {
            th::eq [::mdance::abs_frame $::mdance::results [lindex $reps $cluster]] $frame
        }
    }
    catch {file delete $out}
}

# ------------------------------------------------------------------
th::section "Clear Results purges everything derived from the run"
# ------------------------------------------------------------------
th::test "it closes plot windows, empties the table and disables the plots" {
    ::mdance::plots::population_chart $::mdance::results
    th::true [winfo exists .mdance_pop] "fixture check: a plot window is open"
    # A plot window pins its own copy of the results dict for redraws.
    th::true [info exists ::mdance::plots::redraw_cmds(mdance_pop)]

    proc tk_messageBox {args} { return ok }      ;# confirm the purge
    ::mdance::gui::clear_results

    th::eq "" $::mdance::results
    th::eq 0 [llength [$TV children {}]]
    th::false [winfo exists .mdance_pop] "the plot window must be closed"
    th::false [info exists ::mdance::plots::redraw_cmds(mdance_pop)] \
        "and its cached results dict released"
    foreach b [::mdance::gui::_result_plot_buttons] {
        th::true [.mdance.nb.figures.plots.$b instate disabled] "$b must be disabled"
    }
    th::eq "-" [.mdance.nb.results.summary.v_nclust cget -text]
}
th::test "it drops the overlay and the PRIME / Frame Tools selections" {
    th::eq "" $::mdance::gui::overlay_rep
    th::eq "" $::mdance::gui::prime_results
    th::eq "" $::mdance::gui::ft_frames
}
th::test "clearing an already-empty session says so instead of confirming" {
    set ::CONFIRMED 0
    proc tk_messageBox {args} {
        if {[lsearch -exact $args "okcancel"] >= 0} { set ::CONFIRMED 1 }
        return ok
    }
    ::mdance::gui::clear_results
    th::eq 0 $::CONFIRMED "nothing to clear must not ask for confirmation"
}
th::test "declining the confirmation keeps the results" {
    ::mdance::run_clustering kmeans $params
    ::mdance::gui::update_results_tab
    proc tk_messageBox {args} { return cancel }
    ::mdance::gui::clear_results
    th::ne "" $::mdance::results "cancel must not purge"
    th::eq 2 [llength [$TV children {}]]
    proc tk_messageBox {args} { return ok }
}

exit [th::done "runtime:results_table"]
