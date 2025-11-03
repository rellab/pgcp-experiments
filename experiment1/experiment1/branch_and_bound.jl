module BranchAndBoundSolver

using VoronoiCells
using GeometryBasics: Point
using JSON

struct Circle
    name::String
    center::Point
    radius::Float64
end

struct Rectangle4
    vertices::Vector{Point{2, Float64}}

    Rectangle4(vertices::Vector{Point{2, Float64}}) = new(vertices)
end

function Rectangle4(left_lower::Point{2, Float64}, right_upper::Point{2, Float64})
    Rectangle4([left_lower, Point(left_lower[1], right_upper[2]), right_upper, Point(right_upper[1], left_lower[2])])
end

function dist(p1::Point, p2::Point)
    sqrt((p1[1] - p2[1])^2 + (p1[2] - p2[2])^2)
end

function isinside(c::Circle, p::Point)
    (p[1] - c.center[1])^2 + (p[2] - c.center[2])^2 <= c.radius^2
end

function bnbsolver(circles)
    ps = []
    s = zeros(Int, length(circles))
    findpathvectorset(1, s, ps, circles)
    ps
end

function findpathvectorset(m, s, ps, circles)
    @debug "findpathvectorset: m=$m, s=$(s[1:m-1])"
    if m > length(s)
        return
    end
    s[m] = 1
    if check(s[1:m], circles)
        push!(ps, s[1:m])
    else
        findpathvectorset(m+1, s, ps, circles)
    end
    s[m] = 0
    findpathvectorset(m+1, s, ps, circles)
end

function check(s, circles)
    rect = VoronoiCells.Rectangle(Point(0, 0), Point(1, 1))
    index = [i for (i,x) = enumerate(s) if x == 1]
    points = [circles[i].center for i = index]
    tess = voronoicells(points, rect)
    all([all([isinside(circles[index[i]], x) for x = tess.Cells[i]]) for i = 1:length(points)])
end

function createtree(bss, vars, ps, circles)
    if length(ps) == 0
        return bss.zero
    end
    res = []
    for s = ps
        tmp = [vars[circles[i].name] for (i,x) = enumerate(s) if x == 1]
        push!(res, bdd_and(tmp...))
    end
    bdd_or(res...)
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

# ===================== main =====================
function main(argv)
    if length(argv) < 1
        println("Usage: julia branch_and_bound.jl data.json")
        return
    end

    firstarg = argv[1]
    circles, gridsize, maxlevel, reliability = load_config_from_json(firstarg)
    @info "Loaded $(length(circles)) circles"

    t0 = @elapsed begin
        ps = bnbsolver(circles)
    end

    @info "Found $(length(ps)) path vector(s) in $(t0) seconds"
    for p in ps[1:min(10,length(ps))]
        @info "Path vector: $p"
    end
end

end # module BranchAndBoundSolver

if abspath(PROGRAM_FILE) == @__FILE__
    using .BranchAndBoundSolver
    BranchAndBoundSolver.main(ARGS)
end