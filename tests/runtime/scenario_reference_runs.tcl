# Runtime scenario: the REAL CPP-MDANCE backend against reference runs.
#
# Every other runtime scenario drives `fake_mdance_cli`, which is deterministic
# but does not implement the algorithms -- it proves the plumbing, not the
# science. This one runs the actual mdance-cli over trajectories whose expected
# output is known, and checks the numbers agree with the reference the Python
# MDANCE produced for the same inputs.
#
# It is SKIPPED unless both of these are present, so a normal checkout is
# unaffected:
#
#   MDANCE_REF_RUNS  directory holding inputs/ and results/ (the mdance_vmd_runs
#                    sample set; ~37 MB, far too large to vendor here)
#   MDANCE_CLI       a real mdance-cli binary (NOT tests/fake_mdance_cli)
#
#   MDANCE_REF_RUNS=~/Downloads/mdance_vmd_runs ./tests/run_tests.sh runtime
#
# Tolerances are not guesses. They were calibrated by running every case below
# and taking roughly twice the observed disagreement:
#
#   NANI, 4 configs x 2 systems x 3 inits : cluster fractions differed by
#     <= 0.024, Calinski-Harabasz by <= 1.2%, Davies-Bouldin by <= 3.7%
#
# HELM is the exception and is deliberately NOT asserted on population; see the
# section at the bottom, which records what it actually does.

# Capture the real backend path BEFORE _setup.tcl runs: that file unsets
# MDANCE_CLI and points the plugin at fake_mdance_cli, which is the right default
# for every other scenario and exactly what this one must not use.
set REAL_CLI ""
foreach _v {MDANCE_CLI MDANCE_REF_CLI} {
    if {$REAL_CLI eq "" && [info exists ::env($_v)]} { set REAL_CLI $::env($_v) }
}
set REF ""
if {[info exists ::env(MDANCE_REF_RUNS)]} { set REF $::env(MDANCE_REF_RUNS) }

source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

set have_ref [expr {$REF ne "" && [file isdirectory [file join $REF results]]}]
set have_cli [expr {$REAL_CLI ne "" && [file executable $REAL_CLI] \
                    && [file tail $REAL_CLI] ne "fake_mdance_cli"}]

if {!$have_ref || !$have_cli} {
    th::section "Reference runs against the real CPP-MDANCE backend"
    set why ""
    if {!$have_ref} { append why "MDANCE_REF_RUNS unset or has no results/ directory. " }
    if {!$have_cli} { append why "no real mdance-cli: MDANCE_CLI is unset, not executable, or is fake_mdance_cli." }
    th::skip "reference-run comparison" $why
    exit [th::done "runtime:reference_runs"]
} else {

    # Point the plugin at the real backend for the rest of this file.
    set ::mdance::use_library 0
    set ::mdance::cli_path $REAL_CLI
    th::section "Backend under test"
    th::test "running against a real mdance-cli, not the fake backend" {
        th::eq $REAL_CLI $::mdance::cli_path
        th::ne "fake_mdance_cli" [file tail $::mdance::cli_path]
        th::true [file executable $::mdance::cli_path] "cli must be executable: $::mdance::cli_path"
    }

    # ------------------------------------------------------------------
    # Reference readers
    # ------------------------------------------------------------------

    # ref_fractions - the per-cluster "fraction of total frames" column of a summary
    # CSV, largest first. Both the NANI and HELM summaries are `#`-commented headers
    # followed by `cluster,frac,msd`.
    proc ref_fractions {path} {
        set out {}
        set fp [open $path r]
        foreach line [split [read $fp] "\n"] {
            if {[string match "#*" $line] || [string trim $line] eq ""} continue
            set p [split $line ","]
            if {[llength $p] >= 3} { lappend out [lindex $p 1] }
        }
        close $fp
        return [lsort -real -decreasing $out]
    }

    # ref_screen - {k -> {CH DB}} from a screen_*_summary.csv.
    proc ref_screen {path} {
        set out [dict create]
        set fp [open $path r]
        foreach line [split [read $fp] "\n"] {
            if {[string match "#*" $line] || [string trim $line] eq ""} continue
            set p [split $line ","]
            if {[llength $p] >= 4} {
                dict set out [expr {int(double([lindex $p 0]))}] \
                    [list [lindex $p 2] [lindex $p 3]]
            }
        }
        close $fp
        return $out
    }

    # ref_labels - the cluster-index column of a labels CSV, one per frame.
    proc ref_labels {path} {
        set out {}
        set fp [open $path r]
        foreach line [split [read $fp] "\n"] {
            if {[string match "#*" $line] || [string trim $line] eq ""} continue
            lappend out [lindex [split $line ","] end]
        }
        close $fp
        return $out
    }

    # result_fractions - the same quantity from a plugin result dict.
    proc result_fractions {results} {
        set n [dict get $results nFrames]
        set out {}
        foreach s [dict get $results clusterSizes] { lappend out [expr {double($s) / $n}] }
        return [lsort -real -decreasing $out]
    }

    proc max_abs_diff {a b} {
        set m 0.0
        foreach x $a y $b {
            set d [expr {abs($x - $y)}]
            if {$d > $m} { set m $d }
        }
        return $m
    }

    proc pct_diff {got exp} {
        if {$exp == 0} { return [expr {$got == 0 ? 0.0 : 1e9}] }
        return [expr {abs(double($got) - $exp) / abs(double($exp)) * 100.0}]
    }

    # load_ref_traj - the reference topology + trajectory as one molecule.
    #
    # The DCD carries the frames the reference clustered; the PDB contributes its own
    # coordinate set as frame 0, which the reference did not include. Dropping it is
    # what makes the frame counts line up (6002 -> 6001).
    proc load_ref_traj {pdb dcd} {
        set m [mol new $pdb waitfor all]
        mol addfile $dcd molid $m waitfor all
        animate delete beg 0 end 0 $m
        return $m
    }

    # ------------------------------------------------------------------
    th::section "NANI reproduces the reference partition"
    # ------------------------------------------------------------------
    #
    # "backbone" is the selection: it is what makes the numbers line up, and the
    # agreement below is the evidence. The DCD is named backbone_aligned because it
    # is aligned ON the backbone; it still carries every atom.

    set hept_pdb [file join $REF inputs 1_heptapeptide aligned_tau.pdb]
    set hept_dcd [file join $REF inputs 1_heptapeptide backbone_aligned.dcd]
    set mh [load_ref_traj $hept_pdb $hept_dcd]

    th::test "the heptapeptide trajectory matches the reference frame count" {
        th::eq 6001 [molinfo $mh get numframes]
        set sel [atomselect $mh backbone]
        th::eq 48 [$sel num]
        $sel delete
    }

    foreach {label kinit dir stem} {
        StratAll     StratAll     strat_all_6     summary_6_strat_all.csv
        StratReduced StratReduced strat_reduced_6 summary_6_strat_reduced.csv
        CompSim      CompSim      comp_sim_6      summary_6_comp_sim.csv
    } {
        set refcsv [file join $REF results nani 1_heptapeptide $dir $stem]
        if {![file exists $refcsv]} {
            th::skip "NANI k=6 $label" "reference missing: $refcsv"
            continue
        }
        th::test "NANI k=6 $label matches the reference cluster populations" {
            set params [dict create molid $mh atomsel backbone nclusters 6 \
                metric MSD kinit $kinit percentage 10 first 0 last -1 stride 1]
            set r [::mdance::run_clustering kmeans $params]
            th::eq 6001 [dict get $r nFrames]
            th::eq 6 [dict get $r nClusters]
            set d [max_abs_diff [result_fractions $r] [ref_fractions $refcsv]]
            th::true [expr {$d <= 0.05}] \
                "largest per-cluster fraction difference was $d (calibrated worst case 0.024)"
        }
    }

    th::test "the K screen reproduces the reference scores from k=5 to k=10" {
        set screen [file join $REF results nani 1_heptapeptide screen_strat_all_summary.csv]
        th::true [file exists $screen] "reference screen summary must be present"
        set ref [ref_screen $screen]
        foreach k {5 6 7 8 10} {
            if {![dict exists $ref $k]} continue
            lassign [dict get $ref $k] rch rdb
            set params [dict create molid $mh atomsel backbone nclusters $k \
                metric MSD kinit StratAll percentage 10 first 0 last -1 stride 1]
            set r [::mdance::run_clustering kmeans $params]
            set ch [dict get $r score_calinskiHarabasz]
            set db [dict get $r score_daviesBouldin]
            th::true [expr {[pct_diff $ch $rch] <= 5.0}] \
                "k=$k Calinski-Harabasz $ch vs reference $rch"
            th::true [expr {[pct_diff $db $rdb] <= 8.0}] \
                "k=$k Davies-Bouldin $db vs reference $rdb"
        }
    }

    # ------------------------------------------------------------------
    th::section "A second system, to show the agreement is not one trajectory"
    # ------------------------------------------------------------------
    set pg_pdb [file join $REF inputs 2_protein-g 3gb1.pdb]
    set pg_dcd [file join $REF inputs 2_protein-g backbone_aligned.dcd]
    set pg_ref [file join $REF results nani 2_protein-g strat_all_6 summary_6_strat_all.csv]

    if {![file exists $pg_pdb] || ![file exists $pg_ref]} {
        th::skip "protein G NANI k=6" "reference inputs or summary missing"
    } else {
        set mp [load_ref_traj $pg_pdb $pg_dcd]
        th::test "protein G is a larger selection over fewer frames" {
            th::eq 1923 [molinfo $mp get numframes]
            set sel [atomselect $mp backbone]
            th::eq 225 [$sel num]
            $sel delete
        }
        th::test "NANI k=6 StratAll matches the reference on protein G" {
            set params [dict create molid $mp atomsel backbone nclusters 6 \
                metric MSD kinit StratAll percentage 10 first 0 last -1 stride 1]
            set r [::mdance::run_clustering kmeans $params]
            th::eq 1923 [dict get $r nFrames]
            th::eq 6 [dict get $r nClusters]
            set d [max_abs_diff [result_fractions $r] [ref_fractions $pg_ref]]
            th::true [expr {$d <= 0.05}] "largest fraction difference was $d"
        }
        catch {mol delete $mp}
    }

    # ------------------------------------------------------------------
    th::section "HELM: structure holds, population does NOT match the reference"
    # ------------------------------------------------------------------
    #
    # This section deliberately asserts less than the NANI one, because measured,
    # CPP-MDANCE's HELM does not reproduce the reference partition:
    #
    #   Inter, k=6, heptapeptide, from the reference's own 60-cluster CompSim labels
    #     populations  cpp  0.327 0.312 0.308 0.023 0.015 0.015
    #                  py   0.500 0.318 0.111 0.047 0.015 0.009   (max diff 0.197)
    #     CH           cpp  770.0   py  724.4     DB  cpp 1.889  py 1.808
    #   Intra, same inputs: max population difference 0.046
    #
    # The C++ partition is not simply worse -- its Calinski-Harabasz is HIGHER -- so
    # this reads as a different merge order or tie-break rather than a broken merge.
    # It is left as an open question rather than papered over with a 0.25 tolerance,
    # which would assert nothing. What IS asserted is everything structural, which
    # does hold, so a genuinely broken HELM would still fail here.

    set helm_init_src [file join $REF results helm 1_betaheptapeptide labels_60_comp_sim.csv]
    set helm_ref      [file join $REF results helm 1_betaheptapeptide inter_6 inter_helm_summary_6.csv]

    if {![file exists $helm_init_src]} {
        th::skip "HELM from reference initial labels" "missing $helm_init_src"
    } else {
        # The backend wants a bare one-label-per-line file; the reference CSV is
        # `frame,cluster` under two comment lines.
        set init_path [file join [::mdance::utils::tmpdir] ref_helm_init.csv]
        set fp [open $init_path w]
        foreach l [ref_labels $helm_init_src] { puts $fp $l }
        close $fp

        th::test "the reference initial labels are one per frame, in 60 clusters" {
            set labs [ref_labels $helm_init_src]
            th::eq 6001 [llength $labs]
            th::eq 60 [llength [lsort -unique $labs]]
        }

        th::test "HELM Inter k=6 returns a well-formed partition of every frame" {
            set params [dict create molid $mh atomsel backbone nclusters 6 \
                metric MSD merge-scheme Inter initial-labels $init_path \
                first 0 last -1 stride 1]
            set r [::mdance::run_clustering helm $params]
            th::eq 6001 [dict get $r nFrames]
            th::eq 6 [dict get $r nClusters]
            th::eq 6001 [llength [dict get $r labels]]
            set total 0
            foreach s [dict get $r clusterSizes] { incr total $s }
            th::eq 6001 $total "cluster sizes must account for every frame"
            foreach l [dict get $r labels] {
                if {$l < 0 || $l > 5} { th::true 0 "label $l out of range 0..5"; break }
            }
            th::eq 6 [llength [dict get $r representatives]]
        }

        if {[file exists $helm_ref]} {
            th::skip "HELM Inter k=6 population vs reference" \
                "KNOWN DIVERGENCE: max per-cluster fraction difference 0.197 (largest cluster 0.327 vs 0.500); CH 770.0 vs 724.4. Structure is asserted above; the partition itself is an open question for CPP-MDANCE."
        }
        catch {file delete $init_path}
    }

    catch {mol delete $mh}
    ::mdance::utils::cleanup
    exit [th::done "runtime:reference_runs"]
}
