#
# VMDance - the clusterings in memory, what is read from them, and the
# selection (no Tk dependency)
#
# One clustering is current. It is published whole (publish): checked,
# its derived values computed, and every listener told; a failed,
# cancelled or refused job leaves it as it was. Every clustering
# published is kept as a run (the last 25, compressed); switching runs
# publishes a kept one. What is asked of a clustering afterwards (PRIME,
# the similarity) is kept with its run (attach).
#
# Beside the runs: the last elbow scan, the last sweep and the last frames
# picked without clustering, and the selection (the clusters picked in the
# table or a plot), which every view draws on top.
#
# Frames: the result holds the VMD frames it clustered (frames), and
# every per-frame list (labels, measures) is in that order: row i is VMD
# frame [lindex frames i]. They are VMD's frame numbers of now only while
# the molecule has those frames at those numbers (frames_ok, picks_ok).
#

namespace eval ::VMDance::Results {
    variable A {}              ;# the current clustering ({} = none)
    variable listeners {}
    variable runs {}           ;# {id label packed} ..., oldest first
    variable current ""
    variable next_id 1
    variable limit 25
    variable selection {}      ;# selected clusters, sorted
    variable elbow {}          ;# the last elbow scan
    variable sweep {}          ;# the last sweep
    variable picks {}          ;# the last frames picked
    variable revision 0
    # the molecule as it was when a job read a run's frames (or a session's
    # run was found to have them): run id -> {mol numframes files deletions}
    # (_now); the picks' alone. Never saved: a session's molecule may be
    # another of the same names.
    variable trusted {}
    variable picks_trusted ""
    # the last answer of frames_ok and picks_ok: {state answer extra}
    variable last_ok {}
    variable last_picks_ok {}
    # each molecule as last seen: mol -> {files numframes deletions} (_now)
    variable seen {}
    # derived from A
    variable K 0; variable N 0
    variable labels {}; variable frames {}; variable sizes {}; variable reps {}
    variable members           ;# cluster -> rows
    variable noise 0
    variable memo              ;# values made from A when first asked
}

proc ::VMDance::Results::has_data {} { variable A; expr {[dict size $A] > 0} }

# A value made from the current clustering, made once (the plots ask for
# the same ones on every redraw and every pointer motion).
proc ::VMDance::Results::memo {key script} {
    variable memo
    if {![info exists memo($key)]} { set memo($key) [uplevel 1 $script] }
    return $memo($key)
}
# The same of a value with an argument (a lag): only the last argument's is
# kept (a script's loop over lags kept a k × k matrix for each).
proc ::VMDance::Results::memo_last {key arg script} {
    variable memo
    if {![info exists memo($key)] || [lindex $memo($key) 0] ne $arg} { set memo($key) [list $arg [uplevel 1 $script]] }
    lindex $memo($key) 1
}

proc ::VMDance::Results::listen {cmd} {
    variable listeners
    if {$cmd ni $listeners} { lappend listeners $cmd }
}
proc ::VMDance::Results::unlisten {cmd} {
    variable listeners
    set i [lsearch -exact $listeners $cmd]
    if {$i >= 0} { set listeners [lreplace $listeners $i $i] }
}
# what: analysis, selection, runs, extras, elbow, sweep, picks
proc ::VMDance::Results::_notify {what} {
    variable listeners; variable revision
    incr revision
    foreach l $listeners {
        if {[catch {uplevel #0 [list {*}$l $what]} err]} { puts "VMDance) listener: $err" }
    }
}

#---------------------------------------------------------------------------
# Checking a result (published, or read from a session)
#---------------------------------------------------------------------------

# (a list made of a text costs about 120 bytes a value, and a file of a few
# kilobytes can hold millions: a list must have n values is refused when
# its text is longer than n values can be, before it is made; w the most
# characters of a value)
proc ::VMDance::Results::_fits {what l n w} {
    if {$n ne "" && [string length $l] > ($w + 1) * $n} { error "$what has more than $n values" }
}
# The number of values of a list of plain words (numbers, the atoms' texts),
# whatever the white space between them (any that Tcl's lists split on, and
# runs of it), counted without making them; "" for another list (braces,
# quotes or backslashes). charsvar: their characters, without the space.
proc ::VMDance::Results::_count {l {charsvar ""}} {
    if {$charsvar ne ""} { upvar 1 $charsvar chars }
    if {[regexp {[\{\}"\\\t\n\v\f\r]} $l]} {
        if {[regexp {[\{\}"\\]} $l]} { return "" }
        set l [string map {\t " " \n " " \v " " \f " " \r " "} $l]
    }
    if {[string index $l 0] eq " " || [string index $l end] eq " "} { set l [string trim $l " "] }
    set chars 0
    if {$l eq ""} { return 0 }
    while {[string first "  " $l] >= 0} { set l [string map {"  " " "} $l] }
    set chars [string length [string map {" " ""} $l]]
    expr {[string length $l] - $chars + 1}
}
# The number of values of any list's text, as Tcl reads them (a braced or
# quoted value is one, whatever it holds), counted without making them and
# at most most + 1 (the rest not read); "" when it is not a list.
proc ::VMDance::Results::_elements {l most} {
    set n 0
    set i 0
    set end [string length $l]
    while {$n <= $most && [regexp -start $i -indices {[^ \t\n\v\f\r]} $l m]} {
        set i [lindex $m 0]
        incr n
        switch -- [string index $l $i] {
            "\{" {
                # (to the brace that closes it: a backslash escapes one)
                set depth 0
                while {[regexp -start $i -indices {[{}\\]} $l m]} {
                    set i [lindex $m 0]
                    switch -- [string index $l $i] {
                        "\{" { incr depth }
                        "\}" { if {[incr depth -1] == 0} break }
                        default { incr i }
                    }
                    incr i
                }
                if {$depth} { return "" }
                incr i
            }
            "\"" {
                incr i
                while {[regexp -start $i -indices {["\\]} $l m]} {
                    set i [lindex $m 0]
                    if {[string index $l $i] eq "\""} break
                    incr i 2
                }
                if {[string index $l $i] ne "\""} { return "" }
                incr i
            }
            default {
                # (a word: to white space not escaped; a backslash and a
                # line end take the spaces and tabs after them)
                while {1} {
                    if {![regexp -start $i -indices {[ \t\n\v\f\r\\]} $l m]} { set i $end; break }
                    set i [lindex $m 0]
                    if {[string index $l $i] ne "\\"} break
                    if {[string index $l [incr i]] ne "\n"} { incr i; continue }
                    set i [expr {[regexp -start [incr i] -indices {[^ \t]} $l m] ? [lindex $m 0] : $end}]
                }
                continue
            }
        }
        # (a braced or quoted value is followed by white space)
        if {$i < $end && [string first [string index $l $i] " \t\n\v\f\r"] < 0} { return "" }
    }
    return $n
}
proc ::VMDance::Results::_intlist {what l n lo hi} {
    _fits $what $l $n 13
    if {![string is list $l]} { error "$what is not a list" }
    if {$n ne "" && [llength $l] != $n} { error "$what has [llength $l] values, not $n" }
    if {![llength $l]} return
    # (every value in one regexp and the range by min and max, in C: the
    # loop below only names the one at fault)
    if {[regexp {^(-?(0|[1-9][0-9]{0,11}) )*-?(0|[1-9][0-9]{0,11})$} [join $l " "]] &&
        [::tcl::mathfunc::min {*}$l] >= $lo && ($hi eq "" || [::tcl::mathfunc::max {*}$l] <= $hi)} return
    foreach v $l {
        if {![regexp {^-?[0-9]+$} $v] || [regexp {^-?0[0-9]} $v]} { error "$what holds \"$v\"" }
        if {$v < $lo || ($hi ne "" && $v > $hi)} { error "$what holds $v (outside $lo to $hi)" }
    }
}
# (numbers as the plugin writes them: decimal, no octal 010 or hex 0x10
# that expr would read otherwise, no NaN; every value of a long list in
# one regexp, the one at fault looked for only when there is one)
# (at most 20 digits before the point and an exponent of at most 280:
# below 1e300, which a double holds)
variable ::VMDance::Results::number {-?(0|[1-9][0-9]{0,19})(\.[0-9]{1,40})?([eE](-[0-9]{1,3}|\+?(2[0-7][0-9]|280|1?[0-9]?[0-9])))?}
proc ::VMDance::Results::_numlist {what l n} {
    variable number
    _fits $what $l $n 67
    if {![string is list $l]} { error "$what is not a list" }
    if {$n ne "" && [llength $l] != $n} { error "$what has [llength $l] values, not $n" }
    set vals [lsearch -all -inline -not -exact $l ""]
    if {[regexp "^(${number}( |\$))*\$" [join $vals " "]]} return
    foreach v $vals {
        if {![regexp "^${number}\$" $v]} { error "$what holds \"$v\"" }
    }
}
proc ::VMDance::Results::_isdict {what d} {
    if {![string is list $d] || [llength $d] % 2} { error "$what is not a dictionary" }
}

# The clustering part of a result (or of a scan's record), for n frames:
# nclusters labels sizes representatives msd ch db zmatrix initial.
proc ::VMDance::Results::check_clustering {a n} {
    _isdict "the clustering" $a
    foreach k {nclusters labels sizes representatives msd ch db zmatrix initial} {
        if {![dict exists $a $k]} { error "the clustering has no \"$k\"" }
    }
    set k [dict get $a nclusters]
    if {![regexp {^(0|[1-9][0-9]{0,8})$} $k]} { error "nclusters is \"$k\"" }
    # (as the backend's answer: before anything k long is made)
    if {$k > $n} { error "nclusters ($k) is more than the $n frames" }
    _intlist "labels" [dict get $a labels] $n -1 [expr {$k - 1}]
    _intlist "sizes" [dict get $a sizes] $k 0 $n
    set count [lrepeat $k 0]
    foreach l [dict get $a labels] { if {$l >= 0} { lset count $l [expr {[lindex $count $l] + 1}] } }
    if {$count ne [dict get $a sizes]} { error "the sizes are not those of the labels" }
    _intlist "representatives" [dict get $a representatives] $k -1 [expr {$n - 1}]
    set c 0
    foreach p [dict get $a representatives] s [dict get $a sizes] {
        if {$s == 0 ? $p != -1 : ($p < 0 || [lindex [dict get $a labels] $p] != $c)} { error "the representative of cluster $c is not one of its frames" }
        incr c
    }
    _numlist "the cluster MSDs" [dict get $a msd] $k
    _numlist "the scores" [list [dict get $a ch] [dict get $a db]] 2
    # (HELM merges at most n starting clusters: fewer than n rows of 4)
    _fits "the merge matrix" [dict get $a zmatrix] $n 120
    foreach row [dict get $a zmatrix] {
        if {![string is list $row] || [llength $row] != 4} { error "the merge matrix is corrupt" }
        _intlist "the merge matrix" [lreplace $row 2 2] 3 0 ""
        _numlist "the merge matrix" [lrange $row 2 2] 1
    }
    set init [dict get $a initial]
    if {[llength $init]} { _intlist "the starting clusters" $init $n 0 "" }
    return 1
}

# Refuse a result that is not whole and consistent (an error says why).
proc ::VMDance::Results::check {a} {
    _isdict "the result" $a
    foreach k {format request molecule frames natoms nclusters labels sizes representatives msd ch db zmatrix initial measures extras} {
        if {![dict exists $a $k]} { error "the result has no \"$k\"" }
    }
    if {[dict get $a format] ne "1"} { error "result format \"[dict get $a format]\" is not known" }
    set q [dict get $a request]
    _isdict "the request" $q
    foreach k {mol sel fit first last step algorithm k metric params} {
        if {![dict exists $q $k]} { error "the request has no \"$k\"" }
    }
    set alg [dict get $q algorithm]
    if {![::VMDance::Algo::exists $alg]} { error "unknown algorithm \"$alg\"" }
    ::VMDance::Algo::check_metric [dict get $q metric]
    if {[catch {::VMDance::Algo::check_params $alg [dict get $q params] 1} err]} { error "the request's parameters: $err" }
    set qk [dict get $q k]
    if {[::VMDance::Algo::takes_k $alg] ? ![regexp {^(0|[1-9][0-9]{0,8})$} $qk] : ($qk ni {"" 0})} { error "the request's k is \"$qk\"" }
    foreach k {first last step} {
        if {![regexp {^-?(0|[1-9][0-9]{0,8})$} [dict get $q $k]]} { error "the request's $k is \"[dict get $q $k]\"" }
    }
    check_molecule "the molecule record" [dict get $a molecule]
    check_meta "the result's" $a
    # (an import's: what its file does not record of how it was made)
    if {[dict exists $a unrecorded]} {
        set u [dict get $a unrecorded]
        if {[string length $u] > 20 || ![string is list $u] || [llength [lsearch -all -inline -not -regexp $u {^(metric|params)$}]]} {
            error "the result's unrecorded is corrupt"
        }
    }
    set fr [dict get $a frames]
    # (as many frames as labels, counted before either is made a list)
    set nf [_count $fr]
    set nl [_count [dict get $a labels]]
    if {$nf ne "" && $nl ne "" && $nf != $nl} { error "labels has $nl values, not $nf" }
    check_frames "frames" $fr
    set n [llength $fr]
    if {$n < 1} { error "the result has no frame" }
    set na [dict get $a natoms]
    if {![regexp {^[1-9][0-9]{0,9}$} $na]} { error "natoms is \"$na\"" }
    check_atoms "the request's" $q $na [dict get $a molecule]
    check_identity "the result's" $a $n
    check_clustering $a $n
    set k [dict get $a nclusters]
    # (the tree is made when asked for: its merges must fit now)
    if {[llength [dict get $a zmatrix]] &&
        [catch {::VMDance::Measure::helm_tree [dict get $a zmatrix] [dict get $a initial] [dict get $a labels] $k} err]} {
        error "the merge matrix: $err"
    }
    set m [dict get $a measures]
    _isdict "the measures" $m
    foreach key {frame_msd silhouette} {
        if {![dict exists $m $key]} { error "the measures have no \"$key\"" }
        _numlist "the measure $key" [dict get $m $key] $n
    }
    foreach key {rep_msd centroid_msd} {
        if {![dict exists $m $key]} { error "the measures have no \"$key\"" }
        set M [dict get $m $key]
        _fits "the measure $key" $M $k [expr {68 * $k + 2}]
        # (none above Measure::maxk clusters: not measured; a larger maxk
        # would refuse a session's run of fewer without them)
        if {$k > $::VMDance::Measure::maxk && [string is list $M] && ![llength $M]} continue
        if {![string is list $M] || [llength $M] != $k} { error "the measure $key is not $k × $k" }
        foreach row $M { _numlist "the measure $key" $row $k }
    }
    _isdict "the extras" [dict get $a extras]
    dict for {key v} [dict get $a extras] {
        switch -- $key {
            prime { _check_prime $v $n }
            similarity { _check_similarity $v $n $k }
            default { error "unknown extra \"$key\"" }
        }
    }
    return 1
}
# The VMD frames of a result, a scan or the frame picks: whole numbers in
# increasing order (the frame of a row is looked for by bisection), counted
# before they are made: n different whole numbers have at least the digits
# of 0 to n-1 (a text of one value repeated is refused unread).
proc ::VMDance::Results::check_frames {what fr} {
    set n [_count $fr digits]
    if {$n eq ""} { error "$what are not whole numbers" }
    if {$digits < [_least_digits $n]} {
        error "$what are not in increasing order (their $n values have fewer digits than 0 to [expr {$n - 1}])"
    }
    _intlist $what $fr $n 0 ""
    set p -1
    foreach f $fr { if {$f <= $p} { error "$what are not in increasing order" }; set p $f }
}
# The fewest digits n different whole numbers have: those of 0 to n-1.
proc ::VMDance::Results::_least_digits {n} {
    set d 0
    set w 1
    for {set lo 0; set hi 10} {$lo < $n} {set lo $hi; set hi [expr {$hi * 10}]; incr w} {
        incr d [expr {$w * (min($n, $hi) - $lo)}]
    }
    return $d
}
# What a result, a scan or the picks say of themselves (backend seconds
# created), read as they are shown: a list, the seconds a number, the date
# a date; "" when a file made by hand leaves them out. (whose: "the
# result's" …)
proc ::VMDance::Results::check_meta {whose d} {
    foreach {key re} {backend {} seconds {^[0-9]{1,9}(\.[0-9]{1,6})?$} created {^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$}} {
        if {![dict exists $d $key]} continue
        set v [dict get $d $key]
        if {![string is list $v] || ($re ne "" && $v ne "" && ![regexp $re $v])} { error "$whose $key is corrupt" }
    }
}
# A molecule record (Mol::record): {} (not recorded), or name numatoms
# numframes files types, and paths (the files in full: not in sessions made
# before).
proc ::VMDance::Results::check_molecule {what r} {
    _isdict $what $r
    if {![dict size $r]} return
    foreach k {name numatoms numframes files types} { if {![dict exists $r $k]} { error "$what has no \"$k\"" } }
    foreach k {numatoms numframes} { if {![regexp {^(0|[1-9][0-9]{0,11})$} [dict get $r $k]]} { error "$what's $k is \"[dict get $r $k]\"" } }
    foreach k {files types} { if {![string is list [dict get $r $k]]} { error "$what's $k are corrupt" } }
    if {[llength [dict get $r files]] != [llength [dict get $r types]]} { error "$what's files and types differ in number" }
    if {[dict exists $r paths] && (![string is list [dict get $r paths]] || [llength [dict get $r paths]] != [llength [dict get $r files]])} {
        error "$what's paths are corrupt"
    }
}
# The atoms of a request (q: a result's, a scan's, the picks' input) as
# check_input wrote them, "index 0 to 9 12" (the fit's "" when there is
# none): selection texts given to atomselect, so their form is checked, and
# their length (natoms: at most a run of each; "" not known) before they are
# matched. (A request of a session made before has the texts only.)
proc ::VMDance::Results::check_atoms {whose q natoms mol} {
    if {![dict exists $q atoms]} return
    set re {^index( (0|[1-9][0-9]{0,9})( to (0|[1-9][0-9]{0,9}))?)+$}
    set fa [::VMDance::_get $q fitatoms ""]
    set c [_count [dict get $q atoms]]
    if {$c eq "" || ($natoms ne "" && $c > 3 * $natoms + 1) || ![regexp $re [dict get $q atoms]]} { error "$whose atoms are corrupt" }
    # (the fit's atoms: of the molecule, at most)
    set most [::VMDance::_get $mol numatoms ""]
    set c [_count $fa]
    if {$fa ne "" && ($c eq "" || ($most ne "" && $c > 3 * $most + 1) || ![regexp $re $fa])} { error "$whose fit atoms are corrupt" }
}
# What tells the frames a result, a scan or the picks were made from (d) as
# read from a file: the digest of their coordinates' fingerprints ("2:" and
# 16 hexadecimal digits; 16 alone, made before the fingerprint had its
# RMSD: Coords::_digest), and every frame's radius of gyration (shape),
# numbers before they are compared.
proc ::VMDance::Results::check_identity {whose d n} {
    if {[dict exists $d digest] && ![regexp {^((2:)?[0-9a-f]{16})?$} [dict get $d digest]]} { error "$whose digest is corrupt" }
    if {[dict exists $d shape]} {
        set s [dict get $d shape]
        _numlist "$whose shapes" $s $n
        if {"" in $s} { error "$whose shapes are corrupt" }
    }
}
proc ::VMDance::Results::_check_params {what p specs} {
    _isdict $what $p
    if {[catch {::VMDance::Job::check_specs $specs $p 1} err]} { error "$what: $err" }
}
proc ::VMDance::Results::_check_prime {p n} {
    _isdict "PRIME's result" $p
    if {![dict exists $p params]} { error "PRIME's result has no \"params\"" }
    _check_params "PRIME's parameters" [dict get $p params] $::VMDance::Algo::prime_params
    foreach key {pairwise union medoid outlier medoidAll medoidC0 medoidC0Trimmed} {
        if {![dict exists $p $key]} { error "PRIME's result has no \"$key\"" }
        _intlist "PRIME's $key" [list [dict get $p $key]] 1 -1 [expr {$n - 1}]
    }
}
proc ::VMDance::Results::_check_similarity {s n k} {
    _isdict "the similarity" $s
    foreach key {isim cluster outliers params} { if {![dict exists $s $key]} { error "the similarity has no \"$key\"" } }
    _check_params "the similarity's parameters" [dict get $s params] $::VMDance::Algo::similarity_params
    _numlist "the similarity" [list [dict get $s isim]] 1
    _numlist "the clusters' similarity" [dict get $s cluster] $k
    _intlist "the least similar frames" [dict get $s outliers] $k -1 [expr {$n - 1}]
}

#---------------------------------------------------------------------------
# Publishing, runs
#---------------------------------------------------------------------------

# (the fastest compression: a clustering of a thousand clusters holds two
# million distances, and level 6 took three seconds for them)
proc ::VMDance::Results::pack {a} { zlib compress [encoding convertto utf-8 $a] 1 }
proc ::VMDance::Results::unpack {b} { encoding convertfrom utf-8 [zlib decompress $b] }

# A short name for a run: "KMeans NANI, k 5, 6 clusters".
proc ::VMDance::Results::describe {a} {
    set q [dict get $a request]
    set alg [dict get $q algorithm]
    set s [::VMDance::Algo::label $alg]
    if {[dict get $q k] ne ""} { append s ", k [dict get $q k]" } else { append s ", radius [dict get $q params threshold]" }
    set k [dict get $a nclusters]
    append s " → $k cluster[expr {$k == 1 ? "" : "s"}]"
    return $s
}

# Publish a clustering as a new run (and the current one): a job's, which
# read its frames on its molecule as its record has it.
proc ::VMDance::Results::publish {a {label ""}} {
    variable runs; variable current; variable next_id; variable limit; variable trusted
    check $a
    # (everything that can fail before anything is replaced)
    if {$label eq ""} { set label [describe $a] }
    set packed [pack $a]
    _install $a
    set id $next_id
    incr next_id
    lappend runs [list $id $label $packed]
    if {[llength $runs] > $limit} {
        set runs [lrange $runs end-[expr {$limit - 1}] end]
        set ids [lmap r $runs {lindex $r 0}]
        set trusted [dict filter $trusted script {k v} {expr {$k in $ids}}]
    }
    dict set trusted $id [_trust [dict get $a request mol] $a]
    set current $id
    _notify analysis
    return $id
}
# The molecule as a record says it was: {mol numframes files} ("" without
# a record: deleted while the job ran).
proc ::VMDance::Results::_as_made {m rec} {
    if {![dict exists $rec numframes] || ![dict exists $rec files]} { return "" }
    list $m [dict get $rec numframes] [dict get $rec files]
}
# The molecule as it is now (it is loaded): {mol numframes files}.
proc ::VMDance::Results::_state {m} {
    list $m [molinfo $m get numframes] [lindex [molinfo $m get filename] 0]
}
# The state of it that is kept (trusted, the last answers): {mol numframes
# files deletions}, deletions the times its frames were seen fewer than
# before (of the same files): VMD says nothing when frames are deleted,
# and frames deleted back to a count seen while a trajectory loaded leave
# the count and the files as they were, not the frames at their numbers.
# Its frame is traced from then on (_frame_seen: a load writes it at every
# frame read; a deletion, only when the frame shown moves).
proc ::VMDance::Results::_now {m} {
    variable seen
    set n [molinfo $m get numframes]
    set f [lindex [molinfo $m get filename] 0]
    set k 0
    if {[dict exists $seen $m]} {
        lassign [dict get $seen $m] f0 n0 k
        if {$f eq $f0 && $n < $n0} { incr k }
    } else {
        trace add variable ::vmd_frame($m) write ::VMDance::Results::_frame_seen
    }
    dict set seen $m [list $f $n $k]
    list $m $n $f $k
}
proc ::VMDance::Results::_frame_seen {name m op} {
    catch { if {[::VMDance::Mol::exists $m]} { _now $m } }
}
# The state to trust for d (a result or the picks) a job made on molecule
# m: the molecule as the job's record has it, where the job read d's
# frames (the kept extraction, when it is d's: frames deleted while the job
# ran, back to that count, are not those it read: the first and last that
# matter, _span, are compared); else as it is now. "" when it is not as
# made.
proc ::VMDance::Results::_trust {m d} {
    set made [_as_made $m [dict get $d molecule]]
    # (without VMD, tclsh: no molecule)
    if {$made eq "" || [info commands molinfo] eq "" || ![::VMDance::Mol::exists $m] || [_state $m] ne $made} { return "" }
    set c $::VMDance::Coords::C
    if {[dict size $c] && [dict get $c mol] eq $m && [dict get $c frames] eq [dict get $d frames] &&
        [dict get $c digest] eq [::VMDance::_get $d digest ""]} {
        set f1 [expr {[_span $d] - 1}]
        if {[catch {::VMDance::Coords::ends $m [dict get $c atoms] [dict get $c fitatoms] [lindex [dict get $d frames] 0] \
                [lindex [dict get $d frames] $f1]} ends] ||
            $ends ne [list [lindex [dict get $c fp] 0] [lindex [dict get $c fp] $f1]]} { return "" }
    }
    _now $m
}

proc ::VMDance::Results::_install {a} {
    variable A; variable K; variable N; variable labels; variable frames; variable sizes
    variable reps; variable members; variable noise; variable selection; variable memo; variable last_ok
    array unset memo *
    set last_ok {}
    set A $a
    set K [dict get $a nclusters]
    set labels [dict get $a labels]
    set frames [dict get $a frames]
    set N [llength $frames]
    set sizes [dict get $a sizes]
    set reps [dict get $a representatives]
    array unset members *
    for {set c 0} {$c < $K} {incr c} { set members($c) {} }
    set noise 0
    set i 0
    foreach l $labels {
        if {$l >= 0} { lappend members($l) $i } else { incr noise }
        incr i
    }
    set selection {}
}

proc ::VMDance::Results::_clear {} {
    variable A {}; variable K 0; variable N 0; variable labels {}; variable frames {}
    variable sizes {}; variable reps {}; variable members; variable noise 0; variable selection {}
    variable memo; variable last_ok {}
    array unset members *
    array unset memo *
}

proc ::VMDance::Results::run_list {} {
    variable runs
    lmap r $runs {lrange $r 0 1}
}
proc ::VMDance::Results::run_data {} {
    variable runs
    lmap r $runs {list [lindex $r 0] [lindex $r 1] [unpack [lindex $r 2]]}
}
proc ::VMDance::Results::_run_index {id} {
    variable runs
    set i [lsearch -index 0 -exact $runs $id]
    if {$i < 0} { error "no run \"$id\" (runs: [join [lmap r $runs {lindex $r 0}] {, }])" }
    return $i
}
proc ::VMDance::Results::run_switch {id} {
    variable runs; variable current
    set i [_run_index $id]
    set a [unpack [lindex $runs $i 2]]
    _install $a
    set current $id
    _notify analysis
}
proc ::VMDance::Results::run_label {id text} {
    variable runs
    set i [_run_index $id]
    set text [string trim $text]
    if {$text eq ""} { error "a run's name cannot be empty" }
    lset runs $i 1 $text
    _notify runs
}
# Delete a run; the current one: the newest left becomes current (none
# left: no clustering).
proc ::VMDance::Results::run_delete {id} {
    variable runs; variable current; variable trusted
    set i [_run_index $id]
    set runs [lreplace $runs $i $i]
    dict unset trusted $id
    if {$id eq $current} {
        if {[llength $runs]} {
            set r [lindex $runs end]
            _install [unpack [lindex $r 2]]
            set current [lindex $r 0]
        } else {
            _clear
            set current ""
        }
        _notify analysis
    } else {
        _notify runs
    }
}
# Forget every run, scan and pick.
proc ::VMDance::Results::clear_all {} {
    variable runs {}; variable current ""; variable elbow {}; variable sweep {}; variable picks {}
    variable trusted {}; variable picks_trusted ""; variable last_picks_ok {}
    _clear
    _notify analysis
    _notify elbow
    _notify sweep
    _notify picks
}
# Replace every run (sessions): {id label analysis} each, checked; trust
# the runs whose molecule was found to have their frames, as it was then
# (id -> its state, _now).
proc ::VMDance::Results::set_runs {list cur {trust {}}} {
    variable runs; variable current; variable next_id; variable trusted
    foreach r $list { check [lindex $r 2] }
    set trusted $trust
    set runs {}
    set max 0
    foreach r $list {
        lassign $r id label a
        lappend runs [list $id $label [pack $a]]
        set max [expr {max($max, $id)}]
    }
    set next_id [expr {$max + 1}]
    set i [lsearch -index 0 -exact $runs $cur]
    if {$i < 0} { set i [expr {[llength $runs] - 1}] }
    _install [unpack [lindex $runs $i 2]]
    set current [lindex $runs $i 0]
    _notify analysis
}

# Keep what was asked of a clustering with its run (PRIME, the
# similarity): run, the one it was asked of (the current one by default:
# another may have become current while the job ran).
proc ::VMDance::Results::attach {key value {run ""}} {
    variable A; variable runs; variable current
    if {$run eq ""} { set run $current }
    if {$run eq ""} { error "no clustering" }
    set i [_run_index $run]
    set a [expr {$run eq $current ? $A : [unpack [lindex $runs $i 2]]}]
    dict set a extras $key $value
    check $a
    lset runs $i 2 [pack $a]
    if {$run eq $current} {
        set A $a
        _notify extras
    }
}
proc ::VMDance::Results::extra {key} {
    variable A
    if {[has_data] && [dict exists $A extras $key]} { return [dict get $A extras $key] }
    return {}
}

proc ::VMDance::Results::set_elbow {e} { variable elbow $e; _notify elbow }
proc ::VMDance::Results::set_sweep {s} { variable sweep $s; _notify sweep }
# The frames picked: a job's (made: on their molecule as its record has
# it), or a session's (trust: its state, _now, when their molecule was
# found to have their frames, else "").
proc ::VMDance::Results::set_picks {p {trust made}} {
    variable picks $p; variable picks_trusted; variable last_picks_ok {}
    if {$trust eq "made"} {
        set trust ""
        if {[dict size $p]} { set trust [_trust [dict get $p input mol] $p] }
    }
    set picks_trusted $trust
    _notify picks
}

#---------------------------------------------------------------------------
# Reading the current clustering
#---------------------------------------------------------------------------

proc ::VMDance::Results::request {} { variable A; dict get $A request }

# Whether the clustered molecule (loaded) has the frames that were
# clustered, at their numbers: as it was when a job read them, or when a
# session's run was found to have them (the same number of frames from the
# same files, none deleted since: _now; coordinates moved in place since,
# an alignment, leave the frames what they were); else the frames hold the
# coordinates clustered (same_frames: frames deleted before them, or a
# trajectory loaded otherwise, move them; frames added after do not). The
# last answer is kept for the molecule as it is (_now: frames deleted, then
# others added, change its files; frames deleted back to a count seen while
# a trajectory loaded, its deletions).
proc ::VMDance::Results::frames_ok {} {
    variable A; variable current; variable trusted; variable last_ok
    set m [dict get $A request mol]
    if {![::VMDance::Mol::exists $m]} { return 0 }
    set state [_now $m]
    if {[::VMDance::_get $trusted $current ""] eq $state} { return 1 }
    if {[lindex $last_ok 0] ne $state} { set last_ok [list $state {*}[_frames_there $m $A $state]] }
    lindex $last_ok 1
}
# The same of the picked frames, on their own molecule (the frames up to the
# last picked one: _span).
proc ::VMDance::Results::picks_ok {} {
    variable picks; variable picks_trusted; variable last_picks_ok
    if {![dict size $picks]} { return 0 }
    set m [dict get $picks input mol]
    if {![::VMDance::Mol::exists $m]} { return 0 }
    set state [_now $m]
    if {$picks_trusted eq $state} { return 1 }
    if {[lindex $last_picks_ok 0] ne $state} { set last_picks_ok [list $state {*}[_frames_there $m $picks $state]] }
    lindex $last_picks_ok 1
}
# The frames before them the molecule has that it did not have then, when
# its frames are those moved by that count, as frames_ok (picks_ok) found
# it (0 otherwise): deleting them gives the frames back (Viz::why).
proc ::VMDance::Results::frames_extra {} {
    variable last_ok
    if {[frames_ok] || [llength $last_ok] < 3} { return 0 }
    lindex $last_ok 2
}
proc ::VMDance::Results::picks_extra {} {
    variable last_picks_ok
    if {[picks_ok] || [llength $last_picks_ok] < 3} { return 0 }
    lindex $last_picks_ok 2
}
# Whether m has the frames of d as it is (state): {answer extra} (extra:
# extra_before, when it has not). (One with no digest, made by hand: as
# many frames from the same files, nothing else can tell; the picks of a
# session made before they kept one: not at all, another replica has the
# same names.)
proc ::VMDance::Results::_frames_there {m d state} {
    set v [same_frames $m $d]
    if {$v eq "1"} { return {1 0} }
    if {$v eq "0"} { return [list 0 [extra_before $m $d]] }
    if {[dict exists $d rows]} { return {0 0} }
    list [expr {[lrange $state 1 2] eq [lrange [_as_made $m [dict get $d molecule]] 1 2]}] 0
}
# How many frames molecule m has before the frames of d that it did not
# have when d was made, when its frames are those moved by that count (a
# PDB's own frame, deleted when d was made, read again); 0 otherwise.
proc ::VMDance::Results::extra_before {m d {memo ""}} {
    set rec [dict get $d molecule]
    if {![dict exists $rec numframes]} { return 0 }
    set extra [expr {[molinfo $m get numframes] - [dict get $rec numframes]}]
    if {$extra > 0 && [same_frames $m $d $extra $memo] eq "1"} { return $extra }
    return 0
}
# The frames of d that matter: a result's or a scan's all, the picks' up to
# the last picked one (frames deleted after it leave the picks).
proc ::VMDance::Results::_span {d} {
    set n [llength [dict get $d frames]]
    if {[dict exists $d rows] && [llength [dict get $d rows]]} { set n [expr {[::tcl::mathfunc::max {*}[dict get $d rows]] + 1}] }
    return $n
}
# Whether molecule m holds at the frames of d (a result, a scan or the
# picks), each moved by shift, the coordinates they were made from: the
# digest of their fingerprints (Coords::same_prints), or else every frame's
# radius of gyration as it was (_same_shape: the frames moved in place
# rigidly since, an alignment, then frames added or deleted after them);
# "" when d has no digest. Of the picks, the frames up to the last picked
# one (_span): their shapes, when frames after it are gone (the digest is
# of all). (memo: Coords::prints_of's.)
proc ::VMDance::Results::same_frames {m d {shift 0} {memo ""}} {
    if {[dict exists $d request]} { set q [dict get $d request] } else { set q [dict get $d input] }
    set frames [dict get $d frames]
    if {$shift} { set frames [lmap f $frames {expr {$f + $shift}}] }
    set n [_span $d]
    set nf [molinfo $m get numframes]
    if {[lindex $frames [expr {$n - 1}]] >= $nf} { return 0 }
    set digest [::VMDance::_get $d digest ""]
    if {$digest eq ""} { return "" }
    set all [expr {[lindex $frames end] < $nf}]
    if {!$all} { set frames [lrange $frames 0 [expr {$n - 1}]] }
    # (the atoms that were read, not those the texts select now)
    if {[catch {::VMDance::Coords::prints_of $m [::VMDance::_get $q atoms [dict get $q sel]] \
            [::VMDance::_get $q fitatoms [dict get $q fit]] $frames $memo} fps]} { return 0 }
    expr {($all && [::VMDance::Coords::same_prints $fps $digest]) ||
          [_same_shape [lrange $fps 0 [expr {$n - 1}]] [lrange [::VMDance::_get $d shape {}] 0 [expr {$n - 1}]]]}
}
# Whether every frame's radius of gyration (in its fingerprint, fps) is the
# one kept (shape) within a float's rounding, and the kept ones tell frames
# apart (nine in ten next ones differ by more): a rigid body's frames all
# look alike.
proc ::VMDance::Results::_same_shape {fps shape} {
    set n [llength $shape]
    if {$n < 2 || $n != [llength $fps]} { return 0 }
    set tol 1e-5
    set apart 0
    set prev ""
    foreach fp $fps g $shape {
        set r [lindex $fp 3]
        if {![string is double -strict $r] || [regexp -nocase {nan|inf} $r] || abs($r - $g) > $tol * abs($g)} { return 0 }
        if {$prev ne "" && abs($g - $prev) > $tol * abs($g)} { incr apart }
        set prev $g
    }
    expr {$apart >= 0.9 * ($n - 1)}
}
proc ::VMDance::Results::get {key} { variable A; dict get $A $key }
# What a result says of itself (backend seconds created): "" when a file
# made by hand leaves it out.
proc ::VMDance::Results::meta {key} { variable A; ::VMDance::_get $A $key "" }
proc ::VMDance::Results::measure {key} { variable A; dict get $A measures $key }
proc ::VMDance::Results::nclusters {} { variable K; return $K }
proc ::VMDance::Results::nframes {} { variable N; return $N }
proc ::VMDance::Results::frames {} { variable frames; return $frames }
proc ::VMDance::Results::labels {} { variable labels; return $labels }
proc ::VMDance::Results::sizes {} { variable sizes; return $sizes }
proc ::VMDance::Results::noise {} { variable noise; return $noise }
proc ::VMDance::Results::size {c} { variable sizes; lindex $sizes $c }
proc ::VMDance::Results::members {c} { variable members; set members($c) }
proc ::VMDance::Results::member_frames {c} {
    variable members; variable frames
    lmap i $members($c) {lindex $frames $i}
}
proc ::VMDance::Results::fraction {c} {
    variable sizes; variable N
    expr {$N ? double([lindex $sizes $c]) / $N : 0.0}
}
# The representative of cluster c: its row, and its VMD frame (-1: none).
proc ::VMDance::Results::rep {c} { variable reps; lindex $reps $c }
proc ::VMDance::Results::rep_frame {c} {
    variable reps; variable frames
    set p [lindex $reps $c]
    expr {$p >= 0 ? [lindex $frames $p] : -1}
}
proc ::VMDance::Results::algorithm {} { dict get [request] algorithm }

# The row of the analysed frame at or before VMD frame f (-1: before the
# first).
proc ::VMDance::Results::frame_index {f} {
    variable frames; variable N
    if {!$N || $f < [lindex $frames 0]} { return -1 }
    set lo 0; set hi [expr {$N - 1}]
    while {$lo < $hi} {
        set mid [expr {($lo + $hi + 1) / 2}]
        if {[lindex $frames $mid] <= $f} { set lo $mid } else { set hi [expr {$mid - 1}] }
    }
    return $lo
}
# The row of VMD frame f when it was clustered (-1: it was not).
proc ::VMDance::Results::row_of {f} {
    variable frames
    set i [frame_index $f]
    expr {$i >= 0 && [lindex $frames $i] == $f ? $i : -1}
}
# The cluster of VMD frame f: that of the analysed frame at or before it
# ("" before the first or after the last analysed frame).
proc ::VMDance::Results::cluster_at {f} {
    variable labels; variable frames
    set i [frame_index $f]
    if {$i < 0 || $f > [lindex $frames end]} { return "" }
    lindex $labels $i
}

# The table: {cluster frames percent msd spread representative} each
# (spread: the mean RMSD² of its frames from the representative).
proc ::VMDance::Results::table {} {
    memo table {
        variable K
        set fm [measure frame_msd]
        set msd [get msd]
        set out {}
        for {set c 0} {$c < $K} {incr c} {
            set ms [lmap i [members $c] {lindex $fm $i}]
            set ms [lmap v $ms {expr {$v eq "" ? [continue] : $v}}]
            set spread [expr {[llength $ms] ? [::tcl::mathop::+ {*}$ms] / double([llength $ms]) : ""}]
            lappend out [list $c [size $c] [format %.1f [expr {100.0 * [fraction $c]}]] \
                [lindex $msd $c] $spread [rep_frame $c]]
        }
        set out
    }
}

# The frames of cluster c nearest its representative, at most n: VMD
# frames, nearest first.
proc ::VMDance::Results::top {c n} {
    variable frames
    set fm [measure frame_msd]
    set l [lmap i [members $c] {list $i [lindex $fm $i]}]
    set l [lsort -real -index 1 [lmap p $l {expr {[lindex $p 1] eq "" ? [continue] : $p}}]]
    lmap p [lrange $l 0 [expr {$n - 1}]] {lindex $frames [lindex $p 0]}
}

# The runs of consecutive analysed frames in one cluster ({label first
# length}), and the transitions between clusters (counts, k × k).
proc ::VMDance::Results::residence {} {
    memo residence { variable labels; ::VMDance::Measure::runs $labels }
}
proc ::VMDance::Results::transitions {{lag 1}} {
    memo_last transitions $lag {
        variable labels; variable K
        ::VMDance::Measure::transitions $labels $K $lag
    }
}

# The dendrogram: {how rows leaves base}. how helm: HELM's merges of its
# starting clusters (the distance being the merge's rank; the leaves: the
# starting clusters not trimmed; merge j is node base + j, as scipy
# numbers them: Measure::helm_tree). how linkage: the average linkage of
# the clusters' mean structures (the distance their RMSD²; the leaves: the
# clusters with frames). rows {left right distance count}.
proc ::VMDance::Results::tree_kind {} {
    expr {[llength [get zmatrix]] || ([algorithm] eq "helm" && [llength [get initial]]) ? "helm" : "linkage"}
}
proc ::VMDance::Results::tree {} {
    memo tree {
        variable K
        if {[tree_kind] eq "helm"} {
            list helm {*}[::VMDance::Measure::helm_tree [get zmatrix] [get initial] [labels] $K]
        } else {
            set why [too_many tree]
            if {$why ne ""} { error $why }
            set M [measure centroid_msd]
            set leaves {}
            for {set c 0} {$c < $K} {incr c} { if {[lindex $M $c $c] ne ""} { lappend leaves $c } }
            list linkage [::VMDance::Measure::linkage $M] $leaves $K
        }
    }
}

# Why the distances between the clusters, or the tree of their mean
# structures (what: distances, tree), are not there ("" when they are):
# they are made for Measure::maxk clusters or fewer (a run made with a
# larger maxk can hold the distances of more, a session's made before not:
# Session::read_file; HELM's tree is its merges).
proc ::VMDance::Results::too_many {what} {
    variable K
    set maxk $::VMDance::Measure::maxk
    if {$K <= $maxk} { return "" }
    switch -- $what {
        distances {
            if {[llength [measure centroid_msd]]} { return "" }
            set name "the distances between the clusters are measured"
        }
        tree {
            if {[tree_kind] eq "helm"} { return "" }
            set name "the tree of the clusters' mean structures is made"
        }
    }
    return "$name for $maxk clusters or fewer, and this clustering has $K: cluster into fewer (a smaller k, a larger eQUAL radius)"
}

#---------------------------------------------------------------------------
# The selection
#---------------------------------------------------------------------------

proc ::VMDance::Results::selected {} { variable selection; return $selection }

# Set the selected clusters: mode set, add or toggle.
proc ::VMDance::Results::set_selection {cs {mode set}} {
    variable selection; variable K
    foreach c $cs {
        if {![string is integer -strict $c] || $c < 0 || $c >= $K} { error "no cluster \"$c\" (clusters: 0 to [expr {$K - 1}])" }
    }
    switch -- $mode {
        set { set new $cs }
        add { set new [concat $selection $cs] }
        toggle {
            set new $selection
            foreach c $cs {
                set i [lsearch -exact $new $c]
                if {$i >= 0} { set new [lreplace $new $i $i] } else { lappend new $c }
            }
        }
        default { error "mode must be set, add or toggle" }
    }
    set new [lsort -integer -unique $new]
    if {$new ne $selection} {
        set selection $new
        _notify selection
    }
    return $selection
}
