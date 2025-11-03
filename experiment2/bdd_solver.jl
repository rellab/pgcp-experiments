module BDDSolver

using MiniCUDD
using Printf
using JSON
using ProgressMeter
using GeometryBasics: Point
using LinearAlgebra

abstract type AbstractArea end

@inline getx(p::Point) = @inbounds p[1]
@inline gety(p::Point) = @inbounds p[2]

struct Circle
    name::String
    center::Point
    radius::Float64
end

struct Rectangle4 <: AbstractArea
    vertices::NTuple{4,Point}
end

# function Rectangle4(vs::Vector{Point})
#     Rectangle4(vs)
# end

# function Rectangle4(vs::NTuple{4,Point})
#     Rectangle4(vs)
# end

function Rectangle4(left_lower::Point, right_upper::Point)
    Rectangle4([left_lower, Point(getx(left_lower), gety(right_upper)), right_upper, Point(getx(right_upper), gety(left_lower))])
end

@inline leftlower(r::Rectangle4) = @inbounds r.vertices[1]
@inline leftupper(r::Rectangle4) = @inbounds r.vertices[2]
@inline rightupper(r::Rectangle4) = @inbounds r.vertices[3]
@inline rightlower(r::Rectangle4) = @inbounds r.vertices[4]

isinside(c::Circle, p::Point) = (getx(p) - getx(c.center))^2 + (gety(p) - gety(c.center))^2 <= c.radius^2
dist(a::Point,b::Point) = hypot(getx(a)-getx(b), gety(a)-gety(b))

createarea(area::AbstractArea; kwargs...) = error("createarea(::$(typeof(area))) is not implemented")

function createarea(rect::Rectangle4; gridsize::Int)
    ll = leftlower(rect); ur = rightupper(rect)
    x0 = getx(ll); y0 = gety(ll)
    x1 = getx(ur); y1 = gety(ur)

    dx = (x1 - x0) / gridsize
    dy = (y1 - y0) / gridsize

    n  = gridsize * gridsize
    out = Vector{Rectangle4}(undef, n)
    k = 0

    @inbounds for i in 0:gridsize-1
        xa = x0 + dx * i
        xb = xa + dx
        for j in 0:gridsize-1
            ya = y0 + dy * j
            yb = ya + dy
            k += 1
            out[k] = Rectangle4((Point(xa,ya), Point(xa,yb), Point(xb,yb), Point(xb,ya)))
        end
    end
    return out
end

# ===================== BDD Utilities =====================
function bdd_and(M::MiniCUDD.Manager, vs::Vector{MiniCUDD.BDDNode})
    if isempty(vs)
        return const1(M)
    end
    acc = vs[1]
    for v in vs[2:end]
        acc = MiniCUDD.bdd_and(M, acc, v)
    end
    return acc
end

function bdd_or(M::MiniCUDD.Manager, vs::Vector{MiniCUDD.BDDNode})
    if isempty(vs)
        return const0(M)
    end
    acc = vs[1]
    for v in vs[2:end]
        acc = MiniCUDD.bdd_or(M, acc, v)
    end
    return acc
end

# Utility: intersection of sorted vectors
function set_intersection_vec(a::Vector{T}, b::Vector{T}) where T
    sort!(a); sort!(b)
    out = Vector{T}()
    i = 1; j = 1
    while i <= length(a) && j <= length(b)
        if a[i] < b[j]
            i += 1
        elseif b[j] < a[i]
            j += 1
        else
            push!(out, a[i]); i += 1; j += 1
        end
    end
    return out
end

# Probability via BDD traversal memoized
function prob(M::MiniCUDD.Manager, node::MiniCUDD.BDDNode, pb::Dict{Int,Float64})
    memo = Dict{UInt, Float64}()
    oneptr = const1(M).ptr
    zeroptr = const0(M).ptr
    function go(n::MiniCUDD.BDDNode)
        key = UInt(n.ptr)
        if haskey(memo, key)
            return memo[key]
        end
        if isconstant(n)
            v = (n.ptr == oneptr) ? 1.0 : 0.0
            memo[key] = v
            return v
        end
        idx = Int(node_index(n)) + 1 # MiniCUDD uses 0-based
        pvar = pb[idx-1] # store pb with 0-based keys
        t = bdd_then(M, n)
        e = bdd_else(M, n)
        pt = go(t)
        pe = go(e)
        val = pvar * pt + (1.0 - pvar) * pe
        memo[key] = val
        return val
    end
    return go(node)
end

# ===================== bddsolver =====================
struct SolverResult
    varphi1::MiniCUDD.BDDNode
    varphi2::MiniCUDD.BDDNode
    conv::Bool
    level::Int
    areasByLevel::Vector{Tuple{Int,Int}}
end

function bddsolver(M::MiniCUDD.Manager, vars::Dict{String,Int},
    circles::Vector{Circle}, root::Rectangle4; gridsize::Int=4, maxlevel::Int=10)
    varphi1 = const1(M)
    varphi2 = const1(M)

    q = Vector{Tuple{Rectangle4,Int}}()
    push!(q, (root,1))

    total = 1; processed = 0
    totalarea = Dict{Int,Int}()
    t0 = time()
    level = 1

    pm = Progress(total; dt=0.3, desc="Solving (Level $level, Processed $processed / $total)")
    last_total = total

    while !isempty(q)
        rect, curLevel = popfirst!(q)
        level = curLevel
        processed += 1

        areas = createarea(rect; gridsize=gridsize)
        for r in areas
            idxsPerVertex = [Int[] for _ in 1:4]
            # for k in 1:4
            #     p = r.vertices[k]
            for (k,p) in enumerate(r.vertices)
                for c in circles
                    if isinside(c, p)
                        if haskey(vars, c.name)
                            push!(idxsPerVertex[k], vars[c.name])
                        end
                    end
                end
            end

            vars2 = copy(idxsPerVertex[1])
            for k in 2:4
                vars2 = set_intersection_vec(vars2, idxsPerVertex[k])
            end

            ors = MiniCUDD.const0(M)
            # build OR per vertex
            ors_vec = MiniCUDD.const0(M)
            per_vertex_bdds = MiniCUDD.const0(M)
            ors_list = MiniCUDD.BDDNode[]
            for vv in idxsPerVertex
                tmp = MiniCUDD.const0(M)
                if !isempty(vv)
                    tmp = var(M, vv[1])
                    for id in vv[2:end]
                        tmp = MiniCUDD.bdd_or(M, tmp, var(M, id))
                    end
                end
                push!(ors_list, tmp)
            end
            varphi1new = ors_list[1]
            for i in 2:length(ors_list)
                varphi1new = bdd_and(M, [varphi1new, ors_list[i]])
            end

            tmp2 = MiniCUDD.const0(M)
            if !isempty(vars2)
                tmp2 = var(M, vars2[1])
                for id in vars2[2:end]
                    tmp2 = MiniCUDD.bdd_or(M, tmp2, var(M, id))
                end
            end
            varphi2new = tmp2

            varphi1dash = bdd_and(M, [varphi1, varphi1new])
            varphi2dash = bdd_and(M, [varphi2, varphi2new])

            same_new = (varphi1new.ptr == varphi2new.ptr)
            same_dash = (varphi1dash.ptr == varphi2dash.ptr)

            if same_new || same_dash || curLevel == maxlevel
                varphi1 = varphi1dash
                varphi2 = varphi2dash
                totalarea[curLevel] = get(totalarea, curLevel, 0) + 1
            else
                push!(q, (r, curLevel+1))
                total += 1
            end
        end

        if total != last_total
            pm.n = total
            last_total = total
        end
        desc = @sprintf("Solving (Level %d, Processed %d / %d)", level, processed, total)
        update!(pm, processed; desc=desc)
    end

    finish!(pm)

    areasByLevel = collect(totalarea)
    sort!(areasByLevel)
    areas_pairs = [(k,v) for (k,v) in areasByLevel]
    return SolverResult(varphi1, varphi2, varphi1.ptr == varphi2.ptr, level, areas_pairs)
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

# sort
function sort_with_origin(circles::Vector{Circle})
    return sort(circles, by = c -> dist(Point(0.0,0.0), c.center))
end

"""
    build_adjacency(circles; mode=:linear)

Constructs the weighted adjacency matrix A from circle overlaps.

`mode` can be:
  - `:area`   → π * min(r_i, r_j)^2
  - `:linear` → max(0, r_i + r_j - d)
  - `:gaussian` → exp(-d^2 / (2σ^2))
"""
function build_adjacency(circles::Vector{Circle}; mode=:linear, σ=1.0)
    n = length(circles)
    A = zeros(Float64, n, n)
    for i in 1:n, j in i+1:n
        ci, cj = circles[i], circles[j]
        d = dist(ci.center, cj.center)
        if d < ci.radius + cj.radius
            w = if mode == :area
                π * min(ci.radius, cj.radius)^2
            elseif mode == :gaussian
                exp(-d^2 / (2σ^2))
            elseif mode == :binary
                1.0
            else  # :linear
                max(0.0, ci.radius + cj.radius - d)
            end
            A[i,j] = w
            A[j,i] = w
        end
    end
    return A
end

"""
    spectral_order(A::AbstractMatrix)

Returns indices that sort nodes by the 2nd smallest Laplacian eigenvector (Fiedler vector).
"""
function spectral_order(A::AbstractMatrix)
    D = Diagonal(sum(A, dims=2)[:])
    L = D - A
    evals, evecs = eigen(L)
    fiedler = evecs[:,2]
    return sortperm(fiedler)
end

function sort_with_laplacian(circles::Vector{Circle}, ; mode=:linear)
    A = build_adjacency(circles; mode=mode)
    order = spectral_order(A)
    # reverse!(order)  # optional: reverse order to have more connected circles first
    return circles[order]
end

# ===================== main =====================
function main(argv)
    if length(argv) < 1
        println("Usage: julia bdd_solver.jl data.json")
        return
    end

    firstarg = argv[1]
    gridsize = 4
    maxlevel = 10
    reliability = 0.9

    @info "Loading JSON config: $firstarg"
    circles, gridsize, maxlevel, reliability = load_config_from_json(firstarg)

    @info "Reliability(all): $reliability"
    @info "Gridsize: $gridsize"
    @info "Maxlevel: $maxlevel"

    # sort circles
    circles = sort_with_origin(circles)
    # circles = sort_with_laplacian(circles; mode=:linear)
    # circles = sort_with_laplacian(circles; mode=:area)
    # circles = sort_with_laplacian(circles; mode=:gaussian)

    vars = Dict{String,Int}()
    pb = Dict{Int,Float64}()
    for (i,c) in enumerate(circles)
        vars[c.name] = i-1 # 0-based
        pb[i-1] = reliability
    end
    @info "Number of circles: $(length(circles))"

    M = Manager(nvars=max(1,length(circles)))

    targetarea = Rectangle4((Point(0.0,0.0), Point(0.0,1.0), Point(1.0,1.0), Point(1.0,0.0)))
    t0 = @elapsed begin
        res = bddsolver(M, vars, circles, targetarea; gridsize=gridsize, maxlevel=maxlevel)
    end

    @info "Convergence: $(res.conv)"
    @info "Level: $(res.level)"
    @info "Area: $(res.areasByLevel)"
    @info "Circles: $(length(circles))"
    @info "Nodes: $(dag_size(res.varphi1))"
    @info "SolveTime(sec): $t0"

    t2 = @elapsed begin
        lb = prob(M, res.varphi2, pb)
    end
    t3 = @elapsed begin
        ub = prob(M, res.varphi1, pb)
    end

    @info "Reliability: [$lb, $ub]"
    @info "ProbTime(varphi2): $(t2), ProbTime(varphi1): $(t3)"

    results = Dict(
        "Convergence" => res.conv,
        "Level" => res.level,
        "AreasByLevel" => res.areasByLevel,
        "LowerNodes" => dag_size(res.varphi1),
        "UpperNodes" => dag_size(res.varphi2),
        "ReliabilityLowerBound" => lb,
        "ReliabilityUpperBound" => ub,
        "SolveTimeSec" => t0,
        "ProbTimeVarphi2Sec" => t2,
        "ProbTimeVarphi1Sec" => t3
    )
    println(JSON.json(results))

    quit(M)
end

end

##================== run as script =====================

if abspath(PROGRAM_FILE) == @__FILE__
    using .BDDSolver
    BDDSolver.main(ARGS)
end
