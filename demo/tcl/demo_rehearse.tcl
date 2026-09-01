# demo_rehearse.tcl - play the whole walkthrough headlessly, fast, and report
# anything that broke.
#
#   DEMO_ROOT=... DEMO_REHEARSE_OUT=/tmp/r.txt \
#     vmd -dispdev text -eofexit -e demo/tcl/demo_rehearse.tcl
#
# This is the real test. The selfcheck in demo_main.tcl proves that every widget
# a scene NAMES exists; this proves that every action a scene TAKES actually
# works -- the clustering runs really run, the plots really draw, the exports
# really write files. It runs each beat at a fraction of its narrated length, so
# a twenty-five minute walkthrough rehearses in about a minute of wall clock,
# with the backend doing all of its real work.
#
# Env:
#   DEMO_REHEARSE_OUT   where to write the report (stdout is swallowed by VMD's
#                       Tk console once the GUI exists)
#   DEMO_REHEARSE_ONLY  rehearse just this scene id
#   DEMO_BEAT_SECS      seconds per beat (default 0.35)
#   DEMO_TIMEOUT        give up after this many seconds (default 900)

set env(DEMO_CHECK) ""
set env(DEMO_NOSTART) 1
namespace eval ::demo::rehearse {
    variable chan stdout
    variable done 0
    variable t0 0
    variable limit 900
    variable seen_scenes {}
    variable logged {}
}

proc ::demo::rehearse::say {line} {
    variable chan
    puts $chan $line
    catch {flush $chan}
}

proc ::demo::rehearse::onlog {level text} {
    variable logged
    if {$level eq "error"} {
        lappend logged $text
        say "  ERROR  $text"
    } elseif {$level eq "warn"} {
        lappend logged "WARN: $text"
        say "  warn   $text"
    } elseif {$level eq "scene"} {
        say "-- $text"
    }
}

proc ::demo::rehearse::onchange {} {
    variable seen_scenes
    variable seen_beats
    set st [::demo::engine::status]
    set sid [dict get $st scene]
    if {$sid ne "" && [lsearch -exact $seen_scenes $sid] < 0} {
        lappend seen_scenes $sid
    }
}

proc ::demo::rehearse::finished {} {
    variable done
    set done 1
}

proc ::demo::rehearse::run {} {
    variable chan
    variable done
    variable t0
    variable limit
    variable logged
    variable seen_scenes
    global env

    if {[info exists env(DEMO_REHEARSE_OUT)] && $env(DEMO_REHEARSE_OUT) ne ""} {
        set chan [open $env(DEMO_REHEARSE_OUT) w]
    }

    set secs 0.35
    if {[info exists env(DEMO_BEAT_SECS)] && $env(DEMO_BEAT_SECS) ne ""} {
        set secs $env(DEMO_BEAT_SECS)
    }
    if {[info exists env(DEMO_TIMEOUT)] && $env(DEMO_TIMEOUT) ne ""} {
        set limit $env(DEMO_TIMEOUT)
    }

    # No narration during a rehearsal: the point is to exercise the actions, and
    # 25 minutes of speech would defeat the compression entirely.
    #
    # DEMO_REHEARSE_AUDIO=1 with DEMO_BEAT_SECS=0 runs a chapter at REAL speed
    # with real narration. That combination is the only way to check that the
    # measured durations actually keep the voice and the screen together, so it
    # is worth having even though it is slow.
    set with_audio [expr {[info exists env(DEMO_REHEARSE_AUDIO)] &&
                          $env(DEMO_REHEARSE_AUDIO) ne "" &&
                          $env(DEMO_REHEARSE_AUDIO) ne "0"}]
    ::demo::audio::mute [expr {!$with_audio}]
    if {$with_audio} {
        say "narration: ON (player: [::demo::audio::find_player])"
    }
    ::demo::engine::configure \
        -onlog      ::demo::rehearse::onlog \
        -onchange   ::demo::rehearse::onchange \
        -onfinished ::demo::rehearse::finished \
        -maxbeat    $secs \
        -gap        60 \
        -scenegap   120

    set ids [::demo::scene_ids]
    if {[info exists env(DEMO_REHEARSE_ONLY)] && $env(DEMO_REHEARSE_ONLY) ne ""} {
        set ids [list $env(DEMO_REHEARSE_ONLY)]
    }

    say "=== rehearsal: [llength $ids] scene(s), [expr {$secs > 0 ? \
             "${secs}s per beat" : {full narrated length}}] ==="
    say "planned: [format %.1f [::demo::engine::total_duration $ids]]s"
    set t0 [clock milliseconds]
    ::demo::engine::play $ids

    # Watchdog: a beat that wedges (a backend that never returns, a dialog that
    # slipped past the stand-ins) must fail the rehearsal, not hang it.
    after [expr {int($limit * 1000)}] {
        if {!$::demo::rehearse::done} {
            ::demo::rehearse::say "TIMEOUT after $::demo::rehearse::limit s"
            set ::demo::rehearse::done 2
        }
    }
    vwait ::demo::rehearse::done

    set elapsed [expr {([clock milliseconds] - $t0) / 1000.0}]
    say ""
    say "=== rehearsal report ==="
    say "scenes played: [llength $seen_scenes] of [llength $ids]  ([join $seen_scenes {, }])"
    say "wall clock:    [format %.1f $elapsed]s"

    set errs [::demo::engine::errors]
    if {[llength $errs]} {
        say "beat errors:   [llength $errs]"
        foreach e $errs { say "  FAIL  [lindex $e 0]: [lindex $e 1]" }
    } else {
        say "beat errors:   none"
    }

    set dlg [::demo::dialogs::history]
    say "dialogs seen:  [llength $dlg]"
    foreach d $dlg { say "  dialog  $d" }

    set rc 0
    if {[llength $errs]} { set rc 1 }
    if {$done == 2} { set rc 2 ; say "RESULT: TIMEOUT" }
    if {[llength $seen_scenes] < [llength $ids]} {
        set rc 3
        say "RESULT: not every scene was reached"
    }
    if {$rc == 0} { say "RESULT: PASS" } else { say "RESULT: FAIL ($rc)" }
    # Close, do not just flush: VMD's `exit` does not reliably flush a channel
    # opened from a played script, and an unflushed report is indistinguishable
    # from a rehearsal that never ran.
    if {$chan ne "stdout"} {
        catch {close $chan}
        set chan stdout
    }
    return $rc
}

# Boot the demo (without starting playback), then rehearse.
set _root ""
if {[info exists env(DEMO_ROOT)]} { set _root $env(DEMO_ROOT) }
if {$_root eq ""} { error "demo_rehearse: set DEMO_ROOT" }

source [file join $_root tcl demo_main.tcl]
::demo::start
set _rc [::demo::rehearse::run]
exit $_rc
