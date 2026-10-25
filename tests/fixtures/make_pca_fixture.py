#!/usr/bin/env python3
"""The principal components of the two_state fixture's frames, by numpy:
the reference test_groups checks the plugin's map against (its own PCA,
in Tcl, by classical scaling and subspace iteration).

The frames as the plugin clusters them without a fit: every atom's x y z,
as written in the PDB. Writes pca_two_state.txt: the two axes' shares of
the variance, then each frame's two scores (Å), each axis's sign the one
that makes its largest score positive, as the plugin's.

    cd tests/fixtures && python3 make_pca_fixture.py      (numpy)
"""
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))

frames, cur = [], []
for line in open(os.path.join(HERE, "two_state.pdb")):
    if line.startswith("ATOM"):
        cur.append([float(line[30:38]), float(line[38:46]), float(line[46:54])])
    elif line.startswith("ENDMDL"):
        frames.append(cur)
        cur = []
X = np.array(frames).reshape(len(frames), -1)
X = X - X.mean(0)
u, s, _ = np.linalg.svd(X, full_matrices=False)
scores = u[:, :2] * s[:2]
for k in range(2):
    if scores[np.argmax(np.abs(scores[:, k])), k] < 0:
        scores[:, k] *= -1
share = (s ** 2 / (s ** 2).sum())[:2]
with open(os.path.join(HERE, "pca_two_state.txt"), "w") as f:
    f.write("# the two axes' shares of the variance, then each frame's PC1 PC2 (numpy: make_pca_fixture.py)\n")
    f.write(f"{share[0]:.10f} {share[1]:.10f}\n")
    for a, b in scores:
        f.write(f"{a:.8f} {b:.8f}\n")
print("wrote pca_two_state.txt")
