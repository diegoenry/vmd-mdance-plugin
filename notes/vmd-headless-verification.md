---
name: vmd-headless-verification
description: How to verify the MDANCE VMD Tcl/Tk plugin without a display (headless VMD text mode)
metadata: 
  node_type: memory
  type: reference
  originSessionId: 42b79370-5dc3-4d30-97e2-6f8ad5cafee7
---

The MDANCE VMD plugin (`vmd_plugin/mdance/*.tcl`) can be loaded and exercised headlessly for verification — no display window pops up:

`vmd -dispdev text -eofexit -e script.tcl` (full binary: `~/software/VMD2.app/Contents/vmd2/bin/vmd`).

In the script: `source .../vmd_plugin/mdance/mdance.tcl` loads the whole plugin (it `package require Tk`, which VMD provides). `::mdance::gui::create_window` actually builds the Tk notebook + all tabs (catches widget/treeview/grid typos that a plain `tclsh` parse can't, since tclsh has no Tk). Stub dialogs with `proc tk_messageBox {args} {return ok}` etc. Force CLI mode with `set ::mdance::use_library 0; set ::mdance::cli_path <mdance-cli>` (and `set env(MDANCE_CLI) ...`). Load a multi-model PDB as a test trajectory.

For a pure brace/parse smoke test without VMD: source each file in a child `interp` with `unknown`/`package`/`source`/`load` stubbed and check `info complete`.

See [[mdance-capi-visibility-and-library-mode]].
