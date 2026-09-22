#!/usr/bin/env julia
#
# Exhaustive cross-check on small heterogeneous-radius instances.
#
# For each generated instance (n ~ 10-14 disks, radii from {0.2, 0.4}), all 2^n
# states are enumerated and judged by two independent coverage judges
# (arrangement-based and power-diagram-based, see coverage_judges.jl). The
# resulting exact reliability is compared with the certified bounds of the
# BDD solver on the same instance.
#
# Usage (from pgcp-experiments/, inside the cudd-julia image):
#   julia experiment6/scripts/enumerate_check.jl [n_instances] [pds_distance] [seed]

using Printf
using Random

include(joinpath(@__DIR__, "coverage_judges.jl"))
include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver.jl"))
using .CoverageJudges
using .BDDSolver

# Rejection-based dart throwing in the unit square, then independent radii.
function gen_instance(rng, dmin::Float64; max_fail::Int = 20_000)
    pts = NTuple{2,Float64}[]
    fails = 0
    while fails < max_fail
        p = (rand(rng), rand(rng))
        if all(hypot(p[1] - q[1], p[2] - q[2]) >= dmin for q in pts)
            push!(pts, p)
            fails = 0
        else
            fails += 1
        end
    end
    return [Disk(p[1], p[2], rand(rng, (0.2, 0.4))) for p in pts]
end

function bdd_bounds(disks::Vector{Disk}, p::Float64; gridsize::Int = 4, maxlevel::Int = 10)
    circles = [BDDSolver.Circle(string(k), BDDSolver.Point(d.x, d.y), d.r) for (k, d) in enumerate(disks)]
    vars = Dict{String,Int}()
    pb = Dict{Int,Float64}()
    for (i, c) in enumerate(circles)
        vars[c.name] = i - 1
        pb[i - 1] = p
    end
    M = BDDSolver.Manager(nvars = max(1, length(circles)))
    area = BDDSolver.Rectangle4((BDDSolver.Point(0.0, 0.0), BDDSolver.Point(0.0, 1.0),
                                 BDDSolver.Point(1.0, 1.0), BDDSolver.Point(1.0, 0.0)))
    t = @elapsed res = BDDSolver.bddsolver(M, vars, circles, area; gridsize = gridsize, maxlevel = maxlevel)
    lb = BDDSolver.prob(M, res.varphi2, pb)
    ub = BDDSolver.prob(M, res.varphi1, pb)
    return (lb = lb, ub = ub, conv = res.conv, time = t)
end

function main(argv)
    ninst = length(argv) >= 1 ? parse(Int, argv[1]) : 10
    dmin  = length(argv) >= 2 ? parse(Float64, argv[2]) : 0.28
    seed  = length(argv) >= 3 ? parse(Int, argv[3]) : 42
    p = 0.9
    rng = MersenneTwister(seed)
    R = Rect(0.0, 1.0, 0.0, 1.0)

    println("inst   n  states  covered   A!=B   R_enum(A)            R_lower(BDD)         R_upper(BDD)         |diff|     conv  marginA   marginB   tA(s)  tB(s)  tBDD(s)")
    for inst in 1:ninst
        disks = gen_instance(rng, dmin)
        n = length(disks)
        J = ArrangementJudge(disks, R)

        nstates = 1 << n
        disagree = 0
        ncov = 0
        RA = 0.0
        RB = 0.0
        minmB = Inf
        tA = 0.0
        tB = 0.0
        for s in 0:nstates-1
            active = [k for k in 1:n if (s >> (k - 1)) & 1 == 1]
            x = state_bits(active)
            tA += @elapsed ca = covered_arrangement(J, x)
            tB += @elapsed ((cb, mB) = covered_power(disks, R, active))
            mB < minmB && (minmB = mB)
            ca != cb && (disagree += 1)
            pr = p^length(active) * (1 - p)^(n - length(active))
            ca && (RA += pr; ncov += 1)
            cb && (RB += pr)
        end

        b = bdd_bounds(disks, p)
        diff = max(abs(RA - b.lb), abs(RA - b.ub))
        @printf("%4d  %2d  %7d  %7d  %5d   %.16f   %.16f   %.16f   %.2e   %-5s %.2e  %.2e  %.3f  %.3f  %.3f\n",
            inst, n, nstates, ncov, disagree, RA, b.lb, b.ub, diff, string(b.conv), J.min_margin, minmB, tA, tB, b.time)
        if disagree > 0
            @printf("      R_enum(B) = %.16f\n", RB)
        end
    end
end

main(ARGS)
