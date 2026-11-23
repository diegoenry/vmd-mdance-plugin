Install
=======

VMDance is two things:

- the plugin (Tcl, no build);
- a build of CPP-MDANCE, which does the clustering.

Requirements
------------

On every platform:

- **VMD built with Tcl/Tk 8.6**, as VMD 2 is.
- **To build CPP-MDANCE:** CMake 3.15 or later, a C++17 compiler and git.
  The build downloads Eigen 3.4 and GoogleTest when they are not
  installed.
- **Ghostscript**, for figures in PDF and PNG. EPS works without it.
- **For the library** (optional): Tcl 8.6's headers and its stub library.

Linux and macOS have all of these in their package managers. Windows
takes a few more steps.

Linux
~~~~~

.. code-block:: sh

   sudo apt install build-essential cmake git ghostscript tcl-dev    # Debian, Ubuntu
   sudo dnf install gcc-c++ cmake git ghostscript tcl-devel          # Fedora

macOS
~~~~~

Xcode's command-line tools (``xcode-select --install``), then, with
Homebrew:

.. code-block:: sh

   brew install cmake ghostscript tcl-tk

Windows
~~~~~~~

Tried with VMD 2.0 for Windows (a MinGW64 build):

- **A MinGW-w64 GCC**, with CMake and Ninja: for example the GCC that
  Strawberry Perl ships. Build with Ninja:

  .. code-block:: sh

     cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
     cmake --build build

- **That compiler's runtime first.** Put its ``bin`` folder first on the
  ``PATH``. Git for Windows ships an older ``libstdc++-6.dll``: found
  first, it stops ``mdance-cli.exe`` and the tests with error
  ``0xc0000139``.
- **For the library:** Tcl 8.6's headers and stub library, for example
  from MSYS2's ``mingw64`` (package ``mingw-w64-x86_64-tcl``). Copy only
  ``tcl.h``, ``tclDecls.h``, ``tclPlatDecls.h``, ``tclTomMath.h`` and
  ``tclTomMathDecls.h`` into a folder of their own, and give CMake that
  folder. MSYS2's whole ``include`` folder brings C headers that clash
  with another GCC's.

  .. code-block:: sh

     cmake -S . -B build -G Ninja -DBUILD_TCL=ON ^
       -DTCL_INCLUDE_PATH=C:/path/to/tcl-include ^
       -DTCL_LIBRARY=C:/msys64/mingw64/lib/libtcl86.dll.a ^
       -DTCL_STUB_LIBRARY=C:/msys64/mingw64/lib/libtclstub86.a ^
       -DTCL_TCLSH=C:/msys64/mingw64/bin/tclsh.exe

  Then copy ``build/capi/libmdance.dll`` and the compiler's
  ``libstdc++-6.dll``, ``libgcc_s_seh-1.dll`` and ``libwinpthread-1.dll``
  next to ``build/tcl/mdance_tcl.dll``. VMD then finds them, whatever its
  ``PATH``.
- **Ghostscript** from Artifex's installer (``gs…w64.exe``, at
  github.com/ArtifexSoftware/ghostpdl-downloads). It is not on winget.
  The plugin finds it in ``Program Files\gs`` without the ``PATH``.
- **The paths** in ``MDANCE_CLI`` and ``MDANCE_LIB`` name
  ``mdance-cli.exe`` and ``mdance_tcl.dll``.

The backend
-----------

.. code-block:: sh

   git clone https://github.com/mqcomplab/CPP-MDANCE.git
   cd CPP-MDANCE
   cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TCL=ON
   cmake --build build -j
   ctest --test-dir build --output-on-failure

This makes:

- the program ``build/cli/mdance-cli``;
- with ``BUILD_TCL``, the library ``build/tcl/mdance_tcl.so`` (``.dylib``
  on macOS, ``.dll`` on Windows).

The program is enough. The library is optional.

DIVINE is built when the tree has ``src/cluster/divine.cpp``
(``BUILD_DIVINE`` is then on). CPP-MDANCE's main has it since its PR #52
(1 October 2026). Without it, the plugin offers KMeans NANI, HELM and
eQual, and says why DIVINE is missing.

The plugin
----------

Add it to ``~/.vmdrc``:

.. code-block:: tcl

   lappend auto_path /path/to/vmd-mdance-plugin/vmdance
   package require vmdance   ;# adds the menu entry Analysis > VMDance
   set env(MDANCE_CLI) /path/to/CPP-MDANCE/build/cli/mdance-cli
   set env(MDANCE_LIB) /path/to/CPP-MDANCE/build/tcl/mdance_tcl.so   ;# optional

Then open **Analysis ▸ VMDance**, or type ``vmdance`` in VMD's console.
VMD 2's main window has no Extensions menu. In VMD 1.9, the entry is
under **Extensions ▸ Analysis ▸ VMDance**.

The plugin needs a VMD built with Tcl/Tk 8.6, as VMD 2 is.
``info patchlevel`` in VMD's console says which. VMD 1.9.3 and the Linux
1.9.4 alphas have Tcl 8.5, and cannot load it. The plugin is tested in
VMD 2.1 (Linux).

``make distrib PLUGINDIR=…`` copies the plugin into a VMD plugin tree as
``vmdance1.0``.

Finding the backend
-------------------

The program is looked for in this order:

1. as chosen in **Settings ▸ Backend**;
2. in ``MDANCE_CLI``;
3. in the plugin's folder (``mdance-cli`` or ``bin/mdance-cli``);
4. on the ``PATH``;
5. in a CPP-MDANCE build beside the repository's folder
   (``vmd-mdance-plugin/../CPP-MDANCE/build/cli``, or one folder higher).

The library is looked for likewise (``MDANCE_LIB``, ``mdance_tcl…``).

Settings shows which is used and what it was built with. A program
rebuilt at its path is asked again. Settings keeps a program or library
chosen there between sessions of VMD (in ``~/.vmdance.prefs``), for the
command as for the window. ``vmdance backend`` says the same in a script.

From the command:

- ``vmdance backend -mode … -cli … -library …`` chooses for this VMD
  only, over what Settings chose. A ``-cli`` alone keeps Settings' mode:
  give ``-mode cli`` with it.
- ``vmdance backend try …`` says what a choice would give, without making
  it, as Settings does until OK.

``~/.bashrc`` reaches a VMD started from a shell only. ``set env(…)`` in
``~/.vmdrc`` reaches every one.

The program or the library
--------------------------

The **program** runs in the background: the window and VMD stay usable,
and Cancel stops it.

It can be a script that runs ``mdance-cli``, to set ``LD_LIBRARY_PATH`` or
start a container. Cancel stops what the script started too:

- an Apptainer or Singularity container with it;
- a docker or podman container only when run with ``--init``, which passes
  the stop on to its program.

A program that takes more than 3 s to answer when run without arguments
is offered every algorithm. Settings says so, and a run says if one is
missing.

The coordinates go to the program as a CSV file, and come back as JSON.
The CSV file is in a folder of the plugin's own, in ``TMPDIR``:

- The folder is readable by you only.
- It is named for the machine and the VMD process, so a ``TMPDIR`` shared
  by machines or containers is safe.
- VMD writes there too, and opens a name by its UTF-8 bytes. A ``TMPDIR``
  whose name is not UTF-8, with a locale that is not (``LANG=C``), is
  passed over.

The **library** is loaded into VMD. The coordinates are passed in memory,
though the CSV file is written all the same. But a call blocks VMD until
it returns, and cannot be cancelled. The line at the bottom of the window
says so.

The library is given the coordinates as one Tcl list, the same for every
call of a job (a scan's). CPP-MDANCE's Tcl binding makes a text of it:

- A call takes about 180 bytes of VMD's memory a coordinate at its peak.
  Of these, Tcl keeps 120 until VMD quits.
- A text past 2 GB (about 110 million coordinates) ends VMD, whatever the
  memory.

A library call that cannot fit is refused, saying so.

The default, *The program if found, else the library*, uses the program
when there is one, else the library (Setup then says so). Both give the
same clusters: the tests compare them. For many frames of many atoms, use
the program.

Figures in PDF and PNG use Ghostscript (``gs``). EPS works without it.
