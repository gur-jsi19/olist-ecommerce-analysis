from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data" / "raw" / "olist_orders_dataset.csv"
OUTPUT_DIR = ROOT / "data" / "processed"
REPORT_DIR = ROOT / "reports"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)

orders = pd.read_csv(
    INPUT,
    dtype="string",
    keep_default_na=False,
    na_values=[""],
)
original_rows = len(orders)

# Normalize identifiers and status labels.
for column in ["order_id", "customer_id", "order_status"]:
    orders[column] = orders[column].str.strip().replace("", pd.NA)

if orders[["order_id", "customer_id", "order_status"]].isna().any().any():
    raise ValueError("Missing required order identifiers or status.")

if orders["order_id"].duplicated().any():
    raise ValueError("Order IDs are no longer unique after normalization.")

date_columns = [
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
]

for column in date_columns:
    orders[column] = pd.to_datetime(orders[column], errors="raise")

if orders["order_purchase_timestamp"].isna().any():
    raise ValueError("Missing purchase timestamps.")


def flag_after(first, second):
    return (
        orders[first].notna()
        & orders[second].notna()
        & (orders[first] > orders[second])
    )


orders["flag_approval_after_carrier"] = flag_after(
    "order_approved_at", "order_delivered_carrier_date"
)
orders["flag_carrier_after_delivery"] = flag_after(
    "order_delivered_carrier_date", "order_delivered_customer_date"
)
orders["flag_delivery_before_purchase"] = flag_after(
    "order_purchase_timestamp", "order_delivered_customer_date"
)

purchase = orders["order_purchase_timestamp"]
actual = orders["order_delivered_customer_date"]
estimated = orders["order_estimated_delivery_date"]

orders["purchase_date"] = purchase.dt.strftime("%Y-%m-%d")
orders["purchase_month"] = purchase.dt.strftime("%Y-%m")
orders["purchase_year"] = purchase.dt.year
orders["is_delivered"] = orders["order_status"].eq("delivered")

eligible = (
    orders["is_delivered"]
    & actual.notna()
    & estimated.notna()
    & ~orders["flag_delivery_before_purchase"]
)
orders["is_delivery_analysis_eligible"] = eligible

# Elapsed time from purchase to delivery.
orders["purchase_to_delivery_days"] = (
    (actual - purchase).dt.total_seconds() / 86400
).where(eligible)

# Compare calendar dates: estimated timestamps are date-based deadlines.
calendar_difference = (
    actual.dt.normalize() - estimated.dt.normalize()
).dt.days

orders["days_late"] = (
    calendar_difference.clip(lower=0).where(eligible).astype("Int64")
)
orders["late_delivery"] = (
    (calendar_difference > 0).where(eligible, pd.NA).astype("boolean")
)

if len(orders) != original_rows:
    raise ValueError("Unexpected change in order row count.")

output = OUTPUT_DIR / "orders_clean.csv"
orders.to_csv(output, index=False, date_format="%Y-%m-%d %H:%M:%S")

summary = [
    "ORDERS CLEANING SUMMARY",
    f"Input rows: {original_rows:,}",
    f"Output rows: {len(orders):,}",
    f"Delivered orders: {orders['is_delivered'].sum():,}",
    f"Eligible for delivery analysis: {eligible.sum():,}",
    (
        "Delivered orders excluded from delivery analysis: "
        f"{(orders['is_delivered'] & ~eligible).sum():,}"
    ),
    f"Late orders among eligible orders: {orders['late_delivery'].sum():,}",
    "",
    "TIMELINE FLAGS — RECORDS RETAINED",
]

for column in [
    "flag_approval_after_carrier",
    "flag_carrier_after_delivery",
    "flag_delivery_before_purchase",
]:
    summary.append(f"{column}: {orders[column].sum():,}")

summary.extend([
    "",
    "Delivered-order purchase date range:",
    f"First: {purchase[orders['is_delivered']].min()}",
    f"Last: {purchase[orders['is_delivered']].max()}",
])

report = REPORT_DIR / "orders_cleaning_summary.txt"
report.write_text("\n".join(summary) + "\n", encoding="utf-8")

print("\n".join(summary))
print(f"\nCleaned orders saved to: {output}")