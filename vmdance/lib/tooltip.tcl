#
# VMDance - lightweight tooltips
#

namespace eval ::VMDance::Tip {
    variable text
    variable after ""
}

proc ::VMDance::Tip::add {w msg} {
    variable text
    set text($w) $msg
    bind $w <Enter> [list ::VMDance::Tip::_arm $w]
    bind $w <Leave> ::VMDance::Tip::_hide
    bind $w <ButtonPress> +::VMDance::Tip::_hide
}

# (x y: where on the screen, for a part of a widget, a notebook's tab;
# else under the widget)
proc ::VMDance::Tip::_arm {w {x ""} {y ""}} {
    variable after
    after cancel $after
    set after [after 600 [list ::VMDance::Tip::_show $w $x $y]]
}

proc ::VMDance::Tip::_show {w {px ""} {py ""}} {
    variable text
    if {![winfo exists $w]} return
    set t .vmdance_tip
    catch {destroy $t}
    toplevel $t -background #333a45
    wm overrideredirect $t 1
    catch {wm attributes $t -topmost 1}
    label $t.l -text $text($w) -background #333a45 -foreground white -justify left \
        -font [expr {"MdvUISmall" in [font names] ? "MdvUISmall" : "TkDefaultFont"}] -padx 8 -pady 5 -wraplength 360
    pack $t.l
    set x [expr {[winfo rootx $w] + 8}]
    set y [expr {[winfo rooty $w] + [winfo height $w] + 4}]
    if {$px ne ""} { set x $px; set y $py }
    wm geometry $t +$x+$y
}

proc ::VMDance::Tip::_hide {} {
    variable after
    after cancel $after
    catch {destroy .vmdance_tip}
}
