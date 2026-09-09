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

# ------------------------------------------------------------------
th::section "Coordinate extraction reports progress and can be aborted"
# ------------------------------------------------------------------
# Extraction is the dominant cost of a run (4-5 s for a 6001-frame trajectory,
# against ~1 s for the clustering). It used to run without servicing a single
# event, so the progress bar never moved and Cancel could not even be clicked.
th::test "extraction advances the status line to a real frame count" {
    set ::mdance::status "Ready"
    set ::mdance::cancel_requested 0
    lassign [::mdance::extract_coordinates $mol "name CA" 0 -1 1] csv natoms nf frames
    th::eq 24 $nf
    th::match "*frame 24 of 24*" $::mdance::status \
        "the last tick must report the final frame"
    catch {file delete $csv}
    ::mdance::utils::cleanup
}
th::test "a cancel request aborts extraction instead of running to the end" {
    set ::mdance::cancel_requested 1
    th::throws {::mdance::extract_coordinates $mol "name CA" 0 -1 1} \
        "Clustering cancelled."
    set ::mdance::cancel_requested 0
    ::mdance::utils::cleanup
}
th::test "the flat (library-mode) extraction path aborts too" {
    set ::mdance::cancel_requested 1
    th::throws {::mdance::extract_coordinates_flat $mol "name CA" 0 -1 1} \
        "Clustering cancelled."
    set ::mdance::cancel_requested 0
}
th::test "a stale cancel flag does not abort the NEXT run" {
    # cancel_requested was only ever cleared inside run_cli_capture, which now
    # happens AFTER extraction. Without run_clustering arming it, a run that
    # followed a cancelled one died instantly in its own extraction.
    set ::mdance::cancel_requested 1
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    th::eq 0 $rc "the follow-up run must complete: $err"
    th::eq 24 [llength [dict get $::mdance::results labels]]
}
th::test "the tick interval keeps the overhead bounded on long trajectories" {
    # ~100 ticks maximum, so a 6001-frame extraction does not pay for 6001
    # status updates and event-loop passes.
    th::eq 25 [::mdance::_tick_every 24]
    th::eq 25 [::mdance::_tick_every 199]
    th::eq 60 [::mdance::_tick_every 6001]
    th::ge [expr {6001 / [::mdance::_tick_every 6001]}] 100
    th::true [expr {6001 / [::mdance::_tick_every 6001] <= 101}]
}
th::test "busy_stop leaves the progress bar animated for the next operation" {
    # Extraction switches the shared bar to determinate; if that leaked, the
    # next indeterminate use sat frozen at 100%.
    ::mdance::gui::busy_start "test" 1
    ::mdance::gui::progress_frac 0.5
    th::eq determinate [.mdance.status.pb cget -mode]
    ::mdance::gui::busy_stop
    th::eq indeterminate [.mdance.status.pb cget -mode]
}
th::test "progress_frac is harmless when the plugin window is gone" {
    # Runs can outlive the window (CLI mode parks in a live event loop), and the
    # unit-test stubs have no Tk at all, so this must never raise.
    destroy .mdance
    th::ok { ::mdance::gui::progress_frac 0.5 }
    ::mdance::gui::create_window
}

exit [th::done "runtime:cancel"]
