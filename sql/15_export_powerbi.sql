BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SET LOCAL DateStyle = 'ISO, YMD';

\copy (SELECT * FROM powerbi_orders ORDER BY order_id) TO 'data/powerbi/powerbi_orders.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM powerbi_order_items ORDER BY order_id, order_item_id) TO 'data/powerbi/powerbi_order_items.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM powerbi_dates ORDER BY date) TO 'data/powerbi/powerbi_dates.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM powerbi_states ORDER BY customer_state) TO 'data/powerbi/powerbi_states.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\copy (SELECT * FROM powerbi_products ORDER BY product_id) TO 'data/powerbi/powerbi_products.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

COMMIT;