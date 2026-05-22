"""Sensor importance map for IEEE TR Section VII-F.

Single panel: the campus polygon with every sensor drawn as a marker shaded
and sized by its Birnbaum importance dR/dp_k. Faint disk outlines give the
coverage context. The seven essential sensors (importance R/p_k, the maximum)
are ringed.

Grayscale only (IEEE print). Importance is read from campus_importance.csv,
which is produced by analyze_campus.jl. Writes
- experiment5/results/campus_importance_figure.pdf  (canonical, copied to manuscript/figs)
- experiment5/results/campus_importance_figure.png  (preview)
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
from matplotlib.cm import ScalarMappable
from matplotlib.patches import Circle, Polygon as MplPolygon

HERE    = Path(__file__).resolve().parent.parent
SENS    = HERE / "data"    / "campus_sensors.json"
IMP     = HERE / "results" / "campus_importance.csv"
OUT_PDF = HERE / "results" / "campus_importance_figure.pdf"
OUT_PNG = HERE / "results" / "campus_importance_figure.png"

# Light-gray (low importance) to near-black (high importance).
CMAP = LinearSegmentedColormap.from_list("imp", ["0.88", "0.05"])


def load_sensors():
    rows = []
    with IMP.open() as f:
        for r in csv.DictReader(f):
            rows.append(dict(
                name=r["name"],
                x=float(r["x"]), y=float(r["y"]), radius=float(r["radius"]),
                birnbaum=float(r["birnbaum"]),
            ))
    return rows


def main() -> None:
    sens = json.loads(SENS.read_text())
    poly = sens["polygon"]
    bbox = sens["bbox_normalized"]
    rows = load_sensors()

    imax = max(r["birnbaum"] for r in rows)
    norm = Normalize(vmin=0.0, vmax=imax)
    essential = [r for r in rows if r["birnbaum"] >= imax - 1e-9]

    fig, ax = plt.subplots(figsize=(4.6, 4.6 * bbox[3] + 0.55))

    # campus polygon
    ax.add_patch(MplPolygon(poly, closed=True, facecolor="0.96",
                            edgecolor="black", linewidth=1.0, zorder=1))

    # faint coverage-disk outlines for spatial context
    for r in rows:
        ax.add_patch(Circle((r["x"], r["y"]), r["radius"], facecolor="none",
                            edgecolor="0.72", linewidth=0.35, zorder=2))

    # sensor centres: shade and size by Birnbaum importance
    sizes  = [22.0 + 165.0 * (r["birnbaum"] / imax) for r in rows]
    colors = [CMAP(norm(r["birnbaum"])) for r in rows]
    ax.scatter([r["x"] for r in rows], [r["y"] for r in rows],
               s=sizes, facecolors=colors, edgecolors="black",
               linewidths=0.5, zorder=4)

    # ring the essential sensors
    ax.scatter([r["x"] for r in essential], [r["y"] for r in essential],
               s=320.0, facecolors="none", edgecolors="black",
               linewidths=1.3, zorder=5)

    ax.set_xlim(-0.03, 1.03)
    ax.set_ylim(-0.03, bbox[3] + 0.03)
    ax.set_aspect("equal")
    ax.set_xlabel("x (normalized)")
    ax.set_ylabel("y (normalized)")

    sm = ScalarMappable(norm=norm, cmap=CMAP)
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=ax, fraction=0.046, pad=0.03,
                        orientation="vertical")
    cbar.set_label(r"Birnbaum importance $\partial R / \partial p_k$")

    fig.tight_layout()
    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_PDF)
    fig.savefig(OUT_PNG, dpi=150)
    print(f"wrote {OUT_PDF}")
    print(f"wrote {OUT_PNG}")
    print(f"essential sensors ({len(essential)}): "
          f"{', '.join(sorted(r['name'] for r in essential))}")


if __name__ == "__main__":
    main()
