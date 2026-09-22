#!/usr/bin/env julia
#
# Numerical-margin check of the point-in-disk predicate for the unit-square
# solver (scripts/bdd_solver.jl), over a range of experiment2 instances.
#
# The solver is not modified. `isinside` is replaced by an instrumented version
# that records the double-precision margin |d^2 - r^2| of every evaluation and,
# for evaluations whose margin is below a threshold, re-decides the predicate in
# Rational{BigInt} arithmetic and counts disagreements. Rectangle vertices are
# dyadic, so the only rounding is in the distance computation itself.
#
# Usage (from pgcp-experiments/):
#   julia experiment6/scripts/check_margin_rect.jl <prefix> <from> <to> <out.csv> [threshold]
#   e.g. julia experiment6/scripts/check_margin_rect.jl data/data015 1 50 experiment6/results/margin_015.csv

using Printf
using Random

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver.jl"))
using .BDDSolver

mutable struct MarginLog
    n_eval::Int
    n_checked::Int
    n_mismatch::Int
    min_abs::Float64
    min_rel::Float64
end
const LOG = MarginLog(0, 0, 0, Inf, Inf)
const THRESH = Ref(1e-9)

@eval BDDSolver function isinside(c::Circle, p::Point)
    dx = getx(p) - getx(c.center)
    dy = gety(p) - gety(c.center)
    lhs = dx^2 + dy^2
    rhs = c.radius^2
    res = lhs <= rhs
    L = Main.LOG
    L.n_eval += 1
    m = abs(lhs - rhs)
    m < L.min_abs && (L.min_abs = m)
    m / rhs < L.min_rel && (L.min_rel = m / rhs)
    if m < Main.THRESH[]
        R = Rational{BigInt}
        ex = (R(getx(p)) - R(getx(c.center)))^2 + (R(gety(p)) - R(gety(c.center)))^2 - R(c.radius)^2
        L.n_checked += 1
        (ex <= 0) != res && (L.n_mismatch += 1)
    end
    return res
end

function reset!()
    LOG.n_eval = 0; LOG.n_checked = 0; LOG.n_mismatch = 0; LOG.min_abs = Inf; LOG.min_rel = Inf
end

function main(argv)
    prefix = argv[1]; from = parse(Int, argv[2]); to = parse(Int, argv[3]); out = argv[4]
    length(argv) >= 5 && (THRESH[] = parse(Float64, argv[5]))
    open(out, "w") do io
        println(io, "datafile,n,evaluations,checked_exact,mismatches,min_abs_margin,min_rel_margin,converged")
        for i in from:to
            f = @sprintf("%s-%03d.json", prefix, i)
            isfile(f) || continue
            circles, gridsize, maxlevel, _ = BDDSolver.load_config_from_json(f)
            circles = BDDSolver.sort_with_angles_from_center(circles)  # as in experiment2
            vars = Dict{String,Int}(c.name => k - 1 for (k, c) in enumerate(circles))
            M = BDDSolver.Manager(nvars = max(1, length(circles)))
            area = BDDSolver.Rectangle4((BDDSolver.Point(0.0, 0.0), BDDSolver.Point(0.0, 1.0),
                                         BDDSolver.Point(1.0, 1.0), BDDSolver.Point(1.0, 0.0)))
            reset!()
            res = BDDSolver.bddsolver(M, vars, circles, area; gridsize = gridsize, maxlevel = maxlevel)
            @printf(io, "%s,%d,%d,%d,%d,%.6e,%.6e,%s\n", f, length(circles), LOG.n_eval, LOG.n_checked,
                LOG.n_mismatch, LOG.min_abs, LOG.min_rel, res.conv)
            flush(io)
            @info @sprintf("%s: eval=%d checked=%d mismatch=%d min|d2-r2|=%.3e", f, LOG.n_eval, LOG.n_checked, LOG.n_mismatch, LOG.min_abs)
        end
    end
end

main(ARGS)
