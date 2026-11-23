# The quick-start guide's figures. Runs the guide's own script
# (quickstart.tcl) in VMD with its window, then writes, in figures/:
#   gallery_<plot>.pdf   the 13 plots of the clustering, for the guide's
#                        gallery: ten half a page wide (120 x 90 mm, 10-point
#                        text, printed at two thirds), the Timeline, the
#                        Sweep and the Elbow the page's width (178 mm,
#                        9-point text)
#   main_3d.png          the representatives in VMD's 3D window
#   window.png           the VMDance window (macOS only: screencapture), and
#   window_parts.txt     where its parts are, for annotate.py
#   cd quickstart-guide
#   TAU_DATA=<BitQT>/examples vmd -dispdev win -e figures.tcl < <(sleep 900)
# (make figures does it. VMD's standard input stays open: VMD draws no new
# geometry once it has read its end.) It logs to build/figures.log: windowed
# VMD does not reliably show its standard output.
set here [pwd]
set root [file dirname $here]
set figs [file join $here figures]
set auto_path [linsert $auto_path 0 [file join $root vmdance]]
file mkdir [file join $here build]
set ::logf [open [file join $here build figures.log] w]
fconfigure $::logf -buffering line
proc log {m} { puts $::logf $m }
proc bgerror {msg} { log "BGERROR $msg\n$::errorInfo" }
proc env_or {name default} {
    expr {[info exists ::env($name)] && $::env($name) ne "" ? $::env($name) : $default}
}
# The window drawn whole: its events run for a moment (no vwait)
proc settle {{ms 400}} {
    set end [expr {[clock milliseconds] + $ms}]
    update
    while {[clock milliseconds] < $end} { after 50; update }
}
# A widget's place in the window: {x y width height}, Tk's points
proc place_of {wd} {
    list [expr {[winfo rootx $wd] - [winfo rootx .vmdance]}] [expr {[winfo rooty $wd] - [winfo rooty .vmdance]}] \
        [winfo width $wd] [winfo height $wd]
}

if {[catch {
    package require vmdance
    ::VMDance::_load_tk
    set ::VMDance::Prefs::file ""
    set cli [file normalize [env_or MDANCE_CLI [file join $root .. CPP-MDANCE build cli mdance-cli]]]
    if {![file executable $cli]} { error "no mdance-cli at $cli: set MDANCE_CLI" }
    vmdance backend -mode cli -cli $cli
    set data [env_or TAU_DATA ""]
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} {
        if {![file isfile [file join $data $f]]} {
            error "no $f in \"$data\": set TAU_DATA to BitQT's examples folder"
        }
    }
    set work [file join $here build figrun]
    file delete -force $work
    file mkdir $work
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} { file copy [file join $data $f] $work }
    cd $work

    # the guide's script, as printed: its quit kept for the end
    rename ::quit ::_qs_quit
    proc ::quit {args} {}
    uplevel #0 [list source [file join $here quickstart.tcl]]
    rename ::quit {}
    rename ::_qs_quit ::quit
    log "the script ran: [vmdance runs]"

    file mkdir $figs
    # the gallery: every plot of run 1 (the KMeans NANI clustering), in full
    # colour (no cluster selected)
    vmdance run 1
    vmdance select clear
    foreach key [dict keys $::VMDance::GUI::tabs] {
        # (the page's width: the Timeline, whose note is cut at half of it;
        # the Sweep, whose values fit its cells only there; the Elbow, its two
        # axes, its legend and its stability strip)
        # (the halves are the Make-up's: the Map and the Profiles show the
        # clusters, as they do without groups)
        switch -- $key {
            timeline        { set size {-width 178mm -height 65mm -text 9} }
            sweep           { set size {-width 178mm -height 75mm -text 9} }
            elbow           { set size {-size two-columns} }
            map             { set size {-width 120mm -height 90mm -text 10 -options {mp_colour cluster}} }
            profiles        { set size {-width 120mm -height 90mm -text 10 -options {pf_show clusters}} }
            default         { set size {-width 120mm -height 90mm -text 10} }
        }
        vmdance figures $figs -plots $key -formats pdf -prefix gallery {*}$size
        log "gallery: $key"
    }

    # the representatives, each in its cluster's colour, alone in the 3D view
    for {set i 0} {$i < [molinfo $m get numreps]} {incr i} { mol showrep $m $i 0 }
    vmdance draw -reps 1 -style Licorice -sel backbone
    display projection orthographic
    display depthcue off
    axes location off
    display resize 900 700
    display resetview
    settle 800
    vmdance figures $figs -plots {} -3d 1 -prefix main
    log "main: 3d [glob -nocomplain -directory $figs main_3d*]"

    # the window, on macOS: Results, and the Make-up of the two halves
    set lister [file join $here build macos_windows]
    if {$::tcl_platform(os) eq "Darwin" && [file executable $lister]} {
        set w [vmdance]
        wm geometry .vmdance 1350x950+40+40
        ::VMDance::GUI::show_pane results
        ::VMDance::GUI::show_tab makeup
        raise .vmdance
        settle 2500
        set id ""
        foreach line [split [exec $lister [pid]] \n] {
            lassign $line wid x y ww wh layer on
            if {$on && abs($ww - [winfo width .vmdance]) < 4} { set id $wid }
        }
        if {$id eq ""} { error "the VMDance window was not found among VMD's" }
        exec screencapture -x -o -l$id [file join $figs window.png]
        set tab [$w.pw.right.nb select]
        set fh [open [file join $figs window_parts.txt] w]
        puts $fh [list window 0 0 [winfo width .vmdance] [winfo height .vmdance]]
        foreach {name wd} [list toolbar $w.tb panes $w.pw.left.nb plots $w.pw.right.nb plot $tab.c \
                options $tab.opts readout $w.pw.right.rf status $w.sb] {
            if {[winfo exists $wd]} { puts $fh [list $name {*}[place_of $wd]] } else { log "no $wd" }
        }
        close $fh
        log "window: $id"
    } else {
        log "window: not taken (macOS only; figures/window.png kept)"
    }
    log "done"
} err]} {
    log "ERROR $err\n$::errorInfo"
}
cd $here
catch {::VMDance::Backend::cleanup}
close $::logf
quit
