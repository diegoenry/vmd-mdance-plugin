Recipes
=======

Scripts for common jobs, with the ``vmdance`` command (:doc:`command`). They
run in VMD's console, or in text-mode VMD: ``vmd -dispdev text -e
script.tcl < /dev/null``.

Replicas or conditions in one molecule, as groups
--------------------------------------------------

Load each replica into the same molecule, and give its frames a group by
the frame numbers they took:

.. code-block:: tcl

   package require vmdance
   set m [mol new system.psf]
   set ranges {}
   foreach {name dcd} {wt wt.dcd mutant mutant.dcd ligand ligand.dcd} {
       set first [molinfo $m get numframes]
       mol addfile $dcd waitfor all molid $m
       lappend ranges $name "$first-[expr {[molinfo $m get numframes] - 1}]"
   }
   vmdance -mol $m -sel "name CA" -fit "name CA" -k 5
   vmdance groups -ranges $ranges
   vmdance makeup -by group           ;# each condition's frames by cluster
   vmdance map
   vmdance profiles

The clusters are of all the frames together: a cluster of one condition
only is a state the others did not reach (:doc:`groups`).

Is my run converged?
--------------------

Split one trajectory into blocks and see whether each visits the clusters
in the same shares:

.. code-block:: tcl

   vmdance groups -blocks 4           ;# part1 … part4, as equal as can be (2: first, second)
   vmdance makeup -by group           ;# each block's frames by cluster
   vmdance groups compare             ;# how unlike the blocks are, two by two
   vmdance timeline -windows 20       ;# each cluster's frames in 20 windows; first_seen

Shares that drift from block to block, or a cluster absent from the first
blocks, say the populations have not settled. ``groups compare`` puts it
in numbers: for every two blocks, the Jensen–Shannon divergence of their
shares of the clusters (0: the same; 0.69: no cluster in common) and the
cluster whose share differs most. ``timeline`` gives the clusters' frames
window by window, and the frame each cluster is first seen at: a cluster
first seen late is one the frames before it never reached.

Many trajectories, the same analysis
------------------------------------

The same settings for every system, each system's results in a folder of
its own, and how they were made written beside them:

.. code-block:: tcl

   package require vmdance
   set ::VMDance::Prefs::file ""                  ;# no preferences: the settings below
   vmdance backend -mode cli -cli /path/to/mdance-cli
   foreach dir [glob -directory systems -type d *] {
       set name [file tail $dir]
       set m [mol new [file join $dir system.pdb] waitfor all]
       mol addfile [file join $dir traj.dcd] waitfor all molid $m
       file mkdir results/$name
       # the scan first: its records, with the stability, to choose k from
       vmdance elbow -mol $m -sel "name CA" -fit "name CA" -from 2 -to 12 -stability 1 -quiet 1
       vmdance export results/$name -prefix $name -items {elbow}
       mol delete $m
   }

Then, with a k chosen for each system (a ``k.csv`` of ``system,k`` lines
kept with the results, so that the choice is part of the record):

.. code-block:: tcl

   foreach line [lrange [split [string trim [read [open k.csv]]] \n] 1 end] {
       lassign [split $line ,] name k
       set m [mol new systems/$name/system.pdb waitfor all]
       mol addfile systems/$name/traj.dcd waitfor all molid $m
       vmdance -mol $m -sel "name CA" -fit "name CA" -k $k -quiet 1
       vmdance export results/$name -prefix $name
       vmdance session save results/$name/$name.vmdance
       vmdance run clear
       mol delete $m
   }

Every table's header says the molecule, the atoms, the frames, the
algorithm and its parameters, and the backend.

Figures for a paper or a slide
------------------------------

``figures`` writes the plots as the window draws them, at a size and a text
size of their own (it needs Tk: VMD with its window, or text-mode VMD on a
display: ``Xvfb :1 &`` and ``DISPLAY=:1 vmd -dispdev win``):

.. code-block:: tcl

   # a column of a paper: 85 mm wide, 8-point text, at 600 dpi
   vmdance figures figs -plots {populations makeup} -size column -formats {pdf png} -dpi 600
   # the same column, another height (a length: points, or with mm, cm or in)
   vmdance figures figs -plots {timeline} -size column -height 60mm -prefix low
   # both columns (178 mm, 9-point text); a 16:9 slide (10 in wide, 16-point text)
   vmdance figures figs -plots {elbow} -size two-columns -prefix full
   vmdance figures figs -plots {elbow map} -size slide -prefix slide
   # a plot as one of its views, in ns and Å (the plot options' names)
   vmdance figures figs -plots {tree} -options {td_view heights}
   vmdance figures figs -plots {timeline} -options {tl_view shares plot_time "0.1 ns"}
   vmdance figures figs -plots {compactness distances} -options {plot_len a}

A figure is 160 to 6000 points (56 mm at least) each way, its text 6 to 36
points. The red line at VMD's current frame is left out (``-cursor 1``
draws it), and a plot that has nothing but a message to show gets no
figure.

The 3D view goes with ``vmdance figures figs -3d 1`` (VMD's renderer).

Reading the tables elsewhere
----------------------------

Every table is a CSV whose ``#`` lines say how it was made:

.. code-block:: python

   import pandas as pd
   labels = pd.read_csv("results/tau_labels.csv", comment="#")      # frame, cluster
   makeup = pd.read_csv("results/tau_makeup.csv", comment="#")      # cluster, group, frames, shares
   print(makeup.pivot(index="cluster", columns="group", values="frames"))

The clusters in VMD's 3D window
-------------------------------

Write every frame's cluster into VMD's per-frame *user* field, and colour
any representation by it (**Coloring Method ▸ User**):

.. code-block:: tcl

   vmdance userfield -sel protein
   mol modcolor 0 top User

Or let the plugin draw them: ``vmdance draw -colour 1 -reps 1`` colours the
structure by the current frame's cluster and draws every representative.

The representatives as structures
---------------------------------

The representatives in one PDB, a model each, or each cluster's frames as a
trajectory of its own, of any selection (the protein with its ligand, say):

.. code-block:: tcl

   vmdance export out -prefix c -items {representatives trajectories} -format pdb -sel "protein or resname LIG"

The frames are VMD's as loaded: the fit, when the clustering had one, is
not applied to them. In a PDB each frame is a model (``MODEL`` …
``ENDMDL``), and a ``REMARK`` before it names its cluster and frame; VMD
reads the file back as frames (:doc:`files`).

The program or the library
--------------------------

The plugin runs CPP-MDANCE's program (``mdance-cli``, in the background,
VMD free meanwhile) or its library (inside VMD: no files, VMD waits):

.. code-block:: tcl

   vmdance backend                                 ;# what is in use, and its algorithms
   vmdance backend -mode cli -cli /path/to/mdance-cli
   vmdance backend -mode library -library /path/to/mdance_tcl.so

Both give the same clusters (the reference tests compare them).
