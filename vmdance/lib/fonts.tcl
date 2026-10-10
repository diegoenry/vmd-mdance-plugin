#
# VMDance - fonts and widget styles (the preferences: prefs.tcl)
#
# One family and one text size for the whole plugin: interface fonts
# (MdvUI*) and plot fonts (MdvSmall ... MdvBig) are all derived
# from the "Text size" setting. The widget styles that use them are made by
# theme.tcl.
#

namespace eval ::VMDance::Fonts {
    variable family Helvetica
    variable size 12        ;# interface text size in points (Settings)
    variable reference 12   ;# plot text size figures are laid out for
    # font name -> {offset from the text size, weight}
    variable ui {
        MdvUI      {0 normal}
        MdvUIBold  {0 bold}
        MdvUISmall {-2 normal}
        MdvUIHead  {1 bold}
    }
    variable plot {
        MdvSmall {-2 normal}
        MdvText  {-1 normal}
        MdvBold  {-1 bold}
        MdvTitle {0 bold}
        MdvBig   {4 bold}
    }
}

proc ::VMDance::Fonts::init {} {
    variable ui; variable plot
    set new 0
    foreach {name spec} [concat $ui $plot] {
        if {$name ni [font names]} { font create $name; set new 1 }
    }
    if {$new} { apply }
}

proc ::VMDance::Fonts::_set {table sz} {
    variable family
    foreach {name spec} $table {
        lassign $spec off weight
        font configure $name -family $family -size [expr {max(7, $sz + $off)}] -weight $weight
    }
}

# Set the text size (points) of the interface and the plots. Named fonts
# update every widget that uses them at once.
proc ::VMDance::Fonts::apply {{sz ""}} {
    variable size; variable ui; variable plot
    if {$sz ne ""} {
        if {![regexp {^[1-9][0-9]?$} $sz] || $sz < 8 || $sz > 24} { error "text size must be a whole number of points from 8 to 24" }
        set size $sz
    }
    _set $ui $size
    _set $plot $size
    _styles
}

# Plot fonts at the reference size while figures are drawn (on 1), and back
# at the interface size (on 0): figure text sizes do not depend on how large
# the window's text is.
proc ::VMDance::Fonts::plot_reference {on} {
    variable size; variable reference; variable plot
    if {$size == $reference} return
    _set $plot [expr {$on ? $reference : $size}]
}

proc ::VMDance::Fonts::_styles {} {
    if {[namespace exists ::VMDance::Theme]} { ::VMDance::Theme::fonts }
}
