Citing
======

The clustering is MDANCE's, run by CPP-MDANCE; VMDance brings it into VMD.
When you publish clusters made with the plugin, cite the algorithms you
used, MDANCE, and VMD; and say which backend made them (CPP-MDANCE, and
its version: the exported tables' headers name the program or library).

The algorithms
--------------

- **KMeans NANI** — L. Chen, D. R. Roe, M. Kochert, C. Simmerling,
  R. A. Miranda-Quintana. k-Means NANI: An Improved Clustering Algorithm for
  Molecular Dynamics Simulations. *J. Chem. Theory Comput.* **2024**, 20,
  5583–5597. https://doi.org/10.1021/acs.jctc.4c00308
- **HELM** — L. Chen, J. B. W. Santos, J. Gaza, A. Perez,
  R. A. Miranda-Quintana. Hierarchical Extended Linkage Method (HELM)'s Deep
  Dive into Hybrid Clustering Strategies. *J. Chem. Inf. Model.* **2025**,
  65, 6209–6220. https://doi.org/10.1021/acs.jcim.5c00539
- **eQUAL** — L. Chen, M. Smith, D. R. Roe, R. A. Miranda-Quintana. Extended
  Quality (eQual): Radial Threshold Clustering Based on n-ary Similarity.
  *J. Chem. Inf. Model.* **2025**, 65, 5062–5070.
  https://doi.org/10.1021/acs.jcim.4c02341
- **DIVINE** — J. B. W. Santos, L. Chen, R. A. Miranda-Quintana. Divide and
  Cluster: The DIVINE Framework for Deterministic Top-Down Analysis of
  Molecular Dynamics Trajectories. *bioRxiv* **2025**.
  https://doi.org/10.1101/2025.06.20.660828
- **PRIME** — L. Chen, A. Mondal, A. Perez, R. A. Miranda-Quintana. Protein
  Retrieval via Integrative Molecular Ensembles (PRIME) through Extended
  Similarity Indices. *J. Chem. Theory Comput.* **2024**, 20, 6303–6315.
  https://doi.org/10.1021/acs.jctc.4c00362
- **iSIM** — K. López-Pérez, T. D. Kim, R. A. Miranda-Quintana. iSIM:
  Instant Similarity. *Digital Discovery* **2024**, 3, 1160–1171.
  https://doi.org/10.1039/d4dd00041b
- **Extended similarity** — R. A. Miranda-Quintana et al. Extended
  Similarity Indices: The Benefits of Comparing More than Two Objects
  Simultaneously, Parts 1 and 2. *J. Cheminf.* **2021**.
  https://doi.org/10.1186/s13321-021-00505-3,
  https://doi.org/10.1186/s13321-021-00504-4

The software
------------

- **MDANCE** — L. Chen, R. A. Miranda-Quintana. MDANCE: Flexible and
  Versatile N-ary Clustering Package. *Biophys. J.* **2025**, 124, 485a.
  https://doi.org/10.1016/j.bpj.2024.11.2557;
  https://github.com/mqcomplab/MDANCE
- **CPP-MDANCE** — the C++ implementation of MDANCE that runs the
  clustering: https://github.com/mqcomplab/CPP-MDANCE
- **VMD** — W. Humphrey, A. Dalke, K. Schulten. VMD: Visual Molecular
  Dynamics. *J. Mol. Graphics* **1996**, 14, 33–38.
  https://doi.org/10.1016/0263-7855(96)00018-5
- **VMDance** — https://github.com/diegoenry/vmd-mdance-plugin (an
  application note is in preparation).

The scores
----------

Calinski–Harabasz (*Commun. Stat.* **1974**,
https://doi.org/10.1080/03610927408827101), Davies–Bouldin (*IEEE Trans.
Pattern Anal. Mach. Intell.* **1979**,
https://doi.org/10.1109/TPAMI.1979.4766909), the silhouette (*J. Comput.
Appl. Math.* **1987**, https://doi.org/10.1016/0377-0427(87)90125-7), and,
for the stability, the adjusted Rand index (L. Hubert, P. Arabie,
*J. Classif.* **1985**, https://doi.org/10.1007/BF01908075).
