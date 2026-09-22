# Experiment 6: additional validation for the IEEE TR major revision

## Background

The manuscript *Symbolic Reliability Evaluation of Probabilistic Geometric
Coverage Using Binary Decision Diagrams* (IEEE Transactions on Reliability,
manuscript TR-2026-775) received a major-revision decision on 2026-09-20.
The reviewers asked for evidence on four points that the original experiments
(experiment1 to experiment5) did not cover.
This directory holds the scripts and results produced for the revision.
Nothing in experiment1 to experiment5 was modified; the solver in
`scripts/bdd_solver.jl` is used as is.

| Reviewer request | Script | Output |
|---|---|---|
| Independent ground truth for heterogeneous radii (R1-3, R2-1) | `scripts/enumerate_check.jl` | printed table |
| Monte Carlo baseline for heterogeneous radii (R3-2, R2-4) | `scripts/monte_carlo.jl` | printed table |
| Whether finite convergence can be guaranteed (R2-2, R3-1) | `scripts/nonconvergent_example.jl` | printed table |
| Sensitivity to the variable ordering (R3-3, R2-4) | `scripts/run_random_010.sh` and `scripts/run_bdd_batch.jl ... random` | `results/` |
| Numerical robustness of the point-in-disk predicate (R1-1) | `../experiment5/scripts/check_margin.jl` | printed summary |

All runs use the `cudd-julia` Docker image (see the top-level README) and
fixed seeds.

## Coverage judges (`scripts/coverage_judges.jl`)

Two coverage tests for a union of disks over an axis-aligned rectangle.
Neither uses the partition-based conditions of the BDD solver, so they serve
as independent ground truth for a given component state.

- **Judge A (arrangement).** The region is covered iff every arrangement
  vertex (rectangle corner, circle-edge intersection, circle-circle
  intersection inside the region) lies in an active disk other than the ones
  that define it. Candidate points are state independent, so they are
  precomputed once with a bitset of the disks that strictly contain them; a
  state is then judged by bit operations (about 50 ns per state).
- **Judge B (power diagram).** The region is covered iff, for every active
  disk, all vertices of its power cell clipped to the region lie in that disk.
  The cell is rebuilt per state by half-plane clipping (about 200 times slower
  than A; used to validate A).

Both are double-precision implementations (square roots for intersection points, floating-point half-plane clipping), not exact arithmetic; they assume general position (in particular, a point exactly on a disk boundary is treated as not strictly inside by judge A) and record the smallest margin they observed. They are an independent numerical validation, not an exact-arithmetic certificate.

## Exhaustive cross-check (`scripts/enumerate_check.jl`)

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia experiment6/scripts/enumerate_check.jl 8 0.21 42
```

Generates 8 instances on the unit square by dart-throwing Poisson disk
sampling with minimum distance 0.21 (n = 19 to 23), radii from {0.2, 0.4},
p_k = 0.9, seed 42. All 2^n states are judged by A and B; the enumerated
reliability is compared with the BDD bounds.

Result (2026-09-21): A and B agree on all 23,592,960 states (2^23 + 2^22 + 5*2^21 + 2^19); the enumerated R
equals the BDD value to at most 1.4e-13 on every instance; all BDD runs
converge. A first attempt with minimum distance 0.28 (n = 11 to 14) gave
R = 0 on 8 of 10 instances (the disks were too sparse to cover the square)
and was discarded as uninformative.

## Monte Carlo baseline (`scripts/monte_carlo.jl`)

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia experiment6/scripts/monte_carlo.jl data/data015-001.json 42 10000000
```

Crude Monte Carlo with judge A. Reports the estimate, a Wald 95% half-width, the number of failures and the running time for each sample size. For the paper, exact (Clopper-Pearson) intervals were computed from the failure counts with `scripts/clopper_pearson.py`, because the Wald interval is unreliable with few failures.

Result (2026-09-21, N = 1e7, seed 42, `-001` of data015/012/010/008): the BDD
value lies inside the 95% interval on all four instances. On data008-001
(1 - R = 1.1e-6) the 1e7 samples contain 8 failures (relative half-width 69%)
and 1e5 samples contain none. With N = 1e6 and seed 42, data015-001 missed the
BDD value by 2.4 sigma; four independent seeds at N = 1e7 all contain it.

## Non-convergent example (`scripts/nonconvergent_example.jl`)

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia experiment6/scripts/nonconvergent_example.jl 10
```

Three disks of radius 2 whose boundaries pass through P = (1/3, 1/3) with
normals 120 degrees apart, optionally plus one disk covering the unit square.
P is not dyadic, so it is never a partition vertex, and no single disk covers
any subregion containing P: the sufficient condition fails at every depth.

Result: with the fourth disk (phi = x4 or x1 x2 x3, R = 0.9729 at p = 0.9)
the bounds are [0.9, 0.9729] for every maxLevel 1 to 10; the gap 0.0729 equals
(1 - p) p^3, the probability of the states that rely on the degenerate
contact. The interval always contains R.

## Random variable ordering (`scripts/run_random_010.sh`)

```sh
docker run --rm -v "$PWD:/work" -w /work cudd-julia \
  julia scripts/run_bdd_batch.jl data/data015 1 50 random experiment6/results/results_bdd_015_random_y-wise.csv
sh experiment6/scripts/run_random_010.sh 120
```

The second command runs data010 one instance per container with a 2-minute
wall-clock limit (about 20 s of which is Julia start-up); `status.csv` records
the exit code (124 = timeout) and the elapsed seconds, and the script is
resumable.

Result (2026-09-21): on data015 (50 instances) the random ordering gives final
BDDs 6.7 times larger and peak sizes 3.0 times larger than the y-coordinate
ordering. On data010, 42 of 50 instances timed out; the 8 that finished
averaged 1.48e6 final nodes and 69.0 s against 2.76e4 nodes and 1.35 s for the
y-coordinate ordering on the same 8 instances (which are the easier ones).
`results/random010_limit600/` holds instance 1 under an earlier 10-minute
limit (234 s), and `results/random010_aborted.log` the log of an aborted
30-minute run.

## Predicate margin on the campus (`../experiment5/scripts/check_margin.jl`)

Re-evaluates every point-in-disk predicate of the campus run in exact rational
arithmetic and records the smallest double-precision margin |d^2 - r^2|.

Result: 704,052 evaluations at maxLevel = 11, 0 mismatches between double
precision and exact arithmetic, smallest margin 2.13e-7.

## Timing-bearing runs (`scripts/run_mains.sh`, 2026-09-22)

Executed sequentially on an otherwise idle machine on mains power.

- `results/timing/`: Monte Carlo (N = 1e7, seed 42) and the BDD run back to
  back on data015/012/010/008-001. MC: 4.6, 10.1, 17.5, 41.2 s; BDD: 0.65,
  1.08, 2.09, 54.3 s.
- `results/ycoord_scalability/`: data015 to data010, 50 instances each, with
  the y-coordinate ordering (the published experiment2 runs used
  `angles_from_center`). Median times differ from experiment2 by at most 15%
  in either direction, peak nodes by at most 12%, the same 299 of 300
  instances converge, and R agrees to 1e-15.
- `results/margin/` (`scripts/check_margin_rect.jl`): predicate margins for the
  unit-square solver on 313 instances (data015 to data010 fully, data009
  first 10, data008 first 3), 5.9e8 evaluations; smallest |d^2 - r^2| =
  1.3e-10; the 23 evaluations below 1e-9 were re-decided in exact arithmetic
  with 0 mismatches.

## Reruns prompted by the Codex cross-check (`scripts/run_codex_reruns.sh`, 2026-09-22)

- `experiment4/data/data008-010.json` had `reliability = 0.9` while the other
  nine depth-limit inputs had 0.5, so the stored depth-10 row could not be
  reproduced from the inputs. The file was corrected to 0.5 and the whole
  depth scan was rerun (`experiment4/results_bdd_008.csv`; the previous CSV is
  kept as `results/experiment4_results_before_rerun.csv`). Bounds for depths
  1 to 9 are unchanged; depth 10 now gives R = 0.973157 and converges.
- `scripts/gap_check.jl` evaluates the certified gap Pr(Phi1 and not Phi2)
  directly as Pr(Phi1 xor Phi2) for the four non-converged experiment2
  instances, whose stored bounds coincide in double precision
  (`results/gap_nonconverged.csv`): 7.3e-26 (data010-045), 7.2e-18
  (data009-032), 7.2e-23 (data008-009), 7.3e-32 (data008-044). The
  manuscript's earlier "of order 1e-12" statement was not supported by the
  stored results and has been replaced by these values.
- `scripts/clopper_pearson.py` computes the exact binomial intervals used in
  the paper for the Monte Carlo failure counts.
