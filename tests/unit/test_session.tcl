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

th::section "save_session - atomic replace protects the previous session"
proc slurp {path} {
    set fp [open $path r]
    set c [read $fp]
    close $fp
    return $c
}

th::test "a successful save leaves no temp file behind" {
    set ::mdance::results $sample
    set f [tmpfile]
    ::mdance::save_session $f
    th::eq {} [glob -nocomplain "$f.tmp*"] "the .tmp<pid> staging file must be renamed away"
    catch {file delete $f}
}

th::test "a failed save leaves the existing session byte-identical" {
    # Regression: save_session used to `open $filename w`, truncating the target
    # before writing. A failure part-way through destroyed a good session file.
    set dir [file join [::mdance::utils::tmpdir] "mdance_atomic_[pid]"]
    file delete -force $dir
    file mkdir $dir
    set f [file join $dir session.mdance]

    set ::mdance::results $sample
    ::mdance::save_session $f
    set before [slurp $f]

    file attributes $dir -permissions 0500
    if {[file writable $dir]} {
        # Running as root, or a filesystem that ignores mode bits: the failure
        # cannot be provoked here, so assert only what still holds.
        th::eq $before [slurp $f]
    } else {
        set ::mdance::results [dict replace $sample nClusters 99]
        th::throws {::mdance::save_session $f}
        th::eq $before [slurp $f] "the previous session must survive a failed save"
        th::eq {} [glob -nocomplain "$f.tmp*"] "no partial temp file may be left behind"
    }
    file attributes $dir -permissions 0700
    file delete -force $dir
}

exit [th::done "unit:session"]
