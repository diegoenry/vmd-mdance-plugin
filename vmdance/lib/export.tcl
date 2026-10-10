#
# VMDance - result files (no Tk dependency)
#
# Tables are CSV (a # header says what was clustered, how and when);
# structures are PDB, or DCD with a PDB of the same atoms beside it.
# Frames are VMD's frame numbers. Every file is written under a temporary
# name beside it that only this call made, and renamed when complete (a
# bundle's files once every one is): a failure leaves no half file, and
# changes none.
#

namespace eval ::VMDance::Export {
    # the files written together ({temporary file} ...), renamed once every
    # one is written (_batch)
    variable batch 0
    variable staged {}
    # item -> {file name (after the prefix) needs what}
    variable catalog {
        summary         {_summary.txt clustering "What was clustered, how, and the clusters"}
        clusters        {_clusters.csv clustering "The table of clusters: frames, share, MSD, representative"}
        labels          {_labels.csv clustering "Every clustered frame and its cluster"}
        top             {_top_frames.csv clustering "Each cluster's frames nearest its representative, ranked"}
        timeline        {_timeline.csv clustering "The cluster of every clustered frame, in order"}
        transitions     {_transitions.csv clustering "The transition probabilities between clusters"}
        residence       {_residence.csv clustering "How long the trajectory stays in each cluster"}
        silhouette      {_silhouette.csv clustering "Every frame's silhouette"}
        distances       {_distances.csv clustering "Between the clusters: mean structures (RMSD²) and representatives (RMSD)"}
        tree            {_tree.csv clustering "The merges of the dendrogram"}
        representatives {_representatives.pdb molecule "The representatives' structures, one per cluster"}
        trajectories    {_cluster.pdb molecule "Each cluster's frames as a trajectory of its own"}
        prime           {_prime.csv prime "PRIME's predictions and the medoid baselines"}
        similarity      {_similarity.csv similarity "Each cluster's extended similarity and least similar frame"}
        elbow           {_elbow.csv elbow "The elbow scan's scores at every k"}
        sweep           {_sweep.csv sweep "Every configuration of the sweep and its scores"}
        picks           {_picks.csv picks "The frames picked without clustering"}
    }
    variable default_items {summary clusters labels top timeline transitions residence silhouette distances tree}
}

proc ::VMDance::Export::items {} { variable catalog; dict keys $catalog }

#---------------------------------------------------------------------------
# Writing a file (sessions, preferences and figures too)
#---------------------------------------------------------------------------

# The file a name writes, checked before anything is written: the name made
# a path ("|cmd" would be a pipe to open); a link of the user's followed to
# the file it points to (a dotfile kept elsewhere stays linked), one of
# another user's not (it is replaced, what it points to left alone: a link
# put in a shared folder sends nothing elsewhere); not a folder, nor a link
# to one (the file would be moved into it); not a file the user cannot
# write (a rename would replace it all the same).
proc ::VMDance::Export::target {file} {
    set file [file normalize $file]
    set name "\"$file\""
    for {set i 0} {$i < 20 && ![catch {file lstat $file st}] && $st(type) eq "link" && [_own $st(uid)]} {incr i} {
        if {[catch {file readlink $file} to]} break
        set file [file normalize [file join [file dirname $file] $to]]
    }
    if {$name ne "\"$file\""} { append name " (a link to \"$file\")" }
    if {[file isdirectory $file]} { error "$name is a folder, not a file" }
    if {![catch {file lstat $file st}] && $st(type) ne "link" && ![file writable $file]} { error "$name is read-only" }
    set d [file dirname $file]
    if {![file isdirectory $d]} { error "the folder \"$d\" does not exist" }
    return $file
}
# Whether a file's owner (its lstat uid) is this process's user.
proc ::VMDance::Export::_own {uid} {
    if {$::tcl_platform(platform) eq "windows"} { return 1 }
    set me [::VMDance::Backend::_uid]
    expr {$me ne "" && $uid eq $me}
}

# A temporary beside file, made by this call ({name channel}): a name that
# exists, or a link put there, is never opened (EXCL), and the name is not
# guessed. In place of a file it is the user's alone until it is renamed
# (_commit gives it the file's permissions); a new file gets the umask's.
proc ::VMDance::Export::_open {file} {
    set mode [expr {![catch {file lstat $file st}] && $st(type) eq "file" ? 0600 : 0666}]
    for {set k 0} {$k < 20} {incr k} {
        set tmp [format "%s.tmp%d-%08x" $file [pid] [expr {int(rand() * 4294967296.0)}]]
        if {![catch {open $tmp {WRONLY CREAT EXCL} $mode} fh eo]} { return [list $tmp $fh] }
        if {[lindex [dict get $eo -errorcode] 1] ne "EEXIST"} { _failed $file $fh $eo }
    }
    error "\"$file\" could not be written: no name beside it was free for its temporary"
}
# What the system said of a failed open, write or close ("no space left on
# device"), else the message.
proc ::VMDance::Export::_os {msg opts} {
    set c [::VMDance::_get $opts -errorcode ""]
    if {[lindex $c 0] eq "POSIX" && [lindex $c 2] ne ""} { return [lindex $c 2] }
    return $msg
}
# An error while file is written, said of the file (a full disk: not Tcl's
# name of the channel, nor the temporary's); any other error as it is.
proc ::VMDance::Export::_failed {file msg opts} {
    if {[lindex [::VMDance::_get $opts -errorcode ""] 0] eq "POSIX"} {
        return -code error "\"$file\" could not be written: [_os $msg $opts]"
    }
    return -options $opts $msg
}
# The last data of a temporary written, and its channel closed (a write
# that fails can leave close silent: both are checked).
proc ::VMDance::Export::_put {fh file data} {
    try {
        puts -nonewline $fh $data
        close $fh
    } on error {msg opts} {
        catch {close $fh}
        _failed $file $msg $opts
    }
}
# A temporary given the permissions of the file it replaces, and its group
# when the user can give it. (Where the system allows it: a share mounted
# without them, gvfs's, refuses chmod; the temporary keeps its own.)
proc ::VMDance::Export::_keep {tmp file} {
    if {$::tcl_platform(platform) eq "unix" && ![catch {file lstat $file st}] && $st(type) eq "file"} {
        catch {file attributes $tmp -permissions [file attributes $file -permissions]}
        catch {file attributes $tmp -group [file attributes $file -group]}
    }
}
# A temporary renamed onto its file. A link there (another user's: target
# follows the user's own) is deleted first, and the name taken only while
# it is free: Tcl's rename -force makes writable (u+w) what a link points
# to before it replaces the link.
proc ::VMDance::Export::_commit {tmp file} {
    if {![catch {file lstat $file st}] && $st(type) eq "link"} {
        file delete $file
        file rename $tmp $file
    } else {
        file rename -force $tmp $file
    }
}
# A temporary written: renamed now, or, within a batch, with the others.
proc ::VMDance::Export::_done {tmp file} {
    variable batch; variable staged
    if {$batch} { lappend staged $tmp $file; return }
    _keep $tmp $file
    _commit $tmp $file
}
# Run script so that the files it writes are renamed only once all are
# written: a failure leaves every one as it was. (Within a batch, the
# outer one renames them.)
proc ::VMDance::Export::_batch {script} {
    variable batch; variable staged
    if {$batch} { return [uplevel 1 $script] }
    set batch 1
    set staged {}
    try {
        set r [uplevel 1 $script]
        # (all given their permissions, then all renamed: only a rename the
        # system refuses can leave some in place, and its error names them)
        foreach {tmp f} $staged { _keep $tmp $f }
        set done {}
        foreach {tmp f} $staged {
            if {[catch {_commit $tmp $f} msg opts]} {
                error "\"$f\" could not be written: [_os $msg $opts][expr {[llength $done] ? " (written before it: [join $done {, }])" : ""}]"
            }
            lappend done [file tail $f]
        }
        return $r
    } finally {
        foreach {tmp f} $staged { catch {file delete $tmp} }
        set batch 0
        set staged {}
    }
}

# Write text (UTF-8), or bytes, to file; returns the file written.
proc ::VMDance::Export::_write {file text {binary 0}} {
    set file [target $file]
    lassign [_open $file] tmp fh
    try {
        if {$binary} { fconfigure $fh -translation binary } else { fconfigure $fh -encoding utf-8 }
        _put $fh $file $text
        _done $tmp $file
    } on error {msg opts} {
        catch {close $fh}
        file delete $tmp
        _failed $file $msg $opts
    }
    return $file
}
# A file VMD, Tk or Ghostscript wrote copied in place of file, as _write
# writes one. (They open a name, and would follow a link put there: they
# write into the private folder.)
proc ::VMDance::Export::_copy {src file} {
    set file [target $file]
    lassign [_open $file] tmp fh
    try {
        fconfigure $fh -translation binary
        set in [open $src rb]
        try { fcopy $in $fh } finally { close $in }
        _put $fh $file ""
        _done $tmp $file
    } on error {msg opts} {
        catch {close $fh}
        file delete $tmp
        _failed $file $msg $opts
    }
    return $file
}

#---------------------------------------------------------------------------
# The # header
#---------------------------------------------------------------------------

# A CSV field (quoted when it holds a comma, a quote or a line break).
proc ::VMDance::Export::_f {v} {
    if {[regexp {[,"\r\n]} $v]} { return "\"[string map {\" \"\"} $v]\"" }
    return $v
}
# A # line kept one line: a user's text in it (a selection written over
# several lines, a name with a line break) joined with spaces, so that no
# reader takes the rest for data, nor for another "# key:" line.
proc ::VMDance::Export::_comment {l} { regsub -all {\s*[\r\n]\s*} $l { } }
proc ::VMDance::Export::_row {args} { join [lmap v $args {_f $v}] , }
proc ::VMDance::Export::_num {v {fmt %.6g}} { expr {$v eq "" ? "" : [format $fmt $v]} }

# The # header of a table: what was clustered, how, when.
proc ::VMDance::Export::header {{what ""}} {
    set out {}
    lappend out "# VMDance $::VMDance::version[expr {$what eq "" ? "" : ": $what"}]"
    if {[::VMDance::Results::has_data]} {
        set a $::VMDance::Results::A
        set q [dict get $a request]
        set mol [dict get $a molecule]
        # (the name as it is: expr's ?: would write a molecule 1e10 as
        # 10000000000.0, and fail on NaN)
        lappend out "# molecule: [::VMDance::_get $mol name ?] ([join [lmap f [::VMDance::_get $mol files {}] {file tail $f}] {, }])"
        lappend out "# selection: [dict get $q sel] ([dict get $a natoms] atoms)[expr {[dict get $q fit] ne "" ? ", fitted on: [dict get $q fit]" : ""}]"
        set fr [dict get $a frames]
        lappend out "# frames: [llength $fr] ([lindex $fr 0] to [lindex $fr end], step [dict get $q step])"
        set p {}
        dict for {k v} [dict get $q params] { lappend p "$k $v" }
        set how "metric [dict get $q metric]; [join $p {, }]"
        # (an import whose file does not say: not the defaults it was given)
        if {[llength [::VMDance::_get $a unrecorded {}]]} { set how "metric and parameters not recorded (a session of the MDANCE plugin)" }
        lappend out "# algorithm: [::VMDance::Algo::label [dict get $q algorithm]][expr {[dict get $q k] ne "" ? ", k [dict get $q k]" : ""}], $how"
        lappend out "# clusters: [dict get $a nclusters]; calinski_harabasz [dict get $a ch]; davies_bouldin [dict get $a db]; noise frames [::VMDance::Results::noise]"
        lappend out "# backend: [join [::VMDance::Results::meta backend] { }]; clustered [::VMDance::Results::meta created]"
    }
    join [lmap l $out {_comment $l}] \n
}

#---------------------------------------------------------------------------
# Tables
#---------------------------------------------------------------------------

proc ::VMDance::Export::_need_clustering {} {
    if {![::VMDance::Results::has_data]} { error "no clustering" }
}

proc ::VMDance::Export::table_clusters {} {
    _need_clustering
    set sil [::VMDance::Results::measure silhouette]
    set out [list [header "the clusters (msd: MDANCE's MSD within, Å²; msd_to_representative: the mean RMSD² of its frames from its representative, Å²)"] [_row cluster frames percent msd msd_to_representative representative_frame mean_silhouette]]
    foreach r [::VMDance::Results::table] {
        lassign $r c n pct msd spread rep
        set s [lmap i [::VMDance::Results::members $c] {lindex $sil $i}]
        set s [lmap v $s {expr {$v eq "" ? [continue] : $v}}]
        set ms [expr {[llength $s] ? [::tcl::mathop::+ {*}$s] / double([llength $s]) : ""}]
        lappend out [_row $c $n $pct [_num $msd] [_num $spread] $rep [_num $ms %.4f]]
    }
    join $out \n
}

proc ::VMDance::Export::table_labels {} {
    _need_clustering
    set out [list [header "every clustered frame and its cluster (-1: noise)"] [_row frame cluster]]
    foreach f [::VMDance::Results::frames] l [::VMDance::Results::labels] { lappend out "$f,$l" }
    join $out \n
}

proc ::VMDance::Export::table_top {{n 10}} {
    _need_clustering
    # (the window's number as typed: 010 would be 8 frames, said "010")
    if {![::VMDance::whole $n] || $n < 1} { error "the nearest frames must be a whole number, 1 or more (got \"$n\")" }
    set out [list [header "the $n frames of each cluster nearest its representative (rank 0: the representative; msd_to_representative: RMSD², Å²)"] [_row frame cluster rank msd_to_representative]]
    set fm [::VMDance::Results::measure frame_msd]
    for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
        set k 0
        foreach f [::VMDance::Results::top $c $n] {
            lappend out [_row $f $c $k [_num [lindex $fm [::VMDance::Results::row_of $f]]]]
            incr k
        }
    }
    join $out \n
}

proc ::VMDance::Export::table_timeline {} {
    _need_clustering
    set fm [::VMDance::Results::measure frame_msd]
    set out [list [header "the cluster of every clustered frame (msd_to_representative: RMSD², Å²)"] [_row frame cluster msd_to_representative]]
    foreach f [::VMDance::Results::frames] l [::VMDance::Results::labels] m $fm { lappend out [_row $f $l [_num $m]] }
    join $out \n
}

# Rows sum to 1 over the clusters and noise: the transitions into noise
# are the column -1 (only when there is noise).
proc ::VMDance::Export::table_transitions {{lag 1}} {
    _need_clustering
    # (the window's lag as typed: 010 would be lag 8, said "010 later")
    if {![::VMDance::whole $lag] || $lag < 1} { error "the lag must be a whole number of clustered frames, 1 or more (got \"$lag\")" }
    set k [::VMDance::Results::nclusters]
    set T [::VMDance::Results::transitions $lag]
    set labels [::VMDance::Results::labels]
    set tonoise [lrepeat $k 0]
    for {set i 0} {$i + $lag < [llength $labels]} {incr i} {
        set a [lindex $labels $i]; set b [lindex $labels [expr {$i + $lag}]]
        if {$a >= 0 && $b < 0} { lset tonoise $a [expr {[lindex $tonoise $a] + 1}] }
    }
    set noise [expr {[::VMDance::Results::noise] > 0}]
    set out [list [header "transitions between clusters, from each clustered frame to the one $lag later"] [_row from_cluster to_cluster count probability]]
    for {set a 0} {$a < $k} {incr a} {
        set row [lindex $T $a]
        set tot [expr {[::tcl::mathop::+ 0 {*}$row] + [lindex $tonoise $a]}]
        for {set b 0} {$b < $k} {incr b} {
            set n [lindex $row $b]
            lappend out [_row $a $b $n [expr {$tot ? [format %.6f [expr {double($n) / $tot}]] : ""}]]
        }
        if {$noise} {
            set n [lindex $tonoise $a]
            lappend out [_row $a -1 $n [expr {$tot ? [format %.6f [expr {double($n) / $tot}]] : ""}]]
        }
    }
    join $out \n
}

# Residence: the runs of consecutive clustered frames in one cluster, in
# clustered frames (× step VMD frames).
proc ::VMDance::Export::residence_stats {} {
    ::VMDance::Results::memo residence_stats {
        set k [::VMDance::Results::nclusters]
        for {set c 0} {$c < $k} {incr c} { set L($c) {} }
        foreach r [::VMDance::Results::residence] {
            lassign $r l s n
            if {$l >= 0} { lappend L($l) $n }
        }
        set out {}
        for {set c 0} {$c < $k} {incr c} {
            set l $L($c)
            if {[llength $l]} {
                lappend out [list $c [llength $l] [expr {double([::tcl::mathop::+ {*}$l]) / [llength $l]}] \
                    [::tcl::mathfunc::min {*}$l] [::tcl::mathfunc::max {*}$l]]
            } else {
                lappend out [list $c 0 0 0 0]
            }
        }
        set out
    }
}
proc ::VMDance::Export::table_residence {} {
    _need_clustering
    set step [dict get [::VMDance::Results::request] step]
    set out [list [header "residence: runs of consecutive clustered frames in one cluster (1 clustered frame = $step VMD frame[expr {$step == 1 ? "" : "s"}])"] \
        [_row cluster visits mean_frames min_frames max_frames]]
    foreach r [residence_stats] {
        lassign $r c v mean mn mx
        lappend out [_row $c $v [format %.2f $mean] $mn $mx]
    }
    join $out \n
}

proc ::VMDance::Export::table_silhouette {} {
    _need_clustering
    set out [list [header "every frame's silhouette from the clusters' mean structures"] [_row frame cluster silhouette]]
    foreach f [::VMDance::Results::frames] l [::VMDance::Results::labels] s [::VMDance::Results::measure silhouette] {
        lappend out [_row $f $l [_num $s %.6f]]
    }
    join $out \n
}

proc ::VMDance::Export::table_distances {} {
    _need_clustering
    set why [::VMDance::Results::too_many distances]
    if {$why ne ""} { error $why }
    set C [::VMDance::Results::measure centroid_msd]
    set R [::VMDance::Results::measure rep_msd]
    set k [::VMDance::Results::nclusters]
    set out [list [header "between the clusters: their mean structures (RMSD², Å², no fit: twice MDANCE's MSD of the pair) and representatives (RMSD, Å)"] \
        [_row cluster_i cluster_j centroid_msd representative_rmsd]]
    for {set i 0} {$i < $k} {incr i} {
        for {set j 0} {$j < $k} {incr j} {
            set r [lindex $R $i $j]
            lappend out [_row $i $j [_num [lindex $C $i $j]] [expr {$r eq "" ? "" : [format %.6g [expr {sqrt($r)}]]}]]
        }
    }
    join $out \n
}

proc ::VMDance::Export::table_tree {} {
    _need_clustering
    lassign [::VMDance::Results::tree] how rows
    set what [expr {$how eq "helm" ? "HELM's merges of its starting clusters (distance: the merge's rank)" : "average linkage of the clusters' mean structures (distance: their RMSD², Å²)"}]
    # (not DIVINE's splits: CPP-MDANCE does not return them)
    if {$how ne "helm" && [::VMDance::Results::algorithm] eq "divine"} { append what ", not DIVINE's splits" }
    set out [list [header "the dendrogram: $what"] [_row left right distance count]]
    foreach r $rows { lappend out [_row {*}[lrange $r 0 1] [_num [lindex $r 2]] [lindex $r 3]] }
    join $out \n
}

proc ::VMDance::Export::table_prime {} {
    _need_clustering
    set p [::VMDance::Results::extra prime]
    if {![dict size $p]} { error "no PRIME prediction for this clustering (run PRIME first)" }
    set out [list [header "PRIME (metric [dict get $p params metric], trim [dict get $p params trim-frac], weighted [dict get $p params weighted])"] [_row method frame kind]]
    foreach {key label kind} $::VMDance::prime_rows {
        set i [dict get $p $key]
        lappend out [_row $label [expr {$i >= 0 ? [lindex [::VMDance::Results::frames] $i] : ""}] $kind]
    }
    join $out \n
}

proc ::VMDance::Export::table_similarity {} {
    _need_clustering
    set s [::VMDance::Results::extra similarity]
    if {![dict size $s]} { error "no similarity for this clustering (compute it first)" }
    set fr [::VMDance::Results::frames]
    set out [list [header "extended similarity (iSIM, [dict get $s params metric]) of all frames: [dict get $s isim]"] \
        [_row cluster isim representative_frame least_similar_frame]]
    set c 0
    foreach v [dict get $s cluster] o [dict get $s outliers] {
        lappend out [_row $c [_num $v] [::VMDance::Results::rep_frame $c] [expr {$o >= 0 ? [lindex $fr $o] : ""}]]
        incr c
    }
    join $out \n
}

# The # lines of a scan's or the picks' table (s): what was scanned (the
# molecule, the atoms, the frames, the parameters: {label params} each, ""
# the label of one set), with which backend and when (verb: scanned,
# picked), and when it was written.
proc ::VMDance::Export::scan_header {what q mol frames params s verb} {
    set out [list "# VMDance $::VMDance::version: $what"]
    set files [::VMDance::_get $mol files {}]
    lappend out "# molecule: [::VMDance::_get $mol name ?] ([join [lmap f $files {file tail $f}] {, }])"
    set fit [::VMDance::_get $q fit ""]
    lappend out "# selection: [dict get $q sel][expr {$fit ne "" ? ", fitted on: $fit" : ""}]"
    lappend out "# frames: [llength $frames] ([lindex $frames 0] to [lindex $frames end], step [::VMDance::_get $q step 1])"
    foreach {label p} $params {
        if {[catch {dict size $p} n] || !$n} continue
        set l {}
        dict for {k v} $p { lappend l "$k $v" }
        if {$label eq ""} { lappend out "# parameters: [join $l {, }]" } else { lappend out "# parameters of $label: [join $l {, }]" }
    }
    set b [made_with $s]
    if {[llength $b]} { lappend out "# backend: [join $b { }]; $verb [::VMDance::_get $s created ?]" }
    lappend out "# written [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]"
    join [lmap l $out {_comment $l}] \n
}
# The backend a scan or the picks were made with: theirs, else (a session
# saved before they kept it) their first clustering's; {} when unknown.
proc ::VMDance::Export::made_with {s} {
    if {[dict exists $s backend]} { return [dict get $s backend] }
    foreach r [::VMDance::_get $s records {}] {
        if {[dict get $r status] eq "ok" && [dict exists $r clustering backend]} { return [dict get $r clustering backend] }
    }
    return {}
}

proc ::VMDance::Export::table_elbow {} {
    set e $::VMDance::Results::elbow
    if {![dict size $e]} { error "no elbow scan" }
    set q [dict get $e request]
    set out [list [scan_header "elbow scan of [::VMDance::Algo::label [dict get $q algorithm]] (metric [dict get $q metric]), k [join [dict get $q ks] { }]" \
            $q [dict get $e molecule] [dict get $e frames] [list "" [dict get $q params]] $e scanned] \
        [_row k k_actual calinski_harabasz davies_bouldin cluster_sizes status]]
    foreach r [dict get $e records] {
        lappend out [_row [dict get $r k] [dict get $r nclusters] [dict get $r ch] [dict get $r db] [join [dict get $r sizes] " "] \
            [expr {[dict get $r status] eq "ok" ? "ok" : "failed: [dict get $r message]"}]]
    }
    join $out \n
}

proc ::VMDance::Export::table_sweep {} {
    set s $::VMDance::Results::sweep
    if {![dict size $s]} { error "no sweep" }
    set q [dict get $s request]
    set out [list [scan_header "sweep of [llength [dict get $s records]] configurations" $q [dict get $s molecule] [dict get $s frames] \
            [sweep_params $s] $s scanned] \
        [_row algorithm k k_actual metric seeding calinski_harabasz davies_bouldin status]]
    foreach r [dict get $s records] {
        lappend out [_row [dict get $r algorithm] [dict get $r k] [dict get $r nclusters] [dict get $r metric] [sweep_seeding $r] \
            [dict get $r ch] [dict get $r db] [expr {[dict get $r status] eq "ok" ? "ok" : "failed: [dict get $r message]"}]]
    }
    join $out \n
}
# The seeding of a sweep configuration (HELM's is that of its first
# clustering): none when it used none (Algo::seeding_of: HELM from a label
# file, DIVINE's pair anchors), whatever its parameters hold.
proc ::VMDance::Export::sweep_seeding {r} {
    set p [dict get $r params]
    if {[::VMDance::Algo::seeding_of [::VMDance::_get $r algorithm ""] $p] eq ""} { return none }
    foreach k {kinit initial-kinit} { if {[dict exists $p $k]} { return [dict get $p $k] } }
    return ""
}
# The parameters each algorithm of a sweep was given, but the seeding (a
# column): {label params} each, from its first configuration that ran
# (its parameters checked and complete), else its first one over the
# defaults (one refused keeps them as they were given).
proc ::VMDance::Export::sweep_params {s} {
    set first {}; set ran {}
    foreach r [dict get $s records] {
        set a [dict get $r algorithm]
        if {![dict exists $first $a]} { dict set first $a [dict get $r params] }
        if {![dict exists $ran $a] && [dict get $r status] eq "ok"} { dict set ran $a [dict get $r params] }
    }
    set out {}
    dict for {a p} $first {
        if {[dict exists $ran $a]} {
            set p [dict get $ran $a]
        } elseif {[::VMDance::Algo::exists $a] && ![catch {dict size $p}]} {
            set p [dict merge [::VMDance::Algo::defaults $a] $p]
        }
        if {[catch {dict remove $p kinit initial-kinit} q]} { set q {} }
        lappend out [::VMDance::Algo::label $a] $q
    }
    return $out
}

proc ::VMDance::Export::table_picks {} {
    set p $::VMDance::Results::picks
    if {![dict size $p]} { error "no frames picked" }
    set q [dict get $p input]
    set out [list [scan_header "frames picked ([dict get $p params method], param [dict get $p params param], metric [dict get $p params metric])" \
            $q [dict get $p molecule] [dict get $p frames] [list "" [dict get $p params]] $p picked] \
        [_row rank frame]]
    set k 0
    foreach f [dict get $p vmdframes] { lappend out [_row $k $f]; incr k }
    join $out \n
}

proc ::VMDance::Export::summary_text {} {
    _need_clustering
    set out [list [header]]
    lappend out "" "cluster  frames      %   representative   MSD"
    foreach r [::VMDance::Results::table] {
        lassign $r c n pct msd spread rep
        lappend out [format "%7d  %6d  %5s  %15s   %s" $c $n $pct $rep [_num $msd %.4g]]
    }
    if {[::VMDance::Results::noise]} { lappend out "  noise  [format %6d [::VMDance::Results::noise]]" }
    join $out \n
}

#---------------------------------------------------------------------------
# Structures
#---------------------------------------------------------------------------

# The files a structure export writes: the file, and for a dcd the pdb of
# its atoms beside it (the same name).
proc ::VMDance::Export::frame_files {file fmt} {
    if {$fmt eq "dcd"} { return [list $file [file rootname $file].pdb] }
    return [list $file]
}

# The atoms sel of molecule m at a frame (an error names -sel).
proc ::VMDance::Export::_sel {m sel frame} {
    if {[catch {::VMDance::Mol::sel $m $sel $frame} s]} { error "-sel: [::VMDance::Mol::_why $s]" }
    if {[$s num] == 0} { ::VMDance::Mol::free $s; error "-sel: \"$sel\" matches no atom of molecule $m" }
    return $s
}

# Write frames of molecule m (atoms sel, as at the first frame) to file as
# pdb or dcd: each frame as VMD has it, with its unit cell; a dcd gets a
# pdb of the same atoms beside it (its first frame), the two renamed
# together. The files are checked before either is written; no molecule
# is made (VMD's frame, top molecule and view are left alone).
proc ::VMDance::Export::write_frames {m sel frames file fmt} {
    if {![::VMDance::Mol::exists $m]} { error "the clustered molecule is not loaded" }
    if {![llength $frames]} { error "no frames to write" }
    if {$fmt ni {pdb dcd}} { error "the format must be pdb or dcd" }
    set nf [molinfo $m get numframes]
    foreach f $frames { if {$f >= $nf} { error "molecule $m has no frame $f (it has $nf)" } }
    set files [frame_files $file $fmt]
    foreach f $files { target $f }
    set s [_sel $m $sel [lindex $frames 0]]
    try {
        _batch {
            if {$fmt eq "dcd"} {
                _dcd $s $frames $file
                _pdb $s [lrange $frames 0 0] [lindex $files 1] 0
            } else {
                _pdb $s $frames $file 1
            }
        }
    } finally {
        ::VMDance::Mol::free $s
    }
    return $file
}

# A DCD file (CHARMM's, version 24, as VMD's dcdplugin writes it: each
# frame's unit cell first) of the atoms of selection s at frames: VMD's
# coordinates, float32 as VMD keeps them.
proc ::VMDance::Export::_dcd {s frames file} {
    set file [target $file]
    set n [$s num]
    set m [$s molid]
    set nf [llength $frames]
    # (the cosines of the cell's angles as dcdplugin makes them: 90° is 0)
    set k [expr {acos(0) / 90.0}]
    lassign [_open $file] tmp fh
    try {
        fconfigure $fh -translation binary
        # CORD, NSET ISTART NSAVC NSTEP, four zeros, NAMNF; DELTA; the unit
        # cell flag, eight zeros, the version
        puts -nonewline $fh [binary format ia4i9ri10i 84 CORD [list $nf 0 1 $nf 0 0 0 0 0] 1.0 {1 0 0 0 0 0 0 0 0 24} 84]
        puts -nonewline $fh [binary format iia80i 84 1 "Written by VMDance $::VMDance::version" 84]
        puts -nonewline $fh [binary format iii 4 $n 4]
        set rec [binary format i [expr {4 * $n}]]
        foreach f $frames {
            # (molinfo reads frame f without moving VMD's)
            lassign [molinfo $m get {a b c alpha beta gamma} frame $f] A B C al be ga
            set cell [list $A [expr {sin($k * (90.0 - $ga))}] $B [expr {sin($k * (90.0 - $be))}] [expr {sin($k * (90.0 - $al))}] $C]
            $s frame $f
            set x [binary format iq6i 48 $cell 48]
            foreach c {x y z} { append x "$rec[binary format r* [$s get $c]]$rec" }
            puts -nonewline $fh $x
        }
        _put $fh $file ""
        _done $tmp $file
    } on error {msg opts} {
        catch {close $fh}
        file delete $tmp
        _failed $file $msg $opts
    }
}

# A PDB file of the atoms of selection s at frames, one model each (ended
# by END), as VMD's own writer writes a frame: its numbers as VMD writes
# them (residues past 9999 in hex: read back, they would not be) and each
# frame's unit cell. Each frame is written into the private folder and
# checked whole (VMD's writer stops at a number its columns cannot hold,
# and does not check its last write), then copied in. dcd: whether to
# offer a DCD for a coordinate a PDB cannot hold (a PDB export's, at a
# frame past its first: a DCD export writes that one as a PDB too).
proc ::VMDance::Export::_pdb {s frames file dcd} {
    set file [target $file]
    set part [::VMDance::Backend::tmpfile .pdb]
    # (VMD's name of it: another file with LANG=C, Backend::vmd_name)
    set vpart [::VMDance::Backend::vmd_name $part]
    lassign [_open $file] tmp fh
    try {
        fconfigure $fh -translation binary
        set i 0
        foreach f $frames {
            # (a part left by a frame before is not taken for this one)
            file delete $part
            $s frame $f
            if {[catch {$s writepdb $vpart}] || ![_whole $part]} {
                error "\"$file\" could not be written: [_pdb_why $s $f $part [expr {$dcd && $i > 0}]]"
            }
            incr i
            set in [open $part rb]
            try { fcopy $in $fh } finally { close $in }
        }
        _put $fh $file ""
        _done $tmp $file
    } on error {msg opts} {
        catch {close $fh}
        file delete $tmp
        _failed $file $msg $opts
    } finally {
        file delete $part
    }
}
# Whether VMD's PDB writer wrote a file whole: it ends every frame with
# END, and does not check its last write (a full disk cuts the end off,
# unsaid).
proc ::VMDance::Export::_whole {f} {
    if {![file isfile $f] || [file size $f] < 4} { return 0 }
    set fh [open $f rb]
    try {
        seek $fh [expr {max(0, [file size $f] - 5)}]
        return [regexp {END\r?\n$} [read $fh]]
    } finally {
        close $fh
    }
}
# Why VMD did not write frame f of the atoms s as PDB (part): an occupancy
# or a beta its 6.2 columns cannot hold (the atoms', the same in every
# frame: no DCD helps, its PDB has them), a coordinate its 8.3 columns
# cannot hold (dcd: a DCD holds it, the frame not being the file's first),
# else the disk.
proc ::VMDance::Export::_pdb_why {s f part dcd} {
    if {![catch {_beyond [concat [$s get occupancy] [$s get beta]]} far] && $far} {
        return "an atom has an occupancy or a beta that a PDB cannot hold (-999.999 to 9999.999): set them within it, or leave those atoms out (-sel)"
    }
    if {![catch {_beyond [concat {*}[measure minmax $s]]} far] && $far} {
        return "frame $f has a coordinate, an occupancy or a beta that a PDB cannot hold (-999.999 to 9999.999): [expr {$dcd ? "write a DCD (-format dcd)" : "leave those atoms out (-sel)"}]"
    }
    return "VMD could not write frame $f in [file dirname $part] (is the disk full?)"
}
# Whether numbers v hold one past a PDB's columns (as VMD rounds them).
proc ::VMDance::Export::_beyond {v} {
    expr {[::tcl::mathfunc::min {*}$v] < -999.9994 || [::tcl::mathfunc::max {*}$v] > 9999.9994}
}

# The representatives' frames: one per cluster with frames, in cluster
# order.
proc ::VMDance::Export::rep_frames {} {
    set fl {}
    for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
        set f [::VMDance::Results::rep_frame $c]
        if {$f >= 0} { lappend fl $f }
    }
    return $fl
}
proc ::VMDance::Export::representatives {file {fmt pdb} {sel all}} {
    _need_clustering
    if {[::VMDance::Viz::_mol] < 0} { error [::VMDance::Viz::why] }
    write_frames [dict get [::VMDance::Results::request] mol] $sel [rep_frames] $file $fmt
}
# The picked frames' structures (pick save, the window's Save…), from their
# molecule while it has the frames they were picked from.
proc ::VMDance::Export::picked {file {fmt pdb} {sel all}} {
    set p $::VMDance::Results::picks
    if {![dict size $p]} { error "no frames picked" }
    if {[::VMDance::Viz::_picks_mol] < 0} { error [::VMDance::Viz::picks_why] }
    write_frames [dict get $p input mol] $sel [dict get $p vmdframes] $file $fmt
}

# One trajectory per cluster: base_<c>.<fmt>, renamed together. Returns
# the files.
proc ::VMDance::Export::trajectories {base {fmt dcd} {sel all}} {
    _need_clustering
    if {[::VMDance::Viz::_mol] < 0} { error [::VMDance::Viz::why] }
    set m [dict get [::VMDance::Results::request] mol]
    set out {}
    _batch {
        for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
            set fl [::VMDance::Results::member_frames $c]
            if {![llength $fl]} continue
            set f "${base}_$c.$fmt"
            write_frames $m $sel $fl $f $fmt
            lappend out {*}[frame_files $f $fmt]
        }
        if {![llength $out]} { error "no cluster has frames" }
    }
    return $out
}

#---------------------------------------------------------------------------
# A bundle of files
#---------------------------------------------------------------------------

# Why an item cannot be written now ("" when it can): what it needs (the
# catalog's), said as its writer says it. The window offers what can be.
proc ::VMDance::Export::why_not {it} {
    variable catalog
    set need [lindex [dict get $catalog $it] 1]
    if {$need in {clustering molecule prime similarity} && ![::VMDance::Results::has_data]} { return "no clustering" }
    if {$it in {distances tree}} { return [::VMDance::Results::too_many $it] }
    switch -- $need {
        molecule { if {[::VMDance::Viz::_mol] < 0} { return [::VMDance::Viz::why] } }
        prime { if {![dict size [::VMDance::Results::extra prime]]} { return "no PRIME prediction for this clustering (run PRIME first)" } }
        similarity { if {![dict size [::VMDance::Results::extra similarity]]} { return "no similarity for this clustering (compute it first)" } }
        elbow { if {![dict size $::VMDance::Results::elbow]} { return "no elbow scan" } }
        sweep { if {![dict size $::VMDance::Results::sweep]} { return "no sweep" } }
        picks { if {![dict size $::VMDance::Results::picks]} { return "no frames picked" } }
    }
    return ""
}

# The items written when none are named: the default ones, but for more
# than Measure::maxk clusters the transitions (k² rows: written when named)
# and what is not made then (the distances, the tree of the mean
# structures).
proc ::VMDance::Export::defaults {} {
    variable default_items
    if {[::VMDance::Results::nclusters] <= $::VMDance::Measure::maxk} { return $default_items }
    lmap it $default_items {expr {$it eq "transitions" || [why_not $it] ne "" ? [continue] : $it}}
}

# The files a bundle writes, in the order it returns them.
proc ::VMDance::Export::files {dir prefix items o} {
    variable catalog
    set base [file join $dir $prefix]
    set fmt [dict get $o format]
    set out {}
    foreach it $items {
        set f $base[lindex [dict get $catalog $it] 0]
        switch -- $it {
            representatives {
                if {$fmt eq "dcd"} { lappend out [file rootname $f].pdb [file rootname $f].dcd } else { lappend out $f }
            }
            trajectories {
                for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
                    if {[llength [::VMDance::Results::member_frames $c]]} { lappend out {*}[frame_files ${base}_cluster_$c.$fmt $fmt] }
                }
            }
            default { lappend out $f }
        }
    }
    return $out
}

# The files an earlier export of trajectories under prefix left in dir that
# this one does not write (prefix_cluster_<c>.pdb or .dcd: of a larger k,
# or the other format), which it deletes: read with this one's, they would
# mix two clusterings. A folder of the name is not one.
proc ::VMDance::Export::stale {dir prefix items files} {
    if {"trajectories" ni $items || ![file isdirectory $dir]} { return {} }
    set mine [lmap f $files {file tail $f}]
    set pre ${prefix}_cluster_
    set out {}
    foreach f [glob -nocomplain -directory $dir -- "[string map {\\ \\\\ * \\* ? \\? [ \\[ ] \\] \{ \\\{ \} \\\}} $pre]*"] {
        set t [file tail $f]
        if {[regexp {^(0|[1-9][0-9]*)\.(pdb|dcd)$} [string range $t [string length $pre] end]] && $t ni $mine &&
            ![catch {file lstat $f st}] && $st(type) in {file link}} { lappend out $f }
    }
    lsort $out
}

# A bundle checked before anything is written: the folder, the options, the
# prefix, each item (what it needs: a clustering, PRIME, a scan, the
# molecule with its frames), the structures' atoms at the first frame of
# each file (a selection by position can hold none at one), and every file
# it writes (target). Returns {dir items options files stale}: stale, an
# earlier export's clusters it deletes.
proc ::VMDance::Export::check {dir prefix items {opts {}}} {
    variable catalog
    set o [dict merge {top 10 lag 1 format dcd sel all} $opts]
    # (a name is a file's: "|cmd" would be read by open as a pipe)
    set dir [file normalize $dir]
    if {[file exists $dir] && ![file isdirectory $dir]} { error "\"$dir\" is a file, not a folder" }
    if {![regexp {^[1-9][0-9]{0,5}$} [dict get $o top]]} { error "-top must be a whole number from 1 to 999999 (got \"[dict get $o top]\")" }
    if {![regexp {^[1-9][0-9]{0,8}$} [dict get $o lag]]} { error "-lag must be a whole number from 1 to 999999999 (got \"[dict get $o lag]\")" }
    if {[dict get $o format] ni {dcd pdb}} { error "-format must be dcd or pdb (got \"[dict get $o format]\")" }
    # (no "~" first: Tcl would read the name as a user's home)
    if {$prefix eq "" || [regexp {[/\\:]} $prefix] || [string index $prefix 0] eq "~"} { error "the prefix must be a plain file name (not starting with ~)" }
    if {![llength $items]} { set items [defaults] }
    foreach it $items {
        if {![dict exists $catalog $it]} { error "unknown item \"$it\" (valid: [join [dict keys $catalog] {, }])" }
    }
    foreach it $items {
        set why [why_not $it]
        if {$why ne ""} { error $why }
    }
    set first {}
    if {"representatives" in $items} {
        set fl [rep_frames]
        if {![llength $fl]} { error "no cluster has frames" }
        lappend first [lindex $fl 0]
    }
    if {"trajectories" in $items} {
        set n 0
        for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
            set fl [::VMDance::Results::member_frames $c]
            if {[llength $fl]} { lappend first [lindex $fl 0]; incr n }
        }
        if {!$n} { error "no cluster has frames" }
    }
    if {[llength $first]} {
        set m [dict get [::VMDance::Results::request] mol]
        set sel [dict get $o sel]
        # (the same atoms at every frame: one frame says it)
        if {[::VMDance::Mol::dynamic $sel] eq ""} { set first [lrange $first 0 0] }
        foreach f [lsort -integer -unique $first] { ::VMDance::Mol::free [_sel $m $sel $f] }
    }
    set files [files $dir $prefix $items $o]
    if {[file isdirectory $dir]} { foreach f $files { target $f } }
    list $dir $items $o $files [stale $dir $prefix $items $files]
}

# Folder dir made, with its parents that do not exist; returns those made,
# the deepest last (_unmake takes them back).
proc ::VMDance::Export::_mkdir {dir} {
    set made {}
    for {set d $dir} {[catch {file lstat $d st}] && [file dirname $d] ne $d} {set d [file dirname $d]} {
        set made [linsert $made 0 $d]
    }
    if {[catch {file mkdir $dir} msg eo]} {
        _unmake $made
        error "the folder \"$dir\" could not be made: [_os $msg $eo]"
    }
    return $made
}
# The folders _mkdir made deleted again, those still empty: a call that
# fails while it writes leaves none.
proc ::VMDance::Export::_unmake {made} {
    foreach d [lreverse $made] { catch {file delete $d} }
}

# Write items into dir as prefix_<item>...: everything checked first, the
# folder made when it does not exist, and the files renamed into place
# once every one is written (a failure changes none, and takes back the
# folder it made); then an earlier export's clusters that this one does
# not write are deleted. Returns the files.
proc ::VMDance::Export::bundle {dir prefix items {opts {}}} {
    variable catalog
    lassign [check $dir $prefix $items $opts] dir items o files old
    # (made once everything is checked: a refused export makes no folder)
    set made [_mkdir $dir]
    set base [file join $dir $prefix]
    try {
        _batch {
            foreach it $items {
                set f $base[lindex [dict get $catalog $it] 0]
                switch -- $it {
                    summary { _write $f "[summary_text]\n" }
                    top { _write $f "[table_top [dict get $o top]]\n" }
                    transitions { _write $f "[table_transitions [dict get $o lag]]\n" }
                    representatives {
                        if {[dict get $o format] eq "dcd"} { set f [file rootname $f].dcd }
                        representatives $f [dict get $o format] [dict get $o sel]
                    }
                    trajectories { trajectories ${base}_cluster [dict get $o format] [dict get $o sel] }
                    default { _write $f "[table_$it]\n" }
                }
            }
        }
    } on error {msg opts} {
        _unmake $made
        return -options $opts $msg
    }
    # (one another user's, in a folder where only they can delete it, stays)
    foreach f $old { catch {file delete $f} }
    return $files
}
