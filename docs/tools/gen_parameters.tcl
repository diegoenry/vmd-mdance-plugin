# Write docs/parameters.rst from the algorithms' table (Algo::A), so that
# the page says what the plugin checks.
#   cd <VMDance>; tclsh docs/tools/gen_parameters.tcl
set root [pwd]
set auto_path [linsert $auto_path 0 [file join $root vmdance]]
package require vmdance
set A ::VMDance::Algo
proc lim {type def lim} {
    switch -- $type {
        choice { return [join [lmap v $lim {string cat ``$v``}] ", "] }
        bool { return "0 or 1" }
        file { return "a file" }
        default {
            lassign $lim lo hi
            set s [expr {$type eq "int" ? "whole number" : "number"}]
            if {$lo ne "" && $hi ne ""} { return "$s, $lo to $hi" }
            if {$lo ne ""} { return "$s, at least $lo" }
            if {$hi ne ""} { return "$s, at most $hi" }
            return $s
        }
    }
}
# The Default cell: the value, or what the checker (Algo::check_value)
# makes of none: refused, "(needed)"; taken, "(none)" (HELM's label file:
# it starts from the -initial clustering then)
proc default_cell {spec} {
    set def [lindex $spec 2]
    if {$def ne ""} { return "``$def``" }
    expr {[catch {::VMDance::Algo::check_value $spec "" 1}] ? "(needed)" : "(none)"}
}
set out {}
lappend out ".. This page is written by docs/tools/gen_parameters.tcl from the plugin's" \
    "   table of parameters (lib/algorithms.tcl): edit that, and run it again." "" \
    "Parameters" "==========" "" \
    "Every parameter is an option of the command (``-name value``), a field of" \
    "the window's Setup tab, and — but for the few that are the plugin's own —" \
    "an option of ``mdance-cli`` of the same name (``--name``). Its default is" \
    "the MDANCE plugin's (but DIVINE's Refine: :doc:`algorithms`)." \
    "``vmdance parameters algorithm`` lists them in a" \
    "script. A number is 0, or between 1.2e-38 and 3.4e38 in size:" \
    "``mdance-cli`` reads HELM's as C floats, the others as doubles, and fails" \
    "on one beyond (a session's run that holds one still opens)." ""
foreach a [${A}::all] {
    set t [${A}::label $a]
    lappend out $t [string repeat - [string length $t]] ""
    lappend out "[string totitle [${A}::get $a about] 0 0]." ""
    set ms [${A}::metrics_of $a]
    set met [expr {[llength $ms] > 1 ? "``-metric``: see :doc:`algorithms`." : "``-metric``: [join $ms {, }] only (see :doc:`algorithms`)."}]
    if {[${A}::takes_k $a]} {
        lappend out "``-k``: the number of clusters (default [${A}::default_k $a][expr {$a eq "helm" ? "; 0: stop by ``-eps`` only" : ""}]). $met" ""
    } else {
        lappend out "No ``-k``: the number of clusters follows from the radius. $met" ""
    }
    lappend out ".. list-table::" "   :header-rows: 1" "   :widths: 18 12 22 48" "" \
        "   * - Option" "     - Default" "     - Values" "     - Meaning"
    foreach p [${A}::params $a] {
        lassign $p name type def lim label tip
        set local [expr {$name in [${A}::get $a local] ? " (the plugin's own: not passed to the backend)" : ""}]
        lappend out "   * - ``-$name``" "     - [default_cell $p]" "     - [lim $type $def $lim]" \
            "     - **$label**: $tip$local"
    }
    lappend out ""
}
foreach {title specs} [list "PRIME" $::VMDance::Algo::prime_params "Similarity (iSIM)" $::VMDance::Algo::similarity_params \
                            "Frame picks" $::VMDance::Algo::pick_params] {
    lappend out $title [string repeat - [string length $title]] ""
    lappend out ".. list-table::" "   :header-rows: 1" "   :widths: 18 12 22 48" "" \
        "   * - Option" "     - Default" "     - Values" "     - Meaning"
    foreach p $specs {
        lassign $p name type def lim label tip
        lappend out "   * - ``-$name``" "     - [default_cell $p]" "     - [lim $type $def $lim]" "     - **$label**: $tip"
    }
    lappend out ""
}
set fh [open [file join $root docs parameters.rst] w]
fconfigure $fh -encoding utf-8
puts $fh [join $out \n]
close $fh
puts "wrote docs/parameters.rst"
