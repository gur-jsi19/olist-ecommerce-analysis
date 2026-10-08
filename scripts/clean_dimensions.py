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


def check_key(df, column):
    if df[column].isna().any() or df[column].duplicated().any():
        raise ValueError(f"Missing or repeated key: {column}")


customers = load("olist_customers_dataset.csv")
sellers = load("olist_sellers_dataset.csv")

check_key(customers, "customer_id")
check_key(sellers, "seller_id")

if customers["customer_unique_id"].isna().any():
    raise ValueError("Missing customer_unique_id.")

for df, prefix in [(customers, "customer"), (sellers, "seller")]:
    zip_column = f"{prefix}_zip_code_prefix"
    city_column = f"{prefix}_city"
    state_column = f"{prefix}_state"

    df[zip_column] = df[zip_column].str.zfill(5)
    df[city_column] = df[city_column].str.lower()
    df[state_column] = df[state_column].str.upper()

    valid_zip = df[zip_column].str.fullmatch(r"[0-9]{5}").fillna(False)
    valid_state = df[state_column].str.fullmatch(r"[A-Z]{2}").fillna(False)

    if not valid_zip.all() or not valid_state.all():
        raise ValueError(f"Invalid ZIP prefix or state format in {prefix} data.")

# Keep the product fields needed for our category analysis.
products = load("olist_products_dataset.csv")[
    ["product_id", "product_category_name"]
].copy()
translations = load("product_category_name_translation.csv")

check_key(products, "product_id")
check_key(translations, "product_category_name")

original_product_rows = len(products)

products = products.merge(
    translations,
    on="product_category_name",
    how="left",
    validate="many_to_one",
)

if len(products) != original_product_rows:
    raise ValueError("Product row count changed during translation merge.")

products["category_missing"] = products["product_category_name"].isna()
products["category_translation_missing"] = (
    products["product_category_name"].notna()
    & products["product_category_name_english"].isna()
)

# Use English where available, the original category otherwise.
products["product_category_label"] = (
    products["product_category_name_english"]
    .combine_first(products["product_category_name"])
    .fillna("Unknown category")
)

outputs = {
    "customers_clean.csv": customers,
    "sellers_clean.csv": sellers,
    "products_clean.csv": products,
}

summary = ["DIMENSION CLEANING SUMMARY"]

for filename, df in outputs.items():
    df.to_csv(PROCESSED / filename, index=False)
    summary.append(f"{filename}: {len(df):,} rows")

summary.extend([
    f"Distinct individual customers: {customers['customer_unique_id'].nunique():,}",
    f"Products with missing source category: {products['category_missing'].sum():,}",
    (
        "Products with a category but no English translation: "
        f"{products['category_translation_missing'].sum():,}"
    ),
    "",
    "Untranslated categories:",
    products.loc[
        products["category_translation_missing"], "product_category_name"
    ].drop_duplicates().to_string(index=False),
])

(REPORTS / "dimensions_cleaning_summary.txt").write_text(
    "\n".join(summary) + "\n",
    encoding="utf-8",
)

print("\n".join(summary))