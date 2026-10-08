BEGIN;

CREATE OR REPLACE VIEW category_sales_summary AS
SELECT
    p.product_category_label AS category,
    COUNT(*) AS item_count,
    COUNT(DISTINCT i.order_id) AS orders_with_category,
    SUM(i.price_cents) AS merchandise_sales_cents
FROM order_items AS i
JOIN orders AS o
    ON i.order_id = o.order_id
JOIN products AS p
    ON i.product_id = p.product_id
WHERE o.is_delivered
GROUP BY p.product_category_label;


\echo 'TOP 10 CATEGORIES — DELIVERED ORDERS, FULL AVAILABLE HISTORY'

SELECT
    category,
    item_count,
    orders_with_category,

    ROUND(
        merchandise_sales_cents / 100.0, 2
    ) AS merchandise_sales_brl,

    ROUND(
        100.0 * merchandise_sales_cents
        / NULLIF(SUM(merchandise_sales_cents) OVER (), 0),
        2
    ) AS sales_share_pct

FROM category_sales_summary
ORDER BY merchandise_sales_cents DESC, category
LIMIT 10;


\echo 'CATEGORY TOTAL RECONCILIATION'

SELECT
    SUM(item_count) = (
        SELECT SUM(item_count)
        FROM order_analytics
        WHERE is_delivered
    ) AS item_count_preserved,

    SUM(merchandise_sales_cents) = (
        SELECT SUM(merchandise_value_cents)
        FROM order_analytics
        WHERE is_delivered
    ) AS merchandise_total_preserved

FROM category_sales_summary;

COMMIT;