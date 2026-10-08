from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"


def load(filename):
    return pd.read_csv(
        RAW / filename,
        dtype="string",
        keep_default_na=False,
        na_values=[""],
    )


orders = load("olist_orders_dataset.csv")
items = load("olist_order_items_dataset.csv")
payments = load("olist_order_payments_dataset.csv")
reviews = load("olist_order_reviews_dataset.csv")

report = [
    "OLIST DATA QUALITY CHECKS",
    "",
    "ORDER STATUS COUNTS",
    orders["order_status"].value_counts().to_string(),
    "",
    "DATE PARSING",
]

date_columns = [
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
]

dates = pd.DataFrame(index=orders.index)

for column in date_columns:
    dates[column] = pd.to_datetime(orders[column], errors="coerce")
    invalid = orders[column].notna() & dates[column].isna()
    report.append(f"{column}: {invalid.sum():,} invalid non-missing values")

report.extend([
    "",
    "PURCHASE DATE RANGE",
    f"First: {dates['order_purchase_timestamp'].min()}",
    f"Last: {dates['order_purchase_timestamp'].max()}",
    "",
    "MISSING OR INVALID DATES BY ORDER STATUS",
    dates.isna().groupby(orders["order_status"]).sum().to_string(),
])

coverage = pd.DataFrame({
    "orders": 1,
    "without_items": ~orders["order_id"].isin(items["order_id"]),
    "without_payments": ~orders["order_id"].isin(payments["order_id"]),
    "without_reviews": ~orders["order_id"].isin(reviews["order_id"]),
}, index=orders.index)

report.extend([
    "",
    "RELATED RECORD COVERAGE BY ORDER STATUS",
    coverage.groupby(orders["order_status"]).sum().to_string(),
    "",
    "TIMELINE FLAGS",
])

timeline_checks = [
    ("purchase_after_approval",
     "order_purchase_timestamp", "order_approved_at"),
    ("approval_after_carrier_handoff",
     "order_approved_at", "order_delivered_carrier_date"),
    ("carrier_handoff_after_customer_delivery",
     "order_delivered_carrier_date", "order_delivered_customer_date"),
    ("purchase_after_estimated_delivery",
     "order_purchase_timestamp", "order_estimated_delivery_date"),
]

for label, earlier, later in timeline_checks:
    eligible = dates[earlier].notna() & dates[later].notna()
    flagged = eligible & (dates[earlier] > dates[later])
    report.append(f"{label}: {flagged.sum():,}")

report.extend(["", "NUMERIC VALUE CHECKS"])

numeric_checks = [
    ("items", items, "price"),
    ("items", items, "freight_value"),
    ("payments", payments, "payment_value"),
    ("payments", payments, "payment_installments"),
    ("reviews", reviews, "review_score"),
]

for name, df, column in numeric_checks:
    values = pd.to_numeric(df[column], errors="coerce")
    invalid = df[column].notna() & values.isna()

    report.extend([
        f"{name}.{column}",
        f"  Missing source values: {df[column].isna().sum():,}",
        f"  Invalid non-missing numbers: {invalid.sum():,}",
        f"  Minimum: {values.min()}",
        f"  Maximum: {values.max()}",
        f"  Negative values: {(values < 0).sum():,}",
        f"  Zero values: {(values == 0).sum():,}",
    ])

scores = pd.to_numeric(reviews["review_score"], errors="coerce")
invalid_scores = scores.notna() & ~scores.isin([1, 2, 3, 4, 5])
report.append(f"\nReview scores outside 1–5: {invalid_scores.sum():,}")

output = ROOT / "reports" / "data_quality_checks.txt"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("\n".join(report) + "\n", encoding="utf-8")

print(f"Checks complete. Report saved to: {output}")