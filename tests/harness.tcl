# harness.tcl - a tiny, dependency-free test harness.
#
# Works under both a plain `tclsh` (unit tests) and VMD's embedded Tcl
# (runtime tests), so we do not depend on `tcltest` being present in VMD.
#
# Usage:
#   source harness.tcl
#   th::section "frame mapping"
#   th::test "stride keeps every 3rd frame" {
#       th::eq {0 3 6 9} [::mdance::frame_list 0 0 9 3]
#   }
#   exit [th::done "unit:frames"]      ;# non-zero exit if any test failed
#
# Assertions throw on failure; th::test catches the throw and records it.

namespace eval th {
    variable passed 0
    variable failed 0
    variable skipped 0
    variable failures {}
    # Output channel. Under VMD, `puts stdout` is unreliable (the Tk console may
    # swallow it, and VMD's event loop interacts badly with console buffering),
    # so when MDANCE_TEST_OUT is set we write results to that file via a channel
    # we fully control. Under tclsh (unit tests) it stays on stdout.
    variable outchan ""
}
if {[info exists ::env(MDANCE_TEST_OUT)]} {
    set th::outchan [open $::env(MDANCE_TEST_OUT) w]
}

proc th::emit {line} {
    if {$th::outchan ne ""} {
        puts $th::outchan $line
        flush $th::outchan
    } else {
        puts stdout $line
        flush stdout
    }
}

proc th::section {name} { th::emit "\n\[$name\]" }

proc th::test {name body} {
    set rc [catch {uplevel 1 $body} err opts]
    if {$rc == 0} {
        incr th::passed
        th::emit "  ok    $name"
    } else {
        incr th::failed
        lappend th::failures $name
        th::emit "  FAIL  $name"
        th::emit "          -> $err"
    }
}

proc th::skip {name why} {
    incr th::skipped
    th::emit "  skip  $name ($why)"
}

proc th::_suffix {msg} { return [expr {$msg eq "" ? "" : " :: $msg"}] }

# --- assertions ------------------------------------------------------------

proc th::eq {exp got {msg ""}} {
    if {$exp ne $got} { error "expected \[$exp\] got \[$got\][th::_suffix $msg]" }
}
proc th::ne {a b {msg ""}} {
    if {$a eq $b} { error "expected values to differ but both are \[$a\][th::_suffix $msg]" }
}
proc th::true {val {msg ""}} {
    if {![string is boolean -strict $val]} { error "not a boolean: \[$val\][th::_suffix $msg]" }
    if {!$val} { error "expected true[th::_suffix $msg]" }
}
proc th::false {val {msg ""}} {
    if {![string is boolean -strict $val]} { error "not a boolean: \[$val\][th::_suffix $msg]" }
    if {$val} { error "expected false[th::_suffix $msg]" }
}
proc th::near {exp got tol {msg ""}} {
    if {![string is double -strict $got]} { error "expected a number got \[$got\][th::_suffix $msg]" }
    if {abs($exp - $got) > $tol} { error "expected ~$exp (+/-$tol) got $got[th::_suffix $msg]" }
}
proc th::match {pat got {msg ""}} {
    if {![string match $pat $got]} { error "expected match \[$pat\] got \[$got\][th::_suffix $msg]" }
}
proc th::gt {a b {msg ""}} {
    if {!($a > $b)} { error "expected $a > $b[th::_suffix $msg]" }
}
proc th::ge {a b {msg ""}} {
    if {!($a >= $b)} { error "expected $a >= $b[th::_suffix $msg]" }
}
# Assert $script raises an error; optionally the message must match $pat.
proc th::throws {script {pat *} {msg ""}} {
    set rc [catch {uplevel 1 $script} e]
    if {!$rc} { error "expected an error but none was raised[th::_suffix $msg]" }
    if {![string match $pat $e]} { error "error \[$e\] did not match \[$pat\][th::_suffix $msg]" }
}
# Assert $script runs without error.
proc th::ok {script {msg ""}} {
    set rc [catch {uplevel 1 $script} e opts]
    if {$rc} { error "expected success[th::_suffix $msg] but got: $e" }
}

# --- summary ---------------------------------------------------------------

# Print a summary and return the number of failures (0 == all good).
proc th::done {label} {
    set total [expr {$th::passed + $th::failed}]
    th::emit "\n== $label: $total run | $th::passed passed | $th::failed failed | $th::skipped skipped =="
    if {$th::failed} {
        th::emit "   failed: [join $th::failures {; }]"
    }
    return $th::failed
}
