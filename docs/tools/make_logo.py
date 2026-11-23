#!/usr/bin/env python3
"""Draw VMDance's logo: the wordmark, its mark, and the window's icon.

VMD and MDANCE share their MD (molecular dynamics). The wordmark spells
VMDance with VMD in the colours of VMD's own title (V red, M green, D
blue, as VMD draws it at start) and "ance" in black (light on a dark
background). The mark is VMD in those colours on a black tile, as VMD
shows its title; it is the window's icon too.

Writes docs/_static/logo/ (vmdance.svg and vmdance_dark.svg, the wordmark
for light and dark backgrounds; vmdance_mark.svg; PNGs of each) and the
icons vmdance/icons/app_{16,24,32}.png with their dimmed copies. The SVGs
hold outlines, not text: they need no font to show. The PNGs are drawn
from the same outlines with Pillow (no cairo needed).

    python3 docs/tools/make_logo.py      (from the repository's root)

Requires fontTools, uharfbuzz and Pillow, and the Inter font (SIL Open
Font License; Debian/Ubuntu: fonts-inter), or INTER_DIR set to the folder
of its .otf files.
"""
import os
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "docs" / "_static" / "logo"
ICONS = ROOT / "vmdance" / "icons"
INTER = Path(os.environ.get("INTER_DIR", "/usr/share/fonts/opentype/inter"))

# VMD's title colours (the front faces of its V, M and D), and the ink of
# "ance" on a light and on a dark background
VMD = ("#da5050", "#50da50", "#5050da")
LIGHT = dict(vmd=VMD, ance="#000000")
DARK = dict(vmd=VMD, ance="#f2f2f2")
TILE = "#000000"


def shape(text, font, size):
    """text's glyphs at size px per em, kerned: [(svg path, left, right)],
    with the font's cap height in px. Baseline at y = 0, y downwards."""
    import uharfbuzz as hb
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont
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


# A drawing is a list of items, written as SVG and drawn as PNG alike:
#   ("rect", x, y, w, h, rx, fill)      a rectangle, its corners' radius rx
#   ("path", d, tx, ty, fill)           an outline translated by (tx, ty)
def svg(w, h, items, title):
    body = []
    for it in items:
        if it[0] == "rect":
            _, x, y, rw, rh, rx, fill = it
            r = f' rx="{rx:.2f}"' if rx else ""
            body.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{rw:.2f}" height="{rh:.2f}"{r} fill="{fill}"/>')
        else:
            _, d, tx, ty, fill = it
            body.append(f'<path d="{d}" fill="{fill}" transform="translate({tx:.2f},{ty:.2f})"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" '
            f'width="{w:.2f}" height="{h:.2f}" role="img" aria-label="{title}">'
            f'<title>{title}</title>{"".join(body)}</svg>\n')


def wordmark(pal):
    """VMDance: V, M and D in VMD's colours, "ance" in the ink."""
    g, cap = shape("VMDance", "Inter-Bold.otf", 200.0)
    pad = cap * 0.30
    ox, base = pad - g[0][1], pad + cap
    colours = list(pal["vmd"]) + [pal["ance"]] * 4
    items = [("path", d, ox, base, c) for (d, _, _), c in zip(g, colours)]
    # (below the baseline, the round letters' overshoot)
    return g[-1][2] + ox + pad, base + cap * 0.02 + pad, items


def mark(n=256):
    """VMD in VMD's colours on a black tile, as VMD shows its title."""
    g, cap = shape("VMD", "Inter-Bold.otf", n * 0.34)
    ox = (n - (g[-1][2] - g[0][1])) / 2 - g[0][1]
    items = [("rect", 0, 0, n, n, n * 0.20, TILE)]
    items += [("path", d, ox, n / 2 + cap / 2, c) for (d, _, _), c in zip(g, VMD)]
    return n, n, items


def _contours(d):
    """An SVG path's contours as lists of points, curves flattened."""
    toks = re.findall(r"[MLHVQCZ]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d)
    out, cur, x, y, i, cmd = [], [], 0.0, 0.0, 0, None
    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
            if cmd == "Z":
                if cur:
                    out.append(cur)
                cur = []
                continue
        v = toks
        if cmd == "M":
            if cur:
                out.append(cur)
            x, y = float(v[i]), float(v[i + 1]); i += 2
            cur = [(x, y)]
            cmd = "L"
        elif cmd == "L":
            x, y = float(v[i]), float(v[i + 1]); i += 2
            cur.append((x, y))
        elif cmd == "H":
            x = float(v[i]); i += 1
            cur.append((x, y))
        elif cmd == "V":
            y = float(v[i]); i += 1
            cur.append((x, y))
        elif cmd == "Q":
            x1, y1, x2, y2 = (float(t) for t in v[i:i + 4]); i += 4
            for k in range(1, 13):
                t = k / 12
                cur.append(((1 - t) ** 2 * x + 2 * (1 - t) * t * x1 + t * t * x2,
                            (1 - t) ** 2 * y + 2 * (1 - t) * t * y1 + t * t * y2))
            x, y = x2, y2
        elif cmd == "C":
            x1, y1, x2, y2, x3, y3 = (float(t) for t in v[i:i + 6]); i += 6
            for k in range(1, 17):
                t = k / 16
                a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
                cur.append((a * x + b * x1 + c * x2 + e * x3, a * y + b * y1 + c * y2 + e * y3))
            x, y = x3, y3
        else:
            raise ValueError(f"path command {cmd!r} not drawn")
    if cur:
        out.append(cur)
    return out


def png(drawing, width, height=None, ss=4):
    """A drawing (w, h, items) as an RGBA image of width × height, drawn
    ss times larger and reduced (antialiased); outlines filled even-odd
    (a glyph's counters are holes)."""
    w, h, items = drawing
    height = height or round(width * h / w)
    W, H = width * ss, height * ss
    sx, sy = W / w, H / h
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for it in items:
        mask = Image.new("1", (W, H), 0)
        if it[0] == "rect":
            _, x, y, rw, rh, rx, fill = it
            ImageDraw.Draw(mask).rounded_rectangle(
                [x * sx, y * sy, (x + rw) * sx - 1, (y + rh) * sy - 1], radius=rx * sx, fill=1)
        else:
            _, d, tx, ty, fill = it
            for c in _contours(d):
                one = Image.new("1", (W, H), 0)
                ImageDraw.Draw(one).polygon([((px + tx) * sx, (py + ty) * sy) for px, py in c], fill=1)
                mask = ImageChops.logical_xor(mask, one)
        layer = Image.new("RGBA", (W, H), fill)
        layer.putalpha(mask.convert("L"))
        im = Image.alpha_composite(im, layer)
    return im.resize((width, height), Image.LANCZOS)


def dimmed(im):
    """As make_icons.py dims every icon, for disabled buttons."""
    r, g, b, a = im.split()
    grey = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 150 + v * 0.35)
    return Image.merge("RGBA", (grey, grey, grey, a.point(lambda v: v * 0.55)))


def write_all():
    LOGO.mkdir(parents=True, exist_ok=True)
    for name, pal in (("vmdance", LIGHT), ("vmdance_dark", DARK)):
        dr = wordmark(pal)
        (LOGO / f"{name}.svg").write_text(svg(*dr, "VMDance"))
        png(dr, 1200).save(LOGO / f"{name}.png", optimize=True)
    dr = mark()
    (LOGO / "vmdance_mark.svg").write_text(svg(*dr, "VMDance"))
    for px in (64, 128, 256, 512):
        png(dr, px, px).save(LOGO / f"vmdance_mark_{px}.png", optimize=True)
    # the icons: drawn 16 times larger and reduced, as the plugin's others
    for px in (16, 24, 32):
        im = png(dr, px * 16, px * 16).resize((px, px), Image.LANCZOS)
        im.save(ICONS / f"app_{px}.png")
        dimmed(im).save(ICONS / f"app_{px}_dim.png")
    print("wrote", LOGO, "and", ICONS / "app_*.png")


if __name__ == "__main__":
    write_all()
