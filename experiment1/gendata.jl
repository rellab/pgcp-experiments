using Random
using LinearAlgebra: hypot
using JSON
using DataStructures: OrderedDict

# ===== Common definitions for area and point =====
struct Point
    x::Float64
    y::Float64
end

abstract type AbstractArea end

"Required: Get the bounding box of the area"
bbox(::AbstractArea)::NTuple{4,Float64} = error("bbox(area) must be implemented")

"Required: Check if a point is inside the area"
isinside(::AbstractArea, ::Point)::Bool = error("isinside(area, p) must be implemented")

# ===== Example 1: Rectangle area =====
struct RectArea <: AbstractArea
    xmin::Float64; xmax::Float64
    ymin::Float64; ymax::Float64
end
bbox(a::RectArea) = (a.xmin, a.xmax, a.ymin, a.ymax)
isinside(a::RectArea, p::Point) = (a.xmin <= p.x < a.xmax) & (a.ymin <= p.y < a.ymax)

# ===== Example 2: Circle area =====
struct CircleArea <: AbstractArea
    cx::Float64; cy::Float64; r::Float64
end
bbox(a::CircleArea) = (a.cx - a.r, a.cx + a.r, a.cy - a.r, a.cy + a.r)
isinside(a::CircleArea, p::Point) = (p.x - a.cx)^2 + (p.y - a.cy)^2 <= a.r^2

# ===== Example 3: Polygon area (Ray-casting method) =====
struct PolygonArea <: AbstractArea
    verts::Vector{Point}  # vertices in order
end
function bbox(a::PolygonArea)
    xs = (v.x for v in a.verts); ys = (v.y for v in a.verts)
    return (minimum(xs), maximum(xs), minimum(ys), maximum(ys))
end
function isinside(a::PolygonArea, p::Point)
    c = false
    n = length(a.verts)
    @inbounds for i in 1:n
        v1 = a.verts[i]; v2 = a.verts[i == n ? 1 : i+1]
        if (v1.y > p.y) != (v2.y > p.y)
            t = (p.y - v1.y) / (v2.y - v1.y)
            xcross = v1.x + t * (v2.x - v1.x)
            if p.x < xcross
                c = !c
            end
        end
    end
    return c
end

"""
Poisson Disk Sampling on an arbitrary 2D area.

radius: minimum distance between points
area::AbstractArea: bbox(area), isinside(area,p) must be defined
k: number of attempts per active point
rng: random number generator
"""
function pds(radius::Real; area::AbstractArea, k::Int=30, rng::AbstractRNG=MersenneTwister(0))
    xmin, xmax, ymin, ymax = bbox(area)
    @assert xmin < xmax && ymin < ymax "invalid bbox"
    r    = float(radius)
    cell = r / sqrt(2)
    gw   = Int(ceil((xmax - xmin) / cell))
    gh   = Int(ceil((ymax - ymin) / cell))

    grid   = fill(0, gw, gh)
    points = Vector{Point}()
    active = Vector{Int}()

    @inline gx(x)::Int = max(1, min(gw, Int(floor((x - xmin)/cell)) + 1))
    @inline gy(y)::Int = max(1, min(gh, Int(floor((y - ymin)/cell)) + 1))
    @inline in_bbox(x,y)::Bool = (xmin <= x < xmax) & (ymin <= y < ymax)

    function is_valid(x::Float64, y::Float64)::Bool
        if !in_bbox(x,y) || !isinside(area, Point(x,y))
            return false
        end
        ii = gx(x); jj = gy(y)
        i1 = max(ii-2, 1); i2 = min(ii+2, gw)
        j1 = max(jj-2, 1); j2 = min(jj+2, gh)
        @inbounds for i in i1:i2, j in j1:j2
            idx = grid[i,j]
            if idx != 0
                p = points[idx]
                if hypot(p.x - x, p.y - y) < r
                    return false
                end
            end
        end
        return true
    end

    # Rejection sampling for initial point
    found = false
    for _ in 1:10_000
        x0 = rand(rng) * (xmax - xmin) + xmin
        y0 = rand(rng) * (ymax - ymin) + ymin
        if isinside(area, Point(x0,y0))
            push!(points, Point(x0,y0))
            push!(active, length(points))
            grid[gx(x0), gy(y0)] = length(points)
            found = true
            break
        end
    end
    found || throw(ArgumentError("could not find initial point inside area"))

    # Bridson's algorithm
    while !isempty(active)
        ai = rand(rng, eachindex(active))
        ci = active[ai]
        c  = points[ci]
        success = false

        @inbounds for _ in 1:k
            θ  = 2π * rand(rng)
            ρ  = r * (1 + rand(rng))   # [r, 2r)
            nx = c.x + ρ * cos(θ)
            ny = c.y + ρ * sin(θ)
            if is_valid(nx, ny)
                push!(points, Point(nx, ny))
                newi = length(points)
                push!(active, newi)
                grid[gx(nx), gy(ny)] = newi
                success = true
                break
            end
        end

        if !success
            active[ai] = active[end]; pop!(active)
        end
    end

    return points
end

# man function to create JSON file of circles
struct Circle
    name::String
    center::Point
    radius::Float64
end

function Circle(i::Int, center::Point, radius::Float64)
    return Circle("$(i)", center, radius)
end

function readconfigfromJSON(filename)
    config = JSON.parsefile(filename)
    areaconf = config["area"]
    area_type = areaconf["type"]
    if area_type == "rectangle"
        area = RectArea(areaconf["xmin"], areaconf["xmax"], areaconf["ymin"], areaconf["ymax"])
    elseif area_type == "circle"
        area = CircleArea(areaconf["cx"], areaconf["cy"], areaconf["r"])
    elseif area_type == "polygon"
        verts = [Point(v[1], v[2]) for v in areaconf["verts"]]
        area = PolygonArea(verts)
    else
        error("unknown area type: $area_type")
    end
    pdsradius = config["pds_radius"]
    radius_domain = config["radius_domain"]
    seed = config["seed"]
    return area, pdsradius, radius_domain, seed
end

function main(argv)
    # get filename from command line arguments
    if length(argv) != 2
        @info "Usage: julia gendata.jl [config.json] [output.json]"
        return
    end

    filename = argv[1]
    @info "Using config file: $filename"
    output_filename = argv[2]
    @info "Using output file: $output_filename"

    area, pdsradius, radius_domain, seed = readconfigfromJSON(filename)
    rng = MersenneTwister(seed)
    points = pds(pdsradius; area=area, rng=rng)
    @info "Generated $(length(points)) points"

    # generate circles
    circles = []
    for (k,p) in enumerate(points)
        radius = rand(rng, radius_domain)
        push!(circles, Circle(k, p, radius))
    end

    # dump to JSON:
    circles_json = OrderedDict(
        "config" => filename,
        "gridsize" => 4,
        "maxlevel" => 10,
        "reliability" => 0.9,
        "circles" => [
            OrderedDict(
                "name" => c.name,
                "x" => c.center.x,
                "y" => c.center.y,
                "radius" => c.radius) for c in circles])
    open(output_filename, "w") do io
        JSON.print(io, circles_json, 2)
    end
    @info "Wrote circles to $output_filename"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end