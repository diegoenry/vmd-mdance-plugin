#
# VMDance - what the plugin measures itself (no Tk dependency)
#
# From the coordinates the backend clustered (Coords rows) and its
# labels, once per clustering, so that the result carries them (and a
# session reopened without its molecule still shows them):
#   frame_msd     every frame's mean square deviation from its cluster's
#                 representative (Å², per atom: RMSD²; "" for noise)
#   rep_msd       the same between every two representatives (k × k;
#                 none, {}, above maxk clusters)
#   centroid_msd  the same between every two clusters' mean structures
#   silhouette    every frame's silhouette from the clusters' mean
#                 structures: (b − a) / max(a, b), a the RMSD from its own
#                 cluster's mean, b from the nearest other one ("" for
#                 noise, or with fewer than two clusters; 0 for a frame
#                 alone in its cluster). Not scikit-learn's, which averages
#                 the distances to every frame: it reads higher.
# The distances are VMD's vector commands (C) on the rows, read from the
# coordinates' file in two passes. Frames are compared as they were
# clustered: not fitted again.
#
# And from the labels alone (Results asks): the runs of consecutive frames
# in one cluster, and the transitions between clusters.
#

namespace eval ::VMDance::Measure {
    # the distances between the clusters (k × k) and the tree of their mean
    # structures are made for maxk clusters or fewer: 2k² numbers, about
    # 235 bytes each in Tcl (7.5 GB, and minutes, for the 4000 clusters
    # eQUAL makes at a small radius), and no plot draws more (a cell or a
    # leaf a cluster)
    variable maxk 300
    # with more live clusters than near_min, a frame's nearest other mean
    # structure (its silhouette's b) is looked for among those the triangle
    # inequality leaves (_near_other): the same number, without k distances
    # a frame (eQUAL's 1462 clusters of 4000 frames took 34 s)
    variable near_min 64
}

# Mean square deviation per atom between two rows.
# (veclength and vecsub are VMD's C; vecdist is a Tcl procedure around them)
proc ::VMDance::Measure::msd {a b natoms} {
    set d [veclength [vecsub $a $b]]
    expr {$d * $d / $natoms}
}

# The measures of a clustering: c the coordinates (Coords: read twice,
# row by row), labels, k, representatives (rows, -1 for an empty
# cluster), natoms; progress {fraction message} (of the measures, every
# 250 ms at most). The memory taken is that of 2k rows, and of the two
# k × k matrices (none above maxk). In a coroutine it yields every 40 ms,
# and stops when `cancelled` names a true variable.
proc ::VMDance::Measure::compute {c labels k reps natoms {cancelled ""} {progress ""}} {
    variable maxk
    # first pass: the clusters' sums, and the representatives' rows
    set sums [lrepeat $k ""]
    set cnt [lrepeat $k 0]
    set repof [dict create]
    for {set cl 0} {$cl < $k} {incr cl} { if {[lindex $reps $cl] >= 0} { dict set repof [lindex $reps $cl] $cl } }
    ::VMDance::Coords::each $c i r {
        set l [lindex $labels $i]
        if {[dict exists $repof $i]} { set reprow([dict get $repof $i]) $r }
        if {$l >= 0} {
            set s [lindex $sums $l]
            # (lists are never returned through expr: it could read one as a number)
            if {$s eq ""} { lset sums $l $r } else { lset sums $l [vecadd $s $r] }
            lset cnt $l [expr {[lindex $cnt $l] + 1}]
        }
    } $cancelled
    set cent {}
    foreach s $sums n $cnt { lappend cent [if {$n} { vecscale [expr {1.0 / $n}] $s } else { list }] }
    set live [lmap n $cnt {expr {$n > 0}}]
    set nlive [::tcl::mathop::+ 0 {*}$live]
    set sq [expr {sqrt($natoms)}]
    variable near_min
    set near ""
    if {$nlive > $near_min} { set near [_near_index $cent $live $cancelled] }
    # second pass: every frame from its representative, and its silhouette
    # (k distances a frame, fewer with many clusters: what takes long, said)
    set frame_msd {}; set sil {}
    set nf [llength $labels]
    set mats [expr {$k <= $maxk}]
    set told [clock milliseconds]
    ::VMDance::Coords::each $c i r {
        if {$progress ne "" && [clock milliseconds] - $told >= 250} {
            set told [clock milliseconds]
            {*}$progress [expr {($mats ? 0.9 : 1.0) * $i / $nf}] "measuring the clusters (frame $i of $nf)"
        }
        set l [lindex $labels $i]
        if {$l < 0} {
            lappend frame_msd ""; lappend sil ""
        } else {
            lappend frame_msd [expr {[info exists reprow($l)] ? [msd $r $reprow($l) $natoms] : ""}]
            if {$nlive < 2} {
                lappend sil ""
            } elseif {[lindex $cnt $l] == 1} {
                # (a frame alone in its cluster: 0, as Rousseeuw has it)
                lappend sil 0.0
            } elseif {$near ne ""} {
                set a [expr {[veclength [vecsub $r [lindex $cent $l]]] / $sq}]
                set b [expr {[_near_other $near $r $l] / $sq}]
                set mx [expr {max($a, $b)}]
                lappend sil [expr {$mx > 0 ? ($b - $a) / $mx : 0.0}]
            } else {
                set a ""; set b ""
                for {set cl 0} {$cl < $k} {incr cl} {
                    if {![lindex $live $cl]} continue
                    set d [expr {[veclength [vecsub $r [lindex $cent $cl]]] / $sq}]
                    if {$cl == $l} { set a $d } elseif {$b eq "" || $d < $b} { set b $d }
                }
                set mx [expr {max($a, $b)}]
                lappend sil [expr {$mx > 0 ? ($b - $a) / $mx : 0.0}]
            }
        }
    } $cancelled
    # between the representatives, and between the mean structures (maxk
    # clusters at most): each pair once, the MSD being the same both ways
    # bit for bit (the pairs before p are the rows made: the same values),
    # rounded as it is made
    set rep_msd {}; set cen_msd {}
    set slice [clock milliseconds]
    set pairs 0
    for {set p 0} {$mats && $p < $k} {incr p} {
        set ra [lmap row $rep_msd {lindex $row $p}]
        set ca [lmap row $cen_msd {lindex $row $p}]
        set cp [lindex $cent $p]
        for {set q $p} {$q < $k} {incr q} {
            lappend ra [if {[info exists reprow($p)] && [info exists reprow($q)]} { format %.6g [msd $reprow($p) $reprow($q) $natoms] } else { list }]
            set cq [lindex $cent $q]
            lappend ca [if {$cp ne "" && $cq ne ""} { format %.6g [msd $cp $cq $natoms] } else { list }]
            if {[incr pairs] % 16 == 0} { ::VMDance::Coords::_breathe slice $cancelled }
        }
        lappend rep_msd $ra
        lappend cen_msd $ca
        if {$progress ne "" && [clock milliseconds] - $told >= 250} {
            set told [clock milliseconds]
            {*}$progress [expr {0.9 + 0.1 * ($p + 1) * (2 * $k - $p) / ($k * ($k + 1.0))}] \
                "measuring the distances between the clusters ([expr {$p + 1}] of $k)"
        }
    }
    dict create frame_msd [_round $frame_msd] silhouette [_round $sil] rep_msd $rep_msd centroid_msd $cen_msd
}

# The live clusters' mean structures (cent, live: 1 for a cluster with
# frames) arranged for _near_other: in groups, each around one of them
# chosen farthest from those chosen before (as many as the square root of
# their number), each structure in the group of the centre it is nearest,
# sorted by its distance from it; a group's radius the largest. (Seconds
# with thousands: in a coroutine it yields every 40 ms, and stops when
# `cancelled` names a true variable.)
proc ::VMDance::Measure::_near_index {cent live {cancelled ""}} {
    set ids {}
    set cl 0
    foreach x $live { if {$x} { lappend ids $cl }; incr cl }
    set m [llength $ids]
    set ng [expr {max(1, int(sqrt($m)))}]
    # (each structure's nearest centre so far, and its distance)
    set near [lrepeat $m 0]
    set dist [lrepeat $m Inf]
    set centres {}
    set next 0
    set slice [clock milliseconds]
    for {set g 0} {$g < $ng} {incr g} {
        set c [lindex $cent [lindex $ids $next]]
        lappend centres $c
        set far 0; set fd -1.0
        for {set j 0} {$j < $m} {incr j} {
            set d [veclength [vecsub [lindex $cent [lindex $ids $j]] $c]]
            if {$d < [lindex $dist $j]} { lset dist $j $d; lset near $j $g }
            if {[lindex $dist $j] > $fd} { set fd [lindex $dist $j]; set far $j }
            if {$j % 16 == 0} { ::VMDance::Coords::_breathe slice $cancelled }
        }
        set next $far
    }
    set groups {}
    for {set g 0} {$g < $ng} {incr g} {
        set js [lsearch -all -exact $near $g]
        # (a centre chosen again, when fewer structures differ than there are
        # groups: the same mean structures, none left to it)
        if {![llength $js]} continue
        set ds [lmap j $js {lindex $dist $j}]
        set order [lsort -real -indices $ds]
        set js [lmap o $order {lindex $js $o}]
        set ds [lmap o $order {lindex $ds $o}]
        lappend groups [list [lindex $centres $g] [lindex $ds end] [lmap j $js {lindex $ids $j}] \
            [lmap j $js {lindex $cent [lindex $ids $j]}] $ds]
    }
    return $groups
}
# The distance from row r to the nearest live mean structure of a cluster
# other than l (VMD's veclength, not per atom), of the groups ix
# (_near_index). The triangle inequality bounds the distance to every
# structure of a group from below by r's distance from its centre less its
# radius, and to each by the difference of the two distances from the
# centre: the groups are taken nearest bound first, a group's structures
# from r's distance from its centre outward, and those farther than the
# nearest found are not measured. The answer is the smallest of all the
# distances (a margin of 1e-9 keeps a rounding from leaving out the
# nearest).
proc ::VMDance::Measure::_near_other {ix r l} {
    set dg [lmap g $ix {veclength [vecsub $r [lindex $g 0]]}]
    set lb [lmap g $ix d $dg {expr {$d - [lindex $g 1]}}]
    set best Inf; set lim Inf
    foreach gi [lsort -real -indices $lb] {
        if {[lindex $lb $gi] > $lim} break
        lassign [lindex $ix $gi] - - ids cents ds
        set rg [lindex $dg $gi]
        set m [llength $ids]
        set lo [lsearch -sorted -real -bisect $ds $rg]
        set hi [expr {$lo + 1}]
        while {$lo >= 0 || $hi < $m} {
            if {$hi >= $m || ($lo >= 0 && $rg - [lindex $ds $lo] <= [lindex $ds $hi] - $rg)} {
                set at $lo
                set gap [expr {$rg - [lindex $ds $lo]}]
                incr lo -1
            } else {
                set at $hi
                set gap [expr {[lindex $ds $hi] - $rg}]
                incr hi
            }
            # (the nearer side first: past the margin, every one left is farther)
            if {$gap > $lim} break
            if {[lindex $ids $at] == $l} continue
            set d [veclength [vecsub $r [lindex $cents $at]]]
            if {$d < $best} { set best $d; set lim [expr {$d * (1.0 + 1e-9) + 1e-12}] }
        }
    }
    return $best
}

# Numbers to 6 significant digits (the sessions stay small); "" kept.
proc ::VMDance::Measure::_round {l} {
    lmap v $l {expr {$v eq "" ? "" : [format %.6g $v]}}
}

# Each cluster's MSD as MDANCE has it (the backend's clusterMSD), of the
# rows c: the mean square deviation of every pair of its frames, self-pairs
# too, per atom: 2(n·Σ|x|² − |Σx|²) / (n²·natoms); 0 below two frames. One
# pass.
proc ::VMDance::Measure::cluster_msd {c labels k natoms {cancelled ""}} {
    set sums [lrepeat $k ""]
    set sq [lrepeat $k 0.0]
    set cnt [lrepeat $k 0]
    ::VMDance::Coords::each $c i r {
        set l [lindex $labels $i]
        if {$l >= 0} {
            set s [lindex $sums $l]
            if {$s eq ""} { lset sums $l $r } else { lset sums $l [vecadd $s $r] }
            set v [veclength $r]
            lset sq $l [expr {[lindex $sq $l] + $v * $v}]
            lset cnt $l [expr {[lindex $cnt $l] + 1}]
        }
    } $cancelled
    lmap s $sums q $sq n $cnt {
        if {$n < 2} { expr {0.0} } else {
            set v [veclength $s]
            expr {2.0 * ($n * $q - $v * $v) / (double($n) * $n * $natoms)}
        }
    }
}

# The Calinski–Harabasz and Davies–Bouldin scores of the clustered frames
# of the rows c (labels ≥ 0: noise left out), as scikit-learn computes
# them, and CPP-MDANCE (Euclidean, on the rows), of clusterings cls ({labels
# k} each): {ch db} each, "" with fewer than two clusters or every cluster
# a frame alone. Two passes over the frames for them all, a scan's every k
# (two more for each further share whose clusters' sums take sums_most
# numbers, about 100 MB): the clusters' sums, then every frame's distance
# from its cluster's mean structure.
variable ::VMDance::Measure::sums_most 2000000
proc ::VMDance::Measure::scores {c cls {cancelled ""}} {
    variable sums_most
    set width [expr {3 * [dict get $c natoms]}]
    set out {}
    set batch {}; set held 0
    foreach cl $cls {
        set held [expr {$held + [lindex $cl 1] * $width}]
        if {[llength $batch] && $held > $sums_most} {
            lappend out {*}[_scores $c $batch $cancelled]
            set batch {}; set held [expr {[lindex $cl 1] * $width}]
        }
        lappend batch $cl
    }
    if {[llength $batch]} { lappend out {*}[_scores $c $batch $cancelled] }
    return $out
}
proc ::VMDance::Measure::_scores {c cls cancelled} {
    # (a cluster is its frames: one that several clusterings have, HELM's at
    # one k and the next, is summed and measured once)
    set sets {}
    set nb [llength $cls]
    for {set b 0} {$b < $nb} {incr b} {
        lassign [lindex $cls $b] labels k
        set of($b) {}
        for {set cl 0} {$cl < $k} {incr cl} {
            set fr [lsearch -all -exact $labels $cl]
            if {![llength $fr]} continue
            if {![dict exists $sets $fr]} {
                set x [dict size $sets]
                dict set sets $fr $x
                set cnt($x) [llength $fr]
                foreach i $fr { lappend in($i) $x }
            }
            lappend of($b) [dict get $sets $fr]
        }
    }
    unset sets
    ::VMDance::Coords::each $c i r {
        if {[info exists in($i)]} {
            foreach x $in($i) { set sum($x) [if {[info exists sum($x)]} { vecadd $sum($x) $r } else { set r }] }
        }
    } $cancelled
    # every clustering's mean of all; the clusters' mean structures
    for {set b 0} {$b < $nb} {incr b} {
        set all ""; set n($b) 0
        foreach x $of($b) {
            set all [if {$all eq ""} { set sum($x) } else { vecadd $all $sum($x) }]
            incr n($b) $cnt($x)
        }
        if {$all ne ""} { set mean($b) [vecscale [expr {1.0 / $n($b)}] $all] }
    }
    foreach x [array names sum] {
        set cent($x) [vecscale [expr {1.0 / $cnt($x)}] $sum($x)]
        unset sum($x)
        set W($x) 0.0; set S($x) 0.0
    }
    # every frame from its cluster's mean (squared for CH; the mean
    # distance, each cluster's spread, for DB)
    ::VMDance::Coords::each $c i r {
        if {[info exists in($i)]} {
            foreach x $in($i) {
                set d [veclength [vecsub $r $cent($x)]]
                set W($x) [expr {$W($x) + $d * $d}]
                set S($x) [expr {$S($x) + $d}]
            }
        }
    } $cancelled
    set out {}
    for {set b 0} {$b < $nb} {incr b} {
        set K [llength $of($b)]
        if {$K < 2 || $K >= $n($b)} { lappend out [list "" ""]; continue }
        # between: every cluster's mean from the mean of all, weighted by its
        # frames; within: every frame from its cluster's
        set B 0.0; set w 0.0
        foreach x $of($b) {
            set d [veclength [vecsub $cent($x) $mean($b)]]
            set B [expr {$B + $cnt($x) * $d * $d}]
            set w [expr {$w + $W($x)}]
        }
        set ch [expr {$w == 0 ? 1.0 : $B * ($n($b) - $K) / ($w * ($K - 1.0))}]
        # (each cluster's worst ratio of spreads to separation; two mean
        # structures that coincide give none, as in scikit-learn)
        set tot 0.0
        foreach p $of($b) {
            set worst 0.0
            foreach q $of($b) {
                if {$p == $q} continue
                if {$p < $q} { set pq $p,$q } else { set pq $q,$p }
                if {![info exists D($pq)]} { set D($pq) [veclength [vecsub $cent($p) $cent($q)]] }
                if {$D($pq) > 0} { set worst [expr {max($worst, ($S($p) / $cnt($p) + $S($q) / $cnt($q)) / $D($pq))}] }
            }
            set tot [expr {$tot + $worst}]
        }
        lappend out [list $ch [expr {$tot / $K}]]
    }
    return $out
}

#---------------------------------------------------------------------------
# The map: the frames on their first two principal components
#---------------------------------------------------------------------------

# The axes come from at most map_sample frames, evenly spaced (all of them
# when there are fewer), and every frame is projected on them.
variable ::VMDance::Measure::map_sample 500

# The principal components of the rows c (the coordinates as clustered:
# fitted when the clustering was), from `sample` of them: classical scaling
# of their squared distances, which is PCA (VMD's vecsub and veclength, C,
# make a squared distance in half the time of a dot product), the two
# largest eigenvalues by subspace iteration (_eigen), then every frame
# projected on the two axes. Returns {sample m variance {v1 v2} total t
# pc1 {...} pc2 {...}}: the scores in Å, each axis's share of the sample's
# variance, and its total (Å², the sum of the squared deviations from the
# sample's mean structure, over the sample's frames). An axis's sign is the
# one that makes its largest score positive. In a coroutine it yields every
# 40 ms, and stops when `cancelled` names a true variable.
proc ::VMDance::Measure::pca {c sample {cancelled ""} {progress ""}} {
    set nf [llength [dict get $c frames]]
    set m [expr {min($nf, $sample)}]
    # (evenly spaced rows: the first and the last among them)
    set pick [dict create]
    for {set j 0} {$j < $m} {incr j} {
        dict set pick [expr {$m == 1 ? 0 : int(round(double($j) * ($nf - 1) / ($m - 1)))}] 1
    }
    set rows {}
    set told [clock milliseconds]
    ::VMDance::Coords::each $c i r {
        if {[dict exists $pick $i]} { lappend rows $r }
    } $cancelled
    set m [llength $rows]
    set sum [lindex $rows 0]
    foreach r [lrange $rows 1 end] { set sum [vecadd $sum $r] }
    set mean [vecscale [expr {1.0 / $m}] $sum]
    # B = -1/2 J D² J: the Gram matrix of the rows about their mean
    set D [lrepeat $m [lrepeat $m 0.0]]
    set slice [clock milliseconds]
    set pairs [expr {$m * ($m - 1) / 2}]
    set done 0
    for {set a 0} {$a < $m} {incr a} {
        set ra [lindex $rows $a]
        for {set b [expr {$a + 1}]} {$b < $m} {incr b} {
            set d [veclength [vecsub $ra [lindex $rows $b]]]
            set d [expr {$d * $d}]
            lset D $a $b $d
            lset D $b $a $d
            if {[incr done] % 32 == 0} {
                ::VMDance::Coords::_breathe slice $cancelled
                if {$progress ne "" && [clock milliseconds] - $told >= 250} {
                    set told [clock milliseconds]
                    {*}$progress [expr {0.8 * $done / $pairs}] "the distances between $m frames ($done of $pairs)"
                }
            }
        }
    }
    set rmean [lmap row $D {expr {[::tcl::mathop::+ 0.0 {*}$row] / $m}}]
    set g [expr {[::tcl::mathop::+ 0.0 {*}$rmean] / $m}]
    set B {}
    foreach row $D ri $rmean {
        lappend B [lmap d $row rj $rmean {expr {-0.5 * ($d - $ri - $rj + $g)}}]
    }
    unset D
    set total 0.0
    for {set a 0} {$a < $m} {incr a} { set total [expr {$total + [lindex $B $a $a]}] }
    if {$progress ne ""} { {*}$progress 0.85 "the principal components" }
    lassign [_eigen $B 2 $cancelled] vals vecs
    # each axis in the coordinates' space: the rows' deviations weighted by
    # the eigenvector, scaled so that a row's projection is its score
    set axes {}
    foreach v $vals u $vecs {
        if {$v <= 1e-12 * max($total, 1e-300)} { lappend axes ""; continue }
        set ax [vecscale 0.0 $mean]
        foreach r $rows w $u {
            if {$w != 0} { set ax [vecadd $ax [vecscale $w [vecsub $r $mean]]] }
        }
        lappend axes [vecscale [expr {1.0 / sqrt($v)}] $ax]
    }
    unset rows
    set pc1 {}; set pc2 {}
    lassign $axes a1 a2
    ::VMDance::Coords::each $c i r {
        set x [vecsub $r $mean]
        lappend pc1 [expr {$a1 eq "" ? 0.0 : [vecdot $x $a1]}]
        lappend pc2 [expr {$a2 eq "" ? 0.0 : [vecdot $x $a2]}]
        if {$progress ne "" && [clock milliseconds] - $told >= 250} {
            set told [clock milliseconds]
            {*}$progress [expr {0.9 + 0.1 * $i / $nf}] "projecting the frames ($i of $nf)"
        }
    } $cancelled
    # (the sign that makes the largest score positive)
    set out {}
    foreach l [list $pc1 $pc2] {
        set big 0.0
        foreach x $l { if {abs($x) > abs($big)} { set big $x } }
        if {$big < 0} { set l [lmap x $l {expr {-$x}}] }
        lappend out [_round $l]
    }
    set var [lmap v $vals {expr {$total > 0 ? max(0.0, $v) / $total : 0.0}}]
    dict create sample $m variance [_round $var] total [format %.6g $total] pc1 [lindex $out 0] pc2 [lindex $out 1]
}

# The p largest eigenvalues of the symmetric matrix B (m × m, its rows a
# list) and their eigenvectors: {values vectors}, largest first. Subspace
# iteration on p + 4 vectors (orthonormalized by Gram-Schmidt) until the p
# first turn no more (|cos| of each with its last within 1e-12) or 500 steps,
# then the Rayleigh-Ritz step (_jacobi of the small matrix). Its start is
# fixed: the same matrix gives the same answer.
proc ::VMDance::Measure::_eigen {B p {cancelled ""}} {
    set m [llength $B]
    set b [expr {min($m, $p + 4)}]
    set V {}
    for {set j 0} {$j < $b} {incr j} {
        set v {}
        for {set i 0} {$i < $m} {incr i} { lappend v [expr {sin(0.7 * ($i + 1) * ($j + 1) + 0.3 * $j) + ($i == $j ? 1.0 : 0.0)}] }
        lappend V $v
    }
    set V [_orth $V]
    set slice [clock milliseconds]
    for {set it 0} {$it < 500} {incr it} {
        set W [_orth [lmap v $V {_matvec $B $v}]]
        set turned 0
        for {set j 0} {$j < min($p, [llength $W])} {incr j} {
            if {abs([vecdot [lindex $W $j] [lindex $V $j]]) < 1.0 - 1e-12} { set turned 1 }
        }
        set V $W
        ::VMDance::Coords::_breathe slice $cancelled
        if {!$turned && $it >= 5} break
    }
    # the best vectors within the subspace: the small matrix's eigenvectors
    set Z [lmap v $V {_matvec $B $v}]
    set H [lmap vi $V {lmap zj $Z {vecdot $vi $zj}}]
    lassign [_jacobi $H] vals S
    set order [lsort -real -decreasing -indices $vals]
    set outv {}; set outs {}
    foreach o [lrange $order 0 [expr {$p - 1}]] {
        lappend outv [lindex $vals $o]
        set u [vecscale 0.0 [lindex $V 0]]
        foreach v $V s [lindex $S $o] { set u [vecadd $u [vecscale $s $v]] }
        lappend outs $u
    }
    while {[llength $outv] < $p} { lappend outv 0.0; lappend outs [lrepeat $m 0.0] }
    list $outv $outs
}
proc ::VMDance::Measure::_matvec {B v} { lmap row $B {vecdot $row $v} }
# Vectors made orthonormal (modified Gram-Schmidt); one that is none of its
# own (a combination of those before) is left out.
proc ::VMDance::Measure::_orth {vs} {
    set out {}
    foreach v $vs {
        foreach u $out { set v [vecsub $v [vecscale [vecdot $u $v] $u]] }
        set n [veclength $v]
        if {$n > 1e-12} { lappend out [vecscale [expr {1.0 / $n}] $v] }
    }
    return $out
}
# The eigenvalues of a small symmetric matrix (rows) and its eigenvectors:
# {values vectors}, the vector of value i the i-th (cyclic Jacobi).
proc ::VMDance::Measure::_jacobi {A} {
    set n [llength $A]
    set V {}
    for {set i 0} {$i < $n} {incr i} {
        set row {}
        for {set j 0} {$j < $n} {incr j} { lappend row [expr {$i == $j ? 1.0 : 0.0}] }
        lappend V $row
    }
    for {set sweep 0} {$sweep < 100} {incr sweep} {
        set off 0.0
        for {set i 0} {$i < $n} {incr i} { for {set j [expr {$i + 1}]} {$j < $n} {incr j} { set off [expr {$off + [lindex $A $i $j] ** 2}] } }
        if {$off < 1e-30} break
        for {set p 0} {$p < $n} {incr p} {
            for {set q [expr {$p + 1}]} {$q < $n} {incr q} {
                set apq [lindex $A $p $q]
                if {abs($apq) < 1e-300} continue
                set theta [expr {([lindex $A $q $q] - [lindex $A $p $p]) / (2.0 * $apq)}]
                set t [expr {($theta >= 0 ? 1.0 : -1.0) / (abs($theta) + sqrt($theta * $theta + 1.0))}]
                set c [expr {1.0 / sqrt($t * $t + 1.0)}]
                set s [expr {$t * $c}]
                for {set k 0} {$k < $n} {incr k} {
                    set akp [lindex $A $k $p]; set akq [lindex $A $k $q]
                    lset A $k $p [expr {$c * $akp - $s * $akq}]
                    lset A $k $q [expr {$s * $akp + $c * $akq}]
                }
                for {set k 0} {$k < $n} {incr k} {
                    set apk [lindex $A $p $k]; set aqk [lindex $A $q $k]
                    lset A $p $k [expr {$c * $apk - $s * $aqk}]
                    lset A $q $k [expr {$s * $apk + $c * $aqk}]
                }
                for {set k 0} {$k < $n} {incr k} {
                    set vkp [lindex $V $k $p]; set vkq [lindex $V $k $q]
                    lset V $k $p [expr {$c * $vkp - $s * $vkq}]
                    lset V $k $q [expr {$s * $vkp + $c * $vkq}]
                }
            }
        }
    }
    set vals {}
    for {set i 0} {$i < $n} {incr i} { lappend vals [lindex $A $i $i] }
    # (the vectors as rows: column i of V)
    set vecs {}
    for {set i 0} {$i < $n} {incr i} { lappend vecs [lmap row $V {lindex $row $i}] }
    list $vals $vecs
}

#---------------------------------------------------------------------------
# The profiles: atom by atom, each set of frames' fluctuations, and each
# cluster's mean structure against one cluster's
#---------------------------------------------------------------------------

# Profiles are made for at most profiles_most numbers (2k + groups, times
# the atoms; about 235 bytes each in Tcl).
variable ::VMDance::Measure::profiles_most 600000

# Of the rows c, atom by atom: the RMSF of each cluster's frames and of
# each group's (groups: a group index per row, -1 for none; ng groups),
# about its own mean structure; and the distance of each cluster's mean
# structure from cluster ref's. Frames are compared as they were
# clustered (fitted when the clustering was). Returns {clusters {...}
# groups {...} differences {...}}: a list per cluster (per group), "" for
# one without frames (a cluster without frames has no difference either).
# Two passes; in a coroutine it yields every 40 ms, and stops when
# `cancelled` names a true variable.
proc ::VMDance::Measure::profiles {c labels k groups ng ref {cancelled ""} {progress ""}} {
    set natoms [dict get $c natoms]
    set nf [llength $labels]
    if {![llength $groups]} { set groups [lrepeat $nf -1] }
    # first pass: each set's sums (clusters, then groups)
    set sets [expr {$k + $ng}]
    set sums [lrepeat $sets ""]
    set cnt [lrepeat $sets 0]
    ::VMDance::Coords::each $c i r {
        foreach s [_sets_of $labels $groups $k $i] {
            set x [lindex $sums $s]
            if {$x eq ""} { lset sums $s $r } else { lset sums $s [vecadd $x $r] }
            lset cnt $s [expr {[lindex $cnt $s] + 1}]
        }
    } $cancelled
    set means [lmap x $sums n $cnt {if {$n} { vecscale [expr {1.0 / $n}] $x } else { list }}]
    unset sums
    # second pass: each atom's squared deviation from its sets' mean
    set acc [lrepeat $sets ""]
    set told [clock milliseconds]
    ::VMDance::Coords::each $c i r {
        foreach s [_sets_of $labels $groups $k $i] {
            set sq [_per_atom [vecsub $r [lindex $means $s]]]
            set x [lindex $acc $s]
            if {$x eq ""} { lset acc $s $sq } else { lset acc $s [vecadd $x $sq] }
        }
        if {$progress ne "" && [clock milliseconds] - $told >= 250} {
            set told [clock milliseconds]
            {*}$progress [expr {0.5 + 0.5 * $i / $nf}] "the fluctuations (frame $i of $nf)"
        }
    } $cancelled
    set rmsf [lmap x $acc n $cnt {if {$n} { _round [lmap v $x {expr {sqrt($v / $n)}}] } else { list }}]
    set diff {}
    set mref [lindex $means $ref]
    for {set cl 0} {$cl < $k} {incr cl} {
        set mc [lindex $means $cl]
        lappend diff [if {$mc ne "" && $mref ne ""} { _round [lmap v [_per_atom [vecsub $mc $mref]] {expr {sqrt($v)}}] } else { list }]
    }
    dict create clusters [lrange $rmsf 0 [expr {$k - 1}]] groups [lrange $rmsf $k end] differences $diff
}
# The sets a row is in: its cluster, and k + its group.
proc ::VMDance::Measure::_sets_of {labels groups k i} {
    set out {}
    set l [lindex $labels $i]
    if {$l >= 0} { lappend out $l }
    set g [lindex $groups $i]
    if {$g >= 0} { lappend out [expr {$k + $g}] }
    return $out
}
# A row's squared lengths, atom by atom (x y z each).
proc ::VMDance::Measure::_per_atom {v} {
    set out {}
    foreach {x y z} $v { lappend out [expr {$x * $x + $y * $y + $z * $z}] }
    return $out
}

#---------------------------------------------------------------------------
# From the labels
#---------------------------------------------------------------------------

# The adjusted Rand index of two clusterings of the same frames (labels;
# noise, -1, a cluster of its own): 1 when they are the same, about 0 for
# chance; "" when both put every frame in one cluster (or there is one
# frame).
proc ::VMDance::Measure::ari {a b} {
    set n [llength $a]
    if {$n < 2} { return "" }
    set ab {}; set na {}; set nb {}
    foreach x $a y $b {
        dict incr ab $x,$y
        dict incr na $x
        dict incr nb $y
    }
    set pairs {apply {{v} {expr {$v * ($v - 1) / 2.0}}}}
    set sij 0.0; set sa 0.0; set sb 0.0
    dict for {key v} $ab { set sij [expr {$sij + [{*}$pairs $v]}] }
    dict for {key v} $na { set sa [expr {$sa + [{*}$pairs $v]}] }
    dict for {key v} $nb { set sb [expr {$sb + [{*}$pairs $v]}] }
    set all [{*}$pairs $n]
    set expected [expr {$sa * $sb / $all}]
    set most [expr {($sa + $sb) / 2.0}]
    if {$most == $expected} { return "" }
    expr {($sij - $expected) / ($most - $expected)}
}

# The frames of each cluster by group: {cluster {count per group} ...} as
# a k × ng matrix (rows the clusters; noise and frames of no group left
# out).
proc ::VMDance::Measure::makeup {labels groups k ng} {
    set M [lrepeat $k [lrepeat $ng 0]]
    foreach l $labels g $groups {
        if {$l < 0 || $g < 0} continue
        lset M $l $g [expr {[lindex $M $l $g] + 1}]
    }
    return $M
}

# The runs of consecutive analysed frames in one cluster: {label first
# length} each, in order (noise too, as label -1).
proc ::VMDance::Measure::runs {labels} {
    set out {}
    set prev ""; set start 0; set i 0
    foreach l $labels {
        if {$l ne $prev} {
            if {$prev ne ""} { lappend out [list $prev $start [expr {$i - $start}]] }
            set prev $l; set start $i
        }
        incr i
    }
    if {$prev ne ""} { lappend out [list $prev $start [expr {$i - $start}]] }
    return $out
}

# The transitions between clusters from each analysed frame to the one
# lag frames later: a k × k matrix of counts (noise frames left out).
proc ::VMDance::Measure::transitions {labels k {lag 1}} {
    set T [lrepeat $k [lrepeat $k 0]]
    set n [llength $labels]
    for {set i 0} {$i + $lag < $n} {incr i} {
        set a [lindex $labels $i]; set b [lindex $labels [expr {$i + $lag}]]
        if {$a < 0 || $b < 0} continue
        lset T $a $b [expr {[lindex $T $a $b] + 1}]
    }
    return $T
}

# Average linkage (UPGMA) of the clusters from a k × k matrix of distances
# ("" for an empty cluster, which is left out): rows {left right distance
# count}, the leaves numbered as the clusters, each merge k, k+1 ... in
# turn (count: the leaves under it). Each node keeps its nearest node
# after it (the naive search's order, so that ties go the same way): a
# merge searches again only the nodes whose nearest it took.
proc ::VMDance::Measure::linkage {M} {
    set k [llength $M]
    set active {}
    for {set i 0} {$i < $k} {incr i} {
        if {[lindex $M $i $i] ne ""} { lappend active $i; set cnt($i) 1 }
        for {set j 0} {$j < $k} {incr j} { set D($i,$j) [lindex $M $i $j] }
    }
    # near(i): {distance j}, the nearest node after i in active ("": none)
    foreach i $active { set near($i) [_nearest D $i [lrange $active [expr {[lsearch -exact $active $i] + 1}] end]] }
    set rows {}
    set next $k
    while {[llength $active] > 1} {
        set best ""; set bi ""; set bj ""
        foreach i $active {
            lassign $near($i) d j
            if {$d ne "" && ($best eq "" || $d < $best)} { set best $d; set bi $i; set bj $j }
        }
        if {$best eq ""} break
        set n [expr {$cnt($bi) + $cnt($bj)}]
        lappend rows [list $bi $bj $best $n]
        set cnt($next) $n
        foreach o $active {
            if {$o == $bi || $o == $bj} continue
            set a $D($o,$bi); set b $D($o,$bj)
            set d [expr {$a eq "" || $b eq "" ? "" : ($a * $cnt($bi) + $b * $cnt($bj)) / double($n)}]
            set D($o,$next) $d; set D($next,$o) $d
        }
        set D($next,$next) 0.0
        set active [lmap o $active {expr {$o == $bi || $o == $bj ? [continue] : $o}}]
        unset near($bi) near($bj)
        # the new node is last: it can only be a nearer one, and ties go to
        # the node found first
        set p 0
        foreach o $active {
            incr p
            lassign $near($o) od oj
            if {$oj == $bi || $oj == $bj} {
                set near($o) [_nearest D $o [concat [lrange $active $p end] $next]]
            } elseif {$D($o,$next) ne "" && ($od eq "" || $D($o,$next) < $od)} {
                set near($o) [list $D($o,$next) $next]
            }
        }
        lappend active $next
        set near($next) {}
        incr next
    }
    return $rows
}
proc ::VMDance::Measure::_nearest {dvar i after} {
    upvar 1 $dvar D
    set best ""; set bj ""
    foreach j $after {
        set d $D($i,$j)
        if {$d ne "" && ($best eq "" || $d < $best)} { set best $d; set bj $j }
    }
    expr {$best eq "" ? {} : [list $best $bj]}
}

# The height of each of HELM's merges: the MSD (MDANCE's, Å²) of the
# cluster it makes, from the starting clusters' sums (one pass over the
# rows c of the clustered frames: labels >= 0, init their starting
# clusters), tree the merges as helm_tree numbers them ({rows leaves n0}).
# A list, a value per merge, in their order: how far apart the clusters
# each merge joins are, which their rank does not tell.
proc ::VMDance::Measure::merge_msd {c labels init tree {cancelled ""}} {
    lassign $tree rows leaves n0
    set natoms [dict get $c natoms]
    ::VMDance::Coords::each $c i r {
        if {[lindex $labels $i] < 0} continue
        set s [lindex $init $i]
        set v [veclength $r]
        if {[info exists S($s)]} {
            set S($s) [vecadd $S($s) $r]
            set Q($s) [expr {$Q($s) + $v * $v}]
            incr N($s)
        } else {
            set S($s) $r; set Q($s) [expr {$v * $v}]; set N($s) 1
        }
    } $cancelled
    set out {}
    set j 0
    foreach row $rows {
        lassign $row a b
        set nd [expr {$n0 + $j}]
        if {[info exists S($a)] && [info exists S($b)]} {
            set S($nd) [vecadd $S($a) $S($b)]
            set Q($nd) [expr {$Q($a) + $Q($b)}]
            set N($nd) [expr {$N($a) + $N($b)}]
            set v [veclength $S($nd)]
            lappend out [format %.6g [expr {2.0 * ($N($nd) * $Q($nd) - $v * $v) / (double($N($nd)) * $N($nd) * $natoms)}]]
        } else {
            lappend out ""
        }
        incr j
    }
    return $out
}

# HELM's merges with the leaves and nodes numbered as scipy numbers them:
# {rows leaves n0}, the leaves the starting clusters not trimmed (0 ..
# n0-1, the values of init, whose frames have labels), the merge of row j
# node n0 + j. CPP-MDANCE numbers its merges from the number of starting
# clusters kept after trimming, so that a merge and a kept starting
# cluster can have the same number: each is told apart by what is still
# unmerged and by the row's count (the starting clusters under the merge),
# trying the other when the rows that follow do not fit. Without init (a
# session of the MDANCE plugin), the leaves are 0 .. rows + k - 1.
proc ::VMDance::Measure::helm_tree {z init labels k} {
    if {[llength $init]} {
        set n0 [expr {[::tcl::mathfunc::max {*}$init] + 1}]
        foreach s $init l $labels { if {$l >= 0} { set keep($s) 1 } }
        set leaves [lsort -integer [array names keep]]
    } else {
        set n0 [expr {[llength $z] + $k}]
        set leaves {}
        for {set i 0} {$i < $n0} {incr i} { lappend leaves $i }
    }
    set base [llength $leaves]
    set nr [llength $z]
    if {$base != $nr + $k} { error "HELM's merges ($nr) do not join its [llength $leaves] starting clusters into $k" }
    # free: the nodes not merged yet -> the starting clusters under them
    set free [dict create]
    foreach s $leaves { dict set free $s 1 }
    set out {}
    set tried {}          ;# per row: {options, the one taken, free before}
    set j 0
    set steps 0
    while {$j < $nr} {
        if {[incr steps] > 20 * $nr + 1000} { error "HELM's merges could not be read" }
        if {[llength $tried] > $j} {
            # back from a row that did not fit: the next reading of this one
            lassign [lindex $tried $j] opts o free
            incr o
            set tried [lrange $tried 0 [expr {$j - 1}]]
            set out [lrange $out 0 [expr {$j - 1}]]
        } else {
            set opts [_helm_options [lindex $z $j] $j $free $base $n0]
            set o 0
        }
        if {$o >= [llength $opts]} {
            if {$j == 0} { error "HELM's merges do not fit its starting clusters" }
            incr j -1
            continue
        }
        lappend tried [list $opts $o $free]
        lassign [lindex $opts $o] a b
        set n [expr {[dict get $free $a] + [dict get $free $b]}]
        dict unset free $a
        dict unset free $b
        dict set free [expr {$n0 + $j}] $n
        lassign [lindex $z $j] - - d
        lappend out [list $a $b $d $n]
        incr j
    }
    list $out $leaves $n0
}
# The readings of a row of HELM's merges: {a b} pairs of free nodes (in
# the numbering of helm_tree) whose starting clusters add up to the row's
# count; a merge first.
proc ::VMDance::Measure::_helm_options {row j free base n0} {
    lassign $row a b d n
    foreach v {a b} {
        set x [set $v]
        set c($v) {}
        if {$x >= $base && $x - $base < $j && [dict exists $free [expr {$n0 + $x - $base}]]} { lappend c($v) [expr {$n0 + $x - $base}] }
        if {$x < $n0 && [dict exists $free $x]} { lappend c($v) $x }
    }
    set out {}
    foreach ca $c(a) {
        foreach cb $c(b) {
            if {$ca == $cb} continue
            if {$n ne "" && [dict get $free $ca] + [dict get $free $cb] != $n} continue
            lappend out [list $ca $cb]
        }
    }
    return $out
}
