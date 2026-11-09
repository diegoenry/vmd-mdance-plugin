# Windowed test of the window's layout on small screens and at large text
# (the review of 2026-11-09, its B4 to B8 and B18, §3.1, §3.2, §3.5): the
# dialogs fit a laptop's screen and scroll; the plot options are narrow, of
# one width, and reachable on a 1024-wide screen; the left panel goes back
# to its width; the window can be made short; the sizes of Settings are
# real; the tables' columns hold their values; the toolbar wraps; the line
# under the plots has two lines.
#   cd <VMDance>
#   VMDANCE_OUT=/tmp/mdv vmd -dispdev win -e tests/test_ux_layout.tcl < /dev/null
#   grep -E "FAIL|RESULT" /tmp/mdv/ux_layout.log
# (windowed VMD does not reliably show stdout: everything goes to
# ux_layout.log. The screen's size is given to the window, `screen`: the
# checks are the same on any display.)
set ::root [expr {[info exists ::env(VMDANCE_ROOT)] ? $::env(VMDANCE_ROOT) : [pwd]}]
source [file join $::root tests common.tcl]
set ::logf [open [file join $::out ux_layout.log] w]
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
    if {[dict exists $args -type] && [dict get $args -type] eq "okcancel"} { return ok }
    return yes
}
set ::next_file ""
proc tk_getSaveFile {args} { return $::next_file }
proc tk_getOpenFile {args} { return $::next_file }
proc tk_chooseDirectory {args} { return $::next_file }
proc wait_idle {} {
    while {$::VMDance::GUI::S(busy)} { vwait ::VMDance::GUI::S(busy) }
    update
}
# The window as on a screen of that size (the display's own is not asked).
proc on_screen {sw sh} {
    set ::VMDance::GUI::screen [list $sw $sh]
    ::VMDance::GUI::apply_appearance
    update
}
# A widget is shown whole within a window (its toplevel by default).
proc whole_in {wd {top ""}} {
    if {$top eq ""} { set top [winfo toplevel $wd] }
    expr {[winfo viewable $wd] &&
        [winfo rootx $wd] >= [winfo rootx $top] && [winfo rooty $wd] >= [winfo rooty $top] &&
        [winfo rootx $wd] + [winfo width $wd] <= [winfo rootx $top] + [winfo width $top] &&
        [winfo rooty $wd] + [winfo height $wd] <= [winfo rooty $top] + [winfo height $top]}
}
# A dialog opened: as tall as a screen less a title bar allows, its buttons
# whole in it.
proc dialog_fits {d sh} {
    update
    expr {[winfo height $d] <= $sh - 40 && [winfo reqheight $d] <= $sh - 40 && [whole_in $d.f.b.ok] && [whole_in $d.f.b.cancel]}
}

if {[catch {
package require vmdance
::VMDance::_load_tk
set ::VMDance::Prefs::file ""
use_fake
fake_env
set G ::VMDance::GUI
set S ${G}::S
set R ::VMDance::Results
# (a VMD whose startup file loads a plugin of another folder tests that
# one: vmd -startup <a file without it>)
check "the plugin tested is this folder's ([file dirname $::VMDance::libdir])" [expr {
    [file normalize [file dirname [file dirname $::VMDance::libdir]]] eq [file normalize $::root]}]
set m [load_system two_state]
set w [vmdance]
update
vmdance -mol $m -sel all -k 3 -kinit KmeansPP -quiet 1
update
check "the window, with a clustering" [expr {[winfo exists $w] && [${R}::nclusters] == 3}]
set tree [set ${G}::tree]; set swt [set ${G}::swtree]; set prt [set ${G}::prtree]
set zero [font measure MdvUI 0]

# --- 7, 8: the smallest window, and the sizes of Settings --------------------------------
on_screen 1920 1200
${G}::set_appearance 12 compact auto
update
lassign [wm minsize $w] mw12 mh12
lassign [${G}::needed_size] nw12 nh12
check "7: the smallest window is as tall as a plot needs, not as its tallest page ($mh12 of $nh12)" [expr {
    $mh12 >= 420 && $mh12 <= 520 && $mh12 < $nh12 - 100}]
check "  and as wide as its panels need ($mw12)" [expr {$mw12 == [lindex [${G}::min_size] 0] && $mw12 >= [winfo reqwidth $w.pw.left] + 460}]
wm geometry $w ${mw12}x${mh12}
update
${G}::show_pane tools
update
${G}::_pages_fit
update
set cv [winfo parent [set ${G}::page(tools)]]
check "  made that small: a plot of 200 pixels or more, the line under it and the status line whole, the page scrolling" [expr {
    [winfo height $w] == $mh12 && [winfo height $w.pw.right.nb.[set ${S}(tab)].c] >= 200 &&
    [whole_in $w.pw.right.rf $w] && [whole_in $w.sb $w] && [winfo manager [winfo parent $cv].sb] ne ""}]
set sizes {}
foreach win {compact medium large} {
    ${G}::set_appearance 12 $win
    update
    lappend sizes [list [winfo width $w] [winfo height $w]]
    if {![string match "*window [winfo width $w]×[winfo height $w],*" [set ${S}(status)]]} { puts "  $win: the status says [set ${S}(status)]" }
}
lassign $sizes c12 m12 l12
check "8: the window's sizes of Settings are three sizes ($sizes)" [expr {
    [lindex $c12 1] == 660 && [lindex $m12 1] >= 740 && [lindex $m12 1] >= $nh12 && [lindex $l12 1] >= 880 && [lindex $l12 1] >= $nh12 &&
    [lindex $c12 0] >= $mw12 && [lindex $c12 0] <= [lindex $m12 0] && [lindex $m12 0] < [lindex $l12 0]}]
check "  medium (a new user's) and large show every left page whole (no scroll bar)" [expr {[winfo manager [winfo parent $cv].sb] eq ""}]
check "  their names have no number ([dict values [set ${G}::window_names]])" [expr {
    ![regexp {[0-9]} [dict values [set ${G}::window_names]]] && [dict keys [set ${G}::window_names]] eq [dict keys [set ${G}::window_sizes]]}]
${G}::set_appearance 16 compact
update
lassign [wm minsize $w] mw16 mh16
check "  at 16 pt the smallest and the compact window follow the text ($mh16, [winfo height $w])" [expr {
    $mh16 > $mh12 && $mh16 <= 1.5 * $mh12 && [winfo height $w] == 880}]
${G}::set_appearance 12 compact
update
on_screen 1280 720
check "  on a 1280 × 720 screen: within it, less a title bar ([winfo width $w] × [winfo height $w])" [expr {
    [winfo width $w] <= 1240 && [winfo height $w] <= 680 && [lindex [wm minsize $w] 1] <= [winfo height $w]}]

# --- 6: the left panel goes back to its width ---------------------------------------------
on_screen 1920 1200
${G}::show_pane setup
update
set lw0 [winfo reqwidth $w.pw.left]
${G}::set_appearance 16 compact
update
${G}::show_pane tools
update
set lw16 [winfo reqwidth $w.pw.left]
${G}::set_appearance 12 compact
update
check "6: text 12, 16 with Tools shown, 12 again: the left panel as wide as before ($lw0, $lw16, [winfo reqwidth $w.pw.left])" [expr {
    $lw16 > $lw0 && [winfo reqwidth $w.pw.left] == $lw0 && [winfo width $w.pw.left] == $lw0}]
wm geometry $w [expr {$mw12 + 400}]x700
update
$w.pw sashpos 0 [expr {$lw0 + 200}]
update
set wide [winfo width $prt]
::VMDance::Theme::apply
update
${G}::_pages_fit
update
check "  the divider dragged right, the look made again: the panel asks for no more ([winfo reqwidth $w.pw.left]); its tables fill it" [expr {
    [winfo reqwidth $w.pw.left] == $lw0 && [winfo width $w.pw.left] == $lw0 + 200 && $wide > [winfo reqwidth [winfo parent $prt].tvh] &&
    [$prt column method -width] + [$prt column frame -width] >= $wide - 6}]
$w.pw sashpos 0 10
update
${G}::_clamp_sash
update
check "  dragged back: as narrow as before" [expr {[$w.pw sashpos 0] == $lw0}]
check "17: a divider stops at the panel's width as it is dragged" [expr {"MdvSash" in [bindtags $w.pw] &&
    [lsearch [bindtags $w.pw] MdvSash] > [lsearch [bindtags $w.pw] TPanedwindow] && [bind MdvSash <B1-Motion>] ne ""}]
${G}::apply_appearance
update

# --- 12, 14: the scroll bar's width, the notes ---------------------------------------------
on_screen 1280 720
${G}::show_pane setup
update
set PS [set ${G}::page(setup)]
set fs [winfo parent [winfo parent $PS]]
# (a window just tall enough for Setup as it is: HELM's is taller)
wm geometry $w [winfo width $w]x[expr {[winfo height $w] - [winfo height $fs.c] + [winfo reqheight $PS] + 6}]
update
${G}::_pages_fit
update
set g0 [wm geometry $w]
set had [winfo manager $fs.sb]
set ${S}(algorithm) helm
${G}::_algorithm_changed
update; after 100; update
set now [winfo manager $fs.sb]
check "12: Setup gains its scroll bar (HELM): the window and the panel as wide as before" [expr {
    $had eq "" && $now ne "" && [wm geometry $w] eq $g0 && [winfo reqwidth $w.pw.left] == $lw0 && [whole_in $fs.sb $w]}]
set ${S}(algorithm) kmeans
${G}::_algorithm_changed
update; after 100; update
${G}::apply_appearance
update
set floor 0
foreach key {setup results scans tools v3d} { set floor [expr {max($floor, [winfo reqwidth [set ${G}::page($key)]])}] }
set notes {}
set odd {}
foreach c [${G}::_descendants $w.pw.left] {
    if {[winfo class $c] ne "TLabel" || [$c cget -wraplength] eq "" || [$c cget -wraplength] <= 0} continue
    lappend notes $c
    set wl [$c cget -wraplength]
    # (a section's padding and border are between a note and its page)
    set room [expr {[winfo parent $c] eq [set ${G}::page([lindex [split $c .] 5])] ? 12 : 28}]
    if {$wl < $floor - 44 || $wl > $floor - 12 || [winfo reqwidth $c] > $floor - $room} { lappend odd $c $wl [winfo reqwidth $c] }
}
check "14: the [llength $notes] notes of the left pages wrap at the panel's width ($wl of $floor), and none asks for more than it ($odd)" [expr {
    [llength $notes] >= 8 && ![llength $odd] && $wl > 34 * $zero}]

# --- 9: the tables' columns ----------------------------------------------------------------
foreach a {kmeans divine helm} { set ${S}(gr_alg_$a) [expr {$a eq "kmeans"}] }
foreach k $::VMDance::Algo::kinits { set ${S}(gr_seed_$k) [expr {$k in {KmeansPP VanillaKmeansPP}}] }
set ${S}(gr_from) 2
set ${S}(gr_to) 3
${G}::_grid_count
${G}::sweep
wait_idle
${G}::show_pane scans
update; after 50; update
set cut {}
set sum 0
foreach c [$swt cget -columns] {
    set need [font measure MdvUI [$swt heading $c -text]]
    foreach it [$swt children {}] { set need [expr {max($need, [font measure MdvUI [$swt set $it $c]])}] }
    if {[$swt column $c -width] < $need + 8} { lappend cut $c }
    incr sum [$swt column $c -width]
}
check "9: the sweep table: [llength [$swt children {}]] rows, every column as wide as its heading and its widest value (cut: $cut)" [expr {
    [llength [$swt children {}]] == 4 && ![llength $cut] && "VanillaKmeansPP" in [lmap it [$swt children {}] {$swt set $it seed}] &&
    "KMeans NANI" in [lmap it [$swt children {}] {$swt set $it alg}]}]
check "  and all of them within the table ($sum of [winfo width $swt])" [expr {$sum <= [winfo width $swt]}]
set grown [expr {[winfo reqwidth $w.pw.left] - $lw0}]
check "  the left panel wider by the columns' need ($grown pixels for VanillaKmeansPP), and narrow again without them" [expr {$grown >= 0 && $grown < 12 * $zero}]
vmdance sweep clear
update; after 50; update
check "  (the sweep cleared: [winfo reqwidth $w.pw.left])" [expr {[winfo reqwidth $w.pw.left] == $lw0}]

# --- 10: the clusters' table, and the wheel ------------------------------------------------
${G}::show_pane results
update
check "10: the clusters' table shows 5 rows for 3 clusters" [expr {[$tree cget -height] == 5 && [llength [$tree children {}]] == 3}]
set PR [set ${G}::page(results)]
set cv [winfo parent $PR]
check "  what is under it starts within a 1280 × 720 screen's window: the buttons under the table, and 60 pixels more" [expr {
    [whole_in $PR.b $w] && [winfo rooty $PR.b] + [winfo height $PR.b] + 60 <= [winfo rooty $cv] + [winfo height $cv]}]
vmdance -mol $m -sel all -k 8 -kinit KmeansPP -quiet 1
update; after 50; update
set h8 [$tree cget -height]
vmdance -mol $m -sel all -k 20 -kinit KmeansPP -quiet 1
update; after 50; update
check "  8 rows for 8 clusters, 12 for 20 ($h8, [$tree cget -height])" [expr {$h8 == 8 && [$tree cget -height] == 12}]
wm geometry $w [join [wm minsize $w] x]
update
${G}::_pages_fit
update
set cv [winfo parent $PR]
$cv yview moveto 0
$tree yview moveto 0
update
set scrolls [expr {[lindex [$tree yview] 1] < 1}]
${G}::_page_wheel $tree -1
update
set y20 [lindex [$cv yview] 0]
vmdance run 1
update; after 50; update
$cv yview moveto 0
update
${G}::_page_wheel $tree -1
update
check "  the wheel over the table: a table with more rows than it shows keeps it, one that shows all moves the page ($scrolls, $y20, [lindex [$cv yview] 0])" [expr {
    $scrolls && $y20 == 0 && [lindex [$tree yview] 1] == 1 && [lindex [$cv yview] 0] > 0}]
${G}::apply_appearance
update

# --- 13: the line under the plots ----------------------------------------------------------
set rf $w.pw.right.rf
set room [expr {[winfo width $rf] - 14}]
set lh [font metrics MdvUISmall -linespace]
check "13: the line under the plots is two lines tall" [expr {[winfo height $rf] >= 2 * $lh && [winfo height $rf] < 3 * $lh + 8}]
set words "the frames in each cluster and where they are"
set text $words
while {[font measure MdvUISmall $text] < 1.5 * $room} { append text " · $words" }
set ${S}(readout) $text
update
set shown [split [set ${S}(readout_shown)] \n]
check "  a text of a line and a half is shown whole, on two lines" [expr {[llength $shown] == 2 && [join $shown " "] eq $text &&
    [font measure MdvUISmall [lindex $shown 0]] <= $room && [font measure MdvUISmall [lindex $shown 1]] <= $room}]
set ${S}(readout) [string repeat "$words · " 40]
update
set shown [split [set ${S}(readout_shown)] \n]
check "  a longer one is cut at the end of the second, ending in …" [expr {[llength $shown] == 2 && [string match "*…" [lindex $shown 1]] &&
    [font measure MdvUISmall [lindex $shown 1]] <= $room && [font measure MdvUISmall [lindex $shown 1]] > 0.8 * $room}]
set ${S}(readout) "short"
update
check "  a short one as it is" [expr {[set ${S}(readout_shown)] eq "short"}]
${G}::_show_hint [set ${S}(tab)]

# --- 5: the plot options --------------------------------------------------------------------
on_screen 1920 1200
set ${S}(show_left) 1
set ${S}(show_opts) 1
${G}::panels_changed
update
set O $w.pw.opts
set longest 0
foreach spec [concat {*}[dict values [set ${G}::optspec]] [set ${G}::optall]] {
    if {[lindex $spec 0] ne "combo"} continue
    foreach v [dict values [lindex $spec 3]] { set longest [expr {max($longest, [font measure MdvUI $v])}] }
}
check "5: on a wide screen the left panel, the plots and the plot options side by side" [expr {
    [$w.pw panes] eq [list $w.pw.left $w.pw.right $O] && [set ${S}(show_left)] && [whole_in $O $w]}]
check "  the options ask for their longest choice and little more ([winfo reqwidth $O] pixels for $longest)" [expr {
    [winfo reqwidth $O] <= $longest + 12 * $zero}]
set widths {}
set short {}
foreach key [dict keys [set ${G}::tabs]] {
    ${G}::show_tab $key
    update
    lappend widths [list [winfo width $w] [winfo reqwidth $O] [lindex [wm minsize $w] 0]]
    foreach c [winfo children $O.body.$key] {
        if {[winfo class $c] ne "TCombobox" || ![winfo viewable $c]} continue
        set need [::tcl::mathfunc::max {*}[lmap v [$c cget -values] {font measure MdvUI $v}]]
        if {[winfo width $c] < $need + 16 || ![whole_in $c $w]} { lappend short $c }
    }
}
check "  one width for every plot: the panel's and the window's ([lsort -unique $widths])" [expr {[llength [lsort -unique $widths]] == 1}]
check "  every chooser shows its longest choice ($short)" [expr {![llength $short]}]
${G}::show_tab populations
update
# a screen with no room for both panels
set ${S}(show_opts) 0
${G}::panels_changed
foreach {sw sh} {1024 768 1280 720 1366 768} {
    on_screen $sw $sh
    set wd [winfo width $w]
    # (whether this screen has room for the three: a 1024-wide one has not)
    set fit [${G}::_panels_fit]
    set ${S}(show_opts) 1
    ${G}::panels_changed
    update
    set said [set ${S}(status)]
    set bad {}
    foreach key [dict keys [set ${G}::tabs]] {
        ${G}::show_tab $key
        update
        if {![winfo viewable $O.body.${key}_sec] || [winfo ismapped $w.pw.right.nb.$key.opts]} { lappend bad $key }
        foreach c [list {*}[winfo children $O.body.$key] {*}[winfo children $O.all] $O.b.reset $O.head.close] {
            if {[winfo manager $c] ne "" && [winfo class $c] ne "TFrame" && ![whole_in $c $w]} { lappend bad $c }
        }
    }
    ${G}::show_tab populations
    update
    check "  a $sw-wide screen: every option of every plot whole in a window of [winfo width $w], the plot 300 pixels or more ($bad)" [expr {
        [winfo width $w] <= $sw - 40 && [set ${S}(show_opts)] && ![llength $bad] && [winfo width $w.pw.right.nb.populations.c] >= 300 &&
        ($sw > 1024 || !$fit)}]
    if {!$fit} {
        check "    with no room for both panels, they are in the left panel's place, and the status line says so" [expr {
            [winfo width $w] == $wd && [$w.pw panes] eq [list $w.pw.right $O] && ![set ${S}(show_left)] &&
            [string match "*no room for both panels*left panel's place*" $said]}]
    } else {
        check "    with room for both panels: side by side" [expr {[$w.pw panes] eq [list $w.pw.left $w.pw.right $O] && [set ${S}(show_left)]}]
    }
    set ${S}(show_opts) 0
    ${G}::panels_changed
    update
    check "    closed: the left panel is there, and the option row above the plot" [expr {
        [$w.pw panes] eq [list $w.pw.left $w.pw.right] && [set ${S}(show_left)] && [winfo ismapped $w.pw.right.nb.populations.opts]}]
}
on_screen 1024 768
set ${S}(show_opts) 1
${G}::panels_changed
update
${G}::toggle_left
update
check "  the left panel asked for while they are open: they close" [expr {[$w.pw panes] eq [list $w.pw.left $w.pw.right] && [set ${S}(show_left)] && ![set ${S}(show_opts)] &&
    [string match "*no room for both panels*closed*" [set ${S}(status)]]}]

# --- 11: the toolbar -----------------------------------------------------------------------
on_screen 1024 768
set tb $w.tb
check "11: a 1024-wide screen: the window is narrower than the toolbar's one row ([winfo width $w] of [${G}::_toolbar_width]), which goes on two" [expr {
    [winfo width $w] < [${G}::_toolbar_width] && [winfo manager $tb.r2] ne ""}]
set cutoff {}
foreach c [winfo children $tb] {
    if {$c in [list $tb.r1 $tb.r2 $tb.s4] || [whole_in $c $w]} continue
    lappend cutoff $c
}
check "  every button whole, the plot options' toggle and Help among them ($cutoff)" [expr {![llength $cutoff] && [whole_in $tb.opts $w] && [whole_in $tb.help $w]}]
on_screen 1920 1200
check "  a wide one: one row again" [expr {[winfo manager $tb.r2] eq "" && [whole_in $tb.help $w] && [winfo y $tb.help] == [winfo y $tb.open]}]
${G}::set_appearance 24 compact
update
set big [image width [lindex [$tb.open cget -image] 0]]
${G}::set_appearance 12 compact
update
check "17: the toolbar's icons at 24 pt are of 32 pixels, at 12 pt of 24 ($big, [image width [lindex [$tb.open cget -image] 0]])" [expr {
    $big == 32 && [image width [lindex [$tb.open cget -image] 0]] == 24 && [image width [$tb.t_map cget -image]] == 24}]

# --- 15: a long molecule name ---------------------------------------------------------------
on_screen 1280 720
${G}::show_pane setup
update
set name [string repeat "replica_of_a_long_name_" 3]end.pdb
mol rename $m $name
${G}::refresh_molecules
update
set mc [set ${G}::molcombo]
check "15: a [string length $name]-character molecule name: cut in its middle, its frames kept ([set ${S}(molname)])" [expr {
    [regexp {^\d+: replica.*….*pdb \(24 frames\)$} [set ${S}(molname)]] && [font measure MdvUI [set ${S}(molname)]] <= [winfo width $mc] - 20 &&
    [set ${S}(molname)] in [$mc cget -values]}]
check "  the chooser's tooltip has the whole of it" [string match "*: $name (24 frames)\n*" $::VMDance::Tip::text($mc)]
${G}::_mol_chosen
check "  chosen: the molecule's number is read from it" [expr {[set ${S}(molid)] == $m}]
mol rename $m two_state.pdb
${G}::refresh_molecules
check "  a short one as it is" [expr {[set ${S}(molname)] eq "$m: two_state.pdb (24 frames)"}]

# --- 1, 4: the Export dialog ----------------------------------------------------------------
set d $w.export
set dir [file join $::out ux_layout [string repeat "a_folder_with_a_long_name_" 4]end]
set ${S}(out_dir) $dir
${G}::export_dialog
check "1: Export on a 1280 × 720 screen: [winfo reqwidth $d] × [winfo reqheight $d], within it with its buttons" [dialog_fits $d 720]
set B $d.f.c.p.what
check "  what to export in two columns, read down" [expr {[dict get [grid info $B.csummary] -column] == 0 && [dict get [grid info $B.cpicks] -column] == 1 &&
    [dict get [grid info $B.cclusters] -row] == 1 && [winfo manager $d.f.sb] eq ""}]
$d.f.b.ok configure -command {set ::pressed export}
set ::pressed ""
focus -force $d.f.c.p.where.p
update
event generate $d.f.c.p.where.p <Return>
update
check "  Return presses Export ($::pressed)" [expr {$::pressed eq "export" && [$d.f.b.ok cget -default] eq "active"}]
event generate $d.f.c.p.where.p <Escape>
update
check "  Escape closes it" [expr {![winfo exists $d]}]
set ${G}::screen {1024 768}
${G}::export_dialog
check "  on a 1024 × 768 screen: one column, which scrolls; Export and Cancel stay ([winfo reqwidth $d] × [winfo reqheight $d])" [expr {
    [dialog_fits $d 768] && [winfo reqwidth $d] <= 984 && [dict get [grid info $d.f.c.p.what.cpicks] -column] == 0 && [winfo manager $d.f.sb] ne "" &&
    [winfo reqheight $d.f.c.p] > [winfo height $d.f.c]}]
set c $d.f.c
${G}::_dialog_wheel $d $d.f.c.p.what.csummary -1
update
set y1 [lindex [$c yview] 0]
$c yview moveto 1
update
check "  the wheel scrolls it; at its end the options are whole" [expr {$y1 > 0 && [whole_in $d.f.c.p.opt.sel $d] &&
    [winfo rooty $d.f.c.p.opt.sel] + [winfo height $d.f.c.p.opt.sel] <= [winfo rooty $c] + [winfo height $c]}]
set e $d.f.c.p.where.df.e
$c yview moveto 0
update
check "4: a folder longer than its field: the field shows its end ([$e xview])" [expr {[lindex [$e xview] 0] > 0 && [lindex [$e xview] 1] == 1.0}]
check "  its tooltip has the whole path" [string match "$dir\n*folder*" $::VMDance::Tip::text($e)]
set ${S}(out_dir) "$dir/another"
update
check "  another, as Browse sets it: its end again, and the tooltip follows" [expr {[lindex [$e xview] 1] == 1.0 && [string match "$dir/another\n*" $::VMDance::Tip::text($e)]}]
destroy $d
set ${S}(out_dir) [file join $::out ux_layout]

# --- 3: the Figures dialog -------------------------------------------------------------------
set d $w.figures
set ${G}::screen {1280 720}
set ${S}(fig_dir) $dir
${G}::figure_dialog
set h12 [winfo reqheight $d]
check "3: Figures at 12 pt on a 1280 × 720 screen: whole, no scroll bar" [expr {[dialog_fits $d 720] && [winfo manager $d.f.sb] eq ""}]
set e $d.f.c.p.where.df.e
check "  its folder field shows the path's end, the tooltip all of it" [expr {[lindex [$e xview] 1] == 1.0 && [string match "$dir\n*" $::VMDance::Tip::text($e)]}]
$d.f.b.ok configure -command {set ::pressed figures}
focus -force $d.f.c.p.where.p
update
event generate $d.f.c.p.where.p <Return>
update
check "  Return presses Create" [expr {$::pressed eq "figures"}]
destroy $d
${G}::set_appearance 24 compact
update
${G}::figure_dialog
check "  at 24 pt: its sections scroll, Create and Cancel stay within the screen ([winfo reqheight $d], $h12 at 12 pt)" [expr {
    [dialog_fits $d 720] && [winfo manager $d.f.sb] ne "" && [winfo reqheight $d.f.c.p] > [winfo height $d.f.c]}]
destroy $d
set ${S}(fig_dir) [file join $::out ux_layout]

# --- 2: the Settings dialog ------------------------------------------------------------------
set d $w.settings
set heights {}
foreach pt {24 16 12} {
    ${G}::set_appearance $pt compact
    update
    ${G}::settings_dialog
    set ok [dialog_fits $d 720]
    set p $d.f.c.p
    # (the notes' width with a short line of the backend's: a long path
    # widens them, wherever the fake backend is)
    ${G}::_settings_says $p.bk.st "No backend: none found"
    update
    set wl [$p.cl.n cget -wraplength]
    # the Text size field: reached by scrolling to the end
    $d.f.c yview moveto 1
    update
    set reach [expr {[whole_in $p.app.font $d] && [winfo rooty $p.app.font] + [winfo height $p.app.font] <= [winfo rooty $d.f.c] + [winfo height $d.f.c] &&
        [winfo rooty $p.app.font] >= [winfo rooty $d.f.c]}]
    lappend heights $pt [winfo reqheight $d] $ok $reach $wl [expr {[winfo manager $d.f.sb] ne ""}]
    if {$pt != 12} { destroy $d }
}
check "2: Settings on a 1280 × 720 screen at 24, 16 and 12 pt: within it with OK and Cancel, the Text size field reached ($heights)" [expr {
    [lindex $heights 2] && [lindex $heights 3] && [lindex $heights 8] && [lindex $heights 9] && [lindex $heights 14] && [lindex $heights 15]}]
check "  it scrolls at 24 pt, not at 12" [expr {[lindex $heights 5] && ![lindex $heights 17]}]
check "  its notes wrap at a width that follows the text ([lindex $heights 4], [lindex $heights 10], [lindex $heights 16])" [expr {
    [lindex $heights 4] > [lindex $heights 10] && [lindex $heights 10] > [lindex $heights 16] && [lindex $heights 16] >= 44 * $zero}]
# the backend's line: a long path whole on a line
set p $d.f.c.p
set long /home/someone/[string repeat "a_folder_with_a_long_name/" 3]mdance-cli
${G}::_settings_says $p.bk.st "In use: the program $long\nAlgorithms: KMeans NANI"
update
check "4: Settings' line of the backend wraps before a long path, not within it" [expr {
    [$p.bk.st cget -wraplength] >= [font measure MdvUISmall $long] && [winfo reqheight $p.bk.st] <= 3 * [font metrics MdvUISmall -linespace] + 4}]
# (a path longer than the field, however wide the line above made it)
set long /home/someone
while {[font measure MdvUI $long] < [winfo width $p.bk.cf.e] + 100} { append long /a_folder_with_a_long_name }
append long /mdance-cli
array set ${G}::E [list cli $long]
update
check "  its Program field shows the end of a long path, the tooltip all of it and what the field is" [expr {
    [lindex [$p.bk.cf.e xview] 1] == 1.0 && [lindex [$p.bk.cf.e xview] 0] > 0 && [string match "$long\nmdance-cli (empty:*" $::VMDance::Tip::text($p.bk.cf.e)]}]
array set ${G}::E [list cli ""]
${G}::_settings_cancel
check "  Cancel closes it" [expr {![winfo exists $d]}]

# --- 16: VMD's own look -----------------------------------------------------------------------
${G}::set_appearance 12 compact host
update
set on [ttk::style lookup MdvH.TEntry -fieldbackground]
set off [ttk::style lookup MdvH.TEntry -fieldbackground disabled]
check "16: VMD's own look: a field that is on ($on) is told from one that is off ($off)" [expr {$on ne $off &&
    [ttk::style lookup MdvH.TSpinbox -fieldbackground] ne [ttk::style lookup MdvH.TSpinbox -fieldbackground disabled] &&
    [ttk::style lookup MdvH.TCombobox -fieldbackground] ne [ttk::style lookup MdvH.TCombobox -fieldbackground disabled]}]
check "  its fields have that style" [expr {[$PS.input.s.e cget -style] eq "MdvH.TEntry" && [$PS.input.st.step cget -style] eq "MdvH.TSpinbox"}]
${G}::set_appearance 12 compact auto
update

set ${G}::screen {}
check "no background error at all ($::bgerrors)" [expr {[llength $::bgerrors] == 0}]
done
} err]} { puts "FAIL test_ux_layout crashed: $err\n$::errorInfo"; puts "RESULT checks=$::checks fails=[incr ::fails] skips=$::skips" }
::VMDance::Backend::cleanup
close $::logf
quit
