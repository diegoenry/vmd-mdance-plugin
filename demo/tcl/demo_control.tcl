# demo_control.tcl - the walkthrough's own control panel.
#
# The chapter list is the whole point: each clustering method is a separate
# chapter that can be played on its own, because "show me eQUAL" should not mean
# "sit through KMeans first". Every chapter's setup body puts the molecule and
# the plugin into the state that chapter assumes, so any row in this list is a
# valid starting point.
#
# WIDGET CHOICE, deliberately: the coloured parts use plain Tk widgets (label,
# listbox, text, frame), which honour -background and -foreground on every
# platform. The buttons are ttk and stay NATIVE. On macOS the Aqua theme ignores
# colour options on ttk widgets, so a "dark themed" ttk::treeview or ttk::button
# silently comes out light -- a dark panel with light widgets stranded in it
# looks broken. Native controls next to coloured panes looks intentional.

namespace eval ::demo::control {
    variable w .demo_control
    variable selected ""
    variable mute 0
    variable log_lines 0
    variable row_ids {}       ;# listbox index -> scene id

    variable bg      "#11141a"
    variable panel   "#171b23"
    variable fg      "#eef2f8"
    variable dim     "#8d99ad"
    variable accent  "#4da3ff"
    variable sel_bg  "#24405f"
}

proc ::demo::control::create {} {
    variable w
    variable bg
    variable panel
    variable fg
    variable dim
    variable accent
    variable sel_bg

    catch {destroy $w}
    toplevel $w
    wm title $w "MDANCE Walkthrough"
    wm geometry $w 600x460
    wm minsize $w 460 380
    wm protocol $w WM_DELETE_WINDOW ::demo::control::on_close

    # --- header (plain Tk: colours apply everywhere) ---
    frame $w.head -background $bg
    pack $w.head -fill x
    frame $w.head.rule -background $accent -height 3
    pack $w.head.rule -fill x -side top
    label $w.head.t -background $bg -foreground $fg -anchor w \
        -text "MDANCE Walkthrough" -font [list TkDefaultFont 15 bold]
    label $w.head.s -background $bg -foreground $dim -anchor w \
        -text "" -font [list TkDefaultFont 10]
    pack $w.head.t -fill x -padx 14 -pady {10 0}
    pack $w.head.s -fill x -padx 14 -pady {2 10}

    # --- chapter list ---
    frame $w.list -background $bg
    pack $w.list -fill both -expand 1 -padx 14 -pady {8 4}
    label $w.list.hdr -background $bg -foreground $dim -anchor w \
        -font [list TkFixedFont 10] \
        -text [format " %-3s %-38s %5s %7s" "#" "CHAPTER" "BEATS" "LENGTH"]
    pack $w.list.hdr -fill x
    frame $w.list.body -background $bg
    pack $w.list.body -fill both -expand 1
    listbox $w.list.body.lb -background $panel -foreground $fg \
        -selectbackground $sel_bg -selectforeground $fg \
        -font [list TkFixedFont 11] -height 9 -activestyle none \
        -borderwidth 0 -highlightthickness 0 -exportselection 0 \
        -yscrollcommand [list $w.list.body.sb set]
    ttk::scrollbar $w.list.body.sb -orient vertical \
        -command [list $w.list.body.lb yview]
    pack $w.list.body.sb -side right -fill y
    pack $w.list.body.lb -side left -fill both -expand 1
    bind $w.list.body.lb <<ListboxSelect>> ::demo::control::_on_select
    bind $w.list.body.lb <Double-1> ::demo::control::play_chapter

    # --- transport (native ttk buttons) ---
    ttk::frame $w.tr
    pack $w.tr -fill x -padx 12 -pady {6 0}
    ttk::button $w.tr.all   -text "Play all"     -width 9  -command ::demo::control::play_all
    ttk::button $w.tr.one   -text "Play chapter" -width 12 -command ::demo::control::play_chapter
    ttk::button $w.tr.from  -text "From here"    -width 10 -command ::demo::control::play_from
    ttk::button $w.tr.pause -text "Pause"        -width 8  -command ::demo::control::toggle_pause
    ttk::button $w.tr.stop  -text "Stop"         -width 7  -command ::demo::engine::stop
    pack $w.tr.all $w.tr.one $w.tr.from $w.tr.pause $w.tr.stop -side left -padx 2

    ttk::frame $w.tr2
    pack $w.tr2 -fill x -padx 12 -pady {4 6}
    ttk::button $w.tr2.prev  -text "‹ Beat"   -width 8  -command ::demo::engine::prev_beat
    ttk::button $w.tr2.next  -text "Beat ›"   -width 8  -command ::demo::engine::next_beat
    ttk::button $w.tr2.nextc -text "Chapter ›" -width 11 -command ::demo::engine::next_scene
    ttk::checkbutton $w.tr2.mute -text "Mute narration" \
        -variable ::demo::control::mute -command ::demo::control::_on_mute
    pack $w.tr2.prev $w.tr2.next $w.tr2.nextc -side left -padx 2
    pack $w.tr2.mute -side right -padx 4

    # --- now playing ---
    frame $w.now -background $panel
    pack $w.now -fill x -padx 14 -pady 4
    label $w.now.l -background $panel -foreground $accent -anchor w \
        -text "idle" -font [list TkDefaultFont 10 bold]
    label $w.now.c -background $panel -foreground $fg -anchor w -justify left \
        -text "Select a chapter, or press Play all." \
        -font [list TkDefaultFont 11] -wraplength 540
    pack $w.now.l -fill x -padx 10 -pady {8 2}
    pack $w.now.c -fill x -padx 10 -pady {0 9}

    # --- log ---
    frame $w.log -background $bg
    pack $w.log -fill both -expand 1 -padx 14 -pady {2 12}
    text $w.log.t -height 5 -background $panel -foreground $dim -relief flat \
        -wrap word -font [list TkFixedFont 10] -highlightthickness 0 \
        -borderwidth 0 -padx 8 -pady 6 \
        -yscrollcommand [list $w.log.sb set] -state disabled
    ttk::scrollbar $w.log.sb -orient vertical -command [list $w.log.t yview]
    pack $w.log.sb -side right -fill y
    pack $w.log.t -side left -fill both -expand 1
    $w.log.t tag configure info  -foreground "#8d99ad"
    $w.log.t tag configure ok    -foreground "#54c98b"
    $w.log.t tag configure warn  -foreground "#ffb454"
    $w.log.t tag configure error -foreground "#ff6b6b"
    $w.log.t tag configure scene -foreground "#4da3ff"

    populate
    refresh
    return $w
}

proc ::demo::control::populate {} {
    variable w
    variable selected
    variable row_ids
    if {![winfo exists $w.list.body.lb]} { return }

    set lb $w.list.body.lb
    $lb delete 0 end
    set row_ids {}
    set i 0
    set total 0.0
    foreach sid [::demo::scene_ids] {
        incr i
        set sc [::demo::scene_get $sid]
        set n [llength [dict get $sc beats]]
        set d [::demo::engine::scene_duration $sid]
        set total [expr {$total + $d}]
        lappend row_ids $sid
        $lb insert end [format " %-3d %-38s %5d %7s" \
            $i [_ellipsize [dict get $sc title] 38] $n [_mmss $d]]
    }
    $w.head.s configure -text \
        "[llength [::demo::scene_ids]] chapters  |  [_mmss $total] total  |  narration: [_voice_status]"
    if {$selected eq "" && [llength $row_ids]} {
        set selected [lindex $row_ids 0]
        $lb selection set 0
    }
}

proc ::demo::control::_ellipsize {s n} {
    if {[string length $s] <= $n} { return $s }
    return "[string range $s 0 [expr {$n - 2}]]…"
}

proc ::demo::control::_voice_status {} {
    if {![::demo::audio::available]} { return "no player - captions only" }
    set have 0
    set total 0
    foreach b [::demo::all_beats] {
        incr total
        if {[::demo::engine::beat_audio [dict get $b id]] ne ""} { incr have }
    }
    if {$total == 0} { return "no beats" }
    if {$have == 0} { return "not built - captions only" }
    if {$have < $total} { return "$have/$total beats voiced" }
    return "voiced"
}

proc ::demo::control::_mmss {secs} {
    set s [expr {int(round($secs))}]
    return [format "%d:%02d" [expr {$s / 60}] [expr {$s % 60}]]
}

proc ::demo::control::_on_select {} {
    variable w
    variable selected
    variable row_ids
    set idx [$w.list.body.lb curselection]
    if {[llength $idx]} {
        set selected [lindex $row_ids [lindex $idx 0]]
    }
}

proc ::demo::control::_on_mute {} {
    variable mute
    ::demo::audio::mute $mute
    log info [expr {$mute ? "Narration muted (captions still run to the recorded timings)." \
                          : "Narration unmuted."}]
}

# --- transport actions -----------------------------------------------------

proc ::demo::control::play_all {} {
    ::demo::engine::play [::demo::scene_ids]
}

proc ::demo::control::play_chapter {} {
    variable selected
    if {$selected eq ""} { return }
    ::demo::engine::play [list $selected]
}

proc ::demo::control::play_from {} {
    variable selected
    if {$selected eq ""} { return }
    set ids [::demo::scene_ids]
    set i [lsearch -exact $ids $selected]
    if {$i < 0} { set i 0 }
    ::demo::engine::play [lrange $ids $i end]
}

proc ::demo::control::toggle_pause {} {
    ::demo::engine::toggle_pause
}

proc ::demo::control::on_close {} {
    variable w
    ::demo::engine::stop
    ::demo::caption::destroy_all
    ::demo::dialogs::uninstall
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    ::demo::tab_tour_stop
    ::demo::rep_tour_stop
    catch {destroy $w}
}

# --- feedback --------------------------------------------------------------

proc ::demo::control::refresh {} {
    variable w
    variable row_ids
    if {![winfo exists $w]} { return }
    set st [::demo::engine::status]
    set state [dict get $st state]

    catch {$w.tr.pause configure -text [expr {$state eq "paused" ? "Resume" : "Pause"}]}

    if {$state eq "idle"} {
        $w.now.l configure -text "idle"
        $w.now.c configure -text "Select a chapter, or press Play all."
        return
    }

    set sid [dict get $st scene]
    if {$sid eq ""} { return }
    set sc [::demo::scene_get $sid]
    set bi [dict get $st beat_i]
    set bn [dict get $st beat_n]
    $w.now.l configure -text \
        "[string toupper $state] – [dict get $sc title]  (beat [expr {$bi + 1}]/$bn)"
    set beats [dict get $sc beats]
    if {$bi < [llength $beats]} {
        $w.now.c configure -text [dict get [lindex $beats $bi] caption]
    }
    # Follow along in the chapter list.
    set i [lsearch -exact $row_ids $sid]
    if {$i >= 0} {
        catch {
            $w.list.body.lb selection clear 0 end
            $w.list.body.lb selection set $i
            $w.list.body.lb see $i
        }
    }
}

proc ::demo::control::log {level text} {
    variable w
    variable log_lines
    if {![winfo exists $w.log.t]} { return }
    $w.log.t configure -state normal
    $w.log.t insert end "$text\n" $level
    incr log_lines
    # A long walkthrough would otherwise grow this pane without bound.
    if {$log_lines > 400} {
        $w.log.t delete 1.0 100.0
        incr log_lines -99
    }
    $w.log.t see end
    $w.log.t configure -state disabled
}
