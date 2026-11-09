# Runs a suite so that an error at its top level ends it, as a failure.
# VMD runs a -e script command by command and goes on after one that
# fails: the variable it was to set keeps what it held, and a check after
# it can pass on that (test_groups' trimmed HELM heights did). Sourced, the
# suite stops at the error, and says so. (A suite's quit or exit ends it as
# it would: here, after the source.)
#   vmd -dispdev text -e tests/strict.tcl -args tests/test_core.tcl < /dev/null
set ::strict_suite [lindex $argv 0]
rename quit ::strict_quit
proc quit {args} { return -code error -errorcode {STRICT END} "the suite ended" }
rename exit ::strict_exit
proc exit {args} { return -code error -errorcode {STRICT END} "the suite ended" }
if {[catch {uplevel #0 [list source $::strict_suite]} ::strict_err] && [lrange $::errorCode 0 1] ne {STRICT END}} {
    puts "FAIL $::strict_suite stopped: an error at its top level: $::strict_err"
    puts $::errorInfo
    foreach v {checks fails skips} { if {![info exists ::$v]} { set ::$v 0 } }
    puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips"
}
::strict_quit
