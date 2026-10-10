# A procedure-level profiler for the plugin: every procedure under
# ::VMDance is wrapped, and its calls and inclusive time (wall clock,
# a job's waits included) are counted. The wrapper costs about a
# microsecond a call: a procedure called 100 000 times shows it.
#   source tests/profile/prof.tcl; prof::start; …; prof::report "title"
namespace eval ::prof {
    variable T; variable N
    variable wrapped {}
}
proc ::prof::_procs {ns} {
    set out [info procs ${ns}::*]
    foreach c [namespace children $ns] { lappend out {*}[_procs $c] }
    return $out
}
proc ::prof::start {{ns ::VMDance}} {
    variable wrapped
    foreach p [_procs $ns] {
        if {[string match *__prof $p] || $p in $wrapped} continue
        rename $p ${p}__prof
        proc $p args [string map [list %P [list $p]] {
            set t0 [clock microseconds]
            set code [catch {uplevel 1 [list %P__prof {*}$args]} r opts]
            set dt [expr {[clock microseconds] - $t0}]
            if {[info exists ::prof::T(%P)]} { incr ::prof::T(%P) $dt; incr ::prof::N(%P) } else { set ::prof::T(%P) $dt; set ::prof::N(%P) 1 }
            return -options $opts $r
        }]
        lappend wrapped $p
    }
    reset
    return [llength $wrapped]
}
proc ::prof::reset {} { variable T; variable N; array unset T *; array unset N * }
# The procedures that took longest (inclusive), n of them.
proc ::prof::report {title {n 25} {out ""}} {
    variable T; variable N
    set rows [lsort -integer -decreasing -index 1 [lmap p [array names T] {list $p $T($p) $N($p)}]]
    set lines [list "== $title"]
    foreach r [lrange $rows 0 [expr {$n - 1}]] {
        lassign $r p t c
        lappend lines [format "  %9.1f ms %8d calls %9.1f µs/call  %s" [expr {$t / 1000.0}] $c [expr {double($t) / $c}] [string map {::VMDance:: ""} $p]]
    }
    set text [join $lines \n]
    if {$out ne ""} { set fh [open $out a]; puts $fh $text\n; close $fh }
    reset
    return $text
}
# The resident memory of this VMD, in MB.
proc ::prof::rss {} {
    if {[catch {exec ps -o rss= -p [pid]} kb]} { return "" }
    format %.0f [expr {[string trim $kb] / 1024.0}]
}
