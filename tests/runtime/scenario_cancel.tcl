# Runtime scenario: a long run is cancelled, and a backend failure is handled
# cleanly -- both with the GUI open (the way a user actually runs the plugin),
# and both must leave no temp files or runaway child processes behind.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
::mdance::gui::create_window   ;# realistic: a run is launched from the open GUI

set params [dict create molid $mol atomsel "name CA" \
    nclusters 2 metric MSD kinit CompSim percentage 10 first 0 last -1 stride 1]

proc tmp_count {} {
    return [llength [glob -nocomplain [file join [::mdance::utils::tmpdir] mdance_*]]]
}
# Remove temp files left by earlier test runs so tmp_count reflects only this
# process (the temp dir is shared across runs).
foreach f [glob -nocomplain [file join [::mdance::utils::tmpdir] mdance_*]] {
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
th::test "running flag is cleared after a failure" {
    th::eq 0 $::mdance::running
}
th::test "a failed run leaves no temp files behind" {
    th::eq 0 [tmp_count]
}

::mdance::utils::cleanup
exit [th::done "runtime:cancel"]
