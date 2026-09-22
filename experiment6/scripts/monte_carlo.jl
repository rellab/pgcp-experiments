#!/usr/bin/env julia
#
# Crude Monte Carlo baseline for coverage reliability under heterogeneous radii.
#
# Each sample draws the component states independently with probability p_k and
# judges coverage with the arrangement judge (coverage_judges.jl), which is
# independent of the BDD solver. The estimate, its 95% confidence interval, and
# the running time are reported for several sample sizes, next to the BDD value
# recorded in experiment2.
#
# Usage (from pgcp-experiments/):
#   julia experiment6/scripts/monte_carlo.jl <datafile.json> [seed] [N1 N2 ...]

using Printf
using Random
using JSON

include(joinpath(@__DIR__, "coverage_judges.jl"))
using .CoverageJudges

function load_instance(path::AbstractString)
    cfg = JSON.parsefile(path)
    disks = [Disk(Float64(c["x"]), Float64(c["y"]), Float64(c["radius"])) for c in cfg["circles"]]
    return disks, Float64(cfg["reliability"])
end

function sample_state(rng, n::Int, p::Float64)
    x = UInt128(0)
    for k in 1:n
        rand(rng) < p && (x |= UInt128(1) << (k - 1))
    end
    return x
end

function main(argv)
    path = argv[1]
    seed = length(argv) >= 2 ? parse(Int, argv[2]) : 42
    Ns = length(argv) >= 3 ? [parse(Int, a) for a in argv[3:end]] : [10^4, 10^5, 10^6]

    disks, p = load_instance(path)
    n = length(disks)
    tpre = @elapsed J = ArrangementJudge(disks, Rect(0.0, 1.0, 0.0, 1.0))
    @printf("%s: n=%d, p=%.2f, candidates=%d, min margin=%.2e, precompute=%.3fs\n",
        path, n, p, length(J.cands), J.min_margin, tpre)

    # all-active sanity check: the full system must cover the region
    full = (UInt128(1) << n) - UInt128(1)
    @printf("all components active -> covered = %s\n", covered_arrangement(J, full))

    println("        N   failures   R_hat          95% CI half-width   1-R_hat      time(s)")
    for N in Ns
        rng = MersenneTwister(seed)
        fails = 0
        t = @elapsed for _ in 1:N
            covered_arrangement(J, sample_state(rng, n, p)) || (fails += 1)
        end
        q = fails / N
        hw = 1.96 * sqrt(q * (1 - q) / N)
        @printf("%9d  %9d   %.10f   %.3e           %.3e    %.3f\n", N, fails, 1 - q, hw, q, t)
    end
end

main(ARGS)
