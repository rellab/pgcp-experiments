using JSON
using Statistics
using Printf

function main(argv)
    datadir = length(argv) >= 1 ? argv[1] : "data"
    
    # Dictionary to store circles count for each dataXXX
    data_circles = Dict{String, Vector{Int}}()
    
    # Read all JSON files matching pattern dataXXX-YYY.json
    for file in readdir(datadir)
        if endswith(file, ".json") && contains(file, "-")
            # Parse filename: dataXXX-YYY.json
            parts = split(file, "-")
            if length(parts) >= 2
                prefix = parts[1]  # e.g., "data008"
                
                filepath = joinpath(datadir, file)
                try
                    config = JSON.parsefile(filepath)
                    if haskey(config, "circles")
                        circles_count = length(config["circles"])
                        if !haskey(data_circles, prefix)
                            data_circles[prefix] = Int[]
                        end
                        push!(data_circles[prefix], circles_count)
                    end
                catch e
                    @warn "Failed to read $filepath: $e"
                end
            end
        end
    end
    
    # Sort by prefix
    sorted_prefixes = sort(collect(keys(data_circles)))
    
    # Print results
    println("DataName  | Min | Max | Mean     | Count")
    println("-" ^ 50)
    for prefix in sorted_prefixes
        counts = data_circles[prefix]
        min_val = minimum(counts)
        max_val = maximum(counts)
        mean_val = mean(counts)
        sample_count = length(counts)
        
        @printf "%s | %3d | %3d | %8.2f | %d\n" prefix min_val max_val mean_val sample_count
    end
    
    println("\nTotal prefixes: $(length(sorted_prefixes))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
