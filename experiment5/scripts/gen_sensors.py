"""Generate sensor configuration for Experiment 5 (campus polygon).

Poisson disk sampling inside the Higashi-Hiroshima campus polygon.
Target 25-30 sensors, radii i.i.d. uniform from {0.089, 0.178},
PDS min-distance 0.0888 (= 200 m / 2251.7 m), seed 42, p_k=0.9.

Writes data/campus_sensors.json.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from shapely.geometry import Point, Polygon

HERE = Path(__file__).resolve().parent.parent
POLY_FILE = HERE / "processed" / "campus_normalized.json"
OUT_FILE = HERE / "data" / "campus_sensors.json"

SEED = 42
RADII_SMALL = 0.089   # = 200 m / 2251.7 m
RADII_LARGE = 0.178   # = 400 m / 2251.7 m
LARGE_FRACTION = 0.5  # fraction of sensors upgraded to the large radius
P_K = 0.9
# PDS placement uses the small radius as the minimum-separation. Two
# small disks can therefore touch but not overlap; large disks may
# overlap each other or small disks (they are placed after positions
# are fixed). Letting the dart-throwing loop saturate gives the
# highest density consistent with this separation rule.
PDS_MIN_DIST = RADII_SMALL
N_TARGET_MAX = 200  # effectively unbounded; saturation stops the loop
PDS_MAX_FAILURES = 10000


def load_polygon() -> Polygon:
    data = json.loads(POLY_FILE.read_text())
    return Polygon(data["polygon"]), data["bbox_normalized"]


def poisson_disk_sample(poly: Polygon, bbox, min_dist: float, rng: random.Random,
                        n_target_max: int,
                        max_consecutive_failures: int = 5000):
    """Rejection-based PDS (dart-throwing) inside a polygon.

    More robust than Bridson on non-convex / disconnected regions: every
    new sample is drawn uniformly inside the bbox and accepted iff it lies
    inside the polygon and is at least min_dist from all existing samples.
    Stops at saturation (max_consecutive_failures rejections in a row) or
    at the n_target_max hard cap.
    """
    xmin, ymin, xmax, ymax = bbox
    samples: list[tuple[float, float]] = []
    d2 = min_dist * min_dist

    def too_close(px, py):
        for sx, sy in samples:
            if (sx - px) ** 2 + (sy - py) ** 2 < d2:
                return True
        return False

    failures = 0
    while len(samples) < n_target_max and failures < max_consecutive_failures:
        x = rng.uniform(xmin, xmax)
        y = rng.uniform(ymin, ymax)
        if not poly.contains(Point(x, y)):
            failures += 1
            continue
        if too_close(x, y):
            failures += 1
            continue
        samples.append((x, y))
        failures = 0

    return samples


def main() -> None:
    poly_data = json.loads(POLY_FILE.read_text())
    poly = Polygon(poly_data["polygon"])
    bbox = poly_data["bbox_normalized"]

    rng = random.Random(SEED)
    samples = poisson_disk_sample(poly, bbox, PDS_MIN_DIST, rng,
                                  n_target_max=N_TARGET_MAX,
                                  max_consecutive_failures=PDS_MAX_FAILURES)
    n = len(samples)
    print(f"PDS saturated at {n} samples (min_dist = {PDS_MIN_DIST:.4f})")

    # All positions are placed under the small-radius separation. After
    # positions are fixed, upgrade a random subset to the large radius.
    n_large = int(round(n * LARGE_FRACTION))
    large_idx = set(rng.sample(range(n), n_large))
    print(f"radius assignment: {n - n_large} small (r={RADII_SMALL}), "
          f"{n_large} large (r={RADII_LARGE})")

    circles = []
    for k, (x, y) in enumerate(samples):
        r = RADII_LARGE if k in large_idx else RADII_SMALL
        circles.append({"name": str(k + 1), "x": x, "y": y, "radius": r})

    import hashlib

    # canonical representation of the (positions, radii) tuple, used both
    # as a content hash for downstream sanity checks and to make the
    # configuration self-identifying.
    canonical = json.dumps(circles, sort_keys=True, separators=(",", ":"))
    sha = hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    out = {
        "config": "experiment5/processed/campus_normalized.json",
        "gridsize": 4,
        "maxlevel": 8,
        "reliability": P_K,
        "polygon": poly_data["polygon"],
        "side_meters": poly_data["side_meters"],
        "bbox_normalized": bbox,
        "circles": circles,
        "_meta": {
            "generator": "experiment5/scripts/gen_sensors.py",
            "seed": SEED,
            "radii_small": RADII_SMALL,
            "radii_large": RADII_LARGE,
            "large_fraction": LARGE_FRACTION,
            "pds_min_dist": PDS_MIN_DIST,
            "pds_max_failures": PDS_MAX_FAILURES,
            "n_target_max": N_TARGET_MAX,
            "n_sensors": n,
            "n_small": n - n_large,
            "n_large": n_large,
            "circles_sha256": sha,
        },
    }
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(out, indent=2))
    print(f"wrote {OUT_FILE}")
    print(f"circles_sha256 = {sha}")


if __name__ == "__main__":
    main()
