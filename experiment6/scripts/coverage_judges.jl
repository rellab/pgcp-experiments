# Two independent coverage judges for a union of disks over an axis-aligned
# rectangle. Neither uses the partition-based conditions phi_1 / phi_2 of the
# BDD solver, so both serve as independent ground truth for a given state x.
#
#   Judge A (arrangement):   Omega is covered iff every vertex of the
#       arrangement (rectangle corners, circle-edge intersections,
#       circle-circle intersections inside Omega) is covered by an active disk
#       other than the ones that define it. Candidate points are state
#       independent, so they are precomputed once, together with the bitset of
#       disks that strictly contain each point; a state is then judged by
#       bit operations only.
#
#   Judge B (power diagram): Omega is covered iff, for every active disk i,
#       every vertex of its power cell clipped to Omega lies in disk i.
#       The cell is rebuilt per state by half-plane clipping.
#
# Both assume general position (no tangencies, no three circles through one
# point). Each judge records the smallest margin it saw, so that near-degenerate
# decisions can be detected.

module CoverageJudges

export Disk, Rect, ArrangementJudge, covered_arrangement, covered_power, state_bits

struct Disk
    x::Float64
    y::Float64
    r::Float64
end

struct Rect
    xmin::Float64
    xmax::Float64
    ymin::Float64
    ymax::Float64
end

const Bits = UInt128   # supports up to 128 disks

@inline bit(k::Int) = Bits(1) << (k - 1)

# signed margin of point (px,py) w.r.t. disk d: negative inside, positive outside
@inline margin(d::Disk, px, py) = hypot(px - d.x, py - d.y) - d.r

# ---------------------------------------------------------------- Judge A

struct Candidate
    px::Float64
    py::Float64
    owners::Bits     # disks whose boundaries define the point (0 for a corner)
    cover::Bits      # disks that contain the point (strictly, for non-corners)
end

mutable struct ArrangementJudge
    n::Int
    cands::Vector{Candidate}
    min_margin::Float64   # smallest | dist - r | over all containment tests
end

function cover_bits(disks::Vector{Disk}, px, py, exclude::Bits, minm::Base.RefValue{Float64})
    b = Bits(0)
    for (k, d) in enumerate(disks)
        (bit(k) & exclude) != 0 && continue
        m = margin(d, px, py)
        abs(m) < minm[] && (minm[] = abs(m))
        m < 0 && (b |= bit(k))
    end
    return b
end

function ArrangementJudge(disks::Vector{Disk}, R::Rect)
    n = length(disks)
    @assert n <= 128
    cands = Candidate[]
    minm = Ref(Inf)

    # (1) rectangle corners
    for (px, py) in ((R.xmin, R.ymin), (R.xmin, R.ymax), (R.xmax, R.ymin), (R.xmax, R.ymax))
        push!(cands, Candidate(px, py, Bits(0), cover_bits(disks, px, py, Bits(0), minm)))
    end

    # (2) circle-edge intersections
    for (i, d) in enumerate(disks)
        for x0 in (R.xmin, R.xmax)            # vertical edges
            h2 = d.r^2 - (x0 - d.x)^2
            h2 <= 0 && continue
            for s in (-1.0, 1.0)
                py = d.y + s * sqrt(h2)
                (R.ymin <= py <= R.ymax) || continue
                push!(cands, Candidate(x0, py, bit(i), cover_bits(disks, x0, py, bit(i), minm)))
            end
        end
        for y0 in (R.ymin, R.ymax)            # horizontal edges
            h2 = d.r^2 - (y0 - d.y)^2
            h2 <= 0 && continue
            for s in (-1.0, 1.0)
                px = d.x + s * sqrt(h2)
                (R.xmin <= px <= R.xmax) || continue
                push!(cands, Candidate(px, y0, bit(i), cover_bits(disks, px, y0, bit(i), minm)))
            end
        end
    end

    # (3) circle-circle intersections inside the rectangle
    for i in 1:n-1, j in i+1:n
        a, b = disks[i], disks[j]
        dx, dy = b.x - a.x, b.y - a.y
        dist = hypot(dx, dy)
        (dist >= a.r + b.r || dist <= abs(a.r - b.r)) && continue
        t = (dist^2 + a.r^2 - b.r^2) / (2 * dist)
        h2 = a.r^2 - t^2
        h2 <= 0 && continue
        h = sqrt(h2)
        mx, my = a.x + t * dx / dist, a.y + t * dy / dist
        for s in (-1.0, 1.0)
            px, py = mx - s * h * dy / dist, my + s * h * dx / dist
            (R.xmin <= px <= R.xmax && R.ymin <= py <= R.ymax) || continue
            own = bit(i) | bit(j)
            push!(cands, Candidate(px, py, own, cover_bits(disks, px, py, own, minm)))
        end
    end

    return ArrangementJudge(n, cands, minm[])
end

# x is the bitset of active disks.
function covered_arrangement(J::ArrangementJudge, x::Bits)
    @inbounds for c in J.cands
        if (c.owners & x) == c.owners && (c.cover & x) == 0
            return false
        end
    end
    return true
end

# ---------------------------------------------------------------- Judge B

# Clip a convex polygon (vector of (x,y)) by the half-plane a*x + b*y <= c.
function clip_halfplane(poly::Vector{NTuple{2,Float64}}, a, b, c)
    out = NTuple{2,Float64}[]
    m = length(poly)
    m == 0 && return out
    for k in 1:m
        p = poly[k]
        q = poly[k == m ? 1 : k + 1]
        fp = a * p[1] + b * p[2] - c
        fq = a * q[1] + b * q[2] - c
        if fp <= 0
            push!(out, p)
        end
        if (fp < 0 && fq > 0) || (fp > 0 && fq < 0)
            s = fp / (fp - fq)
            push!(out, (p[1] + s * (q[1] - p[1]), p[2] + s * (q[2] - p[2])))
        end
    end
    return out
end

# Returns (covered, min_margin). `active` lists the indices of active disks.
function covered_power(disks::Vector{Disk}, R::Rect, active::Vector{Int})
    minm = Inf
    isempty(active) && return (false, minm)
    box = NTuple{2,Float64}[(R.xmin, R.ymin), (R.xmax, R.ymin), (R.xmax, R.ymax), (R.xmin, R.ymax)]
    ok = true
    for i in active
        di = disks[i]
        cell = box
        for j in active
            j == i && continue
            dj = disks[j]
            # pow_i(p) <= pow_j(p)  <=>  2(cj - ci).p <= |cj|^2 - rj^2 - |ci|^2 + ri^2
            a = 2 * (dj.x - di.x)
            b = 2 * (dj.y - di.y)
            c = (dj.x^2 + dj.y^2 - dj.r^2) - (di.x^2 + di.y^2 - di.r^2)
            cell = clip_halfplane(cell, a, b, c)
            isempty(cell) && break
        end
        for (px, py) in cell
            m = margin(di, px, py)
            abs(m) < minm && (minm = abs(m))
            m > 0 && (ok = false)
        end
    end
    return (ok, minm)
end

state_bits(active::Vector{Int}) = reduce(|, (bit(k) for k in active); init = Bits(0))

end # module
