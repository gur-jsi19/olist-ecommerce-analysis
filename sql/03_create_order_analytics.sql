BEGIN;

CREATE OR REPLACE VIEW order_item_totals AS
SELECT
    order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT product_id) AS distinct_product_count,
    COUNT(DISTINCT seller_id) AS distinct_seller_count,
    SUM(price_cents) AS merchandise_value_cents,
    SUM(freight_value_cents) AS freight_value_cents
FROM order_items
GROUP BY order_id;

CREATE OR REPLACE VIEW order_payment_totals AS
SELECT
    order_id,
    COUNT(*) AS payment_record_count,
    COUNT(DISTINCT payment_type) AS payment_type_count,
    SUM(payment_value_cents) AS payment_value_cents
FROM order_payments
GROUP BY order_id;

CREATE OR REPLACE VIEW order_analytics AS
SELECT
    o.*,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    i.order_id IS NOT NULL AS has_items,
    COALESCE(i.item_count, 0) AS item_count,
    COALESCE(i.distinct_product_count, 0) AS distinct_product_count,
    COALESCE(i.distinct_seller_count, 0) AS distinct_seller_count,
    i.merchandise_value_cents,
    i.freight_value_cents,
    i.merchandise_value_cents + i.freight_value_cents
        AS items_plus_freight_cents,

    p.order_id IS NOT NULL AS has_payment,
    COALESCE(p.payment_record_count, 0) AS payment_record_count,
    COALESCE(p.payment_type_count, 0) AS payment_type_count,
    p.payment_value_cents,
    p.payment_value_cents
        - (i.merchandise_value_cents + i.freight_value_cents)
        AS payment_difference_cents,

    r.order_id IS NOT NULL AS has_review,
    COALESCE(r.review_count, 0) AS review_count,
    r.mean_review_score,
    r.min_review_score,
    r.max_review_score,
    r.has_low_review,
    r.has_conflicting_scores

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_item_totals i ON o.order_id = i.order_id
LEFT JOIN order_payment_totals p ON o.order_id = p.order_id
LEFT JOIN order_reviews_summary r ON o.order_id = r.order_id;

-- Reconcile the joined view against the source tables.
WITH model_totals AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT order_id) AS unique_orders,
        SUM(item_count) AS item_count,
        SUM(merchandise_value_cents) AS merchandise_cents,
        SUM(freight_value_cents) AS freight_cents,
        SUM(payment_value_cents) AS payment_cents,
        SUM(review_count) AS review_count
    FROM order_analytics
)
SELECT
    'Order count preserved' AS check_name,
    row_count = (SELECT COUNT(*) FROM orders) AS passed
FROM model_totals

UNION ALL
SELECT 'One row per order', row_count = unique_orders
FROM model_totals

UNION ALL
SELECT 'Item count preserved',
       item_count = (SELECT COUNT(*) FROM order_items)
FROM model_totals

UNION ALL
SELECT 'Merchandise total preserved',
       merchandise_cents = (SELECT SUM(price_cents) FROM order_items)
FROM model_totals

UNION ALL
SELECT 'Freight total preserved',
       freight_cents = (SELECT SUM(freight_value_cents) FROM order_items)
FROM model_totals

UNION ALL
SELECT 'Payment total preserved',
       payment_cents = (SELECT SUM(payment_value_cents) FROM order_payments)
FROM model_totals

UNION ALL
SELECT 'Review count preserved',
       review_count = (SELECT COUNT(*) FROM order_reviews)
FROM model_totals;

SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE NOT has_items) AS orders_without_items,
    COUNT(*) FILTER (WHERE NOT has_payment) AS orders_without_payment,
    COUNT(*) FILTER (WHERE NOT has_review) AS orders_without_reviews
FROM order_analytics;

COMMIT;