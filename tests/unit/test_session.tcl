# Unit tests for session persistence: save_session / load_session.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

set ::vmdstub::molids {0}   ;# molecule id 0 is "loaded"

proc tmpfile {} { return [::mdance::utils::mktmp .mdance] }

set sample [dict create \
    algorithm kmeans molid 0 atomsel "name CA" \
    labels {0 1 0 1 0 1} nClusters 2 nFrames 6 \
    clusterSizes {3 3} representatives {0 1} \
    score_calinskiHarabasz 5.0 score_daviesBouldin 1.0 \
    frames {0 1 2 3 4 5}]

th::section "save / load round-trip"
th::test "a saved session reloads with identical results" {
    set ::mdance::results $sample
    set f [tmpfile]
    ::mdance::save_session $f
    set ::mdance::results ""
    set live [::mdance::load_session $f]
    th::eq 2 [dict get $::mdance::results nClusters]
    th::eq {0 1 0 1 0 1} [dict get $::mdance::results labels]
    th::eq {0 1 2 3 4 5} [dict get $::mdance::results frames]
    th::true $live "molid 0 is loaded -> live == 1"
    catch {file delete $f}
}
th::test "load reports not-live when the source molecule is absent" {
    set ::mdance::results [dict replace $sample molid 99]
    set f [tmpfile]
    ::mdance::save_session $f
    set live [::mdance::load_session $f]
    th::false $live "molid 99 is not loaded -> live == 0"
    catch {file delete $f}
}

th::section "save / load - error handling"
th::test "saving with no results is an error" {
    set ::mdance::results ""
    th::throws {::mdance::save_session [tmpfile]} "*No clustering results*"
}
th::test "loading a non-session file is rejected" {
    set f [tmpfile]
    set fp [open $f w]; puts $fp "just some text, not a dict-session"; close $fp
    th::throws {::mdance::load_session $f}
    catch {file delete $f}
}
th::test "loading a session missing a required key is rejected" {
    set f [tmpfile]
    set partial [dict create mdanceSession 1 savedAt now \
        results [dict create labels {0 1} nClusters 2 clusterSizes {1 1}]]
    set fp [open $f w]; puts $fp $partial; close $fp
    th::throws {::mdance::load_session $f} "*representatives*"
    catch {file delete $f}
}

exit [th::done "unit:session"]
