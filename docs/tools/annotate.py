"""The window's picture with its parts numbered (docs/_static/figures/
window_annotated.png), from capture.tcl's window.png and the places of the
parts it wrote (window_parts.txt: name x y width height, in pixels).

    python3 docs/tools/annotate.py <VMDANCE_OUT>/window_parts.txt
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FIGS = os.path.join(os.path.dirname(HERE), "_static", "figures")
# the order the docs number them in, and where the mark goes on each
ORDER = ["toolbar", "panes", "plots", "plot", "options", "readout", "status"]
COLOUR = (163, 72, 59)


def font(size):
    for f in ("/usr/share/fonts/opentype/inter/Inter-Bold.otf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main(parts_file):
    parts = {}
    with open(parts_file) as fh:
        for line in fh:
            w = line.split()
            if len(w) == 5:
                parts[w[0]] = tuple(int(v) for v in w[1:])
    img = Image.open(os.path.join(FIGS, "window.png")).convert("RGB")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    f = font(17)
    r = 14
    for i, name in enumerate(ORDER, 1):
        if name not in parts:
            continue
        x, y, w, h = parts[name]
        d.rounded_rectangle([x + 1, y + 1, x + w - 2, y + h - 2], radius=6, outline=COLOUR + (230,), width=3)
        # the number: at the part's top left, inside it (the plot's and the
        # panes' a little further in, off their tabs)
        cx, cy = x + r + 6, y + r + 4
        if name in ("plot", "panes", "plots"):
            cx, cy = x + w - r - 10, y + r + 6
        if name in ("readout", "status", "options"):
            cx, cy = x + w - r - 10, y + h / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=COLOUR + (255,), outline=(255, 255, 255, 255), width=2)
        d.text((cx, cy), str(i), font=f, fill=(255, 255, 255, 255), anchor="mm")
    out = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")
    out.save(os.path.join(FIGS, "window_annotated.png"), optimize=True)
    print("wrote window_annotated.png")


if __name__ == "__main__":
    main(sys.argv[1])
