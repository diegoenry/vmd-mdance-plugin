#
# VMDance - main window
#
# A menubar and a toolbar on top; on the left, a notebook with the
# clustering's setup, the results (the runs, the table of clusters), the
# scans (elbow, sweep), the tools (PRIME, similarity, frame picks) and the
# 3D drawing; on the right, the plots, and a panel with the settings of the
# current plot. The window holds no results: it listens to Results
# (analysis, selection, runs, extras, scans) and draws what is there. Jobs
# run in the background (Job::start): the window stays usable, and every
# handler returns early while one runs (busy).
#

namespace eval ::VMDance::GUI {
    variable w .vmdance
    variable S
    array set S {
        molid -1 molname "" sel "name CA" count "" fit 0 fitsel backbone
        framemode all first 0 last -1 step 1 nframes ""
        algorithm kmeans metric MSD unavailable ""
        busy 0 status "Ready." readout "" readout_shown "" progress 0 tab populations
        summary "" run_label "" detail ""
        sortcol cluster sortdir 1
        eb_from 2 eb_to 15 eb_by 1 eb_info "" eb_rfrom 0.5 eb_rto 5 eb_rby 0.5
        gr_from 2 gr_to 12 gr_by 1 gr_count ""
        pr_metric RR pr_trim 0.1 pr_weighted 1 pr_info ""
        si_metric MSD si_info ""
        pk_method diversity pk_param 10 pk_nbins 10 pk_metric MSD pk_info ""
        v3d_colour 0 v3d_reps 0 v3d_overlay 0 v3d_picks 0 v3d_style NewCartoon v3d_sel "" v3d_top 10
        v3d_frames "" v3d_material Opaque v3d_mode top
        po_show count po_sort cluster po_noise 1
        tl_view lanes tl_bar 0.5
        tn_show probability tn_lag 1 tn_self 1 tn_cmap blues
        rs_show mean rs_unit clustered
        cp_show msd
        ds_show centroids ds_cmap blues
        td_labels 1 td_view tree
        sl_sort 1 sl_mean 1
        eb_show both eb_partition 1 eb_stability 1 eb_stab 0
        mu_view clusters mu_show count mp_colour group pf_show groups
        gp_ranges "" gp_info "" mp_sample 500 mp_info "" pf_reference -1 pf_info ""
        sw_score ch sw_cmap blues
        mx_values 1
        plot_grid 1 plot_legend 1 plot_cursor 1 plot_lw 1.4 plot_ccol muted
        ui_font 12 ui_window compact ui_theme auto show_left 1 show_opts 0 show_toolbar 1
        unlock_metrics 0 backend_mode auto backend_cli "" backend_lib ""
        out_dir "" out_prefix vmdance out_top 10 out_format dcd out_sel all
        fig_width 900 fig_height 560 fig_pdf 1 fig_png 1 fig_eps 0 fig_dpi 300 fig_prefix vmdance fig_dir ""
    }
    # (in a procedure: a loop variable of namespace eval would be a global's
    # when the user has one of that name)
    apply {{} {
        variable S
        foreach a [::VMDance::Algo::all] {
            set S(k_$a) [::VMDance::Algo::default_k $a]
            foreach {k v} [::VMDance::Algo::defaults $a] { set S(p_${a}_$k) $v }
        }
        foreach a [::VMDance::Algo::with_k] { set S(gr_alg_$a) [expr {$a eq "kmeans"}] }
        foreach m $::VMDance::Algo::metrics { set S(gr_met_$m) [expr {$m eq "MSD"}] }
        foreach k $::VMDance::Algo::kinits { set S(gr_seed_$k) [expr {$k eq "StratAll"}] }
    } ::VMDance::GUI}
    variable tabs {populations "Populations" makeup "Make-up" timeline "Timeline" transitions "Transitions" residence "Residence"
                   compactness "Compactness" distances "Distances" tree "Tree" silhouette "Silhouette"
                   map "Map" profiles "Profiles" elbow "Elbow" sweep "Sweep"}
    variable redraw_after ""
    variable refresh_after ""
    variable last_refresh 0
    variable refresh_interval 120
    variable last_progress 0
    variable progress_after ""
    variable last_step ""
    variable sel_after ""
    variable mod [expr {[tk windowingsystem] eq "aqua" ? "Command" : "Control"}]
    variable modlabel [expr {[tk windowingsystem] eq "aqua" ? "Cmd" : "Ctrl"}]
    variable last_action {}
    variable tree ""
    variable swtree ""
    variable prtree ""
    variable picklist ""
    variable molcombo ""
    variable runcombo ""
    variable leftnb ""
    variable page              ;# left page key -> the frame its widgets are in
    variable console_job 0     ;# a job of the command's is running
    variable own_job 0         ;# the job running is the window's (_start to _job_done)
    variable setup0 ""         ;# Setup as the job running started (_setup_state)
    variable setup_kept 0      ;# changed since: kept, not replaced by the job's settings
    variable vmd_colours ""    ;# VMD's colours the table and the key were last made with
    variable viz_seen {}       ;# the 3D drawing's options as the window last sent or read them
    variable redraws 0
    variable parambox ""
    variable keybox ""
    variable count_after ""
    variable window_sizes {compact {980 660} medium {1180 740} large {1380 880}}
    variable window_names {compact "Compact (980 × 660)" medium "Medium (1180 × 740)" large "Large (1380 × 880)"}
    variable press {}
    variable frame_names {all "All frames" range "Frames"}
    variable sel_presets {
        "Cα atoms" "name CA" "Protein backbone" "backbone" "Protein Cα" "protein and name CA"
        "Protein heavy atoms" "protein and noh" "Nucleic acid backbone" "nucleic and backbone"
        "Everything but water and ions" "not (water or ion) and noh"
    }
    variable styles {NewCartoon Licorice Lines Tube Trace CPK VDW}
    variable hints {
        populations "the frames in each cluster · click = select · shift-click = add or remove · double-click = go to its representative"
        makeup      "each cluster's frames by group (Results ▸ Groups), or each group's by cluster · click = select · double-click = go to its representative"
        map         "the frames on their first two principal components (Results ▸ Map) · click = go to that frame and select its cluster"
        profiles    "residue by residue: each group's or cluster's fluctuations, or each cluster against the reference (Results ▸ Profiles)"
        timeline    "the cluster of every frame · click = go to that frame · shift-click = also select its cluster"
        transitions "where the trajectory goes from each cluster · click a cell = select its clusters"
        residence   "how long the trajectory stays in each cluster · click = select · double-click = go to its representative"
        compactness "how tight each cluster is · click = select · double-click = go to its representative"
        distances   "how far apart the clusters are · click a cell = select its clusters"
        tree        "how the clusters join · click a leaf = select its cluster"
        silhouette  "how well each frame sits in its cluster · click = go to that frame and select its cluster"
        elbow       "the scores at every k of the scan · hover = the clusters' shares · double-click = make it the clustering"
        sweep       "the scores of every configuration · double-click = make it the clustering"
    }
}

#---------------------------------------------------------------------------
# Public helpers used by the plots and the 3D code
#---------------------------------------------------------------------------

proc ::VMDance::GUI::status {msg} {
    variable S
    set S(status) $msg
}

# True while a job runs in the background: event handlers (clicks,
# hovers, frame changes, redraws) return early then.
proc ::VMDance::GUI::busy {} {
    variable S
    # (a job of the command's, from the console, counts too)
    expr {$S(busy) || [::VMDance::Job::busy]}
}

proc ::VMDance::GUI::goto_frame {f} {
    if {[catch {::VMDance::Viz::goto $f} err]} { status $err }
}
proc ::VMDance::GUI::goto_cluster {c} {
    if {![::VMDance::Results::has_data]} return
    set f [::VMDance::Results::rep_frame $c]
    if {$f < 0} { status "Cluster $c has no frame."; return }
    if {[catch {::VMDance::Viz::goto $f} err]} { status $err; return }
    status "Frame $f: the representative of cluster $c."
}

# Select clusters (from a plot): add toggles them.
proc ::VMDance::GUI::select {cs {add 0}} {
    if {[busy] || ![::VMDance::Results::has_data]} return
    ::VMDance::Results::set_selection $cs [expr {$add ? "toggle" : "set"}]
}

proc ::VMDance::GUI::show_tab {key} {
    variable w; variable S
    if {![winfo exists $w.pw.right.nb.$key]} return
    $w.pw.right.nb select $w.pw.right.nb.$key
    set S(tab) $key
}

proc ::VMDance::GUI::show_pane {key} {
    variable leftnb
    if {[winfo exists $leftnb.$key]} { $leftnb select $leftnb.$key }
    _pages_fit_later
}

#---------------------------------------------------------------------------
# Window construction
#---------------------------------------------------------------------------

proc ::VMDance::GUI::show {} {
    variable w; variable S
    if {[winfo exists $w]} {
        wm deiconify $w
        raise $w
        _install_traces
        _busy $S(busy)
        _availability 1
        after idle ::VMDance::GUI::redraw
        return $w
    }
    set prefs [::VMDance::Prefs::load]
    foreach {k v} $prefs { set S($k) $v }
    set ::VMDance::Fonts::size $S(ui_font)
    # (the backend chosen in Settings, as the command reads it: once, and
    # under what the command chose)
    ::VMDance::Backend::from_prefs
    ::VMDance::Plot::init_fonts
    toplevel $w
    wm title $w "VMDance — MDANCE clustering of a trajectory"
    wm protocol $w WM_DELETE_WINDOW ::VMDance::GUI::close_window
    bind $w <Destroy> [list ::VMDance::GUI::_on_destroy %W]
    bind $w <FocusIn> ::VMDance::GUI::_focus_in

    _build_menu
    _build_toolbar
    _bind_keys
    if {[tk windowingsystem] ne "aqua"} {
        set i32 [::VMDance::Icons::get app 32]; set i16 [::VMDance::Icons::get app 16]
        if {$i32 ne "" && $i16 ne ""} { catch {wm iconphoto $w $i32 $i16} }
    }
    ttk::frame $w.sb -padding {8 0}
    ttk::label $w.sb.l -textvariable ::VMDance::GUI::S(status) -style Muted.TLabel
    pack $w.sb.l -side left -fill y
    pack propagate $w.sb 0
    pack $w.sb -side bottom -fill x
    ttk::panedwindow $w.pw -orient horizontal
    pack $w.pw -side top -fill both -expand 1 -padx 6 -pady {2 2}
    _build_left
    _build_right
    _build_opts
    bind $w.pw <ButtonRelease-1> {after idle ::VMDance::GUI::_clamp_sash}
    ::VMDance::Theme::apply $S(ui_theme)
    bind $w <<ThemeChanged>> {+::VMDance::Theme::_rethemed}
    _tab_labels
    _show_hint $S(tab)

    refresh_molecules
    _algorithm_changed
    _frames_changed
    _fit_changed
    _grid_count
    _install_traces
    ::VMDance::Results::listen ::VMDance::GUI::_results_changed
    ::VMDance::Viz::listen ::VMDance::GUI::_draw_options
    ::VMDance::Job::listen ::VMDance::GUI::_job_changed
    _draw_options
    backend_changed
    # a clustering may already exist (made from a script before the window
    # was first opened), or a session loaded from the console
    _results_changed analysis
    foreach k {elbow sweep picks extras} { _results_changed $k }
    set g $::VMDance::Session::pending_gui
    set ::VMDance::Session::pending_gui {}
    if {[dict size $g] && [catch {apply_session_state $g} err]} {
        status "The session's window settings could not be applied: $err"
    }
    apply_appearance 1
    _count_later
    if {[::VMDance::Results::has_data]} { show_pane results }
    set S(busy) [::VMDance::Job::busy]
    # (the window's own job, run on while the window was destroyed, is not
    # the command's: it ends in _job_done)
    variable own_job
    variable console_job [expr {$S(busy) && !$own_job}]
    if {$console_job} {
        variable setup0 [_setup_state]
        variable setup_kept 0
        status "A job of the command's is running ($::VMDance::Job::kind)…"
    }
    _busy $S(busy)
    after idle ::VMDance::GUI::redraw
    return $w
}

proc ::VMDance::GUI::_fit_screen {W H} {
    variable w
    set sw [winfo screenwidth $w]; set sh [winfo screenheight $w]
    list [expr {min($W, max(400, $sw - 40))}] [expr {min($H, max(300, $sh - 100))}]
}
proc ::VMDance::GUI::_minsize {rw rh} {
    variable w
    lassign [_fit_screen $rw $rh] rw rh
    wm minsize $w $rw $rh
    list $rw $rh
}

# Window size and text size (Settings). The window is never smaller than
# its widgets need, so that nothing is cut off.
proc ::VMDance::GUI::apply_appearance {{first 0}} {
    variable w; variable S; variable window_sizes
    ::VMDance::Fonts::apply $S(ui_font)
    # (the look again at this size: the fields' padding and the check
    # boxes follow the text)
    if {!$first} { ::VMDance::Theme::apply }
    _tree_columns
    set lh [font metrics MdvUISmall -linespace]
    $w.sb configure -height [expr {$lh + 8}]
    $w.pw.right.rf configure -height [expr {$lh + 8}]
    _wraplengths
    _panes_arrange
    lassign [_minsize {*}[needed_size]] rw rh
    lassign [dict get $window_sizes $S(ui_window)] pw ph
    lassign [_fit_screen [expr {max($pw, $rw)}] [expr {max($ph, $rh)}]] W H
    wm geometry $w ${W}x${H}
    update idletasks
    _layout_panes
    redraw_later
    return [list $W $H]
}

# The window size at which every widget gets its requested size.
proc ::VMDance::GUI::needed_size {} {
    variable w
    set panes [$w.pw panes]
    set last {}
    for {set i 0} {$i < 6} {incr i} {
        update idletasks
        _pages_fit
        set now [list [winfo reqwidth $w.tb]]
        foreach p $panes { lappend now [winfo reqwidth $p] [winfo reqheight $p] }
        if {$now eq $last} break
        set last $now
    }
    set sash 8
    set shown [expr {[winfo manager $w.tb] ne ""}]
    set pw 0; set ph 0
    foreach p $panes {
        incr pw [winfo reqwidth $p]
        set ph [expr {max($ph, [winfo reqheight $p])}]
    }
    set width [expr {max($pw + $sash * max(0, [llength $panes] - 1) + 12, $shown ? [winfo reqwidth $w.tb] : 0)}]
    set tb [expr {$shown ? [winfo reqheight $w.tb] : 0}]
    set height [expr {$tb + $ph + [$w.sb cget -height] + 4}]
    list $width $height
}

# (an error names what is wrong; nothing is changed)
proc ::VMDance::GUI::_check_appearance {font win theme} {
    variable window_sizes
    if {![regexp {^[1-9][0-9]?$} $font] || $font < 8 || $font > 24} { error "text size must be a whole number of points from 8 to 24" }
    if {![dict exists $window_sizes $win]} { error "window size must be one of [join [dict keys $window_sizes] {, }]" }
    ::VMDance::Theme::resolve $theme
}
proc ::VMDance::GUI::set_appearance {font win {theme ""}} {
    variable S
    if {$theme eq ""} { set theme $S(ui_theme) }
    _check_appearance $font $win $theme
    set S(ui_font) $font
    set S(ui_window) $win
    set S(ui_theme) $theme
    set ::VMDance::Theme::choice $theme
    set size [apply_appearance]
    save_prefs
    status "Text size $font pt, window [join $size ×], theme [::VMDance::Theme::label $theme]."
}

proc ::VMDance::GUI::save_prefs {} {
    variable S
    set d {}
    foreach k {ui_font ui_window show_left show_opts ui_theme show_toolbar unlock_metrics backend_mode backend_cli backend_lib} {
        dict set d $k $S($k)
    }
    set err [::VMDance::Prefs::save $d]
    if {$err ne ""} { status "Preferences not saved: $err" }
}

# Keep every divider where no panel's widgets are cut off.
proc ::VMDance::GUI::_clamp_sash {} {
    variable w
    if {![winfo exists $w.pw]} return
    set panes [$w.pw panes]
    set n [llength $panes]
    if {$n < 2} return
    set W [winfo width $w.pw]
    set sw 6
    set reqs [lmap p $panes {winfo reqwidth $p}]
    for {set i 0} {$i < $n - 1} {incr i} {
        set lo [expr {[::tcl::mathop::+ {*}[lrange $reqs 0 $i]] + $i * $sw}]
        set hi [expr {$W - [::tcl::mathop::+ 0 {*}[lrange $reqs [expr {$i + 1}] end]] - ($n - 1 - $i) * $sw}]
        set p [$w.pw sashpos $i]
        set q [expr {$hi < $lo ? $lo : min(max($p, $lo), $hi)}]
        if {$q != $p} { $w.pw sashpos $i $q }
    }
}

proc ::VMDance::GUI::close_window {} {
    variable w
    _remove_traces
    wm withdraw $w
}

proc ::VMDance::GUI::shown {} {
    variable w
    expr {[winfo exists $w] && [wm state $w] ne "withdrawn"}
}

proc ::VMDance::GUI::_on_destroy {win} {
    variable w
    if {$win ne $w} return
    _remove_traces
    catch {trace remove variable ::vmd_initialize_structure write ::VMDance::GUI::_mol_trace}
    catch {trace remove variable ::vmd_trajectory_read write ::VMDance::GUI::_mol_trace}
    catch {trace remove variable ::VMDance::GUI::S(progress) write ::VMDance::GUI::_draw_progress}
    catch {trace remove variable ::VMDance::GUI::S(readout) write ::VMDance::GUI::_readout}
    ::VMDance::Results::unlisten ::VMDance::GUI::_results_changed
    ::VMDance::Viz::unlisten ::VMDance::GUI::_draw_options
    ::VMDance::Job::unlisten ::VMDance::GUI::_job_changed
    catch {::VMDance::Plots::release_images}
    variable S
    foreach k [array names S] {
        foreach t [trace info variable ::VMDance::GUI::S($k)] {
            lassign $t ops cmd
            if {[string match *_sync* [lindex $cmd 0]]} { catch {trace remove variable ::VMDance::GUI::S($k) $ops $cmd} }
        }
    }
    foreach v {redraw_after refresh_after sel_after count_after progress_after} {
        variable $v
        after cancel [set $v]
        set $v ""
    }
    # a running job keeps running; its result is published without the window
    # (and Setup follows it: the end of a job of the command's goes unheard)
    variable console_job
    if {$console_job} {
        variable setup0 ""
        variable setup_kept 0
    }
}

# Run a menu or toolbar action once: on some platforms a menu accelerator
# and the matching key binding both fire for one key press.
proc ::VMDance::GUI::act {name} {
    variable last_action
    set now [clock milliseconds]
    lassign $last_action ln lt
    if {$ln eq $name && $now - $lt < 300} return
    set last_action [list $name $now]
    set cmd [dict get {
        open_session   open_session_dialog
        save_session   {save_session 0}
        save_as        {save_session 1}
        import         import_session_dialog
        export         export_dialog
        figures        figure_dialog
        cluster        cluster
        elbow          elbow
        sweep          sweep
        prime          prime
        similarity     similarity
        groups         groups_set
        groups_file    groups_file_dialog
        groups_clear   groups_clear
        map            map
        profiles       profiles
        pick           pick
        cancel         cancel
        close          close_window
        render         render_view_dialog
        goto           goto_selected
        colour         toggle_colour
        reps           toggle_reps
        settings       settings_dialog
        help           help
        plot           save_current_plot
        plotdata       save_plot_data
        toggle_left    toggle_left
        toggle_opts    toggle_opts
        table          quick_table
        userfield      userfield
        clear          clear_all
    } $name]
    ::VMDance::GUI::[lindex $cmd 0] {*}[lrange $cmd 1 end]
}

proc ::VMDance::GUI::_menu_add {m kind label args} {
    set img ""
    set opts {}
    foreach {k v} $args {
        if {$k eq "-icon"} { set img [::VMDance::Icons::get $v 16] } else { lappend opts $k $v }
    }
    if {$img ne ""} { lappend opts -image $img -compound left }
    $m add $kind -label $label {*}$opts
}

proc ::VMDance::GUI::_build_menu {} {
    variable w; variable tabs
    set M $w.menu
    menu $M -tearoff 0
    $w configure -menu $M
    set aqua [expr {[tk windowingsystem] eq "aqua"}]
    set acc [expr {$aqua ? "Command-" : "Ctrl+"}]
    set sacc [expr {$aqua ? "Command-Shift-S" : "Ctrl+Shift+S"}]

    menu $M.file -tearoff 0
    $M add cascade -label File -menu $M.file
    _menu_add $M.file command "Open session…" -icon open -accelerator ${acc}O -command {::VMDance::GUI::act open_session}
    _menu_add $M.file command "Save session" -icon save -accelerator ${acc}S -command {::VMDance::GUI::act save_session}
    _menu_add $M.file command "Save session as…" -accelerator $sacc -command {::VMDance::GUI::act save_as}
    $M.file add command -label "Import a session of the MDANCE plugin (.mdance)…" -command {::VMDance::GUI::act import}
    $M.file add separator
    _menu_add $M.file command "Export results…" -icon export -accelerator ${acc}E -command {::VMDance::GUI::act export}
    _menu_add $M.file command "Create figures…" -icon figure -accelerator ${acc}P -command {::VMDance::GUI::act figures}
    menu $M.file.quick -tearoff 0
    $M.file add cascade -label "Quick export" -menu $M.file.quick
    $M.file.quick add command -label "Table of clusters (CSV)…" -command {::VMDance::GUI::act table}
    $M.file.quick add command -label "This plot's data (CSV)…" -command {::VMDance::GUI::act plotdata}
    $M.file.quick add command -label "This plot (PDF, PNG, EPS)…" -command {::VMDance::GUI::act plot}
    $M.file.quick add command -label "3D view (PNG)…" -command {::VMDance::GUI::act render}
    $M.file add separator
    $M.file add command -label "Close window" -accelerator ${acc}W -command {::VMDance::GUI::act close}

    menu $M.view -tearoff 0
    $M add cascade -label View -menu $M.view
    set i 1
    foreach {key title} $tabs {
        _menu_add $M.view radiobutton $title -icon tab_$key -variable ::VMDance::GUI::S(tab) -value $key \
            -accelerator [expr {$i <= 9 ? "$acc$i" : ""}] -command [list ::VMDance::GUI::show_tab $key]
        incr i
    }
    $M.view add separator
    _menu_add $M.view checkbutton "Left panel" -icon panel_left -variable ::VMDance::GUI::S(show_left) \
        -command ::VMDance::GUI::panels_changed
    _menu_add $M.view checkbutton "Plot options" -icon panel_right -variable ::VMDance::GUI::S(show_opts) \
        -command ::VMDance::GUI::panels_changed
    $M.view add checkbutton -label "Toolbar" -variable ::VMDance::GUI::S(show_toolbar) \
        -command {::VMDance::GUI::_toolbar_visible; ::VMDance::GUI::save_prefs}
    $M.view add separator
    $M.view add command -label "Redraw plot" -command ::VMDance::GUI::redraw

    menu $M.cl -tearoff 0
    $M add cascade -label Clustering -menu $M.cl
    _menu_add $M.cl command "Cluster" -icon cluster -accelerator ${acc}R -command {::VMDance::GUI::act cluster}
    _menu_add $M.cl command "Elbow scan" -icon elbow -command {::VMDance::GUI::act elbow}
    $M.cl add command -label "Sweep" -command {::VMDance::GUI::act sweep}
    _menu_add $M.cl command "Cancel" -icon cancel -state disabled -command {::VMDance::GUI::act cancel}
    $M.cl add separator
    $M.cl add command -label "PRIME: predict the native frame" -command {::VMDance::GUI::act prime}
    $M.cl add command -label "Similarity of the clusters (iSIM)" -command {::VMDance::GUI::act similarity}
    $M.cl add command -label "Pick frames" -command {::VMDance::GUI::act pick}
    $M.cl add separator
    menu $M.cl.runs -tearoff 0 -postcommand ::VMDance::GUI::_runs_menu
    $M.cl add cascade -label "Runs" -menu $M.cl.runs
    $M.cl add command -label "Rename this run…" -command ::VMDance::GUI::rename_run
    $M.cl add command -label "Delete this run" -command ::VMDance::GUI::delete_run
    $M.cl add command -label "Clear every run…" -command {::VMDance::GUI::act clear}
    $M.cl add separator
    _menu_add $M.cl command "Settings…" -icon settings -command {::VMDance::GUI::act settings}

    menu $M.v3d -tearoff 0
    $M add cascade -label 3D -menu $M.v3d
    _menu_add $M.v3d checkbutton "Colour by cluster" -icon colour -variable ::VMDance::GUI::S(v3d_colour) -command ::VMDance::GUI::draw_changed
    _menu_add $M.v3d checkbutton "Representatives" -icon reps -variable ::VMDance::GUI::S(v3d_reps) -command ::VMDance::GUI::draw_changed
    $M.v3d add checkbutton -label "Overlay of the selected clusters" -variable ::VMDance::GUI::S(v3d_overlay) -command ::VMDance::GUI::draw_changed
    $M.v3d add checkbutton -label "Picked frames" -variable ::VMDance::GUI::S(v3d_picks) -command ::VMDance::GUI::draw_changed
    $M.v3d add separator
    _menu_add $M.v3d command "Go to the selected cluster's representative" -icon goto -command {::VMDance::GUI::act goto}
    $M.v3d add command -label "Write the clusters to the user field…" -command {::VMDance::GUI::act userfield}
    _menu_add $M.v3d command "Render 3D view (PNG)…" -icon render -command {::VMDance::GUI::act render}

    menu $M.help -tearoff 0
    $M add cascade -label Help -menu $M.help
    _menu_add $M.help command "Quick guide" -icon help -command {::VMDance::GUI::act help}
    $M.help add command -label "References" -command ::VMDance::GUI::references
    $M.help add command -label "About VMDance" -command ::VMDance::GUI::about
}

proc ::VMDance::GUI::_tb_button {f name icon text tip cmd} {
    set img [::VMDance::Icons::get $icon 24]
    if {$img ne ""} {
        ttk::button $f.$name -image [list $img disabled [::VMDance::Icons::dim $icon 24]] \
            -style Toolbutton -command $cmd -takefocus 0
    } else {
        ttk::button $f.$name -text $text -style Toolbutton -command $cmd -takefocus 0
    }
    pack $f.$name -side left -padx 1
    ::VMDance::Tip::add $f.$name $tip
}
proc ::VMDance::GUI::_tb_toggle {f name icon text var tip {cmd ::VMDance::GUI::panels_changed}} {
    set img [::VMDance::Icons::get $icon 24]
    if {$img ne ""} {
        ttk::checkbutton $f.$name -image $img -style Toolbutton -variable $var -takefocus 0 -command $cmd
    } else {
        ttk::checkbutton $f.$name -text $text -style Toolbutton -variable $var -takefocus 0 -command $cmd
    }
    pack $f.$name -side left -padx 1
    ::VMDance::Tip::add $f.$name $tip
}
proc ::VMDance::GUI::_tb_sep {f name} {
    ttk::separator $f.$name -orient vertical
    pack $f.$name -side left -fill y -padx 3 -pady 3
}

proc ::VMDance::GUI::_build_toolbar {} {
    variable w; variable tabs; variable modlabel
    set f [ttk::frame $w.tb -padding {6 4 6 0}]
    set k $modlabel
    _tb_toggle $f left panel_left Panel ::VMDance::GUI::S(show_left) "Show or hide the left panel ($k+Shift+L)"
    _tb_sep $f s0
    _tb_button $f open   open    Open    "Open session… ($k+O)" {::VMDance::GUI::act open_session}
    _tb_button $f save   save    Save    "Save session ($k+S)\nevery run, the scans and the selection" {::VMDance::GUI::act save_session}
    _tb_sep $f s1
    _tb_button $f export export  Export  "Export results… ($k+E)\nthe clusters, the labels, the representatives' structures, each cluster's trajectory, the plots' data" {::VMDance::GUI::act export}
    _tb_button $f figure figure  Figures "Create figures… ($k+P)\nPDF, PNG or EPS of the plots" {::VMDance::GUI::act figures}
    _tb_sep $f s2
    _tb_button $f cluster cluster Cluster "Cluster ($k+R)\nwith the algorithm and parameters of Setup, in the background (with the library, VMD waits until it ends)" {::VMDance::GUI::act cluster}
    _tb_button $f elbow   elbow   Elbow   "Elbow scan\nthe same clustering at every k of Scans ▸ Elbow" {::VMDance::GUI::act elbow}
    _tb_button $f cancel  cancel  Cancel  "Cancel the running job (what was there is kept)" {::VMDance::GUI::act cancel}
    $f.cancel state disabled
    canvas $f.prog -width 22 -height 22 -highlightthickness 0 -borderwidth 0
    ::VMDance::Theme::bg_widget $f.prog
    pack $f.prog -side left -padx {4 1}
    ::VMDance::Tip::add $f.prog "Progress of the running job"
    trace add variable ::VMDance::GUI::S(progress) write ::VMDance::GUI::_draw_progress
    _draw_progress
    _tb_sep $f s3
    set i 1
    foreach {key title} $tabs {
        set img [::VMDance::Icons::get tab_$key 24]
        if {$img ne ""} {
            ttk::radiobutton $f.t_$key -image $img -style Toolbutton -takefocus 0 \
                -variable ::VMDance::GUI::S(tab) -value $key -command [list ::VMDance::GUI::show_tab $key]
        } else {
            ttk::radiobutton $f.t_$key -text $title -style Toolbutton -takefocus 0 \
                -variable ::VMDance::GUI::S(tab) -value $key -command [list ::VMDance::GUI::show_tab $key]
        }
        pack $f.t_$key -side left -padx 1
        ::VMDance::Tip::add $f.t_$key [expr {$i <= 9 ? "$title ($k+$i)" : $title}]
        incr i
    }
    _tb_sep $f s4
    _tb_toggle $f colour colour Colour ::VMDance::GUI::S(v3d_colour) "Colour the molecule by cluster in VMD's 3D window\n(it follows the trajectory as it plays)" ::VMDance::GUI::draw_changed
    _tb_toggle $f reps reps Reps ::VMDance::GUI::S(v3d_reps) "Draw every cluster's representative at once, in its colour" ::VMDance::GUI::draw_changed
    _tb_button $f goto   goto    Go      "Go to the selected cluster's representative frame" {::VMDance::GUI::act goto}
    _tb_button $f render render  Render  "Render the 3D view to PNG…" {::VMDance::GUI::act render}
    _tb_sep $f s5
    _tb_button $f settings settings Settings "Settings…: the backend, text and window size, theme" {::VMDance::GUI::act settings}
    _tb_button $f help   help    Help    "Quick guide" {::VMDance::GUI::act help}
    _tb_toggle $f opts panel_right Options ::VMDance::GUI::S(show_opts) "Show or hide the plot options ($k+Shift+O)"
    pack $f.opts -side right
    _toolbar_visible
}

proc ::VMDance::GUI::_toolbar_visible {} {
    variable w; variable S
    if {$S(show_toolbar)} {
        if {[winfo exists $w.pw]} { pack $w.tb -side top -fill x -before $w.pw } else { pack $w.tb -side top -fill x }
    } else {
        pack forget $w.tb
    }
}

proc ::VMDance::GUI::_draw_progress {args} {
    variable w; variable S
    set c $w.tb.prog
    if {![winfo exists $c]} return
    $c delete all
    $c create oval 3 3 19 19 -outline #d5dae2 -width 3
    set p [expr {[string is double -strict $S(progress)] ? $S(progress) : 0}]
    if {$S(busy) && $p > 0} {
        $c create arc 3 3 19 19 -start 90 -extent [expr {-min(359.9, 3.6 * $p)}] -style arc -outline #1f5fae -width 3
    } elseif {$S(busy)} {
        $c create arc 3 3 19 19 -start 90 -extent -40 -style arc -outline #1f5fae -width 3
    }
}

proc ::VMDance::GUI::_bind_keys {} {
    variable w; variable mod; variable tabs
    foreach {key action} {o open_session s save_session e export p figures r cluster w close} {
        bind $w <$mod-$key> [list ::VMDance::GUI::act $action]
        bind $w <$mod-[string toupper $key]> [list ::VMDance::GUI::act $action]
    }
    bind $w <$mod-Shift-s> {::VMDance::GUI::act save_as}
    bind $w <$mod-Shift-S> {::VMDance::GUI::act save_as}
    foreach {k a} {l toggle_left L toggle_left o toggle_opts O toggle_opts} {
        bind $w <$mod-Shift-$k> [list ::VMDance::GUI::act $a]
    }
    set i 1
    foreach {key title} $tabs {
        if {$i > 9} break
        bind $w <$mod-Key-$i> [list ::VMDance::GUI::show_tab $key]
        incr i
    }
}

proc ::VMDance::GUI::_build_left {} {
    variable w; variable leftnb
    set L [ttk::frame $w.pw.left -padding {0 0 4 0}]
    $w.pw add $L -weight 0
    set nb [ttk::notebook $L.nb]
    set leftnb $nb
    pack $nb -side top -fill both -expand 1
    variable page
    foreach {key title icon} {setup Setup pane_setup results Results pane_results scans Scans pane_scans
                              tools Tools pane_tools v3d "3D" pane_3d} {
        set f [ttk::frame $nb.$key]
        set img [::VMDance::Icons::get $icon 16]
        if {$img ne ""} {
            $nb add $f -text $title -image $img -compound left
        } else {
            $nb add $f -text $title
        }
        set page($key) [_scroll_page $f]
    }
    _build_setup $page(setup)
    _build_results $page(results)
    _build_scans $page(scans)
    _build_tools $page(tools)
    _build_3d $page(v3d)
    foreach key [array names page] {
        foreach c [winfo children $page($key)] { bind $c <Configure> +::VMDance::GUI::_pages_fit_later }
    }
    bind $nb <<NotebookTabChanged>> ::VMDance::GUI::_left_tab_changed
    # the mouse wheel scrolls the left page under the pointer
    foreach {ev d} {<MouseWheel> %D <Button-4> 1 <Button-5> -1} {
        bind $w $ev [list ::VMDance::GUI::_page_wheel %W $d]
    }
}

# A left page that scrolls when the window is too short for it: the
# widgets go in the frame returned, in a canvas as large as they ask for
# (so that the window is made that large when the screen allows), and at
# least as large as the page.
proc ::VMDance::GUI::_scroll_page {f} {
    canvas $f.c -highlightthickness 0 -borderwidth 0 -yscrollincrement 16
    ::VMDance::Theme::bg_widget $f.c
    ttk::scrollbar $f.sb -orient vertical -command [list $f.c yview]
    $f.c configure -yscrollcommand [list $f.sb set]
    set p [ttk::frame $f.c.p -padding {6 6 6 4}]
    $f.c create window 0 0 -window $p -anchor nw -tags page
    pack $f.c -side left -fill both -expand 1
    bind $p <Configure> +::VMDance::GUI::_pages_fit_later
    bind $f.c <Configure> +::VMDance::GUI::_pages_fit_later
    return $p
}
proc ::VMDance::GUI::_pages_fit_later {} {
    after cancel ::VMDance::GUI::_pages_fit
    after idle ::VMDance::GUI::_pages_fit
}
proc ::VMDance::GUI::_pages_fit {} {
    variable page
    foreach key [array names page] {
        set p $page($key)
        if {![winfo exists $p]} continue
        set c [winfo parent $p]
        set f [winfo parent $c]
        set pw [winfo reqwidth $p]; set ph [winfo reqheight $p]
        if {[$c cget -width] != $pw || [$c cget -height] != $ph} { $c configure -width $pw -height $ph }
        set cw [winfo width $c]; set ch [winfo height $c]
        if {![winfo ismapped $c] || $cw <= 1} { set cw $pw; set ch $ph }
        set iw [expr {max($pw, $cw)}]; set ih [expr {max($ph, $ch)}]
        if {[$c itemcget page -width] != $iw || [$c itemcget page -height] != $ih} {
            $c itemconfigure page -width $iw -height $ih
            $c configure -scrollregion [list 0 0 $iw $ih]
        }
        set need [expr {$ph > $ch + 1}]
        if {$need && [winfo manager $f.sb] eq ""} {
            pack $f.sb -side right -fill y -before $c
        } elseif {!$need && [winfo manager $f.sb] ne ""} {
            pack forget $f.sb
            $c yview moveto 0
        }
    }
}
# (a list, a table, a text or a field keeps the wheel for itself)
proc ::VMDance::GUI::_page_wheel {W d} {
    variable page
    if {![winfo exists $W] || [winfo class $W] in {TCombobox TSpinbox Treeview Listbox Text}} return
    foreach key [array names page] {
        set p $page($key)
        set c [winfo parent $p]
        if {$W ne $c && $W ne $p && [string first $p. $W] != 0} continue
        if {[winfo reqheight $p] > [winfo height $c] + 1} {
            $c yview scroll [expr {$d > 0 ? -3 : 3}] units
        }
        return
    }
}

# Tk on macOS can leave a pane undrawn after heavy drawing in the plots:
# changing its padding by one pixel and back makes Tk draw it again.
proc ::VMDance::GUI::_left_tab_changed {} {
    variable leftnb
    if {[tk windowingsystem] ne "aqua" || ![winfo exists $leftnb]} return
    set p [$leftnb select]
    if {$p eq "" || ![winfo exists $p]} return
    set pad [$p cget -padding]
    if {[llength $pad] != 4} return
    $p configure -padding [lreplace $pad end end [expr {[lindex $pad end] + 1}]]
    update idletasks
    $p configure -padding $pad
}

# A titled group: a title label above an untitled labelframe, both in the
# frame <path>_sec, which the caller places; returns the labelframe.
proc ::VMDance::GUI::_section {path title args} {
    set sec [ttk::frame ${path}_sec -style Holder.TFrame]
    ttk::label ${path}_title -text $title -style Section.TLabel
    ttk::frame ${path}_nolabel -width 1 -height 1
    ttk::labelframe $path -style Section.TLabelframe -labelwidget ${path}_nolabel {*}$args
    pack ${path}_title -in $sec -side top -fill x
    pack $path -in $sec -side top -fill both -expand 1
    return $path
}

# label + widget in a grid row
proc ::VMDance::GUI::_row {box r label widget {tip ""}} {
    ttk::label $box.l$r -text $label
    grid $box.l$r $widget -row $r -sticky w -padx {0 6} -pady 1
    grid configure $widget -sticky ew
    if {$tip ne ""} { ::VMDance::Tip::add $box.l$r $tip; ::VMDance::Tip::add $widget $tip }
}

proc ::VMDance::GUI::_combo {path var mapping {cmd ""}} {
    set labels {}
    foreach {k v} $mapping { lappend labels $v }
    ttk::combobox $path -values $labels -state readonly -width [expr {max(6, [::tcl::mathfunc::max {*}[lmap l $labels {string length $l}]] + 1)}]
    foreach {k v} $mapping { if {$k eq [set $var]} { $path set $v } }
    # (a bind script: "%" in a label would be substituted)
    bind $path <<ComboboxSelected>> [string map {% %%} [list ::VMDance::GUI::_combo_set $path $var $mapping $cmd]]
    # (a dialog made again adds the same trace: once is enough)
    set tr [list ::VMDance::GUI::_combo_sync $path $var $mapping]
    catch {trace remove variable $var write $tr}
    trace add variable $var write $tr
    return $path
}
proc ::VMDance::GUI::_combo_sync {path var mapping args} {
    if {![winfo exists $path]} {
        trace remove variable $var write [list ::VMDance::GUI::_combo_sync $path $var $mapping]
        return
    }
    foreach {k v} $mapping { if {$k eq [set $var]} { $path set $v } }
}
proc ::VMDance::GUI::_combo_set {path var mapping cmd} {
    set lab [$path get]
    foreach {k v} $mapping { if {$v eq $lab} { set $var $k } }
    if {$cmd ne ""} { uplevel #0 $cmd } else { redraw }
}
# A value -> label mapping of a list (the label is the value).
proc ::VMDance::GUI::_same {l} { set out {}; foreach v $l { lappend out $v $v }; return $out }

# Every -wraplength of the left panel from the text size (from the panel's
# width, the texts would hold the panel as wide as it once was).
proc ::VMDance::GUI::_wraplengths {} {
    variable w
    if {![winfo exists $w.pw.left]} return
    set wl [expr {max(260, 34 * [font measure MdvUI "0"])}]
    foreach p [list $w.pw.left] {
        if {![winfo exists $p]} continue
        foreach c [_descendants $p] {
            if {[winfo class $c] eq "TLabel" && [$c cget -wraplength] ne "" && [$c cget -wraplength] > 0} {
                $c configure -wraplength $wl
            }
        }
    }
}
proc ::VMDance::GUI::_descendants {p} {
    set out {}
    foreach c [winfo children $p] { lappend out $c {*}[_descendants $c] }
    return $out
}

#---------------------------------------------------------------------------
# Setup
#---------------------------------------------------------------------------

# A selection entry with a menu of common selections.
proc ::VMDance::GUI::_sel_entry {f var presets} {
    ttk::frame $f
    ttk::entry $f.e -textvariable $var -width 18
    ttk::menubutton $f.p -text "▾" -menu $f.p.m -style Toolbutton -takefocus 0
    menu $f.p.m -tearoff 0
    foreach {lab sel} $presets {
        $f.p.m add command -label "$lab ($sel)" -command [list apply {{var sel} { set $var $sel; ::VMDance::GUI::_count_later }} $var $sel]
    }
    pack $f.e -side left -fill x -expand 1
    pack $f.p -side left
    bind $f.e <Return> {::VMDance::GUI::act cluster}
    bind $f.e <KeyRelease> ::VMDance::GUI::_count_later
    return $f
}

proc ::VMDance::GUI::_build_setup {P} {
    variable molcombo; variable frame_names; variable sel_presets; variable parambox
    set V ::VMDance::GUI::S
    set I [_section $P.input "What to cluster" -padding {6 4}]
    pack ${I}_sec -side top -fill x
    set mf [ttk::frame $I.mf]
    ttk::combobox $mf.mol -textvariable ${V}(molname) -state readonly -width 18 -postcommand ::VMDance::GUI::refresh_molecules
    set molcombo $mf.mol
    bind $mf.mol <<ComboboxSelected>> ::VMDance::GUI::_mol_chosen
    ttk::button $mf.r -text "↻" -style Toolbutton -takefocus 0 -command {::VMDance::GUI::refresh_molecules; ::VMDance::GUI::_count_later}
    pack $mf.mol -side left -fill x -expand 1
    pack $mf.r -side left
    ::VMDance::Tip::add $mf.r "Read the molecules again (frames loaded into a molecule do not tell the window)"
    _row $I 0 "Molecule" $mf
    _sel_entry $I.s ${V}(sel) $sel_presets
    _row $I 1 "Atoms" $I.s "The atoms whose coordinates are clustered, in VMD's selection language\n(the same atoms in every frame). Return clusters."
    ttk::label $I.c -textvariable ${V}(count) -style Muted.TLabel
    grid $I.c -row 2 -column 1 -sticky w
    set fr [ttk::frame $I.fr]
    _combo $fr.mode ${V}(framemode) $frame_names ::VMDance::GUI::_frames_changed
    ttk::spinbox $fr.first -from 0 -to 1e9 -increment 1 -width 5 -textvariable ${V}(first) -command ::VMDance::GUI::_count_later
    ttk::label $fr.lt -text "to"
    ttk::spinbox $fr.last -from -1 -to 1e9 -increment 1 -width 5 -textvariable ${V}(last) -command ::VMDance::GUI::_count_later
    pack $fr.mode $fr.first $fr.lt $fr.last -side left -padx {0 4}
    foreach e [list $fr.first $fr.last] { bind $e <KeyRelease> ::VMDance::GUI::_count_later }
    _row $I 3 "Frames" $fr "All the frames, or a range (-1: the last frame)"
    set sf [ttk::frame $I.st]
    ttk::spinbox $sf.step -from 1 -to 1e6 -increment 1 -width 5 -textvariable ${V}(step) -command ::VMDance::GUI::_count_later
    bind $sf.step <KeyRelease> ::VMDance::GUI::_count_later
    ttk::label $sf.l -textvariable ${V}(nframes) -style Muted.TLabel
    pack $sf.step $sf.l -side left -padx {0 6}
    _row $I 4 "Every" $sf "Cluster every n-th frame: residence times are then in steps of n frames"
    set ff [ttk::frame $I.fit]
    ttk::checkbutton $ff.on -text "Fit to the first frame on" -variable ${V}(fit) -command ::VMDance::GUI::_fit_changed
    ttk::entry $ff.sel -textvariable ${V}(fitsel) -width 8
    pack $ff.on -side left
    pack $ff.sel -side left -fill x -expand 1 -padx {4 0}
    grid $ff -row 5 -column 0 -columnspan 2 -sticky ew -pady {2 0}
    ::VMDance::Tip::add $ff.on "Superpose every frame on the first clustered frame by these atoms before clustering\n(computed on the values: VMD's coordinates are not moved).\nOff: the coordinates as they are (an aligned trajectory)."
    grid columnconfigure $I 1 -weight 1

    set A [_section $P.alg "Algorithm" -padding {6 4}]
    pack ${A}_sec -side top -fill x -pady {6 0}
    set names {}
    foreach a [::VMDance::Algo::all] { lappend names $a [::VMDance::Algo::label $a] }
    _combo $A.c ${V}(algorithm) $names ::VMDance::GUI::_algorithm_changed
    # (the backend asked again as it opens: a program rebuilt meanwhile)
    $A.c configure -postcommand {::VMDance::GUI::_availability 1}
    grid $A.c -row 0 -column 0 -sticky w
    ttk::label $A.about -style Muted.TLabel -wraplength 280 -justify left
    grid $A.about -row 1 -column 0 -sticky w -pady {2 0}
    ttk::label $A.na -textvariable ${V}(unavailable) -style Read.TLabel -wraplength 280 -justify left
    grid $A.na -row 2 -column 0 -sticky w
    grid columnconfigure $A 0 -weight 1

    set B [_section $P.par "Parameters" -padding {6 4}]
    pack ${B}_sec -side top -fill x -pady {6 0}
    set parambox $B
    foreach a [::VMDance::Algo::all] { _build_params $B $a }
    set b [ttk::frame $P.b]
    pack $b -side top -fill x -pady {10 0}
    ttk::button $b.run -text "Cluster" -command {::VMDance::GUI::act cluster}
    ttk::button $b.def -text "Defaults" -command ::VMDance::GUI::param_defaults
    pack $b.run -side left
    pack $b.def -side left -padx {6 0}
    ::VMDance::Tip::add $b.def "The chosen algorithm's parameters back to their defaults"
}

# The fields of one algorithm's parameters (only the chosen algorithm's
# frame is shown).
proc ::VMDance::GUI::_build_params {B a} {
    set V ::VMDance::GUI::S
    set f [ttk::frame $B.$a -style Holder.TFrame]
    set r 0
    if {[::VMDance::Algo::takes_k $a]} {
        ttk::spinbox $f.k -from [expr {$a eq "helm" ? 0 : 1}] -to 100000 -increment 1 -width 6 -textvariable ${V}(k_$a)
        _row $f $r "Clusters (k)" $f.k [expr {$a eq "helm" ? "The number of clusters HELM merges down to (0: stop by \"Stop at\" only)" : "The number of clusters"}]
        grid configure $f.k -sticky w
        incr r
    }
    set mf [ttk::frame $f.met]
    _combo $mf.c ${V}(metric) [_same $::VMDance::Algo::metrics] {#}
    # (an algorithm that takes MSD only says why: the table's metric_why)
    ttk::label $mf.l -text [expr {[llength [::VMDance::Algo::metrics_of $a]] > 1 ? "MSD (Settings unlock the others)" :
        "[join [::VMDance::Algo::metrics_of $a] {, }] ([::VMDance::Algo::metric_why $a])"}] -style Muted.TLabel
    _row $f $r "Metric" $mf "The distance or similarity between frames: the mean square deviation (MSD) for Cartesian coordinates.\nThe other indices are for binary or fingerprint data (Settings ▸ Unlock the metrics)."
    set ::VMDance::GUI::metric_rows($a) $mf
    incr r
    foreach p [::VMDance::Algo::params $a] {
        lassign $p name type def lim label tip
        set var ${V}(p_${a}_$name)
        set wd $f.p[string map {- _} $name]
        switch -- $type {
            choice {
                _combo $wd $var [_param_choices $name $lim] ::VMDance::GUI::_params_sync
                _row $f $r $label $wd $tip
                grid configure $wd -sticky w
            }
            bool {
                ttk::checkbutton $wd -text $label -variable $var -command ::VMDance::GUI::_params_sync
                grid $wd -row $r -column 0 -columnspan 2 -sticky w -pady 1
                ::VMDance::Tip::add $wd $tip
            }
            file {
                ttk::frame $wd
                ttk::entry $wd.e -textvariable $var -width 14
                ttk::button $wd.b -text "…" -style Toolbutton -takefocus 0 -command [list ::VMDance::GUI::_browse_labels $var]
                pack $wd.e -side left -fill x -expand 1
                pack $wd.b -side left
                bind $wd.e <KeyRelease> ::VMDance::GUI::_params_sync
                _row $f $r $label $wd $tip
            }
            default {
                ttk::entry $wd -textvariable $var -width 8
                _row $f $r $label $wd $tip
                grid configure $wd -sticky w
            }
        }
        incr r
    }
    grid columnconfigure $f 1 -weight 1
    return $f
}
proc ::VMDance::GUI::_param_choices {name values} {
    set names [expr {$name in {kinit initial-kinit} ? $::VMDance::Algo::kinit_names : {}}]
    set out {}
    foreach v $values { lappend out $v [expr {[dict exists $names $v] ? [dict get $names $v] : $v}] }
    return $out
}

proc ::VMDance::GUI::_browse_labels {var} {
    variable w
    set f [tk_getOpenFile -parent $w -title "HELM's starting clusters: a label file" -filetypes {{"Label files" {.csv .txt .dat}} {"All files" *}}]
    if {$f ne ""} { set $var $f; _params_sync }
}

# The fields that do not apply are greyed: HELM's trim values without
# Trim first, its first clustering with a label file, DIVINE's seeding
# with anchors other than NANI, its smallest share with NANI (CPP-MDANCE's
# NANI splits do not use it) and its Refine always (a NANI split is a
# k-means already; CPP-MDANCE's DIVINE crashes refining the others),
# eQUAL's values of the options that are off.
# When a parameter's field is live (greyed out otherwise: the others' values
# make it mean nothing).
variable ::VMDance::GUI::param_rules {
    helm {initial {$S(p_helm_initial-labels) eq ""} initial-kinit {$S(p_helm_initial-labels) eq ""}
          initial-percentage {$S(p_helm_initial-labels) eq "" && $S(p_helm_initial-kinit) in {StratAll StratReduced CompSim DivSelect}}
          trim-k {$S(p_helm_trim-start)} trim-val {$S(p_helm_trim-start)} min-samples {$S(p_helm_trim-start)}}
    divine {kinit {$S(p_divine_anchors) eq "NANI"} refine {0} threshold {$S(p_divine_anchors) ne "NANI"}
            percentage {$S(p_divine_anchors) eq "NANI" && $S(p_divine_kinit) in {StratAll StratReduced CompSim DivSelect}}}
    equal {min-samples {$S(p_equal_reject-lowd)} sim-threshold {$S(p_equal_check-sim)}
           percentage {$S(p_equal_seed-method) eq "comp_sim"}}
    kmeans {percentage {$S(p_kmeans_kinit) in {StratAll StratReduced CompSim DivSelect}}}
}
proc ::VMDance::GUI::_param_on {a name} {
    variable S; variable param_rules
    if {![dict exists $param_rules $a $name]} { return 1 }
    expr [dict get $param_rules $a $name]
}
proc ::VMDance::GUI::_params_sync {} {
    variable S; variable parambox; variable param_rules
    if {$parambox eq "" || ![winfo exists $parambox]} return
    dict for {a rs} $param_rules {
        dict for {name cond} $rs {
            set on [_param_on $a $name]
            set wd $parambox.$a.p[string map {- _} $name]
            if {![winfo exists $wd]} continue
            set st [expr {$on ? "!disabled" : "disabled"}]
            if {[winfo class $wd] eq "TFrame"} { foreach c [winfo children $wd] { catch {$c state $st} } } else { $wd state $st }
            foreach l [grid slaves $parambox.$a -row [dict get [grid info $wd] -row] -column 0] {
                if {[winfo class $l] eq "TLabel"} { $l state $st }
            }
        }
    }
}

proc ::VMDance::GUI::_algorithm_changed {} {
    variable S; variable w; variable parambox; variable page
    if {$parambox eq "" || ![winfo exists $parambox]} return
    set a $S(algorithm)
    foreach x [::VMDance::Algo::all] {
        if {$x eq $a} { pack $parambox.$x -side top -fill x } else { pack forget $parambox.$x }
    }
    $parambox\_title configure -text "[::VMDance::Algo::label $a] parameters"
    catch {$page(setup).alg.about configure -text [string totitle [::VMDance::Algo::get $a about] 0 0]}
    # (off while a job runs, as _busy left it: the algorithm can be chosen
    # meanwhile)
    catch {$w.tb.elbow state [expr {[busy] || ![::VMDance::Algo::takes_k $a] ? "disabled" : "!disabled"}]}
    _metric_lock
    _params_sync
    _availability
    # (another algorithm's fields can need a wider panel)
    if {[winfo exists $w] && [winfo ismapped $w]} {
        after cancel ::VMDance::GUI::_panes
        after idle ::VMDance::GUI::_panes
    }
}
proc ::VMDance::GUI::_metric_lock {} {
    variable S; variable metric_rows; variable page
    if {!$S(unlock_metrics)} { set S(metric) MSD }
    foreach a [::VMDance::Algo::all] {
        if {![info exists metric_rows($a)] || ![winfo exists $metric_rows($a)]} continue
        set mf $metric_rows($a)
        if {$S(unlock_metrics) && [llength [::VMDance::Algo::metrics_of $a]] > 1} {
            pack forget $mf.l
            pack $mf.c -side left
        } else {
            pack forget $mf.c
            pack $mf.l -side left
        }
    }
    foreach wd [list $page(tools).si.m $page(tools).pk.m] {
        if {[winfo exists $wd]} { $wd state [expr {$S(unlock_metrics) ? "!disabled" : "disabled"}] }
    }
    if {!$S(unlock_metrics)} { set S(si_metric) MSD; set S(pk_metric) MSD }
    _grid_metrics
}

# What the backend in use offers (again: the backend asked again when it
# lacks one, as the chooser opens and the window is shown again: a
# launcher's stamp stays the same when the program it runs is rebuilt).
proc ::VMDance::GUI::_availability {{again 0}} {
    variable S; variable page
    set have {}
    if {[catch {::VMDance::Backend::algorithms} have]} {
        set S(unavailable) "No backend: [lindex [split $have \n] 0]. Settings ▸ Backend."
        return
    }
    if {$again && [llength $have] < [llength [::VMDance::Algo::all]]} { catch {set have [::VMDance::Backend::algorithms 1]} }
    # the chooser offers what the backend has (and the algorithm chosen,
    # which the note then says it has not); the sweep the same
    set c $page(setup).alg.c
    if {[winfo exists $c]} {
        $c configure -values [lmap a [::VMDance::Algo::all] {expr {$a in $have || $a eq $S(algorithm) ? [::VMDance::Algo::label $a] : [continue]}}]
    }
    foreach a [::VMDance::Algo::with_k] {
        set b $page(scans).gr.alg.$a
        if {![winfo exists $b]} continue
        if {$a in $have} { $b state !disabled } else { set S(gr_alg_$a) 0; $b state disabled }
    }
    _grid_count
    set miss [lmap a [::VMDance::Algo::all] {expr {$a in $have ? [continue] : [::VMDance::Algo::label $a]}}]
    if {$S(algorithm) ni $have} {
        set S(unavailable) "[::VMDance::Algo::label $S(algorithm)] is not in this build of the backend (CPP-MDANCE builds DIVINE only with BUILD_DIVINE)."
    } elseif {[llength $miss]} {
        set S(unavailable) "Not in this build of the backend: [join $miss {, }]."
    } else {
        set S(unavailable) ""
    }
    # (the library runs in VMD, which waits for each call: said here, and
    # when Automatic took it, finding no program, which nothing said)
    if {[_in_library]} {
        set S(unavailable) [string trim "$S(unavailable) The library clusters, in VMD, which does not respond during a clustering[expr {[dict get [::VMDance::Backend::settings] -mode] eq "auto" ? " (Automatic found no mdance-cli: Settings ▸ Backend)" : ""}]."]
    }
}
# Whether the backend in use is the library (VMD waits for each of its
# calls).
proc ::VMDance::GUI::_in_library {} {
    expr {![catch {::VMDance::Backend::current} u] && [lindex $u 0] eq "library"}
}

proc ::VMDance::GUI::param_defaults {} {
    variable S
    set a $S(algorithm)
    set S(k_$a) [::VMDance::Algo::default_k $a]
    foreach {k v} [::VMDance::Algo::defaults $a] { set S(p_${a}_$k) $v }
    _params_sync
    status "[::VMDance::Algo::label $a]: the default parameters."
}

proc ::VMDance::GUI::_fit_changed {} {
    variable w; variable S; variable page
    set e $page(setup).input.fit.sel
    if {[winfo exists $e]} { $e state [expr {$S(fit) ? "!disabled" : "disabled"}] }
}

proc ::VMDance::GUI::_frames_changed {} {
    variable w; variable S; variable page
    set fr $page(setup).input.fr
    if {![winfo exists $fr]} return
    foreach c [list $fr.first $fr.last] { $c state [expr {$S(framemode) eq "range" ? "!disabled" : "disabled"}] }
    _count_later
}

# The number of atoms of the selection and of frames, a moment after
# typing stops.
proc ::VMDance::GUI::_count_later {} {
    variable count_after
    after cancel $count_after
    set count_after [after 300 ::VMDance::GUI::_count]
}
proc ::VMDance::GUI::_count {} {
    variable S; variable w
    if {![winfo exists $w]} return
    # (frames added to a molecule change its line in the chooser)
    refresh_molecules
    set m $S(molid)
    if {$m < 0 || ![::VMDance::Mol::exists $m]} { set S(count) "no molecule"; set S(nframes) ""; return }
    set t [string trim $S(sel)]
    if {$t eq ""} {
        set S(count) "no atoms"
    } elseif {[catch {::VMDance::Mol::atoms $m $t} idx]} {
        set S(count) "invalid selection"
    } elseif {[set dw [::VMDance::Mol::dynamic $t]] ne ""} {
        set S(count) "changes with the frame (\"$dw\"): name the atoms"
    } else {
        set n [llength $idx]
        set S(count) [expr {$n == 0 ? "matches no atom" : ($n == 1 ? "1 atom" : "$n atoms")}]
    }
    lassign [_frame_range] first last
    set nf [molinfo $m get numframes]
    if {[catch {::VMDance::Mol::frames $m $first $last [string trim $S(step)]} fl]} {
        set S(nframes) [regsub {^-(first|last|step) } $fl {}]
    } else {
        set S(nframes) "[llength $fl] of $nf frame[expr {$nf == 1 ? "" : "s"}]"
    }
}
proc ::VMDance::GUI::_frame_range {} {
    variable S
    if {$S(framemode) eq "all"} { return {0 -1} }
    list [string trim $S(first)] [string trim $S(last)]
}

#---------------------------------------------------------------------------
# Results
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_build_results {P} {
    variable tree; variable runcombo
    set V ::VMDance::GUI::S
    set rf [ttk::frame $P.run]
    pack $rf -side top -fill x
    ttk::label $rf.l -text "Run"
    ttk::combobox $rf.c -state readonly -width 26 -textvariable ${V}(run_label) -postcommand ::VMDance::GUI::_runs_combo
    set runcombo $rf.c
    bind $rf.c <<ComboboxSelected>> ::VMDance::GUI::_run_chosen
    ttk::menubutton $rf.m -text "▾" -menu $rf.m.m -style Toolbutton -takefocus 0
    menu $rf.m.m -tearoff 0
    $rf.m.m add command -label "Rename this run…" -command ::VMDance::GUI::rename_run
    $rf.m.m add command -label "Delete this run" -command ::VMDance::GUI::delete_run
    $rf.m.m add separator
    $rf.m.m add command -label "Clear every run…" -command {::VMDance::GUI::act clear}
    pack $rf.l -side left -padx {0 6}
    pack $rf.c -side left -fill x -expand 1
    pack $rf.m -side left
    ::VMDance::Tip::add $rf.c "Every clustering is kept (the last 25): choose one to see it again, with its settings"
    ttk::label $P.sum -textvariable ${V}(summary) -style Read.TLabel -wraplength 290 -justify left
    pack $P.sum -side top -fill x -pady {4 4}

    set T [ttk::frame $P.tf]
    pack $T -side top -fill both -expand 1 -pady {2 0}
    set tree [ttk::treeview $T.t -columns {cluster frames pct msd spread rep} -show headings -selectmode extended -height 12]
    foreach {c t} {cluster Cluster frames Frames pct "%" msd MSD spread "To rep." rep "Rep."} {
        $tree heading $c -text $t -command [list ::VMDance::GUI::sort_by $c]
        $tree column $c -anchor e -stretch [expr {$c eq "cluster"}]
    }
    ::VMDance::Tip::add $tree "MSD: the mean square deviation within the cluster (the backend's, MDANCE's: over its pairs of frames, Å²);\nto rep.: the mean RMSD² of its frames from its representative (Å²: from half the MSD to all of it, with the metric MSD).\nClick a heading to sort; right-click for more."
    ttk::scrollbar $T.s -orient vertical -command [list $tree yview]
    $tree configure -yscrollcommand [list $T.s set]
    pack $T.s -side right -fill y
    pack $tree -side left -fill both -expand 1
    bind $tree <<TreeviewSelect>> ::VMDance::GUI::_on_select
    # (a double-click on a heading sorts: it does not act on the selected row)
    bind $tree <Double-1> {if {[%W identify region %x %y] eq "cell"} {::VMDance::GUI::act goto}}
    bind $tree <Button-3> {::VMDance::GUI::_tree_menu %X %Y}
    if {[tk windowingsystem] eq "aqua"} { bind $tree <Button-2> {::VMDance::GUI::_tree_menu %X %Y} }
    menu $tree.m -tearoff 0
    $tree.m add command -label "Go to its representative" -command {::VMDance::GUI::act goto}
    $tree.m add command -label "Overlay its frames in 3D" -command ::VMDance::GUI::overlay_selected
    $tree.m add command -label "Select every cluster" -command {::VMDance::GUI::select_all}
    $tree.m add command -label "Clear the selection" -command {::VMDance::GUI::select {}}
    $tree.m add separator
    $tree.m add command -label "Print to the console" -command ::VMDance::GUI::print_selected
    ttk::label $P.det -textvariable ${V}(detail) -style Read.TLabel -wraplength 290 -justify left
    pack $P.det -side top -fill x -pady {4 0}
    set b [ttk::frame $P.b]
    pack $b -side top -fill x -pady {6 0}
    ttk::button $b.goto -text "Go to representative" -command {::VMDance::GUI::act goto}
    ttk::button $b.ov -text "Overlay in 3D" -command ::VMDance::GUI::overlay_selected
    pack $b.goto $b.ov -side left -padx {0 6}

    # this run's groups of frames, its map and its profiles
    set G [_section $P.gp "Groups, map and profiles" -padding {6 4}]
    pack ${G}_sec -side top -fill x -pady {8 0}
    ttk::entry $G.r -textvariable ${V}(gp_ranges) -width 18
    ttk::button $G.set -text "Set" -command {::VMDance::GUI::act groups}
    grid [ttk::label $G.lr -text "Groups"] $G.r $G.set -row 0 -sticky w -padx {0 4} -pady 1
    grid configure $G.r -sticky ew
    ::VMDance::Tip::add $G.r "Each frame's group (the method, replica or condition it came from): names and VMD frames, as original 0-63 moderate 64-127 (a name with spaces in braces); Return sets them"
    bind $G.r <Return> {::VMDance::GUI::act groups}
    set gb [ttk::frame $G.bt]
    ttk::button $gb.file -text "From a file…" -command {::VMDance::GUI::act groups_file}
    ttk::button $gb.clear -text "Clear" -command {::VMDance::GUI::act groups_clear}
    pack $gb.file $gb.clear -side left -padx {0 6}
    grid $gb -row 1 -column 1 -columnspan 2 -sticky w -pady 1
    ::VMDance::Tip::add $gb.file "A file of frame,group lines (VMD frames; # comments)"
    ttk::label $G.info -textvariable ${V}(gp_info) -style Read.TLabel -wraplength 270 -justify left
    grid $G.info -row 2 -column 0 -columnspan 3 -sticky w
    set mf [ttk::frame $G.mf]
    ttk::button $mf.go -text "Map" -command {::VMDance::GUI::act map}
    ttk::label $mf.l -text "axes from"
    ttk::spinbox $mf.n -from 2 -to 5000 -increment 100 -width 5 -textvariable ${V}(mp_sample)
    ttk::label $mf.f -text "frames"
    pack $mf.go $mf.l $mf.n $mf.f -side left -padx {0 4}
    grid $mf -row 3 -column 0 -columnspan 3 -sticky w -pady {4 1}
    ::VMDance::Tip::add $mf.n [lindex [lindex $::VMDance::Algo::map_params 0] 5]
    set pf [ttk::frame $G.pf]
    ttk::button $pf.go -text "Profiles" -command {::VMDance::GUI::act profiles}
    ttk::label $pf.l -text "against cluster"
    ttk::spinbox $pf.n -from -1 -to 9999 -increment 1 -width 5 -textvariable ${V}(pf_reference)
    pack $pf.go $pf.l $pf.n -side left -padx {0 4}
    grid $pf -row 4 -column 0 -columnspan 3 -sticky w -pady 1
    ::VMDance::Tip::add $pf.n [lindex [lindex $::VMDance::Algo::profiles_params 0] 5]
    ttk::label $G.mi -textvariable ${V}(mp_info) -style Read.TLabel -wraplength 270 -justify left
    grid $G.mi -row 5 -column 0 -columnspan 3 -sticky w
    grid columnconfigure $G 1 -weight 1
    _tree_columns
}

# The tables' columns as wide as their headings and values at the text
# size of now.
proc ::VMDance::GUI::_tree_columns {} {
    variable tree; variable swtree
    set m {apply {{a b} {expr {max([font measure MdvUI $a], [font measure MdvUI $b]) + 12}}}}
    if {$tree ne "" && [winfo exists $tree]} {
        foreach {c h t} {cluster Cluster 000 frames Frames 00000 pct "%" 100.0 msd MSD 0.00000 spread "To rep." 0.00000 rep "Rep." 00000} {
            set wd [{*}$m $h $t]
            $tree column $c -width $wd -minwidth [expr {int($wd * 0.8)}]
        }
    }
    if {$swtree ne "" && [winfo exists $swtree]} {
        foreach {c h t} {alg Algorithm DIVINE k k 00 kact Found 00 metric Metric MSD seed Seeding StratAll ch CH 0000 db DB 0.000} {
            $swtree column $c -width [expr {[{*}$m $h $t] - 2}] -minwidth 20
        }
    }
}

#---------------------------------------------------------------------------
# Scans
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_build_scans {P} {
    variable swtree
    set V ::VMDance::GUI::S
    set E [_section $P.eb "Elbow" -padding {6 4}]
    pack ${E}_sec -side top -fill x
    set r [ttk::frame $E.r]
    ttk::label $r.l -text "k from"
    ttk::spinbox $r.a -from 1 -to 1000 -increment 1 -width 4 -textvariable ${V}(eb_from)
    ttk::label $r.t -text "to"
    ttk::spinbox $r.b -from 2 -to 1000 -increment 1 -width 4 -textvariable ${V}(eb_to)
    ttk::label $r.e -text "every"
    ttk::spinbox $r.c -from 1 -to 100 -increment 1 -width 3 -textvariable ${V}(eb_by)
    pack $r.l $r.a $r.t $r.b $r.e $r.c -side left -padx {0 4}
    grid $r -row 0 -column 0 -sticky w
    set q [ttk::frame $E.q]
    ttk::label $q.l -text "eQUAL: radius from"
    ttk::entry $q.a -width 5 -textvariable ${V}(eb_rfrom)
    ttk::label $q.t -text "to"
    ttk::entry $q.b -width 5 -textvariable ${V}(eb_rto)
    ttk::label $q.e -text "every"
    ttk::entry $q.c -width 5 -textvariable ${V}(eb_rby)
    pack $q.l $q.a $q.t $q.b $q.e $q.c -side left -padx {0 4}
    grid $q -row 1 -column 0 -sticky w -pady {4 0}
    ::VMDance::Tip::add $q.l "eQUAL is given no k: with eQUAL in Setup, the scan runs it at these radii (MDANCE's MSD, Å²)"
    ttk::label $E.note -text "The algorithm and parameters of Setup, at every k (eQUAL: at every radius). Elbow plot: hover a value for the clusters' shares; double-click to make it the clustering." \
        -style Muted.TLabel -wraplength 280 -justify left
    grid $E.note -row 2 -column 0 -sticky w -pady {2 0}
    ttk::checkbutton $E.st -text "Stability: compare NANI's four seedings at each k" -variable ${V}(eb_stab)
    grid $E.st -row 3 -column 0 -sticky w -pady {2 0}
    ::VMDance::Tip::add $E.st "K-means NANI only: each k is clustered again from StratAll, StratReduced, CompSim and DivSelect, and the Elbow plot shows how alike they are (the mean adjusted Rand index: 1, the same clusters). A k whose clusters change with the seeding cuts a continuum."
    ttk::label $E.info -textvariable ${V}(eb_info) -style Read.TLabel -wraplength 280 -justify left
    grid $E.info -row 4 -column 0 -sticky w
    ttk::button $E.go -text "Scan" -command {::VMDance::GUI::act elbow}
    grid $E.go -row 5 -column 0 -sticky w -pady {4 2}

    set G [_section $P.gr "Sweep" -padding {6 4}]
    pack ${G}_sec -side top -fill x -pady {6 0}
    set af [ttk::frame $G.alg]
    foreach a [::VMDance::Algo::with_k] {
        ttk::checkbutton $af.$a -text [::VMDance::Algo::label $a] -variable ${V}(gr_alg_$a) -command ::VMDance::GUI::_grid_count
        pack $af.$a -side left -padx {0 8}
    }
    grid $af -row 0 -column 0 -sticky w
    set r [ttk::frame $G.r]
    ttk::label $r.l -text "k from"
    ttk::spinbox $r.a -from 1 -to 1000 -increment 1 -width 4 -textvariable ${V}(gr_from) -command ::VMDance::GUI::_grid_count
    ttk::label $r.t -text "to"
    ttk::spinbox $r.b -from 1 -to 1000 -increment 1 -width 4 -textvariable ${V}(gr_to) -command ::VMDance::GUI::_grid_count
    ttk::label $r.e -text "every"
    ttk::spinbox $r.c -from 1 -to 100 -increment 1 -width 3 -textvariable ${V}(gr_by) -command ::VMDance::GUI::_grid_count
    foreach e [list $r.a $r.b $r.c] { bind $e <KeyRelease> ::VMDance::GUI::_grid_count }
    pack $r.l $r.a $r.t $r.b $r.e $r.c -side left -padx {0 4}
    grid $r -row 1 -column 0 -sticky w -pady {3 0}
    ttk::label $G.ml -text "Metrics" -style Muted.TLabel
    grid $G.ml -row 2 -column 0 -sticky w -pady {3 0}
    set mf [ttk::frame $G.met]
    set i 0
    foreach m $::VMDance::Algo::metrics {
        ttk::checkbutton $mf.m_$m -text $m -variable ${V}(gr_met_$m) -command ::VMDance::GUI::_grid_count
        grid $mf.m_$m -row [expr {$i / 4}] -column [expr {$i % 4}] -sticky w -padx {0 4}
        incr i
    }
    grid $mf -row 3 -column 0 -sticky w
    ttk::label $G.sl -text "Seedings (HELM: its first clustering's)" -style Muted.TLabel
    grid $G.sl -row 4 -column 0 -sticky w -pady {3 0}
    set sf [ttk::frame $G.seed]
    set i 0
    foreach k $::VMDance::Algo::kinits {
        ttk::checkbutton $sf.s_$k -text $k -variable ${V}(gr_seed_$k) -command ::VMDance::GUI::_grid_count
        grid $sf.s_$k -row [expr {$i / 3}] -column [expr {$i % 3}] -sticky w -padx {0 6}
        ::VMDance::Tip::add $sf.s_$k [dict get $::VMDance::Algo::kinit_names $k]
        incr i
    }
    grid $sf -row 5 -column 0 -sticky w
    set b [ttk::frame $G.b]
    ttk::button $b.go -text "Sweep" -command {::VMDance::GUI::act sweep}
    ttk::label $b.n -textvariable ${V}(gr_count) -style Muted.TLabel
    pack $b.go -side left
    pack $b.n -side left -padx {8 0}
    grid $b -row 6 -column 0 -sticky w -pady {4 2}
    grid columnconfigure $G 0 -weight 1

    set T [ttk::frame $P.tf]
    pack $T -side top -fill both -expand 1 -pady {6 0}
    set swtree [ttk::treeview $T.t -columns {alg k kact metric seed ch db} -show headings -selectmode browse -height 6]
    foreach {c t} {alg Algorithm k k kact Found metric Metric seed Seeding ch CH db DB} {
        $swtree heading $c -text $t -command [list ::VMDance::GUI::_sweep_sort $c]
        $swtree column $c -anchor [expr {$c in {alg metric seed} ? "w" : "e"}] -stretch [expr {$c eq "alg"}]
    }
    _tree_columns
    ttk::scrollbar $T.s -orient vertical -command [list $swtree yview]
    $swtree configure -yscrollcommand [list $T.s set]
    pack $T.s -side right -fill y
    pack $swtree -side left -fill both -expand 1
    $swtree tag configure failed -foreground #b3261e
    $swtree tag configure bestch -background #d6f0d6
    $swtree tag configure bestdb -background #d6e4f5
    $swtree tag configure bestboth -background #d2ebe8
    # (a double-click on a heading sorts: it does not act on the selected row)
    bind $swtree <Double-1> {if {[%W identify region %x %y] eq "cell"} ::VMDance::GUI::adopt_sweep_selected}
    ::VMDance::Tip::add $swtree "CH: Calinski–Harabasz (higher: better, green: the best); DB: Davies–Bouldin (lower: better, blue: the best);\nteal: the best on both.\nDouble-click a row to make it the clustering."
    set b2 [ttk::frame $P.b2]
    pack $b2 -side top -fill x -pady {4 0}
    ttk::button $b2.load -text "Make it the clustering" -command ::VMDance::GUI::adopt_sweep_selected
    pack $b2.load -side left
}

# The configurations of the Sweep section.
proc ::VMDance::GUI::_grid_configs {} {
    variable S
    set algs [lmap a [::VMDance::Algo::with_k] {expr {$S(gr_alg_$a) ? $a : [continue]}}]
    set mets [lmap m $::VMDance::Algo::metrics {expr {$S(gr_met_$m) ? $m : [continue]}}]
    set seeds [lmap k $::VMDance::Algo::kinits {expr {$S(gr_seed_$k) ? $k : [continue]}}]
    # (the command's values of k: counted before they are made, at every
    # key typed)
    set ks [::VMDance::_ks "vmdance sweep" [dict create -ks "" -from [string trim $S(gr_from)] \
        -to [string trim $S(gr_to)] -by [string trim $S(gr_by)]] {} 1000]
    set params {}
    foreach a $algs { dict set params $a [_params_of $a] }
    ::VMDance::sweep_configs $algs $ks $mets $seeds $params
}
proc ::VMDance::GUI::_grid_count {} {
    variable S
    if {[catch {_grid_configs} cf]} { set S(gr_count) $cf; return }
    set n [llength $cf]
    set S(gr_count) "$n configuration[expr {$n == 1 ? "" : "s"}]"
}
proc ::VMDance::GUI::_grid_metrics {} {
    variable S; variable w; variable page
    set mf $page(scans).gr.met
    if {![winfo exists $mf]} return
    foreach m $::VMDance::Algo::metrics {
        if {$m eq "MSD"} continue
        if {$S(unlock_metrics)} { $mf.m_$m state !disabled } else { set S(gr_met_$m) 0; $mf.m_$m state disabled }
    }
    if {!$S(unlock_metrics)} { set S(gr_met_MSD) 1 }
    _grid_count
}

#---------------------------------------------------------------------------
# Tools
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_build_tools {P} {
    variable prtree; variable picklist
    set V ::VMDance::GUI::S
    set R [_section $P.pr "PRIME: the native frame" -padding {6 4}]
    pack ${R}_sec -side top -fill x
    _combo $R.m ${V}(pr_metric) {RR "Russell–Rao (RR)" SM "Sokal–Michener (SM)"} {#}
    _row $R 0 "Similarity" $R.m [lindex [lindex $::VMDance::Algo::prime_params 0] 5]
    grid configure $R.m -sticky w
    ttk::spinbox $R.t -from 0 -to 0.99 -increment 0.05 -width 5 -textvariable ${V}(pr_trim)
    _row $R 1 "Trim" $R.t [lindex [lindex $::VMDance::Algo::prime_params 1] 5]
    grid configure $R.t -sticky w
    ttk::checkbutton $R.w -text "Weight by size" -variable ${V}(pr_weighted)
    grid $R.w -row 2 -column 0 -columnspan 2 -sticky w
    ttk::button $R.go -text "Predict" -command {::VMDance::GUI::act prime}
    grid $R.go -row 3 -column 0 -columnspan 2 -sticky w -pady {4 2}
    set prtree [ttk::treeview $R.tv -columns {method frame} -show headings -selectmode browse -height 7]
    $prtree heading method -text "Method"
    $prtree heading frame -text "Frame"
    $prtree column method -width 190 -stretch 1
    $prtree column frame -width 60 -anchor e
    $prtree tag configure prediction -background #e3f1e3
    grid $prtree -row 4 -column 0 -columnspan 2 -sticky ew
    # (a double-click on a heading sorts: it does not act on the selected row)
    bind $prtree <Double-1> {if {[%W identify region %x %y] eq "cell"} ::VMDance::GUI::_prime_goto}
    ::VMDance::Tip::add $prtree "PRIME ranks the frames of the largest cluster by their similarity to the other clusters (green); the medoids are the baselines.\nDouble-click a row: go to that frame."
    ttk::label $R.info -textvariable ${V}(pr_info) -style Muted.TLabel -wraplength 280 -justify left
    grid $R.info -row 5 -column 0 -columnspan 2 -sticky w
    grid columnconfigure $R 1 -weight 1

    set M [_section $P.si "Similarity (iSIM)" -padding {6 4}]
    pack ${M}_sec -side top -fill x -pady {6 0}
    _combo $M.m ${V}(si_metric) [_same $::VMDance::Algo::metrics] {#}
    _row $M 0 "Metric" $M.m
    grid configure $M.m -sticky w
    ttk::button $M.go -text "Compute" -command {::VMDance::GUI::act similarity}
    grid $M.go -row 1 -column 0 -columnspan 2 -sticky w -pady {4 2}
    ttk::label $M.info -textvariable ${V}(si_info) -style Read.TLabel -wraplength 280 -justify left
    grid $M.info -row 2 -column 0 -columnspan 2 -sticky w
    grid columnconfigure $M 1 -weight 1

    set K [_section $P.pk "Pick frames" -padding {6 4}]
    pack ${K}_sec -side top -fill both -expand 1 -pady {6 0}
    _combo $K.meth ${V}(pk_method) $::VMDance::Algo::pick_names ::VMDance::GUI::_pick_sync
    _row $K 0 "Method" $K.meth [lindex [lindex $::VMDance::Algo::pick_params 0] 5]
    grid configure $K.meth -sticky w
    ttk::entry $K.p -textvariable ${V}(pk_param) -width 6
    _row $K 1 "How many" $K.p [lindex [lindex $::VMDance::Algo::pick_params 1] 5]
    grid configure $K.p -sticky w
    ttk::spinbox $K.b -from 2 -to 100 -increment 1 -width 4 -textvariable ${V}(pk_nbins)
    _row $K 2 "Bins" $K.b [lindex [lindex $::VMDance::Algo::pick_params 2] 5]
    grid configure $K.b -sticky w
    _combo $K.m ${V}(pk_metric) [_same $::VMDance::Algo::metrics] {#}
    _row $K 3 "Metric" $K.m
    grid configure $K.m -sticky w
    ttk::label $K.note -text "Among the molecule, atoms and frames of Setup; no clustering needed." -style Muted.TLabel -wraplength 280 -justify left
    grid $K.note -row 4 -column 0 -columnspan 2 -sticky w
    set b [ttk::frame $K.bt]
    ttk::button $b.go -text "Pick" -command {::VMDance::GUI::act pick}
    ttk::button $b.save -text "Save…" -command ::VMDance::GUI::save_picks_dialog
    ttk::checkbutton $b.show -text "In 3D" -variable ${V}(v3d_picks) -command ::VMDance::GUI::draw_changed
    pack $b.go $b.save $b.show -side left -padx {0 6}
    grid $b -row 5 -column 0 -columnspan 2 -sticky w -pady {4 2}
    ttk::label $K.info -textvariable ${V}(pk_info) -style Read.TLabel
    grid $K.info -row 6 -column 0 -columnspan 2 -sticky w
    set lf [ttk::frame $K.lf]
    set picklist [listbox $lf.l -height 5 -activestyle none -exportselection 0]
    ttk::scrollbar $lf.s -orient vertical -command [list $picklist yview]
    $picklist configure -yscrollcommand [list $lf.s set]
    pack $lf.s -side right -fill y
    pack $picklist -side left -fill both -expand 1
    grid $lf -row 7 -column 0 -columnspan 2 -sticky nsew
    grid rowconfigure $K 7 -weight 1
    grid columnconfigure $K 1 -weight 1
    bind $picklist <Double-1> {::VMDance::GUI::_pick_goto}
    ::VMDance::Tip::add $picklist "Double-click a frame: go to it"
    _pick_sync
}
proc ::VMDance::GUI::_pick_sync {} {
    variable S; variable w; variable page
    set K $page(tools).pk
    if {![winfo exists $K]} return
    $K.p state [expr {$S(pk_method) in {medoid outlier} ? "disabled" : "!disabled"}]
    $K.b state [expr {$S(pk_method) eq "repsample" ? "!disabled" : "disabled"}]
}

#---------------------------------------------------------------------------
# 3D
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_build_3d {P} {
    variable styles; variable keybox
    set V ::VMDance::GUI::S
    set O [_section $P.ov "Clusters on the structure" -padding {6 4}]
    pack ${O}_sec -side top -fill x
    ttk::checkbutton $O.col -text "Colour by cluster" -variable ${V}(v3d_colour) -command ::VMDance::GUI::draw_changed
    grid $O.col -row 0 -column 0 -columnspan 2 -sticky w -pady 1
    ::VMDance::Tip::add $O.col "The structure in the colour of the cluster of VMD's current frame (the clustered frame at or before it);\nit follows the trajectory as it plays. Grey: noise, or not clustered."
    ttk::checkbutton $O.reps -text "Every cluster's representative" -variable ${V}(v3d_reps) -command ::VMDance::GUI::draw_changed
    grid $O.reps -row 1 -column 0 -columnspan 2 -sticky w -pady 1
    ttk::checkbutton $O.ov -text "Overlay" -variable ${V}(v3d_overlay) -command ::VMDance::GUI::draw_changed
    grid $O.ov -row 2 -column 0 -columnspan 2 -sticky w -pady 1
    set tf [ttk::frame $O.top]
    ttk::radiobutton $tf.r -text "the selected clusters'" -variable ${V}(v3d_mode) -value top -command ::VMDance::GUI::draw_changed
    ttk::spinbox $tf.n -from 1 -to 1000 -increment 1 -width 4 -textvariable ${V}(v3d_top) -command ::VMDance::GUI::draw_changed
    ttk::label $tf.l -text "nearest frames"
    pack $tf.r $tf.n $tf.l -side left -padx {0 3}
    ::VMDance::Tip::add $tf "Each selected cluster's frames nearest its representative (the first is the representative)"
    bind $tf.n <Return> ::VMDance::GUI::draw_changed
    grid $tf -row 3 -column 0 -columnspan 2 -sticky w -padx {18 0}
    set ff [ttk::frame $O.fr]
    ttk::radiobutton $ff.r -text "frames" -variable ${V}(v3d_mode) -value frames -command ::VMDance::GUI::draw_changed
    # (typing frames chooses them: what the user types and not what the
    # command or a session sets)
    ttk::entry $ff.e -textvariable ${V}(v3d_frames) -width 12 -validate key \
        -validatecommand {set ::VMDance::GUI::S(v3d_mode) frames; expr 1}
    pack $ff.r -side left -padx {0 3}
    pack $ff.e -side left -fill x -expand 1
    bind $ff.e <Return> ::VMDance::GUI::draw_changed
    # (typed after the choice was made: taken when the field is left, when
    # it changed: everything drawn is made again)
    bind $ff.e <FocusOut> {
        if {$::VMDance::GUI::S(v3d_mode) eq "frames" &&
            [string trim $::VMDance::GUI::S(v3d_frames)] ne [dict get [::VMDance::Viz::get] frames]} { ::VMDance::GUI::draw_changed }
    }
    grid $ff -row 4 -column 0 -columnspan 2 -sticky ew -padx {18 0}
    ::VMDance::Tip::add $ff.e "Frames and ranges: 0-100,500,900-1000 (each in its cluster's colour)"
    ttk::checkbutton $O.pk -text "The picked frames (Tools)" -variable ${V}(v3d_picks) -command ::VMDance::GUI::draw_changed
    grid $O.pk -row 5 -column 0 -columnspan 2 -sticky w -pady 1
    _combo $O.style ${V}(v3d_style) [_same $styles] ::VMDance::GUI::draw_changed
    _row $O 6 "Style" $O.style
    grid configure $O.style -sticky w
    ttk::entry $O.sel -textvariable ${V}(v3d_sel) -width 14
    bind $O.sel <Return> ::VMDance::GUI::draw_changed
    bind $O.sel <FocusOut> {
        if {[string trim $::VMDance::GUI::S(v3d_sel)] ne [dict get [::VMDance::Viz::get] sel]} { ::VMDance::GUI::draw_changed }
    }
    _row $O 7 "Atoms" $O.sel "The atoms drawn (empty: the residues of the clustered atoms)"
    _combo $O.mat ${V}(v3d_material) [_same [material list]] ::VMDance::GUI::draw_changed
    _row $O 8 "Material" $O.mat
    grid configure $O.mat -sticky w
    set b [ttk::frame $O.b]
    ttk::button $b.goto -text "Go to representative" -command {::VMDance::GUI::act goto}
    ttk::button $b.user -text "User field…" -command {::VMDance::GUI::act userfield}
    pack $b.goto $b.user -side left -padx {0 6}
    grid $b -row 9 -column 0 -columnspan 2 -sticky w -pady {6 2}
    ::VMDance::Tip::add $b.user "Write every frame's cluster into VMD's user field (Coloring Method: User)"
    ttk::label $O.hint -text "The plugin adds representations of its own and deletes only those; the molecule's data are left alone." \
        -style Muted.TLabel -wraplength 270 -justify left
    grid $O.hint -row 10 -column 0 -columnspan 2 -sticky w -pady {4 0}
    grid columnconfigure $O 1 -weight 1
    set K [_section $P.key "Colours" -padding {6 4}]
    pack ${K}_sec -side top -fill both -expand 1 -pady {6 0}
    set keybox $K
}

# The key of the clusters' colours (VMD's colour of each).
proc ::VMDance::GUI::_colour_key {} {
    variable keybox
    if {$keybox eq "" || ![winfo exists $keybox]} return
    foreach c [winfo children $keybox] { destroy $c }
    if {![::VMDance::Results::has_data]} {
        ttk::label $keybox.none -text "No clustering yet." -style Muted.TLabel
        grid $keybox.none -row 0 -column 0 -sticky w
        return
    }
    set k [::VMDance::Results::nclusters]
    set names [colorinfo colors]
    set rows [expr {min($k, 30)}]
    set cols [expr {$rows > 12 ? 2 : 1}]
    set per [expr {int(ceil(double($rows) / $cols))}]
    for {set c 0} {$c < $rows} {incr c} {
        set id [::VMDance::Viz::colour_id $c]
        set r [expr {$c % $per}]; set col [expr {2 * ($c / $per)}]
        canvas $keybox.c$c -width 14 -height 10 -highlightthickness 0 -background [::VMDance::Plots::ccol $c 0]
        ttk::label $keybox.l$c -text "$c ([lindex $names $id] in VMD)"
        grid $keybox.c$c -row $r -column $col -sticky w -padx {0 4} -pady 1
        grid $keybox.l$c -row $r -column [expr {$col + 1}] -sticky w -padx {0 10}
    }
    if {$k > $rows} {
        ttk::label $keybox.more -text "… $k clusters: the colours repeat" -style Muted.TLabel
        grid $keybox.more -row $per -column 0 -columnspan 4 -sticky w
    }
    if {[::VMDance::Results::noise]} {
        canvas $keybox.cn -width 14 -height 10 -highlightthickness 0 -background [::VMDance::Plots::ccol -1 0]
        ttk::label $keybox.ln -text "noise ([lindex $names $::VMDance::Viz::noise_id] in VMD)"
        grid $keybox.cn -row [expr {$per + 1}] -column 0 -sticky w -padx {0 4}
        grid $keybox.ln -row [expr {$per + 1}] -column 1 -sticky w
    }
    ::VMDance::Theme::style_tree $keybox
}

#---------------------------------------------------------------------------
# The plots
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_build_right {} {
    variable w; variable tabs
    set R [ttk::frame $w.pw.right -padding {4 0 0 0}]
    $w.pw add $R -weight 1
    set nb [ttk::notebook $R.nb]
    pack $nb -side top -fill both -expand 1
    foreach {key title} $tabs {
        set f [ttk::frame $nb.$key]
        set img [::VMDance::Icons::get tab_$key 16]
        if {$img ne ""} {
            $nb add $f -text $title -image $img -compound left
        } else {
            $nb add $f -text $title
        }
        set o [ttk::frame $f.opts -padding {4 4 4 2}]
        pack $o -side top -fill x
        canvas $f.c -background white -highlightthickness 0 -width 460 -height 340
        pack $f.c -side top -fill both -expand 1
        bind $f.c <Configure> ::VMDance::GUI::redraw_later
        bind $f.c <Motion> [list ::VMDance::GUI::_hover $key %W %x %y]
        bind $f.c <Leave> [list ::VMDance::GUI::_leave $key %W]
        bind $f.c <ButtonPress-1> [list ::VMDance::GUI::_click $key %W %x %y 0]
        bind $f.c <Shift-ButtonPress-1> [list ::VMDance::GUI::_click $key %W %x %y 1]
        bind $f.c <Double-ButtonPress-1> [list ::VMDance::GUI::_dclick $key %W %x %y]
        _build_tab_opts $key $o
    }
    bind $nb <<NotebookTabChanged>> ::VMDance::GUI::_tab_changed
    ttk::frame $R.rf
    # (the readout shown is cut to the line's width, ending in "…")
    ttk::label $R.rf.readout -textvariable ::VMDance::GUI::S(readout_shown) -style Read.TLabel -padding {6 0}
    pack $R.rf.readout -side left -fill both -expand 1
    pack propagate $R.rf 0
    pack $R.rf -side top -fill x
    trace add variable ::VMDance::GUI::S(readout) write ::VMDance::GUI::_readout
    bind $R.rf <Configure> ::VMDance::GUI::_readout
    _readout
}
proc ::VMDance::GUI::_readout {args} {
    variable S; variable w
    set l $w.pw.right.rf.readout
    if {![winfo exists $l]} { set S(readout_shown) $S(readout); return }
    set room [expr {[winfo width $w.pw.right.rf] - 14}]
    set S(readout_shown) [expr {$room > 40 ? [::VMDance::Plot::elide MdvUISmall $room $S(readout)] : $S(readout)}]
}

# Only the selected plot tab shows its name; the others show their icon.
proc ::VMDance::GUI::_tab_labels {} {
    variable w; variable tabs
    set nb $w.pw.right.nb
    if {![winfo exists $nb]} return
    set cur [$nb select]
    foreach {key title} $tabs {
        if {[$nb tab $nb.$key -image] eq ""} continue
        $nb tab $nb.$key -text [expr {"$nb.$key" eq $cur ? $title : ""}]
    }
}

proc ::VMDance::GUI::_show_hint {key} {
    variable S; variable hints
    set S(readout) [dict get $hints $key]
}

# Option row above each plot (without the Plot options panel).
proc ::VMDance::GUI::_build_tab_opts {key o} {
    set V ::VMDance::GUI::S
    switch -- $key {
        populations {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(po_show) {count "Frames" percent "Share of the frames"}
            ttk::label $o.l2 -text "Order"
            _combo $o.o ${V}(po_sort) {cluster "Cluster" size "Size"}
            pack $o.l1 $o.s $o.l2 $o.o -side left -padx {0 6}
        }
        makeup {
            ttk::label $o.l1 -text "Bars"
            _combo $o.v ${V}(mu_view) {clusters "Clusters by group" groups "Groups by cluster"}
            ttk::label $o.l2 -text "Show"
            _combo $o.s ${V}(mu_show) {count "Frames" share "Shares"}
            pack $o.l1 $o.v $o.l2 $o.s -side left -padx {0 6}
        }
        timeline {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(tl_view) {lanes "The cluster of every frame" msd "Distance to its representative"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        map {
            ttk::label $o.l1 -text "Colour by"
            _combo $o.s ${V}(mp_colour) {group "Group" cluster "Cluster"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        profiles {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(pf_show) {groups "Each group's fluctuations" clusters "Each cluster's fluctuations" differences "Each cluster against the reference"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        transitions {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(tn_show) {probability "Probabilities" counts "Counts"}
            ttk::checkbutton $o.d -text "Staying (the diagonal)" -variable ${V}(tn_self) -command ::VMDance::GUI::redraw
            pack $o.l1 $o.s $o.d -side left -padx {0 6}
        }
        residence {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(rs_show) {mean "Mean stay (whisker: the longest)" visits "Visits"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        compactness {
            ttk::label $o.l1 -text "Show"
            _combo $o.s ${V}(cp_show) {msd "MSD within" spread "RMSD² from the representative" scatter "MSD against size" isim "Extended similarity (iSIM)"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        distances {
            ttk::label $o.l1 -text "Between"
            _combo $o.s ${V}(ds_show) {centroids "Mean structures (RMSD²)" representatives "Representatives (RMSD)"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        tree {
            ttk::label $o.l1 -text "Show"
            _combo $o.v ${V}(td_view) {tree "The tree" heights "The merges' heights"}
            ttk::checkbutton $o.l -text "Labels" -variable ${V}(td_labels) -command ::VMDance::GUI::redraw
            pack $o.l1 $o.v $o.l -side left -padx {0 6}
        }
        silhouette {
            ttk::checkbutton $o.s -text "Sorted" -variable ${V}(sl_sort) -command ::VMDance::GUI::redraw
            ttk::checkbutton $o.m -text "Mean" -variable ${V}(sl_mean) -command ::VMDance::GUI::redraw
            pack $o.s $o.m -side left -padx {0 6}
        }
        elbow {
            ttk::label $o.l1 -text "Scores"
            _combo $o.s ${V}(eb_show) {both "Both" ch "Calinski–Harabasz" db "Davies–Bouldin"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
        sweep {
            ttk::label $o.l1 -text "Score"
            _combo $o.s ${V}(sw_score) {ch "Calinski–Harabasz" db "Davies–Bouldin"}
            pack $o.l1 $o.s -side left -padx {0 6}
        }
    }
}

#---------------------------------------------------------------------------
# Molecules
#---------------------------------------------------------------------------

proc ::VMDance::GUI::refresh_molecules {} {
    variable S; variable molcombo
    set ch [::VMDance::Mol::choices]
    set vals [dict values $ch]
    if {$molcombo ne "" && [winfo exists $molcombo]} { $molcombo configure -values $vals }
    if {$S(molid) >= 0 && ![dict exists $ch $S(molid)]} { set S(molid) -1 }
    if {$S(molid) < 0 && [dict size $ch]} {
        set top [molinfo top]
        set S(molid) [expr {[dict exists $ch $top] ? $top : [lindex [dict keys $ch] 0]}]
    }
    set S(molname) [expr {$S(molid) >= 0 ? [dict get $ch $S(molid)] : ""}]
}

proc ::VMDance::GUI::_mol_chosen {} {
    variable S
    set S(molid) [lindex [split $S(molname) :] 0]
    status "Molecule $S(molid): [molinfo $S(molid) get numatoms] atoms, [molinfo $S(molid) get numframes] frames."
    _count_later
}

#---------------------------------------------------------------------------
# Running jobs
#---------------------------------------------------------------------------

# The parameters of algorithm a from the Setup fields.
# (a greyed-out field is not sent: a switch as off, a value left to its
# default; DIVINE's Refine is greyed, off)
proc ::VMDance::GUI::_params_of {a} {
    variable S
    set out {}
    foreach n [::VMDance::Algo::param_names $a] {
        if {![_param_on $a $n]} {
            if {[lindex [::VMDance::Algo::param $a $n] 1] eq "bool"} { dict set out $n 0 }
            continue
        }
        dict set out $n [string trim $S(p_${a}_$n)]
    }
    return $out
}

# The input of Setup: what is clustered.
proc ::VMDance::GUI::input_request {} {
    variable S
    lassign [_frame_range] first last
    # (what is typed, as typed: expr's ?: would make "010" 8, and fail on
    # "NaN")
    set fit ""
    if {$S(fit)} { set fit [string trim $S(fitsel)] }
    dict create mol $S(molid) sel [string trim $S(sel)] fit $fit \
        first $first last $last step [string trim $S(step)]
}

# The clustering request of Setup (not yet checked).
proc ::VMDance::GUI::request {} {
    variable S
    set a $S(algorithm)
    set req [input_request]
    dict set req algorithm $a
    set k ""
    if {[::VMDance::Algo::takes_k $a]} { set k [string trim $S(k_$a)] }
    dict set req k $k
    # (the metric unlocked for the others: DIVINE's and eQUAL's is MSD)
    set metric $S(metric)
    if {$metric ni [::VMDance::Algo::metrics_of $a]} { set metric [lindex [::VMDance::Algo::metrics_of $a] 0] }
    dict set req metric $metric
    dict set req params [_params_of $a]
    return $req
}

proc ::VMDance::GUI::_error {msg {parent ""}} {
    variable w
    if {$parent eq ""} { set parent $w }
    tk_messageBox -parent $parent -icon error -title VMDance -message $msg
}

# Start a job: kind, the checked request, what the status says, and what
# to do with its value (a command prefix: value appended).
proc ::VMDance::GUI::_start {kind req msg then} {
    variable S; variable own_job; variable setup0; variable setup_kept
    _busy 1
    set S(progress) 1
    status "$msg…"
    set own_job 1
    set setup0 [_setup_state]
    set setup_kept 0
    if {[catch {::VMDance::Job::start $kind $req ::VMDance::GUI::_progress [list ::VMDance::GUI::_job_done $kind $then]} err]} {
        set own_job 0
        set setup0 ""
        _busy 0
        _error "The job could not be started:\n$err"
    }
}

proc ::VMDance::GUI::cluster {} {
    variable S
    if {[busy]} return
    if {$S(molid) < 0 || ![::VMDance::Mol::exists $S(molid)]} { _error "Load a molecule first."; return }
    if {[catch {::VMDance::Job::check_cluster [request]} req]} { _error "Not clustered:\n$req"; return }
    if {[catch {::VMDance::Job::check_available [dict get $req algorithm]} err]} { _error $err; return }
    set n [llength [dict get $req frames]]
    _start cluster $req "Clustering $n frames with [::VMDance::Algo::label [dict get $req algorithm]]" \
        [list apply {{a} {
            ::VMDance::Results::publish $a
            ::VMDance::GUI::status "[::VMDance::_summary] — in [dict get $a seconds] s."
            ::VMDance::GUI::show_pane results
        }}]
}

proc ::VMDance::GUI::elbow {} {
    variable S
    if {[busy]} return
    if {$S(molid) < 0 || ![::VMDance::Mol::exists $S(molid)]} { _error "Load a molecule first."; return }
    set req [request]
    if {[catch {
        # (the command's values of k: counted before they are made)
        dict set req ks [::VMDance::_ks "vmdance elbow" [dict create -ks "" -from [string trim $S(eb_from)] \
            -to [string trim $S(eb_to)] -by [string trim $S(eb_by)]] {} 200]
        if {$S(eb_stab) && [dict get $req algorithm] eq "kmeans"} { dict set req stability $::VMDance::Algo::deterministic_kinits }
        if {[dict get $req algorithm] eq "equal"} {
            dict set req ks {}
            dict set req radii [_radii]
        }
        set req [::VMDance::Job::check_elbow [dict remove $req k]]
        ::VMDance::Job::check_available [dict get $req algorithm]
    } err]} { _error "No elbow scan:\n$err"; return }
    set rr [::VMDance::_get $req radii {}]
    set at [expr {[llength $rr] ? "radius [lindex $rr 0] to [lindex $rr end]" : "k = [lindex [dict get $req ks] 0] to [lindex [dict get $req ks] end]"}]
    _start elbow $req "Elbow scan of [::VMDance::Algo::label [dict get $req algorithm]] at $at" \
        [list apply {{s} {
            ::VMDance::Results::set_elbow $s
            set bad [llength [lmap r [dict get $s records] {expr {[dict get $r status] eq "ok" ? [continue] : 1}}]]
            ::VMDance::GUI::status "Elbow scan done in [dict get $s seconds] s[expr {$bad ? "; $bad value[expr {$bad == 1 ? "" : "s"}] of k failed" : ""}]."
            ::VMDance::GUI::show_tab elbow
        }}]
}

# eQUAL's radii of Scans ▸ Elbow: from, to, every (numbers above 0; 200
# values at most).
proc ::VMDance::GUI::_radii {} {
    variable S
    foreach k {eb_rfrom eb_rto eb_rby} {
        set v [string trim $S($k)]
        if {![string is double -strict $v] || [regexp -nocase {nan|inf} $v] || $v <= 0} { error "eQUAL's radii: from, to and every are numbers above 0 (got \"$v\")" }
        set $k $v
    }
    if {$eb_rto < $eb_rfrom} { error "eQUAL's radii: \"to\" is below \"from\"" }
    set n [expr {int(floor(($eb_rto - $eb_rfrom) / $eb_rby + 1e-9)) + 1}]
    if {$n > 200} { error "eQUAL's radii: $n values; at most 200" }
    set out {}
    for {set i 0} {$i < $n} {incr i} { lappend out [format %.6g [expr {$eb_rfrom + $i * $eb_rby}]] }
    return $out
}

proc ::VMDance::GUI::sweep {} {
    variable S; variable w
    if {[busy]} return
    if {$S(molid) < 0 || ![::VMDance::Mol::exists $S(molid)]} { _error "Load a molecule first."; return }
    if {[catch {
        set req [input_request]
        dict set req configs [_grid_configs]
        set req [::VMDance::Job::check_sweep $req]
    } err]} { _error "No sweep:\n$err"; return }
    set n [llength [dict get $req configs]]
    if {$n > 50 && [tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
            -message "The sweep runs $n clusterings. Go on?" -detail [expr {[_in_library] ?
                "Each clustering runs in the library, in VMD, which does not respond during one; Cancel stops the sweep between two." :
                "It runs in the background; Cancel stops it."}]] ne "ok"} return
    _start sweep $req "Sweeping $n configurations" \
        [list apply {{s} {
            ::VMDance::Results::set_sweep $s
            ::VMDance::GUI::status [::VMDance::GUI::_sweep_words $s]
            ::VMDance::GUI::show_tab sweep
            ::VMDance::GUI::show_pane scans
        }}]
}

# A scan's record made the clustering: elbow k, or sweep index.
proc ::VMDance::GUI::adopt {kind which} {
    variable S
    if {[busy]} return
    set s [expr {$kind eq "elbow" ? $::VMDance::Results::elbow : $::VMDance::Results::sweep}]
    if {![dict size $s]} return
    if {$kind eq "elbow"} {
        set rec [::VMDance::Results::elbow_record $s $which]
    } else {
        set rec [lindex [dict get $s records] $which]
    }
    if {![dict size $rec]} return
    if {[dict get $rec status] ne "ok"} { status "That one failed: [dict get $rec message]"; return }
    _start adopt [dict create scan $s record $rec] "Making it the clustering" \
        [list apply {{a} {
            ::VMDance::Results::publish $a
            ::VMDance::GUI::status "[::VMDance::_summary]: from the scan."
            ::VMDance::GUI::show_pane results
        }}]
}
proc ::VMDance::GUI::adopt_sweep_selected {} {
    variable swtree
    set it [$swtree selection]
    if {$it eq ""} { status "Choose a configuration in the table first."; return }
    adopt sweep [string range [lindex $it 0] 1 end]
}
proc ::VMDance::GUI::sweep_row {i} {
    variable swtree
    if {[$swtree exists r$i]} { $swtree selection set r$i; $swtree see r$i }
}

proc ::VMDance::GUI::prime {} {
    variable S
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: PRIME works on the clusters."; return }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::prime_params \
            [dict create metric $S(pr_metric) trim-frac [string trim $S(pr_trim)] weighted $S(pr_weighted)]} p]} { _error "No PRIME:\n$p"; return }
    _start prime [dict create result $::VMDance::Results::A params $p] "PRIME" \
        [list apply {{run r} {
            ::VMDance::Results::attach prime $r $run
            if {$run == $::VMDance::Results::current} {
                ::VMDance::GUI::status "PRIME: the native-like frame is [dict get [::VMDance::prime_frames] pairwise] (pairwise)."
            } else {
                ::VMDance::GUI::status "PRIME: kept with run $run."
            }
            ::VMDance::GUI::show_pane tools
        }} $::VMDance::Results::current]
}

proc ::VMDance::GUI::similarity {} {
    variable S
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: the similarity is the clusters'."; return }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::similarity_params [dict create metric $S(si_metric)]} p]} { _error $p; return }
    _start similarity [dict create result $::VMDance::Results::A params $p] "Extended similarity (iSIM)" \
        [list apply {{run r} {
            ::VMDance::Results::attach similarity $r $run
            set ::VMDance::GUI::S(cp_show) isim
            ::VMDance::GUI::show_tab compactness
            ::VMDance::GUI::status "Extended similarity of all frames: [format %.4g [dict get $r isim]]."
        }} $::VMDance::Results::current]
}

proc ::VMDance::GUI::groups_set {} {
    variable S
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: the groups are given to the clustered frames."; return }
    if {[string trim $S(gp_ranges)] eq ""} { _error "Give each group a name and its frames: original 0-63 moderate 64-127"; return }
    if {[catch {::VMDance::Results::groups_from ranges [string trim $S(gp_ranges)] [::VMDance::Results::frames]} g] ||
        [catch {::VMDance::Results::set_groups [::VMDance::Results::keep_colours $g]} g]} { _error "No groups:\n$g"; return }
    status "Groups: [join [::VMDance::Results::group_names] {, }]."
    show_tab makeup
}
proc ::VMDance::GUI::groups_file_dialog {} {
    variable w
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: the groups are given to the clustered frames."; return }
    set f [tk_getOpenFile -parent $w -title "The frames' groups" -filetypes {{"Tables" {.csv .txt}} {"All files" *}}]
    if {$f eq ""} return
    if {[catch {::VMDance::Results::groups_from file $f [::VMDance::Results::frames]} g] ||
        [catch {::VMDance::Results::set_groups [::VMDance::Results::keep_colours $g]} g]} { _error "No groups:\n$g"; return }
    status "Groups from [file tail $f]: [join [::VMDance::Results::group_names] {, }]."
    show_tab makeup
}
proc ::VMDance::GUI::groups_clear {} {
    if {[busy] || ![::VMDance::Results::has_data]} return
    ::VMDance::Results::set_groups {}
    status "The frames have no groups."
}
proc ::VMDance::GUI::_groups_info {} {
    variable S
    set gi [expr {[::VMDance::Results::has_data] ? [::VMDance::groups_info] : {}}]
    if {![dict size $gi]} {
        set S(gp_info) [expr {[::VMDance::Results::has_data] ? "No groups for this clustering." : ""}]
    } else {
        set S(gp_info) [join [lmap nm [dict get $gi names] n [dict get $gi sizes] {string cat "$nm: $n"}] ", "]
        if {[dict get $gi none]} { append S(gp_info) ", [dict get $gi none] in none" }
    }
    set parts {}
    set m [expr {[::VMDance::Results::has_data] ? [::VMDance::Results::extra map] : {}}]
    if {[dict size $m]} {
        lassign [dict get $m variance] v1 v2
        lappend parts [format "Map: %.0f%% and %.0f%% of the variance (axes from %d frames)" [expr {100 * $v1}] [expr {100 * $v2}] [dict get $m sample]]
    }
    set p [expr {[::VMDance::Results::has_data] ? [::VMDance::Results::extra profiles] : {}}]
    if {[dict size $p]} { lappend parts "Profiles: against cluster [dict get $p reference]" }
    set S(mp_info) [join $parts ". "]
}
proc ::VMDance::GUI::map {} {
    variable S
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: the map is of the clustered frames."; return }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::map_params [dict create sample [string trim $S(mp_sample)]]} p]} { _error "No map:\n$p"; return }
    _start map [dict create result $::VMDance::Results::A params $p] "The map: principal components" \
        [list apply {{run r} {
            ::VMDance::Results::attach map $r $run
            ::VMDance::GUI::show_tab map
            ::VMDance::GUI::status [format "Map: %.0f%% and %.0f%% of the variance." [expr {100 * [lindex [dict get $r variance] 0]}] [expr {100 * [lindex [dict get $r variance] 1]}]]
        }} $::VMDance::Results::current]
}
proc ::VMDance::GUI::profiles {} {
    variable S
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Cluster first: the profiles are of the clusters."; return }
    if {[catch {
        set p [::VMDance::Job::check_specs $::VMDance::Algo::profiles_params [dict create reference [string trim $S(pf_reference)]]]
        if {[dict get $p reference] >= 0} { ::VMDance::_cluster "Against cluster" [dict get $p reference] }
    } err]} { _error "No profiles:\n$err"; return }
    _start profiles [dict create result $::VMDance::Results::A params $p groups [::VMDance::Results::groups]] "The profiles, atom by atom" \
        [list apply {{run r} {
            ::VMDance::Results::attach profiles $r $run
            ::VMDance::GUI::show_tab profiles
            ::VMDance::GUI::status "Profiles: [llength [dict get $r residues]] atoms, against cluster [dict get $r reference]."
        }} $::VMDance::Results::current]
}

proc ::VMDance::GUI::pick {} {
    variable S
    if {[busy]} return
    if {$S(molid) < 0 || ![::VMDance::Mol::exists $S(molid)]} { _error "Load a molecule first."; return }
    if {[catch {
        set req [::VMDance::Job::check_input [input_request]]
        dict set req params [::VMDance::Job::check_specs $::VMDance::Algo::pick_params \
            [dict create method $S(pk_method) param [string trim $S(pk_param)] nbins [string trim $S(pk_nbins)] metric $S(pk_metric)]]
        ::VMDance::Job::check_pick [dict get $req params] [llength [dict get $req frames]]
    } err]} { _error "No frames picked:\n$err"; return }
    _start pick $req "Picking frames ([dict get $::VMDance::Algo::pick_names $S(pk_method)])" \
        [list apply {{r} {
            ::VMDance::Results::set_picks $r
            set n [llength [dict get $r vmdframes]]
            ::VMDance::GUI::status "$n frame[expr {$n == 1 ? "" : "s"}] picked."
            ::VMDance::GUI::show_pane tools
        }}]
}

# Progress: the window is refreshed at most every 250 ms within a step,
# and at once for a new one (its text other than in its numbers: "reading
# frame 9 of 99" is the step of "reading frame 5 of 99"; the step posted
# just before a call that blocks VMD, the library's, was dropped, and the
# reading's last count shown through the call); the last message held back
# is shown when the 250 ms are up (the one before a long step stays up).
proc ::VMDance::GUI::_progress {frac msg} {
    variable S; variable last_progress; variable last_step; variable progress_after
    after cancel $progress_after
    set progress_after ""
    set now [clock milliseconds]
    set step [regsub -all {[0-9]+} $msg #]
    if {$frac < 1.0 && $now - $last_progress < 250 && $step eq $last_step} {
        set progress_after [after [expr {250 - ($now - $last_progress)}] [list ::VMDance::GUI::_progress $frac $msg]]
        return
    }
    set last_progress $now
    set last_step $step
    set S(progress) [expr {max(1.0, 100.0 * $frac)}]
    set S(status) "$msg…"
}

proc ::VMDance::GUI::_job_done {kind then st result} {
    variable S; variable w; variable redraws; variable progress_after; variable own_job; variable setup0; variable setup_kept
    # (a message held back never comes after the end)
    after cancel $progress_after
    set own_job 0
    _busy 0
    set S(progress) 0
    set n $redraws
    switch -- $st {
        cancelled {
            # (the backend stopped from outside says how)
            if {$result ne ""} { status "Cancelled: $result; what was there is kept." } else { status "Cancelled; what was there is kept." }
        }
        error {
            status "Failed; what was there is kept."
            if {[winfo exists $w]} { _error $result }
        }
        default {
            if {[catch {{*}$then $result} err]} {
                status "Failed; what was there is kept."
                if {[winfo exists $w]} { _error "The result could not be kept:\n$err" }
            } elseif {$setup_kept} {
                status "$S(status) Setup keeps what was changed while it ran."
            }
        }
    }
    # (a job its value started, the import of a file onto the molecule of
    # Setup, keeps the snapshot it took)
    if {!$own_job} {
        set setup0 ""
        set setup_kept 0
    }
    # what was asked while it ran returned early (a tab shown, a column
    # sorted): shown now, unless the result has just been drawn
    if {[winfo exists $w] && $redraws == $n} {
        populate_tree
        redraw
    }
}

# A job of the command's (from the console or a script): the window is
# busy while it runs, as for its own.
proc ::VMDance::GUI::_job_changed {what kind} {
    variable w; variable S; variable console_job; variable redraws; variable setup0; variable setup_kept
    if {![winfo exists $w]} return
    if {$what eq "start"} {
        if {!$S(busy)} {
            set console_job 1
            # (what is changed in Setup meanwhile is kept, as for the
            # window's own job)
            set setup0 [_setup_state]
            set setup_kept 0
            _busy 1
            status "A job of the command's is running ($kind)…"
        }
    } elseif {$console_job} {
        set console_job 0
        _busy 0
        status ""
        populate_tree
        redraw
        # (the command publishes once this returns, before the event loop
        # runs again: _sync_setup compares Setup with setup0 then)
        after idle ::VMDance::GUI::_console_job_done
    }
}
# A job of the command's has ended, and its result is published: Setup
# follows the results again, and the line says what it kept.
proc ::VMDance::GUI::_console_job_done {} {
    variable setup0; variable setup_kept
    # (another job has started since: the snapshot is its)
    if {[busy]} return
    if {$setup_kept} { status "Setup keeps what was changed while the command's job ran." }
    set setup0 ""
    set setup_kept 0
}

proc ::VMDance::GUI::cancel {} {
    ::VMDance::Job::cancel
}

# While a job runs, what would start another, change the results or
# draw in 3D is disabled (the handlers refuse it too); afterwards the 3D
# tab shows what is drawn.
proc ::VMDance::GUI::_busy {on} {
    variable w; variable S; variable page; variable tree
    set S(busy) $on
    if {![winfo exists $w]} return
    set idle [expr {$on ? "disabled" : "normal"}]
    set run [expr {$on ? "normal" : "disabled"}]
    foreach b {open save export figure cluster elbow goto render colour reps settings} {
        if {[winfo exists $w.tb.$b]} { $w.tb.$b configure -state $idle }
    }
    if {!$on && [winfo exists $w.tb.elbow] && ![::VMDance::Algo::takes_k $S(algorithm)]} { $w.tb.elbow configure -state disabled }
    if {[winfo exists $w.tb.cancel]} { $w.tb.cancel configure -state $run }
    foreach b [list $page(setup).b.run $page(setup).b.def $page(results).b.goto $page(results).b.ov \
               $page(scans).eb.go $page(scans).gr.b.go $page(scans).b2.load \
               $page(tools).pr.go $page(tools).si.go $page(tools).pk.bt.go $page(tools).pk.bt.save $page(tools).pk.bt.show] {
        catch {$b configure -state $idle}
    }
    foreach c [_descendants $page(v3d)] {
        if {[winfo class $c] in {TButton TCheckbutton TRadiobutton TEntry TSpinbox TCombobox}} {
            $c state [expr {$on ? "disabled" : "!disabled"}]
        }
    }
    foreach {m labels} {file {"Open session…" "Save session" "Save session as…" "Import a session of the MDANCE plugin (.mdance)…"
                              "Export results…" "Create figures…" "Quick export"}
                        cl {Cluster "Elbow scan" Sweep "PRIME: predict the native frame" "Similarity of the clusters (iSIM)"
                            "Pick frames" Runs "Rename this run…" "Delete this run" "Clear every run…" "Settings…"}} {
        foreach l $labels { catch {$w.menu.$m entryconfigure $l -state $idle} }
    }
    for {set i 0} {$i <= [$w.menu.v3d index end]} {incr i} {
        if {[$w.menu.v3d type $i] ne "separator"} { $w.menu.v3d entryconfigure $i -state $idle }
    }
    if {$tree ne "" && [winfo exists $tree.m]} {
        foreach i {0 1} { $tree.m entryconfigure $i -state $idle }
    }
    catch {$w.menu.cl entryconfigure Cancel -state $run}
    $w configure -cursor [expr {$on ? "watch" : ""}]
    # (the Export and Figures dialogs left open wait for the job too)
    foreach d [list $w.export $w.figures] {
        if {![winfo exists $d.f.b.ok]} continue
        $d.f.b.ok state [expr {$on ? "disabled" : "!disabled"}]
        $d configure -cursor [expr {$on ? "watch" : ""}]
    }
    if {!$on} {
        _draw_options
        _pick_sync
    }
    _draw_progress
}

#---------------------------------------------------------------------------
# Listening to the results
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_results_changed {what} {
    variable w
    if {![winfo exists $w]} return
    switch -- $what {
        analysis {
            _sync_setup
            _run_label
            populate_tree
            _prime_table
            _similarity_info
            _groups_info
            _colour_key
            redraw_soon
        }
        selection {
            _sync_tree_selection
            _details
            redraw_soon
        }
        runs { _run_label }
        extras {
            _prime_table
            _similarity_info
            _groups_info
            redraw_soon
        }
        elbow {
            _elbow_info
            if {[_current_tab] eq "elbow"} redraw_soon
        }
        sweep {
            _sweep_table
            if {[_current_tab] eq "sweep"} redraw_soon
        }
        picks { _pick_list }
    }
    # (what the drawing, made again, draws otherwise than asked: said after
    # what the window says of the run, as by draw and the 3D tab)
    if {$what in {analysis picks} && [llength $::VMDance::Viz::notes]} { after idle ::VMDance::GUI::_draw_status }
}

# Setup shows the settings of the clustering shown; what was changed in it
# while a job ran (the window's or the command's) is kept for the next
# Cluster (_job_done, _console_job_done say so), and left alone until the
# job ends. Left unchanged, it takes the job's settings, and the snapshot
# is done with: what a script publishes next, before the event loop runs
# (vmdance run, session load), is followed too.
proc ::VMDance::GUI::_sync_setup {} {
    variable S; variable setup0; variable setup_kept
    if {![::VMDance::Results::has_data]} return
    if {$setup0 ne ""} {
        if {[busy]} return
        if {[_setup_state] ne $setup0} { set setup_kept 1; return }
        set setup0 ""
    }
    set q [::VMDance::Results::request]
    if {[::VMDance::Mol::exists [dict get $q mol]]} { set S(molid) [dict get $q mol] }
    refresh_molecules
    set S(sel) [dict get $q sel]
    set S(fit) [expr {[dict get $q fit] ne ""}]
    if {$S(fit)} { set S(fitsel) [dict get $q fit] }
    set S(step) [dict get $q step]
    if {[dict get $q first] == 0 && [dict get $q last] == -1} {
        set S(framemode) all
    } else {
        set S(framemode) range
        set S(first) [dict get $q first]
        set S(last) [dict get $q last]
    }
    set a [dict get $q algorithm]
    set S(algorithm) $a
    if {[dict get $q k] ne ""} { set S(k_$a) [dict get $q k] }
    # (an import whose file does not record them: the Setup's are left)
    if {![llength [::VMDance::Results::meta unrecorded]]} {
        if {$S(unlock_metrics) || [dict get $q metric] eq "MSD"} { set S(metric) [dict get $q metric] }
        dict for {k v} [dict get $q params] { if {[info exists S(p_${a}_$k)]} { set S(p_${a}_$k) $v } }
    }
    _algorithm_changed
    _frames_changed
    _fit_changed
}
# What of Setup a clustering's settings replace (_sync_setup): the next
# Cluster's.
proc ::VMDance::GUI::_setup_state {} {
    variable S
    set out {}
    foreach k [lsort [array names S]] {
        if {$k in {molid sel fit fitsel framemode first last step algorithm metric} || [regexp {^[kp]_} $k]} { lappend out $k $S($k) }
    }
    return $out
}

#---------------------------------------------------------------------------
# Runs
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_run_text {r} {
    lassign $r id label
    return "$id: $label"
}
proc ::VMDance::GUI::_run_label {} {
    variable S
    set cur $::VMDance::Results::current
    set S(run_label) ""
    foreach r [::VMDance::Results::run_list] {
        if {[lindex $r 0] eq $cur} { set S(run_label) [_run_text $r] }
    }
}
proc ::VMDance::GUI::_runs_combo {} {
    variable runcombo
    $runcombo configure -values [lreverse [lmap r [::VMDance::Results::run_list] {_run_text $r}]]
}
proc ::VMDance::GUI::_run_chosen {} {
    variable S
    if {[busy]} { _run_label; return }
    set id [lindex [split $S(run_label) :] 0]
    if {$id ne $::VMDance::Results::current} { ::VMDance::Results::run_switch $id }
}
proc ::VMDance::GUI::_runs_menu {} {
    variable w
    set m $w.menu.cl.runs
    $m delete 0 end
    set runs [::VMDance::Results::run_list]
    if {![llength $runs]} { $m add command -label "No run yet" -state disabled; return }
    variable S
    set S(run_menu) $::VMDance::Results::current
    foreach r [lreverse $runs] {
        $m add radiobutton -label [_run_text $r] -variable ::VMDance::GUI::S(run_menu) -value [lindex $r 0] \
            -command [list ::VMDance::GUI::switch_run [lindex $r 0]] -state [expr {[busy] ? "disabled" : "normal"}]
    }
}
proc ::VMDance::GUI::switch_run {id} {
    variable S
    if {[busy]} { set S(run_menu) $::VMDance::Results::current; return }
    ::VMDance::Results::run_switch $id
}
proc ::VMDance::GUI::rename_run {} {
    if {[busy] || ![::VMDance::Results::has_data]} return
    set id $::VMDance::Results::current
    set cur [lindex [lsearch -inline -index 0 [::VMDance::Results::run_list] $id] 1]
    set new [_ask "Rename run $id" "Name of the run:" $cur]
    if {$new eq "" || [lsearch -index 0 [::VMDance::Results::run_list] $id] < 0} return
    ::VMDance::Results::run_label $id $new
}
proc ::VMDance::GUI::delete_run {} {
    variable w
    if {[busy] || ![::VMDance::Results::has_data]} return
    set id $::VMDance::Results::current
    if {[tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
            -message "Delete run $id? The other runs are kept."] ne "ok"} return
    ::VMDance::Results::run_delete $id
}
proc ::VMDance::GUI::clear_all {} {
    variable w
    if {[busy]} return
    if {![::VMDance::Results::has_data] && ![dict size $::VMDance::Results::elbow] &&
        ![dict size $::VMDance::Results::sweep] && ![dict size $::VMDance::Results::picks]} {
        status "There is nothing to clear."
        return
    }
    if {[tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
            -message "Clear every run, the elbow scan, the sweep and the picked frames?" \
            -detail "Saved sessions and exported files are not affected. The plugin's representations are deleted."] ne "ok"} return
    # (Save session then asks where: Session forgets the file opened)
    ::VMDance::Results::clear_all
    status "Every run cleared."
}

# A one-line question; "" when cancelled.
proc ::VMDance::GUI::_ask {title prompt value} {
    variable w; variable ask
    set d $w.ask
    catch {destroy $d}
    toplevel $d
    wm title $d $title
    wm transient $d $w
    set ask(v) $value
    set ask(ok) 0
    set f [ttk::frame $d.f -padding 12]
    pack $f -fill both -expand 1
    ttk::label $f.l -text $prompt
    ttk::entry $f.e -textvariable ::VMDance::GUI::ask(v) -width 36
    set b [ttk::frame $f.b]
    ttk::button $b.ok -text OK -command {set ::VMDance::GUI::ask(ok) 1; destroy .vmdance.ask}
    ttk::button $b.c -text Cancel -command {destroy .vmdance.ask}
    pack $b.c $b.ok -side right -padx {6 0}
    pack $f.l $f.e -side top -fill x -pady {0 6}
    pack $b -side top -fill x
    ::VMDance::Theme::style_tree $d
    bind $d <Return> {set ::VMDance::GUI::ask(ok) 1; destroy .vmdance.ask}
    bind $d <Escape> {destroy .vmdance.ask}
    ::focus $f.e
    $f.e selection range 0 end
    catch {grab set $d}
    tkwait window $d
    if {!$ask(ok)} { return "" }
    string trim $ask(v)
}

#---------------------------------------------------------------------------
# The table of clusters
#---------------------------------------------------------------------------

proc ::VMDance::GUI::populate_tree {} {
    variable S; variable tree
    if {$tree eq "" || ![winfo exists $tree]} return
    $tree delete [$tree children {}]
    if {![::VMDance::Results::has_data]} {
        set S(summary) "No clustering yet: choose what to cluster in Setup and press Cluster."
        set S(detail) ""
        return
    }
    set rows [::VMDance::Results::table]
    set col [dict get {cluster 0 frames 1 pct 2 msd 3 spread 4 rep 5} $S(sortcol)]
    set keyed [lmap r $rows {list [lindex $r 0] [expr {[lindex $r $col] eq "" ? -1e300 : [lindex $r $col]}] $r}]
    set rows [lmap p [lsort -real -index 1 [expr {$S(sortdir) > 0 ? "-increasing" : "-decreasing"}] $keyed] {lindex $p 2}]
    foreach r $rows {
        lassign $r c n pct msd spread rep
        $tree insert {} end -id c$c -tags c$c -values [list $c $n $pct \
            [expr {$msd eq "" ? "n/a" : [format %.4g $msd]}] [expr {$spread eq "" ? "n/a" : [format %.4g $spread]}] \
            [expr {$rep < 0 ? "–" : $rep}]]
        $tree tag configure c$c -background [::VMDance::Cmap::tint [::VMDance::Plots::ccol $c 0] 0.82]
    }
    _sync_tree_selection
    _summary
    _details
}

proc ::VMDance::GUI::_summary {} {
    variable S
    set a $::VMDance::Results::A
    set q [dict get $a request]
    set nf [llength [dict get $a frames]]
    set k [dict get $a nclusters]
    set s "[::VMDance::Algo::label [dict get $q algorithm]][expr {[dict get $q k] ne "" ? ", k [dict get $q k]" : ""}] of $nf frames × [dict get $a natoms] atoms: $k cluster[expr {$k == 1 ? "" : "s"}]"
    set n [::VMDance::Results::noise]
    if {$n} { append s ", $n noise frame[expr {$n == 1 ? "" : "s"}]" }
    # (the only text of a run opened from a session, or switched to)
    set why [::VMDance::_fewer]
    if {$why ne ""} { append s " — $why" }
    append s ". Calinski–Harabasz [::VMDance::Plots::_sc [dict get $a ch]] (higher: better), Davies–Bouldin [::VMDance::Plots::_sc [dict get $a db]] (lower: better)."
    set S(summary) $s
}

# The selected clusters in words, under the table.
proc ::VMDance::GUI::_details {} {
    variable S
    if {![::VMDance::Results::has_data]} { set S(detail) ""; return }
    set sel [::VMDance::Results::selected]
    if {![llength $sel]} { set S(detail) "Select a cluster: it is shown on top in every plot, and its frames can be overlaid in 3D."; return }
    if {[llength $sel] > 1} {
        set n [::tcl::mathop::+ {*}[lmap c $sel {::VMDance::Results::size $c}]]
        set S(detail) "Clusters [join $sel {, }] selected: $n frames."
        return
    }
    set c [lindex $sel 0]
    # (the command refuses while a job runs; the window only reads)
    if {[catch {::VMDance::cluster_info $c} d]} { set S(detail) ""; return }
    set S(detail) [format "Cluster %d: %d frames (%s%%), representative frame %s; mean silhouette %s; %d visit%s, %s clustered frames on average, the longest %d." \
        $c [dict get $d frames] [dict get $d percent] [dict get $d representative] \
        [expr {[dict get $d silhouette] eq "" ? "n/a" : [dict get $d silhouette]}] [dict get $d visits] \
        [expr {[dict get $d visits] == 1 ? "" : "s"}] [dict get $d mean_residence] [dict get $d longest_residence]]
}

proc ::VMDance::GUI::sort_by {col} {
    variable S
    if {$S(sortcol) eq $col} {
        set S(sortdir) [expr {-$S(sortdir)}]
    } else {
        set S(sortcol) $col
        set S(sortdir) [expr {$col in {frames pct msd spread} ? -1 : 1}]
    }
    populate_tree
}

proc ::VMDance::GUI::_on_select {} {
    variable sel_after; variable tree
    # (the table set to the selection: its event comes later, and changes nothing)
    if {[lsort [lmap it [$tree selection] {string range $it 1 end}]] eq [::VMDance::Results::selected]} return
    after cancel $sel_after
    set sel_after [after 40 ::VMDance::GUI::_selection_changed]
}
proc ::VMDance::GUI::_selection_changed {} {
    variable tree
    if {[busy] || ![::VMDance::Results::has_data]} return
    ::VMDance::Results::set_selection [lmap it [$tree selection] {string range $it 1 end}]
}
proc ::VMDance::GUI::_sync_tree_selection {} {
    variable tree
    if {$tree eq "" || ![winfo exists $tree]} return
    set want [lmap c [::VMDance::Results::selected] {expr {[$tree exists c$c] ? "c$c" : [continue]}}]
    if {[lsort $want] eq [lsort [$tree selection]]} return
    $tree selection set $want
    if {[llength $want]} { $tree see [lindex $want 0] }
}
proc ::VMDance::GUI::_tree_menu {X Y} {
    variable tree
    if {[busy] || ![::VMDance::Results::has_data]} return
    tk_popup $tree.m $X $Y
}
proc ::VMDance::GUI::select_all {} {
    set all {}
    for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} { lappend all $c }
    select $all
}
proc ::VMDance::GUI::print_selected {} {
    foreach c [::VMDance::Results::selected] { puts "VMDance) [::VMDance::_api_get $c]" }
}
proc ::VMDance::GUI::goto_selected {} {
    if {[busy] || ![::VMDance::Results::has_data]} return
    set sel [::VMDance::Results::selected]
    if {![llength $sel]} { status "Select a cluster first (the table or a plot)."; return }
    goto_cluster [lindex $sel 0]
}
proc ::VMDance::GUI::overlay_selected {} {
    variable S
    if {[busy] || ![::VMDance::Results::has_data]} return
    if {![llength [::VMDance::Results::selected]]} { status "Select a cluster first (the table or a plot)."; return }
    set S(v3d_overlay) 1
    set S(v3d_mode) top
    draw_changed
}

#---------------------------------------------------------------------------
# Scans, PRIME, similarity, picks in the left panel
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_elbow_info {} {
    variable S
    set e $::VMDance::Results::elbow
    if {![dict size $e]} { set S(eb_info) ""; return }
    set q [dict get $e request]
    set ks [dict get $q ks]
    set at "k = [lindex $ks 0] to [lindex $ks end]"
    if {[::VMDance::Results::by_radius $e]} { set ks [dict get $q radii]; set at "radius [lindex $ks 0] to [lindex $ks end]" }
    set S(eb_info) "Last scan: [::VMDance::Algo::label [dict get $q algorithm]] at $at ([llength $ks] values), in [dict get $e seconds] s."
}

# What a sweep found, for the status line.
proc ::VMDance::GUI::_sweep_words {s} {
    set n [llength [dict get $s records]]
    set bad [llength [lmap r [dict get $s records] {expr {[dict get $r status] eq "ok" ? [continue] : 1}}]]
    set out "Sweep done in [dict get $s seconds] s"
    if {$bad == $n} { return "$out: every configuration failed (hover one in the Sweep plot for why)." }
    if {$bad} { append out "; $bad configuration[expr {$bad == 1 ? "" : "s"}] failed" }
    set bch [::VMDance::sweep_best $s ch]; set bdb [::VMDance::sweep_best $s db]
    if {$bch >= 0 && $bch == $bdb} { return "$out. The best on both scores in teal." }
    set best {}
    if {$bch >= 0} { lappend best "best Calinski–Harabasz green" }
    if {$bdb >= 0} { lappend best "best Davies–Bouldin blue" }
    if {![llength $best]} { return "$out; no configuration has scores." }
    return "$out. [string totitle [join $best {, }] 0 0]."
}
proc ::VMDance::GUI::_sweep_table {} {
    variable swtree
    if {$swtree eq "" || ![winfo exists $swtree]} return
    $swtree delete [$swtree children {}]
    set s $::VMDance::Results::sweep
    if {![dict size $s]} return
    set bch [::VMDance::sweep_best $s ch]
    set bdb [::VMDance::sweep_best $s db]
    set i 0
    foreach r [dict get $s records] {
        set tags {}
        if {[dict get $r status] ne "ok"} {
            lappend tags failed
        } elseif {$i == $bch && $i == $bdb} {
            lappend tags bestboth
        } elseif {$i == $bch} {
            lappend tags bestch
        } elseif {$i == $bdb} {
            lappend tags bestdb
        }
        $swtree insert {} end -id r$i -tags $tags -values [list [::VMDance::Algo::label [dict get $r algorithm]] [dict get $r k] \
            [expr {[dict get $r status] eq "ok" ? [dict get $r nclusters] : "failed"}] [dict get $r metric] [::VMDance::Export::sweep_seeding $r] \
            [expr {[dict get $r ch] eq "" ? "–" : [format %.4g [dict get $r ch]]}] [expr {[dict get $r db] eq "" ? "–" : [format %.3f [dict get $r db]]}]]
        incr i
    }
}
proc ::VMDance::GUI::_sweep_sort {col} {
    variable swtree
    set rows [lmap it [$swtree children {}] {list $it [$swtree set $it $col]}]
    set num [expr {$col in {k kact ch db}}]
    set rows [lmap p $rows {if {$num && ![string is double -strict [lindex $p 1]]} { lset p 1 -1e300 }; set p}]
    set rows [lsort {*}[expr {$num ? "-real" : "-dictionary"}] [expr {$col eq "ch" ? "-decreasing" : "-increasing"}] -index 1 $rows]
    set i 0
    foreach p $rows { $swtree move [lindex $p 0] {} $i; incr i }
}

proc ::VMDance::GUI::_prime_table {} {
    variable prtree; variable S
    if {$prtree eq "" || ![winfo exists $prtree]} return
    $prtree delete [$prtree children {}]
    set p [::VMDance::Results::extra prime]
    if {![dict size $p]} {
        set S(pr_info) [expr {[::VMDance::Results::has_data] ? "Not run on this clustering yet." : ""}]
        return
    }
    set fr [::VMDance::prime_frames]
    foreach {key label kind} $::VMDance::prime_rows {
        set f [dict get $fr $key]
        $prtree insert {} end -id $key -tags $kind -values [list $label [expr {$f < 0 ? "–" : $f}]]
    }
    set q [dict get $p params]
    set S(pr_info) "[dict get $q metric], trim [dict get $q trim-frac], [expr {[dict get $q weighted] ? "weighted by size" : "not weighted"}]."
}
proc ::VMDance::GUI::_prime_goto {} {
    variable prtree
    set it [$prtree selection]
    if {$it eq ""} return
    set f [$prtree set $it frame]
    if {[string is integer -strict $f]} { goto_frame $f }
}

proc ::VMDance::GUI::_similarity_info {} {
    variable S
    set s [::VMDance::Results::extra similarity]
    if {![dict size $s]} {
        set S(si_info) [expr {[::VMDance::Results::has_data] ? "Not computed for this clustering yet." : ""}]
        return
    }
    set S(si_info) [format "All frames: %.4g ([dict get $s params metric]; lower: more similar). Each cluster's: Compactness ▸ Extended similarity." [dict get $s isim]]
}

proc ::VMDance::GUI::_pick_list {} {
    variable picklist; variable S
    if {$picklist eq "" || ![winfo exists $picklist]} return
    $picklist delete 0 end
    set p $::VMDance::Results::picks
    if {![dict size $p]} { set S(pk_info) ""; return }
    foreach f [dict get $p vmdframes] { $picklist insert end "frame $f" }
    set n [llength [dict get $p vmdframes]]
    set S(pk_info) "$n frame[expr {$n == 1 ? "" : "s"}] ([dict get $::VMDance::Algo::pick_names [dict get $p params method]])"
}
# (on the picks' molecule: they need no clustering)
proc ::VMDance::GUI::_pick_goto {} {
    variable picklist
    set i [$picklist curselection]
    if {$i eq ""} return
    set f [lindex [dict get $::VMDance::Results::picks vmdframes] $i]
    if {[catch {::VMDance::Viz::goto_pick $f} err]} { status $err; return }
    status "Frame $f of molecule [dict get $::VMDance::Results::picks input mol]: a picked frame."
}

#---------------------------------------------------------------------------
# Plots
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_current_tab {} {
    variable w
    set cur [$w.pw.right.nb select]
    return [lindex [split $cur .] end]
}

# The plot drawn once the window is idle: the notices of one change (a
# session opened: runs, selection, scans, settings) draw it once.
proc ::VMDance::GUI::redraw_soon {} {
    variable redraw_idle
    if {[info exists redraw_idle]} { after cancel $redraw_idle }
    set redraw_idle [after idle ::VMDance::GUI::redraw]
}
proc ::VMDance::GUI::redraw_later {} {
    variable redraw_after
    after cancel $redraw_after
    set redraw_after [after 60 ::VMDance::GUI::redraw]
}

proc ::VMDance::GUI::redraw {} {
    variable w; variable redraws; variable redraw_idle
    if {![winfo exists $w] || [busy]} return
    # (the draw waiting for idle is this one)
    if {[info exists redraw_idle]} { after cancel $redraw_idle }
    incr redraws
    _colours_check
    set key [_current_tab]
    set c $w.pw.right.nb.$key.c
    if {[catch {::VMDance::Plots::draw $key $c} err]} {
        ::VMDance::Plot::empty $c "Plot error" $err
        puts "VMDance) plot error: $::errorInfo"
    }
}

# With VMD's colours (Plot options ▸ Cluster colours), the table and the
# key made again when VMD's changed since: VMD tells no one of Graphics ▸
# Colors. (The plots read them as they are drawn.)
proc ::VMDance::GUI::_colours_check {} {
    variable S; variable vmd_colours
    if {$S(plot_ccol) ne "vmd"} return
    set now [::VMDance::Plots::vmd_colours]
    if {$now eq $vmd_colours} return
    set vmd_colours $now
    populate_tree
    _colour_key
}
# The window in focus again (back from Graphics ▸ Colors): drawn again when
# VMD's colours changed.
proc ::VMDance::GUI::_focus_in {} {
    variable S; variable vmd_colours
    if {$S(plot_ccol) ne "vmd" || [busy]} return
    if {[::VMDance::Plots::vmd_colours] ne $vmd_colours} { redraw_soon }
}

proc ::VMDance::GUI::_tab_changed {} {
    variable S
    set S(tab) [_current_tab]
    _tab_labels
    _opts_show_tab
    _show_hint $S(tab)
    redraw
}

proc ::VMDance::GUI::_hover {key c x y} {
    variable S
    if {[busy]} return
    if {[catch {::VMDance::Plots::hover_$key $c $x $y} txt]} { set txt "" }
    if {$txt eq ""} { _show_hint $key; return }
    set S(readout) $txt
}
proc ::VMDance::GUI::_leave {key c} {
    $c delete partition
    _show_hint [_current_tab]
}
proc ::VMDance::GUI::_click {key c x y add} {
    if {[busy]} return
    if {[info commands ::VMDance::Plots::click_$key] eq ""} return
    if {[catch {::VMDance::Plots::click_$key $c $x $y $add} err]} { puts "VMDance) click on the $key plot: $err" }
}
proc ::VMDance::GUI::_dclick {key c x y} {
    if {[busy]} return
    if {[info commands ::VMDance::Plots::dclick_$key] eq ""} return
    if {[catch {::VMDance::Plots::dclick_$key $c $x $y} err]} { puts "VMDance) double-click on the $key plot: $err" }
}

#---------------------------------------------------------------------------
# Frame tracking, molecules
#---------------------------------------------------------------------------

proc ::VMDance::GUI::_install_traces {} {
    _remove_traces
    catch {trace remove variable ::vmd_initialize_structure write ::VMDance::GUI::_mol_trace}
    catch {trace remove variable ::vmd_trajectory_read write ::VMDance::GUI::_mol_trace}
    trace add variable ::vmd_frame write ::VMDance::GUI::_frame_trace
    trace add variable ::vmd_initialize_structure write ::VMDance::GUI::_mol_trace
    trace add variable ::vmd_trajectory_read write ::VMDance::GUI::_mol_trace
}
proc ::VMDance::GUI::_remove_traces {} {
    catch {trace remove variable ::vmd_frame write ::VMDance::GUI::_frame_trace}
}

# Frame changes: the plots' current-frame markers are refreshed at most
# every refresh_interval ms (the 3D colouring follows by itself).
proc ::VMDance::GUI::_frame_trace {name1 name2 op} {
    variable refresh_after; variable last_refresh; variable refresh_interval
    if {![::VMDance::Results::has_data]} return
    if {$name2 ne "" && $name2 != [dict get [::VMDance::Results::request] mol]} return
    if {$refresh_after ne ""} return
    set wait [expr {max(0, $last_refresh + $refresh_interval - [clock milliseconds])}]
    set refresh_after [after $wait ::VMDance::GUI::_frame_changed]
}
proc ::VMDance::GUI::_frame_changed {} {
    variable w; variable refresh_after; variable last_refresh
    set refresh_after ""
    set last_refresh [clock milliseconds]
    if {![winfo exists $w] || [busy] || ![::VMDance::Results::has_data]} return
    set key [_current_tab]
    catch {::VMDance::Plots::cursor $key $w.pw.right.nb.$key.c}
}

proc ::VMDance::GUI::_mol_trace {args} {
    after cancel ::VMDance::GUI::_mol_refresh
    after 100 ::VMDance::GUI::_mol_refresh
}
proc ::VMDance::GUI::_mol_refresh {} {
    variable w
    if {![winfo exists $w]} return
    refresh_molecules
    _count_later
    # (a trajectory loaded into a molecule drawn on: drawn again, or withdrawn)
    if {![busy]} { ::VMDance::Viz::check }
}

#---------------------------------------------------------------------------
# 3D
#---------------------------------------------------------------------------

proc ::VMDance::GUI::draw_changed {} {
    variable S; variable viz_seen
    if {[busy]} return
    if {![regexp {^[1-9][0-9]*$} [string trim $S(v3d_top)]] || $S(v3d_top) > 1000} { set S(v3d_top) 10 }
    # (a session's "yes" as Viz takes it: the box ticked, Viz's overlay
    # not read back while unchanged)
    set S(v3d_overlay) [expr {$S(v3d_overlay) ? 1 : 0}]
    set frames ""
    if {$S(v3d_mode) eq "frames"} { set frames [string trim $S(v3d_frames)] }
    # ("frames" chosen with none typed yet draws no overlay, the box left
    # ticked: Viz draws the selected clusters' for no frames)
    set ov [expr {$S(v3d_overlay) && ($S(v3d_mode) ne "frames" || $frames ne "")}]
    set o [list colour $S(v3d_colour) reps $S(v3d_reps) overlay $ov picks $S(v3d_picks) style $S(v3d_style) \
        sel [string trim $S(v3d_sel)] top $S(v3d_top) frames $frames material $S(v3d_material)]
    # (Viz tells the window back as it draws: what it was sent is not read
    # again)
    set viz_seen $o
    set bad [catch {::VMDance::Viz::configure {*}$o} err]
    set viz_seen [::VMDance::Viz::get]
    if {$bad} {
        status "3D: $err"
        return
    }
    _draw_status
}
# What the 3D tab draws, or why not: the clusters', and the picks' (on
# their molecule).
proc ::VMDance::GUI::_draw_status {} {
    variable S
    set parts {}
    if {$S(v3d_colour) || $S(v3d_reps) || $S(v3d_overlay)} {
        set m [::VMDance::Viz::_mol]
        if {![::VMDance::Results::has_data]} {
            lappend parts "nothing to draw yet (no clustering)"
        } elseif {$m < 0} {
            lappend parts [::VMDance::Viz::why]
        } elseif {$S(v3d_overlay) && $S(v3d_mode) eq "frames" && [string trim $S(v3d_frames)] eq ""} {
            lappend parts "type the overlay's frames (0-100,500) and press Return"
        } elseif {$S(v3d_overlay) && $S(v3d_mode) eq "top" && ![llength [::VMDance::Results::selected]]} {
            lappend parts "the overlay shows the selected clusters: select one (the table or a plot)"
        } else {
            lappend parts "drawn in molecule $m's representations of the plugin"
        }
    }
    if {$S(v3d_picks)} {
        set pm [::VMDance::Viz::_picks_mol]
        if {$pm < 0} {
            lappend parts "the picked frames: [::VMDance::Viz::picks_why]"
        } else {
            lappend parts "the picked frames drawn in molecule $pm"
        }
    }
    # (what is drawn otherwise than asked: Viz::_note)
    lappend parts {*}$::VMDance::Viz::notes
    if {[llength $parts]} { status "3D: [join $parts {; }]." }
}
# The 3D tab from the drawing's options (set by the command, a session,
# or the tab itself; or the drawing withdrawn when its frames changed:
# said). The overlay's frames and box are read only when Viz changed them
# since the window sent or read them: its choices that Viz does not hold
# stay (frames typed and not yet sent, at a job's end too; "frames" chosen
# with none typed, drawn as no overlay).
proc ::VMDance::GUI::_draw_options {} {
    variable S; variable viz_seen
    set o [::VMDance::Viz::get]
    if {![busy] && [llength [::VMDance::draw_notes $o]]} { _draw_status }
    set seen $viz_seen
    set viz_seen $o
    foreach {k v} $o {
        if {$k in {frames overlay} && [dict exists $seen $k] && [dict get $seen $k] eq $v} continue
        switch -- $k {
            frames {
                # (the text typed is kept when the overlay is back to the
                # selected clusters')
                if {$v ne ""} {
                    set S(v3d_frames) $v
                    set S(v3d_mode) frames
                } else {
                    set S(v3d_mode) top
                }
            }
            overlay {
                set S(v3d_overlay) $v
                # (the selected clusters' drawn)
                if {$v && [dict get $o frames] eq ""} { set S(v3d_mode) top }
            }
            colour - reps - picks - style - sel - top - material { set S(v3d_$k) $v }
        }
    }
}
proc ::VMDance::GUI::toggle_colour {} { variable S; if {[busy]} return; set S(v3d_colour) [expr {!$S(v3d_colour)}]; draw_changed }
proc ::VMDance::GUI::toggle_reps {} { variable S; if {[busy]} return; set S(v3d_reps) [expr {!$S(v3d_reps)}]; draw_changed }

proc ::VMDance::GUI::userfield {} {
    variable w
    if {[busy] || ![::VMDance::Results::has_data]} return
    if {[tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
            -message "Write every frame's cluster into the user field of molecule [dict get [::VMDance::Results::request] mol]'s atoms?" \
            -detail "This changes the molecule's data (its user field, for every frame): colour a representation by it with Coloring Method: User. Noise and frames that were not clustered get -1."] ne "ok"} return
    if {[catch {::VMDance::_api_userfield} n]} { _error $n; return }
    status "The user field holds the clusters of $n frames."
}

#---------------------------------------------------------------------------
# The backend, Settings, help
#---------------------------------------------------------------------------

# The backend changed (Settings, the command): what the window offers.
proc ::VMDance::GUI::backend_changed {} {
    _availability
}

proc ::VMDance::GUI::settings_dialog {} {
    variable w; variable S; variable E; variable window_names
    set d $w.settings
    if {[winfo exists $d]} { raise $d; return }
    # (the backend in use, whoever chose it)
    set sb [::VMDance::Backend::settings]
    array set E [list font $S(ui_font) win $S(ui_window) theme $S(ui_theme) unlock $S(unlock_metrics) \
        mode [dict get $sb -mode] cli [dict get $sb -cli] lib [dict get $sb -library]]
    toplevel $d
    wm title $d "VMDance settings"
    wm transient $d $w
    set f [ttk::frame $d.f -padding 12]
    pack $f -fill both -expand 1
    set B [_section $f.bk "Backend (CPP-MDANCE)" -padding {8 6}]
    pack ${B}_sec -side top -fill x
    _combo $B.mode ::VMDance::GUI::E(mode) {auto "The program if found, else the library" cli "The program (mdance-cli)" library "The library (in VMD)"} {::VMDance::GUI::_settings_backend}
    _row $B 0 "Use" $B.mode "The program runs in the background and can be cancelled; the library runs inside VMD, which it blocks until it returns, and takes about 180 bytes of its memory a coordinate. Either way the coordinates are written to a file of the plugin's private folder (in TMPDIR)."
    set cf [ttk::frame $B.cf]
    ttk::entry $cf.e -textvariable ::VMDance::GUI::E(cli) -width 34
    ttk::button $cf.b -text "…" -style Toolbutton -takefocus 0 -command {::VMDance::GUI::_settings_browse cli}
    pack $cf.e -side left -fill x -expand 1
    pack $cf.b -side left
    _row $B 1 "Program" $cf "mdance-cli (empty: MDANCE_CLI, the plugin's folder, the PATH, a CPP-MDANCE build beside the plugin)"
    set lf [ttk::frame $B.lf]
    ttk::entry $lf.e -textvariable ::VMDance::GUI::E(lib) -width 34
    ttk::button $lf.b -text "…" -style Toolbutton -takefocus 0 -command {::VMDance::GUI::_settings_browse lib}
    pack $lf.e -side left -fill x -expand 1
    pack $lf.b -side left
    _row $B 2 "Library" $lf "mdance_tcl[info sharedlibextension] (empty: MDANCE_LIB, the plugin's folder, a CPP-MDANCE build beside the plugin)"
    ttk::label $B.st -style Muted.TLabel -wraplength 420 -justify left
    grid $B.st -row 3 -column 0 -columnspan 2 -sticky w -pady {4 0}
    ttk::button $B.det -text "Detect again" -command ::VMDance::GUI::_settings_backend
    grid $B.det -row 4 -column 0 -columnspan 2 -sticky w -pady {4 0}
    grid columnconfigure $B 1 -weight 1
    set C [_section $f.cl "Clustering" -padding {8 6}]
    pack ${C}_sec -side top -fill x -pady {10 0}
    ttk::checkbutton $C.unlock -text "Unlock the metrics (MSD only otherwise)" -variable ::VMDance::GUI::E(unlock)
    grid $C.unlock -row 0 -column 0 -sticky w
    ttk::label $C.n -text "The mean square deviation is the metric of Cartesian coordinates. The other ten indices are binary or extended similarities, for fingerprint-like data." \
        -style Muted.TLabel -wraplength 420 -justify left
    grid $C.n -row 1 -column 0 -sticky w
    set A [_section $f.app "Appearance" -padding {8 6}]
    pack ${A}_sec -side top -fill x -pady {10 0}
    ttk::spinbox $A.font -from 8 -to 24 -increment 1 -width 4 -textvariable ::VMDance::GUI::E(font)
    _row $A 0 "Text size (pt)" $A.font
    grid configure $A.font -sticky w
    set wn {}
    foreach {k v} $window_names { lappend wn $k $v }
    _combo $A.win ::VMDance::GUI::E(win) $wn {#}
    _row $A 1 "Window" $A.win
    set tn {}
    foreach k [::VMDance::Theme::available] { lappend tn $k [::VMDance::Theme::label $k] }
    _combo $A.th ::VMDance::GUI::E(theme) $tn {#}
    _row $A 2 "Theme" $A.th
    grid columnconfigure $A 1 -weight 1
    set X [_section $f.prog "Programs" -padding {8 6}]
    pack ${X}_sec -side top -fill x -pady {10 0}
    set gs [::VMDance::Figures::ghostscript]
    ttk::label $X.gs -text [expr {$gs eq "" ? "Ghostscript: not found (figures: EPS only)" : "Ghostscript: $gs (figures in PDF and PNG)"}] -style Muted.TLabel
    grid $X.gs -row 0 -column 0 -sticky w
    set b [ttk::frame $f.b]
    pack $b -side top -fill x -pady {12 0}
    ttk::button $b.ok -text "OK" -command ::VMDance::GUI::_settings_apply
    ttk::button $b.cancel -text "Cancel" -command ::VMDance::GUI::_settings_cancel
    pack $b.cancel $b.ok -side right -padx {6 0}
    ::VMDance::Theme::style_tree $d
    bind $d <Escape> ::VMDance::GUI::_settings_cancel
    wm protocol $d WM_DELETE_WINDOW ::VMDance::GUI::_settings_cancel
    _settings_status
}
# (a backend tried in the dialog was never applied: Cancel has nothing to
# put back, even while a job runs)
proc ::VMDance::GUI::_settings_cancel {} {
    variable w
    destroy $w.settings
}
proc ::VMDance::GUI::_settings_browse {what} {
    variable E; variable w
    set f [tk_getOpenFile -parent $w.settings -title [expr {$what eq "cli" ? "The mdance-cli program" : "The MDANCE library (mdance_tcl)"}]]
    if {$f eq ""} return
    set E($what) $f
    _settings_backend
}
# The backend of the dialog's fields, tried: what it gives, applied only
# by OK (a job started meanwhile runs on the backend in use).
proc ::VMDance::GUI::_settings_backend {} {
    variable E
    if {[catch {::VMDance::Backend::probe -mode $E(mode) -cli $E(cli) -library $E(lib)} s]} { _settings_status $s; return }
    _settings_status "" $s
}
# What the dialog says of the backend in use, or of the one tried (s: its
# status).
proc ::VMDance::GUI::_settings_status {{err ""} {s ""}} {
    variable w
    set l $w.settings.f.bk.st
    if {![winfo exists $l]} return
    if {$err ne ""} { $l configure -text "Not usable: $err"; return }
    set now [::VMDance::Backend::status]
    if {$s eq ""} { set s $now }
    if {[dict get $s error] ne ""} {
        $l configure -text "No backend: [dict get $s error]"
        return
    }
    lassign [dict get $s using] kind path
    set t "[expr {[dict get $s using] eq [dict get $now using] ? "In use" : "On OK"}]: the [expr {$kind eq "cli" ? "program" : "library"}] $path\nAlgorithms: [join [lmap a [dict get $s algorithms] {::VMDance::Algo::label $a}] {, }]"
    # (a program slow to start: its algorithms are not known)
    if {[dict get $s note] ne ""} { append t "\n[dict get $s note]." }
    $l configure -text $t
}
# OK: everything is checked before anything is kept, so that a mistake
# leaves the settings as they were (a job running refuses the backend's
# change: the dialog stays open).
proc ::VMDance::GUI::_settings_apply {} {
    variable E; variable S; variable w
    set d $w.settings
    set E(font) [string trim $E(font)]
    if {[catch {_check_appearance $E(font) $E(win) $E(theme)} err]} { _error "Not applied: $err." $d; return }
    if {[catch {::VMDance::Backend::configure -mode $E(mode) -cli $E(cli) -library $E(lib)} err]} { _error "Not applied: $err." $d; return }
    foreach {k e} {backend_mode mode backend_cli cli backend_lib lib} { set S($k) $E($e) }
    set S(unlock_metrics) $E(unlock)
    _metric_lock
    backend_changed
    if {[catch {set_appearance $E(font) $E(win) $E(theme)} err]} { _error $err $d; return }
    destroy $d
}

proc ::VMDance::GUI::help {} {
    variable w
    set d $w.help
    if {[winfo exists $d]} { raise $d; return }
    toplevel $d
    wm title $d "VMDance — quick guide"
    text $d.t -wrap word -width 76 -height 32 -padx 12 -pady 10 -relief flat -font MdvUI
    ttk::scrollbar $d.s -command [list $d.t yview]
    $d.t configure -yscrollcommand [list $d.s set]
    pack $d.s -side right -fill y
    pack $d.t -side left -fill both -expand 1
    $d.t tag configure h -font MdvUIHead -spacing1 8 -spacing3 3
    $d.t tag configure code -font {Courier 11}
    foreach {tag txt} {
        h "What it does\n"
        {} "VMDance clusters the frames of a trajectory with MDANCE's algorithms (KMeans NANI, DIVINE, HELM, eQUAL, run by CPP-MDANCE), and shows the clusters: how many frames each holds, when the trajectory visits it, how it moves between them, how tight and how far apart they are, their representative structures. PRIME predicts the native-like frame; the extended similarity (iSIM) measures each cluster; frames can be picked without clustering.\n"
        h "Cluster\n"
        {} "Setup: the molecule, the atoms (the same in every frame; Cα atoms by default), the frames and every n-th; optionally a fit to the first frame. Choose the algorithm and its parameters, and press Cluster. The clustering runs in the background; Cancel stops it and keeps what was there (with the library, VMD waits until each clustering ends, and Cancel acts then). Every clustering is kept as a run (Results ▸ Run).\n"
        h "Explore\n"
        {} "Results: the table of clusters (frames, share, the mean square deviation within, from the representative, the representative's frame); click a heading to sort. Selecting clusters there or in a plot shows them on top everywhere, and the 3D tab can overlay their frames. Double-click a cluster to go to its representative.\n"
        h "Plots\n"
        {} "Populations: frames per cluster. Timeline: the cluster of every frame. Transitions: from one cluster to the next. Residence: how long the trajectory stays. Compactness: how tight each cluster is. Distances: between the clusters. Tree: how they join (HELM's merges, or average linkage). Silhouette: how well each frame sits in its cluster. Elbow and Sweep: the scans' scores. The Plot options panel (toolbar, right) holds every setting of a plot.\n"
        h "Scans and tools\n"
        {} "Scans ▸ Elbow clusters at every k of a range with the Setup's algorithm; Scans ▸ Sweep runs every combination of algorithms, k, metrics and seedings; double-click one to make it the clustering. Tools ▸ PRIME, Similarity, Pick frames.\n"
        h "3D\n"
        {} "The 3D tab colours the structure by the cluster of VMD's current frame (it follows the trajectory), draws every representative, or overlays the selected clusters' frames nearest their representative, in the clusters' colours — representations of the plugin's own.\n"
        h "Files\n"
        {} "File ▸ Save session keeps every run, the scans and the selection; File ▸ Export results writes the tables (CSV), the representatives' structures and each cluster's trajectory (PDB or DCD); File ▸ Create figures writes the plots as PDF, PNG or EPS.\n"
        h "Scripting\n"
    } {
        $d.t insert end $txt $tag
    }
    $d.t insert end "vmdance -sel \"name CA\" -algorithm kmeans -k 6\nvmdance clusters\nvmdance get 0\nvmdance elbow -from 2 -to 12\nvmdance elbow load 5\nvmdance prime\nvmdance draw -colour 1\nvmdance export results_dir\nvmdance session save my.vmdance\n" code
    $d.t configure -state disabled
    ::VMDance::Theme::style_tree $d
}

proc ::VMDance::GUI::references {} {
    variable w
    set d $w.refs
    if {[winfo exists $d]} { raise $d; return }
    toplevel $d
    wm title $d "VMDance — references"
    text $d.t -wrap word -width 76 -height 22 -padx 12 -pady 10 -relief flat -font MdvUI
    pack $d.t -fill both -expand 1
    $d.t tag configure h -font MdvUIHead -spacing1 8 -spacing3 3
    foreach {tag txt} {
        h "MDANCE\n"
        {} "The algorithms are MDANCE's (the Miranda-Quintana group, https://github.com/mqcomplab/MDANCE), run by its C++ port CPP-MDANCE (https://github.com/mqcomplab/CPP-MDANCE). Please cite the methods you use.\n"
        h "KMeans NANI\n"
        {} "k-means NANI: J. Chem. Theory Comput. (2024), doi:10.1021/acs.jctc.4c00308.\nStratified NANI: J. Chem. Inf. Model. (2025), doi:10.1021/acs.jcim.5c02741.\n"
        h "HELM\n"
        {} "J. Chem. Inf. Model. (2025), doi:10.1021/acs.jcim.5c00539.\n"
        h "DIVINE, eQUAL, PRIME, iSIM\n"
        {} "See MDANCE's documentation (https://mdance.readthedocs.io) for the references of these methods.\n"
        h "VMD\n"
        {} "Humphrey W, Dalke A, Schulten K. VMD: visual molecular dynamics. J. Mol. Graph. 14:33–38 (1996).\n"
    } {
        $d.t insert end $txt $tag
    }
    $d.t configure -state disabled
    ::VMDance::Theme::style_tree $d
}

proc ::VMDance::GUI::about {} {
    variable w
    set b [::VMDance::Backend::status]
    set bk [expr {[dict get $b error] eq "" ? "[lindex [dict get $b using] 0] [lindex [dict get $b using] 1]" : "none found"}]
    tk_messageBox -parent $w -title "About VMDance" -icon info -message "VMDance $::VMDance::version" \
        -detail "MDANCE clustering of a trajectory, in VMD: KMeans NANI, DIVINE, HELM and eQUAL; PRIME, extended similarity, frame picks; scans of k and parameters.\n\nThe algorithms are MDANCE's, run by CPP-MDANCE (backend: $bk).\n\nTcl [info patchlevel], VMD [vmdinfo version]."
}

#---------------------------------------------------------------------------
# Session state of the window
#---------------------------------------------------------------------------

proc ::VMDance::GUI::session_state {} {
    variable S
    set out [dict create]
    foreach k [array names S] {
        if {[regexp {^(po|mu|tl|tn|rs|cp|ds|td|sl|mp|pf|eb|sw|mx|plot|v3d)_} $k] || $k eq "tab"} { dict set out $k $S($k) }
    }
    return $out
}
# Whether a value of the window's state is one it can take (sessions are
# data: a value that is not is left out).
proc ::VMDance::GUI::_state_ok {k v} {
    variable optspec; variable optall; variable tabs; variable styles
    switch -- $k {
        tab { return [dict exists $tabs $v] }
        v3d_colour - v3d_reps - v3d_overlay - v3d_picks { return [string is boolean -strict $v] }
        v3d_style { return [expr {$v in $styles}] }
        v3d_mode { return [expr {$v in {top frames}}] }
        v3d_top { return [expr {[regexp {^[1-9][0-9]{0,3}$} $v] && $v <= 1000}] }
        v3d_sel - v3d_frames { return [expr {[string length $v] < 1000 && [string first \n $v] < 0}] }
        v3d_material { return [expr {$v in [material list]}] }
        eb_from - eb_to - eb_by { return [regexp {^[1-9][0-9]{0,3}$} $v] }
        eb_rfrom - eb_rto - eb_rby { return [expr {[string is double -strict $v] && ![regexp -nocase {nan|inf} $v] && $v > 0 && $v < 1e6}] }
        eb_info { return 0 }
    }
    foreach spec [concat {*}[dict values $optspec] $optall] {
        lassign $spec kind key label a b
        if {$key ne $k} continue
        switch -- $kind {
            combo { return [dict exists $a $v] }
            check { return [string is boolean -strict $v] }
            spin { return [expr {[::VMDance::whole $v] && $v >= $a && $v <= $b}] }
            entry { return [expr {[string is double -strict $v] && ![regexp -nocase {nan|inf} $v] && $v > 0 && $v <= 1}] }
            palette { return [::VMDance::Cmap::valid $v] }
        }
    }
    return 0
}
proc ::VMDance::GUI::apply_session_state {g} {
    variable S
    if {[catch {dict size $g}]} return
    set d {}
    dict for {k v} $g {
        if {![info exists S($k)] || !([regexp {^(po|mu|tl|tn|rs|cp|ds|td|sl|mp|pf|eb|sw|mx|plot|v3d)_} $k] || $k eq "tab")} continue
        # (the lag box kept " 5" as typed until it kept it as checked: a
        # session saved then has it so)
        if {![_state_ok $k $v] && ![_state_ok $k [set v [string trim $v]]]} continue
        if {[string match v3d_* $k]} { dict set d $k $v; continue }
        set S($k) $v
    }
    if {![dict exists $::VMDance::GUI::tabs $S(tab)]} { set S(tab) populations }
    show_tab $S(tab)
    # (the 3D drawing as without the window: a -sel or -frames refused is
    # left out alone, said, not the whole drawing; the tab shows what is
    # drawn)
    if {[dict size $d]} {
        if {[catch {::VMDance::_draw_state $d} left]} { set left [list $left] }
        if {[llength $left]} { status "3D: the session's drawing: [join $left {; }]." }
    }
    _draw_options
    # (the plot options' rows follow the settings, as when they are set in
    # the window: showing the tab shown already does not redo them)
    _rows_changed
}
