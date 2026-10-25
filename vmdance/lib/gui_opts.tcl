#
# VMDance - the Plot options panel (right) and showing or hiding the
# side panels
#
# The panel shows every setting of the current plot tab, and the settings
# shared by all plots. While it is shown, the short option row above the
# plots is hidden, so that each setting has one place.
#

namespace eval ::VMDance::GUI {
    # kind key label ?arg ...?  (combo: mapping; spin: from to; entry: tip)
    # ?-when condition?
    variable optspec {
        populations {
            {combo po_show "Show" {count "Frames" percent "Share of the frames"}}
            {combo po_sort "Order" {cluster "Cluster" size "Size, largest first"}}
            {check po_noise "Noise (eQUAL's frames outside every cluster)"}
        }
        makeup {
            {combo mu_view "Bars" {clusters "Clusters by group" groups "Groups by cluster"}}
            {combo mu_show "Show" {count "Frames" share "Shares"}}
        }
        timeline {
            {combo tl_view "Show" {lanes "The cluster of every frame" msd "Distance to its representative"}}
            {entry tl_bar "Bar height" "The height of the bars, as a share of a cluster's lane (above 0, at most 1)" -when {$S(tl_view) eq "lanes"}}
            {check plot_cursor "Current-frame marker"}
        }
        transitions {
            {combo tn_show "Show" {probability "Probabilities" counts "Counts"}}
            {spin tn_lag "Lag (clustered frames)" 1 10000}
            {check tn_self "Staying (the diagonal)"}
            {palette tn_cmap "Colours"}
            {check mx_values "Values in the cells"}
        }
        residence {
            {combo rs_show "Show" {mean "Mean stay (whisker: the longest)" visits "Visits"}}
            {combo rs_unit "In" {clustered "Clustered frames" vmd "VMD frames (× the step)"} -when {$S(rs_show) eq "mean"}}
        }
        compactness {
            {combo cp_show "Show" {msd "MSD within" spread "RMSD² from the representative" scatter "MSD against size" isim "Extended similarity (iSIM)"}}
        }
        distances {
            {combo ds_show "Between" {centroids "Mean structures (RMSD²)" representatives "Representatives (RMSD)"}}
            {palette ds_cmap "Colours"}
            {check mx_values "Values in the cells"}
        }
        tree {
            {combo td_view "Show" {tree "The tree" heights "The merges' heights"}}
            {check td_labels "Leaf labels" -when {$S(td_view) eq "tree"}}
        }
        silhouette {
            {check sl_sort "Sorted within each cluster"}
            {check sl_mean "The mean"}
        }
        map {
            {combo mp_colour "Colour by" {group "Group" cluster "Cluster"}}
        }
        profiles {
            {combo pf_show "Show" {groups "Each group's fluctuations" clusters "Each cluster's fluctuations" differences "Each cluster against the reference"}}
        }
        elbow {
            {combo eb_show "Scores" {both "Both" ch "Calinski–Harabasz" db "Davies–Bouldin"}}
            {check eb_stability "Stability (bars), when the scan has it"}
            {check eb_partition "The clusters' shares under the pointer"}
        }
        sweep {
            {combo sw_score "Score" {ch "Calinski–Harabasz" db "Davies–Bouldin"}}
            {palette sw_cmap "Colours"}
            {check mx_values "Values in the cells"}
        }
    }
    variable optwhen {}
    variable optall {
        {check plot_grid "Grid lines"}
        {check plot_legend "Legends"}
        {combo plot_lw "Line width" {1 Thin 1.4 Normal 2 Thick 3 Heavy}}
        {combo plot_ccol "Cluster colours" {muted "Darker tones" vmd "VMD's (as in the 3D window)"}}
    }
    variable opttips {
        po_show "The frames of each cluster, or their share of the frames clustered"
        po_sort "The bars in the order of the clusters, or largest first"
        mu_view "Each cluster's frames by group, or each group's frames by cluster"
        mu_show "The frames, or their share of the bar's"
        mp_colour "The frames coloured by their group (Results ▸ Groups), or by their cluster"
        pf_show "Residue by residue: each group's RMSF about its mean structure, each cluster's, or the distance of each cluster's mean structure from the reference cluster's"
        eb_stability "How alike the clusterings of NANI's four seedings are at each k (the mean adjusted Rand index: 1, the same clusters), when the scan was made with Stability"
        tl_view "Each cluster's lane, with a bar where the trajectory is in it; or every frame's RMSD² from its cluster's representative"
        tn_show "From each cluster (rows) to the cluster lag clustered frames later (columns): the share of the frames that go there (the rest into noise), or their number"
        tn_lag "How many clustered frames later the transition is counted"
        tn_self "The diagonal (staying in a cluster) shaded too: off, the colours show the moves only"
        rs_show "How long the trajectory stays in a cluster once it enters it (the mean of its runs of frames, the whisker to the longest), or how many times it enters it"
        cp_show "The backend's mean square deviation within each cluster (MDANCE's MSD: the mean RMSD² over its pairs of frames, each with itself too); the mean RMSD² of its frames from its representative (lower: from half the MSD to all of it, with the metric MSD); the MSD against the cluster's size (dashed: the medians); or MDANCE's extended similarity (Tools ▸ Similarity)"
        ds_show "The RMSD² between the clusters' mean structures, or the RMSD between their representatives (no fit)"
        sl_sort "Each cluster's frames from its best to its worst silhouette"
        td_view "The dendrogram; or the height of each merge against the clusters before it (HELM's: the MSD of the cluster it makes; the linkage's: the RMSD² between the mean structures it joins): a merge far above the one before joins clusters far apart"
        eb_show "Calinski–Harabasz (higher: better) and Davies–Bouldin (lower: better), each on its own axis"
        sw_score "The score shaded: the best configuration is outlined"
        mx_values "The value of each cell, when it has room"
        plot_cursor "The red line that follows VMD's frame"
        plot_ccol "The plugin's darker tones of the clusters' hues, or VMD's own colours of the 3D window (the same hues, brighter)"
    }
    variable optdefaults [array get S]
}

proc ::VMDance::GUI::_build_opts {} {
    variable w; variable tabs; variable optspec; variable optall
    variable optwhen {}
    set O [ttk::frame $w.pw.opts -padding {4 0 0 0}]
    set h [ttk::frame $O.head]
    pack $h -side top -fill x -pady {2 6}
    ttk::label $h.title -style Section.TLabel -text "Plot options"
    ttk::button $h.close -text "✕" -style Toolbutton -takefocus 0 -command {::VMDance::GUI::act toggle_opts}
    pack $h.close -side right
    pack $h.title -side left -fill x -expand 1
    ::VMDance::Tip::add $h.close "Hide the plot options ($::VMDance::GUI::modlabel+Shift+O)"
    set B [ttk::frame $O.body -style Holder.TFrame]
    pack $B -side top -fill x
    foreach {key title} $tabs {
        set box [_section $B.$key $title -padding {6 4}]
        set img [::VMDance::Icons::get tab_$key 16]
        if {$img ne ""} { $B.${key}_title configure -image $img -compound left }
        set r 0
        foreach spec [dict get $optspec $key] { incr r [_opt_row $box $r $spec] }
        grid columnconfigure $box 1 -weight 1
    }
    set box [_section $O.all "All plots" -padding {6 4}]
    pack ${box}_sec -side top -fill x -pady {8 0}
    set r 0
    foreach spec $optall { incr r [_opt_row $box $r $spec] }
    grid columnconfigure $box 1 -weight 1
    ttk::frame $O.b
    ttk::button $O.b.reset -text "Reset this plot" -command ::VMDance::GUI::reset_plot_options
    pack $O.b.reset -side left
    pack $O.b -side top -fill x -pady {8 0}
    ::VMDance::Tip::add $O.b.reset "Back to the default settings of this plot"
    _opts_show_tab
}

proc ::VMDance::GUI::_opt_row {box r spec} {
    variable opttips; variable optwhen
    set V ::VMDance::GUI::S
    set when ""
    if {[set i [lsearch -exact $spec -when]] >= 0} {
        set when [lindex $spec [expr {$i + 1}]]
        set spec [lreplace $spec $i [expr {$i + 1}]]
    }
    lassign $spec kind key label a b
    switch -- $kind {
        combo {
            ttk::label $box.l$r -text $label
            _combo $box.c$r ${V}($key) $a ::VMDance::GUI::_rows_changed
            grid $box.l$r $box.c$r -row $r -sticky w -padx {0 6} -pady 1
            grid configure $box.c$r -sticky ew
        }
        palette {
            ttk::label $box.l$r -text $label
            _palette $box.c$r ${V}($key)
            grid $box.l$r $box.c$r -row $r -sticky w -padx {0 6} -pady 1
            grid configure $box.c$r -sticky ew
        }
        check {
            ttk::checkbutton $box.c$r -text $label -variable ${V}($key) -command ::VMDance::GUI::redraw
            grid $box.c$r -row $r -column 0 -columnspan 2 -sticky w -pady 1
        }
        spin {
            ttk::label $box.l$r -text $label
            ttk::spinbox $box.c$r -from $a -to $b -increment 1 -width 5 -textvariable ${V}($key) \
                -command [list ::VMDance::GUI::_opt_entry $key]
            foreach ev {<Return> <FocusOut>} { bind $box.c$r $ev [list ::VMDance::GUI::_opt_entry $key] }
            grid $box.l$r $box.c$r -row $r -sticky w -padx {0 6} -pady 1
        }
        entry {
            ttk::label $box.l$r -text $label
            ttk::entry $box.c$r -width 7 -textvariable ${V}($key)
            foreach ev {<Return> <FocusOut>} { bind $box.c$r $ev [list ::VMDance::GUI::_opt_entry $key] }
            grid $box.l$r $box.c$r -row $r -sticky w -padx {0 6} -pady 1
            if {$a ne ""} { ::VMDance::Tip::add $box.c$r $a }
        }
    }
    if {[dict exists $opttips $key]} {
        foreach wd [list $box.c$r $box.l$r] { if {[winfo exists $wd]} { ::VMDance::Tip::add $wd [dict get $opttips $key] } }
    }
    if {$when ne ""} {
        lappend optwhen [list [lmap wd [list $box.l$r $box.c$r] {expr {[winfo exists $wd] ? $wd : [continue]}}] $when]
    }
    return 1
}

proc ::VMDance::GUI::_opts_update_rows {} {
    variable optwhen; variable S
    foreach e $optwhen {
        lassign $e widgets cond
        set on [expr $cond]
        foreach wd $widgets { if {$on} { grid $wd } else { grid remove $wd } }
    }
}

proc ::VMDance::GUI::_rows_changed {} {
    _opts_update_rows
    _opts_show_tab
    redraw_soon
    # (the cluster colours are also the table's and the 3D key's)
    populate_tree
    _colour_key
}

# A palette chooser: the palette's swatch and name, and a menu of every
# palette by kind, with "Reversed".
proc ::VMDance::GUI::_palette {path var {cmd ""}} {
    set id [_palid $var]
    ttk::menubutton $path -menu $path.m -width 14 -compound left
    menu $path.m -tearoff 0
    foreach {cat title} $::VMDance::Cmap::categories {
        if {$cat eq "qualitative"} continue
        $path.m add command -label $title -state disabled
        foreach k [::VMDance::Cmap::names $cat] {
            $path.m add radiobutton -label [::VMDance::Cmap::label $k] -image [::VMDance::Cmap::swatch $k 48 10] \
                -compound left -variable ::VMDance::GUI::palbase($id) -value $k \
                -command [list ::VMDance::GUI::_palette_set $var $cmd]
        }
    }
    $path.m add separator
    $path.m add checkbutton -label "Reversed" -variable ::VMDance::GUI::palrev($id) \
        -command [list ::VMDance::GUI::_palette_set $var $cmd]
    trace add variable $var write [list ::VMDance::GUI::_palette_sync $path $var]
    _palette_sync $path $var
    return $path
}
proc ::VMDance::GUI::_palid {var} { string map {( _ ) _ : _} $var }
proc ::VMDance::GUI::_palette_sync {path var args} {
    variable palbase; variable palrev
    if {![winfo exists $path]} {
        trace remove variable $var write [list ::VMDance::GUI::_palette_sync $path $var]
        return
    }
    set id [_palid $var]
    set v [set $var]
    set r [::VMDance::Cmap::resolve $v]
    if {$r eq ""} { set r {viridis 0}; set v viridis }
    lassign $r palbase($id) palrev($id)
    $path configure -text [::VMDance::Cmap::label $v] -image [::VMDance::Cmap::swatch $v 36 10]
}
proc ::VMDance::GUI::_palette_set {var cmd} {
    variable palbase; variable palrev
    set id [_palid $var]
    set v $palbase($id)
    if {$palrev($id)} { append v _r }
    set $var $v
    if {$cmd ne ""} { uplevel #0 $cmd } else { redraw }
}

# Validate a typed setting; an invalid one goes back to its default.
proc ::VMDance::GUI::_opt_entry {key} {
    variable S; variable optdefaults
    set v [string trim $S($key)]
    switch -- $key {
        tn_lag {
            if {![regexp {^[1-9][0-9]*$} $v] || $v > 10000} {
                set S($key) [dict get $optdefaults $key]
                status "Lag: a whole number of clustered frames, 1 or more."
            } else {
                # (as checked: " 5" kept would be refused when a session reopens)
                set S($key) $v
            }
        }
        tl_bar {
            if {![string is double -strict $v] || [regexp -nocase {nan|inf} $v] || $v <= 0 || $v > 1} {
                set S($key) [dict get $optdefaults $key]
                status "Bar height: a share of the lane, above 0 and at most 1."
            }
        }
    }
    redraw
}

proc ::VMDance::GUI::_opts_show_tab {} {
    variable w; variable tabs; variable S
    set O $w.pw.opts
    if {![winfo exists $O]} return
    set key $S(tab)
    foreach {k t} $tabs {
        if {$k eq $key} {
            if {[winfo manager $O.body.${k}_sec] eq ""} { pack $O.body.${k}_sec -side top -fill x }
        } else {
            pack forget $O.body.${k}_sec
        }
    }
    _opts_size
}

proc ::VMDance::GUI::_opts_size {} {
    variable w; variable tabs; variable S
    set B $w.pw.opts.body
    _opts_update_rows
    update idletasks
    set mw 0
    foreach {k t} $tabs { set mw [expr {max($mw, [winfo reqwidth $B.${k}_sec])}] }
    pack propagate $B 0
    $B configure -width $mw -height [winfo reqheight $B.$S(tab)_sec]
    if {$S(show_opts) && [winfo ismapped $w]} {
        _minsize {*}[needed_size]
    }
}

proc ::VMDance::GUI::reset_plot_options {} {
    variable S; variable optspec; variable optdefaults
    foreach spec [dict get $optspec $S(tab)] {
        set k [lindex $spec 1]
        if {[dict exists $optdefaults $k]} { set S($k) [dict get $optdefaults $k] }
    }
    _opts_show_tab
    redraw
    status "[dict get $::VMDance::GUI::tabs $S(tab)]: default settings."
}

#---------------------------------------------------------------------------
# Side panels
#---------------------------------------------------------------------------

proc ::VMDance::GUI::toggle_left {} { variable S; set S(show_left) [expr {!$S(show_left)}]; panels_changed }
proc ::VMDance::GUI::toggle_opts {} { variable S; set S(show_opts) [expr {!$S(show_opts)}]; panels_changed }

proc ::VMDance::GUI::panels_changed {} {
    _panes
    save_prefs
}

proc ::VMDance::GUI::_panes {} {
    variable w
    if {![winfo exists $w.pw.opts]} return
    _panes_arrange
    _minsize {*}[needed_size]
    update idletasks
    # (a plot whose size this changes is drawn again by its canvas's
    # <Configure>: one that keeps it needs no other draw)
    _layout_panes
}

proc ::VMDance::GUI::_panes_arrange {} {
    variable w; variable S; variable tabs
    set want {}
    if {$S(show_left)} { lappend want $w.pw.left }
    lappend want $w.pw.right
    if {$S(show_opts)} { lappend want $w.pw.opts }
    set have [$w.pw panes]
    if {$have ne $want} {
        foreach p $have { $w.pw forget $p }
        foreach p $want { $w.pw add $p -weight [expr {$p eq "$w.pw.right" ? 1 : 0}] }
    }
    foreach {key title} $tabs {
        set f $w.pw.right.nb.$key
        if {$S(show_opts)} {
            pack forget $f.opts
        } elseif {![winfo ismapped $f.opts] && [winfo manager $f.opts] eq ""} {
            pack $f.opts -side top -fill x -before $f.c
        }
    }
    _opts_show_tab
}

proc ::VMDance::GUI::_layout_panes {} {
    variable w
    set panes [$w.pw panes]
    set n [llength $panes]
    if {$n < 2} return
    if {[lindex $panes 0] eq "$w.pw.left"} {
        catch {$w.pw sashpos 0 [winfo reqwidth $w.pw.left]}
    }
    if {[lindex $panes end] eq "$w.pw.opts"} {
        catch {$w.pw sashpos [expr {$n - 2}] [expr {[winfo width $w.pw] - [winfo reqwidth $w.pw.opts] - 8}]}
    }
    _clamp_sash
}
