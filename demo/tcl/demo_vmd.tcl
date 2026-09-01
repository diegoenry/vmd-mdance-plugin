# demo_vmd.tcl - the VMD side of the walkthrough: loading the system, giving it
# a legible look, moving the camera, and laying the windows out on screen.
#
# Every display-level command is wrapped in catch. In headless text mode (which
# is how the demo is smoke-tested) there is no OpenGL window, and a demo that
# aborts on `display reposition` would be untestable.

namespace eval ::demo::vmd {
    variable molid ""
    variable psf ""
    variable dcd ""
    variable spin_after ""
    variable spin_axis y
    variable spin_rate 0.30      ;# degrees per tick
    variable spin_period 33      ;# ms per tick (~30 fps)
    variable aligned 0
    variable rep_main 0
    variable rep_ion 1
    variable rep_peptide 2
}

# --- loading ---------------------------------------------------------------

# load_system - load the topology + trajectory and hand back the molid.
#
# `first`/`last`/`step` are passed to mol addfile so a quick rehearsal can load a
# decimated trajectory without editing any scene.
proc ::demo::vmd::load_system {psf_path dcd_path {first 0} {last -1} {step 1}} {
    variable molid
    variable psf
    variable dcd
    variable aligned

    if {![file readable $psf_path]} { error "topology not readable: $psf_path" }
    if {![file readable $dcd_path]} { error "trajectory not readable: $dcd_path" }

    # Start from a clean slate so replaying a chapter does not stack molecules.
    foreach m [molinfo list] { catch {mol delete $m} }

    set molid [mol new $psf_path type psf waitfor all]
    mol addfile $dcd_path type dcd first $first last $last step $step \
        waitfor all molid $molid
    catch {mol rename $molid "MDANCE walkthrough"}
    set psf $psf_path
    set dcd $dcd_path
    set aligned 0
    return $molid
}

# align - RMSD-fit every frame onto frame 0 using $fitsel.
#
# THIS MATTERS MORE THAN IT LOOKS. MDANCE's MSD compares raw coordinates: it has
# no superposition step of its own. On this trajectory the unaligned CA RMSD
# reaches 8 A purely from the molecule tumbling in the box, against ~1.4 A of
# actual conformational change -- so clustering unaligned coordinates clusters
# the rigid-body motion and buries the structural signal.
#
# Fitting on the protein alone (rather than everything) is what lets the peptide
# and the ion be seen MOVING RELATIVE TO the protein.
proc ::demo::vmd::align {{fitsel "protein and name CA"}} {
    variable molid
    variable aligned
    if {$molid eq ""} { error "no molecule loaded" }

    set ref [atomselect $molid $fitsel frame 0]
    set sel [atomselect $molid $fitsel]
    set all [atomselect $molid all]
    set n [molinfo $molid get numframes]
    set rc [catch {
        for {set f 0} {$f < $n} {incr f} {
            $sel frame $f
            $all frame $f
            $all move [measure fit $sel $ref]
        }
    } err opts]
    catch {$ref delete}
    catch {$sel delete}
    catch {$all delete}
    if {$rc} { return -options $opts $err }
    set aligned 1
    return $n
}

# rmsd_range - {min max mean} CA RMSD against frame 0, sampled every $stride
# frames. Used by a scene to state a real number rather than a vague claim.
proc ::demo::vmd::rmsd_range {{seltext "protein and name CA"} {stride 25}} {
    variable molid
    set ref [atomselect $molid $seltext frame 0]
    set sel [atomselect $molid $seltext]
    set n [molinfo $molid get numframes]
    set vals {}
    for {set f 0} {$f < $n} {incr f $stride} {
        $sel frame $f
        lappend vals [measure rmsd $sel $ref]
    }
    catch {$ref delete}
    catch {$sel delete}
    set mn [lindex [lsort -real $vals] 0]
    set mx [lindex [lsort -real $vals] end]
    set sum 0.0
    foreach v $vals { set sum [expr {$sum + $v}] }
    return [list $mn $mx [expr {$sum / [llength $vals]}]]
}

# --- look ------------------------------------------------------------------

# style_default - the starting representation set.
#
# Rep 0 is deliberately the WHOLE protein, because the plugin's own
# apply_cluster_colors does `mol modcolor 0 $molid User` -- it repaints rep 0 and
# nothing else. Anything we want to see coloured by cluster has to live there.
proc ::demo::vmd::style_default {} {
    variable molid
    if {$molid eq ""} { return }

    foreach r [lrange [lsort -integer -decreasing \
            [_rep_indices]] 0 end] {
        catch {mol delrep $r $molid}
    }

    # rep 0 - the complex, cartoon. Structure-coloured until a run repaints it.
    mol representation NewCartoon 0.32 12.0 4.1 0
    mol color Structure
    mol selection "protein"
    mol material AOChalky
    mol addrep $molid

    # rep 1 - the bound calcium, so the viewer can see there is a ligand at all.
    mol representation VDW 0.75 24.0
    mol color ColorID 12
    mol selection "segname CALC"
    mol material AOShiny
    mol addrep $molid

    # rep 2 - the peptide backbone, off by default. A scene turns it on to point
    # out which part of the complex is the peptide.
    mol representation Licorice 0.22 20.0 20.0
    mol color ColorID 3
    mol selection "segname PEPT and noh"
    mol material AOChalky
    mol addrep $molid
    catch {mol showrep $molid 2 0}

    catch {color Display Background white}
    catch {display projection Orthographic}
    catch {display depthcue off}
    catch {display shadows on}
    catch {display ambientocclusion on}
    catch {axes location Off}
    catch {display resetview}
    catch {display update}
    return
}

proc ::demo::vmd::_rep_indices {} {
    variable molid
    set n 0
    catch {set n [molinfo $molid get numreps]}
    set out {}
    for {set i 0} {$i < $n} {incr i} { lappend out $i }
    return $out
}

proc ::demo::vmd::show_peptide {{on 1}} {
    variable molid
    variable rep_peptide
    catch {mol showrep $molid $rep_peptide $on}
    catch {display update}
}

# color_by_structure - put rep 0 back to secondary-structure colouring, undoing
# a cluster colouring so the next chapter starts from a neutral picture.
proc ::demo::vmd::color_by_structure {} {
    variable molid
    if {$molid eq ""} { return }
    catch {mol modcolor 0 $molid Structure}
    catch {display update}
}

# smooth - trajectory smoothing window on rep 0; makes playback far less jittery
# on screen without touching the data that gets clustered.
proc ::demo::vmd::smooth {{n 3}} {
    variable molid
    foreach r [_rep_indices] { catch {mol smoothrep $molid $r $n} }
}

# --- camera ----------------------------------------------------------------

proc ::demo::vmd::reset_view {} {
    catch {display resetview}
    catch {display update}
}

# spin_start - continuous rotation driven by `after`, so the event loop (and
# therefore the narration, the captions and the plugin) keeps running.
proc ::demo::vmd::spin_start {{axis y} {rate 0.30}} {
    variable spin_after
    variable spin_axis
    variable spin_rate
    spin_stop
    set spin_axis $axis
    set spin_rate $rate
    _spin_tick
    return
}

proc ::demo::vmd::_spin_tick {} {
    variable spin_after
    variable spin_axis
    variable spin_rate
    variable spin_period
    catch {rotate $spin_axis by $spin_rate}
    set spin_after [after $spin_period ::demo::vmd::_spin_tick]
}

proc ::demo::vmd::spin_stop {} {
    variable spin_after
    if {$spin_after ne ""} { catch {after cancel $spin_after} }
    set spin_after ""
}

proc ::demo::vmd::zoom {{factor 1.15}} {
    catch {scale by $factor}
    catch {display update}
}

proc ::demo::vmd::goto_frame {f} {
    catch {animate goto $f}
    catch {display update}
}

# sweep_frames - step the trajectory from $from to $to over about $secs
# seconds, without blocking. Used to let a chapter's narration play over the
# trajectory actually moving.
proc ::demo::vmd::sweep_frames {from to secs} {
    variable sweep_after
    catch {after cancel $::demo::vmd::sweep_after}
    set steps [expr {abs($to - $from)}]
    if {$steps == 0} { goto_frame $to ; return }
    set period [expr {int(double($secs) * 1000 / $steps)}]
    if {$period < 25} { set period 25 }
    set dir [expr {$to > $from ? 1 : -1}]
    _sweep_tick $from $to $dir $period
}

proc ::demo::vmd::_sweep_tick {cur to dir period} {
    variable sweep_after
    catch {animate goto $cur}
    catch {display update}
    if {($dir > 0 && $cur >= $to) || ($dir < 0 && $cur <= $to)} {
        set sweep_after ""
        return
    }
    set sweep_after [after $period \
        [list ::demo::vmd::_sweep_tick [expr {$cur + $dir}] $to $dir $period]]
}

proc ::demo::vmd::sweep_stop {} {
    variable sweep_after
    if {[info exists sweep_after] && $sweep_after ne ""} {
        catch {after cancel $sweep_after}
    }
    set sweep_after ""
}

# --- window layout ---------------------------------------------------------

# layout - place the VMD display, the plugin window and the demo control panel
# so nothing important sits under anything else.
#
# VMD's `display reposition` measures from the BOTTOM-left of the screen, while
# Tk's `wm geometry` measures from the top-left. The conversion is the reason
# this is one proc rather than three scattered calls.
proc ::demo::vmd::layout {} {
    set sw 1600
    set sh 1000
    catch {set sw [winfo screenwidth .]}
    catch {set sh [winfo screenheight .]}

    # Reserve the bottom strip for the caption bar.
    set usable_h [expr {$sh - 230}]
    set menubar 40

    # VMD display: left 58% of the screen.
    set vw [expr {int($sw * 0.56)}]
    set vh $usable_h
    if {$vh > 980} { set vh 980 }
    set vx 24
    set vy_top $menubar
    # bottom-left origin for VMD
    set vy_bottom [expr {$sh - $vy_top - $vh}]
    catch {display resize $vw $vh}
    catch {display reposition $vx $vy_bottom}

    # Plugin window: to the right of it.
    set px [expr {$vx + $vw + 22}]
    set pw [expr {$sw - $px - 24}]
    if {$pw < 520} { set pw 520 }
    if {$pw > 640} { set pw 640 }
    set ph [expr {int($vh * 0.66)}]
    if {$ph < 620} { set ph 620 }
    catch {wm geometry .mdance "${pw}x${ph}+${px}+${vy_top}"}

    # Control panel: under the plugin window.
    set cy [expr {$vy_top + $ph + 18}]
    set ch [expr {$sh - $cy - 250}]
    if {$ch < 200} { set ch 200 }
    catch {wm geometry .demo_control "${pw}x${ch}+${px}+${cy}"}

    catch {::demo::caption::place_bar}
    return [list screen ${sw}x${sh} vmd ${vw}x${vh} plugin ${pw}x${ph}]
}
