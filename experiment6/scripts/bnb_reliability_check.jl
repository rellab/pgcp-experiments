#!/usr/bin/env julia
#
# Reliability cross-check between the branch-and-bound baseline and the BDD
# framework on the equal-radius instances of experiment1.
#
# experiment1/results_bnb_*.csv record only the number of covering path
# vectors and the running time. This script recomputes the path vectors with
# BranchAndBoundSolver.bnbsolver, builds the up-closure
#     OR over path vectors s of AND over k in s of x_k
# as a BDD, evaluates its probability at the instance's p_k, and compares it
# with reliability_lb stored by the BDD solver in experiment1. Instances on
# which the BnB solver throws are recorded with the exception text instead of
# being skipped.
#
# Usage (from pgcp-experiments/):
#   julia experiment6/scripts/bnb_reliability_check.jl <out.csv> <bdd_results.csv> <prefix> <from> <to>

using Printf
using CSV
using DataFrames
using MiniCUDD

include(joinpath(@__DIR__, "..", "..", "scripts", "branch_and_bound.jl"))
using .BranchAndBoundSolver

function prob(M::MiniCUDD.Manager, node::MiniCUDD.BDDNode, p::Float64)
    memo = Dict{UInt,Float64}()
    function go(n)
        MiniCUDD.isconstant(n) && return n.ptr == MiniCUDD.const1(M).ptr ? 1.0 : 0.0
        key = UInt(n.ptr)
        haskey(memo, key) && return memo[key]
        v = p * go(MiniCUDD.bdd_then(M, n)) + (1 - p) * go(MiniCUDD.bdd_else(M, n))
        memo[key] = v
        return v
    end
    return go(node)
end

function main(argv)
    out, bddcsv, prefix = argv[1], argv[2], argv[3]
    from, to = parse(Int, argv[4]), parse(Int, argv[5])
    bdd = Dict(String(r.datafile) => Float64(r.reliability_lb) for r in eachrow(CSV.read(bddcsv, DataFrame)))
    open(out, "w") do io
        println(io, "datafile,n,n_paths,R_bnb,R_bdd,abs_diff,bnb_time_sec,status")
        for i in from:to
            f = @sprintf("%s-%03d.json", prefix, i)
            isfile(f) || continue
            circles, _, _, p = BranchAndBoundSolver.load_config_from_json(f)
            n = length(circles)
            Rb = get(bdd, f, NaN)
            try
                t = @elapsed ps = BranchAndBoundSolver.bnbsolver(circles)
                M = MiniCUDD.Manager(nvars = max(1, n))
                acc = MiniCUDD.const0(M)
                for s in ps
                    term = MiniCUDD.const1(M)
                    for (k, x) in enumerate(s)
                        x == 1 && (term = MiniCUDD.bdd_and(M, term, MiniCUDD.var(M, k - 1)))
                    end
                    acc = MiniCUDD.bdd_or(M, acc, term)
                end
                R = prob(M, acc, p)
                @printf(io, "%s,%d,%d,%.17g,%.17g,%.3e,%.6f,ok\n", f, n, length(ps), R, Rb, abs(R - Rb), t)
                @info @sprintf("%s: paths=%d R_bnb=%.15f R_bdd=%.15f diff=%.2e t=%.2fs", f, length(ps), R, Rb, abs(R - Rb), t)
            catch e
                msg = replace(sprint(showerror, e), r"[,\n\r]" => " ")
                msg = length(msg) > 200 ? msg[1:200] : msg
                @printf(io, "%s,%d,,,%.17g,,,error: %s\n", f, n, Rb, msg)
                @warn "$f failed: $msg"
            end
            flush(io)
        end
    end
end

main(ARGS)
