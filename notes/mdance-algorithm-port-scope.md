---
name: mdance-algorithm-port-scope
description: Which MDANCE algorithms are ported to CPP-MDANCE and why SHINE / PRISM are not
metadata:
  type: project
---

CPP-MDANCE clustering algorithms map onto a single VMD molecule's coordinate matrix (nframes x 3*natoms). When porting upstream MDANCE methods, this data model decides feasibility:

- **eQUAL** (`src/cluster/equal.{h,cpp}`, `--algorithm equal`, `::mdance::equal`, eQUAL GUI tab): ported. It IS MDANCE's density/quality n-ary clustering on a coordinate matrix; cluster count emerges from a radial `threshold` (no k). Only the deterministic seed methods (`medoid`, `comp_sim`) are supported — sklearn greedy/vanilla/mini_batch_kmeans are rejected at the parse layer. Member removal is by frame index (not value-equality). `align` uni/kron are unimplemented (`alignTraj` is a None-only no-op stub). reject_lowd defaults OFF (flag convention), unlike upstream's constructor.
- **PRIME** (`src/cluster/prime.{h,cpp}`, `--prime`, `::mdance::prime`, PRIME GUI tab): ported as an analysis over existing labels. CRITICAL convention: PRIME uses esim.py's RR_nw/SM_nw raw *similarity* (computed via `calculateCounters` with wFactor=0, NOT `extendedComparison` which returns a dissimilarity here), and medoid=argMIN / outlier=argMAX of complementary similarity — the MIRROR of bts.cpp's `calculateMedoid/Outlier` (argMAX/argMIN on MSD-distance). Do not reuse the bts medoid/outlier helpers for PRIME. Metric restricted to RR/SM. Global scalar min-max normalize; c0 = most-populated cluster.
- **SHINE**: NOT ported. It clusters *whole trajectories* against each other (a list of variable-length trajectories + per-frame traj_ids segmentation) and needs Ward-linkage-from-a-distance-matrix (no such primitive) and emits per-trajectory labels — incompatible with the single-molecule, per-frame-label model.
- **PRISM / CADENCE**: NOT ported. No public reference implementation exists in the MDANCE repo (CADENCE is paper-only); the density-on-coordinates algorithm in MDANCE is eQUAL.

See [[mdance-capi-visibility-and-library-mode]] and [[vmd-headless-verification]].
