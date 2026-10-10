# Shared by the tests: paths, the test systems, the backends, check.
#   cd <VMDance>; vmd -dispdev text -e tests/test_results.tcl < /dev/null
# (VMD's -e does not set [info script], so paths are taken from the cwd or
# from $VMDANCE_ROOT.)
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
set auto_path [linsert $auto_path 0 [file join $::root vmdance]]
proc ::_env {name default} { expr {[info exists ::env($name)] && $::env($name) ne "" ? $::env($name) : $default} }
# the shared test systems (VMD-testsystems: 3ptb, trypsin and benzamidine,
# 100 frames), the plugin's fixtures (CA-only multi-model PDBs), MDANCE's
# reference runs (the heptapeptide and protein G, with MDANCE's results)
set ::systems [_env VMDANCE_SYSTEMS /home/dgomes/github/myprojects/vmd-plugin-projects/vmd-interactions-v2/VMD-testsystems/systems]
set ::fixtures [file join $::root tests fixtures]
set ::refruns [_env MDANCE_REF_RUNS /home/dgomes/Downloads/mdance_vmd_runs]
set ::fake [file join $::root tests fake_mdance_cli]
set ::out [_env VMDANCE_OUT [file join $::root tests out]]
file mkdir $::out
set ::fails 0
set ::checks 0
set ::skips 0
proc check {what cond} {
    incr ::checks
    if {$cond} { puts "PASS $what" } else { puts "FAIL $what"; incr ::fails }
}
proc skip {what why} {
    incr ::skips
    puts "SKIP $what ($why)"
}
# The error message of a script, or "" when it succeeds.
proc err {script} {
    if {[catch {uplevel 1 $script} msg]} { return $msg }
    return ""
}
proc done {} {
    puts "RESULT checks=$::checks fails=$::fails skips=$::skips"
}
proc near {a b {tol 1e-6}} {
    expr {abs($a - $b) <= $tol * max(1.0, abs($a), abs($b))}
}
proc read_text {f} {
    set fh [open $f r]
    fconfigure $fh -encoding utf-8
    try { return [read $fh] } finally { close $fh }
}
proc csv_rows {f} {
    lmap l [split [string trimright [read_text $f] \n] \n] {expr {[string index $l 0] eq "#" ? [continue] : [split $l ,]}}
}

# The real backend (a CPP-MDANCE build): MDANCE_CLI and MDANCE_LIB, else
# the build beside the plugin's folder.
# (normalized, as the plugin keeps them: a path given as "a/../b" is
# compared with the plugin's answers)
proc real_cli {} {
    set p [file normalize [_env MDANCE_CLI [file join $::root .. CPP-MDANCE build cli mdance-cli]]]
    expr {[file executable $p] && [file tail $p] ne "fake_mdance_cli" ? $p : ""}
}
proc real_lib {} {
    set p [file normalize [_env MDANCE_LIB [file join $::root .. CPP-MDANCE build tcl mdance_tcl[info sharedlibextension]]]]
    expr {[file isfile $p] ? $p : ""}
}
# The fake backend (tests/fake_mdance_cli: deterministic, its own simple
# clustering) as the program; env hooks set by the caller.
proc use_fake {} {
    ::VMDance::Backend::configure -mode cli -cli $::fake
}
proc use_cli {} {
    ::VMDance::Backend::configure -mode cli -cli [real_cli]
}
proc use_lib {} {
    ::VMDance::Backend::configure -mode library -library [real_lib]
}
proc fake_env {args} {
    foreach v {MDANCE_FAKE_FAIL MDANCE_FAKE_FAIL_K MDANCE_FAKE_SLEEP MDANCE_FAKE_IGNORE_TERM MDANCE_FAKE_TRUNCATE
               MDANCE_FAKE_EXTRA_LABELS MDANCE_FAKE_NO_DIVINE MDANCE_FAKE_FLOOD MDANCE_FAKE_NOLINE} { unset -nocomplain ::env($v) }
    foreach {k v} $args { set ::env($k) $v }
    array unset ::VMDance::Backend::caps *
}

# A system: 3ptb (trypsin and benzamidine, PSF and 100 frames), or a
# fixture (two_state: 24 frames × 8 atoms, two states; outlier: 12 × 6,
# frame 6 far away; single_state: 10 × 5).
proc load_system {name} {
    switch -- $name {
        3ptb {
            set m [mol new [file join $::systems 3ptb complex.psf] waitfor all]
            mol addfile [file join $::systems 3ptb traj.dcd] waitfor all molid $m
        }
        default { set m [mol new [file join $::fixtures $name.pdb] waitfor all] }
    }
    animate goto 0
    return $m
}
# A reference run's trajectory (its PDB's frame deleted: MDANCE clustered
# the DCD's frames).
proc load_ref {name} {
    switch -- $name {
        heptapeptide { set d [file join $::refruns inputs 1_heptapeptide]; set pdb aligned_tau.pdb }
        proteing { set d [file join $::refruns inputs 2_protein-g]; set pdb 3gb1.pdb }
    }
    set m [mol new [file join $d $pdb] waitfor all]
    mol addfile [file join $d backbone_aligned.dcd] waitfor all molid $m
    animate delete beg 0 end 0 $m
    animate goto 0
    return $m
}

# The plugin's private files left (none after a job).
proc leftovers {} {
    set d $::VMDance::Backend::workdir
    if {$d eq "" || ![file isdirectory $d]} { return {} }
    glob -nocomplain -directory $d *
}
