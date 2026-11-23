# The quick-start guide's benchmark: CPP-MDANCE's program (mdance-cli, run
# in the background) against its library (mdance_tcl, loaded into VMD), on
# the guide's trajectory, fitted as the guide's script fits it. Every job is
# timed whole, as a user waits for it: the coordinates written, the backend,
# its answer read, and the plugin's own measures. Writes the results as
# LaTeX macros (bench.tex).
#   cd quickstart-guide
#   TAU_DATA=<BitQT>/examples vmd -dispdev text -e bench.tcl -args out.tex < /dev/null
# (make bench does it.) The backend: MDANCE_CLI and MDANCE_LIB, else the
# CPP-MDANCE build beside the repository.
set here [pwd]
set root [file dirname $here]
set out [expr {[llength $argv] ? [file normalize [lindex $argv 0]] : [file join $here bench.tex]}]
set auto_path [linsert $auto_path 0 [file join $root vmdance]]

proc env_or {name default} {
    expr {[info exists ::env($name)] && $::env($name) ne "" ? $::env($name) : $default}
}
set ::macros {}
proc keep {name value} {
    if {![regexp {^[A-Za-z]+$} $name]} { error "macro name $name: letters only" }
    lappend ::macros $name $value
    puts [format "  %-18s %s" $name $value]
}
proc median {l} {
    set l [lsort -real $l]
    set n [llength $l]
    expr {$n % 2 ? [lindex $l [expr {$n / 2}]] : ([lindex $l [expr {$n / 2 - 1}]] + [lindex $l [expr {$n / 2}]]) / 2.0}
}
# VMD's resident memory, in MB (ps: Linux and macOS)
proc rss_mb {} { expr {[string trim [exec ps -o rss= -p [pid]]] / 1024.0} }
# Seconds as the table shows them
proc secs {s} { format [expr {$s < 10 ? "%.2f" : "%.1f"}] $s }

# The jobs: a name, the table's label, the subcommand ("" for a clustering)
# and its options. On the backbone only: the stability scan (the longest),
# and eQual, whose radius of 8 A^2 makes thousands of clusters of every
# atom, whose measures by the plugin (the same in both modes) took minutes.
set jobs {
    kmeans    {KMeans NANI, k 6}             ""    {-algorithm kmeans -k 6 -kinit CompSim}
    divine    {DIVINE, k 6}                  ""    {-algorithm divine -k 6}
    helm      {HELM, k 6 (from 60)}          ""    {-algorithm helm -k 6 -initial 60}
    equal     {eQual, radius 8}              ""    {-algorithm equal -threshold 8}
    elbow     {Elbow scan, k 2 to 12}        elbow {-kinit CompSim -from 2 -to 12}
    stability {Elbow scan with stability}    elbow {-kinit CompSim -from 2 -to 12 -stability 1}
}
set reps [env_or BENCH_REPS 3]
set backbone_only {stability equal}
# (BENCH_JOBS: some of the jobs only, to try the script)
set only [env_or BENCH_JOBS ""]

# One job, once: its seconds, and what it gave (the labels of a clustering;
# a scan's every k, its sizes and scores)
proc run_job {m sel sub opts} {
    vmdance run clear
    if {$sub eq ""} {
        set us [lindex [time {vmdance -mol $m -sel $sel {*}$opts -quiet 1}] 0]
        set what [dict values [vmdance labels]]
    } else {
        set us [lindex [time {vmdance $sub -mol $m -sel $sel {*}$opts -quiet 1}] 0]
        set what [lmap r [vmdance elbow show] {list [dict get $r k] [dict get $r sizes] [dict get $r ch] [dict get $r db]}]
    }
    vmdance run clear
    list [expr {$us / 1e6}] $what
}
# The two modes' answers alike: the labels and the sizes the same, the
# scores to a relative 1e-6 (the program's come as JSON text, the library's
# as doubles: their last digits can differ)
proc alike {a b} {
    if {[llength $a] != [llength $b]} { return 0 }
    foreach x $a y $b {
        if {[llength $x] > 1 || [llength $y] > 1} {
            if {![alike $x $y]} { return 0 }
        } elseif {$x ne $y} {
            if {![string is double -strict $x] || ![string is double -strict $y]} { return 0 }
            if {abs($x - $y) > 1e-6 * max(1.0, abs($x), abs($y))} { return 0 }
        }
    }
    return 1
}

if {[catch {
    package require vmdance
    set ::VMDance::Prefs::file ""
    set cli [file normalize [env_or MDANCE_CLI [file join $root .. CPP-MDANCE build cli mdance-cli]]]
    set lib [file normalize [env_or MDANCE_LIB [file join $root .. CPP-MDANCE build tcl mdance_tcl[info sharedlibextension]]]]
    if {![file executable $cli]} { error "no mdance-cli at $cli: set MDANCE_CLI" }
    if {![file isfile $lib]} { error "no mdance_tcl at $lib: set MDANCE_LIB (CPP-MDANCE built with -DBUILD_TCL=ON)" }
    set data [env_or TAU_DATA ""]
    foreach f {aligned_tau.pdb aligned_original_tau_6K.dcd} {
        if {![file isfile [file join $data $f]]} { error "no $f in \"$data\": set TAU_DATA to BitQT's examples folder" }
    }
    # the guide's trajectory and fit: the frame its script fits on, read there
    if {![regexp -line {^set fitframe ([0-9]+)$} [read [set fh [open [file join $here quickstart.tcl]]]] -> fitframe]} {
        error "quickstart.tcl sets no fitframe"
    }
    close $fh
    set m [mol new [file join $data aligned_tau.pdb] waitfor all]
    mol addfile [file join $data aligned_original_tau_6K.dcd] waitfor all molid $m
    animate delete beg 0 end 0 $m
    set backbone "resid 3 to 12 and name N CA C O H"
    set ref [atomselect $m $backbone frame $fitframe]
    set fit [atomselect $m $backbone]
    set all [atomselect $m all]
    for {set f 0} {$f < [molinfo $m get numframes]} {incr f} {
        $fit frame $f; $all frame $f; $all move [measure fit $fit $ref]
    }
    set natoms [$all num]
    $ref delete; $fit delete; $all delete

    keep bnFrames [molinfo $m get numframes]
    keep bnAtomsBackbone 50
    keep bnAtomsAll $natoms
    keep bnReps $reps
    keep bnFitFrame $fitframe
    set cpu ""
    catch { set cpu [exec sysctl -n machdep.cpu.brand_string] }
    if {$cpu eq ""} { catch { regexp -line {^model name\s*:\s*(.+)$} [exec cat /proc/cpuinfo] -> cpu } }
    keep bnMachine [string trim $cpu]

    # each mode in turn: a warm-up of each job (not counted), then the jobs,
    # each `reps` times; VMD's memory before and after
    set rows {}
    set same 0; set compared 0
    foreach mode {cli library} {
        if {$mode eq "cli"} { vmdance backend -mode cli -cli $cli } else { vmdance backend -mode library -library $lib }
        puts "\n$mode: [dict get [vmdance backend] using]"
        set mem0($mode) [rss_mb]
        foreach {input sel} [list backbone $backbone all all] {
            foreach {name label sub opts} $jobs {
                if {$name in $backbone_only && $input eq "all"} continue
                if {$only ne "" && $name ni $only} continue
                run_job $m $sel $sub $opts
                set ts {}
                for {set i 0} {$i < $reps} {incr i} {
                    lassign [run_job $m $sel $sub $opts] s what
                    lappend ts $s
                }
                set t($mode,$input,$name) [median $ts]
                set got($mode,$input,$name) $what
                puts [format "  %-8s %-9s %-10s %s s (%s)" $mode $input $name [secs $t($mode,$input,$name)] [join [lmap s $ts {secs $s}] " "]]
            }
        }
        set mem1($mode) [rss_mb]
    }

    # the table: a row a job and input; the two modes' medians, and how many
    # times the program's the library's is
    foreach {input sel} [list backbone $backbone all all] {
        set atoms [expr {$input eq "backbone" ? 50 : $natoms}]
        foreach {name label sub opts} $jobs {
            if {![info exists t(cli,$input,$name)]} continue
            set c $t(cli,$input,$name); set l $t(library,$input,$name)
            lappend rows "$label & $atoms & [secs $c] & [secs $l] & [format %.1f [expr {$c / $l}]]\\(\\times\\)"
            incr compared
            if {[alike $got(cli,$input,$name) $got(library,$input,$name)]} { incr same } else { puts "  not alike: $input $name" }
        }
    }
    keep bnRows [join $rows " \\\\\n"]
    keep bnCompared $compared
    keep bnSame $same
    # the largest and the smallest gain, and the clustering of every atom
    set gains [lmap k [array names t cli,*] {
        lassign [split $k ,] - input name
        expr {$t($k) / $t(library,$input,$name)}
    }]
    keep bnGainMin [format %.1f [::tcl::mathfunc::min {*}$gains]]
    keep bnGainMax [format %.1f [::tcl::mathfunc::max {*}$gains]]
    keep bnKmeansCli [secs $t(cli,backbone,kmeans)]
    keep bnKmeansLib [secs $t(library,backbone,kmeans)]
    keep bnKmeansAllCli [secs $t(cli,all,kmeans)]
    keep bnKmeansAllLib [secs $t(library,all,kmeans)]
    if {[info exists t(cli,backbone,stability)]} {
        keep bnStabilityCli [secs $t(cli,backbone,stability)]
        keep bnStabilityLib [secs $t(library,backbone,stability)]
    }
    keep bnMemCli [format %.0f [expr {$mem1(cli) - $mem0(cli)}]]
    keep bnMemLib [format %.0f [expr {$mem1(library) - $mem0(library)}]]
} err]} {
    puts "ERROR $err\n$::errorInfo"
    ::VMDance::Backend::cleanup
    quit
}

set fh [open $out w]
fconfigure $fh -encoding utf-8
puts $fh "% The quick-start guide's benchmark, made by bench.tcl (make bench): the"
puts $fh "% program against the library, medians of [dict get $::macros bnReps] runs. Do not edit."
foreach {name value} $::macros { puts $fh "\\newcommand{\\$name}{$value}" }
close $fh
puts "wrote $out"
::VMDance::Backend::cleanup
quit
