#!/usr/bin/env python3
"""Draw VMDance's logo: the wordmark, its mark, and the window's icon.

VMD and MDANCE share their MD (molecular dynamics). The wordmark spells
VMDance with a blue bracket over VMD and a rust one under MDance: the two
overlap on MD, which both hold. The mark is that MD between the two
colours, a blue band above and a rust band below, as the window's icon.

Writes docs/_static/logo/ (vmdance.svg and vmdance_dark.svg, the wordmark
for light and dark backgrounds; vmdance_mark.svg; PNGs of each) and the
icons vmdance/icons/app_{16,24,32}.png with their dimmed copies. The SVGs
hold outlines, not text: they need no font to show.

    python3 docs/tools/make_logo.py      (from the repository's root)

Requires fontTools, uharfbuzz, cairosvg and Pillow, and the Inter font
(SIL Open Font License; Debian/Ubuntu: fonts-inter), or INTER_DIR set to
the folder of its .otf files.
"""
import io
import os
from pathlib import Path

import cairosvg
import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "docs" / "_static" / "logo"
ICONS = ROOT / "vmdance" / "icons"
INTER = Path(os.environ.get("INTER_DIR", "/usr/share/fonts/opentype/inter"))

# muted tones: VMD's blue, MDANCE's rust, the ink they share
LIGHT = dict(vmd="#3f6fa8", md="#0f1c2e", ance="#b0503f")
DARK = dict(vmd="#7fa6d6", md="#e9edf3", ance="#d98a76")


def shape(text, font, size):
    """text's glyphs at size px per em, kerned: [(svg path, left, right)],
    with the font's cap height in px. Baseline at y = 0, y downwards."""
    path = str(INTER / font)
    face = hb.Face(hb.Blob.from_file_path(path))
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hb.Font(face), buf, {"kern": True, "liga": False})
    tt = TTFont(path)
    glyphs, order = tt.getGlyphSet(), tt.getGlyphOrder()
    s = size / tt["head"].unitsPerEm
    out, x = [], 0.0
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        g = glyphs[order[info.codepoint]]
        pen = SVGPathPen(glyphs)
        g.draw(TransformPen(pen, (s, 0, 0, -s, x + pos.x_offset * s, -pos.y_offset * s)))
        box = BoundsPen(glyphs)
        g.draw(box)
        x0, _, x1, _ = box.bounds or (0, 0, 0, 0)
        out.append((pen.getCommands(), x + x0 * s, x + x1 * s))
        x += pos.x_advance * s
    return out, tt["OS/2"].sCapHeight * s


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" '
            f'width="{w:.2f}" height="{h:.2f}" role="img" aria-label="{title}">'
            f'<title>{title}</title>{"".join(body)}</svg>\n')


def rect(x, y, w, h, fill):
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{fill}"/>'


def wordmark(pal):
    """VMDance; a bracket over VMD (blue) and one under MDance (rust)."""
    g, cap = shape("VMDance", "Inter-Bold.otf", 200.0)
    t, gap, tick, pad = cap * 0.085, cap * 0.24, cap * 0.15, cap * 0.30
    base = pad + t + gap + cap
    ox = pad - g[0][1]
    colours = [pal["vmd"], pal["md"], pal["md"]] + [pal["ance"]] * 4
    body = [f'<path d="{d}" fill="{c}" transform="translate({ox:.2f},{base:.2f})"/>'
            for (d, _, _), c in zip(g, colours)]

    def bracket(x0, x1, y, down, fill):
        out = [rect(x0, y, x1 - x0, t, fill)]
        for x in (x0, x1 - t):
            out.append(rect(x, y if down else y - tick, t, tick + t, fill))
        return out
    y_over, y_under = base - cap - gap - t, base + gap
    body += bracket(g[0][1] + ox, g[2][2] + ox, y_over, True, pal["vmd"])
    body += bracket(g[1][1] + ox, g[6][2] + ox, y_under, False, pal["ance"])
    return svg(g[6][2] + ox + pad, y_under + t + pad, body, "VMDance")


def mark(n=256):
    """MD between a blue band and a rust band, on a rounded square."""
    r, band = n * 0.20, n * 0.15
    body = [f'<clipPath id="tile"><rect width="{n}" height="{n}" rx="{r:.2f}"/></clipPath>',
            '<g clip-path="url(#tile)">', rect(0, 0, n, n, LIGHT["md"]),
            rect(0, 0, n, band, LIGHT["vmd"]), rect(0, n - band, n, band, LIGHT["ance"]), '</g>']
    g, cap = shape("MD", "Inter-ExtraBold.otf", n * 0.48)
    ox = (n - (g[-1][2] - g[0][1])) / 2 - g[0][1]
    body += [f'<path d="{d}" fill="#ffffff" transform="translate({ox:.2f},{n / 2 + cap / 2:.2f})"/>'
             for d, _, _ in g]
    return svg(n, n, body, "VMDance")


def png(text, width, height=None):
    data = cairosvg.svg2png(bytestring=text.encode(), output_width=width, output_height=height)
    return Image.open(io.BytesIO(data)).convert("RGBA")


def dimmed(im):
    """As make_icons.py dims every icon, for disabled buttons."""
    r, g, b, a = im.split()
    grey = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 150 + v * 0.35)
    return Image.merge("RGBA", (grey, grey, grey, a.point(lambda v: v * 0.55)))


if __name__ == "__main__":
    LOGO.mkdir(parents=True, exist_ok=True)
    for name, pal in (("vmdance", LIGHT), ("vmdance_dark", DARK)):
        text = wordmark(pal)
        (LOGO / f"{name}.svg").write_text(text)
        png(text, 1200).save(LOGO / f"{name}.png", optimize=True)
    text = mark()
    (LOGO / "vmdance_mark.svg").write_text(text)
    for px in (64, 128, 256, 512):
        png(text, px, px).save(LOGO / f"vmdance_mark_{px}.png", optimize=True)
    # the icons: drawn 16 times larger and reduced, as the plugin's others
    for px in (16, 24, 32):
        im = png(text, px * 16, px * 16).resize((px, px), Image.LANCZOS)
        im.save(ICONS / f"app_{px}.png")
        dimmed(im).save(ICONS / f"app_{px}_dim.png")
    print("wrote", LOGO, "and", ICONS / "app_*.png")
