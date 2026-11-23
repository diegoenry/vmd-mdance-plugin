Changes
=======

1.0 alpha 1, as it grew
-----------------------

**23 November 2026: the pages online.**

- A workflow builds these pages and publishes them on GitHub Pages
  (diegoenry.github.io/vmd-mdance-plugin).
- :doc:`install` and the README: once peer reviewed, VMDance and
  CPP-MDANCE will be distributed with VMD 2.x. Until then, CPP-MDANCE is
  built, and the plugin's path added to ``~/.vmdrc`` (a Tcl/Tk plugin:
  nothing to build).

**23 November 2026: simpler pages, a new logo.**

- Every page but the parameters (made from the plugin's table) and this
  changelog: shorter sentences, paragraphs broken up, lists where there
  were enumerations. Nothing said was dropped.
- *Coming from the MDANCE plugin* removed.
- :doc:`install`: a *Requirements* section, for Linux, macOS and Windows
  (Windows: a MinGW-w64 GCC, its runtime first on the ``PATH``, Tcl's
  headers from MSYS2 for the library, Ghostscript from Artifex's
  installer).
- The logo: VMDance with V, M and D in the colours of VMD's own title
  (red, green, blue) and "ance" in black; the mark and the window's icon,
  VMD in those colours on a black tile. ``make_logo.py`` draws its PNGs
  with Pillow (no cairo).

**23 November 2026: the README an overview.**

- The README says what the plugin does and how to install it, and points
  to these pages. Its script is the command page's (*A whole script*),
  its notes and limits a page of their own (:doc:`limits`), its source
  layout :doc:`internals`'s, its credits :doc:`citing`'s.
- The documentation reviewed against the code: what the 13 November
  review changed (k 6, HELM's ``Intra``, eQual's radius 2, DIVINE's stop,
  the window sizes, the fit), the tutorial's steps (back to the k 3 run
  before the groups; the script keeps its work before eQual's scan replaces
  the elbow), field and menu names, the tests' table, the source layout.
- The documentation's pictures taken again on the tau peptide's atoms
  (``resid 3 to 12 and name CA N C O H``); ``capture.tcl`` runs on Windows
  too (``capture_win.ps1``).
- Figures: Ghostscript is found where its Windows installer puts it
  (``Program Files\gs``), not only on the ``PATH``.

**22 November 2026: the review of 13 November.**

- Defaults: k is 6 for KMeans NANI, DIVINE and HELM (10, 3 and 10 before);
  HELM merges ``Intra`` (``Inter`` before; both and ``Half`` still
  offered); eQual's radius is 2 (it had none, and had to be typed).
  **Suggest a radius** replaces the default, and keeps a radius typed.
- DIVINE: the window has no *Stop when*: it stops at k.
  ``-end-mode points`` stays the command's (``Algo::window_hides``).
- The name is written eQual, as MDANCE writes it (eQUAL before), in the
  window, the messages, the docs and the backend's progress lines.
- Settings ▸ window size: medium and large are wider than compact by 200
  and 400 pixels (at 12 pt) beyond what the panels need. Where the panels
  needed more than the sizes' widths, the three were as wide as the
  panels, and only their heights differed.
- The fit (*Fit to the first frame*) is the plugin's own, exact (Horn's
  quaternion: Newton's method on its polynomial, Jacobi where its root is
  nearly double). VMD's ``measure fit`` stopped after 1000 iterations
  (*Matrix: Warning: no convergence*) with a rotation up to 11% above the
  least RMSD on the tests' fixtures; on the tau peptide within 0.0001 Å.
- An empty number is "needed", whatever its default (eQual's Radius
  cleared in the window says so).

**22 November 2026: long selections, and the tests on Windows.**

- VMD crashes freeing a selection of about 100 000 single values (VMD 2.0
  on Windows: between 100 000 and 120 000; Linux: about 700 000), and
  adding one as a representation; a range ``a to b`` is one value. The
  plugin hands VMD every text with its lists of whole numbers after
  ``index``, ``serial`` and ``residue`` written as ranges (``all or index 0
  0 …`` is ``all or index 0``); its own list of scattered atoms still too
  long is named, ``name CA and index 4 to 99990``, where that selects
  exactly them; a text still too long is refused, saying what to select
  instead. Importing an MDANCE plugin session whose selection is a long
  index list crashed VMD on Windows.
- 3D: the frames of an overlay are written as ranges (``0:3 10:2:14``), as
  the Trajectory tab takes them.
- Tests: the text-mode suites run on Windows: the fake backend through
  ``tests/fake_mdance_cli.bat``, the suites read as UTF-8.

**9 November 2026: a review of its use, its layout and its plots.**

- Setup: a note under *Fit to the first frame* — with a fit, the atoms it
  is made on; without one, how far a sample of the frames is from the first
  as they are and once fitted, a warning when they do not look superposed
  (a fit halves the distance and takes an ångström off it). The command
  notes the same when it clusters such frames unfitted, and ``vmdance
  alignment`` returns the numbers. The fit stays off by default. A fit
  ticked whose atoms the molecule lacks is put on the clustered atoms.
- Setup's frames: a run of every frame shows *All frames* (it turned into a
  range after a scan's k was made the clustering, or a session opened, and
  the range was kept for the next molecule, clustering part of it);
  choosing another molecule puts a range back to all frames.
- eQual: under the radius, the RMSD it stands for (√(2 × radius));
  *Suggest a radius*, and *Suggest* in Scans ▸ Elbow, propose a radius and
  a scan's range from the distances between about 150 frames (``vmdance
  radii``). The Scans box shows the k row or the radius row by the
  algorithm; *Stability* is KMeans NANI's only.
- Results: the summary says *fitted on …* or *not fitted*, and names the
  clusters without frames; a run's name has *(n empty)* and *, fitted*.
  The table's headings have their units, and its rows their clusters'
  colours (the row colours of the three tables are now drawn: the sweep's
  best rows and PRIME's predictions too). **Number its clusters by size**
  makes a new run (``vmdance renumber``); the backend's numbers stay with
  the run it is made of.
- Groups: **Halves** and **Blocks…** (``vmdance groups -blocks n``); under
  the box, how unlike the two most different groups are — the
  Jensen–Shannon divergence of their shares of the clusters, and the
  cluster whose share differs most (``vmdance groups compare``). The
  profiles' reference is chosen by name. A new clustering of the same
  frames and atoms keeps the map.
- Timeline: with more frames than pixels the lanes are shaded by each
  cluster's share of the frames under a pixel (they looked solid); two new
  views, each cluster's share window by window and its share so far, with
  the frame by which every cluster has been seen (``vmdance timeline``);
  the distances as a dot a frame and their running median above 400
  frames.
- Silhouette: a second kind, from every frame, of the squared distances
  (the classic one, scikit-learn's ``silhouette_samples`` with
  ``metric="sqeuclidean"``), beside the one from the clusters' mean
  structures, which stays the default (``vmdance silhouette -kind``; both
  in the export). The axis starts at the lowest value.
- Elbow: the stability (eQual's clusters found) in a strip of its own
  under the scores, with a scale; rings on Davies–Bouldin's lowest value
  and its sharpest dip (MDANCE's two criteria) and on Calinski–Harabasz's
  highest, and a line of words (``vmdance elbow suggest``); a third choice
  of *Scores*, the variance the clusters explain (SSR/SST). A scan
  cancelled after two values or more keeps them.
- Other plots: the Residence's longest stay written beside the mean, no
  longer a whisker; the Tree's heights view circles a jump only when it
  stands out, and says when none does; its leaf labels upright when they
  do not fit side by side; the Map to one scale on both axes, the
  representatives ringed, the frames in a mixed order, the dots sized to
  the plot; the Make-up's frames above each bar in the shares view too;
  the Profiles of more than 12 clusters in colour for the selected ones
  (or the 8 largest) and grey for the others, a curve named under the
  pointer and selected by a click; Compactness to three significant
  digits; colours past the 29 clusters' (the 10 groups') lighter, then
  darker.
- All plots: *Distances as* (squared, Å², or lengths, Å: the table too)
  and *Time per frame* (``0.1 ns``: the Timeline and the Residence read in
  time). A plot's tab says its name and what it shows under the pointer.
- Files: structures written as PDB are models (``MODEL`` … ``ENDMDL``,
  each named by a ``REMARK``, one ``END``), which VMD reads back as
  frames.
- Figures: ``-size column|two-columns|slide|screen``; ``-width`` and
  ``-height`` with a unit (``85mm``); ``-text`` 6 to 36; a figure 160
  points (56 mm) at least each way; ``-cursor`` 0 by default (no
  current-frame line unless asked); no figure of a plot that has only a
  message to show; the Timeline's lanes as shapes, sharp at any
  resolution.
- The command: ``vmdance help ?subcommand?``, ``alignment``, ``radii``,
  ``timeline``, ``renumber``, ``elbow suggest``, ``groups -blocks``,
  ``groups compare``, ``silhouette -kind``. In the window, a message that
  names an option says which field it is.
- 3D: an overlay of several frames, and the picked frames, drew only the
  first frame of each list. VMD reads the frames of a representation
  separated by spaces, as its Trajectory tab shows them; the plugin gave it
  commas, which VMD takes without a word and stops reading at. Every frame
  is drawn now.
- VMD 2's main window has no Extensions menu: the plugin is under
  **Analysis ▸ VMDance** there, and the docs say so.
- The tutorial reads the tau peptide's scan both ways: Davies–Bouldin's
  sharpest dip (k 6, MDANCE's second criterion) and the k the seedings
  agree on (k 2 and 3), and says why it goes on with k 3.
- Tests: ``test_ux`` (the core's and the command's part, the real backend)
  and ``test_ux_gui`` (the window's).

**November 2026: DIVINE, and a review.**

- DIVINE as CPP-MDANCE's main has it since its PR #52 (1 October 2026):
  the smallest share applies to every split, NANI's too, cut to a whole
  number of frames as MDANCE cuts it; ``-end-mode points`` takes NANI's
  anchors; ``-refine`` is on by default, as MDANCE's, and refines the pair
  anchors' splits. The one crash left in CPP-MDANCE's DIVINE (refining an
  OutlierPair split of a cluster of identical frames) is refused where
  DIVINE could come to it, the frames compared as the backend reads them
  (:doc:`algorithms`).
- ``vmdance tree`` gives each merge's height (``heights``), and the tree
  export a column of them, as the Tree plot's heights view draws them.
- The stability scan says how many seedings each k compared; ``elbow
  load`` takes a k as a whole number; an eQual scan refuses ``-threshold``
  (each radius is it).
- Groups: a file with a header naming its columns (the plugin's own groups
  export) reads back; quoted names; a file of a group per frame reads in a
  fraction of a second, and only the clustered frames are kept.
- The map's sample is bounded by memory (2000 frames at most, fewer with
  many atoms) and VMD stays responsive while it is made.
- The window: the Export dialog offers the groups, make-up, map and
  profiles; the Figures dialog has a text size, and names the plots it left
  out; the toolbar's Elbow scans eQual by radius; the groups' controls are
  off while a job runs; hints for the Tree's heights view and a scan by
  radius.
- Fixed: HELM's merges' heights after a trim (all blank); the Make-up and
  Profiles plots drawing the groups and profiles of before; profiles kept
  when the groups kept their names but not their frames; the heights view's
  k line outside the plot.
- Tests: every text-mode suite runs through ``tests/strict.tcl``, which
  makes an error at a suite's top level a failure; the end-to-end phases
  cover the groups, the map, the profiles, the scans' stability and
  radius, HELM's heights and DIVINE.

**October 2026: groups, map and profiles.**

- Each frame's group (the replica, condition or method it came from), with
  a colour per name; the clusters' make-up by group; the map (the frames
  on two principal components); the profiles (each group's and cluster's
  RMSF) — three new plots, 13 in all (:doc:`groups`).
- The elbow scan's stability (NANI's four deterministic seedings compared);
  eQual's scan by radius; HELM's merges' heights (:doc:`scans`).
- Figures take a text size (``-text``).

**October 2026: VMDance.** The plugin took the MDANCE plugin's place in its
repository, after two rounds of review and hardening; renamed VMDance,
with a logo.

**September 2026: 1.0 alpha 1.** The plugin rewritten from scratch: the four
algorithms, PRIME, iSIM, frame picks, elbow scans and sweeps, runs,
sessions (the MDANCE plugin's imported), exports, the 3D drawing, the
window with ten plots, figures, and one command for all of it.
