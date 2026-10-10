#
# VMDance - the MDANCE backend: finding it, what it can do, running it
# (no Tk dependency)
#
# The clustering is CPP-MDANCE's, reached two ways:
#   cli      its mdance-cli program, run in the background (the window and
#            VMD stay usable; Cancel stops it): coordinates go in as a CSV
#            file, results come back as JSON
#   library  its Tcl extension (mdance_tcl), loaded into VMD: coordinates
#            are passed in memory, as one list (about 180 bytes a number
#            at a call's peak: Job::_library_fits), results come back as a
#            dict; a call blocks VMD until it returns and cannot be
#            cancelled (the CSV file is written all the same)
# "auto" uses the program when there is one, else the library. Settings'
# choice is kept in the preferences, which a script reads too (from_prefs).
#
# What the backend returns is data: Result::normalise reads it and
# Result::check refuses anything inconsistent before it is published.
# Files go to a private folder (0700) of this VMD process, named for its
# machine, its PID namespace and itself (a TMPDIR may be shared).
#

namespace eval ::VMDance::Backend {
    variable mode auto          ;# Settings: auto cli library
    variable cli ""             ;# the program chosen in Settings ("" = search)
    variable lib ""             ;# the library chosen in Settings ("" = search)
    variable loaded ""          ;# the library loaded into this VMD
    variable prefs_read 0       ;# the preferences' backend was read (from_prefs: once, under configure's options)
    variable caps               ;# program or library -> {its stamp, its algorithms}
    variable notes              ;# program -> what its probe could not tell
    variable job {}             ;# the running program
    variable last {}            ;# the last job that ended
    variable counter 0
    variable workdir ""
    variable seq 0
    variable max_log 400        ;# lines of the program's output kept
    variable max_line 2000      ;# characters kept of a line
    variable max_chunk 16384    ;# characters read at a time
    variable all_algorithms {kmeans divine helm equal}
}

#---------------------------------------------------------------------------
# Finding the backend
#---------------------------------------------------------------------------

proc ::VMDance::Backend::_plugindir {} { file dirname $::VMDance::libdir }

proc ::VMDance::Backend::_exe {p} {
    expr {$p ne "" && [file isfile $p] && [file executable $p]}
}

# The backend chosen in Settings (the preferences), read once, when the
# backend is first asked about: a script uses it as the window does. Values
# only: nothing is run or loaded here (a program is probed, a library
# loaded, when used), a program or library that is gone is left to the
# search, and configure's options, given first or after, win.
proc ::VMDance::Backend::from_prefs {} {
    variable prefs_read; variable mode; variable cli; variable lib
    if {$prefs_read} return
    set prefs_read 1
    if {[catch {::VMDance::Prefs::load} p]} return
    set mode [dict get $p backend_mode]
    set c [dict get $p backend_cli]
    # (tested as written first: "~user/…" of a user gone fails to normalize)
    if {$c ne "" && [_exe $c]} { set cli [file normalize $c] }
    set l [dict get $p backend_lib]
    if {$l ne "" && [file isfile $l]} { set lib [file normalize $l] }
}

# Where mdance-cli is looked for, in order.
proc ::VMDance::Backend::cli_candidates {} {
    variable cli
    from_prefs
    set pd [_plugindir]
    set out {}
    if {$cli ne ""} { lappend out $cli }
    if {[info exists ::env(MDANCE_CLI)] && $::env(MDANCE_CLI) ne ""} { lappend out $::env(MDANCE_CLI) }
    set exe [expr {$::tcl_platform(platform) eq "windows" ? "mdance-cli.exe" : "mdance-cli"}]
    lappend out [file join $pd $exe] [file join $pd bin $exe]
    set p [auto_execok mdance-cli]
    if {$p ne ""} { lappend out [lindex $p 0] }
    # a CPP-MDANCE build next to the plugin's folder (a source checkout)
    foreach up {{.. ..} {.. .. ..}} {
        lappend out [file join $pd {*}$up CPP-MDANCE build cli $exe]
    }
    lmap p $out {file normalize $p}
}

proc ::VMDance::Backend::lib_candidates {} {
    variable lib
    from_prefs
    set pd [_plugindir]
    set name mdance_tcl[info sharedlibextension]
    set out {}
    if {$lib ne ""} { lappend out $lib }
    if {[info exists ::env(MDANCE_LIB)] && $::env(MDANCE_LIB) ne ""} { lappend out $::env(MDANCE_LIB) }
    lappend out [file join $pd $name] [file join $pd lib $name]
    foreach up {{.. ..} {.. .. ..}} {
        lappend out [file join $pd {*}$up CPP-MDANCE build tcl $name]
    }
    lmap p $out {file normalize $p}
}

# The program found ("" when none).
proc ::VMDance::Backend::find_cli {} {
    foreach p [cli_candidates] { if {[_exe $p]} { return $p } }
    return ""
}
proc ::VMDance::Backend::find_lib {} {
    variable loaded
    if {$loaded ne ""} { return $loaded }
    foreach p [lib_candidates] { if {[file isfile $p]} { return $p } }
    return ""
}

# Load the library into this VMD (once); returns its path or an error.
proc ::VMDance::Backend::load_lib {{path ""}} {
    variable loaded
    if {$loaded ne ""} { return $loaded }
    if {$path eq ""} { set path [find_lib] }
    if {$path eq ""} { error "the MDANCE library (mdance_tcl[info sharedlibextension]) was not found" }
    # (the path kept is normalized, as configure compares it: one library
    # named two ways, "a/../b" and "b", is still one)
    set path [file normalize $path]
    if {[catch {uplevel #0 [list load $path Mdance]} err]} { error "the MDANCE library \"$path\" could not be loaded: $err" }
    if {[info commands ::mdance::kmeans] eq ""} { error "\"$path\" is not the MDANCE library (no ::mdance::kmeans)" }
    set loaded $path
    return $path
}

# Which backend a job uses: {cli path} or {library path}; an error says
# what is missing.
proc ::VMDance::Backend::current {} {
    variable mode; variable cli
    from_prefs
    # (a program chosen that is gone is an error, not another one found)
    if {$cli ne "" && $mode in {cli auto} && ![_exe $cli]} { error "mdance-cli \"$cli\", the program chosen, is not an executable program any more (Settings ▸ Backend, or vmdance backend -cli)" }
    switch -- $mode {
        cli {
            set p [find_cli]
            if {$p eq ""} { error "mdance-cli was not found ([_hint cli])" }
            return [list cli $p]
        }
        library {
            return [list library [load_lib]]
        }
        default {
            set p [find_cli]
            if {$p ne ""} { return [list cli $p] }
            if {[find_lib] ne ""} { return [list library [load_lib]] }
            error "no MDANCE backend was found: build CPP-MDANCE and set MDANCE_CLI to its mdance-cli, or choose it in Settings (in a script: vmdance backend -cli path)"
        }
    }
}
proc ::VMDance::Backend::_hint {what} {
    expr {$what eq "cli" ? "set MDANCE_CLI to the program, or choose it in Settings (in a script: vmdance backend -cli path)" : "set MDANCE_LIB to the library, or choose it in Settings (in a script: vmdance backend -library path)"}
}

# What the command and Settings report: {mode m using {kind path} cli path
# library path loaded path algorithms {...} error text note text}; note:
# what the probe could not tell (a program slow to start).
proc ::VMDance::Backend::status {} {
    variable mode; variable loaded; variable notes
    from_prefs
    set out [dict create mode $mode cli [find_cli] library [find_lib] loaded $loaded using {} algorithms {} error "" note ""]
    if {[catch {current} u]} {
        dict set out error $u
    } else {
        dict set out using $u
        # (a program that is not mdance-cli: said as the backend's error)
        if {[catch {algorithms} al]} { dict set out error $al } else { dict set out algorithms $al }
        if {[info exists notes([lindex $u 1])]} { dict set out note $notes([lindex $u 1]) }
    }
    return $out
}

# configure's options, checked, as the backend {mode cli lib} they make of
# the one in use: every option checked before any is kept (a bad path
# changes nothing). Nothing is kept here.
proc ::VMDance::Backend::_options {args} {
    variable mode; variable cli; variable lib; variable loaded
    from_prefs
    if {[llength $args] % 2} { error "options come in pairs: -mode m, -cli path, -library path" }
    set new [dict create mode $mode cli $cli lib $lib]
    set seen {}
    foreach {k v} $args {
        # (given once: the last of two was kept, the first never checked)
        if {$k in $seen} { error "$k is given twice" }
        lappend seen $k
        switch -- $k {
            -mode {
                if {$v ni {auto cli library}} { error "-mode must be auto, cli or library (got \"$v\")" }
                dict set new mode $v
            }
            -cli {
                if {$v ne "" && ![_exe $v]} { error "-cli: \"$v\" is not an executable program" }
                dict set new cli [expr {$v eq "" ? "" : [file normalize $v]}]
            }
            -library {
                if {$v ne "" && ![file isfile $v]} { error "-library: \"$v\" is not a file" }
                if {$v ne "" && $loaded ne "" && [file normalize $v] ne $loaded} {
                    error "-library: the MDANCE library $loaded is loaded in this VMD; another cannot be (restart VMD to use \"$v\")"
                }
                dict set new lib [expr {$v eq "" ? "" : [file normalize $v]}]
            }
            default { error "unknown option $k (valid: -mode, -cli, -library)" }
        }
    }
    return $new
}

proc ::VMDance::Backend::configure {args} {
    variable mode; variable cli; variable lib; variable caps; variable notes
    set new [_options {*}$args]
    # (a running job keeps the backend it started with)
    if {$new ne [dict create mode $mode cli $cli lib $lib] && [namespace exists ::VMDance::Job] && [::VMDance::Job::busy]} {
        error "a job is running: change the backend when it has ended"
    }
    set mode [dict get $new mode]
    set cli [dict get $new cli]
    set lib [dict get $new lib]
    array unset caps *
    array unset notes *
    status
}

# What configure would give with these options, without keeping them:
# status of that backend, its program asked again (Settings tries a backend
# before OK, and a job meanwhile runs on the one in use). Nothing here
# enters the event loop (the probe sleeps, the library loads), so no job
# sees the backend tried; a library tried is loaded, which cannot be
# undone (configure refuses another one after).
proc ::VMDance::Backend::probe {args} {
    variable mode; variable cli; variable lib; variable caps; variable notes
    set new [_options {*}$args]
    set kept [list $mode $cli $lib]
    try {
        set mode [dict get $new mode]
        set cli [dict get $new cli]
        set lib [dict get $new lib]
        if {![catch {current} u]} {
            unset -nocomplain caps([lindex $u 1]) notes([lindex $u 1])
        }
        return [status]
    } finally {
        lassign $kept mode cli lib
    }
}

# The backend as configure would be told it again.
proc ::VMDance::Backend::settings {} {
    variable mode; variable cli; variable lib
    from_prefs
    list -mode $mode -cli $cli -library $lib
}

# The algorithms the backend was built with. The program says so in the
# usage line it prints when run without arguments
# ("--algorithm {kmeans|divine|helm|equal}": DIVINE only when it was built
# with it); the library by the commands it registered. A probe that fails
# or prints something else yields every algorithm: hiding one that works
# is worse than offering one the backend then refuses (with its own
# message). So does a program that does not answer within 3 s (in a
# container, on a network disk: mdance-cli all the same; one that waits
# for ever runs in the background, where Cancel stops it), with a note.
# The answer is kept with the program's stamp (its file's inode, size and
# times): a program rebuilt or replaced at the same path is asked again
# (DIVINE built in after the advice to); a loaded library cannot change.
# again: asked whatever the stamp, before an algorithm is refused as not
# built in (a launcher's stamp stays the same when the program it runs is
# rebuilt).
proc ::VMDance::Backend::algorithms {{again 0}} {
    variable caps; variable notes; variable all_algorithms
    lassign [current] kind path
    set stamp ""
    if {$kind eq "cli" && ![catch {file stat $path st}]} { set stamp [list $st(ino) $st(size) $st(mtime) $st(ctime)] }
    if {!$again && [info exists caps($path)] && [lindex $caps($path) 0] eq $stamp} {
        set v [lindex $caps($path) 1]
        if {[lindex $v 0] eq "error"} { error [lindex $v 1] }
        return $v
    }
    set out $all_algorithms
    if {$kind eq "cli"} {
        unset -nocomplain notes($path)
        set usage [_probe $path]
        if {$usage eq "\0timeout"} {
            set notes($path) "\"$path\" did not answer within 3 s when run without arguments: its algorithms are not known, so all are offered"
        } elseif {[string length $usage] >= 65536} {
            set e "\"$path\" printed more than 64 KB when run without arguments: it is not mdance-cli (Settings ▸ Backend)"
            set caps($path) [list $stamp [list error $e]]
            error $e
        } elseif {[regexp -- {--algorithm\s*\{([a-z|]+)\}} $usage -> l]} {
            set l [lmap a [split $l |] {expr {$a in $all_algorithms ? $a : [continue]}}]
            if {[llength $l]} { set out $l }
        }
    } else {
        set out [lmap a $all_algorithms {expr {[info commands ::mdance::$a] ne "" ? $a : [continue]}}]
        # (the library registers DIVINE's command whether or not it was
        # built with it: ask it)
        if {"divine" in $out && [catch {::mdance::divine {0 0 0 1 1 1} 2 1 1} e] && [string match "*not available*" $e]} {
            set out [lsearch -all -inline -not -exact $out divine]
        }
    }
    set caps($path) [list $stamp $out]
    return $out
}

# What the program prints when run without arguments: at most 64 KB, in
# at most 3 s ("\0timeout" when it did not end; it is killed, and what it
# started). A program that is not mdance-cli may wait, or print forever:
# VMD must not.
proc ::VMDance::Backend::_probe {path} {
    if {[catch {open |[list $path 2>@1] r} ch]} { return "" }
    fconfigure $ch -blocking 0 -translation binary
    set out ""
    set t0 [clock milliseconds]
    while {![eof $ch] && [string length $out] < 65536 && [clock milliseconds] - $t0 < 3000} {
        set got [read $ch 65536]
        if {$got eq ""} { after 20 } else { append out $got }
    }
    set done [eof $ch]
    if {!$done} { _kill_tree [pid $ch] }
    catch {close $ch}
    expr {$done || [string length $out] >= 65536 ? $out : "\0timeout"}
}

#---------------------------------------------------------------------------
# Private files
#---------------------------------------------------------------------------

# The folder the private folder is made in: TMPDIR (TEMP, TMP), else the
# system's. VMD writes into the private folder (writepdb, render) by
# vmd_name: one in which it can name no file (a name not in UTF-8, with a
# locale that is not) is passed over, and kept in passed for the error if
# no private folder can be made.
proc ::VMDance::Backend::_tmpbase {} {
    variable passed {}
    foreach v {TMPDIR TEMP TMP} {
        if {[info exists ::env($v)] && [file isdirectory $::env($v)] && [file writable $::env($v)]} {
            if {[vmd_name [file normalize $::env($v)]] ne ""} { return $::env($v) }
            lappend passed "$v \"$::env($v)\""
        }
    }
    if {$::tcl_platform(platform) eq "windows" && [info exists ::env(SystemRoot)]} { return [file join $::env(SystemRoot) Temp] }
    return /tmp
}
# The name by which VMD's file commands (writepdb, render, mol new) open
# the file that Tcl's open by the name f, or "" when there is none. VMD
# takes a name's UTF-8 bytes, Tcl the system encoding's (iso8859-1 with
# LANG=C): a name outside ASCII is given to VMD as the characters whose
# UTF-8 bytes are those of the name on disk.
proc ::VMDance::Backend::vmd_name {f} {
    set b [encoding convertto [encoding system] $f]
    set v [encoding convertfrom utf-8 $b]
    if {[encoding convertto utf-8 $v] eq $b} { return $v }
    return ""
}
# The name by which Tcl's file commands open the file that VMD's open by
# the name f (a molecule's file, as VMD names it).
proc ::VMDance::Backend::tcl_name {f} {
    encoding convertfrom [encoding system] [encoding convertto utf-8 $f]
}

# This process's user id, by number, read once without the user database
# ("" when it cannot be told). A uid with no passwd entry (a container's)
# has no name: tcl_platform(user) is "", and an owner is a number.
proc ::VMDance::Backend::_uid {} {
    variable uid
    if {[info exists uid]} { return $uid }
    set u ""
    # (the effective uid, the second of the line: it owns what the process makes)
    if {![catch {open /proc/self/status r} fh]} {
        catch {regexp -line {^Uid:\s+[0-9]+\s+([0-9]+)} [read $fh] -> u}
        catch {close $fh}
    }
    if {$u eq "" && $::tcl_platform(platform) ne "windows" && ![catch {exec id -u} o]} { set u [string trim $o] }
    if {![regexp {^[0-9]+$} $u]} { set u "" }
    set uid $u
}
# The user in the folders' names: the login name, else u and the uid.
proc ::VMDance::Backend::_user {} {
    set u ""
    if {[info exists ::tcl_platform(user)]} { set u $::tcl_platform(user) }
    if {[regexp {^[A-Za-z0-9_-][A-Za-z0-9._-]*$} $u]} { return $u }
    return u[_uid]
}
# This process's machine and PID namespace, as 8 hex digits: two VMDs
# that share a TMPDIR (machines, containers) may have the same process
# number, and /proc says nothing of the other's processes. The machine is
# its node name and machine-id, read without the resolver ("info hostname"
# asks it: a host whose name is an alias of localhost is
# "localhost.localdomain" there, and a resolver that does not answer
# holds VMD).
proc ::VMDance::Backend::_where {} {
    variable where
    if {[info exists where]} { return $where }
    set id {}
    foreach f {/proc/sys/kernel/hostname /etc/machine-id} {
        set s ""
        if {![catch {open $f r} fh]} {
            catch {set s [string trim [read $fh 256]]}
            catch {close $fh}
        }
        lappend id $s
    }
    # (no /proc: the kernel's name all the same)
    if {[lindex $id 0] eq "" && ![catch {exec uname -n} n]} { lset id 0 [string trim $n] }
    set ns ""
    catch {set ns [file readlink /proc/self/ns/pid]}
    set where [format %08x [zlib crc32 "[join $id /]/$ns"]]
}
# Whether d is a real folder (not a link) of this user's, compared by
# uid (by name a uid with no passwd entry is never its own folder's).
proc ::VMDance::Backend::_mine {d} {
    if {[catch {file lstat $d st}] || $st(type) ne "directory"} { return 0 }
    if {$::tcl_platform(platform) eq "windows"} { return 1 }
    if {[_uid] ne ""} { return [string equal $st(uid) [_uid]] }
    file owned $d
}

# A folder of this VMD process that only its user can read: a new one
# (a name that exists is never taken: it may be another VMD's), a real
# folder of the user's, named for this machine, PID namespace and
# process, and a random part.
proc ::VMDance::Backend::workdir {} {
    variable workdir
    if {$workdir ne "" && [_mine $workdir]} { return $workdir }
    set base [file normalize [_tmpbase]]
    set user [_user]
    _reap_dead $base $user
    set why ""
    for {set k 0} {$k < 20} {incr k} {
        set d [file join $base [format "vmdance-%s-%s-%d-%08x" $user [_where] [pid] [expr {int(rand() * 4294967296.0) ^ ([clock clicks] & 0xffffffff)}]]]
        # ("file mkdir" of a folder that exists succeeds)
        if {![catch {file lstat $d st}]} continue
        if {[catch {file mkdir $d} why]} continue
        # (checked after it is made too: another user may have made it
        # meanwhile; one of the user's that is refused is not left behind)
        if {![_mine $d]} {
            catch {file delete $d}
            set why "\"$d\" is not a folder of the user's (uid [_uid])"
            continue
        }
        catch {file attributes $d -permissions 0700}
        set workdir $d
        return $d
    }
    # (a TMPDIR passed over is said: it is a folder of the user's)
    variable passed
    set fix "set TMPDIR to a folder of yours"
    if {[llength $passed]} {
        append why "; [join $passed {, }] passed over: with this locale ([encoding system]) VMD cannot open a file there by its name"
        append fix " whose name is ASCII, or use a UTF-8 locale (LANG=C.UTF-8)"
    }
    error "no private folder could be made under $base ($why): $fix"
}

# The private folders of this user's VMDs that are no longer running
# (killed, or crashed: each keeps a trajectory's coordinates): only those
# of this machine and PID namespace, whose processes /proc lists.
proc ::VMDance::Backend::_reap_dead {base user} {
    if {$::tcl_platform(platform) eq "windows" || ![regexp {^[A-Za-z0-9_-][A-Za-z0-9._-]*$} $user]} return
    # (no /proc, or another PID namespace's: this one's processes are not known)
    if {![_procfs]} return
    set re "^vmdance-[string map {. {\.}} $user]-[_where]-(\[0-9\]+)-\[0-9a-f\]{8}\$"
    foreach d [glob -nocomplain -types d -directory $base "vmdance-$user-[_where]-*"] {
        if {![regexp $re [file tail $d] -> p] || $p eq [pid] || [file exists /proc/$p]} continue
        if {[_mine $d]} { catch {file delete -force $d} }
    }
}

proc ::VMDance::Backend::tmpfile {suffix} {
    variable seq
    file join [workdir] "f[incr seq]-[clock milliseconds]$suffix"
}

# Remove the private folder (when VMD quits, or the tests end).
proc ::VMDance::Backend::cleanup {} {
    variable workdir
    if {$workdir ne ""} { catch {file delete -force $workdir} }
    set workdir ""
}

# A CSV file of one number per line (labels).
proc ::VMDance::Backend::write_column {file values} {
    set fh [open $file w]
    try { puts $fh [join $values \n] } finally { close $fh }
}

#---------------------------------------------------------------------------
# Running the program in the background
#---------------------------------------------------------------------------

proc ::VMDance::Backend::running {} {
    variable job
    expr {[dict size $job] > 0}
}

# Start mdance-cli with argv; callbacks (command prefixes, may be ""):
# -line {text} for every line it prints, -done {status message job}, with
# status ok, failed, stopped (ended from outside by a signal: Ctrl+C at
# VMD's terminal, kill) or cancelled. Returns the job's id.
proc ::VMDance::Backend::start {path argv args} {
    variable job; variable counter
    set o [dict merge {-line "" -done ""} $args]
    if {[running]} { error "the backend is already running" }
    if {[catch {open |[concat [list $path] $argv [list 2>@1]] r} ch]} { error "mdance-cli could not be started: $ch" }
    fconfigure $ch -blocking 0 -buffering line -translation auto
    set id [incr counter]
    set job [dict create id $id path $path argv $argv chan $ch pids [pid $ch] started [clock milliseconds] \
        line [dict get $o -line] done [dict get $o -done] cancelled 0 log {} partial "" ending 0]
    fileevent $ch readable [list ::VMDance::Backend::_readable $id]
    return $id
}
proc ::VMDance::Backend::_is {id} {
    variable job
    expr {[dict exists $job id] && [dict get $job id] == $id}
}

# What the program printed, a slice at a time: one that prints without
# pause, or a line without its end, never holds VMD nor fills its memory.
proc ::VMDance::Backend::_readable {id} {
    variable job; variable max_chunk; variable max_line
    if {![_is $id]} return
    set ch [dict get $job chan]
    set data [read $ch $max_chunk]
    set lines [split [dict get $job partial]$data \n]
    # (of a line whose end has not come, its beginning: it is cut when kept)
    dict set job partial [string range [lindex $lines end] 0 $max_line]
    foreach line [lrange $lines 0 end-1] {
        _keep $line
        if {![_is $id]} return
    }
    if {[eof $ch]} {
        if {[dict get $job partial] ne ""} { _keep [dict get $job partial] }
        if {![_is $id]} return
        fileevent $ch readable {}
        # (a program can end its output before it ends, behind a launcher
        # that logs: the job ends when it has)
        _reap $id
    } elseif {[string length $data] >= $max_chunk} {
        # (more is waiting: VMD runs every Tcl event that is ready before
        # it draws or reads its console, so the reading pauses)
        fileevent $ch readable {}
        after 1 [list ::VMDance::Backend::_resume $id]
    }
}
proc ::VMDance::Backend::_resume {id} {
    variable job
    if {[_is $id]} { fileevent [dict get $job chan] readable [list ::VMDance::Backend::_readable $id] }
}
# A line the program printed: kept in the job's log (its last max_log
# lines, each cut to max_line characters) and given to -line.
proc ::VMDance::Backend::_keep {line} {
    variable job; variable max_log; variable max_line
    if {[string length $line] > $max_line} { set line "[string range $line 0 [expr {$max_line - 1}]]…" }
    # (appended in place, trimmed now and then: a list copied at every
    # line costs its length)
    dict lappend job log $line
    if {[llength [dict get $job log]] >= 2 * $max_log} { dict set job log [lrange [dict get $job log] end-[expr {$max_log - 1}] end] }
    set cb [dict get $job line]
    if {$cb ne ""} { catch {uplevel #0 [list {*}$cb $line]} }
}

# The job ends once its processes have: a blocking close waits for a
# program that still runs, and VMD with it. They are polled (1, 2, 4 …
# 100 ms) and left to the close to reap (until then no other process is
# given their numbers); where that cannot be told, the job ends with its
# output, and the close waits.
proc ::VMDance::Backend::_reap {id {n 0}} {
    variable job
    if {![_is $id]} return
    if {!$n} {
        if {[dict get $job ending]} return
        dict set job ending 1
    }
    foreach p [dict get $job pids] {
        set e [_ended $p]
        if {$e eq "0" || ($e eq "" && ![eof [dict get $job chan]])} {
            after [expr {min(100, 1 << min($n, 7))}] [list ::VMDance::Backend::_reap $id [incr n]]
            return
        }
    }
    _finish $id
}
# Whether /proc is this process's PID namespace's (else the numbers it
# lists are not this one's).
proc ::VMDance::Backend::_procfs {} {
    variable procfs
    if {![info exists procfs]} { set procfs [expr {![catch {file readlink /proc/self} me] && $me eq [pid]}] }
    return $procfs
}
# Whether this VMD's child p has ended: 1 (a zombie, which the close
# reaps, or gone), 0 (it runs), "" (it cannot be told). Not "kill -0": it
# succeeds on a zombie.
proc ::VMDance::Backend::_ended {p} {
    if {$::tcl_platform(platform) eq "windows"} { return "" }
    if {[_procfs]} {
        if {[catch {open /proc/$p/stat r} fh]} { return 1 }
        set s ""
        catch {set s [read $fh]}
        catch {close $fh}
        # (after the name in parentheses, which may hold anything: the state, then the parent)
        if {![regexp {\) (\S) ([0-9]+) } [string range $s [string last ")" $s] end] -> state pp]} { return "" }
    } elseif {[file isdirectory /proc]} {
        # (another PID namespace's /proc, which ps reads too: it would tell
        # of another process of that number)
        return ""
    } elseif {[catch {exec ps -o stat= -o ppid= -p $p} t] || ![regexp {^\s*(\S)\S*\s+([0-9]+)\s*$} $t -> state pp]} {
        return ""
    }
    # (another's number: this one has been reaped)
    if {$pp ne [pid]} { return 1 }
    expr {$state in {Z X x}}
}

proc ::VMDance::Backend::_finish {id} {
    variable job; variable last; variable max_log
    if {![_is $id]} return
    set ch [dict get $job chan]
    fconfigure $ch -blocking 1
    set failed [catch {close $ch} err eo]
    set j $job
    set job {}
    dict set j log [lrange [dict get $j log] end-[expr {$max_log - 1}] end]
    set sig ""
    if {$failed} { set sig [_stopped_by [dict get $eo -errorcode]] }
    if {[dict get $j cancelled]} {
        set st cancelled; set msg "stopped"
    } elseif {$sig ne ""} {
        # (ended from outside, by Ctrl+C at VMD's terminal or kill: the
        # whole job stops, as with Cancel)
        set st stopped; set msg "mdance-cli was stopped ($sig)"
    } elseif {$failed} {
        set st failed; set msg [_failure [dict get $j log] $err [dict get $eo -errorcode]]
        # (a line a program printed can be of any length)
        if {[string length $msg] > 2000} { set msg "[string range $msg 0 1999]…" }
    } else {
        set st ok; set msg ""
    }
    dict set j status $st
    dict set j message $msg
    dict set j seconds [expr {([clock milliseconds] - [dict get $j started]) / 1000.0}]
    set last $j
    set cb [dict get $j done]
    if {$cb ne ""} {
        if {[catch {uplevel #0 [list {*}$cb $st $msg $j]} e]} { puts "VMDance) $e" }
    }
}

# The signal that ended a program from outside (Ctrl+C at VMD's terminal,
# kill), from the error code of its close; "" for any other end (a crash
# is a failure). A launcher that does not exec ends with 128 + the number
# of the signal that ended its program.
proc ::VMDance::Backend::_stopped_by {code} {
    lassign $code kind - a b
    if {$kind eq "CHILDKILLED" && $a in {SIGINT SIGTERM SIGHUP SIGQUIT SIGKILL}} { return $b }
    if {$kind eq "CHILDSTATUS" && $a in {129 130 131 137 143}} { return "exit status $a" }
    return ""
}

# Why the program failed: its "Error: ..." line, else its last line, else
# the exit status.
proc ::VMDance::Backend::_failure {log err {code ""}} {
    # (killed by a signal that is no stop, a crash: that, not the last line
    # it printed)
    if {[lindex $code 0] eq "CHILDKILLED"} { return "mdance-cli crashed ([lindex $code 3])" }
    for {set i [expr {[llength $log] - 1}]} {$i >= 0} {incr i -1} {
        if {[regexp {^Error: (.*)$} [lindex $log $i] -> m]} { return [string trim $m] }
    }
    set l [string trim [lindex $log end]]
    if {$l ne ""} { return $l }
    return [lindex [split $err \n] 0]
}

# The processes under pids, deepest first ({} when that cannot be told):
# a launcher that does not exec leaves mdance-cli under it. Collected
# before any is signalled (what a dead process started is no longer under
# it).
proc ::VMDance::Backend::_descendants {pids} {
    set kids [dict create]
    if {[_procfs]} {
        foreach p [glob -nocomplain -directory /proc -tails {[0-9]*}] {
            if {[catch {open /proc/$p/stat r} fh]} continue
            set s ""
            catch {set s [read $fh]}
            catch {close $fh}
            if {[regexp {\) \S ([0-9]+) } [string range $s [string last ")" $s] end] -> pp]} { dict lappend kids $pp $p }
        }
    } elseif {$::tcl_platform(platform) ne "windows" && ![file isdirectory /proc] && ![catch {exec ps -A -o pid= -o ppid=} t]} {
        foreach l [split $t \n] {
            if {[regexp {^\s*([0-9]+)\s+([0-9]+)\s*$} $l -> p pp]} { dict lappend kids $pp $p }
        }
    }
    set out {}
    set todo $pids
    while {[llength $todo]} {
        set next {}
        foreach p $todo {
            if {![dict exists $kids $p]} continue
            foreach c [dict get $kids $p] {
                if {$c ni $out && $c ni $pids && $c ne [pid]} { lappend out $c; lappend next $c }
            }
        }
        set todo $next
    }
    lreverse $out
}
proc ::VMDance::Backend::_signal {sig pids} {
    if {[llength $pids]} { catch {exec kill -$sig {*}$pids} }
}
# KILL pids and everything under them, at once.
proc ::VMDance::Backend::_kill_tree {pids} {
    if {$::tcl_platform(platform) eq "windows"} {
        foreach p $pids { catch {exec taskkill /F /T /PID $p} }
    } else {
        _signal KILL [concat [_descendants $pids] $pids]
    }
}

# Stop the running program and what it started (a launcher that does not
# exec leaves mdance-cli under it): TERM to what it started, else to it (a
# shell dies of TERM at once, and leaves its program running out of
# reach), then KILL to them all 1.5 s later if it is still the same job (a
# finished job's process ids are never signalled). The job ends when its
# own processes have, whatever still holds their output.
proc ::VMDance::Backend::cancel {} {
    variable job
    if {![running]} { return 0 }
    dict set job cancelled 1
    set id [dict get $job id]
    set pids [dict get $job pids]
    if {$::tcl_platform(platform) eq "windows"} {
        _kill_tree $pids
    } else {
        set under [_descendants $pids]
        if {[llength $under]} { _signal TERM $under } else { _signal TERM $pids }
        after 1500 [list ::VMDance::Backend::_kill_hard $id]
        _reap $id
    }
    return 1
}
proc ::VMDance::Backend::_kill_hard {id} {
    variable job
    if {[_is $id]} { _kill_tree [dict get $job pids] }
}
# Stop the running program and what it started, at once (VMD quits: they
# would run on alone).
proc ::VMDance::Backend::stop_now {} {
    variable job
    if {[running]} { _kill_tree [dict get $job pids] }
}


# The private folder goes when VMD quits.
proc ::VMDance::Backend::_quitting {args} { stop_now; cleanup }
if {([info exists ::vmd_quit] || [info commands vmdinfo] ne "") &&
    [lsearch -exact [trace info variable ::vmd_quit] {write ::VMDance::Backend::_quitting}] < 0} {
    trace add variable ::vmd_quit write ::VMDance::Backend::_quitting
}
