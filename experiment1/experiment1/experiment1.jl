include("bdd_solver.jl")
include("branch_and_bound.jl")

using .BDDSolver

function randcoordinate(rng, eps)
    x = rand(rng) * (1 - 2eps) + eps
    y = rand(rng) * (1 - 2eps) + eps
    return BDDSolver.Point(x, y)
end

function exec_bdd(n, radius, rng)
    targetarea = BDDSolver.Rectangle4([BDDSolver.Point(0.0, 0.0), BDDSolver.Point(1.0, 0.0), BDDSolver.Point(1.0, 1.0), BDDSolver.Point(0.0, 1.0)])
    circles = [BDDSolver.Circle(i, randcoordinate(rng, 0.1), radius) for i = 1:n]
    sort!(circles, by = x -> BDDSolver.dist(x.center, BDDSolver.Point(0,0)))

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
