
# pgcp-experiments

An experiments repository for a BDD-based symbolic reliability solver (computing certified lower/upper bounds for probabilistic geometric coverage), implemented with Julia + MiniCUDD. Includes comparisons against a Branch and Bound baseline on synthetic instances and a real-map case study on a non-rectangular campus polygon.

- Input data: a set of circles (center, radius) represented as JSON
- Data generation: circle centers are generated via Poisson Disk Sampling (PDS)
- BDD solver (rectangle partition): targets the unit square ([0,1]×[0,1]) with adaptive 4×4 grid refinement, computing certified lower/upper bounds from the probabilities of formulas (varphi1/varphi2)
- BDD solver (triangle partition): targets an arbitrary polygon with a constrained Delaunay triangulation as the initial partition and 1:4 edge-midpoint refinement (added for experiment5)
- BDD analysis: once a structure-function BDD has converged, [scripts/bdd_analysis.jl](scripts/bdd_analysis.jl) extracts minimal path/cut sets (via `minsol`) and Birnbaum/criticality/structure importance at marginal cost (a MiniCUDD port of the FaultTree.jl analysis layer; used by experiment5)
- Experiments: see [experiment1/README.md](experiment1/README.md), [experiment2/README.md](experiment2/README.md), [experiment3/README.md](experiment3/README.md), [experiment4/run.sh](experiment4/run.sh), [experiment5/REPRODUCIBILITY.md](experiment5/REPRODUCIBILITY.md), [experiment6/README.md](experiment6/README.md) (additional validation for the IEEE TR revision)

## Prerequisites

- Docker (recommended)
- Or Julia 1.10+ (if you prefer running locally)

## Setup (Docker)

Build the image first (it runs MiniCUDD build/tests, so it can take a while).

```sh
docker build -t cudd-julia .
```

## Generate data

The generator script is [scripts/gendata.jl](scripts/gendata.jl).

```sh
docker run -it --rm -v "$PWD:/work" -w /work cudd-julia \
  julia scripts/gendata.jl dataconfig/config010.json data/data010.json
```

### Config files

JSON configs live under [dataconfig/](dataconfig/) (e.g. [dataconfig/config010.json](dataconfig/config010.json)).

- `area`: sampling area
  - `type`: `rectangle` | `circle` | `polygon`
- `pds_radius`: minimum distance for PDS
- `radius_domain`: candidate radii (array). One value is picked by `rand(rng, radius_domain)`
- `seed`: RNG seed
- `samples`: number of generated samples

### Output files

- If `samples` is 1: a single output JSON (the specified filename)
- If `samples` is 2 or more: multiple files with a `-NNN` suffix, e.g. `data/data010-001.json`

The output JSON includes `gridsize`, `maxlevel`, `reliability`, and `circles` (`name`, `x`, `y`, `radius`).

## Run solvers

### BDD solver (batch)

[scripts/run_bdd_batch.jl](scripts/run_bdd_batch.jl) runs the BDD solver on a numbered dataset like `prefix-001.json` and writes results to a CSV.

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia scripts/run_bdd_batch.jl \
  data/data010 1 50 angles_from_center \
  experiment2/results_bdd_010.csv
```

Arguments:

- `prefix`: e.g. `data/data010` (actual files are `data/data010-001.json`, ...)
- `start_idx`, `end_idx`: range to run
- `sortmode`: variable ordering (e.g. `angles_from_center`, `xcoordinate`, `random`, ...)
- `output_csv`: output CSV path

When `sortmode` is `random`, the sample index is used as the RNG seed for reproducibility.

### BDD solver (x-wise variant)

Experiment 3 also uses the x-wise variant runner.

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia scripts/run_bdd_batch_x-wise.jl \
  data/data010 1 50 angles_from_center \
  experiment3/results_bdd_010_angles_from_center_x-wise.csv
```

### Branch and Bound solver (batch)

[scripts/run_bnb_batch.jl](scripts/run_bnb_batch.jl) runs the Branch and Bound solver in batch and writes results to a CSV.

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia scripts/run_bnb_batch.jl \
  data/data040 1 50 \
  experiment1/results_bnb_040.csv
```

## Experiments

- Experiment 1 (BDD vs BnB runtime comparison): [experiment1/README.md](experiment1/README.md)
- Experiment 2 (scalability): [experiment2/README.md](experiment2/README.md)
- Experiment 3 (variable ordering evaluation): [experiment3/README.md](experiment3/README.md)
- Experiment 4 (small sample run): [experiment4/run.sh](experiment4/run.sh)
- Experiment 5 (triangle case study on the Higashi-Hiroshima campus polygon): [experiment5/REPRODUCIBILITY.md](experiment5/REPRODUCIBILITY.md)
- Experiment 6 (additional validation for the IEEE TR revision: exhaustive enumeration, Monte Carlo, non-convergent example, ordering, predicate margins): [experiment6/README.md](experiment6/README.md)

## Repository layout

- [scripts/](scripts/): data generation, solver runners, analysis, visualization (Julia). Key files: `bdd_solver.jl` (rectangle-partition BDD solver), `bdd_solver_triangle.jl` (triangle-partition variant used by experiment5), `bdd_analysis.jl` (minimal path/cut sets and Birnbaum importance on a converged BDD), `branch_and_bound.jl` (BnB baseline), `gendata.jl` (PDS generator)
- [dataconfig/](dataconfig/): JSON configs for data generation
- [data/](data/): generated datasets (e.g. `data010-001.json`)
- [experiment1/](experiment1/), [experiment2/](experiment2/), [experiment3/](experiment3/), [experiment4/](experiment4/): experiment instructions and outputs (CSV/figures)
- [experiment5/](experiment5/): triangle case study on a real campus polygon (sensor config, CDT, certified bounds, `p_k` sweep, importance / minimal-set analysis, reproducibility manifest)



