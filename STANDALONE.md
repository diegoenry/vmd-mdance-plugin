# VMD-MDANCE — standalone plugin copy

This is a **plugin-only** copy of the MDANCE VMD plugin, kept separate from the
`CPP-MDANCE` repository. It contains the Tcl/Tk plugin (`mdance/`), the installer,
and the user docs. It does **not** contain the C++ backend.

## Backend dependency

The plugin calls a built MDANCE backend:
- `mdance-cli` (CLI mode), and/or
- `mdance_tcl.{so,dylib}` (native library mode).

Both are produced by building the **CPP-MDANCE** C++ project
(`~/github/CPP-MDANCE`). Because this copy lives outside that repo,
the plugin's relative-path search (`../../build/...`) will not find them. Point the
plugin at a built backend in one of these ways:

1. **Environment variables** (recommended):
   ```sh
   export MDANCE_CLI="~/github/CPP-MDANCE/build/cli/mdance-cli"
   export MDANCE_LIB="~/github/CPP-MDANCE/build/tcl/mdance_tcl.dylib"
   ```
   (or set them in `~/.vmdrc`). The Setup tab also has a **Browse...** button for the CLI.
2. **Copy the built binaries into `mdance/`** — the plugin searches its own directory.

Build the backend from the `feat-vmd-backend` branch of CPP-MDANCE, which is the branch
that carries `cli/`, `capi/` and `tcl/`:

```sh
git clone -b feat-vmd-backend https://github.com/diegoenry/CPP-MDANCE.git
cd CPP-MDANCE
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release      # BUILD_CLI is ON by default
cmake --build build -j
```

Add `-DBUILD_TCL=ON` for the native library as well (experimental -- see INSTALL.md).
Eigen and GoogleTest are fetched automatically when absent.

## Contents
- `mdance/` — the Tcl plugin (gui, plots, sweep, utils, core, pkgIndex)
- `install.sh`, `INSTALL.md`, `README.md`, `QUICK_START.{md,html}` — installer + user
  docs. `install.sh` detects that there is no CMakeLists.txt above it, skips the backend
  build, and says so; use the env-var approach above. INSTALL.md is the full guide.
- `notes/` — design/review notes carried over from the build effort, including
  `REVIEW_NOTES.md` (known issues, e.g. the DIVINE `refine` crash) and
  background notes on the port scope, the C API and headless verification.
