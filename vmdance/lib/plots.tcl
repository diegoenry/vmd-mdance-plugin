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
    # (past the 29 colours they come again: lighter the second time,
    # darker the third, so that clusters 0, 29 and 58 are not one blue)
    set round [expr {$c / [llength $::VMDance::Viz::ids]}]
    if {$round} { set col [_again $col $round] }
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

# The time between two frames of the molecule, from the plot option "Time
# per frame" ("0.1 ns", "2 ps"): {value unit}; {} when none is given (the
# axes are then in frames).
proc ::VMDance::Plots::time_ok {v} {
    expr {$v eq "" || ([regexp {^([0-9]+\.?[0-9]*|\.[0-9]+) ?(fs|ps|ns|µs|us|ms|s)$} $v -> n] && ![regexp {^0[0-9]} $n] && $n > 0 && $n < 1e9)}
}
proc ::VMDance::Plots::_time {} {
    set v [string trim [S plot_time]]
    if {$v eq "" || ![time_ok $v]} { return {} }
    regexp {^([0-9.]+) ?(.*)$} $v -> n u
    list $n [expr {$u eq "us" ? "µs" : $u}]
}
# The axis of the frames: {title format}: "Frame" and the frames' numbers,
# or "Time (ns)" and each frame's time.
proc ::VMDance::Plots::_frame_axis {} {
    set t [_time]
    if {![llength $t]} { return [list "Frame" ""] }
    lassign $t n u
    list "Time ($u)" [list apply {{n v} { ::VMDance::Plot::fmt [expr {round($v * $n * 1e6) / 1e6}] }} $n]
}
# The axes of a plot along the frames: Plot::axes with the frames' title
# and format (opts: its options).
proc ::VMDance::Plots::_frame_axes {c ylab yticks opts} {
    lassign [_frame_axis] title fmt
    if {$fmt ne ""} { dict set opts xfmt $fmt }
    ::VMDance::Plot::axes $c $title $ylab auto $yticks $opts
}
# A frame as said in a readout: "frame 1200", with its time when the time
# per frame is given ("frame 1200 (120 ns)").
proc ::VMDance::Plots::_frame_words {f} {
    set t [_time]
    if {![llength $t]} { return "frame $f" }
    lassign $t n u
    return "frame $f ([::VMDance::Plot::fmt [expr {round($f * $n * 1e6) / 1e6}]] $u)"
}
# A squared distance (Å²) as the plots show it: itself, or its square root
# (Å) when the plot option "Distances as" asks for lengths; and that unit.
proc ::VMDance::Plots::_len {v} { expr {$v eq "" ? "" : ([S plot_len] eq "a" ? sqrt($v) : $v)} }
proc ::VMDance::Plots::_lenu {} { expr {[S plot_len] eq "a" ? "Å" : "Å²"} }
proc ::VMDance::Plots::_roots {} { expr {[S plot_len] eq "a"} }

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
    unset -nocomplain ::VMDance::Plot::G($c,empty)
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

# Vertical bars: items {cluster value ?note?}, the y axis label. A bar's
# value is written above it (fmt), with its note when both have room
# ("2.2 · longest 20"), alone when only it has.
proc ::VMDance::Plots::_bars {c items ylab {fmt ""} {ymin 0}} {
    variable H
    set n [llength $items]
    if {!$n} { ::VMDance::Plot::empty $c "Nothing to draw"; return }
    set top 0
    foreach it $items {
        lassign $it cl v
        if {$v ne "" && $v > $top} { set top $v }
    }
    if {$top <= $ymin} { set top [expr {$ymin + 1}] }
    set labels [lmap it $items {clabel [lindex $it 0]}]
    set ml [::VMDance::Plot::ml]
    ::VMDance::Plot::setup $c -0.5 [expr {$n - 0.5}] $ymin [expr {$top * 1.12}] [list $ml 18 18 [::VMDance::Plot::mb]]
    set xt {}
    for {set i 0} {$i < $n} {incr i} { lappend xt $i }
    ::VMDance::Plot::axes $c "Cluster" $ylab $xt auto [dict merge [gridopt] [dict create xfmt [_catfmt $labels] dense [expr {$n > 40}]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set bw [expr {max(2.0, 0.72 * ($x1 - $x0) / $n)}]
    set i 0
    set hit {}
    foreach it $items {
        lassign $it cl v note
        set cx [::VMDance::Plot::X $c $i]
        set xa [expr {$cx - $bw / 2.0}]; set xb [expr {$cx + $bw / 2.0}]
        if {$v ne ""} {
            set yt [::VMDance::Plot::Y $c $v]
            set sel [expr {$cl >= 0 && [on $cl]}]
            $c create rectangle $xa $yt $xb [::VMDance::Plot::Y $c $ymin] -fill [ccol $cl] \
                -outline [expr {$sel ? "#111111" : ""}] -width [expr {$sel ? 2 : 1}] -tags bar
            if {$fmt ne ""} {
                set txt [format $fmt $v]
                foreach t [expr {$note ne "" ? [list "$txt · $note" $txt] : [list $txt]}] {
                    if {$bw < [font measure MdvSmall $t] + 2} continue
                    $c create text $cx [expr {$yt - 3}] -text $t -anchor s -font MdvSmall -fill [theme text] -tags label
                    break
                }
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
    switch -- [S tl_view] {
        msd { _timeline_msd $c }
        shares { _timeline_shares $c }
        cumulative { _timeline_cumulative $c }
        default { _timeline_lanes $c }
    }
}

# Whether canvas c is a figure's (drawn off screen): what the window draws
# as an image, a pixel a column, is then drawn as shapes finer than its
# pixels, so that a small figure is sharp at any resolution (an image is
# written at 72 dots an inch: a lane 164 pixels wide for 6001 frames).
proc ::VMDance::Plots::_figure {c} { expr {![winfo ismapped $c]} }

# One lane per cluster (noise at the bottom), a bar where the trajectory
# is in it. With more frames than columns to draw them in, a column of a
# lane is shaded by the share of its frames that are in the cluster (five
# tones: a bar a run, a pixel wide at least, filled every lane wherever
# its cluster had one frame, and a trajectory that changes cluster every
# other frame looked as if it were in all of them all the time).
proc ::VMDance::Plots::_timeline_lanes {c} {
    variable H
    set k [K]
    set fr [::VMDance::Results::frames]
    set n [llength $fr]
    set noise [expr {[::VMDance::Results::noise] > 0}]
    set lanes [expr {$k + $noise}]
    set lanelabels {}
    if {$noise} { lappend lanelabels noise }
    for {set i 0} {$i < $k} {incr i} { lappend lanelabels $i }
    set step [dict get [::VMDance::Results::request] step]
    set xmax [expr {[lindex $fr end] + $step}]
    set ml [expr {max([::VMDance::Plot::ml], [font measure MdvSmall noise] + 22)}]
    set mb [::VMDance::Plot::mb]
    # (the area's width first: whether the lanes are shaded, which is said
    # in a note above them)
    ::VMDance::Plot::setup $c [lindex $fr 0] $xmax -0.5 [expr {$lanes - 0.5}] [list $ml 14 18 $mb]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set iw [expr {max(1, int($x1 - $x0))}]
    set fig [_figure $c]
    set cols [expr {$fig ? min($n, 4 * $iw) : $iw}]
    set dense [expr {$n > $cols}]
    if {$dense} {
        ::VMDance::Plot::setup $c [lindex $fr 0] $xmax -0.5 [expr {$lanes - 0.5}] [list $ml [expr {max(14, [::VMDance::Plot::note_margin])}] 18 $mb]
    }
    set yt {}
    for {set i 0} {$i < $lanes} {incr i} { lappend yt $i }
    _frame_axes $c "Cluster" $yt [dict merge [gridopt] [dict create yfmt [_catfmt $lanelabels]]]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set ih [expr {max(1, int($y1 - $y0))}]
    set band [expr {double($ih) / $lanes}]
    set th [S tl_bar]
    if {![string is double -strict $th] || [regexp -nocase {nan|inf} $th] || $th <= 0 || $th > 1} { set th 0.5 }
    set bh [expr {max(2.0, $band * $th)}]
    set img ""
    if {!$fig} { set img [_image $c $iw $ih] }
    if {!$dense && !$fig} {
        # every run of frames in one cluster: a bar across its pixel columns
        set span [expr {double($xmax - [lindex $fr 0])}]
        set f0 [lindex $fr 0]
        foreach r [::VMDance::Results::residence] {
            lassign $r l s len
            set fa [lindex $fr $s]
            set fb [expr {[lindex $fr [expr {$s + $len - 1}]] + $step}]
            set pa [expr {int(($fa - $f0) / $span * $iw)}]
            set pb [expr {max($pa + 1, int(($fb - $f0) / $span * $iw))}]
            set lane [expr {$l < 0 ? 0 : $l + $noise}]
            set yc [expr {$ih - ($lane + 0.5) * $band}]
            set ya [expr {int($yc - $bh / 2.0)}]; set yb [expr {max($ya + 2, int($yc + $bh / 2.0))}]
            $img put [ccol $l] -to [expr {min($pa, $iw - 1)}] $ya [expr {min($pb, $iw)}] $yb
        }
    } else {
        # the frames of each lane in each column (column j holds the rows
        # from ceil(j n / cols) to the next column's first, less one)
        foreach r [::VMDance::Results::residence] {
            lassign $r l s len
            set lane [expr {$l < 0 ? 0 : $l + $noise}]
            set e [expr {$s + $len - 1}]
            set ja [expr {$s * $cols / $n}]; set jb [expr {$e * $cols / $n}]
            if {$ja == $jb} {
                incr cnt($lane,$ja) $len
            } else {
                for {set j $ja} {$j <= $jb} {incr j} {
                    set a [expr {max($s, ($j * $n + $cols - 1) / $cols)}]
                    set b [expr {min($e, (($j + 1) * $n + $cols - 1) / $cols - 1)}]
                    if {$b >= $a} { incr cnt($lane,$j) [expr {$b - $a + 1}] }
                }
            }
        }
        set Q 5
        set cw [expr {double($iw) / $cols}]
        for {set lane 0} {$lane < $lanes} {incr lane} {
            set l [expr {$lane - $noise}]
            set base [ccol $l]
            set tones {}
            for {set q 1} {$q <= $Q} {incr q} { lappend tones [::VMDance::Cmap::tint $base [expr {0.8 * ($Q - $q) / ($Q - 1.0)}]] }
            set yc [expr {$ih - ($lane + 0.5) * $band}]
            set ya [expr {int($yc - $bh / 2.0)}]; set yb [expr {max($ya + 2, int($yc + $bh / 2.0))}]
            set prev 0; set start 0
            for {set j 0} {$j <= $cols} {incr j} {
                set lvl 0
                if {$j < $cols && [info exists cnt($lane,$j)]} {
                    set tot [expr {(($j + 1) * $n + $cols - 1) / $cols - ($j * $n + $cols - 1) / $cols}]
                    set lvl [expr {min($Q, max(1, int(ceil($Q * double($cnt($lane,$j)) / max(1, $tot)))))}]
                }
                if {$lvl == $prev} continue
                if {$prev} {
                    set col [lindex $tones [expr {$prev - 1}]]
                    if {$fig} {
                        $c create rectangle [expr {$x0 + $start * $cw}] [expr {$y0 + $ya}] [expr {$x0 + $j * $cw}] [expr {$y0 + $yb}] \
                            -fill $col -outline "" -tags raster
                    } else {
                        $img put $col -to $start $ya $j $yb
                    }
                }
                set prev $lvl; set start $j
            }
        }
        if {$dense} { ::VMDance::Plot::note $c "the darker, the larger the share of the frames there that are in the cluster" }
    }
    if {!$fig} { $c create image $x0 $y0 -image $img -anchor nw -tags raster }
    $c raise axis
    _frame_cursor $c
    set H($c,tl) lanes
    set H($c,tldense) [expr {$dense ? [list $cols $n] : ""}]
}

# The number of windows of the shares view: the plot option's, else about
# 120, of 10 frames at least.
proc ::VMDance::Plots::_tl_windows {n} {
    set w [S tl_windows]
    if {[::VMDance::whole $w] && $w >= 1} { return [expr {max(1, min($n, $w))}] }
    expr {max(1, int(ceil($n / double(max(10, int(ceil($n / 120.0)))))))}
}
proc ::VMDance::Plots::_tl_shares {} {
    set nb [_tl_windows [::VMDance::Results::nframes]]
    ::VMDance::Results::memo_last plot_shares $nb {
        ::VMDance::Measure::shares [::VMDance::Results::labels] [K] $nb
    }
}
# The legend's items of the clusters (24 at most) and of noise.
proc ::VMDance::Plots::_cluster_items {} {
    set items {}
    for {set cl 0} {$cl < min([K], 24)} {incr cl} { lappend items "cluster $cl" [ccol $cl 0] }
    if {[K] > 24} { lappend items "… [expr {[K] - 24}] more" @none }
    if {[::VMDance::Results::noise]} { lappend items noise [ccol -1] }
    return $items
}

# The clusters' shares of the frames, window by window: stacked, a column
# a window (where the trajectory is when; lanes of a long trajectory that
# changes cluster often do not say it).
proc ::VMDance::Plots::_timeline_shares {c} {
    variable H
    set k [K]
    set fr [::VMDance::Results::frames]
    set n [llength $fr]
    set step [dict get [::VMDance::Results::request] step]
    set xmax [expr {[lindex $fr end] + $step}]
    set W [_tl_shares]
    set items [_cluster_items]
    set ml [::VMDance::Plot::ml]
    set mt [expr {max([_legend_margin $c $items $ml 18], [::VMDance::Plot::note_margin])}]
    if {[S plot_legend] && [llength $items]} { incr mt [::VMDance::Plot::rowh] }
    ::VMDance::Plot::setup $c [lindex $fr 0] $xmax 0 100 [list $ml $mt 18 [::VMDance::Plot::mb]]
    _frame_axes $c "Share of the window's frames (%)" auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    foreach w $W {
        lassign $w a b cnt nz
        set tot [expr {$b - $a + 1}]
        set xa [::VMDance::Plot::X $c [lindex $fr $a]]
        set xb [::VMDance::Plot::X $c [expr {[lindex $fr $b] + $step}]]
        set acc 0
        set cl 0
        foreach v [concat $cnt $nz] {
            if {$v > 0} {
                set ya [::VMDance::Plot::Y $c [expr {100.0 * $acc / $tot}]]
                set yb [::VMDance::Plot::Y $c [expr {100.0 * ($acc + $v) / $tot}]]
                $c create rectangle $xa $yb $xb $ya -fill [ccol [expr {$cl < $k ? $cl : -1}]] -outline "" -tags bar
                incr acc $v
            }
            incr cl
        }
    }
    $c raise axis
    set per [expr {[lindex $W 0 1] - [lindex $W 0 0] + 1}]
    ::VMDance::Plot::note $c "[llength $W] window[expr {[llength $W] == 1 ? "" : "s"}] of $per frame[expr {$per == 1 ? "" : "s"}]"
    _legend $c $items [list $x0 $x1]
    _frame_cursor $c
    set H($c,tl) shares
}

# The clusters' shares of the frames so far, along the trajectory: lines
# that have settled say that the populations have; the frame by which
# every cluster has been seen is marked. (The 40 largest clusters, and
# the selected ones, of more.)
proc ::VMDance::Plots::_timeline_cumulative {c} {
    variable H
    set k [K]
    set fr [::VMDance::Results::frames]
    set n [llength $fr]
    set labels [::VMDance::Results::labels]
    set step [dict get [::VMDance::Results::request] step]
    set xmax [expr {[lindex $fr end] + $step}]
    set sel [selected]
    set which {}
    set by [lsort -integer -decreasing -index 1 [lmap cl [lsearch -all -not -exact [::VMDance::Results::sizes] 0] {list $cl [::VMDance::Results::size $cl]}]]
    foreach p [lrange $by 0 39] { lappend which [lindex $p 0] }
    foreach s $sel { if {$s ni $which && [::VMDance::Results::size $s]} { lappend which $s } }
    set C [::VMDance::Results::memo plot_cumulative {
        # the counts so far at 400 rows at most, and where each cluster is first seen
        set every [expr {max(1, $n / 400)}]
        set cnt [lrepeat $k 0]
        set rows {}; set at {}
        set i 0
        foreach l $labels {
            if {$l >= 0} { lset cnt $l [expr {[lindex $cnt $l] + 1}] }
            incr i
            if {$i % $every == 0 || $i == $n} { lappend at $i; lappend rows $cnt }
        }
        list $at $rows [::VMDance::Measure::first_seen $labels $k]
    }]
    lassign $C at rows first
    set top 0.0
    foreach row $rows i $at { foreach cl $which { set top [expr {max($top, 100.0 * [lindex $row $cl] / $i)}] } }
    if {$top <= 0} { set top 1.0 }
    set items {}
    foreach cl [lrange [lsort -integer $which] 0 23] { lappend items "cluster $cl" [ccol $cl 0] }
    if {[llength $which] > 24} { lappend items "… [expr {[llength $which] - 24}] more" @none }
    set ml [::VMDance::Plot::ml]
    set mt [expr {max([_legend_margin $c $items $ml 18], [::VMDance::Plot::note_margin])}]
    if {[S plot_legend] && [llength $items]} { incr mt [::VMDance::Plot::rowh] }
    ::VMDance::Plot::setup $c [lindex $fr 0] $xmax 0 [expr {min(100.0, $top * 1.08)}] [list $ml $mt 18 [::VMDance::Plot::mb]]
    _frame_axes $c "Share of the frames so far (%)" auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set w [lw]
    foreach cl [lsort -integer -index 0 [lmap cl $which {list [expr {$cl in $sel}] $cl}]] {
        lassign $cl raised cl
        set pts {}
        foreach row $rows i $at {
            lappend pts [::VMDance::Plot::X $c [expr {[lindex $fr [expr {$i - 1}]] + $step}]] [::VMDance::Plot::Y $c [expr {100.0 * [lindex $row $cl] / $i}]]
        }
        if {[llength $pts] >= 4} { $c create line {*}$pts -fill [ccol $cl] -width [expr {$raised ? $w + 1.2 : $w + 0.2}] -tags series }
    }
    # the frame by which every cluster with frames has been seen
    set last [::tcl::mathfunc::max -1 {*}$first]
    set notes {}
    if {$last >= 0} {
        set f [lindex $fr $last]
        set px [::VMDance::Plot::X $c $f]
        $c create line $px $y0 $px $y1 -fill [theme muted] -dash {2 3} -tags mark
        lappend notes "dotted: every cluster seen by frame $f"
    }
    if {[llength $which] < [llength $by]} { lappend notes "the [llength $which] largest of [llength $by] clusters" }
    if {[llength $notes]} { ::VMDance::Plot::note $c [join $notes "; "] }
    _legend $c $items [list $x0 $x1]
    _frame_cursor $c
    set H($c,tl) cumulative
}

# Every frame's RMSD² from its representative, coloured by its cluster: a
# line through few frames (400 at most); a dot a frame through more, and
# their running median (a line through thousands of frames that change
# cluster every other one was a scribble).
proc ::VMDance::Plots::_timeline_msd {c} {
    variable H
    set fr [::VMDance::Results::frames]
    set fm [::VMDance::Results::measure frame_msd]
    set labels [::VMDance::Results::labels]
    if {[_roots]} { set fm [lmap v $fm {_len $v}] }
    set vals [lmap v $fm {expr {$v eq "" ? [continue] : $v}}]
    set ymax [expr {[llength $vals] ? [::tcl::mathfunc::max {*}$vals] : 1.0}]
    if {$ymax <= 0} { set ymax 1.0 }
    set n [llength $fr]
    set dots [expr {$n > 400}]
    ::VMDance::Plot::setup $c [lindex $fr 0] [lindex $fr end] 0 [expr {$ymax * 1.08}] \
        [list [::VMDance::Plot::ml] [expr {$dots ? max(14, [::VMDance::Plot::note_margin]) : 14}] 18 [::VMDance::Plot::mb]]
    _frame_axes $c [expr {[_roots] ? "RMSD from its representative (Å)" : "RMSD² from its representative (Å²)"}] auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set w [lw]
    if {!$dots} {
        # one line per run of a cluster (joined to the next frame)
        set pts {}; set prev ""
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
    } else {
        # a dot a frame (200 000 at most, evenly): shapes in a figure of
        # 20 000 frames or fewer, else an image
        set every [expr {max(1, $n / 200000)}]
        set vector [expr {[_figure $c] && $n <= 20000}]
        set iw [expr {max(1, int($x1 - $x0))}]; set ih [expr {max(1, int($y1 - $y0))}]
        if {!$vector} { set img [_image $c $iw $ih] }
        for {set i 0} {$i < $n} {incr i $every} {
            set v [lindex $fm $i]
            if {$v eq ""} continue
            set x [::VMDance::Plot::X $c [lindex $fr $i]]; set y [::VMDance::Plot::Y $c $v]
            if {$vector} {
                $c create rectangle [expr {$x - 0.6}] [expr {$y - 0.6}] [expr {$x + 0.6}] [expr {$y + 0.6}] -fill [ccol [lindex $labels $i]] -outline "" -tags series
            } else {
                set px [expr {max(0, min($iw - 2, int($x - $x0)))}]; set py [expr {max(0, min($ih - 2, int($y - $y0)))}]
                $img put [ccol [lindex $labels $i]] -to $px $py [expr {$px + 2}] [expr {$py + 2}]
            }
        }
        if {!$vector} { $c create image $x0 $y0 -image $img -anchor nw -tags raster }
        # the running median, at 160 places
        set win [expr {max(5, $n / 80)}]
        set pts {}
        for {set j 0} {$j < 160} {incr j} {
            set mid [expr {int(($j + 0.5) * $n / 160.0)}]
            set a [expr {max(0, $mid - $win / 2)}]; set b [expr {min($n - 1, $mid + $win / 2)}]
            set m [_median [lmap v [lrange $fm $a $b] {expr {$v eq "" ? [continue] : $v}}]]
            if {$m eq ""} continue
            lappend pts [::VMDance::Plot::X $c [lindex $fr $mid]] [::VMDance::Plot::Y $c $m]
        }
        if {[llength $pts] >= 4} { $c create line {*}$pts -fill #20242c -width [expr {$w + 0.8}] -tags series }
        $c raise axis
        ::VMDance::Plot::note $c "a dot a frame, in its cluster's colour; line: the median of $win frames around"
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
# The clusters of rows a to b in words, largest first (five at most): as
# counts, or as shares of them.
proc ::VMDance::Plots::_mix_words {a b {percent 0}} {
    array set n {}
    foreach l [lrange [::VMDance::Results::labels] $a $b] { incr n($l) }
    set tot [expr {$b - $a + 1}]
    set l {}
    foreach cl [lrange [lsort -integer -decreasing -index 1 [lmap cl [array names n] {list $cl $n($cl)}]] 0 4] {
        lassign $cl cl v
        lappend l "[expr {$cl < 0 ? "noise" : "cluster $cl"}] [expr {$percent ? [format %.0f%% [expr {100.0 * $v / $tot}]] : $v}]"
    }
    if {[array size n] > 5} { lappend l "…" }
    join $l ", "
}
proc ::VMDance::Plots::hover_timeline {c x y} {
    variable H
    if {![info exists H($c,tl)] || ![::VMDance::Plot::inside $c $x $y]} { return "" }
    set fr [::VMDance::Results::frames]
    set i [_row_at $c $x]
    set f [lindex $fr $i]
    switch -- $H($c,tl) {
        shares {
            foreach w [_tl_shares] {
                lassign $w a b
                if {$i >= $a && $i <= $b} { return "frames [lindex $fr $a] to [lindex $fr $b]: [_mix_words $a $b 1]" }
            }
            return ""
        }
        cumulative { return "up to frame $f: [_mix_words 0 $i 1]" }
        lanes {
            if {$H($c,tldense) ne ""} {
                # (the frames of the column under the pointer)
                lassign $H($c,tldense) cols n
                lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
                set j [expr {max(0, min($cols - 1, int(($x - $x0) * $cols / double(max(1, $x1 - $x0)))))}]
                set a [expr {($j * $n + $cols - 1) / $cols}]; set b [expr {(($j + 1) * $n + $cols - 1) / $cols - 1}]
                if {$b > $a} { return "frames [lindex $fr $a] to [lindex $fr $b]: [_mix_words $a $b]" }
            }
        }
    }
    set l [lindex [::VMDance::Results::labels] $i]
    set m [lindex [::VMDance::Results::measure frame_msd] $i]
    set s "[_frame_words $f]: [expr {$l < 0 ? "noise" : "cluster $l"}]"
    if {$m ne ""} { append s [format ", %s %.3g %s from its representative (frame %s)" [expr {[_roots] ? "RMSD" : "RMSD²"}] [_len $m] [_lenu] [::VMDance::Results::rep_frame $l]] }
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
    if {[S mx_values] && $fmt ne "" && $cs >= [font measure MdvSmall [_cellfmt $fmt $hi]] + 6 && $cs >= $lh + 2} {
        for {set i 0} {$i < $k} {incr i} {
            for {set j 0} {$j < $k} {incr j} {
                set v [lindex $M $i $j]
                if {$v eq "" || ($skipdiag && $i == $j)} continue
                set t [expr {($v - $lo) / double($hi - $lo)}]
                $c create text [expr {$x0 + ($j + 0.5) * $cs}] [expr {$y0 + ($i + 0.5) * $cs}] -text [_cellfmt $fmt $v] \
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
# A cell's value as written: fmt's, and a whole number where %g would
# write an exponent ("1.2e+02" for 120).
proc ::VMDance::Plots::_cellfmt {fmt v} {
    set t [format $fmt $v]
    if {[string first e $t] >= 0 && abs($v) >= 1} { set t [format %.0f $v] }
    return $t
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
    # (frames that go into no cluster are in no column: a row of
    # probabilities then sums to less than 1, said)
    set lost [::tcl::mathop::+ 0 {*}[lindex [_transitions] 3]]
    set long "$t (lag $lag)"
    if {$lost} { set long "$t (lag $lag; $lost into noise: no column)" }
    _matrix $c $M "To cluster" "From cluster" [list $long "$t (lag $lag)" $t] [expr {$counts ? "%d" : "%.2f"}] [S tn_cmap] 0 $hi $skip
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
        if {[_roots]} {
            set M [lmap row $M {lmap v $row {_len $v}}]
            set title {"RMSD between mean structures (Å)" "RMSD (Å)"}
        }
    }
    set hi 0
    foreach row $M { foreach v $row { if {$v ne "" && $v > $hi} { set hi $v } } }
    _matrix $c $M "Cluster" "Cluster" $title "%.3g" [S ds_cmap] 0 $hi
}
proc ::VMDance::Plots::hover_distances {c x y} {
    lassign [_cell $c $x $y] i j
    if {$i eq ""} { return "" }
    set C [lindex [::VMDance::Results::measure centroid_msd] $i $j]
    set R [lindex [::VMDance::Results::measure rep_msd] $i $j]
    set s "clusters $i and $j"
    if {$C ne ""} { append s [format ": mean structures %.3g %s (%s)" [_len $C] [_lenu] [expr {[_roots] ? "RMSD" : "RMSD²"}]] }
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
        # (the longest stay beside the mean, in the label: as a whisker it
        # set the scale, the bars at its foot, and the mean was read at its end)
        set ylab [expr {$vmd || $step == 1 ? "Mean stay (frames)" : "Mean stay (clustered frames, × $step)"}]
        # (as a time, when the time per frame is given)
        set t [_time]
        if {[llength $t]} {
            set f [expr {$step * [lindex $t 0]}]
            set ylab "Mean stay ([lindex $t 1])"
        }
        _bars $c [lmap r $st {list [lindex $r 0] [expr {$f * [lindex $r 2]}] "longest [::VMDance::Plot::fmt [expr {round($f * [lindex $r 4] * 1e6) / 1e6}]]"}] $ylab "%.3g"
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
            _bars $c [lmap r [::VMDance::Results::table] {list [lindex $r 0] [_len [lindex $r 4]]}] \
                [expr {[_roots] ? "RMS distance from the representative (Å)" : "Mean RMSD² from the representative (Å²)"}] "%.3g"
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
            _bars $c [lmap r [::VMDance::Results::table] {list [lindex $r 0] [_len [lindex $r 3]]}] \
                [expr {[_roots] ? "Root mean square deviation within (Å)" : "Mean square deviation within (Å²)"}] "%.3g"
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
        if {$msd ne ""} { lappend pts [list $cl $n [_len $msd]] }
    }
    if {![llength $pts]} { ::VMDance::Plot::empty $c "No cluster MSD" "The backend gave none."; return }
    set xs [lmap p $pts {lindex $p 1}]; set ys [lmap p $pts {lindex $p 2}]
    set xmax [::tcl::mathfunc::max {*}$xs]; set ymax [::tcl::mathfunc::max {*}$ys]
    ::VMDance::Plot::setup $c 0 [expr {$xmax * 1.12 + 1}] 0 [expr {$ymax * 1.15 + 1e-6}] \
        [list [::VMDance::Plot::ml] 18 18 [::VMDance::Plot::mb]]
    ::VMDance::Plot::axes $c "Frames" [expr {[_roots] ? "Root mean square deviation within (Å)" : "Mean square deviation within (Å²)"}] auto auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set mx [::VMDance::Plot::X $c [_median $xs]]; set my [::VMDance::Plot::Y $c [_median $ys]]
    $c create line $mx $y0 $mx $y1 -fill #c4c9d2 -dash {4 3} -tags grid
    $c create line $x0 $my $x1 $my -fill #c4c9d2 -dash {4 3} -tags grid
    set hit {}
    # (smaller dots for many clusters; a cluster's number where it has room,
    # the selected ones' first: hundreds of them were a black column)
    set many [expr {[llength $pts] > 40}]
    set lh [::VMDance::Plot::lh]
    set boxes {}
    foreach p [lsort -integer -decreasing -index 0 [lmap p $pts {list [on [lindex $p 0]] {*}$p}]] {
        lassign $p sel cl n v
        set x [::VMDance::Plot::X $c $n]; set y [::VMDance::Plot::Y $c $v]
        set r [expr {$sel ? 7 : ($many ? 4 : 6)}]
        $c create oval [expr {$x - $r}] [expr {$y - $r}] [expr {$x + $r}] [expr {$y + $r}] -fill [ccol $cl] \
            -outline [expr {$sel ? "#111111" : "white"}] -width [expr {$sel ? 2 : 1}] -tags point
        lappend hit [list $x $y $cl]
        set bx [list [expr {$x + $r + 2}] [expr {$y - $lh / 2.0}] [expr {$x + $r + 4 + [font measure MdvSmall $cl]}] [expr {$y + $lh / 2.0}]]
        set free 1
        foreach b $boxes {
            if {[lindex $bx 0] < [lindex $b 2] && [lindex $b 0] < [lindex $bx 2] && [lindex $bx 1] < [lindex $b 3] && [lindex $b 1] < [lindex $bx 3]} { set free 0; break }
        }
        if {!$free} continue
        lappend boxes $bx [list [expr {$x - $r}] [expr {$y - $r}] [expr {$x + $r}] [expr {$y + $r}]]
        $c create text [expr {$x + $r + 3}] $y -text $cl -anchor w -font [expr {$sel ? "MdvBold" : "MdvSmall"}] -fill [theme text] -tags label
    }
    $c raise point label
    $c raise label
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
    if {[lindex $r 3] ne ""} { append s [format "; %s within %.3g %s" [expr {[_roots] ? "√MSD" : "MSD"}] [_len [lindex $r 3]] [_lenu]] }
    if {[lindex $r 4] ne ""} { append s [format ", %s from its representative %.3g %s" [expr {[_roots] ? "RMS distance" : "RMSD²"}] [_len [lindex $r 4]] [_lenu]] }
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
    set helm [expr {$how eq "helm"}]
    # (a linkage's heights are RMSD²: as lengths when asked; HELM's are
    # the merges' order)
    if {!$helm && [_roots]} { dict for {nd h} $height { dict set height $nd [_len $h] } }
    set hmax 0
    dict for {nd h} $height { if {$h > $hmax} { set hmax $h } }
    if {$hmax <= 0} { set hmax 1 }
    set n [llength $order]
    set final [expr {$helm ? [_helm_final] : {}}]
    set ylab [expr {$helm ? "Merge (in order)" : ([_roots] ? "RMSD between mean structures (Å)" : "RMSD² between mean structures (Å²)")}]
    # (a linkage is not how DIVINE made its clusters: its splits, which
    # CPP-MDANCE does not return, can group them otherwise; nor HELM's
    # merges, for a run that has none)
    set not [::VMDance::_get {divine ", not DIVINE's splits" helm ", not HELM's merges"} [::VMDance::Results::algorithm] ""]
    set xlab [expr {$helm ? "HELM's starting clusters (colour: the cluster they end in)" : "Cluster (average linkage of the mean structures$not)"}]
    # the leaves' labels: side by side when they fit; upright, read from
    # below, when they do not (every n-th when a line's height does not
    # fit between two leaves either): sixty leaves had none at all
    set ml [::VMDance::Plot::ml]
    set lh [::VMDance::Plot::lh]
    set widest 0
    foreach l $order { set widest [expr {max($widest, [font measure MdvSmall $l])}] }
    set room [expr {([lindex [::VMDance::Plot::size $c] 0] - $ml - 18) / double($n)}]
    set lmode [expr {![S td_labels] ? "none" : ($room >= $widest + 3 ? "flat" : "up")}]
    set every [expr {$lmode eq "up" ? max(1, int(ceil(($lh - 2) / $room))) : 1}]
    set mb [::VMDance::Plot::mb $c $xlab]
    if {$lmode eq "up"} { set mb [expr {$mb + max(0, $widest - $lh + 4)}] }
    ::VMDance::Plot::setup $c -0.6 [expr {$n - 0.4}] 0 [expr {$hmax * 1.08}] [list $ml 18 18 $mb]
    ::VMDance::Plot::axes $c [expr {$lmode eq "up" ? "" : $xlab}] $ylab {} auto [gridopt]
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    if {$lmode eq "up"} {
        # (the axis' title under the upright labels)
        lassign [::VMDance::Plot::_xtitle $c $xlab] f wrap
        set tw [expr {$wrap ? $wrap : [font measure $f $xlab]}]
        set W [lindex [::VMDance::Plot::size $c] 0]
        $c create text [expr {max($tw / 2.0 + 2, min($W - $tw / 2.0 - 2, ($x0 + $x1) / 2.0))}] [expr {$y1 + 9 + $widest + 4}] \
            -text $xlab -anchor n -font $f -fill [theme text] -tags axis -width $wrap -justify center
    }
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
    set hit {}
    set li 0
    foreach l $order {
        set px [::VMDance::Plot::X $c [dict get $x $l]]
        set cl [dict get $cl_of $l]
        set r [expr {min(5.0, max(2.0, $room / 3.0))}]
        $c create oval [expr {$px - $r}] [expr {$y1 - $r}] [expr {$px + $r}] [expr {$y1 + $r}] -fill [ccol $cl] \
            -outline [expr {$cl ne "" && $cl >= 0 && [on $cl] ? "#111111" : "white"}] -tags leaf
        if {$lmode eq "flat"} {
            $c create text $px [expr {$y1 + $r + 2}] -text $l -anchor n -font MdvSmall -fill [theme text] -tags label
        } elseif {$lmode eq "up" && $li % $every == 0} {
            $c create text $px [expr {$y1 + $r + 3}] -text $l -angle 90 -anchor e -font MdvSmall -fill [theme text] -tags label
        }
        incr li
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
    if {$how eq "helm" && ![dict exists [::VMDance::Results::get measures] merge_msd]} {
        ::VMDance::Plot::empty $c "No heights" "This run of HELM was made before the heights of its merges were measured: cluster again."
        return
    }
    set hs [lmap h [::VMDance::Results::tree_heights] {_len $h}]
    set ylab [expr {$how eq "helm" ? ([_roots] ? "Merge height: the cluster's √MSD (Å)" : "Merge height: the cluster's MSD (Å²)") : ([_roots] ? "Merge height: RMSD (Å)" : "Merge height: RMSD² (Å²)")}]
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
    # the jump: a merge's height over the one before it (at k + 1), the
    # largest when it stands out: twice the merge before at least, half as
    # much again as the next largest jump, and among the coarser half of
    # the merges (among dozens of starting clusters two of the first
    # merges always differ by some factor: the tau peptide's largest was
    # at k 53, of a continuum that has no place to stop)
    set floor [expr {0.05 * $hi}]
    set ratios {}
    foreach p $pts {
        lassign $p k h
        set i [lsearch -exact -index 0 $pts [expr {$k + 1}]]
        if {$i < 0} continue
        lappend ratios [list $k [expr {$h / max([lindex $pts $i 1], $floor)}]]
    }
    set ratios [lsort -real -decreasing -index 1 $ratios]
    set jump ""; set best 0.0
    if {[llength $ratios]} {
        lassign [lindex $ratios 0] k1 d1
        set d2 [expr {[llength $ratios] > 1 ? [lindex $ratios 1 1] : 1.0}]
        if {$d1 >= 2.0 && $d1 >= 1.5 * $d2 && $k1 <= ($kmin + $kmax) / 2.0} { set jump $k1; set best $d1 }
    }
    # (the clustering's k too: HELM's last merge is at k + 1, its k left of
    # it; the ticks whole numbers of clusters)
    set klo [expr {[K] >= $kmin - 1 && [K] >= 1 ? min($kmin, [K]) : $kmin}]
    set ml [::VMDance::Plot::ml]
    ::VMDance::Plot::setup $c [expr {$klo - 0.5}] [expr {$kmax + 0.5}] 0 [expr {$hi * 1.1}] [list $ml [expr {max(18, [::VMDance::Plot::note_margin])}] 18 [::VMDance::Plot::mb]]
    set kt {}
    for {set k $klo} {$k <= $kmax} {incr k} { lappend kt $k }
    ::VMDance::Plot::axes $c "Clusters before the merge (k)" $ylab $kt auto [gridopt]
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
        ::VMDance::Plot::note $c [format "circled: the jump that stands out (× %.1f), from k = %d to %d" $best $jump [expr {$jump - 1}]] label
    } elseif {[llength $ratios] > 1} {
        ::VMDance::Plot::note $c "no merge stands out from the one before it" label
    }
    # the clustering's k (merges stop there)
    if {[K] >= $klo && [K] <= $kmax} {
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
        return [format "from %d to %d clusters: a merge of height %.4g %s" $k [expr {$k - 1}] [lindex $H($c,heights) $i 1] [_lenu]]
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
    # (of the clusters' mean structures, or of every frame: Plot options)
    set kind [expr {[S sl_kind] eq "pairs" ? "pairs" : "centroid"}]
    set sil [::VMDance::Results::silhouette $kind]
    if {$kind eq "pairs" && ![llength $sil]} {
        ::VMDance::Plot::empty $c "No silhouette from every frame" "This run was made before it was measured: cluster again, or show the silhouette from the clusters' mean structures (Plot options)."
        return
    }
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
    # the axis from the lowest value, a quarter below at most (from 0 when
    # none is below it: from the clusters' mean structures a k-means
    # clustering has none, each frame being in the cluster of the nearest
    # mean, and half the plot was an empty −1 to 0)
    set min [::tcl::mathfunc::min {*}$all]
    set lo [expr {$min < 0 ? max(-1.0, floor($min * 4.0) / 4.0) : 0.0}]
    set xt {}
    set stepx [expr {1.0 - $lo > 1.25 ? 0.5 : 0.25}]
    for {set t $lo} {$t <= 1.0 + 1e-9} {set t [expr {$t + $stepx}]} { lappend xt $t }
    set xtitle [expr {$kind eq "pairs" ? "Silhouette (from every frame, squared distances)" : "Silhouette (from the clusters' mean structures)"}]
    ::VMDance::Plot::setup $c $lo 1 0 $ytot [list $ml [expr {max(18, [::VMDance::Plot::note_margin])}] 18 [::VMDance::Plot::mb $c $xtitle]]
    ::VMDance::Plot::axes $c $xtitle "Cluster" $xt {} [gridopt]
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
        # (above the plot: inside it the label was drawn over the first cluster)
        set t [format "mean %.3f" $mean]
        set hw [expr {[font measure MdvSmall $t] / 2.0}]
        $c create text [expr {max($x0 + $hw, min($x1 - $hw, $xm))}] [expr {$y0 - 3}] -anchor s -font MdvSmall -fill [theme cursor] -text $t -tags mean
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
    set s [format "frame %s (cluster %d): silhouette %.3f" [lindex [::VMDance::Results::frames] $i] $cl $v]
    # (the other kind's, when the run has both)
    set other [expr {[S sl_kind] eq "pairs" ? "centroid" : "pairs"}]
    set o [lindex [::VMDance::Results::silhouette $other] $i]
    if {$o ne ""} { append s [format " (%s: %.3f)" [expr {$other eq "pairs" ? "from every frame" : "from the mean structures"}] $o] }
    return $s
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
    variable H; variable ch_col; variable db_col; variable accent
    set e $::VMDance::Results::elbow
    set recs [dict get $e records]
    # (an elbow scan of eQUAL is of its radius: the values are radii)
    set radius [::VMDance::Results::by_radius $e]
    set ks [lmap r $recs {::VMDance::Results::scan_x $r}]
    set show [S eb_show]
    set series {}
    if {$show in {both ch}} { lappend series ch $ch_col "Calinski–Harabasz (higher: better)" }
    if {$show in {both db}} { lappend series db $db_col "Davies–Bouldin (lower: better)" }
    if {$show eq "explained"} { lappend series explained $accent "Variance the clusters explain (%)" }
    set items {}
    foreach {key col lab} $series { lappend items $lab $col }
    set failed [lmap r $recs {expr {[dict get $r status] eq "ok" ? [continue] : [::VMDance::Results::scan_x $r]}}]
    if {[llength $failed]} { lappend items "failed at [expr {$radius ? "radius" : "k ="}] [join $failed {, }]" @none }
    # bars in a strip of their own under the scores (over the scores'
    # lines their values could not be read, and they had no scale): the
    # agreement between seedings, 0 to 1, when the scan has it; of eQUAL's
    # radius, the clusters found
    set bars {}; set btitle ""; set bmax 1.0
    set stab [expr {[S eb_stability] && [llength [::VMDance::_get [dict get $e request] stability {}]]}]
    if {$stab} {
        set btitle "Stability"
        lappend items "Stability: how alike the seedings' clusters are (below, 0 to 1)" #c9d3df
        foreach r $recs {
            set v [::VMDance::_get $r stability ""]
            if {$v ne ""} { lappend bars [list [::VMDance::Results::scan_x $r] [expr {max(0.0, min(1.0, $v))}] [format %.2f $v]] }
        }
    } elseif {$radius} {
        set btitle "Clusters"
        lappend items "Clusters found (below)" #c9d3df
        set bmax [::tcl::mathfunc::max 1 {*}[lmap r $recs {expr {[dict get $r nclusters] eq "" ? 0 : [dict get $r nclusters]}}]]
        foreach r $recs {
            if {[dict get $r status] ne "ok"} continue
            lappend bars [list [dict get $r radius] [dict get $r nclusters] [dict get $r nclusters]]
        }
    }
    # the current clustering's k (eQUAL's radius), when it is of the scan's algorithm
    set cur ""
    if {[::VMDance::Results::has_data] && [dict get [::VMDance::Results::request] algorithm] eq [dict get $e request algorithm]} {
        set q [::VMDance::Results::request]
        set v [expr {$radius ? [::VMDance::_get [dict get $q params] threshold ""] : [dict get $q k]}]
        if {[string is double -strict $v] && [llength [lmap x $ks {expr {$x == $v ? 1 : [continue]}}]]} {
            set cur $v
            lappend items "dotted: the clustering now" @none
        }
    }
    # what the scan suggests: a ring on those values, and a line of words
    set sug [::VMDance::Results::elbow_suggest $e]
    set words [::VMDance::_elbow_words $e 1]
    set ml [::VMDance::Plot::ml]
    set mr [expr {$show eq "both" ? $ml : 18}]
    set mt [_legend_margin $c $items $ml $mr]
    if {$words ne ""} { set mt [expr {max($mt, [::VMDance::Plot::note_margin]) + ([S plot_legend] && [llength $items] ? [::VMDance::Plot::rowh] : 0)}] }
    set mb [::VMDance::Plot::mb]
    lassign [::VMDance::Plot::size $c] W Hh
    set strip 0; set gap 0
    if {[llength $bars]} {
        set gap 10
        set strip [expr {max(48, int(0.2 * ($Hh - $mt - $mb)))}]
    }
    set kmin [::tcl::mathfunc::min {*}$ks]; set kmax [::tcl::mathfunc::max {*}$ks]
    if {$kmax == $kmin} { set kmax [expr {$kmin + 1}] }
    # (the half gap around the values: k's 0.5; radii's, half the smallest gap)
    set half 0.5
    if {$radius} {
        set sorted [lsort -real $ks]
        set half [expr {($kmax - $kmin) / 2.0}]
        foreach a [lrange $sorted 0 end-1] b [lrange $sorted 1 end] { if {$b > $a} { set half [expr {min($half, ($b - $a) / 2.0)}] } }
    }
    # a record's value of a series ("" none)
    set val {{r key} {
        if {[dict get $r status] ne "ok"} { return "" }
        if {$key ne "explained"} { return [dict get $r $key] }
        set v [::VMDance::Results::explained $r]
        expr {$v eq "" ? "" : 100.0 * $v}
    }}
    # each score on its own scale: the first on the left axis
    foreach {key col lab} $series {
        set vals [lmap r $recs {expr {[set v [apply $val $r $key]] eq "" ? [continue] : $v}}]
        if {![llength $vals]} { set lo 0; set hi 1 } else { set lo [::tcl::mathfunc::min {*}$vals]; set hi [::tcl::mathfunc::max {*}$vals] }
        if {$hi == $lo} { set d [expr {$hi == 0 ? 1.0 : abs($hi) * 0.1}]; set lo [expr {$lo - $d}]; set hi [expr {$hi + $d}] }
        set pad [expr {($hi - $lo) * 0.1}]
        set rng($key) [list [expr {$lo - $pad}] [expr {$hi + $pad}]]
    }
    set k0 [lindex $series 0]
    lassign $rng($k0) lo hi
    set xtitle [expr {$radius ? "Radius (MDANCE's MSD, Å²)" : "Number of clusters (k)"}]
    ::VMDance::Plot::setup $c [expr {$kmin - $half}] [expr {$kmax + $half}] $lo $hi [list $ml $mt $mr [expr {$mb + $strip + $gap}]]
    if {$strip} {
        # (the values and the title of x are written under the strip)
        ::VMDance::Plot::axes $c "" [lindex $series 2] $ks auto [dict merge [gridopt] [dict create xfmt {apply {{v} {return ""}}}]]
    } else {
        ::VMDance::Plot::axes $c $xtitle [lindex $series 2] $ks auto [gridopt]
    }
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    set lh [::VMDance::Plot::lh]
    set ybot $y1
    if {$strip} {
        set s0 [expr {$y1 + $gap}]; set s1 [expr {$s0 + $strip}]
        set ybot $s1
        $c create rectangle $x0 $s0 $x1 $s1 -fill [theme plotbg] -outline "" -tags {bg plotbg}
        set bw [expr {max(3.0, 1.4 * ([::VMDance::Plot::X $c [expr {$kmin + $half}]] - [::VMDance::Plot::X $c $kmin]))}]
        # its scale: 0, the middle, the top
        foreach t [list 0 [expr {$bmax / 2.0}] $bmax] {
            set py [expr {$s1 - double($t) / $bmax * ($strip - $lh - 2)}]
            if {[S plot_grid]} { $c create line $x0 $py $x1 $py -fill [theme grid] -tags grid }
            $c create line [expr {$x0 - 4}] $py $x0 $py -fill [theme axis] -tags axis
            $c create text [expr {$x0 - 6}] $py -text [expr {$bmax == 1 ? [format %.1f $t] : [::VMDance::Plot::fmt [expr {round($t)}]]}] -anchor e -font MdvSmall -fill [theme text] -tags axis
        }
        foreach b $bars {
            lassign $b bx v txt
            set px [::VMDance::Plot::X $c $bx]
            set py [expr {$s1 - double($v) / $bmax * ($strip - $lh - 2)}]
            $c create rectangle [expr {$px - $bw / 2}] $py [expr {$px + $bw / 2}] $s1 -fill #c9d3df -outline "" -tags stability
            if {$bw >= [font measure MdvSmall $txt] + 2} {
                $c create text $px [expr {$py - 1}] -text $txt -anchor s -font MdvSmall -fill [theme text] -tags stability
            }
        }
        $c create line $x0 $s1 $x1 $s1 -fill [theme axis] -tags axis
        $c create line $x0 $s0 $x0 $s1 -fill [theme axis] -tags axis
        if {[font measure MdvSmall $btitle] <= $strip} {
            $c create text [expr {max(14, 2 + $lh / 2.0)}] [expr {($s0 + $s1) / 2.0}] -text $btitle -angle 90 -font MdvSmall -fill [theme text] -tags axis
        }
        # the values of x that have room, and its title
        lassign [::VMDance::Plot::_fit_ticks $c x $ks ::VMDance::Plot::fmt 8] ticks labelled
        foreach t $ticks {
            set px [::VMDance::Plot::X $c $t]
            $c create line $px $s1 $px [expr {$s1 + 4}] -fill [theme axis] -tags axis
            if {$t in $labelled} { $c create text $px [expr {$s1 + 6}] -text [::VMDance::Plot::fmt $t] -anchor n -font MdvSmall -fill [theme text] -tags axis }
        }
        $c create text [expr {($x0 + $x1) / 2.0}] [expr {$s1 + 6 + $lh + 3}] -text $xtitle -anchor n -font MdvText -fill [theme text] -tags axis
    }
    set w [expr {[lw] + 0.6}]
    foreach {key col lab} $series {
        lassign $rng($key) lo hi
        set pts {}
        array unset at
        foreach r $recs {
            set v [apply $val $r $key]
            if {$v eq ""} continue
            set px [::VMDance::Plot::X $c [::VMDance::Results::scan_x $r]]
            set py [expr {$y1 - ($v - $lo) / ($hi - $lo) * ($y1 - $y0)}]
            lappend pts $px $py
            set at([::VMDance::Results::scan_x $r]) [list $px $py]
        }
        if {[llength $pts] >= 4} { $c create line {*}$pts -fill $col -width $w -tags series }
        foreach {px py} $pts { $c create oval [expr {$px - 4}] [expr {$py - 4}] [expr {$px + 4}] [expr {$py + 4}] -fill $col -outline white -tags series }
        # the suggested values of this score: ringed
        foreach g [expr {$key eq "db" ? {db_lowest db_dip} : ($key eq "ch" ? {ch_highest} : {})}] {
            set x [dict get $sug $g]
            if {$x eq "" || ![info exists at($x)]} continue
            lassign $at($x) px py
            $c create oval [expr {$px - 8}] [expr {$py - 8}] [expr {$px + 8}] [expr {$py + 8}] -outline $col -width 1.6 -tags mark
        }
        if {$key ne $k0} {
            # the right axis
            $c create line $x1 $y0 $x1 $y1 -fill [theme axis] -tags axis
            foreach t [::VMDance::Plot::nice_ticks $lo $hi 5] {
                set py [expr {$y1 - ($t - $lo) / ($hi - $lo) * ($y1 - $y0)}]
                if {$py < $y0 - 0.5 || $py > $y1 + 0.5} continue
                $c create line $x1 $py [expr {$x1 + 4}] $py -fill [theme axis] -tags axis
                $c create text [expr {$x1 + 6}] $py -text [::VMDance::Plot::_stepfmt $lo $hi 5 $t] -anchor w -font MdvSmall -fill $col -tags axis
            }
            $c create text [expr {$W - 10}] [expr {($y0 + $y1) / 2.0}] -text $lab -angle 90 \
                -font [::VMDance::Plot::_fit_font $lab [expr {$y1 - $y0}]] -fill $col -tags axis
        }
    }
    # failed values of k: a cross on the axis
    foreach k $failed {
        set px [::VMDance::Plot::X $c $k]
        $c create line [expr {$px - 4}] [expr {$y1 - 4}] [expr {$px + 4}] [expr {$y1 + 4}] -fill [theme cursor] -width 2 -tags series
        $c create line [expr {$px - 4}] [expr {$y1 + 4}] [expr {$px + 4}] [expr {$y1 - 4}] -fill [theme cursor] -width 2 -tags series
    }
    if {$cur ne ""} {
        set px [::VMDance::Plot::X $c $cur]
        $c create line $px $y0 $px $ybot -fill $accent -dash {2 3} -tags mark
    }
    if {$words ne ""} { ::VMDance::Plot::note $c "ringed · $words" }
    _legend $c $items [list $x0 $x1]
    set H($c,elbow) $ks
    set H($c,elbowbot) $ybot
}
# The scan's value (k, or radius) nearest the pointer, within half the gap
# to the next ("" none): over the scores or the strip under them.
proc ::VMDance::Plots::_k_at {c x y} {
    variable H
    if {![info exists H($c,elbow)]} { return "" }
    lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
    if {$x < $x0 || $x > $x1 || $y < $y0 || $y > $H($c,elbowbot)} { return "" }
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
        append s " ([dict get $r nclusters] cluster[expr {[dict get $r nclusters] == 1 ? "" : "s"}])"
    } elseif {[dict get $r nclusters] != $k} { append s " ([dict get $r nclusters] with frames)" }
    append s ": Calinski–Harabasz [_sc [dict get $r ch]], Davies–Bouldin [_sc [dict get $r db]]"
    set ex [::VMDance::Results::explained $r]
    if {$ex ne ""} { append s [format ", %.0f%% of the variance explained" [expr {100 * $ex}]] }
    if {[::VMDance::_get $r stability ""] ne ""} {
        append s ", stability [format %.2f [dict get $r stability]]"
        if {[::VMDance::_get $r compared ""] ne ""} { append s " ([dict get $r compared] seedings)" }
    } elseif {[::VMDance::_get $r compared ""] ne ""} {
        append s ", no stability: [dict get $r compared] seeding[expr {[dict get $r compared] == 1 ? "" : "s"}] could seed it"
    }
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
        -text [expr {[dict exists $r radius] ? "radius $k: $found cluster[expr {$found == 1 ? "" : "s"}]" : "k = $k[expr {$found != $k ? " ($found with frames)" : ""}]"}] -tags partition
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
                    set txt [_cellfmt [expr {$key eq "ch" ? "%.4g" : "%.3f"}] [dict get $r $key]]
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
