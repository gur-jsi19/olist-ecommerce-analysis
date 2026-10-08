from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

files = {
    "orders": "olist_orders_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "items": "olist_order_items_dataset.csv",
    "payments": "olist_order_payments_dataset.csv",
    "reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "translations": "product_category_name_translation.csv",
}

tables = {
    name: pd.read_csv(
        RAW / filename,
        dtype="string",
        keep_default_na=False,
        na_values=[""],
    )
    for name, filename in files.items()
}

report = ["OLIST KEY AND RELATIONSHIP CHECKS", "", "PROPOSED KEYS"]

keys = {
    "orders": ["order_id"],
    "customers": ["customer_id"],
    "products": ["product_id"],
    "sellers": ["seller_id"],
    "items": ["order_id", "order_item_id"],
    "payments": ["order_id", "payment_sequential"],
    "reviews": ["review_id", "order_id"],
    "translations": ["product_category_name"],
}

for name, columns in keys.items():
    df = tables[name]
    missing = df[columns].isna().any(axis=1).sum()
    duplicates = df.duplicated(subset=columns).sum()

    report.extend([
        f"{name}: {', '.join(columns)}",
        f"  Rows with a missing key component: {missing:,}",
        f"  Repeated key combinations beyond first: {duplicates:,}",
    ])

report.extend(["", "RELATIONSHIP CHECKS"])

relationships = [
    ("orders", "customer_id", "customers", "customer_id"),
    ("items", "order_id", "orders", "order_id"),
    ("items", "product_id", "products", "product_id"),
    ("items", "seller_id", "sellers", "seller_id"),
    ("payments", "order_id", "orders", "order_id"),
    ("reviews", "order_id", "orders", "order_id"),
    (
        "products", "product_category_name",
        "translations", "product_category_name",
    ),
]

for child, child_col, parent, parent_col in relationships:
    values = tables[child][child_col]
    parent_values = tables[parent][parent_col]

    unmatched = values.notna() & ~values.isin(parent_values)

    report.extend([
        f"{child}.{child_col} -> {parent}.{parent_col}",
        f"  Missing source values: {values.isna().sum():,}",
        f"  Rows with a non-missing but unmatched value: {unmatched.sum():,}",
        f"  Distinct unmatched values: {values[unmatched].nunique():,}",
    ])

    if unmatched.any():
        examples = values[unmatched].drop_duplicates().head(5).tolist()
        report.append(f"  Example unmatched values: {examples}")

report.extend(["", "MULTIPLE RECORDS PER ORDER"])

for name in ["items", "payments", "reviews"]:
    counts = tables[name]["order_id"].value_counts()

    report.extend([
        f"{name}:",
        f"  Orders with more than one record: {(counts > 1).sum():,}",
        f"  Maximum records for one order: {counts.max()}",
    ])

output = ROOT / "reports" / "relationship_checks.txt"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("\n".join(report) + "\n", encoding="utf-8")

print(f"Checks complete. Report saved to: {output}")