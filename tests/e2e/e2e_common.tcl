# Shared by the end-to-end phases (tests/e2e/run_e2e.sh): the suites'
# helpers, the folder the phases share, timings, and the state of the
# plugin as the command reads it, to be compared across VMD sessions.
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::E [file join $::out e2e]
file mkdir $::E
set ::R ::VMDance::Results

# A step of work, timed; its time goes to timings.txt (the profiling reads it).
proc timed {tag script} {
    set t0 [clock microseconds]
    set code [catch {uplevel 1 $script} r opts]
    set ms [expr {([clock microseconds] - $t0) / 1000.0}]
    set fh [open [file join $::E timings.txt] a]
    puts $fh [format "%-12s %10.1f ms  %s" $::phase $ms $tag]
    close $fh
    puts "TIME [format %.0f $ms] ms: $tag"
    return -options $opts $r
}

# Every answer of the command about every run, the scans and the picks
# (the molecule's id left out: a session may load it under another).
proc state_of {} {
    set R $::R
    set s [dict create runs [vmdance runs] select [vmdance select]]
    set cur [lindex [lsearch -inline -index 2 [vmdance runs] 1] 0]
    foreach r [vmdance runs] {
        set id [lindex $r 0]
        vmdance run $id
        set sel [vmdance select]
        dict set s run$id [dict create \
            info [dict remove [vmdance info] molid] clusters [vmdance clusters] labels [vmdance labels] \
            silhouette [vmdance silhouette] distances [vmdance distances] tree [vmdance tree] \
            transitions [vmdance transitions -counts 1] residence [vmdance residence] \
            prime [${R}::extra prime] similarity [${R}::extra similarity]]
    }
    # (switching runs clears the selection: put back as it was)
    if {$cur ne ""} { vmdance run $cur; if {[llength [dict get $s select]]} { vmdance select {*}[dict get $s select] } }
    dict set s elbow [expr {[dict size $::VMDance::Results::elbow] ? [vmdance elbow show] : {}}]
    dict set s sweep [expr {[dict size $::VMDance::Results::sweep] ? [vmdance sweep show] : {}}]
    dict set s picks [expr {[dict size $::VMDance::Results::picks] ? [vmdance pick show] : {}}]
    return $s
}
proc save_state {name} {
    set fh [open [file join $::E $name] w]
    fconfigure $fh -encoding utf-8
    puts $fh [state_of]
    close $fh
}
proc read_state {name} {
    set fh [open [file join $::E $name]]
    fconfigure $fh -encoding utf-8
    set s [string trim [read $fh]]
    close $fh
    return $s
}
# What differs between two states: "key", "runN part" or "runN info key".
proc diff_state {a b} {
    set out {}
    foreach k [lsort -unique [concat [dict keys $a] [dict keys $b]]] {
        if {![dict exists $a $k] || ![dict exists $b $k]} { lappend out $k; continue }
        set va [dict get $a $k]; set vb [dict get $b $k]
        if {![regexp {^run[0-9]+$} $k]} {
            if {$va ne $vb} { lappend out $k }
            continue
        }
        foreach q [lsort -unique [concat [dict keys $va] [dict keys $vb]]] {
            if {![dict exists $va $q] || ![dict exists $vb $q]} { lappend out "$k $q"; continue }
            set x [dict get $va $q]; set y [dict get $vb $q]
            if {$q eq "info"} {
                foreach i [lsort -unique [concat [dict keys $x] [dict keys $y]]] {
                    if {![dict exists $x $i] || ![dict exists $y $i] || [dict get $x $i] ne [dict get $y $i]} { lappend out "$k info $i" }
                }
            } elseif {$x ne $y} {
                lappend out "$k $q"
            }
        }
    }
    return $out
}
# Rows of a CSV the plugin wrote (the # lines left out).
proc table {f} {
    set out {}
    foreach line [split [read_text $f] \n] {
        if {$line eq "" || [string index $line 0] eq "#"} continue
        lappend out [split $line ,]
    }
    return $out
}
# The largest coordinate difference between frame fa of molecule a and fb
# of b (atoms: a selection text in both).
proc coord_diff {a fa b fb {sel all}} {
    set sa [atomselect $a $sel frame $fa]; set sb [atomselect $b $sel frame $fb]
    set d 0.0
    foreach p [$sa get {x y z}] q [$sb get {x y z}] {
        foreach u $p v $q { set d [expr {max($d, abs($u - $v))}] }
    }
    $sa delete; $sb delete
    return $d
}
