#
# VMDance - figures
#
# Plots are drawn again into a hidden canvas and written as EPS scaled to
# the requested size in points; Ghostscript, when available, converts them
# to PDF or PNG. The 3D view is rendered by VMD (a snapshot, or its internal
# Tachyon) to PPM, which Tk converts to PNG. (DynNetView's figures, without
# its sheets.)
#

namespace eval ::VMDance::Figures {
    variable gs ""
    variable formats {eps pdf png}
}

# Ghostscript executable, or "" when none is found.
proc ::VMDance::Figures::ghostscript {} {
    variable gs
    if {$gs ne ""} { return $gs }
    set cands {}
    foreach name {gs gswin64c gswin32c} {
        set p [auto_execok $name]
        if {$p ne ""} { lappend cands [lindex $p 0] }
    }
    lappend cands /opt/homebrew/bin/gs /usr/local/bin/gs /opt/local/bin/gs /usr/bin/gs
    foreach c $cands {
        if {[file executable $c]} { set gs $c; return $gs }
    }
    return ""
}

# Draw one plot into a hidden canvas of cw × ch; returns its path.
# cursor 0: without the current-frame markers.
proc ::VMDance::Figures::render_plot {key cw ch {cursor 1} {c .vmdance_figure_canvas}} {
    if {![dict exists $::VMDance::GUI::tabs $key]} {
        error "unknown plot \"$key\" (valid: [join [dict keys $::VMDance::GUI::tabs] {, }])"
    }
    destroy $c
    array unset ::VMDance::Plot::G $c,*
    canvas $c -width $cw -height $ch -background white -highlightthickness 0 -borderwidth 0
    ::VMDance::Plots::draw $key $c
    if {!$cursor} { $c delete cursor }
    return $c
}

proc ::VMDance::Figures::_gs_cmd {job} {
    set gs [ghostscript]
    if {$gs eq ""} { error "Ghostscript is needed for PDF and PNG output (EPS works without it)" }
    set job [lmap a $job {
        expr {[string match -sOutputFile=* $a] ? "-sOutputFile=[string map {% %%} [string range $a 13 end]]" : $a}
    }]
    concat [list $gs -q -dSAFER -dBATCH -dNOPAUSE -dEPSCrop] $job
}
proc ::VMDance::Figures::_gs_run {jobs} {
    foreach job $jobs {
        if {[catch {exec {*}[_gs_cmd $job] 2>@1} out]} { error "Ghostscript failed: [string trim $out]" }
    }
}

# Tk pads the bounding box by a point: make it exactly the figure's size
# (ps: the PostScript's text).
proc ::VMDance::Figures::_set_bbox {ps W H} {
    regsub {%%BoundingBox: [-0-9. ]+\n} $ps "%%BoundingBox: 0 0 $W $H\n" ps
    return $ps
}

# The formats, size and resolution of figures, checked (gs 0: no plot is
# drawn, Ghostscript is not needed).
proc ::VMDance::Figures::_check {fmts W H dpi {gs 1}} {
    upvar 0 ::VMDance::Figures::formats valid
    foreach f $fmts { if {$f ni $valid} { error "unknown format \"$f\" (valid: [join $valid {, }])" } }
    if {![llength $fmts]} { error "no format chosen" }
    if {$gs && [llength [lsearch -all -inline -not -exact $fmts eps]] && [ghostscript] eq ""} {
        error "Ghostscript is needed for PDF and PNG output (EPS works without it)"
    }
    # (decimal numbers: expr reads 0700 as octal)
    foreach v [list $W $H] {
        if {![regexp {^[1-9][0-9]{0,4}$} $v] || $v < 240 || $v > 6000} { error "a figure is 240 to 6000 points wide and high (got $W × $H)" }
    }
    if {![regexp {^[1-9][0-9]{0,3}$} $dpi] || $dpi < 50 || $dpi > 1200} { error "the resolution must be 50 to 1200 dpi (got \"$dpi\")" }
}

# Export one plot as W × H points (drawn at W × H pixels with the plots'
# reference text size); returns the files written. (Each file is written as
# the exports' are, Export::_write: Tk gives the PostScript as text, and
# Ghostscript writes into the private folder; nothing is opened by name
# beside the figures, where a link could be waiting.)
proc ::VMDance::Figures::export_plot {key base fmts W H {dpi 300} {cursor 1}} {
    _check $fmts $W $H $dpi
    # (a name is a file's: "<f" or "|cmd" would be read by exec and open;
    # each checked before anything is drawn)
    set base [file normalize $base]
    foreach f $fmts { ::VMDance::Export::target $base.$f }
    # (the window, when it was never opened, has not made its fonts)
    ::VMDance::Plot::init_fonts
    ::VMDance::Fonts::plot_reference 1
    try {
        set c [render_plot $key $W $H $cursor]
        # the plugin's fonts as PostScript's Helvetica: Tk would name the
        # font it found (on X11 a font Ghostscript may not have)
        array unset ::VMDance::Figures::fontmap
        foreach f [font names] {
            if {![string match Mdv* $f]} continue
            set bold [expr {[font actual $f -weight] eq "bold"}]
            set ::VMDance::Figures::fontmap($f) [list [expr {$bold ? "Helvetica-Bold" : "Helvetica"}] [font actual $f -size]]
        }
        try {
            set ps [$c postscript -colormode color -x 0 -y 0 -width $W -height $H \
                -pagewidth ${W}p -pageanchor sw -pagex 0 -pagey 0 -fontmap ::VMDance::Figures::fontmap]
        } finally {
            destroy $c
            ::VMDance::Plots::release_image $c
        }
    } finally {
        ::VMDance::Fonts::plot_reference 0
    }
    set ps [_set_bbox $ps $W $H]
    set out {}
    if {"eps" in $fmts} {
        ::VMDance::Export::_write $base.eps $ps 1
        lappend out $base.eps
    }
    # Ghostscript's input and outputs: {temporary file} each
    set made {}
    set jobs {}
    try {
        if {"pdf" in $fmts || "png" in $fmts} {
            set eps [::VMDance::Backend::tmpfile .eps]
            lappend made $eps ""
            ::VMDance::Export::_put [open $eps wb] $eps $ps
            if {"pdf" in $fmts} {
                set t [::VMDance::Backend::tmpfile .pdf]
                lappend jobs [list -sDEVICE=pdfwrite -sOutputFile=$t $eps]
                lappend made $t $base.pdf
            }
            if {"png" in $fmts} {
                set t [::VMDance::Backend::tmpfile .png]
                lappend jobs [list -sDEVICE=png16m -r$dpi -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -sOutputFile=$t $eps]
                lappend made $t $base.png
            }
        }
        _gs_run $jobs
        foreach {t f} $made {
            if {$f eq ""} continue
            ::VMDance::Export::_copy $t $f
            lappend out $f
        }
    } finally {
        foreach {t f} $made { file delete $t }
    }
    return $out
}

# The renderers of VMD's that write an image of the 3D view: snapshot and
# its internal ray tracers (TachyonInternal, OptiXInternal, ANARIInternal,
# as this VMD has them). Not its exporters (POV3, Tachyon, Wavefront …
# write a scene for another program), nor the interactive ones (a window
# that waits for a person).
proc ::VMDance::Figures::renderers {} {
    set out {}
    foreach r [render list] {
        if {$r eq "snapshot" || [string match *Internal $r]} { lappend out $r }
    }
    return $out
}
# Why renderer r cannot render the 3D view ("" when it can).
proc ::VMDance::Figures::_not_renderer {r} {
    if {$r in [renderers]} { return "" }
    if {$r ni [render list]} { return "VMD has no renderer \"$r\"" }
    if {[string match *Interactive $r]} { return "$r opens a window of its own and waits for it to close" }
    return "$r writes a scene for another program, not an image"
}

# Render the 3D view to PNG (via PPM, which Tk reads) with snapshot or a
# renderer of VMD's that writes at the display's size. (VMD and Tk write
# by name: into the private folder; the PNG is copied in as the exports'
# files are, Export::_copy.)
proc ::VMDance::Figures::render_3d {file {renderer snapshot} {white 1}} {
    set why [_not_renderer $renderer]
    if {$why ne ""} { error "$why (use [join [renderers] {, }])" }
    set file [file normalize $file]
    ::VMDance::Export::target $file
    set ppm [::VMDance::Backend::tmpfile .ppm]
    set png [::VMDance::Backend::tmpfile .png]
    set oldbg [colorinfo category Display Background]
    # (a drawing whose frames changed under it: made again, or withdrawn)
    ::VMDance::Viz::check
    if {$white} { color Display Background white }
    try {
        try {
            display update
            # (VMD's render fails with no message: its console says why; it
            # is given VMD's name of the file, Backend::vmd_name)
            if {[catch {render $renderer [::VMDance::Backend::vmd_name $ppm]} msg]} {
                if {$msg eq ""} { set msg "VMD's $renderer rendered no image (VMD's console says why)" }
                error $msg
            }
        } finally {
            if {$white} {
                color Display Background $oldbg
                display update
            }
        }
        if {![file exists $ppm] || [file size $ppm] == 0} { error "VMD did not write the rendered image" }
        if {[catch {image create photo -file $ppm} img]} { error "cannot read the image VMD rendered: $img" }
        try {
            $img write $png -format png
        } finally {
            image delete $img
        }
        ::VMDance::Export::_copy $png $file
    } finally {
        file delete $ppm $png
    }
    return $file
}

# The command: figures dir ?-plots {...}? ?-formats {pdf png}? ?-width w?
# ?-height h? ?-dpi d? ?-prefix p? ?-cursor 0|1? ?-3d 0|1? ?-renderer r?
# ?-text points? (the plots' text size: 12, the figures' own, by default;
# larger for a slide or a small figure)
proc ::VMDance::Figures::api {dir args} {
    set what "vmdance figures"
    # (by default the plots that have something to draw)
    set have [lmap p [dict keys $::VMDance::GUI::tabs] {expr {[::VMDance::Plots::has_data $p] ? $p : [continue]}}]
    set o [::VMDance::_opts $what [dict create -plots $have -formats {pdf png} \
        -width 900 -height 560 -dpi 300 -prefix vmdance -cursor 1 -3d 0 -renderer auto -options {} -text 12] $args]
    set ts [dict get $o -text]
    if {![regexp {^[1-9][0-9]?$} $ts] || $ts < 8 || $ts > 24} { error "$what: -text must be a whole number of points from 8 to 24 (got \"$ts\")" }
    # (the plots, the 3D view or both: -plots {} -3d 1 is the 3D view alone,
    # as the window renders it)
    set d3 [::VMDance::_bool "$what: -3d" [dict get $o -3d]]
    if {![llength [dict get $o -plots]] && !$d3} {
        if {[dict exists $args -plots]} { error "$what: -plots is empty: name a plot, or give -3d 1 for the 3D view alone" }
        error "$what: nothing to draw (no clustering, no scan)"
    }
    set dir [file normalize $dir]
    if {[file exists $dir] && ![file isdirectory $dir]} { error "$what: \"$dir\" is a file, not a folder" }
    # the plots' settings for these figures only (the window's plot options:
    # tl_view msd, ds_show representatives …), each checked as a session's are
    set po [dict get $o -options]
    if {[catch {dict size $po}]} { error "$what: -options must be a list of setting value …" }
    set seen {}
    foreach {k v} $po {
        # (a setting given twice: dict for kept the last, the first never checked)
        if {$k in $seen} { error "$what: -options: $k is given twice" }
        lappend seen $k
        if {![regexp {^(po|mu|tl|tn|rs|cp|ds|td|sl|mp|pf|eb|sw|mx|plot)_} $k] || ![info exists ::VMDance::GUI::S($k)]} {
            error "$what: unknown plot setting \"$k\" (the plot options' names: po_show, tl_view, tn_show, cp_show, ds_show …)"
        }
        if {![::VMDance::GUI::_state_ok $k $v]} { error "$what: $k cannot be \"$v\"" }
    }
    set r [dict get $o -renderer]
    if {$r eq "auto"} { set r [expr {"TachyonInternal" in [render list] ? "TachyonInternal" : "snapshot"}] }
    set prefix [dict get $o -prefix]
    if {$prefix eq "" || [regexp {[/\\:]} $prefix] || [string index $prefix 0] eq "~"} { error "$what: the prefix must be a plain file name (not starting with ~)" }
    # (checked before any figure is written)
    if {$d3 && [set why [_not_renderer $r]] ne ""} { error "$what: -renderer: $why (use auto, [join [renderers] {, }])" }
    set cur [::VMDance::_bool "$what: -cursor" [dict get $o -cursor]]
    foreach p [dict get $o -plots] {
        if {![dict exists $::VMDance::GUI::tabs $p]} { error "$what: unknown plot \"$p\" (valid: [join [dict keys $::VMDance::GUI::tabs] {, }])" }
    }
    if {[catch {_check [dict get $o -formats] [dict get $o -width] [dict get $o -height] [dict get $o -dpi] [llength [dict get $o -plots]]} err]} { error "$what: $err" }
    # (made once everything is checked, as an export's: a refused call makes
    # no folder, and one that fails before a figure is written takes it back)
    if {[catch {::VMDance::Export::_mkdir $dir} made]} { error "$what: $made" }
    set out {}
    set saved [dict create]
    dict for {k v} $po { dict set saved $k $::VMDance::GUI::S($k); set ::VMDance::GUI::S($k) $v }
    set ref $::VMDance::Fonts::reference
    set ::VMDance::Fonts::reference $ts
    try {
        foreach p [dict get $o -plots] {
            if {[catch {export_plot $p [file join $dir ${prefix}_$p] [dict get $o -formats] [dict get $o -width] [dict get $o -height] \
                    [dict get $o -dpi] $cur} files]} { error "$what: $p: $files" }
            lappend out {*}$files
        }
    } on error {msg opts} {
        ::VMDance::Export::_unmake $made
        return -options $opts $msg
    } finally {
        dict for {k v} $saved { set ::VMDance::GUI::S($k) $v }
        set ::VMDance::Fonts::reference $ref
    }
    if {$d3} {
        if {[catch {render_3d [file join $dir ${prefix}_3d.png] $r} f]} {
            # (the 3D view alone, -plots {}: no figure written, the folders
            # made are taken back too; with plots they hold them, and stay)
            if {![llength $out]} { ::VMDance::Export::_unmake $made }
            error "$what: 3D: $f"
        }
        lappend out $f
    }
    return $out
}
