Install
=======

VMDance is two things: the plugin (Tcl, no build) and a build of
CPP-MDANCE, which does the clustering.

The backend
-----------

.. code-block:: sh

   git clone https://github.com/mqcomplab/CPP-MDANCE.git
   cd CPP-MDANCE
   cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TCL=ON
   cmake --build build -j
   ctest --test-dir build --output-on-failure

This makes the program ``build/cli/mdance-cli`` and, with ``BUILD_TCL``, the
library ``build/tcl/mdance_tcl.so`` (``.dylib`` on macOS, ``.dll`` on
Windows). The program is enough; the library is optional. DIVINE is built
only with ``-DBUILD_DIVINE=ON`` on a tree that has ``src/cluster/divine.cpp``:
without it the plugin offers KMeans NANI, HELM and eQUAL, and says why
DIVINE is missing.

The plugin
----------

Add it to ``~/.vmdrc``:

.. code-block:: tcl

   lappend auto_path /path/to/vmd-mdance-plugin/vmdance
   package require vmdance   ;# registers Extensions > Analysis > VMDance
   set env(MDANCE_CLI) /path/to/CPP-MDANCE/build/cli/mdance-cli
   set env(MDANCE_LIB) /path/to/CPP-MDANCE/build/tcl/mdance_tcl.so   ;# optional

Then open **Extensions ▸ Analysis ▸ VMDance**, or type ``vmdance`` in
VMD's console. It needs a VMD built with Tcl/Tk 8.6, as VMD 2 is (``info
patchlevel`` in VMD's console says which: VMD 1.9.3 and the Linux 1.9.4
alphas have Tcl 8.5, and cannot load it), and is
tested in VMD 2.1 (Linux). ``make distrib PLUGINDIR=…`` copies the plugin
into a VMD plugin tree as ``vmdance1.0``.

Finding the backend
-------------------

The program is looked for, in order, as chosen in **Settings ▸ Backend**,
in ``MDANCE_CLI``, in the plugin's folder (``mdance-cli`` or
``bin/mdance-cli``), on the ``PATH``, and in a CPP-MDANCE build beside the
plugin's folder (``../CPP-MDANCE/build/cli``); the library likewise
(``MDANCE_LIB``, ``mdance_tcl…``). Settings shows which is used and what it
was built with (a program rebuilt at its path is asked again), and keeps a
program or library chosen there between
sessions of VMD (in ``~/.vmdance.prefs``), for the command as for the
window: ``vmdance backend`` says the same in a script. ``vmdance
backend -mode … -cli … -library …`` chooses for this VMD only, over what
Settings chose (a ``-cli`` alone keeps Settings' mode: give ``-mode cli``
with it); ``vmdance backend try …`` says what a choice would give,
without making it, as Settings does until OK.

``~/.bashrc`` reaches a VMD started from a shell only; ``set env(…)`` in
``~/.vmdrc`` reaches every one.

The program or the library
--------------------------

The **program** runs in the background: the window and VMD stay usable,
and Cancel stops it. It can be a script that runs ``mdance-cli`` (to set
``LD_LIBRARY_PATH``, or start a container): Cancel stops what the script
started too (an Apptainer or Singularity container with it, a docker or
podman container only when run with ``--init``, which passes the stop on
to its program), and a program that takes more than 3 s to answer when run
without arguments is offered every algorithm (Settings says so; a run says
if one is missing). The coordinates go to it as a CSV file in a folder of
the plugin's own (readable by you only, in ``TMPDIR``, named for the
machine and the VMD process: a ``TMPDIR`` shared by machines or containers
is safe; VMD writes there too, and opens a name by its UTF-8 bytes: one
whose name is not UTF-8, with a locale that is not, ``LANG=C``, is passed
over), and come back as JSON. The
**library** is loaded into VMD: the coordinates are passed in memory (the
CSV file is written all the same), but a call blocks VMD until it returns,
and cannot be cancelled (the line at the bottom of the window says so). It
is given them as one Tcl list, the same for every call of a job (a scan's),
of which CPP-MDANCE's Tcl binding makes a text: a call takes about 180 bytes of
VMD's memory a coordinate at its peak, of which Tcl keeps 120 until VMD
quits, and a text past 2 GB (about 110 million coordinates) ends VMD,
whatever the memory. A library call that cannot fit is refused, saying
so. *Automatic*, the default, uses the program when there is one, else the
library (Setup then says so). Both give the same clusters (the tests compare them); for many
frames of many atoms, use the program.

Figures in PDF and PNG use Ghostscript (``gs``); EPS works without it.
