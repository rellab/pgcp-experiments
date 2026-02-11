docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 angles_from_center experiment3/results_bdd_015_angles_from_center_x-wise.csv
# docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 random experiment3/results_bdd_015_random_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 origin experiment3/results_bdd_015_origin_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 center experiment3/results_bdd_015_center_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 xcoordinate experiment3/results_bdd_015_xcoordinate_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data015 1 50 ycoordinate experiment3/results_bdd_015_ycoordinate_x-wise.csv

docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 angles_from_center experiment3/results_bdd_010_angles_from_center_x-wise.csv
# docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 random experiment3/results_bdd_010_random_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 origin experiment3/results_bdd_010_origin_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 center experiment3/results_bdd_010_center_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 xcoordinate experiment3/results_bdd_010_xcoordinate_x-wise.csv
docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch_x-wise.jl data/data010 1 50 ycoordinate experiment3/results_bdd_010_ycoordinate_x-wise.csv
