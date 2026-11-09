# Windowed test of what the review of the window's use changed in it: the
# frames of Setup after a scan's k and for another molecule, the tables'
# row colours, the note under the Fit box, the Timeline's shading and its
# shares, the Silhouette's two kinds and its axis, the Elbow's strip, rings
# and words, the Map's representatives and scale, the Profiles of many
# clusters, the groups by halves and how unlike they are, the clusters
# numbered by size, eQUAL's radius from the frames, the time per frame and
# the distances as lengths, a cancelled scan's values kept, the figures'
# sizes, the messages' fields, the tabs' tips.
#   cd <VMDance>
#   vmd -dispdev win -e tests/test_ux_gui.tcl < /dev/null; grep -E "FAIL|RESULT" tests/out/ux_gui.log
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::logf [open [file join $::out ux_gui.log] w]
fconfigure $::logf -buffering line
rename puts _puts
proc puts {args} {
    if {[llength $args] == 1} { _puts $::logf [lindex $args 0] } else { _puts {*}$args }
}
set ::bgerrors {}
proc bgerror {msg} { lappend ::bgerrors $msg; puts "BGERROR $msg\n$::errorInfo" }
set ::messages {}
proc tk_messageBox {args} {
    lappend ::messages [dict get $args -message]
    puts "  (message: [dict get $args -message])"
    return ok
}
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}
# The texts drawn on a plot, and whether it drew without an error.
proc texts {c} { lmap i [$c find all] {expr {[$c type $i] eq "text" ? [$c itemcget $i -text] : [continue]}} }
proc drawn {key} {
    set c .vmdance.pw.right.nb.$key.c
    ::VMDance::GUI::show_tab $key; update
    ::VMDance::GUI::redraw; update
    expr {"Plot error" ni [texts $c] && [llength [$c find all]] > 0}
}

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
set G ::VMDance::GUI
set S ${G}::S
set R ::VMDance::Results
if {[real_cli] eq ""} {
    skip "every check" "no mdance-cli (MDANCE_CLI, or CPP-MDANCE beside the plugin)"
    done
    close $::logf
    quit
}
use_cli
set m [load_system 3ptb]
set w [vmdance]
update
set ${S}(molid) $m
${G}::refresh_molecules
set ${S}(sel) "protein and name CA"
set ${S}(k_kmeans) 3
set ${S}(p_kmeans_kinit) KmeansPP
${G}::_count
${G}::cluster
wait_idle
set pc $w.pw.right.nb

# --- Setup's frames -------------------------------------------------------------------------
vmdance elbow -mol $m -sel "protein and name CA" -from 2 -to 4 -kinit KmeansPP -quiet 1
vmdance elbow load 3
update
check "a scan's k made the clustering: Setup's Frames stay \"All frames\" (its record names the last frame)" [expr {
    [set ${S}(framemode)] eq "all" && [set ${S}(last)] == -1 && [dict get [${R}::request] last] == 99}]
vmdance -mol $m -sel "protein and name CA" -k 3 -kinit KmeansPP -first 10 -last 60 -quiet 1
update
check "  a run of a range of frames: Setup shows the range" [expr {[set ${S}(framemode)] eq "range" && [set ${S}(first)] == 10 && [set ${S}(last)] == 60}]
set m2 [load_system two_state]
${G}::refresh_molecules
set ${S}(molname) [dict get [::VMDance::Mol::choices] $m2]
${G}::_mol_chosen
update
check "  another molecule chosen: all its frames again, said (the range was the first one's)" [expr {
    [set ${S}(framemode)] eq "all" && [set ${S}(molid)] == $m2 && [string match "*Frames: all of them again (the range 10 to 60 was molecule $m's)*" [set ${S}(status)]]}]
set ${S}(molname) [dict get [::VMDance::Mol::choices] $m]
${G}::_mol_chosen
vmdance run 1
update

# --- the tables' row colours ----------------------------------------------------------------
set tree [set ${G}::tree]
set style [$tree cget -style]
if {$style eq ""} { set style Treeview }
set catchall 0
foreach {state colour} [ttk::style map $style -background] { if {$state eq ""} { set catchall 1 } }
check "the table's rows keep their colours: each cluster's tint, and no colour of the style for every state" [expr {
    !$catchall && [$tree tag configure c0 -background] ne "" && [$tree tag configure c0 -background] ne [$tree tag configure c1 -background]}]

# --- the note under the Fit box -------------------------------------------------------------
set fn [set ${G}::page(setup)].input.fn
${G}::_count
check "Fit off, frames that are superposed: the note says so, in the muted colour" [expr {
    [string match "Not fitted. From the first frame: * Å as they are, * Å fitted: the frames look superposed." [set ${S}(fitnote)]] && [$fn cget -foreground] eq ""}]
set m3 [load_system 3ptb]
set all [atomselect $m3 all]
for {set f 1} {$f < 100} {incr f} { $all frame $f; $all move [transmult [transoffset [list [expr {0.4 * $f}] 0 0]] [transaxis z [expr {3.0 * $f}] deg]] }
$all delete
${G}::refresh_molecules
set ${S}(molname) [dict get [::VMDance::Mol::choices] $m3]
${G}::_mol_chosen
${G}::_count
check "  frames that tumble: a warning, with the two distances and what to do" [expr {
    [string match "Not fitted. From the first frame: * Å as they are, * Å fitted: the frames do not look superposed. Tick Fit*" [set ${S}(fitnote)]] &&
    [$fn cget -foreground] eq "#a3483b"}]
set ${S}(fitsel) "name XYZ"
set ${S}(fit) 1
${G}::_fit_changed
check "  Fit ticked with atoms the molecule has not: on the clustered atoms, said; the note counts them" [expr {
    [set ${S}(fitsel)] eq "protein and name CA" && [string match "Fit: on the clustered atoms*" [set ${S}(status)]] &&
    [string match "Fitted on 223 atoms*" [set ${S}(fitnote)]] && [$fn cget -foreground] eq ""}]
${G}::cluster
wait_idle
check "  a fitted run: its summary and its name say it" [expr {
    [string match "*× 223 atoms, fitted on protein and name CA: 3 clusters*" [set ${S}(summary)]] && [string match "*, fitted" [set ${S}(run_label)]]}]
set ${S}(fit) 0
${G}::_fit_changed
vmdance run 1
update
check "  an unfitted one: \"not fitted\"; the status line is the run switched to" [expr {
    [string match "*atoms, not fitted: 3 clusters*" [set ${S}(summary)]]}]
mol delete $m3
mol delete $m2

# --- the Silhouette --------------------------------------------------------------------------
set c $pc.silhouette.c
set ${S}(sl_kind) centroid
check "Silhouette from the mean structures: drawn from 0 (k-means has none below), titled so, the mean above the plot" [expr {
    [drawn silhouette] && $::VMDance::Plot::G($c,xmin) == 0 && "Silhouette (from the clusters' mean structures)" in [texts $c] &&
    [lindex [$c coords [lindex [$c find withtag mean] end]] 1] < $::VMDance::Plot::G($c,y0)}]
set ${S}(sl_kind) pairs
check "  from every frame: titled so; the axis from the lowest value" [expr {
    [drawn silhouette] && "Silhouette (from every frame, squared distances)" in [texts $c] && $::VMDance::Plot::G($c,xmin) <= 0}]
set ${S}(sl_kind) centroid

# --- the Elbow -------------------------------------------------------------------------------
set ${S}(eb_from) 2; set ${S}(eb_to) 6; set ${S}(eb_stab) 1
${G}::elbow
wait_idle
set c $pc.elbow.c
check "Elbow with stability: a strip of bars under the scores, rings on what it suggests, and its words" [expr {
    [drawn elbow] && [llength [$c find withtag stability]] >= 5 && [llength [$c find withtag mark]] >= 2 &&
    [llength [lsearch -all -glob [texts $c] "ringed · Davies–Bouldin: lowest*"]] == 1 && "Stability" in [texts $c]}]
check "  the scan's box says what it points to" [string match "Last scan: *Davies–Bouldin: lowest at k *Calinski–Harabasz: highest at k *" [set ${S}(eb_info)]]
set ${S}(eb_show) explained
check "  the variance explained: drawn, a share of 100" [expr {[drawn elbow] && "Variance the clusters explain (%)" in [texts $c] && $::VMDance::Plot::G($c,ymax) <= 110}]
set ${S}(eb_show) both
${G}::_hover elbow $c [::VMDance::Plot::X $c 3] [expr {$::VMDance::Plots::H($c,elbowbot) - 5}]
check "  the pointer over the strip reads that k too, with the variance explained" [string match "k = 3*of the variance explained*" [set ${S}(readout)]]
${G}::_leave elbow $c

# --- the Map ---------------------------------------------------------------------------------
${G}::map
wait_idle
set c $pc.map.c
set ${S}(mp_colour) cluster
set ${S}(mp_reps) 1
drawn map
set g ::VMDance::Plot::G
set sx [expr {([set ${g}($c,xmax)] - [set ${g}($c,xmin)]) / ([set ${g}($c,x1)] - [set ${g}($c,x0)])}]
set sy [expr {([set ${g}($c,ymax)] - [set ${g}($c,ymin)]) / ([set ${g}($c,y1)] - [set ${g}($c,y0)])}]
check "Map: the two components to one scale; each cluster's representative ringed and numbered" [expr {
    [near $sx $sy 1e-6] && [llength [$c find withtag rep]] == 9 && [llength [$c find withtag point]] == 100}]
set ${S}(mp_reps) 0
check "  without them when unticked" [expr {[drawn map] && ![llength [$c find withtag rep]]}]
set ${S}(mp_reps) 1
set ${S}(mp_colour) group
check "  coloured by group without groups: by cluster, said" [expr {[drawn map] && [llength [lsearch -all -glob [texts $c] "no groups*coloured by cluster"]] == 1}]
set ${S}(k_kmeans) 4
${G}::cluster
wait_idle
check "  a new clustering of the same frames keeps the map" [expr {[dict size [${R}::extra map]] > 0 && [drawn map]}]
set ${S}(sel) "protein and name CA and resid 20 to 120"
${G}::cluster
wait_idle
check "  of other atoms: no map" [expr {![dict size [${R}::extra map]]}]
set ${S}(sel) "protein and name CA"

# --- groups by halves, how unlike, the reference ---------------------------------------------
set P [set ${G}::page(results)]
$P.gp.bt.half invoke
update
check "Halves: two groups of the clustered frames; the line under the box says how unlike they are" [expr {
    [${R}::group_names] eq {first second} && [set ${S}(gp_ranges)] eq "first 0-49 second 50-99" &&
    [string match "first: 50, second: 50. First and second: divergence *cluster * differs most*" [set ${S}(gp_info)]]}]
${G}::groups_blocks 4
check "  four blocks" [expr {[${R}::group_names] eq {part1 part2 part3 part4}}]
${G}::groups_blocks 1
check "  one block: refused" [string match "No groups:*whole number of blocks from 2*" [lindex $::messages end]]
set cb $P.gp.pf.n
${G}::_ref_values $cb
check "the profiles' reference by name: \"the largest\", then the clusters" [expr {[$cb get] eq "the largest" && [$cb cget -values] eq {{the largest} {cluster 0} {cluster 1} {cluster 2} {cluster 3}}}]
$cb set "cluster 2"
${G}::_ref_chosen $cb
set got [set ${S}(pf_reference)]
set ${S}(pf_reference) -1
check "  a cluster chosen is its number; -1 shows as the largest" [expr {$got == 2 && [$cb get] eq "the largest"}]
# (a run without groups: the ranges set for another are not left in the box)
vmdance run 1
update
check "  a run without groups: the box is emptied of the other run's ranges" [expr {[set ${S}(gp_ranges)] eq "" && [set ${S}(gp_info)] eq "No groups for this clustering."}]

# --- the Profiles of many clusters ------------------------------------------------------------
set ${S}(k_kmeans) 20
${G}::cluster
wait_idle
${G}::profiles
wait_idle
set c $pc.profiles.c
set ${S}(pf_show) clusters
drawn profiles
set live [llength [lsearch -all -not -exact [${R}::sizes] 0]]
set grey [llength [lmap i [$c find withtag series] {expr {[$c itemcget $i -fill] eq "#d3d7de" ? 1 : [continue]}}]]
check "Profiles of $live clusters: the eight largest in colour, the others grey, said" [expr {
    $grey > 0 && [llength [lsearch -all -glob [texts $c] "in colour: the 8 largest clusters of $live*"]] == 1}]
vmdance select 5
update
drawn profiles
check "  a cluster selected: it alone in colour" [expr {[llength [lsearch -all -glob [texts $c] "in colour: the selected cluster of $live"]] == 1}]
vmdance select clear
# (a click on a curve selects its cluster)
drawn profiles
lassign $::VMDance::Plots::H($c,profiles) view res chs series
set se [lindex $series end]
set px [::VMDance::Plot::X $c 10]; set py [::VMDance::Plot::Y $c [lindex $se 2 10]]
${G}::_hover profiles $c $px $py
set said [set ${S}(readout)]
${G}::_click profiles $c $px $py 0
update
check "  the readout names the curve under the pointer; a click selects its cluster" [expr {
    [string match "residue *: cluster * Å*click = select it" $said] && [llength [${R}::selected]] == 1}]
vmdance select clear
set ${S}(td_view) tree
set ${S}(td_labels) 1
set c $pc.tree.c
drawn tree
check "Tree of $live leaves: their labels upright when they do not fit side by side" [expr {
    [llength [lmap i [$c find withtag label] {expr {[$c itemcget $i -angle] == 90 ? 1 : [continue]}}]] > 0 || [llength [$c find withtag label]] == $live}]

# --- the clusters by size ---------------------------------------------------------------------
set nruns [llength [${R}::run_list]]
${G}::renumber
update
set s [${R}::sizes]
check "Number its clusters by size: a new run, the largest 0, said" [expr {
    [llength [${R}::run_list]] == $nruns + 1 && $s eq [lsort -integer -decreasing $s] && [string match "The clusters numbered by size*" [set ${S}(status)]]}]
${G}::renumber
check "  already by size: said, no run made" [expr {[llength [${R}::run_list]] == $nruns + 1 && [string match "*numbered by size already*" [set ${S}(status)]]}]

# --- eQUAL's radius from the frames -----------------------------------------------------------
set ${S}(algorithm) equal
${G}::_algorithm_changed
update
set E [set ${G}::page(scans)].eb
${G}::show_pane scans
update
check "eQUAL chosen: the scan's box shows its radii, not k; the stability is NANI's" [expr {
    [winfo manager $E.q] ne "" && [lsearch [grid slaves $E] $E.r] < 0 && [$E.st instate disabled]}]
check "  no radius yet: the note under it says what it is" [string match "No radius yet*half the RMSD² of two frames." [set ${S}(eq_note)]]
${G}::radii
wait_idle
check "  Suggest: a range for the scan and a radius for Setup, from the frames; the radius in RMSD" [expr {
    [set ${S}(eb_rfrom)] > 0 && [set ${S}(eb_rfrom)] < [set ${S}(eb_rto)] && [set ${S}(p_equal_threshold)] > 0 &&
    [string match "Radii from 100 frames: scan * to * every *" [set ${S}(status)]] &&
    [string match "A frame joins a cluster when it is within * Å (RMSD) of its seed*" [set ${S}(eq_note)]]}]
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
update
check "  K-means again: k, not the radii" [expr {[lsearch [grid slaves $E] $E.r] >= 0 && [lsearch [grid slaves $E] $E.q] < 0 && [$E.st instate !disabled]}]
${G}::show_pane tools
update
set K [set ${G}::page(tools)].pk
check "Pick frames: the most diverse are a percentage, said in the field's name" [expr {[$K.l1 cget -text] eq "% of the frames"}]
set ${S}(pk_method) outliers
${G}::_pick_sync
check "  the outliers: a number" [expr {[$K.l1 cget -text] eq "How many"}]
set ${S}(pk_method) diversity
${G}::_pick_sync

# --- the time per frame, the distances as lengths ---------------------------------------------
vmdance run 1
update
set c $pc.timeline.c
set ${S}(tl_view) lanes
set ${S}(plot_time) "0.1 ns"
${G}::_opt_entry plot_time
check "Time per frame 0.1 ns: the Timeline reads in time" [expr {[drawn timeline] && "Time (ns)" in [texts $c] && "Frame" ni [texts $c]}]
${G}::_hover timeline $c [::VMDance::Plot::X $c 50] [expr {([set ${g}($c,y0)] + [set ${g}($c,y1)]) / 2}]
check "  a frame's readout gives its time" [string match "frame 50 (5 ns): *" [set ${S}(readout)]]
set c $pc.residence.c
set ${S}(rs_show) mean
check "  the Residence too; the longest stay beside the mean" [expr {
    [drawn residence] && "Mean stay (ns)" in [texts $c] && [llength [lsearch -all -glob [texts $c] "* · longest *"]] > 0}]
set ${S}(plot_time) "fast"
${G}::_opt_entry plot_time
check "  not a time: emptied, said; frames again" [expr {
    [set ${S}(plot_time)] eq "" && [string match "Time per frame: a number and its unit*" [set ${S}(status)]] && [drawn timeline] && "Frame" in [texts $pc.timeline.c]}]
check "  a session keeps a time, not what is not one" [expr {[${G}::_state_ok plot_time "2 ps"] && [${G}::_state_ok plot_time ""] && ![${G}::_state_ok plot_time "2 parsecs"] && ![${G}::_state_ok plot_time "010 ns"]}]
set msd [lindex [${R}::table] 0 3]
set ${S}(plot_len) a
set c $pc.compactness.c
set ${S}(cp_show) msd
check "Distances as lengths: the table's and the plots' in Å, their square roots" [expr {
    [drawn compactness] && [$tree heading msd -text] eq "√MSD (Å)" && [$tree heading spread -text] eq "To rep. (Å)" &&
    [near [lindex [$tree item c0 -values] 3] [format %.4g [expr {sqrt($msd)}]] 1e-3] && "Root mean square deviation within (Å)" in [texts $c]}]
set ${S}(tl_view) msd
set ${S}(ds_show) centroids
check "  the Timeline's distances, the Distances and the Tree too" [expr {
    [drawn timeline] && "RMSD from its representative (Å)" in [texts $pc.timeline.c] && [drawn distances] && [drawn tree] &&
    "RMSD between mean structures (Å)" in [texts $pc.tree.c]}]
set ${S}(plot_len) a2
check "  squared again: the table follows" [expr {[drawn compactness] && [$tree heading msd -text] eq "MSD (Å²)" && [near [lindex [$tree item c0 -values] 3] [format %.4g $msd] 1e-3]}]
set ${S}(tl_view) lanes

# --- the Timeline of a long trajectory ---------------------------------------------------------
if {![file exists [file join $::refruns inputs 1_heptapeptide backbone_aligned.dcd]]} {
    skip "the Timeline's shading, shares and dots" "MDANCE's reference runs are not here (MDANCE_REF_RUNS)"
} else {
    set mt [load_ref heptapeptide]
    vmdance -mol $mt -sel "name CA" -k 3 -kinit KmeansPP -quiet 1
    update
    set c $pc.timeline.c
    set ${S}(tl_view) lanes
    drawn timeline
    check "Timeline of 6001 frames: more frames than pixels, the lanes shaded by share, said" [expr {
        $::VMDance::Plots::H($c,tldense) ne "" && [llength [lsearch -all -glob [texts $c] "the darker, the larger the share*"]] == 1}]
    ${G}::_hover timeline $c [expr {([set ${g}($c,x0)] + [set ${g}($c,x1)]) / 2}] [expr {([set ${g}($c,y0)] + [set ${g}($c,y1)]) / 2}]
    check "  the readout: the frames under the pointer, by cluster" [string match "frames * to *: cluster *" [set ${S}(readout)]]
    set ${S}(tl_view) shares
    drawn timeline
    set nb [llength [vmdance timeline]]
    check "  the shares, window by window: stacked bars, their number said" [expr {
        [llength [$c find withtag bar]] >= 118 && [llength [lsearch -all -glob [texts $c] "118 windows of 50 frames"]] == 1 && [set ${g}($c,ymax)] == 100}]
    set ${S}(tl_windows) 10
    drawn timeline
    check "  ten windows, as asked" [expr {[llength [lsearch -all -glob [texts $c] "10 windows of 600 frames"]] == 1 && [llength [$c find withtag bar]] <= 30}]
    set ${S}(tl_windows) 0
    set ${S}(tl_view) cumulative
    drawn timeline
    check "  the shares so far: a line a cluster, the frame by which all are seen" [expr {
        [llength [$c find withtag series]] == 3 && [llength [lsearch -all -glob [texts $c] "dotted: every cluster seen by frame *"]] == 1}]
    set ${S}(tl_view) msd
    drawn timeline
    check "  the distances: a dot a frame and their running median, no line through 6001 frames" [expr {
        [llength [$c find withtag series]] == 1 && [llength [$c find withtag raster]] == 1 && [llength [lsearch -all -glob [texts $c] "a dot a frame*"]] == 1}]
    set ${S}(tl_view) lanes
    # (a figure: shapes, finer than its pixels, not an image)
    set fd [file join $::out ux_figs]
    file delete -force $fd
    set fc [::VMDance::Figures::render_plot timeline 241 181 0]
    check "  in a figure the lanes are shapes, four columns a point: sharp at any resolution" [expr {
        [llength [$fc find withtag raster]] > 200 && ![llength [lmap i [$fc find withtag raster] {expr {[$fc type $i] eq "image" ? 1 : [continue]}}]]}]
    destroy $fc
    mol delete $mt
    vmdance run 1
    update
}

# --- figures -----------------------------------------------------------------------------------
set F ::VMDance::Figures
check "a figure's length: points, or with a unit" [expr {
    [${F}::points w 241] == 241 && [${F}::points w 85mm] == 241 && [${F}::points w 8.5cm] == 241 && [${F}::points w 3.35in] == 241 &&
    [string match "*number of points, or one with a unit*" [err {::VMDance::Figures::points w 85furlongs}]] && [string match "*number of points*" [err {::VMDance::Figures::points w 010}]]}]
set fd [file join $::out ux_figs]
file delete -force $fd
if {[${F}::ghostscript] eq ""} {
    skip "the figures' sizes" "no Ghostscript"
} else {
    set files [vmdance figures $fd -plots {populations} -formats png -size column]
    set img [image create photo -file [lindex $files 0]]
    check "-size column: 85 mm wide at 300 dpi, with the size's text" [expr {[image width $img] == 1004 && [image height $img] == 754}]
    image delete $img
    set files [vmdance figures $fd -plots {populations} -formats png -width 60mm -height 60mm -dpi 100]
    set img [image create photo -file [lindex $files 0]]
    check "  a width and a height in mm; smaller than a column" [expr {[image width $img] == 236 && [image height $img] == 236}]
    image delete $img
    check "  a size that is none, a figure too small: refused" [expr {
        [string match "*-size must be one of column, two-columns, slide, screen*" [err {vmdance figures $fd -size poster}]] &&
        [string match "*160 to 6000 points*" [err {vmdance figures $fd -plots populations -width 30mm}]]}]
    # (a plot with only a message to show: no figure of the message)
    set ${S}(cp_show) isim
    file delete -force $fd
    set files [vmdance figures $fd -plots {populations compactness} -formats png]
    check "  a plot that has only a message to show is left out, and named" [expr {
        [llength $files] == 1 && [lindex $::VMDance::Figures::skipped 0] eq "compactness" && [string match "No similarity yet*" [lindex $::VMDance::Figures::skipped 1]]}]
    check "  alone: refused, saying why" [string match "*nothing to draw: compactness (No similarity yet*" [err {vmdance figures $fd -plots compactness -formats png}]]
    set ${S}(cp_show) msd
}

# the dialog: a size for where the figure goes
${G}::figure_dialog
update
set fz $w.figures.f.c.p.size
set ${S}(fig_size) column
${G}::_figure_size
check "the Figures dialog: \"A journal's column\" sets the width, the height and the text, and says the size in mm" [expr {
    [set ${S}(fig_width)] == 241 && [set ${S}(fig_height)] == 181 && [set ${S}(fig_text)] == 8 && [set ${S}(fig_mm)] eq "points: 85 × 64 mm" &&
    [winfo exists $fz.for] && [winfo exists $fz.cur]}]
set ${S}(fig_width) 120mm
${G}::_figure_mm
set mm1 [set ${S}(fig_mm)]
set ${S}(fig_width) wide
${G}::_figure_mm
check "  a width with its unit is read; one that is no size says what is taken" [expr {$mm1 eq "points: 120 × 64 mm" && [string match "points, or 85mm*" [set ${S}(fig_mm)]]}]
set ${S}(fig_size) screen
${G}::_figure_size
destroy $w.figures

# --- a cancelled scan keeps what it scanned ----------------------------------------------------
use_fake
fake_env MDANCE_FAKE_SLEEP 1
vmdance elbow clear
set ${S}(eb_from) 2; set ${S}(eb_to) 8; set ${S}(eb_stab) 0
${G}::elbow
after 3600 {::VMDance::GUI::cancel}
wait_idle
fake_env
set e $::VMDance::Results::elbow
check "an elbow scan cancelled at its fourth or fifth k: the values scanned before are kept as the scan, said" [expr {
    [dict size $e] && [llength [dict get $e records]] >= 2 && [llength [dict get $e records]] < 7 &&
    [dict get $e request ks] eq [lmap r [dict get $e records] {dict get $r k}] &&
    [string match "Cancelled: the * values scanned before, 2 to *, are kept as the scan." [set ${S}(status)]] && [drawn elbow]}]
fake_env MDANCE_FAKE_SLEEP 3
vmdance elbow clear
${G}::elbow
after 500 {::VMDance::GUI::cancel}
wait_idle
fake_env
check "  cancelled before two values: nothing kept" [expr {![dict size $::VMDance::Results::elbow] && [string match "Cancelled; what was there is kept." [set ${S}(status)]]}]
use_cli

# --- messages, tips -----------------------------------------------------------------------------
check "a message of the core's names the window's fields under it" [expr {
    [${G}::_fields "-sel: invalid atom selection \"x\""] eq "-sel: invalid atom selection \"x\"\n\nIn the window: -sel is Atoms." &&
    [string match "*In the window: -percentage is \"Seeds from %\"; -k is Clusters (k)." [${G}::_fields "raise -percentage to 16, or use a smaller -k"]] &&
    [${G}::_fields "nothing named here"] eq "nothing named here" && [${G}::_fields "a self-evident, well-known case"] eq "a self-evident, well-known case"}]
set ${S}(sel) "protien"
set n0 [llength $::messages]
${G}::cluster
update
check "  as the window shows it" [expr {[llength $::messages] == $n0 + 1 && [string match "Not clustered:*-sel: invalid atom selection*In the window: -sel is Atoms." [lindex $::messages end]]}]
set ${S}(sel) "protein and name CA"
${G}::_tab_tip $pc 200 10
check "a plot's tab says its name and what it shows" [expr {
    [info exists ::VMDance::Tip::text($pc)] && [regexp {^[A-Z][a-z-]+: [a-z]} $::VMDance::Tip::text($pc)]}]
::VMDance::Tip::_hide
${G}::help
update
set ht [$w.help.t get 1.0 end]
destroy $w.help
check "the quick guide: the first step, how many clusters, comparing parts of the frames, all thirteen plots" [expr {
    [string match "*Load a trajectory in VMD*How many clusters*Compare parts of the frames*" $ht] &&
    [string match "*Make-up:*Map:*Profiles:*" $ht]}]
check "every plot still draws; no background error" [expr {[llength [lmap k [dict keys [set ${G}::tabs]] {expr {[drawn $k] ? [continue] : $k}}]] == 0 && ![llength $::bgerrors]}]
done
} err]} { puts "FAIL test_ux_gui crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
close $::logf
quit
