"""Plot campus polygon with PDS-placed sensors (disks)."""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon as MplPolygon

HERE = Path(__file__).resolve().parent.parent
DATA = HERE / "data" / "campus_sensors.json"
OUT_PDF = HERE / "figs" / "campus_with_sensors.pdf"
OUT_PNG = HERE / "figs" / "campus_with_sensors.png"


def main() -> None:
    d = json.loads(DATA.read_text())
    poly = d["polygon"]
    circles = d["circles"]
    bbox = d["bbox_normalized"]

    fig, ax = plt.subplots(figsize=(6.5, 6.5 * bbox[3]))

    # campus polygon
    ax.add_patch(MplPolygon(poly, closed=True, facecolor="0.92",
                            edgecolor="black", linewidth=1.2, zorder=1))

    # sensor disks (two grayscales for the two radii)
    for c in circles:
        r = c["radius"]
        face = "0.55" if r == 0.089 else "0.75"
        ax.add_patch(Circle((c["x"], c["y"]), r,
                            facecolor=face, edgecolor="black",
                            linewidth=0.6, alpha=0.45, zorder=2))

    # sensor centers
    xs = [c["x"] for c in circles]
    ys = [c["y"] for c in circles]
    ax.scatter(xs, ys, c="black", s=12, zorder=3)
    for c in circles:
        ax.annotate(c["name"], (c["x"], c["y"]),
                    fontsize=6, color="black",
                    xytext=(2, 2), textcoords="offset points")

    ax.set_xlim(-0.02, 1.02)
    ax.set_ylim(-0.02, bbox[3] + 0.02)
    ax.set_aspect("equal")
    ax.set_xlabel("x (normalized)")
    ax.set_ylabel("y (normalized)")
    ax.set_title(f"Campus polygon with {len(circles)} PDS-placed sensors")

    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(OUT_PDF)
    fig.savefig(OUT_PNG, dpi=150)
    print(f"wrote {OUT_PDF}")
    print(f"wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
