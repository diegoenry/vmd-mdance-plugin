# What the review of "what reaches the backend, and the library mode" (g3)
# found in its fixes, each kept from coming back (text mode; the fake
# backend, and the real one where it is found):
#   F02  eQUAL with an index other than MSD is refused whatever its seeds:
#        on coordinates every frame is within any radius of the seed, and
#        all landed in one cluster published as a success (only its
#        comp_sim seeds were refused, and the message sent users to its
#        medoid, which did the same)
#   F02  HELM's summary of an imported run, which keeps no starting
#        clusters, no longer says "HELM started from 0 clusters"
#   F14  a representative sample's share below one frame picks one frame,
#        as CPP-MDANCE does (it was refused as "holds no frame"; only the
#        outliers' share can hold none)
#   F73  a program path stored as "~user/…" of a user that does not exist
#        no longer fails the first use of the backend with Tcl's 'user
#        "…" doesn't exist' (left to the search, as a program gone is);
#        given to `vmdance backend -cli`, it is refused naming -cli
#   F53  HELM -k 0 with an -eps that is -1 only as a C float says so (it
#        said "-k 0 needs -eps" to a user who gave -eps)
# (The window's checks of F63 and F74 are test_gui's.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_fx_g3.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_fx_g3]
file delete -force $H
file mkdir $H

if {[catch {
package require vmdance
set A ::VMDance::Algo
use_fake
fake_env
set m2 [load_system two_state]

# F02: eQUAL's radius by an index other than MSD holds every frame on
# coordinates (1 − the index falls below 0): with its medoid seeds too,
# every frame landed in one cluster, published as a success (CPP-MDANCE,
# program and library, on 3ptb, the fixtures and the constructed
# trajectories, at radius 0 and 1). The comp_sim refusal named the medoid
# as the way out.
set ep [dict replace [${A}::defaults equal] threshold 1]
set bad {}
foreach met [lrange $::VMDance::Algo::metrics 1 end] {
    foreach seeds {medoid comp_sim} {
        set e [err {${A}::check_combination equal "" [dict replace $ep seed-method $seeds] 100 "" $met}]
        if {![string match "-metric $met with eQUAL: *every frame lands in one cluster; use -metric MSD" $e]} { lappend bad "$met $seeds: <$e>" }
    }
}
set why ""
if {[llength $bad]} { set why ": [join $bad {; }]" }
check "F02: eQUAL with each index other than MSD ([expr {[llength $::VMDance::Algo::metrics] - 1}]), medoid or comp_sim seeds: refused, saying to use MSD$why" [expr {![llength $bad]}]
check "  eQUAL with MSD, either seeds: taken" [expr {[err {${A}::check_combination equal "" $ep 100 "" MSD}] eq "" &&
    [err {${A}::check_combination equal "" [dict replace $ep seed-method comp_sim] 100 "" MSD}] eq ""}]
vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
set nruns [llength [vmdance runs]]
set c0 $::VMDance::Backend::counter
set e [err {vmdance -mol $m2 -sel all -algorithm equal -threshold 1 -seed-method medoid -metric BUB -quiet 1}]
check "  the command: eQUAL's medoid with BUB refused before any job, nothing published ($e)" [expr {
    [string match "vmdance: -metric BUB with eQUAL: *" $e] && $::VMDance::Backend::counter == $c0 && [llength [vmdance runs]] == $nruns}]
set nruns [llength [vmdance runs]]
check "  KMeans with BUB and k-means++ seeds (the metric only seeds it): still taken" [expr {
    ![catch {vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -metric BUB -quiet 1}] && [llength [vmdance runs]] == $nruns + 1}]
if {[real_cli] eq ""} {
    skip "F02: what the real program gives eQUAL's medoid with BUB" "no mdance-cli"
} else {
    # (the backend is the reference: with the index, every frame is in one
    # cluster; were that to change, the refusal could be lifted)
    set c [::VMDance::Coords::extract [::VMDance::Job::check_input [list mol $m2 sel all]]]
    set jout [file join $H equal_bub.json]
    catch {exec [real_cli] --algorithm equal --input [::VMDance::Coords::csv $c] --output $jout --natoms 8 --metric BUB \
        --threshold 1 --seed-method medoid --n-seeds 1 --percentage 10 2>@1}
    set labels {}
    catch {set labels [dict get [::VMDance::Json::parse [read_text $jout]] labels]}
    check "  the real program's eQUAL with BUB, as the refusal says: every frame in one cluster ([lsort -unique $labels])" [expr {
        [llength $labels] == 24 && [lsort -unique $labels] eq "0"}]
}

# F02: HELM's summary counted the starting clusters of a run that has
# none to count: an import from the MDANCE plugin (initial {}) with fewer
# clusters than asked said "HELM started from 0 clusters".
set t [read_text [file join $::fixtures old_helm.mdance]]
set f [file join $H old_helm3.mdance]
set fh [open $f w]; puts -nonewline $fh [string map {"nclusters 2 metric" "nclusters 3 metric"} $t]; close $fh
set ok [expr {![catch {vmdance session import $f -mol $m2}]}]
set s [::VMDance::_summary]
check "F02: an imported HELM run with fewer clusters than asked: said, without a count of starting clusters it does not have ($s)" [expr {
    $ok && [dict get [::VMDance::Results::request] k] == 3 && [::VMDance::Results::get initial] eq "" &&
    [string match "*fewer than the 3 asked" $s] && ![string match "*started from*" $s]}]
vmdance run clear

# F14: CPP-MDANCE picks one frame for a representative sample whose share
# holds none (the outliers' can be none, and stays refused): 0.01 of 24
# frames was refused as "holds no frame", where it picked one.
vmdance pick -mol $m2 -sel all -method outliers -param 2
set before [vmdance pick show]
check "F14: the outliers' 0.01 of 24 frames (none of them): still refused, the picks there kept" [expr {
    [string match "*-param 0.01: a share of the 24 frames that holds no frame*" [err {vmdance pick -mol $m2 -sel all -method outliers -param 0.01}]] &&
    [vmdance pick show] eq $before}]
set r {}
set e [err {set r [vmdance pick -mol $m2 -sel all -method repsample -param 0.01]}]
check "  a representative sample of 0.01 of 24 frames: one frame picked, as the backend does ($r$e)" [expr {$e eq "" && [llength $r] == 1}]
foreach be {cli lib} {
    if {[real_$be] eq ""} { skip "  the real backend ($be): a sample of 0.01 of 24 frames" "not found"; continue }
    use_$be
    set r {}
    set e [err {set r [vmdance pick -mol $m2 -sel all -method repsample -param 0.01]}]
    check "  the real backend ($be): a sample of 0.01 of 24 frames is one frame ($r$e)" [expr {$e eq "" && [llength $r] == 1}]
}
use_fake

# F73: from_prefs normalized the stored program before testing it, and
# Tcl 8.6's `file normalize ~user/…` fails when that user does not exist
# (an account gone, preferences copied from another machine): the first
# clustering, pick or `vmdance backend` of the session failed with
# 'user "…" doesn't exist'. It is left to the search, as a program gone is.
set nouser nosuchuser_mdv73
if {![catch {file normalize ~$nouser/x}]} {
    skip "F73: a stored program of a user that does not exist" "a user $nouser exists"
} else {
    set home [file join $H home73]
    file mkdir $home
    set fh [open [file join $home .vmdance.prefs] w]
    puts $fh "backend_mode auto\nbackend_cli [list ~$nouser/bin/mdance-cli]\nbackend_lib [list ~$nouser/lib/mdance_tcl.so]"
    close $fh
    set child [file join $H prefs73.tcl]
    set fh [open $child w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance]] {
        set auto_path [linsert $auto_path 0 {@LIB@}]
        package require vmdance
        if {[catch {vmdance backend} s]} {
            puts "first=<1> error=<$s>"
        } else {
            puts "first=<0> error=<[dict get $s error]> mode=<[dict get $s mode]> cli=<[dict get $s cli]>"
        }
    }]
    close $fh
    set keep {}
    foreach v {HOME MDANCE_CLI MDANCE_LIB} { if {[info exists ::env($v)]} { dict set keep $v $::env($v) } }
    set ::env(HOME) $home
    set ::env(MDANCE_CLI) $::fake
    unset -nocomplain ::env(MDANCE_LIB)
    catch {exec timeout 30 tclsh $child 2>@1} o
    foreach v {HOME MDANCE_CLI MDANCE_LIB} { if {[dict exists $keep $v]} { set ::env($v) [dict get $keep $v] } else { unset -nocomplain ::env($v) } }
    set o [join [split $o \n] { }]
    check "F73: a program and library stored as ~$nouser/…: the backend found by the search at its first use, no error ($o)" [expr {
        [string match "*first=<0> error=<> mode=<auto> cli=<$::fake>*" $o] && ![string match "*doesn't exist*" $o]}]
    set before [::VMDance::Backend::settings]
    set e [err {vmdance backend -cli ~$nouser/bin/mdance-cli}]
    check "  given to the command: refused naming -cli, the backend kept ($e)" [expr {
        [string match "vmdance backend: -cli: \"~$nouser/bin/mdance-cli\" is not an executable program" $e] &&
        [::VMDance::Backend::settings] eq $before}]
    check "  tried (Settings' trial): the same" [string match "*-cli: \"~$nouser/bin/mdance-cli\" is not an executable program" [err {
        vmdance backend try -cli ~$nouser/bin/mdance-cli}]]
}

# F53: an -eps that is -1 only as the backend reads it (a C float) was
# refused as "-k 0 needs -eps", to a user who had given one.
set e [err {vmdance -mol $m2 -sel all -algorithm helm -k 0 -initial 6 -initial-kinit KmeansPP -eps -0.99999999 -quiet 1}]
check "F53: HELM -k 0 -eps -0.99999999: refused, saying it is -1 as CPP-MDANCE reads it ($e)" [string match \
    "vmdance: -k 0 needs -eps: -eps -0.99999999 is -1 as CPP-MDANCE reads it (a C float)*" $e]
set e [err {vmdance -mol $m2 -sel all -algorithm helm -k 0 -initial 6 -initial-kinit KmeansPP -quiet 1}]
check "  -k 0 without -eps: the message as it was ($e)" [expr {
    [string match "vmdance: -k 0 needs -eps: HELM stops at k clusters*" $e] && ![string match "*C float*" $e]}]

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_fx_g3 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
