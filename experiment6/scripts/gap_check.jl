#!/usr/bin/env julia
#
# Direct evaluation of the certified gap Pr(Phi1 and not Phi2) for instances
# whose double-precision bounds coincide although Phi1 and Phi2 are not
# equivalent (the four non-converged instances of experiment2).
#
# Since Phi2 <= Phi1 pointwise, Phi1 and not Phi2 equals Phi1 xor Phi2, which
# is built with one BDD operation. Its probability is evaluated by the usual
# traversal; because it is a probability of a small event rather than a
# difference of two numbers near one, it does not suffer from cancellation.
#
# Usage (from pgcp-experiments/):
#   julia experiment6/scripts/gap_check.jl <out.csv> <datafile.json> [more files...]

using Printf
include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver.jl"))
using .BDDSolver
using MiniCUDD

function main(argv)
    out = argv[1]
    open(out, "w") do io
        println(io, "datafile,n,converged,R_lower,R_upper,ub_minus_lb,gap_direct,gap_minterms,nodes_gap")
        for f in argv[2:end]
            circles, gridsize, maxlevel, p = BDDSolver.load_config_from_json(f)
            circles = BDDSolver.sort_with_angles_from_center(circles)
            n = length(circles)
            vars = Dict{String,Int}(c.name => k - 1 for (k, c) in enumerate(circles))
            pb = Dict{Int,Float64}(k - 1 => p for k in 1:n)
            M = BDDSolver.Manager(nvars = max(1, n))
            area = BDDSolver.Rectangle4((BDDSolver.Point(0.0, 0.0), BDDSolver.Point(0.0, 1.0),
                                         BDDSolver.Point(1.0, 1.0), BDDSolver.Point(1.0, 0.0)))
            res = BDDSolver.bddsolver(M, vars, circles, area; gridsize = gridsize, maxlevel = maxlevel)
            lb = BDDSolver.prob(M, res.varphi2, pb)
            ub = BDDSolver.prob(M, res.varphi1, pb)
            g = MiniCUDD.bdd_xor(M, res.varphi1, res.varphi2)
            gap = BDDSolver.prob(M, g, pb)
            mt = MiniCUDD.minterms(M, g, n)
            @printf(io, "%s,%d,%s,%.17g,%.17g,%.3e,%.6e,%.6e,%d\n", f, n, res.conv, lb, ub, ub - lb, gap, mt, MiniCUDD.dag_size(g))
            @info @sprintf("%s: conv=%s ub-lb=%.3e gap=%.6e minterms=%.6e", f, res.conv, ub - lb, gap, mt)
        end
    end
end

main(ARGS)
