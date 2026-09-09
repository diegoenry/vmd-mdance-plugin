# mdance_gui.tcl - MDANCE VMD Plugin GUI
#
# Tabbed Tk interface for configuring and running MDANCE clustering
# algorithms on molecular dynamics trajectories loaded in VMD.

namespace eval ::mdance::gui {
    # Algorithm parameters (linked to GUI widgets via -textvariable)
    variable mol_selection "top"
    variable atom_selection "protein and name CA"

    # Frame range / stride for clustering input (last < 0 means "to end")
    variable frame_first 0
    variable frame_last -1
    variable frame_stride 1

    # KMeans (NANI)
    variable km_nclusters 10
    variable km_metric "MSD"
    # StratAll is the default initialization on the MDANCE authors' advice: on
    # the reviewer's own benchmark runs it is 9-12x faster than CompSim
    # (0.11 s vs 1.27 s on a 6001-frame trajectory) at comparable cluster
    # quality, and it is the initialization the Stratified-NANI paper describes.
    variable km_kinit "StratAll"
    variable km_percentage 10

    # Metric selection is LOCKED to MSD for MD data. MSD is the only metric with
    # a physical meaning for Cartesian frames; the other ten are extended-
    # similarity indices meant for binary/fingerprint data (the Sweep tab has
    # always carried a note saying so). Nothing is removed -- every *_metric
    # variable and every backend call site is untouched -- so unlocking is a
    # pure GUI switch. PRIME is deliberately NOT included: its metric is an
    # n-ary similarity index rather than a distance, so MSD is not the same
    # axis and forcing it there would change documented PRIME behaviour.
    variable metric_unlocked 0
    variable metric_all {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
    variable metric_slots      ;# array: combobox path -> its saved `grid info`
    array set metric_slots {}

    # DIVINE
    variable div_nclusters 3
    variable div_metric "MSD"
    variable div_split "WeightedMSD"
    variable div_anchors "NANI"
    variable div_kinit "StratAll"
    variable div_refine 1
    variable div_threshold 0.0
    variable div_end_mode "k"
    variable div_percentage 10

    # eQUAL
    variable eq_metric "MSD"
    variable eq_threshold ""
    variable eq_seed "medoid"
    variable eq_nseeds 1
    variable eq_percentage 10
    variable eq_minsamples 10
    variable eq_simthreshold 0
    variable eq_align "none"
    variable eq_reject_lowd 0
    variable eq_check_sim 0

    # PRIME
    variable prime_metric "RR"
    variable prime_trim 0.1
    variable prime_weighted 1
    variable prime_results ""
    variable prime_molid ""   ;# molecule prime_results were computed against

    # Frame Tools (diversity / outlier / representative selection)
    variable ft_method "diversity"
    variable ft_metric "MSD"
    variable ft_param 10
    variable ft_nbins 10
    variable ft_frames ""
    variable ft_molid ""      ;# molecule ft_frames were computed against

    # HELM
    variable helm_nclusters 10
    variable helm_metric "MSD"
    variable helm_merge "Inter"
    variable helm_eps -1
    variable helm_stop_mode "nclusters"
    variable helm_trim_start 0
    variable helm_min_samples 0.01
    variable helm_trim_val 0
    variable helm_trim_k 0
    # Which trim criterion is active. The backend rejects trim-val and trim-k
    # given TOGETHER (whether or not trimming is on), so they cannot be two
    # independent entry fields -- they are one choice.
    variable helm_trim_mode "k"
    variable helm_labels_source "auto"
    variable helm_pre_k 50
    # Pre-cluster KMeans settings, defaulted to the KMeans tab's own defaults so
    # the hidden first stage of a HELM run matches a single KMeans run.
    variable helm_pre_kinit "StratAll"
    variable helm_pre_percentage 10
    variable helm_labels_file ""

    # Backend combinations that CRASH rather than fail, and so must never be
    # launched. CPP-MDANCE src/cluster/divine.cpp indexes its LOCAL subdata
    # matrix with GLOBAL frame indices inside the refine block, so with
    # anchor = OutlierPair or SplinterPair AND refine on it reads out of bounds
    # and takes VMD down with it (see notes/mdance-divine-refine-bug.md; the
    # NANI anchor uses the correct pattern and is unaffected).
    #
    # This table is the whole guard: delete an entry when the backend is fixed,
    # and the guard for it disappears. The Sweep tab and the elbow scan cannot
    # reach the combination -- run_one_config passes neither --anchors nor
    # --refine, so the backend's own safe defaults apply -- so only the DIVINE
    # tab needs checking.
    variable divine_crash_anchors {OutlierPair SplinterPair}

    # Multi-frame overlay. overlay_rep holds the dedicated representation's
    # REPNAME, not its index.
    #
    # VMD renumbers representations when one is deleted, so a remembered index
    # goes stale silently. Proven: with the overlay at index 2 and a user
    # representation at 3, deleting the user's rep 0 shifts the overlay to 1 and
    # the user's to 2 -- so "Clear Overlay" deleted the USER's representation and
    # left the overlay stranded on screen with no way to remove it. A repname is
    # stable, and mol repindex resolves it to the current index on demand.
    variable overlay_m 10
    variable overlay_rep ""
    variable overlay_molid ""
    variable overlay_ranges ""

    # Results-table sort state (column, and whether the next click reverses)
    variable cluster_sort_col ""
    variable cluster_sort_desc 0

    # CLI binary display
    variable cli_display_path ""

    # Display settings
    variable app_font_size 10

    # Which algorithm's parameter panel the input column is showing, the panels
    # themselves (built once, so switching preserves what has been typed into
    # each), and the column they are packed into.
    variable algo_current "kmeans"
    variable algo_panels
    array set algo_panels {}
    variable algo_host ""
}

# create_window - the plugin shell: setup and algorithm parameters down the
# left, result views on the right, one status band across the bottom.
#
# The eight sibling tabs this replaces put input (Setup), five mutually
# exclusive algorithms, a batch sweep and the output surface at the same level,
# so configuring a run meant leaving the tab that held the molecule and the
# frame range, and reading the result meant leaving the parameters that produced
# it. Now the left column is the whole input side -- molecule, frame range,
# backend, and the parameters of the one algorithm you have selected -- and it
# stays put while you move between result views.
#
# Widget paths are deliberately unchanged. $w.nb is no longer a notebook, but it
# is still the parent of .setup, .kmeans, .divine, .helm, .equal, .sweep,
# .results and .prime, so every absolute path in this plugin and the eighteen
# the test suite pins keep resolving. The panels are placed with `pack -in`,
# which is legal because each host is a descendant of the panel's parent.
# init_styles - the plugin's own ttk styles.
#
# Namespaced on purpose. VMD's ttk theme paints Treeview headings a saturated
# green, which makes the loudest thing in the window the header of a table that
# is usually empty; the slate below is the interactions plugin's headerBg. Bare
# style names would restyle every other VMD plugin's tables in the same process,
# so everything here is prefixed and applied per widget.
proc ::mdance::gui::init_styles {} {
    catch {
        ttk::style configure Mdance.Treeview.Heading \
            -background "#37474f" -foreground "#ffffff" -relief flat -padding {6 5}
        ttk::style map Mdance.Treeview.Heading \
            -background [list active "#455a64" pressed "#263238"] \
            -foreground [list active "#ffffff" pressed "#ffffff"]
        ttk::style configure Mdance.Treeview -rowheight 22
    }
}

proc ::mdance::gui::create_window {} {
    variable algo_current
    variable algo_panels
    variable algo_host
    array unset algo_panels

    init_styles

    set w .mdance
    catch {destroy $w}
    toplevel $w
    wm title $w "MDANCE Clustering"
    wm geometry $w 1180x780
    wm minsize $w 900 560
    wm resizable $w 1 1
    # Closing the window mid-run would take the Cancel button with it, leaving a
    # backend child running with nothing able to stop it.
    wm protocol $w WM_DELETE_WINDOW ::mdance::gui::on_close

    # The status band is packed FIRST, from the bottom. Packed last -- as it was
    # -- it is the slave pack drops when the content asks for more height than
    # the window has, which at the old hard-coded 560x720 meant the only
    # progress bar and the only Cancel button in the plugin were allocated 1 px
    # and never appeared on any tab.
    ttk::frame $w.status
    pack $w.status -side bottom -fill x -padx 5 -pady {0 5}
    ttk::button $w.status.cancel -text "Cancel" -command ::mdance::request_cancel -state disabled
    ttk::progressbar $w.status.pb -mode indeterminate -length 120
    ttk::label $w.status.label -textvariable ::mdance::status -anchor w
    pack $w.status.label -side left -fill x -expand 1

    # A slim toolbar, the one piece of the interactions shell that transfers
    # cleanly: a fixed home for window-level actions that belong to no tab.
    ttk::frame $w.tools
    pack $w.tools -side top -fill x -padx 5 -pady {5 0}
    ttk::button $w.tools.settings -text "Settings..." \
        -command ::mdance::gui::settings_dialog
    ttk::label $w.tools.title -text "MDANCE Clustering" -anchor w
    pack $w.tools.title -side left
    pack $w.tools.settings -side right
    ttk::separator $w.toolsep -orient horizontal
    pack $w.toolsep -side top -fill x -padx 5 -pady {6 0}

    ttk::frame $w.nb
    pack $w.nb -fill both -expand 1 -padx 5 -pady 5

    ttk::panedwindow $w.nb.pane -orient horizontal
    pack $w.nb.pane -fill both -expand 1
    ttk::frame $w.nb.pane.input
    ttk::frame $w.nb.pane.views
    $w.nb.pane add $w.nb.pane.input -weight 0
    $w.nb.pane add $w.nb.pane.views -weight 1

    # ---- left: setup, then the selected algorithm's parameters -------------
    # 500 px: the widest panel is HELM, which requests 484 with its trim grid.
    set col [_scrollcol $w.nb.pane.input 500]

    set setup_tab [ttk::frame $w.nb.setup]
    build_setup_tab $setup_tab
    pack $setup_tab -in $col -fill both -expand 1

    # The algorithm chooser and the panel it drives sit together, directly under
    # the molecule and frame range they consume. They are children of $w.nb, but
    # $w.nb.setup is a descendant of $w.nb, so `pack -in` may host them there.
    set algo_host $setup_tab

    ttk::labelframe $setup_tab.algo -text "Algorithm" -padding {10 6}
    foreach {key label} {kmeans "KMeans NANI" divine "DIVINE" helm "HELM" equal "eQUAL"} {
        ttk::radiobutton $setup_tab.algo.$key -text $label \
            -variable ::mdance::gui::algo_current -value $key \
            -command [list ::mdance::gui::select_algorithm $key]
        pack $setup_tab.algo.$key -anchor w -pady 1
    }

    # Reassert the column order: what you set first at the top, the algorithm and
    # its parameters in the middle, and the things touched once a session at the
    # bottom. build_setup_tab packs in its own historical order, which put the
    # backend path and the Quick Start text above the algorithm.
    foreach f {mol range preview cli} { catch {pack forget $setup_tab.$f} }
    pack $setup_tab.mol     -fill x -padx 10 -pady {10 0}
    pack $setup_tab.range   -fill x -padx 10 -pady {10 0}
    pack $setup_tab.preview -fill x -padx 10
    pack $setup_tab.algo    -fill x -padx 10 -pady {6 0}
    # (the algorithm panel is packed after .algo by select_algorithm)
    pack $setup_tab.cli     -fill x -padx 10 -pady {10 10}

    set algo_panels(kmeans) [ttk::frame $w.nb.kmeans]
    set algo_panels(divine) [ttk::frame $w.nb.divine]
    set algo_panels(helm)   [ttk::frame $w.nb.helm]
    set algo_panels(equal)  [ttk::frame $w.nb.equal]
    build_kmeans_tab $algo_panels(kmeans)
    build_divine_tab $algo_panels(divine)
    build_helm_tab   $algo_panels(helm)
    build_equal_tab  $algo_panels(equal)

    set algo_current "kmeans"
    select_algorithm kmeans

    # Every explanatory note in the plugin carries a hard -wraplength sized for
    # the old full-window tab (460, 450, 430...). In a 390 px column those run
    # off the edge mid-word, so bring any that overflow down to the column.
    _fit_wraplengths $setup_tab 430

    # ---- right: the result views ------------------------------------------
    ttk::notebook $w.nb.pane.views.nb
    pack $w.nb.pane.views.nb -fill both -expand 1
    foreach {key label} {results "Results" figures "Figures" sweep "Sweep" prime "PRIME" help "Help"} {
        set page [ttk::frame $w.nb.pane.views.nb.$key]
        $w.nb.pane.views.nb add $page -text $label
        set body($key) [ttk::frame $w.nb.$key]
        pack $body($key) -in $page -fill both -expand 1
    }
    # Results keeps the summary, the cluster table and the actions; the plot
    # launcher goes to Figures. They are built together because the buttons are
    # enabled and disabled from the same result.
    build_results_tab $body(results) $body(figures)
    build_sweep_tab   $body(sweep)
    build_prime_tab   $body(prime)
    build_help_tab    $body(help)

    # Hide the metric selectors (locked to MSD) now that every panel is gridded.
    register_metric_combos $w

    return $w
}

# select_algorithm - show one algorithm's parameter panel in the input column
# and hide the rest. The panels are built once, so switching keeps whatever the
# user has already typed into each.
proc ::mdance::gui::select_algorithm {name} {
    variable algo_panels
    variable algo_host
    variable algo_current
    if {![info exists algo_panels($name)]} return
    foreach key [array names algo_panels] {
        catch {pack forget $algo_panels($key)}
    }
    set algo_current $name
    pack $algo_panels($name) -in $algo_host -after $algo_host.algo \
        -fill x -padx 10 -pady {2 0}
    _fit_wraplengths $algo_panels($name) 430
}

# _fit_wraplengths - clamp any -wraplength wider than the column it now lives
# in. The values in this plugin (460, 450, 430, 480...) were sized for a
# full-window tab; nothing re-wraps on its own, so a note wider than its
# container runs off the edge mid-word instead of flowing.
proc ::mdance::gui::_fit_wraplengths {root width} {
    foreach c [winfo children $root] {
        if {![catch {$c cget -wraplength} wl] && $wl ne "" && $wl > $width} {
            catch {$c configure -wraplength $width}
        }
        _fit_wraplengths $c $width
    }
}

# show_view - raise one of the right-hand result views by name (results, sweep,
# prime). The three callers that used to say `.mdance.nb select .mdance.nb.results`
# go through here, so the view container is named in one place instead of three.
# Silent when the window is gone: a CLI run sits in a live event loop, so the
# user can close the plugin while it is still going.
proc ::mdance::gui::show_view {name} {
    set nb .mdance.nb.pane.views.nb
    if {![winfo exists $nb]} return
    catch {$nb select $nb.$name}
}

# _scrollcol - a vertically scrolling column. The input side stacks the molecule,
# the frame range, the backend, an algorithm's parameters and the display
# settings, which is more than fits on a laptop; without this the surplus is not
# clipped but unmapped, with nothing to drag toward.
proc ::mdance::gui::_scrollcol {parent width} {
    canvas $parent.c -highlightthickness 0 -borderwidth 0 -width $width
    ttk::scrollbar $parent.sb -orient vertical -command [list $parent.c yview]
    $parent.c configure -yscrollcommand [list $parent.sb set]
    pack $parent.sb -side right -fill y
    pack $parent.c -side left -fill both -expand 1
    ttk::frame $parent.c.inner
    set id [$parent.c create window 0 0 -anchor nw -window $parent.c.inner]
    bind $parent.c.inner <Configure> [list ::mdance::gui::_scrollcol_fit $parent]
    bind $parent.c <Configure> [list ::mdance::gui::_scrollcol_width $parent $id %w]
    foreach ev {<MouseWheel> <Button-4> <Button-5>} {
        bind $parent.c $ev [list ::mdance::gui::_scrollcol_wheel $parent %D %b]
    }
    return $parent.c.inner
}
proc ::mdance::gui::_scrollcol_fit {parent} {
    catch {$parent.c configure -scrollregion [$parent.c bbox all]}
}
proc ::mdance::gui::_scrollcol_width {parent id width} {
    catch {$parent.c itemconfigure $id -width $width}
    _scrollcol_fit $parent
}
proc ::mdance::gui::_scrollcol_wheel {parent delta button} {
    # X11 delivers wheel as Button-4/5 with no %D; Windows/macOS use %D.
    if {$button eq "4"} { set n -2 } elseif {$button eq "5"} { set n 2 } \
        elseif {$delta ne "" && $delta ne "??"} { set n [expr {$delta > 0 ? -2 : 2}] } else { return }
    catch {$parent.c yview scroll $n units}
}

# busy_start / busy_stop - show/hide the status-bar progress bar and Cancel
# button around a long-running operation. cancellable=0 disables Cancel (e.g.
# in-process library-mode runs, which cannot be interrupted).
proc ::mdance::gui::busy_start {msg cancellable} {
    set ::mdance::status $msg
    set s .mdance.status
    if {![winfo exists $s.pb]} return
    pack $s.pb -side right -padx {4 0}
    # Start from the animated form explicitly: a determinate bar left behind by
    # a previous extraction would ignore `start` and sit frozen at 100%.
    catch {$s.pb configure -mode indeterminate -value 0}
    catch {$s.pb start 12}
    if {$cancellable} {
        pack $s.cancel -side right -padx {4 0}
        $s.cancel configure -state normal
    }
    update idletasks
}

proc ::mdance::gui::busy_stop {} {
    set s .mdance.status
    if {![winfo exists $s.pb]} return
    catch {$s.pb stop}
    # Return the bar to its indeterminate default so the next operation that
    # expects the animated form gets it (see busy_start).
    catch {$s.pb configure -mode indeterminate -value 0}
    catch {pack forget $s.pb}
    catch {$s.cancel configure -state disabled}
    catch {pack forget $s.cancel}
}

# progress_frac - Drive the status-bar bar as a DETERMINATE indicator, frac in
# 0.0..1.0. Used by the extraction loops, which know their total frame count and
# so can show real progress rather than the "something is happening" animation.
#
# Deliberately best-effort and total: progress reporting must never be able to
# break a run. `winfo` does not exist at all under the unit-test stubs (no Tk),
# and the plugin window can legitimately be absent (headless runtime scenarios,
# or a window the user closed mid-run), so every step is guarded.
proc ::mdance::gui::progress_frac {frac} {
    catch {
        set s .mdance.status
        if {[winfo exists $s.pb]} {
            if {[$s.pb cget -mode] ne "determinate"} {
                $s.pb stop
                $s.pb configure -mode determinate -maximum 100
            }
            $s.pb configure -value [expr {$frac * 100.0}]
        }
    }
}

# on_close - Window-manager close handler. A CLI run parks in a live event loop,
# so the window can be closed while one is still going; the run itself survives
# (its results still land in ::mdance::results), but the user would have no way
# to cancel it. Offer to cancel, and never destroy silently mid-run.
proc ::mdance::gui::on_close {} {
    variable sweep_running
    variable sweep_cancel
    if {$::mdance::running || $sweep_running} {
        set ans [tk_messageBox -icon question -type okcancel -title "MDANCE" \
            -message "A run is still in progress.\n\nClose the window and cancel it?"]
        if {$ans ne "ok"} return
        set sweep_cancel 1
        catch {::mdance::request_cancel}
    }
    destroy .mdance
}

# run_guarded - shared entry for single clustering runs: prevents concurrent
# runs, shows progress/cancel, runs, and refreshes the Results tab.
proc ::mdance::gui::run_guarded {algorithm params} {
    variable sweep_running
    if {$::mdance::running || $sweep_running} {
        tk_messageBox -icon info -title "MDANCE" \
            -message [expr {$sweep_running ? "A parameter sweep is in progress." \
                                           : "A clustering run is already in progress."}]
        return
    }
    set cancellable [expr {!$::mdance::use_library}]
    if {$cancellable} {
        busy_start "Running $algorithm..." 1
    } else {
        busy_start "Running $algorithm (library mode -- not cancellable)..." 0
    }
    set rc [catch {::mdance::run_clustering $algorithm $params} err]
    busy_stop
    if {$rc} {
        if {$err eq "Clustering cancelled."} {
            set ::mdance::status "Cancelled."
        } else {
            tk_messageBox -icon error -title "MDANCE Error" -message $err
        }
        return
    }
    # In CLI mode the run sits in a live event loop, so the user can close the
    # plugin window while it is still going. The results are safely stored in
    # ::mdance::results either way; there is just no longer a tab to show them in.
    ::mdance::gui::show_view results
    if {[catch {update_results_tab} e]} {
        tk_messageBox -icon error -title "MDANCE Error" -message "Could not display results: $e"
    }
}

# _confirm_overwrite - Ask before clobbering files the user never chose.
# tk_getSaveFile already confirms the path the user picked, but the plugin also
# writes DERIVED files next to it (a DCD's companion .pdb topology, the
# per-cluster set), and those were overwritten with no warning at all.
proc ::mdance::gui::_confirm_overwrite {paths what} {
    set existing {}
    foreach p $paths {
        if {[file exists $p]} { lappend existing [file tail $p] }
    }
    if {[llength $existing] == 0} { return 1 }
    if {[llength $existing] > 6} {
        set shown "[join [lrange $existing 0 5] {, }], and [expr {[llength $existing] - 6}] more"
    } else {
        set shown [join $existing ", "]
    }
    set ans [tk_messageBox -icon warning -type okcancel -title "MDANCE" \
        -message "$what will overwrite existing file(s):\n\n$shown\n\nContinue?"]
    return [expr {$ans eq "ok"}]
}

# _busy_guard - reject a secondary backend operation (PRIME / Similarity / Frame
# Tools / Export) while a clustering run is in flight. In CLI mode the run parks
# in a live event loop (vwait), so these buttons would otherwise fire mid-run and
# read/clobber the shared ::mdance::results / ::mdance::status. Returns 1 if free.
proc ::mdance::gui::_busy_guard {} {
    variable sweep_running
    if {$::mdance::running || $sweep_running} {
        tk_messageBox -icon info -title "MDANCE" \
            -message [expr {$sweep_running ? "A parameter sweep is in progress. Please wait for it to finish." \
                                           : "A clustering run is in progress. Please wait for it to finish."}]
        return 0
    }
    return 1
}

# _find_metric_combos - Every combobox bound to a *_metric variable under $root.
# Discovering them by their -textvariable rather than by hardcoded widget paths
# keeps the lock working when a tab's rows are reordered, and picks up the Frame
# Tools dialog when that toplevel is created. prime_metric is excluded on
# purpose (see the metric_unlocked comment).
proc ::mdance::gui::_find_metric_combos {root} {
    set found {}
    if {![winfo exists $root]} { return $found }
    foreach c [winfo children $root] {
        if {[winfo class $c] eq "TCombobox"} {
            set tv ""
            catch {set tv [$c cget -textvariable]}
            if {[string match "::mdance::gui::*_metric" $tv]
                && $tv ne "::mdance::gui::prime_metric"} {
                lappend found $c
            }
        }
        lappend found {*}[_find_metric_combos $c]
    }
    return $found
}

# _register_metric_combo - Remember a metric combobox and its grid cell so the
# lock can swap a plain "MSD" label in and out of that exact cell. The grid info
# has to be captured now, while the widget is still managed: once it is
# `grid forget`-ten there is nothing left to read it from.
proc ::mdance::gui::_register_metric_combo {cb} {
    variable metric_slots
    if {[info exists metric_slots($cb)]} return
    set gi [grid info $cb]
    if {$gi eq ""} return
    if {![winfo exists ${cb}L]} { ttk::label ${cb}L -text "MSD" -anchor w }
    set metric_slots($cb) $gi
}

# register_metric_combos - Find and register every metric combobox under $root.
proc ::mdance::gui::register_metric_combos {root} {
    foreach cb [_find_metric_combos $root] { _register_metric_combo $cb }
    apply_metric_lock
}

# apply_metric_lock - Show either the combobox or a static "MSD" label in each
# registered cell, and keep the Sweep tab's metric checkboxes in step.
proc ::mdance::gui::apply_metric_lock {} {
    variable metric_slots
    variable metric_unlocked
    variable metric_all
    variable sweep_metric

    if {!$metric_unlocked} {
        # Re-locking must RESET the values, not just hide the widget: a metric
        # chosen while unlocked would otherwise keep going to the backend behind
        # a hidden control the user can no longer see or correct.
        foreach v {km_metric div_metric helm_metric eq_metric ft_metric} {
            set ::mdance::gui::$v "MSD"
        }
    }
    foreach cb [array names metric_slots] {
        if {![winfo exists $cb]} { unset metric_slots($cb); continue }
        set gi $metric_slots($cb)
        if {$metric_unlocked} {
            catch {grid forget ${cb}L}
            $cb configure -values $metric_all -state readonly
            catch {grid $cb {*}$gi}
        } else {
            catch {grid forget $cb}
            catch {grid ${cb}L {*}$gi}
        }
    }
    # The Sweep tab sweeps OVER metrics, so locking means "MSD only" there.
    foreach m $metric_all {
        set wpath .mdance.nb.sweep.met.m$m
        if {![winfo exists $wpath]} continue
        if {$metric_unlocked} {
            $wpath configure -state normal
        } else {
            if {$m ne "MSD"} { set sweep_metric($m) 0 }
            $wpath configure -state [expr {$m eq "MSD" ? "normal" : "disabled"}]
        }
    }
    if {!$metric_unlocked} { set sweep_metric(MSD) 1 }
}

# elbow_algo_params - The algorithm-specific settings an elbow scan needs,
# taken from that algorithm's own tab so the scan matches the single runs the
# user makes there. Only HELM needs anything today.
proc ::mdance::gui::elbow_algo_params {algorithm} {
    variable helm_pre_k
    variable helm_pre_kinit
    variable helm_pre_percentage
    variable helm_merge
    if {$algorithm ne "helm"} { return {} }
    return [dict create pre-k $helm_pre_k pre-kinit $helm_pre_kinit \
        pre-percentage $helm_pre_percentage merge-scheme $helm_merge]
}

# _citation_footer - Put a reference footer at the bottom of an algorithm tab.
#
# A read-only text widget rather than a label so the DOI can be selected and
# copied, which is the whole point of showing a citation. Packed -side bottom so
# it can never push the controls above it off a short window, -wrap word so long
# citations reflow, and -font TkDefaultFont so it follows the app font-size
# setting (apply_app_font reconfigures that named font).
#
# The references shown are ONLY those the MDANCE authors supplied. The backend
# repo's own docs are not usable as a source here: docs/reference/publications.md
# and docs/algorithms/kmeans-nani.md cite one title/DOI while
# docs/concepts/clustering-overview.md cites a different title and DOI for the
# same authors, volume and pages, so at least one is wrong. Tabs with no
# supplied reference say so rather than showing a guess.
proc ::mdance::gui::_citation_footer {parent refs} {
    ttk::labelframe $parent.cite -text "Reference" -padding {8 4}
    pack $parent.cite -side bottom -fill x -padx 10 -pady {0 8}

    set body [join $refs "\n\n"]
    # Height in display lines: enough for each reference to wrap over a few
    # lines without leaving a large empty gap. Nothing depends on it being
    # exact; the widget simply must not consume the tab.
    set h [expr {2 * [llength $refs] + 1}]
    # -width 1 because a text widget's default is 80 columns, and it asks for
    # them: the citation footer alone made every algorithm panel request 688 px.
    # It is packed -fill x, so the real width comes from the container.
    text $parent.cite.t -height $h -width 1 -wrap word -relief flat -padx 2 -pady 2 \
        -font TkDefaultFont -cursor "" -takefocus 0 \
        -background [ttk::style lookup TFrame -background]
    $parent.cite.t insert end $body
    # Disable AFTER inserting: a disabled text widget rejects inserts, but still
    # allows the mouse selection that makes the DOI copyable.
    $parent.cite.t configure -state disabled
    pack $parent.cite.t -fill x
    return $parent.cite
}

# Citations, exactly as supplied by the MDANCE authors.
proc ::mdance::gui::_refs_nani {} {
    return [list \
        "Chen, L.; Roe, D. R.; Kochert, M.; Simmerling, C.; Miranda-Quintana, R. A. K-Means NANI: An Improved Clustering Algorithm for Molecular Dynamics Simulations. J. Chem. Theory Comput. 2024, 20 (13), 5583-5597. https://doi.org/10.1021/acs.jctc.4c00308" \
        "Santos, J. B. W.; Chen, L.; Miranda-Quintana, R. A. Scaling k-Means for Multi-Million Frames: A Stratified NANI Approach for Large-Scale MD Simulations. J. Chem. Inf. Model. 2026, acs.jcim.5c02741. https://doi.org/10.1021/acs.jcim.5c02741"]
}
proc ::mdance::gui::_refs_helm {} {
    return [list \
        "Chen, L.; Santos, Jherome Brylle Woody; Gaza, J.; Perez, A.; Miranda-Quintana, R. A. Hierarchical Extended Linkage Method (HELM)'s Deep Dive into Hybrid Clustering Strategies. J. Chem. Inf. Model. 2025, 65 (12), 6209-6220. https://doi.org/10.1021/acs.jcim.5c00539"]
}
# For algorithms with no reference on file. Naming the absence beats printing a
# citation nobody verified.
proc ::mdance::gui::_refs_none {what} {
    return [list "No $what reference is recorded in this build. MDANCE project: https://github.com/mqcomplab/MDANCE"]
}

# _chknum - validate a numeric entry value at submit time. kind is "double" or
# "int"; min (optional) is an inclusive lower bound. Shows an actionable message
# and returns 0 on failure. Besides catching typos/blank fields, this keeps any
# value that begins with a shell/pipe redirection token (e.g. ">f") out of the
# backend command line, since a validated number can never start with one.
proc ::mdance::gui::_chknum {val label {kind double} {min ""}} {
    set ok [expr {$kind eq "int" ? [string is integer -strict $val] \
                                 : [string is double -strict $val]}]
    if {$ok && $min ne "" && $val < $min} { set ok 0 }
    if {!$ok} {
        set what [expr {$kind eq "int" ? "a whole number" : "a number"}]
        set bound [expr {$min ne "" ? " >= $min" : ""}]
        tk_messageBox -icon error -title "MDANCE" \
            -message "$label must be $what$bound."
        return 0
    }
    return 1
}

# --- Setup Tab ---
proc ::mdance::gui::build_setup_tab {parent} {
    ttk::labelframe $parent.mol -text "Molecule" -padding 10
    pack $parent.mol -fill x -padx 10 -pady 10

    # Vendored from the Interactions plugin: a chooser listing the molecules
    # actually loaded instead of a free-text "top", and a selection field that
    # reports its atom count as you type instead of at Run time. See
    # mdance_input.tcl for what was taken and what was adapted.
    ::mdance::input::build $parent.mol

    # Frame range / stride
    ttk::labelframe $parent.range -text "Frame Range" -padding 10
    pack $parent.range -fill x -padx 10 -pady {10 0}

    ttk::label $parent.range.lf -text "First:"
    ttk::spinbox $parent.range.first -textvariable ::mdance::gui::frame_first \
        -from 0 -to 1000000 -width 8
    ttk::label $parent.range.ll -text "Last:"
    ttk::spinbox $parent.range.last -textvariable ::mdance::gui::frame_last \
        -from -1 -to 1000000 -width 8
    ttk::label $parent.range.ls -text "Stride:"
    ttk::spinbox $parent.range.stride -textvariable ::mdance::gui::frame_stride \
        -from 1 -to 100000 -width 8
    grid $parent.range.lf     -row 0 -column 0 -sticky w -padx {0 4}
    grid $parent.range.first  -row 0 -column 1 -sticky w -padx {0 12}
    grid $parent.range.ll     -row 0 -column 2 -sticky w -padx {0 4}
    grid $parent.range.last   -row 0 -column 3 -sticky w -padx {0 12}
    grid $parent.range.ls     -row 0 -column 4 -sticky w -padx {0 4}
    grid $parent.range.stride -row 0 -column 5 -sticky w
    ttk::label $parent.range.note \
        -text "Cluster a subset of frames. Last = -1 means the final frame. Stride decimates (e.g. 10 keeps every 10th frame)." \
        -justify left -wraplength 460 -foreground "#555555"
    grid $parent.range.note -row 1 -column 0 -columnspan 6 -sticky w -pady {6 0}

    # MDANCE backend location
    ttk::labelframe $parent.cli -text "MDANCE Backend" -padding 10
    pack $parent.cli -fill x -padx 10 -pady {10 0}

    ttk::label $parent.cli.mode_label -text "Mode:"
    ttk::label $parent.cli.mode_value -text "" -anchor w
    grid $parent.cli.mode_label -row 0 -column 0 -sticky w -padx {0 10}
    grid $parent.cli.mode_value -row 0 -column 1 -columnspan 2 -sticky w

    ttk::label $parent.cli.path_label -text "Path:"
    ttk::entry $parent.cli.path_entry -textvariable ::mdance::gui::cli_display_path -width 24 -state readonly
    ttk::button $parent.cli.browse -text "Browse..." -command ::mdance::gui::browse_cli
    ttk::label $parent.cli.status -text "" -anchor w

    grid $parent.cli.path_label -row 1 -column 0 -sticky w -padx {0 10} -pady {5 0}
    grid $parent.cli.path_entry -row 1 -column 1 -sticky ew -padx {0 5} -pady {5 0}
    grid $parent.cli.browse -row 1 -column 2 -sticky w -pady {5 0}
    grid $parent.cli.status -row 2 -column 0 -columnspan 3 -sticky w -pady {5 0}
    grid columnconfigure $parent.cli 1 -weight 1

    # Detect backend on tab creation
    detect_backend $parent

    # Preview button
    ttk::frame $parent.preview -padding 10
    pack $parent.preview -fill x -padx 10

    ttk::button $parent.preview.btn -text "Preview Selection" -command ::mdance::gui::preview_selection
    ttk::button $parent.preview.tools -text "Frame Tools..." -command ::mdance::gui::frame_tools_dialog
    ttk::label $parent.preview.info -text "" -anchor w
    pack $parent.preview.btn -side left
    pack $parent.preview.tools -side left -padx {6 0}
    pack $parent.preview.info -side left -padx 10 -fill x -expand 1
}

# settings_dialog - the preferences that used to sit in two labelframes at the
# bottom of the input column, taking ~200 px of the column permanently to hold
# four controls that are touched once a session. Modelled on the interactions
# plugin's own Settings dialog (interactions/gui/settings.tcl): one reused
# toplevel, transient to the main window, Escape to dismiss, everything applying
# live so there is nothing to OK.
proc ::mdance::gui::settings_dialog {} {
    set w .mdance_settings
    if {[winfo exists $w]} { wm deiconify $w; raise $w; focus $w; return $w }

    toplevel $w
    wm title $w "MDANCE Settings"
    wm resizable $w 0 0
    catch {wm transient $w .mdance}
    bind $w <Escape> [list destroy $w]

    ttk::labelframe $w.display -text "Display" -padding 10
    pack $w.display -fill x -padx 12 -pady {12 0}

    ttk::label $w.display.afl -text "App font size:"
    ttk::spinbox $w.display.afs -from 8 -to 18 -width 4 -increment 1 \
        -textvariable ::mdance::gui::app_font_size \
        -command ::mdance::gui::apply_app_font
    bind $w.display.afs <Return>   ::mdance::gui::apply_app_font
    bind $w.display.afs <FocusOut> ::mdance::gui::apply_app_font

    ttk::label $w.display.pfl -text "Plot font size:"
    ttk::spinbox $w.display.pfs -from 6 -to 24 -width 4 -increment 1 \
        -textvariable ::mdance::plots::plot_font_size \
        -command ::mdance::plots::redraw_all
    bind $w.display.pfs <Return>   ::mdance::plots::redraw_all
    bind $w.display.pfs <FocusOut> ::mdance::plots::redraw_all

    # Off by default: the tab already names the plot. Exports still get the
    # title, since an exported image has no tab to identify it by.
    ttk::checkbutton $w.display.titles -text "Titles inside plots" \
        -variable ::mdance::plots::plot_titles \
        -command ::mdance::plots::redraw_all

    grid $w.display.afl -row 0 -column 0 -sticky w -padx {0 10}
    grid $w.display.afs -row 0 -column 1 -sticky w
    grid $w.display.pfl -row 1 -column 0 -sticky w -padx {0 10} -pady {6 0}
    grid $w.display.pfs -row 1 -column 1 -sticky w -pady {6 0}
    grid $w.display.titles -row 2 -column 0 -columnspan 2 -sticky w -pady {8 0}

    ttk::labelframe $w.adv -text "Advanced" -padding 10
    pack $w.adv -fill x -padx 12 -pady {10 0}
    ttk::checkbutton $w.adv.metric -text "Unlock metric selection" \
        -variable ::mdance::gui::metric_unlocked \
        -command ::mdance::gui::apply_metric_lock
    ttk::label $w.adv.note -justify left -wraplength 330 -foreground "#555555" \
        -text "Clustering runs on MSD, the only metric with a physical meaning for Cartesian MD frames. The other indices are binary/extended-similarity measures for fingerprint-style data; unlock only if you know your input suits them."
    pack $w.adv.metric -anchor w
    pack $w.adv.note -anchor w -pady {6 0}

    ttk::frame $w.btns
    pack $w.btns -fill x -padx 12 -pady 12
    ttk::button $w.btns.close -text "Close" -command [list destroy $w]
    pack $w.btns.close -side right

    return $w
}

# build_help_tab - the Quick Start, moved off the input column onto its own
# view. It is reference text: it does not change, nothing on it is an input, and
# it was consuming the bottom of the column that the algorithm parameters need.
proc ::mdance::gui::build_help_tab {parent} {
    ttk::labelframe $parent.qs -text "Quick Start" -padding 12
    pack $parent.qs -fill x -padx 12 -pady 12

    set help_text "1. Load a molecule with a trajectory in VMD.\n\
2. Pick it in the Molecule chooser at the top of the input column.\n\
3. Type an atom selection. The line under it reports how many atoms match,\n\
\u0020\u0020 so you can tell a typo from an empty selection before you run.\n\
4. Optionally set a Frame Range to skip equilibration or decimate.\n\
5. Choose an algorithm, set its parameters, and press Run.\n\
6. Read the Results view; open any plot from Figures.\n\n\
Algorithms:\n\
\u0020\u0020 KMeans NANI - fast partitional clustering\n\
\u0020\u0020 DIVINE      - divisive hierarchical (top-down)\n\
\u0020\u0020 HELM        - agglomerative hierarchical (bottom-up)\n\
\u0020\u0020 eQUAL       - radial/threshold; k emerges from the threshold\n\n\
Sweep runs a grid of {algorithm x K x metric x init} and tabulates the scores.\n\
PRIME predicts the representative frame of a clustered ensemble."

    ttk::label $parent.qs.text -text $help_text -justify left -anchor w
    pack $parent.qs.text -fill x

    ttk::labelframe $parent.ref -text "Reference" -padding 12
    pack $parent.ref -fill x -padx 12 -pady {0 12}
    ttk::label $parent.ref.t -justify left -anchor w -wraplength 520 \
        -text "Algorithms: MDANCE (Miranda-Quintana group). Backend: CPP-MDANCE.\nHost: VMD, Theoretical and Computational Biophysics Group, UIUC.\nEach algorithm tab carries the citation for the method it runs."
    pack $parent.ref.t -fill x
}


proc ::mdance::gui::apply_app_font {} {
    variable app_font_size
    font configure TkDefaultFont -size $app_font_size
}

# add_range - Inject the Setup-tab first/last/stride selection into a params
# dict. Returns 0 (having shown a message) when one of the three fields is not a
# whole number, so the caller aborts before starting a run. frame_list rejects
# these too, but naming the offending field here beats a mid-run error dialog --
# and the spinboxes accept arbitrary typed text, so this is reachable.
proc ::mdance::gui::add_range {paramsVar} {
    upvar 1 $paramsVar params
    variable frame_first
    variable frame_last
    variable frame_stride
    if {![_chknum $frame_first  "First frame" int 0]}  { return 0 }
    if {![_chknum $frame_last   "Last frame"  int -1]} { return 0 }
    if {![_chknum $frame_stride "Stride"      int 1]}  { return 0 }
    dict set params first $frame_first
    dict set params last $frame_last
    dict set params stride $frame_stride
    return 1
}

proc ::mdance::gui::preview_selection {} {
    variable mol_selection
    variable atom_selection
    variable frame_first
    variable frame_last
    variable frame_stride

    set parent .mdance.nb.setup

    set molid $mol_selection
    if {$molid eq "top"} {
        set molid [molinfo top]
    }

    if {[catch {
        set nframes [molinfo $molid get numframes]
        set sel [atomselect $molid $atom_selection]
        set natoms [$sel num]
        $sel delete
        set nsel [llength [::mdance::frame_list $molid $frame_first $frame_last $frame_stride]]
        $parent.preview.info configure \
            -text "$natoms atoms, $nsel of $nframes frames selected (molid=$molid)"
    } err]} {
        $parent.preview.info configure -text "Error: $err"
    }
}

# --- Backend Detection ---
proc ::mdance::gui::detect_backend {parent} {
    variable cli_display_path

    # Try library first. Must use the explicit "Mdance" prefix exactly like
    # ::mdance::init does: the extension only exports Mdance_Init, so a bare
    # `load $lib_path` looks for Mdance_tcl_Init, fails, and would wrongly leave
    # the GUI showing "CLI" while a later run silently flips to library mode
    # (mismatching the Cancel button computed from use_library).
    set lib_path [::mdance::utils::find_library]
    if {$lib_path ne "" && ![catch {load $lib_path Mdance}]} {
        set ::mdance::use_library 1
        set cli_display_path $lib_path
        $parent.cli.mode_value configure -text "Library (native)" -foreground "#006600"
        $parent.cli.status configure -text "Loaded" -foreground "#006600"
        return
    }

    # Fall back to CLI
    $parent.cli.mode_value configure -text "CLI (subprocess)" -foreground "#333333"
    if {[catch {set path [::mdance::utils::find_cli]} err]} {
        set cli_display_path ""
        $parent.cli.status configure -text "Not found. Set MDANCE_CLI env var or use Browse." -foreground red
    } else {
        set cli_display_path $path
        set ::mdance::cli_path $path
        $parent.cli.status configure -text "Found" -foreground "#006600"
    }
}

proc ::mdance::gui::browse_cli {} {
    variable cli_display_path

    set f [tk_getOpenFile -title "Locate mdance-cli binary"]
    if {$f ne ""} {
        if {![file executable $f]} {
            tk_messageBox -icon error -title "MDANCE" \
                -message "Selected file is not executable: $f"
            return
        }
        set cli_display_path $f
        set ::mdance::cli_path $f
        .mdance.nb.setup.cli.status configure -text "Found" -foreground "#006600"
    }
}

# --- KMeans Tab ---
proc ::mdance::gui::build_kmeans_tab {parent} {
    ttk::labelframe $parent.params -text "KMeans NANI Parameters" -padding 10
    pack $parent.params -fill x -padx 10 -pady 10

    set row 0
    foreach {label var widget vals} {
        "Number of clusters:" km_nclusters spinbox {2 200}
        "Metric:" km_metric combobox {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
        "Initialization:" km_kinit combobox {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP}
        "Sampling %:" km_percentage spinbox {1 100}
    } {
        ttk::label $parent.params.l$row -text $label
        if {$widget eq "spinbox"} {
            ttk::spinbox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -from [lindex $vals 0] -to [lindex $vals 1] -width 10
        } else {
            ttk::combobox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -values $vals -state readonly -width 20
        }
        grid $parent.params.l$row -row $row -column 0 -sticky w -padx {0 10} -pady 3
        grid $parent.params.w$row -row $row -column 1 -sticky w -pady 3
        incr row
    }

    ttk::frame $parent.run -padding 10
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Run KMeans" -command ::mdance::gui::run_kmeans
    pack $parent.run.btn -side left
    ttk::button $parent.run.elbow -text "Elbow Plot..." \
        -command {::mdance::plots::elbow_plot kmeans}
    pack $parent.run.elbow -side left -padx {6 0}

    _citation_footer $parent [_refs_nani]
}

proc ::mdance::gui::run_kmeans {} {
    variable mol_selection
    variable atom_selection
    variable km_nclusters
    variable km_metric
    variable km_kinit
    variable km_percentage

    # These reach the CLI command line verbatim. Besides catching typos, a
    # validated number can never begin with a redirection token like ">f", which
    # Tcl's exec/open-| would otherwise treat as a file redirection.
    if {![_chknum $km_nclusters "Number of clusters" int 2]} return
    if {![_chknum $km_percentage "Sampling %" int 1]} return

    set molid $mol_selection
    if {$molid eq "top"} {
        set molid [molinfo top]
    }

    set params [dict create \
        molid $molid \
        atomsel $atom_selection \
        nclusters $km_nclusters \
        metric $km_metric \
        kinit $km_kinit \
        percentage $km_percentage]
    if {![add_range params]} return

    run_guarded kmeans $params
}

# --- DIVINE Tab ---
proc ::mdance::gui::build_divine_tab {parent} {
    ttk::labelframe $parent.params -text "DIVINE Parameters" -padding 10
    pack $parent.params -fill x -padx 10 -pady 10

    set row 0
    foreach {label var widget vals} {
        "Number of clusters:" div_nclusters spinbox {2 200}
        "Metric:" div_metric combobox {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
        "Split criterion:" div_split combobox {MSD Radius WeightedMSD}
        "Anchor method:" div_anchors combobox {NANI OutlierPair SplinterPair}
        "Initialization:" div_kinit combobox {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP}
        "Threshold:" div_threshold entry {}
        "Sampling %:" div_percentage spinbox {1 100}
    } {
        ttk::label $parent.params.l$row -text $label
        if {$widget eq "spinbox"} {
            ttk::spinbox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -from [lindex $vals 0] -to [lindex $vals 1] -width 10
        } elseif {$widget eq "combobox"} {
            ttk::combobox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -values $vals -state readonly -width 20
        } else {
            ttk::entry $parent.params.w$row -textvariable ::mdance::gui::$var -width 10
        }
        grid $parent.params.l$row -row $row -column 0 -sticky w -padx {0 10} -pady 3
        grid $parent.params.w$row -row $row -column 1 -sticky w -pady 3
        incr row
    }

    # Refine checkbox
    ttk::checkbutton $parent.params.refine -text "Refine with KMeans" \
        -variable ::mdance::gui::div_refine
    grid $parent.params.refine -row $row -column 0 -columnspan 2 -sticky w -pady 3
    incr row

    # End mode
    ttk::label $parent.params.lend -text "Stop when:"
    ttk::radiobutton $parent.params.endk -text "K clusters reached" \
        -variable ::mdance::gui::div_end_mode -value "k"
    ttk::radiobutton $parent.params.endp -text "All points separated" \
        -variable ::mdance::gui::div_end_mode -value "points"
    grid $parent.params.lend -row $row -column 0 -sticky w -padx {0 10} -pady 3
    grid $parent.params.endk -row $row -column 1 -sticky w -pady 3
    incr row
    grid $parent.params.endp -row $row -column 1 -sticky w -pady 3

    ttk::frame $parent.run -padding 10
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Run DIVINE" -command ::mdance::gui::run_divine
    pack $parent.run.btn -side left
    ttk::button $parent.run.elbow -text "Elbow Plot..." \
        -command {::mdance::plots::elbow_plot divine}
    pack $parent.run.elbow -side left -padx {6 0}

    _citation_footer $parent [_refs_none "DIVINE"]
}

# _divine_combo_ok - Refuse a DIVINE configuration that would crash the backend
# instead of failing it. Returns 1 when the run may proceed.
#
# Refusing rather than silently forcing refine off is deliberate: refinement
# changes the clustering, so quietly turning it off would hand the user
# different results than the ones they configured, with nothing to say so.
proc ::mdance::gui::_divine_combo_ok {anchors refine} {
    variable divine_crash_anchors
    if {!$refine || [lsearch -exact $divine_crash_anchors $anchors] < 0} { return 1 }
    tk_messageBox -icon error -title "MDANCE" -message \
        "The $anchors anchor combined with Refine crashes the MDANCE backend (an out-of-bounds read that would take VMD down with it), so this run has been stopped.\n\nEither turn Refine off to use $anchors, or keep Refine on and choose the NANI anchor, which is unaffected."
    return 0
}

proc ::mdance::gui::run_divine {} {
    variable mol_selection
    variable atom_selection
    variable div_nclusters
    variable div_metric
    variable div_split
    variable div_anchors
    variable div_kinit
    variable div_refine
    variable div_threshold
    variable div_end_mode
    variable div_percentage

    if {![_chknum $div_nclusters "Number of clusters" int 2]} return
    if {![_chknum $div_percentage "Sampling %" int 1]} return
    if {![_chknum $div_threshold "DIVINE threshold" double 0]} return
    if {![_divine_combo_ok $div_anchors $div_refine]} return

    set molid $mol_selection
    if {$molid eq "top"} {
        set molid [molinfo top]
    }

    set params [dict create \
        molid $molid \
        atomsel $atom_selection \
        nclusters $div_nclusters \
        metric $div_metric \
        split $div_split \
        anchors $div_anchors \
        kinit $div_kinit \
        refine $div_refine \
        threshold $div_threshold \
        end-mode $div_end_mode \
        percentage $div_percentage]
    if {![add_range params]} return

    run_guarded divine $params
}

# --- HELM Tab ---
proc ::mdance::gui::build_helm_tab {parent} {
    ttk::labelframe $parent.params -text "HELM Parameters" -padding 10
    pack $parent.params -fill x -padx 10 -pady 10

    set row 0

    # Stopping criterion
    ttk::label $parent.params.lstop -text "Stop criterion:"
    ttk::radiobutton $parent.params.stopn -text "N clusters:" \
        -variable ::mdance::gui::helm_stop_mode -value "nclusters"
    ttk::spinbox $parent.params.nclust -textvariable ::mdance::gui::helm_nclusters \
        -from 2 -to 200 -width 8
    grid $parent.params.lstop -row $row -column 0 -sticky w -padx {0 10} -pady 3
    grid $parent.params.stopn -row $row -column 1 -sticky w -pady 3
    grid $parent.params.nclust -row $row -column 2 -sticky w -pady 3
    incr row

    ttk::radiobutton $parent.params.stope -text "Epsilon:" \
        -variable ::mdance::gui::helm_stop_mode -value "eps"
    ttk::entry $parent.params.eps -textvariable ::mdance::gui::helm_eps -width 10
    grid $parent.params.stope -row $row -column 1 -sticky w -pady 3
    grid $parent.params.eps -row $row -column 2 -sticky w -pady 3
    incr row

    # Metric and merge scheme
    foreach {label var widget vals} {
        "Metric:" helm_metric combobox {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
        "Merge scheme:" helm_merge combobox {Intra Inter Half}
    } {
        ttk::label $parent.params.l$row -text $label
        ttk::combobox $parent.params.w$row -textvariable ::mdance::gui::$var \
            -values $vals -state readonly -width 20
        grid $parent.params.l$row -row $row -column 0 -sticky w -padx {0 10} -pady 3
        grid $parent.params.w$row -row $row -column 1 -columnspan 2 -sticky w -pady 3
        incr row
    }

    # Trim Options
    #
    # These fields are NOT peers, which is exactly why "Min samples" was
    # reported as non-functional. In the backend (src/cluster/helm.cpp):
    #   * minSamples is read ONLY inside trimClusters(), which runs only when
    #     trim-start is set -- so setting it with trimming off did nothing at all;
    #   * trim-start is REFUSED unless one of trim-val / trim-k is given, so
    #     setting Min samples alone produced a backend exception, not an effect;
    #   * trim-val and trim-k together are refused whether or not trimming is
    #     on, so two leftover values in "inert" fields failed the run.
    # The controls below express that dependency instead of hiding it.
    ttk::labelframe $parent.trim -text "Trim Options" -padding 10
    pack $parent.trim -fill x -padx 10 -pady 5

    ttk::checkbutton $parent.trim.enable -text "Enable trimming" \
        -variable ::mdance::gui::helm_trim_start \
        -command ::mdance::gui::_helm_trim_sync
    grid $parent.trim.enable -row 0 -column 0 -columnspan 3 -sticky w -pady 3

    ttk::radiobutton $parent.trim.ck -text "Discard the loosest" \
        -variable ::mdance::gui::helm_trim_mode -value "k" \
        -command ::mdance::gui::_helm_trim_sync
    ttk::entry $parent.trim.ek -textvariable ::mdance::gui::helm_trim_k -width 8
    ttk::label $parent.trim.lk -text "clusters (highest MSD)"
    grid $parent.trim.ck -row 1 -column 0 -sticky w -padx {20 6} -pady 3
    grid $parent.trim.ek -row 1 -column 1 -sticky w -pady 3
    grid $parent.trim.lk -row 1 -column 2 -sticky w -padx {6 0} -pady 3

    ttk::radiobutton $parent.trim.cval -text "Discard clusters with MSD above" \
        -variable ::mdance::gui::helm_trim_mode -value "val" \
        -command ::mdance::gui::_helm_trim_sync
    ttk::entry $parent.trim.eval -textvariable ::mdance::gui::helm_trim_val -width 8
    grid $parent.trim.cval -row 2 -column 0 -sticky w -padx {20 6} -pady 3
    grid $parent.trim.eval -row 2 -column 1 -sticky w -pady 3

    ttk::label $parent.trim.lms -text "Also discard clusters smaller than:"
    ttk::entry $parent.trim.ems -textvariable ::mdance::gui::helm_min_samples -width 8
    grid $parent.trim.lms -row 3 -column 0 -sticky w -padx {20 6} -pady {8 3}
    grid $parent.trim.ems -row 3 -column 1 -sticky w -pady {8 3}
    ttk::label $parent.trim.nms \
        -text "Below 1 this is a fraction of the total frames (0.01 = 1%); 1 or more is an absolute frame count. Applies only while trimming is enabled." \
        -justify left -wraplength 430 -foreground "#555555"
    grid $parent.trim.nms -row 4 -column 0 -columnspan 3 -sticky w -pady {2 0}

    # Initial labels source
    ttk::labelframe $parent.labels -text "Initial Labels" -padding 10
    pack $parent.labels -fill x -padx 10 -pady 5

    ttk::radiobutton $parent.labels.auto -text "Auto pre-cluster with KMeans" \
        -variable ::mdance::gui::helm_labels_source -value "auto" \
        -command ::mdance::gui::_helm_labels_sync
    ttk::label $parent.labels.lprek -text "Pre-cluster K:"
    ttk::spinbox $parent.labels.prek -textvariable ::mdance::gui::helm_pre_k \
        -from 5 -to 500 -width 8
    # This stage IS a KMeans run, so it gets KMeans' parameters. It used to be
    # given only the metric and K, silently falling back to whatever the backend
    # defaults its initialization to -- so the hidden first half of a HELM run
    # did not match the single KMeans run the user had tuned on the KMeans tab.
    ttk::label $parent.labels.lpinit -text "Initialization:"
    ttk::combobox $parent.labels.pinit -textvariable ::mdance::gui::helm_pre_kinit \
        -values {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP} \
        -state readonly -width 18
    ttk::label $parent.labels.lppct -text "Sampling %:"
    ttk::spinbox $parent.labels.ppct -textvariable ::mdance::gui::helm_pre_percentage \
        -from 1 -to 100 -width 8
    grid $parent.labels.auto -row 0 -column 0 -columnspan 3 -sticky w -pady 3
    grid $parent.labels.lprek -row 1 -column 0 -sticky w -padx {20 10} -pady 3
    grid $parent.labels.prek -row 1 -column 1 -sticky w -pady 3
    grid $parent.labels.lpinit -row 2 -column 0 -sticky w -padx {20 10} -pady 3
    grid $parent.labels.pinit -row 2 -column 1 -columnspan 2 -sticky w -pady 3
    grid $parent.labels.lppct -row 3 -column 0 -sticky w -padx {20 10} -pady 3
    grid $parent.labels.ppct -row 3 -column 1 -sticky w -pady 3

    ttk::radiobutton $parent.labels.file -text "Load from file:" \
        -variable ::mdance::gui::helm_labels_source -value "file" \
        -command ::mdance::gui::_helm_labels_sync
    ttk::entry $parent.labels.fentry -textvariable ::mdance::gui::helm_labels_file -width 30
    ttk::button $parent.labels.browse -text "Browse..." -command {
        set f [tk_getOpenFile -filetypes {{"CSV files" ".csv"} {"All files" "*"}}]
        if {$f ne ""} { set ::mdance::gui::helm_labels_file $f }
    }
    grid $parent.labels.file -row 4 -column 0 -sticky w -pady {8 3}
    grid $parent.labels.fentry -row 4 -column 1 -sticky ew -pady {8 3}
    grid $parent.labels.browse -row 4 -column 2 -sticky w -padx 5 -pady {8 3}
    grid columnconfigure $parent.labels 1 -weight 1

    ttk::frame $parent.run -padding 10
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Run HELM" -command ::mdance::gui::run_helm
    pack $parent.run.btn -side left
    ttk::button $parent.run.elbow -text "Elbow Plot..." \
        -command {::mdance::plots::elbow_plot helm}
    pack $parent.run.elbow -side left -padx {6 0}

    _citation_footer $parent [_refs_helm]

    # Put the dependent controls into the right state for the initial values.
    _helm_trim_sync
    _helm_labels_sync
}

# _helm_trim_sync - Enable only the trim controls that can currently do
# something. Everything under "Enable trimming" is inert while it is off (the
# backend ignores min-samples and refuses trim-start without a criterion), and
# only the selected criterion's entry is live, because the backend refuses
# trim-val and trim-k together.
proc ::mdance::gui::_helm_trim_sync {} {
    variable helm_trim_start
    variable helm_trim_mode
    set t .mdance.nb.helm.trim
    if {![winfo exists $t]} return
    set on [expr {$helm_trim_start ? "normal" : "disabled"}]
    foreach w {ck cval ems} { catch {$t.$w configure -state $on} }
    foreach w {lk lms nms} {
        catch {$t.$w configure -foreground [expr {$helm_trim_start ? "#000000" : "#999999"}]}
    }
    catch {$t.ek configure -state \
        [expr {$helm_trim_start && $helm_trim_mode eq "k" ? "normal" : "disabled"}]}
    catch {$t.eval configure -state \
        [expr {$helm_trim_start && $helm_trim_mode eq "val" ? "normal" : "disabled"}]}
}

# _helm_labels_sync - The pre-cluster parameters only apply when HELM is
# generating its own initial labels; grey them out when they come from a file.
proc ::mdance::gui::_helm_labels_sync {} {
    variable helm_labels_source
    set l .mdance.nb.helm.labels
    if {![winfo exists $l]} return
    set auto [expr {$helm_labels_source eq "auto" ? "normal" : "disabled"}]
    foreach w {prek pinit ppct} { catch {$l.$w configure -state $auto} }
    # pinit is a readonly combobox: "normal" would make it editable, so restore
    # its readonly state rather than a plain normal one.
    if {$helm_labels_source eq "auto"} { catch {$l.pinit configure -state readonly} }
    foreach w {lprek lpinit lppct} {
        catch {$l.$w configure -foreground \
            [expr {$helm_labels_source eq "auto" ? "#000000" : "#999999"}]}
    }
    set fromfile [expr {$helm_labels_source eq "file" ? "normal" : "disabled"}]
    foreach w {fentry browse} { catch {$l.$w configure -state $fromfile} }
}

proc ::mdance::gui::run_helm {} {
    variable mol_selection
    variable atom_selection
    variable helm_nclusters
    variable helm_metric
    variable helm_merge
    variable helm_eps
    variable helm_stop_mode
    variable helm_trim_start
    variable helm_min_samples
    variable helm_trim_val
    variable helm_trim_k
    variable helm_trim_mode
    variable helm_labels_source
    variable helm_pre_k
    variable helm_pre_kinit
    variable helm_pre_percentage
    variable helm_labels_file

    set molid $mol_selection
    if {$molid eq "top"} {
        set molid [molinfo top]
    }

    set params [dict create \
        molid $molid \
        atomsel $atom_selection \
        metric $helm_metric \
        merge-scheme $helm_merge]
    if {![add_range params]} return

    # Set stopping criterion
    if {$helm_stop_mode eq "nclusters"} {
        dict set params nclusters $helm_nclusters
        dict set params eps -1
    } else {
        dict set params nclusters 0
        dict set params eps $helm_eps
    }

    # Validate numeric inputs (also keeps any redirection metacharacter out of
    # the backend command line)
    if {$helm_stop_mode eq "eps"} {
        if {![_chknum $helm_eps "HELM epsilon" double]} return
    } else {
        if {![_chknum $helm_nclusters "Number of clusters" int 2]} return
    }

    # Set initial labels
    if {$helm_labels_source eq "file" && $helm_labels_file ne ""} {
        dict set params initial-labels $helm_labels_file
    } else {
        if {![_chknum $helm_pre_k "Pre-cluster K" int 2]} return
        if {![_chknum $helm_pre_percentage "Pre-cluster sampling %" int 1]} return
        dict set params pre-k $helm_pre_k
        dict set params pre-kinit $helm_pre_kinit
        dict set params pre-percentage $helm_pre_percentage
    }

    # Trim parameters reach the backend ONLY when trimming is enabled.
    #
    # They used to be sent on every run, which was actively harmful rather than
    # merely untidy: the backend refuses trim-val and trim-k given together
    # whether or not trim-start is set, so two leftover values in fields the
    # user believed inert failed the whole run. And min-samples is read only
    # inside the backend's trimming step, so sending it without trim-start did
    # nothing at all -- the reason the field was reported as non-functional.
    if {$helm_trim_start} {
        if {![_chknum $helm_min_samples "Min samples" double 0]} return
        if {$helm_trim_mode eq "k"} {
            if {![_chknum $helm_trim_k "Number of clusters to discard" int 1]} return
            # The backend throws "trimK is too large!" once the count reaches
            # the cluster total, and warns past half. We know the total up front
            # in the auto pre-cluster case, so say so here instead.
            if {$helm_labels_source ne "file" || $helm_labels_file eq ""} {
                if {$helm_trim_k >= $helm_pre_k - 1} {
                    tk_messageBox -icon error -title "MDANCE" \
                        -message "Discarding $helm_trim_k of $helm_pre_k pre-clusters would leave nothing to cluster.\n\nChoose a number below [expr {$helm_pre_k - 1}], or raise Pre-cluster K."
                    return
                }
            }
            dict set params trim-k $helm_trim_k
        } else {
            if {![_chknum $helm_trim_val "MSD ceiling" double]} return
            if {$helm_trim_val <= 0} {
                tk_messageBox -icon error -title "MDANCE" \
                    -message "The MSD ceiling must be greater than 0.\n\nTrimming keeps only clusters whose MSD is below it, so 0 would discard every cluster."
                return
            }
            dict set params trim-val $helm_trim_val
        }
        dict set params trim-start 1
        dict set params min-samples $helm_min_samples
    }

    run_guarded helm $params
}

# --- eQUAL Tab ---
proc ::mdance::gui::build_equal_tab {parent} {
    ttk::labelframe $parent.params -text "eQUAL Parameters" -padding 10
    pack $parent.params -fill x -padx 10 -pady 10

    set row 0
    foreach {label var widget vals} {
        "Metric:" eq_metric combobox {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
        "Threshold (required):" eq_threshold entry {}
        "Seed method:" eq_seed combobox {medoid comp_sim}
        "Seeds per iter:" eq_nseeds entry {}
        "Sampling % (comp_sim):" eq_percentage spinbox {1 100}
        "Min samples:" eq_minsamples entry {}
        "Sim threshold:" eq_simthreshold entry {}
        "Align method:" eq_align combobox {none}
    } {
        ttk::label $parent.params.l$row -text $label
        if {$widget eq "spinbox"} {
            ttk::spinbox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -from [lindex $vals 0] -to [lindex $vals 1] -width 10
        } elseif {$widget eq "combobox"} {
            ttk::combobox $parent.params.w$row -textvariable ::mdance::gui::$var \
                -values $vals -state readonly -width 18
        } else {
            ttk::entry $parent.params.w$row -textvariable ::mdance::gui::$var -width 12
        }
        grid $parent.params.l$row -row $row -column 0 -sticky w -padx {0 10} -pady 3
        grid $parent.params.w$row -row $row -column 1 -sticky w -pady 3
        incr row
    }

    ttk::checkbutton $parent.params.reject -text "Reject low-density clusters (< min samples)" \
        -variable ::mdance::gui::eq_reject_lowd
    grid $parent.params.reject -row $row -column 0 -columnspan 2 -sticky w -pady 3
    incr row
    ttk::checkbutton $parent.params.checksim -text "Check intra-cluster similarity (terminates on first reject)" \
        -variable ::mdance::gui::eq_check_sim
    grid $parent.params.checksim -row $row -column 0 -columnspan 2 -sticky w -pady 3

    ttk::label $parent.note -justify left -wraplength 480 -foreground "#555555" -text \
        "eQUAL finds the cluster count automatically from the radial threshold — there is no k to set. Frames left over (trailing points, rejected low-density members) are labeled noise. Only the deterministic seed methods (medoid, comp_sim) and align=none are available in this build."
    pack $parent.note -fill x -padx 10 -pady {0 6}

    ttk::frame $parent.run -padding 10
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Run eQUAL" -command ::mdance::gui::run_equal
    pack $parent.run.btn -side left

    _citation_footer $parent [_refs_none "eQUAL"]
}

proc ::mdance::gui::run_equal {} {
    variable mol_selection
    variable atom_selection
    variable eq_metric
    variable eq_threshold
    variable eq_seed
    variable eq_nseeds
    variable eq_percentage
    variable eq_minsamples
    variable eq_simthreshold
    variable eq_align
    variable eq_reject_lowd
    variable eq_check_sim

    if {![string is double -strict $eq_threshold] || $eq_threshold < 0} {
        tk_messageBox -icon error -title "MDANCE" \
            -message "eQUAL needs a non-negative numeric Threshold (e.g. 2.0 for MSD on Cartesian coords)."
        return
    }
    if {![_chknum $eq_nseeds "Seeds per iter" int 1]} return
    if {![_chknum $eq_minsamples "Min samples" int 0]} return
    if {![_chknum $eq_simthreshold "Sim threshold" double]} return
    if {![_chknum $eq_percentage "Sampling %" int 1]} return

    set molid $mol_selection
    if {$molid eq "top"} { set molid [molinfo top] }

    set params [dict create \
        molid $molid \
        atomsel $atom_selection \
        metric $eq_metric \
        threshold $eq_threshold \
        seed-method $eq_seed \
        n-seeds $eq_nseeds \
        percentage $eq_percentage \
        min-samples $eq_minsamples \
        sim-threshold $eq_simthreshold \
        align $eq_align]
    if {$eq_reject_lowd} { dict set params reject-lowd 1 }
    if {$eq_check_sim}   { dict set params check-sim 1 }
    if {![add_range params]} return

    run_guarded equal $params
}

# --- Results Tab ---
# build_results_tab - the result surface. plotparent, when given, is where the
# plot launcher goes; it is a separate frame so the eleven Visualizations
# buttons can live on their own Figures tab instead of below the fold of a tab
# that already carries a summary, a table, eight actions and the frame overlay.
proc ::mdance::gui::build_results_tab {parent {plotparent ""}} {
    if {$plotparent eq ""} { set plotparent $parent }
    # Summary section
    ttk::labelframe $parent.summary -text "Clustering Summary" -padding 10
    pack $parent.summary -fill x -padx 10 -pady 10

    foreach {label tag} {
        "Algorithm:" algo
        "Number of clusters:" nclust
        "Calinski-Harabasz score:" ch
        "Davies-Bouldin score:" db
    } {
        set row [lsearch -exact {algo nclust ch db} $tag]
        ttk::label $parent.summary.l_$tag -text $label
        ttk::label $parent.summary.v_$tag -text "-" -anchor w
        grid $parent.summary.l_$tag -row $row -column 0 -sticky w -padx {0 10} -pady 2
        grid $parent.summary.v_$tag -row $row -column 1 -sticky w -pady 2
    }
    grid columnconfigure $parent.summary 1 -weight 1

    # Cluster table
    ttk::labelframe $parent.table -text "Clusters" -padding 10
    pack $parent.table -fill both -expand 1 -padx 10 -pady 5

    # A treeview rather than the old fixed-width listbox, so the columns are
    # real columns and can be sorted -- clusters are far easier to read ordered
    # by population or by MSD than by index. Follows the Sweep tab's table.
    #
    # The numeric columns store BARE numbers (no "%" suffix): sort_cluster_table
    # decides numeric vs lexical sorting by whether every cell parses as a
    # number, so a formatted "20.2%" would silently fall back to a lexical sort
    # that puts 9% after 10%.
    ttk::frame $parent.table.list
    pack $parent.table.list -fill both -expand 1
    set cols {id size pct msd rep}
    ttk::treeview $parent.table.list.tv -columns $cols -show headings -height 5 \
        -style Mdance.Treeview \
        -yscrollcommand [list $parent.table.list.sb set]
    ttk::scrollbar $parent.table.list.sb -orient vertical \
        -command [list $parent.table.list.tv yview]
    foreach {c text w} {id Cluster 70  size Size 70  pct "% of frames" 90 \
                        msd MSD 90  rep "Rep. frame" 90} {
        $parent.table.list.tv heading $c -text $text \
            -command [list ::mdance::gui::sort_cluster_table $c]
        $parent.table.list.tv column $c -width $w -anchor center
    }
    $parent.table.list.tv tag configure noise -foreground "#808080"
    pack $parent.table.list.sb -side right -fill y
    pack $parent.table.list.tv -side left -fill both -expand 1

    # Action buttons
    ttk::frame $parent.actions -padding 10
    pack $parent.actions -fill x -padx 10 -pady 5

    ttk::button $parent.actions.goto -text "Go to Representative" \
        -command ::mdance::gui::goto_selected_rep
    ttk::button $parent.actions.color -text "Color by Cluster" \
        -command ::mdance::gui::color_by_cluster
    ttk::button $parent.actions.export -text "Export Labels..." \
        -command ::mdance::gui::export_labels_dialog
    ttk::button $parent.actions.reps -text "Export Representatives..." \
        -command ::mdance::gui::export_reps_dialog
    ttk::button $parent.actions.split -text "Export Clusters..." \
        -command ::mdance::gui::export_clusters_dialog
    ttk::button $parent.actions.save -text "Save Session..." \
        -command ::mdance::gui::save_session_dialog
    ttk::button $parent.actions.load -text "Load Session..." \
        -command ::mdance::gui::load_session_dialog
    ttk::button $parent.actions.clear -text "Clear Results" \
        -command ::mdance::gui::clear_results

    grid $parent.actions.goto   -row 0 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.color  -row 0 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.export -row 0 -column 2 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.reps   -row 1 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.split  -row 1 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.save   -row 2 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.load   -row 2 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.clear  -row 2 -column 2 -padx 3 -pady 2 -sticky ew
    for {set col 0} {$col < 3} {incr col} {
        grid columnconfigure $parent.actions $col -weight 1
    }

    # Frame overlay: show several frames at once for direct visual comparison,
    # rather than only jumping to one representative.
    ttk::labelframe $parent.ov -text "Frame Overlay" -padding 10
    pack $parent.ov -fill x -padx 10 -pady 5

    ttk::label $parent.ov.lm -text "Top"
    ttk::spinbox $parent.ov.m -textvariable ::mdance::gui::overlay_m \
        -from 1 -to 200 -width 5
    ttk::label $parent.ov.lm2 -text "frames of the selected cluster"
    ttk::button $parent.ov.show -text "Show Overlay" \
        -command ::mdance::gui::show_cluster_overlay
    grid $parent.ov.lm   -row 0 -column 0 -sticky w -padx {0 4}
    grid $parent.ov.m    -row 0 -column 1 -sticky w
    grid $parent.ov.lm2  -row 0 -column 2 -sticky w -padx {4 10}
    grid $parent.ov.show -row 0 -column 3 -sticky w

    ttk::label $parent.ov.lr -text "Frame ranges:"
    ttk::entry $parent.ov.r -textvariable ::mdance::gui::overlay_ranges -width 24
    ttk::button $parent.ov.showr -text "Show Ranges" \
        -command ::mdance::gui::show_range_overlay
    grid $parent.ov.lr    -row 1 -column 0 -columnspan 2 -sticky w -pady {6 0}
    grid $parent.ov.r     -row 1 -column 2 -sticky ew -padx {4 10} -pady {6 0}
    grid $parent.ov.showr -row 1 -column 3 -sticky w -pady {6 0}

    ttk::button $parent.ov.clear -text "Clear Overlay" \
        -command ::mdance::gui::clear_overlay
    ttk::button $parent.ov.export -text "Export Top Frames..." \
        -command ::mdance::gui::export_top_frames_dialog
    grid $parent.ov.clear  -row 2 -column 0 -columnspan 2 -sticky w -pady {6 0}
    grid $parent.ov.export -row 2 -column 2 -columnspan 2 -sticky w -pady {6 0}
    ttk::label $parent.ov.note \
        -text "Top-N ranks a cluster's frames by MSD from its representative, nearest first, so N=1 is the representative alone. Ranges accept forms like 0-100,500,900-1000." \
        -justify left -wraplength 460 -foreground "#555555"
    grid $parent.ov.note -row 3 -column 0 -columnspan 4 -sticky w -pady {6 0}
    grid columnconfigure $parent.ov 2 -weight 1

    # Visualization buttons
    ttk::labelframe $plotparent.plots -text "Visualizations" -padding 10
    pack $plotparent.plots -fill x -padx 10 -pady 5
    ttk::label $plotparent.hint -justify left -foreground "#555555" \
        -text "Open a plot to add it as a tab below. Run a clustering to enable them."
    pack $plotparent.hint -fill x -padx 10 -pady {0 6} -before $plotparent.plots

    # One export bar for every plot, instead of the same four controls repeated
    # in eleven separate windows. It acts on whichever tab is selected.
    ttk::separator $plotparent.barsep -orient horizontal
    pack $plotparent.barsep -fill x -padx 10 -pady {8 0}

    ttk::frame $plotparent.bar -padding {10 6}
    pack $plotparent.bar -fill x
    ttk::label $plotparent.bar.fl -text "Font:"
    ttk::spinbox $plotparent.bar.fs -from 6 -to 24 -width 3 -increment 1 \
        -textvariable ::mdance::plots::shared_font \
        -command ::mdance::plots::on_shared_font
    bind $plotparent.bar.fs <Return> ::mdance::plots::on_shared_font
    ttk::separator $plotparent.bar.sep -orient vertical
    ttk::button $plotparent.bar.csv -text "Export CSV" \
        -command ::mdance::plots::export_current_csv
    ttk::button $plotparent.bar.ps -text "Export PS" \
        -command [list ::mdance::plots::export_current_image ps]
    ttk::button $plotparent.bar.png -text "Export PNG" \
        -command [list ::mdance::plots::export_current_image png]
    ttk::button $plotparent.bar.close -text "Close" \
        -command ::mdance::plots::close_figure
    ttk::button $plotparent.bar.closeall -text "Close All" \
        -command ::mdance::plots::close_all_figures
    pack $plotparent.bar.fl -side left -padx {0 2}
    pack $plotparent.bar.fs -side left -padx {0 6}
    pack $plotparent.bar.sep -side left -fill y -padx 4 -pady 2
    pack $plotparent.bar.csv -side left -padx 2
    pack $plotparent.bar.ps -side left -padx 2
    pack $plotparent.bar.png -side left -padx 2
    pack $plotparent.bar.closeall -side right -padx {2 0}
    pack $plotparent.bar.close -side right -padx 2

    # The plots themselves. Empty until one is opened.
    ttk::notebook $plotparent.nb
    pack $plotparent.nb -fill both -expand 1 -padx 10 -pady {6 10}
    bind $plotparent.nb <<NotebookTabChanged>> ::mdance::plots::sync_shared_bar

    # A sibling of the notebook, not a child of it: sync_shared_bar swaps the
    # two, so an empty Figures view says so instead of showing an empty sunken
    # box with a plot drawn behind it.
    ttk::label $plotparent.empty -anchor center -foreground "#777777" \
        -text "No plot open.\nPick one above to add it as a tab."

    ::mdance::plots::sync_shared_bar

    # Row 0: core plots
    ttk::button $plotparent.plots.pop -text "Population" \
        -command {::mdance::plots::population_chart $::mdance::results} -state disabled
    ttk::button $plotparent.plots.timeline -text "Timeline" \
        -command {::mdance::plots::timeline_chart $::mdance::results} -state disabled
    ttk::button $plotparent.plots.msd -text "Cluster MSD" \
        -command {::mdance::plots::msd_chart $::mdance::results} -state disabled
    ttk::button $plotparent.plots.dendro -text "Dendrogram" \
        -command {::mdance::plots::dendrogram $::mdance::results} -state disabled
    # No Elbow button here: it lives on each algorithm tab now, where the
    # algorithm it scans is unambiguous. It also used to sit in column 4 of 6
    # and was clipped until the window was resized.
    ttk::button $plotparent.plots.silhouette -text "Silhouette" \
        -command {::mdance::plots::silhouette_plot $::mdance::results} -state disabled

    # Row 1: additional analysis plots
    ttk::button $plotparent.plots.cdist -text "Distances" \
        -command {::mdance::plots::cluster_distance_heatmap $::mdance::results} -state disabled
    ttk::button $plotparent.plots.msdpop -text "MSD/Pop" \
        -command {::mdance::plots::msd_vs_population $::mdance::results} -state disabled
    ttk::button $plotparent.plots.reprmsd -text "Rep. RMSD" \
        -command {::mdance::plots::representative_rmsd_matrix $::mdance::results} -state disabled
    ttk::button $plotparent.plots.trans -text "Transitions" \
        -command {::mdance::plots::transition_heatmap $::mdance::results} -state disabled
    ttk::button $plotparent.plots.residence -text "Residence" \
        -command {::mdance::plots::residence_chart $::mdance::results} -state disabled
    ttk::button $plotparent.plots.isim -text "Similarity" \
        -command ::mdance::gui::run_similarity_analysis -state disabled

    # Six buttons across two rows of five: the old 6-wide grid clipped its last
    # column until the user resized the window.
    set pcol 0
    foreach b {pop timeline msd dendro silhouette cdist msdpop reprmsd trans residence isim} {
        grid $plotparent.plots.$b -row [expr {$pcol / 4}] -column [expr {$pcol % 4}] \
            -padx 3 -pady 2 -sticky ew
        incr pcol
    }
    for {set col 0} {$col < 4} {incr col} {
        grid columnconfigure $plotparent.plots $col -weight 1
    }
}

# fmt_score - format a score for display, tolerating a missing key or a
# non-finite value (NaN / Infinity from a degenerate clustering) instead of
# throwing, which would abort update_results_tab and leave the tab half-built.
proc ::mdance::gui::fmt_score {results key} {
    if {![dict exists $results $key]} { return "n/a" }
    set v [dict get $results $key]
    if {[catch {format "%.4f" $v} out]} { return $v }
    return $out
}

proc ::mdance::gui::update_results_tab {} {
    set parent .mdance.nb.results
    set pf [_plots_frame]
    set results $::mdance::results

    if {$results eq ""} return

    # Update summary labels. Tolerate results/sessions that lack some keys, e.g.
    # a sweep-loaded run without "algorithm" or a degenerate run without scores.
    $parent.summary.v_algo configure -text \
        [expr {[dict exists $results algorithm] ? [dict get $results algorithm] : "-"}]
    $parent.summary.v_nclust configure -text \
        [expr {[dict exists $results nClusters] ? [dict get $results nClusters] : "-"}]
    $parent.summary.v_ch configure -text [fmt_score $results score_calinskiHarabasz]
    $parent.summary.v_db configure -text [fmt_score $results score_daviesBouldin]

    # Populate cluster table
    set tv $parent.table.list.tv
    $tv delete [$tv children {}]

    set sizes [expr {[dict exists $results clusterSizes] ? [dict get $results clusterSizes] : {}}]
    set reps [expr {[dict exists $results representatives] ? [dict get $results representatives] : {}}]
    set nframes [expr {[dict exists $results nFrames] ? [dict get $results nFrames] : 0}]
    # clusterMSD is optional: sessions and sweep-loaded runs can lack it, and an
    # older backend never produced it.
    set msds [expr {[dict exists $results clusterMSD] ? [dict get $results clusterMSD] : {}}]

    for {set i 0} {$i < [llength $sizes]} {incr i} {
        set size [lindex $sizes $i]
        set pct [expr {$nframes > 0 ? [format "%.1f" [expr {100.0 * $size / $nframes}]] : "-"}]
        set af [::mdance::abs_frame $results [lindex $reps $i]]
        set rep [expr {$af < 0 ? "-" : $af}]
        set m [lindex $msds $i]
        if {$m eq "" || ![string is double -strict $m]} {
            set m "n/a"
        } else {
            set m [format "%.4f" $m]
        }
        # The item id IS the cluster index, so a selection maps straight back to
        # a cluster no matter how the rows are currently sorted. Reading the row
        # POSITION instead is what made the old listbox's Go to Representative
        # wrong the moment any ordering changed.
        $tv insert {} end -id $i -values [list $i $size $pct $m $rep]
    }

    # Enable/disable visualization buttons
    if {![winfo exists $pf]} return
    $pf.pop configure -state normal
    $pf.timeline configure -state normal
    $pf.dendro configure -state normal
    $pf.silhouette configure -state normal
    $pf.cdist configure -state normal
    $pf.reprmsd configure -state normal
    $pf.trans configure -state normal
    $pf.residence configure -state normal
    $pf.isim configure -state normal

    if {[dict exists $results clusterMSD]} {
        $pf.msd configure -state normal
        $pf.msdpop configure -state normal
    } else {
        $pf.msd configure -state disabled
        $pf.msdpop configure -state disabled
    }
}

# selected_cluster - The cluster index currently selected in the Results table,
# or "" (having said so) when nothing is. The treeview item id is the cluster
# index, so this is correct under any column sort; the old listbox returned a
# row POSITION, which stopped meaning "cluster N" as soon as rows were reordered.
proc ::mdance::gui::selected_cluster {{quiet 0}} {
    set tv .mdance.nb.results.table.list.tv
    if {![winfo exists $tv]} { return "" }
    set sel [$tv selection]
    if {$sel eq ""} {
        if {!$quiet} {
            tk_messageBox -icon info -title "MDANCE" \
                -message "Select a cluster in the table first."
        }
        return ""
    }
    return [lindex $sel 0]
}

# sort_cluster_table - Sort the Results table by a column. Numeric when every
# cell in the column parses as a number, lexical otherwise (so an "n/a" MSD
# column still sorts sanely); clicking the same heading again reverses it.
proc ::mdance::gui::sort_cluster_table {col} {
    variable cluster_sort_col
    variable cluster_sort_desc
    set tv .mdance.nb.results.table.list.tv
    if {![winfo exists $tv]} return
    if {$col eq $cluster_sort_col} {
        set cluster_sort_desc [expr {!$cluster_sort_desc}]
    } else {
        set cluster_sort_col $col
        set cluster_sort_desc 0
    }
    set rows {}
    set numeric 1
    foreach it [$tv children {}] {
        set v [$tv set $it $col]
        if {![string is double -strict $v]} { set numeric 0 }
        lappend rows [list $v $it]
    }
    set opts [expr {$numeric ? "-real" : "-dictionary"}]
    if {$cluster_sort_desc} {
        set rows [lsort $opts -decreasing -index 0 $rows]
    } else {
        set rows [lsort $opts -index 0 $rows]
    }
    set i 0
    foreach r $rows { $tv move [lindex $r 1] {} $i; incr i }
}

# _overlay_show - Draw $frames as a simultaneous multi-frame overlay, using a
# representation the overlay OWNS so the user's own representations survive.
#
# `mol drawframes` takes a comma-separated frame list (verified against this
# VMD: it accepts "0,5,10", ranges, and reads the spec back), which is what
# makes a genuine side-by-side comparison possible rather than stepping frames.
proc ::mdance::gui::_overlay_show {molid frames what} {
    variable overlay_rep
    variable overlay_molid
    if {[llength $frames] == 0} {
        tk_messageBox -icon info -title "MDANCE" -message "No frames to show."
        return
    }
    # Drop any previous overlay first: two overlays at once are unreadable, and
    # leaking a representation per click would fill the user's rep list.
    clear_overlay 1
    if {[catch {
        mol addrep $molid
        set idx [expr {[molinfo $molid get numreps] - 1}]
        # Remember it by NAME, not by index (see the overlay_rep comment).
        set overlay_rep [mol repname $molid $idx]
        set overlay_molid $molid
        mol modstyle $idx $molid NewCartoon
        mol modcolor $idx $molid ColorID 6
        mol drawframes $molid $idx [join $frames ","]
    } err]} {
        # Never leave a half-built overlay behind that Clear cannot find.
        clear_overlay 1
        tk_messageBox -icon error -title "MDANCE Error" \
            -message "Could not build the overlay: $err"
        return
    }
    set ::mdance::status "Overlay: $what ([llength $frames] frames)"
}

# overlay_index - The overlay representation's CURRENT index, or "" when it no
# longer exists. Always resolved from the repname; never remembered, because
# VMD renumbers representations on every deletion.
proc ::mdance::gui::overlay_index {} {
    variable overlay_rep
    variable overlay_molid
    if {$overlay_rep eq "" || $overlay_molid eq ""} { return "" }
    if {[lsearch -exact [molinfo list] $overlay_molid] < 0} { return "" }
    set idx ""
    # mol repindex returns -1 for a name that is gone; older VMD builds raise.
    if {[catch {mol repindex $overlay_molid $overlay_rep} idx]} { return "" }
    if {![string is integer -strict $idx] || $idx < 0} { return "" }
    return $idx
}

# clear_overlay - Remove the overlay's own representation, if it still exists.
proc ::mdance::gui::clear_overlay {{quiet 0}} {
    variable overlay_rep
    variable overlay_molid
    if {$overlay_rep eq ""} {
        if {!$quiet} {
            tk_messageBox -icon info -title "MDANCE" -message "There is no overlay to clear."
        }
        return
    }
    # Resolve the name to an index HERE. Deleting a remembered index would remove
    # whichever representation had since been renumbered into that slot -- one of
    # the user's own.
    set idx [overlay_index]
    if {$idx ne ""} {
        catch {mol delrep $idx $overlay_molid}
    }
    set overlay_rep ""
    set overlay_molid ""
    if {!$quiet} { set ::mdance::status "Overlay cleared." }
}

# show_cluster_overlay - Overlay the top-N frames of the selected cluster.
proc ::mdance::gui::show_cluster_overlay {} {
    variable overlay_m
    if {![_busy_guard]} return
    if {$::mdance::results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a clustering first."
        return
    }
    if {![_chknum $overlay_m "Number of frames" int 1]} return
    set cluster [selected_cluster]
    if {$cluster eq ""} return
    if {[catch {::mdance::top_frames $::mdance::results $cluster $overlay_m} frames]} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message $frames
        return
    }
    # A cluster can hold fewer frames than were asked for; say so rather than
    # letting the user believe they are looking at N.
    set got [llength $frames]
    if {$got < $overlay_m} {
        set ::mdance::status "Cluster $cluster has only $got frame(s)."
    }
    _overlay_show [dict get $::mdance::results molid] $frames \
        "top $got of cluster $cluster"
}

# show_range_overlay - Overlay explicit frame ranges, for comparing parts of a
# trajectory that clustering did not pick out.
proc ::mdance::gui::show_range_overlay {} {
    variable overlay_ranges
    variable mol_selection
    if {![_busy_guard]} return
    set molid $mol_selection
    if {$molid eq "top"} {
        if {[catch {set molid [molinfo top]}]} {
            tk_messageBox -icon error -title "MDANCE" -message "No molecule loaded."
            return
        }
    }
    if {[catch {::mdance::parse_frame_ranges $overlay_ranges $molid} frames]} {
        tk_messageBox -icon error -title "MDANCE" -message $frames
        return
    }
    _overlay_show $molid $frames "ranges $overlay_ranges"
}

# export_top_frames_dialog - Write the top-N frames of EVERY cluster, with their
# rank, so the selection can be reproduced outside VMD.
proc ::mdance::gui::export_top_frames_dialog {} {
    variable overlay_m
    if {![_busy_guard]} return
    if {$::mdance::results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a clustering first."
        return
    }
    if {![_chknum $overlay_m "Number of frames" int 1]} return
    set f [tk_getSaveFile -title "Export Top Frames" \
        -initialfile "top_frames.csv" \
        -filetypes {{"CSV files" ".csv"} {"All files" "*"}}]
    if {$f eq ""} return
    if {[catch {::mdance::export_top_frames $f $::mdance::results $overlay_m} n]} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message $n
        return
    }
    set ::mdance::status "Wrote $n frame rows to [file tail $f]"
    tk_messageBox -icon info -title "MDANCE" -message "Wrote $n frame row(s) to $f"
}

# Every Results-tab visualization button that needs a result to be present.
# Elbow is deliberately absent: it computes its own runs and works from an empty
# session.
# _plots_frame - where the plot launcher currently lives. It moved to its own
# Figures tab; the fallback keeps the older layout (grid inside Results) working
# for anything that builds the results surface on its own.
proc ::mdance::gui::_plots_frame {} {
    foreach f {.mdance.nb.figures.plots .mdance.nb.results.plots} {
        if {[winfo exists $f]} { return $f }
    }
    return ""
}

proc ::mdance::gui::_result_plot_buttons {} {
    return {pop timeline msd dendro silhouette cdist msdpop reprmsd trans residence isim}
}

# clear_results - Purge the current clustering result and everything derived
# from it, so a fresh run starts from a clean session.
#
# "Everything derived" is the point: a plot window keeps its own copy of the
# results dict in the redraw registry, and PRIME / Frame Tools cache frame
# indices against the molecule they were computed from. Clearing only
# ::mdance::results would leave those alive, still displaying and exporting
# numbers from a result the user believes is gone.
proc ::mdance::gui::clear_results {} {
    variable prime_results
    variable prime_molid
    variable ft_frames
    variable ft_molid
    variable sweep_full
    variable sweep_rows
    variable cluster_sort_col
    variable cluster_sort_desc

    # A run in flight is about to write ::mdance::results, and the sweep's
    # cleanup deletes registered temp files; purging underneath either is how
    # you get a half-populated table and a deleted input CSV.
    if {![_busy_guard]} return
    if {$::mdance::results eq "" && [array size sweep_rows] == 0
        && $prime_results eq "" && $ft_frames eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "There are no results to clear."
        return
    }
    set ans [tk_messageBox -icon question -type okcancel -title "MDANCE" \
        -message "Clear the current clustering result, the sweep table, the PRIME and Frame Tools selections, and close the plot windows?\n\nExported files and saved sessions are not affected. Any cluster colouring already applied to the molecule is left as it is."]
    if {$ans ne "ok"} return

    # Close the plots first: each <Destroy> handler releases that plot's cached
    # results dict and cancels its pending resize redraw. They are notebook tabs
    # now, so this goes through the plots module rather than sweeping the
    # toplevel list -- but close_all_figures still sweeps it, for a session that
    # opened plots before the window existed.
    ::mdance::plots::close_all_figures
    catch {destroy .mdance_elbow_cfg}

    set ::mdance::results ""
    array unset sweep_full
    array set sweep_full {}
    array unset sweep_rows
    array set sweep_rows {}
    set prime_results ""
    set prime_molid ""
    set ft_frames ""
    set ft_molid ""
    set cluster_sort_col ""
    set cluster_sort_desc 0
    clear_overlay 1

    # Reset the Results tab display.
    set parent .mdance.nb.results
    set pf [_plots_frame]
    if {[winfo exists $parent]} {
        catch {$parent.table.list.tv delete [$parent.table.list.tv children {}]}
        foreach tag {algo nclust ch db} {
            catch {$parent.summary.v_$tag configure -text "-"}
        }
        foreach b [_result_plot_buttons] {
            catch {$pf.$b configure -state disabled}
        }
    }
    # And the other tabs' result views.
    catch {.mdance.nb.sweep.res.tv delete [.mdance.nb.sweep.res.tv children {}]}
    catch {.mdance.nb.prime.res.tv delete [.mdance.nb.prime.res.tv children {}]}
    set ::mdance::status "Results cleared."
}

proc ::mdance::gui::goto_selected_rep {} {
    set cluster_idx [selected_cluster]
    if {$cluster_idx eq ""} return
    if {[catch {::mdance::goto_representative $cluster_idx} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
    }
}

proc ::mdance::gui::color_by_cluster {} {
    if {[catch {::mdance::apply_cluster_colors} res]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $res
        return
    }
    if {$res > 0} {
        tk_messageBox -icon warning -title "MDANCE" -message \
            "$res sample(s) map to frames beyond the current trajectory and were left uncoloured. Was the molecule reloaded since the analysis?"
    }
}

proc ::mdance::gui::run_similarity_analysis {} {
    if {![_busy_guard]} return
    set results $::mdance::results
    if {$results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run clustering first."
        return
    }
    if {![dict exists $results molid] || ![dict exists $results atomsel]} {
        tk_messageBox -icon warning -title "MDANCE" -message "No coordinate data available."
        return
    }
    set molid [dict get $results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        tk_messageBox -icon error -title "MDANCE" -message "Source molecule $molid is no longer loaded."
        return
    }
    set sel_text [dict get $results atomsel]
    set labels [dict get $results labels]

    # Frame map: explicit list when present, else identity (full-trajectory run)
    if {[dict exists $results frames]} {
        set frames [dict get $results frames]
    } else {
        set frames {}
        for {set i 0} {$i < [llength $labels]} {incr i} { lappend frames $i }
    }

    set ::mdance::status "Computing extended-similarity (iSIM) analysis..."
    update idletasks
    if {[catch {set analysis [::mdance::run_analysis $molid $sel_text $frames $labels MSD]} err]} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message "Similarity analysis failed: $err"
        return
    }
    set ::mdance::status "Ready"
    ::mdance::plots::similarity_chart $results $analysis
}

# --- PRIME Tab ---
proc ::mdance::gui::build_prime_tab {parent} {
    ttk::label $parent.banner -justify left -wraplength 500 -text \
        "PRIME predicts the representative / \"native\"-like frame of an already-clustered ensemble using extended (n-ary) similarity. Run a clustering algorithm first, then run PRIME here."
    pack $parent.banner -fill x -padx 10 -pady {10 4}

    ttk::labelframe $parent.opts -text "Options" -padding 10
    pack $parent.opts -fill x -padx 10 -pady {4 0}

    ttk::label $parent.opts.lm -text "Similarity:"
    ttk::combobox $parent.opts.metric -textvariable ::mdance::gui::prime_metric \
        -values {RR SM} -state readonly -width 8
    grid $parent.opts.lm -row 0 -column 0 -sticky w -padx {0 10} -pady 3
    grid $parent.opts.metric -row 0 -column 1 -sticky w -pady 3

    ttk::label $parent.opts.lt -text "Trim fraction:"
    ttk::spinbox $parent.opts.trim -textvariable ::mdance::gui::prime_trim \
        -from 0.0 -to 0.5 -increment 0.05 -width 8
    grid $parent.opts.lt -row 1 -column 0 -sticky w -padx {0 10} -pady 3
    grid $parent.opts.trim -row 1 -column 1 -sticky w -pady 3

    ttk::checkbutton $parent.opts.w -text "Weight by cluster population" \
        -variable ::mdance::gui::prime_weighted
    grid $parent.opts.w -row 2 -column 0 -columnspan 2 -sticky w -pady 3

    ttk::frame $parent.run -padding {10 8}
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Predict Representative Frame" \
        -command ::mdance::gui::run_prime_analysis
    pack $parent.run.btn -side left

    ttk::labelframe $parent.res -text "Predicted Frames" -padding 10
    pack $parent.res -fill both -expand 1 -padx 10 -pady {6 10}
    ttk::treeview $parent.res.tv -columns {method frame kind} -show headings -height 8 \
        -style Mdance.Treeview
    foreach {c t w} {method Method 150 frame "VMD frame" 90 kind Type 130} {
        $parent.res.tv heading $c -text $t
        $parent.res.tv column $c -width $w -anchor center
    }
    $parent.res.tv tag configure prediction -background "#d6f5d6"
    pack $parent.res.tv -fill both -expand 1
    ttk::button $parent.res.goto -text "Go to Selected Frame" \
        -command ::mdance::gui::goto_prime_frame
    pack $parent.res.goto -side left -pady {6 0}
    _citation_footer $parent [_refs_none "PRIME"]
}

proc ::mdance::gui::run_prime_analysis {} {
    variable prime_metric
    variable prime_trim
    variable prime_weighted
    variable prime_results
    variable prime_molid

    if {![_busy_guard]} return
    # prime_trim is passed straight through to the backend as --trim-frac.
    if {![_chknum $prime_trim "Trim fraction" double 0]} return
    set results $::mdance::results
    if {$results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a clustering algorithm first."
        return
    }
    if {![dict exists $results molid] || ![dict exists $results atomsel]} {
        tk_messageBox -icon warning -title "MDANCE" -message "No coordinate data available."
        return
    }
    set molid [dict get $results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        tk_messageBox -icon error -title "MDANCE" -message "Source molecule $molid is no longer loaded."
        return
    }
    set sel_text [dict get $results atomsel]
    set labels [dict get $results labels]
    if {[dict exists $results frames]} {
        set frames [dict get $results frames]
    } else {
        set frames {}
        for {set i 0} {$i < [llength $labels]} {incr i} { lappend frames $i }
    }

    set ::mdance::status "Running PRIME analysis..."
    update idletasks
    if {[catch {set prime_results [::mdance::run_prime $molid $sel_text $frames $labels \
            $prime_metric $prime_trim $prime_weighted]} err]} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message "PRIME failed: $err"
        return
    }
    set ::mdance::status "Ready"

    # Record the molecule only once the run SUCCEEDED, so prime_molid always
    # describes the run whose rows are actually on screen -- a failed attempt
    # against a different molecule must not repoint the existing table.
    set prime_molid $molid

    set tv .mdance.nb.prime.res.tv
    $tv delete [$tv children {}]
    foreach {key label kind} {
        medoidAll "Medoid (all frames)" baseline
        medoidC0 "Medoid (c0)" baseline
        medoidC0Trimmed "Medoid (c0 trimmed)" baseline
        pairwise "Pairwise" "PRIME prediction"
        union "Union" "PRIME prediction"
        medoid "Medoid" "PRIME prediction"
        outlier "Outlier" "PRIME prediction"
    } {
        set sample [expr {[dict exists $prime_results $key] ? [dict get $prime_results $key] : -1}]
        set af [::mdance::abs_frame $results $sample]
        set fr [expr {$af < 0 ? "-" : $af}]
        set tag [expr {$kind eq "PRIME prediction" ? "prediction" : ""}]
        $tv insert {} end -values [list $label $fr $kind] -tags $tag
    }
}

proc ::mdance::gui::goto_prime_frame {} {
    variable prime_molid
    set tv .mdance.nb.prime.res.tv
    set sel [$tv selection]
    if {$sel eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Select a row first."
        return
    }
    set fr [$tv set [lindex $sel 0] frame]
    if {$fr eq "-" || ![string is integer -strict $fr]} {
        tk_messageBox -icon warning -title "MDANCE" -message "That method has no valid frame."
        return
    }
    # Validate against the run that PRODUCED this table. ::mdance::results may
    # since have been replaced (a new clustering, or a loaded session), in which
    # case its molid has nothing to do with the frames shown here.
    set molid $prime_molid
    if {$molid eq "" || [lsearch -exact [molinfo list] $molid] < 0} {
        tk_messageBox -icon error -title "MDANCE" \
            -message "The molecule these predictions were computed from (molid $molid) is no longer loaded. Re-run PRIME."
        return
    }
    set total [molinfo $molid get numframes]
    if {$fr < 0 || $fr >= $total} {
        tk_messageBox -icon error -title "MDANCE" \
            -message "Frame $fr is outside the current trajectory ($total frames). Re-run PRIME."
        return
    }
    animate goto $fr
    display update
}

proc ::mdance::gui::export_labels_dialog {} {
    if {![_busy_guard]} return
    set f [tk_getSaveFile -defaultextension ".csv" \
        -filetypes {{"CSV files" ".csv"} {"All files" "*"}} \
        -title "Export Cluster Labels"]
    if {$f ne ""} {
        if {[catch {::mdance::export_labels $f} err]} {
            tk_messageBox -icon error -title "MDANCE Error" -message $err
        } else {
            tk_messageBox -icon info -title "MDANCE" -message "Labels exported to $f"
        }
    }
}

# Infer file format from extension: .dcd -> dcd, otherwise pdb
proc ::mdance::gui::_fmt_from_path {path} {
    return [expr {[string equal -nocase [file extension $path] ".dcd"] ? "dcd" : "pdb"}]
}

proc ::mdance::gui::export_reps_dialog {} {
    if {![_busy_guard]} return
    if {$::mdance::results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run clustering first."
        return
    }
    set f [tk_getSaveFile -defaultextension ".pdb" \
        -filetypes {{"PDB structure" ".pdb"} {"DCD trajectory" ".dcd"} {"All files" "*"}} \
        -title "Export Representative Frames" -initialfile "representatives.pdb"]
    if {$f eq ""} return

    set fmt [_fmt_from_path $f]
    if {$fmt eq "dcd"} {
        # The companion topology is derived from $f, so the user never saw it in
        # the save dialog and never agreed to replace it.
        if {![_confirm_overwrite [list "[file rootname $f].pdb"] \
                "Exporting as DCD also writes a companion .pdb topology, which"]} return
    }
    if {[catch {set n [::mdance::export_representatives $f $fmt "all"]} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
        return
    }
    set msg "Wrote $n representative frame(s) to $f"
    if {$fmt eq "dcd"} {
        append msg "\n\nA companion [file tail [file rootname $f]].pdb topology was written alongside (a DCD has no topology of its own)."
    }
    tk_messageBox -icon info -title "MDANCE" -message $msg
}

proc ::mdance::gui::export_clusters_dialog {} {
    if {![_busy_guard]} return
    if {$::mdance::results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run clustering first."
        return
    }
    set dir [tk_chooseDirectory -title "Choose a directory for per-cluster files"]
    if {$dir eq ""} return

    # Ask format via a simple yes/no (PDB is the safe default)
    set use_dcd [tk_messageBox -icon question -type yesno -title "MDANCE" \
        -message "Write per-cluster trajectories as DCD?\n\nYes = DCD (+ companion .pdb topology)\nNo = multi-model PDB"]
    set fmt [expr {$use_dcd eq "yes" ? "dcd" : "pdb"}]

    # Names here are generated (cluster_<id>.<fmt>), so nothing in the directory
    # chooser told the user what is about to be replaced.
    set targets {}
    set nclust 0
    catch {set nclust [dict get $::mdance::results nClusters]}
    for {set c 0} {$c < $nclust} {incr c} {
        lappend targets [file join $dir "cluster_$c.$fmt"]
        if {$fmt eq "dcd"} { lappend targets [file join $dir "cluster_$c.pdb"] }
    }
    if {![_confirm_overwrite $targets "Writing per-cluster files"]} return

    if {[catch {set n [::mdance::export_clusters_split $dir $fmt "all"]} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
        return
    }
    tk_messageBox -icon info -title "MDANCE" \
        -message "Wrote $n per-cluster file(s) (cluster_<id>.$fmt) to $dir"
}

proc ::mdance::gui::frame_tools_dialog {} {
    # Child toplevel of the main window so it is destroyed when .mdance closes
    # (avoids an orphaned dialog whose buttons reference a torn-down GUI).
    set w .mdance.ftools
    if {[winfo exists $w]} { wm deiconify $w; raise $w; return }
    toplevel $w
    wm title $w "MDANCE Frame Tools"
    wm geometry $w 420x460

    ttk::labelframe $w.p -text "Selection" -padding 10
    pack $w.p -fill x -padx 10 -pady 10

    ttk::label $w.p.lm -text "Method:"
    ttk::combobox $w.p.method -textvariable ::mdance::gui::ft_method -state readonly -width 14 \
        -values {diversity outliers repsample medoid outlier}
    grid $w.p.lm -row 0 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.p.method -row 0 -column 1 -sticky w -pady 3

    ttk::label $w.p.lmet -text "Metric:"
    ttk::combobox $w.p.metric -textvariable ::mdance::gui::ft_metric -state readonly -width 14 \
        -values {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
    grid $w.p.lmet -row 1 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.p.metric -row 1 -column 1 -sticky w -pady 3
    # This dialog is created on demand, so its metric selector is registered
    # here rather than in create_window's sweep of the main window.
    _register_metric_combo $w.p.metric
    apply_metric_lock

    ttk::label $w.p.lparam -text "Param:"
    ttk::entry $w.p.param -textvariable ::mdance::gui::ft_param -width 10
    grid $w.p.lparam -row 2 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.p.param -row 2 -column 1 -sticky w -pady 3

    ttk::label $w.p.lbins -text "Bins (repsample):"
    ttk::spinbox $w.p.nbins -textvariable ::mdance::gui::ft_nbins -from 2 -to 100 -width 10
    grid $w.p.lbins -row 3 -column 0 -sticky w -padx {0 10} -pady 3
    grid $w.p.nbins -row 3 -column 1 -sticky w -pady 3

    ttk::label $w.p.note -justify left -wraplength 380 -foreground "#555555" -text \
        "diversity: param = percentage of frames (1-100). outliers / repsample: param = a count (>=1) or fraction (0-1). medoid / outlier: a single frame (param ignored). Uses the Setup tab's molecule, atom selection and frame range."
    grid $w.p.note -row 4 -column 0 -columnspan 2 -sticky w -pady {6 0}

    ttk::frame $w.run -padding {10 0}
    pack $w.run -fill x -padx 10
    ttk::button $w.run.go -text "Select" -command ::mdance::gui::frame_tools_run
    ttk::label $w.run.count -text "" -anchor w
    pack $w.run.go -side left
    pack $w.run.count -side left -padx 10 -fill x -expand 1

    ttk::labelframe $w.res -text "Selected Frames (double-click to go to a frame)" -padding 10
    pack $w.res -fill both -expand 1 -padx 10 -pady 10
    listbox $w.res.lb -height 8 -yscrollcommand [list $w.res.sb set]
    ttk::scrollbar $w.res.sb -orient vertical -command [list $w.res.lb yview]
    pack $w.res.sb -side right -fill y
    pack $w.res.lb -side left -fill both -expand 1
    bind $w.res.lb <Double-1> {
        set s [%W curselection]
        if {$s ne ""} {
            set fr [%W get [lindex $s 0]]
            catch {animate goto $fr; display update}
        }
    }

    ttk::frame $w.btns -padding 10
    pack $w.btns -fill x -padx 10 -pady {0 10}
    ttk::button $w.btns.export -text "Export Selected..." -command ::mdance::gui::frame_tools_export
    ttk::button $w.btns.close -text "Close" -command [list destroy $w]
    pack $w.btns.export -side left -padx {0 6}
    pack $w.btns.close -side left
}

proc ::mdance::gui::frame_tools_run {} {
    variable mol_selection
    variable atom_selection
    variable frame_first
    variable frame_last
    variable frame_stride
    variable ft_method
    variable ft_metric
    variable ft_param
    variable ft_nbins
    variable ft_frames
    variable ft_molid

    if {![_busy_guard]} return
    if {![_chknum $ft_param "Param" double]} return
    if {![_chknum $ft_nbins "Bins" int 2]} return

    set molid $mol_selection
    if {$molid eq "top"} {
        if {[catch {set molid [molinfo top]}]} {
            tk_messageBox -icon error -title "MDANCE" -message "No molecule loaded."
            return
        }
    }
    if {[catch {
        set frames [::mdance::frame_list $molid $frame_first $frame_last $frame_stride]
        set ::mdance::status "Frame Tools: running $ft_method..."
        update idletasks
        set samples [::mdance::run_select $molid $atom_selection $frames \
            $ft_method $ft_metric $ft_param $ft_nbins]
        set ::mdance::status "Ready"
    } err]} {
        set ::mdance::status "Ready"
        tk_messageBox -icon error -title "MDANCE Error" -message "Frame selection failed: $err"
        return
    }

    set ft_frames {}
    set ft_molid $molid
    foreach si $samples {
        set af [lindex $frames $si]
        if {$af ne ""} { lappend ft_frames $af }
    }

    set lb .mdance.ftools.res.lb
    $lb delete 0 end
    foreach f $ft_frames { $lb insert end $f }
    .mdance.ftools.run.count configure -text "[llength $ft_frames] frame(s) selected"
}

proc ::mdance::gui::frame_tools_export {} {
    variable ft_frames
    variable ft_molid
    if {![_busy_guard]} return
    if {$ft_frames eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a selection first."
        return
    }
    # Use the molecule the frames were COMPUTED against, not whatever "top" now
    # resolves to: re-resolving here wrote frame indices from one molecule out of
    # a different one as soon as the user loaded or reordered anything.
    set molid $ft_molid
    if {$molid eq "" || [lsearch -exact [molinfo list] $molid] < 0} {
        tk_messageBox -icon error -title "MDANCE" \
            -message "The molecule these frames were selected from (molid $molid) is no longer loaded. Re-run the selection."
        return
    }
    # Same molecule, but it may have been re-read with fewer frames since the
    # selection ran. write_frames_to_file would then export whatever VMD clamps
    # those indices to, with no indication anything was wrong.
    set total [molinfo $molid get numframes]
    foreach af $ft_frames {
        if {$af < 0 || $af >= $total} {
            tk_messageBox -icon error -title "MDANCE" \
                -message "Frame $af is outside the current trajectory ($total frames). Re-run the selection."
            return
        }
    }
    set f [tk_getSaveFile -defaultextension ".pdb" \
        -filetypes {{"PDB structure" ".pdb"} {"DCD trajectory" ".dcd"} {"All files" "*"}} \
        -title "Export Selected Frames" -initialfile "selected_frames.pdb"]
    if {$f eq ""} return
    set fmt [_fmt_from_path $f]
    if {[catch {::mdance::write_frames_to_file $molid "all" $ft_frames $f $fmt} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
        return
    }
    tk_messageBox -icon info -title "MDANCE" -message "Wrote [llength $ft_frames] frame(s) to $f"
}

proc ::mdance::gui::save_session_dialog {} {
    # In CLI mode a run parks in a live event loop, so these menu items stay
    # clickable mid-run; saving would then serialize a half-updated results dict.
    if {![_busy_guard]} return
    if {$::mdance::results eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run clustering first."
        return
    }
    set f [tk_getSaveFile -defaultextension ".mdance" \
        -filetypes {{"MDANCE session" ".mdance"} {"All files" "*"}} \
        -title "Save Session" -initialfile "session.mdance"]
    if {$f eq ""} return
    if {[catch {::mdance::save_session $f} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
    } else {
        tk_messageBox -icon info -title "MDANCE" -message "Session saved to $f"
    }
}

proc ::mdance::gui::load_session_dialog {} {
    # Loading overwrites ::mdance::results, which an in-flight run is about to
    # write to as well -- the loaded session would be silently clobbered (or
    # worse, half-replaced) when the run finishes.
    if {![_busy_guard]} return
    set f [tk_getOpenFile \
        -filetypes {{"MDANCE session" ".mdance"} {"All files" "*"}} \
        -title "Load Session"]
    if {$f eq ""} return
    if {[catch {set live [::mdance::load_session $f]} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
        return
    }
    ::mdance::gui::show_view results
    if {[catch {::mdance::gui::update_results_tab} e]} {
        tk_messageBox -icon error -title "MDANCE Error" -message "Could not display results: $e"
    }
    set ::mdance::status "Session loaded"
    if {!$live} {
        set mid [expr {[dict exists $::mdance::results molid] ? [dict get $::mdance::results molid] : "?"}]
        tk_messageBox -icon info -title "MDANCE" -message \
            "Session loaded. The molecule it was computed from (molid $mid) is not currently loaded, so scores, the cluster table, and the population / timeline / MSD / transition / residence / dendrogram plots work from stored data. Color-by-Cluster, Go-to-Representative, structure export, and the centroid / silhouette / RMSD / similarity views need that molecule loaded."
    }
}
