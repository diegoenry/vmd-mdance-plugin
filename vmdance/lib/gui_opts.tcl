#
# VMDance - the Plot options panel (right) and showing or hiding the
# side panels
#
# The panel shows every setting of the current plot tab, and the settings
# shared by all plots. While it is shown, the short option row above the
# plots is hidden, so that each setting has one place. It has one width
# for every plot (_opts_layout); on a screen with no room for it beside
# the left panel and the plots, it takes the left panel's place while it
# is open (_panels_room).
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
            {combo tl_view "Show" {lanes "The cluster of every frame" shares "Each cluster's share, window by window" cumulative "Each cluster's share so far" msd "Distance to its representative"}}
            {entry tl_bar "Bar height" "The height of the bars, as a share of a cluster's lane (above 0, at most 1)" -when {$S(tl_view) eq "lanes"}}
            {spin tl_windows "Windows (0: about 120)" 0 2000 -when {$S(tl_view) eq "shares"}}
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
            {combo rs_show "Show" {mean "Mean stay (and the longest)" visits "Visits"}}
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
            {combo sl_kind "From" {centroid "The clusters' mean structures" pairs "Every frame (squared distances)"}}
            {check sl_sort "Sorted within each cluster"}
            {check sl_mean "The mean"}
        }
        map {
            {combo mp_colour "Colour by" {group "Group" cluster "Cluster"}}
            {check mp_reps "The representatives (ringed)"}
        }
        profiles {
            {combo pf_show "Show" {groups "Each group's fluctuations" clusters "Each cluster's fluctuations" differences "Each cluster against the reference"}}
        }
        elbow {
            {combo eb_show "Scores" {both "Both scores" ch "Calinski–Harabasz" db "Davies–Bouldin" explained "Variance explained"}}
            {check eb_stability "Stability (the strip below), when the scan has it"}
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
        {combo plot_len "Distances as" {a2 "Squared (Å², as MDANCE's MSD)" a "Lengths (Å, their square roots)"}}
        {entry plot_time "Time per frame" ""}
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
        tl_view "Each cluster's lane, with a bar where the trajectory is in it (shaded by the cluster's share of the frames, where a pixel holds several); each cluster's share of the frames in each of a number of windows, stacked; its share of the frames so far (lines that have settled: populations that have); or every frame's RMSD² from its cluster's representative"
        tl_windows "The number of windows the trajectory is cut in (0: about 120, of 10 frames at least)"
        sl_kind "A frame's silhouette from the clusters' mean structures (the simplified one: never below 0 for k-means, which puts each frame in the cluster of the nearest mean), or from every frame, of the squared distances (the classic one: below 0, a frame nearer another cluster's frames than its own's)"
        mp_reps "Each cluster's representative ringed on the map, with its number while there are 30 clusters or fewer"
        tn_show "From each cluster (rows) to the cluster lag clustered frames later (columns): the share of the frames that go there (the rest into noise), or their number"
        tn_lag "How many clustered frames later the transition is counted"
        tn_self "The diagonal (staying in a cluster) shaded too: off, the colours show the moves only"
        rs_show "How long the trajectory stays in a cluster once it enters it (the mean of its runs of frames; the longest written beside it), or how many times it enters it"
        cp_show "The backend's mean square deviation within each cluster (MDANCE's MSD: the mean RMSD² over its pairs of frames, each with itself too); the mean RMSD² of its frames from its representative (lower: from half the MSD to all of it, with the metric MSD); the MSD against the cluster's size (dashed: the medians); or MDANCE's extended similarity (Tools ▸ Similarity)"
        ds_show "The RMSD² between the clusters' mean structures, or the RMSD between their representatives (no fit)"
        sl_sort "Each cluster's frames from its best to its worst silhouette"
        td_view "The dendrogram; or the height of each merge against the clusters before it (HELM's: the MSD of the cluster it makes; the linkage's: the RMSD² between the mean structures it joins): a merge far above the one before joins clusters far apart"
        eb_show "Calinski–Harabasz (higher: better) and Davies–Bouldin (lower: better), each on its own axis; or the share of the frames' variance the clusters explain (SSR/SST: the curve with an elbow, where another cluster stops adding much). Ringed: where Davies–Bouldin is lowest and where it dips most (MDANCE's two criteria), where Calinski–Harabasz is highest"
        sw_score "The score shaded: the best configuration is outlined"
        mx_values "The value of each cell, when it has room"
        plot_cursor "The red line that follows VMD's frame"
        plot_len "The plots' and the table's distances as they are measured, squared (Å²: RMSD², and MDANCE's MSD), or as lengths (Å: their square roots, RMSD and √MSD), the unit RMSD cut-offs are given in"
        plot_time "The time between two frames of the molecule, with its unit (0.1 ns, 2 ps: fs, ps, ns, µs, ms or s): the Timeline and the Residence then read in time. Empty: frames"
        plot_ccol "The plugin's darker tones of the clusters' hues, or VMD's own colours of the 3D window (the same hues, brighter)"
    }
    variable optdefaults [array get S]
}

proc ::VMDance::GUI::_build_opts {} {
    variable w; variable tabs; variable optspec; variable optall
    variable optwhen {}
    variable optrows {}
    variable optlaid ""
    variable swapped 0
    variable panels {}
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

# A row of the panel: its widgets are made here, and placed by
# _opts_layout (a label beside its field, or above it; in the grid's rows
# 2r and 2r + 1).
proc ::VMDance::GUI::_opt_row {box r spec} {
    variable opttips; variable optwhen; variable optrows
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
            # (as wide as its longest choice is on the screen: a width in
            # characters of that many, as _combo gives it, is a third wider)
            set wd [::tcl::mathfunc::max {*}[lmap v [dict values $a] {font measure MdvUI $v}]]
            $box.c$r configure -width [expr {int(ceil($wd / double([font measure MdvUI 0]))) + 1}]
        }
        palette {
            ttk::label $box.l$r -text $label
            _palette $box.c$r ${V}($key)
        }
        check {
            ttk::checkbutton $box.c$r -text $label -variable ${V}($key) -command ::VMDance::GUI::redraw
        }
        spin {
            ttk::label $box.l$r -text $label
            ttk::spinbox $box.c$r -from $a -to $b -increment 1 -width 5 -textvariable ${V}($key) \
                -command [list ::VMDance::GUI::_opt_entry $key]
            foreach ev {<Return> <FocusOut>} { bind $box.c$r $ev [list ::VMDance::GUI::_opt_entry $key] }
        }
        entry {
            ttk::label $box.l$r -text $label
            ttk::entry $box.c$r -width 7 -textvariable ${V}($key)
            foreach ev {<Return> <FocusOut>} { bind $box.c$r $ev [list ::VMDance::GUI::_opt_entry $key] }
            if {$a ne ""} { ::VMDance::Tip::add $box.c$r $a }
        }
    }
    lappend optrows [list $box $r $kind $label]
    _opt_place $box $r $kind 1
    if {[dict exists $opttips $key]} {
        foreach wd [list $box.c$r $box.l$r] { if {[winfo exists $wd]} { ::VMDance::Tip::add $wd [dict get $opttips $key] } }
    }
    if {$when ne ""} {
        lappend optwhen [list [lmap wd [list $box.l$r $box.c$r] {expr {[winfo exists $wd] ? $wd : [continue]}}] $when]
    }
    return 1
}

# A row's widgets in the grid: the label beside its field, or above it.
proc ::VMDance::GUI::_opt_place {box r kind beside} {
    set c $box.c$r; set l $box.l$r
    set row [expr {2 * $r}]
    if {$kind eq "check"} {
        grid $c -row $row -column 0 -columnspan 2 -sticky w -pady 1
    } elseif {$beside} {
        grid $l -row $row -column 0 -columnspan 1 -sticky w -padx {0 6} -pady 1
        grid $c -row $row -column 1 -columnspan 1 -sticky [expr {$kind in {combo palette} ? "ew" : "w"}] -padx 0 -pady 1
    } else {
        grid $l -row $row -column 0 -columnspan 2 -sticky w -padx 0 -pady {1 0}
        grid $c -row [expr {$row + 1}] -column 0 -columnspan 2 -sticky [expr {$kind in {combo palette} ? "ew" : "w"}] -padx 0 -pady {0 2}
    }
}
# The panel's rows at the text size of now, in one width for every plot:
# the widest field's (a chooser is as wide as its longest choice). A label
# with no room beside its field goes above it, and a check box's text
# wraps: the panel asked for 416 pixels, and the window for 1528.
proc ::VMDance::GUI::_opts_layout {} {
    variable optrows; variable optlaid
    # (once for a text size and a look)
    set now [list [font actual MdvUI] $::VMDance::Theme::prefix [llength $optrows]]
    if {[info exists optlaid] && $optlaid eq $now} return
    set optlaid $now
    set wd [expr {24 * [font measure MdvUI 0]}]
    foreach row $optrows {
        lassign $row box r kind label
        if {$kind ne "check"} { set wd [expr {max($wd, [winfo reqwidth $box.c$r])}] }
    }
    set rows {}
    foreach row $optrows {
        lassign $row box r kind label
        set c $box.c$r
        if {$kind eq "check"} {
            # (what the check box asks for beyond its text: its box)
            $c configure -text $label
            set room [expr {$wd - ([winfo reqwidth $c] - [font measure MdvUI $label])}]
            $c configure -text [_wrap MdvUI $room $label]
        } else {
            dict lappend rows $box [list $r $kind [winfo reqwidth $box.l$r] [winfo reqwidth $c]]
        }
    }
    # (a section's labels are one column and its fields another, each as
    # wide as its widest: the row that asks for most goes on two lines,
    # until the two columns fit)
    dict for {box all} $rows {
        set beside $all
        while {[llength $beside]} {
            set lw [::tcl::mathfunc::max {*}[lmap x $beside {lindex $x 2}]]
            set fw [::tcl::mathfunc::max {*}[lmap x $beside {lindex $x 3}]]
            if {$lw + 6 + $fw <= $wd} break
            set most [lindex [lsort -integer -decreasing [lmap x $beside {expr {[lindex $x 2] + [lindex $x 3]}}]] 0]
            set i [lsearch -exact [lmap x $beside {expr {[lindex $x 2] + [lindex $x 3]}}] $most]
            set beside [lreplace $beside $i $i]
        }
        foreach x $all { _opt_place $box [lindex $x 0] [lindex $x 1] [expr {$x in $beside}] }
    }
}
# A text in lines of a width at most, broken between words.
proc ::VMDance::GUI::_wrap {font width text} {
    set lines {}
    set line ""
    foreach word [split $text " "] {
        if {$line eq ""} { set line $word; continue }
        if {[font measure $font "$line $word"] <= $width} { append line " " $word; continue }
        lappend lines $line
        set line $word
    }
    lappend lines $line
    join $lines \n
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
        plot_time {
            if {![::VMDance::Plots::time_ok $v]} {
                set S($key) ""
                status "Time per frame: a number and its unit, fs, ps, ns, µs, ms or s (0.1 ns). Empty: frames."
            } else {
                set S($key) $v
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
    _opts_layout
    _opts_update_rows
    update idletasks
    set mw 0
    foreach {k t} $tabs { set mw [expr {max($mw, [winfo reqwidth $B.${k}_sec])}] }
    pack propagate $B 0
    $B configure -width $mw -height [winfo reqheight $B.$S(tab)_sec]
    if {$S(show_opts) && [winfo ismapped $w]} {
        _minsize
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
    variable S; variable swapped
    _panes
    # (the left panel hidden for the plot options is not hidden by the
    # user: the preferences keep it shown)
    set left $S(show_left)
    if {$swapped} { set S(show_left) 1 }
    save_prefs
    set S(show_left) $left
}

proc ::VMDance::GUI::_panes {} {
    variable w
    if {![winfo exists $w.pw.opts]} return
    _panes_arrange
    _minsize
    update idletasks
    # (a plot whose size this changes is drawn again by its canvas's
    # <Configure>: one that keeps it needs no other draw)
    _layout_panes
}

# Whether the screen has room for the left panel, the plots and the plot
# options side by side.
proc ::VMDance::GUI::_panels_fit {} {
    variable w
    update idletasks
    _pages_fit
    set need [expr {[winfo reqwidth $w.pw.left] + [_right_width] + [winfo reqwidth $w.pw.opts] + 2 * 8 + 12}]
    expr {$need <= [lindex [_fit_screen $need 0] 0]}
}
# Where the screen has no room for both panels and the plots, one panel
# shows at a time: the plot options, opened, take the left panel's place,
# and it comes back when they close; the left panel, asked for meanwhile,
# closes them. (The options were cut off, or not shown at all, and the
# option row above the plot is hidden while they are on.)
proc ::VMDance::GUI::_panels_room {} {
    variable S; variable swapped; variable panels
    if {![llength $panels]} {
        # (the window's first arrangement: the options shown without the
        # left panel, where both have no room, were shown so in its place)
        set panels {1 0}
        set swapped [expr {$S(show_opts) && !$S(show_left) && ![_panels_fit]}]
    }
    lassign $panels left0 opts0
    if {!$S(show_opts)} {
        if {$swapped && $opts0 && !$S(show_left)} {
            set S(show_left) 1
            status "The plot options are closed: the left panel is back."
        }
        set swapped 0
    } elseif {$S(show_left) && ![_panels_fit]} {
        if {$opts0 && !$left0} {
            set S(show_opts) 0
            set swapped 0
            status "This screen has no room for both panels: the plot options are closed."
        } else {
            set S(show_left) 0
            set swapped 1
            status "This screen has no room for both panels: the plot options take the left panel's place until they are closed."
        }
    } elseif {$swapped && !$S(show_left) && [_panels_fit]} {
        # (room again: a smaller text)
        set S(show_left) 1
        set swapped 0
    }
    set panels [list $S(show_left) $S(show_opts)]
}

proc ::VMDance::GUI::_panes_arrange {} {
    variable w; variable S; variable tabs
    # (the options' rows laid out first: the room is judged on their width)
    _opts_show_tab
    _panels_room
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
