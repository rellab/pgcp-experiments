#!/usr/bin/env julia
# Campus per-level experiment under the separate-run-per-maxLevel protocol.
#
# Manuscript Section IV-D declares that outputs from intermediate iterations,
# before the queue empties, are not in the scope of the framework: maxLevel is
# the user-facing knob and only termination outputs are valid. Accordingly,
# each row of campus_bounds.csv is the TERMINAL state of an INDEPENDENT run of
# Algorithm 2 at a fixed maxLevel; the solver is invoked fresh for every row.
# (The older run_triangle_bdd.jl reported per-level snapshots inside one
# maxLevel = 12 run and is kept only as a diagnostic.)
#
#   julia experiment5/scripts/run_triangle_bdd_perlevel.jl [maxlevel_hi] [sort_mode]
#
# Defaults: maxlevel_hi = 11, sort_mode = xcoordinate.
#
# Outputs:
#   experiment5/results/campus_bounds.csv    — one row per run, maxLevel = 1..maxlevel_hi
#   experiment5/results/campus_summary.json  — summary of the converged run
#
# Inputs (must exist):
#   experiment5/data/campus_sensors.json
#   experiment5/results/campus_initial_triangulation.json

include(joinpath(@__DIR__, "..", "..", "scripts", "bdd_solver_triangle.jl"))

using .BDDSolverTriangle
using MiniCUDD
using JSON
using Printf

const HERE        = @__DIR__
const ROOT        = abspath(joinpath(HERE, ".."))
const SENS_PATH   = joinpath(ROOT, "data",    "campus_sensors.json")
const MESH_PATH   = joinpath(ROOT, "results", "campus_initial_triangulation.json")
const OUT_CSV     = joinpath(ROOT, "results", "campus_bounds.csv")
const OUT_SUMJSON = joinpath(ROOT, "results", "campus_summary.json")

function sort_circles(circles, mode::Symbol)
    if     mode === :none
        return circles
    elseif mode === :xcoordinate
        return sort(circles, by = c -> c.center[1])
    elseif mode === :ycoordinate
        return sort(circles, by = c -> c.center[2])
    elseif mode === :angles_from_center
        return sort(circles, by = c -> atan(c.center[2] - 0.5, c.center[1] - 0.5))
    elseif mode === :origin
        return sort(circles, by = c -> hypot(c.center[1], c.center[2]))
    else
        error("unknown sort mode: $mode")
    end
end

# One independent run of Algorithm 2 at a fixed depth limit, taken to
# termination. Returns the terminal-state row. The solver is called with
# `pb = nothing` so that its per-level `take_snapshot!` instrumentation skips
# the transient AND-chains; `peak_node_count` then reflects the algorithm
# only, with no snapshot overhead. The terminal certified bounds are computed
# here from the final BDDs.
function run_one(circles, init_triangles, vars, pb, maxlevel::Int)
    M = Manager(nvars = max(1, length(circles)))
    t = @elapsed begin
        res = BDDSolverTriangle.triangle_bdd_solver(
            M, vars, circles, init_triangles;
            maxlevel = maxlevel, verbose = false, pb = nothing)
    end
    lb = BDDSolverTriangle.prob(M, res.varphi2, pb)
    ub = BDDSolverTriangle.prob(M, res.varphi1, pb)
    row = (
        maxlevel        = maxlevel,
        reached         = res.reached_total,
        resolved        = res.resolved_equiv_total,
        refined         = res.refined_total,
        forced          = res.forced_total,
        nodes_phi1      = Int(dag_size(res.varphi1)),
        nodes_phi2      = Int(dag_size(res.varphi2)),
        peak_nodes      = Int(peak_node_count(M)),
        time_sec        = t,
        R_lower         = lb,
        R_upper         = ub,
        converged       = res.conv,
        level_seen      = res.level,
        resolvedByLevel = res.resolvedByLevel,
    )
    quit(M)
    return row
end

function write_csv(path::String, rows)
    open(path, "w") do io
        println(io, "level,n_reached,n_resolved,n_refined,n_forced,",
                    "nodes_phi1,nodes_phi2,peak_nodes,time_sec,R_lower,R_upper")
        for r in rows
            @printf(io, "%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.12f,%.12f\n",
                r.maxlevel, r.reached, r.resolved, r.refined, r.forced,
                r.nodes_phi1, r.nodes_phi2, r.peak_nodes, r.time_sec,
                r.R_lower, r.R_upper)
        end
    end
end

function main(argv)
    maxlevel_hi = length(argv) >= 1 ? parse(Int, argv[1]) : 11
    sort_mode   = length(argv) >= 2 ? Symbol(argv[2]) : :xcoordinate

    @info "Loading sensors: $SENS_PATH"
    circles, reliability, _, sens_cfg = BDDSolverTriangle.load_sensors_json(SENS_PATH)
    circles = sort_circles(circles, sort_mode)

    @info "Loading initial triangulation: $MESH_PATH"
    init_triangles, V, mesh_meta = BDDSolverTriangle.load_triangulation_json(MESH_PATH)
    @info "Mesh: $(length(V)) vertices, $(length(init_triangles)) triangles"
    @info "Reliability p_k = $reliability"
    @info "Protocol: separate run per maxLevel in 1..$maxlevel_hi, sort_mode = $sort_mode"

    vars = Dict{String,Int}()
    pb   = Dict{Int,Float64}()
    for (i,c) in enumerate(circles)
        vars[c.name] = i - 1
        pb[i - 1]    = reliability
    end

    rows = NamedTuple[]
    for ml in 1:maxlevel_hi
        r = run_one(circles, init_triangles, vars, pb, ml)
        @assert r.reached == r.resolved + r.refined + r.forced "row identity violated at maxLevel=$ml"
        push!(rows, r)
        @info @sprintf("maxLevel=%2d: reached=%4d resolved=%4d refined=%4d forced=%4d  R=[%.9f, %.9f]  conv=%s  peak=%d  %.3fs",
            ml, r.reached, r.resolved, r.refined, r.forced,
            r.R_lower, r.R_upper, r.converged, r.peak_nodes, r.time_sec)
    end

    mkpath(dirname(OUT_CSV))
    write_csv(OUT_CSV, rows)
    @info "wrote $OUT_CSV ($(length(rows)) rows)"

    # Summary of the converged run: the deepest run that terminated with
    # Phi1 == Phi2 and committed nothing at the depth limit.
    conv_idx = findlast(r -> r.converged && r.forced == 0, rows)
    cr = conv_idx === nothing ? rows[end] : rows[conv_idx]
    summary = Dict(
        "protocol"          => "separate-run-per-maxLevel",
        "maxlevel"          => cr.maxlevel,
        "maxlevel_range"    => [1, maxlevel_hi],
        "sort_mode"         => String(sort_mode),
        "n_sensors"         => length(circles),
        "n_initial_tris"    => length(init_triangles),
        "reliability_p"     => reliability,
        "convergence"       => cr.converged,
        "level_max_seen"    => cr.level_seen,
        "resolvedByLevel"   => cr.resolvedByLevel,
        "R_lower"           => cr.R_lower,
        "R_upper"           => cr.R_upper,
        "wall_time_sec"     => cr.time_sec,
        "peak_nodes"        => cr.peak_nodes,
        "nodes_phi1_final"  => cr.nodes_phi1,
        "nodes_phi2_final"  => cr.nodes_phi2,
        "sensors_sha256"    => get(get(sens_cfg, "_meta", Dict()), "circles_sha256", ""),
        "mesh_sha256"       => get(get(mesh_meta, "_meta", Dict()), "mesh_sha256", ""),
    )
    open(OUT_SUMJSON, "w") do io
        JSON.print(io, summary, 2)
    end
    @info "wrote $OUT_SUMJSON (converged at maxLevel=$(cr.maxlevel), R=$(cr.R_lower))"
end

main(ARGS)
