# Experiment 5 — reproducibility manifest

All scientific outputs of Experiment 5 are byte-for-byte (or content-byte-for-content-byte, excluding wall-time fields) reproducible from the inputs listed below.

## Pipeline

```
processed/campus_normalized.json
        │ (Python: shapely + random, seed=42)
        ▼
data/campus_sensors.json
        │ (Python: triangle library, flag "p")
        ▼
results/campus_initial_triangulation.json
        │ (Julia 1.10 + MiniCUDD in cudd-julia Docker image)
        ▼
results/campus_bounds.csv
results/campus_summary.json
results/campus_sweep_pk.csv
        │ (Python: matplotlib)
        ▼
results/campus_figure.pdf   →   manuscript/figs/campus_figure.pdf
```

## Reproduce from scratch

```bash
cd pgcp-experiments/experiment5

# 1. PDS sensor placement (Python; deterministic)
python3 scripts/gen_sensors.py

# 2. Initial CDT (Python; deterministic)
python3 scripts/triangulate.py

# 3. BDD solve + per-level snapshots (Julia/MiniCUDD via Docker)
docker run --rm -v "$(pwd)/..:/work" -w /work cudd-julia \
    julia experiment5/scripts/run_triangle_bdd.jl 12 xcoordinate

# 4. p_k sensitivity sweep (re-evaluates the converged BDD, no resolve)
docker run --rm -v "$(pwd)/..:/work" -w /work cudd-julia \
    julia experiment5/scripts/sweep_pk.jl 12 xcoordinate

# 5. Case-study figure (Python)
python3 scripts/plot_case_study_figure.py
cp results/campus_figure.pdf ../../manuscript/figs/campus_figure.pdf

# 6. Verify hashes match below
python3 scripts/hash_results.py
```

## Fixed parameters

| Step | Parameter             | Value                              |
|------|-----------------------|------------------------------------|
| 1    | RNG seed              | `42`                               |
| 1    | Sensor radii          | `{0.089, 0.178}` (= 200 m, 400 m)  |
| 1    | Large fraction        | `0.5`                              |
| 1    | PDS min-distance      | `0.089` (= small radius)           |
| 1    | PDS max failures      | `10000`                            |
| 1    | Component reliability | `p_k = 0.9` (baseline)             |
| 2    | Triangle flags        | `"p"` (PSLG only, no Steiner)      |
| 3    | BDD variable ordering | `xcoordinate` (sort by x)          |
| 3    | maxlevel              | `12` (converges at level 11)       |

## Expected hashes (regenerate with `python3 scripts/hash_results.py`)

### Raw-file SHA-256

```
d19afc3f816850b524d48ebdf74418d2ec7e7f3aa97d679ad4cfe25ea3700205  processed/campus_normalized.json
c18c0fe4f26f9e05bb90e8e3a5cbe3ec1bfec71a392377bc567733e226a13c7f  data/campus_sensors.json
97c26bc7d842326832064bcfa2cc6748dd4c104f04706e61b823170742f18a02  results/campus_initial_triangulation.json
a4396e42989a2f8af76ff3002ab4ef0b07a16bf52a032246e169cbb05ab97802  results/campus_sweep_pk.csv
```

### Content SHA-256 (timing fields excluded)

```
ff5056cdc953df62142e5c73b6bf2b1001a33c0a6d80f03f9ff7139fe9a24bd7  results/campus_bounds.csv   (drops 'time_sec' column)
f080a5fcb3b5149cdc43225c8f7ba6f9e3eb1c1db2eb4bff6fefbcdc95de35f4  results/campus_summary.json (drops 'wall_time_sec')
```

### Embedded `_meta` content hashes (self-identifying inside the JSONs)

```
data/campus_sensors.json._meta.circles_sha256
   c8ff0cb73cac023c146b2e571843e35ea12babee3c23cbf60b5ef9e13c396f89
results/campus_initial_triangulation.json._meta.mesh_sha256
   134dae749ee668063a594676e8c04bdb65d0feb6fffe92541f1dc3af9ca07960
```

## Headline numbers (immutable across reproducible runs)

| Quantity                                          | Value                            |
|---------------------------------------------------|----------------------------------|
| Polygon area (normalized)                         | 0.5048                           |
| Number of sensors                                 | 53 (27 small, 26 large)          |
| Initial CDT vertices                              | 276 (223 polygon + 53 sensor)    |
| Initial CDT triangles                             | 326                              |
| Convergence level                                 | 11 (out of maxlevel = 12)        |
| Total triangles processed (sum over all levels)   | 2 214                            |
| Peak BDD nodes (incl. snapshot overhead)          | 24 528                           |
| **R = R_lower = R_upper at p_k = 0.9**            | **0.44769162907809484**          |
| Effective number of critical sensors (log R / log p_k) | 7.6280                      |

The per-level `R_lower` / `R_upper` columns in `campus_bounds.csv` report
**certified bounds over the full partition** at end-of-level: the snapshot
ANDs in the pending triangles' `phi_1` / `phi_2` so the bracket reflects
resolved triangles *and* refined-child triangles still in the queue. The
two sequences are monotone (R_lower non-decreasing, R_upper non-increasing)
and meet at level 10. Side effect: this snapshot computation creates
transient BDDs that inflate CUDD's cumulative peak counter from the
algorithm-only value of 17 374 to 24 528; the inflation does not affect
the final converged value `R = 0.44769162907809484`.

### `p_k` sensitivity (from `campus_sweep_pk.csv`)

| p_k     | R                |
|---------|------------------|
| 0.500   | 0.0007489...     |
| 0.700   | 0.0405077...     |
| 0.800   | 0.1569961...     |
| 0.850   | 0.2743300...     |
| 0.900   | **0.4476916...** |
| 0.920   | 0.5351547...     |
| 0.950   | 0.6874185...     |
| 0.970   | 0.8034998...     |
| 0.990   | 0.9315013...     |
| 0.995   | 0.9653753...     |
| 0.999   | 0.9930145...     |

## What is NOT byte-stable

- `time_sec` and `wall_time_sec` columns/fields. These reflect wall-clock duration in the Docker container at the moment of the run and naturally vary; they are excluded from the content hashes.
- `results/campus_figure.pdf` contains a creation timestamp in its metadata; the figure is derived from the (hashed) JSON inputs and is regenerated from those, so we do not hash the PDF directly.

## Environment

- Host: macOS Darwin 25.1.0, arm64.
- Python: 3.9.6 (system) with `shapely==2.0.7`, `triangle`, `numpy`, `matplotlib==3.9.4`.
- Julia: 1.10 inside `cudd-julia` Docker image (built from `pgcp-experiments/Dockerfile`).
- BDD backend: MiniCUDD.jl (CUDD wrapper) — *not* `dd.cudd` or `dd.autoref`.
