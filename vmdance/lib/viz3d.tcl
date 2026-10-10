#
# VMDance - the clusters in VMD's 3D window (no Tk dependency)
#
# Every drawing is a representation of the plugin's own, added to the
# clustered molecule (the picks: to theirs) and found again by its name
# (mol repname): the plugin never changes or deletes another
# representation, and never writes the molecule's data (no user field, no
# colour scale).
#   colour       one representation coloured by the cluster of VMD's
#                current frame (that of the analysed frame at or before
#                it); it follows the trajectory as it plays
#   reps         the representatives: one representation per cluster,
#                drawn at its representative frame, in its colour
#   overlay      the selected clusters' frames nearest their representative
#                (at most -top), or a list of frames, all drawn at once
#   picks        the frames picked without clustering, on their molecule
# A drawing is made only on a molecule that has the frames it draws at
# their numbers (Results::frames_ok, picks_ok), and watched: when that
# molecule's frames change under it (frames deleted, a trajectory loaded),
# it is made again, or withdrawn, at the next change of its frame (VMD says
# nothing of a deletion), as a figure is rendered, and as the window sees
# the molecules change.
# A cluster has a VMD colour id (colour_id) and, for the plots, a darker
# tone of the same hue (colour_hex: InteractionView's flat colours first):
# the plots and the 3D window agree on a cluster's hue without the plugin
# changing VMD's colours. Noise, and frames that were not clustered, are
# grey.
#

namespace eval ::VMDance::Viz {
    # VMD colour ids of the clusters, distinct colours first (no grey,
    # silver, white or black)
    variable ids {0 1 7 3 11 10 4 9 12 5 15 13 14 20 23 25 27 29 31 22 18 26 32 17 19 21 24 28 30}
    variable noise_id 2
    # the plots' tones, in the order of the ids (blue, red, green, orange,
    # purple, cyan, yellow, pink, lime, tan, iceblue, mauve, ochre, green3,
    # blue2, violet, magenta, red2, orange2, cyan3, yellow3, violet2,
    # orange3, yellow2, green2, cyan2, blue3, magenta2, red3)
    variable hex {#3498db #e74c3c #27ae60 #d35400 #9b59b6 #16a085 #c9a227 #d4739a #7aa33b #a0785a
                  #5b9bc9 #8e6c8a #b0822e #1e7b4f #2e5c9a #6f42a8 #b0407e #a93226 #c0661f #117a72
                  #9c8a1f #7d3c98 #a04000 #b7950b #52a05a #3aa0a8 #1f4e79 #8e2d6e #7b241c}
    variable noise_hex #95a5a6
    variable styles {NewCartoon Licorice Lines Tube Trace CPK VDW}
    variable o
    array set o {colour 0 reps 0 overlay 0 picks 0 style NewCartoon sel "" top 10 frames "" material Opaque}
    variable owned {}           ;# {mol repname role} of the plugin's representations
    variable traced {}          ;# the molecules whose frame is traced
    variable drawn {}           ;# molecule -> {mol numframes files} it was drawn on
    variable pending ""         ;# the check after its frames changed (after)
    variable listeners {}
    variable last_id ""
    variable notes {}           ;# what the last draw drew otherwise than asked (draw's note)
    variable told {}            ;# the notes of the draw before (said once on the console)
}

proc ::VMDance::Viz::colour_id {c} {
    variable ids; variable noise_id
    if {$c eq "" || $c < 0} { return $noise_id }
    lindex $ids [expr {$c % [llength $ids]}]
}
proc ::VMDance::Viz::colour_hex {c} {
    variable hex; variable noise_hex
    if {$c eq "" || $c < 0} { return $noise_hex }
    lindex $hex [expr {$c % [llength $hex]}]
}

proc ::VMDance::Viz::listen {cmd} { variable listeners; if {$cmd ni $listeners} { lappend listeners $cmd } }
proc ::VMDance::Viz::unlisten {cmd} {
    variable listeners
    set i [lsearch -exact $listeners $cmd]
    if {$i >= 0} { set listeners [lreplace $listeners $i $i] }
}
proc ::VMDance::Viz::_notify {} {
    variable listeners
    foreach l $listeners { catch {uplevel #0 $l} }
}

# The clustered molecule, when it is loaded with the frames that were
# clustered (-1 otherwise: why says which).
proc ::VMDance::Viz::_mol {} {
    if {![::VMDance::Results::has_data]} { return -1 }
    set m [dict get [::VMDance::Results::request] mol]
    expr {[::VMDance::Mol::exists $m] && [::VMDance::Results::frames_ok] ? $m : -1}
}
proc ::VMDance::Viz::why {} {
    if {![::VMDance::Results::has_data]} { return "no clustering" }
    set m [dict get [::VMDance::Results::request] mol]
    if {![::VMDance::Mol::exists $m]} { return "the clustered molecule is not loaded" }
    _why $m [::VMDance::Results::frames] [::VMDance::_get $::VMDance::Results::A molecule {}] "the clustered frames" "cluster it again" \
        [::VMDance::Results::frames_extra]
}
# The molecule of the picked frames, when it is loaded with the frames they
# were picked from (-1 otherwise: picks_why says which).
proc ::VMDance::Viz::_picks_mol {} {
    set p $::VMDance::Results::picks
    if {![dict size $p]} { return -1 }
    set m [dict get $p input mol]
    expr {[::VMDance::Mol::exists $m] && [::VMDance::Results::picks_ok] ? $m : -1}
}
proc ::VMDance::Viz::picks_why {} {
    set p $::VMDance::Results::picks
    if {![dict size $p]} { return "no frames picked" }
    set m [dict get $p input mol]
    if {![::VMDance::Mol::exists $m]} { return "the molecule of the picked frames is not loaded" }
    # (those up to the last picked one: frames deleted after it leave them)
    _why $m [lrange [dict get $p frames] 0 [expr {[::VMDance::Results::_span $p] - 1}]] [dict get $p molecule] \
        "the frames the picks were made from" "pick them again" [::VMDance::Results::picks_extra]
}
# Why molecule m does not have frames (what) of a record rec: fewer frames
# than them; extra frames before them that it did not have then (a PDB's
# own frame read again: deleting them gives them back); as many from files
# of the same names as then (other coordinates at their numbers); or else
# (frames deleted or added).
proc ::VMDance::Viz::_why {m frames rec what fix {extra 0}} {
    set nf [molinfo $m get numframes]
    if {[lindex $frames end] >= $nf} {
        return "molecule $m no longer has $what (it has $nf frames: frames deleted): $fix"
    }
    if {$extra > 0} {
        return "molecule $m no longer has $what at their numbers: it has $extra frame[expr {$extra == 1 ? "" : "s"}] before them that it did not have then (a PDB's own frame?): delete [expr {$extra == 1 ? "it" : "them"}] (animate delete beg 0 end [expr {$extra - 1}] $m)"
    }
    if {$nf == [::VMDance::_get $rec numframes ""] &&
        ([lindex [molinfo $m get filename] 0] eq [::VMDance::_get $rec files ""] ||
         [::VMDance::Mol::paths $m] eq [::VMDance::_get $rec paths ""])} {
        return "molecule $m does not have $what at their numbers (another trajectory under the same names, its files changed, frames deleted and others added, or its coordinates changed since): load the files they were read from, or $fix"
    }
    return "molecule $m no longer has $what at their numbers (frames deleted before them, its trajectory loaded otherwise, or its coordinates changed and frames added since): $fix"
}

proc ::VMDance::Viz::get {} { variable o; array get o }

# Change what is drawn: colour reps overlay picks (0/1), style, sel (the
# atoms drawn; "" the residues of the clustered atoms), top (frames of
# the overlay), frames (the overlay's frames instead of the selection's,
# as "0-100,500"), material. Returns the options.
proc ::VMDance::Viz::configure {args} {
    variable o; variable styles
    if {[llength $args] % 2} { error "options come in name value pairs" }
    array set new [array get o]
    foreach {k v} $args {
        set k [string trimleft $k -]
        if {![info exists o($k)]} { error "unknown option -$k (valid: [join [lmap n [lsort [array names o]] {string cat - $n}] {, }])" }
        switch -- $k {
            colour - reps - overlay - picks {
                if {![string is boolean -strict $v]} { error "-$k must be 0 or 1 (got \"$v\")" }
                set v [expr {$v ? 1 : 0}]
            }
            style { if {$v ni $styles} { error "-style must be one of [join $styles {, }] (got \"$v\")" } }
            top {
                if {![regexp {^[1-9][0-9]*$} $v] || $v > 1000} { error "-top must be a whole number from 1 to 1000 (got \"$v\")" }
            }
            frames {
                set m [_mol]
                parse_frames $v [expr {$m >= 0 ? [molinfo $m get numframes] : ""}]
            }
            sel {
                set v [string trim $v]
                set m [_sel_mol]
                if {$v ne "" && $m >= 0 && [catch {::VMDance::Mol::atoms $m $v} err]} { error "-sel: $err" }
            }
            material {
                if {$v ni [material list]} { error "-material must be one of VMD's materials ([join [material list] {, }])" }
            }
        }
        set new($k) $v
    }
    array set o [array get new]
    draw
    _notify
    array get o
}

# The molecule a -sel is checked on: the clustered one while it is loaded
# (its atoms are those drawn, whatever its frames), else the top one (VMD
# reads a selection text alike on every molecule: a typo was kept until a
# clustering, then drawn as the default atoms); -1 when none is loaded.
proc ::VMDance::Viz::_sel_mol {} {
    if {[::VMDance::Results::has_data]} {
        set m [dict get [::VMDance::Results::request] mol]
        if {[::VMDance::Mol::exists $m]} { return $m }
    }
    molinfo top
}

# "0-100,500 900-1000" as a sorted list of frames (spaces around a dash
# and leading zeros taken: "0 - 3", "008-010"); with nf, a frame past the
# molecule's last is an error.
proc ::VMDance::Viz::parse_frames {text {nf ""}} {
    set out {}
    regsub -all {\s*-\s*} [string trim $text] - text
    set total 0
    foreach part [split [string map {, " "} $text]] {
        if {$part eq ""} continue
        if {[regexp {^([0-9]{1,9})-([0-9]{1,9})$} $part -> a b]} {
            # (scan: "008" is 8, which expr would read as octal)
            scan $a %d a; scan $b %d b
            if {$b < $a} { error "frames: the range \"$part\" ends before it starts" }
            # (checked before they are made)
            if {$nf ne "" && $b >= $nf} { error "frames: frame $b is past the last frame of the molecule ([expr {$nf - 1}])" }
            incr total [expr {$b - $a + 1}]
            if {$b - $a > 100000 || $total > 1000000} { error "frames: \"$part\": too many frames (at most 100 000 a range)" }
            for {set f $a} {$f <= $b} {incr f} { lappend out $f }
        } elseif {[regexp {^[0-9]{1,9}$} $part]} {
            lappend out [scan $part %d]
        } else {
            error "frames: \"$part\" is not a frame or a range (write them as 0-100,500)"
        }
    }
    set out [lsort -integer -unique $out]
    if {$nf ne "" && [llength $out] && [lindex $out end] >= $nf} {
        error "frames: frame [lindex $out end] is past the last frame of the molecule ([expr {$nf - 1}])"
    }
    return $out
}

#---------------------------------------------------------------------------
# The plugin's representations
#---------------------------------------------------------------------------

# Delete the plugin's representations of role ("" all).
proc ::VMDance::Viz::_remove {{role ""}} {
    variable owned
    set keep {}
    foreach e $owned {
        lassign $e m name r
        if {$role ne "" && $r ne $role} { lappend keep $e; continue }
        if {[::VMDance::Mol::exists $m]} {
            set i [mol repindex $m $name]
            if {$i >= 0} { mol delrep $i $m }
        }
    }
    set owned $keep
}

# Add a representation; returns its index. The settings VMD's "mol
# addrep" takes are given explicitly (and put back), so that neither the
# user's current settings nor ours leak.
proc ::VMDance::Viz::_add {m role sel style colour material frames} {
    variable owned
    mol selection $sel
    mol representation $style
    mol color ColorID $colour
    mol material $material
    mol addrep $m
    set i [expr {[molinfo $m get numreps] - 1}]
    mol drawframes $m $i $frames
    lappend owned [list $m [mol repname $m $i] $role]
    return $i
}

# The atoms drawn on molecule m: -sel, or the residues of the atoms of q
# (the clustering's request, the picks' input: the atoms read, not those
# its text selects now); -sel that selects nothing there, or is no
# selection (kept when no molecule was loaded to check it): the latter,
# said (a note).
proc ::VMDance::Viz::_atoms {m q {read clustered}} {
    variable o
    if {$o(sel) ne ""} {
        if {[catch {llength [::VMDance::Mol::atoms $m $o(sel)]} n]} {
            _note "-sel: $n: the residues of the atoms $read are drawn"
        } elseif {$n} {
            return $o(sel)
        } else {
            _note "-sel: \"$o(sel)\" matches no atom of molecule $m: the residues of the atoms $read are drawn"
        }
    }
    return "same residue as ([::VMDance::_get $q atoms [dict get $q sel]])"
}
# What is drawn otherwise than asked: draw's note, and once on the console.
proc ::VMDance::Viz::_note {text} {
    variable notes; variable told
    if {$text in $notes} return
    lappend notes $text
    if {$text ni $told} { puts "VMDance) warning: the 3D drawing: $text" }
}

# Draw everything that is on, again: the clustering's on its molecule, the
# picks on theirs, each only while it has their frames.
proc ::VMDance::Viz::draw {} {
    variable o; variable drawn; variable pending; variable notes; variable told
    after cancel $pending
    set pending ""
    set told $notes
    set notes {}
    set m [_mol]
    set clu [expr {$m >= 0 && ($o(colour) || $o(reps) || $o(overlay))}]
    set pm [expr {$o(picks) ? [_picks_mol] : -1}]
    _remove
    set drawn {}
    if {$clu} { dict set drawn $m [::VMDance::Results::_state $m] }
    if {$pm >= 0} { dict set drawn $pm [::VMDance::Results::_state $pm] }
    _trace
    if {![dict size $drawn]} return
    # (the user's settings for new representations, put back)
    set keep [_mol_settings]
    try {
        if {$clu} { _draw_clusters $m [_atoms $m [::VMDance::Results::request]] }
        if {$pm >= 0} {
            set p $::VMDance::Results::picks
            _add $pm picks [_atoms $pm [dict get $p input] picked] $o(style) 3 $o(material) [_drawframes [dict get $p vmdframes]]
        }
    } finally {
        _mol_settings $keep
    }
    _frame_changed
}
proc ::VMDance::Viz::_draw_clusters {m sel} {
    variable o
    if {$o(colour)} {
        set f [molinfo $m get frame]
        _add $m colour $sel $o(style) [colour_id [::VMDance::Results::cluster_at $f]] $o(material) now
    }
    if {$o(reps)} {
        for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
            set rf [::VMDance::Results::rep_frame $c]
            if {$rf < 0 || $rf >= [molinfo $m get numframes]} continue
            _add $m reps $sel $o(style) [colour_id $c] $o(material) $rf
        }
    }
    if {$o(overlay)} { _draw_overlay $m $sel }
}
proc ::VMDance::Viz::_draw_overlay {m sel} {
    variable o
    set nf [molinfo $m get numframes]
    if {$o(frames) ne ""} {
        set all [parse_frames $o(frames)]
        set fl [lmap f $all {expr {$f < $nf ? $f : [continue]}}]
        # (frames given before a clustering, when there was no molecule
        # to check them on)
        set past [expr {[llength $all] - [llength $fl]}]
        if {$past} { _note "-frames: $past frame[expr {$past == 1 ? " is" : "s are"}] past the last of molecule $m ([expr {$nf - 1}]): not drawn" }
        if {[llength $fl]} {
            foreach f $fl { lappend byc([::VMDance::Results::cluster_at $f]) $f }
            foreach c [array names byc] { _add $m overlay $sel $o(style) [colour_id $c] $o(material) [_drawframes $byc($c)] }
        }
    } else {
        foreach c [::VMDance::Results::selected] {
            set fl [lmap f [::VMDance::Results::top $c $o(top)] {expr {$f < $nf ? $f : [continue]}}]
            if {[llength $fl]} { _add $m overlay $sel $o(style) [colour_id $c] $o(material) [_drawframes $fl] }
        }
    }
}
# Whether a molecule drawn on no longer is as it was drawn on (deleted, or
# its frames changed): then it is drawn again, or withdrawn (draw asks
# frames_ok and picks_ok again), and the window told.
proc ::VMDance::Viz::check {} {
    variable drawn; variable pending
    after cancel $pending
    set pending ""
    dict for {m st} $drawn {
        if {![::VMDance::Mol::exists $m] || [::VMDance::Results::_state $m] ne $st} {
            draw
            _notify
            return 1
        }
    }
    return 0
}

# VMD's drawframes wants a comma list.
proc ::VMDance::Viz::_drawframes {fl} { join $fl , }

# The settings "mol addrep" uses; with an argument, put them back. VMD
# has no getter for them: they are read from a representation added and
# deleted at once, on a molecule of the user's.
proc ::VMDance::Viz::_mol_settings {{keep ""}} {
    if {$keep ne ""} {
        lassign $keep sel rep col mat
        if {$sel ne ""} {
            mol selection $sel
            mol representation {*}$rep
            mol color {*}$col
            mol material $mat
        }
        return
    }
    set m [molinfo top]
    if {$m < 0 || [catch {
        mol addrep $m
        set i [expr {[molinfo $m get numreps] - 1}]
        lassign [molinfo $m get [list "selection $i" "rep $i" "color $i" "material $i"]] sel rep col mat
        mol delrep $i $m
    }]} { return [list "" "" "" ""] }
    list $sel $rep $col $mat
}

# The frame of every molecule drawn on is traced: the colouring follows
# it, and a change of its frames shows there.
proc ::VMDance::Viz::_trace {} {
    variable traced; variable drawn
    foreach m $traced { catch {trace remove variable ::vmd_frame($m) write ::VMDance::Viz::_frame_trace} }
    set traced [dict keys $drawn]
    foreach m $traced { trace add variable ::vmd_frame($m) write ::VMDance::Viz::_frame_trace }
}
# (frames deleted, or a trajectory loaded: its frames are not those drawn
# any more; checked once they stop changing — a trajectory loading changes
# the frame at each frame read, and runs the window's events in between —
# and the colouring grey until then)
proc ::VMDance::Viz::_frame_trace {name m op} {
    variable drawn; variable pending
    if {[dict exists $drawn $m] && [::VMDance::Mol::exists $m] && [::VMDance::Results::_state $m] eq [dict get $drawn $m]} {
        _frame_changed
        return
    }
    after cancel $pending
    set pending [after 300 ::VMDance::Viz::check]
    _colour_rep [colour_id ""]
}
proc ::VMDance::Viz::_frame_changed {} {
    variable o
    if {!$o(colour) || [_mol] < 0} return
    set m [dict get [::VMDance::Results::request] mol]
    _colour_rep [colour_id [::VMDance::Results::cluster_at [molinfo $m get frame]]]
}
proc ::VMDance::Viz::_colour_rep {id} {
    variable owned; variable last_id
    foreach e $owned {
        lassign $e m name role
        if {$role ne "colour" || ![::VMDance::Mol::exists $m]} continue
        set i [mol repindex $m $name]
        if {$i < 0} continue
        if {$id ne $last_id} {
            mol modcolor $i $m ColorID $id
            set last_id $id
        }
    }
}

# Everything off, the plugin's representations deleted (a new clustering,
# the molecule deleted, the plugin closed).
proc ::VMDance::Viz::reset {} {
    variable last_id ""; variable drawn {}; variable notes {}; variable pending
    after cancel $pending
    _remove
    _trace
}

# The results changed: draw again what is on (the selection moves the
# overlay of the selected clusters, and only it: every representation made
# again took seconds with a thousand representatives; all are made again
# when the frames moved under them).
proc ::VMDance::Viz::results_changed {what} {
    variable o; variable drawn; variable last_id ""
    switch -- $what {
        analysis - picks { draw }
        selection {
            if {!$o(overlay) || $o(frames) ne ""} return
            set m [_mol]
            if {$m < 0 || ![dict exists $drawn $m] || [dict get $drawn $m] ne [::VMDance::Results::_state $m]} { draw; return }
            _remove overlay
            set keep [_mol_settings]
            try {
                _draw_overlay $m [_atoms $m [::VMDance::Results::request]]
            } finally {
                _mol_settings $keep
            }
        }
    }
}
::VMDance::Results::listen ::VMDance::Viz::results_changed

# Go to a VMD frame of the clustered molecule.
proc ::VMDance::Viz::goto {f} {
    set m [_mol]
    if {$m < 0} { error [why] }
    _goto $m $f
}
# Go to a picked frame, on the picks' molecule (no clustering needed).
proc ::VMDance::Viz::goto_pick {f} {
    set m [_picks_mol]
    if {$m < 0} { error [picks_why] }
    if {![::VMDance::whole $f] || $f ni [dict get $::VMDance::Results::picks vmdframes]} {
        error "frame \"$f\" is not a picked frame (vmdance pick show lists them)"
    }
    _goto $m $f
}
proc ::VMDance::Viz::_goto {m f} {
    if {![::VMDance::whole $f] || $f >= [molinfo $m get numframes]} { error "molecule $m has no frame \"$f\"" }
    # (animate goto moves the active molecules only: an inactive one is set)
    if {[molinfo $m get active]} { animate goto $f } else { molinfo $m set frame $f }
    return $f
}
