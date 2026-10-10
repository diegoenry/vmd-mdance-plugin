#
# VMDance - minimal canvas plotting toolkit
#
# A plot is a canvas plus a data->pixel transform stored in G($c,*).
#

namespace eval ::VMDance::Plot {
    namespace export X Y
    variable G
    variable theme
    array set theme {
        bg      #ffffff
        plotbg  #fcfcfd
        grid    #eceef3
        axis    #9aa1ad
        text    #3b4250
        muted   #8a909c
        cursor  #d62728
        accent  #1f5fae
    }
}

proc ::VMDance::Plot::init_fonts {} {
    # With the window's fonts module: one family and size for everything.
    if {[namespace exists ::VMDance::Fonts]} {
        ::VMDance::Fonts::init
    } else {
        foreach {name spec} {
            MdvSmall {-family Helvetica -size 10}
            MdvText  {-family Helvetica -size 11}
            MdvBold  {-family Helvetica -size 11 -weight bold}
            MdvTitle {-family Helvetica -size 12 -weight bold}
            MdvBig   {-family Helvetica -size 16 -weight bold}
        } {
            if {$name ni [font names]} { font create $name {*}$spec }
        }
    }
    _hold_fonts
}

# Tk frees a font that nothing draws with, and opens it again for every
# "font measure" (a millisecond each with Xft): a plot that has just been
# cleared would measure a thousand tick labels in seconds. A canvas never
# shown keeps a text in each of the plugin's fonts.
proc ::VMDance::Plot::_hold_fonts {} {
    set k .vmdance_fonts
    if {![winfo exists $k]} { canvas $k -width 1 -height 1 }
    foreach f [font names] {
        if {[string match Mdv* $f] && ![llength [$k find withtag font_$f]]} {
            $k create text 0 0 -text 0 -font $f -tags [list font_$f]
        }
    }
}

# Drawing size of a canvas: its on-screen size, or its configured size when
# it is not mapped (off-screen rendering for figure export).
proc ::VMDance::Plot::size {c} {
    if {[winfo ismapped $c] && [winfo width $c] >= 50} {
        return [list [winfo width $c] [winfo height $c]]
    }
    return [list [$c cget -width] [$c cget -height]]
}

# Sizes that follow the text size (the window's, or the figures' reference
# size), never smaller than those of the 10-12 pt plot fonts.
proc ::VMDance::Plot::lh {{f MdvSmall}} { font metrics $f -linespace }
# left margin: tick labels (as wide as "−180") and the rotated axis title
proc ::VMDance::Plot::ml {} { expr {max(58, 6 + [font measure MdvSmall "−180"] + 6 + [lh MdvText] + 2)} }
# bottom margin: tick labels and the axis title (a title on canvas c that
# wraps: its lines, Plot::_xtitle)
proc ::VMDance::Plot::mb {{c ""} {title ""}} {
    set th [lh MdvText]
    if {$title ne ""} { set th [expr {max($th, [lindex [_xtitle $c $title] 2])}] }
    expr {max(42, 6 + [lh] + 3 + $th + 2)}
}
# a legend row, and the top margin over `rows` of them
proc ::VMDance::Plot::rowh {} { expr {max(15, [lh] + 2)} }
proc ::VMDance::Plot::top_margin {rows} { expr {16 + $rows * [rowh]} }
# height of a colour bar with its end labels
proc ::VMDance::Plot::bar_height {} { expr {8 + 2 + [lh]} }

# Define the data window and margins {left top right bottom} for canvas c.
proc ::VMDance::Plot::setup {c xmin xmax ymin ymax {margins {58 22 18 42}}} {
    variable G
    lassign $margins ml mt mr mb
    lassign [size $c] W H
    if {$xmax == $xmin} { set xmax [expr {$xmin + 1}] }
    if {$ymax == $ymin} { set ymax [expr {$ymin + 1}] }
    array set G [list $c,x0 $ml $c,y0 $mt \
        $c,x1 [expr {$W - $mr}] $c,y1 [expr {$H - $mb}] \
        $c,xmin $xmin $c,xmax $xmax $c,ymin $ymin $c,ymax $ymax \
        $c,W $W $c,H $H]
}

proc ::VMDance::Plot::X {c x} {
    variable G
    expr {$G($c,x0) + ($x - $G($c,xmin)) / double($G($c,xmax) - $G($c,xmin)) * ($G($c,x1) - $G($c,x0))}
}
proc ::VMDance::Plot::Y {c y} {
    variable G
    expr {$G($c,y1) - ($y - $G($c,ymin)) / double($G($c,ymax) - $G($c,ymin)) * ($G($c,y1) - $G($c,y0))}
}
proc ::VMDance::Plot::invX {c px} {
    variable G
    expr {$G($c,xmin) + ($px - $G($c,x0)) / double($G($c,x1) - $G($c,x0)) * ($G($c,xmax) - $G($c,xmin))}
}
proc ::VMDance::Plot::invY {c py} {
    variable G
    expr {$G($c,ymin) + ($G($c,y1) - $py) / double($G($c,y1) - $G($c,y0)) * ($G($c,ymax) - $G($c,ymin))}
}
proc ::VMDance::Plot::inside {c px py} {
    variable G
    # (a plot that shows a message has no area)
    if {![info exists G($c,x0)]} { return 0 }
    expr {$px >= $G($c,x0) && $px <= $G($c,x1) && $py >= $G($c,y0) && $py <= $G($c,y1)}
}
proc ::VMDance::Plot::area {c} {
    variable G
    list $G($c,x0) $G($c,y0) $G($c,x1) $G($c,y1)
}

# "Nice" tick positions covering [lo, hi] with about n ticks.
proc ::VMDance::Plot::nice_ticks {lo hi {n 6}} {
    set span [expr {double($hi - $lo)}]
    # (a span within the numbers' precision has one tick: t + step would
    # be t, and a loop adding the step would never end)
    if {$span <= 0 || $span <= 1e-12 * max(abs($lo), abs($hi))} { return [list $lo] }
    set raw [expr {$span / max(1, $n)}]
    set mag [expr {pow(10, floor(log10($raw)))}]
    set f [expr {$raw / $mag}]
    if {$f < 1.5} { set s 1 } elseif {$f < 3} { set s 2 } elseif {$f < 7} { set s 5 } else { set s 10 }
    set step [expr {$s * $mag}]
    set i0 [expr {ceil($lo / $step - 1e-9)}]
    set out {}
    for {set i 0} {$i < 1000} {incr i} {
        set t [expr {($i0 + $i) * $step}]
        if {$t > $hi + 1e-9 * $span} break
        # (zero, not a rounding error beside it)
        lappend out [expr {abs($t) < 1e-9 * $step ? 0.0 : $t}]
    }
    return $out
}

# A tick label with the decimals of the ticks' step over [lo, hi] (at most
# n ticks): the finest step the axis could use.
proc ::VMDance::Plot::_stepfmt {lo hi n v} {
    set span [expr {double($hi - $lo)}]
    if {$span <= 0} { return [fmt $v] }
    set raw [expr {$span / max(1, $n)}]
    set d [expr {int(max(0, -floor(log10($raw) - 1e-9)))}]
    # a step of 2.5, 0.25 ... never occurs; 5, 0.5, 0.05 need the next decimal only below 1
    # (large or tiny: as many significant digits as the step needs)
    if {abs($v) >= 1e6 || (abs($v) > 0 && abs($v) < 1e-4)} {
        set sig [expr {max(2, int(ceil(log10(max(abs($v), $raw) / $raw))) + 1)}]
        return [format %.${sig}g $v]
    }
    if {$d == 0} { return [fmt $v] }
    set t [format %.${d}f $v]
    # (no trailing zeros beyond what the step needs: 0.50 -> 0.5)
    if {[string first . $t] >= 0} {
        set t2 [string trimright [string trimright $t 0] .]
        if {[expr {abs($t2 - $v)}] <= 1e-9 * max(1.0, abs($v))} { set t $t2 }
    }
    if {$t eq "-0"} { set t 0 }
    return $t
}

proc ::VMDance::Plot::fmt {v} {
    if {$v == int($v) && abs($v) < 1e9} { return [expr {int($v)}] }
    if {abs($v) >= 100} { return [format %.0f $v] }
    if {abs($v) >= 1} { return [format %.1f $v] }
    # (0.005 and 0.015 stay apart)
    if {abs($v) < 0.1} { return [format %.3g $v] }
    return [format %.2f $v]
}

# Background, grid, ticks, axis labels.
#   xticks/yticks: explicit list, or "auto"
proc ::VMDance::Plot::axes {c xlabel ylabel {xticks auto} {yticks auto} {opts {}}} {
    variable G; variable theme
    set o [dict merge {xfmt ::VMDance::Plot::fmt yfmt ::VMDance::Plot::fmt grid 1} $opts]
    lassign [area $c] x0 y0 x1 y1
    $c create rectangle $x0 $y0 $x1 $y1 -fill $theme(plotbg) -outline "" -tags {bg plotbg}
    # ticks whose labels do not touch: fewer "nice" ticks, or every k-th of
    # the given ones
    # (auto ticks with the default format: as many decimals as the step
    # needs, so that 1.05 and 1.1 are not both "1.1")
    foreach ax {x y} {
        if {[set ${ax}ticks] eq "auto" && [dict get $o ${ax}fmt] eq "::VMDance::Plot::fmt"} {
            dict set o ${ax}fmt [list ::VMDance::Plot::_stepfmt $G($c,${ax}min) $G($c,${ax}max) \
                [expr {max(3, int(([expr {$ax eq "x" ? $x1 - $x0 : $y1 - $y0}]) / ($ax eq "x" ? 90 : 45)))}]]
        }
    }
    set xl [_fit_ticks $c x $xticks [dict get $o xfmt] [expr {max(3, int(($x1 - $x0) / 90))}]]
    set yl [_fit_ticks $c y $yticks [dict get $o yfmt] [expr {max(3, int(($y1 - $y0) / 45))}]]
    lassign $xl xticks xlab
    lassign $yl yticks ylab
    foreach t $xticks {
        set px [X $c $t]
        if {$px < $x0 - 0.5 || $px > $x1 + 0.5} continue
        if {[dict get $o grid]} { $c create line $px $y0 $px $y1 -fill $theme(grid) -tags grid }
        $c create line $px $y1 $px [expr {$y1 + 4}] -fill $theme(axis) -tags axis
        if {$t in $xlab} {
            $c create text $px [expr {$y1 + 6}] -text [{*}[dict get $o xfmt] $t] -anchor n \
                -font MdvSmall -fill $theme(text) -tags axis
        }
    }
    # the x labels' boxes, so that a y label in the corner does not cover one
    set lh [lh]
    set xboxes {}
    foreach t $xlab {
        set px [X $c $t]
        set hw [expr {[font measure MdvSmall [{*}[dict get $o xfmt] $t]] / 2.0}]
        lappend xboxes [list [expr {$px - $hw}] [expr {$y1 + 6}] [expr {$px + $hw}] [expr {$y1 + 6 + $lh}]]
    }
    foreach t $yticks {
        set py [Y $c $t]
        if {$py < $y0 - 0.5 || $py > $y1 + 0.5} continue
        if {[dict get $o grid]} { $c create line $x0 $py $x1 $py -fill $theme(grid) -tags grid }
        $c create line [expr {$x0 - 4}] $py $x0 $py -fill $theme(axis) -tags axis
        set tw [font measure MdvSmall [{*}[dict get $o yfmt] $t]]
        set yb [list [expr {$x0 - 6 - $tw}] [expr {$py - $lh / 2.0}] [expr {$x0 - 6}] [expr {$py + $lh / 2.0}]]
        foreach b $xboxes {
            if {[lindex $yb 0] < [lindex $b 2] - 1 && [lindex $b 0] < [lindex $yb 2] - 1 &&
                [lindex $yb 1] < [lindex $b 3] - 1 && [lindex $b 1] < [lindex $yb 3] - 1} { set t "" }
        }
        if {$t ne "" && $t in $ylab} {
            $c create text [expr {$x0 - 6}] $py -text [{*}[dict get $o yfmt] $t] -anchor e \
                -font MdvSmall -fill $theme(text) -tags axis
        }
    }
    $c create line $x0 $y1 $x1 $y1 -fill $theme(axis) -tags axis
    $c create line $x0 $y0 $x0 $y1 -fill $theme(axis) -tags axis
    lassign [size $c] W H
    if {$xlabel ne ""} {
        # centred under the plot, but on the canvas (wrapped when no font
        # fits it there: a plot that has such a title makes room, Plot::mb)
        lassign [_xtitle $c $xlabel] f wrap
        set tw [expr {$wrap ? $wrap : [font measure $f $xlabel]}]
        set cx [expr {max($tw / 2.0 + 2, min($W - $tw / 2.0 - 2, ($x0 + $x1) / 2.0))}]
        $c create text $cx [expr {$y1 + 6 + $lh + 3}] -text $xlabel -anchor n -font $f -fill $theme(text) -tags axis \
            -width $wrap -justify center
    }
    if {$ylabel ne ""} {
        set f [_fit_font $ylabel [expr {$H - 4}]]
        set tw [font measure $f $ylabel]
        set cy [expr {max($tw / 2.0 + 2, min($H - $tw / 2.0 - 2, ($y0 + $y1) / 2.0))}]
        $c create text [expr {max(14, 2 + [lh $f] / 2.0)}] $cy -text $ylabel -angle 90 -anchor center \
            -font $f -fill $theme(text) -tags axis
    }
}

# The x axis title of canvas c: {font wrap height}: the font as _fit_font
# chooses it, wrapped at the canvas's width when that does not fit either
# (wrap: that width, 0 for one line; it was cut: a narrow figure lost
# DIVINE's tree's "not DIVINE's splits"), and the height it takes.
proc ::VMDance::Plot::_xtitle {c txt} {
    lassign [size $c] W
    set f [_fit_font $txt [expr {$W - 4}]]
    if {[font measure $f $txt] <= $W - 4} { return [list $f 0 [lh $f]] }
    set i [$c create text 0 0 -text $txt -font $f -width [expr {$W - 4}] -anchor nw]
    lassign [$c bbox $i] - ya - yb
    $c delete $i
    list $f [expr {$W - 4}] [expr {$yb - $ya}]
}

# The axis-title font: the text font, or the small one when the text font
# does not fit in `room` pixels.
proc ::VMDance::Plot::_fit_font {txt room} {
    expr {[font measure MdvText $txt] <= $room ? "MdvText" : "MdvSmall"}
}

# Ticks of one axis, and the ones that get a label: {ticks labelled}.
# "auto": the nice ticks, fewer until their labels have room. A given list:
# every k-th tick labelled (preferring the set with 0).
proc ::VMDance::Plot::_fit_ticks {c axis ticks fmt n} {
    variable G
    if {$ticks eq "auto"} {
        set lo $G($c,${axis}min); set hi $G($c,${axis}max)
        for {set k $n} {$k >= 1} {incr k -1} {
            set ticks [nice_ticks $lo $hi $k]
            if {[_labels_fit $c $axis $ticks $fmt]} break
        }
        return [list $ticks $ticks]
    }
    # every tick's place and half its label (measured once), and the
    # smallest step that could fit: two labels need their widths and the
    # gap between them (the ticks on the axis are consecutive ones)
    set gap 6
    set lh [font metrics MdvSmall -linespace]
    set n [llength $ticks]
    set pos {}; set half {}
    foreach t $ticks {
        if {$axis eq "x"} {
            lappend pos [X $c $t]
            lappend half [expr {[font measure MdvSmall [{*}$fmt $t]] / 2.0}]
        } else {
            lappend pos [Y $c $t]
            lappend half [expr {($lh + 1) / 2.0}]
        }
    }
    set lo [expr {$G($c,${axis}0) - 0.5}]; set hi [expr {$G($c,${axis}1) + 0.5}]
    set k0 1
    set on [lmap p $pos {expr {$p < $lo || $p > $hi ? [continue] : $p}}]
    if {[llength $on] > 1} {
        set sp 0.0
        for {set i 1} {$i < [llength $on]} {incr i} { set sp [expr {max($sp, abs([lindex $on $i] - [lindex $on [expr {$i - 1}]]))}] }
        set need [expr {2 * [::tcl::mathfunc::min {*}$half] + ($axis eq "x" ? $gap : 0)}]
        if {$sp > 0} { set k0 [expr {max(1, int($need / $sp))}] }
    }
    set zero [lsearch -exact $ticks 0]
    if {$zero < 0} { set zero [lsearch -exact $ticks 0.0] }
    for {set k $k0} {$k <= max(1, $n)} {incr k} {
        set best ""
        for {set r 0} {$r < $k} {incr r} {
            if {![_every_fits $axis $pos $half $r $k $lo $hi $gap $lh]} continue
            if {$best eq "" || ($zero >= 0 && ($zero - $r) % $k == 0 && ($zero - $best) % $k != 0)} { set best $r }
        }
        if {$best ne ""} {
            set sub {}
            for {set i $best} {$i < $n} {incr i $k} { lappend sub [lindex $ticks $i] }
            return [list $ticks $sub]
        }
    }
    return [list $ticks [lrange $ticks 0 0]]
}
# Whether the labels of every k-th tick from r (places pos, half sizes
# half) keep apart.
proc ::VMDance::Plot::_every_fits {axis pos half r k lo hi gap lh} {
    set prev ""
    set n [llength $pos]
    for {set i $r} {$i < $n} {incr i $k} {
        set p [lindex $pos $i]
        if {$p < $lo || $p > $hi} continue
        if {$axis eq "x"} {
            set h [lindex $half $i]
            if {$prev ne "" && $p - $h < $prev + $gap} { return 0 }
            set prev [expr {$p + $h}]
        } else {
            if {$prev ne "" && abs($prev - $p) < $lh + 1} { return 0 }
            set prev $p
        }
    }
    return 1
}
proc ::VMDance::Plot::_labels_fit {c axis ticks fmt} {
    variable G
    set gap 6
    set lh [font metrics MdvSmall -linespace]
    set prev ""
    foreach t $ticks {
        if {$axis eq "x"} {
            set p [X $c $t]
            if {$p < $G($c,x0) - 0.5 || $p > $G($c,x1) + 0.5} continue
            set hw [expr {[font measure MdvSmall [{*}$fmt $t]] / 2.0}]
            if {$prev ne "" && $p - $hw < $prev + $gap} { return 0 }
            set prev [expr {$p + $hw}]
        } else {
            set p [Y $c $t]
            if {$p < $G($c,y0) - 0.5 || $p > $G($c,y1) + 0.5} continue
            if {$prev ne "" && abs($prev - $p) < $lh + 1} { return 0 }
            set prev $p
        }
    }
    return 1
}

# A colour bar (up to 140 px wide) with a title to its right, both inside
# the canvas: the bar narrows, then a shorter title (titles: the wordings,
# preferred first) is used, then none.
proc ::VMDance::Plot::colorbar_titled {c x y colors lo hi titles {tags legend}} {
    variable theme
    lassign [size $c] W H
    set room [expr {$W - 4 - $x}]
    set bw ""; set title ""
    foreach t $titles {
        set w [expr {min(140, $room - [font measure MdvSmall $t] - 6)}]
        if {$w >= 70} { set bw $w; set title $t; break }
    }
    if {$bw eq ""} { set bw [expr {max(40, min(140, $room))}] }
    colorbar $c $x $y $bw 8 $colors $lo $hi "" $tags
    if {$title ne ""} {
        # (beside the bar and its end values, its top at the bar's: a tall
        # text grows down, into the room the end values take)
        $c create text [expr {$x + $bw + 6}] $y -text $title -anchor nw -font MdvSmall \
            -fill $theme(muted) -tags $tags
    }
}

# A text cut to maxw pixels, ending with "…" when cut.
proc ::VMDance::Plot::elide {font maxw text} {
    if {[font measure $font $text] <= $maxw} { return $text }
    set lo 0; set hi [string length $text]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi + 1) / 2}]
        if {[font measure $font "[string range $text 0 [expr {$mid - 1}]]…"] <= $maxw} { set lo $mid } else { set hi [expr {$mid - 1}] }
    }
    return "[string trimright [string range $text 0 [expr {$lo - 1}]]]…"
}

# Centered placeholder message.
proc ::VMDance::Plot::empty {c msg {sub ""}} {
    variable theme
    $c delete all
    lassign [size $c] W H
    # (the title above the middle, the text below it: apart at any size)
    $c create text [expr {$W/2}] [expr {$H/2 - 2}] -text $msg -font MdvTitle -fill $theme(muted) -anchor s
    if {$sub ne ""} {
        $c create text [expr {$W/2}] [expr {$H/2 + 4}] -text $sub -font MdvText -anchor n \
            -fill $theme(muted) -width [expr {max(200, $W - 80)}] -justify center
    }
}

# Legend in the top margin, wrapping onto extra rows. items: {label color ...}
# A colour can also be a marker: @ring (a small outlined circle), @big (a
# larger one) or @none (the label alone). legend_rows gives the number of
# rows before the plot is set up, so the top margin can make room; it must
# be given the width the legend is drawn in (legend: the plot area, or xr).
proc ::VMDance::Plot::legend_rows {c items {ml 58} {mr 18}} {
    set avail [expr {max(100, [lindex [size $c] 0] - $ml - $mr)}]
    set rows 1; set x 0
    foreach {lab col} $items {
        set tw [expr {[font measure MdvSmall $lab] + 26}]
        if {$x + $tw > $avail && $x > 0} { incr rows; set x 0 }
        set x [expr {$x + $tw}]
    }
    return $rows
}
proc ::VMDance::Plot::legend {c items {y ""} {xr ""}} {
    variable theme
    lassign [area $c] x0 y0 x1 y1
    if {[llength $xr] == 2} { lassign $xr x0 x1 }
    set rh [rowh]
    if {$y eq ""} { set y [expr {5 + $rh / 2.0}] }
    set x $x0
    foreach {lab col} $items {
        set tw [expr {[font measure MdvSmall $lab] + 26}]
        if {$x + $tw > $x1 && $x > $x0} { set x $x0; set y [expr {$y + $rh}] }
        set tx [expr {$x + 16}]
        switch -- $col {
            @none { set tx $x }
            @ring - @big {
                set r [expr {$col eq "@big" ? 5.5 : 4.0}]
                $c create oval [expr {$x + 6 - $r}] [expr {$y - $r}] [expr {$x + 6 + $r}] [expr {$y + $r}] \
                    -fill white -outline #111111 -width [expr {$col eq "@big" ? 1.5 : 1}] -tags legend
            }
            default {
                $c create rectangle $x [expr {$y - 4}] [expr {$x + 12}] [expr {$y + 4}] \
                    -fill $col -outline "" -tags legend
            }
        }
        $c create text $tx $y -text $lab -anchor w -font MdvSmall \
            -fill $theme(text) -tags legend
        set x [expr {$x + $tw}]
    }
}

# Horizontal colour bar: colors = list of Tk colours, placed at (x,y,w,h).
proc ::VMDance::Plot::colorbar {c x y w h colors lo hi {label ""} {tags colorbar}} {
    variable theme
    set n [llength $colors]
    for {set i 0} {$i < $n} {incr i} {
        set xa [expr {$x + $w * double($i) / $n}]
        set xb [expr {$x + $w * double($i + 1) / $n + 0.5}]
        $c create rectangle $xa $y $xb [expr {$y + $h}] -fill [lindex $colors $i] -outline "" -tags $tags
    }
    $c create rectangle $x $y [expr {$x + $w}] [expr {$y + $h}] -outline $theme(axis) -tags $tags
    $c create text $x [expr {$y + $h + 2}] -text $lo -anchor nw -font MdvSmall -fill $theme(text) -tags $tags
    $c create text [expr {$x + $w}] [expr {$y + $h + 2}] -text $hi -anchor ne -font MdvSmall -fill $theme(text) -tags $tags
    if {$label ne ""} {
        $c create text [expr {$x + $w / 2.0}] [expr {$y + $h + 2}] -text $label -anchor n \
            -font MdvSmall -fill $theme(muted) -tags $tags
    }
}


