docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 angles_from_center experiment3/results_bdd_015_angles_from_center_y-wise.csv
# docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 random experiment3/results_bdd_015_random_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 origin experiment3/results_bdd_015_origin_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 center experiment3/results_bdd_015_center_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 xcoordinate experiment3/results_bdd_015_xcoordinate_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data015 1 50 ycoordinate experiment3/results_bdd_015_ycoordinate_y-wise.csv

docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 angles_from_center experiment3/results_bdd_010_angles_from_center_y-wise.csv
# docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 random experiment3/results_bdd_010_random_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 origin experiment3/results_bdd_010_origin_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 center experiment3/results_bdd_010_center_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 xcoordinate experiment3/results_bdd_010_xcoordinate_y-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl data/data010 1 50 ycoordinate experiment3/results_bdd_010_ycoordinate_y-wise.csv
