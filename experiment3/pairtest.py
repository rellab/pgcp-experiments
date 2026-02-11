from __future__ import annotations

import argparse
from pathlib import Path
import pandas as pd
from scipy.stats import wilcoxon


METRICS_DEFAULT = ["nodes_phi1", "peak_nodes", "memory_mb", "solve_time_sec"]


def load_and_pair(
    file_a: Path,
    file_b: Path,
    metric: str,
    require_converged: bool = True,
) -> tuple[pd.Series, pd.Series, int]:
    """Load two CSVs, filter converged, pair by datafile, and return paired series."""
    a = pd.read_csv(file_a)
    b = pd.read_csv(file_b)

    required_cols = {"datafile", "convergence", metric}
    for name, df in [("A", a), ("B", b)]:
        missing = required_cols - set(df.columns)
        if missing:
            raise KeyError(f"{name} is missing columns {sorted(missing)}. "
                           f"Available: {list(df.columns)}")

    if require_converged:
        a = a[a["convergence"] == True]
        b = b[b["convergence"] == True]

    a = a.set_index("datafile")
    b = b.set_index("datafile")

    common = a.index.intersection(b.index)
    if len(common) == 0:
        raise ValueError("No common 'datafile' values between the two files after filtering.")

    a_s = a.loc[common, metric].astype(float)
    b_s = b.loc[common, metric].astype(float)
    return a_s, b_s, len(common)


def wilcoxon_report(
    a_s: pd.Series,
    b_s: pd.Series,
    metric: str,
    alternative: str = "two-sided",
) -> dict[str, float]:
    """
    Run paired Wilcoxon signed-rank test.
    Returns statistic, pvalue, and basic effect summaries.
    """
    # Wilcoxon requires paired non-NaN and non-identical pairs; drop NaNs safely
    df = pd.DataFrame({"a": a_s, "b": b_s}).dropna()
    a = df["a"]
    b = df["b"]

    # If all differences are zero, wilcoxon will error; handle gracefully
    if (a - b).abs().sum() == 0:
        return {
            "n": float(len(df)),
            "stat": float("nan"),
            "p": 1.0,
            "mean_a": float(a.mean()),
            "mean_b": float(b.mean()),
            "median_diff": 0.0,
            "mean_diff": 0.0,
        }

    stat, p = wilcoxon(a, b, alternative=alternative)
    return {
        "n": float(len(df)),
        "stat": float(stat),
        "p": float(p),
        "mean_a": float(a.mean()),
        "mean_b": float(b.mean()),
        "median_diff": float((a - b).median()),
        "mean_diff": float((a - b).mean()),
    }


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Paired Wilcoxon tests for two BDD result CSVs (paired by datafile)."
    )
    ap.add_argument("file_a", type=Path, help="CSV file A")
    ap.add_argument("file_b", type=Path, help="CSV file B")
    ap.add_argument(
        "--metrics",
        nargs="*",
        default=METRICS_DEFAULT,
        help=f"Metrics to test (default: {', '.join(METRICS_DEFAULT)})",
    )
    ap.add_argument(
        "--include-nonconverged",
        action="store_true",
        help="Include non-converged rows (default: converged only).",
    )
    ap.add_argument(
        "--alternative",
        choices=["two-sided", "greater", "less"],
        default="two-sided",
        help="Wilcoxon alternative hypothesis (default: two-sided).",
    )
    args = ap.parse_args()

    require_converged = not args.include_nonconverged

    print(f"File A: {args.file_a}")
    print(f"File B: {args.file_b}")
    print(f"Converged-only: {require_converged}")
    print(f"Alternative: {args.alternative}\n")

    for metric in args.metrics:
        a_s, b_s, n = load_and_pair(args.file_a, args.file_b, metric, require_converged)
        rep = wilcoxon_report(a_s, b_s, metric, alternative=args.alternative)

        # Pretty print
        print(f"[{metric}]")
        print(f"  paired samples: {int(rep['n'])}")
        print(f"  mean(A): {rep['mean_a']:.6g}   mean(B): {rep['mean_b']:.6g}")
        print(f"  mean(A-B): {rep['mean_diff']:.6g}   median(A-B): {rep['median_diff']:.6g}")
        if rep["stat"] != rep["stat"]:  # NaN check
            print(f"  Wilcoxon: all differences are zero -> p=1.0")
        else:
            print(f"  Wilcoxon statistic: {rep['stat']:.6g}   p-value: {rep['p']:.6g}")
        print("")


if __name__ == "__main__":
    main()