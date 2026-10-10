# What the review of the files and exports' fixes (hardening 2, g4) found,
# each kept from coming back (text mode, the fake backend):
#   link-chmod   a link of another user's at an output name: what it points
#                to keeps its permissions (Tcl's rename -force made it u+w
#                through the link: a read-only file of the user's 0644)
#   stale-traj   an export of trajectories deletes the clusters an earlier
#                one left under its name that it does not write (a larger k,
#                the other format): t_cluster_* mixed two clusterings
#   pdb-hint     a PDB refused for an occupancy or a beta, or for a
#                coordinate in a file's first frame, no longer says to write
#                a DCD (whose PDB fails the same way); the advice given works
#   folder-made  an export that fails while it writes takes back the folder
#                it made, and the parents it made (an empty one was left)
#   no-chmod     where chmod is refused (a gvfs share), files are replaced all
#                the same (a re-export, a session, the preferences failed);
#                a rename refused at the end names the file and those already
#                in place; an error names the file, not its temporary (a child
#                VMD with a shim of chmod and rename, LD_PRELOAD; skipped
#                without a C compiler)
#   window-f34   the window's Save picks, in text mode with Tk stubbed: a DCD
#                asks before it replaces the PDB of its name beside it, Cancel
#                writes nothing (test_hardening2 checked frame_files alone;
#                test_gui runs it in the window)
# (The window's folder fields trimmed, the Export dialog naming the clusters
# it deletes, and figures that fail taking back their folder: test_gui.)
#   cd <VMDance>; vmd -dispdev text -e tests/test_hardening2_fx_g4.tcl < /dev/null
source [file join [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}] tests common.tcl]
set H [file join $::out hardening2_fx_g4]
file delete -force $H
file mkdir $H

proc put {f t} { set fh [open $f wb]; puts -nonewline $fh $t; close $fh }
proc slurp {f} { set fh [open $f rb]; try { return [read $fh] } finally { close $fh } }
proc md5 {f} { lindex [split [exec md5sum $f]] 0 }
# the plugin's temporaries left in a folder (<file>.tmp<pid>-<random>)
proc temps {d} { glob -nocomplain -tails -directory $d *.tmp[pid]-* }
proc names {d pattern} { lsort [glob -nocomplain -tails -directory $d -- $pattern] }
# Set x of atom 0 of molecule m at frame f (returns what to put back).
proc far {m f x} {
    set s [atomselect $m "index 0" frame $f]
    set old [$s get {x y z}]
    $s set x $x
    $s delete
    return $old
}
proc unfar {m f old} {
    set s [atomselect $m "index 0" frame $f]
    $s set {x y z} $old
    $s delete
}

if {[catch {
package require vmdance
set ::VMDance::Prefs::file ""
use_fake
fake_env
set R ::VMDance::Results
set m [load_system two_state]
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1

# --- link-chmod: a link of another user's at an output name ----------------------------------
# (target leaves it unfollowed: it is replaced; Tcl's rename -force first
# made what it points to writable, u+w through the link)
set D [file join $H links]
set mine [file join $H mine]
file mkdir $D $mine
foreach n {table.csv s.vmdance prefs.txt} {
    put [file join $mine $n] PRECIOUS
    file attributes [file join $mine $n] -permissions 0444
}
file link -symbolic [file join $D x_labels.csv] [file join $mine table.csv]
file link -symbolic [file join $D x.vmdance] [file join $mine s.vmdance]
file link -symbolic [file join $D x.prefs] [file join $mine prefs.txt]
# (this user's uid made another's: the links are then of someone else)
set uid0 [::VMDance::Backend::_uid]
set ::VMDance::Backend::uid 4000000000
set e1 [err {vmdance export $D -prefix x -items labels}]
set e2 [err {vmdance session save [file join $D x.vmdance]}]
set ::VMDance::Prefs::file [file join $D x.prefs]
set e3 [::VMDance::Prefs::save {ui_font 13}]
set ::VMDance::Prefs::file ""
set ::VMDance::Backend::uid $uid0
set modes [lmap n {table.csv s.vmdance prefs.txt} {file attributes [file join $mine $n] -permissions}]
check "link-chmod: links of another user's to read-only files of the user's (a table, a session, the preferences): each replaced, what it points to as it was, its mode too ($modes)" [expr {
    $e1 eq "" && $e2 eq "" && $e3 eq "" && [lsort -unique $modes] eq "00444" &&
    [lsort -unique [lmap n {table.csv s.vmdance prefs.txt} {slurp [file join $mine $n]}]] eq "PRECIOUS" &&
    [lsort -unique [lmap n {x_labels.csv x.vmdance x.prefs} {file type [file join $D $n]}]] eq "file" &&
    [string match "# VMDance*" [slurp [file join $D x_labels.csv]]] && ![llength [temps $D]]}]
# (the picks' structures too: the PDB beside a DCD, renamed with it; every
# link taken for another user's, Export::_own, as the private folder
# needs the user's own uid)
vmdance pick -mol $m -sel all -method medoid
file link -symbolic [file join $D y.pdb] [file join $mine table.csv]
rename ::VMDance::Export::_own ::VMDance::Export::_own_real
proc ::VMDance::Export::_own {uid} { return 0 }
set e [err {vmdance pick save [file join $D y.dcd] -format dcd}]
rename ::VMDance::Export::_own ""
rename ::VMDance::Export::_own_real ::VMDance::Export::_own
check "  the PDB beside the picks' DCD: likewise ([file attributes [file join $mine table.csv] -permissions])" [expr {
    $e eq "" && [file attributes [file join $mine table.csv] -permissions] eq "00444" && [slurp [file join $mine table.csv]] eq "PRECIOUS" &&
    [file type [file join $D y.pdb]] eq "file" && [file isfile [file join $D y.dcd]]}]
foreach n {table.csv s.vmdance prefs.txt} { file attributes [file join $mine $n] -permissions 0644 }

# --- stale-traj: an earlier export's clusters under the same name -----------------------------
set D [file join $H stale]
file mkdir $D
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
set n3 [llength [lmap c {0 1 2} {expr {[llength [${R}::member_frames $c]] ? $c : [continue]}}]]
vmdance export $D -prefix t -items trajectories
set k3 [names $D t_cluster_*]
# (names an export of trajectories does not make: kept)
file mkdir [file join $D t_cluster_9.pdb]
put [file join $D t_cluster_07.dcd] MINE
put [file join $D t_cluster_2.txt] MINE
put [file join $D tt_cluster_2.pdb] MINE
vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
set e1 [err {vmdance export $D -prefix t -items {trajectories prime}}]
set m2 [lmap c {0 1} {lindex [${R}::member_frames $c] end}]
set old [far $m [lindex $m2 1] -1500.0]
set e2 [err {vmdance export $D -prefix t -items trajectories -format pdb}]
unfar $m [lindex $m2 1] $old
check "stale-traj: k 3 ($n3 clusters with frames: $k3); at k 2, a refused export and one that fails deletes none" [expr {
    $n3 == 3 && [llength $k3] == 6 && [string match "*no PRIME*" $e1] && [string match "*could not be written: frame *" $e2] &&
    [names $D t_cluster_*] eq [lsort [concat $k3 t_cluster_07.dcd t_cluster_2.txt t_cluster_9.pdb]]}]
set c [::VMDance::Export::check $D t trajectories]
vmdance export $D -prefix t -items trajectories
check "  at k 2: the third cluster's DCD and PDB said (check) and deleted; a folder, another numbering, another extension or prefix kept" [expr {
    [lmap f [lindex $c 4] {file tail $f}] eq {t_cluster_2.dcd t_cluster_2.pdb} &&
    [names $D t_cluster_*] eq {t_cluster_0.dcd t_cluster_0.pdb t_cluster_07.dcd t_cluster_1.dcd t_cluster_1.pdb t_cluster_2.txt t_cluster_9.pdb} &&
    [file isfile [file join $D tt_cluster_2.pdb]]}]
set c [::VMDance::Export::check $D t trajectories {format pdb}]
vmdance export $D -prefix t -items trajectories -format pdb
set t [mol new [file join $D t_cluster_0.pdb] waitfor all]
set nf [molinfo $t get numframes]
mol delete $t
check "  as PDB: the DCDs of before deleted (their PDB is now another file), the clusters' PDBs written ($nf frames)" [expr {
    [lmap f [lindex $c 4] {file tail $f}] eq {t_cluster_0.dcd t_cluster_1.dcd} &&
    [names $D t_cluster_*] eq {t_cluster_0.pdb t_cluster_07.dcd t_cluster_1.pdb t_cluster_2.txt t_cluster_9.pdb} &&
    $nf == [llength [${R}::member_frames 0]]}]
check "  none when nothing is there of before, or no trajectories are written" [expr {
    [lindex [::VMDance::Export::check $D t trajectories {format pdb}] 4] eq {} && [lindex [::VMDance::Export::check $D t labels] 4] eq {} &&
    [lindex [::VMDance::Export::check [file join $D none] t trajectories] 4] eq {}}]
# (a prefix that glob would read: its characters taken as they are)
put [file join $D {a[1]_cluster_5.dcd}] OLD
put [file join $D {a1_cluster_5.dcd}] MINE
vmdance export $D -prefix {a[1]} -items trajectories
check "  a prefix with glob's characters ({a\[1\]}): its own deleted, a1's kept" [expr {
    ![file exists [file join $D {a[1]_cluster_5.dcd}]] && [file exists [file join $D {a1_cluster_5.dcd}]] && [file exists [file join $D {a[1]_cluster_0.dcd}]]}]

# --- pdb-hint: what to do with a frame a PDB cannot hold --------------------------------------
set D [file join $H hint]
file mkdir $D
set reps [::VMDance::Export::rep_frames]
set f0 [lindex $reps 0]
set fl [lindex $reps end]
# a coordinate in the representatives' first frame: a DCD's PDB is that frame
set old [far $m $f0 -1500.0]
set e1 [err {vmdance export $D -prefix a -items representatives -format pdb}]
set e2 [err {vmdance export $D -prefix a -items representatives -format dcd}]
set e3 [err {vmdance export $D -prefix a -items representatives -format pdb -sel "not index 0"}]
unfar $m $f0 $old
check "pdb-hint: a coordinate in the file's first frame: no DCD offered (it fails the same), the atoms to leave out; leaving them out works ($e1)" [expr {
    [string match "*a_representatives.pdb\" could not be written: frame $f0 has a coordinate*: leave those atoms out (-sel)" $e1] &&
    [string first "-format dcd" $e1] < 0 && [string match "*a_representatives.pdb\" could not be written: frame $f0 *: leave those atoms out (-sel)" $e2] &&
    $e3 eq "" && ![llength [temps $D]]}]
# a coordinate in a later frame: a DCD offered, and it holds it
set old [far $m $fl -1500.0]
set e1 [err {vmdance export $D -prefix b -items representatives -format pdb}]
set e2 [err {vmdance export $D -prefix b -items representatives -format dcd}]
unfar $m $fl $old
check "  in a later frame: a DCD offered, and written as offered ($e1)" [expr {
    [string match "*b_representatives.pdb\" could not be written: frame $fl has a coordinate*: write a DCD (-format dcd)" $e1] && $e2 eq "" &&
    [file isfile [file join $D b_representatives.dcd]]}]
# a cluster's first frame, as a trajectory of its own
set c1 [${R}::member_frames 1]
set old [far $m [lindex $c1 0] -1500.0]
set e1 [err {vmdance export $D -prefix c -items trajectories -format pdb}]
unfar $m [lindex $c1 0] $old
set old [far $m [lindex $c1 end] -1500.0]
set e2 [err {vmdance export $D -prefix d -items trajectories -format pdb}]
set e3 [err {vmdance export $D -prefix d -items trajectories -format dcd}]
unfar $m [lindex $c1 end] $old
check "  a cluster's trajectory: its first frame, the atoms to leave out; a later one, a DCD, which works" [expr {
    [string match "*c_cluster_1.pdb\" could not be written: frame [lindex $c1 0] *: leave those atoms out (-sel)" $e1] &&
    [string match "*d_cluster_1.pdb\" could not be written: frame [lindex $c1 end] *: write a DCD (-format dcd)" $e2] && $e3 eq ""}]
# an occupancy or a beta: the atoms', in every frame and format
set s [atomselect $m "index 0"]
set ob [$s get {occupancy beta}]
set es {}
foreach {what v} {beta 12345 beta -1000.5 occupancy 99999 occupancy -1000} {
    $s set $what $v
    foreach fmt {pdb dcd} { lappend es [err {vmdance export $D -prefix e -items representatives -format $fmt}] }
    lappend es [err {vmdance export $D -prefix e -items trajectories -format dcd}]
    $s set {occupancy beta} $ob
}
$s set beta 12345
set ok [err {vmdance export $D -prefix e -items {representatives trajectories} -sel "not index 0"}]
$s set {occupancy beta} $ob
$s delete
set bad [lmap e $es {expr {[string match "*could not be written: an atom has an occupancy or a beta that a PDB cannot hold (-999.999 to 9999.999): set them within it, or leave those atoms out (-sel)" $e] ? [continue] : $e}}]
check "  an occupancy or a beta past a PDB's columns: said of the atoms, never a DCD offered (both formats, a trajectory); leaving them out works ([lindex $bad 0])" [expr {
    [llength $es] == 12 && ![llength $bad] && $ok eq "" && [file isfile [file join $D e_representatives.dcd]]}]

# --- folder-made: an export that fails while it writes ----------------------------------------
set old [far $m $fl -1500.0]
set e1 [err {vmdance export [file join $H nf a b] -prefix n -items {labels representatives} -format pdb}]
file mkdir [file join $H have]
set e2 [err {vmdance export [file join $H have new] -prefix n -items {labels representatives} -format pdb}]
unfar $m $fl $old
put [file join $H afile] KEEP
set e3 [err {vmdance export [file join $H afile sub] -prefix n -items labels}]
check "folder-made: a new folder and its parents, the export failing while it writes (a frame a PDB cannot hold): none left; one there kept" [expr {
    [string match "*n_representatives.pdb\" could not be written: frame $fl *" $e1] && ![file exists [file join $H nf]] &&
    [string match "*could not be written: frame $fl *" $e2] && [file isdirectory [file join $H have]] && ![file exists [file join $H have new]] &&
    [string match "*the folder \"*afile/sub\" could not be made: *" $e3] && [slurp [file join $H afile]] eq "KEEP"}]
set e [err {vmdance export [file join $H nf2 a] -prefix n -items labels}]
check "  one that succeeds: the folder made, with its parents" [expr {$e eq "" && [file isfile [file join $H nf2 a n_labels.csv]]}]

# --- no-chmod: where chmod is refused, and a rename at the end ---------------------------------
# (a child VMD with a shim: chmod under NOCHMOD_DIR fails EOPNOTSUPP, as on
# a gvfs share; a rename onto a name holding NORENAME fails EACCES)
set N [file normalize [file join $H nochmod]]
file mkdir $N
set shim [file join $H shim]
file mkdir $shim
put [file join $shim nochmod.c] {
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <fcntl.h>
static int under(const char *p) {
    const char *d = getenv("NOCHMOD_DIR");
    return d && p && strncmp(p, d, strlen(d)) == 0;
}
static int marked(const char *p) {
    const char *m = getenv("NORENAME");
    return m && *m && p && strstr(p, m) != NULL;
}
int chmod(const char *p, mode_t m) {
    static int (*real)(const char *, mode_t);
    if (!real) real = dlsym(RTLD_NEXT, "chmod");
    if (under(p)) { errno = EOPNOTSUPP; return -1; }
    return real(p, m);
}
int fchmodat(int fd, const char *p, mode_t m, int fl) {
    static int (*real)(int, const char *, mode_t, int);
    if (!real) real = dlsym(RTLD_NEXT, "fchmodat");
    if (under(p)) { errno = EOPNOTSUPP; return -1; }
    return real(fd, p, m, fl);
}
int rename(const char *a, const char *b) {
    static int (*real)(const char *, const char *);
    if (!real) real = dlsym(RTLD_NEXT, "rename");
    if (marked(b)) { errno = EACCES; return -1; }
    return real(a, b);
}
}
set vmdexe [auto_execok [_env VMD vmd]]
if {[auto_execok cc] eq "" || $vmdexe eq "" ||
    [catch {exec cc -shared -fPIC -o [file join $shim nochmod.so] [file join $shim nochmod.c] -ldl 2>@1}]} {
    skip "no-chmod: chmod refused, a rename refused" "no C compiler for the shim, or no VMD to run"
} else {
    set child [file join $H nochmod.tcl]
    put $child [string map [list @ROOT@ $::root @N@ $N] {
        source [file join {@ROOT@} tests common.tcl]
        proc say {k v} { puts "FXG4 $k=<[string map {\n { }} $v]>" }
        proc slurp {f} { set fh [open $f rb]; try { return [read $fh] } finally { close $fh } }
        if {[catch {
            package require vmdance
            set ::VMDance::Prefs::file ""
            use_fake
            fake_env
            set N {@N@}
            set m [load_system two_state]
            vmdance -mol $m -sel all -k 2 -kinit KmeansPP -quiet 1
            # (the shim at work: chmod refused there)
            set fh [open [file join $N probe] w]; close $fh
            say probe [catch {file attributes [file join $N probe] -permissions 0600}]
            say export1 [err {vmdance export $N -prefix x -items labels}]
            set fh [open [file join $N x_labels.csv] a]; puts $fh MARK; close $fh
            say export2 [err {vmdance export $N -prefix x -items {summary clusters labels representatives}}]
            say export2_new [expr {![string match "*MARK*" [slurp [file join $N x_labels.csv]]]}]
            say session1 [err {vmdance session save [file join $N s.vmdance]}]
            say session2 [err {vmdance session save [file join $N s.vmdance]}]
            set ::VMDance::Prefs::file [file join $N p.prefs]
            say prefs1 [::VMDance::Prefs::save {ui_font 13}]
            say prefs2 [::VMDance::Prefs::save {ui_font 14}]
            set ::VMDance::Prefs::file ""
            say prefs2_new [string match "*ui_font 14*" [slurp [file join $N p.prefs]]]
            # a rename refused at the end of a batch, and alone
            set ::env(NORENAME) nr_labels
            say batch [err {vmdance export $N -prefix nr -items {summary clusters labels}}]
            say batch_files [lsort [glob -nocomplain -tails -directory $N nr_*]]
            say alone [err {vmdance session save [file join $N nr_labels.vmdance]}]
            unset ::env(NORENAME)
            say temps [glob -nocomplain -tails -directory $N *.tmp*]
        } err]} { say crash "$err $::errorInfo" }
        ::VMDance::Backend::cleanup
        quit
    }]
    catch {exec env LD_PRELOAD=[file join $shim nochmod.so] NOCHMOD_DIR=$N timeout 600 [lindex $vmdexe 0] -dispdev text -e $child < /dev/null 2>@1} o
    set G {}
    foreach {- k v} [regexp -all -inline -line {^FXG4 ([a-z0-9_]+)=<(.*)>$} $o] { dict set G $k $v }
    if {[dict exists $G crash]} { puts "  (the child: [dict get $G crash])" }
    proc g {k} { ::VMDance::_get $::G $k ? }
    check "no-chmod: chmod refused there ([g probe]): a table, a bundle, a session and the preferences replaced all the same ([g export2]; [g session2]; [g prefs2])" [expr {
        [g probe] eq "1" && [g export1] eq "" && [g export2] eq "" && [g export2_new] eq "1" && [g session1] eq "" && [g session2] eq "" &&
        [g prefs1] eq "" && [g prefs2] eq "" && [g prefs2_new] eq "1"}]
    check "  a rename refused at the end of a batch: the file named, and those already in place ([g batch])" [expr {
        [string match "*\"$N/nr_labels.csv\" could not be written: permission denied (written before it: nr_summary.txt, nr_clusters.csv)" [g batch]] &&
        [g batch_files] eq {nr_clusters.csv nr_summary.txt}}]
    check "  alone: the file named, not its temporary; no temporary left ([g alone])" [expr {
        [string match "*\"$N/nr_labels.vmdance\" could not be written: permission denied" [g alone]] && [string first ".tmp" [g alone]] < 0 &&
        [g temps] eq ""}]
}

# --- window-f34: the window's Save picks, Tk stubbed (last: the stubs stay) ------------------
# (test_hardening2's F34 check asked frame_files only; the dialog itself
# ran only in test_gui, which needs a display)
vmdance pick -mol $m -sel all -method medoid
set ::messages {}
set ::answer ""
proc tk_messageBox {args} {
    lappend ::messages [dict get $args -message]
    if {[dict exists $args -type] && [dict get $args -type] eq "okcancel" && $::answer ne ""} { return $::answer }
    return ok
}
set ::next_file ""
proc tk_getSaveFile {args} { return $::next_file }
namespace eval ::VMDance::GUI {
    variable w .vmdance
    variable S
    array set S {status ""}
}
proc ::VMDance::GUI::status {msg} { variable S; set S(status) $msg }
proc ::VMDance::GUI::busy {} { return 0 }
proc ::VMDance::GUI::_error {msg {parent ""}} { tk_messageBox -message $msg }
source [file join $::root vmdance lib gui_io.tcl]
set G ::VMDance::GUI
set pd [file join $H picks]
file mkdir $pd
file copy [file join $::fixtures two_state.pdb] [file join $pd sys.pdb]
set keep [md5 [file join $pd sys.pdb]]
set ::next_file [file join $pd sys.dcd]
set ::answer cancel
${G}::save_picks_dialog
set ::answer ""
check "window-f34: Save picks as a DCD beside a PDB of its name: asked first; Cancel: nothing written" [expr {
    $::messages eq {{Replace sys.pdb?}} && [md5 [file join $pd sys.pdb]] eq $keep && ![file exists [file join $pd sys.dcd]]}]
${G}::save_picks_dialog
set t [mol new [file join $pd sys.pdb] waitfor all]
mol addfile [file join $pd sys.dcd] waitfor all molid $t
set np [expr {[molinfo $t get numframes] - 1}]
mol delete $t
check "  OK: the DCD and the PDB of its atoms written ($np frames)" [expr {
    [llength $::messages] == 2 && $np == [llength [dict get $::VMDance::Results::picks vmdframes]] && [md5 [file join $pd sys.pdb]] ne $keep}]
set ::next_file [file join $pd new.dcd]
${G}::save_picks_dialog
set ::next_file [file join $pd one.pdb]
put [file join $pd one.dcd] MINE
${G}::save_picks_dialog
check "  a DCD with no PDB of its name, or a PDB: nothing asked, nothing beside it touched" [expr {
    [llength $::messages] == 2 && [file isfile [file join $pd new.pdb]] && [file isfile [file join $pd new.dcd]] &&
    [file isfile [file join $pd one.pdb]] && [slurp [file join $pd one.dcd]] eq "MINE"}]

foreach x [molinfo list] { mol delete $x }
done

} err]} { puts "FAIL test_hardening2_fx_g4 crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
quit
