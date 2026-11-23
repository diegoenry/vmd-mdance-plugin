# The quick-start guide's numbers. Runs the guide's own script
# (quickstart.tcl) on the tau peptide of BitQT's examples, then reads back from the plugin
# every value the guide quotes, and writes them as LaTeX macros.
#   cd quickstart-guide
#   TAU_DATA=<BitQT>/examples vmd -dispdev text -e numbers.tcl -args out.tex < /dev/null
# (make numbers does it.) The backend: MDANCE_CLI, else the CPP-MDANCE build
# beside the repository (../CPP-MDANCE/build/cli/mdance-cli). Settings'
# choice (~/.vmdance.prefs) is not read.
set here [pwd]
set root [file dirname $here]
set out [expr {[llength $argv] ? [file normalize [lindex $argv 0]] : [file join $here numbers.tex]}]
set auto_path [linsert $auto_path 0 [file join $root vmdance]]

proc env_or {name default} {
    expr {[info exists ::env($name)] && $::env($name) ne "" ? $::env($name) : $default}
}
# Text for LaTeX: its special characters escaped, and the few non-ASCII ones
# the plugin writes turned into LaTeX.
proc tex {s} {
    string map [list \\ {\textbackslash{}} & {\&} % {\%} \$ {\$} # {\#} _ {\_} \
        \{ {\{} \} {\}} ~ {\textasciitilde{}} ^ {\textasciicircum{}} \
        – -- — --- Å {\AA{}} ² {\textsuperscript{2}} \
        ≥ {$\geq$} ≤ {$\leq$} × {$\times$} → {$\rightarrow$}] $s
}
# "a, b and c"
proc and_list {items} {
    if {[llength $items] < 2} { return [join $items] }
    return "[join [lrange $items 0 end-1] {, }] and [lindex $items end]"
}
set ::macros {}
proc keep {name value} {
    if {![regexp {^[A-Za-z]+$} $name]} { error "macro name $name: letters only" }
    lappend ::macros $name $value
    puts [format "  %-22s %s" $name $value]
}
proc frac {x n} { format %.${n}f $x }

if {[catch {
    package require vmdance
    set ::VMDance::Prefs::file ""
    set cli [file normalize [env_or MDANCE_CLI [file join $root .. CPP-MDANCE build cli mdance-cli]]]
    if {![file executable $cli]} { error "no mdance-cli at $cli: set MDANCE_CLI" }
    vmdance backend -mode cli -cli $cli
    set data [env_or TAU_DATA ""]
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} {
        if {![file isfile [file join $data $f]]} {
            error "no $f in \"$data\": set TAU_DATA to BitQT's examples folder"
        }
    }
    # the script runs in a folder of its own, with the two files, as a reader's would
    set work [file join $here build run]
    file delete -force $work
    file mkdir $work
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} { file copy [file join $data $f] $work }
    cd $work

    # the guide's script, as printed: its quit kept for the end
    rename ::quit ::_qs_quit
    proc ::quit {args} {}
    set t0 [clock milliseconds]
    uplevel #0 [list source [file join $here quickstart.tcl]]
    set seconds [expr {([clock milliseconds] - $t0) / 1000.0}]
    rename ::quit {}
    rename ::_qs_quit ::quit
    puts "\nThe guide's numbers:"

    # where it ran
    keep qsVMD [vmdinfo version]
    keep qsArch [vmdinfo arch]
    keep qsTcl [info patchlevel]
    set cpp [file dirname [file dirname [file dirname $cli]]]
    set commit ""
    catch { set commit [exec git -C $cpp rev-parse --short HEAD] }
    keep qsBackendCommit $commit
    keep qsMinutes [expr {max(1, round($seconds / 60.0))}]
    set cpu ""
    catch { set cpu [exec sysctl -n machdep.cpu.brand_string] }
    if {$cpu eq ""} {
        catch { regexp -line {^model name\s*:\s*(.+)$} [exec cat /proc/cpuinfo] -> cpu }
    }
    keep qsMachine [tex [string trim $cpu]]
    keep qsVersion [package present vmdance]

    # 1-3: the frames, the atoms, the fit
    set nf [molinfo $m get numframes]
    keep qsFrames $nf
    set s [atomselect $m $sel]
    keep qsAtoms [$s num]
    # (the frame the script fitted on: its fitframe)
    keep qsFitFrame $fitframe
    # how far VMD's measure fit (the script's) is from the least RMSD to
    # that frame: each frame as the script moved it, against the plugin's
    # exact fit (Horn's quaternion) of the same coordinates
    set r [atomselect $m $sel frame $fitframe]
    set Y [$r get {x y z}]
    set R [::VMDance::Coords::fit_ref $Y]
    set worst 0.0; set sum 0.0
    for {set f 0} {$f < $nf} {incr f} {
        $s frame $f
        set X [$s get {x y z}]
        set M [::VMDance::Coords::fit_matrix $X $R]
        set d2 0.0; set e2 0.0
        foreach x $X y $Y {
            set z [coordtrans $M $x]
            set d2 [expr {$d2 + [veclength2 [vecsub $x $y]]}]
            set e2 [expr {$e2 + [veclength2 [vecsub $z $y]]}]
        }
        set n [llength $X]
        set gap [expr {sqrt($d2 / $n) - sqrt($e2 / $n)}]
        set sum [expr {$sum + sqrt($d2 / $n)}]
        if {$gap > $worst} { set worst $gap }
    }
    $r delete; $s delete
    # (in thousandths of an angstrom, at least one: "within 0.001")
    keep qsFitWorst [format %.3f [expr {max($worst, 0.001)}]]
    keep qsFitMean [frac [expr {$sum / $nf}] 2]
    set al [vmdance alignment -mol $m -sel $sel]
    keep qsAsIs [frac [dict get $al as_is] 2]
    keep qsFitted [frac [dict get $al fitted] 2]
    keep qsSuperposed [dict get $al superposed]

    # 4: the elbow scan, a row of the table a k
    set rows {}
    set ks {}
    foreach rec [vmdance elbow show] {
        set kk [dict get $rec k]
        lappend ks $kk
        # (if, not expr's ?: which would read "1.00" back as the number 1.0)
        set st [dict get $rec stability]
        if {$st eq ""} { set stab($kk) -- } else { set stab($kk) [frac $st 2] }
        set ch($kk) [frac [dict get $rec ch] 0]
        set db($kk) [frac [dict get $rec db] 2]
        lappend rows "$kk & $ch($kk) & $db($kk) &\
            [frac [expr {100 * [::VMDance::Results::explained $rec]}] 0]\\% & $stab($kk)"
    }
    keep qsElbowRows [join $rows " \\\\\n"]
    set sg [vmdance elbow suggest]
    set lo [dict get $sg db_lowest]
    set dip [dict get $sg db_dip]
    set hi [dict get $sg ch_highest]
    set stable [dict get $sg stable]
    keep qsDbLowest $lo
    keep qsDbLowestValue $db($lo)
    keep qsChHighest $hi
    keep qsChHighestValue $ch($hi)
    keep qsChFirst $ch([lindex $ks 0])
    keep qsChLast $ch([lindex $ks end])
    keep qsKFirst [lindex $ks 0]
    keep qsKLast [lindex $ks end]
    keep qsDbDip $dip
    keep qsDbDipValue $db($dip)
    keep qsDbDipBeforeK [expr {$dip - 1}]
    keep qsDbDipBefore $db([expr {$dip - 1}])
    keep qsDbDipAfterK [expr {$dip + 1}]
    keep qsDbDipAfter $db([expr {$dip + 1}])
    keep qsDbDipStability $stab($dip)
    keep qsStable [and_list $stable]
    keep qsStableValues [and_list [lmap kk $stable {set stab($kk)}]]
    keep qsStableLast [lindex $stable end]
    keep qsStableLastValue $stab([lindex $stable end])
    # the stability above the largest stable k
    set above [lmap kk $ks {expr {$kk > [lindex $stable end] && $stab($kk) ne "--" ? $stab($kk) : [continue]}}]
    keep qsAboveFrom [expr {[lindex $stable end] + 1}]
    keep qsAboveMin [frac [::tcl::mathfunc::min {*}$above] 2]
    keep qsAboveMax [frac [::tcl::mathfunc::max {*}$above] 2]
    keep qsSuggestWords [tex [dict get $sg words]]

    # 5: the clustering (run 1)
    vmdance run 1
    set inf [vmdance info]
    set K [dict get $inf k]
    keep qsK $K
    # the scan's values at that k
    keep qsKStability $stab($K)
    keep qsKCh $ch($K)
    keep qsKDb $db($K)
    # how long the trajectory stays in a cluster: the clusters' mean stays
    set stays [lmap row [vmdance residence] {lindex $row 2}]
    keep qsStayMin [frac [::tcl::mathfunc::min {*}$stays] 1]
    keep qsStayMax [frac [::tcl::mathfunc::max {*}$stays] 1]
    keep qsRunOne [tex [lindex [lsearch -inline -index 0 [vmdance runs] 1] 1]]
    set sizes {}; set pcts {}; set reps {}
    for {set c 0} {$c < $K} {incr c} {
        set d [vmdance get $c]
        lappend sizes [dict get $d frames]
        lappend pcts [frac [dict get $d percent] 0]
        lappend reps [dict get $d representative]
    }
    keep qsSizes [and_list $sizes]
    keep qsPcts [and_list $pcts]
    keep qsReps [and_list $reps]
    keep qsCH [frac [dict get $inf ch] 0]
    keep qsDB [frac [dict get $inf db] 2]
    keep qsSilCentroid [frac [dict get [vmdance silhouette] mean] 2]
    set sp [vmdance silhouette -kind pairs]
    set neg 0
    foreach v [dict values [dict get $sp frames]] { if {$v < 0} { incr neg } }
    keep qsSilPairs [frac [dict get $sp mean] 2]
    keep qsSilNegative $neg
    keep qsSilNegativePct [frac [expr {100.0 * $neg / $nf}] 0]

    # 6: the halves
    set mk [vmdance makeup]
    set g [vmdance groups]
    lassign [dict get $g sizes] na nb
    keep qsHalfFirst $na
    keep qsHalfSecond $nb
    set cmp [vmdance groups compare]
    lassign [lindex [dict get $cmp pairs] 0] ga gb div diff dc
    keep qsDivergence [frac $div 3]
    keep qsDiffCluster $dc
    keep qsDiffPoints [frac [expr {100 * $diff}] 0]
    lassign [dict get $mk $dc] a b
    keep qsDiffFirst $a
    keep qsDiffSecond $b
    keep qsDiffFirstPct [frac [expr {100.0 * $a / $na}] 0]
    keep qsDiffSecondPct [frac [expr {100.0 * $b / $nb}] 0]
    set allvisit 1
    dict for {c row} $mk { if {[lindex $row 0] == 0 || [lindex $row 1] == 0} { set allvisit 0 } }
    keep qsBothVisitAll $allvisit
    keep qsCompareWords [tex [dict get $cmp words]]
    lassign [dict get [vmdance map] variance] v1 v2
    keep qsMapOne [frac [expr {100 * $v1}] 0]
    keep qsMapTwo [frac [expr {100 * $v2}] 0]

    # 7: the second opinions (runs 2 to 4), and how alike their clusters
    # are to run 1's (the adjusted Rand index: 1, the same clusters)
    set ref [dict values [vmdance labels]]
    foreach id {2 3 4} name {Divine Helm Equal} {
        vmdance run $id
        set i [vmdance info]
        keep qs${name}Label [tex [lindex [lsearch -inline -index 0 [vmdance runs] $id] 1]]
        keep qs${name}Clusters [dict get $i nclusters]
        keep qs${name}Sizes [and_list [dict get $i sizes]]
        keep qs${name}Noise [dict get $i noise]
        keep qs${name}Ari [frac [::VMDance::Measure::ari $ref [dict values [vmdance labels]]] 2]
    }
    # the sweep's best configuration by Davies-Bouldin, and how many ran
    set best [vmdance sweep best db]
    keep qsSweepBest [tex "[dict get {kmeans {KMeans NANI} divine DIVINE helm HELM} [dict get $best algorithm]],\
        k [dict get $best k], [dict get $best seeding]"]
    keep qsSweepBestDb [frac [dict get $best db] 2]
    set recs [vmdance sweep show]
    keep qsSweepConfigs [llength $recs]
    set notrun 0
    foreach rec $recs { if {[dict get $rec status] ne "ok"} { incr notrun } }
    keep qsSweepNotRun $notrun
    # the largest eQual clusters, and the share of the frames they hold
    set es [lsort -integer -decreasing [dict get $i sizes]]
    keep qsEqualTopThree [and_list [lrange $es 0 2]]
    keep qsEqualTopThreePct [frac [expr {100.0 * ([lindex $es 0] + [lindex $es 1] + [lindex $es 2]) / $nf}] 0]
    vmdance run 1
    keep qsRuns [llength [vmdance runs]]

    # 8: what was kept
    keep qsExportFiles [tex [join [lsort [lmap f [glob -directory tau_results *] {file tail $f}]] {, }]]
    keep qsSessionKB [expr {max(1, round([file size tau.vmdance] / 1024.0))}]
} err]} {
    puts "ERROR $err\n$::errorInfo"
    cd $here
    ::VMDance::Backend::cleanup
    quit
}

set fh [open $out w]
fconfigure $fh -encoding utf-8
puts $fh "% The quick-start guide's numbers, made by numbers.tcl (make numbers):"
puts $fh "% its script, quickstart.tcl, run on the tau peptide of BitQT's examples. Do not edit."
foreach {name value} $::macros { puts $fh "\\newcommand{\\$name}{$value}" }
close $fh
puts "wrote $out"
cd $here
::VMDance::Backend::cleanup
quit
