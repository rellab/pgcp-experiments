#!/usr/bin/env julia
#
# A degenerate configuration on which the adaptive refinement never converges,
# while the certified bounds remain valid.
#
# Three disks of radius rho pass through a common point P = (1/3, 1/3), with
# inward normals 120 degrees apart. Their union contains the ball of radius rho
# around P, hence the unit square, but every neighbourhood of P needs all three
# disks: no single disk covers a subregion that contains P. Since P is not a
# dyadic point, it is never a partition vertex, so the local sufficient
# condition fails at every depth.
#
#   case 1: the three disks only          -> phi = x1 x2 x3,        R = p^3
#   case 2: plus one disk covering Omega  -> phi = x4 + x1 x2 x3,   R = p + (1-p) p^3
#
# Usage (from pgcp-experiments/, inside the cudd-julia image):
#   julia experiment6/scripts/nonconvergent_example.jl [maxlevel_hi]

using Printf

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver.jl"))
using .BDDSolver

function run_case(name, disks, p, Rtrue, maxlevel_hi)
    circles = [BDDSolver.Circle(string(k), BDDSolver.Point(d[1], d[2]), d[3]) for (k, d) in enumerate(disks)]
    vars = Dict{String,Int}()
    pb = Dict{Int,Float64}()
    for (i, c) in enumerate(circles)
        vars[c.name] = i - 1
        pb[i - 1] = p
    end
    area = BDDSolver.Rectangle4((BDDSolver.Point(0.0, 0.0), BDDSolver.Point(0.0, 1.0),
                                 BDDSolver.Point(1.0, 1.0), BDDSolver.Point(1.0, 0.0)))
    @printf("== %s: n=%d, true R = %.10f\n", name, length(disks), Rtrue)
    println("maxLevel   R_lower        R_upper        gap            conv   contains R   time(s)")
    for ml in 1:maxlevel_hi
        M = BDDSolver.Manager(nvars = length(circles))
        t = @elapsed res = BDDSolver.bddsolver(M, vars, circles, area; gridsize = 4, maxlevel = ml)
        lb = BDDSolver.prob(M, res.varphi2, pb)
        ub = BDDSolver.prob(M, res.varphi1, pb)
        ok = (lb <= Rtrue + 1e-15) && (Rtrue <= ub + 1e-15)
        @printf("%8d   %.10f   %.10f   %.10f   %-5s  %-5s        %.3f\n", ml, lb, ub, ub - lb, string(res.conv), string(ok), t)
    end
end

function main(argv)
    maxlevel_hi = length(argv) >= 1 ? parse(Int, argv[1]) : 10
    p = 0.9
    rho = 2.0
    P = (1 / 3, 1 / 3)
    three = [(P[1] + rho * cosd(a), P[2] + rho * sind(a), rho) for a in (90.0, 210.0, 330.0)]
    run_case("case 1 (three disks through P)", three, p, p^3, maxlevel_hi)
    run_case("case 2 (plus a disk covering Omega)", vcat(three, [(0.5, 0.5, 1.0)]), p, p + (1 - p) * p^3, maxlevel_hi)
end

main(ARGS)
