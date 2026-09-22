#!/usr/bin/env python3
"""Exact (Clopper-Pearson) 95% binomial intervals for the Monte Carlo failure counts.

Usage: python3 clopper_pearson.py N k [k ...]
Pure Python (regularized incomplete beta by continued fraction + bisection), no SciPy needed.
"""
import sys
from math import lgamma, exp, log

def _betacf(a, b, x, maxit=500, eps=3e-16, fpmin=1e-300):
    qab, qap, qam = a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / (d if abs(d) > fpmin else fpmin); h = d
    for m in range(1, maxit + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d; d = 1 / (d if abs(d) > fpmin else fpmin)
        c = 1 + aa / c; c = c if abs(c) > fpmin else fpmin
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d; d = 1 / (d if abs(d) > fpmin else fpmin)
        c = 1 + aa / c; c = c if abs(c) > fpmin else fpmin
        de = d * c; h *= de
        if abs(de - 1) < eps:
            break
    return h

def betainc(a, b, x):
    if x <= 0: return 0.0
    if x >= 1: return 1.0
    bt = exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log(1 - x))
    if x < (a + 1) / (a + b + 2):
        return bt * _betacf(a, b, x) / a
    return 1 - bt * _betacf(b, a, 1 - x) / b

def qbeta(p, a, b):
    lo, hi = 0.0, 1.0
    for _ in range(200):
        mid = (lo + hi) / 2
        if betainc(a, b, mid) < p: lo = mid
        else: hi = mid
    return (lo + hi) / 2

def clopper_pearson(k, n, alpha=0.05):
    lo = qbeta(alpha / 2, k, n - k + 1) if k > 0 else 0.0
    hi = qbeta(1 - alpha / 2, k + 1, n - k) if k < n else 1.0
    return lo, hi

if __name__ == "__main__":
    n = int(sys.argv[1])
    for k in map(int, sys.argv[2:]):
        lo, hi = clopper_pearson(k, n)
        print(f"N={n} k={k}: q_hat={k/n:.4e}  95% CP = [{lo:.4e}, {hi:.4e}]")
