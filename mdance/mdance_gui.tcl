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

    # KMeans
    variable km_nclusters 10
    variable km_metric "MSD"
    variable km_kinit "CompSim"
    variable km_percentage 10

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

    # Frame Tools (diversity / outlier / representative selection)
    variable ft_method "diversity"
    variable ft_metric "MSD"
    variable ft_param 10
    variable ft_nbins 10
    variable ft_frames ""

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
    variable helm_labels_source "auto"
    variable helm_pre_k 50
    variable helm_labels_file ""

    # CLI binary display
    variable cli_display_path ""

    # Display settings
    variable app_font_size 10
}

proc ::mdance::gui::create_window {} {
    set w .mdance
    catch {destroy $w}
    toplevel $w
    wm title $w "MDANCE Clustering"
    wm geometry $w 560x720
    wm resizable $w 1 1

    # Create notebook (tabbed interface)
    ttk::notebook $w.nb
    pack $w.nb -fill both -expand 1 -padx 5 -pady 5

    # Create tabs
    set setup_tab [ttk::frame $w.nb.setup]
    set km_tab [ttk::frame $w.nb.kmeans]
    set div_tab [ttk::frame $w.nb.divine]
    set helm_tab [ttk::frame $w.nb.helm]
    set eq_tab [ttk::frame $w.nb.equal]
    set sweep_tab [ttk::frame $w.nb.sweep]
    set prime_tab [ttk::frame $w.nb.prime]
    set res_tab [ttk::frame $w.nb.results]

    $w.nb add $setup_tab -text "Setup"
    $w.nb add $km_tab -text "KMeans"
    $w.nb add $div_tab -text "DIVINE"
    $w.nb add $helm_tab -text "HELM"
    $w.nb add $eq_tab -text "eQUAL"
    $w.nb add $sweep_tab -text "Sweep"
    $w.nb add $res_tab -text "Results"
    $w.nb add $prime_tab -text "PRIME"

    build_setup_tab $setup_tab
    build_kmeans_tab $km_tab
    build_divine_tab $div_tab
    build_helm_tab $helm_tab
    build_equal_tab $eq_tab
    build_sweep_tab $sweep_tab
    build_results_tab $res_tab
    build_prime_tab $prime_tab

    # Status bar (Cancel + progress bar are shown only while a run is active)
    ttk::frame $w.status
    pack $w.status -fill x -padx 5 -pady {0 5}
    ttk::button $w.status.cancel -text "Cancel" -command ::mdance::request_cancel -state disabled
    ttk::progressbar $w.status.pb -mode indeterminate -length 120
    ttk::label $w.status.label -textvariable ::mdance::status -anchor w
    pack $w.status.label -side left -fill x -expand 1

    return $w
}

# busy_start / busy_stop - show/hide the status-bar progress bar and Cancel
# button around a long-running operation. cancellable=0 disables Cancel (e.g.
# in-process library-mode runs, which cannot be interrupted).
proc ::mdance::gui::busy_start {msg cancellable} {
    set ::mdance::status $msg
    set s .mdance.status
    if {![winfo exists $s.pb]} return
    pack $s.pb -side right -padx {4 0}
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
    catch {pack forget $s.pb}
    catch {$s.cancel configure -state disabled}
    catch {pack forget $s.cancel}
}

# run_guarded - shared entry for single clustering runs: prevents concurrent
# runs, shows progress/cancel, runs, and refreshes the Results tab.
proc ::mdance::gui::run_guarded {algorithm params} {
    if {$::mdance::running} {
        tk_messageBox -icon info -title "MDANCE" \
            -message "A clustering run is already in progress."
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
    .mdance.nb select .mdance.nb.results
    if {[catch {update_results_tab} e]} {
        tk_messageBox -icon error -title "MDANCE Error" -message "Could not display results: $e"
    }
}

# _busy_guard - reject a secondary backend operation (PRIME / Similarity / Frame
# Tools / Export) while a clustering run is in flight. In CLI mode the run parks
# in a live event loop (vwait), so these buttons would otherwise fire mid-run and
# read/clobber the shared ::mdance::results / ::mdance::status. Returns 1 if free.
proc ::mdance::gui::_busy_guard {} {
    if {$::mdance::running} {
        tk_messageBox -icon info -title "MDANCE" \
            -message "A clustering run is in progress. Please wait for it to finish."
        return 0
    }
    return 1
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

    ttk::label $parent.mol.mol_label -text "Molecule ID:"
    ttk::entry $parent.mol.mol_entry -textvariable ::mdance::gui::mol_selection -width 20
    grid $parent.mol.mol_label -row 0 -column 0 -sticky w -padx {0 10}
    grid $parent.mol.mol_entry -row 0 -column 1 -sticky ew

    ttk::label $parent.mol.sel_label -text "Atom selection:"
    ttk::entry $parent.mol.sel_entry -textvariable ::mdance::gui::atom_selection -width 40
    grid $parent.mol.sel_label -row 1 -column 0 -sticky w -padx {0 10} -pady {10 0}
    grid $parent.mol.sel_entry -row 1 -column 1 -sticky ew -pady {10 0}

    grid columnconfigure $parent.mol 1 -weight 1

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
    ttk::entry $parent.cli.path_entry -textvariable ::mdance::gui::cli_display_path -width 40 -state readonly
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

    # Display settings
    ttk::labelframe $parent.display -text "Display Settings" -padding 10
    pack $parent.display -fill x -padx 10 -pady {10 0}

    ttk::label $parent.display.afl -text "App font size:"
    ttk::spinbox $parent.display.afs -from 8 -to 18 -width 4 -increment 1 \
        -textvariable ::mdance::gui::app_font_size \
        -command ::mdance::gui::apply_app_font
    bind $parent.display.afs <Return> ::mdance::gui::apply_app_font

    ttk::label $parent.display.pfl -text "Plot font size:"
    ttk::spinbox $parent.display.pfs -from 6 -to 24 -width 4 -increment 1 \
        -textvariable ::mdance::plots::plot_font_size

    grid $parent.display.afl -row 0 -column 0 -sticky w -padx {0 10}
    grid $parent.display.afs -row 0 -column 1 -sticky w
    grid $parent.display.pfl -row 0 -column 2 -sticky w -padx {20 10}
    grid $parent.display.pfs -row 0 -column 3 -sticky w

    # Help text
    ttk::labelframe $parent.help -text "Quick Start" -padding 10
    pack $parent.help -fill both -expand 1 -padx 10 -pady 10

    set help_text "1. Load a molecule with trajectory in VMD\n\
2. Set the molecule ID (or 'top' for current)\n\
3. Set atom selection (e.g., 'protein and name CA')\n\
4. Click Preview to verify\n\
5. Choose an algorithm tab and run clustering\n\
6. View results in the Results tab\n\n\
Algorithms:\n\
  KMeans NANI - Fast partitional clustering\n\
  DIVINE - Divisive hierarchical (top-down)\n\
  HELM - Agglomerative hierarchical (bottom-up)"

    ttk::label $parent.help.text -text $help_text -justify left -wraplength 450
    pack $parent.help.text -fill both -expand 1
}

proc ::mdance::gui::apply_app_font {} {
    variable app_font_size
    font configure TkDefaultFont -size $app_font_size
}

# add_range - Inject the Setup-tab first/last/stride selection into a params dict
proc ::mdance::gui::add_range {paramsVar} {
    upvar 1 $paramsVar params
    variable frame_first
    variable frame_last
    variable frame_stride
    dict set params first $frame_first
    dict set params last $frame_last
    dict set params stride $frame_stride
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
}

proc ::mdance::gui::run_kmeans {} {
    variable mol_selection
    variable atom_selection
    variable km_nclusters
    variable km_metric
    variable km_kinit
    variable km_percentage

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
    add_range params

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

    if {![_chknum $div_threshold "DIVINE threshold" double 0]} return

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
    add_range params

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

    # Trim options
    ttk::labelframe $parent.trim -text "Trim Options" -padding 10
    pack $parent.trim -fill x -padx 10 -pady 5

    ttk::checkbutton $parent.trim.enable -text "Enable trimming" \
        -variable ::mdance::gui::helm_trim_start
    grid $parent.trim.enable -row 0 -column 0 -columnspan 2 -sticky w -pady 3

    set trow 1
    foreach {label var} {
        "Min samples:" helm_min_samples
        "Trim value:" helm_trim_val
        "Trim K:" helm_trim_k
    } {
        ttk::label $parent.trim.l$trow -text $label
        ttk::entry $parent.trim.w$trow -textvariable ::mdance::gui::$var -width 10
        grid $parent.trim.l$trow -row $trow -column 0 -sticky w -padx {0 10} -pady 3
        grid $parent.trim.w$trow -row $trow -column 1 -sticky w -pady 3
        incr trow
    }

    # Initial labels source
    ttk::labelframe $parent.labels -text "Initial Labels" -padding 10
    pack $parent.labels -fill x -padx 10 -pady 5

    ttk::radiobutton $parent.labels.auto -text "Auto pre-cluster with KMeans" \
        -variable ::mdance::gui::helm_labels_source -value "auto"
    ttk::label $parent.labels.lprek -text "Pre-cluster K:"
    ttk::spinbox $parent.labels.prek -textvariable ::mdance::gui::helm_pre_k \
        -from 5 -to 500 -width 8
    grid $parent.labels.auto -row 0 -column 0 -columnspan 2 -sticky w -pady 3
    grid $parent.labels.lprek -row 1 -column 0 -sticky w -padx {20 10} -pady 3
    grid $parent.labels.prek -row 1 -column 1 -sticky w -pady 3

    ttk::radiobutton $parent.labels.file -text "Load from file:" \
        -variable ::mdance::gui::helm_labels_source -value "file"
    ttk::entry $parent.labels.fentry -textvariable ::mdance::gui::helm_labels_file -width 30
    ttk::button $parent.labels.browse -text "Browse..." -command {
        set f [tk_getOpenFile -filetypes {{"CSV files" ".csv"} {"All files" "*"}}]
        if {$f ne ""} { set ::mdance::gui::helm_labels_file $f }
    }
    grid $parent.labels.file -row 2 -column 0 -sticky w -pady 3
    grid $parent.labels.fentry -row 2 -column 1 -sticky ew -pady 3
    grid $parent.labels.browse -row 2 -column 2 -sticky w -padx 5 -pady 3
    grid columnconfigure $parent.labels 1 -weight 1

    ttk::frame $parent.run -padding 10
    pack $parent.run -fill x -padx 10
    ttk::button $parent.run.btn -text "Run HELM" -command ::mdance::gui::run_helm
    pack $parent.run.btn -side left
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
    variable helm_labels_source
    variable helm_pre_k
    variable helm_labels_file

    set molid $mol_selection
    if {$molid eq "top"} {
        set molid [molinfo top]
    }

    set params [dict create \
        molid $molid \
        atomsel $atom_selection \
        metric $helm_metric \
        merge-scheme $helm_merge \
        min-samples $helm_min_samples \
        trim-val $helm_trim_val \
        trim-k $helm_trim_k]
    add_range params

    if {$helm_trim_start} {
        dict set params trim-start 1
    }

    # Set stopping criterion
    if {$helm_stop_mode eq "nclusters"} {
        dict set params nclusters $helm_nclusters
        dict set params eps -1
    } else {
        dict set params nclusters 0
        dict set params eps $helm_eps
    }

    # Set initial labels
    if {$helm_labels_source eq "file" && $helm_labels_file ne ""} {
        dict set params initial-labels $helm_labels_file
    } else {
        dict set params pre-k $helm_pre_k
    }

    # Validate numeric inputs (also keeps any redirection metacharacter out of
    # the backend command line)
    if {$helm_stop_mode eq "eps"} {
        if {![_chknum $helm_eps "HELM epsilon" double]} return
    } else {
        if {![_chknum $helm_nclusters "Number of clusters" int 2]} return
    }
    if {$helm_trim_start} {
        if {![_chknum $helm_min_samples "Min samples" double 0]} return
        if {![_chknum $helm_trim_val "Trim value" double]} return
        if {![_chknum $helm_trim_k "Trim K" int 0]} return
    }
    if {$helm_labels_source ne "file" || $helm_labels_file eq ""} {
        if {![_chknum $helm_pre_k "Pre-cluster K" int 2]} return
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
    add_range params

    run_guarded equal $params
}

# --- Results Tab ---
proc ::mdance::gui::build_results_tab {parent} {
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

    # Header
    ttk::frame $parent.table.header
    pack $parent.table.header -fill x
    foreach {col w} {ID 40 Size 60 "%" 60 "Rep. Frame" 80} {
        ttk::label $parent.table.header.h_[string map {" " _ "%" pct . _} $col] \
            -text $col -width [expr {$w / 8}] -anchor w -font TkHeadingFont
        pack $parent.table.header.h_[string map {" " _ "%" pct . _} $col] -side left -padx 3
    }

    # Scrollable listbox area
    ttk::frame $parent.table.list
    pack $parent.table.list -fill both -expand 1
    listbox $parent.table.list.lb -height 10 -font TkFixedFont \
        -yscrollcommand [list $parent.table.list.sb set]
    ttk::scrollbar $parent.table.list.sb -orient vertical \
        -command [list $parent.table.list.lb yview]
    pack $parent.table.list.sb -side right -fill y
    pack $parent.table.list.lb -side left -fill both -expand 1

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

    grid $parent.actions.goto   -row 0 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.color  -row 0 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.export -row 0 -column 2 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.reps   -row 1 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.split  -row 1 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.save   -row 2 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.actions.load   -row 2 -column 1 -padx 3 -pady 2 -sticky ew
    for {set col 0} {$col < 3} {incr col} {
        grid columnconfigure $parent.actions $col -weight 1
    }

    # Visualization buttons
    ttk::labelframe $parent.plots -text "Visualizations" -padding 10
    pack $parent.plots -fill x -padx 10 -pady 5

    # Row 0: core plots
    ttk::button $parent.plots.pop -text "Population" \
        -command {::mdance::plots::population_chart $::mdance::results} -state disabled
    ttk::button $parent.plots.timeline -text "Timeline" \
        -command {::mdance::plots::timeline_chart $::mdance::results} -state disabled
    ttk::button $parent.plots.msd -text "Cluster MSD" \
        -command {::mdance::plots::msd_chart $::mdance::results} -state disabled
    ttk::button $parent.plots.dendro -text "Dendrogram" \
        -command {::mdance::plots::dendrogram $::mdance::results} -state disabled
    ttk::button $parent.plots.elbow -text "Elbow Plot..." \
        -command {::mdance::plots::elbow_plot}
    ttk::button $parent.plots.silhouette -text "Silhouette" \
        -command {::mdance::plots::silhouette_plot $::mdance::results} -state disabled

    # Row 1: additional analysis plots
    ttk::button $parent.plots.cdist -text "Distances" \
        -command {::mdance::plots::cluster_distance_heatmap $::mdance::results} -state disabled
    ttk::button $parent.plots.msdpop -text "MSD/Pop" \
        -command {::mdance::plots::msd_vs_population $::mdance::results} -state disabled
    ttk::button $parent.plots.reprmsd -text "Rep. RMSD" \
        -command {::mdance::plots::representative_rmsd_matrix $::mdance::results} -state disabled
    ttk::button $parent.plots.trans -text "Transitions" \
        -command {::mdance::plots::transition_heatmap $::mdance::results} -state disabled
    ttk::button $parent.plots.residence -text "Residence" \
        -command {::mdance::plots::residence_chart $::mdance::results} -state disabled
    ttk::button $parent.plots.isim -text "Similarity" \
        -command ::mdance::gui::run_similarity_analysis -state disabled

    grid $parent.plots.pop        -row 0 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.timeline   -row 0 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.msd        -row 0 -column 2 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.dendro     -row 0 -column 3 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.elbow      -row 0 -column 4 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.silhouette -row 0 -column 5 -padx 3 -pady 2 -sticky ew

    grid $parent.plots.cdist      -row 1 -column 0 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.msdpop     -row 1 -column 1 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.reprmsd    -row 1 -column 2 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.trans      -row 1 -column 3 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.residence  -row 1 -column 4 -padx 3 -pady 2 -sticky ew
    grid $parent.plots.isim       -row 1 -column 5 -padx 3 -pady 2 -sticky ew

    for {set col 0} {$col < 6} {incr col} {
        grid columnconfigure $parent.plots $col -weight 1
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
    set lb $parent.table.list.lb
    $lb delete 0 end

    set sizes [expr {[dict exists $results clusterSizes] ? [dict get $results clusterSizes] : {}}]
    set reps [expr {[dict exists $results representatives] ? [dict get $results representatives] : {}}]
    set nframes [expr {[dict exists $results nFrames] ? [dict get $results nFrames] : 0}]

    for {set i 0} {$i < [llength $sizes]} {incr i} {
        set size [lindex $sizes $i]
        set pct [expr {$nframes > 0 ? [format "%.1f%%" [expr {100.0 * $size / $nframes}]] : "-"}]
        set af [::mdance::abs_frame $results [lindex $reps $i]]
        set rep [expr {$af < 0 ? "-" : $af}]
        set line [format "%-5d %-8d %-8s %-8s" $i $size $pct $rep]
        $lb insert end $line
    }

    # Enable/disable visualization buttons
    $parent.plots.pop configure -state normal
    $parent.plots.timeline configure -state normal
    $parent.plots.dendro configure -state normal
    $parent.plots.silhouette configure -state normal
    $parent.plots.cdist configure -state normal
    $parent.plots.reprmsd configure -state normal
    $parent.plots.trans configure -state normal
    $parent.plots.residence configure -state normal
    $parent.plots.isim configure -state normal

    if {[dict exists $results clusterMSD]} {
        $parent.plots.msd configure -state normal
        $parent.plots.msdpop configure -state normal
    } else {
        $parent.plots.msd configure -state disabled
        $parent.plots.msdpop configure -state disabled
    }
}

proc ::mdance::gui::goto_selected_rep {} {
    set lb .mdance.nb.results.table.list.lb
    set sel [$lb curselection]
    if {$sel eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Select a cluster from the list first."
        return
    }
    set cluster_idx [lindex $sel 0]
    if {[catch {::mdance::goto_representative $cluster_idx} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
    }
}

proc ::mdance::gui::color_by_cluster {} {
    if {[catch {::mdance::apply_cluster_colors} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
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
    ttk::treeview $parent.res.tv -columns {method frame kind} -show headings -height 8
    foreach {c t w} {method Method 150 frame "VMD frame" 90 kind Type 130} {
        $parent.res.tv heading $c -text $t
        $parent.res.tv column $c -width $w -anchor center
    }
    $parent.res.tv tag configure prediction -background "#d6f5d6"
    pack $parent.res.tv -fill both -expand 1
    ttk::button $parent.res.goto -text "Go to Selected Frame" \
        -command ::mdance::gui::goto_prime_frame
    pack $parent.res.goto -side left -pady {6 0}
}

proc ::mdance::gui::run_prime_analysis {} {
    variable prime_metric
    variable prime_trim
    variable prime_weighted
    variable prime_results

    if {![_busy_guard]} return
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
    set molid [dict get $::mdance::results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        tk_messageBox -icon error -title "MDANCE" -message "Source molecule $molid is no longer loaded."
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
    variable mol_selection
    variable ft_frames
    if {![_busy_guard]} return
    if {$ft_frames eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a selection first."
        return
    }
    set molid $mol_selection
    if {$molid eq "top"} { set molid [molinfo top] }
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
    set f [tk_getOpenFile \
        -filetypes {{"MDANCE session" ".mdance"} {"All files" "*"}} \
        -title "Load Session"]
    if {$f eq ""} return
    if {[catch {set live [::mdance::load_session $f]} err]} {
        tk_messageBox -icon error -title "MDANCE Error" -message $err
        return
    }
    .mdance.nb select .mdance.nb.results
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
