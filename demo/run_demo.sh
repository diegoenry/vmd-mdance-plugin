#!/bin/bash
# run_demo.sh - launch the MDANCE walkthrough in VMD.
#
#   ./demo/run_demo.sh              # full walkthrough, ready to play
#   ./demo/run_demo.sh --step 5     # load every 5th frame (faster rehearsal)
#   ./demo/run_demo.sh --check      # headless validation, no window
#   ./demo/run_demo.sh --rehearse   # headless: play every beat fast, report errors
#   ./demo/run_demo.sh --narrate    # (re)build the narration audio, then launch
#
# Everything is overridable from the environment; see demo/README.md.

set -u
DEMO_ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$DEMO_ROOT")"
export DEMO_ROOT

# --- VMD ------------------------------------------------------------------
VMD="${VMD:-}"
if [ -z "$VMD" ]; then
    # Candidates, most specific first. $HOME-relative rather than absolute so
    # the list carries to another machine; `vmd` on PATH is the last resort.
    for c in "$HOME/software/VMD2.app/Contents/vmd2/bin/vmd" \
             /Applications/VMD*2.0*.app/Contents/vmd2/bin/vmd \
             /Applications/VMD*.app/Contents/vmd/vmd_MACOSX* \
             /Applications/VMD*.app/Contents/MacOS/VMD \
             /usr/local/lib/vmd/vmd_* ; do
        if [ -x "$c" ]; then VMD="$c"; break; fi
    done
fi
if [ -z "$VMD" ] && command -v vmd >/dev/null 2>&1; then VMD="vmd"; fi
if [ -z "$VMD" ]; then
    echo "run_demo: no VMD binary found -- set VMD=/path/to/vmd" >&2
    exit 1
fi

# --- backend --------------------------------------------------------------
# The plugin's own env hooks, so the demo and the plugin agree on the backend.
if [ -z "${MDANCE_CLI:-}" ]; then
    # Where a CPP-MDANCE build tree or an install.sh deployment normally lands.
    for c in "$REPO_ROOT/../CPP-MDANCE/build/cli/mdance-cli" \
             "$HOME/github/CPP-MDANCE/build/cli/mdance-cli" \
             "$HOME/CPP-MDANCE/build/cli/mdance-cli" \
             "$HOME/.vmd/plugins/noarch/tcl/mdance1.0/mdance-cli" \
             "$REPO_ROOT/mdance/mdance-cli"; do
        if [ -x "$c" ]; then MDANCE_CLI="$c"; break; fi
    done
    if [ -z "${MDANCE_CLI:-}" ] && command -v mdance-cli >/dev/null 2>&1; then
        MDANCE_CLI="$(command -v mdance-cli)"
    fi
fi
export MDANCE_CLI="${MDANCE_CLI:-}"
if [ -n "$MDANCE_CLI" ] && [ ! -x "$MDANCE_CLI" ]; then
    echo "run_demo: MDANCE_CLI is not executable: $MDANCE_CLI" >&2
    exit 1
fi

MODE=play
BEAT_SECS="${DEMO_BEAT_SECS:-0.35}"
while [ $# -gt 0 ]; do
    case "$1" in
        --check)    MODE=check ;;
        --rehearse) MODE=rehearse ;;
        --narrate)  MODE=narrate ;;
        --step)     shift; export DEMO_STEP="$1" ;;
        --beat)     shift; BEAT_SECS="$1" ;;
        --only)     shift; export DEMO_REHEARSE_ONLY="$1" ;;
        --vmd)      shift; VMD="$1" ;;
        -h|--help)  sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "run_demo: unknown option $1" >&2; exit 2 ;;
    esac
    shift
done

# --- narration ------------------------------------------------------------
build_narration() {
    local py="$DEMO_ROOT/.venv/bin/python"
    if [ ! -x "$py" ]; then
        echo "run_demo: no venv -- run $DEMO_ROOT/bootstrap.sh first" >&2
        return 1
    fi
    echo "==> exporting beats"
    "${TCLSH:-tclsh8.6}" "$DEMO_ROOT/narration/export_beats.tcl" \
        "$DEMO_ROOT/narration/beats.json" || return 1
    echo "==> synthesizing narration (Kokoro)"
    "$py" "$DEMO_ROOT/narration/build_narration.py" "$@" || return 1
}

# Keep beats.json and manifest.tcl in step with the scene files on every launch.
# Without this, editing a scene and pressing play would narrate the old script.
refresh_manifest() {
    "${TCLSH:-tclsh8.6}" "$DEMO_ROOT/narration/export_beats.tcl" \
        "$DEMO_ROOT/narration/beats.json" >/dev/null 2>&1 || true
    local py="$DEMO_ROOT/.venv/bin/python"
    if [ -x "$py" ]; then
        "$py" "$DEMO_ROOT/narration/build_narration.py" --dry-run >/dev/null 2>&1 || true
    fi
}

# run_headless - invoke VMD in text mode for --check / --rehearse.
#
# `</dev/null` is load-bearing, not tidiness. With -eofexit VMD exits when its
# stdin reaches EOF; run from an interactive shell stdin is already at EOF so it
# exits, but run detached (a background job, CI, a `&`) stdin stays open and VMD
# sits at its console prompt forever with the work already finished. That is how
# a --check left a headless VMD alive for eight hours.
#
# The timeout is the backstop for anything else that blocks -- a dialog that
# slipped past the stand-ins would otherwise hang just as silently.
run_headless() {
    local t="${DEMO_VMD_TIMEOUT:-1800}"
    if command -v timeout >/dev/null 2>&1; then
        timeout "$t" "$VMD" -dispdev text -eofexit "$@" </dev/null >/dev/null 2>&1
    else
        "$VMD" -dispdev text -eofexit "$@" </dev/null >/dev/null 2>&1
    fi
}

# A bootstrap file is used instead of passing the script to `vmd -e` directly:
# a played script that calls `vwait` behaves differently from a sourced one, and
# sourcing is the form that works in both.
boot() {
    local target="$1"
    local tmp
    tmp="$(mktemp -t mdance_demo_boot).tcl"
    printf 'source {%s}\n' "$target" > "$tmp"
    echo "$tmp"
}

case "$MODE" in
narrate)
    build_narration || exit 1
    ;;
check)
    refresh_manifest
    out="$(mktemp)"
    DEMO_CHECK=1 DEMO_CHECK_OUT="$out" run_headless \
        -e "$DEMO_ROOT/tcl/demo_main.tcl"
    cat "$out"
    grep -q "all checks passed" "$out"; rc=$?
    rm -f "$out"
    exit $rc
    ;;
rehearse)
    refresh_manifest
    out="$(mktemp)"
    b="$(boot "$DEMO_ROOT/tcl/demo_rehearse.tcl")"
    DEMO_REHEARSE_OUT="$out" DEMO_BEAT_SECS="$BEAT_SECS" \
        run_headless -e "$b"
    cat "$out"
    grep -q "^RESULT: PASS" "$out"; rc=$?
    rm -f "$out" "$b"
    exit $rc
    ;;
esac

if [ "$MODE" = "play" ] || [ "$MODE" = "narrate" ]; then
    refresh_manifest
    echo "==> launching VMD walkthrough"
    echo "    vmd:     $VMD"
    echo "    backend: ${MDANCE_CLI:-<plugin default>}"
    exec "$VMD" -e "$DEMO_ROOT/tcl/demo_main.tcl"
fi
