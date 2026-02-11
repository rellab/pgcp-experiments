module PlotCircles

using Plots
using JSON

struct Point
    x::Float64
    y::Float64
end

struct Circle
    name
    center::Point
    radius::Float64
end

function load_config_from_json(path::String)
    s = read(path, String)
    cfg = JSON.parse(s)
    gridsize = haskey(cfg, "gridsize") ? Int(cfg["gridsize"]) : 4
    maxlevel = haskey(cfg, "maxlevel") ? Int(cfg["maxlevel"]) : 10
    reliability = haskey(cfg, "reliability") ? Float64(cfg["reliability"]) : 0.9

    circles = Circle[]
    for c in cfg["circles"]
        name = string(get(c, "name", get(c, "id", "")))
        x = Float64(get(c, "x", get(c, "cx", 0.0)))
        y = Float64(get(c, "y", get(c, "cy", 0.0)))
        r = Float64(get(c, "radius", get(c, "r", 0.0)))
        push!(circles, Circle(name, Point(x,y), r))
    end
    return circles, gridsize, maxlevel, reliability
end

function circleShape(x, y, r)
    theta = LinRange(0, 2*pi, 500)
    x .+ r*sin.(theta), y .+ r*cos.(theta)
end

function drawgraph(xs)
    f = plot(size=(500,500), legend=:outertopleft, xlims=[0,1], ylims=[0,1], aspect_ratio=1)    
    for p in xs
        plot!(circleShape(p.center.x, p.center.y, p.radius),
              seriestype=[:shape], lw=0.5, linecolor=:black, label=p.name, fillalpha=0.1)
    end
    f
end

function main(argv)
    # get filename from command line arguments
    if length(argv) != 2
        @info "Usage: julia plot_circles.jl [input.json] [output]"
        return
    end

    filename = argv[1]
    output = argv[2]
    @info "Using input file: $filename"

    circles, _ = load_config_from_json(filename)
    @info "Loaded $(length(circles)) circles"

    f = drawgraph(circles)
    savefig(f, output)
    @info "Saved plot to $output"
end

end # module PlotCircles

if abspath(PROGRAM_FILE) == @__FILE__
    using .PlotCircles
    PlotCircles.main(ARGS)
end
