# Where the time goes, without the window (text mode, the real backend):
# each scenario's procedures by inclusive time, and the memory. Scenarios:
# the heptapeptide's backbone (6001 frames × 48 atoms) clustered cold and
# again, its elbow scan, a k of it made the clustering, PRIME, the
# similarity, picks, a sweep, every export, the session; every atom
# fitted (6001 × 217); 3ptb's every atom (100 × 3222); the heptapeptide's
# every atom eight times over (48 008 × 217).
#   vmd -dispdev text -e tests/profile/profile_core.tcl < /dev/null
#   (the report: tests/out/profile/core.txt)
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
source [file join $::root tests profile prof.tcl]
set P [file join $::out profile]
file mkdir $P
set rep [file join $P core.txt]
file delete $rep
proc say {s} { set fh [open $::rep a]; puts $fh $s; close $fh; puts $s }
proc scenario {title script} {
    set m0 [prof::rss]
    set t0 [clock microseconds]
    uplevel 1 $script
    set t [expr {([clock microseconds] - $t0) / 1000.0}]
    prof::report "$title: [format %.0f $t] ms, memory $m0 → [prof::rss] MB" 18 $::rep
}
if {[catch {
package require vmdance
if {[real_cli] eq ""} { puts "no mdance-cli"; quit }
use_cli
say "VMDance profile, [clock format [clock seconds]], [exec uname -n], VMD [vmdinfo version], Tcl [info patchlevel]"
prof::start
set mh [load_ref heptapeptide]
scenario "KMeans NANI k 6, heptapeptide backbone, cold (6001 × 48)" { vmdance -mol $mh -sel backbone -k 6 -quiet 1 }
scenario "the same again (the coordinates kept)" { vmdance -mol $mh -sel backbone -k 6 -quiet 1 }
scenario "elbow scan k 2-10" { vmdance elbow -mol $mh -sel backbone -from 2 -to 10 -quiet 1 }
scenario "elbow load 6 (the measures)" { vmdance elbow load 6 }
scenario "HELM k 6 from 60" { vmdance -mol $mh -sel backbone -algorithm helm -k 6 -initial 60 -quiet 1 }
scenario "PRIME" { vmdance prime }
scenario "similarity" { vmdance similarity }
scenario "pick 2% most diverse" { vmdance pick -mol $mh -sel backbone -method diversity -param 2 }
set dx [file join $P export]
file delete -force $dx
file mkdir $dx
scenario "sweep: KMeans NANI × k {4 6 8} × StratAll, KmeansPP" { vmdance sweep -mol $mh -sel backbone -algorithms kmeans -ks {4 6 8} -seedings {StratAll KmeansPP} -quiet 1 }
scenario "export every item" { vmdance export $dx -items [::VMDance::Export::items] }
set sf [file join $P s.vmdance]
scenario "session save" { vmdance session save $sf }
scenario "session load" { vmdance session load $sf }
scenario "the command's answers (clusters, labels, silhouette, distances, tree, transitions, residence)" {
    foreach q {clusters labels silhouette distances tree transitions residence} { vmdance $q }
}
if {[real_lib] ne ""} {
    use_lib
    scenario "the library: KMeans NANI k 6 (the coordinates kept)" { vmdance -mol $mh -sel backbone -k 6 -quiet 1 }
    use_cli
}
scenario "every atom (6001 × 217) fitted on the backbone, KMeans NANI k 6, cold" { vmdance -mol $mh -sel all -fit backbone -k 6 -quiet 1 }
vmdance run clear
set mp [load_system 3ptb]
scenario "3ptb every atom (100 × 3222), KMeans NANI k 5" { vmdance -mol $mp -sel all -k 5 -kinit KmeansPP -quiet 1 }
scenario "  its PRIME" { vmdance prime }
vmdance run clear
::VMDance::Coords::forget
mol delete all
set d [file join $::refruns inputs 1_heptapeptide]
set mb [mol new [file join $d aligned_tau.pdb] waitfor all]
for {set i 0} {$i < 8} {incr i} { mol addfile [file join $d backbone_aligned.dcd] waitfor all molid $mb }
animate delete beg 0 end 0 $mb
say "heptapeptide ×8: [molinfo $mb get numframes] frames × [molinfo $mb get numatoms] atoms, memory [prof::rss] MB"
scenario "48 008 × 217 (every atom), KMeans NANI k 6, cold" { vmdance -mol $mb -sel all -k 6 -quiet 1 }
scenario "  again (the coordinates kept)" { vmdance -mol $mb -sel all -k 6 -quiet 1 }
scenario "  its similarity" { vmdance similarity }
scenario "  session save" { vmdance session save $sf }
say "session of 48 008 frames: [format %.1f [expr {[file size $sf] / 1e6}]] MB"
} err]} { puts "profile crashed: $err\n$::errorInfo" }
::VMDance::Backend::cleanup
quit
