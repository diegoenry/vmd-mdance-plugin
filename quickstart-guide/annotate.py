"""The window's picture with its parts numbered, and the 3D view cropped to
the molecule, for the guide.

figures/window_annotated.png, from figures.tcl's window.png and
window_parts.txt (name x y width height, in Tk's points; the first line is
the window's own size). The picture can be larger than the points (a Retina
screen's two pixels a point) and taller (the title bar macOS adds above
Tk's window): both are measured from it. The numbers and their places are
those of the online documentation's picture (docs/tools/annotate.py).

figures/main_3d.png, VMD's render of the representatives, is cropped to what
is drawn on its white background, with a margin: the representatives differ
with every clustering, and so does where they are.

    python3 annotate.py figures
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

ORDER = ["toolbar", "panes", "plots", "plot", "options", "readout", "status"]
COLOUR = (163, 72, 59)
WIDTH = 1600  # the picture's width in the guide's file, in pixels


def font(size):
    for f in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size, index=1) if f.endswith(".ttc") else ImageFont.truetype(f, size)
            except OSError:
                return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def crop_3d(path, margin=20):
    img = Image.open(path).convert("RGB")
    box = ImageChops.difference(img, Image.new("RGB", img.size, (255, 255, 255))).getbbox()
    if box is None:
        return
    l, t, r, b = box
    box = (max(0, l - margin), max(0, t - margin), min(img.width, r + margin), min(img.height, b + margin))
    if box != (0, 0, img.width, img.height):
        img.crop(box).save(path, optimize=True)
        print("cropped", path, "to", box)


def main(folder):
    if os.path.exists(os.path.join(folder, "main_3d.png")):
        crop_3d(os.path.join(folder, "main_3d.png"))
    if not os.path.exists(os.path.join(folder, "window_parts.txt")):
        return
    parts = {}
    with open(os.path.join(folder, "window_parts.txt")) as fh:
        for line in fh:
            w = line.split()
            if len(w) == 5:
                parts[w[0]] = tuple(int(v) for v in w[1:])
    img = Image.open(os.path.join(folder, "window.png")).convert("RGB")
    tw, th = parts["window"][2], parts["window"][3]
    scale = img.width / tw
    top = img.height - th * scale  # the title bar above Tk's window
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    r = 14 * scale
    f = font(int(17 * scale))
    for i, name in enumerate(ORDER, 1):
        if name not in parts:
            continue
        x, y, w, h = (v * scale for v in parts[name])
        y += top
        d.rounded_rectangle([x + 1, y + 1, x + w - 2, y + h - 2], radius=6 * scale,
                            outline=COLOUR + (230,), width=int(3 * scale))
        # the number: at the part's top left, inside it (the plot's and the
        # panes' a little further in, off their tabs)
        cx, cy = x + r + 6 * scale, y + r + 4 * scale
        if name in ("plot", "panes", "plots"):
            cx, cy = x + w - r - 10 * scale, y + r + 6 * scale
        if name in ("readout", "status", "options"):
            cx, cy = x + w - r - 10 * scale, y + h / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=COLOUR + (255,), outline=(255, 255, 255, 255),
                  width=int(2 * scale))
        d.text((cx, cy), str(i), font=f, fill=(255, 255, 255, 255), anchor="mm")
    out = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")
    if out.width > WIDTH:
        out = out.resize((WIDTH, round(out.height * WIDTH / out.width)), Image.LANCZOS)
    out.save(os.path.join(folder, "window_annotated.png"), optimize=True)
    print("wrote", os.path.join(folder, "window_annotated.png"))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "figures")
