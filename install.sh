#!/bin/bash
# install.sh - Build mdance-cli and install the MDANCE VMD plugin
#
# Usage: ./install.sh [--vmd-plugin-dir <path>] [--with-library]

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
VMD_PLUGIN_DIR="${HOME}/.vmd/plugins/noarch/tcl/mdance1.0"
BUILD_LIBRARY=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --vmd-plugin-dir)
            [[ $# -ge 2 && -n "$2" ]] || { echo "error: --vmd-plugin-dir requires a non-empty path" >&2; exit 1; }
            VMD_PLUGIN_DIR="$2"
            shift 2
            ;;
        --with-library)
            BUILD_LIBRARY=1
            shift
            ;;
        --help)
            echo "Usage: $0 [--vmd-plugin-dir <path>] [--with-library]"
            echo ""
            echo "Builds mdance-cli (when run inside a CPP-MDANCE checkout) and installs"
            echo "the MDANCE VMD plugin."
            echo ""
            echo "Options:"
            echo "  --vmd-plugin-dir <path>  Install location (default: ~/.vmd/plugins/noarch/tcl/mdance1.0)"
            echo "  --with-library           Also build and install the native Tcl extension (faster, no temp files)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Normalize a trailing slash and reject characters that would break the Tcl
# {braces} we write into ~/.vmdrc (an unbalanced brace there breaks the user's
# entire startup file, not just the plugin).
VMD_PLUGIN_DIR="${VMD_PLUGIN_DIR%/}"
case "$VMD_PLUGIN_DIR" in
    *[{}\\]*)
        echo "error: install path must not contain '{', '}' or '\\': $VMD_PLUGIN_DIR" >&2
        exit 1
        ;;
esac

echo "=== MDANCE VMD Plugin Installer ==="
echo ""

# Step 1: Build -- only when run inside a CPP-MDANCE checkout (CMakeLists.txt at
# PROJECT_ROOT). In the standalone plugin copy the C++ backend is absent, so skip
# the build and rely on a prebuilt backend (MDANCE_CLI/MDANCE_LIB or copied into
# the plugin dir). See STANDALONE.md.
CAN_BUILD=0
if [ -f "$PROJECT_ROOT/CMakeLists.txt" ]; then
    CAN_BUILD=1
fi

if [ "$CAN_BUILD" -eq 1 ]; then
    CMAKE_ARGS="-DBUILD_CLI=ON -DCMAKE_BUILD_TYPE=Release"
    BUILD_TARGETS="mdance-cli"

    if [ "$BUILD_LIBRARY" -eq 1 ]; then
        CMAKE_ARGS="$CMAKE_ARGS -DBUILD_SHARED=ON -DBUILD_TCL=ON"
        BUILD_TARGETS="$BUILD_TARGETS mdance_shared mdance_tcl"
        echo "1. Building mdance-cli and Tcl extension..."
    else
        echo "1. Building mdance-cli..."
    fi

    cmake -S "$PROJECT_ROOT" -B "$PROJECT_ROOT/build" $CMAKE_ARGS
    for target in $BUILD_TARGETS; do
        cmake --build "$PROJECT_ROOT/build" --target "$target"
    done
    echo "   Built: $PROJECT_ROOT/build/cli/mdance-cli"
else
    echo "1. Skipping build: no CMakeLists.txt at $PROJECT_ROOT"
    echo "   (standalone plugin copy -- the C++ backend lives in CPP-MDANCE)."
    echo "   Provide a built backend via MDANCE_CLI / MDANCE_LIB, or copy the"
    echo "   binary into $VMD_PLUGIN_DIR. See STANDALONE.md."
fi
echo ""

# Step 2: Create plugin directory
echo "2. Installing plugin to: $VMD_PLUGIN_DIR"
mkdir -p "$VMD_PLUGIN_DIR"

# Step 3: Copy Tcl files
cp "$SCRIPT_DIR/mdance/"*.tcl "$VMD_PLUGIN_DIR/"
echo "   Copied Tcl files"

# Step 4: Copy CLI binary if one is available
CLI_SRC="$PROJECT_ROOT/build/cli/mdance-cli"
if [ -f "$CLI_SRC" ]; then
    cp "$CLI_SRC" "$VMD_PLUGIN_DIR/"
    chmod +x "$VMD_PLUGIN_DIR/mdance-cli"
    echo "   Copied mdance-cli binary"
else
    echo "   No prebuilt mdance-cli at $CLI_SRC."
    echo "   Set MDANCE_CLI or copy the binary into $VMD_PLUGIN_DIR (see STANDALONE.md)."
fi

# Step 5: Copy Tcl extension library if built
if [ "$BUILD_LIBRARY" -eq 1 ] && [ "$CAN_BUILD" -eq 1 ]; then
    # Look only at the top of build/tcl for a real shared object -- a recursive
    # search descends into build/tcl/CMakeFiles/mdance_tcl.dir and could pick up a
    # .o.d/.json artifact named "mdance_tcl.*".
    TCL_LIB=$(find "$PROJECT_ROOT/build/tcl" -maxdepth 1 -type f \
        \( -name 'mdance_tcl*.so' -o -name 'mdance_tcl*.dylib' -o -name 'mdance_tcl*.dll' \) \
        2>/dev/null | head -1 || true)
    if [ -n "${TCL_LIB:-}" ] && [ -f "$TCL_LIB" ]; then
        cp "$TCL_LIB" "$VMD_PLUGIN_DIR/"
        echo "   Copied Tcl extension: $(basename "$TCL_LIB")"
    else
        echo "   WARNING: Tcl extension library not found in build directory"
    fi
fi

# Step 6: Update .vmdrc
VMDRC="${HOME}/.vmdrc"
echo ""
echo "3. Configuring VMD..."

# auto_path must point at the directory that CONTAINS the package dir
# (mdance1.0): Tcl's package loader scans each auto_path entry and ONE level of
# immediate subdirectories for pkgIndex.tcl. That is a single dirname of the
# install dir (matching README.md), not two.
PLUGIN_PARENT="$(dirname "$VMD_PLUGIN_DIR")"

MARKER_BEGIN="# >>> MDANCE plugin >>>"
MARKER_END="# <<< MDANCE plugin <<<"

if [ -f "$VMDRC" ]; then
    cp "$VMDRC" "$VMDRC.mdance-bak-$(date +%Y%m%d%H%M%S)"
    echo "   Backed up existing .vmdrc"
    # Strip any prior MDANCE block so re-runs and relocations converge on the
    # current auto_path instead of leaving a stale (possibly wrong) entry behind.
    if grep -qF "$MARKER_BEGIN" "$VMDRC"; then
        tmp="$(mktemp)"
        sed "/^# >>> MDANCE plugin >>>$/,/^# <<< MDANCE plugin <<<$/d" "$VMDRC" > "$tmp" && mv "$tmp" "$VMDRC"
    fi
fi

{
    echo ""
    echo "$MARKER_BEGIN"
    echo "# MDANCE Clustering Plugin"
    echo "lappend auto_path {$PLUGIN_PARENT}"
    echo "vmd_install_extension mdance mdance::gui \"Analysis/MDANCE Clustering\""
    echo "$MARKER_END"
} >> "$VMDRC"
echo "   Updated $VMDRC"

echo ""
echo "=== Installation complete ==="
echo ""
if [ "$BUILD_LIBRARY" -eq 1 ] && [ "$CAN_BUILD" -eq 1 ]; then
    echo "Installed with native library support (faster execution, no temp files)."
    echo "The plugin will automatically use the library when available."
    echo ""
fi
echo "To use: Open VMD -> Extensions -> Analysis -> MDANCE Clustering"
echo ""
echo "Or from VMD console:"
echo "  package require mdance"
echo "  mdance::gui"
