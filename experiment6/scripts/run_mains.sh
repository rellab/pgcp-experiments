#!/bin/sh
# Timing-bearing runs for the revision, executed sequentially on an otherwise
# idle machine on mains power. Usage (from pgcp-experiments/): sh experiment6/scripts/run_mains.sh
R=experiment6/results
D='docker run --rm -v '"$PWD"':/work -w /work cudd-julia'
mkdir -p $R/timing $R/ycoord_scalability $R/margin

# 1. MC (N = 1e7) and BDD on the same four instances, back to back
for d in 015 012 010 008; do
  $D julia experiment6/scripts/monte_carlo.jl data/data$d-001.json 42 10000000 > $R/timing/mc_$d.log 2>&1
  $D julia scripts/run_bdd_batch.jl data/data$d 1 1 angles_from_center $R/timing/bdd_$d.csv > $R/timing/bdd_$d.log 2>&1
done

# 2. Section V-C datasets with the recommended y-coordinate ordering (small scale)
for d in 015 014 013 012 011 010; do
  $D julia scripts/run_bdd_batch.jl data/data$d 1 50 ycoordinate $R/ycoord_scalability/results_bdd_${d}_ycoordinate.csv > $R/ycoord_scalability/run_$d.log 2>&1
done

# 3. Predicate margins for the unit-square solver (fast datasets fully, slow ones partially)
for d in 015 014 013 012 011 010; do
  $D julia experiment6/scripts/check_margin_rect.jl data/data$d 1 50 $R/margin/margin_$d.csv > $R/margin/run_$d.log 2>&1
done
$D julia experiment6/scripts/check_margin_rect.jl data/data009 1 10 $R/margin/margin_009.csv > $R/margin/run_009.log 2>&1
$D julia experiment6/scripts/check_margin_rect.jl data/data008 1 3 $R/margin/margin_008.csv > $R/margin/run_008.log 2>&1
echo ALLDONE
