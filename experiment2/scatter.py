#!/usr/bin/env python3

import glob
import pandas as pd
import matplotlib.pyplot as plt


def load_data(pattern="results_bdd_*.csv"):
    files = sorted(glob.glob(pattern))
    if not files:
        raise RuntimeError("No CSV files found.")
    df = pd.concat([pd.read_csv(f) for f in files], ignore_index=True)
    return df


def is_true(x):
    return str(x).strip().lower() in ["true", "1", "t", "yes"]


def plot_scatter(df, ycol, ylabel, outfile):
    conv = df["convergence"].apply(is_true)
    df_true = df[conv]
    df_false = df[~conv]

    fig, ax = plt.subplots(figsize=(6.5, 4.2))

    # convergence = true
    # 黒塗り丸（やや薄め）
    ax.scatter(
        df_true["circles"],
        df_true[ycol],
        marker="o",
        s=22,
        facecolors="black",
        edgecolors="none",
        alpha=0.6,
        zorder=2,
        label="convergence = true",
    )

    # convergence = false
    # 中抜き三角・太線・最前面
    if not df_false.empty:
        ax.scatter(
            df_false["circles"],
            df_false[ycol],
            marker="^",
            s=70,
            facecolors="none",
            edgecolors="black",
            linewidths=1.6,
            alpha=1.0,
            zorder=3,
            label="convergence = false",
        )

    ax.set_xlabel("Number of components")
    ax.set_ylabel(ylabel)
    ax.set_yscale("log")
    ax.grid(True, which="both", linestyle="--", linewidth=0.6, alpha=0.5)

    ax.legend(frameon=False)

    fig.tight_layout()
    fig.savefig(outfile)
    plt.close(fig)

    print(f"saved: {outfile}  (false={len(df_false)})")


def main():
    df = load_data()

    required = [
        "circles",
        "convergence",
        "solve_time_sec",
        "nodes_phi1",
        "peak_nodes",
        "memory_mb",
    ]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise RuntimeError(f"Missing columns: {missing}")

    plot_scatter(df, "solve_time_sec", "Solve time (sec)", "scalability_time.pdf")
    plot_scatter(df, "nodes_phi1", "Number of final BDD nodes", "scalability_phi1_nodes.pdf")
    plot_scatter(df, "peak_nodes", "Peak number of BDD nodes", "scalability_peak_nodes.pdf")
    plot_scatter(df, "memory_mb", "Memory usage (MB)", "scalability_memory.pdf")


if __name__ == "__main__":
    main()