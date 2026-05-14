#!/usr/bin/env julia
# Sweep the component reliability p_k after a single BDD solve.
#
#   julia experiment5/scripts/sweep_pk.jl [maxlevel] [sort_mode]
#
# Outputs experiment5/results/campus_sweep_pk.csv.

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver_triangle.jl"))

using .BDDSolverTriangle
using MiniCUDD
using Printf

const HERE  = @__DIR__
const ROOT  = abspath(joinpath(HERE, ".."))
const SENS  = joinpath(ROOT, "data",    "campus_sensors.json")
const MESH  = joinpath(ROOT, "results", "campus_initial_triangulation.json")
const OUT   = joinpath(ROOT, "results", "campus_sweep_pk.csv")

function main(argv)
    maxlevel = length(argv) >= 1 ? parse(Int, argv[1]) : 12
    sort_mode = length(argv) >= 2 ? Symbol(argv[2]) : :xcoordinate

    circles, _, _, _ = BDDSolverTriangle.load_sensors_json(SENS)
    if sort_mode === :xcoordinate
        circles = sort(circles, by = c -> c.center[1])
    end
    init_triangles, _, _ = BDDSolverTriangle.load_triangulation_json(MESH)

    vars = Dict{String,Int}()
    for (i,c) in enumerate(circles)
        vars[c.name] = i - 1
    end

    M = Manager(nvars = max(1, length(circles)))
    res = BDDSolverTriangle.triangle_bdd_solver(
        M, vars, circles, init_triangles;
        maxlevel = maxlevel, verbose = false, pb = nothing)

    @info "Convergence: $(res.conv)   max level: $(res.level)"

    pks = [0.50, 0.70, 0.80, 0.85, 0.90, 0.92, 0.95, 0.97, 0.99, 0.995, 0.999]
    open(OUT, "w") do io
        println(io, "p_k,R_lower,R_upper")
        for p in pks
            pb = Dict{Int,Float64}(i => p for i in 0:length(circles)-1)
            lb = BDDSolverTriangle.prob(M, res.varphi2, pb)
            ub = BDDSolverTriangle.prob(M, res.varphi1, pb)
            @printf("p_k = %.3f   R = [%.6f, %.6f]   gap = %.2e\n",
                    p, lb, ub, ub - lb)
            @printf(io, "%.4f,%.10f,%.10f\n", p, lb, ub)
        end
    end
    @info "wrote $OUT"

    # Effective critical-sensor count: log R / log p_k at p_k = 0.9.
    pb = Dict{Int,Float64}(i => 0.9 for i in 0:length(circles)-1)
    R = BDDSolverTriangle.prob(M, res.varphi2, pb)
    k_eff = log(R) / log(0.9)
    @info "At p_k = 0.9, R = $(R); effective # critical sensors ≈ $(k_eff)"

    quit(M)
end

main(ARGS)
