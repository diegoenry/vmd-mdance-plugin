#!/bin/bash
# bootstrap.sh - create the demo's Python environment and build the narration.
#
#   ./demo/bootstrap.sh
#
# Installs Kokoro-82M (an 82-million-parameter neural text-to-speech model that
# runs locally on CPU) into demo/.venv, then synthesizes one WAV per narration
# beat. Nothing is sent anywhere: the model weights are pulled from Hugging Face
# once and cached under ~/.cache/huggingface.

set -euo pipefail
DEMO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$DEMO_ROOT"

PY_VERSION="${PY_VERSION:-3.12}"

echo "==> creating virtual environment (python $PY_VERSION)"
if command -v uv >/dev/null 2>&1; then
    uv venv --python "$PY_VERSION" .venv
    # shellcheck disable=SC1091
    source .venv/bin/activate
    uv pip install "kokoro>=0.9.4" soundfile
else
    echo "    uv not found, falling back to python -m venv"
    "python$PY_VERSION" -m venv .venv
    # shellcheck disable=SC1091
    source .venv/bin/activate
    pip install --upgrade pip
    pip install "kokoro>=0.9.4" soundfile
fi

# Kokoro's English front-end falls back to espeak-ng for words its dictionary
# does not cover -- which, in a script full of algorithm names, is a lot of them.
if ! command -v espeak-ng >/dev/null 2>&1; then
    echo ""
    echo "    NOTE: espeak-ng is not installed. Kokoro will still work, but"
    echo "    out-of-dictionary words may be mispronounced."
    echo "    macOS: brew install espeak-ng"
fi

echo ""
echo "==> exporting narration script from the scene files"
"${TCLSH:-tclsh8.6}" narration/export_beats.tcl narration/beats.json

echo ""
echo "==> synthesizing narration (first run downloads the model, ~330 MB)"
.venv/bin/python narration/build_narration.py "$@"

echo ""
echo "Done. Launch the walkthrough with:"
echo "    ./demo/run_demo.sh"
