"""The documentation's diagrams: docs/_static/diagrams/*.svg (and .png for
the decks). Drawn with matplotlib (the infographics) and Graphviz's dot
(docs/diagrams/*.dot: the flows).

    cd <VMDance>/docs
    python3 tools/make_diagrams.py        # needs matplotlib and numpy; dot for the flows

The colours are the plugin's muted ones (the plots', the groups' palette).
"""
import os
import shutil
import subprocess

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.patches import Circle, FancyArrowPatch, FancyBboxPatch  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.dirname(HERE)
OUT = os.path.join(DOCS, "_static", "diagrams")
SRC = os.path.join(DOCS, "diagrams")

INK = "#1d2733"
MUTED = "#5a6573"
LINE = "#9aa7b4"
BLUE, GREEN, GOLD, RUST, PURPLE, TEAL, GREY = "#3d5a80", "#4f7a5a", "#c09a45", "#a3483b", "#7a6a9a", "#4f8a8a", "#707070"
PALETTE = [BLUE, GREEN, GOLD, RUST, PURPLE, TEAL]

plt.rcParams.update({
    "font.family": ["Inter", "DejaVu Sans"],
    "font.size": 10,
    "svg.fonttype": "none",
    "text.color": INK,
})


def tint(c, f):
    """c lightened towards white by f (0: c, 1: white)."""
    c = c.lstrip("#")
    r, g, b = (int(c[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02x%02x%02x" % tuple(int(v + (255 - v) * f) for v in (r, g, b))


def save(fig, name):
    os.makedirs(OUT, exist_ok=True)
    for ext in ("svg", "png"):
        fig.savefig(os.path.join(OUT, f"{name}.{ext}"), dpi=200, transparent=False, facecolor="white", bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)
    print("wrote", name)


def box(ax, x, y, w, h, title, sub="", fc="#f3f5f8", ec=LINE, tc=INK, size=10, subsize=8.2, r=0.12, bold=True):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0,rounding_size={r}", fc=fc, ec=ec, lw=1.1))
    if sub:
        ax.text(x + w / 2, y + h * 0.63, title, ha="center", va="center", fontsize=size, fontweight="bold" if bold else "normal", color=tc)
        ax.text(x + w / 2, y + h * 0.3, sub, ha="center", va="center", fontsize=subsize, color=MUTED, linespacing=1.25)
    else:
        ax.text(x + w / 2, y + h / 2, title, ha="center", va="center", fontsize=size, fontweight="bold" if bold else "normal", color=tc)


def arrow(ax, a, b, color=MUTED, style="-|>", lw=1.2, ls="-", rad=0.0):
    ax.add_patch(FancyArrowPatch(a, b, arrowstyle=style, mutation_scale=11, color=color, lw=lw, linestyle=ls,
                                 connectionstyle=f"arc3,rad={rad}", shrinkA=2, shrinkB=2))


def architecture():
    """Three layers: VMD, the plugin (the command and the window over the
    core), CPP-MDANCE."""
    fig, ax = plt.subplots(figsize=(9.6, 6.0))
    ax.set_xlim(0, 12); ax.set_ylim(0, 7.6); ax.axis("off")
    # VMD
    ax.add_patch(FancyBboxPatch((0.1, 6.0), 11.8, 1.45, boxstyle="round,pad=0,rounding_size=0.18", fc="#f7f9fb", ec="#c8d3e0", lw=1.2))
    ax.text(0.3, 7.22, "VMD", fontsize=12, fontweight="bold", color=BLUE)
    box(ax, 0.6, 6.15, 3.3, 0.85, "The molecule", "its atoms and frames")
    box(ax, 4.35, 6.15, 3.3, 0.85, "The 3D window", "VMDance's representations")
    box(ax, 8.1, 6.15, 3.3, 0.85, "Console and scripts", "vmd -dispdev text too")
    # the plugin
    ax.add_patch(FancyBboxPatch((0.1, 1.95), 11.8, 3.75, boxstyle="round,pad=0,rounding_size=0.18", fc="#fdfbfa", ec="#e2cfc9", lw=1.2))
    ax.text(0.3, 5.42, "VMDance", fontsize=12, fontweight="bold", color=RUST)
    box(ax, 0.6, 4.35, 6.9, 0.9, "The window (Tk)", "Setup · Results · Scans · Tools · 3D, and 13 linked plots", fc="#f6ebe8", ec="#c99a8f")
    box(ax, 8.1, 4.35, 3.3, 0.9, "vmdance", "one command: all the window does", fc="#f6ebe8", ec="#c99a8f")
    ax.add_patch(FancyBboxPatch((0.45, 2.15), 11.1, 1.85, boxstyle="round,pad=0,rounding_size=0.14", fc="none", ec="#d8c7c0", lw=1.0, ls="--"))
    ax.text(0.62, 3.78, "the core: no Tk, tested in text mode", fontsize=8.5, color="#6b5a52", style="italic")
    core = [("Algo", "parameters;\nchecks first"), ("Coords", "frames read,\nfitted on values"), ("Job", "background;\nCancel"),
            ("Results", "runs, scans,\ngroups: checked"), ("Measures", "silhouette, map,\nprofiles, stability"),
            ("Files", "sessions,\ntables, figures"), ("Viz3D", "colours,\nrepresentatives")]
    w, gap, x0 = 1.42, 0.13, 0.62
    for i, (t, s) in enumerate(core):
        box(ax, x0 + i * (w + gap), 2.33, w, 1.3, t, s, size=9.5, subsize=7.6)
    # CPP-MDANCE
    ax.add_patch(FancyBboxPatch((0.1, 0.1), 11.8, 1.55, boxstyle="round,pad=0,rounding_size=0.18", fc="#f9fcfa", ec="#c9dbcf", lw=1.2))
    ax.text(0.3, 1.38, "CPP-MDANCE", fontsize=12, fontweight="bold", color=GREEN)
    box(ax, 0.6, 0.27, 3.0, 0.88, "mdance-cli", "a program: CSV in, JSON out", fc="#e9f1ec", ec="#93b39e")
    box(ax, 3.85, 0.27, 3.0, 0.88, "mdance_tcl", "a library, inside VMD", fc="#e9f1ec", ec="#93b39e")
    box(ax, 7.2, 0.27, 4.2, 0.88, "KMeans NANI · DIVINE · HELM · eQUAL", "PRIME · iSIM · frame picks", fc="white", ec="#93b39e", size=9.5)
    # what goes between the layers, in the gaps (no arrow crosses a box)
    def updown(x, y0, y1, down, up, color):
        arrow(ax, (x - 0.12, y0), (x - 0.12, y1), color=color)
        arrow(ax, (x + 0.12, y1), (x + 0.12, y0), color=color)
        ax.text(x - 0.3, (y0 + y1) / 2, down, ha="right", va="center", fontsize=8, color=color)
        ax.text(x + 0.3, (y0 + y1) / 2, up, ha="left", va="center", fontsize=8, color=color)
    updown(3.0, 5.98, 5.72, "the frames' coordinates", "the clusters drawn in 3D", BLUE)
    updown(9.0, 5.98, 5.72, "commands", "answers", MUTED)
    updown(3.0, 1.93, 1.67, "the coordinates (a CSV, or a list)", "labels, scores, merges", GREEN)
    # inside the plugin: the window and the command drive one core
    arrow(ax, (4.05, 4.35), (4.05, 4.02), color=MUTED)
    arrow(ax, (9.75, 4.35), (9.75, 4.02), color=MUTED)
    arrow(ax, (6.9, 4.02), (6.9, 4.35), color=RUST, ls="--")
    ax.text(7.02, 4.18, "listened to", fontsize=7.8, color=RUST, va="center")
    save(fig, "architecture")


def workflow():
    """An analysis, step by step."""
    steps = [
        ("1", "Load", "a trajectory in VMD\n(aligned, or fitted\nby the plugin)", BLUE),
        ("2", "Choose", "the atoms, the frames,\nthe algorithm and\nits parameters", BLUE),
        ("3", "Scan", "how many clusters:\nscores, stability,\nheights, radius", GOLD),
        ("4", "Cluster", "MDANCE's algorithms,\nrun by CPP-MDANCE\nin the background", RUST),
        ("5", "Explore", "13 linked plots and\nthe 3D window; groups,\nmap, profiles", GREEN),
        ("6", "Keep", "sessions, tables,\nstructures, figures;\nall in a script too", PURPLE),
    ]
    w, gap = 2.05, 0.34
    width = 0.3 + 6 * w + 5 * gap
    fig, ax = plt.subplots(figsize=(11.6, 2.75))
    ax.set_xlim(0, width); ax.set_ylim(0, 3.0); ax.axis("off")
    for i, (n, t, s_, c) in enumerate(steps):
        x = 0.15 + i * (w + gap)
        ax.add_patch(FancyBboxPatch((x, 0.15), w, 2.25, boxstyle="round,pad=0,rounding_size=0.16", fc=tint(c, 0.9), ec=tint(c, 0.45), lw=1.2))
        ax.add_patch(Circle((x + w / 2, 2.4), 0.3, fc=c, ec="white", lw=1.5, zorder=3))
        ax.text(x + w / 2, 2.4, n, ha="center", va="center", color="white", fontsize=11, fontweight="bold", zorder=4)
        ax.text(x + w / 2, 1.75, t, ha="center", va="center", fontsize=11.5, fontweight="bold", color=c)
        ax.text(x + w / 2, 0.9, s_, ha="center", va="center", fontsize=7.9, color=MUTED, linespacing=1.3)
        if i < len(steps) - 1:
            arrow(ax, (x + w + 0.03, 1.3), (x + w + gap - 0.03, 1.3), color=LINE)
    save(fig, "workflow")


def _blobs(seed=3):
    rng = np.random.default_rng(seed)
    centers = np.array([[0.0, 0.0], [3.2, 0.4], [1.4, 2.7], [4.4, 3.1]])
    sizes = [42, 34, 30, 22]
    pts = np.vstack([c + rng.normal(0, s, (n, 2)) for c, n, s in zip(centers, sizes, (0.55, 0.5, 0.45, 0.4))])
    noise = rng.uniform([-1.4, -1.4], [6.0, 4.6], (9, 2))
    return pts, noise, centers


def algorithms():
    """The four algorithms at a glance: what each does to the same frames."""
    pts, noise, centers = _blobs()
    allp = np.vstack([pts, noise])
    fig, axs = plt.subplots(1, 4, figsize=(11.2, 3.75))
    def frame(ax, title, give, color):
        ax.set_xlim(-1.8, 6.4); ax.set_ylim(-1.8, 5.0); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
        for s in ax.spines.values():
            s.set_color(tint(color, 0.5))
        ax.set_title(title, fontsize=12, fontweight="bold", color=color, pad=6)
        ax.text(0.5, -0.1, give, transform=ax.transAxes, ha="center", va="top", fontsize=8.6, color=MUTED, linespacing=1.3)
    # KMeans NANI: k seeds from the densest frames, then k-means
    ax = axs[0]
    d = ((allp[:, None, :] - centers[None]) ** 2).sum(-1)
    lab = d.argmin(1)
    for k in range(4):
        q = allp[lab == k]
        ax.scatter(q[:, 0], q[:, 1], s=11, color=PALETTE[k], alpha=0.85, lw=0)
        ax.scatter(*centers[k], marker="X", s=90, color="white", edgecolor=INK, lw=1.0, zorder=3)
    frame(ax, "KMeans NANI", "k clusters, each about its mean;\nseeds from the densest frames\nyou give: k, the seeding", BLUE)
    # DIVINE: the whole split in two, again and again
    ax = axs[1]
    lab = np.where(allp[:, 0] < 2.1, 0, 1)
    lab = np.where((lab == 0) & (allp[:, 1] > 1.4), 2, lab)
    lab = np.where((lab == 1) & (allp[:, 1] > 1.8), 3, lab)
    for k in range(4):
        q = allp[lab == k]
        ax.scatter(q[:, 0], q[:, 1], s=11, color=PALETTE[k], alpha=0.85, lw=0)
    ax.plot([2.1, 2.1], [-1.8, 5.0], color=INK, lw=1.4)
    ax.plot([-1.8, 2.1], [1.4, 1.4], color=INK, lw=1.0, ls="--")
    ax.plot([2.1, 6.4], [1.8, 1.8], color=INK, lw=1.0, ls=":")
    for (x, y, t) in ((2.25, 4.45, "1"), (-1.55, 1.55, "2"), (5.95, 1.95, "3")):
        ax.text(x, y, t, fontsize=9, color="white", fontweight="bold", ha="center", va="center",
                bbox=dict(boxstyle="circle,pad=0.18", fc=INK, ec="none"))
    frame(ax, "DIVINE", "the whole split in two, then the\nloosest cluster, until k\nyou give: k, the split, the anchors", RUST)
    # HELM: many small clusters, merged
    ax = axs[2]
    rng = np.random.default_rng(7)
    small = np.vstack([c + rng.normal(0, 0.45, (3, 2)) for c in centers])
    ds = ((allp[:, None, :] - small[None]) ** 2).sum(-1).argmin(1)
    parent = np.repeat(np.arange(4), 3)
    for j in range(len(small)):
        q = allp[ds == j]
        ax.scatter(q[:, 0], q[:, 1], s=11, color=PALETTE[parent[j]], alpha=0.85, lw=0)
    for k in range(4):
        sk = small[parent == k]
        for a in range(len(sk)):
            for b in range(a + 1, len(sk)):
                ax.plot(*zip(sk[a], sk[b]), color=INK, lw=0.9, alpha=0.7)
        ax.scatter(sk[:, 0], sk[:, 1], s=26, color="white", edgecolor=INK, lw=0.9, zorder=3)
    frame(ax, "HELM", "a first NANI of many clusters,\nthe closest merged, until k\nyou give: k (or a distance), the start", GOLD)
    # eQUAL: clusters within a radius, the rest noise
    ax = axs[3]
    r = 1.15
    taken = np.zeros(len(allp), bool)
    for k, c in enumerate(centers):
        inside = (((allp - c) ** 2).sum(1) <= r * r) & ~taken
        taken |= inside
        q = allp[inside]
        ax.scatter(q[:, 0], q[:, 1], s=11, color=PALETTE[k], alpha=0.85, lw=0)
        ax.add_patch(Circle(c, r, fc="none", ec=PALETTE[k], lw=1.1, ls="--"))
    q = allp[~taken]
    ax.scatter(q[:, 0], q[:, 1], s=13, color="#b8bec6", lw=0)
    ax.text(-1.55, 4.55, "grey: noise", fontsize=8, color=GREY, ha="left", va="center")
    frame(ax, "eQUAL", "clusters within a radius of their\nseeds; frames in none are noise\nyou give: the radius (no k)", GREEN)
    fig.subplots_adjust(wspace=0.08, bottom=0.2)
    save(fig, "algorithms")


def groups():
    """Where each frame came from, against its cluster."""
    rng = np.random.default_rng(11)
    fig = plt.figure(figsize=(10.4, 3.4))
    # the frames, by group
    ax = fig.add_axes([0.02, 0.18, 0.27, 0.66]); ax.axis("off")
    ax.set_xlim(0, 10); ax.set_ylim(0, 10)
    names = ["replica 1", "replica 2", "replica 3"]
    gcol = [BLUE, GOLD, RUST]
    for j, (nm, c) in enumerate(zip(names, gcol)):
        y = 7.6 - j * 3.0
        ax.text(0, y + 0.95, nm, fontsize=9, color=c, fontweight="bold")
        ax.add_patch(FancyBboxPatch((0, y - 0.65), 9.6, 1.25, boxstyle="round,pad=0,rounding_size=0.25", fc=tint(c, 0.85), ec=tint(c, 0.4)))
        for i in range(24):
            ax.add_patch(FancyBboxPatch((0.25 + i * 0.385, y - 0.42), 0.26, 0.8, boxstyle="round,pad=0,rounding_size=0.06", fc=c, ec="none", alpha=0.8))
    ax.text(0, -0.6, "each frame's group: the replica, condition\nor method it came from (vmdance groups)", fontsize=8, color=MUTED, linespacing=1.3)
    # the make-up
    ax = fig.add_axes([0.37, 0.25, 0.27, 0.55])
    shares = np.array([[0.62, 0.30, 0.08], [0.20, 0.25, 0.55], [0.34, 0.33, 0.33], [0.05, 0.85, 0.10]])
    sizes = np.array([160, 120, 90, 50])
    left = np.zeros(4)
    for j in range(3):
        ax.barh(np.arange(4), shares[:, j] * sizes, left=left, color=gcol[j], height=0.62, edgecolor="white", lw=0.8)
        left += shares[:, j] * sizes
    ax.set_yticks(range(4), [f"cluster {c}" for c in range(4)], fontsize=8.5)
    ax.invert_yaxis()
    ax.set_xlabel("frames", fontsize=8.5, color=MUTED)
    ax.tick_params(colors=MUTED, labelsize=8)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.set_title("Make-up: each cluster by group", fontsize=10, fontweight="bold", color=INK, loc="left")
    # the map
    ax = fig.add_axes([0.71, 0.2, 0.27, 0.62])
    cs = np.array([[-3, 0.5], [2.5, 2], [0.5, -2.5], [4, -1.5]])
    for j in range(3):
        mix = shares[:, j] / shares[:, j].sum()
        idx = rng.choice(4, 70, p=mix)
        p = cs[idx] + rng.normal(0, 0.8, (70, 2))
        ax.scatter(p[:, 0], p[:, 1], s=9, color=gcol[j], alpha=0.8, lw=0)
    ax.set_xlabel("PC 1 (Å)", fontsize=8.5, color=MUTED); ax.set_ylabel("PC 2 (Å)", fontsize=8.5, color=MUTED)
    ax.set_xticks([]); ax.set_yticks([])
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.set_title("Map: the frames on two axes", fontsize=10, fontweight="bold", color=INK, loc="left")
    fig.text(0.315, 0.52, "→", fontsize=22, color=LINE, ha="center", va="center")
    fig.text(0.675, 0.52, "→", fontsize=22, color=LINE, ha="center", va="center")
    save(fig, "groups")


def flows():
    """The Graphviz diagrams: docs/diagrams/*.dot."""
    if shutil.which("dot") is None:
        print("dot not found: the flows are not made")
        return
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".dot"):
            continue
        name = f[:-4]
        for ext, extra in (("svg", []), ("png", ["-Gdpi=200"])):
            subprocess.run(["dot", f"-T{ext}", *extra, os.path.join(SRC, f), "-o", os.path.join(OUT, f"{name}.{ext}")], check=True)
        print("wrote", name)


if __name__ == "__main__":
    architecture()
    workflow()
    algorithms()
    groups()
    flows()
