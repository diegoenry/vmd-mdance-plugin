Changes
=======

1.0 alpha 1, as it grew
-----------------------

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
  load`` takes a k as a whole number; an eQUAL scan refuses ``-threshold``
  (each radius is it).
- Groups: a file with a header naming its columns (the plugin's own groups
  export) reads back; quoted names; a file of a group per frame reads in a
  fraction of a second, and only the clustered frames are kept.
- The map's sample is bounded by memory (2000 frames at most, fewer with
  many atoms) and VMD stays responsive while it is made.
- The window: the Export dialog offers the groups, make-up, map and
  profiles; the Figures dialog has a text size, and names the plots it left
  out; the toolbar's Elbow scans eQUAL by radius; the groups' controls are
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
  eQUAL's scan by radius; HELM's merges' heights (:doc:`scans`).
- Figures take a text size (``-text``).

**October 2026: VMDance.** The plugin took the MDANCE plugin's place in its
repository, after two rounds of review and hardening; renamed VMDance,
with a logo.

**September 2026: 1.0 alpha 1.** The plugin rewritten from scratch: the four
algorithms, PRIME, iSIM, frame picks, elbow scans and sweeps, runs,
sessions (the MDANCE plugin's imported), exports, the 3D drawing, the
window with ten plots, figures, and one command for all of it.
