# What the second round of reviews found in the command, the docs and the
# decks (g8), each kept from coming back (text mode, the fake backend; the
# real one for the docs' numbers):
#   F58  an option given twice is refused by prime, similarity, draw and
#        backend (the last was kept, the first never checked); select's
#        clear and all take nothing more ("clear 1" emptied the selection);
#        elbow refuses -k (it was dropped for -ks, never checked)
#   F59  goto -frame without its frame (read as cluster "-frame"), userfield
#        with a selection of no atom (it said it wrote the frames), export's
#        -top and -lag with their ranges ("1 or more" of 1000000); figures
#        -plots {} -3d 1 (the 3D view alone) is test_gui's
#   F54  draw -sel is checked on the clustered or the top molecule while no
#        clustering is drawn (a typo was kept, then drawn as other atoms
#        without a word); what is drawn otherwise than asked is said; a
#        session that saved such a -sel or -frames loses it alone on load
#   F55  a quoted value is no keyword: chain "x", segname 'y' cluster; a
#        selection that changes with the frame is still refused
#   F17  sweep load reads its index as a person writes it (010 loaded 8);
#        the window's exports of a lag and of the nearest frames too; the
#        window's lag (figures -options, a session) is test_gui's
#   F60  the parameters page says "(needed)" only of what the checker refuses
#        empty (HELM's label file is optional), and is the generator's output
#   F76  README's and the quick start's scripts delete the PDB's own frame;
#        README's quoted run is what the command prints on MDANCE's data
#   F77  the guide's tau numbers are those of the trajectory it names
#   F78  figures in text mode says it needs a display and how to make them,
#        not "use the command"
# and what the review of these fixes found:
#   R1   the shipped decks are their generators' output: the guide's tau
#        numbers and the figures' display (they were not made again); the
#        guide's tau pictures are of the trajectory it names (they were of
#        the reference runs' copy, which clusters otherwise)
#   R2   a session loaded without the window keeps for it no drawing (drawn
#        already; the window drew it again when it opened, over later draws);
#        with the window open (test_gui), its refused -sel or -frames alone
#        is left out, and what a clustering draws otherwise is said there
#   R3   sweep -params refuses a name given twice, and a seeding (-seedings
#        replaced it, unchecked); figures -options likewise (test_gui)
#   R4   Mol::dynamic knows nearest and pucker, and reads a macro's words
#   R5   a session's lag kept as typed (" 5") is read (test_gui)
# (F76, F77: MDANCE's packaged data, $MDANCE_DATA or a manuscripts' .venv,
# and the real mdance-cli; skipped without them. R1 and F77's guide: the
# decks and papers, kept beside the repository; skipped where they are not.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_g8.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_g8]
file delete -force $H
file mkdir $H

# MDANCE's packaged data (mdance/data: the tau peptide), or "".
proc mdance_data {} {
    set c [list [_env MDANCE_DATA ""]]
    foreach r [list $::root [file join $::root .. VMDance]] {
        lappend c {*}[glob -nocomplain [file join $r manuscripts .venv lib python* site-packages mdance data]]
    }
    foreach d $c { if {$d ne "" && [file isfile [file join $d aligned_original_tau_6K.dcd]]} { return [file normalize $d] } }
    return ""
}
# Whether the atoms of a selection text change with every atom's x and
# user field at frame 0 (VMD's own answer to Mol::dynamic's): all at +1000
# and 5, then at -1000 and 0 (the values saved and set back).
proc sel_moves {m text} {
    set all [atomselect $m all frame 0]
    set keep [$all get {x user}]
    set s [atomselect $m $text frame 0]
    set n [$all num]
    $all set x [lrepeat $n 1000]; $all set user [lrepeat $n 5]
    $s update
    set one [$s list]
    $all set x [lrepeat $n -1000]; $all set user [lrepeat $n 0]
    $s update
    set two [$s list]
    $all set {x user} $keep
    $s delete; $all delete
    expr {$one ne $two}
}
# The text of a deck's slides and notes (unzip's), its XML's tags and
# entities undone; "" without unzip.
proc deck_text {f} {
    if {[catch {exec unzip -p $f ppt/slides/*.xml ppt/notesSlides/*.xml} x]} { return "" }
    regsub -all {<[^>]+>} $x "" x
    string map {&amp; & &lt; < &gt; > &quot; \" &apos; '} $x
}
# Whether a deck holds a picture, byte for byte, among its media.
proc deck_has {f png} {
    set fh [open $png rb]
    set want [read $fh]
    close $fh
    if {[catch {exec unzip -Z1 $f} names]} { return 0 }
    foreach n [split $names \n] {
        if {![string match ppt/media/* $n]} continue
        set ch [open |[list unzip -p $f $n] rb]
        set got [read $ch]
        close $ch
        if {$got eq $want} { return 1 }
    }
    return 0
}
# The lines of README's scripting block.
proc readme_block {} {
    set t [read_text [file join $::root README.md]]
    set i [string first "```tcl\n" $t [string first "## Scripting" $t]]
    set j [string first "\n```" $t [expr {$i + 7}]]
    if {$i < 0 || $j < 0} { return {} }
    split [string range $t [expr {$i + 7}] [expr {$j - 1}]] \n
}

if {[catch {
package require vmdance
set R ::VMDance::Results
set A ::VMDance::Algo
set ::VMDance::Prefs::file ""
use_fake
fake_env
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1

# --- F58: an option is given once ---------------------------------------------------------------
check "F58 prime: an option given twice is refused, not the last kept" [expr {
    [string match "*-metric is given twice*" [err {vmdance prime -metric RR -metric SM}]] &&
    [string match "*-metric is given twice*" [err {vmdance prime -metric BOGUS -metric RR}]] &&
    [string match "*-trim-frac is given twice*" [err {vmdance prime -trim-frac 5 -trim-frac 0.2}]] &&
    ![dict size [${R}::extra prime]]}]
check "  similarity too" [expr {[string match "*-metric is given twice*" [err {vmdance similarity -metric nonsense -metric MSD}]] &&
    ![dict size [${R}::extra similarity]]}]
set v0 [::VMDance::Viz::get]
check "  draw too, and nothing changes" [expr {[string match "vmdance draw: -colour is given twice" [err {vmdance draw -colour 1 -colour 0}]] &&
    [string match "*-top is given twice*" [err {vmdance draw -top 5 -top 7}]] && [::VMDance::Viz::get] eq $v0}]
set b0 [::VMDance::Backend::settings]
check "  backend and backend try too, and the backend is kept" [expr {
    [string match "vmdance backend: -mode is given twice" [err {vmdance backend -mode cli -mode auto}]] &&
    [string match "*-cli is given twice*" [err {vmdance backend try -cli $::fake -cli /bin/true}]] &&
    [::VMDance::Backend::settings] eq $b0}]
check "  (once each is taken)" [expr {![catch {vmdance draw -colour 0 -top 10}] && ![catch {vmdance backend {*}$b0}]}]
vmdance select 0 1
check "F58 select clear 1 and select all junk: refused, the selection kept (clear emptied it)" [expr {
    [string match "usage: vmdance select*" [err {vmdance select clear 1}]] &&
    [string match "usage: vmdance select*" [err {vmdance select all junk}]] && [${R}::selected] eq {0 1}}]
check "  clear and all alone still work" [expr {[vmdance select clear] eq {} && [vmdance select all] eq {0 1}}]
vmdance select clear
set e0 $::VMDance::Results::elbow
check "F58 elbow -k: refused, naming -ks (it was dropped unchecked: -k bogus ran)" [expr {
    [string match "vmdance elbow: -k: *-ks*-from -to -by*" [err {vmdance elbow -mol $m -sel all -kinit KmeansPP -ks {2 3} -k 9}]] &&
    [string match "*-k:*" [err {vmdance elbow -mol $m -sel all -kinit KmeansPP -from 2 -to 3 -k bogus}]] &&
    $::VMDance::Results::elbow eq $e0}]
check "  an elbow without -k still runs" [expr {[llength [vmdance elbow -mol $m -sel all -kinit KmeansPP -ks {2 3} -quiet 1]] == 2}]

# --- F59: answers that say what happened ----------------------------------------------------------
check "F59 goto -frame without its frame: the usage (not 'no cluster \"-frame\"')" [string match "usage: vmdance goto*" [err {vmdance goto -frame}]]
check "  goto -frame f still goes there" [expr {[vmdance goto -frame 5] == 5}]
set s [atomselect $m all frame 3]
$s set user 7
check "F59 userfield -sel none: refused, nothing written (it answered 24 frames written)" [expr {
    [string match "vmdance userfield: -sel: \"none\" matches no atom of molecule $m" [err {vmdance userfield -sel none}]] &&
    [string match "*matches no atom*" [err {vmdance userfield -sel {resname XYZ}}]] && [lsort -unique [$s get user]] eq {7.0}}]
check "  a selection of atoms: written" [expr {[vmdance userfield -sel {index 0 1}] == 24 && [lsort -unique [$s get user]] ne {7.0}}]
$s delete
check "  no atom selection left behind" [expr {[llength [atomselect list]] == 0}]
check "F59 export -top and -lag: their ranges said (1000000 was told '1 or more')" [expr {
    [string match "*-top must be a whole number from 1 to 999999 (got \"1000000\")" [err {vmdance export $H -items top -top 1000000}]] &&
    [string match "*-lag must be a whole number from 1 to 999999999 (got \"1000000000\")" [err {vmdance export $H -items transitions -lag 1000000000}]] &&
    [string match "*-top must be a whole number from 1 to 999999 (got \"010\")" [err {vmdance export $H -items top -top 010}]] &&
    ![llength [glob -nocomplain -directory $H *]]}]
check "  within them: written" [expr {[llength [vmdance export $H -items {top transitions} -top 999999 -lag 3]] == 2}]

# --- F17: numbers as a person writes them ---------------------------------------------------------
set rows [vmdance sweep -mol $m -sel all -algorithms kmeans -ks {2 3 4 5 6 7 8 9 10 11 12 13} -seedings KmeansPP -quiet 1]
set runs0 [llength [vmdance runs]]
set bad {}
foreach i {010 0x3 { 3} {3 } +3 0o10 -0 3.0} { if {![string match "*no configuration*" [err {vmdance sweep load $i}]]} { lappend bad $i } }
check "F17 sweep load 010, 0x3, ' 3', +3, 0o10: refused (010 published configuration 8) [join $bad]" [expr {
    ![llength $bad] && [llength [vmdance runs]] == $runs0}]
check "  sweep load 10: configuration 10" [expr {[dict get [vmdance sweep load 10] k] == [dict get [lindex $rows 10] k] &&
    [dict get [lindex $rows 10] k] == 12}]
check "F17 the exports' lag and nearest frames as typed in the window: 010 refused (lag 8 was written as '010 later')" [expr {
    [string match "*lag must be a whole number*" [err {::VMDance::Export::table_transitions 010}]] &&
    [string match "*nearest frames must be a whole number*" [err {::VMDance::Export::table_top 010}]] &&
    [string match "*one 8 later*" [::VMDance::Export::table_transitions 8]] && [string match "*the 3 frames*" [::VMDance::Export::table_top 3]]}]

# --- F54: draw -sel, checked when it is given ------------------------------------------------------
vmdance run clear
check "F54 draw -sel with no clustering: a typo refused on the top molecule (it was kept)" [expr {
    [string match "vmdance draw: -sel: invalid atom selection \"nmae CA\"*" [err {vmdance draw -sel {nmae CA}}]] &&
    [dict get [vmdance draw] sel] eq ""}]
check "  a selection is kept" [expr {[dict get [vmdance draw -sel {name CA}] sel] eq "name CA" && [dict get [vmdance draw -sel ""] sel] eq ""}]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
animate delete beg 0 end 0 $m
check "  the clustered molecule without its frames: checked on it" [expr {[::VMDance::Viz::_mol] < 0 &&
    [string match "*-sel: invalid atom selection*" [err {vmdance draw -sel {nmae CA}}]]}]
mol delete $m
check "  no molecule loaded: nothing to check it on, kept" [expr {[dict get [vmdance draw -sel {nmae CA} -reps 1] sel] eq "nmae CA"}]
set m [load_system two_state]
vmdance -mol $m -sel {index 0 to 5} -k 2 -kinit KmeansPP -quiet 1
set d [vmdance draw]
set sels [lsort -unique [lmap e $::VMDance::Viz::owned {lassign $e mm name; lindex [molinfo $mm get "{selection [mol repindex $mm $name]}"] 0}]]
check "  then drawn as the default atoms, and said (it was silent) ($sels)" [expr {
    [string match "*-sel: invalid atom selection \"nmae CA\"*the residues of the atoms clustered are drawn*" [::VMDance::_get $d note ""]] &&
    [llength $sels] == 1 && [string match "same residue as *" [lindex $sels 0]]}]
# (a session saved so lost its whole drawing on load: the -sel refused)
set f [file join $H typo.vmdance]
vmdance session save $f
vmdance draw -sel "" -reps 0 -colour 1
vmdance session load $f -mol $m
set v [::VMDance::Viz::get]
check "  a session saved with it: it alone left out on load, the rest of its drawing kept" [expr {
    [dict get $v reps] == 1 && [dict get $v colour] == 0 && [dict get $v sel] eq ""}]
# (R2: the window, opened later, drew the session's drawing again, its -sel
# refused, over what draw had changed since)
check "  R2 the window's state kept for later: no drawing (drawn already)" [expr {![llength [dict keys $::VMDance::Session::pending_gui v3d_*]]}]
vmdance draw -sel {resname NOSUCH}
check "  a selection of no atom there: said too" [string match "*-sel: \"resname NOSUCH\" matches no atom of molecule $m*" [::VMDance::_get [vmdance draw] note ""]]
vmdance draw -sel "" -reps 0
check "  a selection drawn as asked: no note" [expr {![dict exists [vmdance draw -reps 1] note]}]
vmdance draw -reps 0
vmdance run clear
vmdance draw -overlay 1 -frames 0-50
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
check "  -frames given before a clustering, past the molecule's last: said" [string match "*-frames: 27 frames are past the last of molecule $m (23): not drawn*" [::VMDance::_get [vmdance draw] note ""]]
set f [file join $H frames.vmdance]
vmdance session save $f
vmdance draw -overlay 0 -frames ""
vmdance session load $f -mol $m
set v [::VMDance::Viz::get]
check "  a session saved with them: they alone left out on load" [expr {[dict get $v overlay] == 1 && [dict get $v frames] eq ""}]
vmdance draw -overlay 0 -frames ""
check "  no atom selection left behind" [expr {[llength [atomselect list]] == 0}]

# --- F55: a quoted value is no keyword -------------------------------------------------------------
set bad {}
foreach {t want} {
    {chain "x"} "" {chain 'x'} "" {segname "y"} "" {chain =~ "^x$"} "" {resname "phi" "within"} "" {name C5' O5'} ""
    {"x" > 5} "" {'x' > 5} "" {name C5'x} "" {resname "user" and name CA} "" {name x1 X} ""
    {x > 1} x {name "CA" and x > 1} x {name C5' and x > 1 or name O5'} x {name "a\"b" or x > 1} x
    {chain "x" or y < 2} y {chain "x" and z<1} z {within 5 of resname "x"} within {user > 0} user {exwithin 3 of index 0} exwithin
} {
    if {[::VMDance::Mol::dynamic $t] ne $want} { lappend bad "$t: [::VMDance::Mol::dynamic $t]" }
}
check "F55 Mol::dynamic: quoted values are values, words outside quotes keywords [join $bad {; }]" [expr {![llength $bad]}]
set c [load_system two_state]
set s [atomselect $c "index 0 to 4"]; $s set chain x; $s delete
set s [atomselect $c "index 3 to 7"]; $s set segname y; $s delete
set bad {}
foreach t {{chain "x"} {chain 'x'} {segname "y"} {chain =~ "^x$"} {chain "x" and x > 1} {x > 1} {"x" > 1} {chain "x" or user > 0}
           {name C5' O5'} {name C5' or x > 1 or name O5'} {name 'x' or x > 1}} {
    if {[sel_moves $c $t] != ([::VMDance::Mol::dynamic $t] ne "")} { lappend bad $t }
}
check "  VMD agrees: what it calls static keeps its atoms when x and user change [join $bad {; }]" [expr {![llength $bad]}]
set rc [catch {vmdance -mol $c -sel {chain "x"} -k 2 -kinit KmeansPP -quiet 1} i]
check "  -sel {chain \"x\"} clusters (it was refused as changing with the frame)" [expr {!$rc && [dict get $i natoms] == 5}]
set rc [catch {vmdance -mol $c -sel {segname 'y'} -fit {chain "x"} -k 2 -kinit KmeansPP -quiet 1} i]
check "  -sel {segname 'y'} -fit {chain \"x\"}, and pick -sel {chain \"x\"}" [expr {!$rc && [dict get $i natoms] == 5 &&
    ![catch {vmdance pick -mol $c -sel {chain "x"} -method medoid} p] && [llength $p] >= 1}]
check "  a selection that changes with the frame: still refused" [expr {
    [string match "*can match other atoms in other frames (\"x\")*" [err {vmdance -mol $c -sel {chain "x" and x > 1} -k 2 -quiet 1}]] &&
    [string match "*-fit:*can match other atoms*(\"user\")*" [err {vmdance -mol $c -sel all -fit {chain "x" or user > 0} -k 2 -quiet 1}]]}]
check "  a quote left open: said to be no selection, not one that changes" [string match "*-sel: invalid atom selection*" [err {vmdance -mol $c -sel {chain "x} -k 2 -quiet 1}]]
mol delete $c
vmdance run clear

# --- R4: nearest, pucker and macros change with the frame too ------------------------------------
# (a -sel or -fit with them was clustered as their atoms at frame 0)
set p [load_system 3ptb]
set s0 [atomselect $p {nearest 30 to resname BAMI} frame 0]
set s1 [atomselect $p {nearest 30 to resname BAMI} frame 99]
set moves [expr {[$s0 list] ne [$s1 list]}]
$s0 delete; $s1 delete
atomselect macro mdvnear {within 5 of resname BAMI}
atomselect macro mdvnear2 {mdvnear and name CA}
set bad {}
foreach {t want} {{nearest 30 to resname BAMI} nearest {name CA and nearest 3 to index 0} nearest {pucker > 10} pucker
                  mdvnear mdvnear {protein and mdvnear2} mdvnear2 {acidic and name CA} "" {resname "mdvnear"} "" {name CA} ""} {
    if {[::VMDance::Mol::dynamic $t] ne $want} { lappend bad "$t: [::VMDance::Mol::dynamic $t]" }
}
check "R4 Mol::dynamic: nearest, pucker, a macro that holds such a word (VMD: nearest's atoms at frames 0 and 99 differ: $moves) [join $bad {; }]" [expr {
    $moves && ![llength $bad]}]
check "  -sel with nearest, -sel and -fit with such a macro: refused (clustered as the atoms at frame 0)" [expr {
    [string match "*-sel: the selection \"nearest 30 to resname BAMI\" can match other atoms in other frames (\"nearest\")*" [err {vmdance -mol $p -sel {nearest 30 to resname BAMI} -k 2 -kinit KmeansPP -quiet 1}]] &&
    [string match "*-sel: *can match other atoms in other frames (\"mdvnear\")*" [err {vmdance -mol $p -sel {mdvnear and name CA} -k 2 -kinit KmeansPP -quiet 1}]] &&
    [string match "*-fit: *(\"mdvnear2\")*" [err {vmdance -mol $p -sel {name CA} -fit mdvnear2 -k 2 -kinit KmeansPP -quiet 1}]] &&
    ![${R}::has_data]}]
check "  a macro of fixed atoms (VMD's acidic) still clusters" [expr {![catch {vmdance -mol $p -sel {acidic and name CA} -k 2 -kinit KmeansPP -quiet 1}]}]
atomselect delmacro mdvnear2
atomselect delmacro mdvnear
mol delete $p
vmdance run clear

# --- R3: sweep -params, a name once and no seeding -----------------------------------------------
# (the last of a name given twice was kept, the first never checked; a
# seeding given there was replaced by -seedings', StratAll unasked)
set s0 $::VMDance::Results::sweep
check "R3 sweep -params: a name given twice, an algorithm named twice: refused (the last was kept)" [expr {
    [string match "vmdance sweep: -params of kmeans: percentage is given twice" [err {vmdance sweep -mol $m -sel all -ks {2 3} -seedings KmeansPP -params {kmeans {percentage BOGUS percentage 10}} -quiet 1}]] &&
    [string match "vmdance sweep: -params: kmeans is given twice" [err {vmdance sweep -mol $m -sel all -ks {2 3} -seedings KmeansPP -params {kmeans {percentage BOGUS} kmeans {percentage 10}} -quiet 1}]] &&
    $::VMDance::Results::sweep eq $s0}]
check "  a seeding in -params: refused, naming -seedings (StratAll ran in its place)" [expr {
    [string match "vmdance sweep: -params of KMeans NANI gives -kinit KmeansPP: a sweep's seedings are -seedings" [err {vmdance sweep -mol $m -sel all -ks {2 3} -params {kmeans {kinit KmeansPP}} -quiet 1}]] &&
    [string match "vmdance sweep: -params of HELM gives -initial-kinit KmeansPP: *-seedings*" [err {vmdance sweep -mol $m -sel all -algorithms helm -ks {2 3} -params {helm {initial-kinit KmeansPP}} -quiet 1}]] &&
    $::VMDance::Results::sweep eq $s0}]
set rows [vmdance sweep -mol $m -sel all -ks {2 3} -seedings KmeansPP -params {kmeans {percentage 50}} -quiet 1]
check "  each name once, the seeding by -seedings: run" [expr {[llength $rows] == 2 && [lsort -unique [lmap r $rows {dict get $r seeding}]] eq "KmeansPP"}]

# --- F60: the parameters page --------------------------------------------------------------------
set page [read_text [file join $::root docs parameters.rst]]
set bad {}
set n 0
foreach a [${A}::all] {
    set t [${A}::label $a]
    set i [string first "\n$t\n[string repeat - [string length $t]]\n" $page]
    if {$i < 0} { lappend bad "$a: no section"; continue }
    set sec [string range $page $i end]
    foreach p [${A}::params $a] {
        lassign $p name type def
        if {![regexp "\\* - ``-$name``\n     - (\[^\n\]*)\n" $sec -> cell]} { lappend bad "$a -$name: no row"; continue }
        incr n
        if {$def ne ""} { set want "``$def``" } elseif {[catch {${A}::check_value $p "" 1}]} { set want "(needed)" } else { set want "(none)" }
        if {$cell ne $want} { lappend bad "$a -$name: $cell, not $want" }
    }
}
check "F60 parameters.rst: each Default is the value, or (needed) only when the checker refuses none ($n rows) [join $bad {; }]" [expr {
    ![llength $bad] && $n > 20 && [string match "*``-initial-labels``\n     - (none)\n*" $page]}]
set g [file join $H gen]
file mkdir [file join $g docs]
file link -symbolic [file join $g vmdance] [file join $::root vmdance]
set here [pwd]
cd $g
set rc [catch {exec tclsh [file join $::root docs tools gen_parameters.tcl] 2>@1} out]
cd $here
check "  the page is the generator's output" [expr {!$rc && [read_text [file join $g docs parameters.rst]] eq $page}]

# --- R1: the shipped decks, made again --------------------------------------------------------------
# (only their generators said the guide's tau numbers and that figures
# need a display: the .pptx printed the reference copy's and "the figures
# command draws the plots without the window")
set gt [deck_text [file join $::root presentation VMDance_guide.pptx]]
set tt [deck_text [file join $::root presentation VMDance.pptx]]
set r1 {presentation/VMDance_guide.pptx presentation/VMDance.pptx presentation/make_guide.js presentation/screens_guide.tcl
        presentation/assets/guide_tau_window.png presentation/assets/guide_tau_rep0_crop.png presentation/assets/tau_window.png
        presentation/assets/tau_rep0_crop.png manuscripts/shared/data/numbers_guide.txt}
if {[llength [lmap f $r1 {expr {[file isfile [file join $::root $f]] ? [continue] : $f}}]]} {
    skip "R1 the shipped decks" "the files they are made of are not beside the repository here"
} elseif {$gt eq "" || $tt eq ""} {
    skip "R1 the shipped decks" "unzip missing"
} else {
    set G {}
    foreach l [split [read_text [file join $::root manuscripts shared data numbers_guide.txt]] \n] {
        if {[regexp {^(\S+)\s+(\S+)} $l -> k v] && [string index $k 0] ne "#"} { dict set G $k $v }
    }
    set two [join [lmap r [split [dict get $G guide.clusters] ";"] {string cat "{" [join [split $r ,] " "] "}"}] " "]
    check "R1 the guide (.pptx): the tau numbers of the trajectory it names ([dict get $G guide.sil], [dict get $G guide.prime.pairwise], $two)" [expr {
        [string first "The mean silhouette here is [dict get $G guide.sil]:" $gt] >= 0 &&
        [string first "predicts frame [dict get $G guide.prime.pairwise]." $gt] >= 0 && [string first "#  $two ..." $gt] >= 0}]
    check "  the guide and the talk: figures need a display (not drawn without the window)" [expr {
        [string first "draws the plots without the window" $gt] < 0 && [string first "which needs a display: text-mode VMD has none" $gt] >= 0 &&
        [string first "in text mode (figures need a display)" $gt] >= 0 && [string first "in text mode too (figures need a display)." $tt] >= 0}]
    set js [read_text [file join $::root presentation make_guide.js]]
    set sg [read_text [file join $::root presentation screens_guide.tcl]]
    set gd [file join $::root presentation VMDance_guide.pptx]
    set as [file join $::root presentation assets]
    check "  the guide's tau pictures: its own, taken on the trajectory it names, in the .pptx (the reference copy's were shown)" [expr {
        ![regexp {"(pane_)?tau_|reps\(s, "tau"} $js] && [regexp {reps\(s, "guide_tau"} $js] &&
        [string first "load_ref heptapeptide" $sg] < 0 && [string first "aligned_original_tau_6K.dcd" $sg] >= 0 &&
        [deck_has $gd [file join $as guide_tau_window.png]] && [deck_has $gd [file join $as guide_tau_rep0_crop.png]] &&
        ![deck_has $gd [file join $as tau_window.png]] && ![deck_has $gd [file join $as tau_rep0_crop.png]]}]
}

# --- F78: figures in text mode -------------------------------------------------------------------
set e [err {vmdance figures $H}]
if {[string match "*needs Tk*" $e]} {
    check "F78 figures in text mode: needs a display, and how to make them (not 'use the command')" [expr {
        [string match "vmdance figures needs Tk and a display (*): *session load*" $e] && ![string match "*use the command*" $e]}]
    check "  the window in text mode: still 'use the command'" [string match "the window needs Tk*use the command*" [err {vmdance}]]
} else {
    skip "F78 figures in text mode" "Tk has a display here"
}

# --- F76, F77: the docs' scripts and numbers -----------------------------------------------------
set lines [readme_block]
set ia [lsearch -glob $lines "mol addfile *"]
set id [lsearch -glob $lines "animate delete beg 0 end 0*"]
set ik [lsearch -glob $lines "vmdance -sel *"]
check "F76 README's script: the PDB's own frame deleted after the trajectory, before the clustering" [expr {$ia >= 0 && $id > $ia && $ik > $id}]
set qs [read_text [file join $::root docs quickstart.rst]]
check "  the quick start's too" [regexp {mol addfile [^\n]*\n\s*animate delete beg 0 end 0[^\n]*\n\s*vmdance -sel} $qs]
set data [mdance_data]
if {$data eq "" || [real_cli] eq ""} {
    skip "F76, F77 the docs' numbers" "MDANCE's data (MDANCE_DATA) or mdance-cli missing"
} else {
    use_cli
    foreach x [molinfo list] { mol delete $x }
    # the README's lines, as written, in MDANCE's data folder
    set here [pwd]
    cd $data
    set ok 1
    foreach l [lrange $lines 0 $ik] {
        if {[string match "#*" $l] || [string match "package *" $l]} continue
        if {[catch {uplevel #0 $l} r]} { set ok 0; puts "  $l: $r" }
    }
    set i [vmdance info]
    set c [lindex $lines [expr {$ik + 1}]]
    set ih [lsearch -glob $lines "vmdance -sel * -algorithm helm *"]
    set hrc [catch {uplevel #0 [lindex $lines $ih]} h]
    cd $here
    lassign {"" "" "" ""} nf sizes ch db
    regexp {frames (\d+) } $c -> nf
    regexp {sizes \{([^\}]*)\}} $c -> sizes
    regexp {ch ([0-9.]+) db ([0-9.]+)} $c -> ch db
    set dch [string length [lindex [split $ch .] 1]]
    set ddb [string length [lindex [split $db .] 1]]
    set got none
    if {[dict size $i]} { set got "[dict get $i frames] [dict get $i sizes] [format %.${dch}f [dict get $i ch]] [format %.${ddb}f [dict get $i db]]" }
    check "F76 README's clustering on MDANCE's data: the frames, sizes and scores its comment quotes ($got)" [expr {
        $ok && [string match "# -> run 1 *" $c] && $nf == 6001 && $got eq "$nf $sizes $ch $db"}]
    check "  and its HELM line runs (it was refused: 6002 frames)" [expr {$ih > 0 && !$hrc && [dict get $h frames] == 6001}]
    # the guide's walkthrough, on the trajectory it names: the numbers its
    # slides print (numbers_guide.txt)
    set NG [file join $::root manuscripts shared data numbers_guide.txt]
    if {![file isfile [file join $::root presentation make_guide.js]] || ![file isfile $NG]} {
        skip "F77 the guide's numbers" "the decks are not beside the repository here"
    } else {
        set G {}
        if {[file exists $NG]} {
            foreach l [split [read_text $NG] \n] { if {[regexp {^(\S+)\s+(\S+)} $l -> k v] && [string index $k 0] ne "#"} { dict set G $k $v } }
        }
        set js [read_text [file join $::root presentation make_guide.js]]
        set gdcd ""
        regexp {"mol addfile (\S+) waitfor all"} $js -> gdcd
        check "F77 the guide's numbers: of the trajectory it tells users to load ($gdcd)" [expr {[::VMDance::_get $G guide.dcd ""] eq $gdcd &&
            [regexp -all "\"mol addfile $gdcd waitfor all\"" $js] == 2 && [string first "v(NR, \"tau." $js] < 0}]
        foreach x [molinfo list] { mol delete $x }
        set g [mol new [file join $data aligned_tau.pdb] waitfor all]
        mol addfile [file join $data $gdcd] waitfor all molid $g
        animate delete beg 0 end 0 $g
        vmdance -mol $g -sel backbone -k 6 -quiet 1
        set two [join [lmap r [lrange [vmdance clusters] 0 1] {format "%d,%d,%.1f,%.2f,%.2f,%d" {*}$r}] ";"]
        set got "[format %.3f [dict get [vmdance silhouette] mean]] [dict get [vmdance prime] pairwise] $two"
        check "  the guide's walkthrough on it: the silhouette, PRIME's frame and the clusters its slides print ($got)" [expr {
            $got eq "[::VMDance::_get $G guide.sil -] [::VMDance::_get $G guide.prime.pairwise -] [::VMDance::_get $G guide.clusters -]"}]
    }
    foreach x [molinfo list] { mol delete $x }
    use_fake
}

vmdance run clear
foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_g8 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
