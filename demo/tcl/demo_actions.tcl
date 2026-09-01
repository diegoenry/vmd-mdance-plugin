# demo_actions.tcl - the verbs a scene's -do body uses.
#
# Scene files should read like a script for a presenter, not like Tk plumbing:
#
#     demo::param km_nclusters 4
#     demo::click .mdance.nb.kmeans.run.btn
#     demo::plot population
#
# Everything here is deliberately forgiving. A demo that dies because a plot
# window was already open, or because a widget moved, is worse than a demo that
# quietly carries on -- so these verbs validate, log, and degrade rather than
# throw. The one exception is demo::param, which refuses to set a plugin
# variable that does not exist: silently setting a typo'd variable would mean the
# narration describes a parameter the run never used.

namespace eval ::demo {
    variable plot_slot 0
    variable open_plots {}
    variable out_dir ""     ;# where exports written by the demo go
}

# --- logging ---------------------------------------------------------------

proc ::demo::note {text {level info}} {
    ::demo::engine::_log $level $text
}

# --- plugin parameters -----------------------------------------------------

# param - set one of the plugin's GUI variables (the same variables its widgets
# are bound to, so the change is visible on screen the moment it happens).
proc ::demo::param {name value} {
    set full ::mdance::gui::$name
    if {![info exists $full]} {
        error "demo::param: ::mdance::gui::$name does not exist"
    }
    set $full $value
    update idletasks
    return $value
}

proc ::demo::param_get {name} {
    return [set ::mdance::gui::$name]
}

# params - set several at once; returns a short "k=4, metric=MSD" summary handy
# for the log.
proc ::demo::params {args} {
    set parts {}
    foreach {k v} $args {
        param $k $v
        lappend parts "$k=$v"
    }
    return [join $parts ", "]
}

# --- widgets ---------------------------------------------------------------

# click - invoke a ttk::button by path. Logs and returns 0 if it is missing or
# disabled rather than aborting the beat.
proc ::demo::click {path} {
    if {![winfo exists $path]} {
        note "click: no such widget $path" warn
        return 0
    }
    set st ""
    catch {set st [$path cget -state]}
    if {$st eq "disabled"} {
        note "click: $path is disabled" warn
        return 0
    }
    $path invoke
    return 1
}

proc ::demo::tab {name} {
    ::demo::engine::_select_tab $name
}

# tab_tour - flip through a list of tabs, $ms apart, WITHOUT blocking.
#
# The obvious version of this -- `after $ms; update` in a loop -- blocks the
# event loop and then re-enters it, which in this demo means the engine's own
# timers fire in the middle of an action. Chained `after` callbacks keep the
# whole thing on the event loop where it belongs.
proc ::demo::tab_tour {tabs {ms 900} {finish ""}} {
    variable tour_after
    catch {after cancel $::demo::tour_after}
    _tour_step $tabs $ms $finish
}

proc ::demo::_tour_step {tabs ms finish} {
    variable tour_after
    if {[llength $tabs] == 0} {
        set tour_after ""
        if {$finish ne ""} { catch {::demo::tab $finish} }
        return
    }
    ::demo::tab [lindex $tabs 0]
    set tour_after [after $ms \
        [list ::demo::_tour_step [lrange $tabs 1 end] $ms $finish]]
}

proc ::demo::tab_tour_stop {} {
    variable tour_after
    if {[info exists tour_after] && $tour_after ne ""} {
        catch {after cancel $tour_after}
    }
    set tour_after ""
}

# select_cluster - highlight row $i of the Results tab's cluster listbox, the
# same way a user would before pressing "Go to Representative".
proc ::demo::select_cluster {i} {
    set lb .mdance.nb.results.table.list.lb
    if {![winfo exists $lb]} { return 0 }
    if {$i >= [$lb size]} { return 0 }
    $lb selection clear 0 end
    $lb selection set $i
    $lb activate $i
    $lb see $i
    update idletasks
    return 1
}

# --- plot windows ----------------------------------------------------------

# Short name -> the proc that opens it and the toplevel it creates.
# The toplevel names come from create_plot_window's `set w .$name`.
proc ::demo::_plot_table {} {
    return {
        population   {::mdance::plots::population_chart          .mdance_pop}
        timeline     {::mdance::plots::timeline_chart            .mdance_timeline}
        msd          {::mdance::plots::msd_chart                 .mdance_msd}
        dendrogram   {::mdance::plots::dendrogram                .mdance_dendro}
        transitions  {::mdance::plots::transition_heatmap        .mdance_trans}
        residence    {::mdance::plots::residence_chart           .mdance_residence}
        distances    {::mdance::plots::cluster_distance_heatmap  .mdance_cdist}
        reprmsd      {::mdance::plots::representative_rmsd_matrix .mdance_reprmsd}
        msdpop       {::mdance::plots::msd_vs_population         .mdance_msdpop}
        silhouette   {::mdance::plots::silhouette_plot           .mdance_silhouette}
        similarity   {::mdance::plots::similarity_chart          .mdance_isim}
        elbow        {::mdance::plots::draw_elbow_chart          .mdance_elbow}
        sweep        {::mdance::gui::draw_sweep_heatmap          .mdance_sweep_hm}
    }
}

# plot - open one of the result plots and park it in the next layout slot.
#
# Most plot procs take the results dict; the two that do not are handled by
# their own scenes. Slots cycle through four positions over the VMD display so
# consecutive plots sit beside each other instead of on top of each other.
proc ::demo::plot {which args} {
    array set tbl [_plot_table]
    if {![info exists tbl($which)]} {
        note "plot: unknown plot \"$which\"" warn
        return ""
    }
    lassign $tbl($which) procname toplevel

    if {$::mdance::results eq ""} {
        note "plot $which: no results yet" warn
        return ""
    }
    if {[catch {$procname $::mdance::results {*}$args} err]} {
        note "plot $which failed: $err" error
        return ""
    }
    _place_plot $toplevel
    return $toplevel
}

# plot_raw - open a plot whose proc takes something other than the results dict.
proc ::demo::plot_raw {which script} {
    array set tbl [_plot_table]
    if {![info exists tbl($which)]} {
        note "plot_raw: unknown plot \"$which\"" warn
        return ""
    }
    lassign $tbl($which) procname toplevel
    if {[catch {uplevel #0 $script} err]} {
        note "plot $which failed: $err" error
        return ""
    }
    _place_plot $toplevel
    return $toplevel
}

# _place_plot - move a freshly opened plot into a tidy position, keeping it
# clear of the caption bar at the bottom of the screen.
proc ::demo::_place_plot {toplevel} {
    variable plot_slot
    variable open_plots

    if {![winfo exists $toplevel]} { return }
    if {[lsearch -exact $open_plots $toplevel] < 0} {
        lappend open_plots $toplevel
    }

    set sw 1600
    set sh 1000
    catch {set sw [winfo screenwidth .]}
    catch {set sh [winfo screenheight .]}

    set pw 660
    set ph 430
    # Four slots in the left half of the screen, above the caption bar.
    set x0 40
    set y0 60
    set dx [expr {$pw + 26}]
    set dy [expr {$ph + 34}]
    # Fall back to two stacked slots on a screen too narrow for two columns.
    set cols [expr {($sw * 0.58) > (2 * $pw + 80) ? 2 : 1}]

    set slot [expr {$plot_slot % 4}]
    incr plot_slot
    set cx [expr {$cols == 2 ? $slot % 2 : 0}]
    set cy [expr {$cols == 2 ? $slot / 2 : $slot % 2}]
    set x [expr {$x0 + $cx * $dx}]
    set y [expr {$y0 + $cy * $dy}]
    if {$y + $ph > $sh - 240} { set y [expr {$sh - 240 - $ph}] }
    if {$y < 30} { set y 30 }

    catch {wm geometry $toplevel "${pw}x${ph}+${x}+${y}"}
    catch {raise $toplevel}
    catch {update idletasks}
}

# close_plots - tidy up between chapters.
proc ::demo::close_plots {} {
    variable open_plots
    variable plot_slot
    array set tbl [_plot_table]
    foreach k [array names tbl] {
        set top [lindex $tbl($k) 1]
        catch {destroy $top}
    }
    # The elbow configuration window and any leftover sweep heatmap too.
    catch {destroy .mdance_elbow_cfg}
    set open_plots {}
    set plot_slot 0
}

# --- exports ---------------------------------------------------------------

# out - a path inside the demo's own output directory. Scenes write here so a
# walkthrough never scatters files across the user's working directory.
proc ::demo::out {name} {
    variable out_dir
    if {$out_dir eq ""} { error "demo::out: output directory not configured" }
    file mkdir $out_dir
    return [file join $out_dir $name]
}

# save_as - arm the next file dialog with a path under the demo output
# directory, then click the button that opens it.
proc ::demo::save_as {path button} {
    ::demo::dialogs::arm $path
    set ok [click $button]
    if {!$ok} { ::demo::dialogs::disarm }
    return $ok
}

# --- VMD shortcuts ---------------------------------------------------------

proc ::demo::spin {{on 1}} {
    if {$on} { ::demo::vmd::spin_start } else { ::demo::vmd::spin_stop }
}

proc ::demo::frame_to {f} {
    ::demo::vmd::goto_frame $f
}

proc ::demo::sweep_to {from to secs} {
    ::demo::vmd::sweep_frames $from $to $secs
}

# rep_tour - step through clusters $from..$to, selecting each in the Results
# list and jumping VMD to its representative frame, $ms apart. Non-blocking,
# for the same reason tab_tour is.
proc ::demo::rep_tour {from to {ms 1600}} {
    variable rep_after
    catch {after cancel $::demo::rep_after}
    _rep_step $from $to $ms
}

proc ::demo::_rep_step {i to ms} {
    variable rep_after
    if {$i > $to} { set rep_after "" ; return }
    if {[select_cluster $i]} {
        catch {::mdance::goto_representative $i}
        note "cluster $i -> frame [molinfo [::demo::vmd::molid] get frame]"
    }
    set rep_after [after $ms [list ::demo::_rep_step [expr {$i + 1}] $to $ms]]
}

proc ::demo::rep_tour_stop {} {
    variable rep_after
    if {[info exists rep_after] && $rep_after ne ""} { catch {after cancel $rep_after} }
    set rep_after ""
}

# --- assertions ------------------------------------------------------------

# expect_results - guarantee that the Results tab holds the clustering this
# chapter's narration describes.
#
# It is NOT enough to run one only when there are no results at all. Chapters
# play in sequence, and the Sweep chapter deliberately loads a k=2 configuration
# into the Results tab -- so an "if empty" test left every later chapter
# analysing k=2 while its narration talked about four clusters, and the exports
# chapter wrote two representative structures instead of four. Match on the
# actual algorithm and cluster count, and re-run when they differ. A run costs
# well under a second; being wrong on stage costs more.
proc ::demo::expect_results {{algorithm kmeans} {k 4}} {
    set r $::mdance::results
    if {$r ne "" && [dict exists $r labels] &&
        [dict exists $r algorithm] && [dict get $r algorithm] eq $algorithm &&
        [dict exists $r nClusters] && [dict get $r nClusters] == $k} {
        return 0
    }
    note "Establishing a $algorithm k=$k clustering for this chapter."
    # Reset the input description too: a previous chapter may have left a stride
    # or a different selection behind, which would silently change the answer.
    params mol_selection [::demo::vmd::molid] \
           atom_selection "protein and name CA" \
           frame_first 0 frame_last -1 frame_stride 1
    switch -exact -- $algorithm {
        kmeans {
            params km_nclusters $k km_metric MSD km_kinit CompSim km_percentage 10
            click .mdance.nb.kmeans.run.btn
        }
        divine {
            params div_nclusters $k div_metric MSD div_split WeightedMSD \
                   div_anchors NANI div_kinit StratAll div_refine 1 \
                   div_threshold 0.0 div_end_mode k div_percentage 10
            click .mdance.nb.divine.run.btn
        }
        default { error "demo::expect_results: unsupported algorithm $algorithm" }
    }
    return 1
}

proc ::demo::vmd::molid {} {
    variable molid
    return $molid
}
