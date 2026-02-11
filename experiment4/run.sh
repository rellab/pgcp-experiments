docker run --rm -v "$PWD:/work" -w /work cudd-julia julia scripts/run_bdd_batch.jl experiment4/data/data008 1 10 angles_from_center experiment4/results_bdd_008.csv
