#
# VMDance - the plots of the frames' groups and of the coordinates: the
# clusters' make-up by group, the map (the frames on their first two
# principal components) and the profiles (atom by atom: each group's or
# cluster's fluctuations, each cluster's mean structure against one's)
#
# The groups are the frames' origins (the method, replica or condition
# each came from: Results::groups), each in a colour of its own, distinct
# from the clusters'. The map and the profiles are computed when asked
# (Results ▸ Map, Profiles; vmdance map, profiles) and kept with their run.
#

# A group's colour (g its index; -1: none, grey): its own, else the
# palette's (Results::group_colour).
# (past the palette's ten its colours come again: lighter the second
# time, darker the third, unless the group was given one of its own)
proc ::VMDance::Plots::gcol {g} {
    variable noise_col
    if {$g eq "" || $g < 0} { return $noise_col }
    set col [::VMDance::Results::group_colour $g]
    set n [llength $::VMDance::Results::group_palette]
    if {$g < $n || [lindex [::VMDance::_get [::VMDance::Results::extra groups] colours {}] $g] ne ""} { return $col }
    _again $col [expr {$g / $n}]
}
# A colour of a palette used again (round 1, 2 …): lighter, then darker,
# so that two clusters or groups of one hue can be told apart.
proc ::VMDance::Plots::_again {col round} {
    if {$round % 2} { return [::VMDance::Cmap::tint $col 0.45] }
    scan $col "#%2x%2x%2x" r g b
    format "#%02x%02x%02x" [expr {int($r * 0.6)}] [expr {int($g * 0.6)}] [expr {int($b * 0.6)}]
}

proc ::VMDance::Plots::_no_groups {c} {
    ::VMDance::Plot::empty $c "No groups" "Results ▸ Groups: give each frame the method, replica or condition it came from (vmdance groups -ranges …)."
}

#---------------------------------------------------------------------------
# Make-up: each cluster's frames by group, or each group's by cluster
#---------------------------------------------------------------------------

# The make-up matrix (clusters × groups), made once a clustering.
proc ::VMDance::Plots::_makeup {} {
    ::VMDance::Results::memo makeup {
        ::VMDance::Measure::makeup [::VMDance::Results::labels] [::VMDance::Results::group_of] \
            [::VMDance::Results::nclusters] [llength [::VMDance::Results::group_names]]
    }
}

proc ::VMDance::Plots::draw_makeup {c} {
    variable H
    set names [::VMDance::Results::group_names]
    if {![llength $names]} { _no_groups $c; return }
    set M [_makeup]
    set k [K]
    set ng [llength $names]
    set share [expr {[S mu_show] eq "share"}]
    set by_group [expr {[S mu_view] eq "groups"}]
    # bars: {category label {{part count colour} ...}}
    set bars {}
    if {$by_group} {
        for {set g 0} {$g < $ng} {incr g} {
            set parts {}
            for {set cl 0} {$cl < $k} {incr cl} { lappend parts [list $cl [lindex $M $cl $g] [ccol $cl]] }
            lappend bars [list $g [lindex $names $g] $parts]
        }
        set items {}
        for {set cl 0} {$cl < min($k, 24)} {incr cl} { lappend items "cluster $cl" [ccol $cl 0] }
        if {$k > 24} { lappend items "… [expr {$k - 24}] more" @none }
        set xlab "Group"
        set ylab [expr {$share ? "Share of the group's frames (%)" : "Frames"}]
    } else {
        for {set cl 0} {$cl < $k} {incr cl} {
            set parts {}
            for {set g 0} {$g < $ng} {incr g} { lappend parts [list $g [lindex $M $cl $g] [gcol $g]] }
            lappend bars [list $cl $cl $parts]
        }
        set items {}
        for {set g 0} {$g < $ng} {incr g} { lappend items [lindex $names $g] [gcol $g] }
        set xlab "Cluster"
        set ylab [expr {$share ? "Share of the cluster's frames (%)" : "Frames"}]
    }
    set top 0
    foreach b $bars {
        set tot [::tcl::mathop::+ 0 {*}[lmap p [lindex $b 2] {lindex $p 1}]]
        if {$tot > $top} { set top $tot }
    }
    if {$share} { set top 100 }
    if {$top <= 0} { set top 1 }
    set n [llength $bars]
    set ml [::VMDance::Plot::ml]
    set mt [_legend_margin $c $items $ml 18]
    # (shares end at 100: nothing is above it but each bar's frames, written there)
    ::VMDance::Plot::setup $c -0.5 [expr {$n - 0.5}] 0 [expr {$share ? 100 : $top * 1.1}] \
        [list $ml [expr {$share ? $mt + [::VMDance::Plot::lh] + 2 : $mt}] 18 [::VMDance::Plot::mb]]
    set xt {}
    for {set i 0} {$i < $n} {incr i} { lappend xt $i }
    ::VMDance::Plot::axes $c $xlab $ylab $xt auto [dict merge [gridopt] [dict create xfmt [_catfmt [lmap b $bars {lindex $b 1}]] dense [expr {$n > 40}]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set bw [expr {max(2.0, 0.72 * ($x1 - $x0) / $n)}]
    set hit {}
    set i 0
    foreach b $bars {
        lassign $b cat lab parts
        set tot [::tcl::mathop::+ 0 {*}[lmap p $parts {lindex $p 1}]]
        set cx [::VMDance::Plot::X $c $i]
        set xa [expr {$cx - $bw / 2.0}]; set xb [expr {$cx + $bw / 2.0}]
        set acc 0.0
        set segs {}
        set sel [expr {!$by_group && [on $cat]}]
        foreach p $parts {
            lassign $p part cnt col
            if {$cnt <= 0} continue
            set v [expr {$share ? 100.0 * $cnt / $tot : $cnt}]
            set ya [::VMDance::Plot::Y $c $acc]; set yb [::VMDance::Plot::Y $c [expr {$acc + $v}]]
            set psel [expr {$by_group && [on $part]}]
            # (a slice thinner than 3 pixels has no white outline: of
            # hundreds of clusters the outlines were all that showed)
            $c create rectangle $xa $yb $xb $ya -fill $col -outline [expr {$psel ? "#111111" : ($ya - $yb >= 3 && $bw >= 4 ? "white" : "")}] \
                -width [expr {$psel ? 2 : 1}] -tags bar
            lappend segs [list $yb $ya $part $cnt]
            set acc [expr {$acc + $v}]
        }
        if {$sel} { $c create rectangle $xa [::VMDance::Plot::Y $c $acc] $xb [::VMDance::Plot::Y $c 0] -outline #111111 -width 2 -tags bar }
        # (the bar's frames above it: of shares too, where a bar of 16
        # frames is as tall as one of 3000)
        foreach t [list [expr {$share ? "n = $tot" : $tot}] $tot] {
            if {$bw < [font measure MdvSmall $t] + 2} continue
            $c create text $cx [expr {[::VMDance::Plot::Y $c $acc] - 3}] -text $t -anchor s -font MdvSmall -fill [theme text] -tags label
            break
        }
        lappend hit [list $xa $xb $cat $tot $segs]
        incr i
    }
    _legend $c $items [list $x0 $x1]
    set H($c,makeup) $hit
}
# The bar and segment under the pointer: {category part} ("" outside).
proc ::VMDance::Plots::_makeup_at {c x y} {
    variable H
    if {![info exists H($c,makeup)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set px [expr {$x + 0.5}]
    foreach b $H($c,makeup) {
        lassign $b xa xb cat tot segs
        if {$px <= $xa - 2 || $px > $xb + 2} continue
        set part ""
        foreach s $segs { lassign $s yb ya p; if {$y >= $yb && $y <= $ya} { set part $p } }
        return [list $cat $part]
    }
    return ""
}
proc ::VMDance::Plots::hover_makeup {c x y} {
    set at [_makeup_at $c $x $y]
    if {$at eq ""} { return "" }
    lassign $at cat part
    set names [::VMDance::Results::group_names]
    set M [_makeup]
    # (the slice under the pointer first, then the bar's largest: a bar of
    # 60 clusters listed them all, and the line was cut after five)
    if {[S mu_view] eq "groups"} {
        set col [lmap row $M {lindex $row $cat}]
        set tot [::tcl::mathop::+ 0 {*}$col]
        set s ""
        if {$part ne "" && $tot} { set s [format "cluster %d: %d of %s's %d frames (%.1f%%) · " $part [lindex $col $part] [lindex $names $cat] $tot [expr {100.0 * [lindex $col $part] / $tot}]] }
        append s "[lindex $names $cat]: $tot frames clustered"
        set l {}
        set cl 0
        foreach n $col { if {$n} { lappend l [list $cl $n] }; incr cl }
        set l [lsort -integer -decreasing -index 1 $l]
        set w [lmap p [lrange $l 0 4] {format "%d in cluster %d (%.0f%%)" [lindex $p 1] [lindex $p 0] [expr {100.0 * [lindex $p 1] / $tot}]}]
        if {[llength $l] > 5} { lappend w "… [expr {[llength $l] - 5}] more" }
        if {[llength $w]} { append s " — [join $w {, }]" }
        return $s
    }
    set row [lindex $M $cat]
    set tot [::tcl::mathop::+ 0 {*}$row]
    set s ""
    if {$part ne "" && $tot} { set s [format "%s: %d of cluster %d's %d frames (%.1f%%) · " [lindex $names $part] [lindex $row $part] $cat $tot [expr {100.0 * [lindex $row $part] / $tot}]] }
    append s "cluster $cat: $tot frames with a group"
    set l {}
    set g 0
    foreach n $row { if {$n} { lappend l [list $g $n] }; incr g }
    set l [lsort -integer -decreasing -index 1 $l]
    set w [lmap p [lrange $l 0 4] {format "%s %d (%.0f%%)" [lindex $names [lindex $p 0]] [lindex $p 1] [expr {100.0 * [lindex $p 1] / $tot}]}]
    if {[llength $l] > 5} { lappend w "… [expr {[llength $l] - 5}] more" }
    if {[llength $w]} { append s " — [join $w {, }]" }
    return $s
}
proc ::VMDance::Plots::click_makeup {c x y add} {
    set at [_makeup_at $c $x $y]
    if {$at eq ""} return
    lassign $at cat part
    _click_cluster [expr {[S mu_view] eq "groups" ? $part : $cat}] $add
}
proc ::VMDance::Plots::dclick_makeup {c x y} {
    set at [_makeup_at $c $x $y]
    if {$at eq ""} return
    lassign $at cat part
    set cl [expr {[S mu_view] eq "groups" ? $part : $cat}]
    if {$cl ne "" && $cl >= 0} { ::VMDance::GUI::goto_cluster $cl }
}

#---------------------------------------------------------------------------
# Map: the frames on their first two principal components
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_map {c} {
    variable H
    set m [::VMDance::Results::extra map]
    if {![dict size $m]} {
        ::VMDance::Plot::empty $c "No map" "Results ▸ Map: the frames on their first two principal components (vmdance map)."
        return
    }
    set xs [dict get $m pc1]; set ys [dict get $m pc2]
    set labels [::VMDance::Results::labels]
    set by_group [expr {[S mp_colour] eq "group" && [llength [::VMDance::Results::group_names]]}]
    set gs [::VMDance::Results::group_of]
    set names [::VMDance::Results::group_names]
    set items {}
    if {$by_group} {
        set g 0
        foreach nm $names { lappend items $nm [gcol $g]; incr g }
        if {-1 in $gs} { lappend items "no group" [gcol -1] }
    } else {
        for {set cl 0} {$cl < min([K], 24)} {incr cl} { lappend items "cluster $cl" [ccol $cl 0] }
        if {[K] > 24} { lappend items "… [expr {[K] - 24}] more" @none }
        if {[::VMDance::Results::noise]} { lappend items noise [ccol -1] }
    }
    set lo1 [::tcl::mathfunc::min {*}$xs]; set hi1 [::tcl::mathfunc::max {*}$xs]
    set lo2 [::tcl::mathfunc::min {*}$ys]; set hi2 [::tcl::mathfunc::max {*}$ys]
    set p1 [expr {($hi1 - $lo1) * 0.05 + 1e-9}]; set p2 [expr {($hi2 - $lo2) * 0.05 + 1e-9}]
    set lo1 [expr {$lo1 - $p1}]; set hi1 [expr {$hi1 + $p1}]; set lo2 [expr {$lo2 - $p2}]; set hi2 [expr {$hi2 + $p2}]
    set ml [::VMDance::Plot::ml]
    set mb [::VMDance::Plot::mb]
    # (asked for the groups' colours of frames that have no groups: said)
    set note [expr {[S mp_colour] eq "group" && !$by_group ? "no groups (Results ▸ Groups): coloured by cluster" : ""}]
    set mt [_legend_margin $c $items $ml 18]
    if {$note ne ""} { set mt [expr {max($mt, [::VMDance::Plot::note_margin]) + ([S plot_legend] && [llength $items] ? [::VMDance::Plot::rowh] : 0)}] }
    # the two components to one scale, an ångström as long on both (they
    # are distances: stretched to fill the pane, a round cloud looked long):
    # the axis with room to spare shows more of it
    lassign [::VMDance::Plot::size $c] W Hh
    set aw [expr {max(10.0, $W - $ml - 18)}]; set ah [expr {max(10.0, $Hh - $mt - $mb)}]
    set scale [expr {min($aw / ($hi1 - $lo1), $ah / ($hi2 - $lo2))}]
    set e1 [expr {($aw / $scale - ($hi1 - $lo1)) / 2.0}]; set e2 [expr {($ah / $scale - ($hi2 - $lo2)) / 2.0}]
    ::VMDance::Plot::setup $c [expr {$lo1 - $e1}] [expr {$hi1 + $e1}] [expr {$lo2 - $e2}] [expr {$hi2 + $e2}] [list $ml $mt 18 $mb]
    lassign [dict get $m variance] v1 v2
    ::VMDance::Plot::axes $c [format "PC1 (Å; %.0f%% of the variance)" [expr {100 * $v1}]] \
        [format "PC2 (Å; %.0f%%)" [expr {100 * $v2}]] auto auto [gridopt]
    # the order the frames are drawn in: noise first, the selected
    # clusters' frames last, the others mixed (by group or by cluster one
    # after another, the last drawn covered the rest: every dense spot
    # looked like the first group's)
    set order {}
    set i 0
    foreach l $labels {
        set top [expr {$l < 0 ? -1 : ([on $l] ? 1 : 0)}]
        lappend order [list $top [expr {($i * 2654435761) % 4294967296}] $i]
        incr i
    }
    set order [lsort -integer -index 0 [lsort -integer -index 1 $order]]
    set n [llength $xs]
    # (the dots as large as their number and the plot's size allow: a
    # figure a column wide had three solid blobs)
    set r [expr {max(0.6, min(3.5, 0.25 * sqrt($aw * $ah / max(1, $n))))}]
    set cell 8
    array unset H $c,mapcell,*
    set sel [selected]
    foreach o $order {
        set i [lindex $o 2]
        set l [lindex $labels $i]
        set col [expr {$by_group ? [gcol [lindex $gs $i]] : [ccol $l]}]
        if {$by_group && [llength $sel] && ($l < 0 || $l ni $sel)} { set col [::VMDance::Cmap::tint $col 0.6] }
        set px [::VMDance::Plot::X $c [lindex $xs $i]]; set py [::VMDance::Plot::Y $c [lindex $ys $i]]
        $c create oval [expr {$px - $r}] [expr {$py - $r}] [expr {$px + $r}] [expr {$py + $r}] -fill $col -outline "" -tags point
        lappend H($c,mapcell,[expr {int($px / $cell)}],[expr {int($py / $cell)}]) [list $px $py $i]
    }
    # each cluster's representative: ringed, with its number while they are few
    if {[S mp_reps]} {
        set k [K]
        for {set cl 0} {$cl < $k} {incr cl} {
            set i [lindex [::VMDance::Results::get representatives] $cl]
            if {$i eq "" || $i < 0} continue
            set px [::VMDance::Plot::X $c [lindex $xs $i]]; set py [::VMDance::Plot::Y $c [lindex $ys $i]]
            set rr [expr {max(4.0, $r + 3.0)}]
            $c create oval [expr {$px - $rr}] [expr {$py - $rr}] [expr {$px + $rr}] [expr {$py + $rr}] -fill [ccol $cl 0] \
                -outline [expr {[on $cl] ? "#111111" : "white"}] -width 1.5 -tags rep
            $c create oval [expr {$px - $rr - 1.5}] [expr {$py - $rr - 1.5}] [expr {$px + $rr + 1.5}] [expr {$py + $rr + 1.5}] -outline #20242c -tags rep
            if {$k <= 30} {
                $c create text [expr {$px + $rr + 4}] $py -text $cl -anchor w -font MdvBold -fill #20242c -tags rep
            }
        }
    }
    if {$note ne ""} { ::VMDance::Plot::note $c $note }
    _legend $c $items [list [lindex [::VMDance::Plot::area $c] 0] [lindex [::VMDance::Plot::area $c] 2]]
    set H($c,map) 1
}
# The frame (row) nearest the pointer, within 6 pixels ("" none).
proc ::VMDance::Plots::_map_at {c x y} {
    variable H
    if {![info exists H($c,map)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set cell 8
    set cx [expr {int($x / $cell)}]; set cy [expr {int($y / $cell)}]
    set best ""; set bd 6.0
    foreach dx {-1 0 1} {
        foreach dy {-1 0 1} {
            set key $c,mapcell,[expr {$cx + $dx}],[expr {$cy + $dy}]
            if {![info exists H($key)]} continue
            foreach p $H($key) {
                lassign $p px py i
                set d [expr {hypot($px - $x, $py - $y)}]
                if {$d <= $bd} { set bd $d; set best $i }
            }
        }
    }
    return $best
}
proc ::VMDance::Plots::hover_map {c x y} {
    set i [_map_at $c $x $y]
    if {$i eq ""} { return "" }
    set m [::VMDance::Results::extra map]
    set l [lindex [::VMDance::Results::labels] $i]
    set s "frame [lindex [::VMDance::Results::frames] $i]: [expr {$l < 0 ? "noise" : "cluster $l"}]"
    set g [lindex [::VMDance::Results::group_of] $i]
    if {$g ne "" && $g >= 0} { append s ", [lindex [::VMDance::Results::group_names] $g]" }
    append s [format "; PC1 %.3g Å, PC2 %.3g Å · click = go to it" [lindex [dict get $m pc1] $i] [lindex [dict get $m pc2] $i]]
}
proc ::VMDance::Plots::click_map {c x y add} {
    set i [_map_at $c $x $y]
    if {$i eq ""} return
    set l [lindex [::VMDance::Results::labels] $i]
    ::VMDance::GUI::goto_frame [lindex [::VMDance::Results::frames] $i]
    if {$l >= 0} { ::VMDance::GUI::select [list $l] $add }
}

#---------------------------------------------------------------------------
# Profiles: atom by atom (residue by residue)
#---------------------------------------------------------------------------

# The profiles residue by residue: {residues chains lists} where lists are
# the views' curves, each value the root mean square over the residue's
# atoms (one atom a residue, the Cα: the atom's own); a residue is a run of
# atoms with one number and chain.
proc ::VMDance::Plots::_by_residue {p key} {
    ::VMDance::Results::memo profiles_$key {
        set res {}; set chs {}; set spans {}
        set prev ""
        set i 0
        foreach r [dict get $p residues] ch [dict get $p chains] {
            if {"$r $ch" ne $prev} {
                if {$prev ne ""} { lappend spans [list $start [expr {$i - 1}]] }
                lappend res $r; lappend chs $ch
                set start $i
                set prev "$r $ch"
            }
            incr i
        }
        lappend spans [list $start [expr {$i - 1}]]
        set out {}
        foreach l [dict get $p $key] {
            if {$l eq ""} { lappend out ""; continue }
            lappend out [lmap s $spans {
                lassign $s a b
                set q 0.0
                foreach v [lrange $l $a $b] { set q [expr {$q + $v * $v}] }
                expr {sqrt($q / ($b - $a + 1))}
            }]
        }
        list $res $chs $out
    }
}

proc ::VMDance::Plots::draw_profiles {c} {
    variable H
    set p [::VMDance::Results::extra profiles]
    if {![dict size $p]} {
        ::VMDance::Plot::empty $c "No profiles" "Results ▸ Profiles: atom by atom, each group's and cluster's fluctuations, and each cluster's mean structure against the most populated one's (vmdance profiles)."
        return
    }
    set view [S pf_show]
    set ref [dict get $p reference]
    set names [dict get $p group_names]
    if {$view eq "groups" && ![llength $names]} { set view clusters }
    switch -- $view {
        groups {
            lassign [_by_residue $p groups] res chs curves
            set series {}
            set g 0
            foreach cv $curves nm $names { if {$cv ne ""} { lappend series [list $nm [gcol $g] $cv 0] }; incr g }
            set ylab "RMSF (Å)"
        }
        differences {
            lassign [_by_residue $p differences] res chs curves
            set series {}
            set cl 0
            foreach cv $curves {
                if {$cv ne "" && $cl != $ref} { lappend series [list "cluster $cl" [ccol $cl] $cv $cl] }
                incr cl
            }
            set ylab "Distance from cluster $ref (Å)"
        }
        default {
            lassign [_by_residue $p clusters] res chs curves
            set series {}
            set cl 0
            foreach cv $curves { if {$cv ne ""} { lappend series [list "cluster $cl" [ccol $cl] $cv $cl] }; incr cl }
            set ylab "RMSF (Å)"
        }
    }
    if {![llength $series]} {
        set why [::VMDance::_get {groups "No group has clustered frames." differences "Another cluster than the reference is needed: this clustering has no other with frames."} $view "No cluster has frames."]
        ::VMDance::Plot::empty $c "Nothing to draw" $why
        return
    }
    # more than a dozen clusters' curves: in colour the selected ones, or
    # the eight largest when none is; the others grey behind them (sixty
    # thin lines in hues that come again could not be told apart)
    set sel [selected]
    set many [expr {$view ne "groups" && [llength $series] > 12}]
    set lit {}
    set note ""
    if {$many} {
        foreach s $series { if {[lindex $s 3] in $sel} { lappend lit [lindex $s 3] } }
        if {[llength $lit]} {
            set note "in colour: the selected cluster[expr {[llength $lit] == 1 ? "" : "s"}] of [llength $series]"
        } else {
            set by [lsort -integer -decreasing -index 1 [lmap s $series {list [lindex $s 3] [::VMDance::Results::size [lindex $s 3]]}]]
            set lit [lmap p [lrange $by 0 7] {lindex $p 0}]
            set note "in colour: the 8 largest clusters of [llength $series] (select others to colour them)"
        }
    }
    set items {}
    foreach s $series {
        if {$many && [lindex $s 3] ni $lit} continue
        if {[llength $items] >= 48} break
        lappend items [lindex $s 0] [expr {$view eq "groups" ? [lindex $s 1] : [ccol [lindex $s 3] 0]}]
    }
    set top 0.0
    foreach s $series { set top [expr {max($top, [::tcl::mathfunc::max {*}[lindex $s 2]])}] }
    if {$top <= 0} { set top 1.0 }
    set nr [llength $res]
    set ml [::VMDance::Plot::ml]
    set mt [_legend_margin $c $items $ml 18]
    if {$note ne ""} { set mt [expr {max($mt, [::VMDance::Plot::note_margin]) + ([S plot_legend] && [llength $items] ? [::VMDance::Plot::rowh] : 0)}] }
    ::VMDance::Plot::setup $c -0.5 [expr {$nr - 0.5}] 0 [expr {$top * 1.08}] [list $ml $mt 18 [::VMDance::Plot::mb]]
    # (ticks: residues' numbers at their positions, the chain when there are
    # several; at round numbers, 50, 100 …, not at every 50th residue from
    # the first, 1, 51, 101 …)
    set multi [expr {[llength [lsort -unique $chs]] > 1}]
    set labs [lmap r $res ch $chs {expr {$multi ? "$ch$r" : $r}}]
    set xt auto
    set whole 1
    foreach r $res { if {![string is integer -strict $r]} { set whole 0; break } }
    if {$whole && $nr > 1} {
        set room [expr {max(2, int(([lindex [::VMDance::Plot::size $c] 0] - $ml - 18) / 55.0))}]
        foreach step {1 2 5 10 20 25 50 100 200 250 500 1000 2000 5000} { if {$nr / double($step) <= $room} break }
        set xt {}
        set i 0
        foreach r $res { if {$r % $step == 0} { lappend xt $i }; incr i }
        if {[llength $xt] < 2} { set xt auto }
    }
    ::VMDance::Plot::axes $c "Residue" $ylab $xt auto [dict merge [gridopt] [dict create xfmt [_catfmt $labs] dense [expr {$xt ne "auto" && [llength $xt] > 40}]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    # chain breaks: a dotted line between chains
    for {set i 1} {$i < $nr} {incr i} {
        if {[lindex $chs $i] ne [lindex $chs [expr {$i - 1}]]} {
            set px [::VMDance::Plot::X $c [expr {$i - 0.5}]]
            $c create line $px $y0 $px $y1 -fill [theme muted] -dash {2 3} -tags grid
        }
    }
    # (the groups' curves, a few dark tones, a little heavier)
    set w [expr {$view eq "groups" ? [lw] + 0.6 : [lw]}]
    # (the selected clusters drawn last and thicker; the others paler when
    # some are; the grey ones of many first)
    set series [lsort -integer -index 0 [lmap s $series {
        set cl [lindex $s 3]
        set grey [expr {$many && $cl ni $lit}]
        if {$grey} { lset s 1 #d3d7de }
        list [expr {$grey ? -1 : ($view ne "groups" && $cl in $sel)}] {*}$s
    }]]
    foreach s $series {
        lassign $s raised lab col cv cl
        if {$raised < 0} { set raised 0 }
        # a line per run of residues of one chain whose numbers follow
        set pts {}
        set i 0
        foreach v $cv r $res ch $chs {
            if {$i > 0 && ($ch ne [lindex $chs [expr {$i - 1}]] || ![string is integer -strict $r] ||
                           ![string is integer -strict [lindex $res [expr {$i - 1}]]] || $r != [lindex $res [expr {$i - 1}]] + 1)} {
                if {[llength $pts] >= 4} { $c create line {*}$pts -fill $col -width [expr {$raised ? $w + 1.2 : $w}] -tags series }
                set pts {}
            }
            lappend pts [::VMDance::Plot::X $c $i] [::VMDance::Plot::Y $c $v]
            incr i
        }
        if {[llength $pts] >= 4} {
            $c create line {*}$pts -fill $col -width [expr {$raised ? $w + 1.2 : $w}] -tags series
        } elseif {[llength $pts] == 2} {
            lassign $pts px py
            $c create oval [expr {$px - 2}] [expr {$py - 2}] [expr {$px + 2}] [expr {$py + 2}] -fill $col -outline "" -tags series
        }
    }
    if {$note ne ""} { ::VMDance::Plot::note $c $note }
    _legend $c $items [list $x0 $x1]
    set H($c,profiles) [list $view $res $chs [lmap s $series {lrange $s 1 4}]]
}
# The residue (its index) and the curve nearest the pointer, within 12
# pixels: {i series} ("" outside the plot; series "" when none is near).
proc ::VMDance::Plots::_profile_at {c x y} {
    variable H
    if {![info exists H($c,profiles)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    lassign $H($c,profiles) view res chs series
    set i [expr {int(round([::VMDance::Plot::invX $c $x]))}]
    if {$i < 0 || $i >= [llength $res]} { return "" }
    set best ""; set bd 12.0
    foreach se $series {
        set d [expr {abs([::VMDance::Plot::Y $c [lindex $se 2 $i]] - $y)}]
        if {$d < $bd} { set bd $d; set best $se }
    }
    list $i $best
}
proc ::VMDance::Plots::hover_profiles {c x y} {
    variable H
    set at [_profile_at $c $x $y]
    if {$at eq ""} { return "" }
    lassign $at i near
    lassign $H($c,profiles) view res chs series
    set s "residue [lindex $res $i][expr {[llength [lsort -unique $chs]] > 1 ? " (chain [lindex $chs $i])" : ""}]:"
    # (the curve under the pointer first; all of them while they are few)
    if {$near ne ""} { append s [format " %s %.2f Å" [lindex $near 0] [lindex $near 2 $i]] }
    if {[llength $series] <= 6} {
        set l {}
        foreach se $series { if {$se ne $near} { lappend l [format "%s %.2f Å" [lindex $se 0] [lindex $se 2 $i]] } }
        if {[llength $l]} { append s "[expr {$near ne "" ? " ·" : ""}] [join $l {, }]" }
    } elseif {$near eq ""} {
        append s " [llength $series] curves (point at one)"
    }
    if {$near ne "" && $view ne "groups"} { append s " · click = select it" }
    return $s
}
# A click on a cluster's curve selects the cluster.
proc ::VMDance::Plots::click_profiles {c x y add} {
    variable H
    set at [_profile_at $c $x $y]
    if {$at eq "" || [lindex $at 1] eq ""} return
    if {[lindex $H($c,profiles) 0] eq "groups"} return
    _click_cluster [lindex $at 1 3] $add
}
