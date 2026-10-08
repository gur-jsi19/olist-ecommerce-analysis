\echo 'PAYMENT RECONCILIATION — DELIVERED ORDERS'
\echo 'Payment total compared with merchandise plus freight.'

WITH classified_orders AS (
    SELECT
        *,
        CASE
            WHEN NOT has_payment THEN 'Missing payment'
            WHEN NOT has_items THEN 'Missing items'
            WHEN payment_difference_cents = 0 THEN 'Exact match'
            WHEN ABS(payment_difference_cents) <= 1
                THEN 'Difference of 1 cent'
            WHEN ABS(payment_difference_cents) <= 100
                THEN 'Difference of 2–100 cents'
            ELSE 'Difference above BRL 1'
        END AS reconciliation_group

    FROM order_analytics
    WHERE is_delivered
)

SELECT
    reconciliation_group,
    COUNT(*) AS orders,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    ) AS order_share_pct,

    ROUND(
        SUM(ABS(payment_difference_cents)) / 100.0,
        2
    ) AS total_absolute_difference_brl,

    ROUND(
        MAX(ABS(payment_difference_cents)) / 100.0,
        2
    ) AS max_absolute_difference_brl

FROM classified_orders
GROUP BY reconciliation_group
ORDER BY reconciliation_group;