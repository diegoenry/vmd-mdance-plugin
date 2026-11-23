# VMDance quick start: a tau peptide, from its frames to its clusters.
# In the folder that holds aligned_tau.pdb and aligned_original_tau_6K.dcd
# (BitQT's examples: https://github.com/LQCT/BitQT/tree/master/examples):
#   vmd -dispdev text -e quickstart.tcl
# or paste it, a line at a time, into VMD's console.
package require vmdance

# 1. Load the trajectory. The PDB is the topology: it names the atoms. Its
#    coordinates come in as frame 0, which is not part of the trajectory:
#    load the DCD into the same molecule, then delete that first frame.
set m [mol new aligned_tau.pdb waitfor all]
mol addfile aligned_original_tau_6K.dcd waitfor all molid $m
animate delete beg 0 end 0 $m          ;# 6001 frames left, the DCD's

# 2. The atoms: the backbone of residues 3 to 12, N CA C O and H
set sel "resid 3 to 12 and name N CA C O H"

# 3. Fit every frame to frame 999 on those atoms (VMD's coordinates move)
set fitframe 999
set ref [atomselect $m $sel frame $fitframe]
set fit [atomselect $m $sel]
set all [atomselect $m all]
for {set f 0} {$f < [molinfo $m get numframes]} {incr f} {
    $fit frame $f
    $all frame $f
    $all move [measure fit $fit $ref]
}
$ref delete; $fit delete; $all delete
puts [vmdance alignment -mol $m -sel $sel]   ;# do the frames look superposed?

# 4. How many clusters? The scores at k 2 to 12, and whether the
#    clusters change with NANI's seeding (-stability 1)
vmdance elbow -mol $m -sel $sel -kinit CompSim -from 2 -to 12 -stability 1
puts [dict get [vmdance elbow suggest] words]

# 5. Cluster: k 6, as MDANCE's own tutorial does (the scan says how far
#    the four seedings agree on its clusters)
set k 6
vmdance elbow load $k
for {set c 0} {$c < $k} {incr c} {
    set d [vmdance get $c]
    puts "cluster $c: [dict get $d frames] frames,\
          representative frame [dict get $d representative]"
}
puts "mean silhouette: [dict get [vmdance silhouette] mean]"

# 6. Has the run converged? Its two halves, cluster by cluster. Then the
#    frames on their first two principal components, and the RMSF of each
#    cluster and each half, residue by residue
vmdance groups -blocks 2
puts [vmdance makeup]
puts [dict get [vmdance groups compare] words]
vmdance map
vmdance profiles

# 7. A second opinion: the same frames clustered by DIVINE, HELM and eQual,
#    and a sweep of three algorithms and two seedings at k 2 to 8
vmdance -mol $m -sel $sel -algorithm divine -k $k
vmdance -mol $m -sel $sel -algorithm helm -k $k -initial 60
vmdance -mol $m -sel $sel -algorithm equal -threshold 8
foreach r [vmdance runs] { puts $r }
vmdance sweep -mol $m -sel $sel -algorithms {kmeans divine helm} -from 2 -to 8 \
    -seedings {StratAll CompSim}
puts [vmdance sweep best db]

# 8. Keep it: back to run 1, then its tables, and the session
vmdance run 1
vmdance export tau_results -prefix tau
vmdance session save tau.vmdance
# (the plots as figures need VMD's window: vmd -e, not -dispdev text)
#   vmdance figures figures -formats {pdf png} -size column
quit
