#
# VMDance - requests and jobs: a clustering, an elbow scan, a sweep, and
# the questions asked of a clustering (no Tk dependency)
#
# A request is checked whole before anything runs (Job::check_*: every
# error names its option). A job reads the coordinates (Coords), runs the
# backend once or several times (Backend), checks what it returns
# (Job::output) and makes one value (a dict). In the window it runs in a
# coroutine: the coordinates are read in slices of 40 ms, mdance-cli runs
# in the background, and Cancel stops either. From the command it runs to
# its end (Job::run). A job never publishes anything: its caller does
# (Results), so a failed, cancelled or refused job changes nothing.
#
# The jobs:
#   cluster      one clustering: a result (Results::check'ed)
#   elbow        one algorithm at several k: a scan of records
#   sweep        a grid of configurations: a scan of records
#   adopt        a scan's record made a result (its measures computed)
#   prime        PRIME's seven frames for a result
#   similarity   the extended similarity (iSIM) of a result's clusters
#   map          a result's frames on their first two principal components
#   profiles     atom by atom: each cluster's and each group's fluctuations,
#                and each cluster's mean structure against one cluster's
#   pick         frames picked without clustering
# A scan's record keeps the clustering (its labels, sizes, representatives,
# scores), not the plugin's measures: they are computed when a record is
# adopted.
#
# One job at a time.
#

namespace eval ::VMDance::Job {
    variable running 0
    variable cancelled 0
    variable stopped ""        ;# why the backend was stopped from outside ("": Cancel)
    variable kind ""
    variable progress_cb ""
    variable inner {0.0 1.0}
    variable listeners {}      ;# told "start kind" and "end kind"
    variable backend ""        ;# the running job's {kind path}
    variable seq 0
    # what the library can take in one call (_library_fits)
    variable lib_text_max 2147483647   ;# Tcl's largest value: a longer text ends VMD
    variable lib_peak 180              ;# bytes a coordinate at a call's peak
    variable lib_kept 120              ;# of them, kept by Tcl for later calls until VMD quits
    variable lib_most 0                ;# the most coordinates given to the library in this VMD
    variable lib_rows {}               ;# the job's coordinates as the library's list (_call)
    variable lib_of ""                 ;# the extraction they are of
    # what a clustering request holds, and its defaults
    variable input_defaults {mol top sel "name CA" first 0 last -1 step 1 fit ""}
}

proc ::VMDance::Job::busy {} { variable running; return $running }

# Who is told when a job starts and ends (the window, for a job of the
# command's too).
proc ::VMDance::Job::listen {cmd} {
    variable listeners
    if {$cmd ni $listeners} { lappend listeners $cmd }
}
proc ::VMDance::Job::unlisten {cmd} {
    variable listeners
    set i [lsearch -exact $listeners $cmd]
    if {$i >= 0} { set listeners [lreplace $listeners $i $i] }
}
proc ::VMDance::Job::_tell {what kind} {
    variable listeners
    foreach l $listeners {
        if {[catch {uplevel #0 [list {*}$l $what $kind]} err]} { puts "VMDance) job listener: $err" }
    }
}

#---------------------------------------------------------------------------
# Requests
#---------------------------------------------------------------------------

# The input of a request (what is clustered), checked: mol (an id), sel,
# fit, first, last, step, and frames (the VMD frames) and natoms added.
proc ::VMDance::Job::check_input {req} {
    variable input_defaults
    set req [dict merge $input_defaults $req]
    set m [::VMDance::Mol::resolve "-mol" [dict get $req mol]]
    dict set req mol $m
    dict set req sel [string trim [dict get $req sel]]
    dict set req fit [string trim [dict get $req fit]]
    foreach k {first last step} { dict set req $k [string trim [dict get $req $k]] }
    dict set req frames [::VMDance::Mol::frames $m [dict get $req first] [dict get $req last] [dict get $req step]]
    set nf [llength [dict get $req frames]]
    if {$nf < 2} { error "-first, -last, -step: a clustering needs at least 2 frames (these give $nf)" }
    if {![::VMDance::Mol::exists $m]} { error "molecule $m was deleted" }
    lassign [::VMDance::Coords::check_selection $m [dict get $req sel] [dict get $req fit]] natoms idx fidx
    dict set req natoms $natoms
    # (the atoms the texts select now: "beta > 0" may be other atoms later)
    dict set req atoms [::VMDance::Mol::index_text $idx]
    dict set req fitatoms [expr {[llength $fidx] ? [::VMDance::Mol::index_text $fidx] : ""}]
    # (what the molecule is now: a session finds it again by its files)
    dict set req molecule [::VMDance::Mol::record $m]
    return $req
}

# A clustering request: the input, algorithm, k, metric and params.
proc ::VMDance::Job::check_cluster {req} {
    set req [check_input $req]
    if {![dict exists $req algorithm]} { dict set req algorithm kmeans }
    set a [dict get $req algorithm]
    if {![::VMDance::Algo::exists $a]} { error "-algorithm must be one of [join [::VMDance::Algo::all] {, }] (got \"$a\")" }
    set nf [llength [dict get $req frames]]
    if {[::VMDance::Algo::takes_k $a]} {
        if {![dict exists $req k] || [dict get $req k] eq ""} { dict set req k [::VMDance::Algo::default_k $a] }
        set k [string trim [dict get $req k]]
        if {![regexp {^(0|[1-9][0-9]*)$} $k]} { error "-k must be a whole number (got \"$k\")" }
        set lo [expr {$a eq "helm" ? 0 : 1}]
        if {$k < $lo || $k > $nf} { error "-k must be from $lo to the number of frames ($nf) (got $k)" }
        dict set req k $k
    } else {
        if {[dict exists $req k] && [dict get $req k] ne ""} { error "-k: [::VMDance::Algo::label $a] finds its own number of clusters (give -threshold)" }
        dict set req k ""
    }
    if {![dict exists $req metric]} { dict set req metric MSD }
    dict set req metric [::VMDance::Algo::check_metric [dict get $req metric]]
    if {![dict exists $req params]} { dict set req params {} }
    dict set req params [::VMDance::Algo::check_params $a [dict get $req params]]
    set nstart ""
    if {$a eq "helm" && [dict get $req params initial-labels] ne ""} {
        if {[catch {::VMDance::Algo::starting_labels [dict get $req params initial-labels] [dict get $req frames]} l]} { error "-initial-labels: $l" }
        set nstart [llength [lsort -unique $l]]
        dict set req nstart $nstart
        # (their sizes: -min-samples leaves out the small ones before a trim)
        dict set req starts [::VMDance::Algo::starting_sizes $l]
    }
    ::VMDance::Algo::check_combination $a [dict get $req k] [dict get $req params] $nf $nstart [dict get $req metric]
    if {[dict exists $req starts]} { ::VMDance::Algo::check_starting [dict get $req k] [dict get $req params] [dict get $req starts] $nf }
    return $req
}

# An elbow scan: a clustering request with ks (the values of k) instead
# of k. The request is checked with the smallest k; a value of k that its
# parameters cannot take (NANI's seeds, HELM's starting clusters) is kept
# in invalid, with the reason, and is not run.
proc ::VMDance::Job::check_elbow {req} {
    set a [::VMDance::_get $req algorithm kmeans]
    if {$a eq "equal"} { return [_check_radii $req] }
    if {[::VMDance::Algo::exists $a] && ![::VMDance::Algo::takes_k $a]} {
        error "-algorithm: [::VMDance::Algo::label $a] finds its own number of clusters; an elbow scan needs an algorithm that is given k"
    }
    set ks [::VMDance::_get $req ks {}]
    if {![llength $ks]} { error "-ks: no value of k" }
    if {[llength $ks] > 200} { error "-ks: at most 200 values of k (got [llength $ks])" }
    foreach k $ks {
        if {![regexp {^[1-9][0-9]{0,8}$} $k]} { error "-ks: \"$k\" is not a whole number of clusters from 1 to 999999999" }
    }
    set out [lsort -integer -unique $ks]
    if {[llength $out] < 2} { error "-ks: an elbow scan needs at least two values of k" }
    set stab [check_stability [::VMDance::_get $req stability {}] $a]
    if {[llength $out] > 200} { error "-ks: at most 200 values of k" }
    if {[catch {check_cluster [dict merge [dict remove $req ks] [dict create k [lindex $out 0]]]} q]} { error [_scan_says $q] }
    ::VMDance::Algo::check_scan [dict get $q algorithm] [dict get $q params]
    set invalid {}
    set nf [llength [dict get $q frames]]
    foreach k $out {
        if {$k > $nf} { dict set invalid $k "$k clusters is more than the $nf frames"; continue }
        if {[catch {::VMDance::Algo::check_combination [dict get $q algorithm] $k [dict get $q params] $nf \
                [expr {[dict exists $q nstart] ? [dict get $q nstart] : ""}] [dict get $q metric]} e]} { dict set invalid $k $e; continue }
        if {[dict exists $q starts] && [catch {::VMDance::Algo::check_starting $k [dict get $q params] [dict get $q starts] $nf} e]} { dict set invalid $k $e }
    }
    if {[dict size $invalid] == [llength $out]} { error "no value of k can be run: [_scan_says [lindex [dict values $invalid] end]]" }
    dict set q ks $out
    dict set q invalid $invalid
    dict set q k ""
    dict set q stability $stab
    return $q
}
# An elbow scan of eQUAL: its radius at every value of radii (eQUAL is
# given no k: the number of clusters follows from the radius). Each a
# radius eQUAL takes (above 0), at least two, at most 200; the request is
# checked with the smallest.
proc ::VMDance::Job::_check_radii {req} {
    set rs [::VMDance::_get $req radii {}]
    if {[dict exists $req ks] && [llength [dict get $req ks]]} { error "-ks: eQUAL is given no k; scan its radius (-radii {0.5 1 2})" }
    if {![string is list $rs] || ![llength $rs]} { error "-radii: an elbow scan of eQUAL is made at several radii (-radii {0.5 1 2})" }
    if {[llength $rs] > 200} { error "-radii: at most 200 values (got [llength $rs])" }
    set spec [::VMDance::Algo::param equal threshold]
    set out {}
    foreach r $rs {
        if {[catch {::VMDance::Algo::check_value $spec $r} v]} { error "-radii: \"$r\" is not a radius ([string map {-threshold "a radius"} $v])" }
        if {$v <= 0} { error "-radii: each radius must be above 0 (got $r)" }
        lappend out $v
    }
    set out [lsort -real -unique $out]
    if {[llength $out] < 2} { error "-radii: an elbow scan needs at least two radii" }
    check_stability [::VMDance::_get $req stability {}] equal
    set q [dict remove $req radii ks stability]
    dict set q params threshold [lindex $out 0]
    if {[catch {check_cluster [dict merge $q [dict create k ""]]} q]} { error [_scan_says $q] }
    dict set q radii $out
    dict set q ks {}
    dict set q invalid {}
    dict set q k ""
    dict set q stability {}
    return $q
}

# The seedings an elbow scan's stability compares: {} (none), or two or
# more of NANI's, each once, for k-means NANI.
proc ::VMDance::Job::check_stability {stab a} {
    if {![llength $stab]} { return {} }
    if {$a ne "kmeans"} { error "-stability: the agreement between seedings is that of k-means NANI's (the scan's algorithm is [::VMDance::Algo::label $a])" }
    if {![string is list $stab]} { error "-stability: a list of seedings" }
    foreach k $stab {
        if {$k ni $::VMDance::Algo::kinits} { error "-stability: \"$k\" is not a seeding ([join $::VMDance::Algo::kinits {, }])" }
    }
    set out [lsort -unique $stab]
    if {[llength $out] != [llength $stab]} { error "-stability: a seeding is given twice" }
    if {[llength $out] < 2} { error "-stability: two seedings at least, to compare" }
    return $stab
}
# A check's message as a scan's refusal says it: the option -k is the
# scan's -ks (-trim-k stays itself; a record names its own k: -k).
proc ::VMDance::Job::_scan_says {msg} {
    regsub -all {(^|[^-A-Za-z0-9_])-k\M} $msg {\1-ks} msg
    return $msg
}

# A sweep: the input and configs, each {algorithm k metric params},
# checked one by one: a configuration that is refused is kept with the
# reason (error), and is not run.
proc ::VMDance::Job::check_sweep {req} {
    if {![dict exists $req configs] || ![llength [dict get $req configs]]} { error "a sweep needs at least one configuration" }
    set q [check_input [dict remove $req configs]]
    if {[llength [dict get $req configs]] > 1000} { error "a sweep has at most 1000 configurations (this one [llength [dict get $req configs]])" }
    set out {}
    set i 0
    set ok 0
    foreach cf [dict get $req configs] {
        incr i
        if {[catch {dict size $cf}] || ![dict exists $cf algorithm]} { error "configuration $i is not a list of name value pairs with an algorithm" }
        if {[::VMDance::Algo::exists [dict get $cf algorithm]] && ![::VMDance::Algo::takes_k [dict get $cf algorithm]]} {
            error "configuration $i: [::VMDance::Algo::label [dict get $cf algorithm]] is not given k: a sweep runs KMeans NANI, DIVINE and HELM"
        }
        if {[catch {
            set c [check_cluster [dict merge $q $cf]]
            ::VMDance::Algo::check_scan [dict get $c algorithm] [dict get $c params]
        } e]} {
            # (the parameters as given, for the table)
            foreach key {k metric params} { if {![dict exists $cf $key]} { dict set cf $key [expr {$key eq "params" ? {} : ""}] } }
            dict set cf error $e
            lappend out $cf
        } else {
            lappend out [dict filter $c key algorithm k metric params]
            incr ok
        }
    }
    if {!$ok} { error "no configuration can be run: [_scan_says [dict get [lindex $out end] error]]" }
    dict set q configs $out
    return $q
}

# Options of the questions after a clustering: {name value ...} checked
# against specs (Algo::prime_params ...), completed with the defaults
# (stored: read from a session, as Algo::check_value takes it).
proc ::VMDance::Job::check_specs {specs given {stored 0}} {
    set out {}
    foreach p $specs { dict set out [lindex $p 0] [lindex $p 2] }
    if {[catch {dict size $given}]} { error "options must come in -name value pairs" }
    dict for {k v} $given {
        set spec ""
        foreach p $specs { if {[lindex $p 0] eq $k} { set spec $p } }
        if {$spec eq ""} { error "unknown option -$k (valid: [join [lmap p $specs {string cat - [lindex $p 0]}] {, }])" }
        dict set out $k [::VMDance::Algo::check_value $spec $v $stored]
    }
    return $out
}

# Whether the backend in use has an algorithm (errors say why not).
proc ::VMDance::Job::check_available {a} {
    set have [::VMDance::Backend::algorithms]
    # (asked again before it is refused: a launcher's stamp stays the same
    # when the program it runs is rebuilt)
    if {$a ni $have} { set have [::VMDance::Backend::algorithms 1] }
    if {$a ni $have} {
        error "[::VMDance::Algo::label $a] is not in this build of the backend (it has [join [lmap x $have {::VMDance::Algo::label $x}] {, }]); CPP-MDANCE builds DIVINE only with BUILD_DIVINE"
    }
}

#---------------------------------------------------------------------------
# Running a job
#---------------------------------------------------------------------------

# Start a job in the background: req its checked request; progress
# {fraction message}; done {status value} with status ok, cancelled or
# error (the value of a cancelled job: why the backend was stopped from
# outside, or "").
proc ::VMDance::Job::start {kind req progress done} {
    variable running; variable cancelled; variable stopped; variable progress_cb
    if {$running} { error "a job is running" }
    if {[info commands ::VMDance::Job::_do_$kind] eq ""} { error "unknown job \"$kind\"" }
    set running 1
    set cancelled 0
    set stopped ""
    set ::VMDance::Job::kind $kind
    set progress_cb $progress
    coroutine ::VMDance::Job::_co ::VMDance::Job::_body $kind $req $done
    _tell start $kind
    return
}

# Run a job to its end (the command); returns its value or an error.
# (each call waits on its own variable: a job started while another ends
# never takes the other's answer)
proc ::VMDance::Job::run {kind req {progress ""}} {
    variable seq
    set var ::VMDance::Job::wait[incr seq]
    set $var ""
    start $kind $req $progress [list apply {{var st r} { set $var [list $st $r] }} $var]
    while {[set $var] eq ""} { vwait $var }
    lassign [set $var] st r
    unset $var
    switch -- $st {
        ok { return $r }
        cancelled {
            if {$r ne ""} { error "cancelled: $r" }
            error "cancelled"
        }
        default { error $r }
    }
}

proc ::VMDance::Job::cancel {} {
    variable running; variable cancelled
    if {!$running} { return 0 }
    set cancelled 1
    ::VMDance::Backend::cancel
    return 1
}

proc ::VMDance::Job::_body {kind req done} {
    variable running; variable cancelled; variable stopped
    set status ok
    set result ""
    # (the caller's code runs first: start returns before any work)
    after 1 [info coroutine]
    yield
    variable backend
    try {
        # (the backend of the whole job: a scan never mixes two programs)
        set backend [::VMDance::Backend::current]
        # (the library takes the coordinates as one list: what cannot fit is
        # refused before they are read; adopt and import call no backend)
        if {[lindex $backend 0] eq "library" && $kind ni {adopt import}} {
            set in [::VMDance::_get $req result $req]
            _library_fits [dict get $in natoms] [llength [dict get $in frames]]
            # (and what would crash it: an elbow's smallest k, its others and
            # a sweep's configurations one by one, as they are run)
            if {$kind in {cluster elbow}} {
                _library_divine [dict get $req algorithm] [lindex [::VMDance::_get $req ks [dict get $req k]] 0] [dict get $req params]
            }
        }
        set result [_do_$kind $req]
        if {$cancelled} { set status cancelled; set result $stopped }
    } on error {msg} {
        if {$cancelled} { set status cancelled; set result $stopped } else { set status error; set result $msg }
    } finally {
        set running 0
        set backend ""
        variable lib_rows {}
        variable lib_of ""
        # (the coordinates' files dropped meanwhile: the job no longer reads them)
        ::VMDance::Coords::reap
    }
    # (its caller first, then who listens)
    after 0 [list {*}$done $status $result]
    after 0 [list ::VMDance::Job::_tell end $kind]
}

proc ::VMDance::Job::_progress {frac msg} {
    variable progress_cb
    if {$progress_cb ne ""} { catch {uplevel #0 [list {*}$progress_cb $frac $msg]} }
}

# The coordinates of a request, read in the background (progress within
# [lo, hi] of the job).
proc ::VMDance::Job::_coords {req {lo 0.0} {hi 0.4}} {
    set c [::VMDance::Coords::cached $req ::VMDance::Job::cancelled]
    if {[dict size $c]} { return $c }
    _progress $lo "reading [llength [dict get $req frames]] frames"
    ::VMDance::Coords::extract $req [list apply {{lo hi f m} {
        ::VMDance::Job::_progress [expr {$lo + ($hi - $lo) * $f}] $m
    }} $lo $hi] ::VMDance::Job::cancelled
}

# One call of the backend (in the background when it is the program).
# what: {cluster a k metric params initial} | {analysis metric labels} |
# {prime metric trim weighted labels} | {select metric method param
# nbins}. Returns the backend's answer as it wrote it (a dict), with
# _backend {kind path}.
proc ::VMDance::Job::_call {c what {msg ""}} {
    variable cancelled
    if {$cancelled} { error "cancelled" }
    variable backend
    lassign [expr {$backend ne "" ? $backend : [::VMDance::Backend::current]}] bk path
    if {$bk eq "cli" && ![::VMDance::Backend::_exe $path]} { error "mdance-cli \"$path\" is not there any more" }
    # (a program the probe found is not mdance-cli is not run: for a pick,
    # PRIME or the similarity no more than for a clustering)
    if {$bk eq "cli"} { ::VMDance::Backend::algorithms }
    set natoms [dict get $c natoms]
    set nf [llength [dict get $c frames]]
    set op [lindex $what 0]
    if {$bk eq "library"} {
        _library_takes $c
        if {$op eq "cluster"} { _library_divine [lindex $what 1] [lindex $what 2] [lindex $what 4] }
        variable inner; variable lib_rows; variable lib_of
        # (one list for the job's calls, the rows the extraction read, as the
        # program's CSV: read again and checked once, and CPP-MDANCE makes
        # its text once; a new list at every k of a scan tripled its time)
        set of [list [dict get $c csv] [dict get $c digest]]
        if {$lib_of ne $of} {
            set lib_rows {}
            set lib_of ""
            _progress [lindex $inner 0] "$msg: reading the frames for the library"
            set lib_rows [::VMDance::Coords::flat $c ::VMDance::Job::cancelled]
            set lib_of $of
        }
        set co $lib_rows
        # (a call blocks VMD: the window shows what runs first, and says so)
        _progress [lindex $inner 0] "$msg[expr {$op eq "cluster" && [lindex $what 2] ne "" ? ", k = [lindex $what 2]" : ""}], in the library: VMD does not respond until it ends"
        after 20 [info coroutine]
        yield
        if {$cancelled} { error "cancelled" }
        # (counted as the call is made: one cancelled before made no text)
        variable lib_most
        set lib_most [expr {max($lib_most, [llength $co])}]
        try {switch -- $op {
            cluster {
                lassign $what - a k metric params initial
                set opts [::VMDance::Algo::lib_args $a $params $metric]
                switch -- $a {
                    equal { set r [::mdance::equal $co $nf $natoms {*}$opts] }
                    helm  { set r [::mdance::helm $co $nf $natoms $k $initial {*}$opts] }
                    default { set r [::mdance::$a $co $nf $natoms $k {*}$opts] }
                }
            }
            analysis {
                lassign $what - metric labels
                set r [::mdance::analysis $co $nf $natoms -metric $metric -labels $labels]
            }
            prime {
                lassign $what - metric trim weighted labels
                set opts [list -metric $metric -labels $labels -trim-frac $trim]
                if {$weighted} { lappend opts -weighted }
                set r [::mdance::prime $co $nf $natoms {*}$opts]
            }
            select {
                lassign $what - metric method param nbins
                set r [dict create indices [::mdance::select $co $nf $natoms -metric $metric -method $method -param $param -nbins $nbins]]
            }
        }} finally {
            # (a Cancel pressed during the call, which VMD reads only now, is
            # taken before the job goes on, or ends and publishes, the call
            # failed or not; 20 ms, as before it: X's events are handled first)
            after 20 [info coroutine]
            yield
            if {$cancelled} { error "cancelled" }
        }
        if {[catch {dict size $r}]} { error "the library's answer is not a dictionary" }
        return [dict merge $r [dict create _backend [list library $path]]]
    }
    set csv [::VMDance::Coords::csv $c]
    set out [::VMDance::Backend::tmpfile .json]
    set tmp [list $out]
    set labels_file {apply {{labels tmpvar} {
        upvar 1 $tmpvar tmp
        set f [::VMDance::Backend::tmpfile .csv]
        ::VMDance::Backend::write_column $f $labels
        lappend tmp $f
        return $f
    }}}
    switch -- $op {
        cluster {
            lassign $what - a k metric params initial
            set init [expr {$a eq "helm" ? [{*}$labels_file $initial tmp] : ""}]
            set argv [::VMDance::Algo::cli_args $a $k $metric $params $natoms $csv $out $init]
        }
        analysis {
            lassign $what - metric labels
            set argv [list --analysis --input $csv --output $out --natoms $natoms --metric $metric --labels [{*}$labels_file $labels tmp]]
        }
        prime {
            lassign $what - metric trim weighted labels
            set argv [list --prime --input $csv --labels [{*}$labels_file $labels tmp] --output $out --natoms $natoms --metric $metric --trim-frac $trim]
            if {$weighted} { lappend argv --weighted }
        }
        select {
            lassign $what - metric method param nbins
            set argv [list --select --input $csv --output $out --natoms $natoms --metric $metric --method $method --param $param --nbins $nbins]
        }
    }
    try {
        set co [info coroutine]
        ::VMDance::Backend::start $path $argv -line [list ::VMDance::Job::_line $msg] \
            -done [list apply {{co st m j} { after 0 [list $co [list $st $m $j]] }} $co]
        lassign [yield] st m j
        if {$st eq "cancelled"} { error "cancelled" }
        if {$st eq "stopped"} {
            # (ended from outside, Ctrl+C at VMD's terminal or kill: the
            # whole job stops, a scan too, as with Cancel)
            variable stopped $m
            set cancelled 1
            error "cancelled"
        }
        if {$st ne "ok"} {
            # (its rows, from 1, are the clustered frames: a row is never
            # handed out as a frame)
            if {[regexp {^(.*) at row ([1-9][0-9]{0,8})$} $m -> head r] && $r <= $nf} {
                set m "$head at VMD frame [lindex [dict get $c frames] [expr {$r - 1}]] (row $r)"
            }
            error "mdance-cli failed: $m"
        }
        if {![file exists $out] || [file size $out] == 0} { error "mdance-cli wrote no result" }
        set fh [open $out r]
        try { set text [read $fh] } finally { close $fh }
        if {[catch {::VMDance::Json::parse $text} r]} { error "mdance-cli's result is not valid JSON: $r" }
        if {[catch {dict size $r}]} { error "mdance-cli's result is not a JSON object" }
        return [dict merge $r [dict create _backend [list cli $path]]]
    } finally {
        foreach f $tmp { file delete $f }
    }
}

# A line the program printed: a percentage becomes progress; what it says
# it is doing, the message.
proc ::VMDance::Job::_line {msg line} {
    variable inner
    lassign $inner lo hi
    if {[regexp {(\d+(?:\.\d+)?)\s*%} $line -> p]} {
        _progress [expr {$lo + ($hi - $lo) * min(1.0, $p / 100.0)}] $msg
    } elseif {[regexp {^(Running|Building|Reading|Writing) (.*)$} $line -> v rest]} {
        # (the line without its closing dots: "threshold=0.2" has a dot of
        # its own; and without the private files' names, which say nothing)
        if {$v in {Reading Writing}} { regsub {: .*$} $rest "" rest }
        _progress $lo "$msg: [string tolower $v] [string trimright $rest {. }]"
    }
}

# Whether the library can take the coordinates of nf frames × natoms
# atoms in one call; an error says what to change. CPP-MDANCE's Tcl binding
# makes a text of the coordinates' list (it looks for its options among
# every argument), and Tcl ends VMD when a text passes 2 GB, whatever the
# memory; text: its length, else estimated (17 bytes a number: VMD's
# coordinates, floats, take 18 to 19 with their separator, so that no call
# of theirs that fits is refused). And a call takes about 180 bytes a
# number at its peak, of which Tcl keeps 120 until VMD quits, for the calls
# after: one that needs more than VMD can get ends it too (the kernel kills
# it). The program, in a process of its own, takes neither.
proc ::VMDance::Job::_library_fits {natoms nf {text ""}} {
    variable lib_text_max; variable lib_peak; variable lib_kept; variable lib_most
    set n [expr {3 * wide($natoms) * $nf}]
    if {$text eq ""} { set text [expr {17 * $n}] }
    set what "$nf frames × $natoms atoms"
    set fix "use the program (Settings ▸ Backend, or vmdance backend -mode cli -cli path[expr {$::VMDance::Backend::mode eq "auto" ? ": Automatic found none" : ""}]), or fewer atoms (-sel) or frames (-first, -last, -step)"
    if {$text > $lib_text_max} {
        error "-sel, -first, -last, -step: the library cannot take $what: CPP-MDANCE makes a text of their coordinates ([_size $text]), longer than Tcl's limit of 2 GB, which ends VMD; $fix"
    }
    set need [expr {$lib_peak * $n - $lib_kept * min($n, $lib_most)}]
    set free [_memory_free]
    if {$free ne "" && $need > $free} {
        error "-sel, -first, -last, -step: the library would need about [_size $need] more in VMD for $what, and [_size $free] is free; $fix"
    }
}
# Whether the library can run DIVINE so, at k: CPP-MDANCE's NANI seeding by
# complementary similarity reads an empty matrix when the cluster split has
# fewer than 100 / p frames (none among its densest p%), which DIVINE can
# choose at any split after the first: the program crashes (one failure,
# Job::_cluster), the library takes VMD with it. (k 2 is the first split
# alone, of every frame, which Algo::check_combination checked.) A check
# made before the backend runs: a scan keeps a k or a configuration it
# refuses as "not run" (errorcode VMDANCE NOTRUN, as Job::_cluster's
# check_starting), and one where none ran is refused, the scan there was
# kept.
proc ::VMDance::Job::_library_divine {a k params} {
    if {$a ne "divine" || [dict get $params anchors] ne "NANI" || [dict get $params kinit] ne "CompSim"} return
    if {[dict get $params end-mode] eq "k" && $k <= 2} return
    set p [dict get $params percentage]
    if {$p < 50} {
        return -code error -errorcode {VMDANCE NOTRUN} "-kinit CompSim with -percentage $p: CPP-MDANCE's DIVINE crashes when it splits a cluster of fewer than [expr {int(ceil(100.0 / $p))}] frames, and the library takes VMD with it; use the program (Settings ▸ Backend, or vmdance backend -mode cli -cli path), -percentage 50 or more, or another seeding"
    }
}
# The same for an extraction, exactly: the text the library makes of its
# rows is their CSV's, less its last newline (the same numbers, a
# separator after each).
proc ::VMDance::Job::_library_takes {c} {
    set text ""
    catch {set text [expr {[file size [::VMDance::Coords::csv $c]] - 1}]}
    _library_fits [dict get $c natoms] [llength [dict get $c frames]] $text
}
proc ::VMDance::Job::_size {b} {
    if {$b < 1e6} { return "[format %.0f [expr {$b / 1e3}]] kB" }
    if {$b < 1e9} { return "[format %.0f [expr {$b / 1e6}]] MB" }
    return "[format %.1f [expr {$b / 1e9}]] GB"
}
# The memory VMD can still take, in bytes ("" when it cannot be told: no
# /proc): what the system has available, or less when the cgroups of VMD
# (a container's, a batch job's) allow less above what they use (less the
# files' cache, which the kernel drops first).
proc ::VMDance::Job::_memory_free {} {
    set free ""
    if {[regexp -line {^MemAvailable:\s+([0-9]{1,15}) kB} [_small /proc/meminfo] -> kb]} { set free [expr {$kb * 1024}] }
    foreach line [split [_small /proc/self/cgroup] \n] {
        # (v2: 0::/path; v1: n:...,memory,...:/path)
        if {![regexp {^[0-9]+:([^:]*):(/.*)$} $line -> ctl g]} continue
        if {$ctl eq ""} {
            lassign {/sys/fs/cgroup memory.max memory.current inactive_file} base fmax fcur fcache
        } elseif {"memory" in [split $ctl ,]} {
            lassign {/sys/fs/cgroup/memory memory.limit_in_bytes memory.usage_in_bytes total_inactive_file} base fmax fcur fcache
        } else continue
        # (the group and those above it: "max", or v1's 2^63, is no limit)
        while 1 {
            set d [file join $base {*}[lrange [file split $g] 1 end]]
            set max [string trim [_small [file join $d $fmax]]]
            set cur [string trim [_small [file join $d $fcur]]]
            if {[regexp {^[0-9]{1,18}$} $max] && [regexp {^[0-9]{1,18}$} $cur]} {
                set cache 0
                regexp -line "^$fcache (\[0-9\]{1,18})\$" [_small [file join $d memory.stat]] -> cache
                set room [expr {max(0, $max - $cur + $cache)}]
                if {$free eq "" || $room < $free} { set free $room }
            }
            if {$g eq "/"} break
            set g [file dirname $g]
        }
    }
    return $free
}
# A small file of the system's (/proc, /sys), "" when it cannot be read.
proc ::VMDance::Job::_small {f} {
    if {[catch {open $f r} fh]} { return "" }
    set t ""
    catch {set t [read $fh 65536]}
    catch {close $fh}
    return $t
}

#---------------------------------------------------------------------------
# What the backend returns, checked
#---------------------------------------------------------------------------

# A list of whole numbers, of length n ("" any), each within [lo, hi].
proc ::VMDance::Job::_ints {what l n lo hi} {
    if {[catch {llength $l} len]} { error "the backend's $what is not a list" }
    if {$n ne "" && $len != $n} { error "the backend returned $len $what, not $n" }
    set out {}
    foreach v $l {
        # (decimal: expr reads 010 as octal; and short: no bignum)
        if {![regexp {^-?(0|[1-9][0-9]{0,11})(\.0*)?$} $v]} { error "the backend's $what hold \"$v\", not a whole number" }
        set v [expr {int($v)}]
        if {$v < $lo || ($hi ne "" && $v > $hi)} { error "the backend's $what hold $v, outside $lo to $hi" }
        lappend out $v
    }
    return $out
}
# A finite number, else "" (NaN, ±Inf, and beyond ±1e300, which Tcl reads
# as a double that overflows later).
proc ::VMDance::Job::_num {v} {
    if {$v eq "" || ![string is double -strict $v] || [regexp -nocase {nan|inf} $v]} { return "" }
    if {[catch {expr {abs($v) < 1e300}} ok] || !$ok} { return "" }
    return $v
}

# A clustering's answer (the program's JSON or the library's dict) as the
# plugin keeps it, checked against nf frames: {nclusters labels sizes
# representatives msd ch db zmatrix}. The sizes are counted from the
# labels, and every representative must be a frame of its own cluster.
proc ::VMDance::Job::output {r nf} {
    foreach k {nClusters labels} {
        if {![dict exists $r $k]} { error "the backend's result has no \"$k\" (truncated?)" }
    }
    set k [dict get $r nClusters]
    if {![regexp {^(0|[1-9][0-9]{0,8})(\.0*)?$} $k]} { error "the backend's nClusters is \"$k\"" }
    set k [expr {int($k)}]
    # (before anything is made k long)
    if {$k > $nf} { error "the backend's nClusters ($k) is more than the $nf frames" }
    set k [expr {$k}]
    set labels [_ints labels [dict get $r labels] $nf -1 [expr {$k - 1}]]
    set sizes [lrepeat $k 0]
    foreach l $labels { if {$l >= 0} { lset sizes $l [expr {[lindex $sizes $l] + 1}] } }
    if {[dict exists $r clusterSizes]} {
        set given [_ints "cluster sizes" [dict get $r clusterSizes] $k 0 $nf]
        if {$given ne $sizes} { error "the backend's cluster sizes ([join $given {, }]) are not those of its labels ([join $sizes {, }])" }
    }
    # (with no cluster the library leaves the lists out)
    if {![dict exists $r representatives] && $k > 0} { error "the backend's result has no representatives (truncated?)" }
    # (as they are: an imported session's answer, which expr's ?: would make
    # "010" 8 of, and fail on "NaN")
    set reps [_ints representatives [::VMDance::_get $r representatives {}] $k -1 [expr {$nf - 1}]]
    for {set c 0} {$c < $k} {incr c} {
        set p [lindex $reps $c]
        if {[lindex $sizes $c] == 0} {
            if {$p != -1} { error "the backend gave the empty cluster $c a representative ($p)" }
        } elseif {$p < 0 || [lindex $labels $p] != $c} {
            error "the backend's representative of cluster $c (row $p) is not in it"
        }
    }
    set msd [::VMDance::_get $r clusterMSD [lrepeat $k ""]]
    if {[catch {llength $msd} n] || $n != $k} { error "the backend returned [llength $msd] cluster MSDs for $k clusters" }
    set msd [lmap v $msd {_num $v}]
    # (CPP-MDANCE writes 0 for a cluster without frames: no MSD, and it would
    # read as the tightest cluster; a frame alone has MDANCE's own 0)
    set msd [lmap v $msd s $sizes {if {$s} { set v } else { list }}]
    set ch ""; set db ""
    if {[dict exists $r scores]} {
        set s [dict get $r scores]
        if {[catch {dict size $s}]} { error "the backend's scores are not an object" }
        if {[dict exists $s calinskiHarabasz]} { set ch [_num [dict get $s calinskiHarabasz]] }
        if {[dict exists $s daviesBouldin]} { set db [_num [dict get $s daviesBouldin]] }
    }
    if {[dict exists $r score_calinskiHarabasz]} { set ch [_num [dict get $r score_calinskiHarabasz]] }
    if {[dict exists $r score_daviesBouldin]} { set db [_num [dict get $r score_daviesBouldin]] }
    if {![_scored $sizes]} { set ch ""; set db "" }
    set z {}
    if {[dict exists $r zMatrix]} {
        foreach row [dict get $r zMatrix] {
            if {[catch {llength $row} n] || $n != 4} { error "the backend's zMatrix has a row that is not 4 values" }
            lassign $row a b d cnt
            foreach v [list $a $b $cnt] {
                if {![regexp {^(0|[1-9][0-9]{0,11})(\.0*)?$} $v]} { error "the backend's zMatrix holds \"$v\"" }
            }
            lappend z [list [expr {int($a)}] [expr {int($b)}] [_num $d] [expr {int($cnt)}]]
        }
    }
    dict create nclusters $k labels $labels sizes $sizes representatives $reps msd $msd ch $ch db $db zmatrix $z
}
# Whether clusters of these sizes have scores. The scores compare clusters:
# scikit-learn takes 2 to n − 1 of them, n the frames scored (noise left
# out). With fewer than two CPP-MDANCE gives 0, and with every cluster a
# frame alone CH 1 and DB 0 (no spread within): neither is a score, and a
# DB of 0 would be the best of a scan.
proc ::VMDance::Job::_scored {sizes} {
    set filled [llength [lsearch -all -not -exact $sizes 0]]
    expr {$filled >= 2 && $filled < [::tcl::mathop::+ 0 {*}$sizes]}
}

#---------------------------------------------------------------------------
# The jobs
#---------------------------------------------------------------------------

# HELM's starting clusters: a label file's, or a first NANI clustering's.
proc ::VMDance::Job::_initial {c req} {
    set p [dict get $req params]
    set nf [llength [dict get $c frames]]
    if {[dict get $p initial-labels] ne ""} {
        return [::VMDance::Algo::starting_labels [dict get $p initial-labels] [dict get $c frames]]
    }
    set first [dict create kinit [dict get $p initial-kinit] percentage [dict get $p initial-percentage]]
    set r [output [_call $c [list cluster kmeans [dict get $p initial] [dict get $req metric] $first {}] "HELM: the first clustering"] $nf]
    # (numbered 0, 1 … without gaps, as CPP-MDANCE numbers HELM's leaves: a
    # cluster of the first clustering can be empty)
    set l [dict get $r labels]
    set i 0
    foreach v [lsort -integer -unique $l] { dict set num $v $i; incr i }
    lmap v $l {dict get $num $v}
}

# One clustering of the coordinates c (progress within [lo, hi]); initial:
# HELM's starting labels when they are known already.
proc ::VMDance::Job::_cluster {c req lo hi {initial ""}} {
    variable inner
    set a [dict get $req algorithm]
    set k [dict get $req k]
    set nf [llength [dict get $c frames]]
    set label [::VMDance::Algo::label $a]
    if {$a eq "helm" && $initial eq ""} {
        set mid [expr {$lo + ($hi - $lo) / 2.0}]
        set inner [list $lo $mid]
        _progress $lo "HELM: its starting clusters"
        set initial [_initial $c $req]
        set lo $mid
    }
    # (HELM's starting clusters as the backend gets them: a k they cannot
    # take is not run)
    if {$a eq "helm" && [catch {::VMDance::Algo::check_starting $k [dict get $req params] [::VMDance::Algo::starting_sizes $initial] $nf} e]} {
        return -code error -errorcode {VMDANCE NOTRUN} $e
    }
    set inner [list $lo $hi]
    _progress $lo "$label[expr {$k ne "" ? ", k = $k" : ""}]"
    if {[catch {_call $c [list cluster $a $k [dict get $req metric] [dict get $req params] $initial] $label} raw opts]} {
        # (a later split of DIVINE's, of a cluster too small for its NANI's
        # two seeds, which the backend calls kClusters: Algo::check_combination
        # can check the first only)
        if {$a eq "divine" && [string match "*fewer centers than kClusters*" $raw]} {
            set p [dict get $req params percentage]
            error "DIVINE chose to split a cluster of fewer than [expr {int(ceil(200.0 / $p))}] frames: its 2-cluster NANI (-kinit [dict get $req params kinit]) seeds from the densest $p% of the cluster's frames, and needs 2; raise -percentage, seed with KmeansPP or Random, or ask for fewer clusters"
        }
        # (or of fewer than 100 / p frames, none among its densest p%: NANI
        # seeded by complementary similarity crashes the program then, after
        # the first split, _library_divine)
        set q [dict get $req params]
        if {$a eq "divine" && [string match "*mdance-cli crashed*" $raw] && $k > 2 && [dict get $q anchors] eq "NANI" &&
                [dict get $q kinit] eq "CompSim" && [dict get $q percentage] < 50} {
            set p [dict get $q percentage]
            error "DIVINE chose to split a cluster of fewer than [expr {int(ceil(100.0 / $p))}] frames, and mdance-cli crashed: its 2-cluster NANI (-kinit CompSim) seeds from the densest $p% of the cluster's frames, none there; raise -percentage to 50 or more, seed with KmeansPP or Random, or ask for fewer clusters"
        }
        return -options $opts $raw
    }
    set out [output $raw $nf]
    # (what -trim-val's cut left, an MSD the backend computes: a k it leaves
    # HELM nothing to merge at is not run either)
    if {$a eq "helm" && [catch {::VMDance::Algo::check_trimmed $k [dict get $req params] $initial [dict get $out labels]} e]} {
        return -code error -errorcode {VMDANCE NOTRUN} $e
    }
    dict set out initial [expr {$a eq "helm" ? $initial : {}}]
    dict set out backend [dict get $raw _backend]
    return $out
}
# HELM clusterings' scores, of their clustered frames: CPP-MDANCE's HELM
# (the program's and the library's) scores the trimmed frames as one more
# cluster, where MDANCE, and CPP-MDANCE's eQUAL, leave them out. Those of
# a scan are made together, once its clusterings are made: two passes over
# the frames, not two at every k.
proc ::VMDance::Job::_clustered_scores {c cls at} {
    set which {}
    set i 0
    foreach cl $cls {
        if {[lsearch -exact [dict get $cl labels] -1] >= 0 && [_scored [dict get $cl sizes]]} { lappend which $i }
        incr i
    }
    if {![llength $which]} { return $cls }
    _progress $at "HELM: the scores of the clustered frames"
    set scores [::VMDance::Measure::scores $c [lmap i $which {
        list [dict get [lindex $cls $i] labels] [dict get [lindex $cls $i] nclusters]
    }] ::VMDance::Job::cancelled]
    foreach i $which s $scores {
        set cl [lindex $cls $i]
        dict set cl ch [_num [lindex $s 0]]
        dict set cl db [_num [lindex $s 1]]
        lset cls $i $cl
    }
    return $cls
}
# A scan's records with their HELM clusterings scored so (an elbow's: of
# the algorithm a; a sweep's: of their own).
proc ::VMDance::Job::_scan_scores {c recs a at} {
    set which {}
    set i 0
    foreach r $recs {
        if {[dict get $r status] eq "ok" && [::VMDance::_get $r algorithm $a] eq "helm"} { lappend which $i }
        incr i
    }
    foreach i $which cl [_clustered_scores $c [lmap i $which {dict get [lindex $recs $i] clustering}] $at] {
        set r [lindex $recs $i]
        dict set r ch [dict get $cl ch]
        dict set r db [dict get $cl db]
        dict set r clustering $cl
        lset recs $i $r
    }
    return $recs
}

# A whole result: the request (with the atoms its texts selected then),
# the molecule, the frames, the clustering and the plugin's measures.
proc ::VMDance::Job::_result {c req cl t0} {
    set m [dict get $req mol]
    set q [dict filter $req key mol sel fit first last step algorithm k metric params atoms fitatoms]
    set r [dict create format 1 request $q molecule [_molecule $req] \
        frames [dict get $c frames] natoms [dict get $c natoms]]
    set r [dict merge $r [dict remove $cl backend]]
    dict set r backend [dict get $cl backend]
    _progress 0.97 "measuring the clusters"
    # (minutes with thousands of clusters: said as it goes, and Cancel stops it)
    dict set r measures [::VMDance::Measure::compute $c [dict get $cl labels] \
        [dict get $cl nclusters] [dict get $cl representatives] [dict get $c natoms] ::VMDance::Job::cancelled \
        [list apply {{f m} { ::VMDance::Job::_progress [expr {0.97 + 0.03 * $f}] $m }}]]
    # (HELM's merges: how loose each makes its cluster, their heights)
    if {[llength [dict get $cl zmatrix]] && [llength [dict get $cl initial]]} {
        set tree [::VMDance::Measure::helm_tree [dict get $cl zmatrix] [dict get $cl initial] [dict get $cl labels] [dict get $cl nclusters]]
        dict set r measures merge_msd [::VMDance::Measure::merge_msd $c [dict get $cl labels] [dict get $cl initial] $tree ::VMDance::Job::cancelled]
    }
    dict set r extras {}
    dict set r digest [dict get $c digest]
    dict set r shape [_shape $c]
    dict set r seconds [format %.2f [expr {([clock milliseconds] - $t0) / 1000.0}]]
    dict set r created [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
    return $r
}

proc ::VMDance::Job::_do_cluster {req} {
    set t0 [clock milliseconds]
    check_available [dict get $req algorithm]
    set c [_coords $req]
    set cl [_cluster $c $req 0.4 0.95]
    if {[dict get $req algorithm] eq "helm"} { set cl [lindex [_clustered_scores $c [list $cl] 0.95] 0] }
    _result $c $req $cl $t0
}

# What tells the frames an extraction read once they are moved in place
# rigidly (an alignment): each one's radius of gyration, as VMD measures it
# (a float: 7 digits; Results::_same_shape).
proc ::VMDance::Job::_shape {c} {
    lmap fp [dict get $c fp] {format %.7g [lindex $fp 3]}
}

# A scan's record: {status message k nclusters ch db sizes clustering}
# (nclusters: the clusters with frames; its clustering keeps the backend's).
proc ::VMDance::Job::_record {cl} {
    dict create status ok message "" nclusters [llength [lsearch -all -not -exact [dict get $cl sizes] 0]] \
        ch [dict get $cl ch] db [dict get $cl db] sizes [dict get $cl sizes] clustering $cl
}
proc ::VMDance::Job::_failed {msg} {
    dict create status error message $msg nclusters "" ch "" db "" sizes {} clustering {}
}
# The coordinates read again for a result or a scan must be those it was
# made from (their fingerprints' digest, in its version). (Frames before
# them the molecule did not have then, a PDB's own frame read again, move
# them: deleting those gives them back.)
proc ::VMDance::Job::_same_coords {c r what} {
    if {[dict exists $r digest] && [dict get $r digest] ne "" && ![::VMDance::Coords::same $c [dict get $r digest]]} {
        set m [dict get $c mol]
        set k [::VMDance::Results::extra_before $m $r]
        if {$k > 0} {
            error "the coordinates of molecule $m changed since $what was made: it has $k frame[expr {$k == 1 ? "" : "s"}] before its frames that it did not have then (a PDB's own frame?): delete [expr {$k == 1 ? "it" : "them"}] (animate delete beg 0 end [expr {$k - 1}] $m)"
        }
        error "the coordinates of molecule $m changed since $what was made (moved, or another trajectory): make it again"
    }
}
# A scan as published: with the backend of the whole job (its tables say
# which).
proc ::VMDance::Job::_scan {kind req recs t0 {digest ""}} {
    variable backend
    set keys [expr {$kind eq "elbow" ? {mol sel fit first last step atoms fitatoms algorithm metric params ks radii stability} : {mol sel fit first last step atoms fitatoms}}]
    dict create format 1 kind $kind request [dict filter $req key {*}$keys] \
        molecule [_molecule $req] frames [dict get $req frames] \
        natoms [dict get $req natoms] records $recs digest $digest backend $backend \
        seconds [format %.2f [expr {([clock milliseconds] - $t0) / 1000.0}]] \
        created [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
}

# How much a clustering at k (cl, of req's seeding) depends on its seeding:
# the mean adjusted Rand index of every two clusterings of the seedings of
# req's stability (cl for its own; a seeding that cannot run at k left
# out); "" when fewer than two ran.
proc ::VMDance::Job::_stability {c req cl lo hi} {
    variable cancelled
    set own [dict get $req params kinit]
    set labs {}
    set seeds [dict get $req stability]
    set n [llength $seeds]
    set j 0
    foreach s $seeds {
        if {$s eq $own} {
            lappend labs [dict get $cl labels]
        } else {
            set q $req
            dict set q params kinit $s
            set a [expr {$lo + ($hi - $lo) * $j / $n}]
            if {[catch {_cluster $c $q $a $hi} o]} {
                if {$cancelled} { error "cancelled" }
            } else {
                lappend labs [dict get $o labels]
            }
        }
        incr j
    }
    if {[llength $labs] < 2} { return "" }
    set sum 0.0; set m 0
    for {set x 0} {$x < [llength $labs]} {incr x} {
        for {set y [expr {$x + 1}]} {$y < [llength $labs]} {incr y} {
            set v [::VMDance::Measure::ari [lindex $labs $x] [lindex $labs $y]]
            # (two clusterings that both put every frame in one cluster agree)
            set sum [expr {$sum + ($v eq "" ? 1.0 : $v)}]
            incr m
        }
    }
    format %.4f [expr {$sum / $m}]
}

# An elbow scan: the same clustering at every k of ks (HELM starts from
# the same clusters at every k). A k that fails is kept, and the scan goes
# on.
proc ::VMDance::Job::_do_elbow {req} {
    variable cancelled; variable backend
    set t0 [clock milliseconds]
    check_available [dict get $req algorithm]
    set c [_coords $req 0.0 0.2]
    # (what the library cannot take refuses the scan, not each k)
    if {[lindex $backend 0] eq "library"} { _library_takes $c }
    set ks [dict get $req ks]
    # (eQUAL: its radius at each value, no k)
    set radii [::VMDance::_get $req radii {}]
    if {[llength $radii]} { set ks $radii }
    set initial ""
    set lo 0.2
    if {[dict get $req algorithm] eq "helm"} {
        variable inner [list 0.2 0.3]
        set initial [_initial $c $req]
        set lo 0.3
    }
    set recs {}
    set n [llength $ks]
    set i 0
    set ran 0
    # (HELM's records are scored at the end)
    set hi [expr {[dict get $req algorithm] eq "helm" ? 0.95 : 1.0}]
    set invalid [::VMDance::_get $req invalid {}]
    foreach k $ks {
        if {$cancelled} { error "cancelled" }
        if {[dict exists $invalid $k]} {
            lappend recs [dict merge [dict create k $k] [_failed "not run: [dict get $invalid $k]"]]
            incr i
            continue
        }
        if {[llength $radii]} {
            dict set req params threshold $k
            dict set req k ""
            set at [dict create k "" radius $k]
        } else {
            dict set req k $k
            set at [dict create k $k]
        }
        set a [expr {$lo + ($hi - $lo) * $i / $n}]; set b [expr {$lo + ($hi - $lo) * ($i + 1) / $n}]
        if {[catch {_cluster $c $req $a $b $initial} cl opts]} {
            if {$cancelled} { error "cancelled" }
            # (a k that HELM's starting clusters cannot take: not run)
            if {[dict get $opts -errorcode] eq {VMDANCE NOTRUN}} { set why $cl; set cl "not run: $cl" } else { incr ran }
            lappend recs [dict merge $at [_failed $cl]]
        } else {
            incr ran
            set rec [dict merge $at [_record $cl]]
            if {[llength [::VMDance::_get $req stability {}]]} { dict set rec stability [_stability $c $req $cl $a $b] }
            lappend recs $rec
        }
        incr i
    }
    if {!$ran && [info exists why]} { error "no value of k can be run: [_scan_says $why]" }
    set recs [_scan_scores $c $recs [dict get $req algorithm] $hi]
    dict set req k ""
    if {[llength $radii]} { dict set req params threshold "" }
    _scan elbow $req $recs $t0 [dict get $c digest]
}

# A sweep: every configuration, one after the other.
proc ::VMDance::Job::_do_sweep {req} {
    variable cancelled; variable backend
    set t0 [clock milliseconds]
    set have [::VMDance::Backend::algorithms]
    # (asked again before a configuration is refused: check_available)
    foreach cf [dict get $req configs] {
        if {[dict get $cf algorithm] ni $have} { set have [::VMDance::Backend::algorithms 1]; break }
    }
    set c [_coords $req 0.0 0.1]
    if {[lindex $backend 0] eq "library"} { _library_takes $c }
    set configs [dict get $req configs]
    set recs {}
    set n [llength $configs]
    set i 0
    set ran 0
    # (HELM's records are scored at the end)
    set hi [expr {"helm" in [lmap cf $configs {dict get $cf algorithm}] ? 0.95 : 1.0}]
    foreach cf $configs {
        if {$cancelled} { error "cancelled" }
        set a [expr {0.1 + ($hi - 0.1) * $i / $n}]; set b [expr {0.1 + ($hi - 0.1) * ($i + 1) / $n}]
        if {[dict exists $cf error]} {
            set why [dict get $cf error]
            set rec [_failed "not run: $why"]
            set cf [dict remove $cf error]
        } elseif {[dict get $cf algorithm] ni $have} {
            set why "[::VMDance::Algo::label [dict get $cf algorithm]] is not in this build of the backend"
            set rec [_failed "not in this build of the backend"]
        } elseif {[catch {_cluster $c [dict merge $req $cf] $a $b} cl opts]} {
            if {$cancelled} { error "cancelled" }
            if {[dict get $opts -errorcode] eq {VMDANCE NOTRUN}} { set why $cl; set cl "not run: $cl" } else { incr ran }
            set rec [_failed $cl]
        } else {
            incr ran
            set rec [_record $cl]
        }
        lappend recs [dict merge $cf $rec]
        incr i
    }
    # (a sweep where nothing ran is refused, as an elbow is: the one there
    # was is kept)
    if {!$ran} { error "no configuration can be run: [_scan_says $why]" }
    set recs [_scan_scores $c $recs "" $hi]
    _scan sweep $req $recs $t0 [dict get $c digest]
}

# A scan's record as a whole result: req {scan record}.
proc ::VMDance::Job::_do_adopt {req} {
    set t0 [clock milliseconds]
    set s [dict get $req scan]
    set rec [dict get $req record]
    if {[dict get $rec status] ne "ok"} { error "that configuration failed: [dict get $rec message]" }
    set in [_input_of [dict get $s request] [dict get $s frames] [dict get $s natoms]]
    set c [_coords $in 0.0 0.8]
    _same_coords $c $s "the scan"
    set q [dict merge $in [dict filter [dict get $s request] key algorithm metric params]]
    foreach key {algorithm k metric params} { if {[dict exists $rec $key]} { dict set q $key [dict get $rec $key] } }
    if {[dict exists $rec radius]} { dict set q params threshold [dict get $rec radius]; dict set q k "" }
    _result $c $q [dict get $rec clustering] $t0
}

# A session of the MDANCE plugin made a result: req {candidates answer file
# explicit known molframes algorithm k metric params nstart unrecorded
# warnings} (import_request), candidates the molecules it may be of, each
# its input checked and exact when it has the name and frames the file
# recorded (Session::old_candidates: the one the file names first). The
# first whose coordinates give the clusters' MSDs the file holds (MDANCE's,
# of the rows the plugin gave its backend) is taken, and the plugin's
# measures are computed from them; one given with -mol (explicit) is taken
# whatever they give, with a warning. Returns {result warnings}, or {result
# {} warnings refused {why text}} when no molecule is taken, why differ
# (none loaded has the coordinates it clustered) or untold (which cannot be
# told): the command and the window say what to do.
proc ::VMDance::Job::_do_import {req} {
    variable cancelled
    set t0 [clock milliseconds]
    set cands [dict get $req candidates]
    set explicit [dict get $req explicit]
    set warnings [::VMDance::_get $req warnings {}]
    set n [llength $cands]
    set nexact [llength [lsearch -all -exact [lmap in $cands {::VMDance::_get $in exact 0}] 1]]
    set i 0
    set tried {}
    set take ""
    foreach in $cands {
        set m [dict get $in mol]
        # (a molecule whose frames cannot be read is not the one: the next is
        # tried; the frames are the file's, none can be left out)
        if {[catch {_coords $in [expr {0.6 * $i / $n}] [expr {0.6 * ($i + 1) / $n}]} c opts]} {
            if {$cancelled} { return -options $opts $c }
            regsub {^-first, -last, -step: (frame [0-9]+) of molecule [0-9]+ } $c {\1 } c
            regsub {: leave the frame out, or delete it \(animate delete beg [0-9]+ end [0-9]+ [0-9]+\)$} $c "" c
            if {$explicit} { error "molecule $m: $c" }
            lappend tried "molecule $m: $c"
            set differ 1
            incr i
            continue
        }
        set cl [output [dict get $req answer] [llength [dict get $c frames]]]
        lassign [_msd_agree $c $cl] agree how
        if {$agree eq "1"} {
            set rf [::VMDance::_get $req molframes ""]
            if {$rf ne "" && [molinfo $m get numframes] != $rf} {
                lappend warnings "molecule $m has [molinfo $m get numframes] frames, the MDANCE plugin's $rf: taken, its frames give the file's cluster MSDs"
            }
            set take [list $c $cl $in]
            break
        }
        if {$explicit} {
            if {$agree eq "0"} {
                lappend warnings "molecule $m was taken as asked, though its coordinates do not give the file's cluster MSDs ($how): it may not be the molecule that was clustered, or its frames have moved since"
            } else {
                lappend warnings "molecule $m was taken as asked, unchecked: $how"
            }
            set take [list $c $cl $in]
            break
        }
        # (nothing to compare: taken only when it is the one molecule of the
        # name and frames the file recorded)
        if {$agree eq "" && $nexact == 1 && [::VMDance::_get $in exact 0] && [dict get $req known]} {
            lappend warnings "molecule $m was taken for its name and frames, unchecked: $how"
            set take [list $c $cl $in]
            break
        }
        lappend tried "molecule $m: $how"
        if {$agree eq "0"} { set differ 1 }
        incr i
    }
    if {$take eq ""} {
        if {[info exists differ]} {
            return [dict create result {} warnings $warnings refused [list differ "no molecule loaded has the coordinates it clustered ([join $tried {; }])"]]
        }
        return [dict create result {} warnings $warnings refused [list untold "which molecule it clustered cannot be told ([join $tried {; }])"]]
    }
    lassign $take c cl in
    if {[dict get $req algorithm] eq "helm"} { set cl [lindex [_clustered_scores $c [list $cl] 0.6] 0] }
    # (HELM's merges as the MDANCE plugin kept them, what cannot be placed
    # without its starting clusters left out)
    if {[llength [dict get $cl zmatrix]]} {
        lassign [::VMDance::Session::old_merges $cl [dict get $req params] [::VMDance::_get $req nstart ""]] z why
        dict set cl zmatrix $z
        if {$why ne ""} { lappend warnings $why }
    }
    dict set cl initial {}
    # (what the file does not record is said of the run: Export::header)
    set u [::VMDance::_get $req unrecorded {}]
    if {[llength $u]} { dict set cl unrecorded $u }
    dict set cl backend [list imported [dict get $req file]]
    foreach k {algorithm k metric params} { dict set in $k [dict get $req $k] }
    dict create result [_result $c $in $cl $t0] warnings $warnings
}
# Whether the rows c give the cluster MSDs of a clustering cl (an MDANCE
# plugin's file: its backend's numbers, of 6 digits or more): {1|0|"" how},
# "" when nothing can be compared (no MSD, or no cluster of two frames).
proc ::VMDance::Job::_msd_agree {c cl} {
    set file [dict get $cl msd]
    set sizes [dict get $cl sizes]
    set k [dict get $cl nclusters]
    set top 0.0
    set some 0
    for {set j 0} {$j < $k} {incr j} {
        set a [lindex $file $j]
        if {$a eq "" || [lindex $sizes $j] < 2} continue
        set some 1
        set top [expr {max($top, abs($a))}]
    }
    if {!$some} { return [list "" "the file has no cluster MSD of two frames or more to compare"] }
    set mine [::VMDance::Measure::cluster_msd $c [dict get $cl labels] $k [dict get $c natoms] ::VMDance::Job::cancelled]
    for {set j 0} {$j < $k} {incr j} {
        set a [lindex $file $j]
        if {$a eq "" || [lindex $sizes $j] < 2} continue
        set b [lindex $mine $j]
        if {abs($a - $b) > 1e-4 * max(abs($a), abs($b)) + 1e-9 * $top} {
            return [list 0 "cluster $j's MSD is [format %.6g $b] there, [format %.6g $a] in the file"]
        }
    }
    list 1 ""
}

# PRIME on a result's clusters: req {result params}. Its seven answers, as
# rows of the clustering (-1: none).
proc ::VMDance::Job::_do_prime {req} {
    set res [dict get $req result]
    set c [_coords [_input_of [dict get $res request] [dict get $res frames] [dict get $res natoms]] 0.0 0.5]
    _same_coords $c $res "the clustering"
    set nf [llength [dict get $c frames]]
    set p [dict get $req params]
    variable inner {0.5 1.0}
    set r [_call $c [list prime [dict get $p metric] [dict get $p trim-frac] [dict get $p weighted] [dict get $res labels]] PRIME]
    set out [dict create params $p]
    foreach key {pairwise union medoid outlier medoidAll medoidC0 medoidC0Trimmed} {
        if {![dict exists $r $key]} { error "PRIME's result has no \"$key\"" }
        dict set out $key [lindex [_ints "PRIME's $key" [list [dict get $r $key]] 1 -1 [expr {$nf - 1}]] 0]
    }
    return $out
}

# The extended similarity (iSIM) of the frames, of each cluster, and each
# cluster's least similar frame: req {result params}.
proc ::VMDance::Job::_do_similarity {req} {
    set res [dict get $req result]
    set c [_coords [_input_of [dict get $res request] [dict get $res frames] [dict get $res natoms]] 0.0 0.5]
    _same_coords $c $res "the clustering"
    set nf [llength [dict get $c frames]]
    set k [dict get $res nclusters]
    variable inner {0.5 1.0}
    set r [_call $c [list analysis [dict get $req params metric] [dict get $res labels]] "Similarity"]
    if {![dict exists $r isim]} { error "the similarity result has no \"isim\"" }
    set ci [expr {[dict exists $r clusterISIM] ? [dict get $r clusterISIM] : {}}]
    set co [expr {[dict exists $r clusterOutliers] ? [dict get $r clusterOutliers] : {}}]
    # (the backend counts clusters up to the largest label)
    if {[llength $ci] > $k || [llength $co] > $k} { error "the similarity result has more clusters than the clustering" }
    while {[llength $ci] < $k} { lappend ci "" }
    while {[llength $co] < $k} { lappend co -1 }
    # (and gives a cluster without frames before the last one 0: none)
    set ci [lmap v $ci s [dict get $res sizes] {if {$s} { set v } else { list }}]
    set co [lmap v $co s [dict get $res sizes] {if {$s} { set v } else { list -1 }}]
    dict create params [dict get $req params] isim [_num [dict get $r isim]] \
        cluster [lmap v $ci {_num $v}] outliers [_ints "similarity outliers" $co $k -1 [expr {$nf - 1}]]
}

# The frames of a result on their first two principal components: req
# {result params}.
proc ::VMDance::Job::_do_map {req} {
    set res [dict get $req result]
    set c [_coords [_input_of [dict get $res request] [dict get $res frames] [dict get $res natoms]] 0.0 0.3]
    _same_coords $c $res "the clustering"
    set p [dict get $req params]
    set m [::VMDance::Measure::pca $c [dict get $p sample] ::VMDance::Job::cancelled \
        [list apply {{f m} { ::VMDance::Job::_progress [expr {0.3 + 0.7 * $f}] $m }}]]
    dict merge [dict create params $p] $m
}

# A result's profiles, atom by atom: req {result params groups}, groups
# the result's ({names of}, or {}). The atoms' residues are kept with
# them, as the molecule has them, so that they are drawn without it.
proc ::VMDance::Job::_do_profiles {req} {
    set res [dict get $req result]
    set k [dict get $res nclusters]
    set natoms [dict get $res natoms]
    set g [dict get $req groups]
    set names [::VMDance::_get $g names {}]
    set of [::VMDance::_get $g of {}]
    set most $::VMDance::Measure::profiles_most
    if {(2 * $k + [llength $names]) * $natoms > $most} {
        error "the profiles of $k clusters[expr {[llength $names] ? " and [llength $names] groups" : ""}] over $natoms atoms take more than $most numbers: cluster into fewer, or select fewer atoms"
    }
    set ref [dict get $req params reference]
    if {$ref < 0} { set ref [largest [dict get $res sizes]] }
    if {$ref >= $k || [lindex [dict get $res sizes] $ref] == 0} { error "cluster $ref has no frames: it cannot be the reference" }
    set in [_input_of [dict get $res request] [dict get $res frames] $natoms]
    set c [_coords $in 0.0 0.3]
    _same_coords $c $res "the clustering"
    # (the atoms that were read, in their order: the rows')
    set s [::VMDance::Mol::sel [dict get $in mol] [::VMDance::_get $in atoms [dict get $in sel]]]
    try {
        set info [$s get {resid chain}]
    } finally {
        ::VMDance::Mol::free $s
    }
    set p [::VMDance::Measure::profiles $c [dict get $res labels] $k $of [llength $names] $ref ::VMDance::Job::cancelled \
        [list apply {{f m} { ::VMDance::Job::_progress [expr {0.3 + 0.7 * $f}] $m }}]]
    dict merge [dict create params [dict create reference $ref] reference $ref \
        residues [lmap a $info {lindex $a 0}] chains [lmap a $info {lindex $a 1}] group_names $names] $p
}
# The most populated cluster (of equal sizes, the first).
proc ::VMDance::Job::largest {sizes} {
    set best 0
    set i 0
    foreach n $sizes { if {$n > [lindex $sizes $best]} { set best $i }; incr i }
    return $best
}

# Frames picked without clustering: req {input... params}.
# How many frames a pick asks for, checked against nf frames: diversity
# a whole percentage, 1 to 100 (CPP-MDANCE reads a number below 1 as a
# share: 0.5 picked half the frames; and drops the decimals), the outliers
# and a representative sample a share (below 1) or a number of frames, at
# most every frame: the outliers' share holds a frame at least (the
# backend picks one frame for a sample whose share holds none).
proc ::VMDance::Job::check_pick {p nf} {
    set v [dict get $p param]
    switch -- [dict get $p method] {
        diversity {
            if {$v < 1 || $v > 100 || $v != int($v)} { error "-param: the most diverse frames are a whole percentage of the frames, at least 1 and at most 100 (got $v)" }
            # (Algo::check_combination: the diversity selection reads past
            # the backend's data with another index)
            if {[::VMDance::_get $p metric MSD] ne "MSD"} {
                error "-metric [dict get $p metric] with -method diversity: CPP-MDANCE's diversity selection reads past its data with an index other than MSD; use -metric MSD, or another -method"
            }
        }
        outliers - repsample {
            if {$v <= 0 || ($v >= 1 && ($v != int($v) || $v > $nf))} {
                error "-param: a share of the frames (below 1) or a number of them, at most the $nf frames (got $v)"
            }
            # (as the backend counts the outliers: the share's frames, rounded
            # down; a sample is one frame at least)
            if {[dict get $p method] eq "outliers" && $v < 1 && int($v * $nf) < 1} {
                error "-param $v: a share of the $nf frames that holds no frame; give a number of frames, 1 to $nf, or a larger share"
            }
        }
    }
}
proc ::VMDance::Job::_do_pick {req} {
    set c [_coords $req 0.0 0.5]
    set nf [llength [dict get $c frames]]
    set p [dict get $req params]
    check_pick $p $nf
    variable inner {0.5 1.0}
    set r [_call $c [list select [dict get $p metric] [dict get $p method] [dict get $p param] [dict get $p nbins]] "Picking frames"]
    if {![dict exists $r indices]} { error "the frame selection has no \"indices\"" }
    set idx [_ints "picked frames" [dict get $r indices] "" 0 [expr {$nf - 1}]]
    # (every method picks a frame once: one picked twice is a backend that
    # read past its data)
    set once [llength [lsort -integer -unique $idx]]
    if {$once != [llength $idx]} { error "the backend picked a frame more than once ([llength $idx] picks of $once frames)" }
    # (what tells their frames, as a clustering's: their numbers are VMD's
    # only while the molecule has them, Results::picks_ok)
    dict create params $p input [dict filter $req key mol sel fit first last step atoms fitatoms] \
        molecule [_molecule $req] frames [dict get $c frames] \
        rows $idx vmdframes [lmap i $idx {lindex [dict get $c frames] $i}] \
        digest [dict get $c digest] shape [_shape $c] \
        backend [dict get $r _backend] created [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"]
}

# The molecule a request was checked on (recorded then: it may have been
# deleted since, while the backend ran).
proc ::VMDance::Job::_molecule {req} {
    if {[dict exists $req molecule] && [dict size [dict get $req molecule]]} { return [dict get $req molecule] }
    ::VMDance::Mol::record [dict get $req mol]
}

# The input of a request made again, to read its coordinates: the
# molecule must be loaded, with the same frames (frames added after them
# change nothing: -last -1 is the last frame clustered), and the atoms that
# were read (natoms of them), not those its texts select now ("beta > 0"
# may be others); its texts are kept, as typed, for the tables and Setup.
proc ::VMDance::Job::_input_of {q frames natoms} {
    set m [dict get $q mol]
    if {![::VMDance::Mol::exists $m]} { error "the clustered molecule is not loaded (reopen it, or load the session with its molecule)" }
    dict set q last [lindex $frames end]
    set in [dict filter $q key mol sel fit first last step]
    set atoms [dict exists $q atoms]
    if {$atoms} {
        dict set in sel [dict get $q atoms]
        dict set in fit [::VMDance::_get $q fitatoms ""]
    }
    set nope "molecule $m does not have the $natoms atoms that were clustered: load the molecule that was"
    if {[catch {check_input $in} req]} {
        if {$atoms && [regexp {^-(sel|fit): } $req]} { error $nope }
        error $req
    }
    if {[dict get $req frames] ne $frames} { error "molecule $m no longer has the frames that were clustered" }
    if {[dict get $req natoms] != $natoms} { error $nope }
    dict set req sel [dict get $q sel]
    dict set req fit [dict get $q fit]
    return $req
}
