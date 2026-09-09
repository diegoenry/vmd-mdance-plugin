# Installing the MDANCE VMD plugin

The plugin is Tcl/Tk and needs no compilation. Its **backend** is C++ and does, so a
working install means two repositories:

| | what it is | you need |
|---|---|---|
| [`CPP-MDANCE`](https://github.com/diegoenry/CPP-MDANCE) branch `feat-vmd-backend` | the C++ library and the `mdance-cli` binary | to build it |
| [`vmd-mdance-plugin`](https://github.com/diegoenry/vmd-mdance-plugin) branch `feat-reviewer-feedback` | the Tcl/Tk plugin | to install it |

The plugin will not run without a built backend. That is the single most common
installation failure.

## Requirements

- **VMD** — verified against 1.9.4 and 2.0.0a7
- **CMake** 3.15 or newer
- a **C++17** compiler
- **git** — the build fetches Eigen and GoogleTest if they are not already installed
- **Python 3** — optional, for one extra validation test (see step 1)

You do *not* need to install Eigen or GoogleTest yourself. If they are absent, CMake
downloads them; if they are present, yours are used. Tcl development headers are needed
only for the optional native-library mode in step 5.

---

## 1. Create a Python environment (optional but recommended)

The backend ships a validator that cross-checks the eQUAL and PRIME algorithms against an
independent NumPy reference — 16 checks that are the strongest evidence the build is
correct. It needs `numpy`, and nothing else.

```bash
python3 -m venv ~/mdance-venv
source ~/mdance-venv/bin/activate
pip install --upgrade pip
pip install numpy
```

**The environment must be active when you run `cmake`, not just when you run the tests.**
CMake records the interpreter path at configure time, so activating afterwards has no
effect. If you skip this step everything still builds — you get one test instead of two.

## 2. Build the backend

```bash
git clone -b feat-vmd-backend https://github.com/diegoenry/CPP-MDANCE.git
cd CPP-MDANCE
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Expect to see, on a machine without them:

```
-- Eigen not found; fetching Eigen 3.4.0
-- GoogleTest not found; fetching v1.15.2
```

Verify:

```bash
ctest --test-dir build --output-on-failure
```

- **2/2 passing** with numpy available (`mdance_tests`, `validate_equal_prime`)
- **1/1 passing** without it — the validator is not registered, which is expected and
  reported at configure time

Then tell the plugin where the binary is:

```bash
export MDANCE_CLI="$PWD/build/cli/mdance-cli"
```

Put that line in your shell profile to make it permanent. The Setup tab also has a
**Browse…** button if you would rather point at it from the GUI.

## 3. Install the plugin

```bash
cd ..
git clone -b feat-reviewer-feedback https://github.com/diegoenry/vmd-mdance-plugin.git
cd vmd-mdance-plugin
./install.sh
```

`install.sh` copies the Tcl files to `~/.vmd/plugins/noarch/tcl/mdance1.0` and registers
the plugin in `~/.vmdrc`, backing that file up first and replacing any previous MDANCE
block so re-runs are safe.

It will print `Skipping build: no CMakeLists.txt` — **this is correct.** The backend lives
in the other repository and you built it in step 2. Install elsewhere with
`./install.sh --vmd-plugin-dir /path/to/mdance1.0`.

Verify the plugin itself, which needs no backend:

```bash
./tests/run_tests.sh
```

Expect **334 checks, all passing**, across 19 suites. The runtime suites drive a real
headless VMD, so this also confirms VMD is usable from your shell.

## 4. Launch it

Open VMD, then **Extensions → Analysis → MDANCE Clustering**. Or from the VMD console:

```tcl
package require mdance
mdance::gui
```

Check **Setup → MDANCE Backend**: it should report the mode and the resolved path. If it
says the backend was not found, `MDANCE_CLI` is not set in the environment VMD inherited —
a common surprise when VMD is launched from a desktop icon rather than the shell you
exported it in.

## 5. Native library mode (optional, unverified)

The backend can also build a Tcl extension that passes coordinates to MDANCE in memory, with
no temporary files or subprocess:

```bash
cd CPP-MDANCE
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TCL=ON
cmake --build build -j
export MDANCE_LIB="$PWD/build/tcl/mdance_tcl.so"     # .dylib on macOS
```

The plugin prefers the library when it can load it and falls back to the CLI otherwise.

**Treat this as experimental.** It needs Tcl development headers, `BUILD_TCL` is OFF by
default, and it has not been successfully loaded into a running VMD process during
development — on macOS, codesign Team ID enforcement blocks dlopening an unsigned
extension into the signed VMD app bundle. CLI mode is the tested path.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `No rule to make target 'mdance-cli'` | You are on a branch without the backend. Use `feat-vmd-backend`. |
| `Could NOT find GTest` / `Could not find ... Eigen3` | An older checkout. `git pull`, delete `build/`, and re-configure — both are fetched automatically now. |
| `Could not find mdance-cli binary` in the GUI | `MDANCE_CLI` is unset in VMD's environment, or points at a path that no longer exists. |
| `validate_equal_prime` missing from ctest | numpy was not importable when you configured. Activate the venv and re-configure. |
| `validate_equal_prime` **fails** rather than being absent | The `mdance-cli` under test is stale. Rebuild. |
| `TestHelm.ZMatrix` fails | An older checkout — the gtests used to resolve their data relative to the build directory. `git pull` and re-configure. |
| `Algorithm 'divine' is not available in this build` | Expected on `feat-vmd-backend`. DIVINE lives on a separate branch upstream and is compiled in only when present. |
| DIVINE refuses to run with `OutlierPair`/`SplinterPair` + Refine | Deliberate. That combination triggers an out-of-bounds read in the backend that takes VMD down with it; the plugin blocks it. Use the `NANI` anchor, or turn Refine off. |
| VMD starts but the menu entry is missing | `~/.vmdrc` was not re-read, or `auto_path` points at the wrong level. It must contain the directory *containing* `mdance1.0`, not `mdance1.0` itself. |

## Manual installation

If you would rather not let a script edit `~/.vmdrc`:

```bash
mkdir -p ~/.vmd/plugins/noarch/tcl/mdance1.0
cp mdance/*.tcl ~/.vmd/plugins/noarch/tcl/mdance1.0/
```

Then add to `~/.vmdrc`, with `$HOME` written out in full — Tcl does not expand `~` inside
braces:

```tcl
lappend auto_path {/Users/you/.vmd/plugins/noarch/tcl}
vmd_install_extension mdance mdance::gui "Analysis/MDANCE Clustering"
```

Optionally copy `mdance-cli` into the plugin directory instead of setting `MDANCE_CLI` —
the plugin searches its own directory first.
