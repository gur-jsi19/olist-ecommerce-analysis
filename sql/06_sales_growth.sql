\x on

\echo 'FEBRUARY–JULY COMPARISON: 2017 VS 2018'
\echo 'Delivered orders; merchandise values exclude freight.'

WITH period_totals AS (
    SELECT
        purchase_year,
        COUNT(*) AS delivered_orders,
        SUM(merchandise_value_cents) AS merchandise_sales_cents,
        AVG(merchandise_value_cents) AS avg_order_value_cents
    FROM order_analytics
    WHERE is_delivered
      AND purchase_year IN (2017, 2018)
      AND EXTRACT(MONTH FROM purchase_date) BETWEEN 2 AND 7
    GROUP BY purchase_year
),

comparison AS (
    SELECT
        *,
        LAG(delivered_orders) OVER (
            ORDER BY purchase_year
        ) AS previous_year_orders,

        LAG(merchandise_sales_cents) OVER (
            ORDER BY purchase_year
        ) AS previous_year_sales_cents,

        LAG(avg_order_value_cents) OVER (
            ORDER BY purchase_year
        ) AS previous_year_avg_order_cents
    FROM period_totals
)

SELECT
    purchase_year,
    delivered_orders,

    ROUND(
        merchandise_sales_cents / 100.0, 2
    ) AS merchandise_sales_brl,

    ROUND(
        avg_order_value_cents / 100.0, 2
    ) AS avg_order_value_brl,

    ROUND(
        100.0 * (delivered_orders - previous_year_orders)
        / NULLIF(previous_year_orders, 0),
        2
    ) AS order_growth_pct,

    ROUND(
        100.0 * (
            merchandise_sales_cents - previous_year_sales_cents
        ) / NULLIF(previous_year_sales_cents, 0),
        2
    ) AS sales_growth_pct,

    ROUND(
        100.0 * (
            avg_order_value_cents - previous_year_avg_order_cents
        ) / NULLIF(previous_year_avg_order_cents, 0),
        2
    ) AS avg_order_value_growth_pct

FROM comparison
ORDER BY purchase_year;

\x off