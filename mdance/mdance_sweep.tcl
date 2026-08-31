# mdance_sweep.tcl - Parameter sweep workflow for the MDANCE VMD plugin
#
# Runs clustering across a grid of {algorithm x K x metric x init}, tabulates
# Calinski-Harabasz / Davies-Bouldin scores per configuration, highlights the
# best run by each score, draws a score heatmap, and can load any configuration
# back into the Results tab. Coordinates are extracted once (honoring the Setup
# tab frame range/stride) and reused for every configuration via
# ::mdance::run_one_config.

namespace eval ::mdance::gui {
    # Sweep selections
    variable sweep_kmin 2
    variable sweep_kmax 12
    variable sweep_kstep 1
    variable sweep_score "CH"     ;# which score the heatmap shows: CH or DB

    # Run state
    variable sweep_cancel 0
    variable sweep_running 0
    variable sweep_status "Idle"

    # Per-run storage (keyed by treeview item id)
    variable sweep_full         ;# array: item-id -> full result dict (+ molid/atomsel/frames)
    array set sweep_full {}
    variable sweep_rows         ;# array: item-id -> summary dict (algo K Kact metric kinit ch db status)
    array set sweep_rows {}

    # Algorithm / metric / init selections (arrays of bool)
    variable sweep_algo
    array set sweep_algo {kmeans 1 divine 0}
    variable sweep_metric
    array set sweep_metric {MSD 1 BUB 0 Fai 0 Gle 0 Ja 0 JT 0 RT 0 RR 0 SM 0 SS1 0 SS2 0}
    variable sweep_kinit
    array set sweep_kinit {StratAll 0 StratReduced 0 CompSim 1 DivSelect 0 KmeansPP 0 Random 0 VanillaKmeansPP 0}
}

# --- Sweep Tab ---
proc ::mdance::gui::build_sweep_tab {parent} {
    # Algorithm + K range
    ttk::labelframe $parent.grid -text "Sweep Grid" -padding 10
    pack $parent.grid -fill x -padx 10 -pady {10 0}

    ttk::label $parent.grid.lalgo -text "Algorithms:"
    ttk::checkbutton $parent.grid.km -text "KMeans" -variable ::mdance::gui::sweep_algo(kmeans)
    ttk::checkbutton $parent.grid.dv -text "DIVINE" -variable ::mdance::gui::sweep_algo(divine)
    grid $parent.grid.lalgo -row 0 -column 0 -sticky w -padx {0 10}
    grid $parent.grid.km -row 0 -column 1 -sticky w
    grid $parent.grid.dv -row 0 -column 2 -sticky w

    ttk::label $parent.grid.lk -text "K range:"
    ttk::spinbox $parent.grid.kmin -textvariable ::mdance::gui::sweep_kmin -from 2 -to 200 -width 5
    ttk::label $parent.grid.kto -text "to"
    ttk::spinbox $parent.grid.kmax -textvariable ::mdance::gui::sweep_kmax -from 2 -to 200 -width 5
    ttk::label $parent.grid.kby -text "step"
    ttk::spinbox $parent.grid.kstep -textvariable ::mdance::gui::sweep_kstep -from 1 -to 50 -width 5
    grid $parent.grid.lk   -row 1 -column 0 -sticky w -padx {0 10} -pady {6 0}
    grid $parent.grid.kmin -row 1 -column 1 -sticky w -pady {6 0}
    grid $parent.grid.kto  -row 1 -column 2 -sticky w -pady {6 0}
    grid $parent.grid.kmax -row 1 -column 3 -sticky w -pady {6 0}
    grid $parent.grid.kby  -row 1 -column 4 -sticky w -padx {10 0} -pady {6 0}
    grid $parent.grid.kstep -row 1 -column 5 -sticky w -pady {6 0}

    # Metrics
    ttk::labelframe $parent.met -text "Metrics" -padding 10
    pack $parent.met -fill x -padx 10 -pady {10 0}
    set col 0
    foreach m {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2} {
        ttk::checkbutton $parent.met.m$m -text $m -variable ::mdance::gui::sweep_metric($m)
        grid $parent.met.m$m -row [expr {$col / 6}] -column [expr {$col % 6}] -sticky w -padx 4 -pady 2
        incr col
    }
    ttk::label $parent.met.note \
        -text "MSD is the right choice for Cartesian coordinates. The other indices are binary/extended-similarity metrics for fingerprint-style data and may not be meaningful on raw XYZ." \
        -justify left -wraplength 460 -foreground "#a05000"
    grid $parent.met.note -row 2 -column 0 -columnspan 6 -sticky w -pady {6 0}

    # Initialization (KMeans / DIVINE)
    ttk::labelframe $parent.init -text "Initialization" -padding 10
    pack $parent.init -fill x -padx 10 -pady {10 0}
    set col 0
    foreach ki {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP} {
        ttk::checkbutton $parent.init.k$ki -text $ki -variable ::mdance::gui::sweep_kinit($ki)
        grid $parent.init.k$ki -row [expr {$col / 4}] -column [expr {$col % 4}] -sticky w -padx 4 -pady 2
        incr col
    }

    # Run controls
    ttk::frame $parent.run -padding {10 8}
    pack $parent.run -fill x -padx 10 -pady {8 0}
    ttk::button $parent.run.go -text "Run Sweep" -command ::mdance::gui::run_parameter_sweep
    ttk::button $parent.run.cancel -text "Cancel" -command {set ::mdance::gui::sweep_cancel 1} -state disabled
    ttk::label $parent.run.status -textvariable ::mdance::gui::sweep_status -anchor w
    pack $parent.run.go -side left -padx {0 6}
    pack $parent.run.cancel -side left -padx {0 12}
    pack $parent.run.status -side left -fill x -expand 1

    # Results table
    ttk::labelframe $parent.res -text "Sweep Results" -padding 10
    pack $parent.res -fill both -expand 1 -padx 10 -pady {8 10}

    set cols {algo K Kact metric kinit CH DB top}
    ttk::treeview $parent.res.tv -columns $cols -show headings -height 8 \
        -yscrollcommand [list $parent.res.sb set]
    ttk::scrollbar $parent.res.sb -orient vertical -command [list $parent.res.tv yview]
    foreach {c text w} {algo Algorithm 80  K K 45  Kact "K act" 50  metric Metric 60 \
                        kinit Init 110  CH "CH (↑)" 90  DB "DB (↓)" 90  top "Top size" 70} {
        $parent.res.tv heading $c -text $text \
            -command [list ::mdance::gui::sweep_sort_by $c]
        $parent.res.tv column $c -width $w -anchor center
    }
    $parent.res.tv tag configure bestCH -background "#d6f5d6"
    $parent.res.tv tag configure bestDB -background "#d6e4f5"
    $parent.res.tv tag configure failed -background "#f5d6d6"
    pack $parent.res.sb -side right -fill y
    pack $parent.res.tv -side top -fill both -expand 1

    ttk::frame $parent.resbtns
    pack $parent.resbtns -fill x -padx 10 -pady {0 10}
    ttk::button $parent.resbtns.load -text "Load Selected into Results" \
        -command ::mdance::gui::sweep_load_selected
    ttk::button $parent.resbtns.hm -text "Score Heatmap" -command ::mdance::gui::sweep_heatmap
    ttk::button $parent.resbtns.csv -text "Export CSV..." -command ::mdance::gui::sweep_export_csv
    pack $parent.resbtns.load -side left -padx {0 6}
    pack $parent.resbtns.hm -side left -padx {0 6}
    pack $parent.resbtns.csv -side left
}

# Build the list of selected values for a bool-array selection
proc ::mdance::gui::_selected_keys {arrName order} {
    upvar #0 $arrName arr
    set out {}
    foreach k $order {
        if {[info exists arr($k)] && $arr($k)} { lappend out $k }
    }
    return $out
}

proc ::mdance::gui::run_parameter_sweep {} {
    variable sweep_kmin
    variable sweep_kmax
    variable sweep_kstep
    variable sweep_cancel
    variable sweep_running
    variable sweep_status
    variable sweep_full
    variable sweep_rows

    if {$sweep_running} return
    # A sweep and a single run/elbow share ::mdance::results and the global temp
    # file registry, and each one ends by calling ::mdance::utils::cleanup, which
    # deletes EVERY registered file -- including the other operation's live input
    # CSV. The interlock has to run both ways, so check the single-run flag here
    # (run_guarded/_busy_guard/run_elbow_analysis check sweep_running in return).
    if {$::mdance::running} {
        tk_messageBox -icon info -title "MDANCE" \
            -message "A clustering run is already in progress."
        return
    }

    set algos   [_selected_keys ::mdance::gui::sweep_algo  {kmeans divine}]
    set metrics [_selected_keys ::mdance::gui::sweep_metric {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}]
    set kinits  [_selected_keys ::mdance::gui::sweep_kinit  {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP}]

    if {[llength $algos] == 0} {
        tk_messageBox -icon error -title "MDANCE" -message "Select at least one algorithm."
        return
    }
    if {[llength $metrics] == 0} { set metrics {MSD} }
    if {[llength $kinits] == 0}  { set kinits {CompSim} }
    # Validate before comparing or looping. The spinboxes accept arbitrary typed
    # text, and a K step of 0 turns the list build below into an infinite loop
    # that grows `ks` until VMD dies -- with no way to interrupt it.
    if {![_chknum $sweep_kmin  "K min"  int 2]} return
    if {![_chknum $sweep_kmax  "K max"  int 2]} return
    if {![_chknum $sweep_kstep "K step" int 1]} return
    if {$sweep_kmin > $sweep_kmax} {
        tk_messageBox -icon error -title "MDANCE" -message "K min must be <= K max."
        return
    }

    # K list
    set ks {}
    for {set k $sweep_kmin} {$k <= $sweep_kmax} {incr k $sweep_kstep} { lappend ks $k }

    set total [expr {[llength $algos] * [llength $ks] * [llength $metrics] * [llength $kinits]}]
    if {$total == 0} {
        tk_messageBox -icon error -title "MDANCE" -message "Grid is empty."
        return
    }
    set ans [tk_messageBox -icon question -type okcancel -title "MDANCE Parameter Sweep" \
        -message "This sweep will run $total clustering configurations.\n\nRuns cannot be interrupted mid-configuration; Cancel takes effect after the current run finishes. Proceed?"]
    if {$ans ne "ok"} return

    # Resolve molecule + extract coordinates once (respecting Setup range/stride)
    set molid $::mdance::gui::mol_selection
    if {$molid eq "top"} {
        if {[catch {set molid [molinfo top]}]} {
            tk_messageBox -icon error -title "MDANCE" -message "No molecule loaded."
            return
        }
    }
    set atomsel $::mdance::gui::atom_selection
    set first $::mdance::gui::frame_first
    set last  $::mdance::gui::frame_last
    set stride $::mdance::gui::frame_stride

    if {[catch {::mdance::init} err]} {
        tk_messageBox -icon error -title "MDANCE" -message "Backend not available: $err"
        return
    }

    set sweep_running 1
    # Hold the shared run flag too: `update` inside the grid loop keeps the event
    # loop live, so without this a Run click on any algorithm tab would start a
    # concurrent run whose cleanup deletes this sweep's input CSV mid-grid.
    set ::mdance::running 1
    set sweep_cancel 0
    .mdance.nb.sweep.run.cancel configure -state normal
    .mdance.nb.sweep.run.go configure -state disabled

    set sweep_status "Extracting coordinates..."
    update idletasks

    set csv_path ""
    if {[catch {
        if {$::mdance::use_library} {
            lassign [::mdance::extract_coordinates_flat $molid $atomsel $first $last $stride] \
                flat natoms nframes frames
            set extract [dict create mode library flat $flat natoms $natoms nframes $nframes]
        } else {
            lassign [::mdance::extract_coordinates $molid $atomsel $first $last $stride] \
                csv_path natoms nframes frames
            set extract [dict create mode cli csv $csv_path natoms $natoms]
        }
    } err]} {
        set sweep_running 0
        set ::mdance::running 0
        .mdance.nb.sweep.run.cancel configure -state disabled
        .mdance.nb.sweep.run.go configure -state normal
        set sweep_status "Idle"
        # Reclaim the temp CSV that extract_coordinates may have registered/created
        # before failing (it is tracked in tmpfiles, not in $csv_path which the
        # failed lassign never assigned).
        ::mdance::utils::cleanup
        tk_messageBox -icon error -title "MDANCE" -message "Extraction failed: $err"
        return
    }

    # Clear previous results
    set tv .mdance.nb.sweep.res.tv
    $tv delete [$tv children {}]
    array unset sweep_full
    array unset sweep_rows
    array set sweep_full {}
    array set sweep_rows {}

    set done 0
    set best_ch_val ""; set best_ch_item ""
    set best_db_val ""; set best_db_item ""

    # Run the grid under one outer catch so that no matter how the loop exits
    # (a stray error, a closed window), the finalization epilogue below always
    # restores sweep_running and reclaims temp files -- otherwise a single bad
    # config would wedge the sweep for the rest of the session.
    set looprc [catch {
        foreach algo $algos {
            foreach metric $metrics {
                foreach kinit $kinits {
                    foreach k $ks {
                        if {$sweep_cancel} break
                        incr done
                        set sweep_status "Run $done / $total: $algo K=$k $metric/$kinit"
                        update
                        # A window-close during `update` destroys the treeview.
                        if {![winfo exists $tv]} { set sweep_cancel 1; break }

                        set config [dict create algorithm $algo nclusters $k metric $metric kinit $kinit]
                        # Run AND consume the result inside one catch: a malformed
                        # or partial result becomes a 'failed' row, not an abort.
                        if {[catch {
                            set result [::mdance::run_one_config $extract $config]
                            if {![dict exists $result nClusters] || ![dict exists $result clusterSizes]} {
                                error "incomplete result"
                            }
                            # is_finite, not `string is double`: the latter accepts
                            # the NaN token a degenerate clustering produces, and
                            # NaN then makes the assignment below raise "domain
                            # error" -- so a run that actually SUCCEEDED was being
                            # recorded as a failed ERR row with no stored result.
                            set hasCH [expr {[dict exists $result score_calinskiHarabasz] \
                                && [::mdance::utils::is_finite [dict get $result score_calinskiHarabasz]]}]
                            set hasDB [expr {[dict exists $result score_daviesBouldin] \
                                && [::mdance::utils::is_finite [dict get $result score_daviesBouldin]]}]
                            set ch ""; set db ""
                            if {$hasCH} { set ch [dict get $result score_calinskiHarabasz] }
                            if {$hasDB} { set db [dict get $result score_daviesBouldin] }
                            set kact [dict get $result nClusters]
                            set sizes [dict get $result clusterSizes]
                            set top 0
                            foreach s $sizes { if {$s > $top} { set top $s } }

                            set item [$tv insert {} end -values [list \
                                $algo $k $kact $metric $kinit \
                                [expr {$hasCH ? [format "%.2f" $ch] : "-"}] \
                                [expr {$hasDB ? [format "%.4f" $db] : "-"}] $top]]

                            # Attach molecule context so the run can be loaded into Results
                            dict set result molid $molid
                            dict set result atomsel $atomsel
                            dict set result frames $frames
                            set sweep_full($item) $result
                            set sweep_rows($item) [dict create algo $algo K $k Kact $kact \
                                metric $metric kinit $kinit ch $ch db $db status ok]

                            # Only let rows with a real numeric score win "best"
                            # (a missing DB defaulting to 0 would always beat real ones).
                            if {$hasCH && ($best_ch_val eq "" || $ch > $best_ch_val)} { set best_ch_val $ch; set best_ch_item $item }
                            if {$hasDB && ($best_db_val eq "" || $db < $best_db_val)} { set best_db_val $db; set best_db_item $item }
                        } err]} {
                            set item [$tv insert {} end -values \
                                [list $algo $k "-" $metric $kinit "ERR" "ERR" "-"] -tags failed]
                            set sweep_rows($item) [dict create algo $algo K $k Kact "-" \
                                metric $metric kinit $kinit ch "" db "" status failed]
                        }
                    }
                    if {$sweep_cancel} break
                }
                if {$sweep_cancel} break
            }
            if {$sweep_cancel} break
        }

        # Highlight best runs (guard against a treeview destroyed mid-sweep)
        if {[winfo exists $tv]} {
            if {$best_ch_item ne ""} { $tv item $best_ch_item -tags bestCH }
            if {$best_db_item ne "" && $best_db_item ne $best_ch_item} { $tv item $best_db_item -tags bestDB }
        }
    } loopErr]

    # Always restore run state and reclaim temp files, however the loop exited.
    if {$csv_path ne ""} { catch {file delete $csv_path} }
    ::mdance::utils::cleanup
    set sweep_running 0
    set ::mdance::running 0
    catch {.mdance.nb.sweep.run.cancel configure -state disabled}
    catch {.mdance.nb.sweep.run.go configure -state normal}

    if {$looprc} {
        set sweep_status "Sweep error after $done / $total runs: $loopErr"
        return
    }
    if {$sweep_cancel} {
        set sweep_status "Cancelled after $done / $total runs."
    } else {
        set sweep_status "Done: $done runs. Best CH highlighted green, best DB blue."
    }
}

# Sort the results table by a column (numeric where possible)
proc ::mdance::gui::sweep_sort_by {col} {
    set tv .mdance.nb.sweep.res.tv
    set items {}
    foreach it [$tv children {}] {
        lappend items [list [$tv set $it $col] $it]
    }
    # Numeric sort when all values parse as numbers, else lexical
    set numeric 1
    foreach pair $items {
        if {![string is double -strict [lindex $pair 0]]} { set numeric 0; break }
    }
    if {$numeric} {
        set items [lsort -real -index 0 $items]
    } else {
        set items [lsort -index 0 $items]
    }
    set i 0
    foreach pair $items {
        $tv move [lindex $pair 1] {} $i
        incr i
    }
}

proc ::mdance::gui::sweep_load_selected {} {
    variable sweep_full
    set tv .mdance.nb.sweep.res.tv
    set sel [$tv selection]
    if {$sel eq ""} {
        tk_messageBox -icon info -title "MDANCE" -message "Select a row in the sweep table first."
        return
    }
    set item [lindex $sel 0]
    if {![info exists sweep_full($item)]} {
        tk_messageBox -icon warning -title "MDANCE" -message "That run has no stored result (it failed)."
        return
    }
    set ::mdance::results $sweep_full($item)
    set ::mdance::status "Loaded sweep run into Results"
    .mdance.nb select .mdance.nb.results
    if {[catch {::mdance::gui::update_results_tab} e]} {
        tk_messageBox -icon error -title "MDANCE Error" -message "Could not display results: $e"
    }
}

proc ::mdance::gui::sweep_export_csv {} {
    variable sweep_rows
    set tv .mdance.nb.sweep.res.tv
    set items [$tv children {}]
    if {[llength $items] == 0} {
        tk_messageBox -icon info -title "MDANCE" -message "No sweep results to export."
        return
    }
    set f [tk_getSaveFile -defaultextension ".csv" \
        -filetypes {{"CSV files" ".csv"} {"All files" "*"}} \
        -title "Export Sweep Results" -initialfile "sweep_results.csv"]
    if {$f eq ""} return
    if {[catch {open $f w} fp]} {
        tk_messageBox -icon error -title "MDANCE" -message "Cannot write $f:\n$fp"
        return
    }
    if {[catch {
        puts $fp "algorithm,K_requested,K_actual,metric,kinit,calinski_harabasz,davies_bouldin,status"
        foreach it $items {
            if {![info exists sweep_rows($it)]} continue
            set r $sweep_rows($it)
            puts $fp "[dict get $r algo],[dict get $r K],[dict get $r Kact],[dict get $r metric],[dict get $r kinit],[dict get $r ch],[dict get $r db],[dict get $r status]"
        }
    } werr]} {
        catch {close $fp}
        tk_messageBox -icon error -title "MDANCE" -message "Failed writing $f:\n$werr"
        return
    }
    close $fp
    tk_messageBox -icon info -title "MDANCE" -message "Sweep results exported to $f"
}

# --- Score heatmap: rows = (algo|metric|init), cols = K ---
proc ::mdance::gui::sweep_heatmap {} {
    variable sweep_rows
    variable sweep_score

    set items [.mdance.nb.sweep.res.tv children {}]
    if {[llength $items] == 0} {
        tk_messageBox -icon info -title "MDANCE" -message "Run a sweep first."
        return
    }

    # Collect ok rows into a cell map combo,K -> score
    set combos {}; set ks {}
    array unset cell
    foreach it $items {
        if {![info exists sweep_rows($it)]} continue
        set r $sweep_rows($it)
        if {[dict get $r status] ne "ok"} continue
        set combo "[dict get $r algo]|[dict get $r metric]|[dict get $r kinit]"
        set k [dict get $r K]
        set val [expr {$sweep_score eq "DB" ? [dict get $r db] : [dict get $r ch]}]
        set cell($combo,$k) $val
        if {[lsearch -exact $combos $combo] < 0} { lappend combos $combo }
        if {[lsearch -exact $ks $k] < 0} { lappend ks $k }
    }
    if {[llength $combos] == 0} {
        tk_messageBox -icon info -title "MDANCE" -message "No successful runs to plot."
        return
    }
    set ks [lsort -integer $ks]

    # Persist data for redraw/toggle
    set ::mdance::gui::sweep_hm_data [list [array get cell] $combos $ks $sweep_score]
    ::mdance::gui::draw_sweep_heatmap
}

proc ::mdance::gui::draw_sweep_heatmap {} {
    if {![info exists ::mdance::gui::sweep_hm_data]} return
    lassign $::mdance::gui::sweep_hm_data cell_list combos ks score
    array set cell $cell_list

    set ::mdance::plots::current_plot mdance_sweep_hm
    set nrows [llength $combos]
    set ncols [llength $ks]

    set w [::mdance::plots::create_plot_window mdance_sweep_hm \
        "Sweep Score Heatmap ($score)" 760 [expr {max(360, 120 + $nrows * 36)}]]
    set c $w.c
    lassign [::mdance::plots::canvas_dims $c 760 420] cw ch

    set left 200; set right 90; set top 60; set bot 50
    set x0 $left; set x1 [expr {$cw - $right}]
    set y0 $top;  set y1 [expr {$ch - $bot}]
    set pw [expr {$x1 - $x0}]; set ph [expr {$y1 - $y0}]

    set label [expr {$score eq "DB" ? "Davies-Bouldin (lower=better)" : "Calinski-Harabasz (higher=better)"}]
    ::mdance::plots::draw_title $c $cw "Sweep: $label"

    # Value range
    set vmin 1e30; set vmax -1e30
    foreach combo $combos {
        foreach k $ks {
            if {[info exists cell($combo,$k)]} {
                set v $cell($combo,$k)
                if {$v < $vmin} { set vmin $v }
                if {$v > $vmax} { set vmax $v }
            }
        }
    }
    if {$vmax <= $vmin} { set vmax [expr {$vmin + 1.0}] }

    set cellw [expr {$ncols > 0 ? double($pw) / $ncols : $pw}]
    set cellh [expr {$nrows > 0 ? double($ph) / $nrows : $ph}]

    for {set i 0} {$i < $nrows} {incr i} {
        set combo [lindex $combos $i]
        set cy0 [expr {$y0 + $i * $cellh}]
        $c create text [expr {$x0 - 6}] [expr {$cy0 + $cellh / 2.0}] \
            -text $combo -anchor e -font [::mdance::plots::plot_font -2]
        for {set j 0} {$j < $ncols} {incr j} {
            set k [lindex $ks $j]
            set cx0 [expr {$x0 + $j * $cellw}]
            if {[info exists cell($combo,$k)]} {
                set v $cell($combo,$k)
                set color [::mdance::plots::heatmap_color $v $vmin $vmax]
            } else {
                set color "#dddddd"
            }
            $c create rectangle $cx0 $cy0 [expr {$cx0 + $cellw}] [expr {$cy0 + $cellh}] \
                -fill $color -outline gray80
        }
    }
    # K axis labels
    for {set j 0} {$j < $ncols} {incr j} {
        set px [expr {$x0 + ($j + 0.5) * $cellw}]
        $c create text $px [expr {$y1 + 6}] -text [lindex $ks $j] -anchor n \
            -font [::mdance::plots::plot_font -1]
    }
    $c create text [expr {($x0 + $x1) / 2}] [expr {$ch - 4}] -text "Number of clusters (K)" \
        -anchor s -font [::mdance::plots::plot_font 0]

    ::mdance::plots::draw_color_legend $c [expr {$x1 + 12}] $y0 $y1 $vmin $vmax 5

    # Toggle button (CH <-> DB) inside the toolbar area
    if {![winfo exists $w.toolbar.sw]} {
        ttk::button $w.toolbar.sw -text "Toggle CH/DB" -command {
            set ::mdance::gui::sweep_score [expr {$::mdance::gui::sweep_score eq "DB" ? "CH" : "DB"}]
            ::mdance::gui::sweep_heatmap
        }
        pack $w.toolbar.sw -side left -padx 6
    }

    set ::mdance::plots::redraw_cmds(mdance_sweep_hm) [list ::mdance::gui::draw_sweep_heatmap]
    set csv "combo,K,$score\n"
    foreach combo $combos {
        foreach k $ks {
            if {[info exists cell($combo,$k)]} { append csv "$combo,$k,$cell($combo,$k)\n" }
        }
    }
    set ::mdance::plots::csv_data(mdance_sweep_hm) $csv
}
