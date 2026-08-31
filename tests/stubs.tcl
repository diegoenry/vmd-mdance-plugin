# stubs.tcl - minimal VMD/Tk stubs so the plugin can be sourced and its
# pure-Tcl procs exercised under a plain `tclsh` (no VMD, no display).
#
# Source this BEFORE sourcing the plugin's mdance.tcl.
#
# It intercepts `package require Tk` (so sourcing does not open a window or fail
# for lack of a display) while leaving the real `package` machinery intact, and
# provides a configurable `molinfo` stub plus a no-op `tk_messageBox`.

rename package __stub_real_package
proc package {args} {
    if {[lindex $args 0] eq "require" && [lindex $args 1] eq "Tk"} {
        return 8.6
    }
    return [uplevel 1 [list __stub_real_package {*}$args]]
}

# Dialogs used by validation helpers etc. -> no-op.
proc tk_messageBox {args} { return ok }

# Configurable molecule state for frame_list / load_session tests.
namespace eval ::vmdstub {
    variable numframes 100
    variable molids {0}
    variable numreps 1
}

proc molinfo {args} {
    set a0 [lindex $args 0]
    if {$a0 eq "list"} { return $::vmdstub::molids }
    if {$a0 eq "top"}  { return [lindex $::vmdstub::molids 0] }
    # molinfo <id> get <field>
    if {[lindex $args 1] eq "get"} {
        switch -- [lindex $args 2] {
            numframes { return $::vmdstub::numframes }
            numreps   { return $::vmdstub::numreps }
        }
    }
    return 0
}
