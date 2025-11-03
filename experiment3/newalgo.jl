using Printf
using LinearAlgebra: norm
using GeometryBasics
using Triangulate
using CairoMakie
using Statistics: mean
using Random

struct PointCloud{P}
    points::Vector{P}
end

function Base.getindex(pc::PointCloud{P}, i::Int) where P
    @inbounds pc.points[i]
end

function Base.length(pc::PointCloud{P}) where P
    length(pc.points)
end

function Base.push!(pc::PointCloud{P}, p::P) where P
    push!(pc.points, p)
end

function Base.iterate(pc::PointCloud{P}, state=1) where P
    state > length(pc) && return nothing
    return (pc[state], state + 1)
end

function Base.show(io::IO, pc::PointCloud{P}) where P
    println(io, "PointCloud with ", length(pc), " points:")
    for p in pc
        println(io, p)
    end
end

function PointCloud{P}(points::Vector{P}) where P
    PointCloud{P}(points)
end

function PointCloud{P}() where P
    PointCloud{P}(Vector{P}())
end

const GPoint2 = GeometryBasics.Point2{Float64}
const GTriangle = NTuple{3, Int}

@inline getx(p::GPoint2) = @inbounds p[1]
@inline gety(p::GPoint2) = @inbounds p[2]

"""
Compute the aspect ratio of a triangle (ratio of longest to shortest edge).
"""
function aspect_ratio(pc::PointCloud{P}, tri::GTriangle) where P
    A, B, C = pc[tri[1]], pc[tri[2]], pc[tri[3]]
    d = [
        hypot(getx(A)-getx(B), gety(A)-gety(B)),
        hypot(getx(B)-getx(C), gety(B)-gety(C)),
        hypot(getx(C)-getx(A), gety(C)-gety(A))
    ]
    return maximum(d) / minimum(d)
end

"""
Subdivide a triangle adaptively:
- If aspect ratio > threshold => longest-edge bisection
- Else => centroid (3-split)
Returns a vector of new triangles.
"""
function subdivide_triangle(pc::PointCloud, tri::GTriangle; threshold::Float64=2.5)
    ar = aspect_ratio(pc, tri)
    if ar > threshold
        return subdivide_longest_edge(pc, tri)
    else
        return subdivide_centroid(pc, tri)
    end
end

# --- Supporting functions (from before) ---
function subdivide_centroid(pc::PointCloud, tri::GTriangle)
    A, B, C = pc[tri[1]], pc[tri[2]], pc[tri[3]]
    G = GPoint2((getx(A)+getx(B)+getx(C))/3, (gety(A)+gety(B)+gety(C))/3)
    push!(pc, G)
    G_index = length(pc)
    [GTriangle((tri[1],tri[2],G_index)),
        GTriangle((tri[2],tri[3],G_index)),
        GTriangle((tri[3],tri[1],G_index))]
end

function subdivide_longest_edge(pc::PointCloud, tri::GTriangle)
    A, B, C = pc[tri[1]], pc[tri[2]], pc[tri[3]]
    d = [
        hypot(getx(A)-getx(B), gety(A)-gety(B)),
        hypot(getx(B)-getx(C), gety(B)-gety(C)),
        hypot(getx(C)-getx(A), gety(C)-gety(A))
    ]
    k = argmax(d)
    if k == 1
        M = GPoint2((getx(A)+getx(B))/2, (gety(A)+gety(B))/2)
        push!(pc, M)
        M_index = length(pc)
        [GTriangle((tri[1],M_index,tri[3])), GTriangle((M_index,tri[2],tri[3]))]
    elseif k == 2
        M = GPoint2((getx(B)+getx(C))/2, (gety(B)+gety(C))/2)
        push!(pc, M)
        M_index = length(pc)
        [GTriangle((tri[2],M_index,tri[1])), GTriangle((M_index,tri[3],tri[1]))]
    else  # k == 3
        M = GPoint2((getx(C)+getx(A))/2, (gety(C)+gety(A))/2)
        push!(pc, M)
        M_index = length(pc)
        [GTriangle((tri[3],M_index,tri[2])), GTriangle((M_index,tri[1],tri[2]))]
    end
end

## initial divisions of a polygon into a mesh

function _pointlist_from_points(pts::Vector{P}) where P
    reduce(hcat, (Float64[getx(p), gety(p)] for p in pts))  # 2×N, Float64
end

function _segments_for_cycle(n::Int)
    segs = Matrix{Int32}(undef, 2, n)
    @inbounds for i in 1:n
        segs[1,i] = Int32(i)
        segs[2,i] = Int32(i == n ? 1 : i+1)
    end
    segs
end

function create_initial_area(pts::Vector{P}, options::String="pq30Q") where P
    # pts = GPoint2[GPoint2(getx(p), gety(p)) for p in pts]
    pointlist = _pointlist_from_points(pts)          # 2×N, Float64
    segs      = _segments_for_cycle(length(pts))     # 2×N, Int32

    tin = Triangulate.TriangulateIO()
    tin.pointlist   = pointlist
    tin.segmentlist = segs

    tout, _ = Triangulate.triangulate(options, tin)    # -p PSLG, -q quality, -Q quiet

    verts = [GPoint2(tout.pointlist[1,i], tout.pointlist[2,i]) for i in 1:size(tout.pointlist,2)]
    tris = [GTriangle((
                Int(tout.trianglelist[1,i]),
                Int(tout.trianglelist[2,i]),
                Int(tout.trianglelist[3,i])
                )) for i in 1:size(tout.trianglelist,2)]
    PointCloud(verts), tris
end

function pds(radius::Real; bbox::NTuple{4,Float64}, k::Int=30, rng::AbstractRNG=MersenneTwister(0))
    xmin, xmax, ymin, ymax = bbox
    @assert xmin < xmax && ymin < ymax "invalid bbox"
    r    = float(radius)
    cell = r / sqrt(2)
    gw   = Int(ceil((xmax - xmin) / cell))
    gh   = Int(ceil((ymax - ymin) / cell))

    grid   = fill(0, gw, gh)
    points = Vector{GPoint2}()
    active = Vector{Int}()

    @inline gx(x)::Int = max(1, min(gw, Int(floor((x - xmin)/cell)) + 1))
    @inline gy(y)::Int = max(1, min(gh, Int(floor((y - ymin)/cell)) + 1))
    @inline in_bbox(x,y)::Bool = (xmin <= x < xmax) & (ymin <= y < ymax)

    function is_valid(x::Float64, y::Float64)::Bool
        if !in_bbox(x,y)
            return false
        end
        ii = gx(x); jj = gy(y)
        i1 = max(ii-2, 1); i2 = min(ii+2, gw)
        j1 = max(jj-2, 1); j2 = min(jj+2, gh)
        @inbounds for i in i1:i2, j in j1:j2
            idx = grid[i,j]
            if idx != 0
                p = points[idx]
                if hypot(getx(p) - x, gety(p) - y) < r
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
        if is_valid(x0, y0)
            push!(points, GPoint2(x0, y0))
            push!(active, length(points))
            grid[gx(x0), gy(y0)] = length(points)
            found = true
            break
        end
    end
    found || throw(ArgumentError("could not find initial point inside bbox"))

    # Bridson's algorithm
    while !isempty(active)
        ai = rand(rng, 1:length(active))  # random index into `active`
        ci = active[ai]
        c  = points[ci]
        success = false

        @inbounds for _ in 1:k
            θ  = 2π * rand(rng)
            ρ  = r * (1 + rand(rng))   # [r, 2r)
            nx = getx(c) + ρ * cos(θ)
            ny = gety(c) + ρ * sin(θ)
            if is_valid(nx, ny)
                push!(points, GPoint2(nx, ny))
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


# --- Example ---
# tri1 = (GPoint2(0.0,0.0), GPoint2(2.0,0.0), GPoint2(0.1,0.3))  # longest-edge
# tri2 = (GPoint2(0.0,0.0), GPoint2(1.0,0.0), GPoint2(0.5,0.8))  # centroid

# println("Aspect ratio tri1 = ", aspect_ratio(tri1))
# println("Aspect ratio tri2 = ", aspect_ratio(tri2))

# println("Subdivide tri1:")
# for t in subdivide_triangle(tri1)
#     @printf("(%.2f, %.2f), (%.2f, %.2f), (%.2f, %.2f): Aspect Ratio = %.2f\n",
#         getx(t[1]), gety(t[1]),
#         getx(t[2]), gety(t[2]),
#         getx(t[3]), gety(t[3]),
#         aspect_ratio(t))
# end

# println("Subdivide tri2:")
# for t in subdivide_triangle(tri2)
#     @printf("(%.2f, %.2f), (%.2f, %.2f), (%.2f, %.2f): Aspect Ratio = %.2f\n",
#         getx(t[1]), gety(t[1]),
#         getx(t[2]), gety(t[2]),
#         getx(t[3]), gety(t[3]),
#         aspect_ratio(t))
# end

# --- Create initial mesh from polygon ---
# Define polygon points: star shape
# pts = [
#     GPoint2(0.0, 0.0),
#     GPoint2(2.0, 0.0),
#     GPoint2(2.0, 2.0),
#     GPoint2(1.0, 1.5),
#     GPoint2(0.0, 2.0)
# ]
pts = GPoint2[
    (139.7016611, 35.6691816),
    (139.7007399, 35.6687173),
    (139.7006075, 35.6686744),
    (139.7004564, 35.6686324),
    (139.7001898, 35.6685751),
    (139.6999074, 35.6685563),
    (139.6988411, 35.6685207),
    (139.6977748, 35.6684827),
    (139.6978161, 35.6672282),
    (139.6939972, 35.6658081),
    (139.693817, 35.6660581),
    (139.6937248, 35.6661603),
    (139.6936046, 35.6662562),
    (139.693503, 35.6663251),
    (139.6933937, 35.6663802),
    (139.6929956, 35.6665765),
    (139.6928984, 35.6666415),
    (139.6928205, 35.6667078),
    (139.6926846, 35.6668521),
    (139.6924329, 35.6671748),
    (139.6920092, 35.6677355),
    (139.6918508, 35.6679671),
    (139.6916349, 35.6682495),
    (139.6913676, 35.6685963),
    (139.691226, 35.6687844),
    (139.6911329, 35.6689444),
    (139.6910781, 35.6690699),
    (139.6910527, 35.6691401),
    (139.6909846, 35.6693445),
    (139.6909478, 35.6695078),
    (139.6909321, 35.6697975),
    (139.6909417, 35.6699636),
    (139.6909874, 35.6702597),
    (139.691123, 35.6710106),
    (139.6914994, 35.6730074),
    (139.6916563, 35.67394),
    (139.6928121, 35.6735002),
    (139.6933393, 35.6740627),
    (139.6934752, 35.6742077),
    (139.6940082, 35.6747249),
    (139.6947275, 35.674728),
    (139.6947516, 35.6750723),
    (139.6953685, 35.6750853),
    (139.6955053, 35.6744164),
    (139.6956099, 35.6741419),
    (139.6958728, 35.6738042),
    (139.6982894, 35.671671),
    (139.6999658, 35.6711393),
    (139.7006015, 35.6699801)
]

R = 6_371_000.0

# 原点（左下＝min lon/lat）と、x縮尺用の代表緯度（平均緯度）
lon_min = minimum(getx.(pts))
lat_min = minimum(gety.(pts))
lat_bar = mean(gety.(pts))

# lon/lat [deg] → x/y [m] に変換（すでに左下原点になる）
pts = [GPoint2(
    R * deg2rad(getx(p) - lon_min) * cos(deg2rad(lat_bar)),
    R * deg2rad(gety(p) - lat_min)
) for p in pts]
# get bbox
lon_min = minimum(getx.(pts))
lat_min = minimum(gety.(pts))
lon_max = maximum(getx.(pts))
lat_max = maximum(gety.(pts))
@printf("Bounding box: width = %.2f m, height = %.2f m\n", lon_max - lon_min, lat_max - lat_min)

pdspoints = pds(50.0; bbox=(lon_min, lon_max, lat_min, lat_max))

pc, triangles = create_initial_area(pts)
println("Number of triangles in initial mesh: ", length(triangles))
for (i,t) in enumerate(triangles)
    @printf("Triangle %d: (%.2f, %.2f), (%.2f, %.2f), (%.2f, %.2f): Aspect Ratio = %.2f\n",
        i,
        getx(pc[t[1]]), gety(pc[t[1]]),
        getx(pc[t[2]]), gety(pc[t[2]]),
        getx(pc[t[3]]), gety(pc[t[3]]),
        aspect_ratio(pc, t))
end

# draw_mesh(pc, triangles) with png

function draw_mesh(pc::PointCloud{P}, triangles::Vector{GTriangle}) where P
    fig = Figure(size = (800, 800))
    ax = Axis(fig[1, 1]; aspect = DataAspect())

    for t in triangles
        x_coords = [getx(pc[t[1]]), getx(pc[t[2]]), getx(pc[t[3]]), getx(pc[t[1]])]
        y_coords = [gety(pc[t[1]]), gety(pc[t[2]]), gety(pc[t[3]]), gety(pc[t[1]])]
        lines!(ax, x_coords, y_coords, color = :black)
    end

    scatter!(ax, [getx(p) for p in pc], [gety(p) for p in pc], color = :red)

    fig
end

fig = draw_mesh(pc, triangles)
# overlay pds points
scatter!(fig[1, 1], [getx(p) for p in pdspoints], [gety(p) for p in pdspoints], color = :blue)

save("mesh.png", fig)

