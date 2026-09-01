# demo_engine.tcl - the sequencer that keeps the voice and the screen together.
#
# A beat is played like this:
#
#   t = 0            caption appears, spotlight lands, narration starts
#   t = -at          the beat's -do body runs (default 0.4s, so the eye follows
#                    the ear rather than racing it)
#   t = dur + hold   the beat ends and the next one starts
#
# `dur` is the MEASURED length of the synthesized narration, read from
# narration/manifest.tcl. Nothing here estimates timing from word counts unless
# there is no audio at all.
#
# RE-ENTRANCY IS THE HARD PART. The plugin's CLI path parks in
# `vwait ::mdance::async_done` while the backend runs, which means this engine's
# own `after` timers keep firing *inside* that nested event loop. Left
# unguarded, the end-of-beat timer would advance to the next beat while the
# previous run was still going, issue a second run, and hit the plugin's
# "already in progress" interlock -- which is a modal dialog. Every scheduling
# callback below therefore defers while an action is in flight or the plugin is
# busy. See _busy and in_action.

namespace eval ::demo::engine {
    variable state      idle      ;# idle | playing | paused
    variable playlist   {}        ;# scene ids queued to play
    variable si         0         ;# index into playlist
    variable bi         0         ;# index into the current scene's beats
    variable beats      {}        ;# cached beats of the current scene
    variable timers     {}        ;# pending after ids owned by the engine
    variable beat_start 0         ;# clock milliseconds at beat start
    variable beat_len   0         ;# planned beat length, ms
    variable fired      0         ;# has this beat's -do already run?
    variable in_action  0         ;# re-entrancy guard around -do
    variable gap        450       ;# ms of silence between beats
    variable scene_gap  1100      ;# ms between chapters
    variable errors     {}        ;# {beat message} for anything a -do threw
    variable on_change  ""        ;# callback: refresh the control panel
    variable on_log     ""        ;# callback: {level text}
    variable audio_dir  ""        ;# absolute path to narration/
    variable finished_cb ""       ;# called once the playlist runs out
    # Rehearsal cap: when > 0, every beat is shortened to this many seconds.
    # A full walkthrough runs ~25 minutes; the automated check has to exercise
    # every -do body, and it must not take 25 minutes to do it.
    variable max_beat 0
}

proc ::demo::engine::configure {args} {
    foreach {k v} $args {
        switch -exact -- $k {
            -onchange   { variable on_change ; set on_change $v }
            -onlog      { variable on_log ; set on_log $v }
            -audiodir   { variable audio_dir ; set audio_dir $v }
            -gap        { variable gap ; set gap $v }
            -scenegap   { variable scene_gap ; set scene_gap $v }
            -onfinished { variable finished_cb ; set finished_cb $v }
            -maxbeat    { variable max_beat ; set max_beat $v }
            default     { error "demo::engine::configure: unknown option $k" }
        }
    }
}

proc ::demo::engine::_log {level text} {
    variable on_log
    if {$on_log ne ""} { catch {uplevel #0 [list {*}$on_log $level $text]} }
}

# install_bgerror - route background errors into the demo log.
#
# An error raised inside an `after` script is reported through `bgerror`, and
# VMD's default handling of it produces NOTHING: not in the VMD log, not on
# stdout (which the Tk console has swallowed by then), not on screen. Since this
# entire engine runs off `after` timers, a single typo in a scene would
# otherwise stop the walkthrough dead with a live GUI and no diagnosis at all.
#
# The plugin's own resize-debounce redraw has the same hole (it prints to the
# swallowed stdout), so this catches those too.
proc ::demo::engine::install_bgerror {} {
    if {[info procs ::demo::engine::_saved_bgerror] eq "" &&
        [info commands ::bgerror] ne ""} {
        catch {rename ::bgerror ::demo::engine::_saved_bgerror}
    }
    proc ::bgerror {msg} {
        ::demo::engine::_log error "background error: $msg"
        # errorInfo is the only place the stack survives; keep the first frames.
        set info [string range $::errorInfo 0 600]
        ::demo::engine::_log error $info
        if {[info procs ::demo::engine::_saved_bgerror] ne ""} {
            catch {::demo::engine::_saved_bgerror $msg}
        }
        return
    }
    return 1
}

proc ::demo::engine::_changed {} {
    variable on_change
    if {$on_change ne ""} { catch {uplevel #0 $on_change} }
}

# _busy - is the plugin itself mid-operation? While this is true the engine must
# not advance, or it will collide with the plugin's own interlock.
proc ::demo::engine::_busy {} {
    if {[info exists ::mdance::running] && $::mdance::running} { return 1 }
    if {[info exists ::mdance::gui::sweep_running] && $::mdance::gui::sweep_running} { return 1 }
    if {[info exists ::mdance::async_fh] && $::mdance::async_fh ne ""} { return 1 }
    return 0
}

proc ::demo::engine::_arm {ms script} {
    variable timers
    set id [after $ms $script]
    lappend timers $id
    return $id
}

proc ::demo::engine::_disarm {} {
    variable timers
    foreach t $timers { catch {after cancel $t} }
    set timers {}
}

# --- narration lookup ------------------------------------------------------

# beat_audio - absolute path to a beat's WAV, or "" if it has none.
proc ::demo::engine::beat_audio {fqid} {
    variable audio_dir
    if {![info exists ::demo::narration::manifest($fqid)]} { return "" }
    set rel [dict get $::demo::narration::manifest($fqid) file]
    if {$rel eq ""} { return "" }
    set p [file join $audio_dir $rel]
    if {![file readable $p]} { return "" }
    return $p
}

# beat_duration - seconds of narration for a beat. Falls back to a reading-rate
# estimate so a demo still paces sensibly before the audio is built.
proc ::demo::engine::beat_duration {b} {
    variable max_beat
    set fqid [dict get $b id]
    if {[info exists ::demo::narration::manifest($fqid)]} {
        set d [dict get $::demo::narration::manifest($fqid) duration]
    } else {
        set words [llength [split [dict get $b say] " "]]
        set d [expr {max(1.8, $words / 2.6)}]
    }
    if {$max_beat > 0 && $d > $max_beat} { set d $max_beat }
    return $d
}

# _cue_ms - resolve a beat's -at into milliseconds. "0.6f" means 60% of the way
# through the narration, which is how a scene says "explain first, then act"
# without guessing how long the sentence will turn out to be.
proc ::demo::engine::_cue_ms {at dur} {
    if {[string match "*f" $at]} {
        set frac [string range $at 0 end-1]
        return [expr {int($frac * $dur * 1000)}]
    }
    return [expr {int($at * 1000)}]
}

# scene_duration - total seconds a chapter will take, narration + holds + gaps.
proc ::demo::engine::scene_duration {sid} {
    variable gap
    set t 0.0
    foreach b [::demo::scene_beats $sid] {
        set t [expr {$t + [beat_duration $b] + [dict get $b hold] + $gap / 1000.0}]
    }
    return $t
}

proc ::demo::engine::total_duration {{sids ""}} {
    if {$sids eq ""} { set sids [::demo::scene_ids] }
    set t 0.0
    foreach s $sids { set t [expr {$t + [scene_duration $s]}] }
    return $t
}

# --- transport -------------------------------------------------------------

# play - start (or restart) the walkthrough over the given scene ids.
proc ::demo::engine::play {{sids ""}} {
    variable state
    variable playlist
    variable si
    variable bi

    stop
    if {$sids eq ""} { set sids [::demo::scene_ids] }
    if {[llength $sids] == 0} { error "demo: nothing to play" }
    set playlist $sids
    set si 0
    set bi 0
    set state playing
    ::demo::dialogs::install
    _changed
    _enter_scene
    return
}

proc ::demo::engine::pause {} {
    variable state
    if {$state ne "playing"} { return 0 }
    _disarm
    ::demo::audio::stop
    set state paused
    _log info "Paused."
    _changed
    return 1
}

# resume - continue from the START of the beat that was interrupted. Restarting
# the beat rather than trying to resume mid-sentence keeps the narration and the
# caption honest; the beats are short enough that it costs a few seconds.
proc ::demo::engine::resume {} {
    variable state
    if {$state ne "paused"} { return 0 }
    set state playing
    _log info "Resumed."
    _changed
    _play_beat
    return 1
}

proc ::demo::engine::toggle_pause {} {
    variable state
    if {$state eq "playing"} { return [pause] }
    if {$state eq "paused"} { return [resume] }
    return 0
}

proc ::demo::engine::stop {} {
    variable state
    variable playlist
    _disarm
    ::demo::audio::stop
    ::demo::caption::clear_spotlight
    ::demo::caption::hide_card
    ::demo::caption::hide
    set state idle
    set playlist {}
    _changed
    return
}

# next_beat / prev_beat - manual stepping. Both work while paused, which is how
# you drive the walkthrough by hand during a talk.
proc ::demo::engine::next_beat {} {
    variable state
    variable bi
    variable beats
    if {$state eq "idle"} { return 0 }
    _disarm
    ::demo::audio::stop
    incr bi
    if {$bi >= [llength $beats]} {
        _leave_scene
        return 1
    }
    if {$state eq "playing"} { _play_beat } else { _show_beat_only }
    return 1
}

proc ::demo::engine::prev_beat {} {
    variable state
    variable bi
    if {$state eq "idle"} { return 0 }
    _disarm
    ::demo::audio::stop
    if {$bi > 0} { incr bi -1 }
    if {$state eq "playing"} { _play_beat } else { _show_beat_only }
    return 1
}

proc ::demo::engine::next_scene {} {
    variable state
    if {$state eq "idle"} { return 0 }
    _disarm
    ::demo::audio::stop
    _leave_scene
    return 1
}

# --- scene lifecycle -------------------------------------------------------

proc ::demo::engine::_enter_scene {} {
    variable playlist
    variable si
    variable bi
    variable beats
    variable state
    variable scene_gap
    variable finished_cb

    if {$state eq "idle"} { return }
    if {$si >= [llength $playlist]} {
        _log ok "Walkthrough complete."
        ::demo::caption::clear_spotlight
        ::demo::caption::hide
        set state idle
        _changed
        if {$finished_cb ne ""} { catch {uplevel #0 $finished_cb} }
        return
    }

    set sid [lindex $playlist $si]
    set sc [::demo::scene_get $sid]
    set beats [dict get $sc beats]
    set bi 0

    set num [format "CHAPTER %d OF %d" [expr {$si + 1}] [llength $playlist]]
    ::demo::caption::hide
    ::demo::caption::title_card $num [dict get $sc title] [dict get $sc subtitle] \
        [expr {$scene_gap / 1000.0 + 1.4}]
    _log scene "[dict get $sc title] -- [llength $beats] beats, [format %.0f [scene_duration $sid]]s"
    _changed

    # Run the scene's setup with the title card up, so any reloading or
    # re-rendering happens behind the card rather than in front of the viewer.
    set rc [catch {_run_body [dict get $sc setup] "$sid setup"} err]
    if {$rc} { _log error "$sid setup: $err" }

    _arm [expr {$scene_gap + 900}] ::demo::engine::_play_beat
}

proc ::demo::engine::_leave_scene {} {
    variable playlist
    variable si
    variable state
    variable scene_gap

    if {$si < [llength $playlist]} {
        set sid [lindex $playlist $si]
        set rc [catch {_run_body [dict get [::demo::scene_get $sid] teardown] "$sid teardown"} err]
        if {$rc} { _log error "$sid teardown: $err" }
    }
    ::demo::caption::clear_spotlight
    incr si
    if {$state eq "playing"} {
        _arm $scene_gap ::demo::engine::_enter_scene
    } else {
        _enter_scene
    }
}

# --- beat lifecycle --------------------------------------------------------

# _show_beat_only - update the caption/spotlight without playing or acting.
# Used when stepping while paused.
proc ::demo::engine::_show_beat_only {} {
    variable beats
    variable bi
    variable playlist
    variable si
    if {$bi >= [llength $beats]} { return }
    set b [lindex $beats $bi]
    set sc [::demo::scene_get [lindex $playlist $si]]
    ::demo::caption::set_text [dict get $sc title] \
        "beat [expr {$bi + 1}] / [llength $beats]" [dict get $b caption]
    _select_tab [dict get $b tab]
    ::demo::caption::spotlight [dict get $b spotlight]
    _changed
}

proc ::demo::engine::_play_beat {} {
    variable beats
    variable bi
    variable si
    variable playlist
    variable state
    variable beat_start
    variable beat_len
    variable fired
    variable gap

    if {$state ne "playing"} { return }
    if {$bi >= [llength $beats]} { _leave_scene ; return }

    # Never start a beat on top of an in-flight backend run.
    if {[_busy]} { _arm 200 ::demo::engine::_play_beat ; return }

    set b [lindex $beats $bi]
    set sc [::demo::scene_get [lindex $playlist $si]]

    ::demo::caption::set_text [dict get $sc title] \
        "beat [expr {$bi + 1}] / [llength $beats]" [dict get $b caption]
    _select_tab [dict get $b tab]
    ::demo::caption::spotlight [dict get $b spotlight]

    set dur [beat_duration $b]
    set wav [beat_audio [dict get $b id]]
    ::demo::audio::play $wav

    set fired 0
    set beat_start [clock milliseconds]
    set beat_len [expr {int(($dur + [dict get $b hold]) * 1000)}]

    set at_ms [_cue_ms [dict get $b at] $dur]
    if {$at_ms > $beat_len} { set at_ms 0 }
    _arm $at_ms ::demo::engine::_fire
    _arm 100 ::demo::engine::_tick
    _arm [expr {$beat_len + $gap}] ::demo::engine::_end_beat
    _changed
}

# _fire - run the beat's action. Guarded so a broken scene logs an error and the
# walkthrough carries on instead of dying on stage.
proc ::demo::engine::_fire {} {
    variable beats
    variable bi
    variable fired
    variable in_action
    variable state

    if {$state ne "playing" || $fired} { return }
    if {$bi >= [llength $beats]} { return }
    if {$in_action} { _arm 120 ::demo::engine::_fire ; return }

    set fired 1
    set b [lindex $beats $bi]
    set body [dict get $b do]
    if {[string trim $body] eq ""} { return }

    set in_action 1
    set rc [catch {_run_body $body [dict get $b id]} err]
    set in_action 0
    if {$rc} {
        variable errors
        lappend errors [list [dict get $b id] $err]
        _log error "[dict get $b id]: $err"
    }
}

# _run_body - evaluate scene Tcl at global scope.
proc ::demo::engine::_run_body {body what} {
    if {[string trim $body] eq ""} { return }
    return [uplevel #0 $body]
}

# _tick - drive the caption progress bar.
proc ::demo::engine::_tick {} {
    variable state
    variable beat_start
    variable beat_len
    if {$state ne "playing"} { return }
    if {$beat_len <= 0} { return }
    set el [expr {[clock milliseconds] - $beat_start}]
    ::demo::caption::progress [expr {double($el) / $beat_len}]
    if {$el < $beat_len} { _arm 100 ::demo::engine::_tick }
}

proc ::demo::engine::_end_beat {} {
    variable state
    variable bi
    variable beats
    variable in_action
    variable fired

    if {$state ne "playing"} { return }

    # Three reasons to wait rather than advance: the action is still running,
    # the plugin is still running, or the narration is still speaking (which
    # happens when a blocking action pushed the audio past its slot).
    if {$in_action || [_busy] || [::demo::audio::playing]} {
        _arm 200 ::demo::engine::_end_beat
        return
    }
    # An action that never got its chance (because the beat was busy the whole
    # time) still deserves to run before we move on.
    if {!$fired} { _fire ; _arm 150 ::demo::engine::_end_beat ; return }

    ::demo::caption::progress 1.0
    incr bi
    if {$bi >= [llength $beats]} {
        _leave_scene
    } else {
        _play_beat
    }
}

# _select_tab - bring one of the plugin's notebook tabs to the front.
proc ::demo::engine::_select_tab {tab} {
    if {$tab eq ""} { return }
    if {![winfo exists .mdance.nb]} { return }
    set path .mdance.nb.$tab
    if {![winfo exists $path]} { return }
    catch {.mdance.nb select $path}
    update idletasks
}

# --- status ----------------------------------------------------------------

proc ::demo::engine::status {} {
    variable state
    variable playlist
    variable si
    variable bi
    variable beats
    set sid [expr {$si < [llength $playlist] ? [lindex $playlist $si] : ""}]
    return [dict create \
        state    $state \
        scene    $sid \
        scene_i  $si \
        scene_n  [llength $playlist] \
        beat_i   $bi \
        beat_n   [llength $beats]]
}

proc ::demo::engine::errors {} {
    variable errors
    return $errors
}

proc ::demo::engine::clear_errors {} {
    variable errors
    set errors {}
}
