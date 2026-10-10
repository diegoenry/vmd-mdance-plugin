"""MDANCE's own labels of 3ptb's Calpha atoms, for the reference suite
(tests/fixtures/mdance_3ptb.txt): MDANCE 0.4's KmeansNANI and Divine on the
plugin's own coordinates (the CSVs make_mdance_3ptb.tcl writes), so that
test_reference compares the plugin with MDANCE where CPP-MDANCE is known to
differ (a stratified seed's position on a half; DIVINE's smallest share,
rounded where MDANCE truncates) and where it agrees.
    python make_mdance_3ptb.py all.csv first50.csv out.txt
"""
import sys
import warnings

import numpy as np
from mdance.cluster.divine import Divine
from mdance.cluster.nani import KmeansNANI

csv_all, csv_50, out = sys.argv[1:4]
X = np.loadtxt(csv_all, delimiter=",")
X50 = np.loadtxt(csv_50, delimiter=",")
N = X.shape[1] // 3
warnings.simplefilter("ignore")

cases = []
# KMeans NANI, StratAll 10%, k 4 on frames 0-49: the third stratified
# position is 24.5 (rounded half to even by NumPy, away from zero by C++)
labels, _, _ = KmeansNANI(data=X50, n_clusters=4, metric="MSD", N_atoms=N,
                          init_type="strat_all", percentage=10).execute_kmeans_all()
cases.append(("kmeans_first50_k4", labels))
# DIVINE with the plugin's defaults (NANI anchors, StratAll 10%), unrefined
# (MDANCE's NANI splits do not read refine)
for k in (4, 5):
    labels = Divine(X, split="weighted_MSD", anchors="nani", init_type="strat_all", end="k", k=k,
                    refine=False, N_atoms=N, threshold=0, percentage=10).run()[1]
    cases.append((f"divine_k{k}", labels))
# the pair anchors, unrefined, with a smallest share: 0.3 of 100 frames is
# 30 for both; 0.035 is 3 frames for MDANCE (int), 4 for CPP-MDANCE (round)
for name, anchors, t, end, k in (("divine_outlier_t0.3_k6", "outlier_pair", 0.3, "k", 6),
                                 ("divine_splinter_t0.035_k6", "splinter_split", 0.035, "k", 6),
                                 ("divine_outlier_t0.2_points", "outlier_pair", 0.2, "points", None)):
    labels = Divine(X, split="weighted_MSD", anchors=anchors, init_type="strat_all", end=end, k=k,
                    refine=False, N_atoms=N, threshold=t, percentage=10).run()[1]
    cases.append((name, labels))

with open(out, "w") as f:
    f.write("# MDANCE's own labels of 3ptb's Calpha atoms (VMD-testsystems: 100 frames,\n"
            "# 223 atoms), on the plugin's coordinates, with MDANCE 0.4: a case, then its\n"
            "# labels in the order of the rows clustered. Written by\n"
            "# tests/fixtures/make_mdance_3ptb.tcl; read by tests/test_reference.tcl.\n")
    for name, labels in cases:
        f.write(name + " " + " ".join(str(int(v)) for v in labels) + "\n")
