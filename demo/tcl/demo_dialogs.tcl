# demo_dialogs.tcl - make modal dialogs safe for an unattended walkthrough.
#
# WHY THIS EXISTS: every Tk modal dialog parks in its own event loop until a
# human clicks it. In a narrated demo there is no human at the keyboard, so a
# single unexpected tk_messageBox would freeze the walkthrough mid-sentence with
# the narration still playing over a dead screen.
#
# So while the demo is playing we replace the four blocking dialogs with
# non-blocking stand-ins:
#
#   tk_messageBox      -> a floating toast that shows the real message, then
#                         self-dismisses and returns the dialog's default answer.
#   tk_getSaveFile     -> returns a path the scene armed in advance.
#   tk_getOpenFile     -> ditto.
#   tk_chooseDirectory -> ditto.
#
# The message text is still shown, so a demo beat can legitimately show off the
# plugin's own validation errors -- it just does not stop for them.
#
# ORDERING TRAP: `package require Tk` reinstalls the real tk_messageBox, so
# install() must run AFTER mdance.tcl has been sourced. Installing first is a
# silent no-op and the demo hangs on the first dialog.

namespace eval ::demo::dialogs {
    variable installed 0
    variable saved         ;# original proc bodies/args, keyed by name
    array set saved {}
    variable answers       ;# FIFO of armed file-dialog answers
    set answers {}
    variable log {}        ;# every dialog the demo triggered, for the log pane
    variable toast_n 0
    variable on_dialog ""  ;# optional callback: {title icon message}
}

# arm - queue the path the next file dialog should return. Scenes call this
# immediately before invoking an export button.
proc ::demo::dialogs::arm {path} {
    variable answers
    lappend answers $path
    return $path
}

proc ::demo::dialogs::disarm {} {
    variable answers
    set answers {}
}

proc ::demo::dialogs::_take {} {
    variable answers
    if {[llength $answers] == 0} { return "" }
    set p [lindex $answers 0]
    set answers [lrange $answers 1 end]
    return $p
}

proc ::demo::dialogs::history {} {
    variable log
    return $log
}

# --- the stand-ins ---------------------------------------------------------

proc ::demo::dialogs::_messageBox {args} {
    variable log
    variable on_dialog

    array set o {-icon info -title "MDANCE" -message "" -type ok -default ""}
    foreach {k v} $args { set o($k) $v }

    lappend log [list messageBox $o(-title) $o(-icon) $o(-message)]
    if {$on_dialog ne ""} {
        catch {uplevel #0 [list {*}$on_dialog $o(-title) $o(-icon) $o(-message)]}
    }
    _toast $o(-icon) $o(-title) $o(-message)

    # Answer the way a user who wants the demo to continue would.
    switch -exact -- $o(-type) {
        ok           { return ok }
        okcancel     { return ok }
        yesno        { return yes }
        yesnocancel  { return yes }
        retrycancel  { return cancel }
        abortretryignore { return ignore }
        default      { return ok }
    }
}

proc ::demo::dialogs::_getSaveFile {args} {
    variable log
    set p [_take]
    lappend log [list getSaveFile $p]
    return $p
}

proc ::demo::dialogs::_getOpenFile {args} {
    variable log
    set p [_take]
    lappend log [list getOpenFile $p]
    return $p
}

proc ::demo::dialogs::_chooseDirectory {args} {
    variable log
    set p [_take]
    lappend log [list chooseDirectory $p]
    return $p
}

# _toast - a non-modal replica of a message box, top-right, self-dismissing.
proc ::demo::dialogs::_toast {icon title message} {
    variable toast_n
    incr toast_n
    set t .demo_toast$toast_n
    catch {destroy $t}

    switch -exact -- $icon {
        error    { set accent "#ff6b6b" ; set glyph "!" }
        warning  { set accent "#ffb454" ; set glyph "!" }
        question { set accent "#4da3ff" ; set glyph "?" }
        default  { set accent "#54c98b" ; set glyph "i" }
    }

    toplevel $t -background "#11141a"
    wm overrideredirect $t 1
    catch {wm attributes $t -topmost 1}
    catch {wm attributes $t -type splash}

    frame $t.stripe -background $accent -width 5
    pack $t.stripe -side left -fill y

    frame $t.b -background "#11141a"
    pack $t.b -fill both -expand 1 -padx 14 -pady 12
    label $t.b.t -background "#11141a" -foreground $accent -anchor w \
        -text "$glyph  $title" -font [list TkDefaultFont 12 bold]
    label $t.b.m -background "#11141a" -foreground "#eef2f8" -anchor w \
        -justify left -text $message -font [list TkDefaultFont 12] -wraplength 380
    pack $t.b.t -fill x
    pack $t.b.m -fill x -pady {4 0}

    update idletasks
    set tw 440
    set th [expr {[winfo reqheight $t] + 4}]
    set sw [winfo screenwidth $t]
    wm geometry $t "${tw}x${th}+[expr {$sw - $tw - 34}]+[expr {34 + ($toast_n % 4) * 8}]"
    raise $t

    # Long messages need longer on screen; short ones should not linger.
    set secs [expr {2200 + 26 * [string length $message]}]
    if {$secs > 7000} { set secs 7000 }
    after $secs [list catch [list destroy $t]]
    return $t
}

# --- install / uninstall ---------------------------------------------------

proc ::demo::dialogs::install {} {
    variable installed
    variable saved
    if {$installed} { return 0 }

    foreach {name repl} {
        tk_messageBox      ::demo::dialogs::_messageBox
        tk_getSaveFile     ::demo::dialogs::_getSaveFile
        tk_getOpenFile     ::demo::dialogs::_getOpenFile
        tk_chooseDirectory ::demo::dialogs::_chooseDirectory
    } {
        if {[info procs $name] ne "" || [info commands $name] ne ""} {
            # Rename rather than copy: these are commands, not necessarily procs
            # (tk_messageBox is a proc, but be defensive), so a body-copy would
            # not survive.
            catch {rename $name ::demo::dialogs::real_$name}
            set saved($name) 1
        }
        proc ::$name {args} "return \[$repl {*}\$args\]"
    }
    set installed 1
    return 1
}

proc ::demo::dialogs::uninstall {} {
    variable installed
    variable saved
    if {!$installed} { return 0 }
    foreach name [array names saved] {
        catch {rename ::$name ""}
        catch {rename ::demo::dialogs::real_$name ::$name}
    }
    array unset saved
    array set saved {}
    set installed 0
    return 1
}

proc ::demo::dialogs::is_installed {} {
    variable installed
    return $installed
}
