# demo_config.tcl - where the walkthrough finds everything.
#
# Every value can be overridden from the environment, so the demo can be pointed
# at a different trajectory or a different backend build without editing a file.

namespace eval ::demo::config {
    variable demo_root ""     ;# .../VMD-MDANCE/demo
    variable repo_root ""     ;# .../VMD-MDANCE
    variable plugin_dir ""    ;# .../VMD-MDANCE/mdance
    variable data_dir ""
    variable psf ""
    variable dcd ""
    variable out_dir ""
    variable cli ""
    variable lib ""
    variable load_first 0
    variable load_last -1
    variable load_step 1
}

# resolve - work out every path. $root is the demo directory.
proc ::demo::config::resolve {root} {
    variable demo_root
    variable repo_root
    variable plugin_dir
    variable data_dir
    variable psf
    variable dcd
    variable out_dir
    variable cli
    variable lib
    variable load_first
    variable load_last
    variable load_step

    set demo_root [file normalize $root]
    set repo_root [file dirname $demo_root]
    set plugin_dir [file join $repo_root mdance]
    set HOME [_home]

    # The trajectory. DEMO_DATA_DIR / DEMO_PSF / DEMO_DCD override; otherwise
    # look in the demo's own data directory first, then the places a checkout
    # of the test data usually sits. No absolute path is baked in -- the
    # walkthrough should be runnable from a fresh clone with one env var.
    set data_dir [_env DEMO_DATA_DIR [_first_dir [list \
        [file join $demo_root data] \
        [file join $repo_root data] \
        [file join $HOME work VMD_tests RMSX_test] \
        [file join $HOME VMD_tests RMSX_test]]]]
    set psf [_env DEMO_PSF [file join $data_dir solute.psf]]
    set dcd [_env DEMO_DCD [file join $data_dir solute.dcd]]
    set out_dir [_env DEMO_OUT [file join $demo_root out]]

    # Backend. MDANCE_CLI / MDANCE_LIB are the plugin's own env hooks, so
    # honouring them here means the demo and the plugin never disagree about
    # which backend is in play.
    set cli [_env MDANCE_CLI [_first_file [list \
        [file join $repo_root .. CPP-MDANCE build cli mdance-cli] \
        [file join $HOME github CPP-MDANCE build cli mdance-cli] \
        [file join $HOME CPP-MDANCE build cli mdance-cli] \
        [file join $HOME .vmd plugins noarch tcl mdance1.0 mdance-cli] \
        [file join $plugin_dir mdance-cli]]]]

    # The walkthrough runs in CLI mode by DEFAULT, and that is a deliberate
    # choice, not an oversight:
    #   - a CLI run parks in a live event loop, so the status bar streams
    #     progress and the Cancel button actually works -- which the walkthrough
    #     demonstrates. A library-mode run blocks VMD outright and cannot be
    #     cancelled at all.
    #   - library mode has a known abort (not an error -- an abort, which takes
    #     VMD with it) on degenerate HELM input. Not a risk worth taking live.
    # Set DEMO_LIBRARY=1 to show off in-process library mode instead.
    set lib [_env MDANCE_LIB ""]
    if {$lib eq "" && [_env DEMO_LIBRARY ""] ne ""} {
        set libname mdance_tcl[info sharedlibextension]
        set lib [_first_file [list \
            [file join $repo_root .. CPP-MDANCE build tcl $libname] \
            [file join $HOME github CPP-MDANCE build tcl $libname] \
            [file join $HOME CPP-MDANCE build tcl $libname] \
            [file join $plugin_dir $libname]]]
    }

    set load_first [_env DEMO_FIRST 0]
    set load_last  [_env DEMO_LAST -1]
    set load_step  [_env DEMO_STEP 1]

    return [summary]
}

proc ::demo::config::_env {name default} {
    global env
    if {[info exists env($name)] && $env($name) ne ""} { return $env($name) }
    return $default
}

# _home - the user's home directory, however this platform spells it.
proc ::demo::config::_home {} {
    global env
    foreach v {HOME USERPROFILE} {
        if {[info exists env($v)] && $env($v) ne ""} { return $env($v) }
    }
    return [file normalize ~]
}

# _first_file / _first_dir - first candidate that exists, else the first
# candidate unchanged.
#
# Returning the first candidate rather than "" on a total miss is deliberate:
# ::demo::config::check reports the path it could not read, and a blank path
# makes that message useless. This way it names the most likely location.
proc ::demo::config::_first_file {candidates} {
    foreach c $candidates {
        set c [file normalize $c]
        if {[file isfile $c]} { return $c }
    }
    return [file normalize [lindex $candidates 0]]
}

proc ::demo::config::_first_dir {candidates} {
    foreach c $candidates {
        set c [file normalize $c]
        if {[file isdirectory $c]} { return $c }
    }
    return [file normalize [lindex $candidates 0]]
}

# check - verify everything the demo needs exists. Returns a list of problems.
proc ::demo::config::check {} {
    variable psf
    variable dcd
    variable plugin_dir
    variable cli
    set problems {}
    # The trajectory defaults point at the machine the walkthrough was authored
    # on. Anyone else gets here on their first run, so the message has to name
    # the way out rather than just the path that failed.
    foreach {what path var} [list "topology" $psf DEMO_PSF "trajectory" $dcd DEMO_DCD] {
        if {![file readable $path]} {
            lappend problems "$what not readable: $path\
                \n    Point the walkthrough at your own trajectory with $var=/path/to/file\
                \n    (or set DEMO_DATA_DIR to a directory holding solute.psf and solute.dcd)."
        }
    }
    if {![file readable [file join $plugin_dir mdance.tcl]]} {
        lappend problems "plugin not found at $plugin_dir"
    }
    if {$cli ne "" && ![file executable $cli]} {
        lappend problems "mdance-cli not executable: $cli\
            \n    Build it from CPP-MDANCE, then set MDANCE_CLI=/path/to/mdance-cli."
    }
    return $problems
}

proc ::demo::config::summary {} {
    variable psf
    variable dcd
    variable cli
    variable lib
    variable out_dir
    return [list psf $psf dcd $dcd cli $cli lib $lib out $out_dir]
}
