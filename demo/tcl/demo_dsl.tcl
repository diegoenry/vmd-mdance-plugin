# demo_dsl.tcl - declarative scene / beat description language for the
# MDANCE plugin walkthrough.
#
# A "scene" is one chapter of the demo (one clustering method, say). A "beat" is
# one narrated step inside it: a spoken sentence, an on-screen caption, and the
# Tcl that actually drives the plugin while that sentence plays.
#
# THE POINT OF THE DSL: the spoken text and the action it describes live in the
# SAME declaration, so they cannot drift apart. The narration builder
# (narration/export_beats.tcl -> narration/build_narration.py) sources these very
# files in a plain tclsh with the -do bodies never evaluated, extracts the -say
# text, and synthesizes one audio file per beat. At run time the engine replays
# those files and fires each -do body at its cue.
#
# Nothing in this file may require Tk or VMD: it is sourced both inside VMD and
# inside a bare tclsh.

namespace eval ::demo {
    # Ordered list of scene ids.
    variable scene_order {}
    # scene id -> dict {title subtitle setup teardown beats}
    variable scenes
    array set scenes {}
    # The scene currently being declared.
    variable _cur ""
}

# scene - open a scene for declaration. Every beat/setup/teardown until the next
# `scene` call belongs to it.
proc ::demo::scene {id title {subtitle ""}} {
    variable scene_order
    variable scenes
    variable _cur

    if {[info exists scenes($id)]} {
        error "demo: scene \"$id\" declared twice"
    }
    if {![regexp {^[a-z][a-z0-9_]*$} $id]} {
        # Beat ids become audio FILENAMES and Tcl array keys, so keep them tame.
        error "demo: scene id \"$id\" must be lowercase alphanumeric/underscore"
    }
    lappend scene_order $id
    set scenes($id) [dict create \
        id       $id \
        title    $title \
        subtitle $subtitle \
        setup    {} \
        teardown {} \
        beats    {}]
    set _cur $id
    return $id
}

# setup / teardown - Tcl run once when a scene is entered / left. Setup is where
# a scene puts the molecule and the GUI into the state its first beat assumes,
# so that any scene can be played on its own.
proc ::demo::setup {body} {
    variable scenes
    variable _cur
    if {$_cur eq ""} { error "demo: setup outside a scene" }
    dict set scenes($_cur) setup $body
}

proc ::demo::teardown {body} {
    variable scenes
    variable _cur
    if {$_cur eq ""} { error "demo: teardown outside a scene" }
    dict set scenes($_cur) teardown $body
}

# beat - declare one narrated step.
#
#   -say        the spoken narration. This is the ONLY text that is synthesized.
#   -caption    the on-screen caption. Defaults to -say when omitted, but a
#               short caption reads far better than a full sentence.
#   -do         Tcl to run while the narration plays.
#   -at         when -do fires, measured from the start of the narration.
#               A plain number is seconds (default 0.4 -- just after the voice
#               starts, so the eye follows the ear). A number suffixed with "f"
#               is a FRACTION of the narration's length, e.g. -at 0.6f fires
#               60% of the way through. Use the fractional form whenever the
#               sentence explains something before the action illustrates it:
#               it stays correct when the wording, the voice or the speaking
#               rate changes, which a hard-coded second count does not.
#   -hold       extra seconds to linger after the narration ends (default 0.6).
#               Use it when the beat leaves something on screen worth reading.
#   -tab        notebook tab to select before -do runs (setup|kmeans|divine|
#               helm|equal|sweep|results|prime). Purely a convenience.
#   -spotlight  Tk widget path (or list of paths) to highlight for this beat.
#   -zoom       optional {x y w h}-free hint: currently unused placeholder for
#               future screen-region emphasis; accepted so scenes can carry it.
#   -slow       if 1, the engine will not let "skip long work" mode drop -do.
#
proc ::demo::beat {id args} {
    variable scenes
    variable _cur
    if {$_cur eq ""} { error "demo: beat \"$id\" outside a scene" }
    if {![regexp {^[a-z0-9][a-z0-9_]*$} $id]} {
        error "demo: beat id \"$id\" must be lowercase alphanumeric/underscore"
    }

    set b [dict create \
        id        "$_cur.$id" \
        local     $id \
        scene     $_cur \
        say       "" \
        caption   "" \
        do        {} \
        at        0.4 \
        hold      0.6 \
        tab       "" \
        spotlight {} \
        slow      0]

    if {[llength $args] % 2} {
        error "demo: beat $_cur.$id has an odd number of options"
    }
    foreach {opt val} $args {
        switch -exact -- $opt {
            -say       { dict set b say       $val }
            -caption   { dict set b caption   $val }
            -do        { dict set b do        $val }
            -at        { dict set b at        $val }
            -hold      { dict set b hold      $val }
            -tab       { dict set b tab       $val }
            -spotlight { dict set b spotlight $val }
            -slow      { dict set b slow      $val }
            default    { error "demo: beat $_cur.$id: unknown option $opt" }
        }
    }

    if {[dict get $b say] eq ""} {
        error "demo: beat $_cur.$id has no -say text"
    }
    if {[dict get $b caption] eq ""} {
        dict set b caption [dict get $b say]
    }
    # -at accepts "2.5" (seconds) or "0.6f" (fraction of the narration).
    set at [dict get $b at]
    if {[string match "*f" $at]} {
        set frac [string range $at 0 end-1]
        if {![string is double -strict $frac] || $frac < 0 || $frac > 1} {
            error "demo: beat $_cur.$id: -at \"$at\" must be a fraction in 0f..1f"
        }
    } elseif {![string is double -strict $at] || $at < 0} {
        error "demo: beat $_cur.$id: -at must be seconds, or a fraction like 0.6f"
    }
    set hold [dict get $b hold]
    if {![string is double -strict $hold] || $hold < 0} {
        error "demo: beat $_cur.$id: -hold must be a non-negative number"
    }

    dict lappend scenes($_cur) beats $b
    return [dict get $b id]
}

# --- accessors -------------------------------------------------------------

proc ::demo::scene_ids {} {
    variable scene_order
    return $scene_order
}

proc ::demo::scene_get {id} {
    variable scenes
    if {![info exists scenes($id)]} { error "demo: no such scene \"$id\"" }
    return $scenes($id)
}

proc ::demo::scene_beats {id} {
    return [dict get [scene_get $id] beats]
}

# beat_get - find a beat by its fully-qualified "scene.beat" id.
proc ::demo::beat_get {fqid} {
    variable scene_order
    foreach s $scene_order {
        foreach b [scene_beats $s] {
            if {[dict get $b id] eq $fqid} { return $b }
        }
    }
    error "demo: no such beat \"$fqid\""
}

# all_beats - every beat of every scene, in order, each with its scene id.
proc ::demo::all_beats {} {
    variable scene_order
    set out {}
    foreach s $scene_order {
        foreach b [scene_beats $s] { lappend out $b }
    }
    return $out
}

# reset - drop every declaration (used by the exporter between passes).
proc ::demo::reset {} {
    variable scene_order
    variable scenes
    variable _cur
    set scene_order {}
    array unset scenes
    array set scenes {}
    set _cur ""
}

# load_scenes - source every scene file in a directory, in sorted order. Scene
# files are named NN_name.tcl so the numeric prefix fixes chapter order.
proc ::demo::load_scenes {dir} {
    foreach f [lsort [glob -nocomplain -directory $dir *.tcl]] {
        uplevel #0 [list source $f]
    }
    return [scene_ids]
}
