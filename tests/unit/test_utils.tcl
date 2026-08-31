# Unit tests for mdance_utils.tcl: parse_json, temp-file lifecycle, discovery.
set unitdir  [file dirname [file normalize [info script]]]
set testsdir [file dirname $unitdir]
set repo     [file dirname $testsdir]
source [file join $testsdir harness.tcl]
source [file join $testsdir stubs.tcl]
source [file join $repo mdance mdance.tcl]

# Parse a JSON string by writing it to a temp file (parse_json takes a path).
proc parse_str {json} {
    set f [::mdance::utils::mktmp .json]
    set fp [open $f w]; puts -nonewline $fp $json; close $fp
    set d [::mdance::utils::parse_json $f]
    catch {file delete $f}
    return $d
}

th::section "parse_json - scalars & strings"
th::test "integer fields" {
    set d [parse_str {{"nClusters": 3, "nFrames": 24}}]
    th::eq 3 [dict get $d nClusters]
    th::eq 24 [dict get $d nFrames]
}
th::test "string fields" {
    set d [parse_str {{"algorithm": "kmeans"}}]
    th::eq kmeans [dict get $d algorithm]
}
th::test "scores: plain floats" {
    set d [parse_str {{"scores": {"calinskiHarabasz": 12.5, "daviesBouldin": 0.8}}}]
    th::near 12.5 [dict get $d score_calinskiHarabasz] 1e-9
    th::near 0.8  [dict get $d score_daviesBouldin] 1e-9
}
th::test "scores: scientific notation" {
    set d [parse_str {{"scores": {"daviesBouldin": 2.5e-05}}}]
    th::near 2.5e-05 [dict get $d score_daviesBouldin] 1e-12
}
th::test "scores: negative value" {
    set d [parse_str {{"scores": {"x": -1.5}}}]
    th::near -1.5 [dict get $d score_x] 1e-9
}
th::test "top-level isim float" {
    set d [parse_str {{"isim": 0.4231}}]
    th::near 0.4231 [dict get $d isim] 1e-9
}

th::section "parse_json - non-finite (the hardening fix)"
th::test "Infinity score is captured, not dropped" {
    set d [parse_str {{"scores": {"calinskiHarabasz": Infinity, "daviesBouldin": 0.5}}}]
    th::true [dict exists $d score_calinskiHarabasz] "key must be present"
    th::eq Infinity [dict get $d score_calinskiHarabasz]
}
th::test "NaN score is captured, not dropped" {
    set d [parse_str {{"scores": {"calinskiHarabasz": 0.0, "daviesBouldin": NaN}}}]
    th::true [dict exists $d score_daviesBouldin] "key must be present"
    th::eq NaN [dict get $d score_daviesBouldin]
}
th::test "-Infinity isim is captured" {
    set d [parse_str {{"isim": -Infinity}}]
    th::eq -Infinity [dict get $d isim]
}

th::section "parse_json - arrays"
th::test "labels array incl. -1 sentinel" {
    set d [parse_str {{"labels": [0, 1, -1, 2]}}]
    th::eq {0 1 -1 2} [dict get $d labels]
}
th::test "indices array" {
    set d [parse_str {{"indices": [0, 2, 4]}}]
    th::eq {0 2 4} [dict get $d indices]
}
th::test "empty array yields empty list" {
    set d [parse_str {{"labels": []}}]
    th::eq {} [dict get $d labels]
}
th::test "absent optional key is simply missing (no crash)" {
    set d [parse_str {{"nClusters": 1}}]
    th::false [dict exists $d clusterMSD]
}

th::section "parse_json - errors"
th::test "missing file raises (callers wrap in catch)" {
    th::throws {::mdance::utils::parse_json /no/such/mdance_file.json}
}

th::section "mktmp / cleanup / tmpdir"
th::test "mktmp returns unique paths" {
    th::ne [::mdance::utils::mktmp .csv] [::mdance::utils::mktmp .csv]
}
th::test "mktmp path lives under tmpdir and carries the suffix" {
    set p [::mdance::utils::mktmp .json]
    th::match "*[::mdance::utils::tmpdir]*" $p
    th::match "*.json" $p
}
th::test "cleanup deletes registered temp files" {
    set p [::mdance::utils::mktmp .tmp]
    set fp [open $p w]; puts $fp "x"; close $fp
    th::true [file exists $p]
    ::mdance::utils::cleanup
    th::false [file exists $p]
}
th::test "tmpdir is an existing writable directory" {
    set d [::mdance::utils::tmpdir]
    th::true [file isdirectory $d]
    th::true [file writable $d]
}

th::section "find_cli / find_library - robustness"
th::test "find_cli returns an executable file given via MDANCE_CLI" {
    set ::env(MDANCE_CLI) [file join $testsdir fake_mdance_cli]
    th::eq [file join $testsdir fake_mdance_cli] [::mdance::utils::find_cli]
    unset ::env(MDANCE_CLI)
}
th::test "find_cli rejects a directory (isfile guard)" {
    # Point MDANCE_CLI at a directory; it must NOT be returned as the binary.
    set ::env(MDANCE_CLI) [::mdance::utils::tmpdir]
    set rc [catch {::mdance::utils::find_cli} res]
    set bad [expr {$rc == 0 && $res eq $::env(MDANCE_CLI)}]
    unset ::env(MDANCE_CLI)
    th::false $bad "a directory must never be accepted as mdance-cli"
}
th::test "find_library rejects a directory (isfile guard)" {
    set ::env(MDANCE_LIB) [::mdance::utils::tmpdir]
    set res [::mdance::utils::find_library]
    unset ::env(MDANCE_LIB)
    th::ne $res [::mdance::utils::tmpdir] "a directory must never be accepted as the library"
}

exit [th::done "unit:utils"]
