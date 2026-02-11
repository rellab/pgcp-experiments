# Variable ordering BDD solver performance evaluation

- Variable ordering impact on BDD solver performance for small and middle instances
- PDS: 0.15, 0.10
- Radius: [0.2, 0.4]
- Measure: computation time, nodes, peak nodes, memory usage

## Run BDD solver

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 angles_from_center experiment3/results_bdd_015_angles_from_center.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 random experiment3/results_bdd_015_random.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 origin experiment3/results_bdd_015_origin.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 center experiment3/results_bdd_015_center.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 xcoordinate experiment3/results_bdd_015_xcoordinate.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 ycoordinate experiment3/results_bdd_015_ycoordinate.csv
```

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 angles_from_center experiment3/results_bdd_010_angles_from_center.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 random experiment3/results_bdd_010_random.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 origin experiment3/results_bdd_010_origin.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 center experiment3/results_bdd_010_center.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 xcoordinate experiment3/results_bdd_010_xcoordinate.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 ycoordinate experiment3/results_bdd_010_ycoordinate.csv
```
