# Runtime scenario: the dendrogram must handle HELM's Z-matrix, which is a
# FOREST rather than a single tree.
#
# HELM stops merging once it has nClusters groups, so with nClusters >= 2 the
# merge structure has nClusters roots. The layout used to start from node
# (nLeaves + nMerges - 1) as if it were THE root, so every other tree's leaves
# never got an x position and the leaf-label loop died with
# `can't read "node_x(0)"` -- for the normal HELM case, not an exotic one.
source [file join $::env(MDANCE_TESTS_DIR) runtime _setup.tcl]

# A HELM-shaped result. nLeaves = nMerges + nClusters, ids: leaves 0..nLeaves-1,
# then one internal node per merge.
proc helm_result {nclusters zmatrix labels sizes reps} {
    return [dict create \
        algorithm helm nClusters $nclusters nFrames [llength $labels] \
        labels $labels clusterSizes $sizes representatives $reps \
        clusterMSD [lrepeat $nclusters 0.1] \
        zMatrix $zmatrix]
}

# ------------------------------------------------------------------
th::section "HELM dendrogram: a forest of trees renders"
# ------------------------------------------------------------------

th::test "two separate trees (nClusters=2): every leaf gets laid out" {
    # 4 leaves, 2 merges -> roots are nodes 4 (0+1) and 5 (2+3).
    th::ok {
        ::mdance::plots::dendrogram \
            [helm_result 2 {{0 1 0.5 2} {2 3 0.7 2}} {0 0 1 1} {2 2} {0 2}]
    }
    catch {destroy .mdance_dendro}
}

th::test "a forest with unmerged single-leaf trees (nClusters=3)" {
    # 4 leaves, 1 merge -> roots are node 4 (0+1) plus bare leaves 2 and 3.
    th::ok {
        ::mdance::plots::dendrogram \
            [helm_result 3 {{0 1 0.5 2}} {0 0 1 2} {2 1 1} {0 2 3}]
    }
    catch {destroy .mdance_dendro}
}

th::test "the single-root case (nClusters=1) still renders" {
    # 3 leaves, 2 merges -> node 3 = (0,1), node 4 = (3,2): one root.
    th::ok {
        ::mdance::plots::dendrogram \
            [helm_result 1 {{0 1 0.5 2} {3 2 0.9 3}} {0 0 0} {3} {0}]
    }
    catch {destroy .mdance_dendro}
}

th::test "a deeper forest: two balanced trees of four leaves each" {
    # 8 leaves, 6 merges, nClusters=2.
    set z {{0 1 0.2 2} {2 3 0.3 2} {8 9 0.6 4}
           {4 5 0.25 2} {6 7 0.35 2} {11 12 0.7 4}}
    th::ok {
        ::mdance::plots::dendrogram \
            [helm_result 2 $z {0 0 0 0 1 1 1 1} {4 4} {0 4}]
    }
    catch {destroy .mdance_dendro}
}

# ------------------------------------------------------------------
th::section "The centroid-linkage dendrogram (non-HELM) is unaffected"
# ------------------------------------------------------------------
set mol [load_fixture two_state.pdb]
set params [dict create molid $mol atomsel "name CA" nclusters 3 metric MSD \
    kinit CompSim percentage 10 first 0 last -1 stride 1]
set r [::mdance::run_clustering kmeans $params]

th::test "a real clustering still builds its dendrogram from centroid distances" {
    th::false [dict exists $r zMatrix] "this path must not have a backend zMatrix"
    th::ok { ::mdance::plots::dendrogram $::mdance::results }
    catch {destroy .mdance_dendro}
}

exit [th::done "runtime:dendrogram"]
