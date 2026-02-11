from __future__ import annotations
import pandas as pd
from pathlib import Path

DATASETS = {
    "y-wise": {
        "Angle from center": "results_bdd_010_angles_from_center_y-wise.csv",
        "Origin distance":   "results_bdd_010_origin_y-wise.csv",
        "Center distance":   "results_bdd_010_center_y-wise.csv",
        "x-coordinate":      "results_bdd_010_xcoordinate_y-wise.csv",
        "y-coordinate":      "results_bdd_010_ycoordinate_y-wise.csv",
    },
    "x-wise": {
        "Angle from center": "results_bdd_010_angles_from_center_x-wise.csv",
        "Origin distance":   "results_bdd_010_origin_x-wise.csv",
        "Center distance":   "results_bdd_010_center_x-wise.csv",
        "x-coordinate":      "results_bdd_010_xcoordinate_x-wise.csv",
        "y-coordinate":      "results_bdd_010_ycoordinate_x-wise.csv",
    },
}

COL_CONV  = "convergence"
COL_FINAL = "nodes_phi1"
COL_PEAK  = "peak_nodes"
COL_MEM   = "memory_mb"
COL_TIME  = "solve_time_sec"


def summarize(csv_path: Path) -> dict[str, float]:
    df = pd.read_csv(csv_path)
    df = df[df[COL_CONV] == True]

    return {
        "Final nodes": df[COL_FINAL].mean(),
        "Peak nodes":  df[COL_PEAK].mean(),
        "Memory (MB)": df[COL_MEM].mean(),
        "Time (sec)":  df[COL_TIME].mean(),
    }


def make_table(files: dict[str, str]) -> pd.DataFrame:
    rows = []
    for ordering, fname in files.items():
        rows.append({
            "Variable ordering": ordering,
            **summarize(Path(fname))
        })
    return pd.DataFrame(rows)


def sci(x: float) -> str:
    m, e = f"{x:.2e}".split("e")
    return f"${m}\\times 10^{{{int(e)}}}$"


def write_latex_table(df: pd.DataFrame, outfile: Path, caption: str, label: str):
    with open(outfile, "w") as f:
        f.write("\\begin{table}[t]\n\\centering\n")
        f.write(f"\\caption{{{caption}}}\n")
        f.write(f"\\label{{{label}}}\n")
        f.write("\\begin{tabular}{lrrrr}\n")
        f.write("\\toprule\n")
        f.write("Variable ordering & Final nodes & Peak nodes & Memory (MB) & Time (sec) \\\\\n")
        f.write("\\midrule\n")

        for _, r in df.iterrows():
            f.write(
                f"{r['Variable ordering']} & "
                f"{int(round(r['Final nodes'])):,} & "
                f"{sci(r['Peak nodes'])} & "
                f"{r['Memory (MB)']:.1f} & "
                f"{r['Time (sec)']:.2f} \\\\\n"
            )

        f.write("\\bottomrule\n")
        f.write("\\end{tabular}\n\\end{table}\n")


def main():
    for traversal, files in DATASETS.items():
        df = make_table(files)

        print(f"\n=== {traversal} ===")
        print(df.to_string(index=False, float_format=lambda x: f'{x:,.4f}'))

        caption = (
            "Average performance on \\texttt{data010} (50 instances) with "
            f"{'row-wise (y-wise)' if traversal=='y-wise' else 'column-wise (x-wise)'} "
            "subregion traversal. Averages are computed over converged instances only."
        )
        label = f"tab:ordering_{traversal.replace('-', '')}"

        out = Path(f"table_ordering_{traversal}.tex")
        write_latex_table(df, out, caption, label)
        print(f"Wrote: {out}")


if __name__ == "__main__":
    main()