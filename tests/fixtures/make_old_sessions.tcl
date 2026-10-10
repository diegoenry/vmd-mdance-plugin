# The sessions of the MDANCE plugin that test_session and test_hardening2_oi
# import, written by that plugin itself (its run_clustering, run_one_config
# and save_session, its files read only) with the real mdance-cli: their
# clusterMSD is MDANCE's, which an import checks against the molecule's
# coordinates. old_kmeans.mdance, old_helm.mdance; old_helm_labels.mdance,
# HELM started from a label file (old_helm_labels.txt, named as typed in
# its HELM tab, from the VMDance folder); old_helm_trim.mdance, HELM
# with its loosest starting clusters trimmed; old_sweep.mdance, a
# configuration of its sweep loaded with Load Selected (no inputParams).
# Text-mode VMD, Tk stood in for:
#   cd <VMDance>; MDANCE_CLI=../CPP-MDANCE/build/cli/mdance-cli TMPDIR=/tmp \
#     vmd -dispdev text -e tests/fixtures/make_old_sessions.tcl < /dev/null
# (MDANCE_PLUGIN: the old plugin's mdance.tcl, which is in this repository's
# history: `git worktree add ../mdance-old bf6fd41` puts it where it is
# looked for otherwise, ../mdance-old/mdance/mdance.tcl.)
# With MDANCE_CLI_OLD, an mdance-cli built from CPP-MDANCE before 4042c24
# (ed2a076, the one the plugin was made with), old_helm_eps.mdance too: HELM
# stopped by -eps, whose merges end with the one -eps refused; and
# old_helm_eps_empty.mdance, of the trajectory read twice (48 frames), whose
# first NANI clustering left one of its 25 starting clusters empty: its one
# row, the merge -eps refused, is also a merge of all 25.
set root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
set dir [file join $root tests fixtures]
set plugin [expr {[info exists ::env(MDANCE_PLUGIN)] ? $::env(MDANCE_PLUGIN) :
    [file normalize [file join $root .. mdance-old mdance mdance.tcl]]}]
rename package _package
proc package {args} {
    if {[lindex $args 0] eq "require" && [lindex $args 1] eq "Tk"} { return 8.6 }
    uplevel 1 [list _package {*}$args]
}
proc tk_messageBox {args} { return ok }
proc update {args} {}
if {[catch {
    source $plugin
    # (its program, not its library)
    proc ::mdance::utils::find_library {} { return "" }
    set ::mdance::use_library 0
    set ::mdance::cli_path $::env(MDANCE_CLI)
    ::mdance::init
    set m [mol new [file join $dir two_state.pdb] waitfor all]
    ::mdance::run_clustering kmeans [list molid $m atomsel all nclusters 2 metric MSD kinit KmeansPP percentage 10 first 4 last 19 stride 2]
    ::mdance::save_session [file join $dir old_kmeans.mdance]
    ::mdance::run_clustering helm [list molid $m atomsel all nclusters 2 metric MSD merge-scheme Inter pre-k 6 pre-kinit KmeansPP pre-percentage 10 first 0 last -1 stride 1]
    ::mdance::save_session [file join $dir old_helm.mdance]
    # (the parameters as its HELM tab sends them: run_helm)
    set fh [open [file join $dir old_helm_labels.txt] w]
    for {set i 0} {$i < 24} {incr i} { puts $fh [expr {$i / 4}] }
    close $fh
    ::mdance::run_clustering helm [list molid $m atomsel all metric MSD merge-scheme Inter first 0 last -1 stride 1 \
        nclusters 2 eps -1 initial-labels tests/fixtures/old_helm_labels.txt]
    ::mdance::save_session [file join $dir old_helm_labels.mdance]
    ::mdance::run_clustering helm [list molid $m atomsel all metric MSD merge-scheme Inter first 0 last -1 stride 1 \
        nclusters 2 eps -1 pre-k 8 pre-kinit KmeansPP pre-percentage 10 trim-k 2 trim-start 1 min-samples 0.01]
    ::mdance::save_session [file join $dir old_helm_trim.mdance]
    # (its sweep's row: run_one_config with the molecule's context added,
    # made the results by Load Selected)
    lassign [::mdance::extract_coordinates $m all 0 -1 1] csv natoms nframes frames
    set r [::mdance::run_one_config [dict create mode cli csv $csv natoms $natoms] {algorithm kmeans nclusters 2 metric MSD kinit KmeansPP}]
    dict set r molid $m
    dict set r atomsel all
    dict set r frames $frames
    set ::mdance::results $r
    ::mdance::save_session [file join $dir old_sweep.mdance]
    puts "written: old_kmeans.mdance, old_helm.mdance, old_helm_labels.mdance, old_helm_trim.mdance, old_sweep.mdance"
    if {[info exists ::env(MDANCE_CLI_OLD)]} {
        set ::mdance::cli_path $::env(MDANCE_CLI_OLD)
        ::mdance::run_clustering helm [list molid $m atomsel all metric MSD merge-scheme Inter first 0 last -1 stride 1 \
            nclusters 0 eps 0.1 pre-k 6 pre-kinit KmeansPP pre-percentage 10]
        ::mdance::save_session [file join $dir old_helm_eps.mdance]
        mol addfile [file join $dir two_state.pdb] waitfor all molid $m
        ::mdance::run_clustering helm [list molid $m atomsel all metric MSD merge-scheme Inter first 0 last -1 stride 1 \
            nclusters 0 eps 0.01 pre-k 25 pre-kinit KmeansPP pre-percentage 10]
        ::mdance::save_session [file join $dir old_helm_eps_empty.mdance]
        puts "written: old_helm_eps.mdance, old_helm_eps_empty.mdance"
    }
} err]} { puts "failed: $err" }
catch {::mdance::utils::cleanup}
quit
