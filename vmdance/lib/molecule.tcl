#
# VMDance - reading the molecule from VMD (no Tk dependency)
#
# Atom selections are made and deleted at the global level: VMD deletes a
# selection when the procedure that made it returns, wherever its handle is
# kept, and a delete from another procedure fails (and leaves the
# selection). Every selection the plugin makes is deleted by it, also on
# errors and on Cancel. Coordinates are read, never moved: a fit is
# computed on the values (Coords).
#

namespace eval ::VMDance::Mol {
    # selection keywords whose value can change from frame to frame: a
    # clustering needs the same atoms in every frame
    variable dynamic_words {within exwithin pbwithin nearest x y z vx vy vz ufx ufy ufz
        user user2 user3 user4 phi psi pucker structure sasa}
}

proc ::VMDance::Mol::exists {m} {
    expr {[string is integer -strict $m] && $m in [molinfo list]}
}

# A molecule id from "top" or a number; an error names the option.
proc ::VMDance::Mol::resolve {what m} {
    if {$m eq "top"} {
        set m [molinfo top]
        if {$m < 0} { error "$what: no molecule loaded" }
    }
    if {![exists $m]} {
        set l [molinfo list]
        error "$what: no molecule \"$m\" ([expr {[llength $l] ? "loaded: [join $l {, }]" : "none is loaded"}])"
    }
    return $m
}

proc ::VMDance::Mol::sel {m text {frame ""}} {
    if {$frame eq ""} { return [uplevel #0 [list atomselect $m $text]] }
    uplevel #0 [list atomselect $m $text frame $frame]
}
proc ::VMDance::Mol::free {args} {
    foreach s $args {
        if {$s ne ""} { catch {uplevel #0 [list $s delete]} }
    }
}

# The first word of a selection text that can match other atoms in other
# frames ("" when there is none). Its words are read as VMD's lexer reads
# them: a quoted value ("…" or '…', with \" and \' in it) is never a
# keyword (chain "x", segname 'y': VMD needs the quotes there); a quote
# after a letter or digit is part of a name (C5', O5': no quoted value
# between them); $name and @name are words of their own. A macro is read as
# its text (atomselect macro near {within 5 of …}): its name is the word.
proc ::VMDance::Mol::dynamic {text} {
    set macros {}
    if {[info commands ::atomselect] ne ""} { foreach n [::atomselect macro] { dict set macros $n [::atomselect macro $n] } }
    _dynamic $text $macros
}
proc ::VMDance::Mol::_dynamic {text macros} {
    variable dynamic_words
    foreach w [regexp -all -inline {"(?:[^"]|\\\\|\\")*"|'(?:[^']|\\\\|\\')*'|[$@]?[A-Za-z0-9_]+(?:['"][A-Za-z0-9_'"]*)?} $text] {
        if {$w in $dynamic_words} { return $w }
        # (each macro read once: one that names itself ends)
        if {[dict exists $macros $w] && [_dynamic [dict get $macros $w] [dict remove $macros $w]] ne ""} { return $w }
    }
    return ""
}

proc ::VMDance::Mol::_why {msg} {
    regsub {^atomselect: } $msg "" msg
    string trim [lindex [split $msg \n] 0]
}

# The atom indices of a selection text (at frame 0); an invalid text is an
# error naming it.
proc ::VMDance::Mol::atoms {m text} {
    if {[catch {sel $m $text 0} s]} { error "invalid atom selection \"$text\": [_why $s]" }
    try { return [$s list] } finally { free $s }
}

# Selection text for a list of atom indices, with runs written "a to b"
# (VMD parses that much faster than the numbers one by one).
proc ::VMDance::Mol::index_text {indices} {
    if {![llength $indices]} { return "none" }
    set out {}
    set lo ""; set hi ""
    foreach i [lsort -integer -unique $indices] {
        if {$lo eq ""} { set lo $i; set hi $i; continue }
        if {$i == $hi + 1} { set hi $i; continue }
        lappend out [expr {$hi > $lo ? "$lo to $hi" : $lo}]
        set lo $i; set hi $i
    }
    lappend out [expr {$hi > $lo ? "$lo to $hi" : $lo}]
    return "index [join $out]"
}

# The VMD frames first..last (-1: the last frame) every step-th, checked;
# an error names the option.
proc ::VMDance::Mol::frames {m first last step {what ""}} {
    set p [expr {$what eq "" ? "" : "$what: "}]
    foreach {k v} [list -first $first -last $last -step $step] {
        # (expr would compare a mistyped number as a string: "1o" < 5, and
        # read 010 as octal 8, 0x10 as 16)
        if {![regexp {^-?(0|[1-9][0-9]*)$} $v]} { error "${p}$k must be a whole number (got \"$v\")" }
    }
    set nf [molinfo $m get numframes]
    if {$nf < 1} { error "${p}molecule $m has no frames" }
    if {$last == -1} { set last [expr {$nf - 1}] }
    if {$first < 0 || $first >= $nf} { error "${p}-first must be a frame of molecule $m: 0 to [expr {$nf - 1}] (got $first)" }
    if {$last < $first || $last >= $nf} { error "${p}-last must be a frame from -first ($first) to [expr {$nf - 1}], or -1 for the last (got $last)" }
    if {$step < 1} { error "${p}-step must be 1 or more (got $step)" }
    set out {}
    for {set f $first} {$f <= $last} {incr f $step} { lappend out $f }
    return $out
}

# What a molecule is and the files it was read from (sessions, exports):
# files as VMD keeps them (as typed: "sys.pdb" is of the folder VMD was in
# then, which it does not keep), and paths, the same in full, of VMD's
# folder of now (a session is opened from any folder; after a cd they name
# another, and sessions try the names as typed too).
proc ::VMDance::Mol::record {m} {
    if {![exists $m]} { return {} }
    dict create name [molinfo $m get name] numatoms [molinfo $m get numatoms] \
        numframes [molinfo $m get numframes] \
        files [lindex [molinfo $m get filename] 0] types [lindex [molinfo $m get filetype] 0] \
        paths [paths $m]
}
# The files of a molecule in full, of VMD's folder of now ("" when it is not
# loaded; a PDB code that VMD downloaded is no file, and is kept as it is).
proc ::VMDance::Mol::paths {m} {
    if {![exists $m]} { return "" }
    lmap f [lindex [molinfo $m get filename] 0] t [lindex [molinfo $m get filetype] 0] {
        if {$t eq "webpdb" || [catch {file normalize $f} p]} { set f } else { set p }
    }
}

# The molecules with atoms, as {molid label} (the window's chooser).
proc ::VMDance::Mol::choices {} {
    set out {}
    foreach m [molinfo list] {
        if {[molinfo $m get numatoms] == 0} continue
        set nf [molinfo $m get numframes]
        lappend out $m "$m: [molinfo $m get name] ($nf frame[expr {$nf == 1 ? "" : "s"}])"
    }
    return $out
}
