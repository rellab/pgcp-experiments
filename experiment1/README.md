# Experiment 1

- Compare bnb and bdd solvers for computation time
- PDS: 0.4, 0.3, 0.2
- Data sets: data040, data030, data020
- Each data set has 50 samples
- Radius domain: fixed to 0.5 for all experiments

## generate experiment data

```sh
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia scripts/gendata.jl dataconfig/config040.json data/data040.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia scripts/gendata.jl dataconfig/config030.json data/data030.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia scripts/gendata.jl dataconfig/config020.json data/data020.json
```

## run BDD solver batch

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data040 1 50 angles_from_center experiment1/results_bdd_040.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data030 1 50 angles_from_center experiment1/results_bdd_030.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data020 1 50 angles_from_center experiment1/results_bdd_020.csv
```

## run Branch and Bound solver batch

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bnb_batch.jl data/data040 1 50 experiment1/results_bnb_040.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bnb_batch.jl data/data030 1 50 experiment1/results_bnb_030.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bnb_batch.jl data/data020 1 50 experiment1/results_bnb_020.csv
```

