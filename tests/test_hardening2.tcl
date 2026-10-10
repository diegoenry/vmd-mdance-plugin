# What the second round of reviews found in the sessions (security and
# limits) and in the backend's process, each kept from coming back (text
# mode, the fake backend):
#   N01  a session's molecule record no longer hands a file and a type to
#        VMD unchecked (a Babel converter or an AMBER reader would run a
#        shell command, a name with shell characters injects one)
#   F37  a molecule file that is a FIFO or a device no longer hangs Open
#   F50  a session's lists are counted before they are made (a 40 KB file
#        would allocate gigabytes), and nclusters, the selection and the
#        picks are bounded against the frames
#   F05  a session that would be larger than it can be read is refused
#        before the old one is touched, naming the runs to delete
#   F49  strings a user typed or a file holds never pass through expr's ?:
#        (a molecule named NaN broke every export; 010, 0x1F were rewritten)
# The backend's process, its folders and its output (g2):
#   F08  a uid with no passwd entry (a container's) gets its private folder
#        (owners compared by uid; it was refused 20 times, left behind)
#   F21  the private folder is named for the machine and PID namespace and
#        never taken when it exists: a VMD sharing the TMPDIR from another
#        container or machine no longer removes a running job's folder
#   F22  a program that closes its output before it ends (a launcher that
#        logs) no longer holds VMD in close: Cancel answers
#   F23  Cancel, VMD quitting and the probe stop what a launcher that does
#        not exec started, not the launcher alone
#   F24  a program slow to start is offered with a note, not refused for
#        the session as "not mdance-cli"
#   F44  the output is read a slice at a time: a flood no longer starves
#        VMD's events, a line without its end is not held whole; a program
#        the probe found is not mdance-cli is run for no job (a pick ran it)
#   F45  mdance-cli ended from outside (Ctrl+C, kill) stops the whole scan
#        and keeps the one there; a crash stays one failed record
#   F43  the progress line keeps "threshold=0.2" (it was cut at the dot)
# What reaches the backend, and the library (g3):
#   F11  coordinates that are not numbers (NaN, infinite) are refused as they
#        are read, naming the VMD frame (a CSV row was named; -fit failed in
#        vectrans; the library took an infinity and answered)
#   F53  a number the backend reads as a C float or double out of its range
#        is refused with its option (a bare "stof"; the library rounded it)
#   F02  a metric other than MSD with the diversity selection (CompSim,
#        DivSelect, comp_sim, the diversity pick) is refused: the backend
#        read past its data (a crash, every frame in one "successful" cluster)
#   F14  the most diverse frames are a whole percentage (0.5 picked half the
#        frames); a share that holds no frame is refused
#   F73  the backend chosen in Settings is the command's too (a script used
#        another until the window opened)
#   F63  Settings tries a backend without applying it (a job ran on it, and
#        Cancel during a job could not put the old one back): backend try
#   F74  the library writes the coordinates' file too (said it wrote none);
#        a folder that cannot take them is named with what to do
#   N03  a library call whose coordinates' text would pass Tcl's 2 GB (VMD
#        aborted) is refused, before the frames are read when it can be told
#   N04  so is one that needs more memory than VMD can get (killed for it)
# Files and exports (g4):
#   F03  a temporary is made by its call alone, beside its file (EXCL, a
#        name not guessed): a link put at <file>.tmp<pid> made an export,
#        a session or the preferences overwrite the file it pointed to
#   F09  a DCD keeps every frame's unit cell, as VMD's writer does (all lost)
#   F20  an export checks everything before it writes anything, and renames
#        its files only once all are written (a run without PRIME, a bad
#        -sel replaced the tables first; a failed file left two runs')
#   F34  a DCD's files are it and the PDB beside it (the window asks first)
#   F35  a selection over two lines, a name with a line break: each # line
#        stays one line (HELM could not read its own labels back)
#   F36  a PDB VMD's writer did not write whole is refused (a coordinate
#        past -999.999, a full disk: it was renamed into place cut)
#   F38  the PDB beside a DCD that fails leaves the DCD as it was; a full
#        disk is said of the file, not of Tcl's channel
#   F48  a name that is a folder, or a link to one, is refused (the file
#        was moved into it and reported written)
#   F51  a file replaced keeps its permissions; a read-only one is refused;
#        a link of the user's is followed, another's replaced
#   F52  a PDB export is VMD's own writer's, frame by frame (residues past
#        9999 were renumbered through a molecule of its own)
#   F72  the folder of an export is made when it does not exist
#   F75  a scan's and the picks' tables name the backend, and a sweep's
#        each algorithm's fixed parameters
# The clustered frames and their molecule (g5):
#   F01  a session is checked against the molecule it is put on: another
#        trajectory of the same file names, or a file written over, is said
#        and its frames refused (goto, 3D, the user field and the structures
#        used other coordinates); its files are found by their names in full
#   F33  a session's molecule loaded from another folder (the names in
#        full, else the session's folder), and the PDB's own frame deleted
#        again when it was deleted before clustering (it never matched)
#   F40  frames moved in place rigidly (an alignment), then frames added:
#        still the clustered ones (each frame's radius of gyration)
#   F25  vmdance frame refuses, as goto does, once the frames moved
#   F26  a drawing whose frames changed under it is withdrawn or made again;
#        the answer kept for a count of frames is not taken for it later
#   F18  the picks keep what tells their frames, and are not drawn, saved
#        or gone to once their molecule's frames moved
#   F19  the picks are drawn and gone to on their own molecule, with no
#        clustering (pick goto, pick save)
#   F61  a result keeps the atoms it clustered, not only its selection text
#   F62  the kept rows of a molecule deleted go at once
#   N02  an MDANCE plugin session is imported onto the molecule whose
#        coordinates give its cluster MSDs (it took the first of its name)
#   F39  the fingerprint has the RMSD from the first frame: atoms 1009 apart
#        swapped, a frame mirrored through its two centres, are seen; a
#        session's digest made before still matches
# The final review of the merged branch:
#   scan-empty  a session holding a scan's record with an empty cluster opens,
#               and saved again opens again (a record's nclusters counts the
#               clusters with frames, its sizes are all k: the check wanted a
#               size per counted cluster, and refused what the plugin wrote)
#   lib-notrun  the library's refusal of DIVINE seeded by CompSim below 50% is
#               a scan's "not run" (a sweep where nothing ran replaced the one
#               there with failures)
#   equal-msd   eQUAL takes MSD only in the table (Algo::A), as DIVINE does:
#               the window, the request and the docs follow it
#   seedless    a sweep makes one configuration of HELM from a label file (and
#               of DIVINE's pair anchors), not one a seeding: the same
#               clustering, each labelled with a seeding it never used
#   near        with many clusters, a frame's nearest other mean structure
#               (its silhouette) is looked for among those the triangle
#               inequality leaves, not every one: the same numbers
# (F27, the window's cursor while frames are added, is test_gui's.)
# (The full disk is a tmpfs in a namespace of the user's, unshare -r -m:
# skipped where it cannot be mounted.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2]
file delete -force $H
file mkdir $H

proc rss_mb {} {
    if {[catch {open /proc/self/status} fh]} { return -1 }
    set t [read $fh]; close $fh
    if {[regexp {VmHWM:\s+(\d+)} $t -> h]} { return [expr {$h / 1024}] }
    return -1
}
proc md5 {f} { lindex [split [exec md5sum $f]] 0 }
proc write_session {f d} {
    set fh [open $f wb]
    puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "VMDanceSession 1\n$d\n"] -level 9]
    close $fh
}
# Open a session and return run 1's warning ("" when there is none). (The
# command prints warnings and returns the run list; the core proc returns
# {warnings gui}.)
proc load_warn {f {mol load}} {
    lindex [lindex [::VMDance::Session::load $f $mol] 0] 0
}
# A saved session's dictionary, with run 1's molecule record changed.
proc with_molecule {d rec} {
    set runs [dict get $d runs]
    set a [lindex $runs 0 2]
    dict set a molecule $rec
    lset runs 0 2 $a
    dict set d runs $runs
    return $d
}

if {[catch {
package require vmdance
set R ::VMDance::Results
use_fake
fake_env
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set base [file join $H base.vmdance]
vmdance session save $base
set bd [::VMDance::Session::read_file $base]
# (a record as sessions made before g5 have it: its names as typed, which
# are then what is loaded; a record's names in full, paths, are checked the
# same way: g5's F01)
set rec [dict remove [dict get [lindex [dict get $bd runs] 0 2] molecule] paths]

# --- N01: a session is data; its molecule files and types are checked -----------------------------
# A molecule record that is still the real one reloads (the guard allows it).
mol delete $m
set w [lindex [vmdance session load $base] 0]
check "N01: a genuine session still reloads its molecule" [expr {[dict get [vmdance info] molid] >= 0 && [molinfo [dict get [vmdance info] molid] get numatoms] == 8}]
foreach x [molinfo list] { mol delete $x }
# A converter type (Babel runs a program) with a name that injects a command:
# set VMDBABELBIN so that, on the unfixed code, the injected command would run.
set dummy [file join $H babel]; set fh [open $dummy w]; puts $fh "#!/bin/sh\nexit 0"; close $fh; file attributes $dummy -permissions 0755
set ::env(VMDBABELBIN) $dummy
set here [pwd]; cd $H
set payload [file join $H {$(touch MARKER_N01).alc}]
set fh [open $payload w]; puts $fh "x"; close $fh
set bad [with_molecule $bd [dict replace $rec files [list $payload] types {Alchemy}]]
write_session [file join $H n01a.vmdance] $bad
set w [load_warn [file join $H n01a.vmdance]]
cd $here
check "N01: a molecule type Alchemy with \$(touch …) in its name: nothing run, not loaded" [expr {
    ![file exists [file join $H MARKER_N01]] && [dict get [${R}::request] mol] == -1}]
check "  the warning says why (a shell character in the name)" [string match "*character a shell would act on*" $w]
unset ::env(VMDBABELBIN)
# A clean name but a converter type: refused by the file-reader allowlist.
set clean [file join $H clean.alc]; set fh [open $clean w]; puts $fh "x"; close $fh
set bad [with_molecule $bd [dict replace $rec files [list $clean] types {Alchemy}]]
write_session [file join $H n01b.vmdance] $bad
set w [load_warn [file join $H n01b.vmdance]]
check "N01: a clean name of a converter type (Alchemy): not loaded, said" [expr {[dict get [${R}::request] mol] == -1 &&
    [string match "*not one of VMD's file readers*" $w]}]
# An AMBER reader (parm7 gives the name to a shell) with a quote breakout:
# for a name that is missing with its .Z beside it, the reader runs
# zcat '<name>.Z' in a shell, in the folder VMD is in (here, H).
set p7 [file join $H "x';touch MARKER2;'.parm7"]
set fh [open $p7.Z w]; puts $fh x; close $fh
set bad [with_molecule $bd [dict replace $rec files [list $p7] types {parm7}]]
write_session [file join $H n01c.vmdance] $bad
cd $H
set w [load_warn [file join $H n01c.vmdance]]
cd $here
check "N01: a parm7 reader with a quote breakout in its name: refused, nothing run" [expr {
    ![file exists [file join $H MARKER2]] && [dict get [${R}::request] mol] == -1 &&
    [string match "*character a shell would act on*" $w]}]

# --- F37: a molecule file that is a FIFO or a device does not hang Open ------------------------------
if {[catch {exec mkfifo [file join $H trap.pdb]}]} {
    skip "F37: a FIFO molecule file does not hang Open" "mkfifo is not available"
} else {
    set trap [file join $H trap.pdb]
    set bad [with_molecule $bd [dict replace $rec files [list $trap] types {pdb}]]
    write_session [file join $H f37.vmdance] $bad
    # a bounded writer, so an unfixed load returns instead of hanging the suite
    exec sh -c {sleep 3; : <> "$0"} $trap &
    set t0 [clock milliseconds]
    set w [load_warn [file join $H f37.vmdance]]
    set dt [expr {[clock milliseconds] - $t0}]
    check "F37: a session whose molecule is a FIFO opens at once, without it ($dt ms)" [expr {$dt < 2000 &&
        [dict get [${R}::request] mol] == -1 && [string match "*not a readable file*" $w]}]
    catch {file delete $trap}
}
# /dev/zero (a device read without end) is refused the same way (the guard
# asked first: without it the load would read for ever, not fail).
set why [::VMDance::Session::_unloadable {/dev/zero} {pdb}]
set bad [with_molecule $bd [dict replace $rec files {/dev/zero} types {pdb}]]
write_session [file join $H f37b.vmdance] $bad
set t0 [clock milliseconds]
set w ""
if {$why ne ""} { set w [load_warn [file join $H f37b.vmdance]] }
check "F37: a molecule file /dev/zero: refused at once, not read without end ([expr {[clock milliseconds] - $t0}] ms)" [expr {
    $why ne "" && [dict get [${R}::request] mol] == -1 && [string match "*not a readable file*" $w]}]

# --- F50: lists are counted before they are made, and bounded ------------------------------------------
# a 40 KB session whose frames are "0 " × 20M: refused at once, memory bounded
set a [lindex [dict get $bd runs] 0 2]
dict set a frames [string trimright [string repeat "0 " 20000000]]
set bomb $bd; dict set bomb runs [list [list 1 x $a]]
write_session [file join $H frames.vmdance] $bomb
unset a bomb
set r0 [rss_mb]
set t0 [clock milliseconds]
set e [err {vmdance session load [file join $H frames.vmdance] -mol none}]
set grew [expr {[rss_mb] - $r0}]
check "F50: 20M frame values in a 40 KB file: refused fast ([expr {[clock milliseconds] - $t0}] ms), memory bounded (+$grew MB)" [expr {
    [string match "*labels has 24 values, not 20000000*" $e] && ($grew < 0 || $grew < 400)}]
# a value bomb whose counts all agree (consistent k×k of zeros): the value cap
set a [lindex [dict get $bd runs] 0 2]
set k 5100
set lab [string trimright [string repeat "0 " $k]]
set rows {}; for {set i 0} {$i < $k} {incr i} { lappend rows $lab }
dict set a nclusters $k
dict set a labels $lab; dict set a sizes $lab; dict set a representatives $lab; dict set a msd $lab
dict set a frames [string trimright [string repeat "3 " $k]]
dict set a measures rep_msd $rows; dict set a measures centroid_msd $rows
set bomb $bd; dict set bomb runs [list [list 1 x $a]]
write_session [file join $H kk.vmdance] $bomb
unset a bomb rows lab
set r0 [rss_mb]
set e [err {::VMDance::Session::read_file [file join $H kk.vmdance]}]
check "F50: a consistent $k×$k session (counts agree): refused by the value cap, memory bounded (+[expr {[rss_mb] - $r0}] MB)" [expr {
    [string match "*million values*" $e] && ([rss_mb] - $r0 < 0 || [rss_mb] - $r0 < 400)}]
# the frames out of order are caught (and never made 20M long first)
set a [lindex [dict get $bd runs] 0 2]
dict set a labels {0 0}
dict set a frames {5 5}
set bad $bd; dict set bad runs [list [list 1 x $a]]
write_session [file join $H order.vmdance] $bad
check "F50: frames not increasing: refused" [string match "*increasing order*" [err {vmdance session load [file join $H order.vmdance] -mol none}]]
unset a bad
# a selection longer than the clusters is refused before it is made a list
set bad [dict replace $bd selection [string trimright [string repeat "0 " 100000]]]
write_session [file join $H sel.vmdance] $bad
check "F50: a selection longer than the clusters: refused" [string match "*selection is corrupt*" [err {vmdance session load [file join $H sel.vmdance] -mol none}]]
# nclusters above the frames is refused (as the backend's output is)
set a [lindex [dict get $bd runs] 0 2]
dict set a nclusters 500000000
set bad $bd; dict set bad runs [list [list 1 x $a]]
write_session [file join $H nk.vmdance] $bad
check "F50: nclusters above the frames: refused" [string match "*more than the 24 frames*" [err {vmdance session load [file join $H nk.vmdance] -mol none}]]
unset a bad
# the plugin's _values counts a list's separators without making it
check "F50: _values counts a plugin list's separators without making it" [expr {[::VMDance::Session::_values "0 1 2 3 4"] == 4 && [::VMDance::Session::_values ""] == 0}]

# --- F05: a session too large to read back is refused before the old one is touched -----------------
foreach x [molinfo list] { mol delete $x }
set m [load_system two_state]
vmdance run clear
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set id1 $::VMDance::Results::current
set b1 [string length [zlib decompress [lindex $::VMDance::Results::runs end 2]]]
set good [file join $H good.vmdance]
# exactly at the limit: the writer and the reader agree (the size the save
# just wrote, unpacked)
vmdance session save $good
set fh [open $good rb]; zlib push gunzip $fh; set raw [read $fh]; close $fh
set ::VMDance::Session::max_bytes [string length $raw]
check "F05: a session exactly at the limit saves and reads back" [expr {![catch {vmdance session save $good} e] && ![catch {::VMDance::Session::read_file $good} e2]}]
set good_md5 [md5 $good]
vmdance -mol $m -sel all -k 4 -kinit KmeansPP -quiet 1
set id2 $::VMDance::Results::current
set b2 [string length [zlib decompress [lindex $::VMDance::Results::runs end 2]]]
# (the bigger run must be named first)
lassign [expr {$b2 >= $b1 ? [list $id2 $id1] : [list $id1 $id2]}] big small
set ::VMDance::Session::max_bytes [expr {$b1 + $b2 - 1}]
set nruns [${R}::run_list]
set cf $::VMDance::Session::current_file
set e [err {vmdance session save $good}]
check "F05: two runs over the limit: the save is refused" [string match "*nothing was written*" $e]
check "  it names the runs to delete, the largest first (run $big before run $small)" [expr {
    [string match "*Delete runs first*" $e] && [string match "*run delete*" $e] &&
    [string first "run $big " $e] >= 0 && [string first "run $big " $e] <= [string first "run $small " $e]}]
check "  the file that was there is unchanged, and still reads" [expr {[md5 $good] eq $good_md5 && ![catch {::VMDance::Session::read_file $good}]}]
check "  no temporary file is left, the runs and the session's file are as they were" [expr {
    ![llength [glob -nocomplain $good.tmp*]] && [${R}::run_list] eq $nruns && $::VMDance::Session::current_file eq $cf}]
vmdance run delete $small
check "F05: after deleting a run, the save succeeds and the file reads back" [expr {
    ![catch {vmdance session save $good} e] && ![catch {::VMDance::Session::read_file $good}]}]
# the value cap refuses a save the same way, and leaves the file untouched
set ::VMDance::Session::max_bytes 400000000
set md [md5 $good]
set ::VMDance::Session::max_values 1
check "F05: over the value cap: the save is refused, the file untouched" [expr {[string match "*million values*" [err {vmdance session save $good}]] && [md5 $good] eq $md}]
set ::VMDance::Session::max_values 50000000
check "  and the file still reads once the cap is restored" [expr {![catch {::VMDance::Session::read_file $good}]}]

# --- F49: strings a user typed or a file holds are never run through expr's ?: -----------------------
foreach x [molinfo list] { mol delete $x }
vmdance run clear
set m [load_system two_state]
foreach name {nan 1e10 010 0x1F} {
    mol rename $m $name
    vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
    vmdance export $H -prefix e$name -items summary
    set hdr [lsearch -inline [split [read_text [file join $H e${name}_summary.txt]] \n] "# molecule*"]
    check "F49: a molecule named \"$name\": its name in the export verbatim, every export works" [string match "*# molecule: $name (*" $hdr]
}
mol rename $m two_state.pdb
# import -label keeps the label as typed (0x10 not 16, NaN not an error)
foreach l {0x10 010 1e3 NaN} {
    vmdance session import [file join $::fixtures old_kmeans.mdance] -label $l
    check "F49: session import -label \"$l\" keeps the label" [expr {[lindex [vmdance runs] end 1] eq $l}]
}
# draw -frames 010 survives a session round trip as frame 10, not 8
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance draw -frames 010
set sf [file join $H f49.vmdance]
vmdance session save $sf
vmdance run clear
vmdance session load $sf
check "F49: draw -frames 010 after a session round trip: still 010 (frame 10, not 8)" [expr {[dict get [::VMDance::Viz::get] frames] eq "010"}]
vmdance draw -frames ""
# a hand-edited session with a corrupt seconds/created is refused on load (a clear message)
set d [::VMDance::Session::read_file $sf]
set a [lindex [dict get $d runs] end 2]
dict set a created 0x1F; dict set a seconds NaN
set runs [dict get $d runs]; lset runs end 2 $a; dict set d runs $runs
write_session [file join $H f49b.vmdance] $d
check "F49: a session with created 0x1F and seconds NaN: refused on load (checked, not run through expr)" [expr {
    [string match "*created is corrupt*" [err {vmdance session load [file join $H f49b.vmdance]}]] ||
    [string match "*seconds is corrupt*" [err {vmdance session load [file join $H f49b.vmdance]}]]}]
# a stored string is returned as it is (expr's ?: made a backend 0x10 16)
set d [::VMDance::Session::read_file $sf]
set runs [dict get $d runs]
set i [lsearch -index 0 -exact $runs [dict get $d current]]
set a [lindex $runs $i 2]
dict set a backend 0x10
lset runs $i 2 $a; dict set d runs $runs
write_session [file join $H f49c.vmdance] $d
vmdance session load [file join $H f49c.vmdance] -mol none
check "  Results::meta returns a stored string as it is, never through expr" [expr {[dict get [vmdance info] backend] eq "0x10"}]

# --- g2: the backend's process, its folders and its output (F08 F21 F22 F23 F24 F44 F45 F43) ---------
# (a TMPDIR of the tests' own: they make folders of other machines and of
# dead VMDs in it)
foreach x [molinfo list] { mol delete $x }
vmdance run clear
::VMDance::Backend::cleanup
set tmp0 [::VMDance::_get [array get ::env] TMPDIR ""]
set tbase [file join $H tmp]
file mkdir $tbase
set ::env(TMPDIR) $tbase
set m [load_system two_state]
use_fake
fake_env
set req [::VMDance::Job::check_cluster [list mol $m sel all k 2 params {kinit KmeansPP}]]
set procfs [file isdirectory /proc/self]
proc bg {kind req} {
    set ::bgdone ""
    ::VMDance::Job::start $kind $req "" {apply {{st r} { set ::bgdone [list $st $r] }}}
}
proc wait_bg {{ms 60000}} {
    set id [after $ms {set ::bgdone timeout}]
    while {$::bgdone eq ""} { vwait ::bgdone }
    after cancel $id
    return $::bgdone
}
proc wait_ms {ms} { set ::waited 0; after $ms {set ::waited 1}; vwait ::waited }
# A program of the tests': a shell script (@FAKE@: the fake backend).
proc script {name body} {
    set f [file join $::H $name]
    set fh [open $f w]
    puts $fh "#!/bin/sh\n[string map [list @FAKE@ $::fake] $body]"
    close $fh
    file attributes $f -permissions 0755
    return $f
}
# Read from /proc by the test itself: the processes whose parent is p;
# whether p runs (not a zombie); the processes running "sleep n". (A
# process that ends while it is read is gone: its file fails to read.)
proc proc_file {f} {
    if {[catch {open $f} fh]} { return "" }
    if {[catch {read $fh} s]} { set s "" }
    catch {close $fh}
    return $s
}
proc children {p} {
    set out {}
    foreach d [glob -nocomplain -directory /proc -tails {[0-9]*}] {
        set s [proc_file /proc/$d/stat]
        if {[regexp {\) \S ([0-9]+) } [string range $s [string last ")" $s] end] -> pp] && $pp eq $p} { lappend out $d }
    }
    return $out
}
proc alive {p} {
    set s [proc_file /proc/$p/stat]
    expr {$s ne "" && [string index $s [expr {[string last ")" $s] + 2}]] ni {Z X}}
}
proc sleepers {n} {
    set out {}
    foreach d [glob -nocomplain -directory /proc -tails {[0-9]*}] {
        if {[proc_file /proc/$d/cmdline] eq "sleep\0$n\0" && [alive $d]} { lappend out $d }
    }
    return $out
}
# The longest the event loop kept a 50 ms ticker waiting.
proc tick {} {
    set now [clock milliseconds]
    if {$now - $::tick_last > $::tick_gap} { set ::tick_gap [expr {$now - $::tick_last}] }
    set ::tick_last $now
    set ::tick_id [after 50 tick]
}
proc tick_start {} { set ::tick_last [clock milliseconds]; set ::tick_gap 0; set ::tick_id [after 50 tick] }
proc tick_stop {} { after cancel $::tick_id; return $::tick_gap }

# F08: a uid with no passwd entry (a container's): tcl_platform(user) is ""
# and an owner is a number. The private folder is made all the same.
set uid [exec id -u]
set user0 $::tcl_platform(user)
set ::tcl_platform(user) ""
set wd ""
set e [err {set wd [::VMDance::Backend::workdir]}]
set ::tcl_platform(user) $user0
set made [lsearch -all -inline -glob [glob -nocomplain -tails -directory $tbase vmdance-u*] "*-[pid]*"]
check "F08: no user name (no passwd entry): a private folder all the same, 0700, named u$uid ([file tail $wd]$e)" [expr {$e eq "" &&
    [string match "vmdance-u$uid-*" [file tail $wd]] && [string match *700 [file attributes $wd -permissions]] && [file owned $wd]}]
check "  and only it ([llength $made] made)" [expr {[llength $made] == 1}]
check "  a clustering in it" [expr {![catch {vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1} i] && [dict get $i nclusters] == 2 &&
    $wd ne "" && [file dirname [dict get $::VMDance::Coords::C csv]] eq $wd}]
foreach d $made { file delete -force [file join $tbase $d] }
::VMDance::Backend::cleanup
# The same under a uid that has no passwd entry, in a user namespace: a
# folder, a run of the program in it, a dead VMD's folder of that uid
# removed, nothing left.
set nsuid 54321
if {!$procfs || [catch {exec unshare -U --map-user=$nsuid --map-group=$nsuid true 2>@1}] || ![catch {exec getent passwd $nsuid}]} {
    skip "F08: under a uid with no passwd entry (unshare -U)" "unshare -U is not allowed here, or uid $nsuid has an entry"
} else {
    set child [file join $H nopasswd.tcl]
    set fh [open $child w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance] @FAKE@ $::fake] {
        set auto_path [linsert $auto_path 0 {@LIB@}]
        package require vmdance
        set B ::VMDance::Backend
        puts "user=<$::tcl_platform(user)>"
        set wd [${B}::workdir]
        puts "mode=<[file attributes $wd -permissions]>"
        set csv [${B}::tmpfile .csv]
        set fh [open $csv w]; puts $fh "0,0,0,0,0,0\n0,0,0.1,0,0,0\n5,5,5,5,5,5\n5,5,5.1,5,5,5"; close $fh
        set json [${B}::tmpfile .json]
        ${B}::start {@FAKE@} [list --algorithm kmeans --input $csv --output $json --natoms 2 --nclusters 2] -done {apply {{st m j} { set ::st $st }}}
        vwait ::st
        puts "run=<$::st [file size $json]>"
        set dead [file join [file dirname $wd] "vmdance-[${B}::_user]-[${B}::_where]-999999999-0badf00d"]
        file mkdir $dead
        ${B}::cleanup
        ${B}::workdir
        puts "reaped=<[expr {![file exists $dead]}]>"
        ${B}::cleanup
        puts "left=<[llength [glob -nocomplain -directory [file dirname $wd] "vmdance-u*"]]>"
    }]
    close $fh
    catch {exec unshare -U --map-user=$nsuid --map-group=$nsuid tclsh $child 2>@1} o
    check "F08: under uid $nsuid, which has no passwd entry: a 0700 folder, the program run in it, a dead VMD's removed, none left ([join [split $o \n] { }])" [expr {
        [string match "*user=<>*mode=<*700>*run=<ok *reaped=<1>*left=<0>*" [join [split $o \n] { }]] && ![string match "*run=<ok 0>*" $o]}]
}

# F21: the private folder is named for this machine and PID namespace, the
# process and a random part: a VMD that shares the TMPDIR from another
# machine or container (the same process numbers, a /proc of its own)
# neither takes it nor removes it.
set wd [::VMDance::Backend::workdir]
set where ""
regexp {^vmdance-.+-([0-9a-f]{8})-[0-9]+-[0-9a-f]{8}$} [file tail $wd] -> where
check "F21: the private folder's name: user, machine and PID namespace, process, random ([file tail $wd])" [expr {
    $where ne "" && [string match "*-$where-[pid]-*" [file tail $wd]]}]
if {$where eq ""} { set where 0badf00d }
scan $where %x n
set there [format %08x [expr {$n ^ 0xffffffff}]]
set u $::tcl_platform(user)
set dead_here [file join $tbase "vmdance-$u-$where-999999999-0badf00d"]
set dead_there [file join $tbase "vmdance-$u-$there-999999999-0badf00d"]
file mkdir $dead_here $dead_there
::VMDance::Backend::cleanup
::VMDance::Backend::workdir
check "F21: a dead VMD's folder of this machine and namespace is removed; another's is kept (this /proc does not list its processes)" [expr {
    ![file exists $dead_here] && [file isdirectory $dead_there]}]
file delete -force $dead_here $dead_there
# a link put in the folder's place is not used (its target would get the coordinates)
set wd [::VMDance::Backend::workdir]
set target [file join $H elsewhere]
file mkdir $target
file delete -force $wd
file link -symbolic $wd $target
set f [::VMDance::Backend::tmpfile .csv]
close [open $f w]
check "F21: a link put in the private folder's place is not used: a new folder, nothing written through the link" [expr {
    [file dirname $f] ne $wd && [file type [file dirname $f]] eq "directory" && ![llength [glob -nocomplain -directory $target *]]}]
file delete $f $wd
file delete -force $target
# another PID namespace (a container) with the same TMPDIR makes its own
# folder while this VMD's job runs: the job goes on
if {!$procfs || [catch {exec unshare -Upf --mount-proc --map-current-user true 2>@1}]} {
    skip "F21: a VMD in another PID namespace leaves this one's folder" "unshare -Upf is not allowed here"
} else {
    set child [file join $H other_ns.tcl]
    set fh [open $child w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance]] {
        set auto_path [linsert $auto_path 0 {@LIB@}]
        package require vmdance
        puts "pid=<[pid]> folder=<[file tail [::VMDance::Backend::workdir]]>"
        ::VMDance::Backend::cleanup
    }]
    close $fh
    fake_env MDANCE_FAKE_SLEEP 3
    bg cluster $req
    wait_ms 800
    catch {exec unshare -Upf --mount-proc --map-current-user tclsh $child 2>@1} o
    lassign [wait_bg 20000] st r
    fake_env
    check "F21: a VMD in another PID namespace ([string trim $o]) runs a job with the same TMPDIR: this one's job goes on ($st)" [expr {$st eq "ok"}]
    # two VMDs with the same process number (1) in two containers: the
    # second neither takes the first's folder nor removes it as it quits
    set c1 [file join $H same_pid_1.tcl]
    set fh [open $c1 w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance]] {
        set auto_path [linsert $auto_path 0 {@LIB@}]
        package require vmdance
        set f [file join [::VMDance::Backend::workdir] mine]
        close [open $f w]
        after 1500
        puts "pid=<[pid]> kept=<[file exists $f]>"
        ::VMDance::Backend::cleanup
    }]
    close $fh
    set log1 [file join $H same_pid_1.out]
    file delete $log1
    exec unshare -Upf --mount-proc --map-current-user tclsh $c1 > $log1 2>@1 &
    wait_ms 500
    catch {exec unshare -Upf --mount-proc --map-current-user tclsh $child 2>@1} o
    set o1 ""
    for {set w 0} {$w < 50 && ![string match "*kept=*" $o1]} {incr w} { wait_ms 100; set o1 [read_text $log1] }
    check "F21: two VMDs with the same process number in two PID namespaces: the second neither takes nor removes the first's folder ([string trim $o1])" [expr {
        [string match "*pid=<1> kept=<1>*" $o1] && [string match "*pid=<1>*" $o]}]
}

# F22: a program that ends its output before it ends (a launcher that
# logs) no longer holds VMD in close until it ends: Cancel answers, and
# its end is still told (ok, or failed).
set logcli [script logcli [string map [list @LOG@ [file join $H logcli.log]] {if [ $# -eq 0 ]; then exec "@FAKE@"; fi
exec "@FAKE@" "$@" >> "@LOG@" 2>&1}]]
::VMDance::Backend::configure -mode cli -cli $logcli
fake_env MDANCE_FAKE_SLEEP 4
tick_start
set t0 [clock milliseconds]
bg cluster $req
after 500 ::VMDance::Job::cancel
lassign [wait_bg 20000] st r
set dt [expr {[clock milliseconds] - $t0}]
set gap [tick_stop]
check "F22: a launcher that sends the output to a log: Cancel answers ($dt ms; VMD waited at most $gap ms)" [expr {$st eq "cancelled" && $dt < 2500 && $gap < 500}]
fake_env MDANCE_FAKE_SLEEP 1
tick_start
bg cluster $req
lassign [wait_bg 20000] st r
set gap [tick_stop]
check "  one that ends: its clustering (VMD waited at most $gap ms)" [expr {$st eq "ok" && [dict get $r nclusters] == 2 && $gap < 500}]
fake_env MDANCE_FAKE_FAIL 1
bg cluster $req
lassign [wait_bg 20000] st r
check "  one that fails: a failure ($r)" [expr {$st eq "error" && [string match "*mdance-cli failed*" $r]}]
fake_env

# F23: a launcher that does not exec mdance-cli (one that sets
# LD_LIBRARY_PATH): Cancel, VMD quitting and the probe stop its program
# too.
if {!$procfs} {
    skip "F23: a launcher's program stopped" "no /proc to see the processes"
} else {
    set wrap [script wrapcli {"@FAKE@" "$@"}]
    ::VMDance::Backend::configure -mode cli -cli $wrap
    foreach {ignore what limit} {0 "" 3000 1 " that ignores TERM" 5000} {
        if {$ignore} { fake_env MDANCE_FAKE_SLEEP 20 MDANCE_FAKE_IGNORE_TERM 1 } else { fake_env MDANCE_FAKE_SLEEP 20 }
        set ::kids {}
        set t0 [clock milliseconds]
        bg cluster $req
        after 700 {
            if {[::VMDance::Backend::running]} { set ::kids [children [lindex [dict get $::VMDance::Backend::job pids] 0]] }
            ::VMDance::Job::cancel
        }
        lassign [wait_bg 8000] st r
        set dt [expr {[clock milliseconds] - $t0}]
        # (a program killed with its launcher ends a moment after it, whose
        # end ends the job)
        for {set i 0} {$i < 20 && [llength [lmap p $::kids {expr {[alive $p] ? $p : [continue]}}]]} {incr i} { wait_ms 50 }
        set left [lmap p $::kids {expr {[alive $p] ? $p : [continue]}}]
        check "F23: a launcher that does not exec, its program$what: Cancel stops both ($dt ms; left running: [llength $left] of [llength $::kids])" [expr {
            $st eq "cancelled" && $dt < $limit && [llength $::kids] == 1 && ![llength $left]}]
        if {[llength $left]} { catch {exec kill -KILL {*}$left} }
        if {$st eq "timeout"} { set ::bgdone ""; wait_bg }
    }
    fake_env MDANCE_FAKE_SLEEP 20
    bg cluster $req
    wait_ms 700
    set ::kids [children [lindex [dict get $::VMDance::Backend::job pids] 0]]
    ::VMDance::Backend::stop_now
    wait_ms 300
    set left [lmap p $::kids {expr {[alive $p] ? $p : [continue]}}]
    check "F23: VMD quitting (stop_now) ends the launcher's program at once ([llength $left] of [llength $::kids] left)" [expr {[llength $::kids] == 1 && ![llength $left]}]
    if {[llength $left]} { catch {exec kill -KILL {*}$left} }
    wait_bg 30000
    fake_env
    set hang [script hangcli {sleep 297}]
    ::VMDance::Backend::configure -mode cli -cli $hang
    set left [sleepers 297]
    check "F23: the probe of a launcher whose program waits leaves nothing running ([llength $left] left)" [expr {![llength $left]}]
    if {[llength $left]} { catch {exec kill -KILL {*}$left} }
}

# F24: a program slow to start (in a container, on a network disk) is
# taken, every algorithm offered with a note, not refused for the session
# as "not mdance-cli".
set slow [script slowcli {sleep 3.5
exec "@FAKE@" "$@"}]
fake_env
set t0 [clock milliseconds]
set b [::VMDance::Backend::configure -mode cli -cli $slow]
set t [expr {[clock milliseconds] - $t0}]
check "F24: a program slow to start (3.5 s): taken, every algorithm offered, said so ($t ms)" [expr {[dict get $b error] eq "" &&
    [llength [dict get $b algorithms]] == 4 && [string match "*did not answer within 3 s*" [::VMDance::_get $b note ""]] && $t < 6000}]
set t0 [clock milliseconds]
set i {}
set e [err {set i [vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1]}]
check "  its clusterings are made ([expr {[clock milliseconds] - $t0}] ms$e)" [expr {$e eq "" && [::VMDance::_get $i nclusters ""] == 2}]
check "  and asked again, it is not run again (the note kept)" [expr {[lindex [time {set b [vmdance backend]}] 0] < 1000000 &&
    [string match "*did not answer*" [::VMDance::_get $b note ""]]}]

# F44: a program that prints without pause, or a line without its end, is
# read a slice at a time: VMD's events (Cancel, timers, idle work) run, and
# no line is held whole.
use_fake
fake_env MDANCE_FAKE_FLOOD 300000 MDANCE_FAKE_SLEEP 30
set ::idle ""
tick_start
set t0 [clock milliseconds]
bg cluster $req
after 300 { after idle { set ::idle [clock milliseconds] } }
after 700 ::VMDance::Job::cancel
lassign [wait_bg 60000] st r
set dt [expr {[clock milliseconds] - $t0}]
set gap [tick_stop]
check "F44: a program that prints without pause: Cancel answers ($dt ms), timers and idle work run meanwhile (longest wait $gap ms)" [expr {
    $st eq "cancelled" && $dt < 3000 && $gap < 500 && $::idle ne "" && $::idle - $t0 < 1500}]
fake_env MDANCE_FAKE_NOLINE 20000000
set ::longest 0
rename ::VMDance::Job::_line ::VMDance::Job::_line_
proc ::VMDance::Job::_line {msg line} {
    if {[string length $line] > $::longest} { set ::longest [string length $line] }
    ::VMDance::Job::_line_ $msg $line
}
tick_start
bg cluster $req
lassign [wait_bg 60000] st r
set gap [tick_stop]
rename ::VMDance::Job::_line {}
rename ::VMDance::Job::_line_ ::VMDance::Job::_line
set kept 0
foreach l [dict get $::VMDance::Backend::last log] { if {[string length $l] > $kept} { set kept [string length $l] } }
check "F44: 20 MB without a newline: never held whole (longest line handled $::longest, kept $kept characters; longest wait $gap ms)" [expr {
    $st eq "error" && $::longest <= 2001 && $kept <= 2001 && [string length $r] <= 2100 && $gap < 500}]
fake_env
# a program the probe found is not mdance-cli (it printed more than 64 KB
# when run without arguments) is not run for a pick either, as for a
# clustering (it ran until cancelled)
::VMDance::Backend::configure -mode cli -cli [script chattycli {i=0
while [ $i -lt 2000 ]; do echo "Running nothing: a line of fifty characters or so"; i=$((i+1)); done
exec sleep 30}]
set id [after 3000 ::VMDance::Job::cancel]
set t0 [clock milliseconds]
set e [err {vmdance pick -mol $m -sel all -method diversity -param 50}]
set dt [expr {[clock milliseconds] - $t0}]
after cancel $id
check "F44: a program the probe found is not mdance-cli: a pick refuses it at once, as a clustering does ($dt ms)" [expr {
    [string match "*printed more than 64 KB*not mdance-cli*" $e] && $dt < 2000}]
use_fake

# F45: the program ended from outside (Ctrl+C at VMD's terminal, kill)
# stops the whole job, a scan too, and keeps what was there; a crash stays
# one failed record, and the scan goes on.
# (the signal to the program of the job's n-th run, or to what its launcher started)
# (once it has printed a line: a SIGINT in the fake's start-up, Python's,
# ends it with 1 or is lost, where mdance-cli dies of it at any moment)
proc signal_at {sig n {child 0}} {
    if {![::VMDance::Job::busy]} return
    if {$::VMDance::Backend::counter >= $::c0 + $n && [::VMDance::Backend::running] &&
        [llength [dict get $::VMDance::Backend::job log]]} {
        set p [lindex [dict get $::VMDance::Backend::job pids] 0]
        if {$child} { set p [children $p] }
        if {[llength $p]} { catch {exec kill -$sig {*}$p}; return }
    }
    after 20 [list signal_at $sig $n $child]
}
use_fake
fake_env MDANCE_FAKE_SLEEP 0.6
vmdance elbow -mol $m -sel all -ks {2 3} -kinit KmeansPP -quiet 1
set before [vmdance elbow show]
set ::c0 $::VMDance::Backend::counter
after 20 [list signal_at INT 2]
set e [err {vmdance elbow -mol $m -sel all -ks {2 3 4 5} -kinit KmeansPP -quiet 1}]
check "F45: Ctrl+C at VMD's terminal during an elbow scan (SIGINT to its second program): the scan stops, saying why ($e)" [expr {
    [string match "*cancelled: mdance-cli was stopped (interrupt)*" $e] && $::VMDance::Backend::counter == $::c0 + 2}]
check "  the elbow scan there is kept" [expr {[vmdance elbow show] eq $before}]
set sreq [::VMDance::Job::check_sweep [list mol $m sel all configs {
    {algorithm kmeans k 2 params {kinit KmeansPP}} {algorithm kmeans k 3 params {kinit KmeansPP}} {algorithm kmeans k 4 params {kinit KmeansPP}}}]]
set ::c0 $::VMDance::Backend::counter
bg sweep $sreq
after 20 [list signal_at TERM 2]
lassign [wait_bg 30000] st r
check "F45: kill (TERM) during a sweep of the window's: it stops, cancelled, saying why ($r)" [expr {
    $st eq "cancelled" && [string match "mdance-cli was stopped (software termination signal)" $r] && $::VMDance::Backend::counter == $::c0 + 2}]
if {$procfs} {
    ::VMDance::Backend::configure -mode cli -cli [script wrapcli {"@FAKE@" "$@"}]
    set ::c0 $::VMDance::Backend::counter
    after 20 [list signal_at TERM 2 1]
    set e [err {vmdance elbow -mol $m -sel all -ks {2 3 4 5} -kinit KmeansPP -quiet 1}]
    check "  through a launcher that does not exec (it ends with 143): the same ($e)" [expr {
        [string match "*cancelled: mdance-cli was stopped (exit status 143)*" $e] && $::VMDance::Backend::counter == $::c0 + 2}]
    use_fake
}
set ::c0 $::VMDance::Backend::counter
after 20 [list signal_at USR1 2]
set rows [vmdance elbow -mol $m -sel all -ks {2 3 4} -kinit KmeansPP -quiet 1]
check "F45: a signal that is no stop (SIGUSR1: a crash) is one failed record, and the scan goes on" [expr {[llength $rows] == 3 &&
    [dict get [lindex $rows 1] status] eq "error" && [string match "*crashed*" [dict get [lindex $rows 1] message]] &&
    [dict get [lindex $rows 0] status] eq "ok" && [dict get [lindex $rows 2] status] eq "ok"}]
fake_env

# F43: the progress line keeps the backend's numbers ("threshold=0.2" has
# a dot of its own), and drops the private files' names.
set ::seen {}
set ::VMDance::Job::progress_cb {apply {{f msg} { lappend ::seen $msg }}}
set ::VMDance::Job::inner {0.4 0.95}
foreach {msg line} {
    eQUAL "Running eQUAL (threshold=0.2, metric=MSD)..."
    PRIME "Running PRIME (metric=RR, trim=0.1, weighted=true)..."
    HELM "Building cluster tree..."
    PRIME "Reading input: /tmp/vmdance-u-0badf00d-1-0badf00d/f1-1791146317250.csv"
} { ::VMDance::Job::_line $msg $line }
set ::VMDance::Job::progress_cb ""
set ::VMDance::Job::inner {0.0 1.0}
check "F43: the progress keeps the backend's numbers (threshold=0.2, trim=0.1), not the private files' names" [expr {$::seen eq
    {{eQUAL: running eQUAL (threshold=0.2, metric=MSD)} {PRIME: running PRIME (metric=RR, trim=0.1, weighted=true)} {HELM: building cluster tree} {PRIME: reading input}}}]

::VMDance::Backend::cleanup
if {$tmp0 eq ""} { unset -nocomplain ::env(TMPDIR) } else { set ::env(TMPDIR) $tmp0 }
use_fake
fake_env

# --- g3: what reaches the backend, and the library (F11 F53 F02 F14 F73 F63 F74 N03 N04) ----------
foreach x [molinfo list] { mol delete $x }
vmdance run clear
use_fake
fake_env
set A ::VMDance::Algo
set m2 [load_system two_state]
set req2 [::VMDance::Job::check_cluster [list mol $m2 sel all k 2 params {kinit KmeansPP}]]

# F11: coordinates that are not numbers are refused as they are read,
# naming the VMD frame and its first such atom, before any backend: the
# program named its CSV row ("row 3" for VMD frame 5, clustered from frame
# 3), a fit failed in vectrans, and the library took an infinity and
# answered (a pick of frames 0 1).
set lines {}
set model 0
foreach line [split [read_text [file join $::fixtures two_state.pdb]] \n] {
    if {[string match "MODEL*" $line]} { incr model }
    # (VMD frame 5, atom index 2: an x of "nan", which VMD reads as NaN)
    if {$model == 6 && [string match "ATOM      3 *" $line]} { set line "[string range $line 0 29]     nan[string range $line 38 end]" }
    lappend lines $line
}
set fh [open [file join $H nan.pdb] w]; puts -nonewline $fh [join $lines \n]; close $fh
set mn [mol new [file join $H nan.pdb] waitfor all]
set nruns [llength [vmdance runs]]
set e [err {vmdance -mol $mn -sel all -first 3 -k 2 -kinit KmeansPP -quiet 1}]
check "F11: a NaN at VMD frame 5, clustered from frame 3: refused, naming frame 5 and its atom, no row ($e)" [expr {
    [string match "*frame 5 of molecule $mn has coordinates that are not numbers*atom 2 of the selection*animate delete beg 5 end 5 $mn*" $e] &&
    ![string match "*row*" $e] && [llength [vmdance runs]] == $nruns}]
set e [err {vmdance -mol $mn -sel all -fit all -k 2 -kinit KmeansPP -quiet 1}]
check "  with a fit: the same, not vectrans's error" [expr {[string match "*frame 5 of molecule $mn has coordinates that are not numbers*" $e] && ![string match "*vectrans*" $e]}]
check "  the atom only in the fit selection: said so" [string match "*frame 5*atom 2 of the fit selection*" [err {
    vmdance -mol $mn -sel "not index 2" -fit "index 2 3 4" -k 2 -kinit KmeansPP -quiet 1}]]
set el $::VMDance::Results::elbow
set pk $::VMDance::Results::picks
check "  a pick and an elbow scan: refused, nothing published" [expr {
    [string match "*frame 5 of molecule $mn*" [err {vmdance pick -mol $mn -sel all -method outliers -param 2}]] &&
    [string match "*frame 5 of molecule $mn*" [err {vmdance elbow -mol $mn -sel all -ks {2 3} -kinit KmeansPP -quiet 1}]] &&
    $::VMDance::Results::elbow eq $el && $::VMDance::Results::picks eq $pk && [llength [vmdance runs]] == $nruns}]
check "  without the frame (-step 2), or without the atom (-sel): clustered" [expr {
    ![catch {vmdance -mol $mn -sel all -step 2 -k 2 -kinit KmeansPP -quiet 1}] &&
    ![catch {vmdance -mol $mn -sel "not index 2" -k 2 -kinit KmeansPP -quiet 1}]}]
mol delete $mn
# (an infinity: atomselect takes Inf, not NaN)
set mi [load_system two_state]
set a [atomselect $mi "index 4" frame 7]
$a set x Inf
if {[real_lib] eq ""} {
    skip "F11: an infinity with the library" "no mdance_tcl library"
} else {
    use_lib
    set e [err {vmdance pick -mol $mi -sel all -method outliers -param 2}]
    check "F11: an infinity at frame 7, with the library: the pick refused, naming the frame (it answered 0 1) ($e)" [string match "*frame 7 of molecule $mi has coordinates that are not numbers*atom 4*" $e]
    use_fake
}
check "  with the program: the clustering refused the same" [string match "*frame 7 of molecule $mi has coordinates that are not numbers*" [err {
    vmdance -mol $mi -sel all -k 2 -kinit KmeansPP -quiet 1}]]
$a set x 3e19
check "F11: a coordinate too large for VMD to measure (3e19): refused as such, not as a NaN" [string match "*frame 7 of molecule $mi has coordinates too large to measure*" [err {
    vmdance -mol $mi -sel all -k 2 -kinit KmeansPP -quiet 1}]]
$a delete
mol delete $mi
# (a message of the program's naming its CSV row names the VMD frame)
::VMDance::Backend::configure -mode cli -cli [script rowcli {if [ $# -eq 0 ]; then exec "@FAKE@"; fi
echo "Error: Invalid numeric value: x (bad) at row 3" >&2
exit 1}]
set e [err {vmdance -mol $m2 -sel all -first 4 -step 2 -k 2 -kinit KmeansPP -quiet 1}]
check "F11: the program's message naming its row 3 names VMD frame 8 (-first 4 -step 2) ($e)" [string match "*at VMD frame 8 (row 3)" $e]
use_fake

# F53: a number the backend cannot read is refused with its option:
# mdance-cli read HELM's as C floats and failed with a bare "stof" (eQUAL's
# and PRIME's: "stod"), where the library rounded them and answered. VMD
# takes 1e-320 for 0: a zero is told by its digits.
set specs {}
foreach al [${A}::all] { foreach p [${A}::params $al] { if {[lindex $p 1] eq "real"} { lappend specs $p } } }
foreach p [concat $::VMDance::Algo::prime_params $::VMDance::Algo::pick_params] { if {[lindex $p 1] eq "real"} { lappend specs $p } }
set bad {}
foreach p $specs {
    foreach v {1e39 -1e39 1e-39 1e-320 1e-400} {
        if {![string match "-[lindex $p 0] *" [err {${A}::check_value $p $v}]]} { lappend bad "-[lindex $p 0] $v taken" }
    }
    foreach v {0 -0.0 0e999 1.2e-38} {
        set e [err {${A}::check_value $p $v}]
        if {$e ne ""} { lappend bad "-[lindex $p 0] $v: $e" }
    }
}
set why ""
if {[llength $bad]} { set why ": [join $bad {; }]" }
check "F53: every real parameter ([llength $specs]) refuses 1e39, -1e39, 1e-39, 1e-320 and 1e-400, naming itself, and takes 0, -0.0, 0e999 and 1.2e-38$why" [expr {![llength $bad]}]
check "  3e38 taken, 3.5e38 refused (a C float's largest is 3.4e38)" [expr {[err {${A}::check_value [${A}::param helm eps] 3e38}] eq "" &&
    [string match "*between 1.2e-38 and 3.4e38*" [err {${A}::check_value [${A}::param helm eps] 3.5e38}]]}]
check "  a stored request keeps its number (a run made with -eps 1e39, before)" [expr {[${A}::check_value [${A}::param helm eps] 1e39 1] eq "1e39"}]
# (a clustering to ask PRIME of)
vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
set c0 $::VMDance::Backend::counter
check "  the command: -eps 1e39, eQUAL's -threshold 1e-320, PRIME's -trim-frac 1e-320 refused before any job" [expr {
    [string match "vmdance: -eps must be 0, or between*" [err {vmdance -mol $m2 -sel all -algorithm helm -k 0 -initial 6 -initial-kinit KmeansPP -eps 1e39 -quiet 1}]] &&
    [string match "vmdance: -threshold must be 0, or between*" [err {vmdance -mol $m2 -sel all -algorithm equal -threshold 1e-320 -quiet 1}]] &&
    [string match "vmdance prime: -trim-frac must be 0, or between*" [err {vmdance prime -trim-frac 1e-320}]] &&
    $::VMDance::Backend::counter == $c0}]
set hp {initial 6 initial-kinit KmeansPP}
check "F53: HELM -k 0 -eps -0.99999999 (the backend's -1, as a float): refused as no -eps, not passed on" [string match "*-k 0 needs -eps*" [err {
    ::VMDance::Job::check_cluster [list mol $m2 sel all algorithm helm k 0 params [dict merge $hp {eps -0.99999999}]]}]]
check "  -k 3 -eps -0.99999999: taken (it was refused as both)" [expr {[err {
    ::VMDance::Job::check_cluster [list mol $m2 sel all algorithm helm k 3 params [dict merge $hp {eps -0.99999999}]]}] eq ""}]
check "F53: HELM -min-samples 3e9 (a C int, which it overflows): refused, naming it" [string match "*-min-samples 3e9: at most the 24 frames*" [err {
    ::VMDance::Job::check_cluster [list mol $m2 sel all algorithm helm k 2 params [dict merge $hp {trim-start 1 trim-val 1 min-samples 3e9}]]}]]
# (a session of runs made before keeps them: a HELM run with -eps 1e39, PRIME with -trim-frac 1e-39)
vmdance -mol $m2 -sel all -algorithm helm -k 2 -initial 6 -initial-kinit KmeansPP -quiet 1
vmdance prime
set sf [file join $H f53.vmdance]
vmdance session save $sf
set d [::VMDance::Session::read_file $sf]
set runs [dict get $d runs]
set a [lindex $runs end 2]
dict set a request params eps 1e39
dict set a extras prime params trim-frac 1e-39
lset runs end 2 $a
dict set d runs $runs
write_session $sf $d
check "  a session of runs made with -eps 1e39 and PRIME's -trim-frac 1e-39 still opens" [expr {![catch {vmdance session load $sf -mol none} e]}]
foreach x [molinfo list] { mol delete $x }
vmdance run clear
set m2 [load_system two_state]
set req2 [::VMDance::Job::check_cluster [list mol $m2 sel all k 2 params {kinit KmeansPP}]]

# F02: with an index other than MSD, CPP-MDANCE's diversity selection read
# past its data (the CompSim and DivSelect seedings, eQUAL's comp_sim
# seeds, the diversity pick): mdance-cli crashed, or every frame landed in
# one cluster published as k. Refused before the backend runs.
set kp [${A}::defaults kmeans]
check "F02: KMeans -kinit CompSim or DivSelect with -metric BUB: refused, naming both and what to do" [expr {
    [string match "-metric BUB with -kinit CompSim: *use -metric MSD, or seed with *" [err {${A}::check_combination kmeans 5 [dict replace $kp kinit CompSim] 100 "" BUB}]] &&
    [string match "-metric BUB with -kinit DivSelect: *" [err {${A}::check_combination kmeans 5 [dict replace $kp kinit DivSelect] 100 "" BUB}]]}]
check "  with MSD, or StratAll with BUB: taken" [expr {[err {${A}::check_combination kmeans 5 [dict replace $kp kinit CompSim] 100 "" MSD}] eq "" &&
    [err {${A}::check_combination kmeans 5 $kp 100 "" BUB}] eq ""}]
set hp2 [dict replace [${A}::defaults helm] initial 20 initial-kinit DivSelect initial-percentage 50]
check "  HELM's first clustering seeded by DivSelect, with RR: refused; started from -initial-labels: taken" [expr {
    [string match "-metric RR with -initial-kinit DivSelect: *" [err {${A}::check_combination helm 5 $hp2 100 "" RR}]] &&
    [err {${A}::check_combination helm 5 [dict replace $hp2 initial-labels x.csv] 100 20 RR}] eq ""}]
set ep [dict replace [${A}::defaults equal] threshold 1]
check "  eQUAL with SM: refused, its comp_sim seeds and its medoid alike (every frame in one cluster)" [expr {
    [string match "-metric SM with eQUAL: *" [err {${A}::check_combination equal "" [dict replace $ep seed-method comp_sim] 100 "" SM}]] &&
    [string match "-metric SM with eQUAL: *use -metric MSD" [err {${A}::check_combination equal "" $ep 100 "" SM}]]}]
check "  DIVINE with CompSim and BUB: refused for its metric (it splits by MSD: h1's N09), not as the diversity selection" [string match "-metric BUB: DIVINE splits by MSD*" [err {
    ${A}::check_combination divine 3 [dict replace [${A}::defaults divine] kinit CompSim] 100 "" BUB}]]
check "  the diversity pick with BUB: refused; the outliers with BUB: taken" [expr {
    [string match "-metric BUB with -method diversity: *" [err {::VMDance::Job::check_pick {method diversity param 10 nbins 10 metric BUB} 100}]] &&
    [err {::VMDance::Job::check_pick {method outliers param 3 nbins 10 metric BUB} 100}] eq ""}]
set c0 $::VMDance::Backend::counter
set e1 [err {vmdance elbow -mol $m2 -sel all -ks {2 3} -kinit CompSim -percentage 20 -metric BUB -quiet 1}]
set e2 [err {vmdance pick -mol $m2 -sel all -method diversity -param 10 -metric BUB}]
set refused [expr {[string match "*-metric BUB with -kinit CompSim*" $e1] && [string match "*-metric BUB with -method diversity*" $e2] && $::VMDance::Backend::counter == $c0}]
set rows [vmdance sweep -mol $m2 -sel all -algorithms kmeans -ks 2 -metrics {MSD BUB} -seedings {KmeansPP CompSim} -quiet 1]
set notrun ""
foreach r $rows { if {[dict get $r metric] eq "BUB" && [dict get $r seeding] eq "CompSim"} { set notrun [dict get $r message] } }
check "  the command: an elbow scan and a pick refused before any job; a sweep keeps BUB with CompSim as not run ($notrun)" [expr {
    $refused && [string match "not run: -metric BUB with -kinit CompSim*" $notrun]}]
# (every method picks a frame once: one picked twice is a backend that
# read past its data, which the plugin's range check let through)
::VMDance::Backend::configure -mode cli -cli [script dupcli {if [ $# -eq 0 ]; then exec "@FAKE@"; fi
out=""
while [ $# -gt 0 ]; do if [ "$1" = "--output" ]; then out=$2; fi; shift; done
echo '{"analysis": "select", "indices": [3, 3, 5]}' > "$out"}]
set pk $::VMDance::Results::picks
set e [err {vmdance pick -mol $m2 -sel all -method outliers -param 3}]
check "F02: a backend that picks a frame twice: refused, the picks there kept ($e)" [expr {[string match "*picked a frame more than once*" $e] && $::VMDance::Results::picks eq $pk}]
use_fake
# (HELM's summary blamed a trimming that was never asked for)
vmdance -mol $m2 -sel all -algorithm helm -k 2 -initial 6 -initial-kinit KmeansPP -quiet 1
set A0 $::VMDance::Results::A
dict set ::VMDance::Results::A request k 9
set s [::VMDance::_summary]
set ::VMDance::Results::A $A0
check "F02: HELM with fewer clusters than asked and no trimming: the summary says from how many it started ($s)" [expr {
    [string match "*fewer than the 9 asked: HELM started from * cluster*" $s] && ![string match "*trimming*" $s]}]

# F14: the most diverse frames are a whole percentage (CPP-MDANCE read 0.5
# as a share: half the frames, 100 times what was asked; 2.5 as 2), and a
# share that holds no frame is refused (an empty pick replaced the one
# there).
check "F14: diversity -param 0.5 and 2.5: refused, a whole percentage; 150: at most 100; 10 and 10.0: taken" [expr {
    [string match "*whole percentage*" [err {vmdance pick -mol $m2 -sel all -method diversity -param 0.5}]] &&
    [string match "*whole percentage*" [err {vmdance pick -mol $m2 -sel all -method diversity -param 2.5}]] &&
    [string match "*at most 100*" [err {vmdance pick -mol $m2 -sel all -method diversity -param 150}]] &&
    ![catch {vmdance pick -mol $m2 -sel all -method diversity -param 10}] && ![catch {vmdance pick -mol $m2 -sel all -method diversity -param 10.0}]}]
set before [vmdance pick show]
check "  outliers -param 0.01 of 24 frames (none of them): refused, the picks there kept; 0.05 (one): taken" [expr {
    [string match "*-param 0.01: a share of the 24 frames that holds no frame*" [err {vmdance pick -mol $m2 -sel all -method outliers -param 0.01}]] &&
    [vmdance pick show] eq $before && [llength [vmdance pick -mol $m2 -sel all -method outliers -param 0.05]] == 1}]

# F73: the backend chosen in Settings (the preferences) is the command's
# too: a script used another until the window opened. It is read once, as
# values, when the backend is first asked about: nothing run or loaded at
# load, the command's options over it, a program gone left to the search,
# a FIFO in the file's place not read.
set home [file join $H home73]
file mkdir $home
set copy [file join $H copy_cli]
file copy -force $::fake $copy
set child [file join $H prefs73.tcl]
set fh [open $child w]
puts $fh [string map [list @LIB@ [file join $::root vmdance] @FAKE@ $::fake] {
    set auto_path [linsert $auto_path 0 {@LIB@}]
    package require vmdance
    set B ::VMDance::Backend
    puts "load=<[expr {[info exists ${B}::prefs_read] ? [set ${B}::prefs_read] : "-"}] [array size ${B}::caps] <[set ${B}::loaded]>>"
    if {[lindex $argv 0] eq "first"} { vmdance backend -cli {@FAKE@} }
    set s [vmdance backend]
    puts "using=<[dict get $s using]> mode=<[dict get $s mode]> error=<[dict get $s error]>"
}]
close $fh
proc prefs73 {text args} {
    set f [file join $::home .vmdance.prefs]
    file delete $f
    if {$text eq "FIFO"} { exec mkfifo $f } else { set fh [open $f w]; puts $fh $text; close $fh }
    set keep {}
    foreach v {HOME MDANCE_CLI MDANCE_LIB} { if {[info exists ::env($v)]} { dict set keep $v $::env($v) } }
    unset -nocomplain ::env(MDANCE_CLI) ::env(MDANCE_LIB)
    set ::env(HOME) $::home
    catch {exec timeout 30 tclsh $::child {*}$args 2>@1} o
    foreach v {HOME MDANCE_CLI MDANCE_LIB} { if {[dict exists $keep $v]} { set ::env($v) [dict get $keep $v] } else { unset -nocomplain ::env($v) } }
    return [join [split $o \n] { }]
}
set o [prefs73 "backend_mode cli\nbackend_cli [list $copy]"]
check "F73: a script uses the program chosen in Settings; nothing read, probed or loaded at load ($o)" [string match "load=<0 0 <>>*using=<cli $copy> mode=<cli> error=<>*" $o]
set o [prefs73 "backend_mode cli\nbackend_cli [list $copy]" first]
check "  vmdance backend -cli given first: kept" [string match "*using=<cli $::fake> mode=<cli>*" $o]
set o [prefs73 "backend_mode auto\nbackend_cli /nowhere/mdance-cli"]
check "  a program chosen that is gone: the search, no error about it" [expr {[string match "*using=<*" $o] && ![string match "*nowhere*" $o]}]
set o [prefs73 "backend_mode {\[exec touch [file join $H pwned73]\]}\nbackend_cli {\[exec touch [file join $H pwned73b]\]}"]
check "  hostile values: ignored, nothing run" [expr {![file exists [file join $H pwned73]] && ![file exists [file join $H pwned73b]] && [string match "*mode=<auto>*" $o]}]
if {[real_lib] ne ""} {
    set o [prefs73 "backend_mode library\nbackend_lib [list [real_lib]]"]
    check "  the library chosen: loaded when the backend is asked, not at load" [string match "load=<0 0 <>>*using=<library [real_lib]>*" $o]
}
if {[catch {exec mkfifo [file join $H fifo_probe]}]} {
    skip "  a FIFO as the preferences" "mkfifo is not available"
} else {
    file delete [file join $H fifo_probe]
    set t0 [clock milliseconds]
    set o [prefs73 FIFO]
    check "  a FIFO as the preferences: not read, the defaults at once ([expr {[clock milliseconds] - $t0}] ms)" [expr {[string match "*mode=<auto>*" $o] && [clock milliseconds] - $t0 < 20000}]
}
file delete [file join $home .vmdance.prefs]

# The library loaded by a name with ".." in it, then asked for by its plain
# name (or the other way round): one library, not "another" that needs a
# restart (load_lib kept the name as given, configure compares normalized
# names). In a child tclsh: a library loads once per process.
if {[real_lib] ne ""} {
    set lib [real_lib]
    set odd [file join [file dirname $lib] .. [file tail [file dirname $lib]] [file tail $lib]]
    set child2 [file join $H twonames.tcl]
    set fh [open $child2 w]
    puts $fh [string map [list @LIB@ [file join $::root vmdance]] {
        set auto_path [linsert $auto_path 0 {@LIB@}]
        package require vmdance
        set B ::VMDance::Backend
        ${B}::load_lib [lindex $argv 0]
        puts "loaded=<[set ${B}::loaded]>"
        if {[catch {${B}::configure -mode library -library [lindex $argv 1]} e]} { puts "refused=<$e>" } else { puts "taken" }
    }]
    close $fh
    foreach {first then} [list $odd $lib $lib $odd] {
        catch {exec timeout 60 tclsh $child2 $first $then 2>@1} o
        check "the library loaded as \"[file tail [file dirname [file dirname $first]]]/...\" then asked for by another name of the same file: taken ([join [split $o \n] { }])" [expr {[string match "*loaded=<$lib>*" $o] && [string match "*taken*" $o]}]
    }
}

# F63: Settings tries a backend without applying it (a job started
# meanwhile ran on the program only tried, and Cancel during a job could not
# put the old one back): the command's backend try does the same.
use_fake
set before [::VMDance::Backend::settings]
set s {}
catch {set s [vmdance backend try -cli $copy]}
check "F63: backend try: what a program gives, the backend in use kept" [expr {[::VMDance::_get $s using ""] eq [list cli $copy] && [::VMDance::Backend::settings] eq $before}]
fake_env MDANCE_FAKE_SLEEP 1
bg cluster $req2
set s {}
catch {set s [vmdance backend try -cli $copy]}
lassign [wait_bg 20000] st r
fake_env
check "  while a job runs too, which runs on the backend in use" [expr {[::VMDance::_get $s using ""] eq [list cli $copy] && $st eq "ok" &&
    [dict get $r backend] eq [list cli $::fake] && [::VMDance::Backend::settings] eq $before}]
check "  a path that is no program: refused, nothing changed" [expr {[string match "*not an executable program*" [err {vmdance backend try -cli /etc/hosts}]] &&
    [::VMDance::Backend::settings] eq $before}]

# N03, N04: the library takes the coordinates as one list, of which
# CPP-MDANCE's Tcl binding makes a text: past 2 GB Tcl ends VMD, and a call
# takes about 180 bytes a number at its peak (VMD was killed for want of
# memory where the program took 700 MB). What cannot fit is refused, saying
# what to change, and nothing is published.
vmdance -mol $m2 -sel all -fit all -k 2 -kinit KmeansPP -quiet 1
set c $::VMDance::Coords::C
set t1 [expr {[string length [::VMDance::Coords::flat $c]] == [file size [::VMDance::Coords::csv $c]] - 1}]
vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
set c $::VMDance::Coords::C
set t2 [expr {[string length [::VMDance::Coords::flat $c]] == [file size [::VMDance::Coords::csv $c]] - 1}]
check "N03: the text the library makes of the coordinates is their CSV less a byte, with a fit or without (the limit's measure)" [expr {$t1 && $t2}]
# (what Tcl kept from an earlier call as large is VMD's to reuse: a second
# call is not refused where the first ran)
set e1 ""; set e2 "-"
if {[info commands ::VMDance::Job::_memory_free] ne ""} {
    set most0 $::VMDance::Job::lib_most
    rename ::VMDance::Job::_memory_free ::VMDance::Job::_memory_free_
    proc ::VMDance::Job::_memory_free {} { return 200000 }
    set ::VMDance::Job::lib_most 0
    set e1 [err {::VMDance::Job::_library_fits 8 100}]
    set ::VMDance::Job::lib_most 2400
    set e2 [err {::VMDance::Job::_library_fits 8 100}]
    rename ::VMDance::Job::_memory_free {}
    rename ::VMDance::Job::_memory_free_ ::VMDance::Job::_memory_free
    set ::VMDance::Job::lib_most $most0
}
check "N04: a first call of 2400 numbers needs 432 kB (refused with 200 kB free); after one as large, 144 kB (taken)" [expr {
    [string match "*would need about 432 kB more in VMD for 100 frames × 8 atoms, and 200 kB is free*" $e1] && $e2 eq ""}]
::VMDance::Backend::configure -mode auto
check "  in Automatic, the message says it found no program" [string match "*use the program (*Automatic found none)*" [err {::VMDance::Job::_library_fits 8 100 3000000000}]]
use_fake
if {[real_lib] eq ""} {
    skip "N03, N04: the library's limits in a job" "no mdance_tcl library"
} else {
    use_lib
    vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
    set nruns [llength [vmdance runs]]
    set el $::VMDance::Results::elbow
    set pk $::VMDance::Results::picks
    set S2 [file size [::VMDance::Coords::csv $::VMDance::Coords::C]]
    ::VMDance::Coords::forget
    set ::VMDance::Job::lib_text_max 1000
    set e [err {vmdance -mol $m2 -sel all -k 3 -kinit KmeansPP -quiet 1}]
    check "N03: past the text's limit (1000 bytes here): refused before the frames are read, saying what to change ($e)" [expr {
        [string match "vmdance: -sel, -first, -last, -step: the library cannot take 24 frames × 8 atoms: *2 GB, which ends VMD; use the program*fewer atoms (-sel) or frames (-first, -last, -step)" $e] &&
        [llength [vmdance runs]] == $nruns && ![dict size $::VMDance::Coords::C]}]
    check "  an elbow scan (refused whole), a pick, PRIME and the similarity: refused, nothing published" [expr {
        [string match "*library cannot take*" [err {vmdance elbow -mol $m2 -sel all -ks {2 3} -kinit KmeansPP -quiet 1}]] &&
        [string match "*library cannot take*" [err {vmdance pick -mol $m2 -sel all -method medoid}]] &&
        [string match "*library cannot take*" [err {vmdance prime}]] &&
        [string match "*library cannot take*" [err {vmdance similarity}]] &&
        $::VMDance::Results::elbow eq $el && $::VMDance::Results::picks eq $pk && [llength [vmdance runs]] == $nruns}]
    # (an estimate below the text: the limit between them is found when the frames are read, exactly)
    set ::VMDance::Job::lib_text_max [expr {$S2 - 2}]
    set e [err {vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1}]
    set ::VMDance::Job::lib_text_max [expr {$S2 - 1}]
    set ok [expr {![catch {vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1}]}]
    set ::VMDance::Job::lib_text_max 2147483647
    check "  the text's exact length, from the frames read ([expr {$S2 - 1}] bytes; estimated [expr {17 * 576}]): a byte over the limit refused, at it clustered" [expr {
        [string match "*library cannot take*" $e] && $ok}]
    set nruns [llength [vmdance runs]]
    if {[info commands ::VMDance::Job::_memory_free] eq "" || [::VMDance::Job::_memory_free] eq ""} {
        skip "N04: the library's memory" "no /proc/meminfo"
    } else {
        set ::VMDance::Job::lib_peak 1e15
        set e [err {vmdance -mol $m2 -sel all -k 3 -kinit KmeansPP -quiet 1}]
        set ::VMDance::Job::lib_peak 180
        check "N04: a call that needs more memory than VMD can get (raised here): refused, saying what to change" [expr {
            [string match "*-sel, -first, -last, -step: the library would need about * more in VMD for 24 frames × 8 atoms, and * is free; use the program*" $e] &&
            [llength [vmdance runs]] == $nruns}]
    }
    # F74: the library writes the coordinates' file too (Settings and the
    # papers said it wrote none): pinned
    ::VMDance::Coords::forget
    vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
    set f [::VMDance::Coords::csv $::VMDance::Coords::C]
    check "F74: a library clustering writes the coordinates to the private folder, as the docs now say" [expr {
        [lindex [dict get [vmdance info] backend] 0] eq "library" && [file dirname $f] eq [::VMDance::Backend::workdir] && [file size $f] > 0}]
    use_fake
}
# F74: a private folder that cannot take the coordinates says so, with the
# folder and what to do (it said Tcl's name of the file, "file46")
::VMDance::Backend::cleanup
::VMDance::Coords::forget
set ro [file join $H readonly]
file mkdir $ro
file attributes $ro -permissions 0500
if {[file writable $ro]} {
    skip "F74: a folder that cannot take the coordinates" "this user writes to a 0500 folder"
} else {
    set ::VMDance::Backend::workdir $ro
    set nruns [llength [vmdance runs]]
    set e [err {vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1}]
    check "F74: a private folder that cannot take the coordinates: said with the folder and TMPDIR, nothing left, nothing published ($e)" [expr {
        [string first "the coordinates could not be written to $ro (" $e] >= 0 && [string match "*: free room there, or set TMPDIR to another folder" $e] &&
        ![llength [glob -nocomplain -directory $ro *]] && [llength [vmdance runs]] == $nruns}]
}
file attributes $ro -permissions 0700
::VMDance::Backend::cleanup
file delete -force $ro
use_fake
fake_env

# --- g4: files and exports (F03 F09 F20 F34 F35 F36 F38 F48 F51 F52 F72 F75) --------------------
set G4 [file join $H g4]
file mkdir $G4
set ::VMDance::Prefs::file ""
proc put {f t} { set fh [open $f wb]; puts -nonewline $fh $t; close $fh }
proc slurp {f} { set fh [open $f rb]; try { return [read $fh] } finally { close $fh } }
# the plugin's temporaries left in a folder (<file>.tmp<pid>-<random>)
proc temps {d} { glob -nocomplain -tails -directory $d *.tmp[pid]-* }
# the first line of a table that is not a # line (its columns)
proc first_row {f} { foreach l [split [slurp $f] \n] { if {[string index $l 0] ne "#"} { return $l } } }
set mg [load_system two_state]
vmdance -mol $mg -sel all -k 2 -kinit KmeansPP -quiet 1

# F03: a link put at a temporary's name (they were <file>.tmp<pid>, opened
# following links: another user who can write to the folder made the
# export overwrite any file of the user's) is never opened.
set sent [file join $H g4_sentinel]
put $sent PRECIOUS
foreach n [list x_labels.csv x_representatives.dcd x_representatives.pdb s.vmdance prefs] {
    file link -symbolic [file join $G4 $n.tmp[pid]] $sent
}
file link -symbolic [file join $G4 y_representatives.pdb.tmp[pid].pdb] $sent
exec ln -s [file join $G4 made_by_a_link] [file join $G4 x_clusters.csv.tmp[pid]]
vmdance export $G4 -prefix x -items {labels clusters representatives}
vmdance export $G4 -prefix y -items representatives -format pdb
vmdance session save [file join $G4 s.vmdance]
set ::VMDance::Prefs::file [file join $G4 prefs]
set pe [::VMDance::Prefs::save {ui_font 13}]
set ::VMDance::Prefs::file ""
check "F03: links at the names temporaries had: exports, a session and the preferences write through none (the file linked to, and a dangling link's, untouched)" [expr {
    [slurp $sent] eq "PRECIOUS" && ![file exists [file join $G4 made_by_a_link]] && $pe eq ""}]
check "  each file written is a file of its own (not the link), and no temporary is left" [expr {
    [lsort -unique [lmap n {x_labels.csv x_clusters.csv x_representatives.dcd x_representatives.pdb y_representatives.pdb s.vmdance prefs} {
        file type [file join $G4 $n]}]] eq "file" && ![llength [temps $G4]]}]
# (rand made to repeat: a link at the very name the next temporary takes)
set f [file normalize [file join $G4 c_labels.csv]]
expr {srand(4242)}
set first [format "%s.tmp%d-%08x" $f [pid] [expr {int(rand() * 4294967296.0)}]]
expr {srand(4242)}
file link -symbolic $first $sent
set e [err {::VMDance::Export::_write $f "new\n"}]
check "  a link at the very name a temporary takes: never opened, another name taken" [expr {
    $e eq "" && [slurp $sent] eq "PRECIOUS" && [slurp $f] eq "new\n" && [file type $first] eq "link"}]
file delete $first

# F09: a DCD keeps every frame's unit cell, as VMD's dcdplugin writes it
# (every cell was dropped: VMD read 0 0 0, MDAnalysis no box).
set mc [load_system two_state]
set cells {}
for {set i 0} {$i < 24} {incr i} {
    switch [expr {$i % 3}] {
        0 { set c [list [expr {60.0 + $i}] [expr {61.0 + $i / 2.0}] 62.0 90.0 90.0 90.0] }
        1 { set c {70.528779 70.528779 70.528779 109.471221 109.471221 109.471221} }
        2 { set c [list 50.0 50.0 [expr {80.0 + $i}] 90.0 90.0 120.0] }
    }
    molinfo $mc set {a b c alpha beta gamma} $c frame $i
    lappend cells $c
}
vmdance -mol $mc -sel all -k 2 -kinit KmeansPP -quiet 1
set reps [::VMDance::Export::rep_frames]
set c0 [${R}::member_frames 0]
vmdance export $G4 -prefix cell -items {representatives trajectories}
proc cells_of {pdb dcd} {
    set t [mol new $pdb waitfor all]
    animate delete all $t
    mol addfile $dcd waitfor all molid $t
    set l {}
    for {set i 0} {$i < [molinfo $t get numframes]} {incr i} { lappend l [molinfo $t get {a b c alpha beta gamma} frame $i] }
    mol delete $t
    return $l
}
proc same_cells {a b} {
    if {[llength $a] != [llength $b]} { return 0 }
    foreach x $a y $b { foreach u $x v $y { if {abs($u - $v) > 1e-3} { return 0 } } }
    return 1
}
check "F09: the representatives' DCD: each frame's cell read back, triclinic and hexagonal ones too" [same_cells \
    [cells_of [file join $G4 cell_representatives.pdb] [file join $G4 cell_representatives.dcd]] [lmap i $reps {lindex $cells $i}]]
check "  a cluster's trajectory: every frame's" [same_cells [cells_of [file join $G4 cell_cluster_0.pdb] [file join $G4 cell_cluster_0.dcd]] \
    [lmap i $c0 {lindex $cells $i}]]
binary scan [slurp [file join $G4 cell_cluster_0.dcd]] x20ix24i nstep flag
check "  its header as dcdplugin's: the cell flag set, NSTEP the frames ($nstep of [llength $c0])" [expr {$flag == 1 && $nstep == [llength $c0]}]
vmdance -mol $mg -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance export $G4 -prefix nobox -items representatives
set zero [lsort -unique -real [concat {*}[lmap c [cells_of [file join $G4 nobox_representatives.pdb] [file join $G4 nobox_representatives.dcd]] {lrange $c 0 2}]]]
check "  a molecule without a box: zeros, as VMD writes them ($zero)" [expr {[llength $zero] == 1 && [lindex $zero 0] == 0}]

# F52: a PDB export is VMD's own writer's, frame by frame: residues past
# 9999 in VMD's hex (read back through a molecule of its own, 271a 271b …
# all became 271), each frame's cell, no molecule made.
vmdance -mol $mc -sel all -k 2 -kinit KmeansPP -quiet 1
set reps [::VMDance::Export::rep_frames]
set a [atomselect $mc all]
set resid0 [$a get resid]
$a set resid [lmap x $resid0 {expr {$x + 10009}}]
$a delete
set top0 [molinfo top]
set mols0 [molinfo list]
vmdance export $G4 -prefix hex -items representatives -format pdb
vmdance export $G4 -prefix hexd -items representatives
set left [list [molinfo top] [molinfo list]]
set s [atomselect $mc all frame [lindex $reps 0]]
$s writepdb [file join $G4 own.pdb]
$s delete
proc resids {f} {
    set l {}
    foreach x [split [slurp $f] \n] { if {[string match ATOM* $x]} { lappend l [string range $x 22 25] } }
    return $l
}
set own [resids [file join $G4 own.pdb]]
check "F52: residues past 9999 as VMD writes them ([lindex $own 0], not 271): the PDB export's first frame, the PDB beside a DCD, VMD's own writepdb" [expr {
    [lrange [resids [file join $G4 hex_representatives.pdb]] 0 7] eq $own && [resids [file join $G4 hexd_representatives.pdb]] eq $own &&
    [lindex $own 0] eq "271a"}]
set t [mol new [file join $G4 hex_representatives.pdb] waitfor all]
set got [lmap i {0 1} {molinfo $t get {a b c} frame $i}]
mol delete $t
check "  each frame with its own cell; no molecule made, VMD's top one left as it was" [expr {
    [same_cells $got [lmap i $reps {lrange [lindex $cells $i] 0 2}]] && $left eq [list $top0 $mols0]}]
set a [atomselect $mc all]
$a set resid $resid0
$a delete

# F36: a frame VMD's PDB writer cannot write (a coordinate past
# -999.999: it stops there, and the file cut was renamed into place as
# written) is refused, naming the frame and what to do; the file there is
# kept, none is left half written.
vmdance export $G4 -prefix far -items representatives -format pdb
set before [md5 [file join $G4 far_representatives.pdb]]
set f1 [lindex $reps end]
set s [atomselect $mc "index 0" frame $f1]
set xyz [$s get {x y z}]
$s set x -1500.0
set e [err {vmdance export $G4 -prefix far -items representatives -format pdb}]
$s set {x y z} $xyz
$s delete
check "F36: a frame with a coordinate a PDB cannot hold: refused, the frame named, a DCD offered; the file there kept ($e)" [expr {
    [string match "*far_representatives.pdb\" could not be written: frame $f1 has a coordinate, an occupancy or a beta that a PDB cannot hold*-format dcd*" $e] &&
    [md5 [file join $G4 far_representatives.pdb]] eq $before && ![llength [temps $G4]] && ![llength [lsearch -all -inline -glob [leftovers] *.pdb]]}]
put [file join $G4 cut.pdb] [string range [slurp [file join $G4 own.pdb]] 0 end-10]
put [file join $G4 empty.pdb] ""
check "  VMD's writer checked by its last END (it says nothing of a last write that fails): whole, cut, empty" [expr {
    [::VMDance::Export::_whole [file join $G4 own.pdb]] && ![::VMDance::Export::_whole [file join $G4 cut.pdb]] &&
    ![::VMDance::Export::_whole [file join $G4 empty.pdb]]}]

# F38: the PDB beside a DCD that cannot be written leaves the DCD there
# as it was (the DCD was renamed first, beside the old PDB).
vmdance export $G4 -prefix pair -items representatives
set before [lmap x {dcd pdb} {md5 [file join $G4 pair_representatives.$x]}]
set f0 [lindex $reps 0]
set s [atomselect $mc "index 0" frame $f0]
set xyz [$s get {x y z}]
$s set x -1500.0
set e [err {vmdance export $G4 -prefix pair -items representatives}]
$s set {x y z} $xyz
$s delete
check "F38: the PDB beside a DCD cannot be written: the DCD is not replaced either, the atoms to leave out said ($e)" [expr {
    [string match "*pair_representatives.pdb\" could not be written: frame $f0 *(-sel)" $e] &&
    [lmap x {dcd pdb} {md5 [file join $G4 pair_representatives.$x]}] eq $before && ![llength [temps $G4]]}]

# F48: a name that is a folder, or a link to one (the file was moved into
# it, under its temporary name, and reported written).
file mkdir [file join $G4 f_labels.csv] [file join $G4 adir] [file join $G4 g_representatives.pdb]
file link -symbolic [file join $G4 f_top_frames.csv] [file join $G4 adir]
set e1 [err {vmdance export $G4 -prefix f -items labels}]
set e2 [err {vmdance export $G4 -prefix f -items top}]
set e3 [err {vmdance export $G4 -prefix g -items {labels representatives}}]
check "F48: a folder, a link to one, the PDB beside a DCD a folder: refused before anything is written, nothing moved into them" [expr {
    [string match "*f_labels.csv\" is a folder, not a file" $e1] && [string match "*f_top_frames.csv\" (a link to \"*adir\") is a folder, not a file" $e2] &&
    [string match "*g_representatives.pdb\" is a folder, not a file" $e3] &&
    ![llength [glob -nocomplain -directory [file join $G4 f_labels.csv] *]] && ![llength [glob -nocomplain -directory [file join $G4 adir] *]] &&
    ![llength [glob -nocomplain -directory [file join $G4 g_representatives.pdb] *]] &&
    ![file exists [file join $G4 g_labels.csv]] && ![file exists [file join $G4 g_representatives.dcd]]}]

# F51: a file there keeps what it was: one read-only is refused (it was
# replaced), one of 0600 or 0664 keeps it (it became 0644), a link of the
# user's stays a link (the file it points to is written: a dotfile kept
# elsewhere); one of another user's is replaced, what it points to left
# alone.
set dot [file join $H g4_dotfiles]
file mkdir $dot
foreach n {ro_labels.csv ro_representatives.pdb} {
    put [file join $G4 $n] OLD
    file attributes [file join $G4 $n] -permissions 0444
}
if {[file writable [file join $G4 ro_labels.csv]]} {
    skip "F51: a read-only file" "this user writes to a 0444 file"
} else {
    set e1 [err {vmdance export $G4 -prefix ro -items labels}]
    set e2 [err {vmdance export $G4 -prefix ro -items representatives -format pdb}]
    check "F51: a read-only table or structure: refused, the file as it was" [expr {
        [string match "*ro_labels.csv\" is read-only" $e1] && [string match "*ro_representatives.pdb\" is read-only" $e2] &&
        [slurp [file join $G4 ro_labels.csv]] eq "OLD" && [file attributes [file join $G4 ro_labels.csv] -permissions] eq "00444"}]
    put [file join $dot ro.prefs] "ui_font 12\n"
    file attributes [file join $dot ro.prefs] -permissions 0444
    set ::VMDance::Prefs::file [file join $G4 ro.prefs]
    file link -symbolic $::VMDance::Prefs::file [file join $dot ro.prefs]
    set pe [::VMDance::Prefs::save {ui_font 16}]
    set ::VMDance::Prefs::file ""
    check "  preferences linked to a read-only file (a store's): not saved, said; the link kept ($pe)" [expr {
        [string match "*read-only" $pe] && [file type [file join $G4 ro.prefs]] eq "link" && [slurp [file join $dot ro.prefs]] eq "ui_font 12\n"}]
}
foreach {p mode} {pv 0600 gw 0664} {
    put [file join $G4 ${p}_labels.csv] OLD
    file attributes [file join $G4 ${p}_labels.csv] -permissions $mode
}
set ss [file join $G4 pv.vmdance]
put $ss OLD
file attributes $ss -permissions 0600
vmdance export $G4 -prefix pv -items labels
vmdance export $G4 -prefix gw -items labels
vmdance export $G4 -prefix nw -items labels
vmdance session save $ss
set fh [open [file join $G4 umask.txt] w]; close $fh
check "  a table of 0600 or 0664, a session of 0600: kept; a new file the umask's ([file attributes [file join $G4 nw_labels.csv] -permissions])" [expr {
    [file attributes [file join $G4 pv_labels.csv] -permissions] eq "00600" && [file attributes [file join $G4 gw_labels.csv] -permissions] eq "00664" &&
    [file attributes $ss -permissions] eq "00600" && [string match "# VMDance*" [slurp [file join $G4 pv_labels.csv]]] &&
    [file attributes [file join $G4 nw_labels.csv] -permissions] eq [file attributes [file join $G4 umask.txt] -permissions]}]
put [file join $dot labels.csv] OLD
file link -symbolic [file join $G4 ln_labels.csv] [file join $dot labels.csv]
put [file join $dot s.vmdance] OLD
file link -symbolic [file join $G4 ln.vmdance] [file join $dot s.vmdance]
put [file join $dot prefs] "ui_font 12\n"
file link -symbolic [file join $G4 ln.prefs] [file join $dot prefs]
vmdance export $G4 -prefix ln -items labels
vmdance session save [file join $G4 ln.vmdance]
set ::VMDance::Prefs::file [file join $G4 ln.prefs]
set pe [::VMDance::Prefs::save {ui_font 16}]
set ::VMDance::Prefs::file ""
check "  a link of the user's (a table, a session, the preferences): still a link, the file it points to written" [expr {$pe eq "" &&
    [lsort -unique [lmap n {ln_labels.csv ln.vmdance ln.prefs} {file type [file join $G4 $n]}]] eq "link" &&
    [string match "# VMDance*" [slurp [file join $dot labels.csv]]] && [string range [slurp [file join $dot s.vmdance]] 0 1] eq "\x1f\x8b" &&
    [string match "*ui_font 16*" [slurp [file join $dot prefs]]]}]
put [file join $dot theirs.csv] THEIRS
file link -symbolic [file join $G4 th_labels.csv] [file join $dot theirs.csv]
# (this user's uid made another's: the link is then of someone else)
set uid0 [::VMDance::Backend::_uid]
set ::VMDance::Backend::uid 4000000000
set e [err {vmdance export $G4 -prefix th -items labels}]
set ::VMDance::Backend::uid $uid0
check "  a link of another user's (put in a shared folder): replaced by the file, what it points to left alone" [expr {
    $e eq "" && [file type [file join $G4 th_labels.csv]] eq "file" && [slurp [file join $dot theirs.csv]] eq "THEIRS"}]

# F35: a selection written over two lines, a name with a line break: each
# # line stays one line (the rest was read as data: HELM could not read
# its labels back, numpy failed).
set name0 [molinfo $mg get name]
mol rename $mg "two_state\n=HYPERLINK(1)"
set nl "all and not\n    name XYZ"
vmdance -mol $mg -sel $nl -fit "all and\n  not name XYZ" -k 2 -kinit KmeansPP -quiet 1
vmdance elbow -mol $mg -sel $nl -ks {2 3} -kinit KmeansPP -quiet 1
vmdance pick -mol $mg -sel $nl -method medoid
vmdance export $G4 -prefix nl -items {labels clusters elbow picks}
mol rename $mg $name0
set lt [slurp [file join $G4 nl_labels.csv]]
check "F35: a selection and a fit over two lines, a name with a line break: every # line one line (labels, clusters, the elbow, the picks)" [expr {
    [first_row [file join $G4 nl_labels.csv]] eq "frame,cluster" && [string match "cluster,frames,*" [first_row [file join $G4 nl_clusters.csv]]] &&
    [string match "k,k_actual,*" [first_row [file join $G4 nl_elbow.csv]]] && [first_row [file join $G4 nl_picks.csv]] eq "rank,frame" &&
    [string match "*\n# selection: all and not name XYZ (8 atoms), fitted on: all and not name XYZ\n*" $lt] &&
    [regexp {\n# molecule: [^\n]*HYPERLINK\(1\)[^\n]*\(two_state.pdb\)\n} $lt]}]
check "  HELM reads the labels back as its starting clusters" [expr {
    ![catch {vmdance -mol $mg -sel all -algorithm helm -k 1 -initial-labels [file join $G4 nl_labels.csv] -quiet 1}]}]
check "  a CSV field with a carriage return is quoted" [expr {[::VMDance::Export::_f "a\rb"] eq "\"a\rb\""}]

# F20: an export checks everything before it writes anything (a run
# without PRIME after one with it replaced the run's tables, then failed;
# the window said "Not exported" after writing 10 files); a failure while
# writing changes no file.
vmdance -mol $mg -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance prime
vmdance export $G4 -prefix p -items {summary clusters prime}
set before [lmap n {summary.txt clusters.csv prime.csv} {md5 [file join $G4 p_$n]}]
vmdance -mol $mg -sel all -k 3 -kinit KmeansPP -quiet 1
set e1 [err {vmdance export $G4 -prefix p -items {summary clusters prime}}]
set e2 [err {vmdance export $G4 -prefix q -items {summary labels representatives} -sel "garbage((("}]
set e3 [err {vmdance export $G4 -prefix q -items {summary labels trajectories} -sel "resname XYZ"}]
set pk $::VMDance::Results::picks
${R}::set_picks {}
set e4 [err {vmdance export $G4 -prefix q -items {summary picks}}]
${R}::set_picks $pk
set md [load_system two_state]
vmdance -mol $md -sel all -k 2 -kinit KmeansPP -quiet 1
mol delete $md
set e5 [err {vmdance export $G4 -prefix q -items {summary labels representatives}}]
check "F20: refused before anything is written: PRIME of another run, a -sel that fails or holds no atom, picks gone, the molecule deleted" [expr {
    [string match "*no PRIME prediction*" $e1] && [lmap n {summary.txt clusters.csv prime.csv} {md5 [file join $G4 p_$n]}] eq $before &&
    [string match "*-sel: *" $e2] && [string match "*-sel: \"resname XYZ\" matches no atom*" $e3] && [string match "*no frames picked*" $e4] &&
    [string match "*not loaded*" $e5] && ![llength [glob -nocomplain -directory $G4 q_*]]}]
vmdance -mol $mg -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance export $G4 -prefix w -items {summary labels representatives trajectories} -format pdb
set wf [lsort [glob -directory $G4 w_*]]
set before [lmap x $wf {md5 $x}]
vmdance -mol $mg -sel all -k 2 -kinit KmeansPP -quiet 1
set ff [lindex [${R}::member_frames 1] end]
set s [atomselect $mg "index 0" frame $ff]
set xyz [$s get {x y z}]
$s set x -1500.0
set e [err {vmdance export $G4 -prefix w -items {summary labels representatives trajectories} -format pdb}]
$s set {x y z} $xyz
$s delete
check "  a file that fails while it is written (its last, a frame a PDB cannot hold): the export's [llength $wf] files as they were, none half written" [expr {
    [string match "*could not be written: frame $ff *" $e] && [lmap x $wf {md5 $x}] eq $before && [lsort [glob -directory $G4 w_*]] eq $wf &&
    ![llength [temps $G4]]}]

# F72: the folder of an export is made when it does not exist (the
# documented `vmdance export results` failed), once everything is
# checked.
set e [err {vmdance export [file join $G4 new a b] -prefix n -items labels}]
set e1 [err {vmdance export [file join $G4 nf1] -items everything}]
set e2 [err {vmdance export [file join $G4 nf2] -prefix ../x -items labels}]
set e3 [err {vmdance export [file join $G4 nf3] -items {labels prime}}]
put [file join $G4 afile] KEEP
set e4 [err {vmdance export [file join $G4 afile] -items labels}]
check "F72: an export into a folder that does not exist: made, with its parents" [expr {$e eq "" && [file isfile [file join $G4 new a b n_labels.csv]]}]
check "  a refused export makes none (an unknown item, a prefix with a folder, an item it cannot write); a file in its place refused" [expr {
    ![file exists [file join $G4 nf1]] && ![file exists [file join $G4 nf2]] && [string match "*no PRIME*" $e3] && ![file exists [file join $G4 nf3]] &&
    [string match "*afile\" is a file, not a folder" $e4] && [slurp [file join $G4 afile]] eq "KEEP"}]

# F75: a scan's and the picks' tables say how they were made: the sweep's
# fixed parameters, each algorithm's, and the backend (a sweep at the
# defaults and one of -percentage 40 wrote the same header).
vmdance sweep -mol $mg -sel all -algorithms {kmeans helm} -ks {2 3} -seedings KmeansPP -params {kmeans {percentage 40} helm {initial 12 merge-scheme Intra}} -quiet 1
vmdance elbow -mol $mg -sel all -ks {2 3} -kinit KmeansPP -quiet 1
vmdance pick -mol $mg -sel all -method medoid
vmdance export $G4 -prefix sc -items {sweep elbow picks}
set tsw [slurp [file join $G4 sc_sweep.csv]]
check "F75: the sweep's table names each algorithm's fixed parameters (the seeding a column, as it was)" [expr {
    [regexp {\n# parameters of KMeans NANI: percentage 40\n} $tsw] && [regexp {\n# parameters of HELM: initial 12, [^\n]*merge-scheme Intra[^\n]*\n} $tsw] &&
    ![regexp {\n# parameters of [^\n]*kinit} $tsw] && [first_row [file join $G4 sc_sweep.csv]] eq "algorithm,k,k_actual,metric,seeding,calinski_harabasz,davies_bouldin,status"}]
check "  the sweep's, the elbow scan's and the picks' tables name the backend, and when" [expr {
    [regexp {\n# backend: cli [^\n]*fake_mdance_cli; scanned [0-9]{4}-[0-9]{2}-[0-9]{2}T[^\n]*\n} $tsw] &&
    [regexp {\n# backend: cli [^\n]*fake_mdance_cli; scanned } [slurp [file join $G4 sc_elbow.csv]]] &&
    [regexp {\n# backend: cli [^\n]*fake_mdance_cli; picked } [slurp [file join $G4 sc_picks.csv]]]}]
set sf [file join $G4 sc.vmdance]
vmdance session save $sf
vmdance session load $sf -mol none
check "  a session keeps them" [expr {[dict exists $::VMDance::Results::sweep backend] && [dict exists $::VMDance::Results::picks backend]}]
set sw $::VMDance::Results::sweep
${R}::set_sweep [dict remove $sw backend]
vmdance export $G4 -prefix sc2 -items sweep
${R}::set_sweep $sw
check "  a sweep saved before scans kept it: its first clustering's backend" [regexp {\n# backend: cli [^\n]*fake_mdance_cli; scanned } [slurp [file join $G4 sc2_sweep.csv]]]
set d [::VMDance::Session::read_file $sf]
dict set d sweep backend "a \{b"
write_session [file join $G4 bad.vmdance] $d
check "  a session whose sweep's backend is not a list: refused" [string match "*the sweep's backend is corrupt*" [err {vmdance session load [file join $G4 bad.vmdance] -mol none}]]

# F34: the files of a DCD: it and the PDB of its atoms beside it, which the
# window's Save picks now asks about before it replaces it (test_gui)
check "F34: a DCD's files: it, and the PDB of the same name beside it" [expr {
    [::VMDance::Export::frame_files /d/x.dcd dcd] eq {/d/x.dcd /d/x.pdb} && [::VMDance::Export::frame_files /d/x.pdb pdb] eq {/d/x.pdb}}]

# F36, F38 on a full disk (a tmpfs of a namespace of this user's): the PDB
# beside a DCD that does not fit leaves the DCD as it was; a DCD that does
# not fit is said of the file (it was Tcl's name of the channel); a PDB
# export that does not fit is refused (it was renamed into place cut); and
# VMD's writer, cut at its last write unsaid, is caught.
set T [file join $H g4_full]
set P [file join $H g4_private]
file mkdir $T $P
set vmdexe [auto_execok [_env VMD vmd]]
if {![file isfile [file join $::systems 3ptb complex.psf]] || $vmdexe eq "" ||
    [catch {exec unshare -r -m sh -c {mount -t tmpfs -o size=64k tmpfs "$1"} sh $T 2>@1}]} {
    skip "F36, F38: a full disk" "no tmpfs can be mounted here (unshare -r -m), no VMD to run, or no 3ptb"
} else {
    set child [file join $H g4_full.tcl]
    set fh [open $child w]
    puts $fh [string map [list @ROOT@ $::root @T@ $T @P@ $P] {
        source [file join {@ROOT@} tests common.tcl]
        proc say {k v} { puts "G4 $k=<[string map {\n { }} $v]>" }
        proc md5 {f} { lindex [split [exec md5sum $f]] 0 }
        # leave room bytes free on a tmpfs, with a file of its own
        proc fill {d room} {
            set f [file join $d fill]
            file delete $f
            set n [expr {[lindex [exec df -B1 --output=avail $d] end] - $room}]
            set fh [open $f {WRONLY CREAT TRUNC}]
            fconfigure $fh -translation binary
            while {$n > 0} { set k [expr {min($n, 65536)}]; puts -nonewline $fh [string repeat x $k]; incr n -$k }
            catch {close $fh}
        }
        proc kept {T pair} {
            expr {[list [md5 [file join $T x_representatives.dcd]] [md5 [file join $T x_representatives.pdb]]] eq $pair &&
                ![llength [glob -nocomplain -directory $T *.tmp*]]}
        }
        if {[catch {
            package require vmdance
            set ::VMDance::Prefs::file ""
            use_fake
            fake_env
            set T {@T@}
            set P {@P@}
            set m [load_system 3ptb]
            vmdance -mol $m -sel "name CA" -k 3 -kinit KmeansPP -quiet 1
            vmdance export $T -prefix x -items representatives
            set pair [list [md5 [file join $T x_representatives.dcd]] [md5 [file join $T x_representatives.pdb]]]
            vmdance -mol $m -sel "name CA" -k 4 -kinit KmeansPP -quiet 1
            # (4 frames of 3238 atoms: the DCD 156 kB, its PDB 262 kB)
            fill $T 204800
            say pdbfull [err {vmdance export $T -prefix x -items representatives}]
            say pdbfull_kept [kept $T $pair]
            fill $T 40960
            say dcdfull [err {vmdance export $T -prefix x -items representatives}]
            say dcdfull_kept [kept $T $pair]
            fill $T 409600
            say pdbfmt [err {vmdance export $T -prefix x -items representatives -format pdb}]
            say pdbfmt_kept [kept $T $pair]
            # (a frame of 10 atoms fits in the writer's buffer: written at
            # its close, which fails unsaid on the full private folder)
            file delete [file join $T fill]
            set wd0 [::VMDance::Backend::workdir]
            set w [file join $P w]
            file mkdir $w
            file attributes $w -permissions 0700
            set ::VMDance::Backend::workdir $w
            fill $P 0
            say cut [err {vmdance export $T -prefix x -items representatives -format pdb -sel "index 0 to 9"}]
            say cut_kept [kept $T $pair]
            set ::VMDance::Backend::workdir $wd0
        } err]} { say crash $err }
        ::VMDance::Backend::cleanup
        quit
    }]
    close $fh
    catch {exec unshare -r -m sh -c {mount -t tmpfs -o size=2m tmpfs "$1" && mount -t tmpfs -o size=64k tmpfs "$2" && exec "$3" -dispdev text -e "$4" < /dev/null} \
        sh $T $P [lindex $vmdexe 0] $child 2>@1} o
    set G {}
    foreach {- k v} [regexp -all -inline -line {^G4 ([a-z_]+)=<(.*)>$} $o] { dict set G $k $v }
    if {[dict exists $G crash]} { puts "  (the child: [dict get $G crash])" }
    check "F38: a full disk: the PDB beside a DCD does not fit: refused, the DCD there not replaced either, nothing left ([::VMDance::_get $G pdbfull ?])" [expr {
        [string match "*x_representatives.pdb\" could not be written: no space left on device" [::VMDance::_get $G pdbfull ""]] && [::VMDance::_get $G pdbfull_kept 0]}]
    check "  a DCD that does not fit: said of the file, not of Tcl's channel ([::VMDance::_get $G dcdfull ?])" [expr {
        [string match "*x_representatives.dcd\" could not be written: no space left on device" [::VMDance::_get $G dcdfull ""]] && [::VMDance::_get $G dcdfull_kept 0]}]
    check "F36: a full disk: a PDB export that does not fit is refused, the file there kept ([::VMDance::_get $G pdbfmt ?])" [expr {
        [string match "*x_representatives.pdb\" could not be written: no space left on device" [::VMDance::_get $G pdbfmt ""]] && [::VMDance::_get $G pdbfmt_kept 0]}]
    check "  VMD's PDB writer, its last write failing unsaid (the private folder full): caught ([::VMDance::_get $G cut ?])" [expr {
        [string match "*could not be written: VMD could not write frame * (is the disk full?)" [::VMDance::_get $G cut ""]] && [::VMDance::_get $G cut_kept 0]}]
}
file delete -force $T $P
mol delete $mc

# --- g5: the clustered frames and their molecule (F01 F33 F27 F40 F25 F26 F18 F19 F61 F62 N02 F39) ----
# (F27, the window's cursor, is test_gui's)
set G5 [file join $H g5]
file mkdir $G5
set here [pwd]
foreach x [molinfo list] { mol delete $x }
vmdance run clear
use_fake
fake_env
# A folder of two_state as sys.pdb (a frame) and traj.dcd (its 24 frames,
# in reverse order with rev: another trajectory of the same names).
proc g5_system {dir {rev 0}} {
    file mkdir $dir
    set t [mol new [file join $::fixtures two_state.pdb] waitfor all]
    set s [atomselect $t all]
    set n [molinfo $t get numframes]
    if {$rev} {
        set xyz {}
        for {set f 0} {$f < $n} {incr f} { $s frame $f; lappend xyz [$s get {x y z}] }
        for {set f 0} {$f < $n} {incr f} { $s frame $f; $s set {x y z} [lindex $xyz [expr {$n - 1 - $f}]] }
    }
    animate write pdb [file join $dir sys.pdb] beg 0 end 0 $t
    animate write dcd [file join $dir traj.dcd] $t
    $s delete
    mol delete $t
}
# sys.pdb then traj.dcd, by the names given (relative: of VMD's folder),
# the PDB's own frame deleted (drop), as MDANCE's tutorial does.
proc g5_load {pdb dcd {drop 1}} {
    set m [mol new $pdb waitfor all]
    mol addfile $dcd waitfor all molid $m
    if {$drop} { animate delete beg 0 end 0 $m }
    return $m
}
# Every frame of m moved in place rigidly (turned and shifted: an
# alignment), as the RMSD Trajectory Tool does.
proc g5_move {m} {
    set s [atomselect $m all]
    for {set f 0} {$f < [molinfo $m get numframes]} {incr f} {
        $s frame $f
        $s move [transaxis z [expr {7 * $f + 3}]]
        $s moveby [list [expr {0.5 * $f}] -1.5 2.0]
    }
    $s delete
}
# The plugin's representations of a role on m, and the atoms of the first.
proc g5_reps {m role} {
    set n 0
    foreach e $::VMDance::Viz::owned { if {[lindex $e 0] == $m && [lindex $e 2] eq $role} { incr n } }
    return $n
}
proc g5_rep_atoms {m role} {
    foreach e $::VMDance::Viz::owned {
        lassign $e mm name r
        if {$mm != $m || $r ne $role} continue
        set s [atomselect $m [lindex [molinfo $m get "{selection [mol repindex $m $name]}"] 0]]
        set n [$s num]
        $s delete
        return $n
    }
    return -1
}
# VMD's events for a while: a drawing is checked 300 ms after its frames
# stop changing.
proc g5_settle {} {
    set t [expr {[clock milliseconds] + 500}]
    while {[clock milliseconds] < $t} { after 30; update }
}
set A [file join $G5 A]
set B [file join $G5 B]
g5_system $A
g5_system $B 1

# F01: a session finds and loads its molecule by its files in full, and
# checks the frames of every run against it
cd $A
set ma [g5_load sys.pdb traj.dcd]
vmdance -mol $ma -sel all -k 2 -kinit KmeansPP -quiet 1
set g0 [vmdance goto 0]
set p0 [vmdance prime]
set sfa [file join $G5 a.vmdance]
vmdance session save $sfa
cd $here
foreach x [molinfo list] { mol delete $x }
vmdance run clear
cd $B
set mb [g5_load sys.pdb traj.dcd]
set w [lindex [::VMDance::Session::load $sfa auto] 0]
cd $here
set why "*does not have the clustered frames at their numbers*"
check "F01: a session opened onto another trajectory of the same file names (loaded): said, and its frames refused" [expr {
    [dict get [${R}::request] mol] == $mb && [string match $why [join $w]] &&
    [string match $why [err {vmdance goto 0}]] && [string match $why [err {vmdance userfield}]] &&
    [string match $why [err {vmdance export $G5 -prefix x -items representatives}]] &&
    [string match $why [dict get [vmdance draw -reps 1] note]] && [string match "*changed since*" [err {vmdance prime}]]}]
vmdance draw -reps 0
foreach x [molinfo list] { mol delete $x }
cd $B
set w [lindex [::VMDance::Session::load $sfa auto] 0]
cd $here
set m2 [dict get [${R}::request] mol]
check "  nothing loaded, opened in the other's folder: its own files loaded, by their names in full" [expr {
    $m2 >= 0 && [lindex [molinfo $m2 get filename] 0 0] eq [file normalize [file join $A sys.pdb]] && ![catch {vmdance goto 0} r] && $r == $g0}]
# F33: the PDB's own frame, deleted when it was clustered
check "F33: a molecule loaded from its files with the PDB's frame deleted when it was clustered: deleted again, the saved answers ([lindex $w 0])" [expr {
    [string match "*1 frame before the clustered frames*deleted again*" [join $w]] && [molinfo $m2 get numframes] == 24 &&
    ![catch {vmdance prime} r] && $r eq $p0}]
foreach x [molinfo list] { mol delete $x }
set mu [g5_load [file join $A sys.pdb] [file join $A traj.dcd] 0]
set w [lindex [::VMDance::Session::load $sfa auto] 0]
check "  the user's molecule with that frame: left as it was, the warning says which frame to delete" [expr {
    [dict get [${R}::request] mol] == $mu && [molinfo $mu get numframes] == 25 &&
    [string match "*animate delete beg 0 end 0 $mu*" [join $w]] && [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]}]
foreach x [molinfo list] { mol delete $x }
set C [file join $G5 C]
file mkdir $C
file copy [file join $A sys.pdb] [file join $A traj.dcd] $C
file copy $sfa [file join $C a.vmdance]
file rename $A [file join $G5 A_gone]
cd $G5
set w [lindex [::VMDance::Session::load [file join $C a.vmdance] auto] 0]
cd $here
set m3 [dict get [${R}::request] mol]
check "  its files moved with the session (the names it kept gone): loaded from the session's folder" [expr {
    $m3 >= 0 && [lindex [molinfo $m3 get filename] 0 0] eq [file normalize [file join $C sys.pdb]] && ![catch {vmdance goto 0} r] && $r == $g0}]
file rename [file join $G5 A_gone] $A
foreach x [molinfo list] { mol delete $x }
vmdance run clear
# (absolute names; the PDB's frame kept, as many frames as clustered)
set mc [g5_load [file join $A sys.pdb] [file join $A traj.dcd] 0]
vmdance -mol $mc -sel all -k 2 -kinit KmeansPP -quiet 1
set g1 [vmdance goto 0]
set sfc [file join $G5 c.vmdance]
vmdance session save $sfc
foreach x [molinfo list] { mol delete $x }
file copy -force [file join $A traj.dcd] [file join $G5 keep.dcd]
file copy -force [file join $B traj.dcd] [file join $A traj.dcd]
set w [lindex [::VMDance::Session::load $sfc auto] 0]
check "F01: its trajectory written over under its name (as many frames): said, its frames refused" [expr {
    [string match $why [join $w]] && [string match $why [err {vmdance goto 0}]]}]
foreach x [molinfo list] { mol delete $x }
file copy -force [file join $G5 keep.dcd] [file join $A traj.dcd]
set w [lindex [::VMDance::Session::load $sfc auto] 0]
check "  the same coordinates written again: taken" [expr {![llength $w] && ![catch {vmdance goto 0} r] && $r == $g1}]
foreach x [molinfo list] { mol delete $x }
vmdance run clear
set md [g5_load [file join $A sys.pdb] [file join $A traj.dcd] 0]
g5_move $md
vmdance -mol $md -sel all -k 2 -kinit KmeansPP -quiet 1
set g2 [vmdance goto 0]
set sfd [file join $G5 d.vmdance]
vmdance session save $sfd
foreach x [molinfo list] { mol delete $x }
set w [lindex [::VMDance::Session::load $sfd auto] 0]
check "  moved in place (aligned) before it was clustered, opened from its files: its frames taken (each one's shape), PRIME refused" [expr {
    ![llength $w] && ![catch {vmdance goto 0} r] && $r == $g2 && [string match "*changed since*" [err {vmdance prime}]]}]
foreach x [molinfo list] { mol delete $x }
vmdance run clear
# a record's names in full are checked as its names are (N01)
set bd5 [::VMDance::Session::read_file $sfa]
set rec5 [dict get [lindex [dict get $bd5 runs] 0 2] molecule]
# (of a reader that gives the name to a shell: parm7)
set payload [file join $G5 {$(touch MARKER_G5).parm7}]
set fh [open $payload w]; puts $fh "x"; close $fh
write_session [file join $G5 paths.vmdance] [with_molecule $bd5 [dict replace $rec5 paths [list $payload [lindex [dict get $rec5 paths] 1]] \
    types [list parm7 [lindex [dict get $rec5 types] 1]]]]
cd $G5
set w [load_warn [file join $G5 paths.vmdance] load]
cd $here
check "  a record whose names in full hold a shell's character: refused, nothing run" [expr {
    ![file exists [file join $G5 MARKER_G5]] && [string match "*character a shell would act on*" $w]}]
foreach x [molinfo list] { mol delete $x }
vmdance run clear

# F25: vmdance frame
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set c17 [dict get [vmdance frame 17] cluster]
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
set ok1 [expr {![catch {vmdance frame 17} r] && [dict get $r cluster] == $c17}]
animate delete beg 0 end 5 $m
set e [err {vmdance frame 11}]
check "F25: frame, after frames deleted before the clustered ones: refused, as goto is (it gave frame 17's cluster for 11)" [expr {
    $ok1 && [string match "vmdance frame: *no longer has the clustered frames*" $e] && [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]}]
mol delete $m
check "  the molecule deleted: answered in the clustering's own numbers" [expr {[dict get [vmdance frame 17] cluster] == $c17}]

# F26: the drawing when frames change under it
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set n0 [molinfo $m get numreps]
vmdance draw -colour 1 -reps 1
animate goto 10
animate delete beg 0 end 2 $m
animate goto 5
g5_settle
check "F26: frames deleted under the drawing: withdrawn at the next change of frame (colour and representatives were left, at other frames)" [expr {
    ![llength $::VMDance::Viz::owned] && [molinfo $m get numreps] == $n0 &&
    [string match "*no longer has the clustered frames*" [::VMDance::_get [vmdance draw] note ""]]}]
vmdance draw -colour 0 -reps 0
mol delete $m
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance draw -reps 1
animate delete beg 0 end 2 $m
animate goto 3
g5_settle
check "  the representatives alone (no frame was followed): withdrawn too" [expr {![g5_reps $m reps]}]
vmdance draw -reps 0
mol delete $m
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance draw -colour 1 -reps 1
set n1 [llength $::VMDance::Viz::owned]
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
animate goto 3
g5_settle
set ok1 [expr {[llength $::VMDance::Viz::owned] == $n1}]
animate delete beg 0 end 2 $m
check "  frames added after the clustered ones: drawn again; then deleted before them, no frame changed: withdrawn as it is checked (a figure, the window)" [expr {
    $ok1 && ![catch {::VMDance::Viz::check} r] && $r && ![llength $::VMDance::Viz::owned]}]
vmdance draw -colour 0 -reps 0
mol delete $m
# (the answer kept for a count of frames is not taken for that count later:
# asked at 44 while frames are added, not after; the review of g5 found the
# answer kept for the last count asked was)
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
proc g5_ask {name m op} { if {[molinfo $m get numframes] == 44} { catch {::VMDance::Results::frames_ok} } }
trace add variable ::vmd_frame($m) write g5_ask
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
trace remove variable ::vmd_frame($m) write g5_ask
animate delete beg 0 end 3 $m
check "  frames_ok asked as frames were added (at 44), then frames deleted back to that count: refused (it kept the answer of that count)" [expr {
    ![::VMDance::Results::frames_ok] && [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]}]
mol delete $m

# F40: moved in place, then frames added
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
g5_move $m
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
check "F40: moved in place (aligned), then frames added: goto, the user field, the structures and the drawing work (refused, blaming deleted frames)" [expr {
    ![catch {vmdance goto -frame 5}] && ![catch {vmdance userfield}] &&
    ![catch {vmdance export $G5 -prefix f40 -items representatives -format pdb}] && ![dict exists [vmdance draw -colour 1] note]}]
vmdance draw -colour 0
set m2 [load_system two_state]
vmdance -mol $m2 -sel all -k 2 -kinit KmeansPP -quiet 1
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m2
g5_move $m2
${R}::run_switch $::VMDance::Results::current
set ok1 [expr {![catch {vmdance goto -frame 5}]}]
animate delete beg 0 end 2 $m2
check "  frames added, then moved: the same answer, asked again; then frames deleted before them: refused" [expr {
    $ok1 && [string match "*no longer has the clustered frames*" [err {vmdance goto -frame 5}]]}]
foreach x [list $m $m2] { mol delete $x }
set m [load_system two_state]
set s [atomselect $m all]
$s frame 0
set x0 [$s get {x y z}]
for {set f 1} {$f < 24} {incr f} { $s frame $f; $s set {x y z} $x0; $s move [transaxis z [expr {13 * $f}]]; $s moveby [list $f 0 0] }
$s delete
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
animate delete beg 0 end 0 $m
mol addfile [file join $::fixtures two_state.pdb] first 0 last 0 waitfor all molid $m
check "  a rigid body's frames (all of one shape), one deleted before them and one added: still refused" [string match "*no longer has the clustered frames*" [err {vmdance goto -frame 5}]]
mol delete $m

# F18, F19: the picks, on their molecule, while it has their frames
vmdance run clear
set mp [load_system two_state]
vmdance pick -mol $mp -sel all -method outliers -param 4
set pf [vmdance pick show]
set f1 [lindex $pf 1]
set n0 [molinfo $mp get numreps]
set d [vmdance draw -picks 1]
check "F19: picks without a clustering: drawn, on their molecule (nothing was drawn, and no note)" [expr {
    [molinfo $mp get numreps] == $n0 + 1 && ![dict exists $d note]}]
check "  gone to: pick goto ('no clustering')" [expr {![catch {vmdance pick goto $f1} r] && $r == $f1 && [molinfo $mp get frame] == $f1 &&
    [string match "*not a picked frame*" [err {vmdance pick goto 999}]]}]
set mo [load_system outlier]
vmdance -mol $mo -sel all -k 2 -kinit KmeansPP -quiet 1
mol inactive $mp
animate goto 0
set f2 [lindex $pf end]
vmdance draw -picks 1
check "  picks of one molecule, a clustering of another: drawn on theirs; goto moves theirs (inactive), not the clustered one" [expr {
    [g5_reps $mp picks] == 1 && ![catch {vmdance pick goto $f2} r] && $r == $f2 && [molinfo $mp get frame] == $f2 && [molinfo $mo get frame] == 0}]
mol active $mp
mol delete $mo
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $mp
set w5 [file join $G5 picked.pdb]
set ok1 0
if {![catch {vmdance pick save $w5}]} {
    set t [mol new $w5 waitfor all]
    set ok1 [expr {[molinfo $t get numframes] == [llength $pf]}]
    mol delete $t
}
animate delete beg 0 end 1 $mp
vmdance -mol $mp -sel all -k 2 -kinit KmeansPP -quiet 1
set d [vmdance draw -picks 1]
set pwhy "*no longer has the frames the picks were made from*"
check "F18: frames deleted before the picked ones (a clustering made since): not drawn, said; not saved; not gone to (other conformations were)" [expr {
    $ok1 && ![g5_reps $mp picks] && [string match $pwhy [::VMDance::_get $d note ""]] &&
    [string match $pwhy [err {vmdance pick save $w5}]] && [string match $pwhy [err {vmdance pick goto $f1}]]}]
vmdance draw -picks 0
foreach x [molinfo list] { mol delete $x }
vmdance run clear
set mp [load_system two_state]
vmdance -mol $mp -sel all -k 2 -kinit KmeansPP -quiet 1
vmdance pick -mol $mp -sel all -method outliers -param 4
set sfp [file join $G5 p.vmdance]
vmdance session save $sfp
foreach x [molinfo list] { mol delete $x }
set mp [mol new [file join $::fixtures two_state.pdb] first 5 waitfor all]
set w [lindex [::VMDance::Session::load $sfp auto] 0]
check "  a session's picks, on their molecule loaded from frame 5: said, not drawn (it said they were checked)" [expr {
    [lsearch -glob $w "the frame picks: *pick them again"] >= 0 && ![::VMDance::Results::picks_ok]}]
foreach x [molinfo list] { mol delete $x }
vmdance run clear

# F61: the atoms clustered, not those the text selects now
set m [load_system two_state]
set a [atomselect $m all]
$a set beta 0
set a2 [atomselect $m "index 0 to 3"]
$a2 set beta 1
vmdance -mol $m -sel "beta > 0" -k 2 -kinit KmeansPP -quiet 1
set p1 [vmdance prime]
vmdance draw -reps 1
set r0 [g5_rep_atoms $m reps]
vmdance draw -reps 0
$a set beta 1
if {[catch {vmdance prime} p2]} { set p2 "refused: $p2" }
vmdance draw -reps 1
set r1 [g5_rep_atoms $m reps]
vmdance draw -reps 0
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
# (a PDB read again sets every atom's beta from its file)
$a set beta 1
check "F61: the atoms of \"beta > 0\" changed after it was clustered: PRIME, the drawing and the frames' check read those clustered (PRIME refused, other atoms drawn)" [expr {
    $p2 eq $p1 && $r0 == 4 && $r1 == 4 && ![catch {vmdance goto 0}]}]
set i [vmdance -mol $m -sel "beta > 0" -k 2 -kinit KmeansPP -quiet 1]
check "  clustered again: the atoms the text selects now, read as such" [expr {
    [dict get $i natoms] == 8 && [dict get $::VMDance::Coords::C natoms] == 8 && [dict get $::VMDance::Coords::C atoms] eq "index 0 to 7"}]
$a delete; $a2 delete
set bad [dict get $::VMDance::Results::A]
check "  a result's atoms read from a file: checked as data" [expr {
    [string match "*atoms are corrupt*" [err {${R}::check [dict replace $bad request [dict replace [dict get $bad request] atoms "all"]]}]] &&
    [string match "*atoms are corrupt*" [err {${R}::check [dict replace $bad request [dict replace [dict get $bad request] fitatoms "index 0 or name CA"]]}]]}]
mol delete $m

# F62: the kept rows of a molecule deleted
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set o [load_system outlier]
mol delete $o
set ok1 [expr {[dict size $::VMDance::Coords::C] && [llength [leftovers]] == 1}]
mol delete $m
check "F62: the kept rows' molecule deleted: they and their file go at once (they stayed until VMD quit); another's deleted: kept" [expr {
    $ok1 && ![dict size $::VMDance::Coords::C] && ![llength [leftovers]]}]
vmdance run clear

# N02: an imported session, onto the molecule whose coordinates it clustered
set of [file join $::fixtures old_kmeans.mdance]
set d [load_system two_state]
set s [atomselect $d all]
set xyz {}
for {set f 0} {$f < 24} {incr f} { $s frame $f; lappend xyz [$s get {x y z}] }
for {set f 0} {$f < 24} {incr f} { $s frame $f; $s set {x y z} [lindex $xyz [expr {23 - $f}]] }
$s delete
set m [load_system two_state]
set i [vmdance session import $of]
check "N02: an import, two molecules of its name and frames, another's first: onto the one of its coordinates (the first was taken)" [expr {
    [dict get $i molid] == $m && [${R}::labels] eq [dict get [read_text $of] results labels]}]
set r [::VMDance::Job::run import [::VMDance::import_request $of $d]]
check "  -mol the other: taken as asked, with a warning that its cluster MSDs are not the file's" [expr {
    [string match "*do not give the file's cluster MSDs*" [::VMDance::_get $r warnings ""]] && [dict get [dict get $r result] request mol] == $d}]
set t [read_text $of]
set gone [file join $G5 gone.mdance]
set fh [open $gone w]; puts $fh [string map {"molKnown 1 molName two_state.pdb molFrames 24" "molKnown 0"} $t]; close $fh
foreach x [molinfo list] { mol delete $x }
set p [load_system 3ptb]
set m [load_system two_state]
set i [vmdance session import $gone]
set ok1 [expr {[dict get $i molid] == $m}]
mol delete $m
check "  its molecule unknown to the file (deleted before it was saved): onto the one of its coordinates, else refused, naming -mol (3ptb was taken)" [expr {
    $ok1 && [string match "*no molecule loaded has the coordinates it clustered*-mol*" [err {vmdance session import $gone}]]}]
foreach x [molinfo list] { mol delete $x }
set nomsd [file join $G5 nomsd.mdance]
set fh [open $nomsd w]; puts $fh [dict replace $t results [dict remove [dict get $t results] clusterMSD]]; close $fh
load_system two_state
load_system two_state
check "  a file with no cluster MSD, two molecules it may be of: refused, asking for -mol (the first was taken)" [string match "*cannot be told*-mol*" [err {vmdance session import $nomsd}]]
foreach x [molinfo list] { mol delete $x }
vmdance run clear

# F39: the fingerprint's blind spots, and the digests of before
set m [load_system 3ptb]
set req [::VMDance::Job::check_input [list mol $m sel all last 11]]
set c [::VMDance::Coords::extract $req]
set a [atomselect $m "index 100 1109" frame 5]
set xyz [$a get {x y z}]
$a set {x y z} [list [lindex $xyz 1] [lindex $xyz 0]]
set u1 [::VMDance::Coords::unchanged $c]
$a set {x y z} $xyz
$a delete
# (frame 10 mirrored through a plane holding its centre and its weighted centre)
set s [atomselect $m all frame 10]
set keep [$s get {x y z}]
set cc [measure center $s]
set cw [measure center $s weight [::VMDance::Coords::_weights [$s num]]]
set u [vecnorm [vecsub $cw $cc]]
set nv [vecnorm [veccross $u {0 0 1}]]
$s set {x y z} [lmap p $keep {vecsub $p [vecscale [expr {2.0 * [vecdot [vecsub $p $cc] $nv]}] $nv]}]
set u2 [::VMDance::Coords::unchanged $c]
$s set {x y z} $keep
$s delete
check "F39: atoms 1009 apart swapped, or a frame mirrored through its two centres: seen (the kept rows were taken)" [expr {!$u1 && !$u2 &&
    [::VMDance::Coords::unchanged $c]}]
mol delete $m
# (a digest made before: the centre, the radius of gyration and the weighted centre)
proc g5_digest1 {m frames} {
    set s [atomselect $m all]
    set w [::VMDance::Coords::_weights [$s num]]
    set fps [lmap f $frames {$s frame $f; concat [measure center $s] [measure rgyr $s] [measure center $s weight $w]}]
    $s delete
    set d [join $fps]
    format %08x%08x [zlib crc32 $d] [zlib adler32 $d]
}
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set a $::VMDance::Results::A
dict set a digest [g5_digest1 $m [dict get $a frames]]
dict unset a shape
${R}::publish $a old
mol addfile [file join $::fixtures two_state.pdb] waitfor all molid $m
check "  a run of a session made before (its digest without the RMSD): PRIME and its frames still checked against it" [expr {
    ![catch {vmdance prime} r] && [dict size $r] == 7 && ![catch {vmdance goto 0}]}]
animate delete beg 0 end 1 $m
check "  and refused when they are other coordinates" [expr {[string match "*changed since*" [err {vmdance prime}]] &&
    [string match "*no longer has the clustered frames*" [err {vmdance goto 0}]]}]
mol delete $m
vmdance run clear

# --- the final review: scan-empty -------------------------------------------------------------------
# (six frames of four atoms, 0-2 the same, 3-5 near each other elsewhere:
# the fake backend's KMeans at k 3 leaves its middle cluster empty)
foreach x [molinfo list] { mol delete $x }
use_fake
fake_env
set six [file join $H six.pdb]
set fa {{0 0 0} {1.5 0 0} {3 0 0} {4.5 0 0}}
set frs [list $fa $fa $fa]
foreach d {0.0 0.2 0.4} { lappend frs [lmap a $fa {lassign $a x y z; list $x [expr {6 + $d}] [expr {$z + $d / 2}]}] }
set fh [open $six w]
set i 0
foreach fr $frs {
    puts $fh [format "MODEL     %4d" [incr i]]
    set a 0
    foreach xyz $fr {
        incr a
        lassign $xyz x y z
        puts $fh [format "ATOM  %5d  CA  ALA A%4d    %8.3f%8.3f%8.3f  1.00  0.00           C" $a $a $x $y $z]
    }
    puts $fh ENDMDL
}
close $fh
set m6 [mol new $six waitfor all]
# (the k 3 records of the elbow and the sweep; what failed, when none)
proc fr_rows {} {
    catch {list [lindex [vmdance elbow show] 1] [lindex [vmdance sweep show] 1]} r
    return $r
}
vmdance -mol $m6 -sel all -k 3 -kinit KmeansPP -quiet 1
vmdance elbow -mol $m6 -sel all -kinit KmeansPP -ks {2 3} -quiet 1
vmdance sweep -mol $m6 -sel all -algorithms kmeans -ks {2 3} -seedings KmeansPP -quiet 1
set rows0 [fr_rows]
set sf [file join $H scan_empty.vmdance]
vmdance session save $sf
vmdance run clear
set l1 [err {vmdance session load $sf -mol $m6}]
set rows1 [fr_rows]
set sf2 [file join $H scan_empty2.vmdance]
set l2 [err {vmdance session save $sf2}]
vmdance run clear
append l2 [err {vmdance session load $sf2 -mol $m6}]
set rows2 [fr_rows]
check "scan-empty: an elbow and a sweep whose k 3 record has an empty cluster (2 clusters with frames, sizes 3 0 3): saved, opened, saved again and opened again ($l1$l2)" [expr {
    [lsort -unique [lmap r $rows0 {list [dict get $r nclusters] [dict get $r sizes]}]] eq {{2 {3 0 3}}} &&
    $l1 eq "" && $l2 eq "" && $rows1 eq $rows0 && $rows2 eq $rows0}]
# (as a session saved before the records counted the clusters with frames:
# nclusters 3, the backend's k)
set fh [open $sf rb]
set text [encoding convertfrom utf-8 [zlib gunzip [read $fh]]]
close $fh
set nl [string first \n $text]
set d [string range $text [expr {$nl + 1}] end]
foreach k {elbow sweep} {
    set recs [dict get $d $k records]
    lset recs 1 [dict replace [lindex $recs 1] nclusters 3]
    dict set d $k records $recs
}
set sb [file join $H scan_before.vmdance]
set fh [open $sb wb]
puts -nonewline $fh [zlib gzip [encoding convertto utf-8 "[string range $text 0 [expr {$nl - 1}]]\n$d"]]
close $fh
vmdance run clear
set l3 [err {vmdance session load $sb -mol $m6}]
set rows3 [fr_rows]
set l4 [err {vmdance session save $sf2}]
vmdance run clear
append l4 [err {vmdance session load $sf2 -mol $m6}]
set rows4 [fr_rows]
check "  one saved before (nclusters 3, the backend's k): opens counting 2, and saved again by this one opens again ($l3$l4)" [expr {
    $l3 eq "" && $l4 eq "" && $rows3 eq $rows0 && $rows4 eq $rows0}]
# (the record's sizes are its clustering's: one per cluster of it, and no
# more clusters with frames than it has)
set e0 [dict get $d elbow]
set r1 [lindex [dict get $e0 records] 1]
set bad {}
foreach {what r} [list "nclusters 4 of k 3" [dict replace $r1 nclusters 4] "sizes of 2" [dict replace $r1 sizes {3 3}] \
        "sizes of 4" [dict replace $r1 sizes {3 0 3 0}] "no nclusters" [dict replace $r1 nclusters ""]] {
    if {![string match "the elbow's record 2 is corrupt" [err {::VMDance::Session::check_scan [dict replace $e0 records [list [lindex [dict get $e0 records] 0] $r]] elbow}]]} { lappend bad $what }
}
check "  a record whose sizes are not one per cluster of its clustering, or more clusters with frames than it has: refused ($bad)" [expr {
    ![llength $bad] && [err {::VMDance::Session::check_scan $e0 elbow}] eq ""}]
vmdance run clear

# --- the final review: seedless --------------------------------------------------------------------
set lf [file join $H labels6.txt]
set fh [open $lf w]; puts $fh "0\n0\n0\n1\n1\n2"; close $fh
set rows [vmdance sweep -mol $m6 -sel all -algorithms {kmeans helm} -ks {2} -seedings {KmeansPP Random} -params [list helm [list initial-labels $lf]] -quiet 1]
check "seedless: a sweep of HELM from a label file and two seedings: HELM run once a k, its seeding none (it ran once a seeding, each labelled with it)" [expr {
    [lmap r $rows {list [dict get $r algorithm] [dict get $r seeding] [dict get $r status]}] eq {{kmeans KmeansPP ok} {kmeans Random ok} {helm none ok}}}]
vmdance export $H -prefix seedless -items sweep
set srows [lmap r [csv_rows [file join $H seedless_sweep.csv]] {lindex $r 4}]
check "  its table likewise (seeding none)" [expr {$srows eq {seeding KmeansPP Random none}}]
set C ::VMDance::sweep_configs
check "  the grid's configurations: HELM from a file, DIVINE's pair anchors, once a k; NANI's seedings each" [expr {
    [llength [$C {helm} {2 3} {MSD} {StratAll KmeansPP CompSim} [list helm [list initial-labels $lf]]]] == 2 &&
    [llength [$C {helm} {2 3} {MSD} {StratAll KmeansPP CompSim} {}]] == 6 &&
    [llength [$C {divine} {2 3} {MSD} {StratAll KmeansPP} {divine {anchors OutlierPair refine 0}}]] == 2 &&
    [llength [$C {divine} {2 3} {MSD} {StratAll KmeansPP} {divine {anchors NANI}}]] == 4 &&
    [lsort -unique [lmap c [$C {divine} {2 3} {MSD} {StratAll KmeansPP} {divine {anchors SplinterPair}}] {dict exists $c params kinit}]] eq {0}}]
check "  a session's HELM record from a file that names a seeding: none" [expr {
    [::VMDance::Export::sweep_seeding [list algorithm helm params [list initial-labels $lf initial-kinit KmeansPP]]] eq "none" &&
    [::VMDance::Export::sweep_seeding {algorithm helm params {initial-kinit KmeansPP}}] eq "KmeansPP" &&
    [::VMDance::Export::sweep_seeding {algorithm kmeans params {kinit Random}}] eq "Random"}]
check "  counted as made: 1 HELM from a file × 7 seedings × 200 k is 200, not refused as 1400" [expr {
    ![catch {$C {helm} [lrange [lsearch -all [lrepeat 202 x] x] 2 end] {MSD} $::VMDance::Algo::kinits [list helm [list initial-labels $lf]]} cf] &&
    [llength $cf] == 200}]
vmdance run clear

# --- the final review: equal-msd -------------------------------------------------------------------
set A ::VMDance::Algo
check "equal-msd: eQUAL takes MSD only in the table, as DIVINE (the others every metric)" [expr {
    [${A}::metrics_of equal] eq {MSD} && [${A}::metrics_of divine] eq {MSD} && [${A}::metrics_of kmeans] eq $::VMDance::Algo::metrics &&
    [${A}::metric_why equal] ne "" && [${A}::metric_why kmeans] eq ""}]
check "  another metric refused as before, saying why" [string match "-metric SM with eQUAL: *every frame lands in one cluster; use -metric MSD" [err {
    ${A}::check_combination equal 0 [dict replace [${A}::defaults equal] threshold 1] 100 "" SM}]]
set fh [open [file join $::root docs parameters.rst] r]; fconfigure $fh -encoding utf-8; set doc [read $fh]; close $fh
check "  the parameters' page says so (made from the table)" [expr {
    [string first "No ``-k``: the number of clusters follows from the radius. ``-metric``: MSD only" $doc] >= 0}]

# --- the final review: lib-notrun ------------------------------------------------------------------
# (the library as a DIVINE build, whose ::mdance::divine notes the k it is
# called at: the real one would take VMD with it at 3)
set m [load_system two_state]
set L [real_lib]
if {$L eq "" || [catch {::VMDance::Backend::load_lib $L}]} {
    skip "lib-notrun: the library's refusal of DIVINE in a scan" "no CPP-MDANCE library (MDANCE_LIB)"
} else {
    use_fake
    vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3} -seedings KmeansPP -quiet 1
    set sw0 $::VMDance::Results::sweep
    use_lib
    set ::VMDance::Backend::caps([lindex [::VMDance::Backend::current] 1]) [list "" {kmeans divine helm equal}]
    rename ::mdance::divine ::mdance::divine_kept
    proc ::mdance::divine {co nf natoms k args} { lappend ::lib_ks $k; ::mdance::kmeans $co $nf $natoms $k -metric MSD -kinit KmeansPP }
    try {
        set ::lib_ks {}
        set es [err {vmdance sweep -mol $m -sel all -algorithms divine -ks {3 4} -seedings CompSim -quiet 1}]
        set ks1 $::lib_ks
        set sw1 $::VMDance::Results::sweep
        set ::lib_ks {}
        set rows [vmdance sweep -mol $m -sel all -algorithms divine -ks {2 3} -seedings CompSim -quiet 1]
        set ks2 $::lib_ks
        set ::lib_ks {}
        set eb [vmdance elbow -mol $m -sel all -algorithm divine -kinit CompSim -ks {2 3 4} -quiet 1]
        set ks3 $::lib_ks
        set el0 $::VMDance::Results::elbow
        set ee [err {vmdance elbow -mol $m -sel all -algorithm divine -kinit CompSim -ks {3 4} -quiet 1}]
        set el1 $::VMDance::Results::elbow
    } finally {
        rename ::mdance::divine {}
        rename ::mdance::divine_kept ::mdance::divine
        use_fake
    }
    set notrun {apply {{r} {list [dict get $r k] [dict get $r status] [string match "not run: -kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes*" [dict get $r message]]}}}
    check "lib-notrun: a library sweep of DIVINE × CompSim 10% at k 3 and 4 only: refused, uncalled, the sweep there kept ($ks1)" [expr {
        [string match "vmdance sweep: no configuration can be run: -kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes*" $es] &&
        $sw1 eq $sw0 && $ks1 eq {}}]
    check "  at k 2 and 3: k 2 run, k 3 kept as not run, with the library's reason ($ks2)" [expr {
        [lmap r $rows {{*}$notrun $r}] eq {{2 ok 0} {3 error 1}} && $ks2 eq {2}}]
    check "  an elbow scan likewise (k 3 and 4 not run, as HELM's refused k are), and one where none can run refused, the one there kept ($ks3)" [expr {
        [lmap r $eb {{*}$notrun $r}] eq {{2 ok 0} {3 error 1} {4 error 1}} && $ks3 eq {2} &&
        [string match "vmdance elbow: -kinit CompSim with -percentage 10: CPP-MDANCE's DIVINE crashes*" $ee] && $el1 eq $el0}]
}
mol delete $m
mol delete $m6
vmdance run clear

# --- the final review: near ------------------------------------------------------------------------
# (300 mean structures of 24 numbers in three far groups, every 17th
# cluster empty, two the same; frames near their own: the nearest other
# found among those left, against every one)
expr {srand(7)}
set cents {}; set live {}
for {set j 0} {$j < 300} {incr j} {
    if {$j % 17 == 5} { lappend cents {}; lappend live 0; continue }
    if {$j == 101} { lappend cents [lindex $cents 100]; lappend live 1; continue }
    set base [expr {($j % 3) * 10.0}]
    lappend cents [lmap x [lrepeat 24 0] {expr {$base + rand() * 4}}]
    lappend live 1
}
set ix [::VMDance::Measure::_near_index $cents $live]
set bad {}
set n 0
for {set f 0} {$f < 400} {incr f} {
    set l [expr {int(rand() * 300)}]
    if {![lindex $live $l]} continue
    # (some frames are a mean structure itself: distance 0 to it)
    if {$f % 50 == 0} { set r [lindex $cents [expr {$l == 100 ? 101 : $l}]] } else {
        set r [lmap x [lindex $cents $l] {expr {$x + rand() - 0.5}}]
    }
    set want Inf
    for {set j 0} {$j < 300} {incr j} {
        if {$j == $l || ![lindex $live $j]} continue
        set d [veclength [vecsub $r [lindex $cents $j]]]
        if {$d < $want} { set want $d }
    }
    set got [::VMDance::Measure::_near_other $ix $r $l]
    if {$got != $want} { lappend bad "$l: $got, not $want" }
    incr n
}
check "near: a frame's nearest other mean structure among 283 live, as against every one, bit for bit ($n frames; [lrange $bad 0 2])" [expr {
    $n > 300 && ![llength $bad]}]
# (fewer different structures than groups: 80 the same, and one other)
set same [lrepeat 80 [lrepeat 24 1.0]]
lappend same [lrepeat 24 2.0]
set ix [::VMDance::Measure::_near_index $same [lrepeat 81 1]]
check "  80 mean structures the same and one other: grouped, the nearest other 0, or the other's distance" [expr {
    [::VMDance::Measure::_near_other $ix [lrepeat 24 1.0] 0] == 0 &&
    [::VMDance::Measure::_near_other $ix [lrepeat 24 2.0] 80] == [veclength [lrepeat 24 1.0]]}]
# (a clustering's measures so, and by every cluster: the same)
foreach x [molinfo list] { mol delete $x }
use_fake
fake_env
set m [load_system two_state]
vmdance -mol $m -sel all -k 16 -kinit KmeansPP -quiet 1
set a $::VMDance::Results::A
set c $::VMDance::Coords::C
set near0 $::VMDance::Measure::near_min
set ::VMDance::Measure::near_min 1000000000
set every [::VMDance::Measure::compute $c [dict get $a labels] [dict get $a nclusters] [dict get $a representatives] [dict get $a natoms]]
set ::VMDance::Measure::near_min 2
set pruned [::VMDance::Measure::compute $c [dict get $a labels] [dict get $a nclusters] [dict get $a representatives] [dict get $a natoms]]
set ::VMDance::Measure::near_min $near0
check "  a clustering's measures with it ([llength [lsort -unique [dict get $a labels]]] clusters), and with every cluster: the same" [expr {
    $pruned eq $every && $every eq [dict get $a measures] && [llength [lsearch -all -not -exact [dict get $every silhouette] ""]] > 0}]
mol delete $m
vmdance run clear

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
