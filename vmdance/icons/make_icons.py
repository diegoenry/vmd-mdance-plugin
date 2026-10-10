#!/usr/bin/env python3
"""Generate VMDance's toolbar, tab and menu icons.

The plot icons are miniatures of the plots, drawn in the colours VMD gives
the first clusters; the action icons are InteractionView's and share one
glyph style with DihedralView's and Molywood Studio's.
Each icon is drawn at 16x supersampling and downsampled, so that the
16, 24 and 32 px versions stay crisp. The application's icon (app_*) is the
logo's mark, drawn by docs/tools/make_logo.py.

    cd vmdance/icons && python3 make_icons.py
Requires Pillow.
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SIZES = (16, 24, 32)
SS = 16                       # supersampling factor
BASE = 32                     # design grid: 32 x 32 units

INK = (59, 66, 80)
MUTED = (138, 144, 156)
GRID = (214, 219, 228)
CARD = (255, 255, 255)
CARD_EDGE = (180, 187, 199)
ACCENT = (31, 95, 174)
CURSOR = (214, 39, 40)
# VMD's colours of the first communities (blue, red, green, orange, purple, cyan)
COMM = [(0, 0, 255), (255, 0, 0), (0, 178, 0), (255, 127, 0), (166, 0, 255), (0, 255, 255)]
COMM = [(46, 89, 196), (212, 52, 52), (44, 150, 64), (236, 132, 28), (132, 70, 196), (40, 170, 190)]
DIVERGING = ["#053061", "#2a71b2", "#9bc9e0", "#f7f6f6", "#fbccb4", "#d05548", "#67001f"]
VIRIDIS = ["#440154", "#3b528b", "#21918c", "#5ec962", "#fde725"]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(stops, t):
    t = min(max(t, 0.0), 1.0) * (len(stops) - 1)
    k = min(int(t), len(stops) - 2)
    f = t - k
    a, b = hexrgb(stops[k]), hexrgb(stops[k + 1])
    return tuple(int(round(a[i] + (b[i] - a[i]) * f)) for i in range(3))


class Canvas:
    """Draw in 32 x 32 design units at SS x resolution."""

    def __init__(self):
        self.n = BASE * SS
        self.img = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def u(self, v):
        return v * SS

    def pts(self, xy):
        return [(self.u(x), self.u(y)) for x, y in xy]

    def line(self, xy, fill, width=1.0):
        self.d.line(self.pts(xy), fill=fill, width=max(1, int(self.u(width))), joint="curve")

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width=1.0, r=0):
        box = [self.u(x0), self.u(y0), self.u(x1), self.u(y1)]
        w = max(1, int(self.u(width))) if outline else 0
        if r:
            self.d.rounded_rectangle(box, radius=self.u(r), fill=fill, outline=outline, width=w)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=w)

    def ellipse(self, cx, cy, rx, ry=None, fill=None, outline=None, width=1.0):
        ry = rx if ry is None else ry
        self.d.ellipse([self.u(cx - rx), self.u(cy - ry), self.u(cx + rx), self.u(cy + ry)],
                       fill=fill, outline=outline, width=max(1, int(self.u(width))) if outline else 0)

    def polygon(self, xy, fill=None, outline=None, width=1.0):
        self.d.polygon(self.pts(xy), fill=fill, outline=outline,
                       width=max(1, int(self.u(width))) if outline else 0)

    def arc(self, cx, cy, r, a0, a1, fill, width=1.0):
        self.d.arc([self.u(cx - r), self.u(cy - r), self.u(cx + r), self.u(cy + r)],
                   a0 - 90, a1 - 90, fill=fill, width=max(1, int(self.u(width))))

    def save(self, name):
        for s in SIZES:
            self.img.resize((s, s), Image.LANCZOS).save(HERE / f"{name}_{s}.png")


def card(c):
    """The miniature-plot 'card' shared by all plot icons."""
    c.rect(1.5, 1.5, 30.5, 30.5, fill=CARD, outline=CARD_EDGE, width=1.4, r=4)



# the first clusters' colours (the plots' darker tones: InteractionView's)
CL = [hexrgb(h) for h in ("#3498db", "#e74c3c", "#27ae60", "#d35400", "#9b59b6", "#16a085")]
COMM = CL
DIVERGING = ["#053061", "#2a71b2", "#9bc9e0", "#f7f6f6", "#fbccb4", "#d05548", "#67001f"]
VIRIDIS = ["#440154", "#3b528b", "#21918c", "#5ec962", "#fde725"]
BLUES = ["#f7fbff", "#c6dbef", "#6aaed6", "#2070b4", "#08306b"]


def rgba(col, a=255):
    return (*col[:3], a)


# ----------------------------------------------------------------- plot icons
def tab_populations():
    """Frames per cluster: bars in the clusters' colours."""
    c = Canvas(); card(c)
    for i, h in enumerate([16, 10, 20, 6, 13]):
        x = 6 + i * 4.3
        c.rect(x, 26 - h, x + 3.2, 26, fill=rgba(CL[i]))
    c.line([(5, 26.3), (27, 26.3)], MUTED, 0.9)
    c.save("tab_populations")


def tab_timeline():
    """The cluster of every frame: one lane per cluster."""
    c = Canvas(); card(c)
    runs = [(0, 5, 0), (5, 9, 2), (9, 12, 0), (12, 18, 1), (18, 20, 2), (20, 26, 1)]
    for a, b, k in runs:
        y = 22 - k * 6
        c.rect(4 + a * 0.9, y - 1.6, 4 + b * 0.9, y + 1.6, fill=rgba(CL[k]))
    c.line([(19, 5), (19, 27)], rgba(CURSOR), 1.0)
    c.save("tab_timeline")


def tab_transitions():
    """Transitions: a matrix, dark on its diagonal."""
    c = Canvas(); card(c)
    vals = [[0.9, 0.2, 0.05], [0.15, 0.8, 0.3], [0.05, 0.25, 0.95]]
    for i in range(3):
        for j in range(3):
            c.rect(6 + j * 7, 6 + i * 7, 12.4 + j * 7, 12.4 + i * 7, fill=rgba(ramp(BLUES, vals[i][j])))
    c.save("tab_transitions")


def tab_residence():
    """How long each cluster lasts: bars with whiskers."""
    c = Canvas(); card(c)
    for i, (h, w) in enumerate([(10, 17), (6, 9), (13, 19), (8, 12)]):
        x = 6.5 + i * 5.2
        c.rect(x, 26 - h, x + 3.6, 26, fill=rgba(CL[i]))
        c.line([(x + 1.8, 26 - h), (x + 1.8, 26 - w)], INK, 0.9)
        c.line([(x + 0.8, 26 - w), (x + 2.8, 26 - w)], INK, 0.9)
    c.line([(5, 26.3), (27, 26.3)], MUTED, 0.9)
    c.save("tab_residence")


def tab_compactness():
    """How tight each cluster is: its size against its spread."""
    c = Canvas(); card(c)
    c.line([(5, 26), (27, 26)], MUTED, 0.9); c.line([(5, 5), (5, 26)], MUTED, 0.9)
    for x in (15,):
        for y0 in range(6, 26, 4):
            c.line([(x, y0), (x, y0 + 2)], GRID, 0.9)
    for y in (16,):
        for x0 in range(6, 27, 4):
            c.line([(x0, y), (x0 + 2, y)], GRID, 0.9)
    for (x, y), k in zip([(9, 21), (13, 12), (19, 18), (24, 8), (22, 23)], range(5)):
        c.ellipse(x, y, 2.4, fill=rgba(CL[k]), outline=(255, 255, 255, 255), width=0.6)
    c.save("tab_compactness")


def tab_distances():
    """Distances between the clusters: a symmetric matrix."""
    c = Canvas(); card(c)
    d = [[0, 0.5, 0.9, 0.7], [0.5, 0, 0.4, 0.8], [0.9, 0.4, 0, 0.3], [0.7, 0.8, 0.3, 0]]
    for i in range(4):
        for j in range(4):
            c.rect(5 + j * 5.5, 5 + i * 5.5, 10 + j * 5.5, 10 + i * 5.5, fill=rgba(ramp(VIRIDIS, d[i][j])))
    c.save("tab_distances")


def tab_tree():
    """A dendrogram: the clusters joined."""
    c = Canvas(); card(c)
    xs = [7, 12, 17, 22, 26]
    for x, k in zip(xs, range(5)):
        c.ellipse(x, 25, 1.9, fill=rgba(CL[k]))
    c.line([(7, 23), (7, 18), (12, 18), (12, 23)], INK, 1.2)
    c.line([(17, 23), (17, 15), (22, 15), (22, 23)], INK, 1.2)
    c.line([(9.5, 18), (9.5, 11), (19.5, 11), (19.5, 15)], INK, 1.2)
    c.line([(14.5, 11), (14.5, 7), (26, 7), (26, 23)], INK, 1.2)
    c.save("tab_tree")


def tab_silhouette():
    """Silhouettes: each cluster's frames as a profile."""
    c = Canvas(); card(c)
    c.line([(10, 5), (10, 27)], MUTED, 0.9)
    y = 6
    for k, prof in enumerate([[16, 14, 11, 8], [13, 10, 7], [17, 15, 13, 9, 5]]):
        pts = [(10, y)]
        for v in prof:
            pts += [(10 + v, y), (10 + v, y + 1.6)]
            y += 1.6
        pts += [(10, y)]
        c.polygon(pts, fill=rgba(CL[k]))
        y += 1.8
    c.save("tab_silhouette")


def tab_elbow():
    """Scores at every k, with the elbow."""
    c = Canvas(); card(c)
    pts = [(6, 7), (10, 15), (14, 19), (18, 21), (22, 22), (26, 22.5)]
    c.line(pts, (63, 111, 168), 1.5)
    for x, y in pts:
        c.ellipse(x, y, 1.4, fill=(63, 111, 168))
    c.ellipse(14, 19, 3.2, outline=rgba(CURSOR), width=1.1)
    c.line([(6, 25), (10, 21), (14, 23), (18, 20), (22, 16), (26, 12)], (176, 80, 63), 1.1)
    c.save("tab_elbow")


def tab_sweep():
    """A sweep: scores over a grid, the best outlined."""
    c = Canvas(); card(c)
    v = [[0.2, 0.5, 0.8, 0.6], [0.3, 0.9, 1.0, 0.7], [0.1, 0.4, 0.6, 0.5]]
    for i in range(3):
        for j in range(4):
            c.rect(5 + j * 5.6, 7 + i * 6, 10.2 + j * 5.6, 12.4 + i * 6, fill=rgba(ramp(VIRIDIS, v[i][j])))
    c.rect(4.6 + 2 * 5.6, 12.6, 10.6 + 2 * 5.6, 18.8, outline=INK, width=1.2)
    c.save("tab_sweep")


def act_open():
    c = Canvas()
    c.polygon([(3, 9), (12, 9), (14.5, 11.5), (27, 11.5), (27, 25), (3, 25)], fill=(*hexrgb("#f2c46d"), 255), outline=INK, width=1.3)
    c.polygon([(3, 25), (7.5, 15), (30, 15), (26, 25)], fill=(*hexrgb("#f7d88f"), 255), outline=INK, width=1.3)
    c.save("open")


def act_save():
    c = Canvas()
    c.rect(4, 4, 28, 28, fill=(*ACCENT, 255), outline=INK, width=1.2, r=2.5)
    c.rect(9, 4, 23, 12, fill=(255, 255, 255, 255), outline=INK, width=1.0)
    c.rect(18.5, 5.5, 21, 10.5, fill=(*ACCENT, 255))
    c.rect(8, 17, 24, 28, fill=(236, 240, 246, 255), outline=INK, width=1.0)
    c.line([(11, 21), (21, 21)], MUTED, 0.9); c.line([(11, 24.5), (21, 24.5)], MUTED, 0.9)
    c.save("save")


def act_export():
    c = Canvas()
    c.rect(3, 5, 21, 27, fill=CARD, outline=INK, width=1.2, r=1.5)
    for y in (10, 14.5, 19, 23.5):
        c.line([(3.5, y), (20.5, y)], GRID, 0.8)
    c.line([(9, 5.5), (9, 26.5)], GRID, 0.8); c.line([(15, 5.5), (15, 26.5)], GRID, 0.8)
    c.rect(3.6, 5.6, 20.4, 9.6, fill=(*COMM[0], 255))
    c.line([(15, 17), (27, 17)], (*COMM[2], 255), 2.6)
    c.polygon([(24, 12.5), (30.5, 17), (24, 21.5)], fill=(*COMM[2], 255))
    c.save("export")


def act_figure():
    c = Canvas()
    c.rect(3, 5, 29, 27, fill=CARD, outline=INK, width=1.3, r=2.5)
    c.rect(6, 8, 26, 24, fill=(247, 249, 252, 255))
    for i, h in enumerate([5, 9, 13, 8, 11]):
        c.rect(7.5 + i * 3.6, 23 - h, 10 + i * 3.6, 23, fill=(*COMM[0], 255))
    c.line([(7, 14), (11, 11), (15, 13), (19, 9), (25, 10.5)], COMM[1], 1.4)
    c.save("figure")


def act_analyze():
    c = Canvas()
    c.ellipse(16, 16, 13, fill=(*hexrgb("#2e8b57"), 255))
    c.polygon([(12.5, 9.5), (23.5, 16), (12.5, 22.5)], fill=(255, 255, 255, 255))
    c.save("analyze")


def act_cancel():
    c = Canvas()
    c.ellipse(16, 16, 13, fill=(*hexrgb("#c0392b"), 255))
    c.rect(11, 11, 21, 21, fill=(255, 255, 255, 255), r=1)
    c.save("cancel")


def act_focus():
    c = Canvas()
    c.ellipse(16, 16, 10, outline=INK, width=1.6)
    c.ellipse(16, 16, 4.5, outline=(*CURSOR, 255), width=1.6)
    for a, b in (((16, 2), (16, 8)), ((16, 24), (16, 30)), ((2, 16), (8, 16)), ((24, 16), (30, 16))):
        c.line([a, b], INK, 1.6)
    c.ellipse(16, 16, 1.4, fill=CURSOR)
    c.save("focus")


def act_render():
    c = Canvas()
    c.rect(3, 9, 29, 26, fill=(*INK, 255), r=3)
    c.rect(10, 5.5, 19, 10, fill=(*INK, 255), r=1)
    c.ellipse(16, 17.5, 6.5, fill=(236, 240, 246, 255))
    c.ellipse(16, 17.5, 4.2, fill=(*ACCENT, 255))
    c.ellipse(14.5, 16, 1.2, fill=(255, 255, 255, 255))
    c.rect(23.5, 11.5, 26.5, 13.5, fill=(*COMM[3], 255))
    c.save("render")


def act_settings():
    c = Canvas()
    cx = cy = 16
    teeth = []
    for k in range(16):
        a = math.radians(k * 22.5)
        r = 13 if k % 2 == 0 else 10
        teeth.append((cx + r * math.sin(a), cy - r * math.cos(a)))
    c.polygon(teeth, fill=(*INK, 255))
    c.ellipse(cx, cy, 8.5, fill=(*INK, 255))
    c.ellipse(cx, cy, 4, fill=(255, 255, 255, 255))
    c.save("settings")


def act_help():
    c = Canvas()
    c.ellipse(16, 16, 13, fill=(*ACCENT, 255))
    c.arc(16, 12.5, 4.8, -90, 150, (255, 255, 255, 255), 2.6)
    c.line([(18.5, 16.6), (16, 19), (16, 20.5)], (255, 255, 255, 255), 2.6)
    c.ellipse(16, 24.5, 1.7, fill=(255, 255, 255, 255))
    c.save("help")



def act_cluster():
    c = Canvas()
    c.ellipse(16, 16, 13, fill=(*hexrgb("#2e8b57"), 255))
    c.polygon([(12.5, 9.5), (23.5, 16), (12.5, 22.5)], fill=(255, 255, 255, 255))
    c.save("cluster")


def act_elbow():
    """An elbow scan: a curve and its knee."""
    c = Canvas()
    c.rect(3, 4, 29, 28, fill=CARD, outline=INK, width=1.2, r=2.5)
    pts = [(6, 8), (10, 16), (14, 20), (19, 22), (26, 23)]
    c.line(pts, (63, 111, 168), 1.8)
    c.ellipse(14, 20, 3.0, outline=rgba(CURSOR), width=1.4)
    c.save("elbow")


def act_goto():
    """Go to the representative: a target on a frame."""
    c = Canvas()
    c.ellipse(16, 16, 10, outline=INK, width=1.6)
    c.ellipse(16, 16, 4.5, outline=rgba(CL[0]), width=1.8)
    for a, b in (((16, 2), (16, 8)), ((16, 24), (16, 30)), ((2, 16), (8, 16)), ((24, 16), (30, 16))):
        c.line([a, b], INK, 1.6)
    c.ellipse(16, 16, 1.6, fill=rgba(CL[0]))
    c.save("goto")


def _chain(c, pts, cols, width=2.6):
    for (a, b), col in zip(zip(pts, pts[1:]), cols):
        c.line([a, b], rgba(col), width)


def act_colour():
    """Colour by cluster: a chain in the cluster's colour."""
    c = Canvas()
    pts = [(5, 22), (9, 13), (15, 17), (19, 8), (26, 11), (27, 22)]
    _chain(c, pts, [CL[1]] * 5, 3.2)
    for x, y in pts:
        c.ellipse(x, y, 2.2, fill=rgba(CL[1]), outline=INK, width=0.7)
    c.save("colour")


def act_reps():
    """Every representative: three structures in their colours."""
    c = Canvas()
    base = [(0, 8), (5, 3), (10, 8), (14, 2)]
    for k, (dx, dy) in enumerate(((3, 17), (9, 11), (15, 5))):
        pts = [(x + dx, y + dy) for x, y in base]
        _chain(c, pts, [CL[k]] * 3, 2.4)
    c.save("reps")


# ----------------------------------------------------------------- panel tabs
def pane_setup():
    """Setup: what is clustered and how."""
    c = Canvas()
    c.rect(3, 3, 29, 29, fill=CARD, outline=INK, width=1.2, r=3)
    for i, (on, col) in enumerate(((True, CL[0]), (True, CL[1]), (False, MUTED))):
        y = 8.5 + i * 7.5
        c.rect(6.5, y - 2.8, 12.1, y + 2.8, fill=(*ACCENT, 255) if on else (255, 255, 255, 255),
               outline=INK if not on else (*ACCENT, 255), width=0.9, r=1)
        if on:
            c.line([(7.7, y), (9, y + 1.6), (11.2, y - 1.6)], (255, 255, 255, 255), 1.3)
        c.line([(15, y), (26, y)], (*col, 255), 2.0)
    c.save("pane_setup")


def pane_results():
    """Results: the table of clusters, rows in their colours."""
    c = Canvas()
    c.rect(3, 4, 29, 28, fill=CARD, outline=INK, width=1.2, r=2)
    c.rect(3.6, 4.6, 28.4, 9.5, fill=(*ACCENT, 255))
    for i in range(4):
        y = 9.5 + i * 4.6
        c.rect(5, y + 1.0, 7.6, y + 3.6, fill=rgba(CL[i]))
        c.line([(3.6, y + 4.6), (28.4, y + 4.6)], GRID, 0.7)
        c.line([(10, y + 2.3), (16, y + 2.3)], MUTED, 1.0)
        c.line([(19, y + 2.3), (26, y + 2.3)], MUTED, 1.0)
    c.save("pane_results")


def pane_scans():
    """Scans: a range of k."""
    c = Canvas()
    c.rect(3, 5, 29, 27, fill=CARD, outline=INK, width=1.2, r=2.5)
    for i, h in enumerate([4, 8, 12, 16]):
        x = 7 + i * 5
        c.rect(x, 23 - h, x + 3, 23, fill=rgba(CL[i]))
    c.line([(6, 10), (13, 13), (19, 15), (26, 16)], (63, 111, 168), 1.4)
    c.save("pane_scans")


def pane_tools():
    """Tools: a star (PRIME's pick) among frames."""
    c = Canvas()
    for (x, y) in [(7, 9), (25, 8), (8, 24), (24, 25), (16, 5)]:
        c.ellipse(x, y, 1.8, fill=rgba(MUTED))
    pts = []
    for k in range(10):
        a = math.radians(k * 36 - 90)
        r = 9 if k % 2 == 0 else 4
        pts.append((16 + r * math.cos(a), 17 + r * math.sin(a)))
    c.polygon(pts, fill=rgba(CL[3]), outline=INK, width=0.8)
    c.save("pane_tools")


def pane_3d():
    """3D: structures in the clusters' colours."""
    c = Canvas()
    pts = [(5, 24), (10, 14), (16, 19), (21, 9), (27, 13)]
    _chain(c, pts, [CL[0], CL[0], CL[2], CL[2]], 2.6)
    for (x, y), k in zip(pts, [0, 0, 2, 2, 2]):
        c.ellipse(x, y, 2.6, fill=rgba(CL[k]), outline=INK, width=0.8)
    c.save("pane_3d")


def panel_left():
    c = Canvas()
    c.rect(3, 5, 29, 27, fill=CARD, outline=INK, width=1.4, r=3)
    c.rect(3.7, 5.7, 12, 26.3, fill=(*ACCENT, 255), r=2.4)
    c.rect(9, 5.7, 12, 26.3, fill=(*ACCENT, 255))
    for y in (10, 14, 18):
        c.line([(5.8, y), (10, y)], (255, 255, 255, 255), 1.3)
    c.line([(12, 5.5), (12, 26.5)], INK, 1.2)
    c.save("panel_left")


def panel_right():
    c = Canvas()
    c.rect(3, 5, 29, 27, fill=CARD, outline=INK, width=1.4, r=3)
    c.rect(19, 5.7, 28.3, 26.3, fill=(236, 240, 246, 255), r=2.4)
    c.rect(19, 5.7, 22, 26.3, fill=(236, 240, 246, 255))
    c.line([(19, 5.5), (19, 26.5)], INK, 1.2)
    for y, x in ((10.5, 25), (16, 22.5), (21.5, 26)):
        c.line([(21, y), (27, y)], MUTED, 1.2)
        c.ellipse(x, y, 1.9, fill=(*ACCENT, 255))
    c.line([(6, 22), (9, 17), (12, 19), (16, 11)], COMM[1], 1.6)
    c.save("panel_right")


# ----------------------------------------------------------------- flat theme parts
UI_SIZES = (16, 20, 24)
FLAT_ACCENT = (47, 111, 219)
FLAT_BORDER = (179, 186, 197)


def indicator(name, kind, on, state):
    """Check box / radio button of the plugin's flat theme (16-unit grid)."""
    n = 16 * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = lambda v: v * SS
    box = [u(1.5), u(1.5), u(14.5), u(14.5)]
    if state == "disabled":
        fill = (160, 184, 228, 255) if on else (240, 241, 243, 255)
        edge = (160, 184, 228, 255) if on else (211, 215, 221, 255)
    elif state == "hover":
        fill = FLAT_ACCENT + (255,) if on else (255, 255, 255, 255)
        edge = FLAT_ACCENT + (255,) if on else (127, 163, 227, 255)
    else:
        fill = FLAT_ACCENT + (255,) if on else (255, 255, 255, 255)
        edge = FLAT_ACCENT + (255,) if on else FLAT_BORDER + (255,)
    if kind == "check":
        d.rounded_rectangle(box, radius=u(3), fill=fill, outline=edge, width=int(u(1.1)))
        if on:
            d.line([(u(4.3), u(8.3)), (u(6.9), u(10.9)), (u(11.8), u(5.4))],
                   fill=(255, 255, 255, 255), width=int(u(2.0)), joint="curve")
    else:
        d.ellipse(box, fill=fill, outline=edge, width=int(u(1.1)))
        if on:
            d.ellipse([u(5.3), u(5.3), u(10.7), u(10.7)], fill=(255, 255, 255, 255))
    for s in UI_SIZES:
        img.resize((s, s), Image.LANCZOS).save(HERE / f"{name}_{s}.png")


def flat_parts():
    for kind in ("check", "radio"):
        for on in (False, True):
            for state in ("normal", "hover", "disabled"):
                nm = f"ui_{kind}_{'on' if on else 'off'}" + ("" if state == "normal" else f"_{state}")
                indicator(nm, kind, on, state)


def dimmed():
    """A dimmed copy of every icon, for disabled toolbar buttons."""
    for f in sorted(HERE.glob("*_[0-9]*.png")):
        if f.stem.startswith("ui_") or f.stem.endswith("_dim"):
            continue
        im = Image.open(f).convert("RGBA")
        r, g, b, a = im.split()
        grey = Image.merge("RGB", (r, g, b)).convert("L").point(lambda v: 150 + v * 0.35)
        out = Image.merge("RGBA", (grey, grey, grey, a.point(lambda v: v * 0.55)))
        out.save(f.with_name(f.stem + "_dim.png"))


if __name__ == "__main__":
    for f in (tab_populations, tab_timeline, tab_transitions, tab_residence, tab_compactness,
              tab_distances, tab_tree, tab_silhouette, tab_elbow, tab_sweep,
              act_open, act_save, act_export, act_figure, act_cluster, act_elbow, act_cancel, act_goto,
              act_render, act_settings, act_help, act_colour, act_reps,
              pane_setup, pane_results, pane_scans, pane_tools, pane_3d, panel_left, panel_right, flat_parts):
        f()
    dimmed()
    print("icons written to", HERE)
