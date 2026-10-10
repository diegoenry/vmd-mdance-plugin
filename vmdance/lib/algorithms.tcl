#
# VMDance - the algorithms and their parameters (no Tk dependency)
#
# One table says, for every algorithm, what it is called, which
# parameters it takes, their defaults, limits and meaning. The command's
# options (-kinit, -merge-scheme ...), the window's fields, the checks and
# the backend's arguments are all made from it: a parameter is named as
# mdance-cli names it (--kinit), and as the library does (-kinit). A few
# are the plugin's own (HELM's first clustering: -initial ...) and are not
# passed on.
#
# An algorithm takes every metric unless its metrics say which, and why
# (metric_why, the window's label): DIVINE MSD (MDANCE's DIVINE splits by
# MSD, and CPP-MDANCE's uses another only to choose the representatives),
# eQUAL MSD (its radius by any other index holds every frame).
#
# A parameter is {name type default limits label tip}:
#   int {lo hi}, real {lo hi}   a number within the limits ("" hi: none);
#                               a default of "" means it must be given
#   choice {value ...}          one of the values
#   bool {}                     0 or 1 (a flag of the backend)
#   file {}                     a file to read ("" none)
#

namespace eval ::VMDance::Algo {
    variable metrics {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2}
    variable metric_names {
        MSD "Mean square deviation" BUB "Baroni-Urbani–Buser" Fai "Faith" Gle "Gleason"
        Ja "Jaccard" JT "Jaccard–Tanimoto" RT "Rogers–Tanimoto" RR "Russell–Rao"
        SM "Sokal–Michener" SS1 "Sokal–Sneath 1" SS2 "Sokal–Sneath 2"
    }
    variable kinits {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP}
    variable kinit_names {
        StratAll "Stratified, all frames" StratReduced "Stratified, reduced" CompSim "Complementary similarity"
        DivSelect "Diversity selection" KmeansPP "k-means++" Random "Random" VanillaKmeansPP "k-means++ (vanilla)"
    }
    # the order of the window's chooser
    variable order {kmeans divine helm equal}
    # anchors that crash CPP-MDANCE's DIVINE with -refine (an out-of-bounds
    # read in divine.cpp): refused before the backend runs
    variable divine_crash_anchors {OutlierPair SplinterPair}
    variable A {
        kmeans {
            label "KMeans NANI" k 10
            about "k-means with N-ary natural initiation: k clusters, seeded by extended similarity"
            local {} trim {}
            params {
                {kinit choice StratAll {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP} "Seeding" "How the k initial centres are chosen: NANI's stratified and complementary-similarity schemes, diversity selection, or the usual k-means++ and random"}
                {percentage int 10 {1 100} "Seeds from %" "The share of the frames the seeds are drawn from (the extended-similarity seedings: StratAll, StratReduced, CompSim, DivSelect; k-means++ and random do not use it): k must be at most this share of the frames"}
            }
        }
        divine {
            label "DIVINE" k 3
            about "divisive hierarchical clustering: the trajectory split in two, cluster by cluster, until k clusters"
            local {} trim {} metrics {MSD} metric_why "DIVINE splits by MSD"
            params {
                {split choice WeightedMSD {WeightedMSD MSD Radius} "Split" "Which cluster is split next: the largest mean square deviation weighted by size, the largest one, or the widest"}
                {anchors choice NANI {NANI OutlierPair SplinterPair} "Anchors" "How a cluster is split in two: by a 2-cluster NANI, or from its two most distant frames"}
                {kinit choice StratAll {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP} "Seeding" "NANI's seeding for the splits (Anchors: NANI)"}
                {refine bool 0 {} "Refine with k-means" "MDANCE refines the OutlierPair and SplinterPair splits with k-means; CPP-MDANCE's DIVINE reads out of bounds when it does, so they run unrefined. A NANI split is a k-means already: Refine changes nothing there"}
                {threshold real 0 {0 ""} "Smallest share" "A split is made only when each side keeps at least this share of all the frames (0: no limit; at most 0.5, below it for an odd number of frames). CPP-MDANCE applies it with Anchors OutlierPair and SplinterPair only, and rounds share × frames where MDANCE truncates"}
                {end-mode choice k {k points} "Stop when" "k clusters are reached, or (points: k not used) no cluster can be split leaving the smallest share on each side"}
                {percentage int 10 {1 100} "Seeds from %" "The share of a cluster's frames NANI's seeds are drawn from, at each split (StratAll, StratReduced, CompSim, DivSelect): a cluster of fewer than 200 / this many frames cannot be split"}
            }
        }
        helm {
            label "HELM" k 10
            about "hierarchical agglomerative clustering: the many small clusters of a first NANI clustering merged until k remain"
            local {initial initial-kinit initial-percentage initial-labels}
            trim {min-samples trim-val trim-k}
            params {
                {initial int 50 {2 ""} "Start from" "The number of clusters of the first NANI clustering, which HELM merges down to k"}
                {initial-kinit choice StratAll {StratAll StratReduced CompSim DivSelect KmeansPP Random VanillaKmeansPP} "Their seeding" "The seeding of the first NANI clustering"}
                {initial-percentage int 10 {1 100} "Their seeds from %" "The share of the frames the first NANI clustering's seeds are drawn from: the starting clusters must be at most this share of the frames (extended-similarity seedings)"}
                {initial-labels file "" {} "Or from a file" "Start from the clusters of a label file instead (one label per clustered frame, or frame,label rows; # comments)"}
                {merge-scheme choice Inter {Inter Intra Half} "Merge" "Which two clusters merge next: the most similar pair (Inter), the pair whose union stays most compact (Intra), or a mix (Half)"}
                {eps real -1 {"" ""} "Stop at" "Stop merging when the closest pair is less similar than this, with k 0 (-1: merge until k; one of the two stops HELM, not both)"}
                {trim-start bool 0 {} "Trim first" "Leave out the loosest starting clusters before merging"}
                {trim-k int 0 {0 ""} "Leave out" "Trim: the number of loosest starting clusters (largest MSD) left out"}
                {trim-val real 0 {0 ""} "Or above MSD" "Trim: leave out the starting clusters whose MSD is above this"}
                {min-samples real 0.01 {0 ""} "And smaller than" "Trim: also leave out starting clusters smaller than this (below 1: a share of the frames)"}
            }
        }
        equal {
            label "eQUAL" k 0
            about "extended quality clustering: clusters grown within a radius, their number following from it; frames outside every one are noise"
            local {} trim {} metrics {MSD} metric_why "eQUAL's radius is an MSD"
            params {
                {threshold real "" {0 ""} "Radius" "MDANCE's MSD (Å²) within which a frame joins a cluster's seed — for two frames half their RMSD²: a frame joins when its RMSD² to the seed is at most twice the radius; the number of clusters follows from it (try 1)"}
                {seed-method choice medoid {medoid comp_sim} "Seeds" "Where each cluster starts: the medoid of what is left, or the frames of highest complementary similarity"}
                {n-seeds real 1 {0 ""} "Seeds tried" "How many seeds are tried for each cluster (below 1: a share of the frames)"}
                {percentage int 10 {1 100} "Seeds from %" "The share of the densest frames the seeds come from (comp_sim)"}
                {reject-lowd bool 0 {} "Reject small clusters" "Leave clusters smaller than Min. size as noise"}
                {min-samples real 10 {0 ""} "Min. size" "The smallest cluster kept (Reject small clusters; below 1: a share of the frames)"}
                {check-sim bool 0 {} "Check similarity" "Stop at the first cluster whose MSD is above the value below: it and every frame left become noise"}
                {sim-threshold real 0 {"" ""} "Largest MSD" "The largest MSD (Å², MDANCE's) a cluster may have (Check similarity): a ceiling; 0 makes every frame noise"}
            }
        }
    }
    # the questions asked after a clustering (the window's defaults)
    variable prime_params {
        {metric choice RR {RR SM} "Similarity" "The n-ary similarity index PRIME scores frames with: Russell–Rao or Sokal–Michener"}
        {trim-frac real 0.1 {0 0.99} "Trim" "The share of the largest cluster's (c0's) least representative frames left out before its frames are scored; the other clusters are used whole"}
        {weighted bool 1 {} "Weight by size" "Weight each cluster's score by its number of frames"}
    }
    variable similarity_params {
        {metric choice MSD {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2} "Metric" "The extended similarity index (MSD: the mean square deviation)"}
    }
    variable pick_names {diversity "Most diverse" outliers "Outliers" repsample "Representative sample" medoid "The medoid" outlier "The outlier"}
    variable pick_params {
        {method choice diversity {diversity outliers repsample medoid outlier} "Method" "Most diverse: a subset spread over the conformations; outliers: the least similar frames; representative sample: frames drawn evenly over the similarity; the medoid or the outlier: one frame"}
        {param real 10 {0 ""} "How many" "Most diverse: a whole percentage of the frames (1–100); outliers: a number of frames, or a share (below 1) that holds one at least; representative sample: a number of frames, or a share (below 1; one frame at least)"}
        {nbins int 10 {2 100} "Bins" "Representative sample: the number of similarity bins"}
        {metric choice MSD {MSD BUB Fai Gle Ja JT RT RR SM SS1 SS2} "Metric" "The extended similarity index"}
    }
}

proc ::VMDance::Algo::all {} { variable order; return $order }
proc ::VMDance::Algo::exists {a} { variable A; dict exists $A $a }
proc ::VMDance::Algo::get {a key} { variable A; dict get $A $a $key }
proc ::VMDance::Algo::label {a} {
    variable A
    if {[dict exists $A $a]} { return [dict get $A $a label] }
    return $a
}
# the default k (0: the algorithm finds its number of clusters)
proc ::VMDance::Algo::takes_k {a} { variable A; expr {[dict get $A $a k] > 0} }
proc ::VMDance::Algo::default_k {a} { variable A; dict get $A $a k }
proc ::VMDance::Algo::params {a} { variable A; dict get $A $a params }
proc ::VMDance::Algo::param_names {a} { lmap p [params $a] {lindex $p 0} }
proc ::VMDance::Algo::param {a name} {
    foreach p [params $a] { if {[lindex $p 0] eq $name} { return $p } }
    return ""
}
# The algorithms that are given k (scans).
proc ::VMDance::Algo::with_k {} { lmap a [all] {expr {[takes_k $a] ? $a : [continue]}} }
# The parameter a sweep's seedings set (-seedings), "" when the
# parameters p use none: HELM started from a label file makes no first
# clustering, DIVINE split by a pair of anchors no NANI.
proc ::VMDance::Algo::seeding_of {a {p {}}} {
    if {[catch {dict size $p}]} { set p {} }
    switch -- $a {
        helm {
            if {[dict exists $p initial-labels] && [dict get $p initial-labels] ne ""} { return "" }
            return initial-kinit
        }
        divine {
            if {[dict exists $p anchors] && [dict get $p anchors] ne "NANI"} { return "" }
            return kinit
        }
    }
    return kinit
}
# The metrics an algorithm takes, and why only those ("" for every one).
proc ::VMDance::Algo::metrics_of {a} {
    variable A; variable metrics
    if {[dict exists $A $a metrics]} { return [dict get $A $a metrics] }
    return $metrics
}
proc ::VMDance::Algo::metric_why {a} {
    variable A
    if {[dict exists $A $a metric_why]} { return [dict get $A $a metric_why] }
    return ""
}

# Every parameter at its default: {name value ...}.
proc ::VMDance::Algo::defaults {a} {
    set out {}
    foreach p [params $a] { dict set out [lindex $p 0] [lindex $p 2] }
    return $out
}

# A value checked against a parameter spec; returns it (booleans as 0/1,
# numbers as written); an error names the option.
proc ::VMDance::Algo::check_value {spec v {stored 0}} {
    lassign $spec name type def lim label
    set o "-$name"
    set v [string trim $v]
    # (expr would compare a mistyped number as a string, read 010 as
    # octal where the backend reads 10, and NaN is no number)
    switch -- $type {
        int {
            if {$v eq "" && $def eq ""} { error "$o is needed ($label)" }
            if {![regexp {^[-+]?(0|[1-9][0-9]*)$} $v]} { error "$o must be a whole number (got \"$v\")" }
            set v [string trimleft $v +]
        }
        real {
            if {$v eq "" && $def eq ""} { error "$o is needed ($label)" }
            if {![regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $v -> mant] || [regexp {^[-+]?0[0-9]} $v]} {
                error "$o must be a number (got \"$v\")"
            }
            if {[catch {expr {abs(double($v)) < 1e300}} ok] || !$ok} { error "$o is out of range (got \"$v\")" }
            # (mdance-cli reads HELM's numbers as C floats, the others as
            # doubles, and fails on one beyond their range with a bare "stof"
            # or "stod", where the library rounds it: a new number is 0, or
            # 1.2e-38 to 3.4e38 in size. VMD takes a number nearer 0 than
            # 2.2e-308 for 0: a zero is told by its digits. A stored request
            # ran already, and is kept as it was.)
            if {!$stored && [regexp {[1-9]} $mant] && (abs(double($v)) < 1.2e-38 || abs(double($v)) > 3.4e38)} {
                error "$o must be 0, or between 1.2e-38 and 3.4e38 in size (got $v)"
            }
            set v [string trimleft $v +]
        }
        choice {
            if {$v ni $lim} { error "$o must be one of [join $lim {, }] (got \"$v\")" }
            return $v
        }
        bool {
            if {![string is boolean -strict $v]} { error "$o must be 0 or 1 (got \"$v\")" }
            return [expr {$v ? 1 : 0}]
        }
        file {
            # (a request read from a session names a file of another time)
            if {!$stored && $v ne "" && (![file isfile $v] || ![file readable $v])} { error "$o: cannot read \"$v\"" }
            return $v
        }
    }
    lassign $lim lo hi
    if {$lo ne "" && $v < $lo} { error "$o must be at least $lo (got $v)" }
    if {$hi ne "" && $v > $hi} { error "$o must be at most $hi (got $v)" }
    return $v
}

# The parameters of algorithm a from {name value ...} (unknown names and
# bad values refused), completed with the defaults.
proc ::VMDance::Algo::check_params {a given {stored 0}} {
    set out [defaults $a]
    if {[catch {dict size $given}]} { error "the parameters must be name value pairs" }
    dict for {k v} $given {
        if {[param $a $k] eq ""} {
            error "-$k is not a parameter of [label $a] (its parameters: [join [lmap n [param_names $a] {string cat - $n}] {, }])"
        }
        dict set out $k $v
    }
    # every value checked, the defaults too (a required one has none)
    dict for {k v} $out { dict set out $k [check_value [param $a $k] $v $stored] }
    return $out
}

proc ::VMDance::Algo::check_metric {m} {
    variable metrics
    if {$m ni $metrics} { error "-metric must be one of [join $metrics {, }] (got \"$m\")" }
    return $m
}

# The checks across parameters (and k), for n frames and the metric; an
# error says why.
proc ::VMDance::Algo::check_combination {a k params n {nstart ""} {metric MSD}} {
    variable divine_crash_anchors
    # CPP-MDANCE's diversity selection (the seedings CompSim and DivSelect,
    # eQUAL's comp_sim seeds) takes the frame of the largest 1 − index above
    # -1: with an index other than MSD, on coordinates, none is, and it reads
    # past its data (mdance-cli crashes, or every frame lands in one cluster
    # that looks a success). MDANCE's Python stops there too.
    set diverse {apply {{metric opt v alt} {
        if {$metric ne "MSD" && $v in {CompSim DivSelect comp_sim}} {
            error "-metric $metric with $opt $v: CPP-MDANCE's diversity selection reads past its data with an index other than MSD; use -metric MSD, or $alt"
        }
    }}}
    # NANI's seedings by extended similarity draw the k seeds from the
    # densest percentage of the frames: at most n × p / 100 of them
    set seeds {apply {{what k kinit p n kopt popt} {
        if {$kinit ni {StratAll StratReduced CompSim DivSelect}} return
        # (the diversity selection's one seed is taken however few frames)
        if {$kinit eq "DivSelect" && $k == 1} return
        set most [expr {$n * $p / 100}]
        if {$k > $most} {
            set need [expr {int(ceil(100.0 * $k / $n))}]
            error "$kopt $k: $what seeds its $k clusters from the densest $p% of the $n frames ($most of them): raise $popt to [expr {min(100, $need)}][expr {$need > 100 ? " (not enough frames for $k clusters with this seeding)" : ""}], use fewer clusters, or seed with KmeansPP or Random"
        }
    }}}
    switch -- $a {
        kmeans {
            {*}$diverse $metric -kinit [dict get $params kinit] "seed with StratAll, StratReduced, KmeansPP or Random"
            {*}$seeds "NANI (-kinit [dict get $params kinit])" $k [dict get $params kinit] [dict get $params percentage] $n -k -percentage
        }
        divine {
            set an [dict get $params anchors]
            set kinit [dict get $params kinit]
            set p [dict get $params percentage]
            set t [dict get $params threshold]
            set points [expr {[dict get $params end-mode] eq "points"}]
            # (MDANCE's DIVINE has no metric: CPP-MDANCE's splits by MSD, and
            # gives another only to the representatives' choice)
            if {$metric ni [metrics_of divine]} {
                error "-metric $metric: DIVINE splits by MSD whatever the metric (MDANCE's DIVINE has none), and CPP-MDANCE would use it only to choose the representatives; use -metric MSD"
            }
            if {[dict get $params refine] && $an in $divine_crash_anchors} {
                error "-anchors $an with -refine 1 crashes CPP-MDANCE's DIVINE (an out-of-bounds read); use -anchors NANI, or -refine 0"
            }
            # -threshold: the smallest share of the frames each side of a
            # split keeps (CPP-MDANCE: round(t × n) frames, at least 1;
            # MDANCE truncates), tested by the pair anchors' splits only
            if {$t > 0 && $an eq "NANI"} {
                error "-threshold $t with -anchors NANI: CPP-MDANCE's DIVINE does not apply it to NANI's splits (MDANCE does); use -anchors OutlierPair or SplinterPair (with -refine 0), or -threshold 0"
            }
            set least [expr {max(1, round($t * $n))}]
            if {($k > 1 || $points) && 2 * $least > $n} {
                # (the largest share whose frames, rounded, are half or
                # fewer: 0.5 of an odd number rounds up, past half; cut, not
                # rounded, to 3 digits)
                error "-threshold $t: each side of a split must keep $least of the $n frames, so no split can be made (one cluster); use at most [expr {$n / 2 * 1000 / $n / 1000.0}] (0: no limit)"
            }
            if {$points} {
                # (k is not used: the splits go on until none is left)
                if {$an eq "NANI"} {
                    error "-end-mode points with -anchors NANI: CPP-MDANCE's NANI splits go on until every frame is alone (-threshold does not stop them; StratAll, StratReduced, CompSim and DivSelect fail first, on clusters too small to seed); use -anchors OutlierPair or SplinterPair (with -refine 0) and -threshold, or -end-mode k"
                }
                if {$least < 2} {
                    # (a share that works here and leaves clusters of some
                    # size: 2 frames each still make up to n / 2, and the
                    # backend's points splits slow as the square of their number)
                    set eg [format %.3g [expr {max(0.05, 2.0 / $n)}]]
                    set m [expr {max(1, round($eg * $n))}]
                    error "-end-mode points with -threshold $t: a split may leave a single frame on a side, so the splits go on to single frames (up to $n clusters); [expr {2 * $m > $n ? "use -end-mode k (no split of $n frames leaves 2 on each side)" : "give -threshold, the smallest share of the frames each side keeps (e.g. $eg: $m frames or more each, [expr {$n / $m}] clusters at most), or use -end-mode k"}]"
                }
            }
            # (each NANI split is a 2-cluster NANI of the cluster's m frames,
            # seeded from floor(m × p / 100) of them: 2 at least; the first
            # is of all n, the later ones the backend refuses, Job::_cluster)
            if {$an eq "NANI" && $kinit in {StratAll StratReduced CompSim DivSelect} && $k > 1 && $n * $p / 100 < 2} {
                set need [expr {int(ceil(200.0 / $n))}]
                error "-percentage $p: DIVINE's first split is a 2-cluster NANI (-kinit $kinit) seeded from the densest $p% of the $n frames ([expr {$n * $p / 100}] of them), and it needs 2; raise -percentage to [expr {min(100, $need)}], or seed with KmeansPP or Random"
            }
        }
        helm {
            set eps [dict get $params eps]
            # (as the backend reads it, a C float: -0.99999999 is its -1)
            binary scan [binary format f $eps] f e32
            if {$k == 0 && $e32 == -1} {
                # (a value given that is -1 only as a float is said to be)
                if {$eps != -1} { error "-k 0 needs -eps: -eps $eps is -1 as CPP-MDANCE reads it (a C float), which is none; HELM stops at k clusters, or when the closest pair is farther than -eps" }
                error "-k 0 needs -eps: HELM stops at k clusters, or when the closest pair is farther than -eps"
            }
            # (CPP-MDANCE takes one of the two)
            if {$k > 0 && $e32 != -1} { error "-k $k and -eps $eps: HELM stops at k clusters (-eps -1) or at -eps (-k 0), not both" }
            if {$nstart ne "" && $nstart <= $k} {
                error "-initial-labels: the file has $nstart starting clusters; HELM merges more than -k ($k)"
            }
            if {[dict get $params initial-labels] eq ""} {
                set i [dict get $params initial]
                if {$i > $n} { error "-initial must be at most the number of frames ($n) (got $i)" }
                if {$i <= $k} { error "-initial ($i) must be more than -k ($k): HELM merges the first clustering's clusters down to k" }
                {*}$diverse $metric -initial-kinit [dict get $params initial-kinit] \
                    "seed the first clustering with StratAll, StratReduced, KmeansPP or Random, or start from -initial-labels"
                {*}$seeds "HELM's first clustering (-initial-kinit [dict get $params initial-kinit])" $i \
                    [dict get $params initial-kinit] [dict get $params initial-percentage] $n -initial -initial-percentage
            }
            if {[dict get $params trim-start]} {
                set tk [dict get $params trim-k]; set tv [dict get $params trim-val]
                if {$tk > 0 && $tv > 0} { error "-trim-k and -trim-val: trim by one of them (the other 0)" }
                if {$tk == 0 && $tv == 0} { error "-trim-start 1 needs -trim-k (a number of clusters) or -trim-val (an MSD above 0)" }
                # (a number of frames, made a C int by the backend: 3e9 overflows)
                set ms [dict get $params min-samples]
                if {$ms >= 1 && $ms > $n} { error "-min-samples $ms: at most the $n frames (or a share of them, below 1)" }
                # (what is left must be more than k, or HELM merges nothing)
                set ns [expr {[dict get $params initial-labels] eq "" ? [dict get $params initial] : $nstart}]
                if {$tk > 0 && $ns ne "" && $ns - $tk <= max($k, 1)} {
                    error "-trim-k $tk of $ns starting clusters leaves [expr {$ns - $tk}], not more than -k ($k): HELM would have nothing to merge (use -trim-k below [expr {$ns - max($k, 1)}], or more starting clusters)"
                }
            }
        }
        equal {
            # (its radius by an index other than MSD: on coordinates 1 − the
            # index falls below 0, every frame is within any radius of the
            # seed, and all land in one cluster, whatever the seeds; with
            # comp_sim, the diversity selection reads past its data too)
            if {$metric ni [metrics_of equal]} {
                error "-metric $metric with eQUAL: on coordinates, an index other than MSD puts every frame within any radius of the seed (1 − the index falls below 0), and every frame lands in one cluster; use -metric MSD"
            }
            # (the backend reads -min-samples only to reject small clusters)
            set qs n-seeds
            if {[dict get $params reject-lowd]} { lappend qs min-samples }
            foreach q $qs {
                set v [dict get $params $q]
                if {$v >= 1 && $v > $n} { error "-$q $v: at most the $n frames (or a share of them, below 1)" }
            }
            # (a ceiling on the clusters' MSD: 0 leaves no cluster)
            if {[dict get $params check-sim] && [dict get $params sim-threshold] <= 0} {
                error "-check-sim 1 needs -sim-threshold above 0: it is the largest MSD a cluster may have, and 0 makes every frame noise"
            }
        }
    }
}

# HELM's starting clusters as the backend gets them, sizes their frames (a
# label file's, or what the first NANI clustering left: its empty clusters
# are dropped), of n frames, for k: more than k, or HELM merges them all
# into one cluster (k of them: none). With -trim-start CPP-MDANCE first
# leaves out those smaller than -min-samples (and fails "trimK is too
# large!" when -trim-k takes all but one of the rest), then trims: what is
# left must be more than k too (with -eps, k 0: two or more). (-trim-val's
# cut, an MSD, is the backend's: check_trimmed counts what it left.) An
# error says why.
proc ::VMDance::Algo::check_starting {k params sizes n} {
    set m [llength $sizes]
    set file [expr {[dict get $params initial-labels] ne ""}]
    set i [dict get $params initial]
    if {$k > 0 && $m <= $k} {
        if {$file} { error "-initial-labels: the file has $m starting clusters; HELM merges more than -k ($k)" }
        set other [expr {[dict get $params initial-kinit] ne "KmeansPP" ? ", or another seeding: -initial-kinit KmeansPP" : ""}]
        error "-initial $i: the first clustering left $m starting clusters with frames, of the $i asked; HELM merges more than -k ($k): use [expr {$m > 1 ? "-k below $m, or " : ""}]more starting clusters (a larger -initial$other)"
    }
    if {![dict get $params trim-start]} return
    # (as the backend counts it: a C float; below 1 a share of the frames,
    # rounded down)
    set ms [dict get $params min-samples]
    binary scan [binary format f $ms] f f32
    if {$f32 > 0 && $f32 < 1} {
        binary scan [binary format f $n] f n32
        binary scan [binary format f [expr {$f32 * $n32}]] f f32
    }
    set least [expr {int($f32)}]
    set kept [llength [lmap s $sizes {expr {$s >= $least ? $s : [continue]}}]]
    if {$kept < $m} {
        set from "-min-samples $ms: HELM trims from the starting clusters of $least frames or more, $kept of the $m"
        set more "a smaller -min-samples, or more starting clusters"
    } elseif {$file || $m == $i} {
        set from "HELM trims from $m starting clusters"
        set more "more starting clusters"
    } else {
        set from "HELM trims from the $m starting clusters the first clustering left, of the $i asked (-initial)"
        set more "more starting clusters"
    }
    if {$k > 0} { set none ", not more than -k ($k): HELM would have nothing to merge" } else { set none ": HELM merges two or more" }
    set tk [dict get $params trim-k]
    if {$tk > 0 && $kept - $tk <= max($k, 1)} {
        set below [expr {$kept - max($k, 1)}]
        if {$below > 1} { set more "-trim-k below $below, $more" }
        error "-trim-k $tk: $from; $tk fewer leaves [expr {max(0, $kept - $tk)}]$none (use $more)"
    }
    if {[dict get $params trim-val] > 0 && $kept < $m && $kept <= max($k, 1)} {
        error "$from$none (use $more)"
    }
}
# What HELM's -trim-val left, for k (initial: the starting labels; labels:
# HELM's, -1 the frames of the starting clusters it trimmed): its cut is an
# MSD the backend computes, so what it kept is counted once HELM has run,
# and must be more than k as check_starting has it (HELM merged them all
# into one cluster, or had none). An error says why.
proc ::VMDance::Algo::check_trimmed {k params initial labels} {
    if {![dict get $params trim-start] || [dict get $params trim-val] <= 0} return
    set kept [llength [lsort -integer -unique [lmap s $initial l $labels {expr {$l >= 0 ? $s : [continue]}}]]]
    if {$kept > max($k, 1)} return
    if {$k > 0} { set none ", not more than -k ($k): HELM had nothing to merge" } else { set none ": HELM merges two or more" }
    error "-trim-val [dict get $params trim-val]: the trim kept $kept of HELM's [llength [lsort -integer -unique $initial]] starting clusters$none (use a larger -trim-val)"
}
# A scan clusters at several k: DIVINE's -end-mode points does not use k,
# and would give the same clustering at every one.
proc ::VMDance::Algo::check_scan {a params} {
    if {$a eq "divine" && [dict get $params end-mode] eq "points"} {
        error "-end-mode points: DIVINE does not use k then (it splits until no split leaves the smallest share on each side), so every k gives the same clustering; scan with -end-mode k"
    }
}

# mdance-cli's arguments for a clustering.
proc ::VMDance::Algo::cli_args {a k metric params natoms input output {initial ""}} {
    set argv [list --algorithm $a --input $input --output $output --natoms $natoms --metric $metric]
    if {$a ne "equal"} { lappend argv --nclusters $k }
    if {$a eq "helm"} { lappend argv --initial-labels $initial }
    foreach {name v} [_passed $a $params] {
        if {[lindex [param $a $name] 1] eq "bool"} {
            if {$v} { lappend argv --$name }
        } else {
            lappend argv --$name $v
        }
    }
    return $argv
}

# The library's options for the same clustering.
proc ::VMDance::Algo::lib_args {a params metric} {
    set out [list -metric $metric]
    foreach {name v} [_passed $a $params] {
        if {[lindex [param $a $name] 1] eq "bool"} {
            if {$v} { lappend out -$name }
        } else {
            lappend out -$name $v
        }
    }
    return $out
}

# The parameters the backend is given: not the plugin's own, and HELM's
# trim values only when it trims (the backend's defaults otherwise).
proc ::VMDance::Algo::_passed {a params} {
    variable A
    set local [dict get $A $a local]
    set trim [dict get $A $a trim]
    set out {}
    foreach p [params $a] {
        set name [lindex $p 0]
        if {$name in $local} continue
        if {$name in $trim && ![dict get $params trim-start]} continue
        # (only the trim that was chosen: -trim-k or -trim-val)
        if {$name in {trim-k trim-val} && [dict get $params $name] == 0} continue
        dict set out $name [dict get $params $name]
    }
    return $out
}

# HELM's starting clusters from a label file: its labels numbered 0, 1 …
# in their order (the backend numbers its merges' leaves so), none
# negative.
proc ::VMDance::Algo::starting_labels {file frames} {
    set l [read_labels $file $frames]
    foreach v $l { if {$v < 0} { error "HELM starts from clusters; \"[file tail $file]\" has a label $v" } }
    set i 0
    foreach v [lsort -integer -unique $l] { dict set num $v $i; incr i }
    lmap v $l {dict get $num $v}
}
# The frames of each starting cluster, numbered 0, 1 … without gaps
# (starting_labels, Job::_initial).
proc ::VMDance::Algo::starting_sizes {labels} {
    if {![llength $labels]} { return {} }
    set sizes [lrepeat [expr {[::tcl::mathfunc::max {*}$labels] + 1}] 0]
    foreach v $labels { lset sizes $v [expr {[lindex $sizes $v] + 1}] }
    return $sizes
}

# A label file: one label per clustered frame, or frame,label rows (the
# frames: rows 0..n-1 of the clustering, as MDANCE writes them, or the
# clustered VMD frames); # comments, a header row. Returns n labels.
proc ::VMDance::Algo::read_labels {file frames} {
    set n [llength $frames]
    # (a name is a file's: "|cmd" would be read by open as a pipe)
    set file [file normalize $file]
    if {![file isfile $file]} { error "\"[file tail $file]\" is not a file" }
    if {[file size $file] > 100000000} { error "\"[file tail $file]\" is larger than 100 MB: not a label file" }
    set fh [open $file r]
    try { set text [read $fh 100000000] } finally { close $fh }
    set rows {}
    set ln 0
    set width ""
    # (the plugin's own export says "# frames: …": its frames are VMD's)
    set vmd 0
    foreach line [split $text \n] {
        incr ln
        set line [string trim $line]
        if {[regexp {^#\s*frames:} $line]} { set vmd 1 }
        if {$line eq "" || [string index $line 0] eq "#"} continue
        set f [lmap x [split $line ,] {string trim $x}]
        if {$width eq ""} {
            # a header row: its last field is no number
            if {![regexp {^-?[0-9]+$} [lindex $f end]]} { set width [llength $f]; continue }
            set width [llength $f]
        }
        if {[llength $f] != $width} { error "line $ln of \"[file tail $file]\" has [llength $f] fields, not $width" }
        if {$width > 2} { error "\"[file tail $file]\" has $width comma-separated fields; a label file has one (a label per frame) or two (frame,label)" }
        foreach x $f { if {![regexp {^-?[0-9]{1,9}$} $x]} { error "line $ln of \"[file tail $file]\": \"$x\" is not a whole number" } }
        lappend rows $f
    }
    if {![llength $rows]} { error "\"[file tail $file]\" holds no labels" }
    if {$width == 1} {
        if {[llength $rows] != $n} { error "\"[file tail $file]\" has [llength $rows] labels for the $n frames clustered (check -first, -last and -step)" }
        return [lmap r $rows {scan [lindex $r 0] %d}]
    }
    # (scan: "08" is 8, which expr would read as a bad octal)
    set keys [lmap r $rows {scan [lindex $r 0] %d}]
    if {[llength [lsort -unique $keys]] != [llength $keys]} { error "\"[file tail $file]\" lists a frame twice" }
    set sorted [lsort -integer $keys]
    set rowsn {}
    for {set i 0} {$i < $n} {incr i} { lappend rowsn $i }
    if {$sorted eq $rowsn && !$vmd} {
        set map {}
        foreach r $rows { dict set map [scan [lindex $r 0] %d] [scan [lindex $r 1] %d] }
        return [lmap i $rowsn {dict get $map $i}]
    }
    if {$sorted eq [lsort -integer $frames]} {
        set map {}
        foreach r $rows { dict set map [scan [lindex $r 0] %d] [scan [lindex $r 1] %d] }
        return [lmap f $frames {dict get $map $f}]
    }
    if {$vmd} { error "\"[file tail $file]\" labels VMD frames [lindex $sorted 0] to [lindex $sorted end] ([llength $keys]), not the $n frames clustered ([lindex $frames 0] to [lindex $frames end]): check -first, -last and -step" }
    error "the frames of \"[file tail $file]\" ([llength $keys], [lindex $sorted 0] to [lindex $sorted end]) are neither rows 0 to [expr {$n - 1}] nor the $n frames clustered"
}
