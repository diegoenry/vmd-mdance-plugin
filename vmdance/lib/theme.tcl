#
# VMDance - themes of the plugin's window
#
# ttk themes are global to the application, so the plugin never switches
# VMD's theme. It defines its own styles instead, one set per look, with a
# prefix: MdvH.* (VMD's own theme, fonts only), MdvN.* (macOS native: the
# aqua theme's elements and settings, borrowed while another theme is in
# use, as in VMD 2) and MdvF.* (flat: clam's configurable elements with the
# plugin's colours and check-box images, in any theme). Widgets keep logical
# style names (TButton, Toolbutton, Muted.TLabel ...); style_tree maps them
# to the active prefix.
#

namespace eval ::VMDance::Theme {
    variable choice auto     ;# Settings: auto native flat host
    variable mode ""         ;# applied: host native flat
    variable prefix MdvH
    variable prefixes {host MdvH native MdvN flat MdvF}
    variable names {auto "Automatic" native "macOS native" flat "Flat" host "VMD's own"}
    variable native_themes {aqua vista xpnative winnative}
    variable defined {}      ;# "ttktheme,mode" already defined
    variable bgwidgets {}    ;# classic widgets that take the window background
    variable applied_theme "" ;# the ttk theme the look was built for
    variable bg_element fill ;# aqua element that paints nested backgrounds
    variable P
    array set P {
        bg #f4f5f7 surface #ffffff border #d3d8df border2 #bcc3cd ink #262b33
        muted #6b7280 read #374151 disabled #a0a6b0 accent #2f6fdb soft #dbe7fb
        hover #eaeef3 pressed #dde2e9 heading #eef0f3 tab #e4e8ee thumb #c7cdd5
        thumb2 #a9b1bc arrow #5b6472 selborder #a9c4f0
    }
    variable classes {TButton Toolbutton TCheckbutton TRadiobutton TEntry TCombobox TSpinbox
        TMenubutton TLabel TFrame TLabelframe TLabelframe.Label TNotebook TNotebook.Tab
        Treeview Vertical.TScrollbar Horizontal.TScrollbar TSeparator TPanedwindow}
    # logical styles used by the code -> the class they are made from
    variable roles {Muted.TLabel TLabel Read.TLabel TLabel Title.TLabel TLabel
                    Section.TLabel TLabel Section.TLabelframe TLabelframe Holder.TFrame TFrame}
}

# Choices that make sense here, in Settings order.
proc ::VMDance::Theme::available {} {
    variable native_themes
    set out auto
    if {[tk windowingsystem] eq "aqua" || [ttk::style theme use] in $native_themes} { lappend out native }
    lappend out flat host
}

# The name of a choice in Settings ("native" is the platform's look).
proc ::VMDance::Theme::label {choice} {
    variable names
    if {$choice eq "native" && [tk windowingsystem] ne "aqua"} { return "Native (Windows)" }
    dict get $names $choice
}

# What a choice means in this VMD: host, native or flat.
proc ::VMDance::Theme::resolve {choice} {
    variable native_themes
    switch -- $choice {
        host { return host }
        flat { return flat }
        auto - native {
            if {[ttk::style theme use] in $native_themes} { return host }
            if {[tk windowingsystem] eq "aqua" && "aqua" in [ttk::style theme names]} { return native }
            return flat
        }
    }
    error "unknown theme \"$choice\" (valid: auto, native, flat, host)"
}

# Window background of the active look.
proc ::VMDance::Theme::bg {} {
    variable prefix
    set c [ttk::style lookup $prefix.TFrame -background]
    if {$c eq ""} { set c [ttk::style lookup TFrame -background] }
    if {$c eq ""} { set c #f4f5f7 }
    return $c
}

# A classic widget (canvas, text) whose background follows the window's.
proc ::VMDance::Theme::bg_widget {path} {
    variable bgwidgets
    if {$path ni $bgwidgets} { lappend bgwidgets $path }
    catch {$path configure -background [bg]}
}

#---------------------------------------------------------------------------
# Borrowing elements from another theme
#---------------------------------------------------------------------------

proc ::VMDance::Theme::_elements {theme} {
    variable elemcache
    if {![info exists elemcache($theme)]} {
        set elemcache($theme) [ttk::style theme settings $theme {ttk::style element names}]
    }
    return $elemcache($theme)
}

# The theme and element that implement `name` in `theme`: the longest dotted
# suffix it defines, else the one the default theme defines; "" when the
# element is generic (the same in every theme).
proc ::VMDance::Theme::_impl {theme name} {
    set parts [split $name .]
    set ts [list $theme]
    if {$theme ne "default"} { lappend ts default }
    foreach t $ts {
        set el [_elements $t]
        for {set i 0} {$i < [llength $parts]} {incr i} {
            set cand [join [lrange $parts $i end] .]
            if {$cand in $el} { return [list $t $cand] }
        }
    }
    return ""
}

# Split a layout ("element ?-option value ...? element ...") into
# {element {options}} pairs.
proc ::VMDance::Theme::_nodes {L} {
    set out {}
    set i 0; set n [llength $L]
    while {$i < $n} {
        set el [lindex $L $i]; incr i
        set opts {}
        while {$i < $n && [string match -* [lindex $L $i]]} {
            lappend opts [lindex $L $i] [lindex $L [expr {$i + 1}]]
            incr i 2
        }
        lappend out $el $opts
    }
    return $out
}

# Copy of a layout in which every theme-specific element is replaced by a
# clone (prefix.name) of the element `theme` would use.
proc ::VMDance::Theme::_clone {pre theme L} {
    set out {}
    foreach {el opts} [_nodes $L] {
        set impl [_impl $theme $el]
        if {$impl ne ""} {
            set new $pre.$el
            if {$new ni [ttk::style element names]} {
                ttk::style element create $new from {*}$impl
            }
            set el $new
        }
        if {[dict exists $opts -children]} {
            dict set opts -children [_clone $pre $theme [dict get $opts -children]]
        }
        lappend out $el {*}$opts
    }
    return $out
}

# Layout, settings and state maps of `cls` in `theme`, as style pre.cls.
proc ::VMDance::Theme::_borrow {pre theme cls {as ""}} {
    if {$as eq ""} { set as $cls }
    set L [ttk::style theme settings $theme [list ttk::style layout $cls]]
    if {[llength $L]} { ttk::style layout $pre.$as [_clone $pre $theme $L] }
    return $L
}

#---------------------------------------------------------------------------
# The three looks
#---------------------------------------------------------------------------

proc ::VMDance::Theme::_define {mode} {
    variable defined; variable prefixes
    set key "[ttk::style theme use],$mode"
    if {$key in $defined} return
    _define_$mode [dict get $prefixes $mode]
    lappend defined $key
}

# VMD's own theme: styles inherit everything; only fonts and a few colours.
proc ::VMDance::Theme::_define_host {p} {
    ttk::style configure $p.Muted.TLabel -foreground #6b7280
    ttk::style configure $p.Read.TLabel -foreground #374151
    if {[ttk::style theme use] eq "aqua"} {
        # aqua pads notebook pages by 18 px on each side; the pages have their own
        ttk::style configure $p.TNotebook -padding {2 4 2 2}
        ttk::style configure $p.TNotebook.Tab -padding {5 2}
    }
}

# macOS native while another theme is in use: aqua's elements and settings.
proc ::VMDance::Theme::_define_native {p} {
    variable classes; variable roles
    set rcfg [ttk::style theme settings aqua {ttk::style configure .}]
    set rmap [ttk::style theme settings aqua {ttk::style map .}]
    foreach cls $classes {
        _borrow $p aqua $cls
        set cfg [dict merge $rcfg [ttk::style theme settings aqua [list ttk::style configure $cls]]]
        set mp  [dict merge $rmap [ttk::style theme settings aqua [list ttk::style map $cls]]]
        if {[llength $cfg]} { ttk::style configure $p.$cls {*}$cfg }
        if {[llength $mp]} { ttk::style map $p.$cls {*}$mp }
    }
    # Aqua shades a widget's background by how deeply it sits in group boxes
    # and notebooks; its "fill" element does that. Borrowed widgets draw it
    # first, or they would show flat boxes inside group boxes. (Labelframes
    # draw their own group box and are left alone.)
    set bgel $p.nestedfill
    if {$bgel ni [ttk::style element names]} {
        ttk::style element create $bgel from aqua $::VMDance::Theme::bg_element
    }
    foreach cls {TFrame TLabel TCheckbutton TRadiobutton TButton Toolbutton TMenubutton
                 TNotebook TEntry TCombobox TSpinbox TPanedwindow} {
        set L [ttk::style layout $p.$cls]
        if {[llength $L] && [lindex $L 0] ne $bgel} { ttk::style layout $p.$cls [concat [list $bgel -sticky nswe] $L] }
    }
    # table headings: the heading style of a Treeview style is <style>.Heading
    _borrow $p aqua Heading Treeview.Heading
    set hcfg [dict merge $rcfg [ttk::style theme settings aqua {ttk::style configure Heading}] \
                  [ttk::style theme settings aqua {ttk::style configure Treeview.Heading}]]
    ttk::style configure $p.Treeview.Heading {*}$hcfg
    ttk::style map $p.Treeview.Heading -background {} -foreground {}
    _roles $p
    ttk::style configure $p.TNotebook -padding {2 4 2 2}
    ttk::style configure $p.Muted.TLabel -foreground #6b7280
    ttk::style configure $p.Read.TLabel -foreground #374151
    # aqua leaves the field colour to its default; VMD 2 sets a grey one
    foreach cls {TEntry TSpinbox TCombobox} {
        ttk::style configure $p.$cls -fieldbackground systemTextBackgroundColor
    }
    # aqua leaves -padding at the element default (0); VMD 2's own settings
    # (2 to 5 px) would make every control larger than the native ones
    foreach cls {TButton Toolbutton TMenubutton TCheckbutton TRadiobutton TEntry TCombobox TSpinbox Treeview} {
        ttk::style configure $p.$cls -padding 0
    }
    ttk::style configure $p.TNotebook.Tab -padding {5 2}
    _listbox systemTextBackgroundColor systemTextColor systemSelectedTextBackgroundColor systemSelectedTextColor
}

# Logical styles (Muted.TLabel ...) as copies of their class in this look.
proc ::VMDance::Theme::_roles {p} {
    variable roles
    foreach {role base} $roles {
        set L [ttk::style layout $p.$base]
        if {[llength $L]} { ttk::style layout $p.$role $L }
        set cfg [ttk::style configure $p.$base]
        if {[llength $cfg]} { ttk::style configure $p.$role {*}$cfg }
        set mp [ttk::style map $p.$base]
        if {[llength $mp]} { ttk::style map $p.$role {*}$mp }
    }
    set L [ttk::style layout $p.TLabelframe.Label]
    if {[llength $L]} { ttk::style layout $p.Section.TLabelframe.Label $L }
    set cfg [ttk::style configure $p.TLabelframe.Label]
    if {[llength $cfg]} { ttk::style configure $p.Section.TLabelframe.Label {*}$cfg }
}

# Drop-down lists of comboboxes (Tk listboxes) in the plugin's windows.
proc ::VMDance::Theme::_listbox {bg fg sbg sfg} {
    foreach {opt v} [list background $bg foreground $fg selectBackground $sbg selectForeground $sfg] {
        option add *vmdance*TCombobox*Listbox.$opt $v
    }
}

# Image element: normal/hover/disabled variants of the check box or radio.
# An element cannot be made again: its images are, at the size of the
# text (a look applied after the text size changed).
proc ::VMDance::Theme::_indicator {p kind} {
    set el $p.[expr {$kind eq "check" ? "Checkbutton" : "Radiobutton"}].indicator
    set sz [expr {$::VMDance::Fonts::size <= 13 ? 16 : ($::VMDance::Fonts::size <= 17 ? 20 : 24)}]
    foreach v {off on off_hover on_hover off_disabled on_disabled} {
        set src [::VMDance::Icons::get ui_${kind}_$v $sz]
        if {$src eq ""} { return 0 }
        set img($v) mdv_indicator_${p}_${kind}_$v
        # (made again under the same name: the element shows the new one,
        # at its size; a photo image written over keeps its larger size)
        image create photo $img($v)
        $img($v) copy $src
    }
    if {$el in [ttk::style element names]} { return 1 }
    ttk::style element create $el image [list $img(off) \
        {disabled selected} $img(on_disabled) disabled $img(off_disabled) \
        {active selected} $img(on_hover) selected $img(on) active $img(off_hover)] \
        -sticky {} -padding {0 0 5 0}
    return 1
}

# Flat: clam's elements (colour options for everything) in the plugin's
# colours, with image check boxes and slim scrollbars, in any host theme.
proc ::VMDance::Theme::_define_flat {p} {
    variable classes; variable P
    array set c [array get P]
    set ok [expr {[_indicator $p check] && [_indicator $p radio]}]
    foreach cls $classes {
        if {[string match *.TScrollbar $cls]} continue
        _borrow $p clam $cls
    }
    # slim scrollbars: trough and thumb, no arrows
    foreach o {Vertical Horizontal} {
        set tr [lindex [_clone $p clam [list $o.Scrollbar.trough]] 0]
        set th [lindex [_clone $p clam [list $o.Scrollbar.thumb]] 0]
        set st [expr {$o eq "Vertical" ? "ns" : "we"}]
        ttk::style layout $p.$o.TScrollbar [list $tr -sticky $st -children [list $th -expand 1 -sticky nswe]]
    }
    # Every state map below ends with a {} entry (all states), so that VMD's
    # own maps for the parent styles never apply.
    ttk::style configure $p.TFrame -background $c(bg)
    ttk::style configure $p.TLabel -background $c(bg) -foreground $c(ink)
    ttk::style map $p.TLabel -foreground [list disabled $c(disabled) {} $c(ink)] -background [list {} $c(bg)]
    foreach {cls pad} {TButton {10 3} TMenubutton {10 3}} {
        ttk::style configure $p.$cls -background $c(surface) -foreground $c(ink) -bordercolor $c(border2) \
            -lightcolor $c(surface) -darkcolor $c(surface) -relief raised -padding $pad -anchor center \
            -arrowcolor $c(arrow) -focuscolor $c(soft)
        ttk::style map $p.$cls \
            -background [list disabled $c(bg) pressed $c(pressed) active $c(hover) {} $c(surface)] \
            -lightcolor [list disabled $c(bg) pressed $c(pressed) active $c(hover) {} $c(surface)] \
            -darkcolor  [list disabled $c(bg) pressed $c(pressed) active $c(hover) {} $c(surface)] \
            -bordercolor [list disabled $c(border) focus $c(accent) {} $c(border2)] \
            -foreground [list disabled $c(disabled) {} $c(ink)] -relief [list {} raised]
    }
    ttk::style configure $p.TButton -width -8
    ttk::style configure $p.Toolbutton -background $c(bg) -bordercolor $c(bg) -lightcolor $c(bg) \
        -darkcolor $c(bg) -relief flat -padding 2 -anchor center -focuscolor $c(bg)
    ttk::style map $p.Toolbutton \
        -background [list disabled $c(bg) selected $c(soft) pressed $c(pressed) active $c(hover) {} $c(bg)] \
        -lightcolor [list disabled $c(bg) selected $c(soft) pressed $c(pressed) active $c(hover) {} $c(bg)] \
        -darkcolor  [list disabled $c(bg) selected $c(soft) pressed $c(pressed) active $c(hover) {} $c(bg)] \
        -bordercolor [list disabled $c(bg) selected $c(selborder) pressed $c(border2) active $c(border) {} $c(bg)] \
        -relief [list disabled flat selected raised pressed raised active raised {} flat]
    foreach cls {TCheckbutton TRadiobutton} {
        ttk::style configure $p.$cls -background $c(bg) -foreground $c(ink) -padding {1 1} -focuscolor $c(bg)
        ttk::style map $p.$cls -background [list {} $c(bg)] -foreground [list disabled $c(disabled) {} $c(ink)]
        if {!$ok} { ttk::style configure $p.$cls -indicatorbackground $c(surface) -indicatorforeground $c(accent) }
    }
    foreach cls {TEntry TCombobox TSpinbox} {
        ttk::style configure $p.$cls -fieldbackground $c(surface) -background $c(surface) -foreground $c(ink) \
            -bordercolor $c(border2) -lightcolor $c(surface) -darkcolor $c(surface) -arrowcolor $c(arrow) \
            -insertcolor $c(ink) -selectbackground $c(soft) -selectforeground $c(ink) -padding {4 2}
        ttk::style map $p.$cls \
            -bordercolor [list focus $c(accent) {} $c(border2)] \
            -lightcolor [list focus $c(soft) {} $c(surface)] \
            -background [list pressed $c(pressed) active $c(hover) {} $c(surface)] \
            -fieldbackground [list disabled $c(bg) {} $c(surface)] \
            -foreground [list disabled $c(disabled) {} $c(ink)] \
            -arrowcolor [list disabled $c(disabled) {} $c(arrow)] \
            -selectbackground [list {} $c(soft)] -selectforeground [list {} $c(ink)]
    }
    ttk::style configure $p.TCombobox -arrowsize 11 -selectbackground $c(surface)
    ttk::style map $p.TCombobox -selectbackground [list {} $c(surface)]
    ttk::style configure $p.TSpinbox -arrowsize 9
    # a "raised" clam border in the background colours would not show: solid
    # draws a 1 px line in the border colour
    ttk::style configure $p.TLabelframe -background $c(bg) -bordercolor $c(border) -lightcolor $c(bg) \
        -darkcolor $c(bg) -relief solid -borderwidth 1 -labeloutside 1 -labelmargins {0 0 0 4}
    ttk::style configure $p.TLabelframe.Label -background $c(bg) -foreground $c(ink)
    ttk::style configure $p.TNotebook -background $c(bg) -bordercolor $c(border) -lightcolor $c(bg) \
        -darkcolor $c(bg) -padding {2 4 2 2} -tabmargins {2 2 2 0}
    ttk::style configure $p.TNotebook.Tab -background $c(tab) -foreground $c(muted) -bordercolor $c(border) \
        -lightcolor $c(tab) -darkcolor $c(tab) -padding {8 3}
    ttk::style map $p.TNotebook.Tab \
        -background [list selected $c(bg) active $c(hover) {} $c(tab)] \
        -lightcolor [list selected $c(bg) active $c(hover) {} $c(tab)] \
        -foreground [list selected $c(ink) active $c(ink) {} $c(muted)] \
        -padding [list {} {8 3}]
    ttk::style configure $p.Treeview -background $c(surface) -fieldbackground $c(surface) -foreground $c(ink) \
        -bordercolor $c(border) -lightcolor $c(surface) -padding 0
    ttk::style map $p.Treeview -background [list selected $c(soft) {} $c(surface)] \
        -foreground [list selected $c(ink) disabled $c(disabled) {} $c(ink)] -bordercolor [list {} $c(border)]
    _borrow $p clam Heading Treeview.Heading
    ttk::style configure $p.Treeview.Heading -background $c(heading) -foreground $c(ink) -relief flat \
        -bordercolor $c(border) -lightcolor $c(heading) -darkcolor $c(heading) -padding {4 3}
    ttk::style map $p.Treeview.Heading -background [list pressed $c(pressed) active $c(hover) {} $c(heading)] \
        -foreground [list {} $c(ink)] -relief [list {} flat]
    foreach o {Vertical Horizontal} {
        ttk::style configure $p.$o.TScrollbar -troughcolor $c(surface) -background $c(thumb) \
            -bordercolor $c(thumb) -lightcolor $c(thumb) -darkcolor $c(thumb) -arrowsize 9 -gripcount 0
        ttk::style map $p.$o.TScrollbar \
            -background [list pressed $c(thumb2) active $c(thumb2) {} $c(thumb)] \
            -lightcolor [list pressed $c(thumb2) active $c(thumb2) {} $c(thumb)] \
            -darkcolor [list pressed $c(thumb2) active $c(thumb2) {} $c(thumb)] \
            -bordercolor [list pressed $c(thumb2) active $c(thumb2) {} $c(thumb)]
    }
    ttk::style configure $p.TSeparator -background $c(border)
    ttk::style configure $p.TPanedwindow -background $c(bg)
    # clam's layouts do not paint their background everywhere (labelframes,
    # labels, check buttons ...); under aqua the window's own nested shade
    # would show through. Every flat widget paints the plugin's first.
    # (Not in TLabelframe.Label: the element fills the whole widget, and the
    # label part is drawn after the group box's border, which it would erase.)
    set fill $p.bgfill
    if {$fill ni [ttk::style element names]} { ttk::style element create $fill from default background }
    foreach cls {TFrame TLabel TLabelframe TNotebook TPanedwindow TCheckbutton
                 TRadiobutton TButton Toolbutton TMenubutton TEntry TCombobox TSpinbox} {
        set L [ttk::style layout $p.$cls]
        if {[lindex $L 0] ne $fill} { ttk::style layout $p.$cls [concat [list $fill -sticky nswe] $L] }
    }
    _roles $p
    ttk::style configure $p.Muted.TLabel -foreground $c(muted)
    ttk::style map $p.Muted.TLabel -foreground [list {} $c(muted)]
    ttk::style configure $p.Read.TLabel -foreground $c(read)
    ttk::style map $p.Read.TLabel -foreground [list {} $c(read)]
    _listbox $c(surface) $c(ink) $c(soft) $c(ink)
}

#---------------------------------------------------------------------------
# Applying a look
#---------------------------------------------------------------------------

# Fonts and row height of the active look (after a text size change too).
proc ::VMDance::Theme::fonts {} {
    variable prefix; variable roles
    set p $prefix
    set f MdvUI
    foreach cls {TButton TCheckbutton TRadiobutton TLabel TMenubutton TEntry TCombobox TSpinbox Toolbutton TNotebook.Tab} {
        ttk::style configure $p.$cls -font $f
    }
    ttk::style configure $p.TLabelframe.Label -font MdvUIBold
    ttk::style configure $p.Section.TLabelframe.Label -font MdvUIBold
    ttk::style configure $p.Treeview -font $f -rowheight [expr {[font metrics $f -linespace] + 6}]
    ttk::style configure $p.Treeview.Heading -font $f
    ttk::style configure $p.Title.TLabel -font MdvUIHead
    ttk::style configure $p.Section.TLabel -font MdvUIBold -padding {4 0 0 3}
    # frames that only hold other widgets and draw nothing themselves
    ttk::style layout $p.Holder.TFrame {null -sticky nswe}
    ttk::style configure $p.Muted.TLabel -font MdvUISmall
    ttk::style configure $p.Read.TLabel -font MdvUISmall
    option add *vmdance*Listbox.font $f
}

# Apply a look (Settings choice) to every window of the plugin.
proc ::VMDance::Theme::apply {{ch ""}} {
    variable choice; variable mode; variable prefix; variable prefixes; variable bgwidgets
    if {$ch ne ""} {
        resolve $ch   ;# validates
        set choice $ch
    }
    set m [resolve $choice]
    variable last_error ""
    if {[catch {_define $m} err]} {
        # a look that cannot be built here (unusual Tk): fall back to VMD's own
        set last_error $::errorInfo
        puts "VMDance) theme \"$m\" not available: $err"
        set m host
        _define host
    }
    set mode $m
    set prefix [dict get $prefixes $m]
    # (the check boxes' images at the text size of now)
    if {$m eq "flat"} { catch {_indicator $prefix check; _indicator $prefix radio} }
    variable applied_theme [ttk::style theme use]
    fonts
    foreach top [_toplevels] { style_tree $top }
    set keep {}
    foreach wd $bgwidgets {
        if {[winfo exists $wd]} { catch {$wd configure -background [bg]}; lappend keep $wd }
    }
    set bgwidgets $keep
    return $mode
}

proc ::VMDance::Theme::_toplevels {} {
    set w $::VMDance::GUI::w
    if {![winfo exists $w]} { return {} }
    set out [list $w]
    foreach c [winfo children $w] { if {[winfo class $c] eq "Toplevel"} { lappend out $c } }
    return $out
}

# <<ThemeChanged>> reaches every widget whenever any style setting changes,
# including the plugin's own: rebuild only when the ttk theme itself was
# switched (by VMD or another plugin), or this would never stop.
proc ::VMDance::Theme::_rethemed {} {
    variable applied_theme
    if {[ttk::style theme use] eq $applied_theme} return
    after cancel ::VMDance::Theme::apply
    after idle ::VMDance::Theme::apply
}

# The logical style of a widget, whatever look it was given before.
proc ::VMDance::Theme::_role {c cls} {
    set st [$c cget -style]
    regsub {^Mdv[HNF]?\.} $st "" st
    set st [string map {MdvMuted.TLabel Muted.TLabel MdvRead.TLabel Read.TLabel MdvTitle.TLabel Title.TLabel
                        MdvSection.TLabelframe Section.TLabelframe MdvSection.TLabel Section.TLabel
                        MdvHolder.TFrame Holder.TFrame} $st]
    if {$st ne ""} { return $st }
    switch -- $cls {
        TScrollbar  { return [expr {[$c cget -orient] eq "horizontal" ? "Horizontal.TScrollbar" : "Vertical.TScrollbar"}] }
        TProgressbar { return [expr {[$c cget -orient] eq "vertical" ? "Vertical.TProgressbar" : "Horizontal.TProgressbar"}] }
        default     { return $cls }
    }
}

# Give every widget under (and including) w the active look and the
# plugin's fonts.
proc ::VMDance::Theme::style_tree {w} {
    variable prefix
    if {[winfo class $w] eq "Toplevel"} { catch {$w configure -background [bg]} }
    foreach c [winfo children $w] {
        set cls [winfo class $c]
        # (a megawidget of Tk's own dialogs has a ttk class but no -style:
        # its parts are styled)
        if {[string match T* $cls] && $cls ni {Text Toplevel} && [catch {$c cget -style}]} {
            style_tree $c
            continue
        }
        switch -- $cls {
            TLabel {
                # A ttk::label takes a -font from the option database when VMD
                # sets one (VMD 2 does), and that would override the style's.
                $c configure -style $prefix.[_role $c $cls] -font ""
            }
            TButton - TCheckbutton - TRadiobutton - TMenubutton - TLabelframe - TNotebook -
            TFrame - Treeview - TScrollbar - TSeparator - TPanedwindow - TProgressbar {
                $c configure -style $prefix.[_role $c $cls]
            }
            TEntry - TCombobox - TSpinbox {
                $c configure -style $prefix.[_role $c $cls] -font MdvUI
            }
            Text - Listbox - Label - Button - Checkbutton - Radiobutton {
                set f [$c cget -font]
                if {[string match MdvUI* $f]} {
                } elseif {[string match Mdv* $f]} {
                    $c configure -font [string map {MdvSmall MdvUISmall MdvText MdvUI
                        MdvBold MdvUIBold MdvTitle MdvUIHead} $f]
                } else {
                    $c configure -font MdvUI
                }
            }
            Menu { if {[tk windowingsystem] ne "aqua"} { $c configure -font MdvUI } }
            Toplevel { continue }
        }
        style_tree $c
    }
}
