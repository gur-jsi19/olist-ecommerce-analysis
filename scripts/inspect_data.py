from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
REPORT_DIR = PROJECT_ROOT / "reports"
REPORT_DIR.mkdir(parents=True, exist_ok=True)

csv_files = sorted(RAW_DIR.glob("*.csv"))

if len(csv_files) != 9:
    raise ValueError(
        f"Expected 9 CSV files in {RAW_DIR}, found {len(csv_files)}."
    )

report = [
    "OLIST RAW DATA INSPECTION",
    "All columns loaded as text for initial inspection.",
    "Duplicate counts represent repeated complete rows.",
]

for csv_file in csv_files:
    print(f"Inspecting {csv_file.name}...")

    # Preserve identifiers and leading zeros.
    # Treat empty CSV fields as missing values.
    df = pd.read_csv(
        csv_file,
        dtype="string",
        keep_default_na=False,
        na_values=[""],
    )

    column_summary = pd.DataFrame({
        "missing_values": df.isna().sum(),
        "distinct_non_missing_values": df.nunique(dropna=True),
    })
    column_summary.index.name = "column"

    report.extend([
        "",
        f"FILE: {csv_file.name}",
        f"Rows: {len(df):,}",
        f"Columns: {len(df.columns)}",
        f"Duplicate rows beyond first occurrence: {df.duplicated().sum():,}",
        "",
        column_summary.to_string(),
    ])

report_path = REPORT_DIR / "data_profile.txt"
report_path.write_text("\n".join(report) + "\n", encoding="utf-8")

print(f"\nInspection complete. Report saved to: {report_path}")
