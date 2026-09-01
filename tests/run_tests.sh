#!/bin/bash
# run_tests.sh - run the MDANCE VMD plugin test suite (unit + runtime).
#
#   ./run_tests.sh            # run everything
#   ./run_tests.sh unit       # unit tests only (fast, no VMD)
#   ./run_tests.sh runtime    # runtime scenarios only (needs VMD)
#
# Config via env:
#   TCLSH   tclsh interpreter   (default: tclsh8.6, falls back to tclsh)
#   VMD     vmd binary          (default: the VMD2.app path, falls back to `vmd`)
#   VMD_TIMEOUT  per-scenario timeout in seconds (default: 180)

set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
export MDANCE_TESTS_DIR="$TESTS_DIR"

TCLSH="${TCLSH:-}"
if [ -z "$TCLSH" ]; then
    if command -v tclsh8.6 >/dev/null 2>&1; then TCLSH=tclsh8.6; else TCLSH=tclsh; fi
fi
VMD="${VMD:-}"
if [ -z "$VMD" ]; then
    for c in "$HOME/software/VMD2.app/Contents/vmd2/bin/vmd" \
             /Applications/VMD*2.0*.app/Contents/vmd2/bin/vmd \
             /Applications/VMD*.app/Contents/vmd/vmd_MACOSX* ; do
        if [ -x "$c" ]; then VMD="$c"; break; fi
    done
fi
[ -z "$VMD" ] && VMD="vmd"
VMD_TIMEOUT="${VMD_TIMEOUT:-180}"

WHICH="${1:-all}"
fail=0

run_unit() {
    echo "########## UNIT TESTS ($TCLSH) ##########"
    for t in "$TESTS_DIR"/unit/test_*.tcl; do
        echo ">>> $(basename "$t")"
        "$TCLSH" "$t" || fail=1
        echo ""
    done
}

# run_vmd <script> : run a runtime scenario, echo its output, track failures.
# The harness writes results to MDANCE_TEST_OUT (a file we control) because
# VMD's stdout/Tk console is an unreliable place to read test output from.
run_vmd() {
    local script="$1" name vmdlog resfile rc
    name="$(basename "$script")"
    vmdlog="$(mktemp)"
    resfile="$(mktemp)"
    echo ">>> $name"
    if command -v timeout >/dev/null 2>&1; then
        MDANCE_TEST_OUT="$resfile" timeout "$VMD_TIMEOUT" \
            "$VMD" -dispdev text -eofexit -e "$script" >"$vmdlog" 2>&1
        rc=$?
    else
        MDANCE_TEST_OUT="$resfile" \
            "$VMD" -dispdev text -eofexit -e "$script" >"$vmdlog" 2>&1
        rc=$?
    fi
    cat "$resfile"
    if [ $rc -ne 0 ]; then
        echo "  !! VMD exited $rc (timeout/crash) -- last VMD log lines:"
        tail -15 "$vmdlog" | sed 's/^/     /'
        fail=1
    # Anchor on the field separators: a bare '0 failed' is also a substring of
    # '10 failed', '20 failed', ... so the unanchored form silently accepted a
    # scenario with 10+ failures as clean.
    elif ! grep -qE '\| 0 failed \|' "$resfile"; then
        echo "  !! no clean summary line found (scenario aborted early?) -- last VMD log lines:"
        tail -15 "$vmdlog" | sed 's/^/     /'
        fail=1
    fi
    rm -f "$vmdlog" "$resfile"
    echo ""
}

run_runtime() {
    echo "########## RUNTIME SCENARIOS ($VMD) ##########"
    python3 "$TESTS_DIR/fixtures/make_fixtures.py" >/dev/null 2>&1 || true
    for s in "$TESTS_DIR"/runtime/scenario_*.tcl; do
        run_vmd "$s"
    done
}

case "$WHICH" in
    unit)    run_unit ;;
    runtime) run_runtime ;;
    all)     run_unit; run_runtime ;;
    *) echo "usage: $0 [unit|runtime|all]"; exit 2 ;;
esac

echo "=================================================="
if [ $fail -eq 0 ]; then
    echo "ALL TESTS PASSED"
else
    echo "SOME TESTS FAILED"
fi
exit $fail
