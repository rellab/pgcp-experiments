#!/usr/bin/env julia
# Importance and minimal-set analysis of the converged campus coverage BDD.
#
# Rebuilds the campus structure function Phi via the triangle solver (run to
# termination, where Phi_1 == Phi_2 == Phi), then runs the BDDAnalysis module:
# Birnbaum / criticality importance of every sensor, and the minimal path and
# cut sets. All analyses are marginal-cost traversals of the one converged BDD.
#
#   julia experiment5/scripts/analyze_campus.jl [maxlevel] [sort_mode]
#
# Defaults: maxlevel = 12, sort_mode = xcoordinate.
#
# Outputs:
#   experiment5/results/campus_importance.csv   — per-sensor importance
#   experiment5/results/campus_minsets.json     — min-path / min-cut summary
#
# Inputs (must exist):
#   experiment5/data/campus_sensors.json
#   experiment5/results/campus_initial_triangulation.json

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver_triangle.jl"))
include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_analysis.jl"))

using .BDDSolverTriangle
using .BDDAnalysis
using MiniCUDD
using JSON
using Printf

const HERE        = @__DIR__
const ROOT        = abspath(joinpath(HERE, ".."))
const SENS_PATH   = joinpath(ROOT, "data",    "campus_sensors.json")
const MESH_PATH   = joinpath(ROOT, "results", "campus_initial_triangulation.json")
const OUT_CSV     = joinpath(ROOT, "results", "campus_importance.csv")
const OUT_JSON    = joinpath(ROOT, "results", "campus_minsets.json")

# Cap on explicit minimal-set enumeration (counts are obtained separately and
# exactly by a memoized traversal, so a cap here only limits the listing).
const ENUM_LIMIT = 1_000_000

function sort_circles(circles, mode::Symbol)
    if     mode === :none;        return circles
    elseif mode === :xcoordinate; return sort(circles, by = c -> c.center[1])
    elseif mode === :ycoordinate; return sort(circles, by = c -> c.center[2])
    else; error("unknown sort mode: $mode")
    end
end

# Summary of one collection of minimal sets (already mapped to names).
function set_summary(named_sets::Vector{Vector{String}}, total_count::Int)
    cards = sort(length.(named_sets))
    # Total-order sort (size, then lexicographic) so the listing is byte-stable.
    smallest = sort(named_sets, by = s -> (length(s), s))
    n_show = min(10, length(smallest))
    return Dict(
        "count"            => total_count,
        "count_enumerated" => length(named_sets),
        "truncated"        => length(named_sets) < total_count,
        "min_cardinality"  => isempty(cards) ? 0 : cards[1],
        "max_cardinality"  => isempty(cards) ? 0 : cards[end],
        "mean_cardinality" => isempty(cards) ? 0.0 : sum(cards) / length(cards),
        "smallest"         => smallest[1:n_show],
    )
end

function main(argv)
    maxlevel  = length(argv) >= 1 ? parse(Int, argv[1]) : 12
    sort_mode = length(argv) >= 2 ? Symbol(argv[2]) : :xcoordinate

    @info "Loading sensors: $SENS_PATH"
    circles, reliability, _, _ = BDDSolverTriangle.load_sensors_json(SENS_PATH)
    circles = sort_circles(circles, sort_mode)

    @info "Loading initial triangulation: $MESH_PATH"
    init_triangles, V, _ = BDDSolverTriangle.load_triangulation_json(MESH_PATH)
    @info "Mesh: $(length(V)) vertices, $(length(init_triangles)) triangles; p_k = $reliability"

    vars = Dict{String,Int}()
    pb   = Dict{Int,Float64}()
    for (i, c) in enumerate(circles)
        vars[c.name] = i - 1
        pb[i - 1]    = reliability
    end

    M = Manager(nvars = max(1, length(circles)))
    res = BDDSolverTriangle.triangle_bdd_solver(
        M, vars, circles, init_triangles;
        maxlevel = maxlevel, verbose = false, pb = pb)
    @assert res.conv "solver did not converge at maxlevel = $maxlevel; cannot analyze Phi"
    phi = res.varphi1
    @info "Converged: Phi has $(Int(dag_size(phi))) BDD nodes"

    # --- importance ---
    imp = BDDAnalysis.importances(M, phi, pb)
    struct_imp = BDDAnalysis.structure_importance(M, phi, vars)
    @info @sprintf("R = %.15f", imp.R)

    # --- minimal path / cut sets ---
    mp_bdd = BDDAnalysis.minsol(M, phi)
    mc_bdd = BDDAnalysis.minsol(M, BDDAnalysis.dual(M, phi))
    n_path = BDDAnalysis.count_solutions(M, mp_bdd)
    n_cut  = BDDAnalysis.count_solutions(M, mc_bdd)
    @info "min-path sets: $n_path,  min-cut sets: $n_cut"

    inv = Dict(v => k for (k, v) in vars)
    tonames(sets) = [sort([inv[i] for i in s]) for s in sets]
    path_named = tonames(BDDAnalysis.enumerate_solutions(M, mp_bdd; limit = ENUM_LIMIT))
    cut_named  = tonames(BDDAnalysis.enumerate_solutions(M, mc_bdd; limit = ENUM_LIMIT))

    # --- write per-sensor importance CSV ---
    open(OUT_CSV, "w") do io
        println(io, "index,name,x,y,radius,birnbaum,criticality1,criticality0,structure")
        for (i, c) in enumerate(circles)
            idx = i - 1
            @printf(io, "%d,%s,%.10f,%.10f,%.10f,%.12f,%.12f,%.12f,%.12f\n",
                idx, c.name, c.center[1], c.center[2], c.radius,
                get(imp.birnbaum, idx, 0.0),
                get(imp.crit1, idx, 0.0),
                get(imp.crit0, idx, 0.0),
                get(struct_imp, c.name, 0.0))
        end
    end
    @info "wrote $OUT_CSV"

    # --- write minimal-set summary JSON ---
    summary = Dict(
        "reliability_p"  => reliability,
        "R"              => imp.R,
        "phi_nodes"      => Int(dag_size(phi)),
        "n_sensors"      => length(circles),
        "min_path_sets"  => set_summary(path_named, n_path),
        "min_cut_sets"   => set_summary(cut_named, n_cut),
    )
    open(OUT_JSON, "w") do io
        JSON.print(io, summary, 2)
    end
    @info "wrote $OUT_JSON"

    # --- console report ---
    ranking = sort(collect(imp.birnbaum); by = x -> -x[2])
    println("\nTop 10 sensors by Birnbaum importance:")
    println("  rank  sensor      radius   Birnbaum    criticality1")
    for (rank, (idx, b)) in enumerate(ranking[1:min(10, end)])
        c = circles[idx + 1]
        @printf("  %4d  %-10s  %.3f    %.6f    %.6f\n",
            rank, c.name, c.radius, b, get(imp.crit1, idx, 0.0))
    end
    @printf("\nmin-path sets: count = %d, smallest size = %d\n",
        n_path, isempty(path_named) ? 0 : minimum(length, path_named))
    @printf("min-cut  sets: count = %d, smallest size = %d\n",
        n_cut, isempty(cut_named) ? 0 : minimum(length, cut_named))

    # cross-check: R from the analysis matches the solver's prob traversal
    r_solver = BDDSolverTriangle.prob(M, phi, pb)
    @assert isapprox(imp.R, r_solver; atol = 1e-12) "R mismatch: $(imp.R) vs $r_solver"
    @info "cross-check OK: analysis R == solver R"

    quit(M)
end

main(ARGS)
