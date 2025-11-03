using GeometryBasics
using Triangulate

const MyPoint2 = GeometryBasics.Point2

struct MyPolygon{P<:MyPoint2}
    points::Vector{P}
end

struct MyTriangle{P<:MyPoint2}
    vertices::NTuple{3,P}
end

struct MyMesh{P<:MyPoint2}
    faces::Vector{MyTriangle{P}}
end

@inline getx(p::MyPoint2{T}) where T = @inbounds p[1]
@inline gety(p::MyPoint2{T}) where T = @inbounds p[2]
@inline getpoints(poly::MyPolygon{P}) where P<:MyPoint2 = poly.points

function _pointlist_from_points(pts::Vector{<:MyPoint2})
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

function polygon_to_mesh(polygon::MyPolygon{P}) where P<:MyPoint2
    pts       = getpoints(polygon)
    pointlist = _pointlist_from_points(pts)          # 2×N, Float64
    segs      = _segments_for_cycle(length(pts))     # 2×N, Int32

    tin = Triangulate.TriangulateIO()
    tin.pointlist   = pointlist
    tin.segmentlist = segs

    tout, _ = Triangulate.triangulate("pqQ", tin)    # -p PSLG, -q quality, -Q quiet

    verts = [MyPoint2(tout.pointlist[1,i], tout.pointlist[2,i]) for i in 1:size(tout.pointlist,2)]
    faces = [MyTriangle{typeof(verts[1])}((verts[Int(tout.trianglelist[1,i])],
              verts[Int(tout.trianglelist[2,i])],
              verts[Int(tout.trianglelist[3,i])])) for i in 1:size(tout.trianglelist,2)]

    MyMesh{P}(faces)
end

function splitting_area(tri::MyTriangle{P}) where P<:MyPoint2
    pts = tri.vertices
    # make 3 triangles by using the center of gravity
    center = P((getx(pts[1]) + getx(pts[2]) + getx(pts[3]))/3,
                      (gety(pts[1]) + gety(pts[2]) + gety(pts[3]))/3)
    t1 = MyTriangle{P}((pts[1], pts[2], center))
    t2 = MyTriangle{P}((pts[2], pts[3], center))
    t3 = MyTriangle{P}((pts[3], pts[1], center))
    [t1, t2, t3]
end

pts  = [MyPoint2(0.0,0.0), MyPoint2(2.0,0.0), MyPoint2(2.0,2.0), MyPoint2(0.0,2.0)]
poly = MyPolygon(pts)
mesh = polygon_to_mesh(poly)
println("Number of triangles: ", length(mesh.faces))
for (i, tri) in enumerate(mesh.faces)
    subtris = splitting_area(tri)
    println("Triangle $i split into ", length(subtris), " sub-triangles.")
end
