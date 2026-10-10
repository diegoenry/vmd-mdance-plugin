# What the second round of reviews found in the library mode, in scans and
# in what a job says while the library runs (h3), each kept from coming
# back (text mode, the real library and program; skipped without them):
#   N12  a job's library calls are given one list, read and checked once:
#        an elbow scan, a sweep and HELM's first clustering read every frame
#        from VMD again at every call (fitted again), and the library made
#        the text of each new list (93 MB on protein G): a library scan took
#        three times the program's. The calls get the rows the extraction
#        read, as the program gets its CSV (a frame moved during a scan
#        failed its next values of k; the scan is now refused when one is
#        made the clustering, as the program's is), and the list goes when
#        the job ends
#   N13  the step before a library call says that the library runs it and
#        that VMD does not respond until it ends (the window showed the
#        reading's last line through the call), and a Cancel then stops the
#        job before the call
# (N13 in the window: the throttle that dropped that step, Setup's note of
# the library Automatic chose, the sweep's question and the texts that
# promised the background are test_gui's.)
# And what the review of those found:
#   N13  a Cancel pressed during a library call, which VMD reads only when
#        the call returns, came to no job when the job ended right after
#        its call (PRIME, the similarity, a pick, a small clustering, a
#        scan's last value of k or configuration), and the job published,
#        though the texts say Cancel acts when the call ends: the job now
#        reads it then, a call that fails too (the window's click is
#        test_gui's)
#   N12  a call cancelled before it was made was counted as made
#        (Job::lib_most): the next call's memory check took for kept the
#        text that call never made
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_h3.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]

# What the library's commands were given: for each call, the command, its
# list's object, whether that list's text was made already (1: not yet),
# and the progress message the job posted last.
set ::seen {}
set ::said ""
set ::nflat 0
set ::click_at ""
set ::fail_at ""
proc h3_said {cmd op} { set ::said [lindex $cmd 2] }
proc h3_flat {cmd op} { incr ::nflat }
proc h3_wrap {name} {
    rename ::mdance::$name ::mdance::${name}_h3
    proc ::mdance::$name {co args} [string map [list %N $name] {
        set r [::tcl::unsupported::representation $co]
        lappend ::seen [list %N [lindex [regexp -inline {object pointer at ([^,]+)} $r] 1] [string match "*no string representation*" $r] $::said]
        # (Cancel pressed during the call click_at: VMD reads it when the
        # call returns; the call fail_at fails after it)
        if {$::click_at eq [llength $::seen]} { after 0 ::VMDance::Job::cancel }
        set out [::mdance::%N_h3 $co {*}$args]
        if {$::fail_at eq [llength $::seen]} { error "the library failed" }
        return $out
    }]
}
# (the error of a job whose call n was clicked Cancel during, and fails
# too when fail is 1)
proc h3_click {n script {fail 0}} {
    set ::seen {}
    set ::click_at $n
    set ::fail_at [expr {$fail ? $n : ""}]
    set e [uplevel 1 [list err $script]]
    set ::click_at ""
    set ::fail_at ""
    return $e
}
proc h3_unwrap {name} {
    rename ::mdance::$name {}
    rename ::mdance::${name}_h3 ::mdance::$name
}
proc h3_lists {} { llength [lsort -unique [lmap s $::seen {lindex $s 1}]] }
proc h3_labels {} { lmap r [dict get $::VMDance::Results::elbow records] {dict get $r clustering labels} }
proc h3_status {} { lmap r [dict get $::VMDance::Results::elbow records] {dict get $r status} }
# (a frame moved when the scan posts the step of k = 3, once)
proc h3_move {cmd op} {
    if {!$::moved && [string match "*k = 3*" [lindex $cmd 2]]} { set ::moved 1; $::s7 moveby {0.5 0 0} }
}
# (Cancel pressed while the step before a library call is shown)
proc h3_cancel {cmd op} {
    if {[string match "*in the library*" [lindex $cmd 2]]} { ::VMDance::Job::cancel }
}

if {[catch {
package require vmdance
set ::VMDance::Prefs::file ""
set R ::VMDance::Results

if {[real_lib] eq "" || [real_cli] eq ""} {
    skip "N12, N13: the library's calls" "no mdance_tcl library or mdance-cli"
} else {
    set m [load_system two_state]
    use_lib
    foreach c {kmeans helm prime analysis select} { h3_wrap $c }
    trace add execution ::VMDance::Job::_progress enter h3_said
    trace add execution ::VMDance::Coords::flat enter h3_flat

    # --- N12: one list for a job's calls ------------------------------------------------
    # (the frames read once and kept, as a clustering leaves them)
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    set ::nflat 0; set ::seen {}
    vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1
    set elbow_seen $::seen
    set lib [h3_labels]
    check "N12: a library elbow scan of 3 values of k reads the frames for the library once (Coords::flat: $::nflat), and gives its 3 calls one list ([h3_lists])" [expr {
        $::nflat == 1 && [llength $::seen] == 3 && [h3_lists] == 1}]
    check "  whose text the library made at the first call only (it made one at every call: [lmap s $::seen {lindex $s 2}])" [expr {
        [lmap s $::seen {lindex $s 2}] eq {1 0 0}}]
    check "  the list goes when the job ends" [expr {[info exists ::VMDance::Job::lib_rows] && ![llength $::VMDance::Job::lib_rows] &&
        $::VMDance::Job::lib_of eq ""}]
    use_cli
    vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1
    use_lib
    check "  the same labels at every k as the program's, on the same coordinates" [expr {[llength $lib] == 3 && $lib eq [h3_labels]}]
    set ::nflat 0; set ::seen {}
    vmdance elbow -mol $m -sel all -algorithm helm -initial 8 -initial-kinit KmeansPP -ks {2 3 4} -quiet 1
    check "  a HELM elbow scan: its first clustering and every k on one list, read once (Coords::flat: $::nflat)" [expr {
        $::nflat == 1 && [lmap s $::seen {lindex $s 0}] eq {kmeans helm helm helm} && [h3_lists] == 1 && [lsort -unique [h3_status]] eq "ok"}]
    set ::nflat 0; set ::seen {}
    vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3 4} -seedings KmeansPP -quiet 1
    check "  a sweep: its 3 configurations on one list, read once (Coords::flat: $::nflat)" [expr {
        $::nflat == 1 && [llength $::seen] == 3 && [h3_lists] == 1}]
    # (a frame moved between two values of k: the library's scan goes on with
    # the rows it read, as the program's with its CSV, and making a value
    # the clustering is then refused for both: the coordinates are others)
    set ::s7 [atomselect $m all frame 7]
    set xyz7 [$::s7 get {x y z}]
    foreach bk {cli lib} {
        use_$bk
        vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
        set ::moved 0
        trace add execution ::VMDance::Job::_progress enter h3_move
        vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1
        trace remove execution ::VMDance::Job::_progress enter h3_move
        set st($bk) [h3_status]
        set ld($bk) [err {vmdance elbow load 3}]
        $::s7 set {x y z} $xyz7
    }
    $::s7 delete
    check "  a frame moved during a scan: the library's goes on with the rows it read, as the program's ($st(lib), $st(cli)), and neither is made the clustering after" [expr {
        $::moved && $st(lib) eq {ok ok ok} && $st(cli) eq {ok ok ok} &&
        [string match "*changed since the scan was made*" $ld(lib)] && [string match "*changed since the scan was made*" $ld(cli)]}]

    # --- N13: what the job says before a library call ----------------------------------------
    check "N13: the step before each library call says that the library runs it and VMD waits (it said the step alone)" [expr {
        [lmap s $elbow_seen {lindex $s 3}] eq [lmap k {2 3 4} {string cat "KMeans NANI, k = $k, in the library: VMD does not respond until it ends"}]}]
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    set ::seen {}
    vmdance prime
    check "  PRIME's too" [expr {[lindex $::seen end 3] eq "PRIME, in the library: VMD does not respond until it ends"}]
    set ::seen {}
    set nruns [llength [vmdance runs]]
    # (the review: a call cancelled there was counted as made, Job::lib_most)
    set most $::VMDance::Job::lib_most
    set ::VMDance::Job::lib_most 0
    trace add execution ::VMDance::Job::_progress enter h3_cancel
    set e [err {vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1}]
    trace remove execution ::VMDance::Job::_progress enter h3_cancel
    check "  a Cancel while it says so stops the job before the call: nothing published, the list gone, the call not counted as made (Job::lib_most [set ::VMDance::Job::lib_most]: the next call's memory check took for kept a text never made) ($e)" [expr {
        [string match "*cancelled*" $e] && ![llength $::seen] && [llength [vmdance runs]] == $nruns && ![llength $::VMDance::Job::lib_rows] &&
        $::VMDance::Job::lib_most == 0}]

    # --- the review of N13: a Cancel pressed during a library call ------------------------------
    # (VMD reads the click when the call returns: a job that ended right after
    # its call published, its Cancel coming to no job)
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    set nruns [llength [vmdance runs]]
    set e1 [h3_click 1 {vmdance prime}]
    check "review N13: a Cancel pressed during PRIME's library call cancels it when the call ends: PRIME not kept (it was, the Cancel finding no job) ($e1)" [expr {
        [string match "*cancelled*" $e1] && [llength $::seen] == 1 && ![dict size [::VMDance::Results::extra prime]]}]
    check "  that call counted as made (Job::lib_most [set ::VMDance::Job::lib_most]: its text was made)" [expr {
        $::VMDance::Job::lib_most == 3 * [molinfo $m get numatoms] * [molinfo $m get numframes]}]
    set ::VMDance::Job::lib_most [expr {max($most, $::VMDance::Job::lib_most)}]
    set e2 [h3_click 1 {vmdance similarity}]
    set pk $::VMDance::Results::picks
    set e3 [h3_click 1 {vmdance pick -mol $m -sel all -method outliers -param 3}]
    check "  the similarity's and a pick's: nothing kept ($e2; $e3)" [expr {
        [string match "*cancelled*" $e2] && ![dict size [::VMDance::Results::extra similarity]] &&
        [string match "*cancelled*" $e3] && $pk eq $::VMDance::Results::picks}]
    set e4 [h3_click 1 {vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1}]
    check "  a clustering's, measured within a slice (40 ms: its measures never yielded): no run made ($e4)" [expr {
        [string match "*cancelled*" $e4] && [llength [vmdance runs]] == $nruns}]
    set eb $::VMDance::Results::elbow
    set sw $::VMDance::Results::sweep
    set e5 [h3_click 3 {vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1}]
    set e6 [h3_click 2 {vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -seedings KmeansPP -quiet 1}]
    check "  an elbow scan's last value of k and a sweep's last configuration: neither scan replaced ($e5; $e6)" [expr {
        [string match "*cancelled*" $e5] && [string match "*cancelled*" $e6] &&
        $eb eq $::VMDance::Results::elbow && $sw eq $::VMDance::Results::sweep}]
    set e7 [h3_click 3 {vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1} 1]
    check "  a last call that fails meanwhile: cancelled, not a scan with that value failed ($e7)" [expr {
        [string match "*cancelled*" $e7] && $eb eq $::VMDance::Results::elbow}]
    set ::seen {}
    set e8 [err {vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1}]
    check "  and a job after them, with no Cancel, runs and publishes ($e8)" [expr {
        $e8 eq "" && [llength $::seen] == 3 && [h3_status] eq {ok ok ok}}]

    trace remove execution ::VMDance::Coords::flat enter h3_flat
    trace remove execution ::VMDance::Job::_progress enter h3_said
    foreach c {kmeans helm prime analysis select} { h3_unwrap $c }
    use_fake
}

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_h3 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
