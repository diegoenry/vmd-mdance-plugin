# 01_setup.tcl - the Setup tab: what gets clustered, and why alignment comes first.

::demo::scene setup "Setting up the analysis" \
    "Molecule, atoms, frames, backend - and the one choice the plugin will not make for you"

::demo::setup {
    ::demo::close_plots
    ::demo::vmd::spin_stop
    ::demo::vmd::sweep_stop
    # Reload from disk, deliberately UNALIGNED. This chapter measures the
    # trajectory before and after fitting, so it has to start from raw
    # coordinates however it was reached -- replayed on its own, or after a
    # chapter that already aligned the molecule.
    ::demo::vmd::load_system [set ::demo::config::psf] [set ::demo::config::dcd] \
        [set ::demo::config::load_first] [set ::demo::config::load_last] \
        [set ::demo::config::load_step]
    ::demo::vmd::style_default
    ::demo::vmd::show_peptide 0
    ::demo::vmd::goto_frame 0
    # load_system deleted every molecule and made a new one, so the id the
    # plugin was pointed at is stale.
    ::demo::params mol_selection [::demo::vmd::molid] \
                   atom_selection "protein and name CA" \
                   frame_first 0 frame_last -1 frame_stride 1
    ::demo::tab setup
}

::demo::beat whatfor \
    -caption "Setup describes what gets clustered" \
    -say "The Setup tab does not cluster anything. It describes what gets clustered: which\
          molecule, which atoms, which frames. Every algorithm tab reads these settings, so you\
          set them once, here." \
    -tab setup \
    -spotlight .mdance.nb.setup \
    -hold 0.5

::demo::beat molecule \
    -caption "The molecule chooser lists what is loaded" \
    -say "First the molecule. The chooser lists the molecules VMD actually has open, each with its\
          frame count, so there is no guessing which one is in front. The small refresh beside it\
          is for the case VMD does not announce: more frames loaded into a molecule already listed." \
    -spotlight .mdance.nb.setup.mol.combo \
    -do { ::demo::param mol_selection [::demo::vmd::molid] } \
    -at 0.6f \
    -hold 0.5

::demo::beat selection \
    -caption "Atom selection: protein and name CA" \
    -say "Then the atom selection. Protein and name CA gives one atom per residue: three hundred\
          and fifty two of them, instead of five thousand three hundred and twenty nine. A much\
          smaller matrix, and backbone motion is what conformational clustering is usually about.\
          The line under the field counts the match as you type, so a typo shows itself immediately." \
    -spotlight .mdance.nb.setup.mol.sel \
    -do { ::demo::param atom_selection "protein and name CA" } \
    -at 0.35f \
    -hold 0.6

::demo::beat otherselection \
    -caption "The selection is the question you are asking" \
    -say "The selection is the question. Cluster the peptide's own alpha carbons instead, and you\
          are clustering binding modes rather than protein conformations. One hard rule: the\
          selection must contain the same atoms in every frame." \
    -spotlight .mdance.nb.setup.mol.sel \
    -do { ::demo::vmd::show_peptide 1 } \
    -at 0.25f \
    -hold 0.8

::demo::beat nosuperposition \
    -caption "MDANCE compares raw coordinates" \
    -say "Now the choice that matters most, and the plugin will not make it for you. MDANCE's MSD\
          compares raw coordinates. There is no superposition step anywhere in the backend. Two\
          identical structures in different orientations look completely different to it." \
    -do {
        set _rms [::demo::vmd::rmsd_range "protein and name CA" 25]
        ::demo::note [format \
            "Unaligned CA RMSD vs frame 0: min %.2f, max %.2f, mean %.2f A" \
            [lindex $_rms 0] [lindex $_rms 1] [lindex $_rms 2]]
    } \
    -at 0.7f \
    -hold 0.8

::demo::beat tumbling \
    -caption "Most of this motion is tumbling, not folding" \
    -say "Here is the trajectory exactly as it came off the disk. The protein is tumbling in the\
          box. Measured against frame zero, the alpha carbon RMSD reaches about eight angstroms,\
          and nearly all of that is rotation. Cluster it like this and you cluster the tumbling." \
    -do {
        ::demo::vmd::show_peptide 0
        ::demo::vmd::sweep_frames 0 300 7.0
    } \
    -at 0.15 \
    -hold 0.6

::demo::beat dofit \
    -caption "Fit every frame onto frame zero, in VMD" \
    -say "So align it first, in VMD, before you cluster anything. Fit every frame onto frame zero\
          on those same alpha carbons. The same measurement now tops out under one and a half\
          angstroms, and what is left is real conformational change." \
    -do {
        ::demo::vmd::sweep_stop
        # align walks all thousand frames and blocks for about a second. Doing
        # it in one -do keeps that pause inside a beat that is explaining it.
        ::demo::vmd::align "protein and name CA"
        set _rms [::demo::vmd::rmsd_range "protein and name CA" 25]
        ::demo::note [format \
            "Aligned CA RMSD vs frame 0: min %.2f, max %.2f, mean %.2f A" \
            [lindex $_rms 0] [lindex $_rms 1] [lindex $_rms 2]]
        ::demo::vmd::sweep_frames 0 300 5.0
    } \
    -at 0.3f \
    -hold 1.2

::demo::beat checks \
    -caption "Both counts are live: atoms, and frames" \
    -say "Nothing here has to be asked for. The line under the selection reports how many atoms it\
          matches, and the line below the frame range reports how many frames the range keeps.\
          Between them you know exactly what the backend is about to receive, before you run it." \
    -spotlight {.mdance.nb.setup.mol.status .mdance.nb.setup.frames.info} \
    -do {
        ::demo::vmd::sweep_stop
        ::demo::vmd::goto_frame 0
        ::demo::note "Selection: [.mdance.nb.setup.mol.status cget -text]"
        ::demo::note "Frames: [.mdance.nb.setup.frames.info cget -text]"
    } \
    -at 0.55f \
    -hold 1.2

::demo::beat framerange \
    -caption "Frame Range: first, last, stride" \
    -say "Underneath is the frame range. First and last trim the trajectory, which is how you drop\
          an equilibration segment before it distorts the clustering. Minus one for last simply\
          means the final frame." \
    -spotlight .mdance.nb.setup.range \
    -do { ::demo::params frame_first 0 frame_last -1 } \
    -at 0.55f \
    -hold 0.5

::demo::beat stride \
    -caption "Stride 10 keeps every tenth frame" \
    -say "Stride decimates. Set it to ten and the count below updates on its own: a thousand frames\
          becomes a hundred. On a long, densely sampled run that is often plenty, and it makes the\
          expensive plots much quicker to draw." \
    -spotlight {.mdance.nb.setup.range.stride .mdance.nb.setup.frames.info} \
    -do {
        ::demo::param frame_stride 10
        # The readout is debounced by 200 ms, so read it after that has landed.
        after 400 {::demo::note "Stride 10 -> [.mdance.nb.setup.frames.info cget -text]"}
    } \
    -at 0.45f \
    -hold 1.4

::demo::beat framenumbers \
    -caption "A subset still reports true VMD frame numbers" \
    -say "Back to one for this walkthrough. Whatever subset you pick, everything downstream reports\
          true VMD frame numbers: the colouring, Go to Representative, every plot axis, every\
          export. Never a position inside the subset." \
    -spotlight .mdance.nb.setup.range.note \
    -do { ::demo::param frame_stride 1 } \
    -at 0.2f \
    -hold 0.8

::demo::beat backend \
    -caption "Backend: native library, or the command line" \
    -say "Where the clustering actually runs is in Settings, under the gear, because it is a\
          property of the machine rather than of the analysis. Library mode loads a native\
          extension straight into VMD. CLI mode writes a CSV and runs the command line binary as a\
          subprocess. This walkthrough uses CLI mode, because a subprocess run streams its progress\
          and can be cancelled." \
    -do {
        ::mdance::gui::settings_dialog
        ::demo::note "Backend: [.mdance_settings.backend.mode_value cget -text] -\
                      [.mdance_settings.backend.status cget -text]"
    } \
    -at 0.5f \
    -hold 1.0

::demo::beat fonts \
    -caption "Display Settings, for projectors" \
    -say "Display Settings is small but worth knowing. App font size scales the plugin's own text.\
          Plot font size sets the starting size for every plot window you open afterwards. Turn\
          both up before you present." \
    -spotlight .mdance_settings.display \
    -do {
        # The spinbox's -command fires on a click, not on a write to its
        # -textvariable, so the font has to be applied by hand here.
        ::demo::param app_font_size 12
        ::mdance::gui::apply_app_font
        set ::mdance::plots::plot_font_size 12
    } \
    -at 0.5f \
    -hold 1.2

::demo::beat handoff \
    -caption "Setup done; on to the methods" \
    -say "That is Setup. A molecule, an atom selection, a frame range, an aligned trajectory and a\
          live backend. Everything from here is just choosing an algorithm, and KMeans is next." \
    -do {
        catch {destroy .mdance_settings}
        ::demo::param app_font_size 10
        ::mdance::gui::apply_app_font
        set ::mdance::plots::plot_font_size 10
    } \
    -at 0.6f \
    -hold 0.4

::demo::teardown {
    ::demo::vmd::sweep_stop
    ::demo::vmd::show_peptide 0
    catch {destroy .mdance_settings}
    # Restore the fonts even if the chapter was cut short before `handoff`.
    ::demo::param app_font_size 10
    ::mdance::gui::apply_app_font
    set ::mdance::plots::plot_font_size 10
}
