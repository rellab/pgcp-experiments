"""Two-panel case-study figure for IEEE TR §VI-H.

Left  : campus polygon with PDS-placed sensor disks.
Right : initial CDT (polygon + sensor centers as Steiner points).

Grayscale only (IEEE print). Writes
- experiment5/results/campus_figure.pdf  (canonical, copied to manuscript/figs)
- experiment5/results/campus_figure.png  (preview)
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection
from matplotlib.patches import Circle, Polygon as MplPolygon

HERE     = Path(__file__).resolve().parent.parent
SENS     = HERE / "data"     / "campus_sensors.json"
MESH     = HERE / "results"  / "campus_initial_triangulation.json"
OUT_PDF  = HERE / "results"  / "campus_figure.pdf"
OUT_PNG  = HERE / "results"  / "campus_figure.png"


def draw_sensors_panel(ax, poly, circles, bbox):
    ax.add_patch(MplPolygon(poly, closed=True, facecolor="0.92",
                            edgecolor="black", linewidth=1.0, zorder=1))
    for c in circles:
        r = c["radius"]
        face = "0.55" if r < 0.1 else "0.78"
        ax.add_patch(Circle((c["x"], c["y"]), r,
                            facecolor=face, edgecolor="black",
                            linewidth=0.4, alpha=0.40, zorder=2))
    xs = [c["x"] for c in circles]
    ys = [c["y"] for c in circles]
    ax.scatter(xs, ys, c="black", s=6, zorder=3)
    ax.set_xlim(-0.02, 1.02)
    ax.set_ylim(-0.02, bbox[3] + 0.02)
    ax.set_aspect("equal")
    ax.set_xlabel("x (normalized)")
    ax.set_ylabel("y (normalized)")
    ax.set_title(f"(a) Campus polygon and {len(circles)} sensor disks")


def draw_mesh_panel(ax, poly, verts, tris, sensors, bbox):
    ax.add_patch(MplPolygon(poly, closed=True, facecolor="0.97",
                            edgecolor="black", linewidth=1.0, zorder=1))
    V = np.asarray(verts)
    edges = set()
    for t in tris:
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            edges.add((min(a, b), max(a, b)))
    segs = [[V[a], V[b]] for a, b in edges]
    ax.add_collection(LineCollection(segs, colors="0.45",
                                     linewidths=0.35, zorder=2))
    xs = [c["x"] for c in sensors]
    ys = [c["y"] for c in sensors]
    ax.scatter(xs, ys, c="black", s=6, zorder=3)
    ax.set_xlim(-0.02, 1.02)
    ax.set_ylim(-0.02, bbox[3] + 0.02)
    ax.set_aspect("equal")
    ax.set_xlabel("x (normalized)")
    ax.set_title(f"(b) Initial CDT: {len(verts)} vertices, {len(tris)} triangles")


def main() -> None:
    sens = json.loads(SENS.read_text())
    mesh = json.loads(MESH.read_text())

    poly    = sens["polygon"]
    bbox    = sens["bbox_normalized"]
    circles = sens["circles"]
    verts   = mesh["vertices"]
    tris    = mesh["triangles"]

    panel_h = 4.0 * bbox[3]          # height proportional to y-extent
    fig, (axL, axR) = plt.subplots(1, 2, figsize=(9.0, panel_h + 0.6))

    draw_sensors_panel(axL, poly, circles, bbox)
    draw_mesh_panel   (axR, poly, verts, tris, circles, bbox)

    fig.tight_layout()
    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_PDF)
    fig.savefig(OUT_PNG, dpi=150)
    print(f"wrote {OUT_PDF}")
    print(f"wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
