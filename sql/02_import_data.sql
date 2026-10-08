BEGIN;

\copy customers FROM 'data/processed/customers_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy sellers FROM 'data/processed/sellers_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy products FROM 'data/processed/products_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy orders FROM 'data/processed/orders_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_items FROM 'data/processed/items_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_payments FROM 'data/processed/payments_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_reviews FROM 'data/processed/reviews_clean.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy order_reviews_summary FROM 'data/processed/order_reviews_summary.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

SELECT
    table_name,
    expected_rows,
    actual_rows,
    actual_rows = expected_rows AS matches
FROM (
    VALUES
        ('customers', 99441, (SELECT COUNT(*) FROM customers)),
        ('sellers', 3095, (SELECT COUNT(*) FROM sellers)),
        ('products', 32951, (SELECT COUNT(*) FROM products)),
        ('orders', 99441, (SELECT COUNT(*) FROM orders)),
        ('order_items', 112650, (SELECT COUNT(*) FROM order_items)),
        ('order_payments', 103886, (SELECT COUNT(*) FROM order_payments)),
        ('order_reviews', 99224, (SELECT COUNT(*) FROM order_reviews)),
        ('order_reviews_summary', 98673, (SELECT COUNT(*) FROM order_reviews_summary))
) AS counts(table_name, expected_rows, actual_rows)
ORDER BY table_name;

COMMIT;