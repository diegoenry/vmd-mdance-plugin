# MDANCE's own labels of 3ptb's Calpha atoms (tests/fixtures/mdance_3ptb.txt),
# which the reference suite compares the plugin's with: the plugin's CSV of
# the coordinates (all 100 frames, and frames 0-49) given to MDANCE 0.4
# (make_mdance_3ptb.py). Text-mode VMD:
#   cd <VMDance>; MDANCE_PYTHON=/path/to/python \
#     vmd -dispdev text -e tests/fixtures/make_mdance_3ptb.tcl < /dev/null
# (MDANCE_PYTHON: a Python with MDANCE 0.4, else python3; VMDANCE_SYSTEMS:
# the test systems, as for the suites.)
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set python [_env MDANCE_PYTHON python3]
if {[catch {
    package require vmdance
    set m [load_system 3ptb]
    set csvs {}
    foreach last {-1 49} {
        set req [::VMDance::Job::check_cluster [list mol $m sel "name CA" last $last k 2]]
        set c [::VMDance::Coords::extract $req]
        set f [file join $::out 3ptb_ca_[expr {$last < 0 ? "all" : "first50"}].csv]
        file copy -force [::VMDance::Coords::csv $c] $f
        lappend csvs $f
    }
    set dest [file join $::fixtures mdance_3ptb.txt]
    puts [exec $python [file join $::fixtures make_mdance_3ptb.py] {*}$csvs $dest 2>@1]
    puts "wrote $dest"
    file delete {*}$csvs
} err]} { puts "FAILED: $err\n$::errorInfo" }
::VMDance::Backend::cleanup
quit
