\x on

\echo 'SALES BASELINE — DELIVERED ORDERS, FULL AVAILABLE HISTORY'

SELECT
    COUNT(*) AS delivered_orders,
    COUNT(DISTINCT customer_unique_id) AS distinct_buyers,
    MIN(order_purchase_timestamp)::date AS first_purchase_date,
    MAX(order_purchase_timestamp)::date AS last_purchase_date,
    ROUND(
        SUM(merchandise_value_cents) / 100.0, 2
    ) AS merchandise_sales_brl,
    ROUND(
        SUM(freight_value_cents) / 100.0, 2
    ) AS freight_value_brl,
    ROUND(
        AVG(merchandise_value_cents) / 100.0, 2
    ) AS avg_merchandise_value_per_order_brl
FROM order_analytics
WHERE is_delivered;


\echo 'DELIVERY BASELINE — ELIGIBLE DELIVERED ORDERS'

SELECT
    COUNT(*) AS eligible_orders,
    COUNT(*) FILTER (
        WHERE late_delivery
    ) AS late_orders,
    COUNT(*) FILTER (
        WHERE NOT late_delivery
    ) AS on_time_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE late_delivery)
        / NULLIF(COUNT(*), 0), 2
    ) AS late_delivery_pct,
    ROUND(
        AVG(purchase_to_delivery_days), 2
    ) AS avg_purchase_to_delivery_days,
    ROUND(
        AVG(days_late) FILTER (WHERE late_delivery), 2
    ) AS avg_days_late_among_late_orders
FROM order_analytics
WHERE is_delivery_analysis_eligible;


\echo 'REVIEW BASELINE — DELIVERED ORDERS'

SELECT
    COUNT(*) AS delivered_orders,
    COUNT(*) FILTER (
        WHERE has_review
    ) AS reviewed_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_review)
        / NULLIF(COUNT(*), 0), 2
    ) AS review_coverage_pct,
    ROUND(
        AVG(mean_review_score), 2
    ) AS avg_order_review_score,
    COUNT(*) FILTER (
        WHERE has_low_review
    ) AS orders_with_any_low_review,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_low_review)
        / NULLIF(COUNT(*) FILTER (WHERE has_review), 0), 2
    ) AS orders_with_any_low_review_pct
FROM order_analytics
WHERE is_delivered;

\x off