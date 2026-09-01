# Runtime scenario: a long run is cancelled, and a backend failure is handled
# cleanly -- both with the GUI open (the way a user actually runs the plugin),
# and both must leave no temp files or runaway child processes behind.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
::mdance::gui::create_window   ;# realistic: a run is launched from the open GUI

set params [dict create molid $mol atomsel "name CA" \
    nclusters 2 metric MSD kinit CompSim percentage 10 first 0 last -1 stride 1]

proc tmp_count {} {
    # Count inside the plugin's OWN private scratch dir. Globbing the shared
    # system tmpdir also saw (and the cleanup below also deleted) files belonging
    # to any other VMD session running at the same time.
    return [llength [glob -nocomplain [file join [::mdance::utils::workdir] *]]]
}
# Remove temp files left by earlier test runs so tmp_count reflects only this
# process (the temp dir is shared across runs).
foreach f [glob -nocomplain [file join [::mdance::utils::workdir] *]] {
    catch {file delete -force $f}
}

th::section "A normal clustering run completes with the GUI open"
# This also confirms the streaming pipe path (run_cli_capture) works after the
# Tk GUI is built -- the case that broke the exec-based paths.
th::test "run_clustering succeeds while the GUI exists" {
    catch {unset ::env(MDANCE_FAKE_SLEEP)}
    catch {unset ::env(MDANCE_FAKE_FAIL)}
    ::mdance::utils::cleanup
    set r [::mdance::run_clustering kmeans $params]
    th::eq 2 [dict get $r nClusters]
}
th::test "no temp files linger after a successful run" {
    th::eq 0 [tmp_count]
}

th::section "Cancelling a long-running clustering"
th::test "a slow run is interrupted and reports cancellation" {
    set ::env(MDANCE_FAKE_SLEEP) 6
    # Fire Cancel from the event loop ~1s in (mirrors the user clicking Cancel,
    # which run_cli_capture's vwait will service).
    after 1000 { ::mdance::request_cancel }
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    th::true $rc "the run must not complete normally"
    th::match "*ancel*" $err
    catch {unset ::env(MDANCE_FAKE_SLEEP)}
}
th::test "running flag is cleared after a cancel" {
    th::eq 0 $::mdance::running
}
th::test "cancel leaves no temp files behind" {
    th::eq 0 [tmp_count]
}

th::section "A backend failure is reported and cleaned up"
th::test "a non-zero backend exit surfaces an error" {
    set ::env(MDANCE_FAKE_FAIL) 1
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    th::true $rc "the run must fail"
    th::match "*failed*" $err
    catch {unset ::env(MDANCE_FAKE_FAIL)}
}
th::test "the backend's own message survives into the error" {
    # Tcl reports a non-zero exit as "child process exited abnormally", which
    # tells the user nothing about what the backend objected to. The last lines
    # the CLI printed are kept and appended instead.
    set ::env(MDANCE_FAKE_FAIL) 1
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    catch {unset ::env(MDANCE_FAKE_FAIL)}
    th::true $rc "the run must fail"
    th::match "*simulated backend failure*" $err \
        "the CLI's own stderr text must reach the user"
}
th::test "running flag is cleared after a failure" {
    th::eq 0 $::mdance::running
}
th::test "a failed run leaves no temp files behind" {
    th::eq 0 [tmp_count]
}

::mdance::utils::cleanup
th::section "Cancel escalates when the child ignores TERM"
th::test "a TERM-ignoring backend is still stopped, and the run returns" {
    # request_cancel used to send a single TERM and wait. A child that ignores it
    # (or a wrapper whose grandchild holds the pipe) left VMD parked in vwait
    # forever with no way out. The escalation is TERM -> KILL -> abandon channel.
    set ::env(MDANCE_FAKE_IGNORE_TERM) 1
    set ::env(MDANCE_FAKE_SLEEP) 30
    after 500 { catch {::mdance::request_cancel} }
    set t0 [clock milliseconds]
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    set elapsed [expr {[clock milliseconds] - $t0}]
    catch {unset ::env(MDANCE_FAKE_IGNORE_TERM)}
    catch {unset ::env(MDANCE_FAKE_SLEEP)}
    th::true $rc "the cancelled run must not report success"
    th::match "*ancel*" $err
    # The child was told to sleep 30s; escalation must end it far sooner.
    th::true [expr {$elapsed < 20000}] "run took ${elapsed}ms -- escalation did not fire"
}
th::test "the run flag is cleared after an escalated cancel" {
    th::eq 0 $::mdance::running
}

th::test "a run started right after a cancel is not killed by the previous run's timer" {
    # Regression: the escalation timers identified their run by the Tcl CHANNEL
    # NAME, and Tcl recycles pipe channel names -- so the cancelled run's timer
    # matched the NEXT run, closed its live channel and unblocked its vwait as if
    # the backend had finished. The follow-up run died with a bogus "couldn't
    # open <output>" while its backend child kept running.
    catch {unset ::env(MDANCE_FAKE_IGNORE_TERM)}
    set ::env(MDANCE_FAKE_SLEEP) 6
    after 300 { catch {::mdance::request_cancel} }
    catch {::mdance::run_clustering kmeans $params}     ;# run 1: cancelled

    # Start run 2 immediately, well inside the 3s+1s escalation window, and make
    # it outlive that window so a stale timer would have something to destroy.
    set ::env(MDANCE_FAKE_SLEEP) 5
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    catch {unset ::env(MDANCE_FAKE_SLEEP)}
    th::eq 0 $rc "the follow-up run must complete: $err"
    th::eq 24 [llength [dict get $::mdance::results labels]]
}

exit [th::done "runtime:cancel"]
