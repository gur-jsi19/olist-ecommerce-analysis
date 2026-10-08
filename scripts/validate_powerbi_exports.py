from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXPORT_DIR = PROJECT_ROOT / "data" / "powerbi"
REPORT_PATH = PROJECT_ROOT / "reports" / "powerbi_export_validation.txt"

FILE_SPECS = {
    "powerbi_orders.csv": (99441, ["order_id"]),
    "powerbi_order_items.csv": (
        112650, ["order_id", "order_item_id"]
    ),
    "powerbi_dates.csv": (1096, ["date"]),
    "powerbi_states.csv": (27, ["customer_state"]),
    "powerbi_products.csv": (32951, ["product_id"]),
}

tables = {}
passed_checks = []
file_summaries = []


def check(condition, description):
    if not condition:
        raise ValueError(f"Validation failed: {description}")
    passed_checks.append(description)


for filename, (expected_rows, key_columns) in FILE_SPECS.items():
    df = pd.read_csv(
        EXPORT_DIR / filename,
        dtype="string",
        keep_default_na=False,
        na_values=[""],
        encoding="utf-8",
    )

    tables[filename] = df

    check(
        len(df) == expected_rows,
        f"{filename}: expected row count",
    )
    check(
        not df[key_columns].isna().any().any(),
        f"{filename}: no missing key components",
    )
    check(
        not df.duplicated(subset=key_columns).any(),
        f"{filename}: unique key",
    )

    file_summaries.append(f"{filename}: {len(df):,} rows")


orders = tables["powerbi_orders.csv"]
items = tables["powerbi_order_items.csv"]
dates = tables["powerbi_dates.csv"]
states = tables["powerbi_states.csv"]
products = tables["powerbi_products.csv"]

relationships = [
    (orders, "purchase_date", dates, "date"),
    (items, "purchase_date", dates, "date"),
    (orders, "customer_state", states, "customer_state"),
    (items, "customer_state", states, "customer_state"),
    (items, "product_id", products, "product_id"),
    (items, "order_id", orders, "order_id"),
]

for source, source_column, target, target_column in relationships:
    check(
        source[source_column].isin(target[target_column]).all(),
        f"Relationship: {source_column} -> {target_column}",
    )


calendar = pd.to_datetime(
    dates["date"], format="%Y-%m-%d", errors="raise"
).sort_values()

check(
    calendar.diff().dropna().eq(pd.Timedelta(days=1)).all(),
    "Calendar dates are continuous",
)


delivered = orders["is_delivered"].eq("1")
eligible = orders["is_delivery_analysis_eligible"].eq("1")
late = eligible & orders["late_delivery"].eq("1")
delivered_items = items["is_delivered"].eq("1")

order_sales = pd.to_numeric(
    orders.loc[delivered, "merchandise_value_cents"],
    errors="raise",
).astype("Int64")

item_sales = pd.to_numeric(
    items.loc[delivered_items, "price_cents"],
    errors="raise",
).astype("Int64")

check(
    order_sales.notna().all() and item_sales.notna().all(),
    "Delivered merchandise values are present",
)

order_sales_cents = int(order_sales.sum())
item_sales_cents = int(item_sales.sum())

check(int(delivered.sum()) == 96478, "Delivered orders: 96,478")
check(int(eligible.sum()) == 96470, "Eligible orders: 96,470")
check(int(late.sum()) == 6534, "Late orders: 6,534")

check(
    order_sales_cents == 1322149811,
    "Delivered merchandise sales match the SQL baseline",
)
check(
    order_sales_cents == item_sales_cents,
    "Order and item files have matching delivered sales",
)


summary = "\n".join([
    "POWER BI EXPORT VALIDATION",
    *file_summaries,
    "",
    f"Passed checks: {len(passed_checks)}",
    f"Delivered orders: {int(delivered.sum()):,}",
    f"Eligible delivery orders: {int(eligible.sum()):,}",
    f"Late orders: {int(late.sum()):,}",
    f"Delivered merchandise sales: BRL {order_sales_cents / 100:,.2f}",
    "RESULT: ALL CHECKS PASSED",
])

REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
REPORT_PATH.write_text(
    summary
    + "\n\nCHECK DETAILS\n"
    + "\n".join(f"PASS: {name}" for name in passed_checks)
    + "\n",
    encoding="utf-8",
)

print(summary)
print(f"\nReport saved: {REPORT_PATH.relative_to(PROJECT_ROOT)}")