BEGIN;

CREATE OR REPLACE VIEW powerbi_dates AS
WITH date_bounds AS (
    SELECT
        DATE_TRUNC(
            'year', MIN(purchase_date)::timestamp
        )::date AS first_date,

        (
            DATE_TRUNC(
                'year', MAX(purchase_date)::timestamp
            ) + INTERVAL '1 year' - INTERVAL '1 day'
        )::date AS last_date

    FROM orders
)

SELECT
    g.calendar_day::date AS date,

    EXTRACT(YEAR FROM g.calendar_day)::integer AS year,
    EXTRACT(QUARTER FROM g.calendar_day)::integer AS quarter,
    EXTRACT(MONTH FROM g.calendar_day)::integer AS month_number,

    TO_CHAR(g.calendar_day, 'FMMonth') AS month_name,
    TO_CHAR(g.calendar_day, 'YYYY-MM') AS year_month,

    (
        EXTRACT(YEAR FROM g.calendar_day) * 100
        + EXTRACT(MONTH FROM g.calendar_day)
    )::integer AS year_month_sort,

    CASE
        WHEN EXTRACT(YEAR FROM g.calendar_day) IN (2017, 2018)
         AND EXTRACT(MONTH FROM g.calendar_day) BETWEEN 2 AND 7
        THEN 1
        ELSE 0
    END AS is_growth_comparison_period

FROM date_bounds AS b
CROSS JOIN LATERAL GENERATE_SERIES(
    b.first_date::timestamp,
    b.last_date::timestamp,
    INTERVAL '1 day'
) AS g(calendar_day);


CREATE OR REPLACE VIEW powerbi_states AS
SELECT DISTINCT
    customer_state,
    'Brazil'::text AS country
FROM customers;


CREATE OR REPLACE VIEW powerbi_products AS
SELECT
    product_id,

    INITCAP(
        REPLACE(product_category_label, '_', ' ')
    ) AS product_category,

    category_missing::integer AS category_missing,
    category_translation_missing::integer
        AS category_translation_missing

FROM products;


\echo 'LOOKUP VIEW ROW COUNTS'

SELECT 'Dates' AS lookup_view, COUNT(*) AS rows
FROM powerbi_dates

UNION ALL

SELECT 'States', COUNT(*)
FROM powerbi_states

UNION ALL

SELECT 'Products', COUNT(*)
FROM powerbi_products;


\echo 'LOOKUP KEY AND RELATIONSHIP CHECKS'

WITH fact_dates AS (
    SELECT purchase_date FROM powerbi_orders
    UNION
    SELECT purchase_date FROM powerbi_order_items
),

fact_states AS (
    SELECT customer_state FROM powerbi_orders
    UNION
    SELECT customer_state FROM powerbi_order_items
)

SELECT
    'Date key unique and calendar continuous' AS check_name,
    COUNT(*) = COUNT(DISTINCT date)
        AND COUNT(*) = MAX(date) - MIN(date) + 1 AS passed
FROM powerbi_dates

UNION ALL

SELECT
    'State key unique and non-missing',
    COUNT(*) = COUNT(DISTINCT customer_state)
FROM powerbi_states

UNION ALL

SELECT
    'Product key unique and non-missing',
    COUNT(*) = COUNT(DISTINCT product_id)
FROM powerbi_products

UNION ALL

SELECT
    'All fact purchase dates have a lookup',
    NOT EXISTS (
        SELECT 1
        FROM fact_dates AS f
        LEFT JOIN powerbi_dates AS d
            ON f.purchase_date = d.date
        WHERE d.date IS NULL
    )

UNION ALL

SELECT
    'All fact customer states have a lookup',
    NOT EXISTS (
        SELECT 1
        FROM fact_states AS f
        LEFT JOIN powerbi_states AS s
            ON f.customer_state = s.customer_state
        WHERE s.customer_state IS NULL
    )

UNION ALL

SELECT
    'All item products have a lookup',
    NOT EXISTS (
        SELECT 1
        FROM powerbi_order_items AS i
        LEFT JOIN powerbi_products AS p
            ON i.product_id = p.product_id
        WHERE p.product_id IS NULL
    );

COMMIT;