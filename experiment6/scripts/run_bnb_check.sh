#!/bin/sh
D='docker run --rm -v '"$PWD"':/work -w /work cudd-julia'
for d in 040 030 020; do
  $D julia experiment6/scripts/bnb_reliability_check.jl experiment6/results/bnb_reliability_$d.csv experiment1/results_bdd_$d.csv data/data$d 1 50 > experiment6/results/bnb_check_$d.log 2>&1
done
echo ALLDONE
