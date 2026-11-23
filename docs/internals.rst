Internals
=========

.. warning::

   The state and procedures below are documented for scripts that need more
   than the command gives, and for work on the plugin. They are **not a
   stable API** in this alpha.

A clustering
------------

``Job::_result`` returns one dict, which ``Results::publish`` checks
(``Results::check``) and makes current:

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - Key
     - Content
   * - ``format``
     - ``1``
   * - ``request``
     - ``mol sel fit first last step algorithm k metric params``
   * - ``molecule``
     - ``name numatoms numframes files types paths`` (for sessions)
   * - ``frames``, ``natoms``
     - the VMD frames clustered, in order; the atoms per frame
   * - ``nclusters labels sizes representatives msd ch db``
     - the backend's answer, checked: a label per frame (-1 noise), the
       sizes counted from the labels, the representatives as rows (-1: an
       empty cluster), the MSD within ("" for an empty cluster), the two
       scores ("" when not finite, with fewer than two clusters or every
       cluster a frame alone; HELM's with a trim of its clustered frames,
       ``Measure::scores``)
   * - ``zmatrix``, ``initial``
     - HELM's merges ``{a b rank count}`` as the backend numbers them, and
       its starting labels (``Measure::helm_tree`` numbers the merges as
       scipy does, for the tree, the command and the export)
   * - ``measures``
     - ``frame_msd silhouette silhouette_pairs`` (per frame; the silhouette
       from the mean structures, and from every frame: a run made before
       has no ``silhouette_pairs``), ``rep_msd centroid_msd``
       (k × k; ``{}``, not measured, above ``Measure::maxk``, 300 clusters)
   * - ``extras``
     - ``prime``, ``similarity``, ``map``, ``profiles``: what was asked of it
       (``Results::attach``); ``groups``
   * - ``backend``, ``seconds``, ``created``
     - ``{cli path}``, ``{library path}`` or ``{imported file}``; the time
       and date
   * - ``unrecorded``
     - an import's whose file does not record them: ``metric params`` (the
       request has MSD and the defaults; ``info``, the ``#`` header and the
       run's name say they are not recorded)

What is read from it (``Results``)
----------------------------------

.. list-table::
   :header-rows: 1
   :widths: 42 58

   * - Procedure
     - Returns
   * - ``has_data``, ``nclusters``, ``nframes``, ``frames``, ``labels``, ``sizes``, ``noise``, ``request``, ``get key``, ``measure key``
     - the clustering and its settings
   * - ``members c``, ``member_frames c``, ``size c``, ``fraction c``, ``rep c``, ``rep_frame c``
     - one cluster
   * - ``frame_index f``, ``row_of f``, ``cluster_at f``
     - VMD frames and rows
   * - ``table``, ``top c n``, ``residence``, ``transitions lag``, ``tree``,
       ``silhouette kind``, ``empty_clusters``
     - what the plots and exports read
   * - ``elbow_suggest e``, ``explained record``
     - what a scan points to (Davies–Bouldin's lowest value and sharpest
       dip, Calinski–Harabasz's highest, the stable values), and the share
       of the variance a record's clusters explain
   * - ``renumbered a``
     - a clustering with its clusters numbered by size: the labels, every
       list and matrix with a row a cluster, and the per-cluster parts of
       its extras, together
   * - ``selected``, ``set_selection cs ?set|add|toggle?``
     - the selection
   * - ``run_list``, ``run_switch``, ``run_label``, ``run_delete``, ``run_data``, ``set_runs``, ``clear_all``
     - runs (kept ``zlib``-compressed)
   * - ``elbow``, ``sweep``, ``picks`` (variables), ``set_elbow``, ``set_sweep``, ``set_picks``
     - the last scans and picks
   * - ``listen cmd``, ``unlisten cmd``
     - ``cmd what`` is called after a change: ``analysis``, ``selection``,
       ``runs``, ``extras``, ``elbow``, ``sweep`` or ``picks``

The jobs
--------

``Job::check_cluster``, ``check_elbow``, ``check_sweep``, ``check_input``
and ``check_specs`` complete and check a request (errors name the option);
``Algo::check_starting`` checks HELM's starting clusters as the backend
gets them, once its first clustering is made, and ``check_trimmed`` what
``-trim-val`` left, once HELM has run (``Job::_cluster``: a scan keeps a k
they refuse as not run, and a scan where none ran is refused).
``Job::run kind req ?progress?`` runs a job to its end and returns its
value; ``Job::start kind req progress done`` runs it in a coroutine and
calls ``done status value`` (``ok``, ``cancelled`` or ``error``; the value
of a cancelled job is why the backend was stopped from outside, or empty);
``Job::cancel`` stops it. The kinds: ``cluster elbow sweep adopt import
prime similarity map profiles radii pick``. An elbow scan cancelled after
two values keeps them in ``Job::partial``, a scan of its own, for its
caller to keep (the window does). ``Job::_call`` runs the backend once — the program
through ``Backend::start`` (``open |``, a fileevent that reads 16 KB at a
time and pauses while more waits, the coroutine resumed when its processes
have ended: a blocking ``close`` would wait for one that closed its output
first; never a program the probe found is not ``mdance-cli``) or the
library's command — and ``Job::output`` checks a clustering's answer.
``Backend::cancel`` sends TERM to what the program started (a launcher that
does not ``exec`` leaves ``mdance-cli`` under it), else to the program, and
KILL to them all 1.5 s later; a status ``stopped`` (a signal from outside:
Ctrl+C, ``kill``) stops the whole job as Cancel does. The private folder
(``Backend::workdir``) is named ``vmdance-<user>-<machine and PID
namespace>-<pid>-<random>``, checked by uid, and never one that exists;
``_reap_dead`` removes only this machine's and namespace's folders of VMDs
that ended. ``Coords::extract`` reads the rows (in slices, in a
coroutine) into a CSV file of the private folder, whatever the backend,
refusing a frame whose coordinates are not numbers (its fingerprint is
not: ``Coords::_row``), and keeps the last one (``Coords::cached``, dropped
when the molecule changes, and at once when it is deleted: a trace of
``vmd_initialize_structure``); ``Coords::each`` reads them again, from VMD
while the molecule is unchanged (else from the file), and
``Measure::compute`` measures a clustering in two such passes (yielding,
saying how far it is: Cancel stops it), then each pair of clusters once
(for 300 clusters or fewer); ``Measure::scores`` scores HELM's clustered
frames in two more, when it trims (a scan's every k in the same two, each
cluster that several k have once). The silhouette from every frame is
made in the same second pass: a frame's mean squared distance from a
cluster's frames is its squared distance from their mean structure plus
their spread, which the first pass keeps. From the labels alone,
``Measure::shares`` and ``first_seen`` count the clusters' frames window by
window, and ``Measure::divergence`` compares the groups' shares of the
clusters. ``Coords::alignment`` measures a sample of frames against the
first, as they are and fitted (on values), and ``Coords::superposed`` is
the rule. A frame's
fingerprint (``Coords::_print``) is the selection's centre, radius of
gyration, weighted centre and RMSD from the first frame (and the fit's):
a result, a scan and the picks keep the digest of their frames'
fingerprints (``2:`` first; one without, of a session made before, is
compared as it was made), each frame's radius of gyration (``shape``) and
the atoms their selection held (``atoms``, ``fitatoms``: every later read
uses them, not the texts). The library
gets them as one list (``Coords::flat``), whose text is the CSV's less a
byte: ``Job::_library_fits`` refuses a call whose text would pass Tcl's
2 GB, or that needs more memory than VMD can get (``/proc/meminfo``, its
cgroups), before the frames are read (estimated) and before each call
(exactly). ``Job::_call`` makes that list once a job (``lib_rows``, keyed on
the extraction, dropped when the job ends) and gives every call the same
object: CPP-MDANCE's binding makes its text at the first (it reads its
options from every argument), and a scan's next k reads no frame again.
Before a call, which blocks VMD, the job posts what runs, that the library
runs it and that VMD waits, and yields 20 ms so that the window shows it,
and again after it: VMD reads a Cancel pressed during the call only then,
and the job stops there, before it goes on or publishes (``lib_most``
counts the call once it is made);
``GUI::_progress`` shows a new step at once, and only the same step's
counts (its text but for its numbers) at most every 250 ms.

``Backend::from_prefs`` reads the backend chosen in Settings
(``Prefs::load``, a core module) once, as values, when the backend is
first asked about; ``configure``'s options are set over it.
``Backend::probe`` says what options would give without keeping them
(Settings' trial, ``vmdance backend try``): nothing in it enters the
event loop, so no job sees the backend tried.

Sessions
--------

A session file is gzip-compressed UTF-8 text: ``VMDanceSession 1`` on the
first line, then a Tcl dictionary read as data: ``format plugin created
runs current selection elbow sweep picks gui``, with ``runs`` ``{id label
result} ...``. Every result goes through ``Results::check``, the scans'
records through ``Results::check_clustering``, before anything is replaced.
A scan and the picks keep their ``backend`` and ``created`` too (checked
as a result's, ``Results::check_meta``), and their atoms, digest and
shapes (``check_atoms``, ``check_identity``).

Frame numbers are VMD's only while the molecule has the frames that were
read (``Results::frames_ok``, ``picks_ok``): as a job read them in this VMD
(``Results::trusted``: the molecule's number of frames and files then, and
the deletions seen on it since, kept in memory and never saved — another
replica has the same names), else the digest of the coordinates at those
frames, else every frame's radius of gyration within a float's rounding
(moved in place rigidly: an alignment; only where those tell frames
apart). The last answer is kept for the molecule as it is
(``Results::_now``: VMD says nothing of a deletion, so the frame of a
molecule something is kept for is traced, which a load writes at every
frame read, and a count of frames lower than the last seen is frames
deleted). ``Session::load`` tries, for every run, scan and the picks, the
molecules loaded (its files in full, ``paths``, or as typed; then its name
and atoms) and then its files (in full, from the session's folder, as
typed), until one has their frames (``_mol_for``, ``_has_frames``): those
that pass are trusted; a molecule it loaded with frames before them that
it did not have then has them deleted again. ``Viz::draw`` records the
molecules it drew on, traces their frame, and ``Viz::check`` draws again
(or withdraws) when they changed.

Files
-----

Every file the plugin writes (exports, sessions, the preferences, figures)
goes through ``Export``: ``target file`` checks a name before anything is
written and returns the file it writes (a link of the user's followed, one
of another user's replaced; not a folder, nor read-only); ``_write file
data ?binary?`` writes it to a temporary beside it opened ``EXCL`` under a
name not guessed (``_open``), and renames it onto the file (``_commit``:
a link of another user's deleted first, as Tcl's ``rename -force`` would
make what it points to writable), which keeps its permissions (``_keep``,
where chmod is allowed); ``_copy src file`` does the same with a file
VMD, Tk or Ghostscript wrote into the private folder. Within ``_batch
script`` the files are renamed only once all of them are written.
``Export::check dir prefix items opts`` checks a bundle (what each item
needs is ``why_not item``, which the window asks too) and lists its files,
and the clusters an earlier export of trajectories left that it deletes
(``stale``); ``bundle`` writes them in one batch, in a folder it makes
(``_mkdir``) and deletes again if it fails (``_unmake``).
``write_frames`` writes a DCD itself
(each frame's unit cell, as ``dcdplugin``) and a PDB with VMD's
``writepdb``, frame by frame, each checked whole (``_whole``: its last
``END``), then put between ``MODEL`` and ``ENDMDL`` under its ``REMARK``
(``_pdb``: several frames, or frames with notes, are models).

Where the time goes
-------------------

``tests/profile/profile_core.tcl`` (text mode) and ``profile_gui.tcl`` (the
window) wrap every procedure of the plugin and count its calls and time;
the reports go to ``tests/out/profile``. On a Linux workstation (VMD 2.1,
the program backend):

.. list-table::
   :header-rows: 1
   :widths: 60 20 20

   * - Work
     - Time
     - Of which the backend
   * - KMeans NANI k 6, the tau peptide's backbone (6001 × 48), first time
     - 1.3 s
     - 0.2 s
   * - the same, the coordinates kept
     - 1.0 s
     - 0.2 s
   * - an elbow scan, k 2 to 10
     - 1.9 s
     - 1.7 s
   * - PRIME
     - 4.0 s
     - 3.9 s
   * - every export (cluster trajectories as DCD)
     - 0.5 s
     -
   * - every atom, fitted on the backbone (6001 × 217)
     - 8.4 s
     - 0.9 s
   * - 3ptb's every atom (100 × 3222)
     - 1.4 s
     - 0.2 s
   * - the tau peptide eight times over, every atom (48 008 × 217)
     - 43 s
     - 8.5 s
   * - the window: a plot drawn; the pointer over one
     - ≤ 90 ms; ≤ 75 µs
     -
   * - the trajectory played, coloured by cluster, the Timeline shown
     - 3 ms a frame (0.06 of it the plugin's)
     -

What is left is the plugin's reading and measuring of the coordinates, in
Tcl: reading a frame of 217 atoms from VMD costs 70 µs (``$sel get`` and
the list made flat); each distance between two rows 27 µs (VMD's
``vecsub`` makes a new list; ``veclength`` is C), and the measures take
1 + k of them per frame, on the second of their two passes (above 64
clusters fewer: a frame's nearest other mean structure, its silhouette's,
is looked for in groups of them, nearest first, and one the triangle
inequality puts farther than the nearest found is not measured; about a
third of them on states3's 1462 clusters, where the distances in 180
dimensions are nearly all alike); with a fit, a
frame's transform costs 250 µs (VMD's ``vectrans``, called per atom), and
its rotation is the plugin's own (``Coords::fit_matrix``: Horn's
quaternion, about 0.15 ms a frame for 50 atoms), not ``measure fit``. VMD's
``veclength2``, ``vecdot``, ``vecdist`` and ``coordtrans`` are Tcl
procedures: the plugin calls ``veclength`` and ``vecsub`` directly, and a
frame's fingerprint uses ``measure center``, ``measure rgyr`` and ``measure
rmsd`` (C, 10 µs a frame of 217 atoms, 95 of 3238, where lists took 110 of
217). What would go further — VMD's ``measure rmsd``
between frames and a scratch molecule of the mean structures, or moving a
copy of the coordinates with ``$sel move`` for the fit — makes and deletes
a molecule at every clustering, which the plugin never does (its exports
too write VMD's frames from a selection).

Source layout
-------------

Where each part of the plugin, its tests and its documentation is::

   vmdance/
     pkgIndex.tcl, vmdance.tcl   package, menu entry, scripting command
     lib/json.tcl         the backend's JSON, read as data
     lib/molecule.tcl     reading VMD: selections at the global level (their texts made short, as ranges, or refused), frames, molecule records
     lib/algorithms.tcl   the algorithms: parameters with defaults and limits, their checks, the backend's arguments, label files
     lib/prefs.tcl        the preferences kept between sessions of VMD (the window's, the backend chosen in Settings), read as data
     lib/backend.tcl      finding CPP-MDANCE (the preferences' first), what it was built with, running mdance-cli in the background, private files
     lib/coords.tcl       the coordinates clustered: the same atoms at every frame, the fit, the rows kept; whether the frames look superposed
     lib/measures.tcl     the plugin's measures: RMSD² from the representatives, distances, silhouettes (two kinds), runs, transitions, the map's PCA, the profiles, the stability's ARI, HELM's tree,
                          the clusters' shares window by window, the groups' divergence, linkage
     lib/analysis.tcl     requests and their checks; the jobs (cluster, elbow, sweep, adopt, import, PRIME, similarity, map, profiles, radii, pick); the backend's output checked
     lib/results.tcl      the clusterings in memory, runs, scans, picks, the selection, queries
     lib/session.tcl      session files; the MDANCE plugin's, imported
     lib/export.tcl       result files: tables, structures
     lib/viz3d.tcl        the 3D drawing: colour by cluster, representatives, overlay, picks
     lib/fonts.tcl        one font family and size
     lib/theme.tcl        the window's looks: native, flat, VMD's own
     lib/tooltip.tcl, lib/icons.tcl, lib/colormaps.tcl, lib/plotlib.tcl   (InteractionView's)
     lib/plots.tcl        the plots of the clusters and the scans
     lib/plots_groups.tcl the plots of the groups and the coordinates: make-up, map, profiles
     lib/figures.tcl      figures (PostScript, Ghostscript) and the 3D view as a picture
     lib/gui.tcl          main window: menus, toolbar, the Setup, Results, Scans, Tools and 3D tabs, running jobs
     lib/gui_opts.tcl     the Plot options panel; showing and hiding the side panels
     lib/gui_io.tcl       sessions, import, export, figures and render dialogs
     icons/               icon PNGs; make_icons.py draws them (the application's, app_*: docs/tools/make_logo.py)
   tests/
     common.tcl           shared: paths, the systems, the backends, check
     fake_mdance_cli      a deterministic stand-in for mdance-cli, with hooks for failures
     fake_mdance_cli.bat  runs it with Python on Windows (Tcl runs no script by its #! line there)
     fixtures/            small multi-model PDBs; sessions of the MDANCE plugin (make_old_sessions.tcl)
     test_core.tcl        the JSON reader, parameters and checks, arguments, label files, a result's checks, runs, sessions as data (tclsh or VMD)
     test_jobs.tcl        the jobs with the fake backend: requests, frames, output checks, failures, Cancel, scans, questions, the coordinates
     test_results.tcl     the command's questions, runs, the 3D drawing, exports and structures
     test_session.tcl     sessions with their molecules, hostile files, imported sessions, preferences
     test_reference.tcl   the real backend: its own labels, program and library, measures by hand, MDANCE's published runs
     test_hardening.tcl   what the reviews found, kept from coming back: files, inputs, the lifecycle, the science
     test_hardening2.tcl  sessions' security and limits: molecule files checked, lists counted, saves bounded, no expr ?: on typed strings;
                          the backend's process: its private folder, Cancel through a launcher, its output, a stop from outside;
                          what reaches the backend: coordinates that are not numbers, numbers out of its range, the metric with
                          the diversity selection, the picks' counts; the library's limits; the preferences in a script; Settings' trial;
                          files and exports; the clustered frames and their molecule: sessions checked against it, frames moved
                          or deleted under a clustering, the drawing and the picks, a selection's atoms, imports
     test_hardening2_*.tcl  what the reviews of the second round's fixes found, a suite each (fx_g1 to fx_g5, g6 to g9, h1, oi, h3,
                          h4: docs/tests.rst says what each keeps); g9's, what the window's fixes ask of the core
     test_groups.tcl      the groups and their colours, the make-up, the map (numpy's PCA), the profiles, the scans' stability,
                          eQual's radius scan, HELM's merges' heights, each against a direct computation (the real backend)
     test_ux.tcl          what the review of the window's use added to the core and the command: alignment, timeline, the silhouette
                          from every frame, what a scan suggests, the variance explained, blocks and the groups' divergence,
                          renumber, radii, the structures as models, help (the real backend)
     test_gui.tcl         windowed: the window, clustering, cancelling, every plot, scans, tools, 3D, files, figures, themes
     test_ux_gui.tcl      windowed: what the same review changed in the window (Setup's frames and fit note, the tables' colours,
                          the plots' new views and options, the figures' sizes)
     test_ux_layout.tcl   windowed: the window's layout at every text and window size, and on small screens
     run_all.sh           every suite (the text-mode ones through strict.tcl)
     strict.tcl           runs a suite so that an error at its top level fails it (VMD's -e goes on after one)
     e2e/                 end to end: four VMD sessions that work, save, quit and reopen (run_e2e.sh)
     profile/             profile_core.tcl, profile_gui.tcl: each procedure's calls and time (prof.tcl; reports in tests/out/profile)
   docs/                  Sphinx documentation: quick start, a complete analysis, every pane and plot, choosing k,
                          groups, the command and recipes, files, the algorithms and parameters, the design
     _static/logo/        the logo: the wordmark (light and dark backgrounds) and its mark, SVG and PNG
     _static/figures/     the screenshots; _static/diagrams/: the diagrams (SVG and PNG)
     diagrams/            the flows' Graphviz sources
     _static/data/        the tutorial's numbers (tutorial_numbers.txt)
     tools/make_logo.py   draws the logo, and the window's icon
     tools/capture.tcl    takes the screenshots (MDANCE's tau peptide); annotate.py numbers the window's parts
     tools/capture_win.ps1  a window's picture on Windows, for capture.tcl
     tools/make_diagrams.py  draws the diagrams (matplotlib, and dot for the flows)
     tools/tutorial_numbers.tcl  the tutorial's numbers; gen_parameters.tcl: the parameters page
   TESTING.md             what to check by hand
   Makefile               make distrib: the plugin into a VMD plugin tree
