from decimal import Decimal
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
REPORTS = ROOT / "reports"

PROCESSED.mkdir(parents=True, exist_ok=True)
REPORTS.mkdir(parents=True, exist_ok=True)


def load(filename):
    df = pd.read_csv(
        RAW / filename,
        dtype="string",
        keep_default_na=False,
        na_values=[""],
    )
    for column in df.columns:
        df[column] = df[column].str.strip().replace("", pd.NA)
    return df


def convert_integer(df, column, minimum):
    values = pd.to_numeric(df[column], errors="raise")

    if values.isna().any():
        raise ValueError(f"Missing values in {column}.")

    if (values % 1 != 0).any() or (values < minimum).any():
        raise ValueError(f"Invalid integer values in {column}.")

    df[column] = values.astype("Int64")


def money_to_cents(series):
    def convert(value):
        if pd.isna(value):
            raise ValueError(f"Missing amount in {series.name}.")

        amount = Decimal(value)

        if not amount.is_finite() or amount < 0:
            raise ValueError(f"Invalid amount in {series.name}: {value}")

        cents = amount * 100

        if cents != cents.to_integral_value():
            raise ValueError(f"Fractional cent in {series.name}: {value}")

        return int(cents)

    return series.map(convert).astype("Int64")


def check_key(df, columns):
    if df[columns].isna().any().any():
        raise ValueError(f"Missing key component: {columns}")

    if df.duplicated(subset=columns).any():
        raise ValueError(f"Repeated key combination: {columns}")


items = load("olist_order_items_dataset.csv")
payments = load("olist_order_payments_dataset.csv")

item_rows = len(items)
payment_rows = len(payments)

convert_integer(items, "order_item_id", minimum=1)
convert_integer(payments, "payment_sequential", minimum=1)
convert_integer(payments, "payment_installments", minimum=0)

check_key(items, ["order_id", "order_item_id"])
check_key(payments, ["order_id", "payment_sequential"])

if items[["product_id", "seller_id"]].isna().any().any():
    raise ValueError("Missing product or seller ID.")

if payments["payment_type"].isna().any():
    raise ValueError("Missing payment type.")

items["shipping_limit_date"] = pd.to_datetime(
    items["shipping_limit_date"], errors="raise"
)

items["price_cents"] = money_to_cents(items["price"])
items["freight_value_cents"] = money_to_cents(items["freight_value"])
payments["payment_value_cents"] = money_to_cents(payments["payment_value"])

if (items["price_cents"] <= 0).any():
    raise ValueError("Unexpected zero or negative item price.")

# Preserve zero payments and installments, with explicit flags.
payments["flag_zero_payment"] = payments["payment_value_cents"].eq(0)
payments["flag_zero_installments"] = payments["payment_installments"].eq(0)

if len(items) != item_rows or len(payments) != payment_rows:
    raise ValueError("Unexpected change in transaction row counts.")

items.to_csv(
    PROCESSED / "items_clean.csv",
    index=False,
    date_format="%Y-%m-%d %H:%M:%S",
)
payments.to_csv(PROCESSED / "payments_clean.csv", index=False)

summary = [
    "TRANSACTION CLEANING SUMMARY",
    f"Item input rows: {item_rows:,}",
    f"Item output rows: {len(items):,}",
    f"Payment input rows: {payment_rows:,}",
    f"Payment output rows: {len(payments):,}",
    f"Distinct orders with items: {items['order_id'].nunique():,}",
    f"Distinct orders with payments: {payments['order_id'].nunique():,}",
    f"Zero freight records retained: {items['freight_value_cents'].eq(0).sum():,}",
    f"Zero payment records retained: {payments['flag_zero_payment'].sum():,}",
    f"Zero installment records retained: {payments['flag_zero_installments'].sum():,}",
    "",
    "Payment type counts:",
    payments["payment_type"].value_counts().to_string(),
]

(REPORTS / "transactions_cleaning_summary.txt").write_text(
    "\n".join(summary) + "\n",
    encoding="utf-8",
)

print("\n".join(summary))