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
# From the labels
#---------------------------------------------------------------------------

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
