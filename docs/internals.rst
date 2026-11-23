Internals
=========

.. warning::

   The state and procedures below are documented for scripts that need more
   than the command gives, and for work on the plugin. They are **not a
   stable API** in this alpha.

A clustering
------------

``Job::_result`` returns one dict. ``Results::publish`` checks it
(``Results::check``) and makes it current. Its keys:

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
     - the backend's answer, checked:

       - a label per frame (-1: noise)
       - the sizes, counted from the labels
       - the representatives, as rows (-1: an empty cluster)
       - the MSD within ("" for an empty cluster)
       - the two scores: "" when not finite, with fewer than two clusters,
         or when every cluster is a frame alone. With a trim, HELM's are
         those of its clustered frames (``Measure::scores``).
   * - ``zmatrix``, ``initial``
     - HELM's merges ``{a b rank count}``, as the backend numbers them, and
       its starting labels. ``Measure::helm_tree`` numbers the merges as
       scipy does, for the tree, the command and the export.
   * - ``measures``
     - ``frame_msd silhouette silhouette_pairs``, per frame: the silhouette
       from the mean structures, and from every frame. A run made before
       has no ``silhouette_pairs``.

       ``rep_msd centroid_msd``, k × k. They are ``{}`` (not measured)
       above ``Measure::maxk``, 300 clusters.
   * - ``extras``
     - ``prime``, ``similarity``, ``map``, ``profiles``: what was asked of it
       (``Results::attach``). Also ``groups``.
   * - ``backend``, ``seconds``, ``created``
     - ``{cli path}``, ``{library path}`` or ``{imported file}``; the time
       and date
   * - ``unrecorded``
     - an import's, when its file does not record them: ``metric params``.
       The request then has MSD and the defaults. ``info``, the ``#``
       header and the run's name say they are not recorded.

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
       dip, Calinski–Harabasz's highest, the stable values); the share of
       the variance a record's clusters explain
   * - ``renumbered a``
     - a clustering with its clusters numbered by size. The labels, every
       list and matrix with a row per cluster, and the per-cluster parts
       of its extras are renumbered together.
   * - ``selected``, ``set_selection cs ?set|add|toggle?``
     - the selection
   * - ``run_list``, ``run_switch``, ``run_label``, ``run_delete``, ``run_data``, ``set_runs``, ``clear_all``
     - runs (kept ``zlib``-compressed)
   * - ``elbow``, ``sweep``, ``picks`` (variables), ``set_elbow``, ``set_sweep``, ``set_picks``
     - the last scans and picks
   * - ``listen cmd``, ``unlisten cmd``
     - ``cmd what`` is called after a change, where *what* is
       ``analysis``, ``selection``, ``runs``, ``extras``, ``elbow``,
       ``sweep`` or ``picks``

The jobs
--------

``Job::check_cluster``, ``check_elbow``, ``check_sweep``, ``check_input``
and ``check_specs`` complete and check a request. Their errors name the
option. Two checks of HELM's come later:

- ``Algo::check_starting`` checks HELM's starting clusters as the backend
  gets them, once its first clustering is made.
- ``check_trimmed`` checks what ``-trim-val`` left, once HELM has run.

In ``Job::_cluster``, a scan keeps a k they refuse as not run, and a scan
where none ran is refused.

Running and stopping a job:

- ``Job::run kind req ?progress?`` runs a job to its end and returns its
  value.
- ``Job::start kind req progress done`` runs it in a coroutine and calls
  ``done status value``. The status is ``ok``, ``cancelled`` or
  ``error``. The value of a cancelled job is why the backend was stopped
  from outside, or empty.
- ``Job::cancel`` stops it.

The kinds: ``cluster elbow sweep adopt import prime similarity map
profiles radii pick``. An elbow scan cancelled after two values keeps them
in ``Job::partial``. That is a scan of its own, for its caller to keep
(the window does).

``Job::_call`` runs the backend once: either the program, through
``Backend::start``, or the library's command. ``Job::output`` checks a
clustering's answer.

``Backend::start`` runs the program with ``open |``. A fileevent reads its
output 16 KB at a time, and pauses while more waits. The coroutine is
resumed when the program's processes have ended: a blocking ``close``
would wait for one that closed its output first. It never runs a program
that the probe found is not ``mdance-cli``.

``Backend::cancel`` sends TERM to what the program started, else to the
program. (A launcher that does not ``exec`` leaves ``mdance-cli`` under
it.) It sends KILL to them all 1.5 s later. A status ``stopped`` means a
signal from outside (Ctrl+C, ``kill``). It stops the whole job, as Cancel
does.

The private folder (``Backend::workdir``) is named
``vmdance-<user>-<machine and PID namespace>-<pid>-<random>``. It is
checked by uid, and is never one that already exists. ``_reap_dead``
removes only the folders of VMDs that ended, and only this machine's and
namespace's.

``Coords::extract`` reads the rows into a CSV file of the private folder,
whatever the backend. It reads them in slices, in a coroutine. It refuses
a frame whose coordinates are not numbers (its fingerprint is not a
number either: ``Coords::_row``). It keeps the last extraction
(``Coords::cached``). That is dropped when the molecule changes, and at
once when it is deleted (a trace of ``vmd_initialize_structure``).

``Coords::each`` reads the rows again: from VMD while the molecule is
unchanged, else from the file. ``Measure::compute`` measures a clustering
in two such passes. It yields and says how far it is, and Cancel stops
it. Then it measures each pair of clusters once, for 300 clusters or
fewer. When HELM trims, ``Measure::scores`` scores its clustered frames in
two more passes. A scan's every k is scored in the same two, and each
cluster that several k have is scored once.

The silhouette from every frame is made in the same second pass. A
frame's mean squared distance from a cluster's frames is its squared
distance from their mean structure, plus their spread. The first pass
keeps that spread.

From the labels alone, ``Measure::shares`` and ``first_seen`` count the
clusters' frames window by window. ``Measure::divergence``, also from the
labels, compares the groups' shares of the clusters.
``Coords::alignment`` measures a sample of frames against the first, as
they are and fitted (on values). ``Coords::superposed`` is the rule.

A frame's fingerprint (``Coords::_print``) is the selection's centre,
radius of gyration, weighted centre and RMSD from the first frame (and the
fit's). A result, a scan and the picks keep:

- the digest of their frames' fingerprints, with ``2:`` first (one
  without it, of a session made before, is compared as it was made);
- each frame's radius of gyration (``shape``);
- the atoms their selection held (``atoms``, ``fitatoms``), which every
  later read uses, not the texts.

The library gets the rows as one list (``Coords::flat``). The list's text
is the CSV's, less a byte. ``Job::_library_fits`` refuses a call whose
text would pass Tcl's 2 GB, or that needs more memory than VMD can get
(``/proc/meminfo``, its cgroups). It checks before the frames are read
(estimated) and before each call (exactly).

``Job::_call`` makes that list once a job (``lib_rows``, keyed on the
extraction, dropped when the job ends). It gives every call the same
object. CPP-MDANCE's binding makes its text at the first call (it reads
its options from every argument). A scan's next k reads no frame again.

A library call blocks VMD. Before it, the job posts what runs, that the
library runs it, and that VMD waits. It then yields 20 ms, so that the
window shows it. It yields again after the call, since VMD reads a Cancel
pressed during the call only then. The job stops there, before it goes on
or publishes (``lib_most`` counts the call once it is made).

``GUI::_progress`` shows a new step at once. Only the same step's counts
(its text but for its numbers) are shown at most every 250 ms.

``Backend::from_prefs`` reads the backend chosen in Settings
(``Prefs::load``, a core module). It reads it once, as values, when the
backend is first asked about. ``configure``'s options are set over it.

``Backend::probe`` says what options would give, without keeping them
(Settings' trial, ``vmdance backend try``). Nothing in it enters the event
loop, so no job sees the backend tried.

Sessions
--------

A session file is gzip-compressed UTF-8 text. Its first line is
``VMDanceSession 1``. Then comes a Tcl dictionary, read as data:
``format plugin created runs current selection elbow sweep picks gui``,
with ``runs`` ``{id label result} ...``.

Before anything is replaced, every result goes through
``Results::check``, and the scans' records through
``Results::check_clustering``. A scan and the picks keep their
``backend`` and ``created`` too, checked as a result's
(``Results::check_meta``). They also keep their atoms, digest and shapes
(``check_atoms``, ``check_identity``).

Frame numbers are VMD's only while the molecule has the frames that were
read (``Results::frames_ok``, ``picks_ok``). It has them:

- as a job read them in this VMD (``Results::trusted``). That is the
  molecule's number of frames and files then, and the deletions seen on
  it since. It is kept in memory and never saved: another replica has the
  same names.
- else, by the digest of the coordinates at those frames;
- else, by every frame's radius of gyration, within a float's rounding.
  This accepts frames moved in place rigidly (an alignment). It is used
  only where those tell frames apart.

The last answer is kept for the molecule as it is (``Results::_now``).
VMD says nothing of a deletion. So the frame of a molecule that something
is kept for is traced; a load writes it at every frame read. A count of
frames lower than the last seen is frames deleted.

For every run, scan and the picks, ``Session::load`` first tries the
molecules loaded. It looks for its files in full (``paths``) or as typed,
then for its name and atoms. Then it tries its files: in full, from the
session's folder, as typed. It goes on until one has their frames
(``_mol_for``, ``_has_frames``). Those that pass are trusted. A molecule
that it loaded may have frames before theirs that it did not have then:
those are deleted again.

``Viz::draw`` records the molecules it drew on and traces their frame.
``Viz::check`` draws again (or withdraws) when they changed.

Files
-----

Every file the plugin writes goes through ``Export``: exports, sessions,
the preferences, figures.

- ``target file`` checks a name before anything is written, and returns
  the file it writes. A link of the user's is followed; one of another
  user's is replaced. The file must not be a folder, nor read-only.
- ``_write file data ?binary?`` writes it to a temporary beside it,
  opened ``EXCL`` under a name not guessed (``_open``). It then renames it
  onto the file (``_commit``). A link of another user's is deleted first,
  as Tcl's ``rename -force`` would make what it points to writable. The
  file keeps its permissions (``_keep``, where chmod is allowed).
- ``_copy src file`` does the same with a file VMD, Tk or Ghostscript
  wrote into the private folder.
- Within ``_batch script``, the files are renamed only once all of them
  are written.

``Export::check dir prefix items opts`` checks a bundle. What each item
needs is ``why_not item``, which the window asks too. It lists the
bundle's files, and the clusters that an earlier export of trajectories
left and that it deletes (``stale``). ``bundle`` writes them in one batch,
in a folder it makes (``_mkdir``). If it fails, it deletes that folder
again (``_unmake``).

``write_frames`` writes a DCD itself, with each frame's unit cell, as
``dcdplugin`` does. It writes a PDB with VMD's ``writepdb``, frame by
frame. Each frame is checked whole (``_whole``: its last ``END``). It is
then put between ``MODEL`` and ``ENDMDL``, under its ``REMARK``
(``_pdb``: several frames, or frames with notes, are models).

Where the time goes
-------------------

``tests/profile/profile_core.tcl`` (text mode) and ``profile_gui.tcl`` (the
window) wrap every procedure of the plugin. They count its calls and time.
The reports go to ``tests/out/profile``. On a Linux workstation (VMD 2.1,
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
Tcl:

- Reading a frame of 217 atoms from VMD costs 70 µs (``$sel get`` and the
  list made flat).
- Each distance between two rows costs 27 µs (VMD's ``vecsub`` makes a
  new list; ``veclength`` is C). The measures take 1 + k of them per
  frame, on the second of their two passes.
- Above 64 clusters they take fewer. A frame's nearest other mean
  structure (its silhouette's) is looked for in groups of them, nearest
  first. One that the triangle inequality puts farther than the nearest
  found is not measured. On states3's 1462 clusters, where the distances
  in 180 dimensions are nearly all alike, the measures take about a third
  of them.
- With a fit, a frame's transform costs 250 µs (VMD's ``vectrans``,
  called per atom). Its rotation is the plugin's own, not ``measure fit``:
  ``Coords::fit_matrix``, Horn's quaternion, about 0.15 ms a frame for 50
  atoms.

VMD's ``veclength2``, ``vecdot``, ``vecdist`` and ``coordtrans`` are Tcl
procedures. So the plugin calls ``veclength`` and ``vecsub`` directly. A
frame's fingerprint uses ``measure center``, ``measure rgyr`` and
``measure rmsd``, which are C: 10 µs a frame of 217 atoms, 95 of 3238,
where lists took 110 of 217.

Two ways would go further:

- VMD's ``measure rmsd`` between frames and a scratch molecule of the mean
  structures;
- moving a copy of the coordinates with ``$sel move`` for the fit.

Both make and delete a molecule at every clustering, which the plugin
never does. Its exports too write VMD's frames from a selection.

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
