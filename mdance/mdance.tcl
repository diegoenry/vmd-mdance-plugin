# mdance.tcl - MDANCE VMD Plugin
#
# Main plugin file: registration, coordinate extraction, CLI invocation,
# and result visualization for molecular dynamics trajectory clustering.

package provide mdance 1.0

package require Tk

namespace eval ::mdance {
    variable cli_path ""
    variable w ""
    variable results ""
    variable molid "top"
    variable atomsel "protein and name CA"
    variable status "Ready"
    variable running 0
    variable use_library 0

    # Async CLI run state (for cancellable, progress-streaming runs)
    variable cancel_requested 0
    variable async_fh ""
    variable async_pid ""
    variable async_done 0
    variable async_err ""
    # Last few lines the child printed, kept so a failure can say what the
    # backend actually complained about (see _async_read).
    variable async_tail {}
    # Monotonic id identifying the CURRENT streaming run, plus the `after` ids it
    # armed. Cancel escalation used to identify its run by the channel name, but
    # Tcl derives pipe channel names from the fd number and hands the same name
    # straight back to the next open -- so a timer left over from a cancelled run
    # matched the next run and killed it. See request_cancel.
    variable async_run_id 0
    variable async_timers {}
}

# Source companion files from same directory
set _mdance_dir [file dirname [info script]]
source [file join $_mdance_dir mdance_utils.tcl]
source [file join $_mdance_dir mdance_gui.tcl]
source [file join $_mdance_dir mdance_plots.tcl]
source [file join $_mdance_dir mdance_sweep.tcl]

# init - Initialize the plugin, locate library or CLI binary
# Returns "library" or "cli" depending on which backend is available
proc ::mdance::init {} {
    variable cli_path
    variable use_library

    # Try loading shared library first.
    # The explicit "Mdance" prefix names the init symbol (Mdance_Init); without
    # it Tcl guesses from the filename (mdance_tcl -> Mdance_tcl_Init), which the
    # extension does not export, so the load would fail and fall back to CLI.
    if {!$use_library} {
        set lib_path [::mdance::utils::find_library]
        if {$lib_path ne ""} {
            if {![catch {load $lib_path Mdance}]} {
                set use_library 1
                return "library"
            }
        }
    }

    if {$use_library} {
        return "library"
    }

    # Fall back to CLI binary
    if {$cli_path eq ""} {
        if {[catch {set cli_path [::mdance::utils::find_cli]} err]} {
            set cli_path ""
            return -code error $err
        }
    }
    return "cli"
}

# frame_list - Resolve a first:last:stride selection into a list of absolute
# VMD frame indices. last < 0 (or out of range) means "to the end"; stride < 1
# is treated as 1. The default 0/-1/1 reproduces "all frames".
proc ::mdance::frame_list {molid {first 0} {last -1} {stride 1}} {
    set total [molinfo $molid get numframes]
    if {$total == 0} {
        error "Molecule $molid has no frames loaded."
    }

    # Reject non-integer input BEFORE the range guards below. Every guard here is
    # an expr comparison, and expr silently falls back to STRING comparison when
    # an operand is not numeric -- so a typo like "1o" for "10" passes them all
    # and selects a wrong subset with no error at all, with the damage depending
    # on the digits of $total ("1o" yields 2 frames out of 500, but all 1000 out
    # of 1000). Clustering the wrong frames silently is the worst failure this
    # plugin can have, so it must fail loudly instead.
    if {$first eq ""}  { set first 0 }
    if {$last eq ""}   { set last -1 }
    if {$stride eq ""} { set stride 1 }
    foreach {label val} [list "First frame" $first "Last frame" $last "Stride" $stride] {
        if {![string is integer -strict $val]} {
            error "$label must be a whole number (got \"$val\")."
        }
    }

    if {$first < 0} { set first 0 }
    if {$last < 0 || $last >= $total} { set last [expr {$total - 1}] }
    if {$stride < 1} { set stride 1 }
    if {$first > $last} {
        error "Frame range invalid: first ($first) is past last ($last)."
    }
    set frames {}
    for {set f $first} {$f <= $last} {incr f $stride} {
        lappend frames $f
    }
    if {[llength $frames] == 0} {
        error "Frame range/stride selected 0 frames."
    }
    return $frames
}

# range_params - Pull first/last/stride out of a params dict (with defaults
# that mean "all frames"). Returns {first last stride}.
proc ::mdance::range_params {params} {
    set first  [expr {[dict exists $params first]  ? [dict get $params first]  : 0}]
    set last   [expr {[dict exists $params last]   ? [dict get $params last]   : -1}]
    set stride [expr {[dict exists $params stride] ? [dict get $params stride] : 1}]
    return [list $first $last $stride]
}

# abs_frame - Map a clustering sample index (row in the extracted matrix) to the
# absolute VMD frame it came from, using the "frames" map stored in a results
# dict. Preserves the -1 "empty cluster" sentinel and falls back to identity
# when no map is present (full-trajectory runs / older results).
proc ::mdance::abs_frame {results subset_idx} {
    if {$subset_idx eq "" || $subset_idx < 0} { return -1 }
    if {![dict exists $results frames]} { return $subset_idx }
    set af [lindex [dict get $results frames] $subset_idx]
    if {$af eq ""} {
        # A map exists but does not reach this sample, so the result is
        # internally inconsistent. Returning $subset_idx here silently pointed
        # the caller at an unrelated absolute frame; -1 routes into the same
        # "no such frame" handling every caller already has for empty clusters.
        return -1
    }
    return $af
}

# _frame_coords - Position $sel on absolute frame $f and return its {x y z} rows,
# refusing to proceed if the selection's atom count changed.
#
# `$sel update` re-evaluates the selection TEXT for the new frame, so a
# coordinate-based selection ("within 5 of resname LIG", "x > 0", ...) gains and
# loses atoms as the trajectory moves. The extracted matrix has one fixed-width
# row per frame and the backend is handed a single natoms, so a varying count
# silently corrupts every row after the first -- the clustering still "succeeds"
# and returns labels computed from misaligned coordinates. A static selection
# (the normal case, e.g. "protein and name CA") never trips this.
proc ::mdance::_frame_coords {sel seltext f natoms} {
    $sel frame $f
    $sel update
    set n [$sel num]
    if {$n != $natoms} {
        error "Atom selection '$seltext' is frame-dependent: it matches $n atoms\
at frame $f but $natoms at the start. Clustering needs a selection whose atom\
set is the same in every frame (e.g. \"protein and name CA\")."
    }
    return [$sel get {x y z}]
}

# _extract_tick - Report extraction progress, service the event loop, and honour
# a cancel request. Returns the frame counter unchanged; raises to abort.
#
# Both extraction loops used to run to completion without servicing a single
# event. Extraction is the DOMINANT cost of a run -- measured at 4-5 s for a
# 6001-frame trajectory against 0.1-1.3 s for the clustering itself -- so VMD
# simply froze for it: the progress bar never advanced, and the status-bar Cancel
# button could not be pressed at all, because the click was never delivered.
#
# Servicing events mid-loop makes the whole GUI live, which is only safe because
# ::mdance::running is already 1 before extraction starts (run_clustering sets it
# before dispatching, the sweep and the elbow set it themselves), so run_guarded,
# _busy_guard, run_parameter_sweep and run_elbow_analysis all refuse to start
# anything on top of it. Do NOT extract from a context that has not taken that
# flag, or a second run can be launched into the middle of this one.
# live=1 delivers user input (so Cancel works) and honours the cancel flag; it
# REQUIRES the caller to hold ::mdance::running. live=0 is for extraction paths
# that run outside that flag (post-hoc analysis via extract_csv_for_frames):
# those still show progress, but only via `update idletasks`, which repaints
# without delivering button clicks -- so no new re-entrancy is introduced and,
# by the same token, they are not interruptible.
proc ::mdance::_extract_tick {what done total {live 1}} {
    variable status
    variable cancel_requested
    if {$live && $cancel_requested} {
        # The same wording run_guarded already special-cases, so a cancel during
        # extraction reports as "Cancelled." instead of as a run failure.
        error "Clustering cancelled."
    }
    set pct [expr {$total > 0 ? int(100.0 * $done / $total) : 0}]
    set status "$what: frame $done of $total ($pct%)"
    ::mdance::gui::progress_frac [expr {$total > 0 ? double($done) / $total : 0.0}]
    if {$live} { update } else { update idletasks }
}

# _tick_every - How often to tick, so the cost stays negligible on long
# trajectories while short ones still get a final update. ~100 ticks maximum.
proc ::mdance::_tick_every {total} {
    return [expr {$total < 200 ? 25 : $total / 100}]
}

# extract_coordinates - Extract atomic coordinates from VMD molecule to CSV.
# Optionally restricted to a first:last:stride frame range.
# CSV row order == frame_list order; this alignment is load-bearing: the
# backend returns labels/representatives indexed by matrix row, which the
# plugin maps back to absolute VMD frames via the returned frame_list.
# Returns: list of {csv_path natoms nframes frame_list}
proc ::mdance::extract_coordinates {molid sel_text {first 0} {last -1} {stride 1}} {
    variable status

    set frames [frame_list $molid $first $last $stride]

    set sel [atomselect $molid $sel_text]
    set natoms [$sel num]
    if {$natoms == 0} {
        $sel delete
        error "Atom selection '$sel_text' matched 0 atoms."
    }

    set csv_path [::mdance::utils::mktmp ".csv"]
    set fp [open $csv_path w]

    set nframes [llength $frames]
    set every [_tick_every $nframes]
    # Always release the channel and the VMD selection, even if a step in the
    # loop throws (e.g. the molecule is deleted mid-run, a write fails, or the
    # user cancels -- _extract_tick raises to abort).
    set rc [catch {
        set done 0
        foreach f $frames {
            set row {}
            foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                lappend row [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
            }
            puts $fp [join $row ","]
            incr done
            if {$done % $every == 0 || $done == $nframes} {
                _extract_tick "Extracting coordinates" $done $nframes
            }
        }
    } res opts]
    # close is where buffered output is actually flushed, so a full disk or a
    # dying filesystem surfaces HERE rather than in the loop above. Swallowing it
    # would hand the backend a silently truncated coordinate file and cluster it.
    if {$rc} {
        catch {close $fp}
    } else {
        set rc [catch {close $fp} res opts]
        if {$rc} { set res "Failed writing coordinates to $csv_path: $res" }
    }
    catch {$sel delete}
    if {$rc} { return -options $opts $res }

    return [list $csv_path $natoms [llength $frames] $frames]
}

# extract_coordinates_flat - Extract coordinates as a flat Tcl list (for library mode).
# Optionally restricted to a first:last:stride frame range.
# Returns: list of {coords_list natoms nframes frame_list}
proc ::mdance::extract_coordinates_flat {molid sel_text {first 0} {last -1} {stride 1}} {
    variable status

    set frames [frame_list $molid $first $last $stride]

    set sel [atomselect $molid $sel_text]
    set natoms [$sel num]
    if {$natoms == 0} {
        $sel delete
        error "Atom selection '$sel_text' matched 0 atoms."
    }

    set flat_coords {}
    set nframes [llength $frames]
    set every [_tick_every $nframes]
    set rc [catch {
        set done 0
        foreach f $frames {
            foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                lappend flat_coords [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
            }
            incr done
            if {$done % $every == 0 || $done == $nframes} {
                _extract_tick "Extracting coordinates" $done $nframes
            }
        }
    } res opts]
    catch {$sel delete}
    if {$rc} { return -options $opts $res }

    return [list $flat_coords $natoms [llength $frames] $frames]
}

# read_labels_file - Read a per-sample cluster-label file into a list, ordered by
# FRAME, and validate it hard enough that a malformed file cannot be mistaken
# for a good one.
#
# Four dialects occur in practice and all must work:
#   1. one bare integer label per line          -- the plugin's own normalized _init.csv
#   2. "frame,cluster" with a one-line header   -- the plugin's own export_labels
#   3. any number of leading "#" comment lines, then "frame,cluster" rows in
#      frame order                              -- MDANCE labels_<k>_<init>.csv
#   4. as (3) but rows GROUPED BY CLUSTER       -- MDANCE <x>_helm_cluster_labels_<k>.csv
#
# Two bugs made this function reject or corrupt every file the MDANCE reference
# pipeline emits, and both are worth naming because they look harmless:
#
#   * The header skip was gated on `lineno == 1`, but the MDANCE writers emit TWO
#     "#" comment lines. Every real NANI/HELM label CSV was therefore rejected
#     outright with "line 2 is not an integer label" -- including the k=60 NANI
#     labels file that is the documented way to seed HELM.
#   * Worse, the label was taken as [lindex [split $line ","] end] and the frame
#     index in column 0 was discarded, i.e. row order was trusted to be frame
#     order. That holds for NANI output but NOT for HELM output, which lists
#     every frame of cluster 0, then cluster 1, and so on. Such a file has one
#     row per frame, so the caller's label-count check passed and the run
#     proceeded on data where every label sat on the wrong frame -- a silent
#     scientific error, which is why the frame column is now authoritative.
#
# Returns a list of labels indexed by frame 0..maxframe. Partial coverage is an
# error, not a short list: see the gap check below.
proc ::mdance::read_labels_file {path} {
    set fp [open $path r]
    set rc [catch {read $fp} content opts]
    catch {close $fp}
    if {$rc} { return -options $opts $content }

    # Pass 1: gather the data rows. A "#" line is a comment wherever it appears,
    # not only on line 1. Blank lines (including the trailing newline's empty
    # tail) are skipped too.
    set rows {}          ;# flat {lineno fields lineno fields ...}
    set ncols 0
    set cand 0           ;# non-comment, non-blank lines seen so far
    set lineno 0
    foreach line [split $content "\n"] {
        incr lineno
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        incr cand
        set fields {}
        foreach fld [split $line ","] { lappend fields [string trim $fld] }
        # A bare (un-commented) header such as "frame,cluster" is only possible
        # as the FIRST data candidate, and is recognised by its last field not
        # being an integer -- a data row always ends in one. Restricting this to
        # $cand == 1 keeps a genuinely corrupt row further down from being
        # silently swallowed as "another header".
        if {$cand == 1 && ![string is integer -strict [lindex $fields end]]} continue
        if {$ncols == 0} {
            set ncols [llength $fields]
            if {$ncols != 1 && $ncols != 2} {
                error "Labels file $path: line $lineno has $ncols comma-separated\
fields; expected either one label per line, or \"frame,cluster\" pairs."
            }
        } elseif {[llength $fields] != $ncols} {
            error "Labels file $path: line $lineno has [llength $fields] field(s)\
but earlier rows have $ncols, so this is not one consistent table."
        }
        lappend rows $lineno $fields
    }
    if {[llength $rows] == 0} {
        error "Labels file $path contains no labels."
    }

    # Single column: there is no frame index, so row order IS frame order.
    if {$ncols == 1} {
        set labels {}
        foreach {ln fields} $rows {
            set v [lindex $fields 0]
            if {![string is integer -strict $v]} {
                error "Labels file $path: line $ln is not an integer label (\"$v\")."
            }
            lappend labels $v
        }
        return $labels
    }

    # Two columns: column 0 is the frame index and column 1 the label. Place each
    # label AT its frame instead of trusting row order (dialect 4 above).
    array set byframe {}
    set maxf -1
    foreach {ln fields} $rows {
        lassign $fields f v
        if {![string is integer -strict $f]} {
            error "Labels file $path: line $ln has a non-integer frame index (\"$f\")."
        }
        if {![string is integer -strict $v]} {
            error "Labels file $path: line $ln is not an integer label (\"$v\")."
        }
        if {$f < 0} {
            error "Labels file $path: line $ln has a negative frame index ($f)."
        }
        if {[info exists byframe($f)]} {
            error "Labels file $path: frame $f is listed twice (line $ln). A label\
file must name each frame at most once."
        }
        set byframe($f) $v
        if {$f > $maxf} { set maxf $f }
    }

    # Gaps mean the file does not label every frame it spans. A TRIMMED MDANCE
    # result looks exactly like this -- HELM trimming discards whole clusters, so
    # its label CSV carries only the surviving frames (e.g. 1577 rows whose
    # indices still run to 6000) -- and so does a "best frames" file. Neither can
    # seed a run that needs one label per frame, and saying which file this is
    # beats the raw count mismatch the caller used to report.
    set have [array size byframe]
    if {$have != $maxf + 1} {
        set missing [expr {$maxf + 1 - $have}]
        error "Labels file $path labels $have frame(s) but its highest frame index\
is $maxf, leaving $missing frame(s) in 0..$maxf unlabelled. This is what a\
TRIMMED result or a \"best frames\" file looks like; an input label file must\
give a label for every frame."
    }

    set labels {}
    for {set f 0} {$f <= $maxf} {incr f} { lappend labels $byframe($f) }
    return $labels
}

# top_frames - The $m member frames of $cluster closest to that cluster's
# representative, nearest first (element 0 IS the representative). Returns
# absolute VMD frame numbers.
#
# Ranking is by mean square deviation from the representative, computed exactly
# the way representative_rmsd_matrix does it: the summed squared coordinate
# differences over the selection, divided by the atom count. That is MSD in
# MDANCE's sense, so the ordering agrees with the metric the clustering used.
#
# One honest caveat, worth knowing before comparing against MDANCE directly:
# MDANCE's own best_frames_indices_*.csv ranks by distance to the cluster
# CENTROID, whereas this ranks by distance to the MEDOID -- the representative
# the plugin already displays and exports. The two orderings agree closely but
# are not identical.
proc ::mdance::top_frames {results cluster m} {
    foreach key {labels representatives molid atomsel nClusters} {
        if {![dict exists $results $key]} {
            error "This result has no \"$key\", so its frames cannot be ranked."
        }
    }
    if {![string is integer -strict $cluster] || $cluster < 0
        || $cluster >= [dict get $results nClusters]} {
        error "No such cluster: $cluster."
    }
    if {![string is integer -strict $m] || $m < 1} {
        error "The number of frames must be a whole number of at least 1."
    }

    set molid [dict get $results molid]
    set sel_text [dict get $results atomsel]
    # Re-reading coordinates needs the original molecule; a session can be
    # loaded without it (load_session says so explicitly).
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        error "Source molecule $molid is no longer loaded, so frames cannot be ranked."
    }

    set rep_abs [abs_frame $results [lindex [dict get $results representatives] $cluster]]
    if {$rep_abs < 0} {
        error "Cluster $cluster has no representative frame in the current trajectory."
    }

    # Member sample indices, and the absolute frame each maps to. A sample the
    # frame map cannot place yields -1 and is dropped rather than silently
    # standing in for an unrelated frame.
    set labels [dict get $results labels]
    set members {}
    for {set i 0} {$i < [llength $labels]} {incr i} {
        if {[lindex $labels $i] != $cluster} continue
        set af [abs_frame $results $i]
        if {$af >= 0} { lappend members $af }
    }
    if {[llength $members] == 0} {
        error "Cluster $cluster has no frames in the current trajectory."
    }

    set sel [atomselect $molid $sel_text]
    set natoms [$sel num]
    if {$natoms == 0} {
        $sel delete
        error "Atom selection '$sel_text' matched 0 atoms."
    }

    set ranked {}
    set rc [catch {
        set ref {}
        foreach atom [_frame_coords $sel $sel_text $rep_abs $natoms] {
            foreach v $atom { lappend ref $v }
        }
        set total [llength $members]
        set every [_tick_every $total]
        set done 0
        foreach af $members {
            set sum_sq 0.0
            set k 0
            foreach atom [_frame_coords $sel $sel_text $af $natoms] {
                foreach v $atom {
                    set d [expr {$v - [lindex $ref $k]}]
                    set sum_sq [expr {$sum_sq + $d * $d}]
                    incr k
                }
            }
            lappend ranked [list [expr {$sum_sq / $natoms}] $af]
            incr done
            # live=0: this runs from a Results-tab button, which does not hold
            # ::mdance::running, so it reports progress but does not deliver
            # user input (see _extract_tick).
            if {$done % $every == 0 || $done == $total} {
                _extract_tick "Ranking cluster $cluster frames" $done $total 0
            }
        }
    } res opts]
    catch {$sel delete}
    if {$rc} { return -options $opts $res }

    # -index 0 with -real sorts by MSD; ties keep their trajectory order, so the
    # result is deterministic.
    set ranked [lsort -real -index 0 $ranked]
    set out {}
    foreach r $ranked {
        if {[llength $out] >= $m} break
        lappend out [lindex $r 1]
    }
    return $out
}

# export_top_frames - Write the top-$m frames of every cluster as CSV, with the
# rank so the ordering is reproducible outside VMD. Returns the row count.
#
# The header mirrors MDANCE's own best_frames_indices_*.csv ("frame,cluster")
# and adds the rank, which that file leaves implicit in its row order -- being
# explicit means the file survives being sorted.
proc ::mdance::export_top_frames {filename results m} {
    if {![dict exists $results nClusters]} {
        error "This result has no cluster count, so top frames cannot be exported."
    }
    set nclusters [dict get $results nClusters]
    set rows {}
    set skipped {}
    for {set c 0} {$c < $nclusters} {incr c} {
        # One unusable cluster (empty, or a representative the trajectory has
        # outgrown) must not abort the whole export; record and carry on.
        if {[catch {top_frames $results $c $m} frames]} {
            lappend skipped $c
            continue
        }
        set rank 0
        foreach af $frames {
            lappend rows "$af,$c,$rank"
            incr rank
        }
    }
    if {[llength $rows] == 0} {
        error "No cluster produced any frames to export."
    }
    set fp [open $filename w]
    set rc [catch {
        puts $fp "# top $m frames per cluster, ranked by MSD from the cluster representative"
        if {[llength $skipped] > 0} {
            puts $fp "# clusters with no usable frames (skipped): [join $skipped {, }]"
        }
        puts $fp "frame,cluster,rank"
        foreach r $rows { puts $fp $r }
    } res opts]
    # close is where buffered output is flushed, so a full disk surfaces here.
    if {$rc} {
        catch {close $fp}
    } else {
        set rc [catch {close $fp} res opts]
        if {$rc} { set res "Failed writing top frames to $filename: $res" }
    }
    if {$rc} { return -options $opts $res }
    return [llength $rows]
}

# parse_frame_ranges - Turn a "0-100,500,900-1000" specification into a sorted
# list of unique absolute frame numbers, bounded by the molecule's length.
# Every malformed piece is named, because silently dropping one would display an
# overlay the user did not ask for and believe it was complete.
proc ::mdance::parse_frame_ranges {spec molid} {
    set total [molinfo $molid get numframes]
    if {$total == 0} { error "Molecule $molid has no frames loaded." }
    array set seen {}
    foreach piece [split $spec ","] {
        set piece [string trim $piece]
        if {$piece eq ""} continue
        if {[regexp {^([0-9]+)$} $piece -> a]} {
            set b $a
        } elseif {[regexp {^([0-9]+)\s*-\s*([0-9]+)$} $piece -> a b]} {
            # ok
        } else {
            error "Cannot read \"$piece\" as a frame or a frame range. Use forms like\
0-100, 500, or 900-1000, separated by commas."
        }
        # Strip any leading zeros before comparing: "007" is integer-valid but
        # expr would read it as octal.
        scan $a %d a
        scan $b %d b
        if {$a > $b} {
            error "Range \"$piece\" runs backwards ($a is past $b)."
        }
        if {$a >= $total} {
            error "Frame $a is beyond the trajectory, which has $total frame(s) (0-[expr {$total - 1}])."
        }
        if {$b >= $total} { set b [expr {$total - 1}] }
        for {set f $a} {$f <= $b} {incr f} { set seen($f) 1 }
    }
    if {[array size seen] == 0} {
        error "No frames selected. Enter something like 0-100,500,900-1000."
    }
    return [lsort -integer [array names seen]]
}

# _need_cli - Guarantee a usable CLI path, or fail with a message that says what
# to do. Callers used to run `if {$cli_path eq ""} { init }` and carry on: when
# init loaded the LIBRARY instead, cli_path stayed empty and the command list
# began with an empty word, producing a baffling exec error.
proc ::mdance::_need_cli {} {
    variable cli_path
    if {$cli_path eq ""} { catch {init} }
    if {$cli_path eq ""} {
        error "This operation needs the mdance-cli backend, which was not found. Set the MDANCE_CLI environment variable to its path."
    }
    return $cli_path
}

# run_clustering - Execute clustering via library or CLI
# algorithm: kmeans, divine, or helm
# params: dict of parameter key-value pairs
proc ::mdance::run_clustering {algorithm params} {
    variable use_library
    variable results
    variable status
    variable running
    variable cancel_requested

    set running 1
    # Arm cancellation for THIS run. cancel_requested is otherwise only cleared
    # inside run_cli_capture, which now happens after extraction -- so a cancel
    # left set by a previous run would abort the next run's extraction instantly,
    # before the backend ever started.
    set cancel_requested 0

    # Ensure backend is available
    if {[catch {init} err]} {
        set running 0
        error "Cannot initialize MDANCE: $err"
    }

    # Run inside a catch so the running flag is always cleared (e.g. on cancel)
    set rc [catch {
        if {$use_library} {
            run_clustering_library $algorithm $params
        } else {
            run_clustering_cli $algorithm $params
        }
    } result]
    if {$rc} {
        set running 0
        # Reclaim any temp files registered before the failure (CLI mode only;
        # library mode registers none, so this is a harmless no-op there).
        ::mdance::utils::cleanup
        return -code error $result
    }

    set results $result
    # Stash the input parameters so sessions are self-documenting
    dict set results inputParams $params
    set running 0

    set nclust [dict get $results nClusters]
    set status "Done: $nclust clusters found"

    return $results
}

# run_clustering_library - Execute clustering via the loaded Tcl extension
proc ::mdance::run_clustering_library {algorithm params} {
    variable status

    set status "Extracting coordinates..."
    update idletasks

    set molid [dict get $params molid]
    set sel_text [dict get $params atomsel]
    lassign [::mdance::range_params $params] first last stride

    if {[catch {set extract_result [extract_coordinates_flat $molid $sel_text $first $last $stride]} err]} {
        set status "Error: $err"
        error $err
    }
    lassign $extract_result flat_coords natoms nframes frame_list

    set status "Running $algorithm clustering (library)..."
    update idletasks

    switch $algorithm {
        kmeans {
            set metric [expr {[dict exists $params metric] ? [dict get $params metric] : "MSD"}]
            set kinit [expr {[dict exists $params kinit] ? [dict get $params kinit] : "StratAll"}]
            set percentage [expr {[dict exists $params percentage] ? [dict get $params percentage] : 10}]
            set nclusters [dict get $params nclusters]

            set result [::mdance::kmeans $flat_coords $nframes $natoms $nclusters \
                -metric $metric -kinit $kinit -percentage $percentage]
        }
        divine {
            set metric [expr {[dict exists $params metric] ? [dict get $params metric] : "MSD"}]
            set nclusters [dict get $params nclusters]

            set cmd [list ::mdance::divine $flat_coords $nframes $natoms $nclusters \
                -metric $metric]

            foreach {flag key} {-split split -anchors anchors -kinit kinit
                                -threshold threshold -end-mode end-mode -percentage percentage} {
                if {[dict exists $params $key]} {
                    lappend cmd $flag [dict get $params $key]
                }
            }
            if {[dict exists $params refine] && [dict get $params refine]} {
                lappend cmd -refine
            }

            set result [eval $cmd]
        }
        equal {
            set metric [expr {[dict exists $params metric] ? [dict get $params metric] : "MSD"}]
            set cmd [list ::mdance::equal $flat_coords $nframes $natoms \
                -metric $metric -threshold [dict get $params threshold]]
            foreach {flag key} {-seed-method seed-method -n-seeds n-seeds
                                -percentage percentage -min-samples min-samples
                                -sim-threshold sim-threshold -align align} {
                if {[dict exists $params $key]} {
                    lappend cmd $flag [dict get $params $key]
                }
            }
            if {[dict exists $params check-sim] && [dict get $params check-sim]} {
                lappend cmd -check-sim
            }
            if {[dict exists $params reject-lowd] && [dict get $params reject-lowd]} {
                lappend cmd -reject-lowd
            }
            set result [eval $cmd]
        }
        helm {
            set metric [expr {[dict exists $params metric] ? [dict get $params metric] : "MSD"}]
            set nclusters [expr {[dict exists $params nclusters] ? [dict get $params nclusters] : 0}]

            # Handle initial labels - for library mode we need them as a list
            if {[dict exists $params initial-labels-list]} {
                set init_labels [dict get $params initial-labels-list]
            } elseif {[dict exists $params initial-labels]} {
                set init_labels [read_labels_file [dict get $params initial-labels]]
                if {[llength $init_labels] != $nframes} {
                    # Naming both counts AND the frame range matters: the
                    # usual cause is a label file computed over the whole
                    # trajectory while the Setup tab restricts first/last/stride
                    # (or vice versa), which reads as a mysterious file error.
                    error "Initial-labels file gives [llength $init_labels] label(s)\
but $nframes frame(s) were extracted. A label file must cover exactly the frames\
being clustered -- check the Setup tab's First/Last/Stride against the file."
                }
            } else {
                # Auto pre-cluster with KMeans
                set status "Pre-clustering with KMeans (library)..."
                update idletasks

                set pre_k [expr {[dict exists $params pre-k] ? [dict get $params pre-k] : 50}]
                # The pre-cluster stage IS a KMeans run, so it takes KMeans'
                # parameters. It used to be handed only the metric and K, so it
                # silently used whatever the backend defaults its initialization
                # to rather than what the user selected.
                set pre_kinit [expr {[dict exists $params pre-kinit] ? [dict get $params pre-kinit] : "StratAll"}]
                set pre_pct [expr {[dict exists $params pre-percentage] ? [dict get $params pre-percentage] : 10}]
                set pre_result [::mdance::kmeans $flat_coords $nframes $natoms $pre_k \
                    -metric $metric -kinit $pre_kinit -percentage $pre_pct]
                set init_labels [dict get $pre_result labels]

                set status "Running HELM clustering (library)..."
                update idletasks
            }

            set cmd [list ::mdance::helm $flat_coords $nframes $natoms $nclusters $init_labels \
                -metric $metric]

            foreach {flag key} {-merge-scheme merge-scheme -eps eps
                                -min-samples min-samples -trim-val trim-val -trim-k trim-k} {
                if {[dict exists $params $key]} {
                    lappend cmd $flag [dict get $params $key]
                }
            }
            if {[dict exists $params trim-start] && [dict get $params trim-start]} {
                lappend cmd -trim-start
            }

            set result [eval $cmd]
        }
    }

    # Store molecule info in results
    dict set result molid $molid
    dict set result atomsel $sel_text
    dict set result frames $frame_list

    return $result
}

# run_cli_capture - Run a CLI command (a list) asynchronously, streaming its
# merged stdout+stderr line-by-line to $status_cb so the GUI can show progress
# and stay responsive (the event loop runs during the vwait, so a Cancel button
# can fire). Returns normally on success; raises "CANCELLED" if request_cancel
# was called, or the child's error text on non-zero exit.
proc ::mdance::run_cli_capture {cmd status_cb} {
    variable async_fh
    variable async_pid
    variable async_done
    variable async_err
    variable cancel_requested

    # Single-instance state: refuse to start a second streaming run on top of an
    # in-flight one (would clobber async_fh/async_pid and corrupt both runs).
    if {$async_fh ne ""} {
        return -code error "A CLI run is already active."
    }

    set async_done 0
    set async_err ""
    set cancel_requested 0
    set ::mdance::async_tail {}
    incr ::mdance::async_run_id
    set ::mdance::async_timers {}

    # "2>@1" merges the child's stderr (where the CLI prints progress) into the
    # readable pipe. Paths here live under the temp dir and contain no spaces.
    set async_fh [open "|$cmd 2>@1" r]
    fconfigure $async_fh -blocking 0 -buffering line
    set async_pid [pid $async_fh]
    fileevent $async_fh readable [list ::mdance::_async_read $status_cb]

    vwait ::mdance::async_done

    # Disarm this run's escalation timers before anyone can start another run.
    # Leaving them pending is what let a cancelled run reach forward and kill its
    # successor; the run-id guard is the backstop, this is the actual cure.
    variable async_timers
    foreach t $async_timers { catch {after cancel $t} }
    set async_timers {}
    set async_pid ""
    set async_fh ""
    if {$cancel_requested} {
        return -code error "CANCELLED"
    }
    if {$async_err ne ""} {
        return -code error $async_err
    }
    return
}

# _async_read - fileevent handler: forward complete lines to the callback and
# detect end-of-stream / errors.
proc ::mdance::_async_read {status_cb} {
    variable async_fh
    variable async_done
    variable async_err

    if {[catch {set n [gets $async_fh line]} e]} {
        fileevent $async_fh readable {}
        catch {close $async_fh}
        set async_err $e
        set async_done 1
        return
    }
    if {$n < 0} {
        # -1 with eof => stream finished; -1 without eof => partial line, wait
        if {[eof $async_fh]} {
            fileevent $async_fh readable {}
            # Switch back to blocking so close() waits for the child and reports a
            # non-zero exit. On a non-blocking pipe close returns without the exit
            # status, so a failed CLI would otherwise slip through as a cryptic
            # "couldn't open <output>" error downstream instead of a clean failure.
            catch {fconfigure $async_fh -blocking 1}
            if {[catch {close $async_fh} ce]} {
                # Tcl reports a non-zero exit as "child process exited
                # abnormally", which tells the user nothing. The CLI's own last
                # words came through this merged stream, so attach them.
                variable async_tail
                set tail [join $async_tail " | "]
                set async_err [expr {$tail eq "" ? $ce : "$ce -- backend output: $tail"}]
            }
            set async_done 1
        }
        return
    }
    if {[string trim $line] ne ""} {
        variable async_tail
        lappend async_tail [string trim $line]
        # Keep only the tail; a long run streams thousands of progress lines.
        if {[llength $async_tail] > 5} {
            set async_tail [lrange $async_tail end-4 end]
        }
        if {$status_cb ne ""} {
            uplevel #0 [list {*}$status_cb $line]
        }
    }
}

# request_cancel - Ask an in-flight async CLI run to stop (kills the child).
# In-process library-mode runs cannot be interrupted and are unaffected.
proc ::mdance::request_cancel {} {
    variable async_pid
    variable async_run_id
    variable async_timers
    variable cancel_requested
    set cancel_requested 1
    if {$async_pid eq ""} return

    _signal_children $async_pid term

    # A child that ignores TERM -- or a wrapper script whose grandchild still
    # holds the pipe open -- would leave run_cli_capture parked in its vwait
    # forever, with the whole VMD session frozen and no way out. Escalate on a
    # timer, then abandon the channel so the run always terminates.
    #
    # The timer carries the RUN ID, not the channel name: Tcl recycles pipe
    # channel names (two successive opens both come back as e.g. "file6"), so a
    # name-based guard matched the next run and let a cancelled run destroy it.
    lappend async_timers [after 3000 [list ::mdance::_cancel_escalate $async_pid $async_run_id]]
}

# _signal_children - TERM or KILL a list of child pids, portably.
proc ::mdance::_signal_children {pids how} {
    foreach p $pids {
        if {$::tcl_platform(platform) eq "windows"} {
            # `kill` does not exist on Windows; taskkill /T ends the tree, /F forces it.
            catch {exec taskkill /F /T /PID $p}
        } elseif {$how eq "kill"} {
            catch {exec kill -9 $p}
        } else {
            catch {exec kill $p}
        }
    }
}

# _cancel_escalate - TERM was not enough; send an uncatchable KILL.
proc ::mdance::_cancel_escalate {pids rid} {
    variable async_done
    variable async_run_id
    variable async_timers
    if {$async_done || $async_run_id != $rid} return
    _signal_children $pids kill
    lappend async_timers [after 1000 [list ::mdance::_cancel_giveup $rid]]
}

# _cancel_giveup - Even KILL did not close the pipe (a grandchild still holds
# it). Stop listening and unblock the vwait; a leaked child beats a frozen VMD.
proc ::mdance::_cancel_giveup {rid} {
    variable async_done
    variable async_run_id
    variable async_fh
    if {$async_done || $async_run_id != $rid} return
    catch {fileevent $async_fh readable {}}
    catch {close $async_fh}
    set async_done 1
}

# _exec_cli - Run a CLI command list synchronously, capturing stderr so a failure
# reports what the backend actually said. `exec -ignorestderr` (what these call
# sites used to do) stops stderr from being treated as an error, but also throws
# it away -- leaving only Tcl's "child process exited abnormally" for the user.
# Redirecting stderr to a file has the same don't-treat-stderr-as-error effect
# while keeping the text.
proc ::mdance::_exec_cli {cmd} {
    set errfile [::mdance::utils::mktmp "_err.txt"]
    set rc [catch {exec {*}$cmd 2> $errfile} out opts]
    set detail ""
    if {![catch {open $errfile r} efp]} {
        catch {set detail [string trim [read $efp]]}
        catch {close $efp}
    }
    catch {file delete $errfile}
    if {$rc} {
        if {$detail ne ""} {
            # Cap it: a crashing backend can emit a great deal of text.
            if {[string length $detail] > 500} {
                set detail "...[string range $detail end-499 end]"
            }
            return -code error "$out -- backend output: $detail"
        }
        return -options $opts $out
    }
    return $out
}

# _require_valid_result - Reject backend output the plugin cannot safely use.
#
# parse_json is a regex scraper: truncated or malformed output yields a PARTIAL
# dict rather than an error, and a label list of the wrong length silently shifts
# every sample's cluster when the labels are mapped back onto the trajectory.
proc ::mdance::_require_valid_result {result nframes {what "Backend output"}} {
    foreach key {labels nClusters clusterSizes representatives} {
        if {![dict exists $result $key]} {
            error "$what is missing '$key' -- the run was probably truncated or the JSON is malformed."
        }
    }
    set nlab [llength [dict get $result labels]]
    if {$nlab != $nframes} {
        error "$what returned $nlab labels for $nframes extracted frames; refusing to map them onto the trajectory."
    }
}

# _cli_progress - default progress sink: surface the CLI's status lines
proc ::mdance::_cli_progress {line} {
    variable status
    set status $line
}

# run_clustering_cli - Execute clustering via CLI subprocess (fallback)
proc ::mdance::run_clustering_cli {algorithm params} {
    variable cli_path
    variable status

    set status "Extracting coordinates..."
    update idletasks

    set molid [dict get $params molid]
    set sel_text [dict get $params atomsel]
    lassign [::mdance::range_params $params] first last stride

    if {[catch {set extract_result [extract_coordinates $molid $sel_text $first $last $stride]} err]} {
        set status "Error: $err"
        error $err
    }
    lassign $extract_result csv_path natoms nframes frame_list

    set status "Running $algorithm clustering..."
    update idletasks

    # Build command line
    set output_path [::mdance::utils::mktmp ".json"]
    set cmd [list $cli_path \
        --algorithm $algorithm \
        --input $csv_path \
        --output $output_path \
        --natoms $natoms]

    # Add common parameters
    foreach key {nclusters metric} {
        if {[dict exists $params $key]} {
            lappend cmd --$key [dict get $params $key]
        }
    }

    # Add algorithm-specific parameters
    switch $algorithm {
        kmeans {
            foreach key {kinit percentage} {
                if {[dict exists $params $key]} {
                    lappend cmd --$key [dict get $params $key]
                }
            }
        }
        divine {
            foreach key {split anchors kinit threshold end-mode percentage} {
                if {[dict exists $params $key]} {
                    lappend cmd --$key [dict get $params $key]
                }
            }
            if {[dict exists $params refine] && [dict get $params refine]} {
                lappend cmd --refine
            }
        }
        equal {
            foreach key {threshold seed-method n-seeds percentage min-samples sim-threshold align} {
                if {[dict exists $params $key]} {
                    lappend cmd --$key [dict get $params $key]
                }
            }
            if {[dict exists $params check-sim] && [dict get $params check-sim]} {
                lappend cmd --check-sim
            }
            if {[dict exists $params reject-lowd] && [dict get $params reject-lowd]} {
                lappend cmd --reject-lowd
            }
        }
        helm {
            foreach key {merge-scheme eps min-samples trim-val trim-k} {
                if {[dict exists $params $key]} {
                    lappend cmd --$key [dict get $params $key]
                }
            }
            if {[dict exists $params trim-start] && [dict get $params trim-start]} {
                lappend cmd --trim-start
            }

            # Handle initial labels. Normalize the user's file first so both
            # backends accept the same inputs -- including the plugin's own
            # exported "frame,cluster" CSV -- and so a wrong label count is
            # reported here rather than misinterpreted by the backend.
            if {[dict exists $params initial-labels]} {
                set init_labels [read_labels_file [dict get $params initial-labels]]
                if {[llength $init_labels] != $nframes} {
                    # Naming both counts AND the frame range matters: the
                    # usual cause is a label file computed over the whole
                    # trajectory while the Setup tab restricts first/last/stride
                    # (or vice versa), which reads as a mysterious file error.
                    error "Initial-labels file gives [llength $init_labels] label(s)\
but $nframes frame(s) were extracted. A label file must cover exactly the frames\
being clustered -- check the Setup tab's First/Last/Stride against the file."
                }
                set norm_csv [::mdance::utils::mktmp "_init.csv"]
                set nfp [open $norm_csv w]
                set nrc [catch {foreach l $init_labels { puts $nfp $l }} nres nopts]
                if {$nrc} {
                    catch {close $nfp}
                } else {
                    set nrc [catch {close $nfp} nres nopts]
                }
                if {$nrc} { return -options $nopts $nres }
                lappend cmd --initial-labels $norm_csv
            } else {
                # Auto pre-cluster with KMeans
                set status "Pre-clustering with KMeans..."
                update idletasks

                set pre_k [expr {[dict exists $params pre-k] ? [dict get $params pre-k] : 50}]
                # See the library path above: this stage takes KMeans'
                # parameters, not just the metric and K.
                set pre_cmd [list $cli_path \
                    --algorithm kmeans \
                    --input $csv_path \
                    --output [set pre_output [::mdance::utils::mktmp "_pre.json"]] \
                    --natoms $natoms \
                    --nclusters $pre_k \
                    --metric [expr {[dict exists $params metric] ? [dict get $params metric] : "MSD"}] \
                    --kinit [expr {[dict exists $params pre-kinit] ? [dict get $params pre-kinit] : "StratAll"}] \
                    --percentage [expr {[dict exists $params pre-percentage] ? [dict get $params pre-percentage] : 10}]]

                if {[catch {run_cli_capture $pre_cmd ::mdance::_cli_progress} pre_err]} {
                    if {$pre_err eq "CANCELLED"} {
                        set status "Cancelled."
                        error "Clustering cancelled."
                    }
                    set status "Pre-clustering error: $pre_err"
                    error "Pre-clustering failed: $pre_err"
                }

                # Extract labels from pre-clustering result and write as CSV.
                # Validate it exactly like the final result: this is the DEFAULT
                # HELM path, and a truncated pre-cluster JSON would otherwise be
                # written out as a short label file and blamed on HELM itself.
                set pre_result [::mdance::utils::parse_json $pre_output]
                _require_valid_result $pre_result $nframes "Pre-clustering output"
                set pre_labels [dict get $pre_result labels]
                set labels_csv [::mdance::utils::mktmp "_labels.csv"]
                set lfp [open $labels_csv w]
                set prc [catch {foreach l $pre_labels { puts $lfp $l }} pres popts]
                if {$prc} {
                    catch {close $lfp}
                } else {
                    set prc [catch {close $lfp} pres popts]
                }
                if {$prc} { return -options $popts $pres }
                lappend cmd --initial-labels $labels_csv

                set status "Running HELM clustering..."
                update idletasks
            }
        }
    }

    # Execute CLI asynchronously so the run streams progress and can be cancelled
    if {[catch {run_cli_capture $cmd ::mdance::_cli_progress} err]} {
        if {$err eq "CANCELLED"} {
            set status "Cancelled."
            error "Clustering cancelled."
        }
        set status "Error: $err"
        error "mdance-cli failed: $err"
    }

    # Parse results
    set status "Loading results..."
    update idletasks

    if {[catch {set result [::mdance::utils::parse_json $output_path]} err]} {
        set status "Error parsing results: $err"
        error $err
    }

    _require_valid_result $result $nframes

    # Store molecule info in results
    dict set result molid $molid
    dict set result atomsel $sel_text
    dict set result frames $frame_list

    # Clean up temp files
    ::mdance::utils::cleanup

    return $result
}

# apply_cluster_colors - Set VMD User field and coloring by cluster
proc ::mdance::apply_cluster_colors {} {
    variable results
    variable status

    if {$results eq ""} {
        error "No clustering results available."
    }

    set molid [dict get $results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        error "Source molecule $molid is no longer loaded."
    }
    set labels [dict get $results labels]
    set nsub [llength $labels]
    set nclusters [dict get $results nClusters]
    set total [molinfo $molid get numframes]

    # Resolve every sample to its absolute frame FIRST, so we know exactly which
    # frames this result paints. The old code decided whether to run the
    # "reset everything to unassigned" pass from the frame map's LENGTH, which is
    # wrong whenever the trajectory changed length after the analysis: the map can
    # still be as long as the molecule while covering different frames, leaving
    # stale colours on frames this result says nothing about.
    array set painted {}
    set skipped 0
    for {set i 0} {$i < $nsub} {incr i} {
        set af [::mdance::abs_frame $results $i]
        # Both failures count. abs_frame returns -1 for "the frame map does not
        # reach this sample" as well as for an empty cluster, and skipping that
        # silently is exactly the partial-colouring-that-looks-complete this
        # count exists to prevent.
        if {$af < 0 || $af >= $total} { incr skipped; continue }
        # Canonicalise: a map entry of " 7" or "007" would be painted under one
        # key and probed under another, so the frame would be repainted -1 by
        # the reset pass below.
        set painted([expr {int($af)}]) [lindex $labels $i]
    }

    set sel [atomselect $molid all]
    set rc [catch {
        # Anything this result does not paint is explicitly unassigned.
        foreach f [lsort -integer [array names painted]] {
            $sel frame $f
            $sel set user [expr {double($painted($f))}]
        }
        for {set f 0} {$f < $total} {incr f} {
            if {[info exists painted($f)]} continue
            $sel frame $f
            $sel set user -1.0
        }
    } res opts]
    catch {$sel delete}
    if {$rc} { return -options $opts $res }

    # Configure representation for cluster coloring. Ensure rep 0 exists (the
    # user may have deleted all reps), and keep the scale range non-degenerate
    # (min != max) so a 1-cluster result still colors.
    if {[molinfo $molid get numreps] == 0} {
        mol addrep $molid
    }
    mol modcolor 0 $molid User
    mol scaleminmax $molid 0 0.0 [expr {max(1.0, double($nclusters - 1))}]
    color scale method BGR
    display update

    # Never let a partial colouring look complete. Returns the number of samples
    # that could not be placed so the GUI can say so.
    if {$skipped > 0} {
        set status "Coloured [array size painted] frames; $skipped sample(s) could not be placed in the current $total-frame trajectory."
    }
    return $skipped
}

# goto_representative - Navigate to a representative frame
proc ::mdance::goto_representative {cluster_idx} {
    variable results

    if {$results eq ""} {
        error "No clustering results available."
    }

    set reps [dict get $results representatives]
    if {$cluster_idx < 0 || $cluster_idx >= [llength $reps]} {
        error "Invalid cluster index: $cluster_idx"
    }

    set molid [dict get $results molid]
    set frame_idx [::mdance::abs_frame $results [lindex $reps $cluster_idx]]
    if {$frame_idx < 0} {
        error "Cluster $cluster_idx has no representative frame (empty cluster)."
    }
    set total [molinfo $molid get numframes]
    if {$frame_idx >= $total} {
        error "Representative frame $frame_idx is beyond the current trajectory ($total frames). Was the molecule reloaded?"
    }
    animate goto $frame_idx
    display update
}

# export_labels - Save cluster labels to a CSV file
proc ::mdance::export_labels {filename} {
    variable results

    if {$results eq ""} {
        error "No clustering results available."
    }

    set labels [dict get $results labels]
    set fp [open $filename w]
    set rc [catch {
        puts $fp "frame,cluster"
        for {set i 0} {$i < [llength $labels]} {incr i} {
            puts $fp "[::mdance::abs_frame $results $i],[lindex $labels $i]"
        }
    } res opts]
    # Report a failed flush rather than claiming the export succeeded: the user
    # would otherwise keep a truncated label CSV believing it is complete.
    if {$rc} {
        catch {close $fp}
    } else {
        set rc [catch {close $fp} res opts]
        if {$rc} { set res "Failed writing labels to $filename: $res" }
    }
    if {$rc} { return -options $opts $res }
}

# extract_csv_for_frames - Write a CSV of coordinates for an explicit list of
# absolute VMD frames (used by analysis on an already-computed result, whose
# frame list may be arbitrary, e.g. a sweep-loaded run). Row order == $frames.
# Returns {csv_path natoms}.
proc ::mdance::extract_csv_for_frames {molid sel_text frames} {
    set sel [atomselect $molid $sel_text]
    set natoms [$sel num]
    if {$natoms == 0} {
        $sel delete
        error "Atom selection '$sel_text' matched 0 atoms."
    }
    set csv [::mdance::utils::mktmp ".csv"]
    set fp [open $csv w]
    set nframes [llength $frames]
    set every [_tick_every $nframes]
    set rc [catch {
        set done 0
        foreach f $frames {
            set row {}
            foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                lappend row [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
            }
            puts $fp [join $row ","]
            incr done
            # live=0: this runs from post-hoc analysis, which does NOT hold
            # ::mdance::running, so delivering user input here would let a
            # clustering run start on top of it. Progress only, no cancel.
            if {$done % $every == 0 || $done == $nframes} {
                _extract_tick "Reading frames" $done $nframes 0
            }
        }
    } res opts]
    if {$rc} {
        catch {close $fp}
    } else {
        set rc [catch {close $fp} res opts]
        if {$rc} { set res "Failed writing coordinates to $csv: $res" }
    }
    catch {$sel delete}
    if {$rc} { return -options $opts $res }
    return [list $csv $natoms]
}

# run_analysis - Compute extended-similarity (iSIM) analysis for a set of frames
# and per-sample labels. Returns a dict with keys: isim, clusterISIM,
# clusterOutliers (outlier indices are SAMPLE indices, i.e. positions in
# $frames -- map with abs_frame for display). Works in both backends.
proc ::mdance::run_analysis {molid sel_text frames labels metric} {
    variable use_library
    variable cli_path

    # Resolve a backend BEFORE choosing a path. With neither loaded yet
    # use_library is still 0, so the CLI branch was taken even when init was
    # about to load the library -- leaving cli_path empty.
    if {!$use_library && $cli_path eq ""} { catch {init} }

    if {$use_library} {
        set sel [atomselect $molid $sel_text]
        set natoms [$sel num]
        if {$natoms == 0} { $sel delete; error "Atom selection '$sel_text' matched 0 atoms." }
        set flat {}
        set rc [catch {
            foreach f $frames {
                foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                    lappend flat [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
                }
            }
        } res opts]
        catch {$sel delete}
        if {$rc} { return -options $opts $res }
        return [::mdance::analysis $flat [llength $frames] $natoms -metric $metric -labels $labels]
    }

    _need_cli
    lassign [extract_csv_for_frames $molid $sel_text $frames] csv natoms
    set lcsv [::mdance::utils::mktmp "_lab.csv"]
    set lfp [open $lcsv w]
    set rc [catch {foreach l $labels { puts $lfp $l }} res opts]
    catch {close $lfp}
    if {$rc} { catch {file delete $csv}; catch {file delete $lcsv}; return -options $opts $res }
    set out [::mdance::utils::mktmp ".json"]
    set cmd [list $cli_path --analysis --input $csv --output $out \
        --natoms $natoms --metric $metric --labels $lcsv]
    # Wrap exec+parse so a non-zero CLI exit (which exec raises) still deletes temps.
    set rc [catch {_exec_cli $cmd; ::mdance::utils::parse_json $out} result opts]
    catch {file delete $out}
    catch {file delete $csv}
    catch {file delete $lcsv}
    if {$rc} { return -options $opts $result }
    return $result
}

# run_prime - PRIME representative/"native" frame prediction for an existing
# clustering (frames + per-sample labels). Returns a dict with keys pairwise,
# union, medoid, outlier, medoidAll, medoidC0, medoidC0Trimmed, nClusters. The
# frame fields are SAMPLE indices (positions in $frames); map with abs_frame.
proc ::mdance::run_prime {molid sel_text frames labels metric trimFrac weighted} {
    variable use_library
    variable cli_path

    # Resolve a backend BEFORE choosing a path. With neither loaded yet
    # use_library is still 0, so the CLI branch was taken even when init was
    # about to load the library -- leaving cli_path empty.
    if {!$use_library && $cli_path eq ""} { catch {init} }

    if {$use_library} {
        set sel [atomselect $molid $sel_text]
        set natoms [$sel num]
        if {$natoms == 0} { $sel delete; error "Atom selection '$sel_text' matched 0 atoms." }
        set flat {}
        set rc [catch {
            foreach f $frames {
                foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                    lappend flat [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
                }
            }
        } res opts]
        catch {$sel delete}
        if {$rc} { return -options $opts $res }
        set cmd [list ::mdance::prime $flat [llength $frames] $natoms \
            -metric $metric -labels $labels -trim-frac $trimFrac]
        if {$weighted} { lappend cmd -weighted }
        return [eval $cmd]
    }

    _need_cli
    lassign [extract_csv_for_frames $molid $sel_text $frames] csv natoms
    set lcsv [::mdance::utils::mktmp "_lab.csv"]
    set lfp [open $lcsv w]
    set rc [catch {foreach l $labels { puts $lfp $l }} res opts]
    catch {close $lfp}
    if {$rc} { catch {file delete $csv}; catch {file delete $lcsv}; return -options $opts $res }
    set out [::mdance::utils::mktmp ".json"]
    set cmd [list $cli_path --prime --input $csv --output $out \
        --natoms $natoms --metric $metric --labels $lcsv --trim-frac $trimFrac]
    if {$weighted} { lappend cmd --weighted }
    set rc [catch {_exec_cli $cmd; ::mdance::utils::parse_json $out} result opts]
    catch {file delete $out}
    catch {file delete $csv}
    catch {file delete $lcsv}
    if {$rc} { return -options $opts $result }
    return $result
}

# run_select - Frame-selection tools (diversity / outliers / repsample / medoid /
# outlier) over a set of frames. Returns a list of SAMPLE indices (positions in
# $frames); map with abs_frame / [lindex $frames $i] for absolute VMD frames.
proc ::mdance::run_select {molid sel_text frames method metric param nbins} {
    variable use_library
    variable cli_path

    # Resolve a backend BEFORE choosing a path. With neither loaded yet
    # use_library is still 0, so the CLI branch was taken even when init was
    # about to load the library -- leaving cli_path empty.
    if {!$use_library && $cli_path eq ""} { catch {init} }

    if {$use_library} {
        set sel [atomselect $molid $sel_text]
        set natoms [$sel num]
        if {$natoms == 0} { $sel delete; error "Atom selection '$sel_text' matched 0 atoms." }
        set flat {}
        set rc [catch {
            foreach f $frames {
                foreach atom [_frame_coords $sel $sel_text $f $natoms] {
                    lappend flat [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]
                }
            }
        } res opts]
        catch {$sel delete}
        if {$rc} { return -options $opts $res }
        return [::mdance::select $flat [llength $frames] $natoms \
            -metric $metric -method $method -param $param -nbins $nbins]
    }

    _need_cli
    lassign [extract_csv_for_frames $molid $sel_text $frames] csv natoms
    set out [::mdance::utils::mktmp ".json"]
    set cmd [list $cli_path --select --input $csv --output $out \
        --natoms $natoms --metric $metric --method $method --param $param --nbins $nbins]
    set rc [catch {_exec_cli $cmd; ::mdance::utils::parse_json $out} result opts]
    catch {file delete $out}
    catch {file delete $csv}
    if {$rc} { return -options $opts $result }
    return [expr {[dict exists $result indices] ? [dict get $result indices] : {}}]
}

# write_frames_to_file - Write an arbitrary (possibly non-contiguous) list of
# absolute VMD frames to a single structure/trajectory file.
#
# VMD's `animate write` OVERWRITES its target on each call and only accepts a
# contiguous beg/end/skip range -- it cannot append, and cannot take an explicit
# frame list. So for >1 non-contiguous frame we assemble the selected frames into
# a fresh in-memory molecule (built from the chosen selection) and then write that
# molecule once over its full 0..N-1 range. Mirrors VMD's own modelmaker plugin.
#
#   molid    - source molecule id
#   seltext  - atom selection to export (e.g. "all" or "protein and name CA")
#   frames   - list of absolute VMD frame indices (already mapped via abs_frame)
#   out_path - output file
#   fmt      - "pdb" or "dcd"
proc ::mdance::write_frames_to_file {molid seltext frames out_path fmt} {
    set n [llength $frames]
    if {$n == 0} {
        error "No frames to write."
    }

    set src [atomselect $molid $seltext]
    if {[$src num] == 0} {
        $src delete
        error "Atom selection '$seltext' matched 0 atoms."
    }

    # Do the work under a catch so an error mid-build (animate dup/write, a
    # coordinate count mismatch, etc.) never orphans the temp molecule $dest,
    # the per-iteration selection $d, $allsel, or $src in the VMD molecule list.
    set rc [catch {
        if {$n == 1 && $fmt eq "pdb"} {
            # Single PDB frame: write directly, no temp molecule needed.
            $src frame [lindex $frames 0]
            $src update
            $src writepdb $out_path
        } else {
            # General case: build a temp molecule containing only the selected
            # atoms, one timestep per requested frame, then write it once.
            set tmppdb [::mdance::utils::mktmp ".pdb"]
            $src frame [lindex $frames 0]
            $src update
            $src writepdb $tmppdb
            set dest [mol new $tmppdb waitfor all]
            catch {file delete $tmppdb}

            for {set i 1} {$i < $n} {incr i} {
                animate dup frame 0 $dest
                set last [expr {[molinfo $dest get numframes] - 1}]
                $src frame [lindex $frames $i]
                $src update
                set d [atomselect $dest all frame $last]
                $d set {x y z} [$src get {x y z}]
                $d delete
                unset d
            }

            set nf [molinfo $dest get numframes]
            set allsel [atomselect $dest all]
            animate write $fmt $out_path beg 0 end [expr {$nf - 1}] waitfor all sel $allsel $dest
            $allsel delete
            mol delete $dest
        }
    } res opts]
    if {$rc} {
        catch {$d delete}
        catch {$allsel delete}
        catch {mol delete $dest}
    }
    catch {$src delete}
    if {$rc} { return -options $opts $res }
}

# export_representatives - Write the medoid (representative) frame of every
# cluster to a single multi-frame file (one model/timestep per cluster).
# Returns the number of representatives written.
proc ::mdance::export_representatives {out_path fmt {seltext "all"}} {
    variable results
    if {$results eq ""} {
        error "No clustering results available."
    }
    set molid [dict get $results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        error "Source molecule $molid is no longer loaded."
    }

    set reps [dict get $results representatives]
    set frames {}
    foreach r $reps {
        set af [::mdance::abs_frame $results $r]
        if {$af >= 0} { lappend frames $af }
    }
    if {[llength $frames] == 0} {
        error "No valid representative frames to export."
    }

    write_frames_to_file $molid $seltext $frames $out_path $fmt

    # A DCD has no topology; write a companion PDB so it is loadable standalone.
    if {$fmt eq "dcd"} {
        write_frames_to_file $molid $seltext [list [lindex $frames 0]] \
            "[file rootname $out_path].pdb" pdb
    }
    return [llength $frames]
}

# export_clusters_split - Write one file per cluster containing all of that
# cluster's member frames (as a trajectory). Files are named cluster_<id>.<fmt>
# in $dir. Returns the number of cluster files written.
proc ::mdance::export_clusters_split {dir fmt {seltext "all"}} {
    variable results
    if {$results eq ""} {
        error "No clustering results available."
    }
    set molid [dict get $results molid]
    if {[lsearch -exact [molinfo list] $molid] < 0} {
        error "Source molecule $molid is no longer loaded."
    }

    set labels [dict get $results labels]
    set nclusters [dict get $results nClusters]

    # Group absolute frames by cluster
    for {set c 0} {$c < $nclusters} {incr c} { set members($c) {} }
    for {set i 0} {$i < [llength $labels]} {incr i} {
        set c [lindex $labels $i]
        set af [::mdance::abs_frame $results $i]
        if {$af >= 0 && [info exists members($c)]} {
            lappend members($c) $af
        }
    }

    set written 0
    for {set c 0} {$c < $nclusters} {incr c} {
        if {[llength $members($c)] == 0} continue
        set out [file join $dir "cluster_$c.$fmt"]
        write_frames_to_file $molid $seltext $members($c) $out $fmt
        if {$fmt eq "dcd"} {
            write_frames_to_file $molid $seltext [list [lindex $members($c) 0]] \
                [file join $dir "cluster_$c.pdb"] pdb
        }
        incr written
    }
    if {$written == 0} {
        error "No non-empty clusters to export."
    }
    return $written
}

# run_one_config - Execute one clustering configuration and return the result
# dict (labels/clusterSizes/representatives/clusterMSD/score_*/nClusters). Does
# NOT attach molid/atomsel/frames -- the caller adds those. Coordinates are
# extracted once by the caller and passed in via $extract so a sweep/elbow does
# not re-read the trajectory per configuration.
#
#   extract: dict, one of
#       {mode library flat <flatlist> natoms N nframes M}
#       {mode cli     csv  <path>     natoms N}
#   config:  dict {algorithm a nclusters k ?metric m? ?kinit ki? ?percentage p?
#                   ?merge-scheme ms? ?initial-labels csv? ?initial-labels-list l?}
#
# HELM needs initial labels, which the caller supplies ONCE and reuses for every
# k -- HELM's k is a cut of a single dendrogram, so re-deriving the starting
# partition per k would be both slower and a different question.
proc ::mdance::run_one_config {extract config} {
    variable cli_path

    set algorithm [dict get $config algorithm]
    set k         [dict get $config nclusters]
    set metric [expr {[dict exists $config metric]     ? [dict get $config metric]     : "MSD"}]
    set kinit  [expr {[dict exists $config kinit]      ? [dict get $config kinit]      : "StratAll"}]
    set pct    [expr {[dict exists $config percentage] ? [dict get $config percentage] : 10}]
    set merge  [expr {[dict exists $config merge-scheme] ? [dict get $config merge-scheme] : "Inter"}]

    if {[dict get $extract mode] eq "library"} {
        set flat    [dict get $extract flat]
        set natoms  [dict get $extract natoms]
        set nframes [dict get $extract nframes]
        switch $algorithm {
            kmeans {
                return [::mdance::kmeans $flat $nframes $natoms $k \
                    -metric $metric -kinit $kinit -percentage $pct]
            }
            divine {
                return [::mdance::divine $flat $nframes $natoms $k \
                    -metric $metric -kinit $kinit]
            }
            helm {
                if {![dict exists $config initial-labels-list]} {
                    error "HELM needs initial labels; none were supplied."
                }
                return [::mdance::helm $flat $nframes $natoms $k \
                    [dict get $config initial-labels-list] \
                    -metric $metric -merge-scheme $merge]
            }
            default { error "Unsupported algorithm: $algorithm" }
        }
    }

    # CLI mode
    _need_cli
    set csv    [dict get $extract csv]
    set natoms [dict get $extract natoms]
    set out [::mdance::utils::mktmp ".json"]
    set cmd [list $cli_path \
        --algorithm $algorithm \
        --input $csv \
        --output $out \
        --natoms $natoms \
        --nclusters $k \
        --metric $metric]
    switch $algorithm {
        kmeans { lappend cmd --kinit $kinit --percentage $pct }
        divine { lappend cmd --kinit $kinit }
        helm {
            if {![dict exists $config initial-labels]} {
                error "HELM needs initial labels; none were supplied."
            }
            lappend cmd --merge-scheme $merge \
                --initial-labels [dict get $config initial-labels]
        }
    }
    set rc [catch {_exec_cli $cmd; ::mdance::utils::parse_json $out} result opts]
    catch {file delete $out}
    if {$rc} { return -options $opts $result }
    return $result
}

# save_session - Serialize the current results (which already carries the input
# parameters, molecule id, atom selection and frame map) to a single file. The
# results dict is itself a valid Tcl dict, so it round-trips verbatim.
proc ::mdance::save_session {filename} {
    variable results
    if {$results eq ""} {
        error "No clustering results to save."
    }
    # Record enough to RECOGNIZE the molecule later. A molid on its own is just a
    # slot number, and VMD hands the same number to whatever is loaded next, so
    # without this a session reloaded into a different session's molecule looks
    # perfectly live while its frame indices point into another trajectory.
    # molKnown distinguishes "this file predates signatures" (no molSignature at
    # all -> fall back to the old molid check) from "the molecule was already
    # gone when we saved" (signature present but empty -> identity is
    # unverifiable, so the session must NOT be reported as live).
    set molSig [dict create molKnown 0]
    if {[dict exists $results molid]} {
        set mid [dict get $results molid]
        if {[lsearch -exact [molinfo list] $mid] >= 0} {
            catch {dict set molSig molName [molinfo $mid get name]}
            catch {dict set molSig molFrames [molinfo $mid get numframes]}
            if {[dict exists $molSig molName] || [dict exists $molSig molFrames]} {
                dict set molSig molKnown 1
            }
        }
    }

    set session [dict create \
        mdanceSession 1 \
        savedAt [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] \
        molSignature $molSig \
        results $results]

    # Write to a sibling temp file and rename into place. Writing directly would
    # truncate the target first, so a failure part-way through (full disk, lost
    # permissions) would destroy a perfectly good existing session and leave a
    # half-written file that load_session cannot read.
    set tmp "$filename.tmp[pid]"
    set fp [open $tmp w]
    set rc [catch {puts $fp $session} res opts]
    if {$rc} {
        catch {close $fp}
    } else {
        set rc [catch {close $fp} res opts]
    }
    if {$rc} {
        catch {file delete -force $tmp}
        return -options $opts $res
    }
    if {[catch {file rename -force $tmp $filename} rerr]} {
        catch {file delete -force $tmp}
        error "Could not save session to $filename: $rerr"
    }
}

# load_session - Restore a saved session into ::mdance::results. The molecule it
# was computed from may not be loaded; score/table/label-based views still work,
# while coordinate-re-extracting plots and structure export require the original
# molecule. Returns 1 if the saved molecule is currently loaded, 0 otherwise.
proc ::mdance::load_session {filename} {
    variable results
    set fp [open $filename r]
    set content [read $fp]
    close $fp
    if {[catch {dict get $content mdanceSession} ver] || $ver eq ""} {
        error "Not a valid MDANCE session file."
    }
    if {![dict exists $content results]} {
        error "Session file has no results block."
    }
    set res [dict get $content results]
    foreach key {labels nClusters clusterSizes representatives} {
        if {![dict exists $res $key]} {
            error "Session results are missing '$key' -- file may be corrupt."
        }
    }

    # Key presence is not enough. An internally inconsistent session loads fine
    # here and then dies much later inside a plot, where the real cause is
    # invisible -- so reject it now, while we can still name the problem.
    set nclust [dict get $res nClusters]
    if {![string is integer -strict $nclust] || $nclust < 0} {
        error "Session results have a non-numeric nClusters ('$nclust') -- file may be corrupt."
    }
    foreach key {clusterSizes representatives} {
        set n [llength [dict get $res $key]]
        if {$n != $nclust} {
            error "Session results are inconsistent: nClusters is $nclust but '$key' has $n entries."
        }
    }
    set slabels [dict get $res labels]
    if {[llength $slabels] == 0} {
        error "Session results contain no labels -- file may be corrupt."
    }
    foreach l $slabels {
        if {![string is integer -strict $l]} {
            error "Session results contain a non-integer cluster label ('$l')."
        }
    }
    if {[dict exists $res frames]} {
        set nf [llength [dict get $res frames]]
        if {$nf < [llength $slabels]} {
            error "Session results are inconsistent: [llength $slabels] labels but only $nf frames in the map."
        }
    }

    set results $res

    set molid [expr {[dict exists $res molid] ? [dict get $res molid] : ""}]
    if {$molid eq "" || [lsearch -exact [molinfo list] $molid] < 0} {
        return 0
    }

    # The slot is occupied, but is it the same molecule? If the name or frame
    # count disagrees with what was saved, the stored frame indices address a
    # different trajectory -- report "not live" so the caller shows its caution
    # dialog instead of silently colouring and exporting the wrong molecule.
    # Sessions written before molSignature existed simply skip this check.
    if {[dict exists $content molSignature]} {
        set sig [dict get $content molSignature]
        if {![dict exists $sig molKnown] || ![dict get $sig molKnown]} {
            return 0    ;# saved without a usable identity -- cannot verify
        }
        if {[dict exists $sig molName]} {
            if {[catch {molinfo $molid get name} nm] || $nm ne [dict get $sig molName]} {
                return 0
            }
        }
        if {[dict exists $sig molFrames]} {
            if {[catch {molinfo $molid get numframes} nf] || $nf != [dict get $sig molFrames]} {
                return 0
            }
        }
    }
    return 1
}

# run_single_k - Run clustering for a single K value (used by the elbow plot).
# Takes a pre-extracted csv_path; delegates to run_one_config (MSD + CompSim, to
# preserve the elbow's historical behavior) and does NOT extract coordinates.
# _extract_from_csv - Build the $extract dict run_one_config expects from a CSV
# the caller already wrote. In library mode the file is read back into a flat
# list; in CLI mode the path is handed straight through.
proc ::mdance::_extract_from_csv {csv_path natoms} {
    variable use_library
    if {!$use_library} {
        return [dict create mode cli csv $csv_path natoms $natoms]
    }
    set fp [open $csv_path r]
    set flat_coords {}
    set nframes 0
    set rc [catch {
        while {[gets $fp line] >= 0} {
            set line [string trim $line]
            if {$line ne ""} {
                foreach val [split $line ","] {
                    lappend flat_coords [string trim $val]
                }
                incr nframes
            }
        }
    } res opts]
    catch {close $fp}
    if {$rc} { return -options $opts $res }
    return [dict create mode library flat $flat_coords natoms $natoms nframes $nframes]
}

proc ::mdance::run_single_k {algorithm csv_path natoms nclusters {extra {}}} {
    set extract [_extract_from_csv $csv_path $natoms]

    # kinit tracks the KMeans tab default (StratAll), so an elbow curve is
    # comparable with the single runs the user makes from that tab. $extra
    # carries whatever the algorithm additionally needs -- for HELM, the shared
    # initial labels the caller derived once for the whole scan.
    return [run_one_config $extract \
        [dict merge [dict create algorithm $algorithm nclusters $nclusters \
                         metric MSD kinit StratAll] $extra]]
}

# elbow_prepare - Whatever an elbow scan must compute ONCE, before the per-k
# loop, and pass to every run_single_k call as its $extra.
#
# For HELM that is the starting partition. HELM's k is a cut of one dendrogram
# built from an initial set of clusters, so the pre-cluster step belongs outside
# the k loop: doing it per k would re-answer a different question at every point
# and make the curve incomparable, besides costing a KMeans run per k.
# Returns a dict suitable as run_single_k's $extra ({} for algorithms that need
# nothing).
proc ::mdance::elbow_prepare {algorithm csv_path natoms params} {
    if {$algorithm ne "helm"} { return {} }
    set extract [_extract_from_csv $csv_path $natoms]

    set pre_k  [expr {[dict exists $params pre-k] ? [dict get $params pre-k] : 50}]
    set kinit  [expr {[dict exists $params pre-kinit] ? [dict get $params pre-kinit] : "StratAll"}]
    set pct    [expr {[dict exists $params pre-percentage] ? [dict get $params pre-percentage] : 10}]
    set merge  [expr {[dict exists $params merge-scheme] ? [dict get $params merge-scheme] : "Inter"}]

    set pre [run_one_config $extract [dict create algorithm kmeans \
        nclusters $pre_k metric MSD kinit $kinit percentage $pct]]
    if {![dict exists $pre labels]} {
        error "Pre-clustering produced no labels, so HELM cannot be scanned."
    }
    set labels [dict get $pre labels]

    set extra [dict create merge-scheme $merge initial-labels-list $labels]
    if {[dict get $extract mode] ne "library"} {
        # The CLI takes the labels as a file. It is registered as a temp file, so
        # the caller's ::mdance::utils::cleanup reclaims it after the scan.
        set lcsv [::mdance::utils::mktmp "_elbow_init.csv"]
        set fp [open $lcsv w]
        set rc [catch {foreach l $labels { puts $fp $l }} res opts]
        if {$rc} {
            catch {close $fp}
        } else {
            set rc [catch {close $fp} res opts]
        }
        if {$rc} { return -options $opts $res }
        dict set extra initial-labels $lcsv
    }
    return $extra
}

# gui - Main entry point called by VMD extension registration
proc ::mdance::gui {} {
    variable w

    if {[winfo exists .mdance]} {
        wm deiconify .mdance
        raise .mdance
        return .mdance
    }

    return [::mdance::gui::create_window]
}
