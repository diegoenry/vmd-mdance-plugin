# Runtime scenario: what happens when the backend exits 0 but its output is not
# what the plugin expects.
#
# parse_json is a regex scraper, so truncated or malformed output produces a
# PARTIAL dict rather than an error, and a label list of the wrong length
# silently shifts every sample's cluster assignment. Both used to sail straight
# through into ::mdance::results and mis-colour the trajectory.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set mol [load_fixture two_state.pdb]
set params [dict create molid $mol atomsel "name CA" nclusters 2 metric MSD \
    kinit CompSim percentage 10 first 0 last -1 stride 1]

# Establish a good baseline result we can prove is left untouched by a bad run.
set good [::mdance::run_clustering kmeans $params]

th::section "A backend that exits 0 with unusable output is rejected"

th::test "truncated JSON is refused, not accepted as a partial result" {
    set ::env(MDANCE_FAKE_TRUNCATE) 1
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    catch {unset ::env(MDANCE_FAKE_TRUNCATE)}
    th::true $rc "a half-written result must not be accepted"
    th::match "*missing*" $err
}
th::test "a label count that disagrees with the frame count is refused" {
    set ::env(MDANCE_FAKE_EXTRA_LABELS) 3
    set rc [catch {::mdance::run_clustering kmeans $params} err]
    catch {unset ::env(MDANCE_FAKE_EXTRA_LABELS)}
    th::true $rc "27 labels for 24 frames must not be mapped onto the trajectory"
    th::match "*labels*" $err
}
th::test "the previous good results survive a rejected run" {
    th::eq [dict get $good labels] [dict get $::mdance::results labels]
    th::eq 24 [llength [dict get $::mdance::results labels]]
}
th::test "the run flag is cleared and no temp files leak" {
    th::eq 0 $::mdance::running
    th::eq 0 [llength [glob -nocomplain [file join [::mdance::utils::workdir] *]]]
}

exit [th::done "runtime:backend_output"]
