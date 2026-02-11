#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Make paper-friendly boxplots of solve time (log scale):
  - Methods: BDD vs Branch-and-Bound
  - PDS: 0.2, 0.3, 0.4
Inputs (in current directory by default):
  results_bdd_020.csv, results_bdd_030.csv, results_bdd_040.csv
  results_bnb_020.csv, results_bnb_030.csv, results_bnb_040.csv
Outputs:
  boxplot_solve_time_log.pdf
  boxplot_solve_time_log.png
"""

from __future__ import annotations

import argparse
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt


def load_one_csv(path: Path, method: str, pds: float) -> pd.DataFrame:
    df = pd.read_csv(path)

    # BDD: use only converged instances if available
    if method == "BDD" and "convergence" in df.columns:
        conv = df["convergence"].astype(str).str.lower()
        df = df[conv.isin(["true", "1", "t", "yes", "y"])]

    if "solve_time_sec" not in df.columns:
        raise ValueError(f"'solve_time_sec' not found in {path}")

    out = pd.DataFrame(
        {
            "method": method,
            "pds": pds,
            "solve_time_sec": pd.to_numeric(df["solve_time_sec"], errors="coerce"),
        }
    ).dropna(subset=["solve_time_sec"])

    return out


def build_dataset(indir: Path) -> pd.DataFrame:
    files = {
        ("BDD", 0.2): indir / "results_bdd_020.csv",
        ("BDD", 0.3): indir / "results_bdd_030.csv",
        ("BDD", 0.4): indir / "results_bdd_040.csv",
        ("BnB", 0.2): indir / "results_bnb_020.csv",
        ("BnB", 0.3): indir / "results_bnb_030.csv",
        ("BnB", 0.4): indir / "results_bnb_040.csv",
    }

    parts = []
    for (method, pds), path in files.items():
        if not path.exists():
            raise FileNotFoundError(f"Missing file: {path}")
        parts.append(load_one_csv(path, method, pds))

    data = pd.concat(parts, ignore_index=True)
    return data


def draw_boxplot_log(
    data: pd.DataFrame,
    out_pdf: Path,
    out_png: Path,
    pds_order=(0.4, 0.3, 0.2),
    methods=("BDD", "BnB"),
    width=0.28,
    dodge=0.18,
    show_fliers=False,
):
    # Paper-ish defaults (keep conservative to avoid font issues in Docker)
    plt.rcParams.update(
        {
            "font.size": 10,
            "axes.labelsize": 11,
            "axes.titlesize": 11,
            "legend.fontsize": 10,
            "xtick.labelsize": 10,
            "ytick.labelsize": 10,
            "axes.linewidth": 0.8,
        }
    )

    fig, ax = plt.subplots(figsize=(8.6, 4.2))

    base_pos = {p: i + 1 for i, p in enumerate(pds_order)}  # 1,2,3
    offsets = {"BDD": -dodge, "BnB": +dodge}

    # Greys for print-friendly figure
    face = {"BDD": (0.82, 0.82, 0.82), "BnB": (0.55, 0.55, 0.55)}

    boxdata = []
    positions = []
    colors = []

    for p in pds_order:
        for m in methods:
            vals = data.loc[(data["pds"] == p) & (data["method"] == m), "solve_time_sec"].values
            boxdata.append(vals)
            positions.append(base_pos[p] + offsets[m])
            colors.append(face[m])

    bp = ax.boxplot(
        boxdata,
        positions=positions,
        widths=width,
        patch_artist=True,
        showfliers=show_fliers,
        whis=1.5,
    )

    # Style: thin, clean
    for patch, c in zip(bp["boxes"], colors):
        patch.set_facecolor(c)
        patch.set_edgecolor("black")
        patch.set_linewidth(0.8)

    for key in ["whiskers", "caps", "medians"]:
        for line in bp[key]:
            line.set_color("black")
            line.set_linewidth(0.8 if key != "medians" else 1.0)

    ax.set_yscale("log")
    ax.grid(True, axis="y", linestyle="--", linewidth=0.5, alpha=0.5)

    ax.set_xlim(0.5, len(pds_order) + 0.5)
    ax.set_xticks([base_pos[p] for p in pds_order])
    # ax.set_xticklabels([f"PDS={p}" for p in pds_order])
    ax.set_xticklabels(['data040', 'data030', 'data020'])
    ax.set_xlabel("Instance type")
    ax.set_ylabel("Computation time (sec, log10 scale)")

    # Legend (proxy artists)
    from matplotlib.patches import Patch

    label_map = {"BDD": "Proposed", "BnB": "Feng's"}
    handles = [Patch(facecolor=face[m], edgecolor="black", label=label_map[m]) for m in methods]
    ax.legend(handles=handles, loc="upper left", frameon=True, framealpha=1.0, fancybox=False)

    fig.tight_layout()
    fig.savefig(out_pdf)
    fig.savefig(out_png, dpi=200)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--indir", type=str, default=".", help="Directory containing result CSVs")
    ap.add_argument("--out-prefix", type=str, default="boxplot_solve_time_log", help="Output prefix")
    ap.add_argument("--show-fliers", action="store_true", help="Show outliers (fliers)")
    args = ap.parse_args()

    indir = Path(args.indir)
    out_prefix = Path(args.out_prefix)

    data = build_dataset(indir)

    # Save (optional) merged dataset for debugging/repro
    # merged_csv = out_prefix.with_suffix(".merged.csv")
    # data.to_csv(merged_csv, index=False)

    draw_boxplot_log(
        data,
        out_pdf=out_prefix.with_suffix(".pdf"),
        out_png=out_prefix.with_suffix(".png"),
        show_fliers=args.show_fliers,
    )

    # Small summary to stdout (useful in Docker logs)
    summary = (
        data.groupby(["method", "pds"])["solve_time_sec"]
        .agg(n="size", median="median", mean="mean")
        .reset_index()
        .sort_values(["pds", "method"])
    )
    print(summary.to_string(index=False))
    print(f"Saved: {out_prefix.with_suffix('.pdf')} and {out_prefix.with_suffix('.png')}")
    # print(f"Merged data: {merged_csv}")


if __name__ == "__main__":
    main()