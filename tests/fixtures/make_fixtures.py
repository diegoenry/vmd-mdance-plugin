#!/usr/bin/env python3
"""Generate small multi-model PDB trajectories used by the runtime tests.

Deterministic (fixed seed) so assertions are reproducible. CA-only chains keep
the files tiny while still being valid VMD-loadable structures.
"""
import os, math, random

HERE = os.path.dirname(os.path.abspath(__file__))


def atom(serial, resseq, x, y, z):
    return (f"ATOM  {serial:>5}  CA  ALA A{resseq:>4}    "
            f"{x:8.3f}{y:8.3f}{z:8.3f}  1.00  0.00           C")


def write_pdb(name, frames):
    """frames: list of list-of-(x,y,z) tuples, one per model."""
    lines = []
    for m, coords in enumerate(frames, start=1):
        lines.append(f"MODEL     {m:>4}")
        for i, (x, y, z) in enumerate(coords):
            lines.append(atom(i + 1, i + 1, x, y, z))
        lines.append("ENDMDL")
    lines.append("END")
    path = os.path.join(HERE, name)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {path} ({len(frames)} models x {len(frames[0])} atoms)")


def chain(base, jitter, rng, natoms):
    return [(base + i * 1.5 + rng.uniform(-jitter, jitter),
             2.0 + rng.uniform(-jitter, jitter),
             3.0 + 0.3 * i + rng.uniform(-jitter, jitter)) for i in range(natoms)]


def main():
    rng = random.Random(20260629)

    # two_state: 24 frames, 8 atoms. Frames 0-11 near state A (base 0), 12-23
    # near state B (base 10). A k=2 clustering separates them cleanly.
    natoms = 8
    frames = []
    for m in range(24):
        base = 0.0 if m < 12 else 10.0
        frames.append(chain(base, 0.15, rng, natoms))
    write_pdb("two_state.pdb", frames)

    # outlier: 12 frames, 6 atoms, frame 6 is a large outlier.
    natoms = 6
    frames = []
    for m in range(12):
        base = 0.0 if m != 6 else 50.0
        frames.append(chain(base, 0.1, rng, natoms))
    write_pdb("outlier.pdb", frames)

    # single_state: 10 frames, 5 atoms, all near one conformation (effectively
    # one cluster -> exercises degenerate k=1 / NaN-score handling).
    natoms = 5
    frames = [chain(0.0, 0.1, rng, natoms) for _ in range(10)]
    write_pdb("single_state.pdb", frames)


if __name__ == "__main__":
    main()
