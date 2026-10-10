# VMDance — notes for working on it

A VMD Tcl/Tk plugin (package `vmdance`, command `vmdance`, namespace
`::VMDance`) that clusters a trajectory's frames with MDANCE's
algorithms, run by CPP-MDANCE (`../CPP-MDANCE`: `mdance-cli` and the
`mdance_tcl` library). It replaces, rewritten from scratch, the MDANCE VMD
plugin this repository held before (its last version: commit bf6fd41; the
rewrite was called MDANCEView, in its own repository ../MDANCEView, until it
took its place on 2026-10-09; MDANCEView's sessions and preferences are
still read), following the design of
DihedralView (`~/.vmd/plugins/noarch/tcl/VMD-Dihedral-view-TEMP`),
InteractionView (`~/github/myprojects/vmd-plugin-projects/vmd-interactions-v2/InteractionView`)
and Molywood Studio. README.md (Design, Differences, Layout) and
docs/internals.rst describe it.

## Rules the design keeps

- One command does everything the window does: a new window feature gets
  a `vmdance` subcommand (`_api_*` in vmdance.tcl) and a test.
- The core (json, molecule, algorithms, backend, coords, measures,
  analysis, results, session, export, viz3d) never uses Tk; the window's
  modules load lazily (`_load_tk`). viz3d is core: the command draws in 3D
  too.
- A clustering is one dict (Job::_result), checked and published whole
  (Results::publish, Results::check); the runs, the scans (elbow, sweep),
  the picks and the selection live in Results. The window listens
  (Results::listen) and holds no results. A job (Job::start/run) never
  publishes: its caller does.
- The parameters are one table (Algo::A in algorithms.tcl): the command's
  options, the window's fields, the checks and the backend's arguments are
  made from it. A parameter has mdance-cli's name. The plugin's own
  (HELM's `initial*`) are listed in `local` and never passed on. An
  algorithm's metrics are there too (`metrics`, `metric_why`: DIVINE's and
  eQUAL's MSD only), and the seeding a sweep sets (Algo::seeding_of: none
  for HELM from a label file and DIVINE's pair anchors, run once a k).
- Every check that can be made before the backend runs is made there, with
  the option's name and what to change (Algo::check_combination: NANI's
  seeds, HELM's starting clusters and trim, DIVINE's crash, metric, first
  split, smallest share and points, the diversity selection or eQUAL with
  any index but MSD; check_starting: HELM's starting clusters as the
  backend gets them, once its first clustering is made; check_trimmed: what
  -trim-val's cut left, once HELM has run; check_value: a number the
  backend can read; Coords::_row: coordinates that are numbers;
  Job::_library_fits: what the library can take; Job::_library_divine: the
  DIVINE splits that would crash it). A scan keeps a value that fails its
  checks as a record "not run: …" (errorcode VMDANCE NOTRUN) and goes on.
- The backend is the reference: test_reference runs mdance-cli directly on
  the plugin's CSV and compares every label; the library against the
  program; the measures against direct computations; MDANCE's published
  runs. A deliberate difference gets a comment, a line in README's
  *Differences*, and a test. A divergence that is CPP-MDANCE's (the
  stratified seed's rounding) is recorded (SKIP with the numbers), never
  loosened into a pass. Compare with MDANCE's published runs on the atoms
  they cluster, the Cα: on the backbone, HELM's populations looked like a
  backend difference (0.197 on the tau peptide) and were another choice of
  atoms (found 2026-10-09; on the Cα everything is MDANCE's to the digit).
- Frames: a result holds the VMD frames it clustered; every per-frame list
  is in their order (row i is VMD frame [lindex frames i]). The backend's
  indices are rows. Never hand a row out as a frame. A frame number is
  VMD's only while the molecule has those frames (Results::frames_ok,
  picks_ok): everything that uses one (goto, frame, 3D, the user field,
  structure exports, the picks' goto and Save) goes through Viz::_mol or
  Viz::_picks_mol.
- Files are data: the backend's JSON (Json::parse), sessions, the MDANCE
  plugin's sessions, label files and preferences are parsed and checked,
  never evaluated. Numbers are checked with regexps before expr sees them
  (expr compares "1o" as a string and reads "010" as octal).
- VMD state is borrowed: a job never moves VMD's frame or coordinates (the
  fit is computed on values: `coordtrans`, not `vectrans`, which drops the
  translation); selections are made and deleted at the global level
  (Mol::sel, Mol::free); the plugin's representations are found by name
  (mol repname) and only they are deleted; `mol addrep` settings are read
  and put back (Viz::_mol_settings); the user field is written only when
  asked (`userfield`); structure exports make no molecule (VMD's writers,
  frame by frame, from a selection); the frames of a molecule are changed
  only when a session loaded it itself (Session::_has_frames: its PDB's
  own frame deleted again), never the user's.
- Every file written goes through Export (exports, sessions, preferences,
  figures): `target` checks the name first (a folder, read-only; a link of
  the user's followed, another's replaced), `_write`/`_copy` write a
  temporary beside it opened EXCL under a name not guessed and rename it
  onto the file, which keeps its permissions; within `_batch` (a bundle, a
  DCD and its PDB) all are renamed once all are written. VMD's, Tk's and
  Ghostscript's writers open a name: they write into the private folder,
  and the file is copied in.
- The docs and messages use the reference plugins' voice: plain, short,
  concrete sentences.

## Running the tests (this Linux machine)

- VMD 2.1: `/home/dgomes/software/vmd2-integration/bin/vmd` (`vmd` on the
  PATH). The real backend: `$MDANCE_CLI` (set in the shell:
  `../CPP-MDANCE/build/cli/mdance-cli`, built without DIVINE) and
  `../CPP-MDANCE/build/tcl/mdance_tcl.so`. MDANCE's reference runs:
  `~/Downloads/mdance_vmd_runs` (MDANCE_REF_RUNS). The shared systems:
  `~/github/myprojects/vmd-plugin-projects/vmd-interactions-v2/VMD-testsystems/systems`
  (VMDANCE_SYSTEMS).
- The windowed suite in a nested X server, so nothing opens on the
  desktop: `nohup Xephyr :9 -screen 1600x1200x24 -ac &` (it can die between
  runs: check `pgrep Xephyr` when a run finds no display), then
  `DISPLAY=:9 sh tests/run_all.sh`, or one suite:
  `vmd -dispdev text -e tests/test_{core,jobs,results,session,reference,hardening,hardening2}.tcl < /dev/null | grep -E "FAIL|SKIP|RESULT"`
  (and the second round's fixes, a suite each: `tests/test_hardening2_{fx_g1,fx_g2,fx_g3,fx_g4,fx_g5,g6,g7,g8,g9,h1,oi,h3,h4}.tcl`, which run_all.sh runs too),
  `tclsh tests/test_core.tcl`, and
  `DISPLAY=:9 vmd -dispdev win -e tests/test_gui.tcl < /dev/null; grep -E "FAIL|RESULT" tests/out/gui.log`.
  Last results (2026-10-09): 140, 110, 67, 42, 33 (3 skips), 31, 194, 219
  (core, jobs, results, session, reference, hardening, hardening2, gui), and
  the groups' 42, 5, 15, 19, 23, 25, 73, 56, 8, 59, 35, 17, 18 (fx_g1 to
  fx_g5, g6 to g9, h1, oi, h3, h4; with the papers and decks beside the
  repository and states3 made; a clone: g7 68, g8 51, h4 17), all
  passing (the window's too, on a nested display). End to
  end: `DISPLAY=:9 sh tests/e2e/run_e2e.sh` (29, 14, 15, 10). Profiles:
  `tests/profile/profile_{core,gui}.tcl` (reports in tests/out/profile).
- Screenshots: `import -window [wm frame .vmdance] f.png` (ImageMagick)
  on display :9.
- Icons: `cd vmdance/icons && python3 make_icons.py` (Pillow). The logo
  (docs/_static/logo/) and the application's icon (app_*), from
  `python3 docs/tools/make_logo.py` (fontTools, uharfbuzz, cairosvg, Pillow
  and the Inter font): VMD and MDANCE share MD, so a blue bracket spans VMD
  and a rust one MDance; muted tones, as the plots'.
- Old-plugin session fixtures (tests/fixtures/old_*.mdance) were written by
  the MDANCE plugin itself (its run_clustering, run_one_config and
  save_session, its files read only) with the real mdance-cli:
  tests/fixtures/make_old_sessions.tcl (old_helm_eps.mdance with
  MDANCE_CLI_OLD, an mdance-cli built from CPP-MDANCE ed2a076, before
  4042c24). An import checks their clusterMSD (MDANCE's) against the
  coordinates; the plugin's fake backend wrote the mean RMSD² to the
  representative there.

## Traps already hit

- `$R::name` with `set R ::VMDance::Results` reads a variable: write
  `${R}::name` (the tests use it everywhere).
- `dict set d …` changes d itself: a test that builds a bad copy with it
  spoils every check after (test_core's `dset`).
- `set out …` at the top level of a test overwrites `::out`, the output
  folder of common.tcl.
- A hostile string inside a double-quoted string of a test is run by the
  test itself when it writes the file: escape the brackets (`\[exec …\]`).
- `vectrans` transforms a direction (no translation); a point needs
  `coordtrans`: the fit was wrong until test_jobs compared distances.
- `animate dup` crashes VMD 2 later (on a delete): add frames with
  `mol addfile`.
- `molinfo … get drawframes` does not exist: `mol drawframes m rep`.
- Widget names cannot start with a capital letter (`$f.MSD`): prefix them.
- Coordinates moved in place change no molecule attribute: the kept rows
  carry every frame's fingerprint (Coords::_print: centre, radius of
  gyration, weighted centre, RMSD from the first frame, in C; without the
  RMSD a swap of atoms 1009 apart, or a frame mirrored through its two
  centres, went unseen), and results, scans and picks its digest ("2:"
  first; one without, a session's of before, is compared as it was made:
  Coords::same_prints) and each frame's radius of gyration (shape); a test
  that moves a frame and moves it back does not restore VMD's floats (+50
  then -50): save and set them.
- Rows parsed from text cost ~1 µs a number to convert; the measures read
  them again from VMD (`$sel get` is numbers already), checked against the
  fingerprints, and fall back to the CSV only when the molecule changed.
- The Xephyr on :9 can die between commands: `pgrep Xephyr` first, and
  start it with `setsid nohup … < /dev/null &`; a windowed suite that finds
  no display leaves the previous gui.log in place.
- Tk frees a font nothing draws with and opens it again for every
  `font measure` (1.4 ms each with Xft): a cleared canvas measured 1000
  tick labels in 11 s. Plot::_hold_fonts keeps a hidden text in each Mdv
  font. Measure a label once, not per candidate step (Plot::_fit_ticks).
- A photo image written over keeps its larger size (`blank` and
  `-width 0` do not shrink it): make it again under the same name
  (`image create photo name`); an element cannot be made twice
  (Theme::_indicator).
- `if {cond} ::cmd arg` reads `arg` as the else body: brace the body.
- A canvas window item is clipped only when its widget is the canvas's
  child: the left pages' widgets are in `$tab.c.p` (GUI::page(key)), never
  hard-coded as `$w.pw.left.nb.<key>…`.
- CPP-MDANCE's HELM numbers its merges from the starting clusters left
  after trimming, so that "16" can be a merge and a starting cluster:
  Measure::helm_tree tells them apart; never read `zmatrix` as scipy's.
- A file name from a user reaches `open`: "|cmd" is a pipe, "<f" a
  redirection for exec. `file normalize` every name first (Session, Export,
  Figures, label files). Files read must be `file isfile` (a FIFO blocks)
  with a size limit, and a gzip stream unpacked with a cap (`zlib push`).
  `file normalize ~user/x` fails when that user does not exist (Tcl 8.6),
  where `file isfile` says 0: a stored path is tested before it is
  normalized (Backend::from_prefs).
- A session's molecule record names files and a type that VMD reads: a
  Babel converter type (Alchemy, SybylMol, …) runs a program on the file,
  `webpdb` downloads it, the AMBER and NetCDF readers give the name to a
  shell, and a FIFO or device blocks or is read without end. Session is
  data: load_molecule normalizes the names, refuses any with a shell
  character for a type that gives it to one (parm, parm7, netcdf: a user's
  folder "R&D" is no reason), any that is not a non-empty file (or a `.dtr`
  folder) or has a FIFO or device beside it, or in a `.dtr` folder's
  folders, links followed (a reader opens files beside the one named:
  VASP's POTCAR; Session::_blocking), and any type that is not one of VMD's
  own file readers (`plugin list`, minus `webpdb`) before `mol new`.
- A list parsed from a file costs ~120 bytes a value, so a few KB of text
  can allocate gigabytes: values are counted before the list is made, by
  every character Tcl's lists split on (space, tab, line ends, and `\v`
  and `\f` too) and every backslash (`0\n1` is one value, and two a level
  down), not `llength`. A session is bounded by `max_bytes` and
  `max_values` (read_file and save share them); `_count`/`_fits` in
  results.tcl refuse a list whose text is too long for its count before
  `string is list`, `_elements` counts any list's values as Tcl reads them
  up to a bound (a scan's records), and frames with fewer digits than 0 to
  n-1 are refused unread (a value repeated); `nclusters` is checked ≤
  frames, the selection ≤ the current run's k, the picks' rows ≤ frames.
- `expr {c ? $s : …}` with a string a user typed or a file holds fails on
  "NaN" and rewrites "010" to 8, "0x1F" to 31, "1e10" to 10000000000.0
  (expr reads it as a number): `::VMDance::_get`, or `if`. A session
  that would be written unreadable (over `max_bytes`) is refused before the
  old file is touched, naming what to drop (runs to delete; the scans and
  the picks to clear: `elbow clear`, `sweep clear`, `pick clear`) and the
  limit to raise (Session::save).
- A comment inside a `switch` body is a pattern: put it above the switch.
- `string is integer -strict` takes "010", "0x3", " 3", "+3", which `lindex`
  and `expr` read as 8, 3, 3, 3: an index or a whole number typed, or held
  by a file, is `::VMDance::whole` (sweep load, GUI::_state_ok's spin,
  the plots' and exports' lag). Every option parser refuses a name given
  twice (`_opts`, `_request`, `_specs_given`, `_api_draw`,
  Backend::_options, and the lists of figures' -options and sweep's
  -params): a `dict set` kept the last, the first never checked.
- Frame numbers are only the clustered ones while the molecule has the
  frames it had (Results::frames_ok): as a job read them in this VMD
  (Results::trusted: its count and files then, in memory, never saved), or
  as a session's run was found to have them as it opened; else the digest
  of the coordinates at the clustered frames; else every frame's radius of
  gyration within a float's rounding (moved rigidly in place, an
  alignment; only where those tell frames apart). The same count and file
  names prove nothing across sessions: another replica's folder has them.
  The last answer and the trust are kept for {mol numframes files
  deletions} (Results::_now): VMD says nothing of a deletion, and frames
  deleted back to a count seen while a trajectory loaded reused them; the
  frame of a molecule something is kept for is traced (a load writes it at
  every frame read), and a count lower than the last seen is frames
  deleted. The picks have their own (picks_ok: the frames up to the last
  picked one); the 3D views, goto, frame, the user field and the structure
  exports use Viz::_mol, the picks Viz::_picks_mol.
- VMD keeps the file names as typed (`mol new sys.pdb`: of the folder it
  was in, which it does not keep): a molecule record keeps them in full too
  (paths, of VMD's folder when it is recorded: after a cd, another);
  sessions try the molecules loaded (paths or the names as typed, then the
  name and atoms) and the files (paths, the session's folder, as typed)
  until one has the frames (Session::_mol_for). A molecule loaded
  with a PDB's own frame, deleted when it was clustered, is shifted by one:
  Session::_has_frames tests the frames moved by the extra count and
  deletes them again on a molecule it loaded itself, never on the user's.
- VMD writes no variable when frames are deleted under a valid current
  frame (vmd_frame only when the frame moves): a drawing is checked at the
  next frame change of a molecule it is on (Viz::_frame_trace, after 300 ms
  of quiet: a load writes vmd_frame at every frame, and `after idle` runs
  between them), as a figure renders, and on the window's molecule refresh.
- `rename ::ns::p ::q` moves the procedure out of its namespace: its body's
  unqualified calls then fail (a test's counting wrapper did): keep the
  renamed one in its namespace.
- A selection text can select other atoms after the structure changes
  (and `mol addfile` of a PDB sets every atom's beta and occupancy from
  that file): requests carry the atoms' indices (check_input), the kept
  coordinates are keyed on them, results, scans and picks keep them (atoms,
  fitatoms), and every later read (Job::_input_of, Coords::extract, the
  frames' check, Viz::_atoms) uses them, not the texts.
- Mol::dynamic reads a selection's words as VMD's lexer does: a quoted
  value is never a keyword (VMD needs the quotes for `chain "x"`, `segname
  'y'`), and a quote after a letter or digit is part of a name (`C5'`,
  `O5'`: stripping quoted strings pairs those primes and hides an `x > 1`
  between them). A selection is checked valid before dynamic (`chain "x`
  without its end quote is no selection). `nearest` and `pucker` change
  with the frame too, and a macro (`atomselect macro`) is read as its text.
- Job::run waits on a variable of its own (nested runs), the job's backend
  is fixed at its start, and the package is loaded once
  (::VMDance::loaded).
- MDANCE's MSD of two frames is half their RMSD² (the mean over the pairs,
  self-pairs included): the backend's "msd", eQUAL's radius and the
  similarity ceiling are MDANCE's; the plugin's own measures are RMSD².
- NANI's seedings by extended similarity (StratAll, StratReduced, CompSim,
  DivSelect) draw k seeds from floor(n × percentage / 100) frames:
  mdance-cli fails "fewer centers than kClusters" otherwise. The fixtures'
  tests seed with KmeansPP.
- CPP-MDANCE's Tcl library registers `::mdance::divine` whether or not it
  was built with DIVINE: Backend::algorithms asks it. It keeps a program's
  answer with the file's stamp (inode, size, times): a program rebuilt at
  its path is asked again, and so is any before an algorithm is refused as
  not built in (a launcher's stamp stays the same); a test that changes
  what one says writes it again (another size), or clears `caps` (fake_env).
- CPP-MDANCE's DIVINE (`BUILD_DIVINE`, on a tree with divine.cpp: its
  feat-vmd-plugin branch; built in a scratch folder it runs test_reference's
  DIVINE checks) splits by MSD whatever `--metric` (the representatives use
  it); `--threshold` is the smallest share of the frames each side of a
  split keeps, round(t × n) (MDANCE: int), tested by the pair anchors'
  splits only, never NANI's; `--refine` is read by the pair anchors only
  (which then read out of bounds); `points` ignores k; each NANI split is a
  2-cluster NANI of the cluster, seeded from floor(m × p / 100) frames
  (CompSim with none crashes). It returns no parents of its splits: its
  Tree is a linkage.
- CPP-MDANCE's stratified seeding rounds a position half away from zero
  (`std::round`), MDANCE's half to even (`np.round`): 50 frames at 10%
  (24.5) seed otherwise (test_reference records it from
  tests/fixtures/mdance_3ptb.txt, MDANCE's own labels of the plugin's CSV).
- The fake backend writes NaN (Python's json); the real one null: both are
  "" for the reader.
- A named font that does not exist is taken by Tk as a family (no error):
  anything that draws plots without the window calls `Plot::init_fonts`.
- Tcl's `exec … 2>&1` is no redirection: it writes a file named `&1`.
  Standard error into the result is `2>@1` (and the message then ends with
  "child process exited abnormally").
- A blocking `close` of a command pipe waits for the program to end, and
  its output can end first (a launcher that logs): VMD froze in close. The
  job is closed once its processes are zombies (Backend::_reap reads
  /proc/<pid>/stat; `kill -0` succeeds on a zombie).
- VMD runs every Tcl event that is ready (`while (Tcl_DoOneEvent(
  TCL_DONT_WAIT))`) before it draws or reads its console: a fileevent
  handler that leaves its channel readable starves it, even returning each
  time. A pipe is read in slices (`read $ch n`; `gets` reads a line without
  its end whole), pausing (`after 1`, the handler re-armed) while more
  waits.
- A launcher that does not `exec` leaves mdance-cli under it: TERM goes to
  what the program started (a shell dies of TERM at once and leaves its
  child out of reach), KILL to all; the tree is collected (/proc, else `ps`)
  before any signal, since a dead process's children are reparented.
- Owners are compared by uid (`file lstat`'s uid, /proc/self/status's
  effective uid): with no passwd entry `tcl_platform(user)` is "" and
  `file attributes -owner` is a number. `file mkdir` of a folder that exists
  succeeds: lstat before, check after.
- A TMPDIR can be shared by machines and containers, whose processes /proc
  does not list: the private folder's name carries the machine and PID
  namespace (`_where`), and only those are reaped.
- `info hostname` is the resolver's name for the node name (gethostbyname):
  `localhost.localdomain` on every host whose name is an alias of localhost
  in /etc/hosts, and a wait where DNS does not answer. `_where` reads
  /proc/sys/kernel/hostname (else `uname -n`) and /etc/machine-id.
- ps reads /proc too: in a PID namespace without a /proc of its own
  (`unshare -p` without `--mount-proc`) it tells of another process of the
  number. Backend asks ps only where there is no /proc (`_ended`,
  `_descendants`); where /proc is another namespace's, it cannot tell.
- `close`'s error code says how a program ended: `CHILDKILLED pid SIGINT
  interrupt` (Ctrl+C at VMD's terminal reaches it; VMD ignores it), or
  `CHILDSTATUS pid 130` from a launcher whose program a signal ended (128 +
  n). A stop from outside ends the whole job (Backend::_stopped_by); a
  crash is one failure.
- CPP-MDANCE's HELM stops only at k + 1 clusters: with k or fewer starting
  clusters it merges them all into one (k: none). A first NANI clustering
  can leave clusters empty (renumbered away: states3 at -initial 30 left
  26), and with -trim-start the backend first drops the starting clusters
  smaller than -min-samples (a C float; below 1, times the frames in float,
  truncated: 0.29 of 100 is 29) and fails "trimK is too large!" when
  -trim-k takes all but one of the rest. Algo::check_starting counts them
  so, before HELM runs (Job::_cluster; a scan's k: "not run", errorcode
  VMDANCE NOTRUN; a scan where none ran is refused), and check_trimmed
  what -trim-val's cut (an MSD the backend computes) left, once it has run.
  A scan says -ks where the checks say -k (Job::_scan_says).
- The backend's placeholders are not numbers: an empty cluster's MSD and
  iSIM are 0 (the tightest), every cluster a frame alone gives CH 1 and DB
  0 (the best of a sweep; scikit-learn refuses k = n), and its HELM scores
  the trimmed frames (-1) as a cluster of its own, where its eQUAL and
  MDANCE leave noise out. Job::output blanks them (_scored), HELM's clustered
  frames are scored by the plugin (Job::_clustered_scores, Measure::scores:
  a scan's every k together, in two passes; a pass per k made a HELM elbow
  with a trim 2.4 times as long), and a scan's record counts the clusters
  with frames. A session saved before has them blanked as it opens
  (Session::_as_now); HELM's scores with a trim it keeps as they were.
- A scan or a pick takes its own options, the command's defaults where none
  is given, never the current run's (the window's Setup follows the run):
  the docs' `elbow` after a backbone CompSim clustering scanned Cα with
  StratAll, and `elbow load` published it. A listing gives a scan the
  clustering's options; the command notes the difference (_scan_note).
  A sweep's seedings are -seedings: _api_sweep refuses one in -params (not
  sweep_configs: the window passes its Setup's, which the grid replaces).
- Under `vmd -e script`, `info script` is empty inside procedures called
  later: the papers' scripts (manuscripts/, beside the repository) source
  `[pwd]/scripts/common_ms.tcl` and run from `manuscripts/shared`.
- VMD's launcher (bin/vmd) unsets DISPLAY for `-dispdev text` (and none):
  Tk cannot load in text mode even on a desktop, so `figures` fails there;
  `_load_tk who advice` lets it say so with its own advice, not the
  window's "use the command".
- ttk styles are logical names (`Muted.TLabel`, `Section.TLabel`,
  `Holder.TFrame`); Theme::style_tree maps them to the look's prefix
  (MdvH, MdvN, MdvF).
- VMD runs with subnormal numbers flushed to zero: `expr {1e-320 > 0}` is 0
  in VMD and 1 in tclsh, and `double(1e-320)` is 0.0. A zero is told by its
  digits (Algo::check_value); a check of it run only in tclsh passes where
  VMD's fails.
- mdance-cli reads HELM's numbers as C floats (`stof`) and the others as
  doubles (`stod`), and fails with a bare "stof"/"stod" beyond their range,
  where the library rounds: a new number is 0 or 1.2e-38 to 3.4e38 in size;
  a stored one (sessions: `stored`) is kept. It reads `-eps -0.99999999` as
  -1, a diversity pick's `-param` below 1 as a share (0.5: half the frames)
  and makes HELM's `-min-samples` a C int (3e9 overflows).
- CPP-MDANCE's diversity selection (CompSim, DivSelect, eQUAL's comp_sim,
  the diversity pick) starts from -1 and reads past its data when no
  frame's 1 − index is above it: with any index but MSD, on coordinates
  (`mdance-cli` crashed; every frame in one cluster, published as k).
  eQUAL's radius by such an index holds every frame (1 − index below 0):
  one cluster whatever the seeds, so eQUAL takes MSD only. A
  representative sample's share is one frame at least (the outliers' may
  be none).
- Non-finite coordinates: VMD reads "nan" in a PDB's coordinate as NaN;
  `atomselect set x NaN` is refused but `Inf` is taken (the tests make them
  so). A frame's fingerprint is then not a number (`regexp -nocase
  {nan|inf}`), and so is one of finite coordinates past ~1e19 (VMD's float
  radius of gyration overflows).
- CPP-MDANCE's Tcl binding looks for its options among every argument,
  from objv[0]: it makes the text of the coordinates' list (~19 bytes a
  number; Tcl 8.6 panics past 2 GB and VMD aborts) and Tcl keeps ~120 bytes
  a number of it until VMD quits (~180 at the call's peak). The text is the
  CSV's less a byte (Job::_library_fits). A test that builds a large list
  keeps it inside a procedure: VMD's console makes the text of every
  top-level command's result. The text stays with the list's object: a
  job's calls are given one (Job::_call's lib_rows; a new list at every k,
  each read again from VMD, tripled a scan's time). Never change it, nor
  make a text of anything that holds it.
- A progress throttle that drops a message can drop the last one before a
  call that blocks VMD (the library's): the window then shows a stale step
  through the whole call. GUI::_progress throttles only the counts of one
  step (its text but for its numbers); a new step is shown at once.
- A click during a call that blocks VMD is read when the job next yields: a
  job that ended right after its library call (PRIME, a pick, a scan's last
  k) published, and the Cancel came to no job. Job::_call yields after the
  call too (20 ms), and checks Cancel then, the call failed or not.
- A /proc file of a process that is ending can fail at `read` ("no such
  process") after its `open` succeeded: catch both; a process killed with
  its launcher ends a moment after it.
- The preferences are core (prefs.tcl): Backend::from_prefs reads the
  backend chosen in Settings once, when the backend is first asked about,
  and configure sets its options over it. A script that wants none sets
  `Prefs::file ""` first (or configures the backend whole).
- `open … w` (and VMD's `writepdb`, `animate write`, `render`, Tk's
  `postscript -file`) follows a link at the name: a `<file>.tmp<pid>` that
  another user put in a shared folder made an export overwrite any file of
  the user's. A temporary is opened `{WRONLY CREAT EXCL}` (a link, live or
  dangling, is EEXIST). `file rename -force` onto a folder, or a link to
  one, moves the file into it; onto a link, replaces the link, but first
  makes what it points to writable (u+w through the link: Export::_commit
  deletes another user's link and renames without -force); and gives the
  umask's permissions (Export::_keep copies the old file's, where chmod is
  allowed: a gvfs share refuses it).
  `file normalize` leaves a link in the last component.
- A `puts` that fails (a full disk) can leave the `close` after it silent:
  check both (Export::_put). VMD's PDB writer does not check its last
  write (fclose): a file cut by a full disk ends without its END
  (Export::_whole); it stops at a coordinate, occupancy or beta past
  -999.999 to 9999.999, and `animate write` returns the frames written.
- A PDB read back by VMD (`mol new`) turns a residue past 9999, which its
  writer writes in hex (271a), into 271: structures are VMD's `writepdb` of
  each frame, joined, never a molecule made of a PDB.
- A job's loop that never yields holds Cancel until the job has ended
  (Job::cancel then finds none running) and its result is published: the
  measures between clusters froze VMD for minutes. A long loop in a job
  calls Coords::_breathe (in a coroutine: every 40 ms; error "cancelled")
  and says how far it is; the window shows the progress message its 250 ms
  throttle held back when they are up (else the last line stays up).
- A list of doubles costs ~235 bytes a value in Tcl, kept until VMD quits:
  k × k values for the thousands of clusters eQUAL makes at a small radius
  took gigabytes. The distances between clusters and their average-linkage
  tree are made for Measure::maxk (300) clusters or fewer (none above, in
  a result too: a session made before has them, left out before they are
  read); the plots read the same limit.
- Tk fills the pixels whose centre is in a rectangle (round(x1) to
  round(x2) − 1), a later item on top: a hit test of thin bars tests x + 0.5
  and keeps the last match (Plots::_bar_at).
- VMD tells no one when a colour changes (Graphics ▸ Colors, `color change
  rgb`): its RGB is read when used (Plots::vmd_colour; ccol keeps it for
  one draw), never kept, and the window compares it as it draws and when it
  has the focus again (GUI::_colours_check).
- What the window turns off while a job runs (`_busy`) another handler can
  turn on again (the algorithm chooser, the toolbar's Elbow): it asks
  `busy` too. A listener of the core (Viz::listen, Results::listen) hears
  the window's own changes: it must not undo a choice the core does not
  hold (the overlay's "frames" with none typed yet, or typed and not yet
  sent, at a job's end too: what changed since GUI::viz_seen only; what is
  typed in Setup while a job runs: GUI::setup0). A job tells its caller,
  then its listeners, in one timer event: the command (Job::run) publishes
  after `_job_changed end` and before any `after idle`.
- The MDANCE plugin's sessions keep no HELM starting clusters: after a
  trimming its zMatrix cannot be placed (Session::old_merges leaves it out,
  never the clustering); an mdance-cli before 4042c24 stopped by -eps added
  the refused merge as its last row, and left frames in no cluster when
  NANI left starting clusters empty, which it could (rows + k = pre-k is
  also one empty and the refused merge); a sweep's configuration has no
  inputParams (the result's `unrecorded`); HELM from a file has
  `initial-labels` and no pre-*; a zero-padded number (`nclusters`,
  `pre-k`, a percentage) was 10 to mdance-cli and 8 to its library.
  read_old counts the values on the text against the frames loaded before
  any list is made, the selection apart: VMD crashes on a selection of
  ~130 000 `or` terms, or deleting one of a ~700 000-value `index` list.
- VMD's file commands (`writepdb`, `render`, `mol new`, `animate write`)
  take a name's UTF-8 bytes, Tcl's (`open`, `file`, `glob`, `exec`) the
  system encoding's: iso8859-1 with `LANG=C` or no locale, where a name
  outside ASCII reaches VMD as another file (`writepdb` fails silently,
  `animate write` and `render` with no message). VMD writes only into the
  private folder, and is given the name whose UTF-8 bytes are the file's
  (Backend::vmd_name; tcl_name the other way: a session's molecule); a
  TMPDIR in which there is none (not UTF-8) is passed over, said if no
  private folder can be made. A test sets `encoding system iso8859-1` and
  makes names of UTF-8 bytes.
- A scan's record counts the clusters with frames (`nclusters`) and keeps a
  size for each of its clustering's k (`sizes`, empty ones too): the
  session check bounds the sizes by the clustering's k, not by nclusters (a
  session with an empty cluster in a record was refused as it was written).
- VMD's `vecdot`, `veclength2`, `vecnorm` and `vecmul` are Tcl procedures
  (vecdot 15 µs on 180 numbers, `veclength [vecsub]` 7): the silhouette's
  nearest other mean structure, with many clusters, is pruned by the
  triangle inequality (Measure::_near_other), which gains about 3× only: in
  hundreds of dimensions the distances are nearly all alike.
- `render list` has VMD's exporters too: POV3, Tachyon, VRML … write a
  scene for another program, Wavefront fails with no message (it wants a
  .obj), the `*Interactive` ones open a window that waits for a person. The
  3D figure takes snapshot and the `*Internal` ray tracers only
  (Figures::renderers).

## State

Version 1.0a1 (2026-09-30): the four algorithms, PRIME, iSIM, frame picks,
elbow scans and sweeps, runs, sessions (and the MDANCE plugin's imported),
exports, the 3D drawing, the window with ten plots, figures. Not carried
over from the MDANCE plugin: its narrated demo, its installer. Only VMD 2.1
on Linux has been tried. It took the MDANCE plugin's place in this
repository on 2026-10-09 (GitHub: diegoenry/vmd-mdance-plugin).

Hardening 2 (branch hardening-2, 2026-10-09): a second round of reviews,
fixed in thirteen groups, each kept by a suite of its own
(`tests/test_hardening2_<group>.tcl`): the sessions' security and limits
(fx_g1), the backend's process (fx_g2), what reaches the backend and the
library (fx_g3), the files and exports (fx_g4), the clustered frames and
their molecule (fx_g5), thousands of clusters (g6), what the numbers mean
(g7: HELM's starting clusters, the backend's placeholders, the scans), the
command, docs and decks (g8), the window during jobs (g9), DIVINE and what
the backend was built with (h1), the MDANCE plugin's sessions imported
(oi), the library mode (h3), the exports and the stated requirements (h4).
Merged, then the final review's fixes (test_hardening2's and test_gui's
last checks): a session whose scan has a record with an empty cluster
opens again, the library's refusal of DIVINE's CompSim splits is a scan's
*not run*, eQUAL's MSD only is the table's (the window, the request and the
parameters page follow), the 3D figure alone takes back the folders it
made, Setup follows a run or a session a script opens right after a job of
the command's, a sweep runs HELM from a label file and DIVINE's pair
anchors once a k (seeding none), the silhouette's nearest mean structure
is pruned (states3's 1462 clusters: 14 s of measures, 35 before), the
window's unused failure callback is gone, and the decks' pictures name no
folder.

The repository is the code only. The papers and the decks are kept beside
it, in folders git ignores (`manuscripts/`, `presentation/`), each its own
git repository; `manuscripts/README.md` says how they are made. A few
checks of test_hardening2_g7, g8 and h4 read them where they are, and skip
where they are not.
