# Runtime scenario: the GUI controls added for the reviewer feedback --
# the MSD metric lock, the sortable Results table, Clear Results, the citation
# footers and the DIVINE crash guard. These need real Tk widgets, so they live
# here rather than in a tclsh unit test.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
::mdance::gui::create_window

# ------------------------------------------------------------------
th::section "The metric selector is hidden and locked to MSD"
# ------------------------------------------------------------------
# For MD data the metric is fixed to MSD: it is the only one with a physical
# meaning for Cartesian frames. The machinery stays reachable, so this is a GUI
# lock rather than a removal.
th::test "every algorithm tab registered its metric combobox" {
    # Discovery is by -textvariable, so a reordered tab still gets locked.
    set found {}
    foreach cb [array names ::mdance::gui::metric_slots] {
        lappend found [$cb cget -textvariable]
    }
    foreach v {km_metric div_metric helm_metric eq_metric} {
        th::true [expr {[lsearch -exact $found ::mdance::gui::$v] >= 0}] \
            "$v must be registered with the lock"
    }
}
th::test "PRIME is deliberately NOT locked (its metric is a similarity index)" {
    foreach cb [array names ::mdance::gui::metric_slots] {
        th::ne "::mdance::gui::prime_metric" [$cb cget -textvariable]
    }
    th::eq "RR" $::mdance::gui::prime_metric
}
th::test "while locked, the combobox is not mapped and a plain MSD label is" {
    th::false $::mdance::gui::metric_unlocked "fixture check: locked by default"
    # The parameter sections ship folded, and nothing inside a folded section is
    # managed by grid, so open them before reading any child's geometry. This
    # tests the metric lock, not the fold state.
    ::mdance::gui::set_all_folded 0
    foreach cb [array names ::mdance::gui::metric_slots] {
        th::eq "" [grid info $cb] "the combobox must be out of the grid"
        th::ne "" [grid info ${cb}L] "the MSD label must occupy its cell"
        th::eq "MSD" [${cb}L cget -text]
    }
}
th::test "all four metric variables read MSD while locked" {
    foreach v {km_metric div_metric helm_metric eq_metric} {
        th::eq "MSD" [set ::mdance::gui::$v]
    }
}
th::test "unlocking restores the combobox with the full metric list" {
    set ::mdance::gui::metric_unlocked 1
    ::mdance::gui::apply_metric_lock
    foreach cb [array names ::mdance::gui::metric_slots] {
        th::ne "" [grid info $cb] "the combobox must be back in the grid"
        th::eq "" [grid info ${cb}L]
        th::eq 11 [llength [$cb cget -values]]
        th::eq "readonly" [$cb cget -state]
    }
}
th::test "re-locking resets a metric chosen while unlocked" {
    # Hiding the widget without resetting the value would keep sending the
    # exotic metric to the backend from behind a control the user can no longer
    # see or correct.
    set ::mdance::gui::km_metric "JT"
    set ::mdance::gui::metric_unlocked 0
    ::mdance::gui::apply_metric_lock
    th::eq "MSD" $::mdance::gui::km_metric
}
th::test "the lock survives being applied twice (idempotent)" {
    th::ok { ::mdance::gui::apply_metric_lock }
    th::ok { ::mdance::gui::apply_metric_lock }
    th::eq "MSD" $::mdance::gui::km_metric
}
th::test "a destroyed metric combobox is forgotten, not left dangling" {
    # The Frame Tools dialog is created and destroyed on demand, so its entry
    # would otherwise accumulate as a stale widget path and error on the next
    # apply. (A throwaway toplevel, because .mdance itself is pack-managed.)
    set before [array size ::mdance::gui::metric_slots]
    toplevel .probe
    ttk::combobox .probe.cb -textvariable ::mdance::gui::ft_metric
    grid .probe.cb
    ::mdance::gui::_register_metric_combo .probe.cb
    th::eq [expr {$before + 1}] [array size ::mdance::gui::metric_slots]
    destroy .probe
    th::ok { ::mdance::gui::apply_metric_lock }
    th::eq $before [array size ::mdance::gui::metric_slots]
}

# ------------------------------------------------------------------
th::section "The Sweep tab offers MSD only while the lock is on"
# ------------------------------------------------------------------
th::test "non-MSD metric checkboxes are disabled and cleared" {
    foreach m {BUB Fai Gle Ja JT RT RR SM SS1 SS2} {
        th::true [.mdance.nb.sweep.met.m$m instate disabled] "$m must be disabled"
        th::false $::mdance::gui::sweep_metric($m) "$m must be unselected"
    }
    th::false [.mdance.nb.sweep.met.mMSD instate disabled] "MSD stays selectable"
    th::true $::mdance::gui::sweep_metric(MSD)
}
th::test "unlocking re-enables the whole metric grid" {
    set ::mdance::gui::metric_unlocked 1
    ::mdance::gui::apply_metric_lock
    foreach m {MSD BUB JT SS2} {
        th::false [.mdance.nb.sweep.met.m$m instate disabled] "$m must be enabled"
    }
    set ::mdance::gui::metric_unlocked 0
    ::mdance::gui::apply_metric_lock
}

# ------------------------------------------------------------------
th::section "StratAll is the default initialization"
# ------------------------------------------------------------------
th::test "the KMeans tab and the sweep both default to StratAll" {
    th::eq "StratAll" $::mdance::gui::km_kinit
    th::true $::mdance::gui::sweep_kinit(StratAll)
    th::false $::mdance::gui::sweep_kinit(CompSim)
}

# ------------------------------------------------------------------
th::section "HELM trim options: Min samples is now actually functional"
# ------------------------------------------------------------------
# Intercept run_guarded so we can see exactly what run_helm hands the backend,
# without running a clustering for each combination.
set ::CAPTURED ""
proc ::mdance::gui::run_guarded {algorithm params} { set ::CAPTURED [list $algorithm $params] }

set ::mdance::gui::mol_selection $mol
set ::mdance::gui::atom_selection "name CA"
set ::mdance::gui::helm_nclusters 3
set ::mdance::gui::helm_stop_mode "nclusters"
set ::mdance::gui::helm_labels_source "auto"
set ::mdance::gui::helm_pre_k 50

proc helm_params {} {
    set ::CAPTURED ""
    ::mdance::gui::run_helm
    if {$::CAPTURED eq ""} { return "" }
    return [lindex $::CAPTURED 1]
}

th::test "with trimming OFF no trim parameter is sent at all" {
    # All three used to be sent on EVERY run. That was not merely untidy: the
    # backend refuses trim-val and trim-k together whether or not trim-start is
    # set, so two leftover values failed the run (see the next test).
    set ::mdance::gui::helm_trim_start 0
    set p [helm_params]
    th::ne "" $p "the run must be accepted"
    foreach k {trim-start min-samples trim-val trim-k} {
        th::false [dict exists $p $k] "$k must not be sent while trimming is off"
    }
}
th::test "two leftover trim values no longer poison a non-trimming run" {
    set ::mdance::gui::helm_trim_start 0
    set ::mdance::gui::helm_trim_val 10
    set ::mdance::gui::helm_trim_k 45
    set p [helm_params]
    th::ne "" $p "the run must still be accepted"
    th::false [dict exists $p trim-val]
    th::false [dict exists $p trim-k]
}
th::test "trimming by cluster count sends trim-k AND min-samples, never trim-val" {
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "k"
    set ::mdance::gui::helm_trim_k 45
    set ::mdance::gui::helm_min_samples 0.01
    set p [helm_params]
    th::ne "" $p
    th::eq 1 [dict get $p trim-start]
    th::eq 45 [dict get $p trim-k]
    th::eq 0.01 [dict get $p min-samples] "Min samples must now reach the backend"
    th::false [dict exists $p trim-val] "the backend refuses both criteria together"
}
th::test "trimming by MSD ceiling sends trim-val AND min-samples, never trim-k" {
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "val"
    set ::mdance::gui::helm_trim_val 10
    set p [helm_params]
    th::ne "" $p
    th::eq 10 [dict get $p trim-val]
    th::eq 0.01 [dict get $p min-samples]
    th::false [dict exists $p trim-k]
}
th::test "an MSD ceiling of 0 is refused with an explanation, not sent" {
    # trim-val keeps clusters BELOW the ceiling, so 0 discards everything.
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "val"
    set ::mdance::gui::helm_trim_val 0
    th::eq "" [helm_params] "the run must be rejected up front"
}
th::test "discarding more pre-clusters than exist is refused up front" {
    # The backend would throw "trimK is too large!"; we know the total here.
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "k"
    set ::mdance::gui::helm_pre_k 50
    set ::mdance::gui::helm_trim_k 49
    th::eq "" [helm_params] "49 of 50 leaves nothing to cluster"
    set ::mdance::gui::helm_trim_k 48
    th::ne "" [helm_params] "48 of 50 is allowed"
}
th::test "a negative Min samples is still rejected" {
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "k"
    set ::mdance::gui::helm_trim_k 5
    set ::mdance::gui::helm_min_samples -1
    th::eq "" [helm_params]
    set ::mdance::gui::helm_min_samples 0.01
}

# ------------------------------------------------------------------
th::section "HELM pre-cluster KMeans takes KMeans' own parameters"
# ------------------------------------------------------------------
th::test "auto pre-clustering sends kinit and sampling %, not just K" {
    # Previously only the metric and K were passed, so the hidden first stage
    # of a HELM run silently used the backend's default initialization.
    set ::mdance::gui::helm_trim_start 0
    set ::mdance::gui::helm_labels_source "auto"
    set ::mdance::gui::helm_pre_k 60
    set ::mdance::gui::helm_pre_kinit "StratAll"
    set ::mdance::gui::helm_pre_percentage 10
    set p [helm_params]
    th::eq 60 [dict get $p pre-k]
    th::eq "StratAll" [dict get $p pre-kinit]
    th::eq 10 [dict get $p pre-percentage]
}
th::test "the pre-cluster defaults match the KMeans tab's defaults" {
    th::eq $::mdance::gui::km_kinit $::mdance::gui::helm_pre_kinit
    th::eq $::mdance::gui::km_percentage $::mdance::gui::helm_pre_percentage
}
th::test "loading labels from a file sends no pre-cluster parameters" {
    set lf [::mdance::utils::mktmp "_lbl.csv"]
    set fp [open $lf w]; puts $fp "frame,cluster"
    for {set i 0} {$i < 24} {incr i} { puts $fp "$i,[expr {$i % 3}]" }
    close $fp
    set ::mdance::gui::helm_labels_source "file"
    set ::mdance::gui::helm_labels_file $lf
    set p [helm_params]
    th::eq $lf [dict get $p initial-labels]
    foreach k {pre-k pre-kinit pre-percentage} {
        th::false [dict exists $p $k] "$k is meaningless when labels come from a file"
    }
    set ::mdance::gui::helm_labels_source "auto"
    catch {file delete $lf}
}

# ------------------------------------------------------------------
th::section "The dependent HELM controls are greyed out when inert"
# ------------------------------------------------------------------
th::test "everything under Enable trimming is disabled while it is off" {
    set ::mdance::gui::helm_trim_start 0
    ::mdance::gui::_helm_trim_sync
    foreach w {ck cval ems ek eval} {
        th::true [.mdance.nb.helm.trim.$w instate disabled] "$w must be disabled"
    }
}
th::test "only the selected trim criterion's entry is live" {
    set ::mdance::gui::helm_trim_start 1
    set ::mdance::gui::helm_trim_mode "k"
    ::mdance::gui::_helm_trim_sync
    th::false [.mdance.nb.helm.trim.ek instate disabled] "the K entry is live"
    th::true [.mdance.nb.helm.trim.eval instate disabled] "the MSD entry is not"
    set ::mdance::gui::helm_trim_mode "val"
    ::mdance::gui::_helm_trim_sync
    th::true [.mdance.nb.helm.trim.ek instate disabled]
    th::false [.mdance.nb.helm.trim.eval instate disabled]
    th::false [.mdance.nb.helm.trim.ems instate disabled] "Min samples applies to both"
}
th::test "pre-cluster controls grey out when labels come from a file" {
    set ::mdance::gui::helm_labels_source "file"
    ::mdance::gui::_helm_labels_sync
    foreach w {prek pinit ppct} {
        th::true [.mdance.nb.helm.labels.$w instate disabled] "$w must be disabled"
    }
    set ::mdance::gui::helm_labels_source "auto"
    ::mdance::gui::_helm_labels_sync
    foreach w {prek pinit ppct} {
        th::false [.mdance.nb.helm.labels.$w instate disabled] "$w must be enabled"
    }
    th::eq "readonly" [.mdance.nb.helm.labels.pinit cget -state] \
        "the init combobox must go back to readonly, not editable"
}

# ------------------------------------------------------------------
th::section "Every reference lives on the Help view"
# ------------------------------------------------------------------
th::test "one block per algorithm, and none left on the input column" {
    # They moved off the algorithm panels: a reference is read once and never
    # edited, so on the input column it was permanent furniture in the space the
    # parameters need.
    foreach tab {kmeans divine helm equal prime} {
        th::true [winfo exists .mdance.nb.help.refs.$tab] \
            "$tab must have a reference block on Help"
        th::false [winfo exists .mdance.nb.$tab.cite] \
            "$tab must not carry its own footer any more"
    }
}
th::test "the NANI block carries both supplied NANI references" {
    set t [.mdance.nb.help.refs.kmeans.t get 1.0 end]
    th::match "*K-Means NANI*" $t
    th::match "*10.1021/acs.jctc.4c00308*" $t
    th::match "*Stratified NANI*" $t
    th::match "*10.1021/acs.jcim.5c02741*" $t
}
th::test "the HELM block carries the supplied HELM reference" {
    set t [.mdance.nb.help.refs.helm.t get 1.0 end]
    th::match "*Hierarchical Extended Linkage Method*" $t
    th::match "*10.1021/acs.jcim.5c00539*" $t
}
th::test "algorithms with no reference on file say so, and cite nothing" {
    # The backend repo's docs contradict themselves on the primary reference
    # (two different titles and DOIs for the same authors/volume/pages), so no
    # citation is invented for these.
    foreach tab {divine equal prime} {
        set t [.mdance.nb.help.refs.$tab.t get 1.0 end]
        th::match "*No * reference is recorded*" $t
        th::false [string match "*10.1021*" $t] "$tab must not show a DOI"
    }
}
th::test "the footer text is read-only but selectable (so a DOI can be copied)" {
    th::eq "disabled" [.mdance.nb.help.refs.kmeans.t cget -state]
    # A disabled text widget ignores an insert SILENTLY rather than raising, so
    # assert the content is untouched rather than expecting an error.
    set before [.mdance.nb.help.refs.kmeans.t get 1.0 end]
    catch {.mdance.nb.help.refs.kmeans.t insert end "tampered"}
    th::eq $before [.mdance.nb.help.refs.kmeans.t get 1.0 end]
    th::eq "TkDefaultFont" [.mdance.nb.help.refs.kmeans.t cget -font] \
        "must follow the app font-size setting"
}

# ------------------------------------------------------------------
th::section "DIVINE configurations that crash the backend are refused"
# ------------------------------------------------------------------
# CPP-MDANCE divine.cpp indexes a local matrix with global indices in its
# refine block, so OutlierPair/SplinterPair + refine reads out of bounds and
# takes VMD down. This guard is the plugin's side of that.
th::test "the crashing anchors are refused while Refine is on" {
    foreach a {OutlierPair SplinterPair} {
        th::false [::mdance::gui::_divine_combo_ok $a 1] "$a + refine must be refused"
    }
}
th::test "the same anchors are allowed with Refine off" {
    foreach a {OutlierPair SplinterPair} {
        th::true [::mdance::gui::_divine_combo_ok $a 0]
    }
}
th::test "the NANI anchor is unaffected either way" {
    th::true [::mdance::gui::_divine_combo_ok NANI 1]
    th::true [::mdance::gui::_divine_combo_ok NANI 0]
}
th::test "run_divine stops before reaching the backend" {
    set ::CAPTURED ""
    set ::mdance::gui::div_anchors "OutlierPair"
    set ::mdance::gui::div_refine 1
    ::mdance::gui::run_divine
    th::eq "" $::CAPTURED "no run may be launched"
    set ::mdance::gui::div_refine 0
    ::mdance::gui::run_divine
    th::ne "" $::CAPTURED "with refine off the run proceeds"
    set ::mdance::gui::div_anchors "NANI"
    set ::mdance::gui::div_refine 1
}
th::test "the GUI default combination is a safe one" {
    th::eq "NANI" $::mdance::gui::div_anchors
    th::true [::mdance::gui::_divine_combo_ok \
        $::mdance::gui::div_anchors $::mdance::gui::div_refine]
}

# ------------------------------------------------------------------
th::section "The algorithm chooser and the panel it drives"
# ------------------------------------------------------------------
# Four radiobuttons became one combobox. algo_current is still the variable
# everything downstream reads, so the two directions both have to hold: picking
# in the chooser must set the key, and setting the key must move the chooser.
th::test "the chooser lists every algorithm, in the panel order" {
    set cb .mdance.nb.setup.algo.cb
    th::eq [dict values $::mdance::gui::algo_labels] [$cb cget -values]
    th::eq "readonly" [$cb cget -state] "typing into it must not be possible"
}
th::test "choosing in the chooser sets the key, not the label" {
    set cb .mdance.nb.setup.algo.cb
    $cb current [lsearch -exact [$cb cget -values] "HELM"]
    ::mdance::gui::on_algo_selected
    th::eq "helm" $::mdance::gui::algo_current
    # `pack info` THROWS on an unpacked widget rather than returning empty, so
    # ask the geometry manager instead: "" means nothing is managing it.
    th::eq "pack" [winfo manager $::mdance::gui::algo_panels(helm)] "HELM's panel must show"
    th::eq "" [winfo manager $::mdance::gui::algo_panels(kmeans)] "KMeans' must not"
}
th::test "setting the algorithm in code moves the chooser with it" {
    # Session load and the tests set the algorithm without touching the widget.
    ::mdance::gui::select_algorithm equal
    th::eq "eQUAL" [.mdance.nb.setup.algo.cb get]
    th::eq "equal" $::mdance::gui::algo_current
    ::mdance::gui::select_algorithm kmeans
    th::eq "KMeans NANI" [.mdance.nb.setup.algo.cb get]
}
th::test "Run still names the algorithm the chooser is showing" {
    ::mdance::gui::select_algorithm divine
    ::mdance::gui::_toolbar_labels .mdance.tools 0
    th::match "*DIVINE*" [.mdance.tools.run cget -text]
    ::mdance::gui::select_algorithm kmeans
    ::mdance::gui::_toolbar_labels .mdance.tools 0
    th::match "*KMeans*" [.mdance.tools.run cget -text]
}

# ------------------------------------------------------------------
th::section "The live frame count that replaced Preview Selection"
# ------------------------------------------------------------------
# It is counted arithmetically rather than by building the index list, so the
# thing that can go wrong is disagreeing with ::mdance::frame_list. Every case
# here asserts against frame_list itself rather than a hard-coded number.
proc frame_info_for {first last stride} {
    set ::mdance::gui::frame_first $first
    set ::mdance::gui::frame_last $last
    set ::mdance::gui::frame_stride $stride
    ::mdance::gui::update_frame_info
    return [.mdance.nb.setup.frames.info cget -text]
}
th::test "the count agrees with frame_list for every range shape" {
    set ::mdance::gui::mol_selection $mol
    foreach {first last stride} {0 -1 1   0 -1 3   4 18 2   5 5 1   0 100 7} {
        set want [llength [::mdance::frame_list $mol $first $last $stride]]
        th::match "$want of *frames" [frame_info_for $first $last $stride]             "first=$first last=$last stride=$stride"
    }
}
th::test "it reports the trajectory length too, not just the subset" {
    set total [molinfo $mol get numframes]
    th::eq "$total of $total frames" [frame_info_for 0 -1 1]
}
th::test "a non-numeric field names the field instead of counting" {
    th::match "Stride must be a whole number*" [frame_info_for 0 -1 "1o"]
    th::match "First must be a whole number*" [frame_info_for "x" -1 1]
    th::match "Last must be a whole number*" [frame_info_for 0 "" 1]
}
th::test "first past last is refused here as frame_list refuses it" {
    th::match "First (9) is past last (4)*" [frame_info_for 9 4 1]
    th::throws {::mdance::frame_list $mol 9 4 1} "*first*past*last*"
}
th::test "the readout follows the spinboxes on its own, debounced" {
    # The whole point of dropping the Preview button: nothing is pressed.
    # (The previous test left an invalid range behind on purpose.)
    set ::mdance::gui::frame_first 0
    set ::mdance::gui::frame_last -1
    set ::mdance::gui::frame_stride 1
    ::mdance::gui::update_frame_info
    set before [.mdance.nb.setup.frames.info cget -text]
    set ::mdance::gui::frame_stride 4
    # The trace debounces by 200 ms, so the label is deliberately stale here.
    th::eq $before [.mdance.nb.setup.frames.info cget -text]
    after 400 {set ::SETTLED 1}
    vwait ::SETTLED
    set want [llength [::mdance::frame_list $mol 0 -1 4]]
    th::match "$want of *frames" [.mdance.nb.setup.frames.info cget -text]
    set ::mdance::gui::frame_stride 1
}

# ------------------------------------------------------------------
th::section "The backend group moved to Settings"
# ------------------------------------------------------------------
th::test "nothing on the Setup column reports the backend any more" {
    th::false [winfo exists .mdance.nb.setup.cli] "the old group must be gone"
    th::false [winfo exists .mdance.nb.setup.preview] "so must Preview Selection"
    th::true [winfo exists .mdance.nb.setup.frames.tools] "Frame Tools stays"
}
th::test "detection still runs at window creation, with no dialog open" {
    # It is what sets use_library and cli_path; a run started before Settings is
    # ever opened depends on it having happened.
    th::false [winfo exists .mdance_settings] "fixture check: dialog closed"
    th::ne "" $::mdance::gui::backend_mode
    th::ne "" $::mdance::gui::backend_status
}
th::test "the dialog shows the state that was detected earlier" {
    ::mdance::gui::settings_dialog
    th::eq $::mdance::gui::backend_mode [.mdance_settings.backend.mode_value cget -text]
    th::eq $::mdance::gui::backend_status [.mdance_settings.backend.status cget -text]
    th::eq "readonly" [.mdance_settings.backend.path_entry cget -state]         "the path is reported, not typed"
}
th::test "re-detecting with the dialog open updates it in place" {
    set ::mdance::gui::backend_mode "stale"
    .mdance_settings.backend.mode_value configure -text "stale"
    ::mdance::gui::detect_backend
    th::ne "stale" [.mdance_settings.backend.mode_value cget -text]
    th::eq $::mdance::gui::backend_mode [.mdance_settings.backend.mode_value cget -text]
    destroy .mdance_settings
}

exit [th::done "runtime:gui_controls"]
