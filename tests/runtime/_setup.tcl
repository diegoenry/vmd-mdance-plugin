# Shared setup for runtime (in-VMD) scenarios.
#
# A scenario sources this with:
#   source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]
#
# (VMD's `-e script` does NOT set `info script`, so paths come from the
# MDANCE_TESTS_DIR env var that run_tests.sh exports.)
#
# It loads the plugin, stubs the file/alert dialogs (AFTER sourcing, because
# `package require Tk` re-installs the real tk_messageBox), and points the plugin
# at the deterministic fake backend instead of a real mdance-cli.

set ::TESTS_DIR $::env(MDANCE_TESTS_DIR)                           ;# tests
set ::REPO      [file dirname $::TESTS_DIR]                        ;# repo root

source [file join $::TESTS_DIR harness.tcl]
source [file join $::REPO mdance mdance.tcl]

# Non-interactive dialog stubs (overridden per-test where a return value matters).
proc tk_messageBox {args} { return ok }
proc tk_getSaveFile {args} { return "" }
proc tk_getOpenFile {args} { return "" }
proc tk_chooseDirectory {args} { return "" }

# Force CLI mode against the fake backend; make sure no stray env points elsewhere.
catch {unset ::env(MDANCE_LIB)}
catch {unset ::env(MDANCE_CLI)}
set ::mdance::use_library 0
set ::mdance::cli_path [file join $::TESTS_DIR fake_mdance_cli]

set ::FIXTURES [file join $::TESTS_DIR fixtures]
proc load_fixture {name} { return [mol new [file join $::FIXTURES $name] waitfor all] }

# Read a CSV file into a list of lines (for export assertions).
proc read_lines {path} {
    set fp [open $path r]; set c [read $fp]; close $fp
    return [split [string trimright $c "\n"] "\n"]
}
