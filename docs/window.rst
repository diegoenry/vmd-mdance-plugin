The window
==========

A toolbar on top; on the left a panel of five tabs (**Setup**, **Results**,
**Scans**, **Tools**, **3D**); on the right the plots, and the **Plot
options** panel, which can be shown instead of the row of options above
each plot. Both side panels can be hidden (the toolbar's first and last
buttons). The line at the bottom says what the window last did; the line
under the plots what the pointer is on. A left tab taller than the window
(a small screen, a large text size) scrolls, with the mouse wheel too.
While a job runs, what would start another, change the results or draw in
3D is off (in an Export or Figures dialog left open too), also for a job
started from the console. Setup stays open: what is changed in it while a
clustering runs is kept for the next one, and the line at the bottom says
so; left unchanged, it shows the settings of the clustering shown, also
when a script chooses a run or opens a session right after a job.

The toolbar
-----------

The left panel · open and save a session · export results and create
figures · **Cluster**, **Elbow scan** and **Cancel**, with the ring of the
running job's progress · the ten plots · colour by cluster, every
representative, go to the selected cluster's representative, render the 3D
view · Settings and the quick guide · the plot options.

Setup
-----

**What to cluster**: the molecule (the list follows VMD; ↻ reads it again
after frames were added to one); the atoms, in VMD's selection language,
with a menu of common ones and the number of atoms they match (a selection
whose atoms can change with the frame — ``within``, ``nearest``, ``x``,
``user`` …, or a macro of them — is
refused: a clustering compares the same atoms in every frame; a value in
quotes, ``chain "x"``, is a value); the frames
(all, or a range, -1 being the last) and every n-th, with the number of
frames they give; **Fit to the first frame on** a selection, which
superposes every frame on the first clustered one before clustering (on the
values: VMD's coordinates are not moved).

**Algorithm**: KMeans NANI, DIVINE, HELM or eQUAL, with what it does; a
note names the algorithms the backend was built without (asked again as the
chooser opens: a program rebuilt meanwhile), and says when the library
clusters (VMD then waits for each clustering, and the line at the bottom
says so through it), and that *Automatic* took it, finding no program.

**Parameters**: the chosen algorithm's (:doc:`parameters`); the others keep
what was typed in them. Fields that do not apply are greyed: HELM's trim
values without *Trim first*, its first clustering with a label file,
DIVINE's seeding with anchors other than NANI, its smallest share with NANI
(CPP-MDANCE's NANI splits do not use it) and its Refine (always:
:doc:`algorithms`), eQUAL's minimum size and similarity with their options
off, a seeding share that the seeding does not use. **Metric** is the mean
square deviation unless Settings unlock the others (DIVINE's and eQUAL's
always: the field says why).
**Defaults** puts the algorithm's back.

**Cluster** checks the request first: an error names the option and what
to change (:doc:`algorithms`), and nothing runs.

Results
-------

**Run**: every clustering is kept (the last 25); choose one to see it
again — the Setup tab shows its settings. ▾ renames or deletes it, or
clears every run, scan and pick. Under it, the clustering in words.

The **table of clusters**: its number (the row in its colour), its frames,
their share, the mean square deviation within it (the backend's), the mean
RMSD² of its frames from its representative, and the representative's frame.
Click a heading to sort. Selecting rows selects clusters: every plot draws
them on top (the others paler), and **Overlay in 3D** draws their frames
nearest their representative. Double-click: go to the representative.
Right-click: more. Under the table, the selection in words: frames, share,
representative, mean silhouette, visits and residence.

Scans
-----

**Elbow**: the Setup's algorithm and parameters at every k from … to …
every …; the Elbow plot shows it. **Sweep**: every combination of the
algorithms (KMeans NANI, DIVINE, HELM), the range of k, the metrics and the
seedings (HELM's: its first clustering's; HELM from a label file and
DIVINE's pair anchors once, using none), with the number of
configurations; its table (sort by a heading; the best Calinski–Harabasz
green, the best Davies–Bouldin blue, failures red) and the Sweep plot.
**Make it the clustering** (or a double-click) publishes a configuration as
a run. :doc:`scans` says more.

Tools
-----

**PRIME**: the native-like frame of the clusters, with its similarity
index, trim and weighting; the table of its four predictions and three
medoid baselines (double-click: go to the frame). **Similarity (iSIM)**:
MDANCE's extended similarity of all frames, and of each cluster (the
Compactness plot shows them). **Pick frames**: the most diverse, the
outliers, a representative sample, the medoid or the outlier of the Setup's
frames, without clustering; the list (double-click: go to the frame, on
their molecule), **Save…** as PDB or DCD, **In 3D**. :doc:`tools` says
more.

3D
--

:doc:`threed`: colour by cluster, every representative, the overlay, the
picked frames, their style, atoms and material, the user field, and the key
of the clusters' colours.

Settings
--------

**Backend**: automatic, the program or the library, and which program and
library (… browses); what is in use and what it was built with (a program
that did not answer within 3 s: not known, every algorithm offered);
*Detect again*. A backend chosen there is tried, not applied: the dialog
says what it gives "On OK", a job started meanwhile runs on the one in
use, and Cancel keeps that one; OK while a job runs says to wait for its
end. **Clustering**: unlock the metrics. **Appearance**: the text size
(8–24 pt), the window size, the theme (automatic, macOS native where it
exists, flat, VMD's own). They are kept in ``~/.vmdance.prefs``, which is
read as data; the command reads the backend chosen there too.

Keys
----

Ctrl (⌘ on macOS) + O open, S save (Shift: as), E export, P figures, R
cluster, W close, 1–9 the plots, Shift+L and Shift+O the side panels.
