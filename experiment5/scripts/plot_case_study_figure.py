"""Case-study figures for IEEE TR Section VI.

Two standalone single-column figures (drawn separately so neither is shrunk):
- campus_sensors.pdf : campus polygon with the PDS-placed sensor disks.
- campus_cdt.pdf     : initial CDT (polygon + sensor centers as Steiner points).

Grayscale only (IEEE print). Writes the PDFs (canonical, copied to
manuscript/figs) and matching PNG previews to experiment5/results/.
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import LineCollection
from matplotlib.patches import Circle, Polygon as MplPolygon

HERE         = Path(__file__).resolve().parent.parent
SENS         = HERE / "data"     / "campus_sensors.json"
MESH         = HERE / "results"  / "campus_initial_triangulation.json"
OUT_SENS_PDF = HERE / "results"  / "campus_sensors.pdf"
OUT_SENS_PNG = HERE / "results"  / "campus_sensors.png"
OUT_CDT_PDF  = HERE / "results"  / "campus_cdt.pdf"
OUT_CDT_PNG  = HERE / "results"  / "campus_cdt.png"


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
    ax.set_ylabel("y (normalized)")


def main() -> None:
    sens = json.loads(SENS.read_text())
    mesh = json.loads(MESH.read_text())

    poly    = sens["polygon"]
    bbox    = sens["bbox_normalized"]
    circles = sens["circles"]
    verts   = mesh["vertices"]
    tris    = mesh["triangles"]

    h = 4.4 * bbox[3] + 0.45        # height proportional to the y-extent

    fig_s, ax_s = plt.subplots(figsize=(4.4, h))
    draw_sensors_panel(ax_s, poly, circles, bbox)
    fig_s.tight_layout()
    OUT_SENS_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig_s.savefig(OUT_SENS_PDF)
    fig_s.savefig(OUT_SENS_PNG, dpi=150)
    plt.close(fig_s)

    fig_c, ax_c = plt.subplots(figsize=(4.4, h))
    draw_mesh_panel(ax_c, poly, verts, tris, circles, bbox)
    fig_c.tight_layout()
    fig_c.savefig(OUT_CDT_PDF)
    fig_c.savefig(OUT_CDT_PNG, dpi=150)
    plt.close(fig_c)

    print(f"wrote {OUT_SENS_PDF}")
    print(f"wrote {OUT_CDT_PDF}")


if __name__ == "__main__":
    main()
