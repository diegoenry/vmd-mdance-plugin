# mdance_plots.tcl - Canvas-based plotting for MDANCE cluster analysis
#
# Provides 11 visualization types using Tk canvas with:
#   - Auto-resize on window resize
#   - Adjustable font size per plot
#   - CSV data export and PostScript/PNG image export

namespace eval ::mdance {}
namespace eval ::mdance::plots {
    # Canvas margin constants
    variable left_margin 80
    variable right_margin 40
    variable top_margin 50
    variable bottom_margin 60

    # Font size for new plots (default baseline)
    variable plot_font_size 10

    # Draw the plot's NAME inside the canvas? Off by default: the window title
    # bar already shows it, so on screen it is redundant. An EXPORTED image has
    # no title bar, so export_image turns this on for the duration of the export
    # (see there) rather than shipping an unidentifiable picture.
    variable plot_titles 0

    # Timeline bar thickness as a fraction of each cluster's lane. Was a fixed
    # 0.7, which on a long trajectory with few clusters drew slabs so thick that
    # neighbouring lanes nearly touched.
    variable timeline_thickness 0.35

    # Per-plot state
    variable current_plot ""
    variable font_sizes
    variable redraw_cmds
    variable redraw_after
    variable csv_data
    variable data
    array set font_sizes {}
    variable is_redrawing 0
    array set redraw_cmds {}
    array set redraw_after {}
    array set csv_data {}
    # Per-K partitions from the last elbow scan: K -> {kActual clusterSizes}.
    # The scan used to keep only (K, CH, DB) and throw each K's partition away,
    # so the two scores were all the user could ever see.
    variable elbow_partitions
    array set elbow_partitions {}
    array set data {}

    # Display title per plot. It used to be the toplevel's `wm title`; an
    # embedded plot has no title bar, so it is kept here and mirrored to
    # whichever container is showing the plot.
    variable titles
    array set titles {}

    # The shared export bar's font spinbox edits the CURRENT plot's size, so it
    # needs a variable of its own that follows the selected tab.
    variable shared_font 10

    # Tab labels. The full titles ("Within-Cluster MSD (Compactness)") are what
    # an export needs and what the window used to show, but a strip of eleven of
    # them truncates to uselessness. These match the launcher buttons, so the
    # button you pressed and the tab you get read the same.
    variable tab_labels
    array set tab_labels {
        mdance_pop        "Population"
        mdance_timeline   "Timeline"
        mdance_msd        "Cluster MSD"
        mdance_dendro     "Dendrogram"
        mdance_silhouette "Silhouette"
        mdance_cdist      "Distances"
        mdance_msdpop     "MSD/Pop"
        mdance_reprmsd    "Rep. RMSD"
        mdance_trans      "Transitions"
        mdance_residence  "Residence"
        mdance_isim       "Similarity"
        mdance_elbow      "Elbow"
        mdance_sweep_hm   "Score Heatmap"
    }
}

# ============================================================
# Color mapping - BGR scale matching VMD's User field coloring
# ============================================================

proc ::mdance::plots::cluster_color {cid nclusters} {
    # Noise / unassigned (-1) -> neutral gray. Clamp out-of-range ids so the
    # channel math below can never leave [0,255]; otherwise format "#%02x%02x%02x"
    # emits a >6-hex-digit string that Tk rejects, aborting the canvas draw.
    if {$cid < 0} { return "#808080" }
    if {$cid >= $nclusters} { set cid [expr {$nclusters - 1}] }
    set t [expr {$nclusters > 1 ? double($cid) / ($nclusters - 1) : 0.0}]
    if {$t < 0.5} {
        set s [expr {$t * 2.0}]
        set r 0
        set g [expr {int(255 * $s)}]
        set b [expr {int(255 * (1.0 - $s))}]
    } else {
        set s [expr {($t - 0.5) * 2.0}]
        set r [expr {int(255 * $s)}]
        set g [expr {int(255 * (1.0 - $s))}]
        set b 0
    }
    return [format "#%02x%02x%02x" $r $g $b]
}

# ============================================================
# Plot window creation with toolbar
# ============================================================

# figures_notebook - the notebook that hosts embedded plots, or "" when the
# main window is not up (a script or a test can still call a chart proc
# directly, and then each plot gets its own toplevel as before).
proc ::mdance::plots::figures_notebook {} {
    set nb .mdance.nb.figures.nb
    if {[winfo exists $nb]} { return $nb }
    return ""
}

# plot_widget - the container for a plot, whether it is a tab or a toplevel.
#
# Embedding forced this to stop being ".<name>". A widget's geometry master must
# be in the same toplevel as the widget, so a plot whose parent is "." cannot be
# packed into the main window -- the body has to BE the notebook page. Nothing
# outside this file should assemble a plot path by hand; ask here.
proc ::mdance::plots::plot_widget {name} {
    set nb [figures_notebook]
    if {$nb ne ""} { return $nb.p_$name }
    return .$name
}

proc ::mdance::plots::plot_exists {name} {
    return [winfo exists [plot_widget $name]]
}

# current_figure - the plot name of the selected tab, or "" if none. The shared
# export bar acts on this.
proc ::mdance::plots::current_figure {} {
    set nb [figures_notebook]
    if {$nb eq ""} { return "" }
    if {[catch {$nb select} cur] || $cur eq ""} { return "" }
    set leaf [lindex [split $cur .] end]
    if {![string match "p_*" $leaf]} { return "" }
    return [string range $leaf 2 end]
}

# plot_title / set_plot_title - a plot's display title. It used to live in the
# toplevel's `wm title`; embedded plots have no title bar, so it is kept here
# and pushed to whichever of the two is showing it.
proc ::mdance::plots::plot_title {name} {
    variable titles
    if {[info exists titles($name)]} { return $titles($name) }
    return ""
}

# tab_label - the short name for a plot's tab, falling back to the full title.
proc ::mdance::plots::tab_label {name title} {
    variable tab_labels
    if {[info exists tab_labels($name)]} { return $tab_labels($name) }
    if {[string length $title] > 18} { return "[string range $title 0 15]..." }
    return $title
}

proc ::mdance::plots::set_plot_title {name title} {
    variable titles
    set titles($name) $title
    set w [plot_widget $name]
    if {![winfo exists $w]} return
    if {[winfo toplevel $w] eq $w} {
        catch {wm title $w $title}
        return
    }
    set nb [figures_notebook]
    if {$nb ne ""} { catch {$nb tab $w -text [tab_label $name $title]} }
}

# create_plot_window - the container for one plot.
#
# Embedded as a tab in the Figures view when the main window is up, and a
# toplevel otherwise. Either way the body is the widget named `.<name>`, so
# every chart proc, the redraw registry and the `.mdance_*` teardown in
# clear_results keep working on the paths they already use: a frame whose parent
# is "." may be packed into any widget, because everything descends from ".".
#
# The toolbar here now carries only per-plot extras (the elbow's score export,
# the timeline's bar width, the heatmap's CH/DB toggle). Font size and the three
# exports moved to one shared bar above the notebook, so eleven plots no longer
# mean eleven copies of the same four controls.
proc ::mdance::plots::create_plot_window {name title width height} {
    variable font_sizes
    variable plot_font_size

    set nb [figures_notebook]
    set w [plot_widget $name]
    set is_new [expr {![winfo exists $w]}]

    if {$is_new} {
        if {$nb ne ""} {
            ttk::frame $w
            $nb add $w -text [tab_label $name $title]
        } else {
            toplevel $w
            wm geometry $w ${width}x${height}
            wm minsize $w 320 220
        }

        set font_sizes($name) $plot_font_size

        # Per-plot extras only; empty for most plots, and an empty ttk::frame
        # costs no height.
        ttk::frame $w.toolbar
        pack $w.toolbar -fill x -padx 5 -pady {2 0}

        canvas $w.c -bg white
        pack $w.c -fill both -expand 1

        bind $w.c <Configure> [list ::mdance::plots::on_resize $name %w %h]
        # Release this plot's cached state and cancel its pending redraw when it
        # is closed (the container pathname is in each child's bindtags, so guard
        # on %W to act only on the container's own <Destroy>).
        bind $w <Destroy> [list ::mdance::plots::on_plot_destroy $name %W $w]
    } else {
        $w.c delete all
        catch {destroy $w.xsb}
        catch {destroy $w.ysb}
        $w.c configure -scrollregion {} -xscrollcommand {} -yscrollcommand {}
    }

    set_plot_title $name $title
    if {$nb ne ""} {
        catch {$nb select $w}
        # Give the canvas the launcher's height the moment there is something to
        # draw in it. Only on the first plot, so a user who deliberately reopened
        # the launcher is not fought with.
        if {$is_new && [llength [$nb tabs]] == 1} {
            catch {
                if {!$::mdance::gui::fold_state(.mdance.nb.figures.plots)} {
                    ::mdance::gui::fold_toggle .mdance.nb.figures.plots
                }
            }
        }
        sync_shared_bar
    }
    return $w
}

# close_figure / close_all_figures - what "closing a plot" means once a plot is
# a tab rather than a window. Destroying the body fires on_plot_destroy, which
# releases the cached results dict and removes the tab.
proc ::mdance::plots::close_figure {{name ""}} {
    if {$name eq ""} { set name [current_figure] }
    if {$name eq ""} return
    catch {destroy [plot_widget $name]}
    sync_shared_bar
}

proc ::mdance::plots::close_all_figures {} {
    set nb [figures_notebook]
    if {$nb ne ""} {
        foreach page [$nb tabs] { catch {destroy $page} }
    }
    # Standalone plot toplevels, for a session that opened some before the GUI.
    foreach w [winfo children .] {
        if {[string match ".mdance_*" $w] && $w ne ".mdance_elbow_cfg" \
            && $w ne ".mdance_settings"} {
            catch {destroy $w}
        }
    }
    sync_shared_bar
}

# ============================================================
# Font helper - returns font spec based on per-plot font size
# ============================================================

proc ::mdance::plots::plot_font {size_offset {weight ""}} {
    variable current_plot
    variable font_sizes
    set base 10
    if {$current_plot ne "" && [info exists font_sizes($current_plot)]} {
        set base $font_sizes($current_plot)
    }
    set s [expr {$base + $size_offset}]
    if {$s < 6} { set s 6 }
    if {$weight ne ""} {
        return [list TkDefaultFont $s $weight]
    }
    return [list TkDefaultFont $s]
}

# ============================================================
# Resize, font change, and export handlers
# ============================================================

proc ::mdance::plots::on_resize {name w h} {
    variable redraw_cmds
    variable redraw_after
    variable is_redrawing

    # Guard: ignore Configure events triggered by our own redraws
    # (e.g. $c configure -width, -scrollregion changes)
    if {$is_redrawing} return
    if {![info exists redraw_cmds($name)]} return

    # Debounce: cancel pending redraw, schedule new one
    if {[info exists redraw_after($name)]} {
        after cancel $redraw_after($name)
    }
    set redraw_after($name) [after 200 [list ::mdance::plots::do_redraw $name]]
}

proc ::mdance::plots::do_redraw {name} {
    variable redraw_cmds
    variable redraw_after
    variable is_redrawing
    catch {unset redraw_after($name)}
    if {$is_redrawing} return
    if {[info exists redraw_cmds($name)] && [plot_exists $name]} {
        set is_redrawing 1
        if {[catch {{*}$redraw_cmds($name)} err]} {
            puts "MDANCE redraw error ($name): $err"
        }
        set is_redrawing 0
    }
}

proc ::mdance::plots::on_font_change {name} {
    do_redraw $name
}

# redraw_all - Re-render every open plot, for a preference that affects all of
# them (the in-plot title switch). Each redraw goes through redraw_cmds, so a
# plot with no registered command is simply skipped.
proc ::mdance::plots::redraw_all {} {
    variable redraw_cmds
    foreach name [array names redraw_cmds] {
        if {[plot_exists $name]} { do_redraw $name }
    }
}

# on_plot_destroy - clear a closed plot's per-name cached state (which can pin a
# whole results dict / per-frame CSV) and cancel any queued resize redraw.
proc ::mdance::plots::on_plot_destroy {name W w} {
    if {$W ne $w} return
    variable redraw_after
    catch {after cancel $redraw_after($name)}
    foreach a {redraw_cmds redraw_after csv_data font_sizes titles} {
        catch {unset ::mdance::plots::${a}($name)}
    }
    # An embedded plot leaves its notebook page behind when the body is
    # destroyed -- clear_results destroys the bodies, so without this the
    # Figures view keeps a row of empty tabs.
    set nb [figures_notebook]
    if {$nb ne ""} { catch {$nb forget $w} }
    # Release the computed-data cache too. These entries hold whole distance
    # matrices, and leaving them behind pinned that memory for the rest of the
    # VMD session -- and served stale numbers to a later re-open of the plot.
    variable data
    switch -- $name {
        mdance_dendro     { catch {unset data(dendro)} }
        mdance_cdist      { catch {unset data(cdist)} }
        mdance_reprmsd    { catch {unset data(reprmsd)} }
        mdance_silhouette { catch {unset data(silhouette)} }
    }
}

# sync_shared_bar - point the shared controls at the selected tab: load that
# plot's font size, and enable or disable the whole bar depending on whether
# there is a plot to act on.
proc ::mdance::plots::sync_shared_bar {} {
    variable font_sizes
    variable shared_font
    set bar .mdance.nb.figures.bar
    if {![winfo exists $bar]} return

    # An empty notebook draws as a bare sunken box, so swap in a placeholder
    # rather than leaving the user looking at nothing.
    set nb [figures_notebook]
    set empty .mdance.nb.figures.empty
    if {$nb ne "" && [winfo exists $empty]} {
        if {[llength [$nb tabs]] == 0} {
            catch {pack forget $nb}
            catch {pack $empty -fill both -expand 1 -padx 10 -pady {6 10}}
        } else {
            catch {pack forget $empty}
            catch {pack $nb -fill both -expand 1 -padx 10 -pady {6 10}}
        }
    }

    catch {::mdance::gui::sync_export_buttons}
    set name [current_figure]
    set state [expr {$name eq "" ? "disabled" : "normal"}]
    foreach child {fs csv ps png close closeall} {
        catch {$bar.$child configure -state $state}
    }
    if {$name ne "" && [info exists font_sizes($name)]} {
        set shared_font $font_sizes($name)
    }
}

# on_shared_font - the shared spinbox writes through to the current plot.
proc ::mdance::plots::on_shared_font {} {
    variable font_sizes
    variable shared_font
    set name [current_figure]
    if {$name eq ""} return
    set font_sizes($name) $shared_font
    on_font_change $name
}

# Shared-bar wrappers, so the buttons need no argument and degrade quietly when
# no plot is open.
proc ::mdance::plots::export_current_csv {} {
    set n [current_figure]; if {$n ne ""} { export_csv $n }
}
proc ::mdance::plots::export_current_image {fmt} {
    set n [current_figure]; if {$n ne ""} { export_image $n $fmt }
}

proc ::mdance::plots::export_csv {name} {
    variable csv_data
    if {![info exists csv_data($name)] || $csv_data($name) eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "No data available to export."
        return
    }
    set f [tk_getSaveFile -defaultextension ".csv" \
        -filetypes {{"CSV files" ".csv"} {"All files" "*"}} \
        -title "Export Plot Data"]
    if {$f ne ""} {
        if {[catch {
            set fd [open $f w]
            puts -nonewline $fd $csv_data($name)
            close $fd
        } err]} {
            catch {close $fd}
            tk_messageBox -icon error -title "MDANCE" -message "Could not write CSV:\n$err"
            return
        }
        tk_messageBox -icon info -title "MDANCE" -message "Data exported to $f"
    }
}

proc ::mdance::plots::export_image {name fmt} {
    set w [plot_widget $name]
    if {![winfo exists $w]} return
    set c $w.c

    # An exported image has no window title bar, so a titleless export would be
    # an unidentifiable picture. Draw the title for the export regardless of the
    # on-screen preference, then put the canvas back the way the user had it.
    variable plot_titles
    set titles_were $plot_titles
    if {!$plot_titles} {
        set plot_titles 1
        do_redraw $name
    }
    set rc [catch {_export_image_body $name $fmt $w $c} res opts]
    if {!$titles_were} {
        set plot_titles 0
        do_redraw $name
    }
    if {$rc} { return -options $opts $res }
    return $res
}

# save_canvas_image - write a plot to $path, no dialog.
#
# Split out of the old _export_image_body so the shared toolbar export and the
# per-plot one go through the same code: one converter chain, one set of
# messages, one place to fix.
# Minimum size a plot is composed at for export. A figure is not the same
# artefact as the pane it happens to be sitting in: the pane can be 434x96 in a
# small window, and exporting that verbatim gives a flattened, unusable picture.
namespace eval ::mdance::plots {
    variable export_min_w 820
    variable export_min_h 600
}

proc ::mdance::plots::save_canvas_image {name path fmt} {
    variable export_min_w
    variable export_min_h
    variable font_sizes
    set w [plot_widget $name]
    if {![winfo exists $w.c]} { return 0 }
    set c $w.c

    # An exported image has no tab or title bar to identify it, so the in-plot
    # title is forced on for the export and restored afterwards.
    variable plot_titles
    set saved $plot_titles
    set plot_titles 1

    # Compose at a proper figure size when the pane is smaller than one. The
    # canvas is temporarily taken out of pack and `place`d at the target size --
    # winfo then reports the real dimensions, so the plot re-lays itself out --
    # and the font scales with the height, or the labels come out proportionally
    # tiny in a large image.
    set cw [winfo width $c]
    set ch [winfo height $c]
    set resized 0
    set packinfo {}
    set oldfont ""
    if {$cw < $export_min_w || $ch < $export_min_h} {
        set tw [expr {$cw > $export_min_w ? $cw : $export_min_w}]
        set th [expr {$ch > $export_min_h ? $ch : $export_min_h}]
        if {[winfo manager $c] eq "pack" && $ch > 0} {
            set packinfo [pack info $c]
            if {[info exists font_sizes($name)]} {
                # Size the type for the TARGET canvas, never by the ratio to the
                # current one: a 98 px pane scaled the font 6x and the labels
                # collided. 500 px is the height a plot is composed for at the
                # plugin's normal window size, so this keeps the exported figure
                # in the proportions the plot was designed in.
                set oldfont $font_sizes($name)
                set scaled [expr {int(round(double($oldfont) * $th / 500.0))}]
                if {$scaled < $oldfont} { set scaled $oldfont }
                if {$scaled > [expr {$oldfont * 2}]} { set scaled [expr {$oldfont * 2}] }
                set font_sizes($name) $scaled
            }
            pack forget $c
            place $c -x 0 -y 0 -width $tw -height $th
            set resized 1
            update idletasks
        }
    }

    catch {do_redraw $name}
    set rc [catch {_write_canvas $c $path $fmt} err]

    if {$resized} {
        place forget $c
        if {$oldfont ne ""} { set font_sizes($name) $oldfont }
        catch {pack $c {*}$packinfo}
        update idletasks
    }
    set plot_titles $saved
    catch {do_redraw $name}

    if {$rc} {
        tk_messageBox -icon error -title "MDANCE" -message "Could not export figure:\n$err"
        return 0
    }
    set ::mdance::status "Exported [file tail $path]"
    return 1
}

# _write_canvas - the actual bytes. PostScript is native; PNG goes through a
# rasteriser, and the whole scroll region is exported rather than just the part
# that happens to be visible.
proc ::mdance::plots::_write_canvas {c path fmt} {
    set opts [list -colormode color]
    set sr [$c cget -scrollregion]
    if {[llength $sr] == 4} {
        lassign $sr x0 y0 x1 y1
        lappend opts -x $x0 -y $y0 \
            -width [expr {$x1 - $x0}] -height [expr {$y1 - $y0}]
    }
    if {$fmt eq "ps"} {
        $c postscript -file $path {*}$opts
        return
    }
    set tmpps [::mdance::utils::mktmp .ps]
    $c postscript -file $tmpps {*}$opts

    # Ghostscript first: ImageMagick shells out to gs for PostScript anyway, and
    # gs is present on far more machines than IM -- its absence from this list is
    # why PNG export used to degrade to PostScript on systems that could in fact
    # render it.
    set converters {}
    if {[auto_execok gs] ne ""} {
        lappend converters [list gs -q -dNOPAUSE -dBATCH -dSAFER \
            -sDEVICE=png16m -r150 -dEPSCrop -sOutputFile=$path $tmpps]
    }
    if {[auto_execok magick] ne ""} { lappend converters [list magick convert -density 150 $tmpps $path] }
    if {[auto_execok gm] ne ""}     { lappend converters [list gm convert -density 150 $tmpps $path] }
    if {$::tcl_platform(platform) ne "windows" && [auto_execok convert] ne ""} {
        lappend converters [list convert -density 150 $tmpps $path]
    }
    set ok 0
    foreach cmd $converters {
        # -ignorestderr: gs and IM warn on stderr constantly; the exit status is
        # what says whether it worked.
        if {![catch {exec -ignorestderr {*}$cmd}] && [file exists $path]} { set ok 1; break }
    }
    catch {file delete $tmpps}
    if {!$ok} {
        set psout [file rootname $path].ps
        $c postscript -file $psout {*}$opts
        return -code error "no PNG rasteriser found (tried gs, magick, gm, convert).\nSaved as PostScript instead: $psout"
    }
}

proc ::mdance::plots::_export_image_body {name fmt w c} {
    if {$fmt eq "ps"} {
        set f [tk_getSaveFile -defaultextension ".ps" \
            -filetypes {{"PostScript" ".ps"} {"All files" "*"}} \
            -title "Export Plot as PostScript"]
    } else {
        set f [tk_getSaveFile -defaultextension ".png" \
            -filetypes {{"PNG image" ".png"} {"All files" "*"}} \
            -title "Export Plot as PNG"]
    }
    if {$f eq ""} return
    save_canvas_image $name $f $fmt
}

proc ::mdance::plots::canvas_dims {c default_w default_h} {
    update idletasks
    set cw [winfo width $c]
    set ch [winfo height $c]
    if {$cw < 50} { set cw $default_w }
    if {$ch < 50} { set ch $default_h }
    return [list $cw $ch]
}

# ============================================================
# Canvas helper procedures
# ============================================================

proc ::mdance::plots::draw_axes {c x0 y0 x1 y1} {
    $c create line $x0 $y1 $x0 $y0 -width 2 -fill black
    $c create line $x0 $y1 $x1 $y1 -width 2 -fill black
}

# draw_title - The plot heading.
#
# $title is the plot's NAME, which the window title bar already shows, so it is
# drawn only when "Titles inside plots" is enabled (off by default).
#
# $subtitle is a different thing and is ALWAYS drawn: it carries information
# that exists nowhere else on the canvas -- a skipped-K caveat, a units
# qualifier, a computed mean. Suppressing it along with the name would silently
# drop a warning from an exported figure, so when the name is hidden the
# subtitle moves up into its slot instead of disappearing.
proc ::mdance::plots::draw_title {c width title {subtitle ""}} {
    variable plot_titles
    set y 20
    if {$plot_titles} {
        # -width lets Tk wrap a long title instead of running it off both edges.
        $c create text [expr {$width / 2}] $y -text $title -font [plot_font 2 bold] \
            -anchor n -width [expr {$width - 20}] -justify center
        set y 40
    }
    if {$subtitle ne ""} {
        $c create text [expr {$width / 2}] $y -text $subtitle -font [plot_font -1] \
            -anchor n -width [expr {$width - 20}] -justify center -fill "#666666"
    }
}

# Compute "nice" tick values for a numeric axis
proc ::mdance::plots::nice_ticks {vmin vmax nticks} {
    if {$vmax <= $vmin} { set vmax [expr {$vmin + 1.0}] }
    # double() forces float arithmetic: with integer vmin/vmax (e.g. cluster
    # sizes 0..3) and nticks 6, $range/$nticks would be integer division -> 0,
    # then log10(0) -> -Inf and rough_step/mag becomes 0.0/0.0 (domain error).
    set range [expr {double($vmax) - $vmin}]
    set rough_step [expr {$range / $nticks}]
    if {$rough_step <= 0} { return [list $vmin] }
    set mag [expr {pow(10, floor(log10($rough_step)))}]
    set norm [expr {$rough_step / $mag}]
    if {$norm < 1.5} {
        set nice_step [expr {1.0 * $mag}]
    } elseif {$norm < 3.5} {
        set nice_step [expr {2.0 * $mag}]
    } elseif {$norm < 7.5} {
        set nice_step [expr {5.0 * $mag}]
    } else {
        set nice_step [expr {10.0 * $mag}]
    }
    set tick_min [expr {$nice_step * floor($vmin / $nice_step)}]
    set ticks {}
    set v $tick_min
    while {$v <= $vmax * 1.001} {
        if {$v >= $vmin - $nice_step * 0.001} {
            lappend ticks $v
        }
        set v [expr {$v + $nice_step}]
    }
    return $ticks
}

proc ::mdance::plots::draw_yticks {c x0 y0 y1 vmin vmax nticks {x1 ""}} {
    if {$x1 eq ""} {
        # Last resort only -- every in-tree caller passes the real right edge.
        # `bbox all` measures whatever is already drawn, which includes the
        # centred title, so it overshoots the plot area.
        set bbox [$c bbox all]
        set x1 [expr {$bbox eq "" ? $x0 : [lindex $bbox 2]}]
    }
    set ticks [nice_ticks $vmin $vmax $nticks]
    set plot_h [expr {$y1 - $y0}]
    set range [expr {$vmax - $vmin}]
    if {$range <= 0} { set range 1.0 }
    foreach v $ticks {
        set py [expr {$y1 - ($v - $vmin) / $range * $plot_h}]
        $c create line [expr {$x0 - 5}] $py $x0 $py -fill gray60
        # Span the ACTUAL plot width. This used to read the canvas's -width
        # *option*, which is the creation-time request (a "10c" default), so the
        # gridlines were unrelated to the real plot and stopped short of, or ran
        # past, the axes on every resized window.
        $c create line $x0 $py $x1 $py -fill gray90 -dash {2 4}
        if {abs($v) < 0.001 && $vmax > 1} {
            set label [format "%.0f" $v]
        } elseif {$vmax >= 100} {
            set label [format "%.0f" $v]
        } elseif {$vmax >= 1} {
            set label [format "%.1f" $v]
        } else {
            set label [format "%.3f" $v]
        }
        $c create text [expr {$x0 - 8}] $py -text $label -anchor e -font [plot_font -1]
    }
}

proc ::mdance::plots::draw_xtick_labels {c x0 y1 x1 labels} {
    set n [llength $labels]
    if {$n == 0} return
    set plot_w [expr {$x1 - $x0}]
    set step [expr {double($plot_w) / $n}]
    for {set i 0} {$i < $n} {incr i} {
        set px [expr {$x0 + $step * $i + $step / 2.0}]
        set py [expr {$y1 + 5}]
        $c create text $px $py -text [lindex $labels $i] -anchor n -font [plot_font -1]
    }
}

# Map a scalar value to a blue-white-red color gradient
proc ::mdance::plots::heatmap_color {val vmin vmax} {
    if {$vmax <= $vmin} { return "#FFFFFF" }
    set t [expr {($val - $vmin) / double($vmax - $vmin)}]
    if {$t < 0.0} { set t 0.0 }
    if {$t > 1.0} { set t 1.0 }
    if {$t < 0.5} {
        set s [expr {$t * 2.0}]
        set r [expr {int(59 + 196 * $s)}]
        set g [expr {int(76 + 179 * $s)}]
        set b [expr {int(192 + 63 * $s)}]
    } else {
        set s [expr {($t - 0.5) * 2.0}]
        set r [expr {int(255)}]
        set g [expr {int(255 - 200 * $s)}]
        set b [expr {int(255 - 200 * $s)}]
    }
    return [format "#%02x%02x%02x" $r $g $b]
}

# Draw a vertical color scale legend on the right side of a heatmap
proc ::mdance::plots::draw_color_legend {c x y0 y1 vmin vmax nticks} {
    set bar_w 15
    set steps 50
    set step_h [expr {double($y1 - $y0) / $steps}]
    for {set i 0} {$i < $steps} {incr i} {
        set t [expr {1.0 - double($i) / $steps}]
        set v [expr {$vmin + $t * ($vmax - $vmin)}]
        set color [heatmap_color $v $vmin $vmax]
        set ry0 [expr {$y0 + $i * $step_h}]
        set ry1 [expr {$ry0 + $step_h + 1}]
        $c create rectangle $x $ry0 [expr {$x + $bar_w}] $ry1 -fill $color -outline ""
    }
    $c create rectangle $x $y0 [expr {$x + $bar_w}] $y1 -outline gray60 -width 1

    set ticks [nice_ticks $vmin $vmax $nticks]
    set range [expr {$vmax - $vmin}]
    if {$range <= 0} { set range 1.0 }
    set plot_h [expr {$y1 - $y0}]
    foreach v $ticks {
        set py [expr {$y1 - ($v - $vmin) / $range * $plot_h}]
        $c create line [expr {$x + $bar_w}] $py [expr {$x + $bar_w + 4}] $py -fill gray60
        if {$vmax >= 100} {
            set label [format "%.0f" $v]
        } elseif {$vmax >= 1} {
            set label [format "%.2f" $v]
        } else {
            set label [format "%.3f" $v]
        }
        $c create text [expr {$x + $bar_w + 7}] $py -text $label -anchor w -font [plot_font -2]
    }
}

# Numeric X-axis ticks (mirror of draw_yticks)
proc ::mdance::plots::draw_xticks {c x0 y1 x1 vmin vmax nticks} {
    set ticks [nice_ticks $vmin $vmax $nticks]
    set plot_w [expr {$x1 - $x0}]
    set range [expr {$vmax - $vmin}]
    if {$range <= 0} { set range 1.0 }
    foreach v $ticks {
        set px [expr {$x0 + ($v - $vmin) / $range * $plot_w}]
        $c create line $px $y1 $px [expr {$y1 + 5}] -fill gray60
        if {$vmax >= 100} {
            set label [format "%.0f" $v]
        } elseif {$vmax >= 1} {
            set label [format "%.1f" $v]
        } else {
            set label [format "%.3f" $v]
        }
        $c create text $px [expr {$y1 + 8}] -text $label -anchor n -font [plot_font -1]
    }
}

# ============================================================
# Plot 1: Cluster Population Bar Chart
# ============================================================

proc ::mdance::plots::population_chart {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_pop

    set sizes [dict get $results clusterSizes]
    set nclusters [dict get $results nClusters]
    set nframes [dict get $results nFrames]

    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    set w [create_plot_window mdance_pop "Cluster Population Distribution" 700 500]
    set c $w.c
    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin

    lassign [canvas_dims $c 700 500] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Cluster Population Distribution"
    draw_axes $c $x0 $y0 $x1 $y1

    # Find max size for y-axis scaling
    set max_size 0
    foreach s $sizes { if {$s > $max_size} { set max_size $s } }
    if {$max_size == 0} { set max_size 1 }

    draw_yticks $c $x0 $y0 $y1 0 $max_size 6 $x1

    # Draw bars
    set gap 4
    set bar_w [expr {(double($plot_w) - $gap * ($nclusters + 1)) / $nclusters}]
    if {$bar_w < 2} { set bar_w 2 }

    for {set i 0} {$i < $nclusters} {incr i} {
        set size [lindex $sizes $i]
        set bx0 [expr {$x0 + $gap + $i * ($bar_w + $gap)}]
        set bx1 [expr {$bx0 + $bar_w}]
        set by0 [expr {$y1 - double($size) / $max_size * $plot_h}]
        set by1 $y1
        set color [cluster_color $i $nclusters]
        $c create rectangle $bx0 $by0 $bx1 $by1 -fill $color -outline black -width 1
        # Label below bar
        set mid_x [expr {($bx0 + $bx1) / 2.0}]
        $c create text $mid_x [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
        # Count above bar
        if {$bar_w > 20} {
            $c create text $mid_x [expr {$by0 - 5}] -text $size -anchor s -font [plot_font -2]
        }
    }

    # Axis labels
    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Cluster ID" -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text "Frame Count" -anchor w -angle 90 -font [plot_font 0]

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_pop) [list ::mdance::plots::population_chart $results]
    set csv "cluster_id,frame_count,percentage\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        append csv "$i,[lindex $sizes $i],[format "%.2f" [expr {100.0 * [lindex $sizes $i] / $nframes}]]\n"
    }
    set ::mdance::plots::csv_data(mdance_pop) $csv
}

# ============================================================
# Plot 2: Cluster Assignment Timeline
# ============================================================

proc ::mdance::plots::timeline_chart {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_timeline

    set labels [dict get $results labels]
    set nclusters [dict get $results nClusters]
    set nframes [dict get $results nFrames]

    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    set w [create_plot_window mdance_timeline "Cluster Assignment Timeline" 800 450]
    set c $w.c
    # Bar thickness belongs on this plot's own window: how thin is readable
    # depends on the trajectory length and cluster count in front of the user.
    if {![winfo exists $w.toolbar.lth]} {
        ttk::separator $w.toolbar.sep2 -orient vertical
        ttk::label $w.toolbar.lth -text "Bar:"
        ttk::spinbox $w.toolbar.th -from 0.05 -to 1.0 -increment 0.05 -width 4 \
            -textvariable ::mdance::plots::timeline_thickness \
            -command [list ::mdance::plots::do_redraw mdance_timeline]
        bind $w.toolbar.th <Return> [list ::mdance::plots::do_redraw mdance_timeline]
        pack $w.toolbar.sep2 -side left -fill y -padx 4 -pady 2
        pack $w.toolbar.lth -side left -padx {0 2}
        pack $w.toolbar.th -side left -padx {0 4}
    }
    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin

    lassign [canvas_dims $c 800 450] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Cluster Assignment Timeline"
    draw_axes $c $x0 $y0 $x1 $y1

    # Y-axis: cluster IDs (integer ticks).
    #
    # Noise (-1) needs a lane of its own. Plotting it at lane index -1 put it
    # BELOW the x-axis, on top of the frame-number labels, where it read as a
    # rendering glitch rather than as data. When noise is present every cluster
    # shifts up one lane and noise takes the bottom one.
    set has_noise 0
    foreach lbl $labels {
        if {$lbl < 0} { set has_noise 1; break }
    }
    set lane_offset [expr {$has_noise ? 1 : 0}]
    set nlanes [expr {$nclusters + $lane_offset}]
    set band_h [expr {double($plot_h) / $nlanes}]
    if {$has_noise} {
        set py [expr {$y1 - 0.5 * $band_h}]
        $c create text [expr {$x0 - 8}] $py -text "noise" -anchor e -font [plot_font -2]
        $c create line $x0 $py [expr {$x0 - 4}] $py -fill black
    }
    for {set cl 0} {$cl < $nclusters} {incr cl} {
        set py [expr {$y1 - ($cl + $lane_offset + 0.5) * $band_h}]
        $c create text [expr {$x0 - 8}] $py -text $cl -anchor e -font [plot_font -1]
        $c create line $x0 $py [expr {$x0 - 4}] $py -fill black
    }

    # X-axis: frame number ticks
    set nxticks 8
    for {set t 0} {$t <= $nxticks} {incr t} {
        set sample [expr {int(double($t) / $nxticks * ($nframes - 1))}]
        set frame [::mdance::abs_frame $results $sample]
        set px [expr {$x0 + double($t) / $nxticks * $plot_w}]
        $c create text $px [expr {$y1 + 5}] -text $frame -anchor n -font [plot_font -1]
        $c create line $px $y1 $px [expr {$y1 + 4}] -fill black
    }

    # Pixel-binning: map frames to pixel columns
    variable timeline_thickness
    set rect_h [expr {max(2, $band_h * $timeline_thickness)}]
    set pixels $plot_w
    for {set px_col 0} {$px_col < $pixels} {incr px_col} {
        # Frame range for this pixel column
        set f_start [expr {int(double($px_col) / $pixels * $nframes)}]
        set f_end [expr {int(double($px_col + 1) / $pixels * $nframes)}]
        if {$f_end > $nframes} { set f_end $nframes }
        if {$f_end <= $f_start} { set f_end [expr {$f_start + 1}] }

        # Collect unique labels in this pixel column
        array unset seen
        for {set f $f_start} {$f < $f_end} {incr f} {
            set lbl [lindex $labels $f]
            set seen($lbl) 1
        }

        # Draw colored rectangle for each unique label
        set sx [expr {$x0 + $px_col}]
        foreach lbl [array names seen] {
            # Explicit integer test: `$lbl < 0` on a non-numeric label falls back
            # to STRING comparison, which would silently park it in the noise
            # lane instead of surfacing the malformed result.
            if {![string is integer -strict $lbl]} {
                error "Cluster label \"$lbl\" is not an integer; the result is malformed."
            }
            set lane [expr {$lbl < 0 ? 0 : $lbl + $lane_offset}]
            set cy [expr {$y1 - ($lane + 0.5) * $band_h}]
            set color [cluster_color $lbl $nclusters]
            $c create rectangle $sx [expr {$cy - $rect_h / 2.0}] \
                [expr {$sx + 1}] [expr {$cy + $rect_h / 2.0}] \
                -fill $color -outline $color
        }
    }

    # Axis labels
    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Frame Number" -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text "Cluster ID" -anchor w -angle 90 -font [plot_font 0]

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_timeline) [list ::mdance::plots::timeline_chart $results]
    set csv "frame,cluster_id\n"
    for {set f 0} {$f < $nframes} {incr f} {
        append csv "[::mdance::abs_frame $results $f],[lindex $labels $f]\n"
    }
    set ::mdance::plots::csv_data(mdance_timeline) $csv
}

# ============================================================
# Plot 3: Within-Cluster MSD Bar Chart
# ============================================================

proc ::mdance::plots::msd_chart {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }
    if {![dict exists $results clusterMSD]} {
        tk_messageBox -icon warning -title "MDANCE" \
            -message "No clusterMSD data. Please rebuild mdance-cli and re-run clustering."
        return
    }

    variable current_plot
    set current_plot mdance_msd

    set msds [dict get $results clusterMSD]
    set nclusters [dict get $results nClusters]

    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    set w [create_plot_window mdance_msd "Within-Cluster MSD (Compactness)" 700 500]
    set c $w.c
    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin

    lassign [canvas_dims $c 700 500] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Within-Cluster MSD (Compactness)"
    draw_axes $c $x0 $y0 $x1 $y1

    # Find max MSD for y-axis
    set max_msd 0
    foreach m $msds { if {$m > $max_msd} { set max_msd $m } }
    if {$max_msd <= 0} { set max_msd 1.0 }

    draw_yticks $c $x0 $y0 $y1 0 $max_msd 6 $x1

    # Draw bars
    set gap 4
    set bar_w [expr {(double($plot_w) - $gap * ($nclusters + 1)) / $nclusters}]
    if {$bar_w < 2} { set bar_w 2 }

    for {set i 0} {$i < $nclusters} {incr i} {
        set msd [lindex $msds $i]
        set bx0 [expr {$x0 + $gap + $i * ($bar_w + $gap)}]
        set bx1 [expr {$bx0 + $bar_w}]
        set by0 [expr {$y1 - $msd / $max_msd * $plot_h}]
        set by1 $y1
        set color [cluster_color $i $nclusters]
        $c create rectangle $bx0 $by0 $bx1 $by1 -fill $color -outline black -width 1
        # Label below
        set mid_x [expr {($bx0 + $bx1) / 2.0}]
        $c create text $mid_x [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
        # Value above bar
        if {$bar_w > 20} {
            $c create text $mid_x [expr {$by0 - 5}] -text [format "%.2f" $msd] \
                -anchor s -font [plot_font -2]
        }
    }

    # Axis labels
    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Cluster ID" -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text "MSD" -anchor w -angle 90 -font [plot_font 0]

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_msd) [list ::mdance::plots::msd_chart $results]
    set csv "cluster_id,msd\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        append csv "$i,[format "%.6f" [lindex $msds $i]]\n"
    }
    set ::mdance::plots::csv_data(mdance_msd) $csv
}

# ============================================================
# Plot 4: Dendrogram (HELM only)
# ============================================================

# Compute cluster centroids from VMD coordinates
proc ::mdance::plots::compute_centroids {results centroid_arr natoms_var} {
    upvar $centroid_arr centroid $natoms_var natoms

    set molid [dict get $results molid]
    set sel_text [dict get $results atomsel]
    set labels [dict get $results labels]
    set nclusters [dict get $results nClusters]
    set nframes [dict get $results nFrames]

    set sel [atomselect $molid $sel_text]
    set natoms [$sel num]
    if {$natoms == 0} {
        $sel delete
        error "Atom selection '$sel_text' matched 0 atoms."
    }

    # Accumulate per-cluster coordinate sums and counts
    for {set c 0} {$c < $nclusters} {incr c} {
        set ccount($c) 0
        set csum($c) [lrepeat [expr {3 * $natoms}] 0.0]
    }

    # Always release the selection, even if a $sel frame call throws (e.g. the
    # trajectory was shortened after clustering so an absolute frame is gone).
    set rc [catch {
        for {set f 0} {$f < $nframes} {incr f} {
            set c [lindex $labels $f]
            # Skip noise / unassigned (-1) and any out-of-range label -- those
            # have no accumulator (eQUAL labels leftover frames -1, which would
            # otherwise throw "no such element in array csum(-1)").
            if {$c < 0 || $c >= $nclusters} continue
            $sel frame [::mdance::abs_frame $results $f]
            $sel update
            set coords [$sel get {x y z}]
            set idx 0
            set new_sum {}
            foreach atom $coords {
                foreach v $atom s [lrange $csum($c) $idx [expr {$idx + 2}]] {
                    lappend new_sum [expr {$s + $v}]
                }
                incr idx 3
            }
            set csum($c) $new_sum
            incr ccount($c)
        }
    } res opts]
    catch {$sel delete}
    if {$rc} { return -options $opts $res }

    # Divide sums by counts to get centroids
    for {set c 0} {$c < $nclusters} {incr c} {
        set n $ccount($c)
        if {$n == 0} {
            set centroid($c) $csum($c)
            continue
        }
        set avg {}
        foreach s $csum($c) {
            lappend avg [expr {$s / $n}]
        }
        set centroid($c) $avg
    }
}

# Compute pairwise MSD between cluster centroids
proc ::mdance::plots::compute_centroid_distances {results} {
    set nclusters [dict get $results nClusters]

    compute_centroids $results centroid natoms

    set dists {}
    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j [expr {$i + 1}]} {$j < $nclusters} {incr j} {
            set msd 0.0
            foreach ci $centroid($i) cj $centroid($j) {
                set d [expr {$ci - $cj}]
                set msd [expr {$msd + $d * $d}]
            }
            set msd [expr {$msd / $natoms}]
            lappend dists $i $j $msd
        }
    }

    return $dists
}

# Agglomerative clustering (average linkage) producing a scipy-style Z-matrix
proc ::mdance::plots::agglomerative_linkage {dists n} {
    # Build distance matrix as array dist(i,j) where i < j
    foreach {i j d} $dists {
        set dm($i,$j) $d
    }

    # Track active clusters and their sizes
    for {set i 0} {$i < $n} {incr i} {
        set active($i) 1
        set csize($i) 1
    }

    set zMatrix {}
    set next_id $n

    for {set step 0} {$step < [expr {$n - 1}]} {incr step} {
        # Find the closest pair among active clusters
        set best_d 1e300
        set best_i -1
        set best_j -1
        foreach key [array names dm] {
            lassign [split $key ,] ci cj
            if {[info exists active($ci)] && [info exists active($cj)]} {
                if {$dm($key) < $best_d} {
                    set best_d $dm($key)
                    set best_i $ci
                    set best_j $cj
                }
            }
        }

        # Merge best_i and best_j into next_id
        set ni $csize($best_i)
        set nj $csize($best_j)
        set new_size [expr {$ni + $nj}]

        lappend zMatrix [list $best_i $best_j $best_d $new_size]

        # Update distances: average linkage to new cluster
        unset active($best_i)
        unset active($best_j)

        foreach k [array names active] {
            # Get distance from k to best_i and best_j
            set di [expr {[info exists dm($k,$best_i)] ? $dm($k,$best_i) :
                          ([info exists dm($best_i,$k)] ? $dm($best_i,$k) : 1e300)}]
            set dj [expr {[info exists dm($k,$best_j)] ? $dm($k,$best_j) :
                          ([info exists dm($best_j,$k)] ? $dm($best_j,$k) : 1e300)}]
            # Average linkage: weighted average by cluster size
            set dm($k,$next_id) [expr {($di * $ni + $dj * $nj) / double($new_size)}]
        }

        # Clean up old entries involving best_i and best_j
        foreach key [array names dm "$best_i,*"] { unset dm($key) }
        foreach key [array names dm "*,$best_i"] { unset dm($key) }
        foreach key [array names dm "$best_j,*"] { unset dm($key) }
        foreach key [array names dm "*,$best_j"] { unset dm($key) }

        set active($next_id) 1
        set csize($next_id) $new_size
        incr next_id
    }

    return $zMatrix
}

proc ::mdance::plots::dendrogram {results {use_cache 0}} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_dendro
    variable data

    if {$use_cache && [info exists data(dendro)]} {
        lassign $data(dendro) zMatrix nMerges nClusters nLeaves is_helm
    } else {
        # Use existing Z-matrix (HELM) or compute one from cluster centroids
        if {[dict exists $results zMatrix]} {
            set zMatrix [dict get $results zMatrix]
            set nMerges [llength $zMatrix]
            set nClusters [dict get $results nClusters]
            set nLeaves [expr {$nMerges + $nClusters}]
            set is_helm 1
        } elseif {[dict exists $results molid] && [dict exists $results atomsel]} {
            set nClusters [dict get $results nClusters]
            if {$nClusters < 2} {
                tk_messageBox -icon warning -title "MDANCE" \
                    -message "Need at least 2 clusters for a dendrogram."
                return
            }
            if {[catch {compute_centroid_distances $results} dists]} {
                tk_messageBox -icon error -title "MDANCE" -message $dists
                return
            }
            set zMatrix [agglomerative_linkage $dists $nClusters]
            set nMerges [llength $zMatrix]
            set nLeaves $nClusters
            set is_helm 0
        } else {
            tk_messageBox -icon warning -title "MDANCE" \
                -message "No data available to build a dendrogram."
            return
        }
        set data(dendro) [list $zMatrix $nMerges $nClusters $nLeaves $is_helm]
    }

    # Build tree structure
    array set node_left {}
    array set node_right {}
    array set node_height {}
    array set node_x {}
    array set node_is_leaf {}

    # Initialize leaves
    for {set i 0} {$i < $nLeaves} {incr i} {
        set node_height($i) 0.0
        set node_is_leaf($i) 1
    }

    # Build from Z-matrix
    for {set i 0} {$i < $nMerges} {incr i} {
        set row [lindex $zMatrix $i]
        set left_id [expr {int([lindex $row 0])}]
        set right_id [expr {int([lindex $row 1])}]
        set dist [lindex $row 2]
        set new_id [expr {$nLeaves + $i}]

        set node_left($new_id) $left_id
        set node_right($new_id) $right_id
        set node_height($new_id) $dist
        set node_is_leaf($new_id) 0
    }

    # HELM stops merging once it has nClusters groups, so its Z-matrix describes
    # a FOREST of nClusters trees, not a single tree -- only when nClusters == 1
    # is the last merge the one root. Treating node (nLeaves + nMerges - 1) as
    # THE root laid out just that tree, leaving every other tree's leaves without
    # an x position, and the leaf-label loop below then died on node_x(0).
    # A root is any node that is never a child of a merge (an unmerged leaf is
    # its own single-node tree).
    array set is_child {}
    for {set i 0} {$i < $nMerges} {incr i} {
        set row [lindex $zMatrix $i]
        set is_child([expr {int([lindex $row 0])}]) 1
        set is_child([expr {int([lindex $row 1])}]) 1
    }
    set roots {}
    for {set id 0} {$id < $nLeaves + $nMerges} {incr id} {
        if {![info exists is_child($id)]} { lappend roots $id }
    }

    # Recursive layout: assign x-positions to leaves via in-order traversal,
    # carrying the leaf counter across trees so they sit side by side.
    set leaf_counter 0
    foreach root_id $roots {
        dendro_layout node_left node_right node_x node_is_leaf leaf_counter $root_id
    }

    # Find max height for y-axis scaling
    set max_height 0
    foreach {id h} [array get node_height] {
        if {$h > $max_height} { set max_height $h }
    }
    if {$max_height <= 0} { set max_height 1.0 }

    # Create canvas
    set canvas_w [expr {max(800, $nLeaves * 15 + 120)}]
    set w [create_plot_window mdance_dendro "Dendrogram" $canvas_w 500]
    set c $w.c

    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $canvas_w 500] cw ch
    # For dendrograms, canvas width may need to be larger than window
    if {$cw < $canvas_w} { set cw $canvas_w }
    $c configure -width $cw
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    if {$is_helm} {
        set title "Dendrogram (Merge Distance)"
        set y_label "Merge Distance"
        set x_label "Initial Cluster ID"
    } else {
        set title "Dendrogram (Centroid MSD)"
        set y_label "Centroid MSD"
        set x_label "Cluster ID"
    }

    draw_title $c $cw $title

    # Draw axes
    $c create line $x0 $y1 $x0 $y0 -width 2 -fill black
    $c create line $x0 $y1 $x1 $y1 -width 2 -fill black

    # Y-axis ticks
    draw_yticks $c $x0 $y0 $y1 0 $max_height 6 $x1

    # Map node x-positions and heights to canvas coordinates
    set x_scale [expr {$nLeaves > 1 ? double($plot_w) / ($nLeaves - 1) : $plot_w}]
    set leaf_margin [expr {$x_scale * 0.5}]

    # Draw U-shaped links by traversing each tree in the forest
    foreach root_id $roots {
        dendro_draw $c node_left node_right node_height node_x node_is_leaf \
            $root_id $x0 $y0 $y1 $x_scale $max_height $plot_h $leaf_margin $nLeaves
    }

    # Draw leaf labels
    for {set i 0} {$i < $nLeaves} {incr i} {
        set px [expr {$x0 + $leaf_margin + $node_x($i) * $x_scale}]
        $c create text $px [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -2]
    }

    # Axis labels
    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text $x_label -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text $y_label -anchor w -angle 90 -font [plot_font 0]

    # Scrollbar for wide dendrograms
    if {$cw > 800} {
        $c configure -scrollregion [list 0 0 $cw $ch]
        ttk::scrollbar $w.xsb -orient horizontal -command [list $c xview]
        $c configure -xscrollcommand [list $w.xsb set]
        pack $w.xsb -fill x -side bottom -before $c
    }

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_dendro) [list ::mdance::plots::dendrogram $results 1]
    set csv "left,right,distance,count\n"
    foreach row $zMatrix {
        append csv "[lindex $row 0],[lindex $row 1],[format "%.6f" [lindex $row 2]],[lindex $row 3]\n"
    }
    set ::mdance::plots::csv_data(mdance_dendro) $csv
}

# Recursive layout: in-order traversal assigns x to leaves
proc ::mdance::plots::dendro_layout {left_arr right_arr x_arr leaf_arr counter_var node_id} {
    upvar $left_arr nl $right_arr nr $x_arr nx $leaf_arr is_leaf $counter_var counter

    if {[info exists is_leaf($node_id)] && $is_leaf($node_id)} {
        set nx($node_id) $counter
        incr counter
        return $counter
    }

    set left_id $nl($node_id)
    set right_id $nr($node_id)

    dendro_layout nl nr nx is_leaf counter $left_id
    dendro_layout nl nr nx is_leaf counter $right_id

    set nx($node_id) [expr {($nx($left_id) + $nx($right_id)) / 2.0}]
    return $counter
}

# Draw U-shaped links recursively
proc ::mdance::plots::dendro_draw {c left_arr right_arr height_arr x_arr leaf_arr
                                    node_id x0 y0 y1 x_scale max_h plot_h leaf_margin nLeaves} {
    upvar $left_arr nl $right_arr nr $height_arr nh $x_arr nx $leaf_arr is_leaf

    if {[info exists is_leaf($node_id)] && $is_leaf($node_id)} return

    set left_id $nl($node_id)
    set right_id $nr($node_id)

    # Canvas coordinates
    set h $nh($node_id)
    set hl $nh($left_id)
    set hr $nh($right_id)

    set px_l [expr {$x0 + $leaf_margin + $nx($left_id) * $x_scale}]
    set px_r [expr {$x0 + $leaf_margin + $nx($right_id) * $x_scale}]

    set py   [expr {$y1 - $h / $max_h * $plot_h}]
    set py_l [expr {$y1 - $hl / $max_h * $plot_h}]
    set py_r [expr {$y1 - $hr / $max_h * $plot_h}]

    # U-shape: vertical from left child up, horizontal across, vertical down to right child
    $c create line $px_l $py_l $px_l $py -fill "#333333" -width 1.5
    $c create line $px_l $py $px_r $py -fill "#333333" -width 1.5
    $c create line $px_r $py_r $px_r $py -fill "#333333" -width 1.5

    # Recurse into children
    dendro_draw $c nl nr nh nx is_leaf $left_id $x0 $y0 $y1 $x_scale $max_h $plot_h $leaf_margin $nLeaves
    dendro_draw $c nl nr nh nx is_leaf $right_id $x0 $y0 $y1 $x_scale $max_h $plot_h $leaf_margin $nLeaves
}

# ============================================================
# Plot 5: Elbow Plot (Multi-K quality scores)
# ============================================================

# elbow_plot - Configure and launch an elbow scan.
#
# $algorithm pre-selects the method and hides the chooser, so the button on each
# algorithm tab scans THAT algorithm. Called with no argument the chooser is
# shown, which is what a generic entry point needs.
proc ::mdance::plots::elbow_plot {{algorithm ""}} {
    # Configuration dialog
    set w .mdance_elbow_cfg
    catch {destroy $w}
    toplevel $w
    wm title $w [expr {$algorithm eq "" ? "Elbow Plot Configuration" \
                                        : "Elbow Plot: [string toupper $algorithm]"}]
    wm geometry $w 400x340

    # Seed the defaults only the FIRST time. `variable name value` inside
    # namespace eval re-assigns on every call, so reopening the dialog used to
    # throw away the K range the user had just chosen.
    namespace eval ::mdance::plots::elbow {
        foreach {v d} {algorithm kmeans k_min 2 k_max 15 k_step 1} {
            variable $v
            if {![info exists $v]} { set $v $d }
        }
    }
    if {$algorithm ne ""} { set ::mdance::plots::elbow::algorithm $algorithm }

    ttk::labelframe $w.params -text "Parameters" -padding 10
    pack $w.params -fill x -padx 10 -pady 10

    # Only offer the chooser when the caller did not fix the algorithm.
    if {$algorithm eq ""} {
        ttk::label $w.params.l_algo -text "Algorithm:"
        ttk::combobox $w.params.algo -textvariable ::mdance::plots::elbow::algorithm \
            -values {kmeans divine helm} -state readonly -width 15
        grid $w.params.l_algo -row 0 -column 0 -sticky w -padx {0 10} -pady 3
        grid $w.params.algo -row 0 -column 1 -sticky w -pady 3
    }

    ttk::label $w.params.l_kmin -text "K min:"
    ttk::spinbox $w.params.kmin -textvariable ::mdance::plots::elbow::k_min \
        -from 2 -to 100 -width 8
    grid $w.params.l_kmin -row 1 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.params.kmin -row 1 -column 1 -sticky w -pady 3

    ttk::label $w.params.l_kmax -text "K max:"
    ttk::spinbox $w.params.kmax -textvariable ::mdance::plots::elbow::k_max \
        -from 2 -to 200 -width 8
    grid $w.params.l_kmax -row 2 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.params.kmax -row 2 -column 1 -sticky w -pady 3

    ttk::label $w.params.l_kstep -text "K step:"
    ttk::spinbox $w.params.kstep -textvariable ::mdance::plots::elbow::k_step \
        -from 1 -to 10 -width 8
    grid $w.params.l_kstep -row 3 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.params.kstep -row 3 -column 1 -sticky w -pady 3

    set note "Uses the current Setup tab molecule, atom selection and frame range."
    if {$::mdance::plots::elbow::algorithm eq "helm"} {
        # Say plainly what HELM's k means here, because it is not the same
        # operation the other two perform per k.
        append note "\n\nHELM is scanned by pre-clustering once with KMeans (using the HELM tab's pre-cluster settings) and then cutting the dendrogram at each K, so every point comes from the same starting partition."
    }
    ttk::label $w.note -text $note -justify left -wraplength 360
    pack $w.note -padx 10 -pady 5

    ttk::frame $w.btns -padding 10
    pack $w.btns -fill x -padx 10
    ttk::button $w.btns.run -text "Run Elbow Analysis" \
        -command [list ::mdance::plots::run_elbow_analysis $w]
    ttk::button $w.btns.cancel -text "Cancel" -command [list destroy $w]
    pack $w.btns.run -side left -padx 3
    pack $w.btns.cancel -side left -padx 3
}

proc ::mdance::plots::run_elbow_analysis {config_win} {
    variable ::mdance::plots::elbow::algorithm
    variable ::mdance::plots::elbow::k_min
    variable ::mdance::plots::elbow::k_max
    variable ::mdance::plots::elbow::k_step

    # Validate. A K step of 0 (or a non-numeric field -- these are plain entries)
    # turns the scan below into an unbounded loop that freezes VMD with no way to
    # interrupt it, so every field is checked before anything starts.
    if {![::mdance::gui::_chknum $k_min "K min" int 2]} return
    if {![::mdance::gui::_chknum $k_max "K max" int 2]} return
    if {![::mdance::gui::_chknum $k_step "K step" int 1]} return
    if {$k_min >= $k_max} {
        tk_messageBox -icon error -title "MDANCE" -message "K min must be less than K max."
        return
    }
    if {$::mdance::running} {
        tk_messageBox -icon info -title "MDANCE" -message "A run is already in progress."
        return
    }

    destroy $config_win

    # Get current settings
    set molid $::mdance::gui::mol_selection
    if {$molid eq "top"} {
        if {[catch {set molid [molinfo top]}]} {
            tk_messageBox -icon error -title "MDANCE" -message "No molecule loaded."
            return
        }
    }
    set atomsel $::mdance::gui::atom_selection

    # Take the run flag, arm cancellation and show the Cancel button BEFORE
    # extracting, not after.
    #
    # Extraction now services the event loop so its own progress shows and Cancel
    # works during it (see ::mdance::_extract_tick), and that is only safe while
    # ::mdance::running is held -- otherwise a Run click on any algorithm tab
    # would start a clustering run inside this extraction. Arming
    # cancel_requested first also matters: it is otherwise left set by whatever
    # was cancelled last, which would abort this extraction on its first tick.
    set ::mdance::running 1
    set ::mdance::cancel_requested 0
    ::mdance::gui::busy_start "Elbow plot: extracting coordinates..." 1

    # Extract coordinates once (respecting the Setup-tab frame range/stride)
    if {[catch {set extract [::mdance::extract_coordinates $molid $atomsel \
            $::mdance::gui::frame_first $::mdance::gui::frame_last $::mdance::gui::frame_stride]} err]} {
        ::mdance::gui::busy_stop
        ::mdance::utils::cleanup
        set ::mdance::running 0
        if {$err eq "Clustering cancelled."} {
            set ::mdance::status "Elbow plot cancelled."
        } else {
            set ::mdance::status "Ready"
            tk_messageBox -icon error -title "MDANCE" -message "Extraction failed: $err"
        }
        return
    }
    lassign $extract csv_path natoms nframes frame_list

    # Anything the algorithm needs computed once for the whole scan. For HELM
    # that is the starting partition -- its k is a cut of one dendrogram, so the
    # pre-cluster step belongs outside the loop.
    set extra {}
    if {[catch {
        set ::mdance::status "Elbow plot: preparing $algorithm..."
        update
        set extra [::mdance::elbow_prepare $algorithm $csv_path $natoms \
            [::mdance::gui::elbow_algo_params $algorithm]]
    } perr]} {
        ::mdance::gui::busy_stop
        catch {file delete $csv_path}
        ::mdance::utils::cleanup
        set ::mdance::running 0
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE" \
            -message "Could not prepare the $algorithm scan: $perr"
        return
    }

    # Run for each K (cancellable between K values via the shared status-bar
    # Cancel).
    set ::mdance::status "Elbow plot: starting..."
    set cancelled 0
    set data_points {}
    set failed_ks {}
    set first_err ""
    # Per-K partitions, kept so the user can inspect the population split at
    # every K rather than only reading two scores off the curve. Keyed by K.
    variable elbow_partitions
    array unset elbow_partitions
    array set elbow_partitions {}
    set rc [catch {
        for {set k $k_min} {$k <= $k_max} {set k [expr {$k + $k_step}]} {
            if {$::mdance::cancel_requested} { set cancelled 1; break }
            set ::mdance::status "Elbow plot: K=$k / $k_max..."
            update

            if {[catch {
                set result [::mdance::run_single_k $algorithm $csv_path $natoms $k $extra]
                set ch [dict get $result score_calinskiHarabasz]
                set db [dict get $result score_daviesBouldin]
                # A degenerate clustering yields NaN/Infinity scores. They must
                # not reach the chart: NaN makes the canvas coordinate arithmetic
                # raise and kills the whole plot after every K has been computed.
                if {![::mdance::utils::is_finite $ch] || ![::mdance::utils::is_finite $db]} {
                    error "backend returned a non-finite score (CH=$ch DB=$db)"
                }
                lappend data_points [list $k $ch $db]
                # Keep the partition, not the whole result: cluster sizes are
                # all the population view needs, and holding every K's labels
                # for a long scan would pin a lot of memory for the session.
                set sizes [expr {[dict exists $result clusterSizes] ? [dict get $result clusterSizes] : {}}]
                set kact  [expr {[dict exists $result nClusters] ? [dict get $result nClusters] : $k}]
                set elbow_partitions($k) [list $kact $sizes]
            } err]} {
                # Record the failure -- do NOT fabricate a data point. Appending
                # (K,0,0) here used to plot a real dot at zero, and since the
                # legend reads "Davies-Bouldin (lower=better)" a failed K rendered
                # as the visually optimal one, which is exactly the number the
                # user reads off this chart.
                lappend failed_ks $k
                if {$first_err eq ""} { set first_err $err }
            }
        }
        if {!$cancelled && [llength $data_points] > 0} {
            set ::mdance::status "Elbow plot: rendering..."
            update idletasks
            draw_elbow_chart $data_points $failed_ks
        }
    } eerr]

    # Always restore state, regardless of how the body exited.
    ::mdance::gui::busy_stop
    catch {file delete $csv_path}
    ::mdance::utils::cleanup
    set ::mdance::running 0

    if {$rc} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message "Elbow plot failed: $eerr"
        return
    }
    if {$cancelled} {
        set ::mdance::status "Elbow plot cancelled."
        return
    }
    set ::mdance::status "Ready"

    # Never let failed K values pass silently: they are missing from the chart,
    # so without this the user reads an elbow off an incomplete curve.
    if {[llength $data_points] == 0} {
        tk_messageBox -icon error -title "MDANCE Error" \
            -message "Every K in the scan failed, so there is nothing to plot.\n\nFirst error: $first_err"
    } elseif {[llength $failed_ks] > 0} {
        tk_messageBox -icon warning -title "MDANCE" \
            -message "Skipped K = [join $failed_ks {, }] (no usable score); the chart shows the remaining values.\n\nFirst error: $first_err"
    }
}

proc ::mdance::plots::draw_elbow_chart {data_points {failed_ks {}}} {
    variable current_plot
    set current_plot mdance_elbow

    set w [create_plot_window mdance_elbow "Cluster Quality vs. K" 750 500]
    set c $w.c
    # The shared toolbar has always exported this plot's data, but a generic
    # "Export CSV" does not read as "the scores" -- which is why the reviewer
    # asked for a button that already existed. Name it, reusing the same export.
    if {![winfo exists $w.toolbar.scores]} {
        ttk::button $w.toolbar.scores -text "Export Scores..." \
            -command [list ::mdance::plots::export_csv mdance_elbow]
        pack $w.toolbar.scores -side left -padx 2
    }
    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin

    lassign [canvas_dims $c 750 500] cw ch
    set right_margin_dual 80
    set x0 $left_margin; set x1 [expr {$cw - $right_margin_dual}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    # Carry the skipped-K caveat on the chart itself, so it survives being saved
    # or shown to someone who never saw the warning dialog.
    if {[llength $failed_ks] > 0} {
        draw_title $c $cw "Cluster Quality vs. K" \
            "K = [join $failed_ks {, }] skipped: no usable score"
    } else {
        draw_title $c $cw "Cluster Quality vs. K"
    }

    # Left and bottom axes
    $c create line $x0 $y1 $x0 $y0 -width 2 -fill "#2255cc"
    $c create line $x0 $y1 $x1 $y1 -width 2 -fill black
    # Right axis
    $c create line $x1 $y1 $x1 $y0 -width 2 -fill "#cc2222"

    # Extract ranges
    set ks {}; set chs {}; set dbs {}
    foreach pt $data_points {
        lappend ks [lindex $pt 0]
        lappend chs [lindex $pt 1]
        lappend dbs [lindex $pt 2]
    }

    set k_min [lindex $ks 0]
    set k_max [lindex $ks end]
    if {$k_max <= $k_min} { set k_max [expr {$k_min + 1}] }

    # CH range.
    # A single point, or several points that happen to share one value, gives a
    # zero-width range. Resetting that to [0,1] pushed the real value (say 4200)
    # far above the top of the plot; pad around the value instead so it lands in
    # the middle of the axis where it can actually be read.
    set ch_min 1e30; set ch_max -1e30
    foreach v $chs { if {$v < $ch_min} { set ch_min $v }; if {$v > $ch_max} { set ch_max $v } }
    if {$ch_max <= $ch_min} {
        set span [expr {abs($ch_min) > 0 ? abs($ch_min) * 0.1 : 1.0}]
        set ch_max [expr {$ch_min + $span}]
        set ch_min [expr {$ch_min - $span}]
    }
    set ch_pad [expr {($ch_max - $ch_min) * 0.1}]
    set ch_min [expr {$ch_min - $ch_pad}]
    set ch_max [expr {$ch_max + $ch_pad}]

    # DB range (same degenerate-range reasoning as CH above).
    set db_min 1e30; set db_max -1e30
    foreach v $dbs { if {$v < $db_min} { set db_min $v }; if {$v > $db_max} { set db_max $v } }
    if {$db_max <= $db_min} {
        set span [expr {abs($db_min) > 0 ? abs($db_min) * 0.1 : 1.0}]
        set db_max [expr {$db_min + $span}]
        set db_min [expr {$db_min - $span}]
    }
    set db_pad [expr {($db_max - $db_min) * 0.1}]
    set db_min [expr {$db_min - $db_pad}]
    set db_max [expr {$db_max + $db_pad}]

    # X-axis ticks
    foreach k $ks {
        set px [expr {$x0 + double($k - $k_min) / ($k_max - $k_min) * $plot_w}]
        $c create text $px [expr {$y1 + 5}] -text $k -anchor n -font [plot_font -1]
        $c create line $px $y1 $px [expr {$y1 + 4}] -fill black
    }

    # Left Y-axis ticks (CH - blue)
    set ch_ticks [nice_ticks $ch_min $ch_max 5]
    set ch_range [expr {$ch_max - $ch_min}]
    foreach v $ch_ticks {
        set py [expr {$y1 - ($v - $ch_min) / $ch_range * $plot_h}]
        $c create line [expr {$x0 - 5}] $py $x0 $py -fill "#2255cc"
        $c create text [expr {$x0 - 8}] $py -text [format "%.0f" $v] \
            -anchor e -font [plot_font -1] -fill "#2255cc"
    }

    # Right Y-axis ticks (DB - red)
    set db_ticks [nice_ticks $db_min $db_max 5]
    set db_range [expr {$db_max - $db_min}]
    foreach v $db_ticks {
        set py [expr {$y1 - ($v - $db_min) / $db_range * $plot_h}]
        $c create line $x1 $py [expr {$x1 + 5}] $py -fill "#cc2222"
        $c create text [expr {$x1 + 8}] $py -text [format "%.2f" $v] \
            -anchor w -font [plot_font -1] -fill "#cc2222"
    }

    # Draw CH line (blue) with dots
    set prev_px ""; set prev_py ""
    for {set i 0} {$i < [llength $data_points]} {incr i} {
        set k [lindex $ks $i]
        set ch_val [lindex $chs $i]
        set px [expr {$x0 + double($k - $k_min) / ($k_max - $k_min) * $plot_w}]
        set py [expr {$y1 - ($ch_val - $ch_min) / $ch_range * $plot_h}]
        if {$prev_px ne ""} {
            $c create line $prev_px $prev_py $px $py -fill "#2255cc" -width 2
        }
        $c create oval [expr {$px - 4}] [expr {$py - 4}] [expr {$px + 4}] [expr {$py + 4}] \
            -fill "#2255cc" -outline "#2255cc"
        # A generous invisible hit area over the whole column at this K, so the
        # partition view is reachable without pixel-hunting a 8px dot.
        set hit [$c create rectangle [expr {$px - 6}] $y0 [expr {$px + 6}] $y1 \
            -fill "" -outline ""]
        $c bind $hit <Enter> [list ::mdance::plots::elbow_show_partition $c $k $px $y0]
        $c bind $hit <Leave> [list ::mdance::plots::elbow_hide_partition $c]
        set prev_px $px; set prev_py $py
    }

    # Draw DB line (red) with dots
    set prev_px ""; set prev_py ""
    for {set i 0} {$i < [llength $data_points]} {incr i} {
        set k [lindex $ks $i]
        set db_val [lindex $dbs $i]
        set px [expr {$x0 + double($k - $k_min) / ($k_max - $k_min) * $plot_w}]
        set py [expr {$y1 - ($db_val - $db_min) / $db_range * $plot_h}]
        if {$prev_px ne ""} {
            $c create line $prev_px $prev_py $px $py -fill "#cc2222" -width 2
        }
        $c create oval [expr {$px - 4}] [expr {$py - 4}] [expr {$px + 4}] [expr {$py + 4}] \
            -fill "#cc2222" -outline "#cc2222"
        set prev_px $px; set prev_py $py
    }

    # Legend
    set lx [expr {$x0 + 20}]; set ly [expr {$y0 + 10}]
    $c create rectangle $lx $ly [expr {$lx + 15}] [expr {$ly + 3}] -fill "#2255cc" -outline ""
    $c create text [expr {$lx + 20}] $ly -text "Calinski-Harabasz (higher=better)" \
        -anchor nw -font [plot_font -1] -fill "#2255cc"
    $c create rectangle $lx [expr {$ly + 18}] [expr {$lx + 15}] [expr {$ly + 21}] \
        -fill "#cc2222" -outline ""
    $c create text [expr {$lx + 20}] [expr {$ly + 18}] -text "Davies-Bouldin (lower=better)" \
        -anchor nw -font [plot_font -1] -fill "#cc2222"

    # Axis labels
    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Number of Clusters (K)" \
        -anchor s -font [plot_font 0]
    # Say that the curve is interactive; a hover affordance nobody knows about
    # is the same as not having one.
    $c create text [expr {$cw - 8}] [expr {$ch - 5}] \
        -text "hover a K for its population split" \
        -anchor se -font [plot_font -3] -fill "#888888"

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_elbow) \
        [list ::mdance::plots::draw_elbow_chart $data_points $failed_ks]
    variable elbow_partitions
    set csv "k,k_actual,calinski_harabasz,davies_bouldin,cluster_sizes\n"
    foreach pt $data_points {
        set k [lindex $pt 0]
        set kact ""; set sizes {}
        if {[info exists elbow_partitions($k)]} {
            lassign $elbow_partitions($k) kact sizes
        }
        # The population split goes in the export as well, so the numbers behind
        # the hover view leave the plugin with the scores.
        append csv "$k,$kact,[format "%.6f" [lindex $pt 1]],[format "%.6f" [lindex $pt 2]],\"[join $sizes { }]\"\n"
    }
    # Skipped K values are recorded as blanks rather than dropped, so the CSV
    # cannot be mistaken for a complete scan.
    foreach k $failed_ks {
        append csv "$k,,,,\n"
    }
    set ::mdance::plots::csv_data(mdance_elbow) $csv
}

# elbow_show_partition - Draw the population split for one K next to the curve.
#
# The reviewer asked for a pie chart on hover. Horizontal population bars are
# used instead: at K = 30 a pie's slices are thin wedges with nowhere to put a
# label, whereas bars stay readable and directly comparable, and they reuse
# cluster_color so a cluster keeps the colour it has in every other plot.
#
# Everything is tagged so Leave can delete exactly this overlay, and nothing is
# cached on the canvas: a redraw or a resize rebuilds the chart from
# redraw_cmds, and an exported image therefore never depends on hover state.
proc ::mdance::plots::elbow_show_partition {c k px y0} {
    variable elbow_partitions
    if {![winfo exists $c]} return
    elbow_hide_partition $c
    if {![info exists elbow_partitions($k)]} return
    lassign $elbow_partitions($k) kact sizes
    if {[llength $sizes] == 0} return

    set total 0
    foreach n $sizes { incr total $n }
    if {$total <= 0} return

    set bw 130
    set bh 9
    set pad 6
    set n [llength $sizes]
    set boxh [expr {$n * $bh + 2 * $pad + 16}]
    # Flip to the left of the hovered column when the panel would run off the
    # right edge of the canvas.
    set bx [expr {$px + 12}]
    if {$bx + $bw + 2 * $pad > [winfo width $c]} {
        set bx [expr {$px - 12 - $bw - 2 * $pad}]
    }
    set by [expr {$y0 + 4}]

    $c create rectangle $bx $by [expr {$bx + $bw + 2 * $pad}] [expr {$by + $boxh}] \
        -fill "#ffffff" -outline "#888888" -tags elbowpart
    set label "K=$k"
    if {$kact ne "" && $kact ne $k} { append label " (got $kact)" }
    $c create text [expr {$bx + $pad}] [expr {$by + $pad}] -text $label \
        -anchor nw -font [plot_font -1] -tags elbowpart

    set ty [expr {$by + $pad + 16}]
    for {set i 0} {$i < $n} {incr i} {
        set frac [expr {double([lindex $sizes $i]) / $total}]
        set wpx [expr {$frac * $bw}]
        # Always leave a visible sliver: a cluster holding 0.1% of frames must
        # not vanish from a view whose whole purpose is showing the split.
        if {$wpx < 1} { set wpx 1 }
        set col [cluster_color $i $n]
        $c create rectangle [expr {$bx + $pad}] $ty \
            [expr {$bx + $pad + $wpx}] [expr {$ty + $bh - 2}] \
            -fill $col -outline $col -tags elbowpart
        $c create text [expr {$bx + $pad + $bw + 2}] [expr {$ty + ($bh - 2) / 2}] \
            -text [format "%.1f%%" [expr {100.0 * $frac}]] \
            -anchor w -font [plot_font -3] -tags elbowpart
        incr ty $bh
    }
}

proc ::mdance::plots::elbow_hide_partition {c} {
    if {[winfo exists $c]} { catch {$c delete elbowpart} }
}

# ============================================================
# Plot 6: Cluster Transition Heatmap
# ============================================================

proc ::mdance::plots::transition_heatmap {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_trans

    set labels [dict get $results labels]
    set nclusters [dict get $results nClusters]
    set nframes [dict get $results nFrames]

    if {$nframes < 2} {
        tk_messageBox -icon warning -title "MDANCE" -message "Need at least 2 frames for transitions."
        return
    }
    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    # Count transitions
    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            set tcount($i,$j) 0
        }
    }
    for {set f 0} {$f < [expr {$nframes - 1}]} {incr f} {
        set from [lindex $labels $f]
        set to [lindex $labels [expr {$f + 1}]]
        incr tcount($from,$to)
    }

    # Normalize rows to probabilities.
    #
    # The denominator must count EVERY transition leaving cluster i, including
    # those into noise (-1). Summing only columns 0..nclusters-1 divided by a
    # too-small total and inflated every probability on display -- with enough
    # noise, a rare transition could read as near-certain. Noise has no column of
    # its own, so rows now legitimately sum to less than 1 and the title says so.
    set has_noise 0
    set max_prob 0.0
    for {set i 0} {$i < $nclusters} {incr i} {
        set row_sum 0
        for {set j 0} {$j < $nclusters} {incr j} {
            incr row_sum $tcount($i,$j)
        }
        set noise_out($i) 0
        if {[info exists tcount($i,-1)] && $tcount($i,-1) > 0} {
            set noise_out($i) $tcount($i,-1)
            incr row_sum $noise_out($i)
            set has_noise 1
        }
        set row_total($i) $row_sum
        for {set j 0} {$j < $nclusters} {incr j} {
            if {$row_sum > 0} {
                set tprob($i,$j) [expr {double($tcount($i,$j)) / $row_sum}]
            } else {
                set tprob($i,$j) 0.0
            }
            if {$tprob($i,$j) > $max_prob} { set max_prob $tprob($i,$j) }
        }
    }
    if {$max_prob <= 0} { set max_prob 1.0 }

    # Canvas setup
    set legend_w 80
    set cw_default 650; set ch_default 550
    set w [create_plot_window mdance_trans "Cluster Transitions" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $legend_w - 20}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    if {$has_noise} {
        draw_title $c $cw "Cluster Transition Probabilities" \
            "rows sum to <1: transitions into noise are counted but have no column"
    } else {
        draw_title $c $cw "Cluster Transition Probabilities"
    }

    # Draw heatmap cells
    set cell_w [expr {double($plot_w) / $nclusters}]
    set cell_h [expr {double($plot_h) / $nclusters}]

    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            set cx0 [expr {$x0 + $j * $cell_w}]
            set cy0 [expr {$y0 + $i * $cell_h}]
            set cx1 [expr {$cx0 + $cell_w}]
            set cy1 [expr {$cy0 + $cell_h}]
            set color [heatmap_color $tprob($i,$j) 0 $max_prob]
            $c create rectangle $cx0 $cy0 $cx1 $cy1 -fill $color -outline gray80

            if {$nclusters <= 12} {
                set txt [format "%.2f" $tprob($i,$j)]
                set tx [expr {($cx0 + $cx1) / 2.0}]
                set ty [expr {($cy0 + $cy1) / 2.0}]
                set text_color [expr {$tprob($i,$j) > $max_prob * 0.6 ? "white" : "black"}]
                $c create text $tx $ty -text $txt -font [plot_font -2] -fill $text_color
            }
        }
    }

    # Axis labels
    for {set i 0} {$i < $nclusters} {incr i} {
        set py [expr {$y0 + ($i + 0.5) * $cell_h}]
        $c create text [expr {$x0 - 8}] $py -text $i -anchor e -font [plot_font -1]
        set px [expr {$x0 + ($i + 0.5) * $cell_w}]
        $c create text $px [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
    }

    $c create text [expr {($x0 + $x1) / 2}] [expr {$ch - 5}] -text "To Cluster" \
        -anchor s -font [plot_font 0]
    $c create text 12 [expr {($y0 + $y1) / 2}] -text "From Cluster" \
        -anchor w -angle 90 -font [plot_font 0]

    # Color legend
    draw_color_legend $c [expr {$x1 + 15}] $y0 $y1 0 $max_prob 5

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_trans) [list ::mdance::plots::transition_heatmap $results]
    set csv "from_cluster,to_cluster,probability\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            append csv "$i,$j,[format "%.6f" $tprob($i,$j)]\n"
        }
        # Emit the noise destination explicitly so the exported rows sum to 1
        # and nobody has to guess where the missing probability went.
        if {$has_noise} {
            set denom $row_total($i)
            set pn [expr {$denom > 0 ? double($noise_out($i)) / $denom : 0.0}]
            append csv "$i,-1,[format "%.6f" $pn]\n"
        }
    }
    set ::mdance::plots::csv_data(mdance_trans) $csv
}

# ============================================================
# Plot 7: Cluster Residence Time Chart
# ============================================================

proc ::mdance::plots::residence_chart {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_residence

    set labels [dict get $results labels]
    set nclusters [dict get $results nClusters]
    set nframes [dict get $results nFrames]

    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    # Compute consecutive run lengths per cluster
    for {set c 0} {$c < $nclusters} {incr c} {
        set runs($c) {}
    }

    set current_label [lindex $labels 0]
    set run_len 1
    for {set f 1} {$f < $nframes} {incr f} {
        set lbl [lindex $labels $f]
        if {$lbl == $current_label} {
            incr run_len
        } else {
            lappend runs($current_label) $run_len
            set current_label $lbl
            set run_len 1
        }
    }
    lappend runs($current_label) $run_len

    # Compute mean, min, max per cluster
    set max_val 0
    for {set c 0} {$c < $nclusters} {incr c} {
        set rlist $runs($c)
        if {[llength $rlist] == 0} {
            set rmean($c) 0; set rmin($c) 0; set rmax($c) 0
            continue
        }
        set total 0; set mn 1e30; set mx 0
        foreach r $rlist {
            set total [expr {$total + $r}]
            if {$r < $mn} { set mn $r }
            if {$r > $mx} { set mx $r }
        }
        set rmean($c) [expr {double($total) / [llength $rlist]}]
        set rmin($c) $mn
        set rmax($c) $mx
        if {$mx > $max_val} { set max_val $mx }
    }
    if {$max_val <= 0} { set max_val 1 }

    # Canvas setup
    set cw_default 700; set ch_default 500
    set w [create_plot_window mdance_residence "Residence Times" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    # Name the unit honestly: samples, and the frame equivalent when a stride
    # means the two differ.
    set res_stride 1
    if {[dict exists $results frames]} {
        set fl [dict get $results frames]
        if {[llength $fl] > 1} {
            set res_stride [expr {[lindex $fl 1] - [lindex $fl 0]}]
            if {$res_stride < 1} { set res_stride 1 }
        }
    }
    if {$res_stride > 1} {
        # The long form does not fit the rotated y-axis slot and gets clipped off
        # the canvas, so the qualifier goes in the title where there is room.
        set res_unit_label "Residence Time (samples)"
        set res_title "Cluster Residence Times"
        set res_sub "1 sample = $res_stride frames"
    } else {
        set res_unit_label "Residence Time (frames)"
        set res_title "Cluster Residence Times"
        set res_sub ""
    }

    draw_title $c $cw $res_title $res_sub
    draw_axes $c $x0 $y0 $x1 $y1
    draw_yticks $c $x0 $y0 $y1 0 $max_val 6 $x1

    # Draw bars (mean) with min/max whiskers
    set gap 4
    # Clamp: with many clusters the gaps alone exceed the plot width and this
    # goes negative, producing inverted rectangles Tk draws as artifacts.
    set bar_w [expr {($plot_w - ($nclusters + 1) * $gap) / double($nclusters)}]
    if {$bar_w < 1.0} {
        # Drop the gaps rather than forcing a minimum width: a 1px floor would
        # push the last bars past the right axis and off the canvas, silently
        # hiding clusters instead of just drawing them thin.
        set gap 0
        set bar_w [expr {$plot_w / double($nclusters)}]
    }

    for {set i 0} {$i < $nclusters} {incr i} {
        set bx0 [expr {$x0 + $gap + $i * ($bar_w + $gap)}]
        set bx1 [expr {$bx0 + $bar_w}]
        set by0 [expr {$y1 - $rmean($i) / $max_val * $plot_h}]
        set color [cluster_color $i $nclusters]
        $c create rectangle $bx0 $by0 $bx1 $y1 -fill $color -outline "#333333"

        # Min/max whiskers
        set mid_x [expr {($bx0 + $bx1) / 2.0}]
        set py_min [expr {$y1 - $rmin($i) / $max_val * $plot_h}]
        set py_max [expr {$y1 - $rmax($i) / $max_val * $plot_h}]
        if {$rmax($i) > $rmean($i)} {
            $c create line $mid_x $by0 $mid_x $py_max -fill "#333333" -width 1
            $c create line [expr {$mid_x - 4}] $py_max [expr {$mid_x + 4}] $py_max \
                -fill "#333333" -width 1
        }

        # Label
        $c create text $mid_x [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
        $c create text $mid_x [expr {$by0 - 4}] -text [format "%.1f" $rmean($i)] \
            -anchor s -font [plot_font -2]
    }

    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Cluster ID" \
        -anchor s -font [plot_font 0]
    # These are run lengths in SAMPLES (consecutive rows of the clustered
    # matrix). With a stride they are not frames: 3 samples at stride 10 spans 30
    # frames, so calling the axis "frames" understated every residence time.
    $c create text 12 [expr {$ch / 2}] -text $res_unit_label \
        -anchor w -angle 90 -font [plot_font 0]

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_residence) [list ::mdance::plots::residence_chart $results]
    set csv "cluster_id,mean_residence_samples,min_residence_samples,max_residence_samples\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        append csv "$i,[format "%.2f" $rmean($i)],$rmin($i),$rmax($i)\n"
    }
    set ::mdance::plots::csv_data(mdance_residence) $csv
}

# ============================================================
# Plot 8: Cluster Distance Heatmap
# ============================================================

proc ::mdance::plots::cluster_distance_heatmap {results {use_cache 0}} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_cdist
    variable data

    if {$use_cache && [info exists data(cdist)]} {
        lassign $data(cdist) nclusters dm_list max_dist
        array set dm $dm_list
    } else {
        if {![dict exists $results molid] || ![dict exists $results atomsel]} {
            tk_messageBox -icon warning -title "MDANCE" -message "No coordinate data available."
            return
        }

        set nclusters [dict get $results nClusters]
        if {$nclusters < 2} {
            tk_messageBox -icon warning -title "MDANCE" -message "Need at least 2 clusters."
            return
        }

        # Compute pairwise distances
        if {[catch {compute_centroid_distances $results} dists]} {
            tk_messageBox -icon error -title "MDANCE" -message $dists
            return
        }

        # Build NxN matrix
        for {set i 0} {$i < $nclusters} {incr i} {
            set dm($i,$i) 0.0
        }
        set max_dist 0.0
        foreach {i j d} $dists {
            set dm($i,$j) $d
            set dm($j,$i) $d
            if {$d > $max_dist} { set max_dist $d }
        }
        if {$max_dist <= 0} { set max_dist 1.0 }

        set data(cdist) [list $nclusters [array get dm] $max_dist]
    }

    # Canvas setup
    set legend_w 80
    set cw_default 650; set ch_default 550
    set w [create_plot_window mdance_cdist "Cluster Distances" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $legend_w - 20}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Inter-Cluster Distance (Centroid MSD)"

    set cell_w [expr {double($plot_w) / $nclusters}]
    set cell_h [expr {double($plot_h) / $nclusters}]

    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            set cx0 [expr {$x0 + $j * $cell_w}]
            set cy0 [expr {$y0 + $i * $cell_h}]
            set cx1 [expr {$cx0 + $cell_w}]
            set cy1 [expr {$cy0 + $cell_h}]
            set color [heatmap_color $dm($i,$j) 0 $max_dist]
            $c create rectangle $cx0 $cy0 $cx1 $cy1 -fill $color -outline gray80

            if {$nclusters <= 12} {
                set txt [format "%.2f" $dm($i,$j)]
                set tx [expr {($cx0 + $cx1) / 2.0}]
                set ty [expr {($cy0 + $cy1) / 2.0}]
                set text_color [expr {$dm($i,$j) > $max_dist * 0.6 ? "white" : "black"}]
                $c create text $tx $ty -text $txt -font [plot_font -2] -fill $text_color
            }
        }
    }

    # Axis labels
    for {set i 0} {$i < $nclusters} {incr i} {
        set py [expr {$y0 + ($i + 0.5) * $cell_h}]
        $c create text [expr {$x0 - 8}] $py -text $i -anchor e -font [plot_font -1]
        set px [expr {$x0 + ($i + 0.5) * $cell_w}]
        $c create text $px [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
    }

    $c create text [expr {($x0 + $x1) / 2}] [expr {$ch - 5}] -text "Cluster ID" \
        -anchor s -font [plot_font 0]
    $c create text 12 [expr {($y0 + $y1) / 2}] -text "Cluster ID" \
        -anchor w -angle 90 -font [plot_font 0]

    draw_color_legend $c [expr {$x1 + 15}] $y0 $y1 0 $max_dist 5

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_cdist) [list ::mdance::plots::cluster_distance_heatmap $results 1]
    set csv "cluster_i,cluster_j,distance\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            append csv "$i,$j,[format "%.6f" $dm($i,$j)]\n"
        }
    }
    set ::mdance::plots::csv_data(mdance_cdist) $csv
}

# ============================================================
# Plot 9: Representative Frame RMSD Matrix
# ============================================================

proc ::mdance::plots::representative_rmsd_matrix {results {use_cache 0}} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_reprmsd
    variable data

    if {$use_cache && [info exists data(reprmsd)]} {
        lassign $data(reprmsd) nclusters dm_list max_rmsd
        array set dm $dm_list
    } else {
        if {![dict exists $results molid] || ![dict exists $results atomsel]} {
            tk_messageBox -icon warning -title "MDANCE" -message "No coordinate data available."
            return
        }

        set molid [dict get $results molid]
        set sel_text [dict get $results atomsel]
        set reps [dict get $results representatives]
        set nclusters [dict get $results nClusters]

        # This view re-reads coordinates, so it needs the original molecule. A
        # session loaded without it (load_session says so explicitly) would
        # otherwise fail inside atomselect as a raw Tk background error.
        if {[lsearch -exact [molinfo list] $molid] < 0} {
            tk_messageBox -icon error -title "MDANCE" \
                -message "Source molecule $molid is no longer loaded."
            return
        }

        set sel [atomselect $molid $sel_text]
        set natoms [$sel num]
        if {$natoms == 0} {
            $sel delete
            tk_messageBox -icon error -title "MDANCE" -message "Atom selection matched 0 atoms."
            return
        }

        # Extract coordinates for each representative frame (always release $sel)
        set rc [catch {
            for {set i 0} {$i < $nclusters} {incr i} {
                set frame_idx [::mdance::abs_frame $results [lindex $reps $i]]
                if {$frame_idx < 0} {
                    set rep_valid($i) 0
                    set rep_coords($i) {}
                    continue
                }
                set rep_valid($i) 1
                set flat {}
                foreach atom [::mdance::_frame_coords $sel $sel_text $frame_idx $natoms] {
                    foreach v $atom { lappend flat $v }
                }
                set rep_coords($i) $flat
            }
        } res]
        catch {$sel delete}
        if {$rc} {
            tk_messageBox -icon error -title "MDANCE" -message "Could not read coordinates:\n$res"
            return
        }

        # Compute pairwise RMSD (empty clusters with no representative -> 0)
        set max_rmsd 0.0
        for {set i 0} {$i < $nclusters} {incr i} {
            set dm($i,$i) 0.0
            for {set j [expr {$i + 1}]} {$j < $nclusters} {incr j} {
                if {!$rep_valid($i) || !$rep_valid($j)} {
                    set dm($i,$j) 0.0
                    set dm($j,$i) 0.0
                    continue
                }
                set sum_sq 0.0
                foreach ci $rep_coords($i) cj $rep_coords($j) {
                    set d [expr {$ci - $cj}]
                    set sum_sq [expr {$sum_sq + $d * $d}]
                }
                set rmsd [expr {sqrt($sum_sq / $natoms)}]
                set dm($i,$j) $rmsd
                set dm($j,$i) $rmsd
                if {$rmsd > $max_rmsd} { set max_rmsd $rmsd }
            }
        }
        if {$max_rmsd <= 0} { set max_rmsd 1.0 }

        set data(reprmsd) [list $nclusters [array get dm] $max_rmsd]
    }

    # Canvas setup
    set legend_w 80
    set cw_default 650; set ch_default 550
    set w [create_plot_window mdance_reprmsd "Representative RMSD" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $legend_w - 20}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Representative Frame RMSD"

    set cell_w [expr {double($plot_w) / $nclusters}]
    set cell_h [expr {double($plot_h) / $nclusters}]

    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            set cx0 [expr {$x0 + $j * $cell_w}]
            set cy0 [expr {$y0 + $i * $cell_h}]
            set cx1 [expr {$cx0 + $cell_w}]
            set cy1 [expr {$cy0 + $cell_h}]
            set color [heatmap_color $dm($i,$j) 0 $max_rmsd]
            $c create rectangle $cx0 $cy0 $cx1 $cy1 -fill $color -outline gray80

            if {$nclusters <= 12} {
                set txt [format "%.2f" $dm($i,$j)]
                set tx [expr {($cx0 + $cx1) / 2.0}]
                set ty [expr {($cy0 + $cy1) / 2.0}]
                set text_color [expr {$dm($i,$j) > $max_rmsd * 0.6 ? "white" : "black"}]
                $c create text $tx $ty -text $txt -font [plot_font -2] -fill $text_color
            }
        }
    }

    for {set i 0} {$i < $nclusters} {incr i} {
        set py [expr {$y0 + ($i + 0.5) * $cell_h}]
        $c create text [expr {$x0 - 8}] $py -text $i -anchor e -font [plot_font -1]
        set px [expr {$x0 + ($i + 0.5) * $cell_w}]
        $c create text $px [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
    }

    $c create text [expr {($x0 + $x1) / 2}] [expr {$ch - 5}] -text "Cluster ID" \
        -anchor s -font [plot_font 0]
    $c create text 12 [expr {($y0 + $y1) / 2}] -text "Cluster ID" \
        -anchor w -angle 90 -font [plot_font 0]

    draw_color_legend $c [expr {$x1 + 15}] $y0 $y1 0 $max_rmsd 5

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_reprmsd) [list ::mdance::plots::representative_rmsd_matrix $results 1]
    set csv "cluster_i,cluster_j,rmsd\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        for {set j 0} {$j < $nclusters} {incr j} {
            append csv "$i,$j,[format "%.6f" $dm($i,$j)]\n"
        }
    }
    set ::mdance::plots::csv_data(mdance_reprmsd) $csv
}

# ============================================================
# Plot 10: MSD vs. Population Scatter
# ============================================================

proc ::mdance::plots::msd_vs_population {results} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }
    if {![dict exists $results clusterMSD]} {
        tk_messageBox -icon warning -title "MDANCE" -message "No cluster MSD data available."
        return
    }

    variable current_plot
    set current_plot mdance_msdpop

    set sizes [dict get $results clusterSizes]
    set msds [dict get $results clusterMSD]
    set nclusters [dict get $results nClusters]
    # Sibling plots all carry this guard; without it a 0-cluster result (every
    # frame rejected as noise) reaches the median computation below, where
    # lindex on an empty list yields "" and the expr raises an uncaught error.
    if {$nclusters < 1} {
        tk_messageBox -icon warning -title "MDANCE" -message "No clusters to plot."
        return
    }

    # Find ranges
    set x_min 1e30; set x_max 0; set y_min 1e30; set y_max 0
    for {set i 0} {$i < $nclusters} {incr i} {
        set s [lindex $sizes $i]
        set m [lindex $msds $i]
        if {$s < $x_min} { set x_min $s }
        if {$s > $x_max} { set x_max $s }
        if {$m < $y_min} { set y_min $m }
        if {$m > $y_max} { set y_max $m }
    }
    # Add 10% padding
    set x_pad [expr {($x_max - $x_min) * 0.1 + 1}]
    set y_pad [expr {($y_max - $y_min) * 0.1 + 0.001}]
    set x_min [expr {max(0, $x_min - $x_pad)}]
    set x_max [expr {$x_max + $x_pad}]
    set y_min [expr {max(0, $y_min - $y_pad)}]
    set y_max [expr {$y_max + $y_pad}]

    # Compute medians
    set sorted_sizes [lsort -real $sizes]
    set sorted_msds [lsort -real $msds]
    set mid [expr {$nclusters / 2}]
    if {$nclusters % 2 == 0} {
        set med_size [expr {([lindex $sorted_sizes [expr {$mid - 1}]] + [lindex $sorted_sizes $mid]) / 2.0}]
        set med_msd [expr {([lindex $sorted_msds [expr {$mid - 1}]] + [lindex $sorted_msds $mid]) / 2.0}]
    } else {
        set med_size [lindex $sorted_sizes $mid]
        set med_msd [lindex $sorted_msds $mid]
    }

    # Canvas setup
    set cw_default 700; set ch_default 500
    set w [create_plot_window mdance_msdpop "MSD vs Population" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Cluster Compactness vs. Population"
    draw_axes $c $x0 $y0 $x1 $y1
    draw_yticks $c $x0 $y0 $y1 $y_min $y_max 6 $x1
    draw_xticks $c $x0 $y1 $x1 $x_min $x_max 6

    set x_range [expr {$x_max - $x_min}]
    set y_range [expr {$y_max - $y_min}]
    if {$x_range <= 0} { set x_range 1.0 }
    if {$y_range <= 0} { set y_range 1.0 }

    # Median reference lines
    set med_px [expr {$x0 + ($med_size - $x_min) / $x_range * $plot_w}]
    set med_py [expr {$y1 - ($med_msd - $y_min) / $y_range * $plot_h}]
    $c create line $med_px $y0 $med_px $y1 -fill gray70 -dash {4 4}
    $c create line $x0 $med_py $x1 $med_py -fill gray70 -dash {4 4}

    # Draw points
    set radius 6
    for {set i 0} {$i < $nclusters} {incr i} {
        set s [lindex $sizes $i]
        set m [lindex $msds $i]
        set px [expr {$x0 + ($s - $x_min) / $x_range * $plot_w}]
        set py [expr {$y1 - ($m - $y_min) / $y_range * $plot_h}]
        set color [cluster_color $i $nclusters]
        $c create oval [expr {$px - $radius}] [expr {$py - $radius}] \
            [expr {$px + $radius}] [expr {$py + $radius}] \
            -fill $color -outline "#333333" -width 1
        $c create text [expr {$px + $radius + 3}] $py -text $i \
            -anchor w -font [plot_font -2]
    }

    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Cluster Population (frames)" \
        -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text "Within-Cluster MSD" \
        -anchor w -angle 90 -font [plot_font 0]

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_msdpop) [list ::mdance::plots::msd_vs_population $results]
    set csv "cluster_id,population,msd\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        append csv "$i,[lindex $sizes $i],[format "%.6f" [lindex $msds $i]]\n"
    }
    set ::mdance::plots::csv_data(mdance_msdpop) $csv
}

# ============================================================
# Plot 11: Silhouette Plot
# ============================================================

proc ::mdance::plots::silhouette_plot {results {use_cache 0}} {
    if {$results eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No results available."
        return
    }

    variable current_plot
    set current_plot mdance_silhouette
    variable data

    if {$use_cache && [info exists data(silhouette)]} {
        lassign $data(silhouette) ordered group_bounds mean_sil sampled total_bars nclusters
    } else {
        if {![dict exists $results molid] || ![dict exists $results atomsel]} {
            tk_messageBox -icon warning -title "MDANCE" -message "No coordinate data available."
            return
        }

        set nclusters [dict get $results nClusters]
        if {$nclusters < 2} {
            tk_messageBox -icon warning -title "MDANCE" \
                -message "Need at least 2 clusters for a silhouette plot."
            return
        }

        set molid [dict get $results molid]
        set sel_text [dict get $results atomsel]
        set labels [dict get $results labels]
        set nframes [dict get $results nFrames]

        # Compute centroids (errors cleanly on a 0-atom selection)
        if {[catch {compute_centroids $results centroid natoms} cerr]} {
            tk_messageBox -icon error -title "MDANCE" -message $cerr
            return
        }

        # Sampling: limit frames per cluster for performance
        set max_per_cluster 200
        set sampled 0
        for {set c 0} {$c < $nclusters} {incr c} {
            set frames_in($c) {}
        }
        for {set f 0} {$f < $nframes} {incr f} {
            lappend frames_in([lindex $labels $f]) $f
        }

        set sample_frames {}
        for {set c 0} {$c < $nclusters} {incr c} {
            set flist $frames_in($c)
            if {[llength $flist] > $max_per_cluster} {
                set sampled 1
                set step [expr {double([llength $flist]) / $max_per_cluster}]
                for {set i 0} {$i < $max_per_cluster} {incr i} {
                    set idx [expr {int($i * $step)}]
                    lappend sample_frames [lindex $flist $idx]
                }
            } else {
                foreach f $flist { lappend sample_frames $f }
            }
        }

        # Compute silhouette coefficients
        set sel [atomselect $molid $sel_text]
        set sil_data {}
        set total_sil 0.0
        set count 0

        set rc [catch {
        foreach f $sample_frames {
            set c [lindex $labels $f]
            $sel frame [::mdance::abs_frame $results $f]
            $sel update
            set coords [$sel get {x y z}]
            set flat {}
            foreach atom $coords {
                foreach v $atom { lappend flat $v }
            }

            # a = MSD to own centroid, b = min MSD to other centroids
            set a 0.0
            foreach fi $flat ci $centroid($c) {
                set d [expr {$fi - $ci}]
                set a [expr {$a + $d * $d}]
            }
            set a [expr {$a / $natoms}]

            set b 1e30
            for {set k 0} {$k < $nclusters} {incr k} {
                if {$k == $c} continue
                set dist_k 0.0
                foreach fi $flat ck $centroid($k) {
                    set d [expr {$fi - $ck}]
                    set dist_k [expr {$dist_k + $d * $d}]
                }
                set dist_k [expr {$dist_k / $natoms}]
                if {$dist_k < $b} { set b $dist_k }
            }

            set denom [expr {max($a, $b)}]
            if {$denom > 0} {
                set s [expr {($b - $a) / $denom}]
            } else {
                set s 0.0
            }

            lappend sil_data [list $c $s]
            set total_sil [expr {$total_sil + $s}]
            incr count

            if {$count % 100 == 0} {
                set ::mdance::status "Computing silhouettes: $count / [llength $sample_frames]..."
                update idletasks
            }
        }
        } res]
        catch {$sel delete}
        if {$rc} {
            tk_messageBox -icon error -title "MDANCE" -message "Could not read coordinates:\n$res"
            return
        }

        set mean_sil [expr {$count > 0 ? $total_sil / $count : 0.0}]

        # Group by cluster and sort descending within each group
        for {set c 0} {$c < $nclusters} {incr c} {
            set group($c) {}
        }
        foreach item $sil_data {
            lassign $item c s
            lappend group($c) $s
        }
        set ordered {}
        set group_bounds {}
        set idx 0
        for {set c 0} {$c < $nclusters} {incr c} {
            set sorted [lsort -real -decreasing $group($c)]
            set start $idx
            foreach s $sorted {
                lappend ordered [list $c $s]
                incr idx
            }
            lappend group_bounds [list $c $start $idx]
        }
        set total_bars [llength $ordered]

        # Cache computed data
        set data(silhouette) [list $ordered $group_bounds $mean_sil $sampled $total_bars $nclusters]
    }

    # Canvas setup
    set cw_default 700
    set ch_default [expr {max(500, $total_bars + 150)}]
    if {$ch_default > 800} { set ch_default 800 }
    set w [create_plot_window mdance_silhouette "Silhouette Plot" $cw_default $ch_default]
    set c $w.c

    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin
    lassign [canvas_dims $c $cw_default $ch_default] cw ch
    set x0 [expr {$left_margin + 20}]
    set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    set sil_sub [format "mean = %.3f" $mean_sil]
    if {$sampled} { append sil_sub " (sampled)" }
    draw_title $c $cw "Silhouette Plot" $sil_sub

    # X-axis: silhouette coefficient [-1, 1]
    set sil_min -1.0; set sil_max 1.0
    set sil_range 2.0

    # Draw axes
    $c create line $x0 $y1 $x0 $y0 -width 2 -fill black
    $c create line $x0 $y1 $x1 $y1 -width 2 -fill black
    draw_xticks $c $x0 $y1 $x1 $sil_min $sil_max 5

    # Zero line
    set zero_x [expr {$x0 + (0 - $sil_min) / $sil_range * $plot_w}]
    $c create line $zero_x $y0 $zero_x $y1 -fill gray70 -dash {2 4}

    # Mean silhouette line
    set mean_x [expr {$x0 + ($mean_sil - $sil_min) / $sil_range * $plot_w}]
    $c create line $mean_x $y0 $mean_x $y1 -fill red -dash {6 3} -width 1.5

    # Draw horizontal bars
    set bar_h [expr {$total_bars > 0 ? double($plot_h) / $total_bars : 1}]
    if {$bar_h > 5} { set bar_h 5 }

    for {set i 0} {$i < $total_bars} {incr i} {
        lassign [lindex $ordered $i] cl sv
        set by0 [expr {$y0 + $i * $bar_h}]
        set by1 [expr {$by0 + $bar_h}]
        set bx [expr {$x0 + ($sv - $sil_min) / $sil_range * $plot_w}]
        set color [cluster_color $cl $nclusters]
        $c create rectangle $zero_x $by0 $bx $by1 -fill $color -outline ""
    }

    # Cluster labels on left
    foreach gb $group_bounds {
        lassign $gb cl start end
        if {$end <= $start} continue
        set mid_y [expr {$y0 + ($start + $end) / 2.0 * $bar_h}]
        $c create text [expr {$x0 - 5}] $mid_y -text "C$cl" -anchor e -font [plot_font -2]
        # Separator line
        if {$start > 0} {
            set sep_y [expr {$y0 + $start * $bar_h}]
            $c create line $x0 $sep_y $x1 $sep_y -fill gray80 -dash {1 3}
        }
    }

    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Silhouette Coefficient" \
        -anchor s -font [plot_font 0]

    # Scrollbar for tall plots
    if {$total_bars * $bar_h > $plot_h} {
        set scroll_h [expr {int($total_bars * $bar_h + $y0 + $bottom_margin)}]
        $c configure -scrollregion [list 0 0 $cw $scroll_h] -height $ch
        ttk::scrollbar $w.ysb -orient vertical -command [list $c yview]
        $c configure -yscrollcommand [list $w.ysb set]
        pack $w.ysb -side right -fill y -before $c
    }

    # Store redraw command and CSV data
    set ::mdance::plots::redraw_cmds(mdance_silhouette) [list ::mdance::plots::silhouette_plot $results 1]
    set csv "cluster_id,silhouette_coefficient\n"
    foreach item $ordered {
        lassign $item cl sv
        append csv "$cl,[format "%.6f" $sv]\n"
    }
    set ::mdance::plots::csv_data(mdance_silhouette) $csv

    set ::mdance::status "Done"
}

# ============================================================
# Plot 12: Per-Cluster Extended-Similarity (iSIM) Compactness
# ============================================================
#
# results  - clustering result dict (for nClusters, representatives, frames)
# analysis - dict from ::mdance::run_analysis {isim clusterISIM clusterOutliers}
proc ::mdance::plots::similarity_chart {results analysis} {
    if {$results eq "" || $analysis eq ""} {
        tk_messageBox -icon warning -title "MDANCE" -message "No analysis available."
        return
    }

    variable current_plot
    set current_plot mdance_isim

    set isim [dict get $analysis isim]
    set comp [dict get $analysis clusterISIM]
    set outliers [expr {[dict exists $analysis clusterOutliers] ? [dict get $analysis clusterOutliers] : {}}]
    set reps [dict get $results representatives]
    set nclusters [llength $comp]
    if {$nclusters == 0} {
        tk_messageBox -icon warning -title "MDANCE" \
            -message "No per-cluster similarity data (analysis needs cluster labels)."
        return
    }

    set w [create_plot_window mdance_isim "Cluster Compactness (iSIM)" 720 500]
    set c $w.c
    variable left_margin; variable right_margin; variable top_margin; variable bottom_margin

    lassign [canvas_dims $c 720 500] cw ch
    set x0 $left_margin; set x1 [expr {$cw - $right_margin}]
    set y0 $top_margin; set y1 [expr {$ch - $bottom_margin}]
    set plot_w [expr {$x1 - $x0}]; set plot_h [expr {$y1 - $y0}]

    draw_title $c $cw "Per-Cluster Compactness" \
        [format "ensemble iSIM = %.4g" $isim]
    draw_axes $c $x0 $y0 $x1 $y1

    set max_c 0
    foreach v $comp { if {$v > $max_c} { set max_c $v } }
    if {$max_c <= 0} { set max_c 1.0 }
    draw_yticks $c $x0 $y0 $y1 0 $max_c 6 $x1

    set gap 4
    set bar_w [expr {(double($plot_w) - $gap * ($nclusters + 1)) / $nclusters}]
    if {$bar_w < 2} { set bar_w 2 }

    for {set i 0} {$i < $nclusters} {incr i} {
        set v [lindex $comp $i]
        set bx0 [expr {$x0 + $gap + $i * ($bar_w + $gap)}]
        set bx1 [expr {$bx0 + $bar_w}]
        set by0 [expr {$y1 - $v / $max_c * $plot_h}]
        set color [cluster_color $i $nclusters]
        $c create rectangle $bx0 $by0 $bx1 $y1 -fill $color -outline black -width 1
        set mid_x [expr {($bx0 + $bx1) / 2.0}]
        $c create text $mid_x [expr {$y1 + 5}] -text $i -anchor n -font [plot_font -1]
        if {$bar_w > 24} {
            $c create text $mid_x [expr {$by0 - 4}] -text [format "%.3g" $v] \
                -anchor s -font [plot_font -2]
        }
    }

    $c create text [expr {$cw / 2}] [expr {$ch - 5}] -text "Cluster ID" \
        -anchor s -font [plot_font 0]
    $c create text 12 [expr {$ch / 2}] -text "Compactness (lower = tighter)" \
        -anchor w -angle 90 -font [plot_font 0]

    set ::mdance::plots::redraw_cmds(mdance_isim) \
        [list ::mdance::plots::similarity_chart $results $analysis]
    set csv "cluster_id,compactness_isim,medoid_frame,outlier_frame\n"
    for {set i 0} {$i < $nclusters} {incr i} {
        set medoid [::mdance::abs_frame $results [lindex $reps $i]]
        set ol [expr {$i < [llength $outliers] ? [::mdance::abs_frame $results [lindex $outliers $i]] : -1}]
        append csv "$i,[format "%.6f" [lindex $comp $i]],$medoid,$ol\n"
    }
    set ::mdance::plots::csv_data(mdance_isim) $csv
}
