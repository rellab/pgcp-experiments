# CLAUDE.md — Experiment 5: Triangle-Partition Case Study on a Real Campus Polygon

This file briefs Claude Code (claude.ai/code) for implementing Experiment 5 of the
`pgcp-experiments` repository. The goal of Experiment 5 is to demonstrate that the
symbolic reliability evaluation framework of the parent paper works on a
non-rectangular target region using a **triangular** partition, with results
reported on a real-world map (the Higashi-Hiroshima campus of Hiroshima
University).

The parent paper is the IEEE Transactions on Reliability submission located at
`../../manuscript/main.tex` (relative to this file). Experiment 5 will populate
a new Section VI-H "Case Study on a Real Campus Polygon".

---

## 1. Why this experiment exists

Reviewers of the earlier IJOC submission consistently inferred that the framework
was restricted to rectangular partitions, even though the manuscript states
clearly that the sufficient condition relies only on convexity. The present
case study removes that doubt by running the framework on:

1. A target region that is a **realistic non-rectangular polygon** (the campus
   outline from OpenStreetMap).
2. A partition that is a **triangulation** of the polygon, refined by edge-
   midpoint subdivision.

The deliverables are (a) a figure showing the campus, the sensor disks, and the
final triangulation; (b) certified lower and upper bounds on the coverage
reliability, together with the exact value when convergence is detected; and
(c) a comparison with a rectangular bounding-box partition on the same disk
configuration to show that triangulation reduces wasted refinement.

---

## 2. Inputs already available

```
experiment5/
├── export.geojson                   # raw OSM polygon, lat/lon (223 verts)
├── processed/
│   └── campus_normalized.json       # polygon in [0,1]^2 (side = 2251.7 m)
└── figs/
    ├── campus_outline.pdf
    └── campus_outline.png
```

`campus_normalized.json` already contains:

- `polygon`: list of (x, y) in normalized `[0, 1]` coordinates
- `side_meters`: 2251.7 (so unit 1 in normalized space = 2251.7 m)
- `bbox_normalized`: `[0, 0, 1.0000, 0.9447]`
- Polygon area in normalized coords: 0.5048 (= 2.56 km² in real units)

Use this as the polygon input. Do not re-project the lat/lon.

---

## 3. Sensor configuration (fixed)

These parameters were agreed with the authors. **Do not change them without
asking.**

| Parameter             | Value                       | Notes                       |
|-----------------------|-----------------------------|-----------------------------|
| Number of sensors     | 25–30 (target via PDS)      | Poisson disk sampling       |
| Sensor radii          | `{0.089, 0.178}` (normalized) | `= {200 m, 400 m}`        |
| Radius assignment     | i.i.d. uniform from the set | per sensor                  |
| Component reliability | `p_k = 0.9` for all k       | matches existing experiments|
| PDS minimum distance  | `200 m / 2251.7 = 0.0888`   | normalized                  |
| Sampling domain       | inside the campus polygon   | reject samples outside      |
| RNG seed              | 42                          | reproducibility             |

Storage format: a JSON file `experiment5/data/campus_sensors.json` with
fields `circles: [{name, x, y, radius}]` and a top-level `polygon: [[x,y],...]`
copied from `campus_normalized.json`. Match the existing format used elsewhere
in `pgcp-experiments` (`data/data010-001.json` etc.) as closely as possible.

---

## 4. Phase A: Python prototype (do this first)

### Goal

Produce a working symbolic reliability evaluator with a triangular partition,
running on the campus polygon, in pure Python. The prototype must:

- Read the polygon and the sensor configuration.
- Build a constrained Delaunay triangulation of the polygon.
- Iterate adaptive symbolic refinement using triangles.
- Maintain global ROBDDs `Φ1` (necessary) and `Φ2` (sufficient) over the
  processed triangles.
- Emit certified lower and upper bounds at every refinement level.
- Save per-level statistics (subregions resolved, reached, area resolved) and
  the final triangulation.

### Recommended Python stack

- `shapely >= 2.0` for polygon ops (`shapely.geometry.Polygon`, `triangulate`,
  `Point.within`, etc.).
- `triangle` (Jonathan Shewchuk's via `triangle` PyPI package) for constrained
  Delaunay triangulation of the polygon. Use option flag `q30a0.05` to obtain
  reasonably uniform triangles of area at most 0.05 in normalized coordinates.
- `dd` (PyPI) for BDDs (use `dd.cudd` if available, otherwise the pure-Python
  backend). `from dd.autoref import BDD` is the safe default.
- `matplotlib` for visualization.
- `numpy`, `scipy` as standard utilities.

### Algorithm details (triangle-aware)

Let the partition be a set of triangles. For each triangle `T` with vertices
`V(T) = {v_1, v_2, v_3}`:

```
phi_1(T) := AND over u in V(T) of OR over k in D(u) of x_k
phi_2(T) := OR over k in D_tilde(T) of x_k
  where
    D(u)      = { k : ||u - c_k|| <= r_k }
    D_tilde(T)= D(v_1) ∩ D(v_2) ∩ D(v_3)
```

The aggregate ROBDDs are `Φ1 = AND over processed T of phi_1(T)` and likewise
for `Φ2`. The certified bounds are `R_lower = Pr(Φ2 = 1)` and
`R_upper = Pr(Φ1 = 1)`.

### Triangle refinement rule

When a triangle's `phi_1` and `phi_2` disagree and neither the local nor the
global equivalence test passes, subdivide it by **edge-midpoint subdivision**:
the parent triangle `T` is replaced by four child triangles formed by joining
the midpoints of the three edges. This keeps the triangulation conforming
within `T` but introduces hanging nodes on adjacent triangles. For the BDD
algorithm hanging nodes are not a problem because each triangle's `phi_1` is
evaluated on its own three corners independently; however, the union of the
four children equals the parent, so the soundness arguments of Propositions
1 and 2 carry over directly.

### Adaptive refinement loop

The loop is exactly the same as Algorithm 1 of the parent paper, with two
differences:

- `BuildVertexBDD(A)` uses 3 corner vertices instead of 4.
- `SplitRegion(A)` returns the four midpoint sub-triangles instead of the four
  rectangular quadrants.

Track per-level statistics: number of triangles resolved (locally or by
global merge), number of triangles reached, cumulative area resolved.

### Convergence detection

The procedure converges when `Φ1 ≡ Φ2` after all triangles in the queue have
been processed. Use the ROBDD root-identity check from the `dd` library.

### Output (Phase A)

Write three files to `experiment5/results/`:

- `campus_bounds.csv` — one row per refinement level with columns
  `level, n_triangles, n_resolved, n_reached, area_resolved, R_lower, R_upper,
  nodes_phi1, nodes_phi2, peak_nodes, time_sec`.
- `campus_final_triangulation.json` — final triangulation vertices and
  triangles, plus a flag per triangle indicating whether it was resolved
  locally, by global merge, or hit the depth limit.
- `campus_figure.pdf` — multi-panel figure: (left) campus polygon + sensors,
  (middle) initial coarse triangulation, (right) final refined triangulation
  overlaid on the polygon.

### Validation in Phase A

Before declaring Phase A done, run two sanity checks:

1. **Bounding-box comparison.** Run the existing rectangular framework on the
   bounding box `[0,1] × [0, 0.9447]` with the same sensors, treating the
   region outside the campus polygon as "covered by a dummy disk" so that
   the rectangular framework only needs to refine inside the campus. The
   converged value should match the triangle framework's converged value to
   double-precision accuracy.

2. **Brute force on a small sub-instance.** Take a sub-instance with 10–12
   sensors (subset of the full configuration), enumerate the `2^n` states,
   and check coverage of the polygon for each state by a fine grid test
   (resolution 0.005 in normalized units). Compare with the symbolic
   framework's converged value.

Both checks must agree to at least six decimal places.

### Maximum refinement depth

Start with `maxLevel = 8`. If convergence is not reached, increase in steps
of 1 up to 12. Record the depth at which convergence occurs.

### Wall-time budget

Phase A should run in under 10 minutes on a single CPU for 25–30 sensors. If
it does not, profile and check that the `dd` backend is `cudd` (much faster
than `autoref`). If `dd.cudd` is unavailable, install it or fall back to
`autoref`, but note the timing in the CSV.

---

## 5. Phase B: Julia port (after Phase A succeeds)

### Goal

Port the working Python prototype to Julia + MiniCUDD, using the same module
boundaries as `pgcp-experiments/scripts/bdd_solver.jl`. The Julia port goes
into a new file:

```
pgcp-experiments/scripts/bdd_solver_triangle.jl
```

It exports a runner with the same CSV output format as
`bdd_solver.jl`, plus per-level statistics. A wrapper script
`scripts/run_triangle_batch.jl` should be patterned after
`run_bdd_batch.jl`.

### Inputs to the Julia code

- `data/campus_sensors.json` (sensor configuration, same JSON format as Phase A).
- Optionally, the triangulation produced by Phase A
  (`results/campus_initial_triangulation.json`) so that both implementations
  start from the same initial mesh.

### Julia dependencies

- `JSON` for I/O.
- `MiniCUDD.jl` for BDDs (already a dependency of the existing solver).
- `DelaunayTriangulation.jl` for constrained Delaunay triangulation.
- `Polyhedra.jl` or simple custom code for point-in-polygon tests.
- `Plots.jl` for figures (optional; can reuse Phase A figures).

### Algorithm

Mirror Phase A exactly. The only differences are language-level.

### Validation in Phase B

The converged reliability and the bounds vs depth table must match Phase A to
at least six decimal places, on the same sensor configuration.

### Output (Phase B)

- `experiment5/results/campus_bounds_julia.csv` — same schema as Phase A.
- A short Markdown note `experiment5/results/notes.md` summarizing wall-clock
  and peak-node-count differences between Python `dd` and Julia/CUDD.

### Performance budget

Phase B should be significantly faster than Phase A. A target is under 1
minute for the full case on 25–30 sensors.

---

## 6. Manuscript integration

When both phases are done, add a new subsection to the manuscript:

```
\subsection{Case Study on a Real Campus Polygon}
\label{sec:campus}
```

Place it after the current Section VI-G ("Behavior at Lower Redundancy") and
before Section VII ("Discussion"). The subsection should:

1. **State the scenario in one short paragraph.** Use phrases like "the
   Higashi-Hiroshima campus of Hiroshima University, with bounding box
   2252 m and area 2.56 km², monitored by 25–30 heterogeneous outdoor
   wireless sensors".
2. **Describe the partition.** A constrained Delaunay triangulation of the
   campus polygon, refined by edge-midpoint subdivision. Note explicitly
   that the sufficient condition holds because triangles are convex
   (Proposition 2 / Remark 1).
3. **Report numbers.** A small table mirroring Table VII (subregions resolved
   by level) and a one-row entry in a comparison table that contrasts the
   triangle-only run with the bounding-box rectangle run on the same disks
   (use Phase A's validation result for the rectangle row).
4. **Show the figure.** Cite `campus_figure.pdf` as Fig.\ N (auto-numbered
   by IEEEtran). Three panels as described above.
5. **One short concluding paragraph** observing that the framework handled
   the non-rectangular region without modification of the symbolic engine,
   only the partition data structure was changed. This is the punchline
   that defuses the "rectangle-only" misunderstanding.

Word budget: about half a page (250–350 words). The figure occupies roughly
half a page on its own.

### Where to put the figure file

`manuscript/figs/campus_figure.pdf`. Copy from
`pgcp-experiments/experiment5/results/campus_figure.pdf`.

---

## 7. File layout after Phase A

```
pgcp-experiments/experiment5/
├── CLAUDE.md                                  # this file
├── README.md                                  # short README mirroring this file
├── export.geojson                             # raw OSM polygon (already there)
├── processed/
│   └── campus_normalized.json                 # processed polygon (already there)
├── data/
│   └── campus_sensors.json                    # sensor config
├── scripts/
│   ├── gen_sensors.py                         # PDS within polygon
│   ├── triangulate.py                         # constrained Delaunay
│   ├── triangle_bdd_solver.py                 # core algorithm
│   ├── validate_against_bbox.py               # sanity check 1
│   └── validate_brute_force.py                # sanity check 2
├── results/
│   ├── campus_bounds.csv
│   ├── campus_initial_triangulation.json
│   ├── campus_final_triangulation.json
│   └── campus_figure.pdf
└── figs/
    ├── campus_outline.pdf                     # already there
    └── campus_outline.png                     # already there
```

---

## 8. Style and conventions

- The case study lives in `pgcp-experiments/experiment5/`. Do not modify other
  experiment directories.
- Match the JSON schema of `data/data010-001.json` as closely as possible so
  that the existing `scripts/bdd_solver.jl` can be invoked on the sensor
  configuration without modification (for the bounding-box validation step).
- Use `seed = 42` everywhere unless explicitly overridden.
- The implementation is research code; emphasize correctness and readability
  over micro-optimization.
- Match the manuscript's terminology: "subregion" (not "cell"), "vertex"
  (not "corner"), "necessary/sufficient condition" (not "outer/inner
  bound"), "certified bounds" (not "valid range").
- Write the algorithm in the order: read input → build initial mesh →
  refine → emit results. No deep callback nesting.
- For the figure, do not use color (the journal print version is grayscale).
  Use line styles, hatch patterns, and grayscale fills.

---

## 9. Open questions for the human

If any of the following come up during implementation, stop and ask the
authors (Hiroyuki Okamura):

- What to do if `dd.cudd` is not installable in the environment.
- Whether to allow non-conforming triangulation (hanging nodes) or to
  re-triangulate after each level. The default is to allow hanging nodes;
  switch only with explicit approval.
- Whether to skip the bounding-box validation if it requires non-trivial
  modifications to the existing `bdd_solver.jl`. A reasonable alternative
  is to validate only by brute force on a small sub-instance.
- Whether to deviate from the sensor configuration in Section 3 above. The
  default answer is no.

---

## 10. Done criteria

Phase A is done when:

- `campus_bounds.csv` exists and shows monotone tightening of the bounds
  with depth.
- Both validation checks (bounding-box and brute force) agree to six decimals.
- `campus_figure.pdf` is generated and visually correct.
- The wall-clock summary is under 10 minutes.

Phase B is done when:

- `campus_bounds_julia.csv` matches `campus_bounds.csv` to six decimals.
- The Julia run finishes in under 1 minute.
- `notes.md` records the comparison.

Manuscript integration is done when:

- `manuscript/main.tex` contains Section VI-H "Case Study on a Real Campus
  Polygon".
- The figure file is in `manuscript/figs/`.
- `latexmk main.tex` builds without warnings.
- The total manuscript length stays at most 12 pages.
