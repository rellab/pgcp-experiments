#!/bin/sh
# Reruns prompted by the Codex cross-check (2026-09-22):
#  (1) experiment4 depth scan, all ten depth limits, after fixing p=0.5 in data008-010.json
#  (2) direct gap Pr(Phi1 xor Phi2) for the four non-converged experiment2 instances
D='docker run --rm -v '"$PWD"':/work -w /work cudd-julia'
$D julia scripts/run_bdd_batch.jl experiment4/data/data008 1 10 angles_from_center experiment4/results_bdd_008.csv > experiment6/results/experiment4_rerun.log 2>&1
$D julia experiment6/scripts/gap_check.jl experiment6/results/gap_nonconverged.csv \
   data/data010-045.json data/data009-032.json data/data008-009.json data/data008-044.json > experiment6/results/gap_check.log 2>&1
echo ALLDONE
