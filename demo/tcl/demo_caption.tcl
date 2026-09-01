# demo_caption.tcl - the on-screen furniture: caption bar, chapter title cards,
# and the spotlight that frames whichever control the narrator is talking about.
#
# All three are borderless always-on-top toplevels so they float over both the
# plugin's Tk windows and VMD's OpenGL display without becoming part of either.

namespace eval ::demo::caption {
    variable w        .demo_caption
    variable card     .demo_titlecard
    variable spot_pfx .demo_spot
    variable spots    {}          ;# active spotlight window paths
    variable visible  0
    variable card_after ""
    variable pulse_after ""
    variable pulse_on 1

    # Palette. Deliberately dark and low-chroma so it reads as chrome, not as
    # content, over a molecular scene that is itself brightly coloured.
    variable bg      "#11141a"
    variable fg      "#eef2f8"
    variable dim     "#8d99ad"
    variable accent  "#4da3ff"
    variable accent2 "#ffb454"
    variable bar_bg  "#232833"

    variable font_size 17
    variable height    132
    variable margin    28
}

# --- caption bar -----------------------------------------------------------

proc ::demo::caption::create {} {
    variable w
    variable bg
    variable fg
    variable dim
    variable accent
    variable bar_bg
    variable font_size

    catch {destroy $w}
    toplevel $w -background $bg
    wm overrideredirect $w 1
    catch {wm attributes $w -topmost 1}
    # An overrideredirect window on macOS can come up as a document window in
    # Mission Control; -type helps window managers that honour it and is
    # harmless where it is not supported.
    catch {wm attributes $w -type splash}

    frame $w.pad -background $bg
    pack $w.pad -fill both -expand 1 -padx 22 -pady 12

    # Top line: chapter name on the left, beat counter on the right.
    frame $w.pad.top -background $bg
    pack $w.pad.top -fill x
    label $w.pad.top.chapter -background $bg -foreground $accent -anchor w \
        -text "" -font [list TkDefaultFont [expr {$font_size - 5}] bold]
    label $w.pad.top.counter -background $bg -foreground $dim -anchor e \
        -text "" -font [list TkDefaultFont [expr {$font_size - 5}]]
    pack $w.pad.top.chapter -side left
    pack $w.pad.top.counter -side right

    # The caption itself.
    label $w.pad.text -background $bg -foreground $fg -anchor w -justify left \
        -text "" -font [list TkDefaultFont $font_size] -wraplength 1200
    pack $w.pad.text -fill both -expand 1 -pady {6 8}

    # A hairline progress bar for the current beat -- drawn by hand because a
    # ttk::progressbar picks up the platform theme and looks like a dialog.
    canvas $w.pad.bar -height 3 -background $bar_bg -highlightthickness 0
    pack $w.pad.bar -fill x
    $w.pad.bar create rectangle 0 0 0 3 -fill $accent -outline "" -tags progress

    place_bar
    return $w
}

# place_bar - park the caption bar across the bottom of the screen.
proc ::demo::caption::place_bar {} {
    variable w
    variable height
    variable margin

    if {![winfo exists $w]} { return }
    set sw [winfo screenwidth $w]
    set sh [winfo screenheight $w]
    set bw [expr {$sw - 2 * $margin}]
    if {$bw > 1500} { set bw 1500 }
    set x [expr {($sw - $bw) / 2}]
    set y [expr {$sh - $height - 56}]
    wm geometry $w "${bw}x${height}+${x}+${y}"
    $w.pad.text configure -wraplength [expr {$bw - 60}]
}

proc ::demo::caption::show {} {
    variable w
    variable visible
    if {![winfo exists $w]} { create }
    wm deiconify $w
    catch {raise $w}
    set visible 1
}

proc ::demo::caption::hide {} {
    variable w
    variable visible
    if {[winfo exists $w]} { wm withdraw $w }
    set visible 0
}

# set_text - update the caption bar for one beat.
proc ::demo::caption::set_text {chapter counter text} {
    variable w
    if {![winfo exists $w]} { create }
    $w.pad.top.chapter configure -text $chapter
    $w.pad.top.counter configure -text $counter
    $w.pad.text configure -text $text
    progress 0.0
    show
    catch {raise $w}
}

# progress - draw the beat progress bar, frac in [0,1].
proc ::demo::caption::progress {frac} {
    variable w
    if {![winfo exists $w]} { return }
    if {$frac < 0} { set frac 0 }
    if {$frac > 1} { set frac 1 }
    set width [winfo width $w.pad.bar]
    if {$width <= 1} { set width [expr {[winfo reqwidth $w] - 44}] }
    $w.pad.bar coords progress 0 0 [expr {$frac * $width}] 3
}

# --- chapter title card ----------------------------------------------------

# title_card - a centred card announcing a chapter. Auto-dismisses after $secs.
proc ::demo::caption::title_card {number title subtitle {secs 2.6}} {
    variable card
    variable bg
    variable fg
    variable dim
    variable accent
    variable card_after

    catch {after cancel $card_after}
    catch {destroy $card}

    toplevel $card -background $bg
    wm overrideredirect $card 1
    catch {wm attributes $card -topmost 1}
    catch {wm attributes $card -type splash}

    frame $card.b -background $accent
    pack $card.b -fill x -side top
    frame $card.b.h -background $accent -height 4
    pack $card.b.h -fill x

    frame $card.pad -background $bg
    pack $card.pad -fill both -expand 1 -padx 46 -pady 34

    label $card.pad.num -background $bg -foreground $accent -anchor w \
        -text $number -font [list TkDefaultFont 13 bold]
    label $card.pad.title -background $bg -foreground $fg -anchor w \
        -text $title -font [list TkDefaultFont 30 bold]
    label $card.pad.sub -background $bg -foreground $dim -anchor w -justify left \
        -text $subtitle -font [list TkDefaultFont 15] -wraplength 660
    pack $card.pad.num -fill x
    pack $card.pad.title -fill x -pady {4 8}
    pack $card.pad.sub -fill x

    update idletasks
    set cw 740
    set ch [expr {[winfo reqheight $card] + 4}]
    set sw [winfo screenwidth $card]
    set sh [winfo screenheight $card]
    wm geometry $card "${cw}x${ch}+[expr {($sw - $cw) / 2}]+[expr {($sh - $ch) / 2 - 90}]"
    raise $card

    set card_after [after [expr {int($secs * 1000)}] [list ::demo::caption::hide_card]]
    return $card
}

proc ::demo::caption::hide_card {} {
    variable card
    variable card_after
    catch {after cancel $card_after}
    set card_after ""
    catch {destroy $card}
}

# --- spotlight -------------------------------------------------------------

# spotlight - frame one or more widgets with an accent-coloured rectangle.
#
# Drawn as four thin bars around the widget rather than one translucent panel
# over it, so the control being described stays fully visible and fully usable.
proc ::demo::caption::spotlight {widgets} {
    variable spot_pfx
    variable spots
    variable accent2
    variable pulse_after

    clear_spotlight

    set i 0
    foreach target $widgets {
        if {![winfo exists $target]} {
            # Silently skipping this is how a scene ends up pointing at nothing
            # for the whole beat with no sign anything is wrong. Say so.
            ::demo::engine::_log warn "spotlight: no such widget $target"
            continue
        }
        # A widget on an unselected notebook tab has no meaningful position.
        if {![winfo ismapped $target]} { continue }
        update idletasks
        set x [winfo rootx $target]
        set y [winfo rooty $target]
        set ww [winfo width $target]
        set wh [winfo height $target]
        if {$ww <= 1 || $wh <= 1} { continue }

        set pad 4
        set t 3
        set x0 [expr {$x - $pad}]
        set y0 [expr {$y - $pad}]
        set x1 [expr {$x + $ww + $pad}]
        set y1 [expr {$y + $wh + $pad}]

        foreach {tag gx gy gw gh} [list \
            top    $x0 $y0                  [expr {$x1 - $x0}] $t \
            bottom $x0 [expr {$y1 - $t}]    [expr {$x1 - $x0}] $t \
            left   $x0 $y0                  $t [expr {$y1 - $y0}] \
            right  [expr {$x1 - $t}] $y0    $t [expr {$y1 - $y0}]] {
            set sw ${spot_pfx}_${i}_$tag
            # REUSE rather than recreate. Every beat spotlights something, and
            # destroying four borderless toplevels and building four more, 157
            # times, is visible work for the window server on a real display.
            # Repositioning an existing one is not.
            if {![winfo exists $sw]} {
                toplevel $sw -background $accent2
                wm overrideredirect $sw 1
                catch {wm attributes $sw -topmost 1}
                catch {wm attributes $sw -type splash}
            } else {
                $sw configure -background $accent2
                wm deiconify $sw
            }
            wm geometry $sw "${gw}x${gh}+${gx}+${gy}"
            raise $sw
            lappend spots $sw
        }
        incr i
    }

    if {[llength $spots]} {
        set pulse_after [after 480 ::demo::caption::_pulse]
    }
    return [llength $spots]
}

# _pulse - blink the spotlight so the eye finds it, then settle.
proc ::demo::caption::_pulse {} {
    variable spots
    variable accent2
    variable pulse_after
    variable pulse_on
    variable bg

    if {![llength $spots]} { set pulse_after ""; return }
    set pulse_on [expr {!$pulse_on}]
    set col [expr {$pulse_on ? $accent2 : "#7a5a24"}]
    foreach s $spots {
        if {[winfo exists $s]} { $s configure -background $col }
    }
    set pulse_after [after 480 ::demo::caption::_pulse]
}

# clear_spotlight - hide the frame. The windows are withdrawn, not destroyed, so
# the next beat can reposition them instead of rebuilding them.
proc ::demo::caption::clear_spotlight {} {
    variable spots
    variable pulse_after
    catch {after cancel $pulse_after}
    set pulse_after ""
    foreach s $spots { catch {wm withdraw $s} }
    set spots {}
}

# destroy_spotlights - actually tear the pool down (on shutdown).
proc ::demo::caption::destroy_spotlights {} {
    variable spot_pfx
    clear_spotlight
    foreach w [winfo children .] {
        if {[string match "${spot_pfx}_*" $w]} { catch {destroy $w} }
    }
}

proc ::demo::caption::destroy_all {} {
    variable w
    variable card
    destroy_spotlights
    hide_card
    catch {destroy $w}
}
