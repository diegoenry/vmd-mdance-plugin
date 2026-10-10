#
# VMDance - the coordinates a clustering reads (no Tk dependency)
#
# One row per analysed frame: the x y z of every atom of the selection, in
# the selection's order (3 × natoms numbers). The rows are what the
# backend clusters, and what the plugin's own measures (distances to the
# representatives, between the clusters' centres, the silhouette) are
# computed from, so both see the same numbers.
#
# The rows are written to a CSV file of the plugin's private folder as the
# frames are read — the program's input, written whatever the backend — and
# are not kept in memory: the measures read them again (Coords::each). A
# trajectory of any length takes the memory of a few rows, but for the
# library: it is given them as one list for a job's calls (Coords::flat,
# kept by Job::_call until the job ends: a scan's every k), of
# which CPP-MDANCE's Tcl binding makes a text too, about 180 bytes a number
# at the call's peak, about 120 of them kept by Tcl until VMD quits
# (Job::_library_fits refuses a call that cannot fit). Coordinates that are
# not numbers (NaN, infinite) are refused as they are read, naming the
# frame.
#
# The selection is read once, at the first analysed frame, and the same
# atoms are read at every frame: a selection whose text can change with the
# frame (within, x, user ...) is refused. With a fit selection, every frame
# is first superposed on the first analysed frame by those atoms, on the
# values: VMD's own coordinates are never moved.
#
# The last extraction is kept (Coords::cached), so that the questions that
# follow a clustering (an elbow scan, PRIME, similarity, frame picks) do not
# read the trajectory again. Every frame's coordinates have a fingerprint
# (_print: the selection's centre, radius of gyration, weighted centre and
# RMSD from the first frame, and the fit's, in C): the kept rows are used
# only while every frame's is unchanged — coordinates moved in place (an
# alignment) are read again — and the rows read again from VMD for the
# measures are checked against them, so that the measures are those of the
# rows the backend clustered (a check: a change below a float's last digit
# in every one of its numbers would pass). The rows of a molecule deleted
# are dropped at once, and the file of rows dropped while a job runs is
# deleted when the job ends (reap).
#

namespace eval ::VMDance::Coords {
    variable C {}          ;# the kept extraction ({} = none)
    variable doomed {}     ;# files dropped while a job ran
}

# The input part of a request, which the extraction depends on: the
# atoms themselves (a selection text can select others after a change of
# the structure), else the texts.
proc ::VMDance::Coords::key {req} {
    set m [dict get $req mol]
    set a [::VMDance::_get $req atoms [dict get $req sel]]
    set f [::VMDance::_get $req fitatoms [dict get $req fit]]
    list $m [molinfo $m get numatoms] [molinfo $m get numframes] [lindex [molinfo $m get filename] 0] $a [dict get $req frames] $f
}

# The kept extraction for a request, or {}: the same molecule, atoms and
# frames, and every frame's coordinates as they were (a pass over the
# frames, yielding in a coroutine).
proc ::VMDance::Coords::cached {req {cancelled ""}} {
    variable C
    # (the rows of a molecule deleted: never asked for again)
    if {[dict size $C] && ![::VMDance::Mol::exists [dict get $C mol]]} { forget }
    if {![dict size $C] || ![::VMDance::Mol::exists [dict get $req mol]]} { return {} }
    if {[dict get $C key] ne [key $req]} { return {} }
    if {![file exists [dict get $C csv]] || ![unchanged $C $cancelled]} { forget; return {} }
    return $C
}
# Drop the kept extraction and its file (while a job runs, the file is
# deleted when it ends: the job may be reading it).
proc ::VMDance::Coords::forget {} {
    variable C; variable doomed
    if {[dict size $C] && [dict get $C csv] ne ""} {
        if {[::VMDance::Job::busy]} { lappend doomed [dict get $C csv] } else { catch {file delete [dict get $C csv]} }
    }
    set C {}
}
# The files dropped while the job ran (Job, when a job ends).
proc ::VMDance::Coords::reap {} {
    variable doomed; variable C
    foreach f $doomed {
        if {[dict size $C] && [dict get $C csv] eq $f} continue
        catch {file delete $f}
    }
    set doomed {}
}
# A molecule deleted (VMD writes 0 into vmd_initialize_structure(molid),
# once it is gone): its kept rows go (VMD never gives its number to another
# molecule). (An error here would fail VMD's own mol delete.)
proc ::VMDance::Coords::_mol_gone {name m op} {
    variable C
    catch {
        if {[dict size $C] && [dict get $C mol] eq $m && ![::VMDance::Mol::exists $m]} { forget }
    }
}
if {[info commands molinfo] ne "" &&
    [lsearch -exact [trace info variable ::vmd_initialize_structure] {write ::VMDance::Coords::_mol_gone}] < 0} {
    trace add variable ::vmd_initialize_structure write ::VMDance::Coords::_mol_gone
}

# Selections of the atoms of an extraction at a frame and at its first
# frame (r0: every frame's RMSD from it), and the weights of their
# fingerprints (one per atom): {s fs ref w wf r0} (fs, ref and wf "" without
# a fit; ref the fit's atoms at the first frame). Free them with close.
proc ::VMDance::Coords::_open {m atoms fitatoms f0} {
    set s [::VMDance::Mol::sel $m $atoms $f0]
    set fs ""; set ref ""; set wf ""; set r0 ""
    if {[catch {
        set r0 [::VMDance::Mol::sel $m $atoms $f0]
        if {$fitatoms ne ""} {
            set fs [::VMDance::Mol::sel $m $fitatoms $f0]
            set ref [::VMDance::Mol::sel $m $fitatoms $f0]
        }
    } err]} { ::VMDance::Mol::free $s $r0 $fs $ref; error $err }
    if {$fs ne ""} { set wf [_weights [$fs num]] }
    list $s $fs $ref [_weights [$s num]] $wf $r0
}
proc ::VMDance::Coords::_close {h} { ::VMDance::Mol::free {*}[lrange $h 0 2] [lindex $h 5] }
# A frame's fingerprint, from VMD's coordinates by VMD's own C code (no
# list of numbers made): the atoms' centre, their radius of gyration, their
# centre weighted by their place, and their RMSD from the first frame (r).
# The first two do not change when atoms swap places or a frame turns about
# its centre; the weighted centre does, but its weights repeat every 1009
# atoms, and a frame turned or mirrored about the line through the two
# centres keeps both; the RMSD from the first frame changes then (and a
# change of the first frame changes every other's). The weights are fixed
# numbers from 1 to 2. (Lists and vecdot or veclength2, which are Tcl
# procedures, took 110 µs a frame of 217 atoms; this takes 10, 3 of them
# the RMSD.)
proc ::VMDance::Coords::_weights {n} {
    set out {}
    for {set j 0} {$j < $n} {incr j} { lappend out [expr {1.0 + (($j * 7919 + 13) % 1009) / 1009.0}] }
    return $out
}
proc ::VMDance::Coords::_print {sel w r} {
    concat [measure center $sel] [measure rgyr $sel] [measure center $sel weight $w] [measure rmsd $sel $r]
}
# A frame's row (fitted when there is a fit) and the fingerprint of its
# coordinates: {row fp}. Coordinates that are not numbers are refused
# here, before the fit and before any backend: their fingerprint is not
# (NaN or infinite: a simulation that blew up, a damaged file; mdance-cli
# named its CSV row, the library took an infinity and answered).
proc ::VMDance::Coords::_row {h f} {
    lassign $h s fs ref w wf r0
    $s frame $f
    set xyz [$s get {x y z}]
    # (concat of lists keeps the numbers: no text in between)
    set raw [concat {*}$xyz]
    set fp [_print $s $w $r0]
    if {[regexp -nocase {nan|inf} $fp]} { _not_finite $s $f "the selection" }
    if {$fs eq ""} { return [list $raw $fp] }
    $fs frame $f
    set ff [_print $fs $wf $ref]
    if {[regexp -nocase {nan|inf} $ff]} { _not_finite $fs $f "the fit selection" }
    lappend fp {*}$ff
    set M [measure fit $fs $ref]
    # (a point: as coordtrans does it, vectrans of {x y z 1} — a vector of 3
    # would drop the translation — without its procedure call per atom)
    set out {}
    foreach v $xyz { lappend out {*}[lrange [vectrans $M [linsert $v end 1]] 0 2] }
    list $out $fp
}
# The error of a frame whose fingerprint is not finite (what: the
# selection, or the fit's), naming the VMD frame and its first atom whose
# coordinates are not numbers; with none, they are too large for VMD to
# measure (about 1e19 Å).
proc ::VMDance::Coords::_not_finite {sel f what} {
    set m [$sel molid]
    set how "too large to measure (in $what)"
    foreach a [$sel get {index x y z}] {
        if {[regexp -nocase {nan|inf} [lrange $a 1 3]]} {
            set how "that are not numbers (NaN or infinite: atom [lindex $a 0] of $what, the first)"
            break
        }
    }
    error "-first, -last, -step: frame $f of molecule $m has coordinates $how: leave the frame out, or delete it (animate delete beg $f end $f $m)"
}
proc ::VMDance::Coords::_fp {h f} {
    lassign $h s fs ref w wf r0
    $s frame $f
    set fp [_print $s $w $r0]
    if {$fs ne ""} {
        $fs frame $f
        lappend fp {*}[_print $fs $wf $ref]
    }
    return $fp
}
# Whether every frame's coordinates are those an extraction read.
proc ::VMDance::Coords::unchanged {c {cancelled ""}} {
    set frames [dict get $c frames]
    set h [_open [dict get $c mol] [dict get $c atoms] [dict get $c fitatoms] [lindex $frames 0]]
    try {
        set slice [clock milliseconds]
        foreach f $frames fp [dict get $c fp] {
            if {[_fp $h $f] ne $fp} { return 0 }
            _breathe slice $cancelled
        }
    } finally {
        _close $h
    }
    return 1
}
# In a coroutine: let the window work every 40 ms, and stop on Cancel.
proc ::VMDance::Coords::_breathe {slicevar cancelled} {
    upvar 1 $slicevar slice
    if {[info coroutine] eq "" || [clock milliseconds] - $slice <= 40} return
    after 1 [info coroutine]
    yield
    set slice [clock milliseconds]
    if {$cancelled ne "" && [set $cancelled]} { error "cancelled" }
}

# Check the selections of a request; returns {natoms indices fitindices}.
proc ::VMDance::Coords::check_selection {m sel fit {what ""}} {
    set p [expr {$what eq "" ? "" : "$what: "}]
    set t [string trim $sel]
    if {$t eq ""} { error "${p}-sel: no atom selection" }
    # (a selection first: chain "x without its end quote is no selection,
    # not one whose atoms change with the frame)
    if {[catch {::VMDance::Mol::atoms $m $t} idx]} { error "${p}-sel: $idx" }
    set w [::VMDance::Mol::dynamic $t]
    if {$w ne ""} {
        error "${p}-sel: the selection \"$t\" can match other atoms in other frames (\"$w\"); a clustering compares the same atoms in every frame: name them (e.g. \"protein and name CA\")"
    }
    if {![llength $idx]} { error "${p}-sel: the selection \"$t\" matches no atom of molecule $m" }
    set fidx {}
    set f [string trim $fit]
    if {$f ne ""} {
        if {[catch {::VMDance::Mol::atoms $m $f} fidx]} { error "${p}-fit: $fidx" }
        set w [::VMDance::Mol::dynamic $f]
        if {$w ne ""} { error "${p}-fit: the fit selection \"$f\" can match other atoms in other frames (\"$w\")" }
        if {[llength $fidx] < 3} { error "${p}-fit: a fit needs at least 3 atoms (\"$f\" matches [llength $fidx])" }
    }
    list [llength $idx] $idx $fidx
}

# Read the coordinates of a checked request into a CSV file: {key natoms
# frames csv seconds}. In a coroutine it yields every 40 ms (and stops
# when `cancelled` names a true variable); progress {fraction message} is
# called along the way.
proc ::VMDance::Coords::extract {req {progress ""} {cancelled ""}} {
    variable C
    set c [cached $req $cancelled]
    if {[dict size $c]} { return $c }
    set m [dict get $req mol]
    set frames [dict get $req frames]
    # (the atoms the request was checked with: its texts may select others
    # now, "beta > 0", and the key names those)
    lassign [check_selection $m [::VMDance::_get $req atoms [dict get $req sel]] \
        [::VMDance::_get $req fitatoms [dict get $req fit]]] natoms idx fidx
    set atoms [::VMDance::Mol::index_text $idx]
    set fitatoms [expr {[llength $fidx] ? [::VMDance::Mol::index_text $fidx] : ""}]
    set t0 [clock milliseconds]
    set csv [::VMDance::Backend::tmpfile .csv]
    set tmp $csv.part
    set h [_open $m $atoms $fitatoms [lindex $frames 0]]
    set fh ""
    set fps {}
    try {
        set fh [open $tmp w]
        fconfigure $fh -buffering full -buffersize 1048576
        set n [llength $frames]
        set slice [clock milliseconds]
        set k 0
        foreach f $frames {
            lassign [_row $h $f] row fp
            puts $fh [join $row ,]
            lappend fps $fp
            incr k
            if {[info coroutine] ne "" && [clock milliseconds] - $slice > 40} {
                if {$progress ne ""} { {*}$progress [expr {double($k) / $n}] "reading frame $k of $n" }
                after 1 [info coroutine]
                yield
                set slice [clock milliseconds]
                if {$cancelled ne "" && [set $cancelled]} { error "cancelled" }
                if {![::VMDance::Mol::exists $m]} { error "molecule $m was deleted while its frames were read" }
                if {[molinfo $m get numframes] <= [lindex $frames end]} { error "frames of molecule $m were deleted while they were read" }
            }
        }
        set e [catch {close $fh} err eo]
        set fh ""
        if {$e} { return -options $eo $err }
        file rename -force $tmp $csv
    } on error {msg opts} {
        if {$fh ne ""} { catch {close $fh} }
        file delete $tmp $csv
        # (a full disk shows at a write, once the buffer is full, or at close:
        # said with the folder, not Tcl's name of the file)
        if {[lindex [dict get $opts -errorcode] 0] eq "POSIX"} {
            error "the coordinates could not be written to [file dirname $csv] ([lindex [dict get $opts -errorcode] end]): free room there, or set TMPDIR to another folder"
        }
        return -options $opts $msg
    } finally {
        _close $h
    }
    forget
    # (the digest of every frame's fingerprint: a clustering and its scans
    # keep it, so that a question asked later reads the same coordinates)
    set C [dict create key [key $req] natoms $natoms frames $frames csv $csv mol $m \
        atoms $atoms fitatoms $fitatoms fp $fps digest [_digest $fps] \
        seconds [expr {([clock milliseconds] - $t0) / 1000.0}]]
    return $C
}

# The digest of the frames' fingerprints: "2:" and two checksums. Version
# 1, that of results made before the fingerprint had its RMSD (sessions
# keep it), is made of the same fingerprints without it: a digest is
# always compared as it was made (same_prints).
proc ::VMDance::Coords::_digest {fps {version 2}} {
    if {$version == 1} {
        # (the RMSD is the 8th number of the selection's, and of the fit's)
        set fps [lmap fp $fps {
            if {[llength $fp] > 8} { concat [lrange $fp 0 6] [lrange $fp 8 14] } else { lrange $fp 0 6 }
        }]
    }
    set d [join $fps]
    format [expr {$version == 1 ? "" : "2:"}]%08x%08x [zlib crc32 $d] [zlib adler32 $d]
}
# Whether fingerprints are those a digest was made of (in its version).
proc ::VMDance::Coords::same_prints {fps digest} {
    expr {[_digest $fps [expr {[string match 2:* $digest] ? 2 : 1}]] eq $digest}
}
# Whether the coordinates an extraction read are those a digest was made of.
proc ::VMDance::Coords::same {c digest} {
    if {[string match 2:* $digest]} { return [expr {[dict get $c digest] eq $digest}] }
    same_prints [dict get $c fp] $digest
}
# The fingerprints of frames of molecule m as a clustering of these atoms
# (fitted on fitatoms) has them; memo (an array's name: a session's checks
# as it opens) keeps them for the molecule's number of frames.
proc ::VMDance::Coords::prints_of {m atoms fitatoms frames {memo ""}} {
    if {$memo ne ""} {
        upvar #0 $memo M
        set key [list $m [molinfo $m get numframes] $atoms $fitatoms $frames]
        if {[info exists M($key)]} { return $M($key) }
    }
    lassign [check_selection $m $atoms $fitatoms] natoms idx fidx
    set h [_open $m [::VMDance::Mol::index_text $idx] [expr {[llength $fidx] ? [::VMDance::Mol::index_text $fidx] : ""}] [lindex $frames 0]]
    try {
        set fps [lmap f $frames {_fp $h $f}]
    } finally {
        _close $h
    }
    if {$memo ne ""} { set M($key) $fps }
    return $fps
}
# The fingerprints of frames f0 and f1 of molecule m, of these atoms (as
# an extraction has them, f0 its first frame): whether the frames there are
# still those it read (Results::_trust).
proc ::VMDance::Coords::ends {m atoms fitatoms f0 f1} {
    set h [_open $m $atoms $fitatoms $f0]
    try { list [_fp $h $f0] [_fp $h $f1] } finally { _close $h }
}
# Their digest: whether they are the coordinates a clustering read.
proc ::VMDance::Coords::digest_of {m atoms fitatoms frames} {
    _digest [prints_of $m $atoms $fitatoms $frames]
}

# The CSV file of an extraction (the program's input).
proc ::VMDance::Coords::csv {c} { dict get $c csv }

# The rows as one flat list (the library's input: for a job's calls, which
# share it). Its text, which the library makes, is the CSV's less its last
# newline (the same numbers, one separator each).
proc ::VMDance::Coords::flat {c {cancelled ""}} {
    set out {}
    each $c i r { lappend out {*}$r } $cancelled
    return $out
}

# Run script for every row, in order, with rowvar the row (a list of
# numbers) and ivar its number, in the caller's frame; in a coroutine it
# yields every 40 ms, and stops when `cancelled` names a true variable.
# The rows are read from VMD again while the molecule is the one they were
# read from — the same numbers as the file's (a double's text reads back
# to the same double), without converting text — each checked against its
# fingerprint: coordinates changed since are an error, never measured; else
# they are read from the file.
proc ::VMDance::Coords::each {c ivar rowvar script {cancelled ""}} {
    upvar 1 $ivar i $rowvar row
    set m [dict get $c mol]
    set here [expr {[::VMDance::Mol::exists $m] && [key [dict create mol $m sel [lindex [dict get $c key] 4] \
        frames [dict get $c frames] fit [lindex [dict get $c key] 6]]] eq [dict get $c key]}]
    set slice [clock milliseconds]
    set i 0
    if {$here} {
        set frames [dict get $c frames]
        set h [_open $m [dict get $c atoms] [dict get $c fitatoms] [lindex $frames 0]]
        try {
            foreach f $frames fp0 [dict get $c fp] {
                lassign [_row $h $f] row fp
                if {$fp ne $fp0} { error "the coordinates of frame $f of molecule $m changed during the job: cluster again" }
                uplevel 1 $script
                incr i
                if {[info coroutine] ne "" && [clock milliseconds] - $slice > 40} {
                    after 1 [info coroutine]
                    yield
                    set slice [clock milliseconds]
                    if {$cancelled ne "" && [set $cancelled]} { error "cancelled" }
                    if {![::VMDance::Mol::exists $m]} { error "molecule $m was deleted while its frames were read" }
                }
            }
        } finally {
            _close $h
        }
        return
    }
    set fh [open [dict get $c csv] r]
    fconfigure $fh -buffersize 1048576
    try {
        # (the numbers read once: VMD's vector commands would convert the
        # text again at every use)
        set num [expr {[info commands vecscale] ne ""}]
        while {[gets $fh line] >= 0} {
            set row [split $line ,]
            if {$num} { set row [vecscale 1.0 $row] }
            uplevel 1 $script
            incr i
            if {[info coroutine] ne "" && [clock milliseconds] - $slice > 40} {
                after 1 [info coroutine]
                yield
                set slice [clock milliseconds]
                if {$cancelled ne "" && [set $cancelled]} { error "cancelled" }
            }
        }
    } finally {
        close $fh
    }
}

# The rows as a list (tests; a short trajectory only).
proc ::VMDance::Coords::rows {c} {
    set out {}
    each $c i r { lappend out $r }
    return $out
}
