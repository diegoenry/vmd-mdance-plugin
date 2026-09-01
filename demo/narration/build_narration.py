#!/usr/bin/env python3
"""Synthesize the walkthrough narration with Kokoro-82M.

    demo/.venv/bin/python demo/narration/build_narration.py [--voice af_heart]

Reads ``beats.json`` (produced by ``export_beats.tcl``), synthesizes one WAV per
beat into ``audio/``, and writes ``manifest.tcl`` -- a Tcl dict the demo engine
reads at run time to know how long each line of narration lasts.

The measured duration is the whole point of this file. The engine schedules the
plugin actions against the *real* length of each spoken line, so the voice and
the screen stay locked together no matter how a sentence is phrased.

Synthesis is content-addressed: a beat whose text is unchanged is not
re-synthesized, so editing one sentence rebuilds one file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
AUDIO = HERE / "audio"
BEATS = HERE / "beats.json"
MANIFEST = HERE / "manifest.tcl"
SAMPLE_RATE = 24000

# Words Kokoro's English G2P mangles, spelled the way it should be said. The
# narration is full of acronyms and algorithm names, and "MSD" read as a word
# instead of three letters is the difference between a demo and a joke.
PRONOUNCE = {
    "MDANCE": "em dance",
    "VMD": "V M D",
    "NANI": "nah-nee",
    "DIVINE": "divine",
    "HELM": "helm",
    "eQUAL": "e-qual",
    "PRIME": "prime",
    "iSIM": "eye sim",
    "MSD": "M S D",
    "RMSD": "R M S D",
    "CSV": "C S V",
    "PDB": "P D B",
    "DCD": "D C D",
    "GUI": "gooey",
    "CLI": "C L I",
    "Calinski-Harabasz": "Ka-lin-ski Ha-ra-bash",
    "Davies-Bouldin": "Davies Bould-in",
    "CompSim": "comp sim",
    "StratAll": "strat all",
    "StratReduced": "strat reduced",
    "DivSelect": "div select",
    "KmeansPP": "K means plus plus",
    "KMeans": "K means",
    "k-means": "K means",
    "n-ary": "en-ary",
    "CA": "C alpha",
    "Cα": "C alpha",
    "Å": " angstroms",
}


_PRONOUNCE_RE = None


def _pronounce_re():
    """One alternation of every replaceable token, longest first.

    Longest-first matters: a plain per-key ``str.replace`` would rewrite the
    "CA" inside "CALC" and the "MSD" inside "WeightedMSD", turning real words
    into gibberish. Matching once, with the longest key winning, cannot do that.
    """
    global _PRONOUNCE_RE
    if _PRONOUNCE_RE is None:
        keys = sorted(PRONOUNCE, key=len, reverse=True)
        # \b does not anchor against a token that starts or ends with a
        # non-word character (Å, Cα), so guard those with lookarounds on
        # word characters instead.
        parts = []
        for k in keys:
            esc = re.escape(k)
            left = r"(?<![A-Za-z0-9])" if k[0].isalnum() else ""
            right = r"(?![A-Za-z0-9])" if k[-1].isalnum() else ""
            parts.append(f"{left}{esc}{right}")
        _PRONOUNCE_RE = re.compile("|".join(parts))
    return _PRONOUNCE_RE


def spoken(text: str) -> str:
    """Rewrite a line into something the G2P front-end pronounces correctly."""
    return _pronounce_re().sub(lambda m: PRONOUNCE[m.group(0)], text)


def wav_duration(path: Path) -> float:
    with wave.open(str(path), "rb") as w:
        return w.getnframes() / float(w.getframerate())


def load_state(path: Path) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--voice", default="af_heart",
                    help="Kokoro voice (af_heart, bf_emma, ff_siwis are cached offline)")
    ap.add_argument("--speed", type=float, default=1.0, help="speaking rate multiplier")
    ap.add_argument("--force", action="store_true", help="re-synthesize every beat")
    ap.add_argument("--only", default=None,
                    help="only rebuild beats whose id starts with this prefix")
    ap.add_argument("--dry-run", action="store_true",
                    help="estimate durations from word count; write no audio")
    args = ap.parse_args()

    if not BEATS.exists():
        print(f"error: {BEATS} not found -- run export_beats.tcl first", file=sys.stderr)
        return 1

    data = json.loads(BEATS.read_text())
    scenes = data["scenes"]
    beats = [(s["id"], b) for s in scenes for b in s["beats"]]
    print(f"{len(scenes)} scenes, {len(beats)} beats")

    AUDIO.mkdir(parents=True, exist_ok=True)
    state_path = AUDIO / ".state.json"
    state = {} if args.force else load_state(state_path)

    def key_of(b):
        h = hashlib.sha256()
        h.update(spoken(b["say"]).encode("utf-8"))
        h.update(f"|{args.voice}|{args.speed}".encode("utf-8"))
        return h.hexdigest()[:16]

    todo = []
    for sid, b in beats:
        wav = AUDIO / f"{b['id']}.wav"
        if args.only and not b["id"].startswith(args.only):
            continue
        if state.get(b["id"]) == key_of(b) and wav.exists():
            continue
        todo.append((sid, b))

    if args.dry_run:
        print(f"dry run: would synthesize {len(todo)} beat(s)")
        write_manifest(scenes, dry_run=True)
        return 0

    if todo:
        print(f"synthesizing {len(todo)} beat(s) with voice={args.voice} "
              f"speed={args.speed} (of {len(beats)} total)")
        # Import late: loading torch + Kokoro costs ~60s, and a run where every
        # beat is already cached should not pay it.
        import numpy as np
        import soundfile as sf
        from kokoro import KPipeline

        t0 = time.time()
        pipeline = KPipeline(lang_code="a")
        print(f"  pipeline ready in {time.time() - t0:.1f}s")

        for i, (sid, b) in enumerate(todo, 1):
            text = spoken(b["say"])
            chunks = [np.asarray(audio) for _, _, audio in
                      pipeline(text, voice=args.voice, speed=args.speed)]
            if not chunks:
                print(f"  !! {b['id']}: Kokoro produced no audio", file=sys.stderr)
                return 2
            samples = np.concatenate(chunks)
            wav = AUDIO / f"{b['id']}.wav"
            sf.write(str(wav), samples, SAMPLE_RATE)
            state[b["id"]] = key_of(b)
            dur = len(samples) / SAMPLE_RATE
            print(f"  [{i:3d}/{len(todo)}] {b['id']:<28} {dur:6.2f}s")
            # Persist after every beat: a long build interrupted halfway should
            # not throw away everything it already synthesized.
            state_path.write_text(json.dumps(state, indent=1))
    else:
        print("every beat is already up to date")

    write_manifest(scenes)
    return 0


def tcl_quote(s: str) -> str:
    """Escape a string so it is safe inside a Tcl braced list element."""
    return (s.replace("\\", "\\\\")
             .replace("{", "\\{")
             .replace("}", "\\}")
             .replace("$", "\\$")
             .replace("[", "\\["))


def write_manifest(scenes, dry_run: bool = False) -> None:
    """Write manifest.tcl: beat id -> {file duration words}."""
    lines = [
        "# manifest.tcl - GENERATED by narration/build_narration.py. Do not edit.",
        "#",
        "# Maps each beat id to its synthesized narration and that narration's",
        "# measured duration in seconds. The engine paces the walkthrough off",
        "# these numbers, so they must come from the audio itself, never from an",
        "# estimate -- an estimate is how a demo ends up talking over itself.",
        "",
        "namespace eval ::demo::narration {",
        "    variable manifest",
        "    array unset manifest",
        "    array set manifest {}",
        "}",
        "",
    ]
    total = 0.0
    missing = 0
    for s in scenes:
        lines.append(f"# --- {s['id']}: {s['title']}")
        for b in s["beats"]:
            wav = AUDIO / f"{b['id']}.wav"
            words = len(b["say"].split())
            if wav.exists():
                dur = wav_duration(wav)
                rel = f"audio/{b['id']}.wav"
            else:
                # Fall back to a reading-rate estimate so the demo still runs
                # (silently) before the audio has been built.
                dur = max(1.5, words / 2.6)
                rel = ""
                missing += 1
            total += dur
            lines.append(
                f"set ::demo::narration::manifest({b['id']}) "
                f"{{file {{{tcl_quote(rel)}}} duration {dur:.3f} words {words}}}"
            )
        lines.append("")
    lines.append(f"# total narration: {total / 60.0:.1f} minutes across "
                 f"{sum(len(s['beats']) for s in scenes)} beats")
    MANIFEST.write_text("\n".join(lines) + "\n")
    kind = "estimated" if dry_run else "measured"
    print(f"wrote {MANIFEST.name}: {total/60.0:.1f} min total ({kind})"
          + (f", {missing} beat(s) without audio" if missing else ""))


if __name__ == "__main__":
    sys.exit(main())
