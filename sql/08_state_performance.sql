BEGIN;

CREATE OR REPLACE VIEW customer_state_summary AS
SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    SUM(merchandise_value_cents) AS merchandise_sales_cents,

    COUNT(*) FILTER (
        WHERE is_delivery_analysis_eligible
    ) AS eligible_delivery_orders,

    COUNT(*) FILTER (
        WHERE is_delivery_analysis_eligible
          AND late_delivery
    ) AS late_orders,

    AVG(purchase_to_delivery_days) FILTER (
        WHERE is_delivery_analysis_eligible
    ) AS avg_delivery_days

FROM order_analytics
WHERE is_delivered
GROUP BY customer_state;


\echo 'TOP 10 CUSTOMER STATES BY SALES — FULL AVAILABLE HISTORY'

SELECT
    customer_state,
    delivered_orders,

    ROUND(
        merchandise_sales_cents / 100.0, 2
    ) AS merchandise_sales_brl,

    ROUND(
        100.0 * merchandise_sales_cents
        / NULLIF(SUM(merchandise_sales_cents) OVER (), 0),
        2
    ) AS sales_share_pct

FROM customer_state_summary
ORDER BY merchandise_sales_cents DESC, customer_state
LIMIT 10;


\echo 'HIGHEST LATE-DELIVERY RATES — AT LEAST 500 ELIGIBLE ORDERS'

SELECT
    customer_state,
    eligible_delivery_orders,
    late_orders,

    ROUND(
        100.0 * late_orders
        / NULLIF(eligible_delivery_orders, 0),
        2
    ) AS late_delivery_pct,

    ROUND(
        avg_delivery_days, 2
    ) AS avg_purchase_to_delivery_days

FROM customer_state_summary
WHERE eligible_delivery_orders >= 500
ORDER BY
    100.0 * late_orders
        / NULLIF(eligible_delivery_orders, 0) DESC,
    eligible_delivery_orders DESC,
    customer_state
LIMIT 10;

COMMIT;