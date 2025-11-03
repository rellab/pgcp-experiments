using Pkg
Pkg.activate(".")
Pkg.instantiate()

include("../src/gpcp_binary.jl")

using .GPCPBinary: Circle, Rectangle4, dist, bddsolver, randcoordinate, bnbsolver, createtree
using GeometryBasics: Point
using Random: MersenneTwister
using DD.BDD: bdd, defvar!, var!, id
using CSV
using DataFrames

struct MyException <: Exception
    msg::String
    value::Any
end

function randcoordinate2(rng, eps)
    x = rand(rng) * (1 - 2eps) + eps
    y = rand(rng) * (1 - 2eps) + eps
    return Point(x, y)
end

function experiment1(n, radius, rng)
    targetarea = Rectangle4([Point(0.0, 0.0), Point(1.0, 0.0), Point(1.0, 1.0), Point(0.0, 1.0)])
    circles = [Circle(i, randcoordinate2(rng, 0.1), radius) for i = 1:n]
    sort!(circles, by = x -> dist(x.center, Point(0,0)))

    bss = bdd()
    for (k,x) = enumerate(circles)
        defvar!(bss, Symbol(x.name), k)
    end
    vars = Dict([x.name => var!(bss, Symbol(x.name)) for x = circles])
    
    varphi1, time1, allocated1, garbage1 = @timed begin
        varphi1, varphi2, conv, searchedlevel, areas = bddsolver(bss, vars, circles, targetarea, gridsize=4, maxlevel=10)
        if conv == false
            throw(MyException("No convergence", (circles, varphi1, varphi2)))
        end
        varphi1
    end
    
    ps, time2, allocated2, garbage2 = @timed begin
        bnbsolver(circles)
    end

    varphi3 = createtree(bss, vars, ps, circles)
    if id(varphi1) != id(varphi3)
        throw(MyException("Different trees", (circles, varphi1, varphi3)))
    end

    return time1, allocated1, garbage1, time2, allocated2, garbage2
end

rng = MersenneTwister(1234)

errcircles = []
errvarphi1 = []
errvarphi3 = []

allresult = DataFrame(n=Int[], r=Float64[], time1=Float64[], allocated1=Int[], garbage1=Float64[], time2=Float64[], allocated2=Int[], garbage2=Float64[])

for n = [5, 10, 20]
    for r = [0.5, 0.7, 0.9]
        println("Running experiment with n=$n and r=$r")
        try
            for _ = 1:100
                push!(allresult, (n, r, experiment1(n, r, rng)...))
            end
        catch e
            if isa(e, MyException)
                println(e.msg)
                global errcircles, errvarphi1, errvarphi3 = e.value
            else
                rethrow(e)
            end
        end
    end
end

# Save the results to a CSV file
CSV.write("./results/experiment1.csv", allresult)
println("Results saved to experiment1_results.csv")
