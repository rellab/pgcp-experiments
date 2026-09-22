#!/usr/bin/env julia
#
# Numerical-margin check of the point-in-disk predicate on the campus case study.
#
# The solver is NOT modified. This script replaces BDDSolverTriangle.isinside
# with an instrumented version that, for every predicate evaluation, records
#   - the double-precision margin |d^2 - r^2|,
#   - whether the double-precision classification agrees with the exact one
#     computed in Rational{BigInt} arithmetic (Float64 inputs are rationals,
#     so the exact sign of d^2 - r^2 is decidable).
# It then runs the converged campus configuration (maxLevel = 11) and prints a
# summary. Nothing under results/ is written.
#
# Usage (from pgcp-experiments/):
#   julia experiment5/scripts/check_margin.jl [maxlevel] [sort_mode]

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver_triangle.jl"))

using .BDDSolverTriangle
using MiniCUDD
using Printf

const SENS_PATH = joinpath(@__DIR__, "..", "data", "campus_sensors.json")
const MESH_PATH = joinpath(@__DIR__, "..", "results", "campus_initial_triangulation.json")

mutable struct MarginLog
    n_eval::Int
    n_mismatch::Int
    min_abs::Float64          # min |d^2 - r^2| in double precision
    min_rel::Float64          # min |d^2 - r^2| / r^2
    min_exact::BigFloat       # min |d^2 - r^2| computed exactly
    argmin::Any
    small::Vector{Float64}    # all margins below 1e-6, for a histogram
end

const LOG = MarginLog(0, 0, Inf, Inf, BigFloat(Inf), nothing, Float64[])

@eval BDDSolverTriangle function isinside(c::Circle, p::Point)
    dx = getx(p) - getx(c.center)
    dy = gety(p) - gety(c.center)
    lhs = dx^2 + dy^2
    rhs = c.radius^2
    res = lhs <= rhs

    L = Main.LOG
    L.n_eval += 1
    m = abs(lhs - rhs)

    R = Rational{BigInt}
    ex = (R(getx(p)) - R(getx(c.center)))^2 + (R(gety(p)) - R(gety(c.center)))^2 - R(c.radius)^2
    res_exact = ex <= 0
    if res != res_exact
        L.n_mismatch += 1
    end
    mex = BigFloat(abs(ex))
    if mex < L.min_exact
        L.min_exact = mex
        L.argmin = (c.name, c.radius, (getx(p), gety(p)), (getx(c.center), gety(c.center)))
    end
    if m < L.min_abs
        L.min_abs = m
    end
    if m / rhs < L.min_rel
        L.min_rel = m / rhs
    end
    if m < 1e-6
        push!(L.small, m)
    end
    return res
end

function sort_circles(circles, mode::Symbol)
    if mode === :xcoordinate
        return sort(circles; by = c -> c.center[1])
    elseif mode === :ycoordinate
        return sort(circles; by = c -> c.center[2])
    else
        return circles
    end
end

function main(argv)
    maxlevel = length(argv) >= 1 ? parse(Int, argv[1]) : 11
    sort_mode = length(argv) >= 2 ? Symbol(argv[2]) : :xcoordinate

    circles, reliability, _, _ = BDDSolverTriangle.load_sensors_json(SENS_PATH)
    circles = sort_circles(circles, sort_mode)
    init_triangles, _, _ = BDDSolverTriangle.load_triangulation_json(MESH_PATH)

    @info "coordinate type" typeof(circles[1].center) typeof(init_triangles[1].vertices[1])

    vars = Dict{String,Int}()
    for (i, c) in enumerate(circles)
        vars[c.name] = i - 1
    end
    M = Manager(nvars = max(1, length(circles)))
    res = BDDSolverTriangle.triangle_bdd_solver(
        M, vars, circles, init_triangles;
        maxlevel = maxlevel, verbose = false, pb = nothing)

    println("==== margin check (campus, maxLevel=$maxlevel) ====")
    @printf("predicate evaluations      : %d\n", LOG.n_eval)
    @printf("double vs exact mismatches : %d\n", LOG.n_mismatch)
    @printf("min |d^2 - r^2| (double)   : %.6e\n", LOG.min_abs)
    @printf("min |d^2 - r^2| (exact)    : %.6e\n", Float64(LOG.min_exact))
    @printf("min |d^2 - r^2| / r^2      : %.6e\n", LOG.min_rel)
    println("argmin (name, r, point, center): ", LOG.argmin)
    println("margins below 1e-6, by decade:")
    for k in 6:17
        lo, hi = 10.0^(-(k + 1)), 10.0^(-k)
        n = count(m -> lo <= m < hi, LOG.small)
        n > 0 && @printf("  [1e-%02d, 1e-%02d): %d\n", k + 1, k, n)
    end
    nz = count(==(0.0), LOG.small)
    nz > 0 && @printf("  exactly 0: %d\n", nz)
    println("converged = ", res.conv)
end

main(ARGS)
