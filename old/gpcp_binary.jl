module GPCPBinary

export bddsolver, prob, size, drawgraph, createtree, pds
export Circle, Rectangle4, dist, isinside, createarea

using VoronoiCells
using GeometryBasics
using Random
using Plots
using DD.BDD
using LinearAlgebra
using DataStructures
using Dates

import VoronoiCells: Rectangle

function bddand(bss, vs...)
    if isempty(vs)
        return bss.one
    end
    BDD.and(vs...)
end

function bddor(bss, vs...)
    if isempty(vs)
        return bss.zero
    end
    BDD.or(vs...)
end

# struct Point
#     x::Float64
#     y::Float64
# end

function randcoordinate(rng::AbstractRNG)
    Point(rand(rng), rand(rng))
end

struct Circle
    name
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

function createarea(rectangle, circles, gridsize)
    xgrid = LinRange(rectangle.vertices[1][1], rectangle.vertices[3][1], gridsize+1)
    ygrid = LinRange(rectangle.vertices[1][2], rectangle.vertices[3][2], gridsize+1)
    grid = [Point(x, y) for x = xgrid for y = ygrid];
    nodes = Dict([p=>[c.name for c = circles if isinside(c, p)] for p = grid]...)
    areas = [Rectangle4([
        Point(xgrid[i], ygrid[j]),
        Point(xgrid[i+1], ygrid[j]),
        Point(xgrid[i+1], ygrid[j+1]),
        Point(xgrid[i], ygrid[j+1])]) for i = 1:gridsize for j = 1:gridsize];
    return areas, nodes
end

function bddsolver(bss, vars, circles, root; gridsize=4, maxlevel=10, clear_cache=10_000_000)
    varphi1 = bss.one
    varphi2 = bss.one
    queue = Deque{Tuple{Rectangle4,Int}}()
    push!(queue, (root,1))
    total = 1
    processed = 0
    totalarea = Dict()
    start_time = now()
    local level
    while !isempty(queue)
        if clear_cache >= 0 && length(bss.cache) > clear_cache
            empty!(bss.cache)
        end
        rectangle, level = popfirst!(queue)
        processed += 1
        areas, cs = createarea(rectangle, circles, gridsize)
        for rectangle = areas
            vars1 = [[vars[x] for x = cs[p]] for p = rectangle.vertices]
            vars2 = [vars[x] for x = intersect([cs[p] for p = rectangle.vertices]...)]
            varphi1new = bddand(bss, [bddor(bss, v...) for v = vars1]...)
            varphi2new = bddor(bss, vars2...)
            varphi1dash = bddand(bss, varphi1, varphi1new)
            varphi2dash = bddand(bss, varphi2, varphi2new)
            if id(varphi1new) == id(varphi2new) || id(varphi1dash) == id(varphi2dash) || level == maxlevel
                varphi1 = varphi1dash
                varphi2 = varphi2dash
                totalarea[level] = get(totalarea, level, 0) + 1
            else
                push!(queue, (rectangle, level+1))
                total += 1
            end
        end
        percentage = round(processed / total * 100, digits=1)
        eta = round(Dates.value(now() - start_time) * (total - processed) / processed / 1000, digits=2)
        print("\rProgress (level $level): $processed / $total ($percentage%) ETA: $eta (sec)")
    end
    println("...Done")
    return (varphi1=varphi1, varphi2=varphi2, conv=id(varphi1)==id(varphi2), level=level, areas=sort([(k,v) for (k,v) in totalarea], by=x->x[1]))
end

#### exact

function bnbsolver(circles)
    ps = []
    s = zeros(Int, length(circles))
    findpathvectorset(1, s, ps, circles)
    ps
end

function findpathvectorset(m, s, ps, circles)
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

function prob(f::BDD.AbstractNonTerminalNode, pb, cache)
    get!(cache, id(f)) do
        x = label(f)
        p = pb[x]
        pbar = 1.0 - p

        b0 = prob(get_zero(f), pb, cache)
        b1 = prob(get_one(f), pb, cache)

        pbar * b0 + p * b1
    end
end

function prob(f::BDD.AbstractTerminalNode, pb, cache)
    if iszero(f)
        0.0
    else
        1.0
    end
end

# function count(f::BDD.AbstractNonTerminalNode, current_level, cache)
#     n0 = count(get_zero(f), cache)
#     n0_level = level(get_zero(f))
#     n1 = count(get_one(f), cache)
#     n1_level = level(get_one(f))
#     2^(current_level - n0_level - 1) * n0 + 2^(current_level - n1_level - 1) * n1
# end

# function count(f::BDD.AbstractNonTerminalNode, cache)
#     get!(cache, id(f)) do
#         current_level = level(f)
#         n0 = count(get_zero(f), cache)
#         n0_level = level(get_zero(f))
#         n1 = count(get_one(f), cache)
#         n1_level = level(get_one(f))
#         2^(current_level - n0_level - 1) * n0 + 2^(current_level - n1_level - 1) * n1
#     end
# end

# function count(f::BDD.AbstractTerminalNode, cache)
#     if iszero(f)
#         0
#     else
#         1
#     end
# end

function size(f::BDD.AbstractNonTerminalNode, cache)
    if haskey(cache, id(f))
        return 0
    end
    n0 = size(get_zero(f), cache)
    n1 = size(get_one(f), cache)
    cache[id(f)] = true
    n0 + n1 + 1
end

function size(f::BDD.AbstractTerminalNode, cache)
    if haskey(cache, id(f))
        return 0
    end
    cache[id(f)] = true
    1
end

function circleShape(x, y, r)
    theta = LinRange(0, 2*pi, 500)
    x .+ r*sin.(theta), y .+ r*cos.(theta)
end

function drawgraph(xs)
    p = plot(size=(500,500), legend=:outertopleft, xlims=[0,1], ylims=[0,1], aspect_ratio=1)    
    for x in xs
        plot!(circleShape(x.center[1], x.center[2], x.radius),
              seriestype=[:shape], lw=0.5, linecolor=:black, label=x.name, fillalpha=0.1)
    end
    p
end

function createtree(bss, vars, ps, circles)
    if length(ps) == 0
        return bss.zero
    end
    res = []
    for s = ps
        tmp = [vars[circles[i].name] for (i,x) = enumerate(s) if x == 1]
        push!(res, and(tmp...))
    end
    or(res...)
end

function pds(radius, rng; width=1.0, height=1.0, k=30)
    # Parameters
    cell_size = radius / sqrt(2)
    grid_width = ceil(Int, width / cell_size)
    grid_height = ceil(Int, height / cell_size)
    
    # Initialize grid
    grid = Matrix{Union{Nothing, Tuple{Float64, Float64}}}(undef, grid_width, grid_height)
    for i in 1:grid_width, j in 1:grid_height
        grid[i, j] = nothing
    end
    
    points = Tuple{Float64, Float64}[]
    active_list = Tuple{Float64, Float64}[]

    # Add initial point
    x0 = rand(rng) * width
    y0 = rand(rng) * height
    push!(points, (x0, y0))
    push!(active_list, (x0, y0))
    grid[ceil(Int, x0 / cell_size), ceil(Int, y0 / cell_size)] = (x0, y0)

    function is_valid_point(x, y)
        if x < 0 || x >= width || y < 0 || y >= height
            return false
        end
        gx = ceil(Int, x / cell_size)
        gy = ceil(Int, y / cell_size)
        for i in max(gx-2, 1):min(gx+2, grid_width)
            for j in max(gy-2, 1):min(gy+2, grid_height)
                if !isnothing(grid[i, j]) && norm((grid[i, j][1] - x, grid[i, j][2] - y)) < radius
                    return false
                end
            end
        end
        return true
    end

    # Generate points
    while !isempty(active_list)
        i = rand(rng, 1:length(active_list))
        cx, cy = active_list[i]

        success = false
        for _ in 1:k
            angle = 2π * rand(rng)
            r = radius * (1 + rand(rng))
            nx = cx + r * cos(angle)
            ny = cy + r * sin(angle)
            if is_valid_point(nx, ny)
                push!(points, (nx, ny))
                push!(active_list, (nx, ny))
                grid[ceil(Int, nx / cell_size), ceil(Int, ny / cell_size)] = (nx, ny)
                success = true
                break
            end
        end

        if !success
            deleteat!(active_list, i)
        end
    end

    return [Point(x,y) for (x,y) = points]
end

end
