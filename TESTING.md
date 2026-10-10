# VMDance — what to check by hand

The suites in `tests/` (`sh tests/run_all.sh`) check the clusterings against
CPP-MDANCE and MDANCE's published runs, the plugin's measures against direct
computations, the command, sessions, exports and the window's wiring. What
they cannot decide is below: go through it on a new platform, a new VMD, a
new CPP-MDANCE, or before a release.

## Platforms not tried yet

- [ ] Another VMD with Tcl/Tk 8.6 (VMD 2.0, a 1.9.4 built with Tcl 8.6):
      every text-mode suite; the window opens.
- [ ] A VMD with Tcl 8.5 (VMD 1.9.3, the Linux 1.9.4 alphas): `package
      require vmdance` fails at once, saying it needs Tcl 8.6.
- [ ] macOS (aqua): the *macOS native* theme; Command-key shortcuts; the
      menubar; `mdance-cli` found through `MDANCE_CLI` set in `~/.vmdrc`;
      Cancel of a script that runs `mdance-cli` without `exec` (no /proc:
      the processes are found with `ps`), and a job's end seen by `ps`.
- [ ] Windows: the *Native (Windows)* theme; `mdance-cli.exe`; Cancel
      (taskkill); figures with `gswin64c`.
- [ ] macOS, Windows: no `/proc/meminfo`, so the library's memory is not
      checked before a call (its 2 GB text still is): a large selection with
      the library.
- [ ] A path with spaces for the plugin, the backend, sessions and exports.
- [ ] A CPP-MDANCE built with DIVINE (`BUILD_DIVINE`): DIVINE offered,
      clustered, and the reference suite's DIVINE checks run (against the
      program, the library and MDANCE's labels; none skipped as missing).
- [ ] A CPP-MDANCE whose Tcl binding looks for its options after its
      positional arguments (it looks among every argument, and so makes the
      text of the coordinates' list: 93 MB and about a second of VMD's wait
      on protein G's 855 atoms, at a job's first call): a single library
      call (a clustering, PRIME, the similarity, a pick) then makes none;
      `Job::_library_fits`'s limits (the 2 GB text, 180 and 120 bytes a
      coordinate) measured again.
- [ ] Exports, a session and the preferences in a folder another user can
      write to (two accounts): a link of theirs at a file's name is
      replaced, not followed; a file of theirs this user cannot write is
      refused. On macOS and Windows: a file replaced keeps its permissions,
      a full disk is refused with the file's name. (test_hardening2 tries
      these on Linux, the other user by a uid made up, the full disk on a
      tmpfs.)

## Usability, in the window

- [ ] Cluster a trajectory of your own with each algorithm: the table, the
      Timeline and the 3D colouring agree on which frames are where.
- [ ] Play the trajectory with *Colour by cluster* on: the colour changes
      when the frame changes cluster; the Timeline's red line follows.
- [ ] Cancel a clustering of a long trajectory (the program): the window
      answers at once, the previous clustering stays.
- [ ] eQUAL at a small radius (thousands of clusters): the status says how
      far the measures are, the window answers, Cancel stops them; the
      Distances and Tree plots, and Export, say why there are none.
- [ ] The library: a clustering runs (VMD is busy meanwhile, and the line at
      the bottom says so, not the last frame read), and gives the
      program's clusters. On a selection of tens of millions of coordinates:
      refused, saying what it would need, or run within it (VMD keeps about
      120 bytes a coordinate afterwards).
- [ ] Settings: try another program, Cancel (nothing changes), then OK;
      restart VMD in text mode: `vmdance backend` names that program.
- [ ] Hover every plot: the line under the plots says what the pointer is
      on. Click: the selection shows in the table, every plot and the
      overlay.
- [ ] An elbow scan and a sweep of 50+ configurations: the tables, the
      hover panel, double-click to make one the clustering.
- [ ] Text size 8 and 24, window compact and large: nothing is cut off.
- [ ] Every theme on your platform.
- [ ] Figures open in a PDF viewer at the size asked; the 3D view's PNG.
- [ ] A session of the MDANCE plugin (`.mdance`) of your own imported.

## Science on systems only you have

- [ ] An unaligned trajectory clustered with and without *Fit to the first
      frame*: without it, frames of a drifting molecule separate by their
      position; with it, by their shape.
- [ ] eQUAL at a radius that leaves noise: the noise frames are the ones
      you expect far from every cluster.
- [ ] HELM from a label file of MDANCE's (its `labels_*.csv`), and PRIME on
      the result: the predicted frame is native-like.
- [ ] Compare a clustering with MDANCE's Python on the same aligned
      trajectory (NANI reproduces it, but where a stratified seed falls on a
      half; HELM does not: see README).
