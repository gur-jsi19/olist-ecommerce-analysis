BEGIN;

\echo 'REVIEW TIMING — ELIGIBLE DELIVERED ORDERS'
\echo 'Counts below represent individual review records.'

SELECT
    CASE
        WHEN o.late_delivery THEN 'Late'
        ELSE 'On time'
    END AS delivery_group,

    COUNT(*) AS review_records,

    COUNT(*) FILTER (
        WHERE r.review_answer_timestamp
            < o.order_delivered_customer_date
    ) AS pre_delivery_reviews,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_answer_timestamp
                < o.order_delivered_customer_date
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS pre_delivery_review_pct

FROM order_analytics AS o
JOIN order_reviews AS r
    ON o.order_id = r.order_id
WHERE o.is_delivery_analysis_eligible
GROUP BY o.late_delivery
ORDER BY o.late_delivery;


CREATE OR REPLACE VIEW order_post_delivery_reviews AS
SELECT
    r.order_id,
    COUNT(*) AS post_delivery_review_count,
    AVG(r.review_score) AS post_delivery_mean_score,
    BOOL_OR(
        r.review_score <= 2
    ) AS post_delivery_has_low_review

FROM order_reviews AS r
JOIN orders AS o
    ON r.order_id = o.order_id

WHERE o.is_delivery_analysis_eligible
  AND r.review_answer_timestamp
      >= o.order_delivered_customer_date

GROUP BY r.order_id;


\echo 'SENSITIVITY CHECK — REVIEW RESPONSES AT OR AFTER DELIVERY'
\echo 'Each included order receives equal weight in the average.'

SELECT
    CASE
        WHEN o.late_delivery THEN 'Late'
        ELSE 'On time'
    END AS delivery_group,

    COUNT(*) AS eligible_orders,

    COUNT(p.order_id) AS orders_with_post_review,

    ROUND(
        100.0 * COUNT(p.order_id)
        / NULLIF(COUNT(*), 0),
        2
    ) AS post_review_coverage_pct,

    ROUND(
        AVG(p.post_delivery_mean_score), 2
    ) AS avg_post_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE p.post_delivery_has_low_review
        ) / NULLIF(COUNT(p.order_id), 0),
        2
    ) AS post_low_review_pct

FROM order_analytics AS o
LEFT JOIN order_post_delivery_reviews AS p
    ON o.order_id = p.order_id

WHERE o.is_delivery_analysis_eligible
GROUP BY o.late_delivery
ORDER BY o.late_delivery;

COMMIT;