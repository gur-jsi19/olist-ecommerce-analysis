BEGIN;

CREATE OR REPLACE VIEW buyer_purchase_summary AS
SELECT
    customer_unique_id,
    COUNT(*) AS delivered_order_count,
    COUNT(DISTINCT purchase_date) AS distinct_purchase_dates,
    MIN(purchase_date) AS first_observed_purchase,
    MAX(purchase_date) AS last_observed_purchase,
    SUM(merchandise_value_cents) AS merchandise_sales_cents

FROM order_analytics
WHERE is_delivered
GROUP BY customer_unique_id;


\x on

\echo 'OBSERVED BUYER PURCHASING — FULL AVAILABLE HISTORY'
\echo 'Only delivered orders are included.'

SELECT
    COUNT(*) AS distinct_buyers,

    COUNT(*) FILTER (
        WHERE delivered_order_count >= 2
    ) AS buyers_with_multiple_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivered_order_count >= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS multiple_order_buyer_pct,

    COUNT(*) FILTER (
        WHERE distinct_purchase_dates >= 2
    ) AS buyers_purchasing_on_multiple_dates,

    SUM(delivered_order_count) FILTER (
        WHERE delivered_order_count >= 2
    ) AS orders_from_multiple_order_buyers,

    ROUND(
        100.0 * SUM(merchandise_sales_cents) FILTER (
            WHERE delivered_order_count >= 2
        ) / NULLIF(SUM(merchandise_sales_cents), 0),
        2
    ) AS sales_share_from_multiple_order_buyers_pct,

    MAX(delivered_order_count) AS max_orders_per_buyer

FROM buyer_purchase_summary;

\x off

COMMIT;