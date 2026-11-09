#!/bin/sh
# Every test suite, one after the other, and their results. A suite that
# prints no RESULT line (it crashed, or VMD did) counts as failed.
#   cd <VMDance>; sh tests/run_all.sh          (VMD: $VMD, or vmd)
#   NOGUI=1 sh tests/run_all.sh                    (without the window)
# The windowed suite needs a display: on a machine without one,
#   Xephyr :9 -screen 1600x1200x24 -ac &   (or Xvfb :9 -screen 0 1600x1200x24 &)
#   DISPLAY=:9 sh tests/run_all.sh
VMD=${VMD:-vmd}
OUT=${VMDANCE_OUT:-$(pwd)/tests/out}
mkdir -p "$OUT"
export VMDANCE_OUT="$OUT"
status=0
run() {
    name=$1; shift
    line=$("$@" 2>&1 | grep -E '^(FAIL|SKIP|RESULT)' | tee "$OUT/$name.result" | grep RESULT | tail -1)
    if [ -z "$line" ]; then
        echo "$name: no result (crashed)"; status=1
    else
        echo "$name: $line"
        case "$line" in *"fails=0"*) ;; *) status=1; grep FAIL "$OUT/$name.result" ;; esac
        grep SKIP "$OUT/$name.result"
    fi
}
run core-tclsh tclsh tests/test_core.tcl
# (and the second round's fixes, a suite each: tests/test_hardening2_<group>.tcl)
for t in core jobs results session reference hardening hardening2 \
         hardening2_fx_g1 hardening2_fx_g2 hardening2_fx_g3 hardening2_fx_g4 hardening2_fx_g5 \
         hardening2_g6 hardening2_g7 hardening2_g8 hardening2_g9 hardening2_h1 hardening2_oi \
         hardening2_h3 hardening2_h4 groups ux; do
    # (sourced by strict.tcl: an error at a suite's top level ends it, as a
    # failure; run with -e, VMD goes on after it)
    run $t "$VMD" -dispdev text -e tests/strict.tcl -args tests/test_$t.tcl < /dev/null
done
# (the windowed suites write their lines to a log of their own: windowed
# VMD does not reliably show its standard output)
if [ -z "$NOGUI" ]; then
    for t in gui ux_gui ux_layout; do
        [ -f tests/test_$t.tcl ] || continue
        rm -f "$OUT/$t.log"
        "$VMD" -dispdev win -e tests/test_$t.tcl < /dev/null > "$OUT/$t.vmd.log" 2>&1
        run $t grep -E '^(FAIL|SKIP|RESULT)' "$OUT/$t.log"
    done
fi
exit $status
