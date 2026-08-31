# VMD-MDANCE — standalone plugin copy

This is a **plugin-only** copy of the MDANCE VMD plugin, kept separate from the
`CPP-MDANCE` repository. It contains the Tcl/Tk plugin (`mdance/`), the installer,
and the user docs. It does **not** contain the C++ backend.

## Backend dependency

The plugin calls a built MDANCE backend:
- `mdance-cli` (CLI mode), and/or
- `mdance_tcl.{so,dylib}` (native library mode).

Both are produced by building the **CPP-MDANCE** C++ project
(`/Users/deb0054/github/CPP-MDANCE`). Because this copy lives outside that repo,
the plugin's relative-path search (`../../build/...`) will not find them. Point the
plugin at a built backend in one of these ways:

1. **Environment variables** (recommended):
   ```sh
   export MDANCE_CLI="/Users/deb0054/github/CPP-MDANCE/build/cli/mdance-cli"
   export MDANCE_LIB="/Users/deb0054/github/CPP-MDANCE/build/tcl/mdance_tcl.dylib"
   ```
   (or set them in `~/.vmdrc`). The Setup tab also has a **Browse...** button for the CLI.
2. **Copy the built binaries into `mdance/`** — the plugin searches its own directory.

Build the backend in CPP-MDANCE with:
```sh
cmake -S . -B build -DBUILD_CLI=ON -DBUILD_SHARED=ON -DBUILD_TCL=ON
cmake --build build --target mdance-cli mdance_tcl
```

## Contents
- `mdance/` — the Tcl plugin (gui, plots, sweep, utils, core, pkgIndex)
- `install.sh`, `README.md`, `QUICK_START.{md,html}` — installer + user docs
  (note: `install.sh` expects to run from inside a CPP-MDANCE checkout to build
  the backend; in this standalone copy use the env-var approach above instead)
- `notes/` — design/review notes carried over from the build effort, including
  `REVIEW_NOTES.md` (known issues, e.g. the DIVINE `refine` crash) and
  background notes on the port scope, the C API and headless verification.
