from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data" / "raw" / "olist_order_reviews_dataset.csv"
PROCESSED = ROOT / "data" / "processed"
REPORTS = ROOT / "reports"

PROCESSED.mkdir(parents=True, exist_ok=True)
REPORTS.mkdir(parents=True, exist_ok=True)

reviews = pd.read_csv(
    INPUT,
    dtype="string",
    keep_default_na=False,
    na_values=[""],
)
original_rows = len(reviews)

for column in [
    "review_id",
    "order_id",
    "review_comment_title",
    "review_comment_message",
]:
    reviews[column] = reviews[column].str.strip().replace("", pd.NA)

key = ["review_id", "order_id"]

if reviews[key].isna().any().any():
    raise ValueError("Missing review or order ID.")

if reviews.duplicated(subset=key).any():
    raise ValueError("Repeated review/order key combination.")

scores = pd.to_numeric(reviews["review_score"], errors="raise")

if not scores.isin([1, 2, 3, 4, 5]).all():
    raise ValueError("Missing or invalid review score.")

reviews["review_score"] = scores.astype("Int64")

for column in ["review_creation_date", "review_answer_timestamp"]:
    reviews[column] = pd.to_datetime(reviews[column], errors="raise")

reviews["has_written_feedback"] = (
    reviews["review_comment_title"].notna()
    | reviews["review_comment_message"].notna()
)

order_reviews = (
    reviews.groupby("order_id", as_index=False)
    .agg(
        review_count=("review_id", "size"),
        mean_review_score=("review_score", "mean"),
        min_review_score=("review_score", "min"),
        max_review_score=("review_score", "max"),
    )
)

order_reviews["has_low_review"] = order_reviews["min_review_score"].le(2)
order_reviews["has_conflicting_scores"] = (
    order_reviews["min_review_score"]
    != order_reviews["max_review_score"]
)

if len(reviews) != original_rows:
    raise ValueError("Unexpected change in review row count.")

if order_reviews["order_id"].duplicated().any():
    raise ValueError("Order review summary is not unique by order.")

if order_reviews["review_count"].sum() != original_rows:
    raise ValueError("Review counts do not reconcile.")

reviews.to_csv(
    PROCESSED / "reviews_clean.csv",
    index=False,
    date_format="%Y-%m-%d %H:%M:%S",
)
order_reviews.to_csv(
    PROCESSED / "order_reviews_summary.csv",
    index=False,
)

summary = [
    "REVIEW CLEANING SUMMARY",
    f"Input review rows: {original_rows:,}",
    f"Output review rows: {len(reviews):,}",
    f"Reviewed orders: {len(order_reviews):,}",
    f"Orders with multiple reviews: {order_reviews['review_count'].gt(1).sum():,}",
    f"Orders with differing review scores: {order_reviews['has_conflicting_scores'].sum():,}",
    f"Orders with any score of 1 or 2: {order_reviews['has_low_review'].sum():,}",
    f"Reviews with written feedback: {reviews['has_written_feedback'].sum():,}",
    "",
    "All reviews retained. Summary contains one row per reviewed order.",
]

(REPORTS / "reviews_cleaning_summary.txt").write_text(
    "\n".join(summary) + "\n",
    encoding="utf-8",
)

print("\n".join(summary))