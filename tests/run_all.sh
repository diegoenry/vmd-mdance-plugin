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
         hardening2_h3 hardening2_h4 groups; do
    run $t "$VMD" -dispdev text -e tests/test_$t.tcl < /dev/null
done
if [ -z "$NOGUI" ]; then
    rm -f "$OUT/gui.log"
    "$VMD" -dispdev win -e tests/test_gui.tcl < /dev/null > "$OUT/gui.vmd.log" 2>&1
    run gui grep -E '^(FAIL|SKIP|RESULT)' "$OUT/gui.log"
fi
exit $status
