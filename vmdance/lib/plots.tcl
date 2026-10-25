#
# VMDance - the plots
#
# Each plot draws the current clustering (Results) on a canvas, the
# selected clusters on top: draw_<key> draws it, hover_<key> returns the
# readout under the pointer, click_<key> selects clusters or goes to a
# frame, dclick_<key> does the plot's second action, cursor_<key> moves
# the current-frame marker. A cluster is drawn in a darker tone of its
# colour in VMD's 3D window (Viz::colour_hex), or in VMD's own RGB (Plot
# options ▸ Cluster colours); noise is grey. Rasters (the
# timeline, the matrices) are photo images, so that their cost follows the
# canvas and not the length of the trajectory. The elbow and the sweep
# plots draw the last scans (Results::elbow, sweep).
#

namespace eval ::VMDance::Plots {
    variable H              ;# hit-testing data, by canvas
    variable images         ;# canvas -> photo image
    variable ccache         ;# cluster colours while a plot is drawn
    variable drawing 0
    variable bg #ffffff
    variable accent #1f5fae
    variable ink #3b4250
    variable noise_col #a3a8b1
    # colours of the two scores
    variable ch_col #3f6fa8
    variable db_col #b0503f
}

proc ::VMDance::Plots::S {key} { set ::VMDance::GUI::S($key) }
proc ::VMDance::Plots::lw {} {
    set v [S plot_lw]
    expr {[string is double -strict $v] && $v > 0 ? $v : 1.4}
}
proc ::VMDance::Plots::gridopt {} { list grid [expr {[S plot_grid] ? 1 : 0}] }
proc ::VMDance::Plots::selected {} { ::VMDance::Results::selected }
proc ::VMDance::Plots::K {} { ::VMDance::Results::nclusters }
proc ::VMDance::Plots::theme {k} { set ::VMDance::Plot::theme($k) }

# The Tk colour of a VMD colour id (VMD's own RGB, so that the plots match
# the 3D window; a fixed palette without VMD). Read when asked: VMD tells
# no one when Graphics ▸ Colors changes one (ccol keeps it while a plot is
# drawn).
proc ::VMDance::Plots::vmd_colour {id} {
    if {[info commands colorinfo] ne "" && ![catch {colorinfo rgb $id} rgb] && [llength $rgb] == 3} {
        lassign $rgb r g b
        return [format "#%02x%02x%02x" [expr {int($r * 255)}] [expr {int($g * 255)}] [expr {int($b * 255)}]]
    }
    ::VMDance::Cmap::pick tableau $id 10
}
# VMD's colours of the clusters' ids and of noise, as they are now.
proc ::VMDance::Plots::vmd_colours {} {
    lmap id [list {*}$::VMDance::Viz::ids $::VMDance::Viz::noise_id] {vmd_colour $id}
}

# A cluster's colour: the plugin's darker tone of its hue, or (Plot
# options ▸ Cluster colours) VMD's colour of the 3D window; noise (-1, "")
# grey. With a selection, the clusters not in it are paler.
# (kept while a plot is drawn: a timeline asks it thousands of times)
proc ::VMDance::Plots::ccol {c {dim 1}} {
    variable ccache; variable drawing
    if {!$drawing} { return [_ccol $c $dim] }
    if {[info exists ccache($c,$dim)]} { return $ccache($c,$dim) }
    set ccache($c,$dim) [_ccol $c $dim]
}
proc ::VMDance::Plots::_ccol {c dim} {
    set vmd [expr {[info exists ::VMDance::GUI::S(plot_ccol)] && [S plot_ccol] eq "vmd"}]
    if {$c eq "" || $c < 0} {
        return [expr {$vmd ? [vmd_colour $::VMDance::Viz::noise_id] : $::VMDance::Viz::noise_hex}]
    }
    set col [expr {$vmd ? [vmd_colour [::VMDance::Viz::colour_id $c]] : [::VMDance::Viz::colour_hex $c]}]
    set sel [selected]
    if {$dim && [llength $sel] && $c ni $sel} { return [::VMDance::Cmap::tint $col 0.5] }
    return $col
}
proc ::VMDance::Plots::on {c} { expr {$c in [selected]} }
proc ::VMDance::Plots::clabel {c} { expr {$c < 0 ? "noise" : $c} }


proc ::VMDance::Plots::release_images {} {
    variable images
    foreach {c img} [array get images] { catch {image delete $img} }
    array unset images *
}
proc ::VMDance::Plots::release_image {c} {
    variable images
    if {[info exists images($c)]} {
        catch {image delete $images($c)}
        unset images($c)
    }
}
proc ::VMDance::Plots::_image {c w h} {
    variable images; variable bg
    if {![info exists images($c)] || $images($c) ni [image names]} {
        set images($c) [image create photo]
    }
    set img $images($c)
    $img blank
    $img configure -width $w -height $h
    $img put $bg -to 0 0 $w $h
    return $img
}

# Whether a plot draws scans rather than the clustering.
proc ::VMDance::Plots::needs {key} {
    switch -- $key {
        elbow { return elbow }
        sweep { return sweep }
        default { return clustering }
    }
}

# Whether a plot has something to draw (figures leave the others out):
# its scan, or a clustering, with a cluster unless it draws noise too.
proc ::VMDance::Plots::has_data {key} {
    switch -- [needs $key] {
        elbow { return [expr {[dict size $::VMDance::Results::elbow] > 0}] }
        sweep { return [expr {[dict size $::VMDance::Results::sweep] > 0}] }
    }
    if {![::VMDance::Results::has_data]} { return 0 }
    switch -- $key {
        makeup { return [expr {[K] > 0 && [llength [::VMDance::Results::group_names]] > 0}] }
        map { return [expr {[dict size [::VMDance::Results::extra map]] > 0}] }
        profiles { return [expr {[dict size [::VMDance::Results::extra profiles]] > 0}] }
    }
    expr {[K] > 0 || $key in {timeline populations}}
}

proc ::VMDance::Plots::draw {key c} {
    variable H; variable ccache; variable drawing
    array unset ccache
    set drawing 1
    try {
        _draw $key $c
    } finally {
        set drawing 0
        array unset ccache
    }
}
proc ::VMDance::Plots::_draw {key c} {
    variable H
    $c delete all
    array unset H $c,*
    switch -- [needs $key] {
        elbow {
            if {![dict size $::VMDance::Results::elbow]} {
                ::VMDance::Plot::empty $c "No elbow scan" "Scans ▸ Elbow: cluster at every k of a range, and compare the scores."
                return
            }
        }
        sweep {
            if {![dict size $::VMDance::Results::sweep]} {
                ::VMDance::Plot::empty $c "No sweep" "Scans ▸ Sweep: cluster with every combination of algorithm, k, metric and seeding."
                return
            }
        }
        default {
            if {![::VMDance::Results::has_data]} {
                ::VMDance::Plot::empty $c "No clustering" "Choose what to cluster in Setup and press Cluster."
                return
            }
        }
    }
    draw_$key $c
}
proc ::VMDance::Plots::cursor {key c} {
    if {[info commands ::VMDance::Plots::cursor_$key] ne ""} { cursor_$key $c }
}

# The clustered row VMD shows (-1: none). (A frame outside the clustered
# ones has none: told before the frames are checked, which reads every
# clustered frame at each new count of frames — VMD shows each frame it
# adds as it loads a trajectory.)
proc ::VMDance::Plots::now_row {} {
    if {![::VMDance::Results::has_data]} { return -1 }
    set m [dict get [::VMDance::Results::request] mol]
    if {![::VMDance::Mol::exists $m]} { return -1 }
    set f [molinfo $m get frame]
    set fr [::VMDance::Results::frames]
    if {$f < [lindex $fr 0] || $f > [lindex $fr end]} { return -1 }
    if {[::VMDance::Viz::_mol] < 0} { return -1 }
    ::VMDance::Results::frame_index $f
}

proc ::VMDance::Plots::_legend_margin {c items {ml 58} {mr 18}} {
    if {![S plot_legend] || ![llength $items]} { return 16 }
    ::VMDance::Plot::top_margin [::VMDance::Plot::legend_rows $c $items $ml $mr]
}
proc ::VMDance::Plots::_legend {c items {xr ""}} {
    if {[S plot_legend] && [llength $items]} { ::VMDance::Plot::legend $c $items "" $xr }
}

# The label axis of categories at 0 .. n-1: a tick formatter.
proc ::VMDance::Plots::_catfmt {labels} {
    list apply {{labs v} {
        set i [expr {int(round($v))}]
        if {$i < 0 || $i >= [llength $labs]} { return "" }
        lindex $labs $i
    }} $labels
}


#---------------------------------------------------------------------------
# Bars of the clusters (populations, compactness, residence)
#---------------------------------------------------------------------------

# Vertical bars: items {cluster value ?whisker?}, the y axis label.
proc ::VMDance::Plots::_bars {c items ylab {fmt ""} {ymin 0}} {
    variable H
    set n [llength $items]
    if {!$n} { ::VMDance::Plot::empty $c "Nothing to draw"; return }
    set top 0
    foreach it $items {
        lassign $it cl v wh
        if {$v ne "" && $v > $top} { set top $v }
        if {$wh ne "" && $wh > $top} { set top $wh }
    }
    if {$top <= $ymin} { set top [expr {$ymin + 1}] }
    set labels [lmap it $items {clabel [lindex $it 0]}]
    set ml [::VMDance::Plot::ml]
    ::VMDance::Plot::setup $c -0.5 [expr {$n - 0.5}] $ymin [expr {$top * 1.12}] [list $ml 18 18 [::VMDance::Plot::mb]]
    set xt {}
    for {set i 0} {$i < $n} {incr i} { lappend xt $i }
    ::VMDance::Plot::axes $c "Cluster" $ylab $xt auto [dict merge [gridopt] [dict create xfmt [_catfmt $labels]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set bw [expr {max(2.0, 0.72 * ($x1 - $x0) / $n)}]
    set i 0
    set hit {}
    foreach it $items {
        lassign $it cl v wh
        set cx [::VMDance::Plot::X $c $i]
        set xa [expr {$cx - $bw / 2.0}]; set xb [expr {$cx + $bw / 2.0}]
        if {$v ne ""} {
            set yt [::VMDance::Plot::Y $c $v]
            set sel [expr {$cl >= 0 && [on $cl]}]
            $c create rectangle $xa $yt $xb [::VMDance::Plot::Y $c $ymin] -fill [ccol $cl] \
                -outline [expr {$sel ? "#111111" : ""}] -width [expr {$sel ? 2 : 1}] -tags bar
            if {$wh ne "" && $wh > $v} {
                set yw [::VMDance::Plot::Y $c $wh]
                $c create line $cx $yt $cx $yw -fill [theme text] -tags bar
                $c create line [expr {$cx - $bw / 5.0}] $yw [expr {$cx + $bw / 5.0}] $yw -fill [theme text] -tags bar
            }
            if {$fmt ne "" && $bw >= [font measure MdvSmall [format $fmt $v]] + 2} {
                set yl [expr {$wh ne "" && $wh > $v ? [::VMDance::Plot::Y $c $wh] : $yt}]
                $c create text $cx [expr {$yl - 3}] -text [format $fmt $v] -anchor s -font MdvSmall -fill [theme text] -tags label
            }
        }
        lappend hit [list $xa $xb $cl]
        incr i
    }
    set H($c,bars) $hit
}
# The bar under the pointer: the one drawn on its pixel (Tk fills the
# pixels whose centre is in a bar; thin bars, 2 px wide, overlap, the later
# on top), else the nearest within 2 px (a gap is shared at its middle).
# (The first whose extent widened by 2 px held it named the bar on the left
# once bars were thinner than 7 px.)
proc ::VMDance::Plots::_bar_at {c x y} {
    variable H
    if {![info exists H($c,bars)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set px [expr {$x + 0.5}]
    set on ""; set near ""; set bd 2.0
    foreach b $H($c,bars) {
        lassign $b xa xb cl
        if {$px > $xa && $px <= $xb} { set on $cl; continue }
        set d [expr {$px < $xa ? $xa - $px : $px - $xb}]
        if {$d <= $bd} { set bd $d; set near $cl }
    }
    if {$on ne ""} { return $on }
    return $near
}
proc ::VMDance::Plots::_cluster_words {cl} {
    if {$cl < 0} { return "noise: [::VMDance::Results::noise] frames" }
    set n [::VMDance::Results::size $cl]
    format "cluster %d: %d frame%s (%.1f%%), representative frame %s" $cl $n [expr {$n == 1 ? "" : "s"}] \
        [expr {100.0 * [::VMDance::Results::fraction $cl]}] [::VMDance::Results::rep_frame $cl]
}
proc ::VMDance::Plots::_click_cluster {cl add} {
    if {$cl eq "" || $cl < 0} return
    ::VMDance::GUI::select [list $cl] $add
}

#---------------------------------------------------------------------------
# Populations
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_populations {c} {
    set k [K]
    set pct [expr {[S po_show] eq "percent"}]
    set N [::VMDance::Results::nframes]
    set items {}
    for {set i 0} {$i < $k} {incr i} {
        set n [::VMDance::Results::size $i]
        lappend items [list $i [expr {$pct ? 100.0 * $n / $N : $n}]]
    }
    if {[S po_sort] eq "size"} { set items [lsort -real -decreasing -index 1 $items] }
    if {[S po_noise] && [::VMDance::Results::noise]} {
        set n [::VMDance::Results::noise]
        lappend items [list -1 [expr {$pct ? 100.0 * $n / $N : $n}]]
    }
    _bars $c $items [expr {$pct ? "Share of the frames (%)" : "Frames"}] [expr {$pct ? "%.1f" : "%.0f"}]
}
proc ::VMDance::Plots::hover_populations {c x y} {
    set cl [_bar_at $c $x $y]
    if {$cl eq ""} { return "" }
    _cluster_words $cl
}
proc ::VMDance::Plots::click_populations {c x y add} { _click_cluster [_bar_at $c $x $y] $add }
proc ::VMDance::Plots::dclick_populations {c x y} {
    set cl [_bar_at $c $x $y]
    if {$cl ne "" && $cl >= 0} { ::VMDance::GUI::goto_cluster $cl }
}

#---------------------------------------------------------------------------
# Timeline: the cluster of every frame
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_timeline {c} {
    if {[S tl_view] eq "msd"} { _timeline_msd $c } else { _timeline_lanes $c }
}

# One lane per cluster (noise at the bottom), a bar where the trajectory
# is in it.
proc ::VMDance::Plots::_timeline_lanes {c} {
    variable H
    set k [K]
    set fr [::VMDance::Results::frames]
    set labels [::VMDance::Results::labels]
    set noise [expr {[::VMDance::Results::noise] > 0}]
    set lanes [expr {$k + $noise}]
    set lanelabels {}
    if {$noise} { lappend lanelabels noise }
    for {set i 0} {$i < $k} {incr i} { lappend lanelabels $i }
    set step [dict get [::VMDance::Results::request] step]
    set xmax [expr {[lindex $fr end] + $step}]
    set ml [expr {max([::VMDance::Plot::ml], [font measure MdvSmall noise] + 22)}]
    ::VMDance::Plot::setup $c [lindex $fr 0] $xmax -0.5 [expr {$lanes - 0.5}] [list $ml 14 18 [::VMDance::Plot::mb]]
    set yt {}
    for {set i 0} {$i < $lanes} {incr i} { lappend yt $i }
    ::VMDance::Plot::axes $c "Frame" "Cluster" auto $yt [dict merge [gridopt] [dict create yfmt [_catfmt $lanelabels]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set iw [expr {max(1, int($x1 - $x0))}]; set ih [expr {max(1, int($y1 - $y0))}]
    set img [_image $c $iw $ih]
    set band [expr {double($ih) / $lanes}]
    set th [S tl_bar]
    if {![string is double -strict $th] || [regexp -nocase {nan|inf} $th] || $th <= 0 || $th > 1} { set th 0.5 }
    set bh [expr {max(2.0, $band * $th)}]
    set span [expr {double($xmax - [lindex $fr 0])}]
    # every run of frames in one cluster: a bar across its pixel columns
    set f0 [lindex $fr 0]
    foreach r [::VMDance::Results::residence] {
        lassign $r l s n
        set fa [lindex $fr $s]
        set fb [expr {[lindex $fr [expr {$s + $n - 1}]] + $step}]
        set pa [expr {int(($fa - $f0) / $span * $iw)}]
        set pb [expr {max($pa + 1, int(($fb - $f0) / $span * $iw))}]
        set lane [expr {$l < 0 ? 0 : $l + $noise}]
        set yc [expr {$ih - ($lane + 0.5) * $band}]
        set ya [expr {int($yc - $bh / 2.0)}]; set yb [expr {max($ya + 2, int($yc + $bh / 2.0))}]
        $img put [ccol $l] -to [expr {min($pa, $iw - 1)}] $ya [expr {min($pb, $iw)}] $yb
    }
    $c create image $x0 $y0 -image $img -anchor nw -tags raster
    $c raise axis
    _frame_cursor $c
    set H($c,tl) lanes
}

# Every frame's RMSD² from its representative, coloured by its cluster.
proc ::VMDance::Plots::_timeline_msd {c} {
    variable H
    set fr [::VMDance::Results::frames]
    set fm [::VMDance::Results::measure frame_msd]
    set labels [::VMDance::Results::labels]
    set vals [lmap v $fm {expr {$v eq "" ? [continue] : $v}}]
    set ymax [expr {[llength $vals] ? [::tcl::mathfunc::max {*}$vals] : 1.0}]
    if {$ymax <= 0} { set ymax 1.0 }
    ::VMDance::Plot::setup $c [lindex $fr 0] [lindex $fr end] 0 [expr {$ymax * 1.08}] \
        [list [::VMDance::Plot::ml] 14 18 [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c "Frame" "RMSD² from its representative (Å²)" auto auto [gridopt]
    set w [lw]
    # one line per run of a cluster (joined to the next frame)
    set pts {}; set prev ""
    set n [llength $fr]
    for {set i 0} {$i < $n} {incr i} {
        set l [lindex $labels $i]; set v [lindex $fm $i]
        if {$l ne $prev && [llength $pts] >= 2} {
            if {[llength $pts] >= 4} { $c create line {*}$pts -fill [ccol $prev] -width $w -tags series }
            set pts [lrange $pts end-1 end]
            if {$v eq ""} { set pts {} }
        }
        if {$v eq ""} { set pts {}; set prev $l; continue }
        lappend pts [::VMDance::Plot::X $c [lindex $fr $i]] [::VMDance::Plot::Y $c $v]
        set prev $l
    }
    if {[llength $pts] >= 4} { $c create line {*}$pts -fill [ccol $prev] -width $w -tags series }
    if {$n <= 200} {
        foreach f $fr v $fm l $labels {
            if {$v eq ""} continue
            set x [::VMDance::Plot::X $c $f]; set y [::VMDance::Plot::Y $c $v]
            $c create oval [expr {$x - 2}] [expr {$y - 2}] [expr {$x + 2}] [expr {$y + 2}] -fill [ccol $l] -outline "" -tags series
        }
    }
    _frame_cursor $c
    set H($c,tl) msd
}

proc ::VMDance::Plots::_frame_cursor {c} {
    $c delete cursor
    if {![S plot_cursor]} return
    set i [now_row]
    if {$i < 0} return
    set f [molinfo [dict get [::VMDance::Results::request] mol] get frame]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set x [::VMDance::Plot::X $c $f]
    if {$x < $x0 - 1 || $x > $x1 + 1} return
    $c create line $x $y0 $x $y1 -fill [theme cursor] -width 1.4 -tags cursor
}
proc ::VMDance::Plots::cursor_timeline {c} { _frame_cursor $c }

# The clustered row at pixel x (on a frame axis): in the lanes, the frame
# whose bar covers it (frame f's: from f to the next); in the distances,
# the nearest (frame f's dot is at f).
proc ::VMDance::Plots::_row_at {c x} {
    variable H
    set fr [::VMDance::Results::frames]
    set f [::VMDance::Plot::invX $c $x]
    set k [lsearch -sorted -integer -bisect $fr [expr {int(floor($f))}]]
    if {$k < 0} { set k 0 }
    if {$H($c,tl) eq "msd" && $k + 1 < [llength $fr] && [lindex $fr $k+1] - $f < $f - [lindex $fr $k]} { incr k }
    return $k
}
proc ::VMDance::Plots::hover_timeline {c x y} {
    variable H
    if {![info exists H($c,tl)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set i [_row_at $c $x]
    set f [lindex [::VMDance::Results::frames] $i]
    set l [lindex [::VMDance::Results::labels] $i]
    set m [lindex [::VMDance::Results::measure frame_msd] $i]
    set s "frame $f: [expr {$l < 0 ? "noise" : "cluster $l"}]"
    if {$m ne ""} { append s [format ", RMSD² %.3g Å² from its representative (frame %s)" $m [::VMDance::Results::rep_frame $l]] }
    return $s
}
proc ::VMDance::Plots::click_timeline {c x y add} {
    variable H
    if {![info exists H($c,tl)] || ![::VMDance::Plot::inside $c $x $y]} return
    set i [_row_at $c $x]
    ::VMDance::GUI::goto_frame [lindex [::VMDance::Results::frames] $i]
    set l [lindex [::VMDance::Results::labels] $i]
    if {$add && $l >= 0} { ::VMDance::GUI::select [list $l] 1 }
}

#---------------------------------------------------------------------------
# Matrices (transitions, distances)
#---------------------------------------------------------------------------

# A k × k matrix as coloured cells: M (values or ""), the axis titles,
# the colour bar's title, the value format; from the palette cmap over
# [lo, hi].
proc ::VMDance::Plots::_matrix {c M xlab ylab title fmt cmap lo hi {skipdiag 0}} {
    variable H; variable bg
    set k [llength $M]
    lassign [::VMDance::Plot::size $c] W Hh
    set lh [::VMDance::Plot::lh]
    set ml [expr {max([::VMDance::Plot::ml], [font measure MdvSmall [expr {$k - 1}]] + 30)}]
    set mb [::VMDance::Plot::mb]
    set mt [expr {16 + [::VMDance::Plot::bar_height]}]
    set cs [expr {max(2.0, min(double($W - $ml - 18) / $k, double($Hh - $mt - $mb) / $k))}]
    set side [expr {$cs * $k}]
    set x0 $ml; set y0 $mt
    if {$hi <= $lo} { set hi [expr {$lo + 1.0}] }
    ::VMDance::Plot::setup $c -0.5 [expr {$k - 0.5}] -0.5 [expr {$k - 0.5}] [list $x0 $y0 [expr {$W - $x0 - $side}] [expr {$Hh - $y0 - $side}]]
    set img [_image $c [expr {max(1, int($side))}] [expr {max(1, int($side))}]]
    for {set i 0} {$i < $k} {incr i} {
        for {set j 0} {$j < $k} {incr j} {
            set v [lindex $M $i $j]
            if {$v eq "" || ($skipdiag && $i == $j)} { set col #eceef3 } else { set col [::VMDance::Cmap::at $cmap [expr {($v - $lo) / double($hi - $lo)}]] }
            # row i from the top
            $img put $col -to [expr {int($j * $cs)}] [expr {int($i * $cs)}] [expr {max(int($j * $cs) + 1, int(($j + 1) * $cs))}] [expr {max(int($i * $cs) + 1, int(($i + 1) * $cs))}]
        }
    }
    $c create image $x0 $y0 -image $img -anchor nw -tags raster
    $c create rectangle $x0 $y0 [expr {$x0 + $side}] [expr {$y0 + $side}] -outline [theme axis] -tags axis
    set step [expr {max(1, int(ceil(($lh - 1) / $cs)))}]
    for {set i 0} {$i < $k} {incr i} {
        if {$i % $step} continue
        set yc [expr {$y0 + ($i + 0.5) * $cs}]
        $c create rectangle [expr {$x0 - 12}] [expr {$yc - 4}] [expr {$x0 - 4}] [expr {$yc + 4}] -fill [ccol $i 0] -outline "" -tags label
        $c create text [expr {$x0 - 16}] $yc -text $i -anchor e -font [expr {[on $i] ? "MdvBold" : "MdvSmall"}] -fill [theme text] -tags label
        set xc [expr {$x0 + ($i + 0.5) * $cs}]
        $c create rectangle [expr {$xc - 4}] [expr {$y0 + $side + 4}] [expr {$xc + 4}] [expr {$y0 + $side + 12}] -fill [ccol $i 0] -outline "" -tags label
        $c create text $xc [expr {$y0 + $side + 14}] -text $i -anchor n -font [expr {[on $i] ? "MdvBold" : "MdvSmall"}] -fill [theme text] -tags label
    }
    $c create text [expr {$x0 + $side / 2.0}] [expr {$y0 + $side + 16 + $lh}] -text $xlab -anchor n -font MdvText -fill [theme text] -tags axis
    $c create text [expr {max(14, 2 + [::VMDance::Plot::lh MdvText] / 2.0)}] [expr {$y0 + $side / 2.0}] -text $ylab -angle 90 -font MdvText -fill [theme text] -tags axis
    # the values, when they fit
    if {[S mx_values] && $fmt ne "" && $cs >= [font measure MdvSmall [format $fmt $hi]] + 6 && $cs >= $lh + 2} {
        for {set i 0} {$i < $k} {incr i} {
            for {set j 0} {$j < $k} {incr j} {
                set v [lindex $M $i $j]
                if {$v eq "" || ($skipdiag && $i == $j)} continue
                set t [expr {($v - $lo) / double($hi - $lo)}]
                $c create text [expr {$x0 + ($j + 0.5) * $cs}] [expr {$y0 + ($i + 0.5) * $cs}] -text [format $fmt $v] \
                    -font MdvSmall -fill [expr {[_dark [::VMDance::Cmap::at $cmap $t]] ? "white" : "#222222"}] -tags label
            }
        }
    }
    # the selected clusters' rows and columns
    foreach s [selected] {
        $c create rectangle $x0 [expr {$y0 + $s * $cs}] [expr {$x0 + $side}] [expr {$y0 + ($s + 1) * $cs}] -outline $::VMDance::Plots::accent -width 2 -tags sel
        $c create rectangle [expr {$x0 + $s * $cs}] $y0 [expr {$x0 + ($s + 1) * $cs}] [expr {$y0 + $side}] -outline $::VMDance::Plots::accent -width 2 -tags sel
    }
    ::VMDance::Plot::colorbar_titled $c $x0 6 [lmap t {0 1 2 3 4 5 6 7 8 9 10} {::VMDance::Cmap::at $cmap [expr {$t / 10.0}]}] \
        [::VMDance::Plot::fmt $lo] [::VMDance::Plot::fmt $hi] $title
    set H($c,mx) [list $k $x0 $y0 $cs $M]
}
proc ::VMDance::Plots::_dark {col} {
    scan $col "#%2x%2x%2x" r g b
    expr {0.299 * $r + 0.587 * $g + 0.114 * $b < 128}
}
proc ::VMDance::Plots::_cell {c x y} {
    variable H
    if {![info exists H($c,mx)]} { return {} }
    lassign $H($c,mx) k x0 y0 cs
    set j [expr {int(floor(($x - $x0) / $cs))}]
    set i [expr {int(floor(($y - $y0) / $cs))}]
    if {$i < 0 || $j < 0 || $i >= $k || $j >= $k} { return {} }
    list $i $j
}
proc ::VMDance::Plots::_cell_click {c x y add} {
    lassign [_cell $c $x $y] i j
    if {$i eq ""} return
    ::VMDance::GUI::select [lsort -unique [list $i $j]] $add
}

# Transitions: from each clustered frame to the one lag later.
proc ::VMDance::Plots::_transitions {} {
    set lag [S tn_lag]
    # (a lag typed and not yet confirmed: 010 would be lag 8, titled 010)
    if {![::VMDance::whole $lag] || $lag < 1} { set lag 1 }
    ::VMDance::Results::memo_last plot_transitions $lag {
        set T [::VMDance::Results::transitions $lag]
        set labels [::VMDance::Results::labels]
        set k [K]
        set tonoise [lrepeat $k 0]
        for {set i 0} {$i + $lag < [llength $labels]} {incr i} {
            set a [lindex $labels $i]; set b [lindex $labels [expr {$i + $lag}]]
            if {$a >= 0 && $b < 0} { lset tonoise $a [expr {[lindex $tonoise $a] + 1}] }
        }
        set P {}
        foreach row $T n $tonoise {
            set tot [expr {[::tcl::mathop::+ 0 {*}$row] + $n}]
            lappend P [lmap v $row {expr {$tot ? double($v) / $tot : ""}}]
        }
        list $T $P $lag $tonoise
    }
}
# A matrix plot needs a cluster, and not too many: up to Measure::maxk (a
# cell a cluster: more do not fit, and the distances are not measured for
# more). The message says so, or why.
proc ::VMDance::Plots::_matrix_ok {c {why ""}} {
    set maxk $::VMDance::Measure::maxk
    if {[K] == 0} {
        ::VMDance::Plot::empty $c "No cluster" "Every frame is noise: there is nothing between clusters to draw."
        return 0
    }
    if {[K] > $maxk} {
        if {$why eq ""} { set why "The matrix is drawn for $maxk clusters or fewer. Export writes its values." }
        ::VMDance::Plot::empty $c "[K] clusters" $why
        return 0
    }
    return 1
}
proc ::VMDance::Plots::draw_transitions {c} {
    if {![_matrix_ok $c]} return
    lassign [_transitions] T P lag
    set counts [expr {[S tn_show] eq "counts"}]
    set M [expr {$counts ? $T : $P}]
    set skip [expr {![S tn_self]}]
    set hi 0
    for {set i 0} {$i < [llength $M]} {incr i} {
        for {set j 0} {$j < [llength $M]} {incr j} {
            set v [lindex $M $i $j]
            if {$v ne "" && !($skip && $i == $j) && $v > $hi} { set hi $v }
        }
    }
    if {$hi == 0} { set hi 1 }
    set t [expr {$counts ? "Transitions" : "Probability"}]
    _matrix $c $M "To cluster" "From cluster" [list "$t (lag $lag)" $t] [expr {$counts ? "%d" : "%.2f"}] [S tn_cmap] 0 $hi $skip
}
proc ::VMDance::Plots::hover_transitions {c x y} {
    lassign [_cell $c $x $y] i j
    if {$i eq ""} { return "" }
    lassign [_transitions] T P lag tonoise
    set n [lindex $T $i $j]
    set p [lindex $P $i $j]
    set s "cluster $i → $j: $n transition[expr {$n == 1 ? "" : "s"}]"
    if {$p ne ""} { append s [format " (%.1f%% of those from %d)" [expr {100 * $p}] $i] }
    if {[lindex $tonoise $i]} { append s ", [lindex $tonoise $i] into noise" }
    return "$s, lag $lag"
}
proc ::VMDance::Plots::click_transitions {c x y add} { _cell_click $c $x $y $add }

proc ::VMDance::Plots::draw_distances {c} {
    # (not measured for many clusters: why, and what to change)
    set why [::VMDance::Results::too_many distances]
    if {$why ne ""} { set why "[string toupper $why 0 0]." }
    if {![_matrix_ok $c $why]} return
    if {[S ds_show] eq "representatives"} {
        set M [lmap row [::VMDance::Results::measure rep_msd] {lmap v $row {expr {$v eq "" ? "" : sqrt($v)}}}]
        set title {"RMSD between representatives (Å)" "RMSD (Å)"}
    } else {
        set M [::VMDance::Results::measure centroid_msd]
        set title {"RMSD² between mean structures (Å²)" "RMSD² (Å²)"}
    }
    set hi 0
    foreach row $M { foreach v $row { if {$v ne "" && $v > $hi} { set hi $v } } }
    _matrix $c $M "Cluster" "Cluster" $title "%.2g" [S ds_cmap] 0 $hi
}
proc ::VMDance::Plots::hover_distances {c x y} {
    lassign [_cell $c $x $y] i j
    if {$i eq ""} { return "" }
    set C [lindex [::VMDance::Results::measure centroid_msd] $i $j]
    set R [lindex [::VMDance::Results::measure rep_msd] $i $j]
    set s "clusters $i and $j"
    if {$C ne ""} { append s [format ": mean structures %.3g Å² (RMSD²)" $C] }
    if {$R ne ""} { append s [format ", representatives (frames %s, %s) %.3g Å (RMSD)" [::VMDance::Results::rep_frame $i] [::VMDance::Results::rep_frame $j] [expr {sqrt($R)}]] }
    return $s
}
proc ::VMDance::Plots::click_distances {c x y add} { _cell_click $c $x $y $add }

#---------------------------------------------------------------------------
# Residence, compactness
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_residence {c} {
    set st [::VMDance::Export::residence_stats]
    set step [dict get [::VMDance::Results::request] step]
    set vmd [expr {[S rs_unit] eq "vmd"}]
    set f [expr {$vmd ? $step : 1}]
    if {[S rs_show] eq "visits"} {
        _bars $c [lmap r $st {list [lindex $r 0] [lindex $r 1]}] "Visits (runs of frames)" "%.0f"
    } else {
        set ylab [expr {$vmd || $step == 1 ? "Residence (frames)" : "Residence (clustered frames, × $step)"}]
        _bars $c [lmap r $st {list [lindex $r 0] [expr {$f * [lindex $r 2]}] [expr {$f * [lindex $r 4]}]}] $ylab "%.1f"
    }
}
proc ::VMDance::Plots::hover_residence {c x y} {
    set cl [_bar_at $c $x $y]
    if {$cl eq "" || $cl < 0} { return "" }
    lassign [lindex [::VMDance::Export::residence_stats] $cl] - v mean mn mx
    set step [dict get [::VMDance::Results::request] step]
    format "cluster %d: %d visit%s, %.1f clustered frames on average (%d to %d)%s" $cl $v [expr {$v == 1 ? "" : "s"}] $mean $mn $mx \
        [expr {$step > 1 ? ", one clustered frame every $step" : ""}]
}
proc ::VMDance::Plots::click_residence {c x y add} { _click_cluster [_bar_at $c $x $y] $add }

proc ::VMDance::Plots::draw_compactness {c} {
    variable H
    set k [K]
    switch -- [S cp_show] {
        spread {
            _bars $c [lmap r [::VMDance::Results::table] {list [lindex $r 0] [lindex $r 4]}] "Mean RMSD² from the representative (Å²)" "%.2g"
        }
        scatter { _compactness_scatter $c }
        isim {
            set s [::VMDance::Results::extra similarity]
            if {![dict size $s]} {
                ::VMDance::Plot::empty $c "No similarity yet" "Tools ▸ Similarity computes each cluster's extended similarity (iSIM)."
                return
            }
            set items {}
            set i 0
            foreach v [dict get $s cluster] { lappend items [list $i $v]; incr i }
            _bars $c $items "Extended similarity (iSIM, [dict get $s params metric])" "%.3g"
            $c create text [expr {[lindex [::VMDance::Plot::size $c] 0] - 20}] 6 -anchor ne -font MdvSmall -fill [theme muted] \
                -text [expr {[dict get $s isim] eq "" ? "all frames: none" : [format "all frames: %.4g (lower: tighter)" [dict get $s isim]]}] -tags label
        }
        default {
            _bars $c [lmap r [::VMDance::Results::table] {list [lindex $r 0] [lindex $r 3]}] "Mean square deviation within (Å²)" "%.2g"
        }
    }
}
proc ::VMDance::Plots::_median {l} {
    set l [lsort -real $l]
    set n [llength $l]
    if {!$n} { return "" }
    expr {$n % 2 ? [lindex $l [expr {$n / 2}]] : ([lindex $l [expr {$n / 2 - 1}]] + [lindex $l [expr {$n / 2}]]) / 2.0}
}
proc ::VMDance::Plots::_compactness_scatter {c} {
    variable H
    set pts {}
    foreach r [::VMDance::Results::table] {
        lassign $r cl n pct msd
        if {$msd ne ""} { lappend pts [list $cl $n $msd] }
    }
    if {![llength $pts]} { ::VMDance::Plot::empty $c "No cluster MSD" "The backend gave none."; return }
    set xs [lmap p $pts {lindex $p 1}]; set ys [lmap p $pts {lindex $p 2}]
    set xmax [::tcl::mathfunc::max {*}$xs]; set ymax [::tcl::mathfunc::max {*}$ys]
    ::VMDance::Plot::setup $c 0 [expr {$xmax * 1.12 + 1}] 0 [expr {$ymax * 1.15 + 1e-6}] \
        [list [::VMDance::Plot::ml] 18 18 [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c "Frames" "Mean square deviation within (Å²)" auto auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set mx [::VMDance::Plot::X $c [_median $xs]]; set my [::VMDance::Plot::Y $c [_median $ys]]
    $c create line $mx $y0 $mx $y1 -fill #c4c9d2 -dash {4 3} -tags grid
    $c create line $x0 $my $x1 $my -fill #c4c9d2 -dash {4 3} -tags grid
    set hit {}
    foreach p $pts {
        lassign $p cl n v
        set x [::VMDance::Plot::X $c $n]; set y [::VMDance::Plot::Y $c $v]
        set r [expr {[on $cl] ? 7 : 6}]
        $c create oval [expr {$x - $r}] [expr {$y - $r}] [expr {$x + $r}] [expr {$y + $r}] -fill [ccol $cl] \
            -outline [expr {[on $cl] ? "#111111" : "white"}] -width [expr {[on $cl] ? 2 : 1}] -tags point
        $c create text [expr {$x + $r + 3}] $y -text $cl -anchor w -font MdvSmall -fill [theme text] -tags label
        lappend hit [list $x $y $cl]
    }
    $c create text [expr {$x1 - 4}] [expr {$y0 + 4}] -anchor ne -font MdvSmall -fill [theme muted] -text "dashed: the medians" -tags label
    set H($c,pts) $hit
}
proc ::VMDance::Plots::_point_at {c x y} {
    variable H
    if {![info exists H($c,pts)]} { return "" }
    set best ""; set bd 100
    foreach p $H($c,pts) {
        lassign $p px py cl
        set d [expr {hypot($px - $x, $py - $y)}]
        if {$d < $bd} { set bd $d; set best $cl }
    }
    expr {$bd <= 10 ? $best : ""}
}
proc ::VMDance::Plots::_compact_at {c x y} {
    if {[S cp_show] eq "scatter"} { return [_point_at $c $x $y] }
    _bar_at $c $x $y
}
proc ::VMDance::Plots::hover_compactness {c x y} {
    set cl [_compact_at $c $x $y]
    if {$cl eq "" || $cl < 0} { return "" }
    set r [lindex [::VMDance::Results::table] $cl]
    set s "[_cluster_words $cl]"
    if {[lindex $r 3] ne ""} { append s [format "; MSD within %.3g Å²" [lindex $r 3]] }
    if {[lindex $r 4] ne ""} { append s [format ", RMSD² from its representative %.3g Å²" [lindex $r 4]] }
    set sim [::VMDance::Results::extra similarity]
    if {[dict size $sim] && [lindex [dict get $sim cluster] $cl] ne ""} {
        append s [format ", iSIM %.3g" [lindex [dict get $sim cluster] $cl]]
    }
    return $s
}
proc ::VMDance::Plots::click_compactness {c x y add} { _click_cluster [_compact_at $c $x $y] $add }
proc ::VMDance::Plots::dclick_compactness {c x y} {
    set cl [_compact_at $c $x $y]
    if {$cl ne "" && $cl >= 0} { ::VMDance::GUI::goto_cluster $cl }
}
proc ::VMDance::Plots::dclick_residence {c x y} { dclick_populations $c $x $y }

#---------------------------------------------------------------------------
# Tree: the dendrogram
#---------------------------------------------------------------------------

# The dendrogram's layout: leaves (their x order), every node's x and
# height, the roots; HELM's leaves are its starting clusters (Results::tree).
proc ::VMDance::Plots::_tree {} {
    lassign [::VMDance::Results::tree] how rows leaves base
    set kids [dict create]
    set height [dict create]
    set child [dict create]
    set i 0
    foreach r $rows {
        lassign $r a b d n
        dict set kids [expr {$base + $i}] [list $a $b]
        dict set height [expr {$base + $i}] [expr {$d eq "" ? 0 : $d}]
        dict set child $a 1; dict set child $b 1
        incr i
    }
    foreach l $leaves { dict set height $l 0 }
    set roots {}
    foreach l $leaves { if {![dict exists $child $l]} { lappend roots $l } }
    for {set j 0} {$j < [llength $rows]} {incr j} { if {![dict exists $child [expr {$base + $j}]]} { lappend roots [expr {$base + $j}] } }
    # leaves in order, tree after tree
    set order {}
    set stack [lreverse $roots]
    while {[llength $stack]} {
        set nd [lindex $stack end]
        set stack [lrange $stack 0 end-1]
        if {[dict exists $kids $nd]} {
            lassign [dict get $kids $nd] a b
            lappend stack $b $a
        } else {
            lappend order $nd
        }
    }
    set x [dict create]
    set i 0
    foreach l $order { dict set x $l $i; incr i }
    # internal nodes: midway between their children (rows are in merge
    # order, children first)
    for {set j 0} {$j < [llength $rows]} {incr j} {
        set nd [expr {$base + $j}]
        lassign [dict get $kids $nd] a b
        if {[dict exists $x $a] && [dict exists $x $b]} { dict set x $nd [expr {([dict get $x $a] + [dict get $x $b]) / 2.0}] }
    }
    list $how $rows $base $order $x $height $roots $kids
}

# The final cluster of a starting cluster of HELM (-1: left out).
proc ::VMDance::Plots::_helm_final {} {
    set init [::VMDance::Results::get initial]
    set labels [::VMDance::Results::labels]
    set out [dict create]
    foreach s $init l $labels { if {![dict exists $out $s]} { dict set out $s $l } }
    return $out
}

proc ::VMDance::Plots::draw_tree {c} {
    variable H
    if {[S td_view] eq "heights"} { _tree_heights $c; return }
    set why [::VMDance::Results::too_many tree]
    if {$why ne ""} {
        ::VMDance::Plot::empty $c "[K] clusters" "[string toupper $why 0 0]."
        return
    }
    if {[catch {_tree} tree]} { ::VMDance::Plot::empty $c "No tree" $tree; return }
    lassign $tree how rows base order x height roots kids
    if {[llength $order] < 1} { ::VMDance::Plot::empty $c "No tree" "The clustering has no cluster with frames."; return }
    if {$how eq "linkage" && [llength $order] < 2} { ::VMDance::Plot::empty $c "One cluster" "A dendrogram needs two clusters or more."; return }
    set hmax 0
    dict for {nd h} $height { if {$h > $hmax} { set hmax $h } }
    if {$hmax <= 0} { set hmax 1 }
    set n [llength $order]
    set helm [expr {$how eq "helm"}]
    set final [expr {$helm ? [_helm_final] : {}}]
    set ylab [expr {$helm ? "Merge (in order)" : "RMSD² between mean structures (Å²)"}]
    # (a linkage is not how DIVINE made its clusters: its splits, which
    # CPP-MDANCE does not return, can group them otherwise; nor HELM's
    # merges, for a run that has none)
    set not [::VMDance::_get {divine ", not DIVINE's splits" helm ", not HELM's merges"} [::VMDance::Results::algorithm] ""]
    set xlab [expr {$helm ? "HELM's starting clusters (colour: the cluster they end in)" : "Cluster (average linkage of the mean structures$not)"}]
    ::VMDance::Plot::setup $c -0.6 [expr {$n - 0.4}] 0 [expr {$hmax * 1.08}] [list [::VMDance::Plot::ml] 18 18 [::VMDance::Plot::mb $c $xlab]]
    ::VMDance::Plot::axes $c $xlab $ylab {} auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set w [lw]
    # the cluster a node's leaves end in (HELM), else ""
    set cl_of [dict create]
    foreach l $order {
        dict set cl_of $l [expr {$helm ? ([dict exists $final $l] ? [dict get $final $l] : -1) : $l}]
    }
    for {set j 0} {$j < [llength $rows]} {incr j} {
        set nd [expr {$base + $j}]
        lassign [dict get $kids $nd] a b
        if {![dict exists $x $nd]} continue
        set ca [expr {[dict exists $cl_of $a] ? [dict get $cl_of $a] : ""}]
        set cb [expr {[dict exists $cl_of $b] ? [dict get $cl_of $b] : ""}]
        dict set cl_of $nd [expr {$ca eq $cb ? $ca : ""}]
        set col [expr {$helm && $ca eq $cb && $ca ne "" && $ca >= 0 ? [ccol $ca 0] : "#4a5160"}]
        set xa [::VMDance::Plot::X $c [dict get $x $a]]; set xb [::VMDance::Plot::X $c [dict get $x $b]]
        set ya [::VMDance::Plot::Y $c [dict get $height $a]]; set yb [::VMDance::Plot::Y $c [dict get $height $b]]
        set yn [::VMDance::Plot::Y $c [dict get $height $nd]]
        $c create line $xa $ya $xa $yn $xb $yn $xb $yb -fill $col -width $w -tags link
    }
    # the leaves: a mark in their cluster's colour, labels when they fit
    set room [expr {($x1 - $x0) / double($n)}]
    set lh [::VMDance::Plot::lh]
    set hit {}
    foreach l $order {
        set px [::VMDance::Plot::X $c [dict get $x $l]]
        set cl [dict get $cl_of $l]
        set r [expr {min(5.0, max(2.0, $room / 3.0))}]
        $c create oval [expr {$px - $r}] [expr {$y1 - $r}] [expr {$px + $r}] [expr {$y1 + $r}] -fill [ccol $cl] \
            -outline [expr {$cl ne "" && $cl >= 0 && [on $cl] ? "#111111" : "white"}] -tags leaf
        if {[S td_labels] && $room >= [font measure MdvSmall $l] + 3} {
            $c create text $px [expr {$y1 + $r + 2}] -text $l -anchor n -font MdvSmall -fill [theme text] -tags label
        }
        lappend hit [list $px $l $cl]
    }
    if {$helm} {
        set note {}
        if {[llength $roots] > 1} { lappend note "[llength $roots] trees: HELM stopped at [K] clusters" }
        set cut [expr {[dict size $final] - $n}]
        if {$cut > 0} { lappend note "$cut starting cluster[expr {$cut == 1 ? "" : "s"}] trimmed (noise)" }
        if {[llength $note]} {
            $c create text [expr {$x1 - 4}] [expr {$y0 + 4}] -anchor ne -font MdvSmall -fill [theme muted] \
                -text [join $note "; "] -tags label
        }
    }
    set H($c,tree) [list $how $hit]
}
proc ::VMDance::Plots::_leaf_at {c x y} {
    variable H
    if {![info exists H($c,tree)]} { return {} }
    lassign $H($c,tree) how hit
    set best {}; set bd 1e9
    foreach h $hit {
        lassign $h px l cl
        set d [expr {abs($px - $x)}]
        if {$d < $bd} { set bd $d; set best $h }
    }
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    if {$bd > 12 || $y < $y0} { return {} }
    list $how {*}$best
}
# The merges' heights against the clusters before each: HELM's, the MSD
# of the cluster each merge makes (measured when it was clustered); the
# average linkage's, the RMSD² between the mean structures it joins. A
# merge much higher than the one before joins clusters far apart: the k
# before it is a natural place to stop. The largest such jump is marked,
# relative (the height over the one before, which counts as 5% of the
# highest at least: merges of near-identical clusters are not jumps).
proc ::VMDance::Plots::_tree_heights {c} {
    variable H
    set why [::VMDance::Results::too_many tree]
    if {$why ne ""} { ::VMDance::Plot::empty $c "[K] clusters" "[string toupper $why 0 0]."; return }
    if {[catch {::VMDance::Results::tree} tree]} { ::VMDance::Plot::empty $c "No tree" $tree; return }
    lassign $tree how rows leaves base
    if {$how eq "helm"} {
        set m [::VMDance::Results::get measures]
        if {![dict exists $m merge_msd]} {
            ::VMDance::Plot::empty $c "No heights" "This run of HELM was made before the heights of its merges were measured: cluster again."
            return
        }
        set hs [dict get $m merge_msd]
        set ylab "MSD of the cluster each merge makes (Å²)"
    } else {
        set hs [lmap r $rows {lindex $r 2}]
        set ylab "RMSD² between the mean structures joined (Å²)"
    }
    set L [llength $leaves]
    set pts {}
    set j 0
    foreach h $hs {
        if {$h ne ""} { lappend pts [list [expr {$L - $j}] $h] }
        incr j
    }
    if {[llength $pts] < 1} { ::VMDance::Plot::empty $c "No merges" "The tree has no merge to draw."; return }
    set xs [lmap p $pts {lindex $p 0}]; set ys [lmap p $pts {lindex $p 1}]
    set kmin [::tcl::mathfunc::min {*}$xs]; set kmax [::tcl::mathfunc::max {*}$xs]
    set hi [::tcl::mathfunc::max {*}$ys]
    if {$hi <= 0} { set hi 1 }
    # the largest jump: a merge's height over the one before it (at k + 1)
    set jump ""; set best 1.0
    set floor [expr {0.05 * $hi}]
    foreach p $pts {
        lassign $p k h
        set i [lsearch -exact -index 0 $pts [expr {$k + 1}]]
        if {$i < 0} continue
        set d [expr {$h / max([lindex $pts $i 1], $floor)}]
        if {$d > $best} { set best $d; set jump $k }
    }
    set ml [::VMDance::Plot::ml]
    ::VMDance::Plot::setup $c [expr {$kmin - 0.5}] [expr {$kmax + 0.5}] 0 [expr {$hi * 1.1}] [list $ml 18 18 [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c "Clusters before the merge (k)" $ylab auto auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set line {}
    foreach p [lsort -integer -index 0 $pts] {
        lassign $p k h
        lappend line [::VMDance::Plot::X $c $k] [::VMDance::Plot::Y $c $h]
    }
    if {[llength $line] >= 4} { $c create line {*}$line -fill $::VMDance::Plots::accent -width [expr {[lw] + 0.4}] -tags series }
    foreach {px py} $line { $c create oval [expr {$px - 3.5}] [expr {$py - 3.5}] [expr {$px + 3.5}] [expr {$py + 3.5}] -fill $::VMDance::Plots::accent -outline white -tags series }
    if {$jump ne ""} {
        set px [::VMDance::Plot::X $c $jump]; set py [::VMDance::Plot::Y $c [lindex $pts [lsearch -exact -index 0 $pts $jump] 1]]
        $c create oval [expr {$px - 7}] [expr {$py - 7}] [expr {$px + 7}] [expr {$py + 7}] -outline [theme cursor] -width 1.5 -tags mark
        $c create text [expr {$x1 - 4}] [expr {$y0 + 4}] -anchor ne -font MdvSmall -fill [theme muted] \
            -text [format "circled: the largest jump (× %.1f), from k = %d to %d" $best $jump [expr {$jump - 1}]] -tags label
    }
    # the clustering's k (merges stop there)
    if {[K] >= $kmin - 1 && [K] <= $kmax} {
        set px [::VMDance::Plot::X $c [K]]
        $c create line $px $y0 $px $y1 -fill $::VMDance::Plots::accent -dash {2 3} -tags mark
    }
    set H($c,heights) $pts
}
proc ::VMDance::Plots::hover_tree {c x y} {
    variable H
    if {[S td_view] eq "heights"} {
        if {![info exists H($c,heights)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
        set k [expr {int(round([::VMDance::Plot::invX $c $x]))}]
        set i [lsearch -exact -index 0 $H($c,heights) $k]
        if {$i < 0} { return "" }
        return [format "from %d to %d clusters: a merge of height %.4g Å²" $k [expr {$k - 1}] [lindex $H($c,heights) $i 1]]
    }
    lassign [_leaf_at $c $x $y] how px l cl
    if {$how eq ""} { return "" }
    if {$how eq "helm"} {
        set n [llength [lsearch -all -exact [::VMDance::Results::get initial] $l]]
        return "starting cluster $l ($n frame[expr {$n == 1 ? "" : "s"}]) → cluster $cl"
    }
    return [_cluster_words $cl]
}
proc ::VMDance::Plots::click_tree {c x y add} {
    if {[S td_view] eq "heights"} return
    lassign [_leaf_at $c $x $y] how px l cl
    if {$how ne "" && $cl ne ""} { _click_cluster $cl $add }
}

#---------------------------------------------------------------------------
# Silhouette
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_silhouette {c} {
    variable H
    set k [K]
    set sil [::VMDance::Results::measure silhouette]
    set fr [::VMDance::Results::frames]
    set all [lmap v $sil {expr {$v eq "" ? [continue] : $v}}]
    if {![llength $all]} { ::VMDance::Plot::empty $c "No silhouette" "A silhouette needs two clusters or more."; return }
    set blocks {}
    set total 0
    for {set cl 0} {$cl < $k} {incr cl} {
        set rows [lmap i [::VMDance::Results::members $cl] {expr {[lindex $sil $i] eq "" ? [continue] : [list $i [lindex $sil $i]]}}]
        if {[S sl_sort]} { set rows [lsort -real -decreasing -index 1 $rows] }
        if {[llength $rows]} { lappend blocks [list $cl $rows]; incr total [llength $rows] }
    }
    # a gap of a 60th of the frames (2 rows at least) between two clusters,
    # all of them a quarter of the axis at most (a fraction of a row each
    # with hundreds of clusters: the frames kept most of it)
    set gap [expr {min(max(2, $total / 60), $total / (3.0 * max(1, [llength $blocks] - 1)))}]
    set ytot [expr {$total + $gap * ([llength $blocks] - 1)}]
    set ml [expr {max([::VMDance::Plot::ml], [font measure MdvSmall "00"] + 30)}]
    ::VMDance::Plot::setup $c -1 1 0 $ytot [list $ml 18 18 [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c "Silhouette" "" {-1 -0.5 0 0.5 1} {} [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set xz [::VMDance::Plot::X $c 0]
    # y from the top: row r at data ytot - r (a gap can be a fraction of one)
    set r 0
    set hit {}
    set labs {}
    foreach b $blocks {
        lassign $b cl rows
        set pts [list $xz [::VMDance::Plot::Y $c [expr {$ytot - $r}]]]
        set ya $r
        foreach p $rows {
            lassign $p i v
            set yt [::VMDance::Plot::Y $c [expr {$ytot - $r}]]
            set yb [::VMDance::Plot::Y $c [expr {$ytot - $r - 1}]]
            set xv [::VMDance::Plot::X $c $v]
            lappend pts $xv $yt $xv $yb
            set r [expr {$r + 1}]
        }
        lappend pts $xz [::VMDance::Plot::Y $c [expr {$ytot - $r}]]
        $c create polygon {*}$pts -fill [ccol $cl] -outline [expr {[on $cl] ? "#111111" : ""}] -width 1.5 -tags bar
        lappend labs [list $cl [::VMDance::Plot::Y $c [expr {$ytot - ($ya + $r) / 2.0}]]]
        lappend hit [list $cl $ya $r $rows]
        set r [expr {$r + $gap}]
    }
    # the clusters' numbers where they fit, the selected ones first (blocks
    # are as tall as their clusters: not every n-th)
    set lh [::VMDance::Plot::lh]
    set taken {}
    foreach pass {1 0} {
        foreach l $labs {
            lassign $l cl ym
            if {[on $cl] != $pass} continue
            set free 1
            foreach t $taken { if {abs($t - $ym) < $lh} { set free 0; break } }
            if {!$free} continue
            $c create text [expr {$x0 - 6}] $ym -text $cl -anchor e -font [expr {$pass ? "MdvBold" : "MdvSmall"}] -fill [theme text] -tags label
            lappend taken $ym
        }
    }
    $c create line $xz $y0 $xz $y1 -fill [theme axis] -tags axis
    set mean [expr {[::tcl::mathop::+ {*}$all] / double([llength $all])}]
    if {[S sl_mean]} {
        set xm [::VMDance::Plot::X $c $mean]
        $c create line $xm $y0 $xm $y1 -fill [theme cursor] -dash {6 3} -width 1.2 -tags mean
        $c create text [expr {$xm + 4}] [expr {$y0 + 2}] -anchor nw -font MdvSmall -fill [theme cursor] -text [format "mean %.3f" $mean] -tags mean
    }
    set H($c,sil) [list $ytot $hit]
}
proc ::VMDance::Plots::_sil_at {c x y} {
    variable H
    if {![info exists H($c,sil)] || ![::VMDance::Plot::inside $c $x $y]} { return {} }
    lassign $H($c,sil) ytot hit
    # (blocks start at a fraction of a row with many clusters)
    set r [expr {$ytot - [::VMDance::Plot::invY $c $y]}]
    foreach h $hit {
        lassign $h cl ya yb rows
        if {$r >= $ya && $r < $yb} { return [list $cl [lindex $rows [expr {min([llength $rows] - 1, int(floor($r - $ya)))}]]] }
    }
    return {}
}
proc ::VMDance::Plots::hover_silhouette {c x y} {
    lassign [_sil_at $c $x $y] cl p
    if {$cl eq ""} { return "" }
    lassign $p i v
    format "frame %s (cluster %d): silhouette %.3f" [lindex [::VMDance::Results::frames] $i] $cl $v
}
proc ::VMDance::Plots::click_silhouette {c x y add} {
    lassign [_sil_at $c $x $y] cl p
    if {$cl eq ""} return
    ::VMDance::GUI::goto_frame [lindex [::VMDance::Results::frames] [lindex $p 0]]
    ::VMDance::GUI::select [list $cl] $add
}

#---------------------------------------------------------------------------
# Elbow: the scores at every k
#---------------------------------------------------------------------------

proc ::VMDance::Plots::draw_elbow {c} {
    variable H; variable ch_col; variable db_col
    set e $::VMDance::Results::elbow
    set recs [dict get $e records]
    # (an elbow scan of eQUAL is of its radius: the values are radii)
    set radius [::VMDance::Results::by_radius $e]
    set ks [lmap r $recs {::VMDance::Results::scan_x $r}]
    set show [S eb_show]
    set series {}
    if {$show in {both ch}} { lappend series ch $ch_col "Calinski–Harabasz (higher: better)" }
    if {$show in {both db}} { lappend series db $db_col "Davies–Bouldin (lower: better)" }
    set items {}
    foreach {key col lab} $series { lappend items $lab $col }
    set failed [lmap r $recs {expr {[dict get $r status] eq "ok" ? [continue] : [::VMDance::Results::scan_x $r]}}]
    if {[llength $failed]} { lappend items "failed at [expr {$radius ? "radius" : "k ="}] [join $failed {, }]" @none }
    # bars behind, 0 to 1: the agreement between seedings, when the scan has
    # it; of eQUAL's radius, the clusters found (the most: the full height)
    set bars {}
    set stab [expr {[S eb_stability] && [llength [::VMDance::_get [dict get $e request] stability {}]]}]
    if {$stab} {
        lappend items "Stability: agreement between seedings (bars, 0 to 1)" #c9d3df
        foreach r $recs {
            set v [::VMDance::_get $r stability ""]
            if {$v ne "" && $v > 0} { lappend bars [list [::VMDance::Results::scan_x $r] [expr {min(1.0, $v)}] [format %.2f $v]] }
        }
    } elseif {$radius} {
        lappend items "Clusters found (bars)" #c9d3df
        set most [::tcl::mathfunc::max 1 {*}[lmap r $recs {expr {[dict get $r nclusters] eq "" ? 0 : [dict get $r nclusters]}}]]
        foreach r $recs {
            if {[dict get $r status] ne "ok"} continue
            lappend bars [list [dict get $r radius] [expr {double([dict get $r nclusters]) / $most}] [dict get $r nclusters]]
        }
    }
    set ml [::VMDance::Plot::ml]
    set mr [expr {$show eq "both" ? $ml : 18}]
    set mt [_legend_margin $c $items $ml $mr]
    set kmin [::tcl::mathfunc::min {*}$ks]; set kmax [::tcl::mathfunc::max {*}$ks]
    if {$kmax == $kmin} { set kmax [expr {$kmin + 1}] }
    # (the half gap around the values: k's 0.5; radii's, half the smallest gap)
    set half 0.5
    if {$radius} {
        set sorted [lsort -real $ks]
        set half [expr {($kmax - $kmin) / 2.0}]
        foreach a [lrange $sorted 0 end-1] b [lrange $sorted 1 end] { if {$b > $a} { set half [expr {min($half, ($b - $a) / 2.0)}] } }
    }
    # each score on its own scale: the first on the left axis
    set first 1
    foreach {key col lab} $series {
        set vals [lmap r $recs {expr {[dict get $r status] eq "ok" && [dict get $r $key] ne "" ? [dict get $r $key] : [continue]}}]
        if {![llength $vals]} { set lo 0; set hi 1 } else { set lo [::tcl::mathfunc::min {*}$vals]; set hi [::tcl::mathfunc::max {*}$vals] }
        if {$hi == $lo} { set d [expr {$hi == 0 ? 1.0 : abs($hi) * 0.1}]; set lo [expr {$lo - $d}]; set hi [expr {$hi + $d}] }
        set pad [expr {($hi - $lo) * 0.1}]
        set rng($key) [list [expr {$lo - $pad}] [expr {$hi + $pad}]]
    }
    set k0 [lindex $series 0]
    lassign $rng($k0) lo hi
    ::VMDance::Plot::setup $c [expr {$kmin - $half}] [expr {$kmax + $half}] $lo $hi [list $ml $mt $mr [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c [expr {$radius ? "Radius (MDANCE's MSD, Å²)" : "Number of clusters (k)"}] [lindex $series 2] $ks auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    if {[llength $bars]} {
        set bw [expr {max(3.0, ([::VMDance::Plot::X $c [expr {$kmin + $half}]] - [::VMDance::Plot::X $c $kmin]))}]
        foreach b $bars {
            lassign $b bx v txt
            set px [::VMDance::Plot::X $c $bx]
            set py [expr {$y1 - $v * ($y1 - $y0)}]
            $c create rectangle [expr {$px - $bw / 2}] $py [expr {$px + $bw / 2}] $y1 -fill #dfe5ec -outline #c9d3df -tags stability
            if {$bw >= [font measure MdvSmall $txt] + 2} {
                $c create text $px [expr {$py + 2}] -text $txt -anchor n -font MdvSmall -fill [theme muted] -tags stability
            }
        }
        # (above the grid, behind the scores' lines)
        $c raise stability plotbg
        if {[llength [$c find withtag grid]]} { $c raise stability grid }
    }
    set w [expr {[lw] + 0.6}]
    foreach {key col lab} $series {
        lassign $rng($key) lo hi
        set pts {}
        foreach r $recs {
            if {[dict get $r status] ne "ok" || [dict get $r $key] eq ""} continue
            set px [::VMDance::Plot::X $c [::VMDance::Results::scan_x $r]]
            set py [expr {$y1 - ([dict get $r $key] - $lo) / ($hi - $lo) * ($y1 - $y0)}]
            lappend pts $px $py
        }
        if {[llength $pts] >= 4} { $c create line {*}$pts -fill $col -width $w -tags series }
        foreach {px py} $pts { $c create oval [expr {$px - 4}] [expr {$py - 4}] [expr {$px + 4}] [expr {$py + 4}] -fill $col -outline white -tags series }
        if {$key ne $k0} {
            # the right axis
            $c create line $x1 $y0 $x1 $y1 -fill [theme axis] -tags axis
            foreach t [::VMDance::Plot::nice_ticks $lo $hi 5] {
                set py [expr {$y1 - ($t - $lo) / ($hi - $lo) * ($y1 - $y0)}]
                if {$py < $y0 - 0.5 || $py > $y1 + 0.5} continue
                $c create line $x1 $py [expr {$x1 + 4}] $py -fill [theme axis] -tags axis
                $c create text [expr {$x1 + 6}] $py -text [::VMDance::Plot::_stepfmt $lo $hi 5 $t] -anchor w -font MdvSmall -fill $col -tags axis
            }
            $c create text [expr {[lindex [::VMDance::Plot::size $c] 0] - 10}] [expr {($y0 + $y1) / 2.0}] -text $lab -angle 90 \
                -font [::VMDance::Plot::_fit_font $lab [expr {$y1 - $y0}]] -fill $col -tags axis
        }
    }
    # failed values of k: a cross on the axis
    foreach k $failed {
        set px [::VMDance::Plot::X $c $k]
        $c create line [expr {$px - 4}] [expr {$y1 - 4}] [expr {$px + 4}] [expr {$y1 + 4}] -fill [theme cursor] -width 2 -tags series
        $c create line [expr {$px - 4}] [expr {$y1 + 4}] [expr {$px + 4}] [expr {$y1 - 4}] -fill [theme cursor] -width 2 -tags series
    }
    # the current clustering's k (eQUAL's radius), when it is of the scan's algorithm
    if {[::VMDance::Results::has_data] && [dict get [::VMDance::Results::request] algorithm] eq [dict get $e request algorithm]} {
        set q [::VMDance::Results::request]
        set cur [expr {$radius ? [::VMDance::_get [dict get $q params] threshold ""] : [dict get $q k]}]
        if {[string is double -strict $cur] && [llength [lmap v $ks {expr {$v == $cur ? 1 : [continue]}}]]} {
            set px [::VMDance::Plot::X $c $cur]
            $c create line $px $y0 $px $y1 -fill $::VMDance::Plots::accent -dash {2 3} -tags mark
        }
    }
    _legend $c $items [list $x0 $x1]
    set H($c,elbow) $ks
}
# The scan's value (k, or radius) nearest the pointer, within half the gap
# to the next ("" none).
proc ::VMDance::Plots::_k_at {c x y} {
    variable H
    if {![info exists H($c,elbow)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set best ""; set bd Inf
    set pxs [lsort -real [lmap k $H($c,elbow) {::VMDance::Plot::X $c $k}]]
    set gap Inf
    foreach a [lrange $pxs 0 end-1] b [lrange $pxs 1 end] { if {$b > $a} { set gap [expr {min($gap, $b - $a)}] } }
    foreach k $H($c,elbow) {
        set d [expr {abs([::VMDance::Plot::X $c $k] - $x)}]
        if {$d < $bd} { set bd $d; set best $k }
    }
    expr {$bd <= max(6.0, $gap / 2.0) ? $best : ""}
}
proc ::VMDance::Plots::_elbow_record {k} { ::VMDance::Results::elbow_record $::VMDance::Results::elbow $k }
# A scan value as said: "k = 6", "radius 1.5".
proc ::VMDance::Plots::_at_words {k} {
    expr {[::VMDance::Results::by_radius $::VMDance::Results::elbow] ? "radius $k" : "k = $k"}
}
proc ::VMDance::Plots::hover_elbow {c x y} {
    set k [_k_at $c $x $y]
    $c delete partition
    if {$k eq ""} { return "" }
    set r [_elbow_record $k]
    if {[dict get $r status] ne "ok"} { return "[_at_words $k] failed: [dict get $r message]" }
    if {[S eb_partition]} { _partition $c $x $y $k $r }
    set s [_at_words $k]
    if {[dict exists $r radius]} {
        append s " ([dict get $r nclusters] clusters)"
    } elseif {[dict get $r nclusters] != $k} { append s " (found [dict get $r nclusters])" }
    append s ": Calinski–Harabasz [_sc [dict get $r ch]], Davies–Bouldin [_sc [dict get $r db]]"
    if {[::VMDance::_get $r stability ""] ne ""} { append s ", stability [format %.2f [dict get $r stability]]" }
    append s " · double-click: make it the clustering"
    return $s
}
proc ::VMDance::Plots::_sc {v} { expr {$v eq "" ? "n/a" : [format %.4g $v]} }
# The clusters' shares at k, in a box by the pointer.
proc ::VMDance::Plots::_partition {c x y k r} {
    set sizes [dict get $r sizes]
    set tot [::tcl::mathop::+ 0 {*}$sizes]
    if {$tot <= 0} return
    set lh [::VMDance::Plot::lh]
    set rh [expr {$lh + 1}]
    set bw 120
    set n [llength $sizes]
    set found [dict get $r nclusters]
    set shown [expr {min($n, 16)}]
    set bh [expr {8 + $rh * ($shown + 1) + ($n > $shown ? $rh : 0)}]
    set tw [font measure MdvSmall "100.0%"]
    set boxw [expr {$bw + $tw + 36}]
    lassign [::VMDance::Plot::size $c] W Hh
    set bx [expr {$x + 14}]
    if {$bx + $boxw > $W - 4} { set bx [expr {$x - 14 - $boxw}] }
    set by [expr {max(4, min($Hh - $bh - 4, $y - $bh / 2.0))}]
    $c create rectangle $bx $by [expr {$bx + $boxw}] [expr {$by + $bh}] -fill white -outline [theme muted] -tags partition
    $c create text [expr {$bx + 6}] [expr {$by + 4}] -anchor nw -font MdvBold -fill [theme text] \
        -text [expr {[dict exists $r radius] ? "radius $k: $found clusters" : "k = $k[expr {$found != $k ? " (found $found)" : ""}]"}] -tags partition
    # (the bars scaled to the largest share: the widths compare the clusters)
    set fmax [expr {double([::tcl::mathfunc::max {*}$sizes]) / $tot}]
    for {set i 0} {$i < $shown} {incr i} {
        set f [expr {double([lindex $sizes $i]) / $tot}]
        set yy [expr {$by + 4 + $rh * ($i + 1)}]
        $c create text [expr {$bx + 6}] [expr {$yy + $rh / 2.0}] -anchor w -font MdvSmall -fill [theme text] -text $i -tags partition
        set xa [expr {$bx + 26}]
        $c create rectangle $xa [expr {$yy + 2}] [expr {$xa + max(1, $f / $fmax * $bw)}] [expr {$yy + $rh - 2}] -fill [ccol $i 0] -outline "" -tags partition
        $c create text [expr {$xa + $bw + 4}] [expr {$yy + $rh / 2.0}] -anchor w -font MdvSmall -fill [theme text] \
            -text [format %.1f%% [expr {100 * $f}]] -tags partition
    }
    if {$n > $shown} {
        $c create text [expr {$bx + 6}] [expr {$by + 4 + $rh * ($shown + 1)}] -anchor nw -font MdvSmall -fill [theme muted] \
            -text "… [expr {$n - $shown}] more" -tags partition
    }
}
proc ::VMDance::Plots::click_elbow {c x y add} {}
proc ::VMDance::Plots::dclick_elbow {c x y} {
    set k [_k_at $c $x $y]
    if {$k ne ""} { ::VMDance::GUI::adopt elbow $k }
}

#---------------------------------------------------------------------------
# Sweep: the scores of every configuration
#---------------------------------------------------------------------------

proc ::VMDance::Plots::_sweep_grid {} {
    set s $::VMDance::Results::sweep
    set recs [dict get $s records]
    set key [S sw_score]
    set combos {}; set ks {}
    set cell [dict create]
    set i 0
    foreach r $recs {
        set combo "[::VMDance::Algo::label [dict get $r algorithm]] · [dict get $r metric] · [::VMDance::Export::sweep_seeding $r]"
        if {$combo ni $combos} { lappend combos $combo }
        if {[dict get $r k] ni $ks} { lappend ks [dict get $r k] }
        dict set cell $combo,[dict get $r k] $i
        incr i
    }
    list $recs $key $combos [lsort -integer $ks] $cell
}
proc ::VMDance::Plots::draw_sweep {c} {
    variable H; variable bg
    lassign [_sweep_grid] recs key combos ks cell
    set vals [lmap r $recs {expr {[dict get $r status] eq "ok" && [dict get $r $key] ne "" ? [dict get $r $key] : [continue]}}]
    if {![llength $vals]} { ::VMDance::Plot::empty $c "No [expr {$key eq "ch" ? "Calinski–Harabasz" : "Davies–Bouldin"}] score" "No configuration of the sweep has one."; return }
    set lo [::tcl::mathfunc::min {*}$vals]; set hi [::tcl::mathfunc::max {*}$vals]
    if {$hi == $lo} { set hi [expr {$lo + 1}] }
    set best [::VMDance::sweep_best $::VMDance::Results::sweep $key]
    lassign [::VMDance::Plot::size $c] W Hh
    set lh [::VMDance::Plot::lh]
    set lwid 0
    foreach cb $combos { set lwid [expr {max($lwid, [font measure MdvSmall $cb])}] }
    set ml [expr {int(min($W * 0.45, $lwid + 14))}]
    set mt [expr {16 + [::VMDance::Plot::bar_height]}]
    set mb [::VMDance::Plot::mb]
    set nr [llength $combos]; set nc [llength $ks]
    set cw [expr {max(4.0, double($W - $ml - 18) / $nc)}]
    set ch [expr {max(4.0, min(40.0, double($Hh - $mt - $mb) / $nr))}]
    set x0 $ml; set y0 $mt
    ::VMDance::Plot::setup $c -0.5 [expr {$nc - 0.5}] 0 $nr [list $x0 $y0 [expr {$W - $x0 - $cw * $nc}] [expr {$Hh - $y0 - $ch * $nr}]]
    set cmap [S sw_cmap]
    if {$key eq "db"} { set cmap [expr {[string match *_r $cmap] ? [string range $cmap 0 end-2] : "${cmap}_r"}] }
    set i 0
    foreach cb $combos {
        set j 0
        foreach k $ks {
            set xa [expr {$x0 + $j * $cw}]; set ya [expr {$y0 + $i * $ch}]
            set col #eceef3
            set txt ""
            if {[dict exists $cell $cb,$k]} {
                set r [lindex $recs [dict get $cell $cb,$k]]
                if {[dict get $r status] ne "ok"} {
                    set col #f3d9d9; set txt "×"
                } elseif {[dict get $r $key] ne ""} {
                    set col [::VMDance::Cmap::at $cmap [expr {(double([dict get $r $key]) - $lo) / ($hi - $lo)}]]
                    set txt [format [expr {$key eq "ch" ? "%.3g" : "%.3f"}] [dict get $r $key]]
                }
            }
            $c create rectangle $xa $ya [expr {$xa + $cw}] [expr {$ya + $ch}] -fill $col -outline white -tags cell
            if {[S mx_values] && $txt ne "" && $cw >= [font measure MdvSmall $txt] + 4 && $ch >= $lh} {
                $c create text [expr {$xa + $cw / 2.0}] [expr {$ya + $ch / 2.0}] -text $txt -font MdvSmall \
                    -fill [expr {$col ne "#eceef3" && $col ne "#f3d9d9" && [_dark $col] ? "white" : "#222222"}] -tags label
            }
            if {[dict exists $cell $cb,$k] && [dict get $cell $cb,$k] == $best} {
                $c create rectangle [expr {$xa + 1}] [expr {$ya + 1}] [expr {$xa + $cw - 1}] [expr {$ya + $ch - 1}] -outline #111111 -width 2 -tags best
            }
            incr j
        }
        $c create text [expr {$x0 - 6}] [expr {$y0 + ($i + 0.5) * $ch}] -text $cb -anchor e -font MdvSmall -fill [theme text] -tags label
        incr i
    }
    set step [expr {max(1, int(ceil(([font measure MdvSmall 000] + 6) / $cw)))}]
    set j 0
    foreach k $ks {
        if {$j % $step == 0} { $c create text [expr {$x0 + ($j + 0.5) * $cw}] [expr {$y0 + $nr * $ch + 4}] -text $k -anchor n -font MdvSmall -fill [theme text] -tags label }
        incr j
    }
    $c create text [expr {$x0 + $nc * $cw / 2.0}] [expr {$y0 + $nr * $ch + 6 + $lh}] -text "Number of clusters (k)" -anchor n -font MdvText -fill [theme text] -tags axis
    set title [expr {$key eq "ch" ? {"Calinski–Harabasz (higher: better; outlined: the best)" "Calinski–Harabasz"} : {"Davies–Bouldin (lower: better; outlined: the best)" "Davies–Bouldin"}}]
    set bar [lmap t {0 1 2 3 4 5 6 7 8 9 10} {::VMDance::Cmap::at $cmap [expr {$t / 10.0}]}]
    ::VMDance::Plot::colorbar_titled $c $x0 6 $bar [::VMDance::Plot::fmt $lo] [::VMDance::Plot::fmt $hi] $title
    set H($c,sweep) [list $x0 $y0 $cw $ch $combos $ks $cell]
}
proc ::VMDance::Plots::_sweep_at {c x y} {
    variable H
    if {![info exists H($c,sweep)]} { return "" }
    lassign $H($c,sweep) x0 y0 cw ch combos ks cell
    set j [expr {int(floor(($x - $x0) / $cw))}]; set i [expr {int(floor(($y - $y0) / $ch))}]
    if {$i < 0 || $j < 0 || $i >= [llength $combos] || $j >= [llength $ks]} { return "" }
    set key [lindex $combos $i],[lindex $ks $j]
    expr {[dict exists $cell $key] ? [dict get $cell $key] : ""}
}
proc ::VMDance::Plots::hover_sweep {c x y} {
    set i [_sweep_at $c $x $y]
    if {$i eq ""} { return "" }
    set r [lindex [dict get $::VMDance::Results::sweep records] $i]
    set s "[::VMDance::Algo::label [dict get $r algorithm]], k [dict get $r k], [dict get $r metric], [::VMDance::Export::sweep_seeding $r]"
    if {[dict get $r status] ne "ok"} { return "$s: failed ([dict get $r message])" }
    append s ": [dict get $r nclusters] clusters, Calinski–Harabasz [_sc [dict get $r ch]], Davies–Bouldin [_sc [dict get $r db]] · double-click: make it the clustering"
}
proc ::VMDance::Plots::click_sweep {c x y add} {
    set i [_sweep_at $c $x $y]
    if {$i ne ""} { ::VMDance::GUI::sweep_row $i }
}
proc ::VMDance::Plots::dclick_sweep {c x y} {
    set i [_sweep_at $c $x $y]
    if {$i ne ""} { ::VMDance::GUI::adopt sweep $i }
}
