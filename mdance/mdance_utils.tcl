# mdance_utils.tcl - Utility procedures for the MDANCE VMD plugin
#
# Provides JSON parsing, CLI binary location, and temp file management.

namespace eval ::mdance {}
namespace eval ::mdance::utils {
    variable tmpfiles {}
    variable tmpseq 0
}

# is_finite - True when $v is a real number safe to do arithmetic and formatting
# with. `string is double` alone is not enough: it accepts the NaN/Infinity
# tokens the backend emits for degenerate clusterings, and those poison every
# consumer -- NaN makes any expr raise "domain error" and format %f raise, while
# Inf survives both but blows up canvas coordinate math. Callers use this to tell
# "no score" from "a score", instead of letting the token reach the plot.
proc ::mdance::utils::is_finite {v} {
    if {![string is double -strict $v]} { return 0 }
    if {[catch {format %f $v}]} { return 0 }
    return [expr {abs($v) != Inf}]
}

# parse_json - Minimal JSON parser for mdance-cli output
# Returns a Tcl dict with the parsed JSON structure.
# Only handles the known output format: flat objects, arrays of numbers,
# nested score object, and optional zMatrix array of arrays.
proc ::mdance::utils::parse_json {filepath} {
    set fp [open $filepath r]
    set rc [catch {read $fp} content opts]
    catch {close $fp}
    if {$rc} { return -options $opts $content }

    set result [dict create]

    # Extract string values: "key": "value"
    foreach {_ key val} [regexp -all -inline {"(\w+)":\s*"([^"]*)"} $content] {
        dict set result $key $val
    }

    # Extract top-level integer values: "key": 123
    set intPat {"(\w+)":\s*(-?\d+)\s*[,\x7d\n]}
    foreach {_ key val} [regexp -all -inline $intPat $content] {
        if {$key ne "calinskiHarabasz" && $key ne "daviesBouldin"} {
            dict set result $key $val
        }
    }

    # Extract scores block
    set scoresPat {"scores":\s*\x7b([^\x7d]*)\x7d}
    if {[regexp $scoresPat $content _ scoreBlock]} {
        # Accept the non-finite tokens Python's json.dumps emits for degenerate
        # clusterings (NaN / Infinity / -Infinity) so the key is captured rather
        # than silently dropped (callers display "n/a" for a non-finite score).
        foreach {_ key val} [regexp -all -inline {"(\w+)":\s*(-?Infinity|NaN|-?[\d.eE+-]+)} $scoreBlock] {
            dict set result "score_$key" $val
        }
    }

    # Top-level float values (e.g. analysis "isim")
    if {[regexp {"isim":\s*(-?Infinity|NaN|-?[0-9.eE+-]+)} $content _ isimVal]} {
        dict set result isim $isimVal
    }

    # Helper: extract a JSON array of numbers by key name
    foreach arrKey {labels clusterSizes representatives clusterMSD clusterISIM clusterOutliers indices} {
        set arrPat "\"$arrKey\":\\s*\\\[(\[^\\]\]*)\\\]"
        if {[regexp $arrPat $content _ arrStr]} {
            set arrList {}
            foreach val [split $arrStr ","] {
                set val [string trim $val]
                if {$val ne ""} {
                    lappend arrList $val
                }
            }
            dict set result $arrKey $arrList
        }
    }

    # Extract zMatrix (array of arrays) if present
    set zPat "\"zMatrix\":\\s*\\\[(.+)\\\]\\s*\x7d"
    if {[regexp $zPat $content _ zStr]} {
        set zMatrix {}
        set rowPat "\\\[(\[^\\]\]*)\\\]"
        foreach {_ row} [regexp -all -inline $rowPat $zStr] {
            set rowList {}
            foreach val [split $row ","] {
                set val [string trim $val]
                if {$val ne ""} {
                    lappend rowList $val
                }
            }
            lappend zMatrix $rowList
        }
        dict set result zMatrix $zMatrix
    }

    return $result
}

# find_cli - Locate the mdance-cli binary
# Search order: $MDANCE_CLI env var, plugin directory, PATH
proc ::mdance::utils::find_cli {} {
    # 1. Check environment variable
    if {[info exists ::env(MDANCE_CLI)] && [file isfile $::env(MDANCE_CLI)] \
            && [file executable $::env(MDANCE_CLI)]} {
        return $::env(MDANCE_CLI)
    }

    # 2. Check relative to plugin directory
    set pluginDir [file dirname [file dirname [info script]]]
    set candidates [list \
        [file join $pluginDir mdance-cli] \
        [file join $pluginDir .. .. build cli mdance-cli] \
        [file join $pluginDir .. .. .. build cli mdance-cli] \
    ]
    foreach candidate $candidates {
        set candidate [file normalize $candidate]
        if {[file isfile $candidate] && [file executable $candidate]} {
            return $candidate
        }
    }

    # 3. Check PATH (auto_execok is cross-platform and honors PATHEXT on Windows,
    # unlike `which`, which does not exist there)
    set found [auto_execok mdance-cli]
    if {$found ne "" && [file isfile [lindex $found 0]]} {
        return [lindex $found 0]
    }

    error "Could not find mdance-cli binary. Set MDANCE_CLI environment variable or ensure it is in your PATH."
}

# find_library - Locate the mdance Tcl extension shared library
# Search order: $MDANCE_LIB env var, plugin directory, common build paths
# Returns: path to library, or empty string if not found
proc ::mdance::utils::find_library {} {
    set ext [info sharedlibextension]
    set libname "mdance_tcl$ext"

    # 1. Check environment variable
    if {[info exists ::env(MDANCE_LIB)] && [file isfile $::env(MDANCE_LIB)]} {
        return $::env(MDANCE_LIB)
    }

    # 2. Check relative to plugin directory
    set pluginDir [file dirname [file dirname [info script]]]
    set candidates [list \
        [file join $pluginDir $libname] \
        [file join $pluginDir .. .. build tcl $libname] \
        [file join $pluginDir .. .. .. build tcl $libname] \
        [file join $pluginDir .. .. build capi libmdance$ext] \
    ]
    foreach candidate $candidates {
        set candidate [file normalize $candidate]
        if {[file isfile $candidate]} {
            return $candidate
        }
    }

    return ""
}

# tmpdir - Return a writable temp directory
# Probes the standard temp-dir env vars in order, validating each is a writable
# directory (so a stale/non-writable TMPDIR is skipped rather than trusted), then
# falls back per-platform. On Windows TMPDIR is usually unset and "/tmp" does not
# exist, so TEMP/TMP (and a SystemRoot\Temp fallback) are essential there.
proc ::mdance::utils::tmpdir {} {
    foreach v {TMPDIR TEMP TMP} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)] \
                && [file writable $::env($v)]} {
            return $::env($v)
        }
    }
    if {$::tcl_platform(platform) eq "windows"} {
        if {[info exists ::env(SystemRoot)] \
                && [file isdirectory [file join $::env(SystemRoot) Temp]]} {
            return [file join $::env(SystemRoot) Temp]
        }
        return "C:/Temp"
    }
    return "/tmp"
}

# mktmp - Create a temp file path and register it for cleanup
proc ::mdance::utils::mktmp {suffix} {
    variable tmpfiles
    variable tmpseq
    incr tmpseq
    set path [file join [tmpdir] "mdance_[pid]_[clock milliseconds]_$tmpseq$suffix"]
    lappend tmpfiles $path
    return $path
}

# cleanup - Remove all registered temp files
proc ::mdance::utils::cleanup {} {
    variable tmpfiles
    foreach f $tmpfiles {
        catch {file delete -force $f}
    }
    set tmpfiles {}
}
