Tests
=====

The suites run inside VMD (and the core's in plain ``tclsh`` too), and say
``PASS``, ``FAIL`` or ``SKIP`` for each check, then ``RESULT checks=…
fails=… skips=…``:

.. code-block:: sh

   cd vmd-mdance-plugin
   sh tests/run_all.sh                 # every suite
   NOGUI=1 sh tests/run_all.sh         # without the window

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Suite
     - Checks
   * - ``test_core``
     - the JSON reader (malformed, truncated, deep, long), the parameters and
       their checks (numbers that ``expr`` would misread, NANI's seeds,
       HELM's and DIVINE's combinations), the backend's arguments, label
       files in their dialects, a result's checks, runs and the selection,
       sessions as data (damaged and hostile files), the average linkage
       against a search of every pair, HELM's merges renumbered (trimmed
       starting clusters, numbers that are both a merge's and a starting
       cluster's)
   * - ``test_jobs``
     - with the fake backend: requests refused and why, frame subsets, the
       backend's output checked (truncated, too many labels, failures), NaN
       scores, noise, HELM's merges and label files, Cancel (also of a
       backend that ignores TERM, and the job after), one job at a time,
       elbow scans and sweeps (failed and refused values), PRIME, the
       similarity and picks, the capability probe (and a backend changed
       whole or not at all, never under a running job), the coordinates kept
       and the fit
   * - ``test_results``
     - the command's questions, the selection, the runs, the 3D drawing (the
       user's representations untouched), exports and structures
   * - ``test_session``
     - sessions with their molecules found, loaded or none; damaged and
       hostile files; atomic saves; the MDANCE plugin's sessions imported
       (written by it with ``mdance-cli``: ``tests/fixtures/make_old_sessions.tcl``);
       the preferences read as data
   * - ``test_reference``
     - with the real backend: the plugin's labels are the program's on the
       same coordinates (KMeans NANI, HELM, eQUAL; DIVINE with every
       parameter at another value once, when the build has it), the
       library's are the program's, the measures are direct computations',
       MDANCE's own labels of 3ptb (``tests/fixtures/mdance_3ptb.txt``, made
       by ``make_mdance_3ptb.tcl``) and MDANCE's published runs are
       reproduced on the atoms they cluster, the Cα (the tau peptide:
       NANI's populations with three seedings, the scores at five values of
       k, HELM's populations; protein G), exactly; HELM's tree after
       trimming
   * - ``test_hardening``
     - what the reviews of files, inputs, the lifecycle and the science
       found, kept from coming back: sessions the plugin wrote reopen; a
       name like ``|cmd`` is a file's; a FIFO, a compressed bomb, a huge
       ``nClusters``, numbers beyond a double; frames deleted under a
       clustering (goto, the drawing, the user field and the structures
       refused) or added after it (all still work); a selection text on
       other atoms; a program that waits (offered, and cancelled) or prints
       without end (refused); the program deleted during a scan; a job
       started as another ends; the package loaded twice; the folders of
       dead VMDs; one cluster's scores; a lone frame's silhouette; the
       plugin's own label files of other frames
   * - ``test_hardening2``
     - what the second round of reviews found in the sessions (security and
       limits), kept from coming back: a shared session's molecule record no
       longer hands a file and a type to VMD unchecked (a Babel converter or
       the AMBER readers would run a shell command; a FIFO or device would
       hang Open); its lists are counted before they are made (a 40 KB file
       would otherwise allocate gigabytes) and ``nclusters``, the selection
       and the picks are bounded; a save that would be too large to read
       back is refused and the file left as it was, naming the runs to
       delete; strings a user typed or a file holds (a molecule named
       ``NaN``, ``010`` or ``1e10``, an import label, overlay frames) are
       never rewritten or run through ``expr``; and the backend's process:
       the private folder under a uid with no passwd entry, named for the
       machine and PID namespace (another namespace's VMD sharing the
       ``TMPDIR`` neither takes nor removes it; a link in its place is not
       used), a launcher that logs (Cancel answers), a launcher that does
       not ``exec`` (Cancel, VMD quitting and the probe stop its program),
       a program slow to start (offered, with a note), one that prints
       without pause or a line without its end (VMD's events still run,
       no line held whole), one the probe found is not ``mdance-cli`` (a
       pick refuses it too), ``mdance-cli`` ended from outside during a scan
       (the scan stops and the one there is kept; a crash stays one failed
       record), the progress line's numbers; and what reaches the backend:
       coordinates that are not numbers (a NaN, an infinity, with a fit,
       either backend: refused naming the VMD frame; a row the program names
       made a frame), numbers beyond a C float's range (every real
       parameter; ``-eps -0.99999999``, which the backend reads as -1;
       HELM's ``-min-samples`` that overflows an int; a session's runs made
       with them still open), a metric other than MSD with the diversity
       selection (the seedings, eQUAL with any seeds, the pick; a sweep keeps it as
       not run; a frame picked twice), the picks' counts (a whole
       percentage; a share that holds no frame), the backend chosen in
       Settings in a script (read once, as values, nothing loaded; a FIFO
       in its place), ``backend try``, the library's limits (its text past
       2 GB, before and after the frames are read; its memory, with what an
       earlier call left), a folder that cannot take the coordinates; and
       the files: links put at the names temporaries had (exports, a
       session, the preferences write through none), a DCD's unit cells
       (triclinic, hexagonal, none), a PDB as VMD writes it (residues past
       9999, each frame's cell, no molecule made), a frame a PDB cannot
       hold (refused, the file there kept), the PDB beside a DCD that
       fails (the DCD kept), a full disk (a tmpfs of the user's namespace:
       said of the file; VMD's writer cut at its last write, caught), a
       folder or a link to one in a file's place, read-only files, 0600
       and 0664 kept, links of the user's followed and another's replaced,
       a selection over two lines and a name with a line break in the
       ``#`` lines, an export checked whole before it writes (PRIME of
       another run, a bad ``-sel``, picks or the molecule gone) and none of
       its files changed by a failure, its folder made, the sweep's fixed
       parameters and every scan's backend in their tables; and the
       clustered frames and their molecule: a session opened onto another
       trajectory of the same file names, or a file written over (said, its
       frames refused), its files found by their names in full or beside the
       session, the PDB's own frame deleted again (the user's molecule left
       as it is), a trajectory aligned before it was clustered (taken); frames
       moved in place then added (still the clustered ones; a rigid body's
       not); ``frame`` refused as ``goto`` is; a drawing whose frames
       changed withdrawn, the answer kept for a count of frames not taken
       later; the picks on their own molecule (drawn, gone to, saved),
       refused once its frames moved, a session's too; a selection's atoms
       kept (``beta > 0`` changed); the kept rows of a deleted molecule; an
       import onto the molecule whose coordinates give its cluster MSDs;
       atoms 1009 apart swapped or a frame mirrored (seen), and the digests
       of sessions made before; and what the final review of the merged
       branch found: a session holding a scan's record with an empty
       cluster opens, and saved again opens again (one saved before too);
       the library's refusal of DIVINE's CompSim splits a scan's *not run*
       (a sweep where none ran refused, the one there kept); eQUAL's MSD in
       the table, and on the parameters page; a sweep's HELM from a label
       file and DIVINE's pair anchors run once at each k (seeding none, not
       a seeding never used); the silhouette's nearest other mean structure
       looked for among those the triangle inequality leaves, the same as
       against every one
   * - ``test_hardening2_fx_g1``
     - what the review of the sessions' fixes found: values counted whatever
       separates them (a vertical tab, a form feed, an escape), a scan's
       records and the picks' rows counted before they are made; a save
       refused naming what to drop (the runs, and the scans and picks:
       ``elbow clear``, ``sweep clear``, ``pick clear``) and how to raise
       the limits; the shell's characters refused only for the readers that
       give a name to a shell; a FIFO or a device beside a molecule's file,
       or in a DESRES trajectory's folders; the MDANCE plugin's
       representatives and cluster MSDs read as written
   * - ``test_hardening2_fx_g2``
     - what the review of the backend's process found: Cancel of a program
       that ignores TERM where ``/proc`` is another PID namespace's (``ps``
       not asked); the machine in the private folder's name read without the
       resolver (hosts whose names are aliases of localhost); ``configure``
       clearing the probe's notes (in namespaces of the user's own, skipped
       where they cannot be made)
   * - ``test_hardening2_fx_g3``
     - what the review of what reaches the backend found: eQUAL refused with
       any index but MSD, whatever its seeds; an imported HELM run's summary;
       a representative sample's share that holds no frame (one frame, as the
       backend picks); a stored program ``~user/…`` of a user that does not
       exist; HELM's ``-eps`` that is -1 as a C float
   * - ``test_hardening2_fx_g4``
     - what the review of the files and exports found: a link of another
       user's at an output name leaves its target's permissions; an export
       of trajectories deletes the clusters an earlier one left under its
       name; a PDB's advice for a number it cannot hold; the folders an
       export made taken back when it fails; files replaced where ``chmod``
       is refused (a child VMD with a shim, skipped without a C compiler);
       the window's Save picks, with Tk stubbed
   * - ``test_hardening2_fx_g5``
     - what the review of the clustered frames and their molecule found:
       frames deleted back to a count seen while a trajectory loaded (the
       answer kept, a job's trust, the picks); two replicas of the same
       names, each run on its own molecule; a session's molecule after a
       ``cd``; picks whose VMD frames are not their rows', or made before
       they kept a digest; an import past a molecule whose frames cannot be
       read; the PDB's own frame read again (delete it, not cluster again)
   * - ``test_hardening2_g6``
     - thousands of clusters (eQUAL at a small radius): the measures yield,
       say how far they are and stop on Cancel; the distances between the
       clusters and their tree made for 300 clusters or fewer, each pair
       once; an export's defaults without them and the transitions; one lag
       of the transitions kept; a selection change making the overlay alone;
       sessions made before with more distances; the console's progress of
       ``elbow load``, ``sweep load`` and ``session import``
   * - ``test_hardening2_g7``
     - what the numbers mean: HELM's starting clusters counted as the
       backend gets them, and what ``-trim-val`` left; a cluster without
       frames with no MSD or iSIM; HELM's scores with a trim those of its
       clustered frames, a scan's together; no scores when every cluster is
       a frame alone; eQUAL's ``-min-samples`` read with ``-reject-lowd``
       only; what a scan reads, and its refusals naming ``-ks``; a sweep
       where nothing ran refused; a seeding in a sweep's ``-params`` refused;
       the backend's placeholders in sessions made before (the real backend
       on 3ptb, and a constructed three-state trajectory where
       ``VMDANCE_CONSTRUCTED`` names its folder)
   * - ``test_hardening2_g8``
     - the command, the docs and the decks: an option, or a name in
       ``-options`` or ``-params``, given twice refused; draw's ``-sel``
       checked, and what is drawn otherwise than asked said; quoted values
       and macros in a selection; numbers read as a person writes them
       (``010``); the parameters page the generator's; README's and the
       quick start's scripts on MDANCE's data (``MDANCE_DATA``, with the
       real ``mdance-cli``); figures in text mode. A few checks of g7, g8
       and h4 read files kept outside the repository, and skip without
       them
   * - ``test_hardening2_g9``
     - what the window's fixes of the second round of reviews ask of the
       core: the range of k as the window's Sweep and Elbow fields ask it
       (counted before the values are made, the command's answer; ten
       digits refused, saying the range), a job's caller called once the job
       no longer runs, the command's clustering published before the event
       loop runs again, and a session's overlay of "frames" with none typed
       drawn without the window (no overlay) (the window's own checks are
       ``test_gui``'s)
   * - ``test_hardening2_h1``
     - DIVINE, and what the backend was built with: DIVINE's metric (MSD),
       its ``-threshold`` (the share each side of a split keeps), ``-end-mode
       points``, its first split's seeds and a later split's failure, Refine
       off, its tree said not to be its splits, the library spared the
       CompSim splits that crash it (a scan's k kept as not run); a program rebuilt at the same path asked
       again (DIVINE against the real program, the library and MDANCE is
       ``test_reference``'s, on a build with it)
   * - ``test_hardening2_oi``
     - the import of the MDANCE plugin's sessions: counted before its lists
       are made, a long selection apart; a HELM run started from a label
       file; HELM's merges that cannot be placed left out; a molecule with
       frames added; zero-padded and signed numbers as the plugin read them;
       a configuration of its sweep (its parameters not recorded); fixtures
       written by the MDANCE plugin itself
   * - ``test_hardening2_h3``
     - the library mode: a job's calls given one list, read once (an elbow,
       HELM's, a sweep), and its text made once; the step said before each
       call, and a Cancel pressed during a call taken when it returns (the
       real library and program; skipped without them)
   * - ``test_hardening2_h4``
     - the exports and the stated requirements: structures into a folder
       that cannot be written (said, file and reason); with ``LANG=C``, a
       ``TMPDIR`` whose name is not ASCII (kept: VMD is given its own name
       of the files there), one whose name is not UTF-8 (passed over, and
       said where no other folder can be made), a destination outside ASCII
       (PDB, DCD with its PDB) and a session's molecule outside ASCII
       (loaded); the distances, tree and clusters tables saying RMSD² where
       it is one, and the number it names; no document or deck claiming VMD
       1.9.4 or later, and a Tcl 8.5 told what the plugin needs
   * - ``test_gui``
     - windowed: the window, clustering in the background, Cancel, refused
       requests, the table and the selection, every plot (with every kind of
       result, and every setting; every frame noise; more clusters than the
       matrices are drawn for), hovering and clicking, what is disabled while
       a job runs (also one of the command's), the scans, the tools, 3D,
       sessions, export (an item ticked when the dialog opened that the run
       no longer has: refused before Replace is asked), figures (no link at
       a temporary's old name written through; a new folder made; ``-3d``
       with a renderer that writes no image refused before any figure, a
       render that fails said and its temporary removed, and the folders
       made for the 3D view alone taken back), eQUAL's metric MSD with the
       metrics unlocked (said why, and sent), the
       picks saved as a DCD (asked before the PDB of its name is replaced),
       the picks' list and **In 3D** on their molecule, frames deleted under
       the drawing and the picks (withdrawn, refused, said), the cursor while
       frames are added (no frame read again), the Sweep's and the Elbow's k
       fields at 3000000 (counted, not made, in time), the overlay's
       "frames" chosen before they are typed (no overlay drawn), frames
       typed and not yet sent through a job's end, the timeline's distances
       under the pointer, VMD's colours changed (the plots, the table, the
       key and a figure follow), one draw per clustering, Setup changed
       while a clustering runs (kept, said; the command's too, and in a
       window opened during one; left alone, it follows a run chosen or a
       session opened by a script right after a job of the command's), the
       toolbar's Elbow and the open Export and
       Figures dialogs during a job, the window destroyed and opened again
       during its own job,
       settings (refused whole; a backend tried
       is not applied before OK, a job meanwhile runs on the one in use, OK
       during a job waits), themes, text sizes and back, a short window (the
       pages scroll), a deleted molecule

End to end (``tests/e2e/run_e2e.sh``, about 40 s), each phase in a new VMD
with the real backend: a session of work with the command on the
tau peptide and 3ptb, every export checked against the command's answers
and VMD's coordinates, the library against the program, the session saved;
that session opened again (every answer the same; a molecule loaded with
other frames refused for the questions and the 3D views); the window
driven as a user would (Setup, scans, tools, every plot hovered, figures,
exports, the 3D view rendered, the library chosen in Settings); and its
session opened from the window with no molecule loaded. The phases write
``timings.txt``; ``tests/profile/profile_core.tcl`` and
``profile_gui.tcl`` break the time down by procedure.

The fake backend (``tests/fake_mdance_cli``, Python 3) is deterministic and
has hooks for what a real one does rarely: ``MDANCE_FAKE_FAIL``,
``MDANCE_FAKE_FAIL_K`` (fail at one k), ``MDANCE_FAKE_SLEEP`` (run for that
long, printing progress), ``MDANCE_FAKE_IGNORE_TERM``,
``MDANCE_FAKE_TRUNCATE`` (half a JSON file), ``MDANCE_FAKE_EXTRA_LABELS``,
``MDANCE_FAKE_NO_DIVINE``, ``MDANCE_FAKE_FLOOD`` (lines printed without
pause), ``MDANCE_FAKE_NOLINE`` (bytes without a newline).

The reference suite needs a CPP-MDANCE build (``MDANCE_CLI``, ``MDANCE_LIB``,
else the build beside the plugin's folder), MDANCE's reference runs
(``MDANCE_REF_RUNS``) and the shared test systems (``VMDANCE_SYSTEMS``);
what is missing is skipped, and says so. Some are skipped on purpose:
DIVINE's, when the build has none, and what CPP-MDANCE does not reproduce of
MDANCE — a stratified seed's position on a half (rounded away from zero,
MDANCE's to even), DIVINE's smallest share (rounded, MDANCE's truncated):
the numbers are printed, not asserted, and the plugin's labels are checked
against the program's apart.
