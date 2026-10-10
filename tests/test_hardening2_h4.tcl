# What the second round of reviews found in the exports, the figures and
# the stated requirements (h4), each kept from coming back (text mode, the
# fake backend):
#   N14  a structure export into a folder that cannot be written says why
#        (VMD's animate write failed with no message: "vmdance export: ";
#        the files' hardening, 626ee7e, made Tcl write them: kept here)
#   N15  VMD takes a file name's UTF-8 bytes, Tcl the system encoding's
#        (iso8859-1 with LANG=C): with a TMPDIR whose name is not ASCII,
#        VMD could not write into the private folder, and every structure
#        export failed ("is the disk full?"); VMD is given its name of the
#        file (Backend::vmd_name). A folder outside ASCII as the
#        destination is written by Tcl, a DCD with its PDB.
#        Its review: such a TMPDIR was passed over for /tmp, unchecked, and
#        where /tmp could not be written every clustering was refused, told
#        to set the TMPDIR it had (now kept; one whose name is not UTF-8 is
#        passed over, and the error says so and what to change: a VMD run
#        with /tmp read-only in a namespace of the user's, unshare -r -m,
#        skipped where it cannot be mounted); a session's molecule in a
#        folder outside ASCII was "not a readable file" with LANG=C (Tcl
#        looked for another file: it is loaded)
#   N17  the distances and tree exports called the RMSD² between mean
#        structures "MSD", which is MDANCE's, half of it; the tables with
#        msd_to_representative say it is an RMSD²
#   N26  the docs said VMD 1.9.4 or later, whose Linux alphas have Tcl 8.5
#        and cannot load the plugin: the requirement is Tcl 8.6, and a VMD
#        without it is told so by name (its review: the decks themselves,
#        .pptx, still said it: their slides and notes are read too)
# (N25, figures -3d with a renderer that writes no image, is test_gui's.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_h4.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_h4]
file delete -force $H
file mkdir $H

# The number of models in a PDB VMD wrote (each ends with END).
proc pdb_models {f} { llength [regexp -all -inline -line {^END\s*$} [read_text $f]] }
# The text of the members of a zip file (a deck) whose names match pat,
# found by its central directory, each stored or deflated. (Read with
# binary scan: the file's bytes are never made a string.)
proc zip_text {f pat} {
    set fh [open $f rb]
    set z [read $fh]
    close $fh
    # (the end of the central directory, in the last 64 KB: its count and offset)
    set k [expr {max(0, [string length $z] - 65558)}]
    binary scan $z @${k}a* tail
    set e [expr {$k + [string last [binary format H8 504b0506] $tail]}]
    binary scan $z @[expr {$e + 10}]su@[expr {$e + 16}]iu n p
    set out ""
    for {set i 0} {$i < $n} {incr i} {
        binary scan $z @${p}x10sux8iux4sususux8iu method size nl xl cl off
        binary scan $z @[expr {$p + 46}]a$nl name
        incr p [expr {46 + $nl + $xl + $cl}]
        if {![string match $pat $name]} continue
        binary scan $z @[expr {$off + 26}]susu nl xl
        binary scan $z @[expr {$off + 30 + $nl + $xl}]a$size data
        if {$method == 8} { set data [zlib inflate $data] }
        append out [encoding convertfrom utf-8 $data]
    }
    return $out
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set B ::VMDance::Backend
use_fake
fake_env

set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1

# --- N14: a folder that cannot be written --------------------------------------------------
if {[${B}::_uid] eq "0"} {
    skip "N14: an export into a read-only folder" "root writes into any folder"
} else {
    set ro [file join $H readonly]
    file mkdir $ro
    file attributes $ro -permissions 0555
    set mols [molinfo list]
    set top [molinfo top]
    set es {}
    foreach {it fmt} {representatives pdb trajectories pdb representatives dcd trajectories dcd} {
        lappend es [err {vmdance export $ro -prefix p -items $it -format $fmt}]
    }
    lappend es [err {::VMDance::Export::write_frames $m all {0 1} [file join $ro picked.pdb] pdb}]
    file attributes $ro -permissions 0755
    set bad [lsearch -all -inline -not $es "*could not be written: permission denied"]
    check "N14: structures into a folder that cannot be written (PDB, DCD, the picks' Save): said, file and reason" [expr {
        ![llength $bad] && [llength $es] == 5}]
    check "  nothing written there, no molecule made, the top one kept" [expr {
        ![llength [glob -nocomplain -directory $ro *]] && [molinfo list] eq $mols && [molinfo top] == $top}]
}

# --- N15: names outside ASCII with a locale that is not UTF-8 -------------------------------
set enc [encoding system]
set env0 {}
foreach v {TMPDIR TEMP TMP} { if {[info exists ::env($v)]} { dict set env0 $v $::env($v) } }
set wd0 [set ${B}::workdir]
set wd1 ""
set wd2 ""
encoding system iso8859-1
try {
    # (names as Tcl reads them from disk with LANG=C: their UTF-8 bytes,
    # each byte a character; lat's is not UTF-8: é as one byte)
    set tmp [file join $H [encoding convertfrom iso8859-1 [encoding convertto utf-8 "tmp_ü"]]]
    set dest [file join $H [encoding convertfrom iso8859-1 [encoding convertto utf-8 "déjà"]]]
    set lat [file join $H "lat_[format %c 233]"]
    file mkdir $tmp $dest $lat
    check "N15: VMD's name of a file with LANG=C: the characters of its UTF-8 bytes, the same in ASCII, none for a name not in UTF-8; Tcl's name of VMD's the other way" [expr {
        [${B}::vmd_name $tmp] eq [file join $H "tmp_ü"] && [${B}::vmd_name [file join $H plain]] eq [file join $H plain] &&
        [${B}::vmd_name $lat] eq "" && [${B}::tcl_name [file join $H "tmp_ü"]] eq $tmp && [${B}::tcl_name [file join $H plain]] eq [file join $H plain]}]
    foreach v {TMPDIR TEMP TMP} { unset -nocomplain ::env($v) }
    set ::env(TMPDIR) $tmp
    # (a new private folder: the clustering's coordinates stay in the old one)
    set ${B}::workdir ""
    set es {}
    foreach d [list [file join $H ascii] $dest] {
        foreach {it fmt} {representatives pdb trajectories pdb representatives dcd trajectories dcd} {
            lappend es [err {vmdance export $d -prefix $fmt -items $it -format $fmt}]
        }
    }
    set wd1 [set ${B}::workdir]
    set made [lsort [glob -nocomplain -tails -directory $dest *]]
    # (it was passed over for /tmp, which the private folder then needed)
    check "  a TMPDIR whose name is not ASCII: kept, VMD writing its frames there, the structures exported (PDB, DCD), into an ASCII folder or one outside ASCII" [expr {
        [lsort -unique $es] eq {{}} && [string match $tmp/vmdance-* $wd1] && ![llength [set ${B}::passed]] &&
        ![llength [glob -nocomplain -directory $wd1 *]]}]
    check "  each DCD with its PDB, every frame written" [expr {
        $made eq {dcd_cluster_0.dcd dcd_cluster_0.pdb dcd_cluster_1.dcd dcd_cluster_1.pdb dcd_representatives.dcd dcd_representatives.pdb pdb_cluster_0.pdb pdb_cluster_1.pdb pdb_representatives.pdb} &&
        [pdb_models [file join $dest pdb_representatives.pdb]] == 2 && [pdb_models [file join $dest dcd_representatives.pdb]] == 1 &&
        [pdb_models [file join $dest pdb_cluster_0.pdb]] + [pdb_models [file join $dest pdb_cluster_1.pdb]] == 24}]
    # (one whose name is not UTF-8: VMD can name no file there)
    set ::env(TMPDIR) $lat
    set ${B}::workdir ""
    set e [err {vmdance export [file join $H lat_out] -prefix p -items representatives -format pdb}]
    set wd2 [set ${B}::workdir]
    check "  a TMPDIR whose name is not UTF-8: passed over (kept for the error), the structures exported all the same" [expr {
        $e eq "" && $wd2 ne "" && ![string match $lat/* $wd2] && [${B}::vmd_name $wd2] ne "" &&
        [set ${B}::passed] eq [list "TMPDIR \"$lat\""] && [pdb_models [file join $H lat_out p_representatives.pdb]] == 2}]
} finally {
    encoding system $enc
    foreach v {TMPDIR TEMP TMP} { unset -nocomplain ::env($v) }
    dict for {v x} $env0 { set ::env($v) $x }
    foreach w [list $wd1 $wd2] { if {$w ne "" && $w ne $wd0} { file delete -force $w } }
    set ${B}::workdir $wd0
}
# The review's case: with LANG=C and /tmp read-only (a namespace of the
# user's), a TMPDIR outside ASCII clusters and exports (it was passed over
# for /tmp: "no private folder could be made under /tmp ... set TMPDIR to a
# folder of yours"); one whose name is not UTF-8 is passed over, and the
# error names it and what to change. (The child's script is ASCII: it is
# read with LANG=C.)
set vmdexe [auto_execok [_env VMD vmd]]
if {![llength $vmdexe] || [catch {exec unshare -r -m sh -c {mount --bind "$1" "$1" && mount --rbind /tmp /tmp && mount -o remount,bind,ro /tmp} sh $H 2>@1}]} {
    skip "N15: with /tmp read-only, a TMPDIR outside ASCII" "/tmp cannot be made read-only here (unshare -r -m), or no VMD to run"
} else {
    set child [file join $H ro_tmp.tcl]
    set fh [open $child w]
    puts $fh [string map [list @ROOT@ $::root @H@ $H] {
        source [file join {@ROOT@} tests common.tcl]
        proc say {k v} { puts "H4 $k=<[join [split $v [format %c 10]] { }]>" }
        if {[catch {
            package require vmdance
            set ::VMDance::Prefs::file ""
            use_fake
            set B ::VMDance::Backend
            say enc [encoding system]
            foreach v {TMPDIR TEMP TMP} { unset -nocomplain ::env($v) }
            # (the parent's tmp: its name's UTF-8 bytes, as Tcl reads them with LANG=C)
            set ::env(TMPDIR) [file join {@H@} "tmp_[format %c%c 195 188]"]
            set m [load_system two_state]
            if {[catch {vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1} e]} { say cluster 1$e } else { say cluster 0 }
            say kept [string match $::env(TMPDIR)/vmdance-* [set ${B}::workdir]]
            say export [catch {vmdance export [file join {@H@} ro_out] -prefix p -items {representatives trajectories} -format pdb} e]$e
            ${B}::cleanup
            set ::env(TMPDIR) [file join {@H@} "lat_[format %c 233]"]
            say lat [catch {${B}::workdir} e]$e
        } err]} { say crash $err }
        quit
    }]
    close $fh
    catch {exec unshare -r -m sh -c {mount --bind "$1" "$1" && mount --rbind /tmp /tmp && mount -o remount,bind,ro /tmp &&
        exec env -u LC_ALL -u LC_CTYPE -u LANGUAGE LANG=C "$2" -dispdev text -e "$3" < /dev/null} sh $H [lindex $vmdexe 0] $child 2>@1} o
    set G {}
    foreach {- k v} [regexp -all -inline -line {^H4 ([a-z]+)=<(.*)>$} $o] { dict set G $k $v }
    if {[dict exists $G crash]} { puts "  (the child: [dict get $G crash])" }
    check "N15, its review: with LANG=C and /tmp read-only, a TMPDIR outside ASCII: a clustering in it, the structures exported ([::VMDance::_get $G cluster ?] [::VMDance::_get $G kept ?] [::VMDance::_get $G export ?])" [expr {
        [::VMDance::_get $G enc ""] eq "iso8859-1" && [::VMDance::_get $G cluster ""] eq "0" && [::VMDance::_get $G kept ""] eq "1" && [::VMDance::_get $G export ""] ne "" &&
        [string index [::VMDance::_get $G export ""] 0] eq "0" &&
        [pdb_models [file join $H ro_out p_representatives.pdb]] == 2 &&
        [pdb_models [file join $H ro_out p_cluster_0.pdb]] + [pdb_models [file join $H ro_out p_cluster_1.pdb]] == 24}]
    check "  one whose name is not UTF-8: the error says it was passed over, why, and what to change ([::VMDance::_get $G lat ?])" [string match \
        "1no private folder could be made under /tmp (*read-only file system; TMPDIR \"*/lat_*\" passed over: with this locale (iso8859-1) VMD cannot open a file there by its name): set TMPDIR to a folder of yours whose name is ASCII, or use a UTF-8 locale (LANG=C.UTF-8)" \
        [::VMDance::_get $G lat ""]]
}

# --- N17: RMSD² said of the RMSD² --------------------------------------------------------------
set files [vmdance export $H -prefix n17 -items {clusters top timeline distances tree}]
proc first_line {f} { lindex [split [read_text $f] \n] 0 }
set hd [first_line [file join $H n17_distances.csv]]
set ht [first_line [file join $H n17_tree.csv]]
check "N17: the distances and the tree say RMSD² of the mean structures, not MSD (MDANCE's is half of it)" [expr {
    [string match "*mean structures (RMSD², Å²*" $hd] && [string match "*distance: their RMSD², Å²*" $ht] &&
    ![string match "*MSD, Å²*" $hd] && ![string match "*distance: MSD*" $ht]}]
check "  the clusters, the top frames and the timeline: msd MDANCE's, msd_to_representative an RMSD²" [expr {
    [string match "*msd: MDANCE's MSD within*msd_to_representative: the mean RMSD²*" [first_line [file join $H n17_clusters.csv]]] &&
    [string match "*msd_to_representative: RMSD², Å²*" [first_line [file join $H n17_top_frames.csv]]] &&
    [string match "*msd_to_representative: RMSD², Å²*" [first_line [file join $H n17_timeline.csv]]]}]
# (the number the header names: the RMSD² between the two mean structures,
# from VMD's coordinates, twice MDANCE's MSD of the pair)
set s [atomselect $m all]
set n [$s num]
set means {}
for {set c 0} {$c < 2} {incr c} {
    set sum [lrepeat $n {0 0 0}]
    set fl [${R}::member_frames $c]
    foreach f $fl {
        $s frame $f
        set sum [lmap a $sum b [$s get {x y z}] {vecadd $a $b}]
    }
    lappend means [lmap a $sum {vecscale [expr {1.0 / [llength $fl]}] $a}]
}
$s delete
set d2 [expr {[::tcl::mathop::+ {*}[lmap a [lindex $means 0] b [lindex $means 1] {expr {[veclength2 [vecsub $a $b]]}}]] / double($n)}]
set tree [lindex [csv_rows [file join $H n17_tree.csv]] 1]
set dist [lsearch -inline -index 0 [lsearch -all -inline -index 1 [lrange [csv_rows [file join $H n17_distances.csv]] 1 end] 1] 0]
check "  and it is the RMSD² of the mean structures (Å², no fit), twice MDANCE's MSD of them" [expr {
    $d2 > 0 && [near [lindex $tree 2] $d2 1e-5] && [near [lindex $dist 2] $d2 1e-5]}]
mol delete $m
vmdance run clear

# --- N15, its review: a session's molecule in a folder outside ASCII, opened with LANG=C ----------
# (saved with a UTF-8 locale, the session names the molecule's file by its
# characters, which Tcl took for another file with LANG=C: "not a readable
# file"; VMD opens it by them)
set sd [file join $H "séance"]
file mkdir $sd
file copy [file join $::fixtures two_state.pdb] [file join $sd mol.pdb]
set m [mol new [file join $sd mol.pdb] waitfor all]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set sf [file join $H n15.vmdance]
vmdance session save $sf
mol delete $m
vmdance run clear
set enc [encoding system]
encoding system iso8859-1
try {
    set w1 [lindex [::VMDance::Session::load $sf load] 0]
    set mols1 [molinfo list]
    set m1 [dict get [${R}::request] mol]
    set w2 [lindex [::VMDance::Session::load $sf auto] 0]
    set mols2 [molinfo list]
    set m2 [dict get [${R}::request] mol]
    # (one VMD can name no file of: a name not in UTF-8)
    set lat [file join $H "lat_[format %c 233]"]
    file copy -force [file join $::fixtures two_state.pdb] [file join $lat mol.pdb]
    set why [::VMDance::Session::_unloadable [list [file join $lat mol.pdb]] pdb]
} finally {
    encoding system $enc
}
check "N15, its review: with LANG=C, a session's molecule in a folder outside ASCII is loaded, the run on it ([join $w1 { }])" [expr {
    $w1 eq {} && [llength $mols1] == 1 && $m1 == [lindex $mols1 0] &&
    [lindex [molinfo $m1 get filename] 0] eq [list [file join $sd mol.pdb]] && [molinfo $m1 get numatoms] == 8}]
check "  and found loaded (-mol auto: no other molecule)" [expr {$w2 eq {} && $mols2 eq $mols1 && $m2 == $m1}]
check "  one VMD can name no file of: said, with what to change ($why)" [string equal $why \
    "with this locale (iso8859-1) VMD cannot open \"mol.pdb\" by its name: use a UTF-8 locale (LANG=C.UTF-8)"]
foreach x [molinfo list] { mol delete $x }
vmdance run clear

# --- N26: the requirement ----------------------------------------------------------------------
set stale {}
# (the papers and decks are kept beside the repository: read where they are)
foreach f [list README.md docs/install.rst TESTING.md {*}[lsort [glob -nocomplain -tails -directory $::root manuscripts/*/manuscript.tex]] presentation/make_guide.js presentation/make_deck.js] {
    if {![file isfile [file join $::root $f]]} continue
    if {[regexp {1\.9\.4 or later} [read_text [file join $::root $f]]]} { lappend stale $f }
}
# (the decks as they are shipped, not only their scripts: every slide and note)
set decks {}
foreach f {presentation/VMDance.pptx presentation/VMDance_guide.pptx} {
    if {![file isfile [file join $::root $f]]} continue
    dict set decks $f [zip_text [file join $::root $f] ppt/*.xml]
    if {[regexp {1\.9\.4 or later} [dict get $decks $f]]} { lappend stale $f }
}
check "N26: no document or deck says VMD 1.9.4 or later (its Linux alphas have Tcl 8.5) $stale" [expr {![llength $stale]}]
if {[dict size $decks] < 2} {
    skip "  the decks say Tcl/Tk 8.6" "the decks are not beside the repository here"
} else {
    check "  the decks say Tcl/Tk 8.6 (the guide's slide, the talk's note: read)" [expr {
        [string match "*Built with Tcl/Tk 8.6, as VMD 2 is.*" [dict get $decks presentation/VMDance_guide.pptx]] &&
        [string match "*Needs a VMD built with Tcl/Tk 8.6, as VMD 2 is*" [dict get $decks presentation/VMDance.pptx]]}]
}
check "  the install docs say Tcl/Tk 8.6" [expr {
    [string match "*needs a VMD built with Tcl/Tk 8.6*" [read_text [file join $::root README.md]]] &&
    [string match "*needs a VMD built with Tcl/Tk 8.6*" [read_text [file join $::root docs install.rst]]]}]
# (a Tcl 8.5 is an interpreter whose info patchlevel says so)
set i [interp create]
$i eval {
    rename info _info
    proc info {args} { if {$args eq "patchlevel"} { return 8.5.6 }; uplevel 1 [list _info {*}$args] }
}
set e [catch {$i eval [list source -encoding utf-8 [file join $::root vmdance vmdance.tcl]]} msg]
interp delete $i
check "  a VMD with Tcl 8.5 is told the plugin needs Tcl 8.6 (not only Tcl's version conflict)" [expr {
    $e && [string match "VMDance needs a VMD with Tcl 8.6*this one has Tcl 8.5.6*" $msg]}]

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_h4 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
