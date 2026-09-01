# demo_main.tcl - entry point for the MDANCE walkthrough.
#
#   vmd -e demo/tcl/demo_main.tcl
#
# or, from a VMD console:  source /path/to/demo/tcl/demo_main.tcl
#
# Environment:
#   DEMO_ROOT     the demo directory (required when `info script` is unset,
#                 which it is under `vmd -e`)
#   DEMO_PSF/DCD  override the trajectory
#   DEMO_STEP     load every Nth frame (a quick rehearsal wants 5 or 10)
#   DEMO_CHECK=1  validate scenes, paths and widget references, then exit
#                 without playing anything. This is how the walkthrough is
#                 smoke-tested in headless VMD.
#   MDANCE_CLI    path to mdance-cli (defaults to the CPP-MDANCE build tree)

namespace eval ::demo {
    variable root ""
    variable ready 0
}

# --- locate ourselves ------------------------------------------------------
#
# `info script` is UNSET under `vmd -e` (a trap this repo's test suite already
# documents), so an env var is the only reliable answer there.
proc ::demo::_find_root {} {
    global env
    if {[info exists env(DEMO_ROOT)] && $env(DEMO_ROOT) ne ""} {
        return [file normalize $env(DEMO_ROOT)]
    }
    set s ""
    catch {set s [info script]}
    if {$s ne ""} {
        # .../demo/tcl/demo_main.tcl -> .../demo
        return [file dirname [file dirname [file normalize $s]]]
    }
    error "demo: cannot locate the demo directory -- set DEMO_ROOT"
}

# --- bootstrap -------------------------------------------------------------

proc ::demo::bootstrap {} {
    variable root
    variable ready
    global env

    set root [_find_root]
    set tcldir [file join $root tcl]

    source [file join $tcldir demo_config.tcl]
    ::demo::config::resolve $root

    set problems [::demo::config::check]
    if {[llength $problems]} {
        foreach p $problems { puts stderr "demo: $p" }
        error "demo: [llength $problems] configuration problem(s) -- see above"
    }

    # Tell the plugin which backend to use BEFORE sourcing it, so its own
    # discovery finds what we intend rather than something else on the machine.
    set env(MDANCE_CLI) [::demo::config::_env MDANCE_CLI \
        [set ::demo::config::cli]]
    if {[set ::demo::config::lib] ne ""} {
        set env(MDANCE_LIB) [set ::demo::config::lib]
    }

    # The plugin first: it does `package require Tk`, which reinstalls the real
    # tk_messageBox. Installing our non-blocking dialogs before this point would
    # be silently undone, and the first dialog would freeze the walkthrough.
    source [file join [set ::demo::config::plugin_dir] mdance.tcl]

    foreach f {demo_dsl.tcl demo_audio.tcl demo_caption.tcl demo_dialogs.tcl
               demo_vmd.tcl demo_engine.tcl demo_actions.tcl demo_control.tcl} {
        source [file join $tcldir $f]
    }

    set ::demo::out_dir [set ::demo::config::out_dir]

    # Narration manifest (generated; absent before the first build).
    set manifest [file join $root narration manifest.tcl]
    if {[file readable $manifest]} {
        source $manifest
    } else {
        namespace eval ::demo::narration {
            variable manifest
            array set manifest {}
        }
        puts "demo: no narration manifest yet -- run narration/build_narration.py\
              (the walkthrough will still run, paced from reading-rate estimates)"
    }

    ::demo::load_scenes [file join $tcldir scenes]
    if {[llength [::demo::scene_ids]] == 0} {
        error "demo: no scenes found in [file join $tcldir scenes]"
    }

    ::demo::engine::configure \
        -audiodir [file join $root narration] \
        -onchange ::demo::control::refresh \
        -onlog    ::demo::control::log

    # Before a single timer is armed: without this, an error inside any `after`
    # script is completely silent under VMD and the walkthrough just stops.
    ::demo::engine::install_bgerror

    set ready 1
    return [::demo::scene_ids]
}

# --- start -----------------------------------------------------------------

proc ::demo::start {} {
    variable root

    # The plugin's own window, exactly as a user would open it.
    ::mdance::init
    ::mdance::gui::create_window
    ::mdance::gui::detect_backend .mdance.nb.setup

    ::demo::caption::create
    ::demo::caption::hide
    ::demo::control::create

    # Load and dress the molecule before anything is on screen, so the first
    # chapter opens on a finished picture rather than on a loading bar.
    ::demo::vmd::load_system [set ::demo::config::psf] [set ::demo::config::dcd] \
        [set ::demo::config::load_first] [set ::demo::config::load_last] \
        [set ::demo::config::load_step]
    ::demo::vmd::style_default
    ::demo::vmd::layout

    # Point the plugin at the molecule we just loaded.
    set ::mdance::gui::mol_selection [::demo::vmd::molid]

    ::demo::control::log ok \
        "Ready: [molinfo [::demo::vmd::molid] get numframes] frames, [llength [::demo::scene_ids]] chapters."
    ::demo::control::log info \
        "Backend: [expr {$::mdance::use_library ? {native library} : {CLI}}]  |  [set ::demo::config::cli]"
    return
}

# --- headless self-check ---------------------------------------------------
#
# Validates everything a live run depends on WITHOUT playing anything: that
# every scene declares beats, that every spotlight path and every widget a -do
# body clicks actually exists in a freshly built GUI, and that every beat either
# has audio or a duration estimate. Exits non-zero on failure so it can be
# wired into a test run.
proc ::demo::selfcheck {} {
    global env
    set problems {}
    set warnings {}
    set deferred {}

    # Once any Tk widget exists, VMD redirects stdout into its own console and
    # `puts` vanishes -- the same trap the plugin's test harness documents. So
    # the report goes to a real file channel whenever one is named.
    variable check_chan stdout
    set opened 0
    if {[info exists env(DEMO_CHECK_OUT)] && $env(DEMO_CHECK_OUT) ne ""} {
        set check_chan [open $env(DEMO_CHECK_OUT) w]
        set opened 1
    }

    ::mdance::init
    ::mdance::gui::create_window
    ::demo::caption::create
    ::demo::caption::hide

    ::demo::vmd::load_system [set ::demo::config::psf] [set ::demo::config::dcd] \
        [set ::demo::config::load_first] [set ::demo::config::load_last] \
        [set ::demo::config::load_step]
    ::demo::vmd::style_default
    set ::mdance::gui::mol_selection [::demo::vmd::molid]

    # Open the Frame Tools dialog so its widgets become checkable. It is a
    # non-modal child of .mdance built on demand, and the frametools chapter
    # spotlights half a dozen controls inside it -- without this they would all
    # be written off as "created at run time" and a typo would reach the stage.
    catch {::mdance::gui::frame_tools_dialog}

    set nbeats 0
    set voiced 0
    foreach sid [::demo::scene_ids] {
        set sc [::demo::scene_get $sid]
        set beats [dict get $sc beats]
        if {[llength $beats] == 0} {
            lappend problems "scene $sid has no beats"
        }
        foreach b $beats {
            incr nbeats
            set fq [dict get $b id]
            if {[::demo::engine::beat_audio $fq] ne ""} { incr voiced }

            # Every spotlight target must be a real widget path. A typo here is
            # invisible at run time (spotlight just skips it) but means the
            # narrator points at nothing.
            foreach sp [dict get $b spotlight] {
                if {![string match ".*" $sp]} {
                    lappend problems "$fq: spotlight \"$sp\" is not a widget path"
                } elseif {[winfo exists $sp]} {
                    # fine
                } elseif {[_checkable_widget $sp]} {
                    lappend problems "$fq: spotlight widget $sp does not exist"
                } else {
                    # A plot toplevel that the beat itself opens. Not verifiable
                    # here; ::demo::caption::spotlight warns about it live.
                    lappend deferred "$fq: spotlight $sp (created at run time)"
                }
            }
            if {[dict get $b tab] ne "" &&
                ![winfo exists .mdance.nb.[dict get $b tab]]} {
                lappend problems "$fq: no such tab \"[dict get $b tab]\""
            }
            # The -do body must at least parse.
            if {![info complete [dict get $b do]]} {
                lappend problems "$fq: -do body is not complete Tcl"
            }
            # Any widget path mentioned literally in the body should exist --
            # this is what catches a renamed button before a live run.
            #
            # Only the PERSISTENT GUI can be checked this way. The plot
            # toplevels (.mdance_pop, .mdance_elbow_cfg, ...) and the Frame
            # Tools dialog (.mdance.ftools) are created on demand by the very
            # beats that reference them, so they legitimately do not exist yet.
            foreach path [regexp -all -inline {\.mdance[a-zA-Z0-9_.]*} [dict get $b do]] {
                set path [string trimright $path .]
                if {![_checkable_widget $path]} {
                    lappend deferred "$fq: $path (created at run time)"
                    continue
                }
                if {![winfo exists $path]} {
                    lappend problems "$fq: -do references missing widget $path"
                }
            }
            if {[string length [dict get $b caption]] > 150} {
                lappend warnings "$fq: caption is [string length [dict get $b caption]] chars (long for one line)"
            }
        }
    }

    _ck ""
    _ck "=== demo selfcheck ==="
    _ck "scenes:   [llength [::demo::scene_ids]]"
    _ck "beats:    $nbeats  ($voiced voiced)"
    _ck "runtime:  [format %.1f [expr {[::demo::engine::total_duration] / 60.0}]] min"
    foreach sid [::demo::scene_ids] {
        _ck [format "  %-12s %2d beats  %5.1f min  %s" $sid \
            [llength [::demo::scene_beats $sid]] \
            [expr {[::demo::engine::scene_duration $sid] / 60.0}] \
            [dict get [::demo::scene_get $sid] title]]
    }
    if {[llength $deferred]} {
        _ck "deferred: [llength $deferred] run-time widget reference(s) not checkable here"
        foreach d $deferred { _ck "  ....  $d" }
    }
    foreach wmsg $warnings { _ck "WARN  $wmsg" }
    set rc 0
    if {[llength $problems]} {
        foreach p $problems { _ck "FAIL  $p" }
        _ck "=== [llength $problems] problem(s) ==="
        set rc 1
    } else {
        _ck "=== all checks passed ==="
    }
    if {$opened} { catch {close $check_chan} }
    set check_chan stdout
    return $rc
}

# _checkable_widget - can this path be verified against a freshly built GUI?
#
# The plugin's persistent window is .mdance (notebook + status bar). Everything
# else the walkthrough touches -- every plot toplevel, the elbow configuration
# window, the Frame Tools dialog -- is created on demand by the beat that uses
# it, so its absence here means nothing.
proc ::demo::_checkable_widget {path} {
    foreach prefix {.mdance.nb .mdance.status .mdance.ftools} {
        if {$path eq $prefix || [string match "$prefix.*" $path]} { return 1 }
    }
    return 0
}

proc ::demo::_ck {line} {
    variable check_chan
    puts $check_chan $line
    catch {flush $check_chan}
}

# --- run -------------------------------------------------------------------

if {[catch {::demo::bootstrap} _err]} {
    puts stderr "demo: bootstrap failed: $_err"
    puts stderr $::errorInfo
    return
}

proc ::demo::_envflag {name} {
    global env
    return [expr {[info exists env($name)] && $env($name) ne "" && $env($name) ne "0"}]
}

if {[::demo::_envflag DEMO_CHECK]} {
    set _rc [::demo::selfcheck]
    if {[::demo::_envflag DEMO_CHECK_EXIT]} { exit $_rc }
} elseif {[::demo::_envflag DEMO_NOSTART]} {
    # The rehearsal driver sources this file for its bootstrap and starts the
    # session itself.
} else {
    ::demo::start
}
