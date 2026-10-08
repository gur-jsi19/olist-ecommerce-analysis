\echo 'MONTHLY SALES — GROUPED BY PURCHASE MONTH'
\echo 'Sales and average order value include delivered orders only.'

SELECT
    purchase_month,

    COUNT(*) AS orders_placed,

    COUNT(*) FILTER (
        WHERE is_delivered
    ) AS delivered_orders,

    ROUND(
        COALESCE(
            SUM(merchandise_value_cents)
                FILTER (WHERE is_delivered),
            0
        ) / 100.0,
        2
    ) AS merchandise_sales_brl,

    ROUND(
        AVG(merchandise_value_cents)
            FILTER (WHERE is_delivered) / 100.0,
        2
    ) AS avg_order_value_brl

FROM order_analytics
GROUP BY purchase_month
ORDER BY purchase_month;


\echo 'DELIVERED-ORDER PURCHASE COVERAGE BY YEAR'

SELECT
    purchase_year,
    COUNT(*) AS delivered_orders,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,
    COUNT(DISTINCT purchase_month) AS months_with_orders
FROM order_analytics
WHERE is_delivered
GROUP BY purchase_year
ORDER BY purchase_year;