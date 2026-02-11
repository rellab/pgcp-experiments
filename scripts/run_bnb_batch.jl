using Printf
using CSV
using DataFrames

include("branch_and_bound.jl")
using .BranchAndBoundSolver

function run_bnb(datafile::AbstractString)
    circles, gridsize, maxlevel, reliability = BranchAndBoundSolver.load_config_from_json(datafile)
    
    # Measure solve time
    tsolve = @elapsed begin
        ps = BranchAndBoundSolver.bnbsolver(circles)
    end
    
    return (
        datafile=datafile,
        circles=length(circles),
        path_vectors=length(ps),
        solve_time_sec=tsolve
    )
end

function main(argv)
    prefix = length(argv) >= 1 ? argv[1] : "data/data040"
    start_idx = length(argv) >= 2 ? parse(Int, argv[2]) : 1
    end_idx = length(argv) >= 3 ? parse(Int, argv[3]) : 50
    output_csv = length(argv) >= 4 ? argv[4] : "result_bnb_batch.csv"

    results = []
    
    for i in start_idx:end_idx
        datafile = @sprintf "%s-%03d.json" prefix i
        
        if !isfile(datafile)
            @warn "File not found: $datafile"
            continue
        end
        
        @info "Processing $datafile ($i/$end_idx)"
        try
            result = run_bnb(datafile)
            push!(results, result)
            @info "  Circles: $(result.circles), Path vectors: $(result.path_vectors), Time: $(result.solve_time_sec) sec"
        catch e
            @warn "Error processing $datafile: $e"
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
