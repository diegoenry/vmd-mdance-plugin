Design
======

VMDance replaces, rewritten from scratch, the MDANCE VMD plugin that its
repository held before. It follows the principles of the authors' DihedralView,
InteractionView and Molywood Studio plugins.

Principles
----------

- **One package, one command.** ``vmdance`` opens the window, and its
  options and subcommands do everything the window does. A new window
  feature gets a subcommand (``_api_*`` in ``vmdance.tcl``) and a test.
- **The core without Tk.** ``json``, ``molecule``, ``algorithms``,
  ``backend``, ``coords``, ``measures``, ``analysis``, ``results``,
  ``session``, ``export`` and ``viz3d`` never use Tk; the window's modules
  are loaded only when it opens (``_load_tk``). The 3D drawing is core: the
  command draws in 3D too. The core is tested in ``vmd -dispdev text``, the
  parts that need no molecule in plain ``tclsh`` too.
- **One job at a time, published whole.** A clustering is one value (a
  dict), checked and published at once (``Results::publish``); a failed,
  cancelled or refused job leaves the current one untouched. The runs, the
  scans, the picks and the selection live in the core too: the window
  listens to them (``Results::listen``) and holds no results.
- **One table of parameters.** The command's options, the window's fields,
  the checks, the backend's arguments and the parameters page are made from
  one table (``Algo::A``), with ``mdance-cli``'s names.
- **Never trust what is read.** The backend's JSON is read by a reader of
  the plugin's own and checked whole before anything is published;
  sessions, the MDANCE plugin's sessions, label files and preferences are
  parsed as data, never evaluated; numbers are checked before ``expr`` sees
  them (it would compare ``1o`` as a string, read ``010`` as octal, rewrite
  ``1e10`` as a float, and fail on ``NaN``), and strings a user typed or a
  file holds are returned with ``_get`` or ``if``, never through ``expr``'s
  ``?:``. A session is someone else's file: its lists are counted before
  they are made (a few kilobytes can otherwise allocate gigabytes) and
  bounded, and the files its molecule record names are refused unless they
  are regular files of one of VMD's own readers, so loading one never runs a
  converter, downloads a file, reaches a shell, or blocks on a device.
- **VMD state is borrowed, not taken.** A job never moves VMD's frame or
  coordinates; every atom selection is made and deleted at the global level
  (VMD deletes a selection when the procedure that made it returns, and
  refuses a delete from elsewhere), also on errors and on Cancel; the plugin
  draws with representations of its own and deletes only those; it writes
  the molecule's data only when asked, and changes the frames of no
  molecule but one a session loaded itself (its PDB's own frame deleted
  again, as it was when it was clustered).
- **Responsive.** A job runs in a coroutine: the frames are read in slices
  of 40 ms, ``mdance-cli`` runs in the background, and the plots' frame
  markers are refreshed at most every 120 ms.

Choices of this plugin
----------------------

- **The backend's science, as the reference.** The clusterings are
  CPP-MDANCE's. The tests run ``mdance-cli`` directly on the coordinates the
  plugin gives it and compare every label; compare the library with the
  program; the plugin's measures with direct computations; and the
  plugin's clusterings with MDANCE's published runs. A difference is
  deliberate or a bug: a deliberate one has its reason in the code, a line
  in :doc:`differences`, and a test.
- **Checked before running.** What can be known before the backend runs is
  checked there (NANI's seeds, HELM's starting clusters and trim, DIVINE's
  crash, metric, first split and smallest share, the diversity selection
  with an index other than MSD, eQUAL's
  radius, numbers the backend cannot read, the frames and atoms,
  coordinates that are not numbers, what the library can take), with the
  option's name and what to change: a message from the backend is the last
  resort.
- **The frames are VMD's.** A result holds the VMD frames it clustered;
  every per-frame list is in their order. The backend's indices are rows of
  the clustering, and never leave the plugin as frames.
- **Measured once.** The plugin's measures are computed with the
  clustering, from the coordinates the backend clustered, and kept with it:
  a session reopened without its molecule shows every plot.
- **One hue per cluster.** A cluster is drawn in 3D in VMD's colour of an
  id, and in the plots in a darker tone of the same hue (or, as an option,
  in VMD's colour read from VMD): the plots and the 3D window agree without
  the plugin changing VMD's colours.
