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

   set n [molinfo $m get numframes]
   set b [expr {$n / 4}]
   vmdance groups -ranges [list q1 0-[expr {$b - 1}] q2 $b-[expr {2 * $b - 1}] \
       q3 [expr {2 * $b}]-[expr {3 * $b - 1}] q4 [expr {3 * $b}]-[expr {$n - 1}]]
   vmdance makeup -by group

Shares that drift from block to block, or a cluster absent from the first
blocks, say the populations have not settled.

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

   # a column of a paper: 3.3 in (240 points) wide at 600 dpi, 9-point text
   # (a figure is 240 to 6000 points each way)
   vmdance figures figs -plots {populations makeup} -width 240 -height 240 \
       -formats {pdf png} -dpi 600 -text 9
   # a slide: larger text
   vmdance figures figs -plots {elbow map} -width 900 -height 560 -text 16 -prefix slide
   # a plot as one of its views (the plot options' names)
   vmdance figures figs -plots {tree} -options {td_view heights}

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

One PDB per cluster's representative, or each cluster's frames as a
trajectory of its own, of any selection (the protein with its ligand, say):

.. code-block:: tcl

   vmdance export out -prefix c -items {representatives trajectories} -format pdb -sel "protein or resname LIG"

The frames are VMD's as loaded: the fit, when the clustering had one, is
not applied to them.

The program or the library
--------------------------

The plugin runs CPP-MDANCE's program (``mdance-cli``, in the background,
VMD free meanwhile) or its library (inside VMD: no files, VMD waits):

.. code-block:: tcl

   vmdance backend                                 ;# what is in use, and its algorithms
   vmdance backend -mode cli -cli /path/to/mdance-cli
   vmdance backend -mode library -library /path/to/mdance_tcl.so

Both give the same clusters (the reference tests compare them).
