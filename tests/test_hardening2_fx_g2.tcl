# What the review of the backend's process (g2) found in its fixes, each
# kept from coming back (text mode, the fake backend and programs of the
# tests' own):
#   R1  where /proc is another PID namespace's (a PID namespace without a
#       /proc of its own), ps is not asked whether the job's program has
#       ended: it reads that /proc too, told of another process of that
#       number, and Cancel then held VMD in close until the program ended
#       (the KILL 1.5 s later could not run)
#   R2  the machine in the private folder's name is its node name and
#       machine-id, read without the resolver: "info hostname" gave every
#       host whose name is an alias of localhost one name (a TMPDIR shared
#       by them had its running jobs' folders removed), and a resolver that
#       does not answer held VMD
#   R3  configure clears the probe's notes (it cleared a local array)
# (The review's two flaky checks, F23's and F45's, are test_hardening2's.)
# (The namespaces are the user's own, unshare -U: skipped where they
# cannot be made.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_fx_g2.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_fx_g2]
file delete -force $H
file mkdir $H

proc wait_ms {ms} { set ::waited 0; after $ms {set ::waited 1}; vwait ::waited }
# A program of the tests': a shell script.
proc script {name body} {
    set f [file join $::H $name]
    set fh [open $f w]
    puts $fh "#!/bin/sh\n$body"
    close $fh
    file attributes $f -permissions 0755
    return $f
}
# A Tcl script run by tclsh in a namespace of the user's, which loads the
# plugin (@LIB@).
proc child {name body} {
    set f [file join $::H $name]
    set fh [open $f w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance]] "set auto_path \[linsert \$auto_path 0 {@LIB@}\]\npackage require vmdance\n$body"]
    close $fh
    return $f
}

if {[catch {
package require vmdance
set B ::VMDance::Backend
use_fake
fake_env

# R1: /proc of another PID namespace (a PID namespace without a /proc of
# its own): ps reads it too, and told of another process of the job's
# number (kthreadd for 2) as ended, so Cancel closed the channel at once,
# a blocking close that waited for the program (one that ignores TERM:
# until it ended by itself, the KILL 1.5 s later being an event that could
# not run). Where it cannot be told, Cancel waits for the end of the output.
set quiet [script quiet_noterm {trap '' TERM
exec sleep 6}]
# (here: /proc said to be another namespace's, and a ps that tells of
# another process, as that /proc would)
set bin [file join $H bin]
file mkdir $bin
set asked [file join $H ps.asked]
set fh [open [file join $bin ps] w]
puts $fh "#!/bin/sh\necho \"\$*\" >> '$asked'\necho 'I<       2'"
close $fh
file attributes [file join $bin ps] -permissions 0755
${B}::_procfs
set procfs0 [set ${B}::procfs]
set path0 $::env(PATH)
set ::env(PATH) $bin:$path0
set ${B}::procfs 0
set ::done ""
${B}::start $quiet {} -done {apply {{st msg j} { set ::done [list $st [clock milliseconds]] }}}
wait_ms 300
set t1 [clock milliseconds]
${B}::cancel
set tc [expr {[clock milliseconds] - $t1}]
set id [after 15000 {set ::done timeout}]
while {$::done eq ""} { vwait ::done }
after cancel $id
set ::env(PATH) $path0
set ${B}::procfs $procfs0
set td [expr {[lindex $::done 1] - $t1}]
check "R1: /proc of another PID namespace, a program that ignores TERM: Cancel returns at once ($tc ms), the job ends cancelled when it is killed ([lindex $::done 0], $td ms), ps never asked ([file exists $asked])" [expr {
    $tc < 1000 && [lindex $::done 0] eq "cancelled" && $td < 5000 && ![file exists $asked]}]
if {[${B}::running]} { ${B}::stop_now; wait_ms 500 }
# the same in a PID namespace of the user's whose /proc is this one's
# (unshare -p without --mount-proc): the job's number there is another
# process's here
if {![file isdirectory /proc/self] || [catch {exec unshare -Upf --map-current-user true 2>@1}]} {
    skip "R1: Cancel in a PID namespace without a /proc of its own" "unshare -Upf is not allowed here"
} else {
    set c [child nsproc.tcl [string map [list @QUIET@ $quiet] {
        set ::done ""
        ::VMDance::Backend::start {@QUIET@} {} -done {apply {{st msg j} { set ::done [list $st [clock milliseconds]] }}}
        set p [dict get $::VMDance::Backend::job pids]
        after 500 {set ::go 1}; vwait ::go
        set t1 [clock milliseconds]
        ::VMDance::Backend::cancel
        set tc [expr {[clock milliseconds] - $t1}]
        after 15000 {set ::done timeout}
        if {$::done eq ""} { vwait ::done }
        puts "procfs=<[::VMDance::Backend::_procfs]> pid=<$p> cancel=<$tc> status=<[lindex $::done 0]> end=<[expr {[lindex $::done 1] - $t1}]>"
    }]]
    catch {exec timeout 60 unshare -Upf --map-current-user tclsh $c 2>@1} o
    set o [string trim $o]
    set tc ""; set st ""; set te ""
    regexp {procfs=<0> pid=<[0-9]+> cancel=<([0-9]+)> status=<([a-z]+)> end=<([0-9]+)>} $o -> tc st te
    check "R1: in a PID namespace without a /proc of its own, Cancel of a program that ignores TERM returns at once, and the job ends when it is killed ($o)" [expr {
        $tc ne "" && $tc < 1000 && $st eq "cancelled" && $te < 5000}]
}

# R2: the private folder's machine is the node name and machine-id the
# kernel and /etc give, not the resolver's answer ("info hostname": the
# canonical name of the node name, which can wait on DNS).
set where0 [${B}::_where]
unset ${B}::where
rename ::tcl::info::hostname ::tcl::info::hostname_fx
proc ::tcl::info::hostname {} { incr ::asked; after 2000; return localhost.localdomain }
set ::asked 0
set t0 [clock milliseconds]
set w [${B}::_where]
set dt [expr {[clock milliseconds] - $t0}]
rename ::tcl::info::hostname {}
rename ::tcl::info::hostname_fx ::tcl::info::hostname
check "R2: the machine is told without the resolver (asked $::asked times, $dt ms, a resolver that waits 2 s), the same each time ($w)" [expr {
    $::asked == 0 && $dt < 1000 && $w eq $where0}]
# two machines whose name is an alias of localhost in /etc/hosts (the old
# RHEL layout: "127.0.0.1 localhost.localdomain localhost <name>"), each in
# its first PID namespace: the resolver names both localhost.localdomain,
# and their folders had one name (each removed the other's)
set hosts [file join $H hosts]
set fh [open $hosts w]
puts $fh "127.0.0.1 localhost.localdomain localhost node-a node-b"
close $fh
set empty [file join $H empty]
file mkdir $empty
set c [child where.tcl {puts "host=<[info hostname]> where=<[::VMDance::Backend::_where]>"}]
set got {}
foreach node {node-a node-b} {
    # (nscd's folder hidden: the file is what the resolver reads)
    if {[catch {exec timeout 60 unshare -Urmu sh -c "hostname $node && mount --bind '$hosts' /etc/hosts && { \[ ! -d /run/nscd \] || mount --bind '$empty' /run/nscd; } && tclsh '$c'" 2>@1} o]} { set got {}; break }
    lappend got [string trim $o]
}
if {[llength $got] != 2 || ![string match "host=<localhost.localdomain>*" [lindex $got 0]] || ![string match "host=<localhost.localdomain>*" [lindex $got 1]]} {
    skip "R2: two machines named as aliases of localhost" "unshare -Urmu, hostname or mount --bind is not allowed here ($got)"
} else {
    regexp {where=<([0-9a-f]+)>} [lindex $got 0] -> wa
    regexp {where=<([0-9a-f]+)>} [lindex $got 1] -> wb
    check "R2: two machines whose names are aliases of localhost in /etc/hosts: their folders' names differ ($got)" [expr {
        [info exists wa] && [info exists wb] && $wa ne $wb}]
}

# R3: configure clears what the probe could not tell (the note of a
# program slow to start), as it clears what the probe found.
set ${B}::notes(/some/old/program) "\"/some/old/program\" did not answer within 3 s when run without arguments"
use_fake
check "R3: configure clears the probe's notes ([array get ${B}::notes])" [expr {![array size ${B}::notes]}]

fake_env
done

} err]} { puts "FAIL test_hardening2_fx_g2 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
catch {set ::env(PATH) $path0}
::VMDance::Backend::cleanup
quit
