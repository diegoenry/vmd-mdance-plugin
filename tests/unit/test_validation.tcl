# Unit tests for the GUI validation/formatting helpers: _chknum, fmt_score, _busy_guard.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

th::section "_chknum - numeric field validation (also blocks injection)"
th::test "accepts a valid double" { th::true [::mdance::gui::_chknum 2.5 F double] }
th::test "accepts a valid int"    { th::true [::mdance::gui::_chknum 7 F int] }
th::test "accepts scientific notation" { th::true [::mdance::gui::_chknum 1e-3 F double] }
th::test "rejects non-numeric text" { th::false [::mdance::gui::_chknum abc F double] }
th::test "rejects an empty field"   { th::false [::mdance::gui::_chknum "" F double] }
th::test "rejects a value below min" { th::false [::mdance::gui::_chknum -1 F double 0] }
th::test "accepts a value at min"    { th::true  [::mdance::gui::_chknum 0 F double 0] }
th::test "int kind rejects a float"  { th::false [::mdance::gui::_chknum 2.5 F int] }
th::test "rejects a redirection-leading token '>file'" {
    th::false [::mdance::gui::_chknum >pwned F double]
}
th::test "rejects a pipe-leading token '|cmd'" {
    th::false [::mdance::gui::_chknum |id F double]
}

th::section "fmt_score - tolerant score formatting"
th::test "missing key -> n/a" {
    th::eq "n/a" [::mdance::gui::fmt_score {a 1} score_x]
}
th::test "finite value -> 4 decimals" {
    th::eq "3.1416" [::mdance::gui::fmt_score {score_x 3.14159} score_x]
}
th::test "NaN does not throw (returned raw)" {
    th::eq "NaN" [::mdance::gui::fmt_score {score_x NaN} score_x]
}
th::test "Infinity formats without error" {
    # format %.4f of Infinity yields "inf" on Tcl 8.x; the point is no exception.
    th::ok { ::mdance::gui::fmt_score {score_x Infinity} score_x }
}

th::section "_busy_guard - reentrancy gate"
th::test "free when no run is active" {
    set ::mdance::running 0
    th::true [::mdance::gui::_busy_guard]
}
th::test "blocked while a run is active" {
    set ::mdance::running 1
    th::false [::mdance::gui::_busy_guard]
    set ::mdance::running 0
}

th::section "utils::is_finite - a real number vs the backend's NaN/Infinity tokens"
th::test "accepts ordinary numbers" {
    th::true [::mdance::utils::is_finite 1.5]
    th::true [::mdance::utils::is_finite 0]
    th::true [::mdance::utils::is_finite -3.25]
    th::true [::mdance::utils::is_finite 1e30]
}
th::test "rejects NaN, which 'string is double' accepts" {
    th::true  [string is double -strict NaN]
    th::false [::mdance::utils::is_finite NaN]
}
th::test "rejects Infinity in both signs" {
    th::false [::mdance::utils::is_finite Infinity]
    th::false [::mdance::utils::is_finite -Infinity]
}
th::test "rejects empty and non-numeric values" {
    th::false [::mdance::utils::is_finite ""]
    th::false [::mdance::utils::is_finite abc]
}
th::test "the trap it exists for: NaN makes plain expr and format throw" {
    # This is why 'string is double' was not a sufficient guard: a NaN score
    # passed it, then blew up the arithmetic that consumed the value -- turning
    # a SUCCESSFUL sweep run into a failed 'ERR' row and killing elbow charts.
    th::throws {expr {1 ? NaN : ""}} "*domain error*"
    th::throws {format %.2f NaN}
}

exit [th::done "unit:validation"]
