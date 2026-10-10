#
# VMDance - colour palettes for the plots
#
# Every colour scale of the plots can use any palette. Palettes are grouped
# as sequential (low to high), diverging (around a middle), cyclic (the ends
# meet) and qualitative (distinct colours: series). A name
# with "_r" is the palette reversed. Continuous values use the colours
# interpolated (qualitative palettes in steps); categories use them in turn
# (continuous palettes sampled evenly).
#

namespace eval ::VMDance::Cmap {
    variable lut
    variable swatches
    variable categories {sequential Sequential diverging Diverging cyclic Cyclic qualitative Qualitative}
    # name {category label colours}; the continuous ones from matplotlib
    # 3.10 (17 samples, 24 for the cyclic ones) or the plugin's own
    variable palettes {
        viridis          {sequential {Viridis} {#440154 #48186a #472d7b #424086 #3b528b #33638d #2c728e #26828e #21918c #1fa088 #28ae80 #3fbc73 #5ec962 #84d44b #addc30 #d8e219 #fde725}}
        cividis          {sequential {Cividis} {#00224e #002e6a #1a386f #32436d #434e6c #535a6d #61656f #6f7073 #7d7c78 #8c8878 #9b9476 #aba072 #bcae6c #cdbb63 #dec958 #f0d846 #fee838}}
        magma            {sequential {Magma} {#000004 #0a0822 #1d1147 #36106b #51127c #6a1c81 #832681 #9c2e7f #b73779 #d0416f #e75263 #f56b5c #fc8961 #fea772 #fec488 #fde2a3 #fcfdbf}}
        inferno          {sequential {Inferno} {#000004 #0b0724 #210c4a #3d0965 #57106e #71196e #8a226a #a32c61 #bc3754 #d24644 #e45a31 #f1731d #f98e09 #fcac11 #f9cb35 #f2ea69 #fcffa4}}
        plasma           {sequential {Plasma} {#0d0887 #310597 #4c02a1 #6600a7 #7e03a8 #9511a1 #aa2395 #bc3587 #cc4778 #da5a6a #e66c5c #f0804e #f89540 #fdac33 #fdc527 #f8df25 #f0f921}}
        lightblues       {sequential {Light blues} {#ffffff #eef3fa #c9dcef #93bfe0 #5a9bcf #2f72b3 #174a86}}
        blues            {sequential {Blues} {#f7fbff #eaf3fb #deebf7 #d2e3f3 #c6dbef #b2d2e8 #9dcae1 #84bcdb #6aaed6 #56a0ce #4191c6 #3181bd #2070b4 #1460a8 #08509b #084082 #08306b}}
        greys            {sequential {Greys} {#ffffff #f7f7f7 #f0f0f0 #e4e4e4 #d9d9d9 #cbcbcb #bdbdbd #a9a9a9 #959595 #848484 #727272 #626262 #515151 #3a3a3a #242424 #111111 #000000}}
        ylgnbu           {sequential {Yellow–green–blue} {#ffffd9 #f6fbc5 #edf8b1 #daf0b3 #c6e9b4 #a2dbb8 #7ecdbb #5fc1c0 #40b5c4 #2ea3c2 #1d90c0 #2076b3 #225da8 #24489d #243392 #162874 #081d58}}
        ylorrd           {sequential {Yellow–orange–red} {#ffffcc #fff6b6 #ffeda0 #fee38b #fed976 #fec561 #feb24c #fd9f44 #fd8c3c #fc6c33 #fc4d2a #ef3323 #e2191c #cf0c21 #bb0026 #9d0026 #800026}}
        bupu             {sequential {Blue–purple} {#f7fcfd #ebf4f8 #e0ecf4 #cfdfed #bfd3e6 #aec7e0 #9ebcda #95a8d0 #8c95c6 #8c80bb #8c6ab1 #8a55a7 #88409c #84278c #800f7b #650762 #4d004b}}
        bluered          {diverging {Blue–red} {#053061 #175290 #2a71b2 #3f8ec0 #6bacd1 #9bc9e0 #c2ddec #e0ecf3 #f7f6f6 #fbe5d8 #fbccb4 #f5aa89 #e48066 #d05548 #ba2832 #930e26 #67001f}}
        coolwarm         {diverging {Cool–warm} {#3b4cc0 #4e68d8 #6282ea #779af7 #8db0fe #a3c2fe #b9d0f9 #ccd9ed #dddcdc #ecd3c5 #f5c4ac #f7b093 #f4987a #eb7d62 #dd5f4b #ca3b37 #b40426}}
        purpleorange     {diverging {Purple–orange} {#2d004b #451871 #5f3a91 #7b6aa8 #9990bf #b7b1d5 #cfcfe5 #e4e5f0 #f7f7f6 #fce8cd #fed59f #fdbc6b #ee9b39 #d97b12 #bd6109 #9e4c07 #7f3b08}}
        brownteal        {diverging {Brown–teal} {#543005 #774508 #995d13 #b97b29 #cfa256 #e2c787 #f1dfb3 #f6edd7 #f4f5f5 #d7eeeb #b4e2db #87d0c5 #58b0a7 #2d8f87 #0c7169 #01554b #003c30}}
        pinkgreen        {diverging {Pink–green} {#8e0152 #b1116d #cb3289 #db6ca8 #e897c4 #f3bcdd #fad6ea #fbe9f2 #f7f7f6 #ecf6de #d9f0bc #bde38d #9acd61 #77b53c #589b28 #3d7f1e #276419}}
        purplegreen      {diverging {Purple–green} {#40004b #621a6e #7f3c8d #9568a6 #ae8bbd #c7abd2 #dec9e2 #ede2ee #f6f7f6 #e4f2e0 #cbeac5 #abdda5 #7ec37f #50a65a #298440 #10632b #00441b}}
        wells            {cyclic {Torsion wells} {#23305e #3f7fb5 #5aa66a #e9d98b #e58a3c #a8395a #23305e}}
        twilight         {cyclic {Twilight} {#e2d9e2 #d1d5da #b3c6ce #95b5c7 #7ba1c2 #6b8cbf #6276ba #5f5eb3 #5e43a5 #592a8f #4e186f #3d114d #2f1436 #3f123d #581647 #741e4f #8e2c50 #a24050 #b25652 #be6f5b #c68a6d #cca389 #d4bcac #ddd0ce #e2d9e2}}
        twilightshifted  {cyclic {Twilight, shifted} {#301437 #3d114d #4e186f #592a8f #5e45a6 #5f5eb3 #6276ba #6b8cbf #7ca2c2 #95b5c7 #b3c6ce #d1d5da #e2d9e2 #ddd0ce #d4bcac #cca389 #c6896c #be6f5b #b25652 #a24050 #8d2b50 #741e4f #581647 #3f123d #301437}}
        hue              {cyclic {Hue wheel} {#ff0000 #ff3b00 #ff7c00 #ffbd00 #fcf500 #c5ff00 #84ff00 #49ff00 #08ff00 #00ff39 #00ff74 #00ffb5 #00fff6 #00cdff #008cff #004bff #0010ff #3100ff #7200ff #ad00ff #ee00ff #ff00cf #ff0094 #ff0053 #ff0000}}
        vmdance       {qualitative {VMDance} {#4E79A7 #E15759 #59A14F #F28E2B #B07AA1 #76B7B2 #EDC948 #9C755F #FF9DA7 #BAB0AC}}
        tableau          {qualitative {Tableau 10} {#1f77b4 #ff7f0e #2ca02c #d62728 #9467bd #8c564b #e377c2 #7f7f7f #bcbd22 #17becf}}
        okabeito         {qualitative {Okabe–Ito} {#0072B2 #D55E00 #009E73 #E69F00 #CC79A7 #56B4E9 #F0E442 #000000}}
        set1             {qualitative {Set 1} {#e41a1c #377eb8 #4daf4a #984ea3 #ff7f00 #ffff33 #a65628 #f781bf #999999}}
        set2             {qualitative {Set 2} {#66c2a5 #fc8d62 #8da0cb #e78ac3 #a6d854 #ffd92f #e5c494 #b3b3b3}}
        dark2            {qualitative {Dark 2} {#1b9e77 #d95f02 #7570b3 #e7298a #66a61e #e6ab02 #a6761d #666666}}
        paired           {qualitative {Paired} {#a6cee3 #1f78b4 #b2df8a #33a02c #fb9a99 #e31a1c #fdbf6f #ff7f00 #cab2d6 #6a3d9a #ffff99 #b15928}}
    }
    # names of the first versions
    variable aliases {density lightblues diverging bluered cyclic wells}

    # Communities take VMD's colour ids, in this order (distinct colours
    # first; no white, black or silver), so that the plots show them in the
    # colours of the 3D view.
    variable community_ids {0 1 7 3 11 10 4 9 12 5 15 13 14 20 23 25 27 29 31 22 2 18 26 32 17 19 21 24 28 30}
    variable vmdrgb        ;# VMD colour id -> Tk colour, read once per session of the window
}

proc ::VMDance::Cmap::_hex2rgb {h} {
    scan $h "#%2x%2x%2x" r g b
    return [list $r $g $b]
}

# {name reversed} of a palette name ("" when there is no such palette).
proc ::VMDance::Cmap::resolve {name} {
    variable palettes; variable aliases
    set rev [string match *_r $name]
    if {$rev} { set name [string range $name 0 end-2] }
    if {[dict exists $aliases $name]} { set name [dict get $aliases $name] }
    if {![dict exists $palettes $name]} { return "" }
    list $name $rev
}
proc ::VMDance::Cmap::valid {name} { expr {[resolve $name] ne ""} }
proc ::VMDance::Cmap::names {{category ""}} {
    variable palettes
    set out {}
    dict for {k v} $palettes { if {$category eq "" || [lindex $v 0] eq $category} { lappend out $k } }
    return $out
}
proc ::VMDance::Cmap::category {name} {
    variable palettes
    lassign [resolve $name] k
    expr {$k eq "" ? "" : [lindex [dict get $palettes $k] 0]}
}
proc ::VMDance::Cmap::label {name} {
    variable palettes
    lassign [resolve $name] k rev
    if {$k eq ""} { return $name }
    set l [lindex [dict get $palettes $k] 1]
    expr {$rev ? "$l, reversed" : $l}
}
# The palette's colours, reversed for "_r" (viridis when unknown).
proc ::VMDance::Cmap::colours {name} {
    variable palettes
    set r [resolve $name]
    if {$r eq ""} { set r {viridis 0} }
    lassign $r k rev
    set c [lindex [dict get $palettes $k] 2]
    expr {$rev ? [lreverse $c] : $c}
}

# 256 colours for values 0..1: interpolated, or in steps for a
# qualitative palette.
proc ::VMDance::Cmap::_build {name} {
    variable lut
    set a [colours $name]
    set na [expr {[llength $a] - 1}]
    set step [expr {[category $name] eq "qualitative"}]
    set out {}
    for {set i 0} {$i < 256} {incr i} {
        if {$step} {
            lappend out [lindex $a [expr {min($na, int($i / 256.0 * ($na + 1)))}]]
            continue
        }
        set t [expr {double($i) / 255 * $na}]
        set k [expr {min(int($t), $na - 1)}]
        set f [expr {$t - $k}]
        lassign [_hex2rgb [lindex $a $k]] r0 g0 b0
        lassign [_hex2rgb [lindex $a [expr {$k + 1}]]] r1 g1 b1
        lappend out [format "#%02x%02x%02x" \
            [expr {int(round($r0 + ($r1 - $r0) * $f))}] \
            [expr {int(round($g0 + ($g1 - $g0) * $f))}] \
            [expr {int(round($b0 + ($b1 - $b0) * $f))}]]
    }
    set lut($name) $out
}

# Colour for t in [0,1].
proc ::VMDance::Cmap::at {name t} {
    variable lut
    if {![info exists lut($name)]} { _build $name }
    set k [expr {int($t * 255.0 + 0.5)}]
    if {$k < 0} { set k 0 } elseif {$k > 255} { set k 255 }
    lindex $lut($name) $k
}


# The k-th of n categories: a qualitative palette's colours in turn, a
# cyclic one around the circle, the others sampled between 0.1 and 0.9 (so
# that no category is white or black).
proc ::VMDance::Cmap::pick {name k {n 10}} {
    set cat [category $name]
    if {$cat eq "qualitative"} {
        set c [colours $name]
        return [lindex $c [expr {$k % [llength $c]}]]
    }
    if {$cat eq "cyclic"} { return [at $name [expr {double($k % max(1, $n)) / max(1, $n)}]] }
    if {$n <= 1} { return [at $name 0.5] }
    at $name [expr {0.1 + 0.8 * double($k % $n) / ($n - 1)}]
}

# A small image of the palette (menus, legends).
proc ::VMDance::Cmap::swatch {name {w 64} {h 12}} {
    variable swatches
    set key $name,$w,$h
    if {[info exists swatches($key)] && $swatches($key) in [image names]} { return $swatches($key) }
    set img [image create photo -width $w -height $h]
    set row {}
    if {[category $name] eq "qualitative"} {
        set c [colours $name]
        for {set x 0} {$x < $w} {incr x} { lappend row [lindex $c [expr {min([llength $c] - 1, $x * [llength $c] / $w)}]] }
    } else {
        for {set x 0} {$x < $w} {incr x} { lappend row [at $name [expr {double($x) / max(1, $w - 1)}]] }
    }
    $img put [lrepeat $h $row] -to 0 0
    $img put #9aa1ad -to 0 0 $w 1
    $img put #9aa1ad -to 0 [expr {$h - 1}] $w $h
    $img put #9aa1ad -to 0 0 1 $h
    $img put #9aa1ad -to [expr {$w - 1}] 0 $w $h
    set swatches($key) $img
}


# Lighter tint of a colour (for fills behind outlines).
proc ::VMDance::Cmap::tint {h f} {
    lassign [_hex2rgb $h] r g b
    format "#%02x%02x%02x" \
        [expr {int($r + (255 - $r) * $f)}] \
        [expr {int($g + (255 - $g) * $f)}] \
        [expr {int($b + (255 - $b) * $f)}]
}


# VMD colour id of community c, and its Tk colour (VMD's own RGB, so that
# the plots match the 3D view; a fixed palette without VMD).
proc ::VMDance::Cmap::community_vmd {c} {
    variable community_ids
    lindex $community_ids [expr {$c % [llength $community_ids]}]
}
proc ::VMDance::Cmap::community {c} {
    variable vmdrgb
    set id [community_vmd $c]
    if {![info exists vmdrgb($id)]} {
        if {[info commands colorinfo] ne "" && ![catch {colorinfo rgb $id} rgb] && [llength $rgb] == 3} {
            lassign $rgb r g b
            set vmdrgb($id) [format "#%02x%02x%02x" [expr {int($r * 255)}] [expr {int($g * 255)}] [expr {int($b * 255)}]]
        } else {
            set vmdrgb($id) [pick tableau $c 10]
        }
    }
    return $vmdrgb($id)
}
# VMD's colours may have been changed (Graphics > Colors): read them again.
proc ::VMDance::Cmap::refresh_vmd {} {
    variable vmdrgb
    array unset vmdrgb
}
