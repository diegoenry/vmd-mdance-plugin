#!/bin/sh
# The end-to-end phases, each in a new VMD, in order: 1 and 2 in text
# mode, 3 and 4 in the window (they need a display). They use the real
# backend (MDANCE_CLI, MDANCE_LIB, else the CPP-MDANCE build beside the
# plugin) and MDANCE's runs (MDANCE_REF_RUNS); what the phases share, and
# timings.txt, go to $VMDANCE_OUT/e2e (tests/out/e2e).
#   cd <VMDance>; DISPLAY=:9 sh tests/e2e/run_e2e.sh
VMD=${VMD:-vmd}
OUT=${VMDANCE_OUT:-$(pwd)/tests/out}
export VMDANCE_OUT="$OUT"
mkdir -p "$OUT/e2e"
status=0
result() {
    name=$1; file=$2
    line=$(grep -E '^RESULT' "$file" | tail -1)
    if [ -z "$line" ]; then echo "$name: no result (crashed)"; status=1; return; fi
    echo "$name: $line"
    case "$line" in *"fails=0"*) ;; *) status=1; grep -E '^FAIL' "$file" ;; esac
    grep -E '^SKIP' "$file"
}
for p in 1_work 2_reopen; do
    "$VMD" -dispdev text -e tests/e2e/e2e_$p.tcl < /dev/null > "$OUT/e2e/$p.out" 2>&1
    result "e2e $p" "$OUT/e2e/$p.out"
done
if [ -n "$DISPLAY" ]; then
    rm -f "$OUT/e2e/window.log" "$OUT/e2e/window_reopen.log"
    "$VMD" -dispdev win -e tests/e2e/e2e_3_window.tcl < /dev/null > /dev/null 2>&1
    result "e2e 3_window" "$OUT/e2e/window.log"
    "$VMD" -dispdev win -e tests/e2e/e2e_4_window_reopen.tcl < /dev/null > /dev/null 2>&1
    result "e2e 4_window_reopen" "$OUT/e2e/window_reopen.log"
else
    echo "e2e 3_window, 4_window_reopen: no display (set DISPLAY)"
fi
echo "timings: $OUT/e2e/timings.txt"
exit $status
