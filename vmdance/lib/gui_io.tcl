#
# VMDance - the window's files: sessions, exports, figures, the 3D view
# as a picture
#
# Each dialog runs the same code as the command (Session, Export, Figures).
#

namespace eval ::VMDance::GUI {
    variable session_types {{"VMDance sessions" {.vmdance .mdvsession}} {"All files" *}}
    # the Export dialog's items, and what each says
    variable export_items {
        summary "What was clustered, how, and the clusters (text)"
        clusters "The table of clusters: frames, share, MSD, representative"
        labels "Every clustered frame and its cluster"
        top "Each cluster's frames nearest its representative, ranked"
        timeline "The cluster of every frame, and its RMSD² from the representative"
        transitions "The transitions between the clusters"
        residence "How long the trajectory stays in each cluster"
        silhouette "Every frame's silhouette"
        distances "The distances between the clusters"
        tree "The dendrogram's merges"
        representatives "The representatives' structures (one per cluster)"
        trajectories "Each cluster's frames as a trajectory of its own"
        prime "PRIME's predictions (when run)"
        similarity "The clusters' extended similarity (when computed)"
        elbow "The elbow scan's scores"
        sweep "The sweep's configurations and scores"
        picks "The picked frames"
    }
    # the table each plot's data is
    variable plot_tables {populations clusters timeline timeline transitions transitions residence residence
                          compactness clusters distances distances tree tree silhouette silhouette elbow elbow sweep sweep}
}

proc ::VMDance::GUI::open_session_dialog {} {
    variable w; variable S; variable session_types
    if {[busy]} return
    set f [tk_getOpenFile -parent $w -title "Open a VMDance session" -filetypes $session_types]
    if {$f eq ""} return
    set n [llength [::VMDance::Results::run_list]]
    if {($n || [dict size $::VMDance::Results::elbow] || [dict size $::VMDance::Results::sweep]) &&
        [tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
            -message "Open [file tail $f] in place of what is here?" \
            -detail "Its runs, scans and picked frames replace the [expr {$n == 1 ? "run" : "$n runs"}] and scans of now (Save session first to keep them)."] ne "ok"} return
    if {[catch {::VMDance::Session::load $f auto} r]} {
        _error "The session was not opened:\n$r"
        return
    }
    lassign $r warnings gui
    apply_session_state $gui
    set n [llength [::VMDance::Results::run_list]]
    status "Session [file tail $f]: $n run[expr {$n == 1 ? "" : "s"}][expr {[llength $warnings] ? "; [join $warnings {; }]" : "."}]"
}

# A session of the MDANCE plugin (.mdance): imported as a run.
proc ::VMDance::GUI::import_session_dialog {} {
    variable w
    if {[busy]} return
    set f [tk_getOpenFile -parent $w -title "Import a session of the MDANCE plugin" -filetypes {{"MDANCE plugin sessions" {.mdance}} {"All files" *}}]
    if {$f eq ""} return
    _import $f auto
}
# Import f onto mol: auto, its molecule found by the coordinates
# (Job::_do_import); when none is, the molecule of Setup is offered (the
# command's -mol).
proc ::VMDance::GUI::_import {f mol} {
    if {[catch {::VMDance::import_request $f $mol} req opts]} {
        set code [dict get $opts -errorcode]
        if {$mol eq "auto" && [lrange $code 0 1] eq {VMDANCE NOMOL}} { _import_onto $f $req [lindex $code 2]; return }
        _error "The session was not imported:\n$req"
        return
    }
    _start import $req "Importing [file tail $f]" [list ::VMDance::GUI::_imported $f $req]
}
proc ::VMDance::GUI::_imported {f req r} {
    if {[dict exists $r refused]} {
        _import_onto $f [lindex [dict get $r refused] 1] [lindex [dict get [lindex [dict get $req candidates] 0] frames] end]
        return
    }
    set a [dict get $r result]
    set warnings [dict get $r warnings]
    ::VMDance::Results::publish $a [::VMDance::_imported_label $a]
    status "Imported [file tail $f] onto molecule [dict get $a request mol]: [::VMDance::_summary][expr {[llength $warnings] ? "; [join $warnings {; }]" : "."}]"
    show_pane results
}
# No molecule of f's found (why): the molecule of Setup offered when it has
# the frames clustered (more than last, Session::old_candidates).
proc ::VMDance::GUI::_import_onto {f why last} {
    variable w; variable S
    status "Not imported; what was there is kept."
    set m $S(molid)
    if {$m >= 0 && [::VMDance::Mol::exists $m] && [molinfo $m get numframes] > $last} {
        if {[tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
                -message "Import [file tail $f] onto molecule $m, the molecule of Setup?" \
                -detail "[string toupper $why 0 0]. Molecule $m ([molinfo $m get name], [molinfo $m get numframes] frames) is taken as it is: the status says whether its coordinates give the session's cluster MSDs."] eq "ok"} {
            _import $f $m
        }
        return
    }
    _error "The session was not imported:\n$why.\nLoad its molecule, or choose it in Setup, and import again."
}

proc ::VMDance::GUI::save_session {as} {
    variable w; variable S; variable session_types
    if {[busy]} return
    if {![::VMDance::Results::has_data]} { _error "Nothing to save: cluster a trajectory first."; return }
    # (the file the runs came from or were saved to, whoever opened it: the
    # window or the command)
    set f $::VMDance::Session::current_file
    if {$as || $f eq ""} {
        set f [tk_getSaveFile -parent $w -title "Save the session" -filetypes $session_types -defaultextension .vmdance \
            -initialfile [expr {$f eq "" ? "clusters.vmdance" : [file tail $f]}]]
        if {$f eq ""} return
    }
    if {[catch {::VMDance::Session::save $f [session_state]} err]} {
        _error "The session was not saved:\n$err"
        return
    }
    set n [llength [::VMDance::Results::run_list]]
    status "Session saved: $f ($n run[expr {$n == 1 ? "" : "s"}])."
}

#---------------------------------------------------------------------------
# Export
#---------------------------------------------------------------------------

# Whether an item can be exported now (as the command decides it).
proc ::VMDance::GUI::_exportable {it} {
    expr {[::VMDance::Export::why_not $it] eq ""}
}

proc ::VMDance::GUI::export_dialog {} {
    variable w; variable S; variable X; variable Xkept; variable export_items
    if {[busy]} return
    set any 0
    foreach {it lab} $export_items { if {[_exportable $it]} { set any 1 } }
    if {!$any} { _error "Nothing to export: cluster a trajectory first."; return }
    set d $w.export
    if {[winfo exists $d]} { raise $d; return }
    toplevel $d
    wm title $d "Export results"
    wm transient $d $w
    if {$S(out_dir) eq ""} { set S(out_dir) [pwd] }
    set f [ttk::frame $d.f -padding 12]
    pack $f -fill both -expand 1
    set A [_section $f.where "Where" -padding {8 6}]
    pack ${A}_sec -side top -fill x
    set df [ttk::frame $A.df]
    ttk::entry $df.e -textvariable ::VMDance::GUI::S(out_dir) -width 34
    ttk::button $df.b -text "Browse…" -command [list apply {{d} {
        set x [tk_chooseDirectory -parent $d -title "Folder of the files" -initialdir $::VMDance::GUI::S(out_dir)]
        if {$x ne ""} { set ::VMDance::GUI::S(out_dir) $x }
    }} $d]
    pack $df.e -side left -fill x -expand 1
    pack $df.b -side left -padx {4 0}
    _row $A 0 "Folder" $df
    ttk::entry $A.p -textvariable ::VMDance::GUI::S(out_prefix) -width 20
    _row $A 1 "File names" $A.p "Each file is <name>_<item>.csv (.txt, .pdb, .dcd)"
    grid columnconfigure $A 1 -weight 1
    set B [_section $f.what "What" -padding {8 6}]
    pack ${B}_sec -side top -fill x -pady {10 0}
    set r 0
    set defaults [::VMDance::Export::defaults]
    foreach {it lab} $export_items {
        set ok [_exportable $it]
        if {![info exists X($it)]} { set X($it) [expr {$it in $::VMDance::Export::default_items}] }
        # (unticked when it cannot be written, or is a k × k table left out of
        # the defaults for many clusters: the tick it had is kept apart, and
        # given back when it is offered again)
        if {!$ok || ($it in $::VMDance::Export::default_items && $it ni $defaults)} {
            if {![info exists Xkept($it)]} { set Xkept($it) $X($it) }
            set X($it) 0
        } elseif {[info exists Xkept($it)]} {
            set X($it) $Xkept($it)
            unset Xkept($it)
        }
        ttk::checkbutton $B.c$it -text $lab -variable ::VMDance::GUI::X($it)
        if {!$ok} {
            $B.c$it state disabled
            if {$it in {distances tree} && [set why [::VMDance::Results::too_many $it]] ne ""} { ::VMDance::Tip::add $B.c$it "Not made: $why" }
        } elseif {$it eq "transitions" && $it ni $defaults} {
            set k [::VMDance::Results::nclusters]
            ::VMDance::Tip::add $B.c$it "$k × $k rows (left out unless ticked)"
        }
        grid $B.c$it -row $r -column 0 -sticky w -pady 1
        incr r
    }
    set O [_section $f.opt "Options" -padding {8 6}]
    pack ${O}_sec -side top -fill x -pady {10 0}
    ttk::spinbox $O.top -from 1 -to 10000 -increment 1 -width 5 -textvariable ::VMDance::GUI::S(out_top)
    _row $O 0 "Nearest frames" $O.top "How many frames of each cluster the ranked list has"
    grid configure $O.top -sticky w
    _combo $O.fmt ::VMDance::GUI::S(out_format) {dcd "DCD (and a PDB of the atoms)" pdb "PDB (one model per frame)"} {#}
    _row $O 1 "Structures" $O.fmt
    ttk::entry $O.sel -textvariable ::VMDance::GUI::S(out_sel) -width 20
    _row $O 2 "Atoms" $O.sel "The atoms of the structures written"
    grid columnconfigure $O 1 -weight 1
    set b [ttk::frame $f.b]
    pack $b -side top -fill x -pady {12 0}
    ttk::button $b.ok -text "Export" -command ::VMDance::GUI::_export_go
    ttk::button $b.cancel -text "Cancel" -command [list destroy $d]
    pack $b.cancel $b.ok -side right -padx {6 0}
    ::VMDance::Theme::style_tree $d
    bind $d <Escape> [list destroy $d]
}
proc ::VMDance::GUI::_export_go {} {
    variable w; variable S; variable X; variable export_items
    set d $w.export
    if {[busy]} { _error "A job is running: export when it has ended, or cancel it." $d; return }
    set items [lmap {it lab} $export_items {expr {$X($it) ? $it : [continue]}}]
    if {![llength $items]} { _error "Choose something to export." $d; return }
    if {![regexp {^[1-9][0-9]{0,5}$} [string trim $S(out_top)]]} { _error "Nearest frames: a whole number from 1 to 999999." $d; return }
    set pre [string trim $S(out_prefix)]
    # (a space pasted after the folder would make a folder of its own)
    set dir [string trim $S(out_dir)]
    set o [dict create top [string trim $S(out_top)] lag $S(tn_lag) format $S(out_format) sel [string trim $S(out_sel)]]
    # (checked as the command checks it, before anything is asked or
    # written: what the dialog offered when it opened may be gone, a run
    # switched or the molecule deleted)
    if {[catch {::VMDance::Export::check $dir $pre $items $o} c]} { _error "Not exported:\n$c" $d; return }
    # (an existing file is replaced, an earlier export's clusters that this
    # one does not write deleted: say so first; the files written)
    set exist {}
    foreach p [lindex $c 3] { if {[file exists $p]} { lappend exist [file tail $p] } }
    set old [lmap p [lindex $c 4] {file tail $p}]
    set n [llength $exist]
    set ask {}
    if {$n} { lappend ask "Replace $n file[expr {$n == 1 ? "" : "s"}]" }
    if {[llength $old]} { lappend ask "[expr {$n ? "and delete" : "Delete"}] [llength $old] of an earlier export" }
    set detail [join [lrange $exist 0 7] \n]
    if {[llength $old]} { append detail [expr {$n ? "\n\n" : ""}] "An earlier export's clusters, which this one does not write:\n[join [lrange $old 0 7] \n]" }
    if {[llength $ask] && [tk_messageBox -parent $d -type okcancel -icon question -title VMDance \
            -message "[join $ask {, }]?" -detail $detail] ne "ok"} return
    $d configure -cursor watch
    update
    set err [catch {::VMDance::Export::bundle $dir $pre $items $o} files]
    if {[winfo exists $d]} { $d configure -cursor "" }
    if {$err} { _error "Not exported:\n$files" $d; return }
    destroy $d
    status "[llength $files] file[expr {[llength $files] == 1 ? "" : "s"}] written in $dir."
}

# A table to a file chosen (File ▸ Quick export).
proc ::VMDance::GUI::_save_table {title initial item} {
    variable w; variable S
    set f [tk_getSaveFile -parent $w -title $title -defaultextension .csv -filetypes {{"CSV" {.csv}} {"All files" *}} -initialfile $initial]
    if {$f eq ""} return
    if {[catch {
        switch -- $item {
            top { set t [::VMDance::Export::table_top $S(out_top)] }
            transitions { set t [::VMDance::Export::table_transitions $S(tn_lag)] }
            default { set t [::VMDance::Export::table_$item] }
        }
        ::VMDance::Export::_write $f "$t\n"
    } err]} { _error $err; return }
    status "Written: $f."
}
proc ::VMDance::GUI::quick_table {} {
    if {[busy] || ![::VMDance::Results::has_data]} return
    _save_table "The table of clusters" clusters.csv clusters
}
proc ::VMDance::GUI::save_plot_data {} {
    variable plot_tables
    if {[busy]} return
    set key [_current_tab]
    set item [dict get $plot_tables $key]
    if {$key eq "compactness" && $::VMDance::GUI::S(cp_show) eq "isim"} { set item similarity }
    # (why not, as an export says it: for thousands of clusters no
    # distances will come)
    set why [::VMDance::Export::why_not $item]
    if {$why ne ""} { status "Not saved: $why."; return }
    _save_table "The data of the $key plot" "vmdance_$key.csv" $item
}

# The picked frames' structures.
proc ::VMDance::GUI::save_picks_dialog {} {
    variable w
    if {[busy]} return
    set p $::VMDance::Results::picks
    if {![dict size $p]} { _error "Pick frames first."; return }
    # (their molecule must have the frames they were picked from: asked
    # before a file is)
    if {[::VMDance::Viz::_picks_mol] < 0} { _error "Not written: [::VMDance::Viz::picks_why]."; return }
    set f [tk_getSaveFile -parent $w -title "The picked frames" -initialfile picked_frames.pdb \
        -filetypes {{"PDB" {.pdb}} {"DCD (and a PDB of the atoms)" {.dcd}}}]
    if {$f eq ""} return
    set fmt [expr {[string tolower [file extension $f]] eq ".dcd" ? "dcd" : "pdb"}]
    # (Tk asked of the file named only: a DCD has a PDB of its atoms beside
    # it, which may be there, the molecule's own file among them)
    foreach x [lrange [::VMDance::Export::frame_files $f $fmt] 1 end] {
        if {[file exists $x] && [tk_messageBox -parent $w -type okcancel -icon question -title VMDance \
                -message "Replace [file tail $x]?" -detail "A DCD is written with a PDB of its atoms beside it, of the same name."] ne "ok"} return
    }
    if {[catch {::VMDance::Export::picked $f $fmt} err]} { _error "Not written:\n$err"; return }
    status "[llength [dict get $p vmdframes]] frames written: $f[expr {$fmt eq "dcd" ? " (and [file rootname [file tail $f]].pdb)" : ""}]."
}

#---------------------------------------------------------------------------
# Figures
#---------------------------------------------------------------------------

proc ::VMDance::GUI::figure_dialog {} {
    variable w; variable S; variable tabs; variable F
    if {[busy]} return
    if {![::VMDance::Results::has_data] && ![dict size $::VMDance::Results::elbow] && ![dict size $::VMDance::Results::sweep]} {
        _error "Nothing to draw: cluster a trajectory first."
        return
    }
    set d $w.figures
    if {[winfo exists $d]} { raise $d; return }
    toplevel $d
    wm title $d "Create figures"
    wm transient $d $w
    if {$S(fig_dir) eq ""} { set S(fig_dir) [pwd] }
    foreach {k t} $tabs { if {![info exists F($k)]} { set F($k) [expr {$k eq $S(tab)}] } }
    set f [ttk::frame $d.f -padding 12]
    pack $f -fill both -expand 1
    set A [_section $f.where "Where" -padding {8 6}]
    pack ${A}_sec -side top -fill x
    set df [ttk::frame $A.df]
    ttk::entry $df.e -textvariable ::VMDance::GUI::S(fig_dir) -width 34
    ttk::button $df.b -text "Browse…" -command [list apply {{d} {
        set x [tk_chooseDirectory -parent $d -title "Folder of the figures" -initialdir $::VMDance::GUI::S(fig_dir)]
        if {$x ne ""} { set ::VMDance::GUI::S(fig_dir) $x }
    }} $d]
    pack $df.e -side left -fill x -expand 1
    pack $df.b -side left -padx {4 0}
    _row $A 0 "Folder" $df
    ttk::entry $A.p -textvariable ::VMDance::GUI::S(fig_prefix) -width 20
    _row $A 1 "File names" $A.p "Each figure is <name>_<plot>.pdf (.png, .eps)"
    grid columnconfigure $A 1 -weight 1
    set P [_section $f.plots "Plots" -padding {8 6}]
    pack ${P}_sec -side top -fill x -pady {10 0}
    set i 0
    foreach {k t} $tabs {
        ttk::checkbutton $P.c$k -text $t -variable ::VMDance::GUI::F($k)
        # (a plot with nothing to draw: no scan, or no cluster)
        if {![::VMDance::Plots::has_data $k]} { $P.c$k state disabled }
        grid $P.c$k -row [expr {$i / 3}] -column [expr {$i % 3}] -sticky w -padx {0 10} -pady 1
        incr i
    }
    set Z [_section $f.size "Size and format" -padding {8 6}]
    pack ${Z}_sec -side top -fill x -pady {10 0}
    set sf [ttk::frame $Z.sf]
    ttk::entry $sf.w -textvariable ::VMDance::GUI::S(fig_width) -width 5
    ttk::label $sf.x -text "×"
    ttk::entry $sf.h -textvariable ::VMDance::GUI::S(fig_height) -width 5
    ttk::label $sf.u -text "points"
    pack $sf.w $sf.x $sf.h $sf.u -side left -padx {0 4}
    _row $Z 0 "Size" $sf
    set ff [ttk::frame $Z.ff]
    foreach fm {pdf png eps} { ttk::checkbutton $ff.$fm -text [string toupper $fm] -variable ::VMDance::GUI::S(fig_$fm); pack $ff.$fm -side left -padx {0 8} }
    _row $Z 1 "Formats" $ff
    ttk::entry $Z.dpi -textvariable ::VMDance::GUI::S(fig_dpi) -width 5
    _row $Z 2 "PNG dpi" $Z.dpi
    grid configure $Z.dpi -sticky w
    if {[::VMDance::Figures::ghostscript] eq ""} {
        ttk::label $Z.gs -text "Ghostscript was not found: EPS only." -style Muted.TLabel
        grid $Z.gs -row 3 -column 0 -columnspan 2 -sticky w
    }
    set b [ttk::frame $f.b]
    pack $b -side top -fill x -pady {12 0}
    ttk::button $b.ok -text "Create" -command ::VMDance::GUI::_figures_go
    ttk::button $b.cancel -text "Cancel" -command [list destroy $d]
    pack $b.cancel $b.ok -side right -padx {6 0}
    ::VMDance::Theme::style_tree $d
    bind $d <Escape> [list destroy $d]
}
proc ::VMDance::GUI::_figures_go {} {
    variable w; variable S; variable F; variable tabs
    set d $w.figures
    if {[busy]} { _error "A job is running: create the figures when it has ended, or cancel it." $d; return }
    set plots [lmap {k t} $tabs {expr {$F($k) && [::VMDance::Plots::has_data $k] ? $k : [continue]}}]
    set fmts [lmap fm {pdf png eps} {expr {$S(fig_$fm) ? $fm : [continue]}}]
    if {![llength $plots]} { _error "Choose a plot." $d; return }
    if {![llength $fmts]} { _error "Choose a format." $d; return }
    # (a space pasted after the folder would make a folder of its own)
    set dir [string trim $S(fig_dir)]
    $d configure -cursor watch
    update
    set err [catch {::VMDance::Figures::api $dir -plots $plots -formats $fmts -width [string trim $S(fig_width)] \
        -height [string trim $S(fig_height)] -dpi [string trim $S(fig_dpi)] -prefix [string trim $S(fig_prefix)]} files]
    if {[winfo exists $d]} { $d configure -cursor "" }
    redraw
    if {$err} { _error "Not created:\n$files" $d; return }
    destroy $d
    status "[llength $files] file[expr {[llength $files] == 1 ? "" : "s"}] written in $dir."
}

# The current plot as a figure (File ▸ Quick export).
proc ::VMDance::GUI::save_current_plot {} {
    variable w; variable S
    if {[busy]} return
    set key [_current_tab]
    set f [tk_getSaveFile -parent $w -title "The current plot" -initialfile "vmdance_$key.pdf" \
        -filetypes {{"PDF" {.pdf}} {"PNG" {.png}} {"EPS" {.eps}}}]
    if {$f eq ""} return
    set ext [string tolower [string range [file extension $f] 1 end]]
    if {$ext ni {pdf png eps}} { set ext pdf; append f .pdf }
    set c $w.pw.right.nb.$key.c
    lassign [::VMDance::Plot::size $c] cw ch
    if {[catch {::VMDance::Figures::export_plot $key [file rootname $f] [list $ext] [expr {max(240, $cw)}] [expr {max(240, $ch)}] $S(fig_dpi)} r]} {
        _error $r
    } else {
        status "Written: [join $r {, }]."
    }
    redraw
}

# The 3D view as a picture.
proc ::VMDance::GUI::render_view_dialog {} {
    variable w
    if {[busy]} return
    set f [tk_getSaveFile -parent $w -title "The 3D view" -defaultextension .png -filetypes {{"PNG" {.png}}} -initialfile clusters_3d.png]
    if {$f eq ""} return
    set r [expr {"TachyonInternal" in [render list] ? "TachyonInternal" : "snapshot"}]
    if {[catch {::VMDance::Figures::render_3d $f $r} err]} { _error "Not rendered:\n$err"; return }
    status "The 3D view ($r): $f."
}
