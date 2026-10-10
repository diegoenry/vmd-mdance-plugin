#
# VMDance - a JSON reader for the backend's output (no Tk dependency)
#
# The backend writes JSON; it is read as data, never evaluated. Objects
# become dicts, arrays lists, strings and numbers their text, true and
# false 1 and 0. null, and the NaN and Infinity that some writers put in
# place of a non-finite number, become "" (a value that is not there): the
# checks that follow (Backend::check_*) treat "" as missing.
#
# The text is cut into tokens by one regular expression and the tokens are
# read in order: a 100 000-frame label array takes a fraction of a second.
#

namespace eval ::VMDance::Json {
    variable T {}
    variable i 0
    variable n 0
    variable depth 0
    # one token: an array of numbers only (read whole: label arrays are
    # long), a string, a number, a word, a punctuation mark, or any other
    # character (an error). The scan goes left to right: brackets inside a
    # string are the string's.
    variable re {\[\s*-?[0-9][-+0-9.eE]*(?:\s*,\s*-?[0-9][-+0-9.eE]*)*\s*\]|"(?:[^"\\]|\\.)*"|[-+0-9.eE]+|[A-Za-z]+|[^\s]}
    # a JSON number (no leading zeros, "1." or ".5": Tcl reads 010 as octal)
    variable num {^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$}
    variable numcore {-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?}
}

# The value of a JSON text; an error says where it went wrong.
proc ::VMDance::Json::parse {text} {
    variable T; variable i; variable n; variable re; variable depth
    set T [regexp -all -inline -- $re $text]
    set n [llength $T]
    set i 0
    set depth 0
    if {!$n} { error "empty JSON text" }
    try {
        set v [_value]
        if {$i < $n} { error "unexpected \"[_show [lindex $T $i]]\" after the value (token [expr {$i + 1}])" }
        return $v
    } finally {
        set T {}
    }
}

proc ::VMDance::Json::_show {tok} {
    if {[string length $tok] > 20} { return "[string range $tok 0 16]…" }
    return $tok
}

proc ::VMDance::Json::_next {} {
    variable T; variable i; variable n
    if {$i >= $n} { error "the JSON text ends too early (truncated?)" }
    set t [lindex $T $i]
    incr i
    return $t
}

proc ::VMDance::Json::_value {} {
    variable depth
    set t [_next]
    switch -- $t {
        "\{" {
            if {[incr depth] > 64} { error "JSON nested too deeply" }
            set d [dict create]
            set t [_next]
            if {$t ne "\}"} {
                while 1 {
                    if {[string index $t 0] ne "\""} { error "expected a key, found \"[_show $t]\"" }
                    set k [_string $t]
                    if {[_next] ne ":"} { error "expected \":\" after the key \"$k\"" }
                    dict set d $k [_value]
                    set t [_next]
                    if {$t eq "\}"} break
                    if {$t ne ","} { error "expected \",\" or \"\}\" in an object, found \"[_show $t]\"" }
                    set t [_next]
                }
            }
            incr depth -1
            return $d
        }
        "\[" {
            if {[incr depth] > 64} { error "JSON nested too deeply" }
            set l {}
            variable T; variable i; variable num
            # an empty array
            if {[lindex $T $i] eq "\]"} { incr i; incr depth -1; return {} }
            while 1 {
                # (numbers inline: label arrays are long)
                set t [lindex $T $i]
                if {[regexp $num $t]} {
                    lappend l $t
                    incr i
                } else {
                    lappend l [_value]
                }
                set t [_next]
                if {$t eq "\]"} break
                if {$t ne ","} { error "expected \",\" or \"\]\" in an array, found \"[_show $t]\"" }
            }
            incr depth -1
            return $l
        }
        true { return 1 }
        false { return 0 }
        null - NaN - Infinity { return "" }
        - {
            # (-Infinity, -NaN: two tokens)
            variable T; variable i
            if {[lindex $T $i] in {Infinity NaN}} { incr i; return "" }
        }
    }
    set c [string index $t 0]
    if {$c eq "\[" && [string length $t] > 1} {
        # an array of numbers, one token: its numbers checked in one regexp
        variable numcore; variable num
        if {$depth >= 64} { error "JSON nested too deeply" }
        set l [string map {, " "} [string range $t 1 end-1]]
        if {![regexp "^\\s*${numcore}(\\s+${numcore})*\\s*\$" $l]} {
            foreach v $l { if {![regexp $num $v]} { error "bad number \"[_show $v]\"" } }
            error "bad number in an array"
        }
        return [lrange $l 0 end]
    }
    if {$c eq "\""} { return [_string $t] }
    if {[string is digit $c] || $c in {- + . e E}} {
        variable num
        if {![regexp $num $t]} { error "bad number \"[_show $t]\"" }
        return $t
    }
    error "unexpected \"[_show $t]\""
}

# The text of a JSON string token (quotes removed, escapes read).
proc ::VMDance::Json::_string {t} {
    # (a lone quote: a string that does not end)
    if {[string length $t] < 2 || [string index $t end] ne "\""} { error "a JSON string does not end (truncated?)" }
    set s [string range $t 1 end-1]
    if {[string first \\ $s] < 0} { return $s }
    set out ""
    set k 0
    set len [string length $s]
    while {$k < $len} {
        set j [string first \\ $s $k]
        if {$j < 0} { append out [string range $s $k end]; break }
        append out [string range $s $k [expr {$j - 1}]]
        set e [string index $s [expr {$j + 1}]]
        switch -- $e {
            \" { append out \" }
            \\ { append out \\ }
            / { append out / }
            b { append out \b }
            f { append out \f }
            n { append out \n }
            r { append out \r }
            t { append out \t }
            u {
                set h [string range $s [expr {$j + 2}] [expr {$j + 5}]]
                if {![regexp {^[0-9a-fA-F]{4}$} $h]} { error "bad \\u escape in a JSON string" }
                append out [format %c [scan $h %x]]
                incr j 4
            }
            default { error "bad escape \\$e in a JSON string" }
        }
        set k [expr {$j + 2}]
    }
    return $out
}
