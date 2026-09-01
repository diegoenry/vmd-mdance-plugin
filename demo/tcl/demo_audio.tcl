# demo_audio.tcl - narration playback.
#
# One job: start a WAV playing without blocking VMD's event loop, and be able to
# stop it instantly. Everything is done with a detached child process, because
# the alternative -- a blocking player -- would freeze the very GUI the demo is
# supposed to be showing off.

namespace eval ::demo::audio {
    variable player ""      ;# resolved command, e.g. /usr/bin/afplay
    variable player_args {} ;# extra args the player needs before the filename
    variable pid ""         ;# pid of the currently playing child, "" if silent
    variable muted 0
    variable checked 0
}

# find_player - locate a command-line audio player. Returns "" if none.
#
# macOS ships afplay, which is what this demo is developed against. The others
# are there so the walkthrough is not macOS-only.
proc ::demo::audio::find_player {} {
    variable player
    variable player_args
    variable checked

    if {$checked} { return $player }
    set checked 1

    foreach {cmd cmdargs} {
        afplay  {}
        ffplay  {-nodisp -autoexit -loglevel quiet}
        paplay  {}
        aplay   {-q}
    } {
        set path [auto_execok $cmd]
        if {$path ne ""} {
            set player [lindex $path 0]
            set player_args $cmdargs
            return $player
        }
    }
    set player ""
    return ""
}

proc ::demo::audio::available {} {
    return [expr {[find_player] ne ""}]
}

# play - start $file. Returns the duration the caller should budget, or 0 if
# nothing is playing (muted, no player, or missing file).
proc ::demo::audio::play {file} {
    variable pid
    variable player
    variable player_args
    variable muted

    stop

    if {$muted} { return 0 }
    if {$file eq "" || ![file readable $file]} { return 0 }
    if {[find_player] eq ""} { return 0 }

    # 2>/dev/null: some players chatter on stderr, and VMD redirects stderr to a
    # Tk console that is not open for writing once the GUI is up -- writing to it
    # raises "channel console2 wasn't opened for writing" and would abort the
    # beat. (Same trap the plugin itself hit; see notes/HARDENING_BACKLOG.md.)
    if {[catch {
        set pid [exec $player {*}$player_args $file >/dev/null 2>/dev/null &]
    } err]} {
        set pid ""
        return 0
    }
    return 1
}

# stop - silence any narration immediately.
proc ::demo::audio::stop {} {
    variable pid
    if {$pid eq ""} { return }
    foreach p $pid {
        # The child may already have exited on its own; killing a reaped pid is
        # an error we do not care about.
        catch {exec kill $p}
    }
    set pid ""
}

# playing - 1 while the child is still alive.
proc ::demo::audio::playing {} {
    variable pid
    if {$pid eq ""} { return 0 }
    foreach p $pid {
        # `kill -0` tests for existence without signalling.
        if {![catch {exec kill -0 $p}]} { return 1 }
    }
    set pid ""
    return 0
}

proc ::demo::audio::mute {{on 1}} {
    variable muted
    set muted [expr {$on ? 1 : 0}]
    if {$muted} { stop }
    return $muted
}

proc ::demo::audio::is_muted {} {
    variable muted
    return $muted
}
