BEGIN;

CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT NOT NULL,
    customer_city TEXT,
    customer_state TEXT NOT NULL
);

CREATE TABLE sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT NOT NULL,
    seller_city TEXT,
    seller_state TEXT NOT NULL
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_category_name_english TEXT,
    category_missing BOOLEAN NOT NULL,
    category_translation_missing BOOLEAN NOT NULL,
    product_category_label TEXT NOT NULL
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id),
    order_status TEXT NOT NULL,
    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,
    flag_approval_after_carrier BOOLEAN NOT NULL,
    flag_carrier_after_delivery BOOLEAN NOT NULL,
    flag_delivery_before_purchase BOOLEAN NOT NULL,
    purchase_date DATE NOT NULL,
    purchase_month TEXT NOT NULL,
    purchase_year INTEGER NOT NULL,
    is_delivered BOOLEAN NOT NULL,
    is_delivery_analysis_eligible BOOLEAN NOT NULL,
    purchase_to_delivery_days NUMERIC
        CHECK (purchase_to_delivery_days >= 0),
    days_late INTEGER CHECK (days_late >= 0),
    late_delivery BOOLEAN
);

CREATE TABLE order_items (
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    order_item_id INTEGER NOT NULL CHECK (order_item_id >= 1),
    product_id TEXT NOT NULL REFERENCES products(product_id),
    seller_id TEXT NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(14, 2) NOT NULL CHECK (price > 0),
    freight_value NUMERIC(14, 2) NOT NULL CHECK (freight_value >= 0),
    price_cents BIGINT NOT NULL CHECK (price_cents > 0),
    freight_value_cents BIGINT NOT NULL CHECK (freight_value_cents >= 0),
    PRIMARY KEY (order_id, order_item_id),
    CHECK (price * 100 = price_cents),
    CHECK (freight_value * 100 = freight_value_cents)
);

CREATE TABLE order_payments (
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    payment_sequential INTEGER NOT NULL CHECK (payment_sequential >= 1),
    payment_type TEXT NOT NULL,
    payment_installments INTEGER NOT NULL CHECK (payment_installments >= 0),
    payment_value NUMERIC(14, 2) NOT NULL CHECK (payment_value >= 0),
    payment_value_cents BIGINT NOT NULL CHECK (payment_value_cents >= 0),
    flag_zero_payment BOOLEAN NOT NULL,
    flag_zero_installments BOOLEAN NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CHECK (payment_value * 100 = payment_value_cents)
);

CREATE TABLE order_reviews (
    review_id TEXT NOT NULL,
    order_id TEXT NOT NULL REFERENCES orders(order_id),
    review_score INTEGER NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP NOT NULL,
    review_answer_timestamp TIMESTAMP NOT NULL,
    has_written_feedback BOOLEAN NOT NULL,
    PRIMARY KEY (review_id, order_id)
);

CREATE TABLE order_reviews_summary (
    order_id TEXT PRIMARY KEY REFERENCES orders(order_id),
    review_count INTEGER NOT NULL CHECK (review_count >= 1),
    mean_review_score NUMERIC NOT NULL
        CHECK (mean_review_score BETWEEN 1 AND 5),
    min_review_score INTEGER NOT NULL
        CHECK (min_review_score BETWEEN 1 AND 5),
    max_review_score INTEGER NOT NULL
        CHECK (max_review_score BETWEEN 1 AND 5),
    has_low_review BOOLEAN NOT NULL,
    has_conflicting_scores BOOLEAN NOT NULL,
    CHECK (min_review_score <= mean_review_score),
    CHECK (mean_review_score <= max_review_score)
);

CREATE INDEX idx_customers_unique_id
    ON customers(customer_unique_id);

CREATE INDEX idx_reviews_order_id
    ON order_reviews(order_id);

COMMIT;