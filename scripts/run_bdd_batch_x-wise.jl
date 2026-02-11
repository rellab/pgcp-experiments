using Printf
using CSV
using DataFrames
using Random

include("bdd_solver_x-wise.jl")
using .BDDSolver

const SORTMODES = [
    :origin,
    :center,
    :random,
    :xcoordinate,
    :ycoordinate,
    :angles_from_origin,
    :angles_from_center
]

function run_bdd_case(datafile::AbstractString, sortmode::Symbol; random_seed::Union{Nothing,Int}=nothing)
    circles, gridsize, maxlevel, reliability = BDDSolver.load_config_from_json(datafile)
    
    rng = random_seed === nothing ? Random.GLOBAL_RNG : MersenneTwister(random_seed)
    circles = sort_circles(circles, sortmode; rng=rng)

    vars = Dict{String,Int}()
    pb = Dict{Int,Float64}()
    for (i,c) in enumerate(circles)
        vars[c.name] = i-1
        pb[i-1] = reliability
    end

    M = BDDSolver.Manager(nvars=max(1, length(circles)))
    targetarea = BDDSolver.Rectangle4((BDDSolver.Point(0.0,0.0), BDDSolver.Point(0.0,1.0), BDDSolver.Point(1.0,1.0), BDDSolver.Point(1.0,0.0)))

    tsolve = @elapsed begin
        res = BDDSolver.bddsolver(M, vars, circles, targetarea; gridsize=gridsize, maxlevel=maxlevel)
    end

    t2 = @elapsed begin
        lb = BDDSolver.prob(M, res.varphi2, pb)
    end
    t3 = @elapsed begin
        ub = BDDSolver.prob(M, res.varphi1, pb)
    end

    metrics = (
        datafile=datafile,
        sortmode=sortmode,
        circles=length(circles),
        convergence=res.conv,
        level=res.level,
        nodes_phi1=BDDSolver.dag_size(res.varphi1),
        nodes_phi2=BDDSolver.dag_size(res.varphi2),
        peak_nodes=BDDSolver.peak_node_count(M),
        total_nodes=BDDSolver.node_count(M),
        memory_mb=BDDSolver.memory_in_use(M) / 1024^2,
        solve_time_sec=tsolve,
        prob_time_varphi2_sec=t2,
        prob_time_varphi1_sec=t3,
        reliability_lb=lb,
        reliability_ub=ub
    )

    BDDSolver.quit(M)
    return metrics
end

function sort_circles(circles, sortmode::Symbol; rng::AbstractRNG = Random.GLOBAL_RNG)
    if sortmode == :origin
        return BDDSolver.sort_with_origin(circles)
    elseif sortmode == :center
        return BDDSolver.sort_with_center(circles)
    elseif sortmode == :random
        return BDDSolver.sort_with_random(circles, rng)
    elseif sortmode == :xcoordinate
        return BDDSolver.sort_with_xcoordinate(circles)
    elseif sortmode == :ycoordinate
        return BDDSolver.sort_with_ycoordinate(circles)
    elseif sortmode == :angles_from_origin
        return BDDSolver.sort_with_angles_from_origin(circles)
    elseif sortmode == :angles_from_center
        return BDDSolver.sort_with_angles_from_center(circles)
    else
        error("unknown sort mode: $sortmode")
    end
end

function main(argv)
    prefix = length(argv) >= 1 ? argv[1] : "data/data010"
    start_idx = length(argv) >= 2 ? parse(Int, argv[2]) : 1
    end_idx = length(argv) >= 3 ? parse(Int, argv[3]) : 10
    sortmode = length(argv) >= 4 ? Symbol(argv[4]) : :angles_from_center
    output_csv = length(argv) >= 5 ? argv[5] : "result_bdd_batch.csv"

    results = []
    
    for i in start_idx:end_idx
        datafile = @sprintf "%s-%03d.json" prefix i
        
        if !isfile(datafile)
            @warn "File not found: $datafile"
            continue
        end
        
        @info "Processing $datafile ($i/$end_idx)"
        random_seed = sortmode == :random ? i : nothing
        @info "  Sorting with mode: $sortmode"
        try
            result = run_bdd_case(datafile, sortmode; random_seed=random_seed)
            push!(results, result)
            @info "    Circles: $(result.circles), Nodes: $(result.nodes_phi1)/$(result.nodes_phi2), Time: $(result.solve_time_sec) sec"
        catch e
            @warn "    Error: $e"
        end
    end
    
    # Save to CSV
    if !isempty(results)
        df = DataFrame(results)
        CSV.write(output_csv, df)
        @info "Wrote $(nrow(df)) results to $output_csv"
    else
        @warn "No results to write"
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
