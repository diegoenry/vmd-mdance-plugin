# VMDance quick-start guide (PDF)

A short guide, from an install to the clusters of a tau peptide's trajectory
(BitQT's examples), in
the window and in a script, with a gallery of the 13 plots. It is written for
the JCIM article's Supporting Information. It is kept apart from `docs/`, the
online documentation: it reads two of that folder's diagrams and the logo,
and writes nothing there.

The analysis: the PDB as the topology, its own frame deleted after the DCD
is loaded (6001 frames); every frame fitted on frame 999 in VMD, on
`resid 3 to 12 and name N CA C O H` (50 atoms); an elbow scan with the
stability of NANI's seedings; KMeans NANI at k 6, as MDANCE's own tutorial
(Davies-Bouldin's sharpest dip; the seedings agree at k 2 and 5: the guide
says so); the two halves as
groups; DIVINE, HELM, eQual and a sweep for a second opinion.

| File | What it is |
| --- | --- |
| `vmdance-quickstart.tex` | the guide (LaTeX) |
| `quickstart.tcl` | the guide's script, printed in it as it is |
| `numbers.tcl` | runs that script in text-mode VMD, and writes every number the guide quotes |
| `numbers.tex` | those numbers, as LaTeX macros (made: do not edit) |
| `bench.tcl` | times the same jobs with CPP-MDANCE's program and with its library |
| `bench.tex` | those times, as LaTeX macros (made: do not edit) |
| `figures.tcl` | runs the same script in VMD with its window, and writes `figures/` |
| `figures/` | the gallery (`gallery_<plot>.pdf`), the representatives (`main_3d.png`), the window (`window*.png`) (made: do not edit) |
| `annotate.py` | numbers the window's parts, and crops the 3D view to the molecule (Pillow) |
| `macos_windows.swift` | lists VMD's windows, so that `screencapture` takes the VMDance window alone (macOS) |
| `Makefile` | builds it all |

## Build the PDF

Needs pdfLaTeX and latexmk (TeX Live), with the packages `libertinus`,
`inconsolata`, `tcolorbox`, `listings`, `subcaption` and `titlesec`.

```sh
make            # vmdance-quickstart.pdf, from numbers.tex and figures/
```

## Make the numbers and the figures again

Needs VMD, CPP-MDANCE's `mdance-cli` and the example: the `examples` folder
of BitQT (`git clone https://github.com/LQCT/BitQT.git`), which holds
`aligned_tau.pdb` and `aligned_original_tau_6K.dcd`.

```sh
make numbers VMD=/path/to/vmd TAU_DATA=/path/to/BitQT/examples   # numbers.tex written again
make check   VMD=/path/to/vmd TAU_DATA=/path/to/BitQT/examples   # made again, and compared
make figures VMD=/path/to/vmd TAU_DATA=/path/to/BitQT/examples   # figures/ written again
make bench   VMD=/path/to/vmd TAU_DATA=/path/to/BitQT/examples   # bench.tex written again
```

`make bench` also needs CPP-MDANCE's library (`MDANCE_LIB`, or a build with
`-DBUILD_TCL=ON` beside the repository). It takes about ten minutes, and its
times are the machine's: run it on a machine otherwise idle. `make check`
does not compare them. With the library, VMD's memory grows by about a
gigabyte during it.

`MDANCE_CLI` names the program; by default it is the CPP-MDANCE build beside
the repository (`../CPP-MDANCE/build/cli/mdance-cli`). VMD runs with an empty
startup file, so `~/.vmdrc` is not read. `make check` leaves out of the
comparison where the numbers were made (VMD, the machine, the backend's
commit), how long it took and the session's size.

`make figures` opens VMD's windows on the screen for a minute: the figures
are drawn by Tk, which text-mode VMD cannot load. The window's picture is
taken on macOS only (`screencapture`, which needs the terminal to be allowed
to record the screen); elsewhere `figures/window*.png` are kept as they are.

The numbers and figures were made with CPP-MDANCE a5d197b (its main,
0546995, and two commits that change only the release builds) and VMD
2.0.0a6 on an Apple M1 Max.
