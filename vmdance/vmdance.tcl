#
# VMDance - MDANCE clustering of a trajectory, in VMD
#
#   GUI:        Extensions > Analysis > VMDance, or `vmdance`
#   Scripting:  vmdance -mol top -sel "name CA" -first 0 -last -1 -step 1 ?-fit sel? \
#                   -algorithm kmeans|divine|helm|equal ?-k n? ?-metric MSD? ?parameters? ?-label text? ?-quiet 1?
#               vmdance info | algorithms | parameters ?algorithm? | cancel
#               vmdance backend ?-mode auto|cli|library? ?-cli path? ?-library path? | backend try ?options?
#               vmdance clusters | get c | labels | frame f
#               vmdance transitions ?-lag n? ?-counts 1? | residence | silhouette | distances | tree
#               vmdance elbow ?-ks {k ...} | -from a -to b -by s? ?-stability 0|1|{seedings}? ?clustering options?
#               vmdance elbow -algorithm equal -radii {r ...} ?clustering options?
#               vmdance elbow show | elbow load k | elbow clear
#               vmdance sweep -algorithms {...} -ks|-from/-to/-by -metrics {...} -seedings {...} ?-params {a {...}}?
#               vmdance sweep show | sweep best ?ch|db? | sweep load n | sweep clear
#               vmdance prime ?-metric RR|SM? ?-trim-frac f? ?-weighted 0|1?
#               vmdance similarity ?-metric m?
#               vmdance groups | groups -ranges {name frames ...} | groups -file f.csv | groups -names {...}
#                 (and -colours {name #rrggbb ...}, or alone) | groups clear
#               vmdance makeup ?-by cluster|group?
#               vmdance map ?-sample n? | map show
#               vmdance profiles ?-reference c? | profiles show
#               vmdance pick ?-method m? ?-param p? ?-nbins n? ?-metric m? ?input options? | pick show
#               vmdance pick goto f | pick save file ?-format pdb|dcd? ?-sel text? | pick clear
#               vmdance select ?c ...? | select add|toggle c ... | select clear|all
#               vmdance draw ?-colour 0|1? ?-reps 0|1? ?-overlay 0|1? ?-picks 0|1? ?-style s? ?-sel text?
#                            ?-top n? ?-frames "0-100,500"? ?-material m?
#               vmdance goto c | goto -frame f | userfield ?-sel text?
#               vmdance runs | run id | run delete id | run label id text | run clear
#               vmdance export dir ?-prefix p? ?-items {...}? ?-top n? ?-lag n? ?-format pdb|dcd? ?-sel text?
#               vmdance session save file | session load file ?-mol auto|load|none|molid?
#               vmdance figures dir ?-plots {...}? ?-formats {pdf png}? ?-text points? ...
#
# A cluster is its number (0 ...); a frame is VMD's frame number.
#

# (a VMD with Tcl 8.5 reads this far: told what it needs, not only Tcl's
# version conflict)
if {![package vsatisfies [info patchlevel] 8.6]} {
    error "VMDance needs a VMD with Tcl 8.6, as VMD 2 has (this one has Tcl [info patchlevel])"
}
package require Tcl 8.6
package provide vmdance 1.0a1

# Loaded once per VMD: "package forget" then "package require" again
# would start every module afresh under the runs, the drawing and a job
# that are still there. (To load changed sources, restart VMD.)
if {[info exists ::VMDance::loaded]} return

namespace eval ::VMDance {
    variable version 1.0a1
    variable libdir [file join [file dirname [file normalize [info script]]] lib]
    # PRIME's answers, in the order they are listed: key, label, kind
    variable prime_rows {
        medoidAll "Medoid of all frames" baseline
        medoidC0 "Medoid of the largest cluster" baseline
        medoidC0Trimmed "… trimmed" baseline
        pairwise "PRIME: pairwise" prediction
        union "PRIME: union" prediction
        medoid "PRIME: medoid" prediction
        outlier "PRIME: outlier" prediction
    }
}

# The modules hold display glyphs (Å, ×, …): read them as UTF-8 whatever
# the system encoding is; sourced at the global level without leaving a
# variable there.
apply {{dir} {
    foreach f {json.tcl molecule.tcl algorithms.tcl prefs.tcl backend.tcl coords.tcl measures.tcl analysis.tcl
               results.tcl session.tcl export.tcl viz3d.tcl} {
        if {[file exists [file join $dir $f]]} {
            uplevel #0 [list source -encoding utf-8 [file join $dir $f]]
        }
    }
}} $::VMDance::libdir

set ::VMDance::loaded 1

# Tk parts are loaded lazily: text-mode VMD has no Tk. (who: what needs
# it; advice: what to do without it)
proc ::VMDance::_load_tk {{who "the window"} {advice "in text-mode VMD, use the command (vmdance -sel … and its subcommands)"}} {
    if {[namespace exists ::VMDance::GUI]} return
    if {[catch {package require Tk 8.5} err]} {
        error "$who needs Tk and a display ($err): $advice"
    }
    foreach f {fonts.tcl theme.tcl tooltip.tcl colormaps.tcl icons.tcl plotlib.tcl plots.tcl plots_groups.tcl
               figures.tcl gui.tcl gui_opts.tcl gui_io.tcl} {
        if {[file exists [file join $::VMDance::libdir $f]]} {
            uplevel #0 [list source -encoding utf-8 [file join $::VMDance::libdir $f]]
        }
    }
}

# Menu callback for vmd_install_extension; must return the toplevel.
proc vmdance_tk {} {
    ::VMDance::_load_tk
    ::VMDance::GUI::show
}

proc vmdance {args} {
    if {[llength $args] == 0} { return [vmdance_tk] }
    set sub [lindex $args 0]
    if {[string match -* $sub]} { return [::VMDance::_api_cluster {*}$args] }
    set cmds {info algorithms parameters backend cancel clusters get labels frame transitions residence
              silhouette distances tree elbow sweep prime similarity groups makeup map profiles pick select draw
              goto userfield runs run export session figures}
    if {$sub ni $cmds} {
        error "vmdance: unknown subcommand \"$sub\" (valid: [join $cmds {, }], or -option value pairs to cluster)"
    }
    ::VMDance::_api_$sub {*}[lrange $args 1 end]
}

#---------------------------------------------------------------------------
# Helpers
#---------------------------------------------------------------------------

# Parse "-name value" pairs against a dict of defaults.
proc ::VMDance::_opts {what defaults argl} {
    if {[llength $argl] % 2} { error "$what: options must come in -name value pairs (got: $argl)" }
    set seen {}
    foreach {k v} $argl {
        if {$k in $seen} { error "$what: $k is given twice" }
        lappend seen $k
        if {![dict exists $defaults $k]} {
            error "$what: unknown option $k (valid: [join [dict keys $defaults] {, }])"
        }
        dict set defaults $k $v
    }
    return $defaults
}

proc ::VMDance::_say {quiet msg} {
    if {!$quiet} { puts "VMDance) $msg" }
}

# Whether v is a whole number written in decimal, as a person writes it
# (expr reads 010 as octal, 0x10 as hex; string is integer takes " 5").
proc ::VMDance::whole {v {signed 0}} {
    regexp [expr {$signed ? {^-?(0|[1-9][0-9]{0,15})$} : {^(0|[1-9][0-9]{0,15})$}}] $v
}

# A dictionary's value, else a default. (Not expr's ?: with a string a
# user typed: expr reads "NaN" as a number, and fails.)
proc ::VMDance::_get {d key default} {
    if {[dict exists $d $key]} { return [dict get $d $key] }
    return $default
}

proc ::VMDance::_bool {what v} {
    if {![string is boolean -strict $v]} { error "$what must be 0 or 1 (got \"$v\")" }
    expr {$v ? 1 : 0}
}

# While a job runs in the background, no command may read or replace
# the results.
proc ::VMDance::_check_idle {what} {
    if {[::VMDance::Job::busy]} {
        error "$what: VMDance is running a job; wait for it or cancel it (vmdance cancel)"
    }
}
proc ::VMDance::_need_data {what} {
    _check_idle $what
    if {![::VMDance::Results::has_data]} { error "$what: no clustering" }
}

proc ::VMDance::_gui_open {} {
    expr {[namespace exists ::VMDance::GUI] && [winfo exists $::VMDance::GUI::w]}
}

# Progress on the console, at most every 10% (and every 10 s: a long step,
# the measures of thousands of clusters, says how far it is).
proc ::VMDance::_console_progress {frac msg} {
    variable last_pct; variable last_said
    set p [expr {int($frac * 10)}]
    set now [clock milliseconds]
    if {![info exists last_pct] || $p != $last_pct || $now - $last_said >= 10000} {
        set last_pct $p
        set last_said $now
        if {$frac < 1.0} { puts "VMDance) [format %3d [expr {int(100 * $frac)}]]%  $msg" }
    }
}
# The progress of a step a command does not say it takes (a scan's run
# loaded, a session imported: quick for a few clusters), on the console
# only once it has taken 10 s, and then every 10 s (the measures of
# thousands of clusters). last_said: when the step started.
proc ::VMDance::_console_long {frac msg} {
    variable last_said
    if {[clock milliseconds] - $last_said >= 10000} { _console_progress $frac $msg }
}

# A cluster number of the current clustering.
proc ::VMDance::_cluster {what c} {
    set k [::VMDance::Results::nclusters]
    if {$k == 0} { error "$what: the clustering has no cluster (every frame is noise)" }
    if {![whole $c] || $c >= $k} { error "$what: no cluster \"$c\" (clusters: 0 to [expr {$k - 1}])" }
    return [expr {$c}]
}

# The input options of a request, and the clustering ones.
variable ::VMDance::input_opts {-mol top -sel "name CA" -fit "" -first 0 -last -1 -step 1}
variable ::VMDance::cluster_opts {-algorithm kmeans -k "" -metric MSD}

# Split -option value pairs into a request: the known options, and the
# rest as the algorithm's parameters.
proc ::VMDance::_request {what argl known} {
    if {[llength $argl] % 2} { error "$what: options must come in -name value pairs (got: $argl)" }
    set req {}; set params {}; set extra {}
    set seen {}
    # (every algorithm's parameters: a name none has is no option at all)
    set any {}
    foreach a [::VMDance::Algo::all] { lappend any {*}[::VMDance::Algo::param_names $a] }
    foreach {k v} $argl {
        if {[string index $k 0] ne "-"} { error "$what: \"$k\" is not an option" }
        if {$k in $seen} { error "$what: $k is given twice" }
        lappend seen $k
        if {![dict exists $known $k] && ![dict exists $::VMDance::input_opts $k] && ![dict exists $::VMDance::cluster_opts $k] &&
            [string range $k 1 end] ni $any} {
            error "$what: unknown option $k (the options: [join [concat [dict keys $::VMDance::input_opts] [dict keys $::VMDance::cluster_opts] [dict keys $known]] {, }], and the algorithm's parameters: vmdance parameters algorithm)"
        }
        if {[dict exists $known $k]} {
            dict set extra $k $v
        } elseif {[dict exists $::VMDance::input_opts $k] || [dict exists $::VMDance::cluster_opts $k]} {
            dict set req [string range $k 1 end] $v
        } else {
            dict set params [string range $k 1 end] $v
        }
    }
    dict set req params $params
    list $req [dict merge $known $extra]
}

#---------------------------------------------------------------------------
# vmdance -option value ...: cluster
#---------------------------------------------------------------------------

proc ::VMDance::_api_cluster {args} {
    set what vmdance
    lassign [_request $what $args {-quiet 0 -label ""}] req o
    set quiet [_bool "$what: -quiet" [dict get $o -quiet]]
    _check_idle $what
    if {[catch {::VMDance::Job::check_cluster $req} req]} { error "$what: $req" }
    set nf [llength [dict get $req frames]]
    _say $quiet "clustering $nf frames of [dict get $req sel] ([dict get $req natoms] atoms) of molecule [dict get $req mol] with [::VMDance::Algo::label [dict get $req algorithm]]"
    variable last_pct
    unset -nocomplain last_pct
    set pr [expr {$quiet ? "" : "::VMDance::_console_progress"}]
    if {[catch {::VMDance::Job::run cluster $req $pr} a]} { error "$what: $a" }
    ::VMDance::Results::publish $a [dict get $o -label]
    _say $quiet "[_summary] ([dict get $a seconds] s)"
    _api_info
}

proc ::VMDance::_summary {} {
    set k [::VMDance::Results::nclusters]
    set s "$k cluster[expr {$k == 1 ? "" : "s"}]"
    set n [::VMDance::Results::noise]
    if {$n} { append s ", $n noise frame[expr {$n == 1 ? "" : "s"}]" }
    set ch [::VMDance::Results::get ch]; set db [::VMDance::Results::get db]
    if {$ch ne ""} { append s ", Calinski–Harabasz [format %.4g $ch]" }
    if {$db ne ""} { append s ", Davies–Bouldin [format %.4g $db]" }
    set why [_fewer]
    if {$why ne ""} { append s " — $why" }
    return $s
}

# Why the current clustering has fewer clusters than the k asked ("" when
# it has not; the command's summary and the window's say it).
proc ::VMDance::_fewer {} {
    set k [::VMDance::Results::nclusters]
    set q [::VMDance::Results::request]
    if {[dict get $q k] eq "" || $k >= [dict get $q k]} { return "" }
    set p [dict get $q params]
    # (HELM merges all it has when it has k or fewer: say why, its trimming
    # or a first clustering that left that few)
    if {[dict get $q algorithm] eq "helm"} {
        if {[_get $p trim-start 0]} {
            return "fewer than the [dict get $q k] asked: the trimming left HELM k or fewer starting clusters"
        }
        # (an import has no starting clusters to count: why is not known)
        if {![llength [::VMDance::Results::get initial]]} { return "fewer than the [dict get $q k] asked" }
        set n [llength [lsort -unique [::VMDance::Results::get initial]]]
        return "fewer than the [dict get $q k] asked: HELM started from $n cluster[expr {$n == 1 ? "" : "s"}]"
    }
    # (DIVINE stops when no cluster can be split: by its smallest share,
    # which only the pair anchors' splits apply, else because the frames
    # left in each are the same)
    if {[dict get $q algorithm] eq "divine" && [_get $p end-mode k] eq "k"} {
        set t [_get $p threshold 0]
        set m [expr {max(1, round($t * [::VMDance::Results::nframes]))}]
        if {[_get $p anchors NANI] ne "NANI" && $m >= 2} {
            return "fewer than the [dict get $q k] asked: no split left $m frames or more on each side (-threshold $t)"
        }
        return "fewer than the [dict get $q k] asked: the clusters left could not be split (their frames are the same)"
    }
    return ""
}

# What the current clustering is.
proc ::VMDance::_api_info {args} {
    if {[llength $args]} { error "usage: vmdance info" }
    if {![::VMDance::Results::has_data]} { return {} }
    set a $::VMDance::Results::A
    set q [dict get $a request]
    set fr [dict get $a frames]
    dict create run $::VMDance::Results::current molid [dict get $q mol] sel [dict get $q sel] fit [dict get $q fit] \
        frames [llength $fr] first [lindex $fr 0] last [lindex $fr end] step [dict get $q step] natoms [dict get $a natoms] \
        algorithm [dict get $q algorithm] k [dict get $q k] metric [dict get $q metric] params [dict get $q params] \
        nclusters [dict get $a nclusters] sizes [dict get $a sizes] noise [::VMDance::Results::noise] \
        ch [dict get $a ch] db [dict get $a db] selected [::VMDance::Results::selected] \
        backend [::VMDance::Results::meta backend] seconds [::VMDance::Results::meta seconds] \
        unrecorded [_get $a unrecorded {}]
}

# The algorithms: {name {label about takes_k 0|1 available 0|1} ...}.
proc ::VMDance::_api_algorithms {args} {
    if {[llength $args]} { error "usage: vmdance algorithms" }
    set have {}
    catch {set have [::VMDance::Backend::algorithms]}
    # (asked again when one is missing: Job::check_available)
    if {[llength $have] < [llength [::VMDance::Algo::all]]} { catch {set have [::VMDance::Backend::algorithms 1]} }
    set out {}
    foreach a [::VMDance::Algo::all] {
        dict set out $a [dict create label [::VMDance::Algo::label $a] about [::VMDance::Algo::get $a about] \
            k [::VMDance::Algo::default_k $a] available [expr {$a in $have}]]
    }
    return $out
}

# An algorithm's parameters: {-name {type default limits label tip} ...}.
proc ::VMDance::_api_parameters {args} {
    if {[llength $args] > 1} { error "usage: vmdance parameters ?algorithm?" }
    if {[llength $args]} { set a [lindex $args 0] } else { set a kmeans }
    switch -- $a {
        prime { set specs $::VMDance::Algo::prime_params }
        similarity { set specs $::VMDance::Algo::similarity_params }
        pick { set specs $::VMDance::Algo::pick_params }
        default {
            if {![::VMDance::Algo::exists $a]} { error "vmdance parameters: no algorithm \"$a\" (valid: [join [::VMDance::Algo::all] {, }], or prime, similarity, pick)" }
            set specs [::VMDance::Algo::params $a]
        }
    }
    set out {}
    foreach p $specs { dict set out -[lindex $p 0] [lrange $p 1 end] }
    return $out
}

proc ::VMDance::_api_backend {args} {
    if {![llength $args]} { return [::VMDance::Backend::status] }
    # (what these options would give, kept for nothing: Settings' trial,
    # which a job running does not see)
    if {[lindex $args 0] eq "try"} {
        if {[catch {::VMDance::Backend::probe {*}[lrange $args 1 end]} r]} { error "vmdance backend try: $r" }
        return $r
    }
    _check_idle "vmdance backend"
    if {[catch {::VMDance::Backend::configure {*}$args} r]} { error "vmdance backend: $r" }
    if {[_gui_open]} { catch {::VMDance::GUI::backend_changed} }
    return $r
}

proc ::VMDance::_api_cancel {args} {
    if {[llength $args]} { error "usage: vmdance cancel" }
    ::VMDance::Job::cancel
}

#---------------------------------------------------------------------------
# Reading the clustering
#---------------------------------------------------------------------------

# clusters: {cluster frames percent msd msd_to_representative representative_frame} each
proc ::VMDance::_api_clusters {args} {
    set what "vmdance clusters"
    set o [_opts $what {-sort cluster} $args]
    _need_data $what
    set rows [::VMDance::Results::table]
    switch -- [dict get $o -sort] {
        cluster { }
        size { set rows [lsort -integer -decreasing -index 1 $rows] }
        msd { set rows [lsort -real -index 3 [lmap r $rows {if {[lindex $r 3] eq ""} { lset r 3 Inf }; set r}]]; set rows [lmap r $rows {if {[lindex $r 3] eq "Inf"} { lset r 3 "" }; set r}] }
        default { error "$what: -sort must be cluster, size or msd" }
    }
    return $rows
}

# get c: one cluster in full.
proc ::VMDance::_api_get {args} {
    set what "vmdance get"
    if {[llength $args] != 1} { error "usage: $what cluster" }
    _need_data $what
    cluster_info [_cluster $what [lindex $args 0]]
}
# Cluster c in full (the window reads it too, also while a job runs).
proc ::VMDance::cluster_info {c} {
    lassign [lindex [::VMDance::Results::table] $c] - n pct msd spread rep
    set sil [::VMDance::Results::measure silhouette]
    set s [lmap i [::VMDance::Results::members $c] {lindex $sil $i}]
    set s [lmap v $s {expr {$v eq "" ? [continue] : $v}}]
    set res [lindex [::VMDance::Export::residence_stats] $c]
    dict create cluster $c frames $n percent $pct msd $msd msd_to_representative $spread representative $rep \
        vmd_colour [::VMDance::Viz::colour_id $c] \
        silhouette [expr {[llength $s] ? [format %.4f [expr {[::tcl::mathop::+ {*}$s] / double([llength $s])}]] : ""}] \
        visits [lindex $res 1] mean_residence [format %.2f [lindex $res 2]] longest_residence [lindex $res 4] \
        members [::VMDance::Results::member_frames $c]
}

# labels: {frame cluster ...} of every clustered frame.
proc ::VMDance::_api_labels {args} {
    if {[llength $args]} { error "usage: vmdance labels" }
    _need_data "vmdance labels"
    set out {}
    foreach f [::VMDance::Results::frames] l [::VMDance::Results::labels] { lappend out $f $l }
    return $out
}

# frame f: the cluster of VMD frame f (that of the clustered frame at or
# before it): {frame f clustered f' cluster c}. VMD's frame f is the
# clustered frame f only while the molecule has the frames it had (as goto
# asks); not loaded, the clustering answers in its own numbers (as labels).
proc ::VMDance::_api_frame {args} {
    set what "vmdance frame"
    if {[llength $args] != 1 || ![whole [lindex $args 0]]} { error "usage: $what frame (a VMD frame: 0, 1 …)" }
    _need_data $what
    set m [dict get [::VMDance::Results::request] mol]
    if {[::VMDance::Mol::exists $m] && ![::VMDance::Results::frames_ok]} { error "$what: [::VMDance::Viz::why]" }
    set f [lindex $args 0]
    set i [::VMDance::Results::frame_index $f]
    set fr [::VMDance::Results::frames]
    if {$i < 0 || $f > [lindex $fr end]} { error "$what: frame $f is outside the clustered frames ([lindex $fr 0] to [lindex $fr end])" }
    dict create frame $f clustered [lindex $fr $i] cluster [lindex [::VMDance::Results::labels] $i]
}

# transitions: the k × k matrix of probabilities (rows: from; the share
# into noise is left out of the columns; "" in a row with nothing counted,
# as the export and the plot have it) or of counts.
proc ::VMDance::_api_transitions {args} {
    set what "vmdance transitions"
    set o [_opts $what {-lag 1 -counts 0} $args]
    _need_data $what
    set lag [dict get $o -lag]
    if {![regexp {^[1-9][0-9]*$} $lag]} { error "$what: -lag must be a whole number of clustered frames, 1 or more" }
    set T [::VMDance::Results::transitions $lag]
    if {[_bool "$what: -counts" [dict get $o -counts]]} { return $T }
    set labels [::VMDance::Results::labels]
    set k [::VMDance::Results::nclusters]
    set tonoise [lrepeat $k 0]
    for {set i 0} {$i + $lag < [llength $labels]} {incr i} {
        set a [lindex $labels $i]; set b [lindex $labels [expr {$i + $lag}]]
        if {$a >= 0 && $b < 0} { lset tonoise $a [expr {[lindex $tonoise $a] + 1}] }
    }
    set out {}
    foreach row $T n $tonoise {
        set tot [expr {[::tcl::mathop::+ 0 {*}$row] + $n}]
        lappend out [lmap v $row {expr {$tot ? [format %.4f [expr {double($v) / $tot}]] : ""}}]
    }
    return $out
}

# residence: {cluster visits mean min max} each (in clustered frames).
proc ::VMDance::_api_residence {args} {
    if {[llength $args]} { error "usage: vmdance residence" }
    _need_data "vmdance residence"
    lmap r [::VMDance::Export::residence_stats] { lset r 2 [format %.2f [lindex $r 2]]; set r }
}

# silhouette: {mean m clusters {c mean ...} frames {frame s ...}}.
proc ::VMDance::_api_silhouette {args} {
    if {[llength $args]} { error "usage: vmdance silhouette" }
    _need_data "vmdance silhouette"
    set sil [::VMDance::Results::measure silhouette]
    set all [lmap v $sil {expr {$v eq "" ? [continue] : $v}}]
    set per {}
    for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} {
        set s [lmap i [::VMDance::Results::members $c] {lindex $sil $i}]
        set s [lmap v $s {expr {$v eq "" ? [continue] : $v}}]
        dict set per $c [expr {[llength $s] ? [format %.4f [expr {[::tcl::mathop::+ {*}$s] / double([llength $s])}]] : ""}]
    }
    set fr {}
    foreach f [::VMDance::Results::frames] v $sil { lappend fr $f $v }
    dict create mean [expr {[llength $all] ? [format %.4f [expr {[::tcl::mathop::+ {*}$all] / double([llength $all])}]] : ""}] \
        clusters $per frames $fr
}

# distances: {centroids {k × k RMSD²} representatives {k × k RMSD}}.
proc ::VMDance::_api_distances {args} {
    if {[llength $args]} { error "usage: vmdance distances" }
    _need_data "vmdance distances"
    set why [::VMDance::Results::too_many distances]
    if {$why ne ""} { error "vmdance distances: $why" }
    set R [lmap row [::VMDance::Results::measure rep_msd] {lmap v $row {expr {$v eq "" ? "" : [format %.4g [expr {sqrt($v)}]]}}}]
    dict create centroids [::VMDance::Results::measure centroid_msd] representatives $R
}

# tree: {kind helm|linkage merges {{left right distance count} ...}}.
proc ::VMDance::_api_tree {args} {
    if {[llength $args]} { error "usage: vmdance tree" }
    _need_data "vmdance tree"
    if {[catch {::VMDance::Results::tree} t]} { error "vmdance tree: $t" }
    lassign $t how rows leaves base
    dict create kind $how merges $rows leaves $leaves
}

#---------------------------------------------------------------------------
# Scans
#---------------------------------------------------------------------------

# The values of k from -ks, or -from -to -by (args: the options given;
# at most limit values, counted before they are made).
proc ::VMDance::_ks {what o args_given limit} {
    set range [lmap {k v} $args_given {expr {$k in {-from -to -by} ? $k : [continue]}}]
    if {[dict get $o -ks] ne ""} {
        if {[llength $range]} { error "$what: -ks, or -from -to -by: not both" }
        if {![string is list [dict get $o -ks]]} { error "$what: -ks must be a list of values of k" }
        if {[llength [dict get $o -ks]] > $limit} { error "$what: -ks: at most $limit values (got [llength [dict get $o -ks]])" }
        return [dict get $o -ks]
    }
    foreach k {-from -to -by} {
        if {![regexp {^[1-9][0-9]{0,8}$} [dict get $o $k]]} { error "$what: $k must be a whole number from 1 to 999999999 (got \"[dict get $o $k]\")" }
    }
    if {[dict get $o -from] > [dict get $o -to]} { error "$what: -from must not be above -to" }
    set n [expr {([dict get $o -to] - [dict get $o -from]) / [dict get $o -by] + 1}]
    if {$n > $limit} { error "$what: -from -to -by give $n values of k; at most $limit" }
    set out {}
    for {set k [dict get $o -from]} {$k <= [dict get $o -to]} {incr k [dict get $o -by]} { lappend out $k }
    return $out
}

# A scan's records for the command: {k|config nclusters ch db sizes status message}.
proc ::VMDance::_scan_rows {s} {
    set i 0
    lmap r [dict get $s records] {
        set row [dict create index $i]
        incr i
        foreach key {algorithm k radius metric} { if {[dict exists $r $key]} { dict set row $key [dict get $r $key] } }
        if {[dict get $s kind] eq "sweep"} { dict set row seeding [::VMDance::Export::sweep_seeding $r] }
        foreach key {nclusters ch db sizes status message} { dict set row $key [dict get $r $key] }
        if {[dict exists $r stability]} { dict set row stability [dict get $r stability] }
        set row
    }
}

# What a scan reads, as it starts: its frames, atoms and molecule; and an
# algorithm with the parameters (and metric) that are not its defaults.
proc ::VMDance::_input_said {req} {
    set s "[llength [dict get $req frames]] frames of [dict get $req sel] ([dict get $req natoms] atoms) of molecule [dict get $req mol]"
    if {[dict get $req fit] ne ""} { append s ", fitted on [dict get $req fit]" }
    return $s
}
proc ::VMDance::_algo_said {a params metric} {
    set s [::VMDance::Algo::label $a]
    set d [::VMDance::Algo::defaults $a]
    dict for {k v} $params { if {![dict exists $d $k] || $v ne [dict get $d $k]} { append s " -$k $v" } }
    if {$metric ne "MSD"} { append s " -metric $metric" }
    return $s
}
# A scan takes its own options, the command's defaults where none is
# given, never the current run's (the window's Setup follows the run): a
# note says so when it reads other frames, atoms (keys) than the run.
proc ::VMDance::_scan_note {quiet req keys} {
    if {![::VMDance::Results::has_data]} return
    set q [::VMDance::Results::request]
    set same [expr {[::VMDance::Results::frames] eq [dict get $req frames]}]
    foreach key $keys { if {[_get $q $key ""] ne [_get $req $key ""]} { set same 0 } }
    if {$same} return
    set run "[dict get $q sel] ([dict get $::VMDance::Results::A natoms] atoms) of molecule [dict get $q mol]"
    if {"algorithm" in $keys} { append run ", [_algo_said [dict get $q algorithm] [dict get $q params] [dict get $q metric]]" }
    _say $quiet "note: not what run $::VMDance::Results::current clustered ($run): a scan takes its own options, the command's defaults where none is given"
}

proc ::VMDance::_api_elbow {args} {
    set what "vmdance elbow"
    switch -- [lindex $args 0] {
        show {
            if {[llength $args] != 1} { error "usage: $what show" }
            if {![dict size $::VMDance::Results::elbow]} { error "$what: no elbow scan" }
            return [_scan_rows $::VMDance::Results::elbow]
        }
        load {
            if {[llength $args] != 2} { error "usage: $what load k (or radius)" }
            _check_idle $what
            set e $::VMDance::Results::elbow
            if {![dict size $e]} { error "$what: no elbow scan" }
            set k [lindex $args 1]
            set rec [::VMDance::Results::elbow_record $e $k]
            if {![dict size $rec]} { error "$what: the scan has no [expr {[::VMDance::Results::by_radius $e] ? "radius" : "k ="} ] $k" }
            return [_adopt $what $e $rec]
        }
        clear {
            if {[llength $args] != 1} { error "usage: $what clear" }
            _check_idle $what
            ::VMDance::Results::set_elbow {}
            return
        }
    }
    lassign [_request $what $args {-quiet 0 -ks "" -from 2 -to 15 -by 1 -stability 0 -radii ""}] req o
    # (a -k of the clustering options would be dropped for the scan's)
    if {[dict exists $req k]} { error "$what: -k: a scan runs the values of k of -ks, or of -from -to -by" }
    set quiet [_bool "$what: -quiet" [dict get $o -quiet]]
    _check_idle $what
    if {[_get $req algorithm kmeans] eq "equal"} {
        # (eQUAL: its radius; -ks, -from, -to and -by are k's)
        if {[dict get $o -ks] ne "" || [llength [lmap {k v} $args {expr {$k in {-from -to -by} ? 1 : [continue]}}]]} {
            error "$what: eQUAL is given no k: scan its radius with -radii {0.5 1 2}"
        }
        dict set req radii [dict get $o -radii]
        set ks {}
    } elseif {[dict get $o -radii] ne ""} {
        error "$what: -radii is eQUAL's (-algorithm equal); [::VMDance::Algo::label [_get $req algorithm kmeans]] is scanned at values of k"
    } elseif {[catch {_ks $what $o $args 200} ks]} { error $ks }
    dict set req ks $ks
    # (-stability 1: NANI's seedings that draw no random number; 0 none; or a list)
    set st [dict get $o -stability]
    if {$st eq "1"} { set st $::VMDance::Algo::deterministic_kinits } elseif {$st eq "0"} { set st {} }
    dict set req stability $st
    if {[catch {::VMDance::Job::check_elbow $req} req]} { error "$what: $req" }
    set at [expr {[llength [_get $req radii {}]] ? "radius = [join [dict get $req radii] {, }]" : "k = [join [dict get $req ks] {, }]"}]
    _say $quiet "scanning [_algo_said [dict get $req algorithm] [dict remove [dict get $req params] threshold] [dict get $req metric]] at $at: [_input_said $req]"
    _scan_note $quiet $req {mol atoms fitatoms algorithm metric params}
    variable last_pct
    unset -nocomplain last_pct
    if {[catch {::VMDance::Job::run elbow $req [expr {$quiet ? "" : "::VMDance::_console_progress"}]} s]} { error "$what: $s" }
    ::VMDance::Results::set_elbow $s
    _scan_rows $s
}

# A scan's record published as a run.
proc ::VMDance::_adopt {what s rec {label ""}} {
    variable last_said [clock milliseconds]
    if {[catch {::VMDance::Job::run adopt [dict create scan $s record $rec] ::VMDance::_console_long} a]} { error "$what: $a" }
    ::VMDance::Results::publish $a $label
    _api_info
}

proc ::VMDance::_api_sweep {args} {
    set what "vmdance sweep"
    switch -- [lindex $args 0] {
        show {
            if {[llength $args] != 1} { error "usage: $what show" }
            if {![dict size $::VMDance::Results::sweep]} { error "$what: no sweep" }
            return [_scan_rows $::VMDance::Results::sweep]
        }
        best {
            if {[llength $args] > 2} { error "usage: $what best ?ch|db?" }
            set by ch
            if {[llength $args] == 2} { set by [lindex $args 1] }
            if {$by ni {ch db}} { error "$what best: ch or db" }
            if {![dict size $::VMDance::Results::sweep]} { error "$what: no sweep" }
            set i [sweep_best $::VMDance::Results::sweep $by]
            if {$i < 0} { error "$what best: no configuration has a $by score" }
            return [lindex [_scan_rows $::VMDance::Results::sweep] $i]
        }
        load {
            if {[llength $args] != 2} { error "usage: $what load n" }
            _check_idle $what
            set s $::VMDance::Results::sweep
            if {![dict size $s]} { error "$what: no sweep" }
            set i [lindex $args 1]
            # (whole: string is integer takes 010, which lindex reads as 8)
            if {![whole $i] || $i >= [llength [dict get $s records]]} {
                error "$what load: no configuration \"$i\" (0 to [expr {[llength [dict get $s records]] - 1}])"
            }
            return [_adopt $what $s [lindex [dict get $s records] $i]]
        }
        clear {
            if {[llength $args] != 1} { error "usage: $what clear" }
            _check_idle $what
            ::VMDance::Results::set_sweep {}
            return
        }
    }
    set o [_opts $what [dict merge $::VMDance::input_opts {-algorithms kmeans -ks "" -from 2 -to 12 -by 1 -metrics MSD -seedings StratAll -params {} -quiet 0}] $args]
    set quiet [_bool "$what: -quiet" [dict get $o -quiet]]
    _check_idle $what
    if {[catch {_ks $what $o $args 1000} ks]} { error $ks }
    # (the seedings are a sweep's own axis: one in -params was replaced by
    # them without a word)
    set p [dict get $o -params]
    if {![catch {dict size $p}]} {
        dict for {a ap} $p {
            set sk [expr {$a eq "helm" ? "initial-kinit" : "kinit"}]
            if {![catch {dict exists $ap $sk} has] && $has} {
                error "$what: -params of [::VMDance::Algo::label $a] gives -$sk [dict get $ap $sk]: a sweep's seedings are -seedings[expr {$a eq "helm" ? " (HELM's: its first clustering's)" : ""}]"
            }
        }
    }
    set configs [sweep_configs [dict get $o -algorithms] $ks [dict get $o -metrics] [dict get $o -seedings] [dict get $o -params]]
    set req {}
    foreach k [dict keys $::VMDance::input_opts] { dict set req [string range $k 1 end] [dict get $o $k] }
    dict set req configs $configs
    if {[catch {::VMDance::Job::check_sweep $req} req]} { error "$what: $req" }
    _say $quiet "sweeping [llength [dict get $req configs]] configurations: [_input_said $req]"
    _scan_note $quiet $req {mol atoms fitatoms}
    variable last_pct
    unset -nocomplain last_pct
    if {[catch {::VMDance::Job::run sweep $req [expr {$quiet ? "" : "::VMDance::_console_progress"}]} s]} { error "$what: $s" }
    ::VMDance::Results::set_sweep $s
    _scan_rows $s
}

# The configurations of a grid, in the order algorithm, metric, seeding,
# k; params: {algorithm {name value ...}} of fixed parameters. One whose
# parameters use no seeding (Algo::seeding_of: HELM started from a label
# file, DIVINE's pair anchors) is made once, not once a seeding: each would
# be the same clustering, labelled with a seeding it never used.
proc ::VMDance::sweep_configs {algorithms ks metrics seedings params} {
    set what "vmdance sweep"
    foreach {l name} [list $algorithms -algorithms $ks -ks $metrics -metrics $seedings -seedings] {
        if {![string is list $l]} { error "$what: $name must be a list" }
    }
    if {![llength $algorithms]} { error "$what: -algorithms: none" }
    if {![llength $metrics]} { set metrics MSD }
    if {![llength $seedings]} { set seedings StratAll }
    if {[catch {dict size $params}]} { error "$what: -params must be {algorithm {name value ...} ...}" }
    # (a name given twice: the dict kept the last, the first never checked)
    set seen {}
    foreach {a p} $params {
        if {$a in $seen} { error "$what: -params: $a is given twice" }
        lappend seen $a
        if {$a ni $algorithms} {
            error "$what: -params names [expr {[::VMDance::Algo::exists $a] ? "[::VMDance::Algo::label $a], which is not swept (-algorithms)" : "\"$a\", which is not an algorithm"}]"
        }
        if {[catch {dict size $p}]} { error "$what: -params of $a must be {name value ...}" }
        set names {}
        foreach {n v} $p {
            if {$n in $names} { error "$what: -params of $a: $n is given twice" }
            lappend names $n
        }
    }
    # (counted before they are made: a sweep runs at most 1000)
    set n 0
    foreach a $algorithms {
        set ns [llength $seedings]
        if {[::VMDance::Algo::seeding_of $a [_get $params $a {}]] eq ""} { set ns 1 }
        incr n [expr {[llength $metrics] * $ns * [llength $ks]}]
    }
    if {$n > 1000} {
        set all [expr {[llength $algorithms] * [llength $metrics] * [llength $seedings] * [llength $ks]}]
        error "$what: [expr {$n == $all ? "[llength $algorithms] × [llength $metrics] × [llength $seedings] × [llength $ks] = " : ""}]$n configurations; a sweep has at most 1000"
    }
    set out {}
    foreach a $algorithms {
        set fixed [_get $params $a {}]
        set sk [::VMDance::Algo::seeding_of $a $fixed]
        set seeds $seedings
        if {$sk eq ""} { set seeds [list ""] }
        foreach m $metrics {
            foreach s $seeds {
                foreach k $ks {
                    set p $fixed
                    if {$sk ne ""} { set p [dict merge $fixed [dict create $sk $s]] }
                    lappend out [dict create algorithm $a k $k metric $m params $p]
                }
            }
        }
    }
    return $out
}

# The best configuration of a sweep: the highest Calinski–Harabasz, or
# the lowest Davies–Bouldin (the first of equals); -1 when none has one.
proc ::VMDance::sweep_best {s by} {
    set best -1; set bv ""
    set i 0
    foreach r [dict get $s records] {
        set v [dict get $r $by]
        if {[dict get $r status] eq "ok" && $v ne ""} {
            if {$bv eq "" || ($by eq "ch" ? $v > $bv : $v < $bv)} { set bv $v; set best $i }
        }
        incr i
    }
    return $best
}

#---------------------------------------------------------------------------
# Questions after a clustering
#---------------------------------------------------------------------------

# prime: PRIME's seven answers as VMD frames ({key frame ...}).
proc ::VMDance::_api_prime {args} {
    set what "vmdance prime"
    _need_data $what
    if {[catch {_specs_given $what $args} given]} { error $given }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::prime_params $given} p]} { error "$what: $p" }
    set run $::VMDance::Results::current
    if {[catch {::VMDance::Job::run prime [dict create result $::VMDance::Results::A params $p]} r]} { error "$what: $r" }
    ::VMDance::Results::attach prime $r $run
    if {$run ne $::VMDance::Results::current} { error "$what: run $run was left while PRIME ran; its answer is kept with it" }
    prime_frames
}
# -name value pairs as {name value}: every name with one dash.
proc ::VMDance::_specs_given {what argl} {
    if {[llength $argl] % 2} { error "$what: options must come in -name value pairs" }
    set given {}
    foreach {k v} $argl {
        if {![regexp {^-([a-z][-a-z]*)$} $k -> name]} { error "$what: \"$k\" is not an option (-name value)" }
        if {[dict exists $given $name]} { error "$what: $k is given twice" }
        dict set given $name $v
    }
    return $given
}
proc ::VMDance::prime_frames {} {
    set p [::VMDance::Results::extra prime]
    set out {}
    set fr [::VMDance::Results::frames]
    foreach {key label kind} $::VMDance::prime_rows {
        set i [dict get $p $key]
        dict set out $key [expr {$i >= 0 ? [lindex $fr $i] : -1}]
    }
    return $out
}

# similarity: {isim x clusters {c isim ...} least_similar {c frame ...}}.
proc ::VMDance::_api_similarity {args} {
    set what "vmdance similarity"
    _need_data $what
    if {[catch {_specs_given $what $args} given]} { error $given }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::similarity_params $given} p]} { error "$what: $p" }
    set run $::VMDance::Results::current
    if {[catch {::VMDance::Job::run similarity [dict create result $::VMDance::Results::A params $p]} r]} { error "$what: $r" }
    ::VMDance::Results::attach similarity $r $run
    if {$run ne $::VMDance::Results::current} { error "$what: run $run was left while it ran; its answer is kept with it" }
    similarity_info
}
proc ::VMDance::similarity_info {} {
    set s [::VMDance::Results::extra similarity]
    set fr [::VMDance::Results::frames]
    set cl {}; set out {}
    set c 0
    foreach v [dict get $s cluster] o [dict get $s outliers] {
        dict set cl $c $v
        dict set out $c [expr {$o >= 0 ? [lindex $fr $o] : -1}]
        incr c
    }
    dict create metric [dict get $s params metric] isim [dict get $s isim] clusters $cl least_similar $out
}

# groups: the groups of the current run's frames (the method, replica or
# condition each came from): {names {...} sizes {...} none n colours
# {...}}, {} without. groups -ranges {name frames ...} (VMD frames:
# 0-63,70), -file f.csv (frame,group lines), -names {...} (one per frame
# clustered): set them; -colours {name #rrggbb ...}, with them or alone:
# their colours in the plots (a name they do not have is passed over: one
# list for several molecules; "": the palette's); groups clear.
proc ::VMDance::_api_groups {args} {
    set what "vmdance groups"
    _need_data $what
    if {[llength $args] == 1 && [lindex $args 0] eq "clear"} {
        ::VMDance::Results::set_groups {}
        return {}
    }
    if {[llength $args]} {
        set o [_opts $what {-ranges "" -file "" -names "" -colours ""} $args]
        set how [lmap k {-ranges -file -names} {expr {[dict get $o $k] ne "" ? $k : [continue]}}]
        set colours [dict get $o -colours]
        if {[llength $how] > 1 || (![llength $how] && $colours eq "")} { error "$what: give one of -ranges, -file or -names, or -colours (or clear)" }
        if {[llength $how]} {
            if {[catch {::VMDance::Results::groups_from [string range $how 1 end] [dict get $o $how] [::VMDance::Results::frames]} g]} {
                error "$what: $g"
            }
            set g [::VMDance::Results::keep_colours $g]
        } else {
            set g [::VMDance::Results::groups]
            if {![dict size $g]} { error "$what: the frames have no groups to colour (vmdance groups -ranges …)" }
        }
        if {$colours ne "" && [catch {::VMDance::Results::colour_groups $g $colours} g]} { error "$what: $g" }
        if {[catch {::VMDance::Results::set_groups $g} err]} { error "$what: $err" }
    }
    groups_info
}
proc ::VMDance::groups_info {} {
    set names [::VMDance::Results::group_names]
    if {![llength $names]} { return {} }
    set sizes [lrepeat [llength $names] 0]
    set none 0
    foreach g [::VMDance::Results::group_of] {
        if {$g < 0} { incr none; continue }
        lset sizes $g [expr {[lindex $sizes $g] + 1}]
    }
    set colours {}
    for {set g 0} {$g < [llength $names]} {incr g} { lappend colours [::VMDance::Results::group_colour $g] }
    dict create names $names sizes $sizes none $none colours $colours
}

# makeup: the frames of each cluster by group, {cluster {n ...} ...} (in the
# groups' order), or with -by group each group's by cluster, {group {n ...}
# ...}. Noise and frames of no group are left out.
proc ::VMDance::_api_makeup {args} {
    set what "vmdance makeup"
    _need_data $what
    set o [_opts $what {-by cluster} $args]
    set names [::VMDance::Results::group_names]
    if {![llength $names]} { error "$what: the frames have no groups (vmdance groups -ranges …)" }
    set M [::VMDance::Measure::makeup [::VMDance::Results::labels] [::VMDance::Results::group_of] \
        [::VMDance::Results::nclusters] [llength $names]]
    set out {}
    switch -- [dict get $o -by] {
        cluster {
            set c 0
            foreach row $M { dict set out $c $row; incr c }
        }
        group {
            set j 0
            foreach nm $names { dict set out $nm [lmap row $M {lindex $row $j}]; incr j }
        }
        default { error "$what: -by must be cluster or group (got \"[dict get $o -by]\")" }
    }
    return $out
}

# map: the frames on their first two principal components (computed; kept
# with the run): {sample m variance {v1 v2} total t}; map show: {frame
# {pc1 pc2} ...}.
proc ::VMDance::_api_map {args} {
    set what "vmdance map"
    _need_data $what
    if {$args eq "show"} {
        set m [::VMDance::Results::extra map]
        if {![dict size $m]} { error "$what show: no map for this clustering (vmdance map)" }
        set out {}
        foreach f [::VMDance::Results::frames] x [dict get $m pc1] y [dict get $m pc2] { dict set out $f [list $x $y] }
        return $out
    }
    if {[catch {_specs_given $what $args} given]} { error $given }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::map_params $given} p]} { error "$what: $p" }
    set run $::VMDance::Results::current
    if {[catch {::VMDance::Job::run map [dict create result $::VMDance::Results::A params $p]} r]} { error "$what: $r" }
    ::VMDance::Results::attach map $r $run
    if {$run ne $::VMDance::Results::current} { error "$what: run $run was left while it ran; its map is kept with it" }
    dict filter $r key sample variance total
}

# profiles: atom by atom, each cluster's and each group's RMSF and each
# cluster's mean structure against one cluster's (computed; kept with the
# run): {reference c atoms n clusters k groups {...}}; profiles show: the
# whole profiles (residues chains clusters groups differences …).
proc ::VMDance::_api_profiles {args} {
    set what "vmdance profiles"
    _need_data $what
    if {$args eq "show"} {
        set p [::VMDance::Results::extra profiles]
        if {![dict size $p]} { error "$what show: no profiles for this clustering (vmdance profiles)" }
        return $p
    }
    if {[catch {_specs_given $what $args} given]} { error $given }
    if {[catch {::VMDance::Job::check_specs $::VMDance::Algo::profiles_params $given} p]} { error "$what: $p" }
    set ref [dict get $p reference]
    if {$ref >= 0} { _cluster "$what: -reference" $ref }
    set run $::VMDance::Results::current
    set req [dict create result $::VMDance::Results::A params $p groups [::VMDance::Results::groups]]
    if {[catch {::VMDance::Job::run profiles $req} r]} { error "$what: $r" }
    ::VMDance::Results::attach profiles $r $run
    if {$run ne $::VMDance::Results::current} { error "$what: run $run was left while they were made; they are kept with it" }
    dict create reference [dict get $r reference] atoms [llength [dict get $r residues]] \
        clusters [llength [dict get $r clusters]] groups [dict get $r group_names]
}

# pick: frames picked without clustering (the input options as a
# clustering's): VMD frames. pick goto f: VMD's frame to a picked one, on
# their molecule; pick save file: their structures (-format pdb|dcd, -sel).
proc ::VMDance::_api_pick {args} {
    set what "vmdance pick"
    switch -- [lindex $args 0] {
        show {
            if {[llength $args] != 1} { error "usage: $what show" }
            if {![dict size $::VMDance::Results::picks]} { error "$what: no frames picked" }
            return [dict get $::VMDance::Results::picks vmdframes]
        }
        goto {
            if {[llength $args] != 2} { error "usage: $what goto frame" }
            _check_idle $what
            if {[catch {::VMDance::Viz::goto_pick [lindex $args 1]} r]} { error "$what goto: $r" }
            return $r
        }
        save {
            if {[llength $args] < 2} { error "usage: $what save file ?-format pdb|dcd? ?-sel text?" }
            set o [_opts "$what save" {-format pdb -sel all} [lrange $args 2 end]]
            _check_idle $what
            if {[dict get $o -format] ni {pdb dcd}} { error "$what save: -format must be pdb or dcd" }
            if {[catch {::VMDance::Export::picked [lindex $args 1] [dict get $o -format] [dict get $o -sel]} r]} { error "$what save: $r" }
            return $r
        }
        clear {
            if {[llength $args] != 1} { error "usage: $what clear" }
            _check_idle $what
            ::VMDance::Results::set_picks {}
            return
        }
    }
    set o [_opts $what [dict merge $::VMDance::input_opts {-method diversity -param 10 -nbins 10 -metric MSD}] $args]
    _check_idle $what
    set req {}
    foreach k [dict keys $::VMDance::input_opts] { dict set req [string range $k 1 end] [dict get $o $k] }
    if {[catch {
        set req [::VMDance::Job::check_input $req]
        dict set req params [::VMDance::Job::check_specs $::VMDance::Algo::pick_params \
            [dict create method [dict get $o -method] param [dict get $o -param] nbins [dict get $o -nbins] metric [dict get $o -metric]]]
        ::VMDance::Job::check_pick [dict get $req params] [llength [dict get $req frames]]
    } err]} { error "$what: $err" }
    if {[catch {::VMDance::Job::run pick $req} r]} { error "$what: $r" }
    ::VMDance::Results::set_picks $r
    dict get $r vmdframes
}

#---------------------------------------------------------------------------
# The selection, the 3D window
#---------------------------------------------------------------------------

proc ::VMDance::_api_select {args} {
    set what "vmdance select"
    _need_data $what
    if {![llength $args]} { return [::VMDance::Results::selected] }
    set mode set
    # (clear and all alone: "clear 1" emptied the whole selection)
    if {[lindex $args 0] in {clear all} && [llength $args] != 1} {
        error "usage: $what ?cluster ...? | $what add|toggle cluster ... | $what all | $what clear"
    }
    switch -- [lindex $args 0] {
        clear { return [::VMDance::Results::set_selection {}] }
        all {
            set all {}
            for {set c 0} {$c < [::VMDance::Results::nclusters]} {incr c} { lappend all $c }
            return [::VMDance::Results::set_selection $all]
        }
        add - toggle { set mode [lindex $args 0]; set args [lrange $args 1 end] }
    }
    set cs [lmap c $args {_cluster $what $c}]
    ::VMDance::Results::set_selection $cs $mode
}

# draw: the options, and a note of what is on but cannot be drawn.
proc ::VMDance::_api_draw {args} {
    set what "vmdance draw"
    _check_idle $what
    set seen {}
    foreach {k v} $args {
        if {![regexp {^-[a-z]+$} $k]} { error "$what: \"$k\" is not an option (-name value)" }
        if {$k in $seen} { error "$what: $k is given twice" }
        lappend seen $k
    }
    if {[catch {::VMDance::Viz::configure {*}$args} o]} { error "$what: $o" }
    set notes [draw_notes $o]
    if {[llength $notes]} { dict set o note [join $notes "; "] }
    return $o
}
# What of the drawing's options o is on but not drawn, and why (the window
# says it too).
proc ::VMDance::draw_notes {o} {
    set notes {}
    if {[dict get $o colour] || [dict get $o reps] || [dict get $o overlay]} {
        if {[::VMDance::Viz::_mol] < 0} { lappend notes "[::VMDance::Viz::why]: the clusters are not drawn" }
    }
    if {[dict get $o picks] && [::VMDance::Viz::_picks_mol] < 0} {
        lappend notes "[::VMDance::Viz::picks_why]: the picked frames are not drawn"
    }
    # (what is drawn otherwise than asked: a -sel that is no selection of
    # the molecule, frames past its last)
    lappend notes {*}$::VMDance::Viz::notes
    return $notes
}

# goto c: VMD's frame to cluster c's representative; goto -frame f.
proc ::VMDance::_api_goto {args} {
    set what "vmdance goto"
    _need_data $what
    if {[lindex $args 0] eq "-frame"} {
        if {[llength $args] != 2} { error "usage: $what cluster | $what -frame f" }
        if {[catch {::VMDance::Viz::goto [lindex $args 1]} r]} { error "$what: $r" }
        return $r
    }
    if {[llength $args] != 1} { error "usage: $what cluster | $what -frame f" }
    set c [_cluster $what [lindex $args 0]]
    set f [::VMDance::Results::rep_frame $c]
    if {$f < 0} { error "$what: cluster $c has no frame" }
    if {[catch {::VMDance::Viz::goto $f} r]} { error "$what: $r" }
    return $r
}

# userfield: write every frame's cluster into VMD's user field of the
# atoms (-1: noise, and the frames that were not clustered), for colouring
# representations by it (Coloring Method: User). This is the one command
# that changes the molecule's data: it is asked for.
proc ::VMDance::_api_userfield {args} {
    set what "vmdance userfield"
    set o [_opts $what {-sel all} $args]
    _need_data $what
    set m [::VMDance::Viz::_mol]
    if {$m < 0} { error "$what: [::VMDance::Viz::why]" }
    if {[catch {::VMDance::Mol::sel $m [dict get $o -sel]} s]} { error "$what: -sel: [::VMDance::Mol::_why $s]" }
    # (the answer is the frames written: none to any atom is no answer)
    if {[$s num] == 0} {
        ::VMDance::Mol::free $s
        error "$what: -sel: \"[dict get $o -sel]\" matches no atom of molecule $m"
    }
    set n 0
    try {
        set nf [molinfo $m get numframes]
        set fr [::VMDance::Results::frames]
        for {set f 0} {$f < $nf} {incr f} {
            set i [::VMDance::Results::row_of $f]
            $s frame $f
            $s set user [expr {$i >= 0 ? [lindex [::VMDance::Results::labels] $i] : -1}]
            if {$i >= 0} { incr n }
        }
    } finally {
        ::VMDance::Mol::free $s
    }
    return $n
}

#---------------------------------------------------------------------------
# Runs
#---------------------------------------------------------------------------

proc ::VMDance::_api_runs {args} {
    if {[llength $args]} { error "usage: vmdance runs" }
    lmap r [::VMDance::Results::run_list] {
        concat $r [expr {[lindex $r 0] eq $::VMDance::Results::current}]
    }
}

proc ::VMDance::_api_run {args} {
    set what "vmdance run"
    set usage "usage: $what id | delete id | label id text | clear"
    _check_idle $what
    switch -- [lindex $args 0] {
        delete {
            if {[llength $args] != 2} { error $usage }
            if {[catch {::VMDance::Results::run_delete [lindex $args 1]} err]} { error "$what: $err" }
        }
        label {
            if {[llength $args] != 3} { error $usage }
            if {[catch {::VMDance::Results::run_label [lindex $args 1] [lindex $args 2]} err]} { error "$what: $err" }
        }
        clear {
            if {[llength $args] != 1} { error $usage }
            ::VMDance::Results::clear_all
        }
        default {
            if {[llength $args] != 1} { error $usage }
            if {[catch {::VMDance::Results::run_switch [lindex $args 0]} err]} { error "$what: $err" }
        }
    }
    _api_runs
}

#---------------------------------------------------------------------------
# Files
#---------------------------------------------------------------------------

proc ::VMDance::_api_export {args} {
    set what "vmdance export"
    if {[llength $args] < 1} { error "usage: $what dir ?-prefix name? ?-items {[join [::VMDance::Export::items] { }]}? ?-top n? ?-lag n? ?-format pdb|dcd? ?-sel text?" }
    set o [_opts $what {-prefix vmdance -items "" -top 10 -lag 1 -format dcd -sel all} [lrange $args 1 end]]
    _check_idle $what
    # (-top and -lag: checked by the export, Export::check, with their ranges)
    if {[dict get $o -format] ni {pdb dcd}} { error "$what: -format must be pdb or dcd" }
    set items [dict get $o -items]
    if {![::VMDance::Results::has_data]} {
        if {![llength $items] || [llength [lmap i $items {expr {$i in {elbow sweep picks} ? [continue] : $i}}]]} {
            error "$what: no clustering (without one: -items elbow, sweep or picks)"
        }
    }
    if {[catch {::VMDance::Export::bundle [lindex $args 0] [dict get $o -prefix] $items \
            [dict create top [dict get $o -top] lag [dict get $o -lag] format [dict get $o -format] sel [dict get $o -sel]]} r]} {
        error "$what: $r"
    }
    return $r
}

# session save file | session load file ?-mol auto|load|none|id? |
# session import file.mdance ?-mol auto|id? (the MDANCE plugin's)
proc ::VMDance::_api_session {args} {
    set usage "usage: vmdance session save file | load file ?-mol auto|load|none|molid? | import file.mdance ?-mol auto|molid?"
    if {[llength $args] < 2} { error $usage }
    lassign $args sub file
    switch -- $sub {
        save {
            _opts "vmdance session save" {} [lrange $args 2 end]
            _check_idle "vmdance session save"
            set gui [_window_state]
            if {[catch {::VMDance::Session::save $file $gui} r]} { error "vmdance session save: $r" }
            return $r
        }
        load {
            set o [_opts "vmdance session load" {-mol auto} [lrange $args 2 end]]
            _check_idle "vmdance session load"
            if {[catch {::VMDance::Session::load $file [dict get $o -mol]} r]} { error "vmdance session load: $r" }
            lassign $r warnings gui
            foreach w $warnings { puts "VMDance) warning: $w" }
            if {[_gui_open]} {
                ::VMDance::GUI::apply_session_state $gui
            } else {
                # (the 3D drawing the session had, without the window too: drawn
                # now, the window shows it when it opens, not drawn again then)
                set ::VMDance::Session::pending_gui [dict filter $gui script {k v} {expr {![string match v3d_* $k]}}]
                if {[catch {_draw_state $gui} err]} { puts "VMDance) warning: the session's 3D drawing: $err" }
            }
            return [_api_runs]
        }
        import {
            set o [_opts "vmdance session import" {-mol auto -label ""} [lrange $args 2 end]]
            _check_idle "vmdance session import"
            # (no molecule found: the command's way to give one)
            if {[catch {import_request $file [dict get $o -mol]} req opts]} {
                if {[lrange [dict get $opts -errorcode] 0 1] eq {VMDANCE NOMOL}} { append req ": load it, or give its id (-mol)" }
                error "vmdance session import: $req"
            }
            variable last_said [clock milliseconds]
            if {[catch {::VMDance::Job::run import $req ::VMDance::_console_long} r]} { error "vmdance session import: $r" }
            foreach w [dict get $r warnings] { puts "VMDance) warning: $w" }
            if {[dict exists $r refused]} {
                lassign [dict get $r refused] why text
                error "vmdance session import: $text: [expr {$why eq "differ" ? "load its molecule, or give its id (-mol)" : "give its id (-mol)"}]"
            }
            set a [dict get $r result]
            # (the label as typed: expr's ?: would make 0x10 16)
            set label [dict get $o -label]
            if {$label eq ""} { set label [_imported_label $a] }
            ::VMDance::Results::publish $a $label
            return [_api_info]
        }
        default { error $usage }
    }
}

# The window's state for a session: the window's, or without it the
# state a session left for it with the 3D drawing of now.
proc ::VMDance::_window_state {} {
    if {[_gui_open]} { return [::VMDance::GUI::session_state] }
    set g $::VMDance::Session::pending_gui
    if {[catch {dict size $g}]} { set g {} }
    foreach {k v} [::VMDance::Viz::get] {
        if {$k eq "frames"} {
            dict set g v3d_mode [expr {$v ne "" ? "frames" : "top"}]
            if {$v ne ""} { dict set g v3d_frames $v }
        } else {
            dict set g v3d_$k $v
        }
    }
    return $g
}
# The 3D drawing of a session's window state; returns what was left out.
proc ::VMDance::_draw_state {g} {
    set o {}
    foreach k {colour reps overlay picks style sel top material} {
        if {[dict exists $g v3d_$k]} { lappend o $k [dict get $g v3d_$k] }
    }
    # (the frames as written: expr's ?: would make "010" frame 8)
    set fr ""
    if {[_get $g v3d_mode ""] eq "frames"} {
        set fr [_get $g v3d_frames ""]
        # ("frames" with none typed: no overlay, as the window draws it)
        if {[string trim $fr] eq ""} { set fr ""; lappend o overlay 0 }
    }
    lappend o frames $fr
    # (a -sel or -frames refused, kept while no molecule was there to check
    # it on and saved so, is left out alone, said: not the whole drawing)
    set left {}
    while {[catch {::VMDance::Viz::configure {*}$o} err]} {
        if {![regexp {^-?(sel|frames): } $err -> k] || [dict get $o $k] eq ""} { error $err }
        puts "VMDance) warning: the session's 3D drawing: $err: left out"
        lappend left "$err: left out"
        dict set o $k ""
    }
    return $left
}

# The request of an MDANCE plugin session: its request on each molecule it
# may be of (candidates, in the order they are tried: Job::_do_import
# checks their coordinates; exact, of the name and frames it recorded),
# checked; its answer; the file; whether the molecule was given (explicit)
# and whether the file names it (known), the frames it recorded
# (molframes); HELM's starting clusters (nstart), what it does not record
# (unrecorded) and the warnings of its reading (Session::read_old).
proc ::VMDance::import_request {file mol} {
    set d [::VMDance::Session::read_old $file $mol]
    set q [dict get $d request]
    set a [dict get $q algorithm]
    # (the MDANCE plugin kept no fit and asked for no seeding check: its
    # parameters are checked as a stored request's)
    set metric [::VMDance::Algo::check_metric [dict get $q metric]]
    set params [::VMDance::Algo::check_params $a [dict get $q params] 1]
    set ins {}
    set why {}
    foreach mx [::VMDance::Session::old_candidates $d $mol] {
        lassign $mx m exact
        dict set q mol $m
        if {[catch {::VMDance::Job::check_input $q} in]} { lappend why "molecule $m: $in"; continue }
        if {[dict get $in frames] ne [dict get $d frames]} { lappend why "molecule $m: the frames do not match"; continue }
        dict set in exact $exact
        lappend ins $in
    }
    if {![llength $ins]} { error [join $why "; "] }
    dict create candidates $ins explicit [expr {$mol ne "auto"}] known [dict size [dict get $d signature]] \
        molframes [_get [dict get $d signature] molFrames ""] \
        algorithm $a k [dict get $q k] metric $metric params $params \
        answer [dict get $d answer] file [file normalize $file] \
        nstart [dict get $d nstart] unrecorded [dict get $d unrecorded] warnings [dict get $d warnings]
}
# An imported run's name: its clustering, and what its file does not record.
proc ::VMDance::_imported_label {a} {
    set s "[::VMDance::Results::describe $a] (imported"
    if {[llength [_get $a unrecorded {}]]} { append s "; parameters not recorded" }
    return "$s)"
}

# figures dir ?-option value ...?: the plots as files (needs Tk)
proc ::VMDance::_api_figures {args} {
    set what "vmdance figures"
    if {[llength $args] < 1} { error "usage: $what dir ?-plots {...}? ?-formats {pdf png}? ?-width w? ?-height h? ?-prefix p? ?-options {setting value ...}? ?-3d 0|1? ?-renderer auto|name?" }
    # (not the window's advice, "use the command": this is the command)
    _load_tk $what "make them in VMD with its window (text-mode VMD has no display: its launcher unsets DISPLAY), from a session saved here if need be (vmdance session load file -mol none, then vmdance figures dir)"
    _check_idle $what
    ::VMDance::Figures::api [lindex $args 0] {*}[lrange $args 1 end]
}

if {[info commands vmd_install_extension] ne ""} {
    vmd_install_extension vmdance vmdance_tk "Analysis/VMDance"
}
