#!/bin/sh
# Random variable ordering on data010, one container per instance, so that a
# timeout or an out-of-memory kill loses only that instance.
# Usage (from pgcp-experiments/): sh experiment6/scripts/run_random_010.sh [limit_sec]
LIMIT=${1:-1800}
OUT=experiment6/results/random010
mkdir -p "$OUT"
for i in $(seq 1 50); do
    id=$(printf "%03d" "$i")
    [ -f "$OUT/$id.csv" ] && continue
    start=$(date +%s)
    docker run --rm -v "$PWD:/work" -w /work cudd-julia \
        timeout "$LIMIT" julia scripts/run_bdd_batch.jl data/data010 "$i" "$i" random "$OUT/$id.csv" \
        > "$OUT/$id.log" 2>&1
    rc=$?
    end=$(date +%s)
    echo "$id,$rc,$((end - start))" >> "$OUT/status.csv"
done
