# Experiment 2: Varying PDS Radius

## Generate Data with Different PDS Radii

```sh
mkdir -p data
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config015.json data/data015.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config014.json data/data014.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config013.json data/data013.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config012.json data/data012.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config011.json data/data011.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config010.json data/data010.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config009.json data/data009.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia gendata.jl dataconfig/config008.json data/data008.json
```

## Run BDD Solver on Generated Data

```sh
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data015.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data014.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data013.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data012.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data011.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data010.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data009.json
docker run -it --rm -v $PWD:/work -w /work cudd-julia julia bdd_solver.jl data/data008.json
```
