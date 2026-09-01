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

th::section "load_session - internally inconsistent sessions are rejected"
# Key presence was the only check. An inconsistent session loaded cleanly and
# then died inside a plot, far from anything that pointed at the real cause.
proc write_session {res} {
    set f [tmpfile]
    set fp [open $f w]
    puts $fp [dict create mdanceSession 1 savedAt "2026-01-01 00:00:00" results $res]
    close $fp
    return $f
}
th::test "nClusters disagreeing with clusterSizes is rejected" {
    set f [write_session [dict replace $sample clusterSizes {3 3 3}]]
    th::throws {::mdance::load_session $f} "*clusterSizes*"
    catch {file delete $f}
}
th::test "nClusters disagreeing with representatives is rejected" {
    set f [write_session [dict replace $sample representatives {0}]]
    th::throws {::mdance::load_session $f} "*representatives*"
    catch {file delete $f}
}
th::test "a non-numeric nClusters is rejected" {
    set f [write_session [dict replace $sample nClusters "two"]]
    th::throws {::mdance::load_session $f} "*nClusters*"
    catch {file delete $f}
}
th::test "a non-integer cluster label is rejected" {
    set f [write_session [dict replace $sample labels {0 1 0 x 0 1}]]
    th::throws {::mdance::load_session $f} "*non-integer cluster label*"
    catch {file delete $f}
}
th::test "a frame map shorter than the labels is rejected" {
    set f [write_session [dict replace $sample frames {0 1 2}]]
    th::throws {::mdance::load_session $f} "*only 3 frames*"
    catch {file delete $f}
}
th::test "an empty label list is rejected" {
    set f [write_session [dict replace $sample labels {} clusterSizes {} \
        representatives {} nClusters 0]]
    th::throws {::mdance::load_session $f} "*no labels*"
    catch {file delete $f}
}
th::test "the consistent sample session still loads" {
    set f [write_session $sample]
    th::ok { ::mdance::load_session $f }
    catch {file delete $f}
}

th::section "load_session - the saved molecule must still BE that molecule"
th::test "a changed frame count marks the session not-live" {
    # A molid is just a slot number and VMD reuses it, so "molid 0 exists" is not
    # evidence that it holds the trajectory this session was computed from --
    # its frame indices would address a different molecule entirely.
    set ::mdance::results $sample
    set f [tmpfile]
    ::mdance::save_session $f
    set saved $::vmdstub::numframes
    set ::vmdstub::numframes [expr {$saved + 7}]
    set live [::mdance::load_session $f]
    set ::vmdstub::numframes $saved
    th::false $live "a different frame count means a different molecule"
    catch {file delete $f}
}
th::test "an unchanged molecule is still reported live" {
    set ::mdance::results $sample
    set f [tmpfile]
    ::mdance::save_session $f
    th::true [::mdance::load_session $f]
    catch {file delete $f}
}
th::test "a pre-molSignature session file still loads (backward compatible)" {
    set f [tmpfile]
    set old [dict create mdanceSession 1 savedAt "2026-01-01 00:00:00" results $sample]
    set fp [open $f w]; puts $fp $old; close $fp
    th::true [::mdance::load_session $f] "no signature -> fall back to the molid check"
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
