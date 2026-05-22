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
results/campus_importance.csv      (Birnbaum / criticality importance)
results/campus_minsets.json        (min-path / min-cut sets)
        │ (Python: matplotlib)
        ▼
results/campus_sensors.pdf            →  manuscript/figs/campus_sensors.pdf
results/campus_cdt.pdf                →  manuscript/figs/campus_cdt.pdf
results/campus_importance_figure.pdf  →  manuscript/figs/campus_importance_figure.pdf
```

## Reproduce from scratch

```bash
cd pgcp-experiments/experiment5

# 1. PDS sensor placement (Python; deterministic)
python3 scripts/gen_sensors.py

# 2. Initial CDT (Python; deterministic)
python3 scripts/triangulate.py

# 3. BDD solve, separate run to termination per maxLevel (Julia/MiniCUDD via Docker)
docker run --rm -v "$(pwd)/..:/work" -w /work cudd-julia \
    julia experiment5/scripts/run_triangle_bdd_perlevel.jl 11 xcoordinate

# 4. p_k sensitivity sweep (re-evaluates the converged BDD, no resolve)
docker run --rm -v "$(pwd)/..:/work" -w /work cudd-julia \
    julia experiment5/scripts/sweep_pk.jl 12 xcoordinate

# 5. Importance + minimal-set analysis of the converged BDD (Julia/MiniCUDD)
docker run --rm -v "$(pwd)/..:/work" -w /work cudd-julia \
    julia experiment5/scripts/analyze_campus.jl 12 xcoordinate

# 6. Case-study figures (Python)
python3 scripts/plot_case_study_figure.py
cp results/campus_sensors.pdf results/campus_cdt.pdf ../../manuscript/figs/
python3 scripts/plot_importance_figure.py
cp results/campus_importance_figure.pdf ../../manuscript/figs/campus_importance_figure.pdf

# 7. Verify hashes match below
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
| 3    | maxLevel protocol     | separate run to termination, `maxLevel = 1..11` |
| 3    | Convergence           | at `maxLevel = 11` (`Phi1 == Phi2`) |

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
a04139201786bfc7b963c88c17625f6237ec0e4f838d017459109bcbf0c3f8ec  results/campus_bounds.csv   (drops 'time_sec' column)
4021dcc5587b6436d6f1c643744080577176bb55f5ffd20334d399bb7eb2f4b1  results/campus_summary.json (drops 'wall_time_sec')
```

### Analysis outputs — raw SHA-256 (no timing fields)

```
1a0648b5fd5ffe2abb39b5cfca120a666e898caa9f1d48d330d097880ddecc3a  results/campus_importance.csv
70917dd5e635f85630c07bb1cd8cf7873fdcf7c808cd8b1894b622a5e43b8cf9  results/campus_minsets.json
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
| Convergence `maxLevel`                            | 11                               |
| Triangles popped, converged run (`maxLevel = 11`) | 2 214                            |
| Peak BDD nodes, converged run                     | 17 374                           |
| **R = R_lower = R_upper at p_k = 0.9**            | **0.44769162907809484**          |
| Effective number of critical sensors (log R / log p_k) | 7.6280                      |

Each row of `campus_bounds.csv` is the terminal state of an independent
run of Algorithm 2 at a fixed `maxLevel` (driver
`scripts/run_triangle_bdd_perlevel.jl`); the solver is invoked fresh for
every row. `R_lower` / `R_upper` are the certified bounds `Pr(Phi_2)` /
`Pr(Phi_1)` over the final partition of that run. Both sequences are
monotone in `maxLevel` (R_lower non-decreasing, R_upper non-increasing)
and coincide at `maxLevel = 11`, where the run also verifies the global
equivalence `Phi_1 == Phi_2` and terminates with `converged = true`. The
driver passes `pb = nothing` to the solver, so the solver's per-level
snapshot instrumentation does no transient AND-chain work; the reported
`peak_nodes` is therefore the algorithm-only peak (17 374 at the
converged run), with no snapshot inflation.

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

### Importance and minimal-set analysis (from `campus_importance.csv`, `campus_minsets.json`)

Computed from the converged BDD by `scripts/analyze_campus.jl`, which uses
`scripts/bdd_analysis.jl` (the MiniCUDD port of FaultTree.jl's `minsol` and
`grad`). All quantities are at `p_k = 0.9`.

| Quantity                                    | Value                     |
|---------------------------------------------|---------------------------|
| Essential sensors (criticality 1)           | 7                         |
| Birnbaum importance of an essential sensor  | 0.49743514... (= R/p_k)   |
| Sensors with nonzero Birnbaum importance    | 36 of 53                  |
| Sensors not affecting Phi                   | 17                        |
| Min-cut sets                                | 29 (cardinality 1..5)     |
| Singleton min-cut sets                      | 7 (the essential sensors) |
| Min-path sets                               | 1842 (cardinality 15..19) |

The seven essential sensors are `{13, 16, 22, 25, 26, 30, 53}`. Each lies on
every min-path set and is a singleton min-cut set. The analysis is a
marginal-cost traversal of the same converged BDD that produced `R`; it
builds no new geometry and does not change `R`.

## What is NOT byte-stable

- `time_sec` and `wall_time_sec` columns/fields. These reflect wall-clock duration in the Docker container at the moment of the run and naturally vary; they are excluded from the content hashes.
- `results/campus_sensors.pdf`, `results/campus_cdt.pdf`, and `results/campus_importance_figure.pdf` contain a creation timestamp in their metadata; the figures are derived from the (hashed) JSON inputs and regenerated from those, so we do not hash the PDFs directly.

## Environment

- Host: macOS Darwin 25.1.0, arm64.
- Python: 3.9.6 (system) with `shapely==2.0.7`, `triangle`, `numpy`, `matplotlib==3.9.4`.
- Julia: 1.10 inside `cudd-julia` Docker image (built from `pgcp-experiments/Dockerfile`).
- BDD backend: MiniCUDD.jl (CUDD wrapper) — *not* `dd.cudd` or `dd.autoref`.
