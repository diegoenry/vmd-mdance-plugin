# The documentation's pictures: the window (its tabs and every plot) on
# MDANCE's heptapeptide, the plots as figures, the 3D view.
#   cd <VMDance>
#   DISPLAY=:9 vmd -dispdev win -e docs/tools/capture.tcl < <(sleep 900)
# (standard input must stay open: VMD draws no new geometry once it has
# read its end, and the renders would show a stale scene)
# MDANCE_REF_RUNS: the reference runs (inputs/1_heptapeptide).
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::figs [file join $::root docs _static figures]
file mkdir $::figs
set ::logf [open [file join $::out capture.log] w]
fconfigure $::logf -buffering line
proc log {m} { puts $::logf $m }
proc bgerror {msg} { log "BGERROR $msg\n$::errorInfo" }
proc tk_messageBox {args} { log "message: [dict get $args -message]"; return ok }
proc shot {name} {
    update; after 400; update
    exec import -window [wm frame .vmdance] [file join $::figs $name.png]
    log "wrote $name.png"
}
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
if {[real_cli] ne ""} { use_cli }
set m [load_ref heptapeptide]
mol modstyle 0 $m Licorice 0.2 12 12
display resetview
set G ::VMDance::GUI
set S ${G}::S
set w [vmdance]
${G}::set_appearance 12 medium flat
update
set ${S}(molid) $m
${G}::refresh_molecules
set ${S}(sel) backbone
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
set ${S}(k_kmeans) 6
set ${S}(p_kmeans_kinit) CompSim
${G}::_count
${G}::show_pane setup
shot setup
${G}::cluster
wait_idle
vmdance select 2
${G}::show_tab populations
shot window
foreach key [dict keys [set ${G}::tabs]] {
    if {$key in {elbow sweep}} continue
    ${G}::show_tab $key
    shot plot_$key
}
set ${S}(eb_from) 2
set ${S}(eb_to) 12
${G}::elbow
wait_idle
${G}::show_tab elbow
update
set c $w.pw.right.nb.elbow.c
lassign [::VMDance::Plot::area $c] x0 y0 x1 y1
# (drawn by Tk before the picture: idle tasks only, so that no redraw
# wipes the panel)
${G}::_hover elbow $c [::VMDance::Plot::X $c 6] [expr {($y0 + $y1) / 2}]
update idletasks
exec import -window [wm frame .vmdance] [file join $::figs plot_elbow.png]
log "wrote plot_elbow.png ([llength [$c find withtag partition]] items of the panel)"
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a eq "kmeans"}] }
foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k in {StratAll StratReduced CompSim}}] }
set ${S}(gr_from) 3
set ${S}(gr_to) 10
${G}::_grid_count
${G}::sweep
wait_idle
${G}::show_tab sweep
${G}::show_pane scans
shot plot_sweep
# the run of k 6 again, and its questions
vmdance run 1
${G}::prime
wait_idle
${G}::similarity
wait_idle
${G}::show_pane tools
shot tools
${G}::show_pane results
vmdance select 2
${G}::show_tab timeline
shot results
set ${S}(show_opts) 1
${G}::panels_changed
${G}::show_tab transitions
shot options
set ${S}(show_opts) 0
${G}::panels_changed
# 3D: every representative, in its colour
set ${S}(v3d_reps) 1
set ${S}(v3d_style) Licorice
set ${S}(v3d_sel) backbone
${G}::draw_changed
${G}::show_pane v3d
shot pane_3d
mol off $m
mol on $m
foreach i [lsort -integer -decreasing [lmap i [lsearch -all [lrepeat [molinfo $m get numreps] x] x] {set i}]] {
    if {[mol repname $m $i] ni [lmap e $::VMDance::Viz::owned {lindex $e 1}]} { mol showrep $m $i 0 }
}
display projection orthographic
display depthcue off
axes location off
color Display Background white
display resize 900 700
display update
set r [expr {"TachyonInternal" in [render list] ? "TachyonInternal" : "snapshot"}]
if {[catch {::VMDance::Figures::render_3d [file join $::figs 3d.png] $r} err]} { log "3D: $err" } else { log "wrote 3d.png ($r)" }
# figures of the plots, as the figures dialog makes them
set ${S}(v3d_reps) 0
${G}::draw_changed
foreach f [vmdance figures $::figs -plots {populations timeline transitions tree silhouette elbow} -formats png -width 700 -height 420 -dpi 110 -prefix figure] {
    log "wrote [file tail $f]"
}
} err]} { log "ERROR $err\n$::errorInfo" }
close $::logf
quit
