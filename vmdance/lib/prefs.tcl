#
# VMDance - the user's preferences, kept between VMD sessions (no Tk
# dependency)
#
# The window's appearance and the backend chosen in Settings, in
# ~/.vmdance.prefs (~/.mdanceview.prefs is read while there is none). The
# file is data: it is never evaluated, and invalid or unknown entries are
# ignored. The core reads the backend's (Backend::from_prefs), so that a
# script uses the program chosen in Settings as the window does.
#

namespace eval ::VMDance::Prefs {
    # (no home: none kept, rather than in whatever folder VMD runs in; a
    # name made a path: "|…" would be a pipe to open)
    variable file ""
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} { catch {set file [file normalize [file join $::env(HOME) .vmdance.prefs]]} }
    # key -> {default check}
    variable keys {
        ui_font        {12 {[regexp {^[1-9][0-9]?$} $v] && $v >= 8 && $v <= 24}}
        ui_window      {compact {$v in {compact medium large}}}
        show_toolbar   {1 {[string is boolean -strict $v]}}
        ui_theme       {auto {$v in {auto native flat host}}}
        show_left      {1 {[string is boolean -strict $v]}}
        show_opts      {0 {[string is boolean -strict $v]}}
        unlock_metrics {0 {[string is boolean -strict $v]}}
        backend_mode   {auto {$v in {auto cli library}}}
        backend_cli    {"" {[string length $v] < 4096}}
        backend_lib    {"" {[string length $v] < 4096}}
    }
}

# Stored preferences merged over the defaults. (A file only: a FIFO in its
# place would block VMD at its first use of the backend.)
proc ::VMDance::Prefs::load {} {
    variable file; variable keys
    set out {}
    foreach {k spec} $keys { dict set out $k [lindex $spec 0] }
    set f $file
    # (the plugin was MDANCEView before VMDance: its preferences are read
    # until these are first saved)
    if {$f ne "" && ![file exists $f] && [file tail $f] eq ".vmdance.prefs"} {
        set f [file join [file dirname $f] .mdanceview.prefs]
    }
    if {$f eq "" || ![file isfile $f]} { return $out }
    if {[catch {
        set fh [open $f r]
        fconfigure $fh -encoding utf-8
        set d [read $fh 65536]
        close $fh
        set d [join [lsearch -all -inline -not -regexp [split $d \n] {^\s*#}] \n]
        dict size $d
    }]} { return $out }
    foreach {k v} $d {
        if {![dict exists $keys $k]} continue
        set check [lindex [dict get $keys $k] 1]
        if {[catch {expr $check} ok] || !$ok} continue
        # yes/on/true → 1: the checkbuttons use 1 and 0
        if {[string match "*boolean*" $check]} { set v [expr {$v ? 1 : 0}] }
        dict set out $k $v
    }
    return $out
}

# Write preferences; returns "" or the reason they could not be saved. (As
# every file of the plugin's, Export::_write: a dotfile linked elsewhere
# stays linked, its permissions are kept, a read-only one is not replaced.)
proc ::VMDance::Prefs::save {d} {
    variable file
    # no file: preferences are not kept (tests, scripts)
    if {$file eq ""} { return "" }
    set text "# VMDance preferences (written by the plugin)\n"
    foreach {k v} $d { append text [list $k $v] \n }
    if {[catch {::VMDance::Export::_write $file $text} err]} { return $err }
    return ""
}
