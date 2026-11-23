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
    # VMD frees a selection's values one by one, and past about 100 000
    # single values its stack overflows: VMD crashes deleting the
    # selection (VMD 2.0 on Windows, a 2 MB stack: between 100 000 and
    # 120 000; Linux's 8 MB: about 700 000), and adding it as a
    # representation. A range "a to b" is one value: 40 000 of them, in
    # 120 000 words, are freed. The plugin hands VMD no text of more.
    variable max_values 50000
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
    _sel $m [vmd_text $m $text] $frame
}
proc ::VMDance::Mol::_sel {m text {frame ""}} {
    if {$frame eq ""} { return [uplevel #0 [list atomselect $m $text]] }
    uplevel #0 [list atomselect $m $text frame $frame]
}

# The text handed to VMD for a selection text (atomselect, mol selection):
# the same atoms, in few enough values (max_values). A long text has its
# lists of whole numbers written as ranges (compact); the plugin's own
# index list that is still too long (atoms scattered: the Cα of a large
# system) is named instead, "name CA and index 4 to 99990", where that
# selects exactly its atoms now (_named). Otherwise an error: VMD would
# crash. Texts kept (requests, sessions) are not changed.
proc ::VMDance::Mol::vmd_text {m text} {
    variable max_values
    # (a value is a character at least: a text no longer is handed as it is)
    if {[string length $text] <= $max_values} { return $text }
    set t [compact $text]
    set n [_items $t]
    if {$n <= $max_values} { return $t }
    if {[regexp {^index( (0|[1-9][0-9]*)( to (0|[1-9][0-9]*))?)+$} $t]} {
        set named [_named $m $t]
        if {$named ne ""} { return $named }
    }
    error "the selection lists $n separate values, more than VMD takes ($max_values: it crashes freeing about 100000): select the atoms by name, residue or range (e.g. \"protein and name CA\", \"index 0 to 999\")"
}

# A selection text with each list of whole numbers after index, serial or
# residue written as sorted ranges ("index 5 1 2 3 3" is "index 1 to 3 5"):
# the same atoms, since such a list is a set. Its words are read as
# _dynamic reads them (a quoted value is one word). A list is rewritten only
# when nothing could make it mean otherwise: its numbers decimal (VMD and
# Tcl read "010" differently), separated by spaces, "a to b" with a <= b,
# and followed by the end, ")", "and" or "or".
proc ::VMDance::Mol::compact {text} {
    set toks [regexp -all -indices -inline {"(?:[^"]|\\\\|\\")*"|'(?:[^']|\\\\|\\')*'|[$@]?[A-Za-z0-9_]+(?:['"][A-Za-z0-9_'"]*)?} $text]
    set n [llength $toks]
    set out ""
    set at 0
    for {set i 0} {$i < $n} {incr i} {
        lassign [lindex $toks $i] b e
        if {[string range $text $b $e] ni {index serial residue}} continue
        set vals {}
        set last $e
        set j [expr {$i + 1}]
        set ok 1
        while {$j < $n} {
            lassign [lindex $toks $j] b2 e2
            set v [string range $text $b2 $e2]
            if {![_spaces $text $last $b2] || ![regexp {^(0|[1-9][0-9]*)$} $v]} break
            set lo $v; set hi $v; set end $e2; set k [expr {$j + 1}]
            if {$k + 1 < $n} {
                lassign [lindex $toks $k] b3 e3
                lassign [lindex $toks $k+1] b4 e4
                set v4 [string range $text $b4 $e4]
                if {[string range $text $b3 $e3] eq "to" && [_spaces $text $e2 $b3] && [_spaces $text $e3 $b4]} {
                    if {![regexp {^(0|[1-9][0-9]*)$} $v4] || $v4 < $lo} { set ok 0; break }
                    set hi $v4; set end $e4; incr k 2
                }
            }
            lappend vals [list $lo $hi]
            set last $end
            set j $k
        }
        if {!$ok || [llength $vals] < 2} continue
        set rest [string trimleft [string range $text $last+1 end]]
        if {$rest ne "" && [string index $rest 0] ne ")" && ![regexp {^(and|or)(?![A-Za-z0-9_'"])} $rest]} continue
        append out [string range $text $at $e] " " [_ranges $vals]
        set at [expr {$last + 1}]
        set i [expr {$j - 1}]
    }
    append out [string range $text $at end]
}
# Only spaces between two words (their last and first characters).
proc ::VMDance::Mol::_spaces {text e b} {
    string is space [string range $text $e+1 $b-1]
}
# {lo hi} pairs as merged ranges: "1 to 3 5".
proc ::VMDance::Mol::_ranges {pairs} {
    set out {}
    set lo ""; set hi ""
    foreach p [lsort -integer -index 0 $pairs] {
        lassign $p a b
        if {$lo ne "" && $a <= $hi + 1} {
            if {$b > $hi} { set hi $b }
            continue
        }
        if {$lo ne ""} { lappend out [expr {$hi > $lo ? "$lo to $hi" : $lo}] }
        set lo $a; set hi $b
    }
    lappend out [expr {$hi > $lo ? "$lo to $hi" : $lo}]
    join $out
}
# The values VMD holds for a text, at most: its words, a range "a to b" one
# (counted, no list made).
proc ::VMDance::Mol::_items {text} {
    set w [regexp -all {"(?:[^"]|\\\\|\\")*"|'(?:[^']|\\\\|\\')*'|[$@]?[A-Za-z0-9_]+(?:['"][A-Za-z0-9_'"]*)?} $text]
    expr {$w - 2 * [regexp -all {(?:^|\s)to(?=\s)} $text]}
}
# An index text (index_text's) as the indices, sorted.
proc ::VMDance::Mol::_expand {t} {
    set out {}
    set w [lrange $t 1 end]
    for {set i 0} {$i < [llength $w]} {incr i} {
        set a [lindex $w $i]
        if {[lindex $w $i+1] eq "to"} {
            set b [lindex $w $i+2]
            for {set k $a} {$k <= $b} {incr k} { lappend out $k }
            incr i 2
        } else { lappend out $a }
    }
    lsort -integer -unique $out
}
# The atoms of an index text named by their atom names within their range,
# "name CA and index 4 to 99990", when that selects exactly them now; else
# "". (The names unquoted: VMD reads a double-quoted value as a regular
# expression.)
proc ::VMDance::Mol::_named {m t} {
    set idx [_expand $t]
    set lo [lindex $idx 0]
    set hi [lindex $idx end]
    set box [_sel $m "index $lo to $hi"]
    try { set rows [$box get {index name}] } finally { free $box }
    foreach i $idx { set want($i) 1 }
    set names [dict create]
    foreach r $rows {
        lassign $r i nm
        if {[info exists want($i)]} { dict set names $nm 1 }
    }
    if {[dict size $names] > 100} { return "" }
    foreach nm [dict keys $names] { if {![regexp {^[A-Za-z0-9_][A-Za-z0-9_']*$} $nm]} { return "" } }
    set text "name [join [lsort [dict keys $names]]] and index $lo to $hi"
    set s [_sel $m $text]
    try { set got [$s list] } finally { free $s }
    expr {$got eq $idx ? $text : ""}
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
    if {[catch {sel $m $text 0} s]} { error "invalid atom selection \"[shown $text]\": [_why $s]" }
    try { return [$s list] } finally { free $s }
}
# A selection text as a message shows it: a long one cut, saying how long.
proc ::VMDance::Mol::shown {text} {
    if {[string length $text] <= 200} { return $text }
    return "[string range $text 0 159]… ([string length $text] characters)"
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
