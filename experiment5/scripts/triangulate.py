"""Build the initial Constrained Delaunay Triangulation (CDT) for Experiment 5.

Option A: vertex set = polygon vertices + sensor centers (Steiner points).
The polygon boundary is enforced as a PSLG; sensor centers become interior
vertices. Flag `pq30` preserves the boundary and asks for a minimum angle
of 30 degrees. No max-area refinement is requested at this stage — the
adaptive symbolic refinement (next step) will subdivide where needed.

Inputs
------
- processed/campus_normalized.json   (polygon in normalized [0,1] coords)
- data/campus_sensors.json           (sensor centers)

Outputs
-------
- results/campus_initial_triangulation.json
- figs/campus_initial_triangulation.{pdf,png}

The output JSON schema mirrors what the BDD solver will read in the next
step. Each triangle is a triple of vertex indices; the triangles inside
the polygon are kept and those outside (Triangle creates a convex-hull
mesh) are filtered out using point-in-polygon on the centroid.
"""
from __future__ import annotations

import json
import hashlib
from pathlib import Path

import numpy as np
import triangle as tr
from shapely.geometry import Point, Polygon

HERE = Path(__file__).resolve().parent.parent
POLY_FILE = HERE / "processed" / "campus_normalized.json"
SENS_FILE = HERE / "data" / "campus_sensors.json"
OUT_JSON = HERE / "results" / "campus_initial_triangulation.json"
OUT_PDF = HERE / "figs" / "campus_initial_triangulation.pdf"
OUT_PNG = HERE / "figs" / "campus_initial_triangulation.png"

TRIANGLE_FLAGS = "p"  # PSLG, no quality refinement — vertices are exactly
                       # polygon vertices + sensor centers (Steiner). Triangle
                       # quality is left to the adaptive refinement step.


def build_pslg(polygon: list, sensors: list):
    """Build the PSLG input dict for the `triangle` library.

    Polygon vertices come first (indices 0..n-1), followed by sensor
    centers as interior Steiner points. Segments form a closed loop
    around the polygon vertices.
    """
    n_poly = len(polygon)
    verts = list(polygon) + [[c["x"], c["y"]] for c in sensors]
    segs = [[i, (i + 1) % n_poly] for i in range(n_poly)]
    return {
        "vertices": np.asarray(verts, dtype=float),
        "segments": np.asarray(segs, dtype=int),
    }, n_poly


def filter_inside(mesh, polygon: Polygon):
    """Keep only triangles whose centroid lies inside the polygon.

    `triangle` may produce triangles in the convex hull but outside the
    polygon (since the polygon is non-convex). We discard those.
    """
    V = mesh["vertices"]
    T = mesh["triangles"]
    keep = []
    for tri in T:
        cx = float(np.mean(V[tri, 0]))
        cy = float(np.mean(V[tri, 1]))
        if polygon.contains(Point(cx, cy)):
            keep.append([int(i) for i in tri])
    return [[float(x), float(y)] for x, y in V.tolist()], keep


def write_figure(verts, tris, sensors, bbox):
    import matplotlib.pyplot as plt
    from matplotlib.collections import LineCollection
    fig, ax = plt.subplots(figsize=(6.5, 6.5 * bbox[3]))
    V = np.asarray(verts)
    # triangulation edges
    edges = set()
    for t in tris:
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            edges.add((min(a, b), max(a, b)))
    segs = [[V[a], V[b]] for a, b in edges]
    ax.add_collection(LineCollection(segs, colors="0.55", linewidths=0.4))
    # sensor centers (markers; same set is already in V at interior indices)
    xs = [c["x"] for c in sensors]
    ys = [c["y"] for c in sensors]
    ax.scatter(xs, ys, c="black", s=8, zorder=3)
    ax.set_xlim(-0.02, 1.02)
    ax.set_ylim(-0.02, bbox[3] + 0.02)
    ax.set_aspect("equal")
    ax.set_xlabel("x (normalized)")
    ax.set_ylabel("y (normalized)")
    ax.set_title(f"Initial CDT: {len(verts)} vertices, {len(tris)} triangles")
    fig.tight_layout()
    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT_PDF)
    fig.savefig(OUT_PNG, dpi=150)


def main() -> None:
    poly_data = json.loads(POLY_FILE.read_text())
    sens_data = json.loads(SENS_FILE.read_text())
    polygon_pts = poly_data["polygon"]
    sensors = sens_data["circles"]
    bbox = poly_data["bbox_normalized"]
    poly_shp = Polygon(polygon_pts)

    pslg, n_poly = build_pslg(polygon_pts, sensors)
    n_sensors = len(sensors)
    print(f"PSLG: {n_poly} polygon vertices, {n_sensors} sensor centers, "
          f"{len(pslg['segments'])} segments")

    mesh = tr.triangulate(pslg, TRIANGLE_FLAGS)
    print(f"raw mesh: {len(mesh['vertices'])} vertices, "
          f"{len(mesh['triangles'])} triangles")

    verts, tris = filter_inside(mesh, poly_shp)
    n_after = len(mesh["vertices"])
    print(f"after polygon clip: {len(tris)} triangles "
          f"(triangle added {n_after - (n_poly + n_sensors)} Steiner points)")

    # Sensor-vertex mapping: indices 0..n_poly-1 are polygon vertices;
    # indices n_poly..n_poly+n_sensors-1 are sensor centers in the same
    # order as circles in campus_sensors.json. Steiner points added by
    # `triangle` (if any) follow.
    sensor_vertex_index = list(range(n_poly, n_poly + n_sensors))

    payload = {
        "_meta": {
            "generator": "experiment5/scripts/triangulate.py",
            "flags": TRIANGLE_FLAGS,
            "n_polygon_vertices": n_poly,
            "n_sensors": n_sensors,
            "n_steiner_added": n_after - (n_poly + n_sensors),
            "n_total_vertices": len(verts),
            "n_triangles_inside": len(tris),
            "sensors_sha256": sens_data["_meta"]["circles_sha256"],
        },
        "vertices": verts,
        "triangles": tris,
        "sensor_vertex_index": sensor_vertex_index,
    }
    canonical = json.dumps({"vertices": verts, "triangles": tris},
                           sort_keys=True, separators=(",", ":"))
    payload["_meta"]["mesh_sha256"] = hashlib.sha256(
        canonical.encode("utf-8")).hexdigest()

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(payload, indent=2))
    print(f"wrote {OUT_JSON}")
    print(f"mesh_sha256 = {payload['_meta']['mesh_sha256']}")

    write_figure(verts, tris, sensors, bbox)
    print(f"wrote {OUT_PDF}")
    print(f"wrote {OUT_PNG}")


if __name__ == "__main__":
    main()
