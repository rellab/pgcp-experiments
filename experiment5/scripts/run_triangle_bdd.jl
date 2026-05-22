#!/usr/bin/env julia
# Diagnostic: per-level snapshots inside a SINGLE run of the triangle BDD solver.
#
# NOTE: this is NOT the canonical campus per-level experiment. The manuscript
# table tab:campus-bounds is produced by run_triangle_bdd_perlevel.jl, which
# runs the solver fresh to termination for each maxLevel. This script is kept
# only as a within-run diagnostic and writes to *_snapshot.* so that it does
# not clobber the canonical campus_bounds.csv / campus_summary.json.
#
#   julia experiment5/scripts/run_triangle_bdd.jl [maxlevel] [sort_mode]
#
# Defaults: maxlevel = 8, sort_mode = xcoordinate.
#
# Outputs:
#   experiment5/results/campus_bounds_snapshot.csv    — per-level snapshots
#   experiment5/results/campus_summary_snapshot.json  — final summary
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
const OUT_CSV     = joinpath(ROOT, "results", "campus_bounds_snapshot.csv")
const OUT_SUMJSON = joinpath(ROOT, "results", "campus_summary_snapshot.json")

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

function write_csv(path::String, snaps::Vector{BDDSolverTriangle.LevelSnapshot})
    open(path, "w") do io
        println(io, "level,n_reached,n_resolved,n_refined,area_resolved,",
                    "nodes_phi1,nodes_phi2,peak_nodes,time_sec,R_lower,R_upper")
        for s in snaps
            @printf(io, "%d,%d,%d,%d,%.10f,%d,%d,%d,%.6f,%.12f,%.12f\n",
                s.level, s.n_reached, s.n_resolved, s.n_refined,
                s.area_resolved, s.nodes_phi1, s.nodes_phi2,
                s.peak_nodes, s.time_sec, s.R_lower, s.R_upper)
        end
    end
end

function main(argv)
    maxlevel = length(argv) >= 1 ? parse(Int, argv[1]) : 8
    sort_mode = length(argv) >= 2 ? Symbol(argv[2]) : :xcoordinate

    @info "Loading sensors: $SENS_PATH"
    circles, reliability, _, sens_cfg = BDDSolverTriangle.load_sensors_json(SENS_PATH)
    n_sensors_json = length(circles)
    circles = sort_circles(circles, sort_mode)

    @info "Loading initial triangulation: $MESH_PATH"
    init_triangles, V, mesh_meta = BDDSolverTriangle.load_triangulation_json(MESH_PATH)
    @info "Mesh: $(length(V)) vertices, $(length(init_triangles)) triangles"
    @info "Reliability p_k = $reliability"
    @info "maxlevel = $maxlevel,  sort_mode = $sort_mode,  n_sensors = $n_sensors_json"

    vars = Dict{String,Int}()
    pb   = Dict{Int,Float64}()
    for (i,c) in enumerate(circles)
        vars[c.name] = i - 1
        pb[i - 1]    = reliability
    end

    M = Manager(nvars = max(1, length(circles)))
    t_all = @elapsed begin
        res = BDDSolverTriangle.triangle_bdd_solver(
            M, vars, circles, init_triangles;
            maxlevel = maxlevel, verbose = true, pb = pb)
    end

    lb = BDDSolverTriangle.prob(M, res.varphi2, pb)
    ub = BDDSolverTriangle.prob(M, res.varphi1, pb)

    @info "Convergence: $(res.conv)"
    @info "Max level seen: $(res.level)"
    @info "Resolved by level: $(res.resolvedByLevel)"
    @info "R_lower = $(lb)"
    @info "R_upper = $(ub)"
    @info "Wall time: $(t_all) sec"
    @info "Peak BDD nodes: $(peak_node_count(M))"

    mkpath(dirname(OUT_CSV))
    write_csv(OUT_CSV, res.snapshots)
    @info "wrote $OUT_CSV ($(length(res.snapshots)) rows)"

    summary = Dict(
        "maxlevel"          => maxlevel,
        "sort_mode"         => String(sort_mode),
        "n_sensors"         => length(circles),
        "n_initial_tris"    => length(init_triangles),
        "reliability_p"     => reliability,
        "convergence"       => res.conv,
        "level_max_seen"    => res.level,
        "resolvedByLevel"   => res.resolvedByLevel,
        "R_lower"           => lb,
        "R_upper"           => ub,
        "wall_time_sec"     => t_all,
        "peak_nodes"        => Int(peak_node_count(M)),
        "nodes_phi1_final"  => Int(dag_size(res.varphi1)),
        "nodes_phi2_final"  => Int(dag_size(res.varphi2)),
        "sensors_sha256"    => get(get(sens_cfg, "_meta", Dict()), "circles_sha256", ""),
        "mesh_sha256"       => get(get(mesh_meta, "_meta", Dict()), "mesh_sha256", ""),
    )
    open(OUT_SUMJSON, "w") do io
        JSON.print(io, summary, 2)
    end
    @info "wrote $OUT_SUMJSON"

    quit(M)
end

main(ARGS)
