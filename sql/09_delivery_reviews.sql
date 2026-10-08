\echo 'ON-TIME VS LATE DELIVERY — FULL AVAILABLE HISTORY'
\echo 'Only orders eligible for delivery analysis are included.'

SELECT
    CASE
        WHEN late_delivery THEN 'Late'
        ELSE 'On time'
    END AS delivery_group,

    COUNT(*) AS eligible_orders,

    COUNT(*) FILTER (
        WHERE has_review
    ) AS reviewed_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_review)
        / NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_pct,

    ROUND(
        AVG(mean_review_score), 2
    ) AS avg_order_review_score,

    COUNT(*) FILTER (
        WHERE has_low_review
    ) AS orders_with_any_low_review,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_low_review)
        / NULLIF(COUNT(*) FILTER (WHERE has_review), 0),
        2
    ) AS low_review_pct

FROM order_analytics
WHERE is_delivery_analysis_eligible
GROUP BY late_delivery
ORDER BY late_delivery;


\echo 'REVIEW SCORES BY LATENESS BAND'

WITH delivery_bands AS (
    SELECT
        *,
        CASE
            WHEN days_late = 0 THEN 0
            WHEN days_late <= 3 THEN 1
            WHEN days_late <= 7 THEN 2
            WHEN days_late <= 14 THEN 3
            ELSE 4
        END AS band_order,

        CASE
            WHEN days_late = 0 THEN 'On time'
            WHEN days_late <= 3 THEN '1–3 days late'
            WHEN days_late <= 7 THEN '4–7 days late'
            WHEN days_late <= 14 THEN '8–14 days late'
            ELSE '15+ days late'
        END AS lateness_band

    FROM order_analytics
    WHERE is_delivery_analysis_eligible
)

SELECT
    lateness_band,
    COUNT(*) AS eligible_orders,

    COUNT(*) FILTER (
        WHERE has_review
    ) AS reviewed_orders,

    ROUND(
        AVG(mean_review_score), 2
    ) AS avg_order_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_low_review)
        / NULLIF(COUNT(*) FILTER (WHERE has_review), 0),
        2
    ) AS low_review_pct

FROM delivery_bands
GROUP BY band_order, lateness_band
ORDER BY band_order;