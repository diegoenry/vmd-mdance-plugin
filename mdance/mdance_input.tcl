# mdance_input.tcl - molecule chooser and atom selection, with live validation.
#
# VENDORED from the Interactions VMD plugin (same author, MIT), which had solved
# this properly already. Adapted rather than copied wholesale: namespaces are
# rewritten to ::mdance::input, the two-selection (A/B) model collapses to the
# single selection MDANCE clusters on, and the theme lookups become the three
# literal colours below, because this plugin has no theme layer.
#
#   interactions/gui/input.tcl        create_molecule_section, refresh_molecule_list,
#                                     get_selected_molid, mark_selection_dirty,
#                                     validate_selection, update_status_label
#   interactions/core/validation.tcl  validate_selection
#   interactions/utils/molecule.tcl   get_top, exists, num_frames
#   interactions/utils/format.tcl     count
#   interactions/gui/main_window.tcl  setup_molecule_trace, on_molecule_changed
#
# What this replaces: a free-text "Molecule ID" entry defaulting to the string
# "top", and an atom-selection entry that reported nothing at all until you
# pressed Run and a modal told you the selection was empty or malformed.

namespace eval ::mdance::input {
    variable mol_combo ""        ;# the molecule combobox widget, "" until built
    variable mol_list {}         ;# molids, parallel to the combobox display list
    variable sel_entry ""        ;# atom-selection entry
    variable sel_status ""       ;# the label under it that reports the count
    variable sel_after_id ""     ;# pending debounced validation
    variable traced 0            ;# whether the vmd_molecule trace is installed

    # Interactions takes these from Theme::get_color. Contrast against the
    # default ttk background is the only constraint that matters here.
    variable c_ok    "#1a7f37"
    variable c_warn  "#8a5a00"
    variable c_error "#b3261e"
}

# ============================================================
# Molecule resolution (interactions/utils/molecule.tcl)
# ============================================================

proc ::mdance::input::top_molid {} {
    if {[info commands molinfo] eq ""} { return -1 }
    if {[catch {molinfo top} molid]} { return -1 }
    if {![string is integer -strict $molid]} { return -1 }
    return $molid
}

proc ::mdance::input::mol_exists {molid} {
    if {![string is integer -strict $molid] || $molid < 0} { return 0 }
    if {[info commands molinfo] eq ""} { return 0 }
    if {[catch {molinfo list} molids]} { return 0 }
    return [expr {[lsearch -exact $molids $molid] >= 0}]
}

# selected_molid - the molecule the rest of the plugin should work on.
#
# ::mdance::gui::mol_selection stays the single source of truth because every
# run path and five test scenarios assign it directly. The combobox writes to
# it; this reads it back and falls through to VMD's top molecule when it holds
# the legacy "top" or names a molecule that has since been closed.
proc ::mdance::input::selected_molid {} {
    set want $::mdance::gui::mol_selection
    if {[string is integer -strict $want] && [mol_exists $want]} { return $want }
    return [top_molid]
}

# ============================================================
# Formatting (interactions/utils/format.tcl)
# ============================================================

proc ::mdance::input::count {n} {
    # Thousands separators: atom counts run to six figures and "128394" is
    # harder to read at a glance than "128,394".
    if {![string is integer -strict $n]} { return $n }
    set out ""
    set digits [string reverse $n]
    for {set i 0} {$i < [string length $digits]} {incr i 3} {
        if {$out ne ""} { set out ",$out" }
        set out "[string reverse [string range $digits $i [expr {$i + 2}]]]$out"
    }
    return $out
}

# ============================================================
# Validation (interactions/core/validation.tcl)
# ============================================================

# validate_selection - does this selection text resolve, and to how many atoms?
# Returns a dict: valid (0/1), atoms (int), message (string).
proc ::mdance::input::validate_selection {seltext {molid ""}} {
    if {[string trim $seltext] eq ""} {
        return [dict create valid 0 atoms 0 message "Empty selection"]
    }
    if {$molid eq ""} {
        set molid [top_molid]
    }
    if {$molid < 0} {
        return [dict create valid 0 atoms 0 message "No molecule loaded"]
    }
    if {[catch {set sel [atomselect $molid $seltext]} err]} {
        return [dict create valid 0 atoms 0 message "Invalid selection: $err"]
    }
    if {[catch {$sel num} natoms]} {
        catch {$sel delete}
        return [dict create valid 0 atoms 0 message "Invalid selection"]
    }
    catch {$sel delete}
    if {$natoms == 0} {
        return [dict create valid 1 atoms 0 message "Selection matches 0 atoms"]
    }
    return [dict create valid 1 atoms $natoms message "$natoms atoms"]
}

# ============================================================
# Widgets
# ============================================================

# build - the Molecule group: a chooser, the selection text, and the result of
# evaluating it. Packs into $parent, which the caller has already created.
proc ::mdance::input::build {parent} {
    variable mol_combo
    variable sel_entry
    variable sel_status

    # No "Molecule ID:" label -- the group header already says Molecule, and in
    # a 500 px column the label was pure width. (Same reasoning, and the same
    # comment, as interactions/gui/input.tcl:78.)
    set mol_combo [ttk::combobox $parent.combo -state readonly -width 18]

    # A manual refresh next to the chooser. The vmd_molecule trace below keeps
    # the LIST current on its own -- verified: loading a molecule adds it and
    # deleting one removes it, with no user action -- but it fires on molecules
    # appearing and disappearing, not on their contents changing. `mol addfile`
    # into an existing molecule takes it from 24 frames to 48 and the trace says
    # nothing, so the frame count in the label goes stale. This corrects it
    # without reopening the plugin.
    #
    # Sized to the glyph and stretched to the chooser's height (-sticky ns
    # below): at the default TButton padding it was a button-shaped object next
    # to a field, wider than it was tall and taller than the combobox, reading
    # as the primary control of the group rather than the small correction it
    # is.
    ttk::button $parent.refresh -text "\u21BB" -width 2 \
        -style Mdance.Icon.TButton \
        -command ::mdance::input::refresh_molecules

    ttk::label $parent.sell -text "Atom selection" -anchor w
    set sel_entry [ttk::entry $parent.sel -textvariable ::mdance::gui::atom_selection]
    set sel_status [ttk::label $parent.status -text "" -anchor w]

    # grid, not pack: the refresh button has to sit beside the chooser while
    # everything else stacks under it, and mixing -side right with the default
    # top-packing in one container put the selection label on the chooser's row.
    grid $mol_combo       -row 0 -column 0 -sticky ew
    grid $parent.refresh  -row 0 -column 1 -sticky ns -padx {4 0}
    grid $parent.sell     -row 1 -column 0 -columnspan 2 -sticky ew -pady {8 2}
    grid $sel_entry       -row 2 -column 0 -columnspan 2 -sticky ew
    grid $sel_status      -row 3 -column 0 -columnspan 2 -sticky ew -pady {2 0}
    grid columnconfigure $parent 0 -weight 1

    bind $mol_combo <<ComboboxSelected>> [list ::mdance::input::on_molecule_selected]

    # Typing revalidates on a 500 ms debounce; leaving the field or pressing
    # Return does it at once. Without the debounce every keystroke of
    # "protein and name CA" builds and destroys an atomselect.
    bind $sel_entry <KeyRelease> [list ::mdance::input::mark_dirty]
    bind $sel_entry <FocusOut>   [list ::mdance::input::validate_now]
    bind $sel_entry <Return>     [list ::mdance::input::validate_now]

    install_trace
    # The selection is also set programmatically -- by session load, by the
    # Frame Tools dialog, and by every test scenario -- so the status has to
    # follow the variable, not just the keyboard, or it reports the previous
    # selection's count against the current text.
    catch {trace remove variable ::mdance::gui::atom_selection write \
        [list ::mdance::input::on_selection_var]}
    trace add variable ::mdance::gui::atom_selection write \
        [list ::mdance::input::on_selection_var]

    refresh_molecules
    validate_now
    return $parent
}

# refresh_molecules - repopulate the chooser from VMD, keeping the current pick
# if that molecule is still loaded.
proc ::mdance::input::refresh_molecules {} {
    variable mol_combo
    variable mol_list

    if {$mol_combo eq "" || ![winfo exists $mol_combo]} return

    set prev [selected_molid]
    set mol_list {}
    set display {}
    if {[catch {molinfo list} molids]} { set molids {} }

    foreach molid $molids {
        lappend mol_list $molid
        if {[catch {molinfo $molid get name} name]} { set name "?" }
        if {[catch {molinfo $molid get numframes} nf]} { set nf 0 }
        if {[string length $name] > 18} {
            set name "[string range $name 0 15]..."
        }
        lappend display "$molid: $name ($nf)"
    }
    $mol_combo configure -values $display

    set idx -1
    if {[string is integer -strict $prev]} { set idx [lsearch -exact $mol_list $prev] }
    if {$idx < 0 && [llength $mol_list] > 0} {
        set idx [lsearch -exact $mol_list [top_molid]]
        if {$idx < 0} { set idx 0 }
    }
    if {$idx >= 0} {
        $mol_combo current $idx
        set ::mdance::gui::mol_selection [lindex $mol_list $idx]
    } else {
        $mol_combo set ""
        # Nothing loaded. Leave the legacy sentinel so a headless caller that
        # never opened the chooser still behaves as it always did.
        set ::mdance::gui::mol_selection "top"
    }
    validate_now
}

proc ::mdance::input::on_molecule_selected {} {
    variable mol_combo
    variable mol_list
    set idx [$mol_combo current]
    if {$idx >= 0 && $idx < [llength $mol_list]} {
        set ::mdance::gui::mol_selection [lindex $mol_list $idx]
    }
    validate_now
}

# ============================================================
# Validation feedback
# ============================================================

# on_selection_var - the variable changed under us. Debounced through the same
# path as typing, so a script that assigns it in a loop does not build one
# atomselect per assignment.
proc ::mdance::input::on_selection_var {args} {
    variable sel_status
    if {$sel_status eq "" || ![winfo exists $sel_status]} return
    mark_dirty
}

proc ::mdance::input::mark_dirty {} {
    variable sel_after_id
    if {$sel_after_id ne ""} { catch {after cancel $sel_after_id} }
    set sel_after_id [after 500 [list ::mdance::input::validate_now]]
}

proc ::mdance::input::validate_now {} {
    variable sel_entry
    variable sel_status
    variable sel_after_id
    variable c_ok
    variable c_warn
    variable c_error

    set sel_after_id ""
    if {$sel_status eq "" || ![winfo exists $sel_status]} return

    set seltext $::mdance::gui::atom_selection
    set result [validate_selection $seltext [selected_molid]]

    set valid [dict get $result valid]
    set atoms [dict get $result atoms]
    if {!$valid} {
        $sel_status configure -text "✖ [dict get $result message]" -foreground $c_error
    } elseif {$atoms == 0} {
        $sel_status configure -text "⚠ matches no atoms" -foreground $c_warn
    } else {
        $sel_status configure -text "✔ [count $atoms] atoms" -foreground $c_ok
    }
}

# ============================================================
# Keeping the chooser current
# ============================================================

# install_trace - VMD writes the global vmd_molecule array whenever a molecule
# is loaded, deleted or renamed. Debounced, because loading a trajectory fires
# it repeatedly. (interactions/gui/main_window.tcl:431)
proc ::mdance::input::install_trace {} {
    variable traced
    if {$traced} return
    if {![info exists ::vmd_molecule]} { return }
    catch {
        trace add variable ::vmd_molecule write [list ::mdance::input::on_vmd_molecule]
        set traced 1
    }
}

proc ::mdance::input::on_vmd_molecule {args} {
    variable mol_combo
    if {$mol_combo eq "" || ![winfo exists $mol_combo]} return
    after cancel [list ::mdance::input::refresh_molecules]
    after 100 [list ::mdance::input::refresh_molecules]
}
