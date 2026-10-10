#
# VMDance - sessions: save and reopen every run (no Tk dependency)
#
# A session file is gzip-compressed UTF-8 text:
#     VMDanceSession <format>\n<Tcl dictionary>
# (MDANCEViewSession: the plugin's name before VMDance; those sessions open
# too)
# The dictionary is parsed as data and never evaluated. Keys:
#   format plugin created
#   runs       {id label result} each (Results::check'ed on reading)
#   current    the current run's id
#   selection  the selected clusters of the current run
#   elbow sweep picks   the last scans and frame picks ({} when none)
#   gui        the window's state (optional)
# Everything is checked before anything is replaced. A session reopens
# without its molecules; with them (found loaded, or loaded from their
# files) the 3D views and the questions that read the coordinates again
# (PRIME, similarity) work too.
#

namespace eval ::VMDance::Session {
    variable format 1
    variable magic "VMDanceSession"
    variable old_magic {MDANCEViewSession}
    variable ext .vmdance
    variable pending_gui {}   ;# window state of a session loaded before the window was opened
    variable current_file ""  ;# the session file the runs came from, or were last saved to
    variable prints           ;# fingerprints read while a session opens (Coords::prints_of)
    # The most a session holds, read (read_file refuses more) and written
    # (save writes no more): its text unpacked, and its values (numbers and
    # words). A small file can unpack to gigabytes, and every value read
    # costs about 120 bytes of memory: 50 million, about 6 GB.
    variable max_bytes 400000000
    variable max_values 50000000
}

# (the runs cleared: they no longer are a file's, and the window state
# waiting for the window is not theirs)
proc ::VMDance::Session::_results_changed {what} {
    variable current_file; variable pending_gui
    if {$what eq "analysis" && ![::VMDance::Results::has_data]} {
        set current_file ""
        set pending_gui {}
    }
}
::VMDance::Results::listen ::VMDance::Session::_results_changed

# The values of a session's text (its UTF-8 bytes), counted without making
# them: every character Tcl's lists split on (space, tab, the line ends,
# vertical tab and form feed) and every backslash (an escape such as \n or
# \x20 in a word is a separator once the word is read), a megabyte at a
# time.
proc ::VMDance::Session::_values {bytes} {
    set n 0
    set len [string length $bytes]
    for {set i 0} {$i < $len} {incr i 1048576} {
        set c [string range $bytes $i [expr {$i + 1048575}]]
        incr n [expr {[string length $c] - [string length [string map {" " "" "\n" "" "\t" "" "\r" "" "\v" "" "\f" "" "\\" ""} $c]]}]
    }
    return $n
}
# The index of the first s in a text from at (-1: none), a megabyte at a
# time: string first and regexp make a copy of the whole text, at two bytes
# a character.
proc ::VMDance::Session::_first {s text at} {
    set len [string length $text]
    for {set i $at} {$i < $len} {incr i 1048576} {
        set j [string first $s [string range $text $i [expr {$i + 1048575 + [string length $s]}]]]
        if {$j >= 0} { return [expr {$i + $j}] }
    }
    return -1
}
# (in millions, with the decimals that tell it from other: never "50 million,
# more than the 50 million")
proc ::VMDance::Session::_mb {b {other ""}} {
    set d [expr {$b < 1e7 ? 1 : 0}]
    while {$d < 6 && (($other ne "" && [format %.${d}f [expr {$b / 1e6}]] eq [format %.${d}f [expr {$other / 1e6}]]) ||
            ($b > 0 && [format %.${d}f [expr {$b / 1e6}]] == 0))} { incr d }
    format %.${d}f [expr {$b / 1e6}]
}

# Why a session is not written: more than read_file opens (bytes or values),
# with its largest parts and how to drop each; sizes {id label bytes} each
# (the runs); scans 1: the scans and the picks too (measured once the
# session's text is made: their text is there).
proc ::VMDance::Session::_too_large {bytes values sizes {scans 0}} {
    variable max_bytes; variable max_values
    set runs {"delete runs" "(Clustering ▸ Delete this run, or vmdance run delete id)"}
    set others {}
    if {$scans} {
        foreach {key name how} {
            elbow "the elbow scan" {"clear the elbow scan" "(vmdance elbow clear)"}
            sweep "the sweep" {"clear the sweep" "(vmdance sweep clear)"}
            picks "the frame picks" {"clear the frame picks" "(vmdance pick clear)"}
        } {
            set v [set ::VMDance::Results::$key]
            if {[dict size $v]} { lappend others $name $v $how $key }
        }
    }
    if {$bytes > $max_bytes} {
        set why "would be [_mb $bytes $max_bytes] MB, more than the [_mb $max_bytes $bytes] MB a session can be"
        set max $max_bytes
        set parts [lmap s $sizes {lassign $s id label b; list "run $id ($label)" $b $runs $id}]
        foreach {name v how key} $others { lappend parts [list $name [string length $v] $how $key] }
        set unit " MB"
    } else {
        set why "would hold [_mb $values $max_values] million values, more than the [_mb $max_values $values] million a session can hold"
        set max $max_values
        set parts {}
        foreach r $::VMDance::Results::runs {
            lassign $r id label packed
            lappend parts [list "run $id ($label)" [_values [zlib decompress $packed]] $runs $id]
        }
        foreach {name v how key} $others { lappend parts [list $name [_values $v] $how $key] }
        set unit " million values"
    }
    set parts [lrange [lsort -real -decreasing -index 1 $parts] 0 4]
    set l [lmap p $parts {lassign $p name b; format "%s %s%s" $name [_mb $b] $unit}]
    # (what to do, for what holds the most first: delete runs, clear a scan)
    set hows {}
    foreach p $parts { if {[lindex $p 2] ni $hows} { lappend hows [lindex $p 2] } }
    set do ""
    foreach h $hows {
        lassign $h verb where
        if {$do eq ""} {
            set do "[string toupper [string index $verb 0]][string range $verb 1 end] first $where"
        } else {
            append do ", or $verb $where"
        }
    }
    set msg "the session $why (it could not be opened again); nothing was written. $do: [join $l {, }]"
    # (what alone is more than a session can be cannot be kept in one: its
    # tables can be exported)
    lassign [lindex $parts 0] name b how key
    if {$b > $max} {
        if {[string match "run *" $name]} { set ex "vmdance run $key, then vmdance export dir" } else { set ex "vmdance export dir -items $key" }
        append msg ". [string toupper [string index $name 0]][string range $name 1 end] alone is more than a session can hold, and cannot be kept in one: export its tables first ($ex)"
    }
    if {$unit ne " MB"} {
        append msg " (or raise the limit, here and where it is opened: set ::VMDance::Session::max_values $values; a value takes about 120 bytes of memory once read)"
    }
    return $msg
}

# Write a session file, atomically (a temporary file, then a rename).
proc ::VMDance::Session::save {file {gui {}}} {
    variable magic; variable format; variable max_bytes; variable max_values
    if {![::VMDance::Results::has_data]} { error "nothing to save: no clustering" }
    if {$file eq ""} { error "no file name" }
    # (the file the name writes, checked first, as an export's: a name is a
    # file's, "|cmd" or "<f" would be read by open as a pipe; a link of the
    # user's is followed, another's replaced; not a folder, nor read-only)
    set file [::VMDance::Export::target $file]
    # (no more than read_file opens, or the file written over could not be
    # opened again: the runs measured one at a time before the text is
    # made, which past 2 GB stops VMD; then the text itself)
    set sizes {}
    set total 0
    foreach r $::VMDance::Results::runs {
        lassign $r id label packed
        set b [string length [zlib decompress $packed]]
        lappend sizes [list $id $label $b]
        incr total $b
    }
    if {$total > $max_bytes} { error [_too_large $total 0 $sizes] }
    set s [dict create format $format plugin $::VMDance::version \
        created [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S"] \
        runs [::VMDance::Results::run_data] current $::VMDance::Results::current \
        selection [::VMDance::Results::selected] \
        elbow $::VMDance::Results::elbow sweep $::VMDance::Results::sweep \
        picks $::VMDance::Results::picks gui $gui]
    set raw [encoding convertto utf-8 "$magic $format\n$s\n"]
    unset s
    set n [_values $raw]
    if {[string length $raw] > $max_bytes || $n > $max_values} {
        error [_too_large [string length $raw] $n $sizes 1]
    }
    set bytes [zlib gzip $raw -level 6]
    unset raw
    ::VMDance::Export::_write $file $bytes 1
    variable current_file $file
    return $file
}

# Check a scan (elbow or sweep) as read from a file.
proc ::VMDance::Session::check_scan {s kind} {
    if {![string is list $s] || [llength $s] % 2} { error "the $kind is not a dictionary" }
    if {![dict size $s]} return
    foreach k {format kind request molecule frames natoms records} {
        if {![dict exists $s $k]} { error "the $kind has no \"$k\"" }
    }
    if {[dict get $s kind] ne $kind} { error "the $kind is corrupt" }
    set frames [dict get $s frames]
    ::VMDance::Results::check_frames "the $kind's frames" $frames
    set n [llength $frames]
    foreach k {mol sel fit first last step} {
        if {![dict exists $s request $k]} { error "the $kind's request has no \"$k\"" }
    }
    if {[catch {::VMDance::Results::check_molecule "the $kind's molecule record" [dict get $s molecule]} err]} { error $err }
    if {![regexp {^[1-9][0-9]{0,9}$} [dict get $s natoms]]} { error "the $kind's natoms is corrupt" }
    ::VMDance::Results::check_atoms "the $kind's" [dict get $s request] [dict get $s natoms] [dict get $s molecule]
    ::VMDance::Results::check_identity "the $kind's" $s $n
    # (its backend and date are written in its table's header)
    ::VMDance::Results::check_meta "the $kind's" $s
    if {$kind eq "elbow"} {
        foreach k {algorithm metric params ks} { if {![dict exists $s request $k]} { error "the elbow's request has no \"$k\"" } }
        if {![::VMDance::Algo::exists [dict get $s request algorithm]]} { error "the elbow's request names no algorithm" }
        if {[catch {::VMDance::Algo::check_metric [dict get $s request metric]} err]} { error "the elbow's request: $err" }
    }
    # (a record a k or a configuration, as many as a scan runs at most, each
    # of a dozen keys: counted before they are made)
    set most [expr {$kind eq "elbow" ? 200 : 1000}]
    set recs [dict get $s records]
    set nr [::VMDance::Results::_elements $recs $most]
    if {$nr eq ""} { error "the $kind's records are corrupt" }
    if {$nr > $most} { error "the $kind has more records than a scan makes (at most $most)" }
    set i 0
    foreach r $recs {
        incr i
        set nv [::VMDance::Results::_elements $r 32]
        if {$nv eq "" || $nv > 32 || $nv % 2} { error "the $kind's record $i is corrupt" }
        foreach k {status message nclusters ch db sizes clustering} {
            if {![dict exists $r $k]} { error "the $kind's record $i has no \"$k\"" }
        }
        if {[dict get $r status] ni {ok error}} { error "the $kind's record $i is corrupt" }
        # (its clusters with frames, at most the frames; a size for each
        # cluster of its clustering, the empty ones too (Job::_record: a
        # record's nclusters counts those with frames, its clustering keeps
        # the backend's k), none when it failed; bounded before they are made)
        set nk [dict get $r nclusters]
        if {$nk ne "" && (![regexp {^(0|[1-9][0-9]{0,8})$} $nk] || $nk > $n)} { error "the $kind's record $i is corrupt" }
        set ns [expr {$nk eq "" ? 0 : $nk}]
        if {[dict get $r status] eq "ok"} {
            if {[catch {::VMDance::Results::check_clustering [dict get $r clustering] $n} err]} { error "the $kind's record $i: $err" }
            set ns [dict get $r clustering nclusters]
            if {$nk eq "" || $nk > $ns} { error "the $kind's record $i is corrupt" }
        }
        if {[catch {::VMDance::Results::_intlist "sizes" [dict get $r sizes] $ns 0 $n}]} { error "the $kind's record $i is corrupt" }
        if {[catch {::VMDance::Results::_numlist "the scores" [list [dict get $r ch] [dict get $r db]] 2}]} { error "the $kind's record $i is corrupt" }
        if {$kind eq "sweep" || [dict exists $r algorithm]} {
            foreach k {algorithm k metric params} { if {![dict exists $r $k]} { error "the $kind's record $i has no \"$k\"" } }
            # (a configuration refused is kept with what was asked, as it was:
            # only one that ran is checked as a clustering's)
            if {[dict get $r status] eq "ok"} {
                if {![::VMDance::Algo::exists [dict get $r algorithm]]} { error "the $kind's record $i names no algorithm" }
                if {[catch {::VMDance::Algo::check_params [dict get $r algorithm] [dict get $r params] 1} err]} { error "the $kind's record $i: $err" }
            }
        }
        if {($kind eq "elbow" || [dict get $r status] eq "ok") && ![regexp {^[1-9][0-9]{0,5}$} [dict get $r k]]} { error "the $kind's record $i has no k" }
    }
}
proc ::VMDance::Session::check_picks {p} {
    if {![string is list $p] || [llength $p] % 2} { error "the frame picks are not a dictionary" }
    if {![dict size $p]} return
    foreach k {params input molecule frames rows vmdframes} {
        if {![dict exists $p $k]} { error "the frame picks have no \"$k\"" }
    }
    if {[catch {::VMDance::Results::_check_params "the frame picks' parameters" [dict get $p params] $::VMDance::Algo::pick_params} err]} { error $err }
    if {[catch {dict size [dict get $p input]}] || ![dict exists $p input mol] || ![dict exists $p input sel]} { error "the frame picks' input is corrupt" }
    if {[catch {::VMDance::Results::check_molecule "the frame picks' molecule record" [dict get $p molecule]} err]} { error $err }
    ::VMDance::Results::check_meta "the frame picks'" $p
    ::VMDance::Results::check_frames "the frame picks' frames" [dict get $p frames]
    set n [llength [dict get $p frames]]
    # (what tells their frames: picks of a session made before have none)
    ::VMDance::Results::check_atoms "the frame picks'" [dict get $p input] [::VMDance::_get [dict get $p molecule] numatoms ""] [dict get $p molecule]
    ::VMDance::Results::check_identity "the frame picks'" $p $n
    # (a frame is picked once: no more rows than frames, counted before they
    # are made)
    set nr [::VMDance::Results::_count [dict get $p rows]]
    if {$nr eq ""} { error "the frame picks' rows are not whole numbers" }
    if {$nr > $n} { error "the frame picks have more rows ($nr) than frames ($n)" }
    ::VMDance::Results::_intlist "the frame picks' rows" [dict get $p rows] $nr 0 [expr {$n - 1}]
    ::VMDance::Results::_intlist "the frame picks' VMD frames" [dict get $p vmdframes] $nr 0 ""
    # (what is drawn, gone to and saved: the frames of their rows, which
    # their digest tells)
    set fr [dict get $p frames]
    if {[lrange [dict get $p vmdframes] 0 end] ne [lmap r [dict get $p rows] {lindex $fr $r}]} { error "the frame picks' VMD frames are not those of their rows" }
}

# Read and check a session file; returns its dictionary.
proc ::VMDance::Session::read_file {file} {
    variable magic; variable old_magic; variable format; variable max_bytes; variable max_values
    set t [file tail $file]
    set file [file normalize $file]
    # (a file: a FIFO or a device would be read without end)
    if {![file isfile $file] || ![file readable $file]} { error "cannot read \"$file\" (not a readable file)" }
    set max $max_bytes
    if {[file size $file] > $max} { error "\"$t\" is larger than [expr {$max / 1000000}] MB: not a session" }
    set fh [open $file rb]
    set head [read $fh 2]
    seek $fh 0
    # (unpacked as it is read, at most max bytes: a small file can unpack to gigabytes)
    set gz [expr {$head eq "\x1f\x8b"}]
    if {$gz} { zlib push gunzip $fh }
    set bad [catch {read $fh [expr {$max + 1}]} raw]
    # (damaged data can show only when the stream ends, at close)
    if {[catch {close $fh}] && $gz} { set bad 1 }
    if {$gz && $raw eq ""} { set bad 1 }
    if {$bad} { error "\"$t\" is corrupt (bad gzip data)" }
    if {[string length $raw] > $max} { error "\"$t\" unpacks to more than [expr {$max / 1000000}] MB: not a session" }
    # (counted before anything is made of them: two bytes of text can cost
    # 120 once read)
    set nv [_values $raw]
    if {$nv > $max_values} {
        error "\"$t\" holds [_mb $nv $max_values] million values, more than the [_mb $max_values $nv] million a session can hold (a value takes about 120 bytes of memory once read; to open it, raise the limit: set ::VMDance::Session::max_values $nv)"
    }
    if {[catch {encoding convertfrom utf-8 $raw} text]} { error "\"$t\" is not a text file" }
    unset raw
    set nl [string first \n $text]
    if {$nl < 0} { error "\"$t\" is not a VMDance session" }
    set head [string range $text 0 [expr {$nl - 1}]]
    if {[catch {lindex $head 0} word] || ($word ne $magic && $word ni $old_magic)} { error "\"$t\" is not a VMDance session" }
    set ver [lindex $head 1]
    if {![string is integer -strict $ver] || $ver < 1} { error "\"$t\": bad session header" }
    if {$ver > $format} { error "\"$t\" uses session format $ver; this plugin reads up to $format" }
    set d [string range $text [expr {$nl + 1}] end]
    if {[catch {dict size $d}]} { error "\"$t\" is corrupt (not a dictionary)" }
    foreach k {runs current selection elbow sweep picks gui} {
        if {![dict exists $d $k]} { error "\"$t\" is incomplete (no \"$k\")" }
    }
    if {[catch {dict size [dict get $d gui]}]} { error "\"$t\" is corrupt (\"gui\")" }
    set runs [dict get $d runs]
    if {![string is list $runs] || ![llength $runs]} { error "\"$t\" has no run" }
    set ids {}
    set kept {}
    set i 0
    foreach r $runs {
        if {![string is list $r] || [llength $r] != 3} { error "\"$t\": run $i is corrupt" }
        lassign $r id label a
        if {![regexp {^[1-9][0-9]{0,8}$} $id] || $id in $ids} { error "\"$t\": run $i has an invalid id" }
        lappend ids $id
        # (a session made before keeps the distances between more clusters
        # than Measure::maxk: left out before they are read, as a run made
        # now has none; what is not whole is the check's)
        if {![catch {dict get $a nclusters} k] && [regexp {^[1-9][0-9]{0,8}$} $k] && $k > $::VMDance::Measure::maxk &&
            ![catch {dict get $a measures} ms] && ![catch {dict size $ms}]} {
            foreach key {rep_msd centroid_msd} { if {[dict exists $ms $key]} { dict set a measures $key {} } }
        }
        if {[catch {::VMDance::Results::check $a} err]} { error "\"$t\": run $id: $err" }
        set nk($id) [dict get $a nclusters]
        lappend kept [list $id $label $a]
        incr i
    }
    dict set d runs $kept
    if {[dict get $d current] ni $ids} { error "\"$t\": the current run is not in it" }
    set sel [dict get $d selection]
    # (clusters of the current run: at most k of them, of at most 9 digits
    # each, bounded before they are made)
    if {[string length $sel] > 10 * $nk([dict get $d current]) || ![string is list $sel]} { error "\"$t\": the selection is corrupt" }
    foreach x $sel { if {![regexp {^(0|[1-9][0-9]{0,8})$} $x]} { error "\"$t\": the selection is corrupt" } }
    foreach k {elbow sweep} {
        if {[catch {check_scan [dict get $d $k] $k} err]} { error "\"$t\": $err" }
    }
    if {[catch {check_picks [dict get $d picks]} err]} { error "\"$t\": $err" }
    return $d
}

# The molecules loaded that may be a molecule record's, in the order they
# are tried: {molid how} each, how files (its files, in full or as typed:
# VMD keeps a name as typed, of the folder it was in then, which it does
# not keep) or atoms (the same name), all of its number of atoms.
proc ::VMDance::Session::find_molecule {rec} {
    if {![dict size $rec]} { return {} }
    set paths [_paths $rec]
    set files {}; set named {}
    foreach m [molinfo list] {
        if {[molinfo $m get numatoms] != [dict get $rec numatoms]} continue
        if {[::VMDance::Mol::paths $m] eq $paths || [lindex [molinfo $m get filename] 0] eq [dict get $rec files]} {
            lappend files $m files
        } elseif {[molinfo $m get name] eq [dict get $rec name]} {
            lappend named $m atoms
        }
    }
    concat $files $named
}
# A record's files in full (one made before kept them as typed: of VMD's
# folder of now, then).
proc ::VMDance::Session::_paths {rec} {
    if {[dict exists $rec paths]} { return [dict get $rec paths] }
    lmap f [dict get $rec files] t [dict get $rec types] {
        if {$t eq "webpdb" || [catch {file normalize $f} p]} { set f } else { set p }
    }
}

# Why a molecule record's files are not loaded ("" when they can be). A
# session may be someone else's, and its files are read by VMD: each must
# be a file that is not empty (or a DESRES trajectory's folder) of one of
# VMD's file readers, named without the characters a shell acts on when
# reading it gives the name to one (the AMBER and NetCDF readers; the Babel
# converters, which are not readers, run a program on it). A reader opens
# files beside the one named too (VASP's POTCAR, a DESRES trajectory's
# own, SQLite's journal): none may be a FIFO or a device. (VMD waits on a
# FIFO for ever and reads a device without end; webpdb downloads the file.)
# files are Tcl's names; VMD must have one for each (Backend::vmd_name).
proc ::VMDance::Session::_unloadable {files types} {
    set readers {}
    foreach p [plugin list] {
        lassign $p kind name
        if {$kind eq "mol file reader" && $name ne "webpdb"} { lappend readers $name }
    }
    foreach f $files t $types {
        set n [file tail $f]
        # (VMD is given its name of the file: another with LANG=C, Backend::vmd_name)
        set v [::VMDance::Backend::vmd_name $f]
        if {($t ni $readers || $t in {parm parm7 netcdf}) && [regexp {[[:cntrl:]"'`$;|&<>\\]} $v]} {
            return "the name \"$f\" has a character a shell would act on, and reading it as $t gives the name to one (rename it, or its folder, load it, and open the session again)"
        }
        if {[catch {file stat $f st}] || ![file readable $f]} { return "\"$n\" is not a readable file" }
        if {$t ni $readers} { return "\"$n\" is of type \"$t\", not one of VMD's file readers a session uses" }
        # (a DESRES trajectory: its folder, or the clickme.dtr in it, every
        # file of it read; a stack of them names others, not looked at)
        if {$st(type) eq "directory" && $t eq "dtr"} {
            set w [_blocking $f 1]
        } elseif {$st(type) ne "file"} {
            return "\"$n\" is not a readable file"
        } elseif {$st(size) == 0} {
            return "\"$n\" is empty"
        } elseif {$t eq "dtr" && $n ne "clickme.dtr"} {
            return "\"$n\" is a stack of DESRES trajectories, whose files are not looked at (load it, and open the session again)"
        } else {
            set w [_blocking [file dirname $f] [expr {$t eq "dtr"}]]
        }
        if {$w ne ""} { return "\"$n\": $w (load it, and open the session again)" }
        if {$v eq ""} { return "with this locale ([encoding system]) VMD cannot open \"$n\" by its name: use a UTF-8 locale (LANG=C.UTF-8)" }
    }
    return ""
}
# What a reader could wait on in folder d (deep: in its folders too, as a
# reader follows links, each once, at most 1000): a FIFO or a device (or a
# link to one), said; "" when there is none.
proc ::VMDance::Session::_blocking {d deep} {
    set todo [list $d]
    set seen {}
    while {[llength $todo]} {
        set todo [lassign $todo d]
        if {[catch {file stat $d st}] || ![file readable $d]} { return "the folder \"$d\" cannot be read, to look for a FIFO or a device in it" }
        if {[dict exists $seen $st(dev),$st(ino)]} continue
        dict set seen $st(dev),$st(ino) 1
        if {[dict size $seen] > 1000} { return "more than 1000 folders to look for a FIFO or a device in" }
        foreach h {{} hidden} {
            set bad [glob -nocomplain -types [concat $h {p b c}] -directory $d *]
            if {[llength $bad]} { return "a reader could open \"[lindex $bad 0]\" with it, a FIFO or a device, and wait on it for ever" }
            if {!$deep} continue
            foreach s [glob -nocomplain -types [concat $h d] -directory $d *] {
                if {[file tail $s] ni {. ..}} { lappend todo $s }
            }
        }
    }
    return ""
}

# The files a molecule record may be loaded from, in the order they are
# tried: by their names in full; from the session's folder dir (moved with
# it: a relative name there, an absolute one by its last part); as typed,
# of VMD's folder of now (the names in full are made in the folder VMD is
# in when it is recorded, not the one a name was typed in). Each in full
# (a name is a file's, whatever the folder VMD runs in: checked and read as
# one), once; a name that cannot be read is left out.
proc ::VMDance::Session::_tries {rec dir} {
    # (Tcl's names of the files VMD named: another file with LANG=C,
    # Backend::tcl_name)
    set tries [list [lmap f [_paths $rec] {::VMDance::Backend::tcl_name $f}]]
    if {$dir ne ""} {
        lappend tries [lmap f [dict get $rec files] {
            set f [::VMDance::Backend::tcl_name $f]
            if {[file pathtype $f] eq "relative"} { file join $dir $f } else { file join $dir [file tail $f] }
        }]
    }
    lappend tries [lmap f [dict get $rec files] {::VMDance::Backend::tcl_name $f}]
    set out {}
    foreach try $tries {
        if {![catch {lmap f $try {file normalize $f}} files] && $files ni $out} { lappend out $files }
    }
    return $out
}
# Load a molecule record's files (in full, checked: _unloadable). Returns the
# molecule id, or an error that says why not.
proc ::VMDance::Session::_load {rec files} {
    set types [dict get $rec types]
    set why [_unloadable $files $types]
    if {$why ne ""} { error $why }
    set m -1
    if {[catch {
        foreach f $files t $types {
            set f [::VMDance::Backend::vmd_name $f]
            if {$m < 0} {
                set m [mol new $f type $t waitfor all]
            } else {
                mol addfile $f type $t waitfor all molid $m
            }
        }
    } err]} {
        if {$m >= 0} { catch {mol delete $m} }
        error "VMD could not read it"
    }
    if {[molinfo $m get numatoms] != [dict get $rec numatoms]} {
        set na [molinfo $m get numatoms]
        mol delete $m
        error "its files have $na atoms, not [dict get $rec numatoms]"
    }
    return $m
}

# Which molecule stands for d (a run, a scan or the picks: rec its
# molecule record), and the state of it to trust: {molid trust}, trust ""
# when it does not have d's frames (_has_frames says why). mol: auto (the
# molecules loaded that may be it, then its files, until one has d's
# frames: a user's of its files that has not is taken, not loaded again),
# load (its files), none, or an id. In the caller: mine(m) the molecules
# the session loaded (their frames are the plugin's to change), held(m)
# those something was found on (their frames kept), molof(key) the one
# loaded from files, for a record's atoms and frames. what names d, frames
# its frames, loses what cannot be done without them.
proc ::VMDance::Session::_mol_for {rec d mol what frames loses dir warnvar} {
    upvar 1 $warnvar warnings mine mine held held molof molof
    # (no record: the molecule was deleted while the job ran)
    if {![dict exists $rec files] || ![dict exists $rec numatoms]} {
        if {$mol ni {auto load none}} {
            set m [::VMDance::Mol::resolve "-mol" $mol]
            return [list $m [_has_frames $m $d 0 $what $frames $loses warnings]]
        }
        if {$mol ne "none"} { lappend warnings "$what: its molecule was not recorded (deleted while it was clustered): no 3D views, PRIME or similarity" }
        return {-1 ""}
    }
    if {$mol eq "none"} { return {-1 ""} }
    if {$mol ni {auto load}} {
        set m [::VMDance::Mol::resolve "-mol" $mol]
        if {[molinfo $m get numatoms] != [dict get $rec numatoms]} {
            error "molecule $m has [molinfo $m get numatoms] atoms; the session's has [dict get $rec numatoms]"
        }
        return [list $m [_has_frames $m $d 0 $what $frames $loses warnings]]
    }
    set take ""; set keep ""; set named ""
    if {$mol eq "auto"} {
        foreach {m how} [find_molecule $rec] {
            if {[_suits $m $d]} { set take [list $m $how]; break }
            if {[info exists mine($m)]} continue
            if {$how eq "files" && $keep eq ""} { set keep $m }
            if {$how eq "atoms" && $named eq ""} { set named $m }
        }
        if {$take eq "" && $keep ne ""} { set take [list $keep files] }
    }
    if {$take eq ""} {
        set why ""; set first ""; set new {}
        set key0 [list [dict get $rec numatoms] [::VMDance::_get $rec numframes ""]]
        foreach files [_tries $rec $dir] {
            set key [list $files {*}$key0]
            if {[info exists molof($key)] && [::VMDance::Mol::exists $molof($key)]} {
                set m $molof($key)
            } elseif {[catch {_load $rec $files} m]} {
                if {$why eq ""} { set why $m }
                continue
            } else {
                set mine($m) 1
                set molof($key) $m
                lappend new $m
            }
            if {[_suits $m $d]} { set take [list $m load]; break }
            if {$first eq ""} { set first $m }
        }
        if {$take eq "" && $first ne ""} { set take [list $first load] }
        # (those it loaded that it does not take: deleted)
        foreach m $new {
            if {$m == [lindex $take 0]} continue
            foreach k [array names molof] { if {$molof($k) == $m} { unset molof($k) } }
            unset mine($m)
            mol delete $m
        }
        if {$take eq "" && $named ne ""} { set take [list $named atoms] }
        if {$take eq ""} {
            if {$why ne ""} { set why " ($why)" }
            lappend warnings "$what: its molecule ([join [lmap f [dict get $rec files] {file tail $f}] {, }]) is not loaded and could not be$why: no 3D views, PRIME or similarity"
            return {-1 ""}
        }
    }
    lassign $take m how
    if {$how eq "atoms" && [::VMDance::Results::same_frames $m $d 0 ::VMDance::Session::prints] ne "1"} {
        lappend warnings "$what: molecule $m was taken because it has the name and number of atoms of the saved one, not its files"
    }
    set t [_has_frames $m $d [expr {[info exists mine($m)] && ![info exists held($m)]}] $what $frames $loses warnings]
    if {$t ne ""} { set held($m) 1 }
    list $m $t
}
# Whether molecule m can stand for d (_mol_for, in the caller's mine and
# held): it has d's frames at their numbers, or nothing tells them (no
# digest), or it is the session's own and not held, with frames before them
# it did not have then (_has_frames deletes them).
proc ::VMDance::Session::_suits {m d} {
    upvar 1 mine mine held held
    set v [::VMDance::Results::same_frames $m $d 0 ::VMDance::Session::prints]
    if {$v ne "0"} { return 1 }
    expr {[info exists mine($m)] && ![info exists held($m)] && [::VMDance::Results::extra_before $m $d ::VMDance::Session::prints] > 0}
}

# Whether molecule m has at their numbers the frames of d (a run, a scan or
# the picks) as they were made (Results::same_frames): the molecule's state
# to trust (Results::trusted), else "" and a warning that says why not. A
# molecule loaded here (mine) with frames before them that it did not have
# then (a PDB's own frame, deleted after it was loaded) has them deleted
# again; one of the user's is left as it is, and the warning says which
# frames to delete. (Nothing tells the frames of d without a digest: ""
# with no warning, Results::frames_ok then counts its frames; the picks
# then are refused, and said.) frames names them; loses says what cannot
# be done then.
proc ::VMDance::Session::_has_frames {m d mine what frames loses warnvar} {
    upvar 1 $warnvar warnings
    set v [::VMDance::Results::same_frames $m $d 0 ::VMDance::Session::prints]
    if {$v eq "1"} { return [::VMDance::Results::_now $m] }
    if {$v eq ""} {
        if {[dict exists $d rows]} { lappend warnings "$what: nothing tells $frames (saved before the picks kept it): $loses" }
        return ""
    }
    set extra [::VMDance::Results::extra_before $m $d ::VMDance::Session::prints]
    if {$extra > 0} {
        set n "$extra frame[expr {$extra == 1 ? "" : "s"}]"
        set last [expr {$extra - 1}]
        if {$mine} {
            animate delete beg 0 end $last $m
            lappend warnings "$what: molecule $m was loaded from its files with $n before $frames that it did not have then (a PDB's own frame?): deleted again"
            return [::VMDance::Results::_now $m]
        }
        lappend warnings "$what: molecule $m has $n before $frames that it did not have then (a PDB's own frame?): delete them (animate delete beg 0 end $last $m); until then $loses"
        return ""
    }
    lappend warnings "$what: molecule $m does not have $frames at their numbers (another trajectory under the same names, files changed since, frames deleted or added before them, or its coordinates changed): $loses"
    return ""
}

# A clustering of a session (a run, a scan's record's) as the plugin makes
# it now: one saved before kept the backend's placeholders, which are not
# numbers (Job::output, _do_similarity): a cluster without frames had MSD
# 0 and iSIM 0, every cluster a frame alone CH 1 and DB 0. (HELM's scores
# with a trim it kept as they were: CPP-MDANCE's, of the trimmed frames
# as one more cluster.)
proc ::VMDance::Session::_as_now {a} {
    set sizes [dict get $a sizes]
    dict set a msd [lmap v [dict get $a msd] n $sizes {if {$n} { set v } else { list }}]
    if {![::VMDance::Job::_scored $sizes]} { dict set a ch ""; dict set a db "" }
    if {[dict exists $a extras similarity]} {
        set m [dict get $a extras similarity]
        dict set m cluster [lmap v [dict get $m cluster] n $sizes {if {$n} { set v } else { list }}]
        dict set m outliers [lmap v [dict get $m outliers] n $sizes {if {$n} { set v } else { list -1 }}]
        dict set a extras similarity $m
    }
    return $a
}
# A scan of a session so: a record's scores its clustering's, and its
# number of clusters those with frames (Job::_record).
proc ::VMDance::Session::_scan_as_now {s} {
    if {![dict size $s]} { return $s }
    dict set s records [lmap r [dict get $s records] {
        if {[dict get $r status] eq "ok"} {
            set cl [_as_now [dict get $r clustering]]
            dict set r clustering $cl
            dict set r ch [dict get $cl ch]
            dict set r db [dict get $cl db]
            dict set r nclusters [llength [lsearch -all -not -exact [dict get $cl sizes] 0]]
        }
        set r
    }]
    return $s
}

# Open a session: its runs replace the current ones. mol: auto (find the
# molecules or load them), load (always load them), none, or a molecule id
# for every run. Each run, scan and the picks is checked against the
# molecule it is put on (_has_frames). Returns {warnings gui}.
proc ::VMDance::Session::load {file {mol auto}} {
    variable prints
    set d [read_file $file]
    set dir [file dirname [file normalize $file]]
    set warnings {}
    set runs {}
    set trust {}
    # (the molecules it loaded, those something was found to have its frames
    # on, which keep them: no frame of them is deleted after, and the one
    # loaded from files: _mol_for)
    array set mine {}
    array set held {}
    array set molof {}
    # (the fingerprints read for the checks, while it opens)
    array unset prints *
    try {
        set lost "no 3D views, goto, user field, structure exports, PRIME or similarity for it"
        foreach r [dict get $d runs] {
            lassign $r id label a
            set a [_as_now $a]
            lassign [_mol_for [dict get $a molecule] $a $mol "run $id" "the clustered frames" $lost $dir warnings] m t
            dict set a request mol $m
            if {$t ne ""} { dict set trust $id $t }
            lappend runs [list $id $label $a]
        }
        set scans {}
        foreach k {elbow sweep} {
            set s [_scan_as_now [dict get $d $k]]
            if {[dict size $s]} {
                set m [lindex [_mol_for [dict get $s molecule] $s $mol "the $k" "the frames it scanned" "its records cannot be made runs" $dir warnings] 0]
                dict set s request mol $m
            }
            dict set scans $k $s
        }
        set p [dict get $d picks]
        set pt ""
        if {[dict size $p]} {
            lassign [_mol_for [dict get $p molecule] $p $mol "the frame picks" "the frames they were picked from" \
                "they are listed only: pick them again" $dir warnings] m pt
            dict set p input mol $m
        }
    } finally {
        array unset prints *
    }
    ::VMDance::Results::set_runs $runs [dict get $d current] $trust
    set sel [lmap x [dict get $d selection] {expr {$x < [::VMDance::Results::nclusters] ? $x : [continue]}}]
    ::VMDance::Results::set_selection $sel
    ::VMDance::Results::set_elbow [dict get $scans elbow]
    ::VMDance::Results::set_sweep [dict get $scans sweep]
    ::VMDance::Results::set_picks $p $pt
    variable current_file [file normalize $file]
    return [list $warnings [dict get $d gui]]
}

#---------------------------------------------------------------------------
# Sessions of the MDANCE plugin (.mdance), imported
#---------------------------------------------------------------------------

# The MDANCE plugin's parameters, by algorithm: its name -> ours.
namespace eval ::VMDance::Session {
    variable old_params {
        kmeans {kinit kinit percentage percentage}
        divine {split split anchors anchors kinit kinit refine refine threshold threshold end-mode end-mode percentage percentage}
        helm {merge-scheme merge-scheme eps eps trim-start trim-start trim-k trim-k trim-val trim-val min-samples min-samples
              pre-k initial pre-kinit initial-kinit pre-percentage initial-percentage initial-labels initial-labels}
        equal {threshold threshold seed-method seed-method n-seeds n-seeds percentage percentage min-samples min-samples
               check-sim check-sim sim-threshold sim-threshold reject-lowd reject-lowd}
    }
}

# Read an MDANCE plugin session as data: {request {...} answer {...}
# signature {...} molid frames nstart unrecorded warnings}, the request
# without its molecule, the answer the backend's keys (Job::output checks
# it), nstart the starting clusters HELM asked for ("" when not said),
# unrecorded what the file does not say of how it was made (metric params),
# warnings what was assumed. mol: the molecule it is for, an id or auto (any
# loaded), whose frames bound what is read (more than they can hold, with
# auto: an error coded {VMDANCE NOMOL most}, a molecule of more than
# the most frames loaded needed, as old_candidates').
proc ::VMDance::Session::read_old {file {mol auto}} {
    variable old_params
    set t [file tail $file]
    set file [file normalize $file]
    if {![file isfile $file] || ![file readable $file]} { error "cannot read \"$file\" (not a readable file)" }
    # (a session of a million frames is about 15 MB)
    if {[file size $file] > 100000000} { error "\"$t\" is larger than 100 MB: not a session of the MDANCE plugin" }
    set fh [open $file r]
    try { set text [read $fh 100000000] } finally { close $fh }
    # (its values are counted before any is made, each about 120 bytes once
    # made: a clustering of n frames holds its labels and frames, its
    # clusters' sizes, representatives and MSDs, and HELM's merges, fewer
    # than 8n; a file of more than a clustering of the frames it can be put
    # on can hold is refused before it is parsed, as old_candidates refuses.
    # Its selection, in results and inputParams, is VMD's text, never made
    # a list, and an index list can make it long: counted apart (in braces,
    # as the plugin writes it, within 4 MB), and bounded on its own (VMD's
    # own parser fails on a few hundred thousand words))
    set nv [_values $text]
    lassign [_old_most $mol] most m
    set i 0
    foreach - {results inputParams} {
        if {$nv <= 8 * $most + 100000} break
        set i [_first atomsel $text $i]
        if {$i < 0} break
        set g atomsel
        if {[regexp {^atomsel\s+\{([^{}]*)\}} [string range $text $i [expr {$i + 4194303}]] g sel]} {
            set w [_values $sel]
            if {$w >= 200000} { error "\"$t\": its selection is longer than an import takes (more than 200000 words)" }
            incr nv -$w
        }
        incr i [string length $g]
    }
    if {$nv > 8 * $most + 100000} {
        if {$m ne ""} { error "molecule $m has $most frames, too few for \"$t\" ($nv values)" }
        return -code error -errorcode [list VMDANCE NOMOL $most] \
            "\"$t\" holds $nv values, more than a clustering of the frames loaded can (the most a molecule has is $most): its molecule is not loaded"
    }
    if {[catch {dict size $text}] || ![dict exists $text mdanceSession] || ![dict exists $text results]} {
        error "\"$t\" is not a session of the MDANCE plugin"
    }
    set r [dict get $text results]
    if {[catch {dict size $r}]} { error "\"$t\": its results are corrupt" }
    foreach k {algorithm labels nClusters representatives atomsel} {
        if {![dict exists $r $k]} { error "\"$t\": its results have no \"$k\"" }
    }
    set a [dict get $r algorithm]
    if {![::VMDance::Algo::exists $a]} { error "\"$t\": unknown algorithm \"$a\"" }
    # (whatever the count above: one not in braces, or with frames enough
    # loaded, passed it)
    if {[_values [dict get $r atomsel]] >= 200000} { error "\"$t\": its selection is longer than an import takes (more than 200000 words)" }
    set labels [dict get $r labels]
    if {![string is list $labels]} { error "\"$t\": its labels are corrupt" }
    set n [llength $labels]
    if {[dict exists $r frames]} { set frames [dict get $r frames] } else { set frames {}; for {set i 0} {$i < $n} {incr i} { lappend frames $i } }
    if {![string is list $frames] || [llength $frames] != $n} { error "\"$t\": its frames are not its labels'" }
    foreach f $frames { if {![regexp {^[0-9]+$} $f]} { error "\"$t\": its frames are corrupt" } }
    # (scan: 010 is 10, which expr would read as octal)
    set frames [lmap f $frames {scan $f %d}]
    if {$n < 2} { error "\"$t\" has fewer than 2 frames" }
    # the frames as first, last and step
    set first [lindex $frames 0]; set step [expr {[lindex $frames 1] - $first}]
    if {$step < 1} { error "\"$t\": its frames are not in order" }
    set i 0
    foreach f $frames { if {$f != $first + $i * $step} { error "\"$t\": its frames are not every n-th of a range" }; incr i }
    # (the strings read as they are: expr's ?: would make "010" 8 and fail
    # on "NaN")
    set ip [::VMDance::_get $r inputParams {}]
    set warnings {}
    # (a configuration of its sweep made the clustering with Load Selected:
    # no inputParams. MSD and the defaults are assumed, and said to be not
    # recorded, not shown as what was run)
    set unrecorded {}
    if {[catch {dict size $ip} np] || !$np} {
        set ip {}
        set unrecorded {metric params}
        lappend warnings "the file does not record its metric and parameters (the MDANCE plugin saved a configuration of its sweep without them): MSD and the defaults are assumed, and the run says they are not recorded"
    }
    set params {}
    dict for {old new} [dict get $old_params $a] {
        if {![dict exists $ip $old]} continue
        set v [dict get $ip $old]
        set spec [::VMDance::Algo::param $a $new]
        # (a number as the MDANCE plugin took it (string is integer, string
        # is double): zero-padded, as mdance-cli read it; its library (Tcl)
        # read 010 as 8, and the file does not say which ran)
        if {[lindex $spec 1] in {int real} && [regexp {^([-+]?)(0+([0-9].*))$} [string trim $v] -> sg pad v]} {
            if {[regexp {^0[0-7]+$} $pad] && [scan $pad %o] != [scan $v %d]} {
                lappend warnings "its $old, \"$sg$pad\", is [scan $sg$v %d] to mdance-cli and [scan $sg$pad %o] to its library, and the file does not say which ran: taken as [scan $sg$v %d]"
            }
            set v $sg$v
        }
        # (checked as a stored request's, and named as the file names it:
        # "-initial" is its pre-k)
        if {[catch {::VMDance::Algo::check_value $spec $v 1} v]} { error "\"$t\": its $old[string range $v [string length -$new] end]" }
        dict set params $new $v
    }
    set metric [::VMDance::_get $ip metric MSD]
    # (HELM's starting clusters, when it asked for a first clustering of so
    # many: Session::old_merges)
    set nstart ""
    if {![dict exists $ip initial-labels] && [regexp {^\+?([1-9][0-9]{0,8})$} [string trim [::VMDance::_get $params initial ""]] -> d]} { set nstart [scan $d %d] }
    set k ""
    if {[::VMDance::Algo::takes_k $a]} {
        set nc [dict get $r nClusters]
        set k [string trim [::VMDance::_get $ip nclusters $nc]]
        # (a whole number as the MDANCE plugin took it: mdance-cli read 010
        # as 10, its library (Tcl) as 8, and the file does not say which
        # ran: the reading that is the clusters it found, else mdance-cli's)
        if {![regexp {^\+?([0-9]{1,9})$} $k -> d]} { error "\"$t\": its number of clusters is \"$k\"" }
        set k [scan $d %d]
        if {[regexp {^0[0-7]+$} $d] && [scan $d %o] != $k} {
            set o [scan $d %o]
            if {[regexp {^([0-9]{1,9})(\.0*)?$} $nc -> nci] && [scan $nci %d] == $o} {
                set k $o
            } elseif {![info exists nci] || [scan $nci %d] != $k} {
                lappend warnings "its number of clusters, \"$d\", is $k to mdance-cli and $o to its library, and the file does not say which ran: taken as $k"
            }
        }
    }
    set req [dict create sel [dict get $r atomsel] fit "" first $first last [lindex $frames end] step $step \
        algorithm $a k $k metric $metric params $params]
    # (the name and frames of its molecule, when the plugin knew them as it
    # saved: molKnown 1; not when it was deleted first, nor in files made
    # before it kept them, nor when damaged)
    set sig [::VMDance::_get $text molSignature {}]
    set known {}
    if {![catch {dict size $sig}] && [::VMDance::_get $sig molKnown 0] eq "1"} {
        if {[dict exists $sig molName]} { dict set known molName [dict get $sig molName] }
        if {[regexp {^[0-9]{1,9}$} [::VMDance::_get $sig molFrames ""]]} { dict set known molFrames [scan [dict get $sig molFrames] %d] }
    }
    set molid [::VMDance::_get $r molid ""]
    if {![regexp {^[0-9]{1,9}$} $molid]} { set molid "" }
    # (merges are HELM's only: another's would be drawn as HELM's tree)
    if {$a ne "helm"} { set r [dict remove $r zMatrix] }
    list request $req answer [dict filter $r key nClusters labels clusterSizes representatives clusterMSD \
        score_calinskiHarabasz score_daviesBouldin zMatrix] signature $known molid $molid frames $frames \
        nstart $nstart unrecorded $unrecorded warnings $warnings
}

# The most frames a molecule an imported session may be put on has, and
# that molecule when it is given: {frames molid}, molid "" for auto (every
# molecule loaded).
proc ::VMDance::Session::_old_most {mol} {
    if {$mol ne "auto"} {
        set m [::VMDance::Mol::resolve "-mol" $mol]
        return [list [molinfo $m get numframes] $m]
    }
    set most 0
    foreach m [molinfo list] { set most [expr {max($most, [molinfo $m get numframes])}] }
    list $most ""
}

# HELM's merges in a session of the MDANCE plugin, cl its answer as
# Job::output reads it, params its request's, nstart the starting clusters
# it asked for (read_old): {merges why}, why "" or what was left out. The
# plugin kept no starting clusters, and CPP-MDANCE numbers HELM's leaves
# among them all, trimmed ones too, and its merges from the number kept:
# after a trimming (its frames are noise, -1) they cannot be placed.
# Stopped by -eps (more than one cluster left), an mdance-cli before
# CPP-MDANCE 4042c24 kept the merge -eps refused as its last row, and one
# of now does not: the reading that fits is taken (each row's count of
# starting clusters, no more than nstart of them); when both do, neither
# (the rows of all nstart are also those of one fewer and the refused
# merge: NANI can leave a starting cluster empty).
# Merges that cannot be placed are left out: the tree is then the linkage
# of the mean structures (Results::tree_kind); the clustering is never
# refused for them.
proc ::VMDance::Session::old_merges {cl params nstart} {
    set z [dict get $cl zmatrix]
    set k [dict get $cl nclusters]
    set labels [dict get $cl labels]
    set linkage "the tree is the linkage of the mean structures"
    if {[lsearch -exact $labels -1] >= 0} {
        # (untrimmed too: an mdance-cli before 4042c24 left frames in no
        # cluster when NANI had left starting clusters empty)
        set which "those of its frames in no cluster (-1)"
        if {[::VMDance::_get $params trim-start 0]} { set which "the trimmed ones" }
        return [list {} "HELM's merges left out: they are numbered among its starting clusters, $which too, which the MDANCE plugin did not keep ($linkage)"]
    }
    set all [_old_fits $z $labels $k $nstart]
    # (as the backend read it, a C float: -0.99999999 is its -1)
    binary scan [binary format f [dict get $params eps]] f eps
    if {$eps != -1 && $k > 1 && [_old_fits [lrange $z 0 end-1] $labels $k $nstart]} {
        if {$all} {
            return [list {} "HELM's merges left out: -eps stopped it, and whether its last merge is the one -eps refused, which the mdance-cli of the MDANCE plugin (before CPP-MDANCE 4042c24) kept, cannot be told ($linkage)"]
        }
        return [list [lrange $z 0 end-1] "HELM's last merge left out: -eps refused it, and the mdance-cli of the MDANCE plugin (before CPP-MDANCE 4042c24) kept it"]
    }
    if {!$all} { return [list {} "HELM's merges left out: they do not fit its clusters ($linkage)"] }
    list $z ""
}
# Whether HELM's merges z join starting clusters (no more than nstart, ""
# not known) into the k clusters of labels.
proc ::VMDance::Session::_old_fits {z labels k nstart} {
    expr {($nstart eq "" || [llength $z] + $k <= $nstart) && ![catch {::VMDance::Measure::helm_tree $z {} $labels $k}]}
}

# The molecules an imported session may be of, in the order they are
# tried (Job::_do_import takes the first whose coordinates give the file's
# cluster MSDs): {molid exact} each. mol: an id; or auto, the molecules with
# its frames, of the name the plugin recorded (when it knew it), those of
# the number of frames it recorded too first (exact; frames added since are
# told by the coordinates), the one of the molecule id it recorded first
# among them (VMD numbers molecules afresh in each of its sessions: an
# order only). None: an error coded {VMDANCE NOMOL last}, last the last
# frame clustered (a molecule of more frames needed), whose message names no
# option (the command and the window say what to do).
proc ::VMDance::Session::old_candidates {d mol} {
    set last [lindex [dict get $d frames] end]
    if {$mol ne "auto"} {
        set m [::VMDance::Mol::resolve "-mol" $mol]
        if {[molinfo $m get numframes] <= $last} { error "molecule $m has [molinfo $m get numframes] frames; the session clustered frames up to $last" }
        return [list [list $m 1]]
    }
    set sig [dict get $d signature]
    set exact {}
    set other {}
    set few {}
    foreach m [molinfo list] {
        if {[dict exists $sig molName] && [molinfo $m get name] ne [dict get $sig molName]} continue
        set nf [molinfo $m get numframes]
        if {$nf <= $last} { lappend few "molecule $m has $nf frames"; continue }
        set x [expr {[dict size $sig] && (![dict exists $sig molFrames] || $nf == [dict get $sig molFrames])}]
        set to [expr {$x ? "exact" : "other"}]
        if {$m eq [dict get $d molid]} { set $to [linsert [set $to] 0 [list $m $x]] } else { lappend $to [list $m $x] }
    }
    set out [concat $exact $other]
    if {![llength $out]} {
        set what {}
        if {[dict exists $sig molName]} { lappend what [dict get $sig molName] }
        if {[dict exists $sig molFrames]} { lappend what "[dict get $sig molFrames] frames" }
        set name ""
        if {[llength $what]} { set name " ([join $what {, }])" }
        set why ""
        if {[llength $few]} { set why " ([join $few {, }]: it clustered frames up to $last)" }
        return -code error -errorcode [list VMDANCE NOMOL $last] "its molecule$name is not loaded$why"
    }
    return $out
}
