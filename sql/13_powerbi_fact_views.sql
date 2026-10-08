BEGIN;

CREATE OR REPLACE VIEW powerbi_orders AS
SELECT
    o.order_id,
    o.customer_unique_id,
    o.purchase_date,
    o.customer_state,
    o.order_status,

    o.is_delivered::integer AS is_delivered,
    o.is_delivery_analysis_eligible::integer
        AS is_delivery_analysis_eligible,
    o.late_delivery::integer AS late_delivery,

    CASE
        WHEN NOT o.is_delivery_analysis_eligible
            THEN 'Not eligible'
        WHEN o.late_delivery THEN 'Late'
        ELSE 'On time'
    END AS delivery_group,

    CASE
        WHEN NOT o.is_delivery_analysis_eligible
            THEN 'Not eligible'
        WHEN o.days_late = 0 THEN 'On time'
        WHEN o.days_late <= 3 THEN '1–3 days late'
        WHEN o.days_late <= 7 THEN '4–7 days late'
        WHEN o.days_late <= 14 THEN '8–14 days late'
        ELSE '15+ days late'
    END AS lateness_band,

    CASE
        WHEN NOT o.is_delivery_analysis_eligible THEN 5
        WHEN o.days_late = 0 THEN 0
        WHEN o.days_late <= 3 THEN 1
        WHEN o.days_late <= 7 THEN 2
        WHEN o.days_late <= 14 THEN 3
        ELSE 4
    END AS lateness_band_sort,

    o.purchase_to_delivery_days,
    o.days_late,
    o.item_count,
    o.merchandise_value_cents,
    o.freight_value_cents,
    o.payment_value_cents,
    o.payment_difference_cents,

    o.review_count,
    o.mean_review_score,
    o.has_low_review::integer AS has_low_review,

    COALESCE(
        p.post_delivery_review_count, 0
    ) AS post_delivery_review_count,

    p.post_delivery_mean_score,
    p.post_delivery_has_low_review::integer
        AS post_delivery_has_low_review,

    CASE
        WHEN o.is_delivery_analysis_eligible
        THEN o.review_count
            - COALESCE(p.post_delivery_review_count, 0)
        ELSE NULL
    END AS pre_delivery_review_count

FROM order_analytics AS o
LEFT JOIN order_post_delivery_reviews AS p
    ON o.order_id = p.order_id;


CREATE OR REPLACE VIEW powerbi_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    o.purchase_date,
    o.customer_state,
    o.is_delivered::integer AS is_delivered,
    i.price_cents,
    i.freight_value_cents

FROM order_items AS i
JOIN order_analytics AS o
    ON i.order_id = o.order_id;


\echo 'POWER BI FACT VIEW VALIDATION'
\x on

WITH order_checks AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT order_id) AS unique_orders,
        SUM(merchandise_value_cents) FILTER (
            WHERE is_delivered = 1
        ) AS delivered_sales_cents
    FROM powerbi_orders
),

item_checks AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT (order_id, order_item_id))
            AS unique_items,
        SUM(price_cents) FILTER (
            WHERE is_delivered = 1
        ) AS delivered_sales_cents
    FROM powerbi_order_items
)

SELECT
    o.row_count = (
        SELECT COUNT(*) FROM orders
    ) AS order_count_preserved,

    o.row_count = o.unique_orders
        AS one_row_per_order,

    i.row_count = (
        SELECT COUNT(*) FROM order_items
    ) AS item_count_preserved,

    i.row_count = i.unique_items
        AS one_row_per_order_item,

    o.delivered_sales_cents = i.delivered_sales_cents
        AS delivered_sales_match_between_views

FROM order_checks AS o
CROSS JOIN item_checks AS i;

\x off
COMMIT;
