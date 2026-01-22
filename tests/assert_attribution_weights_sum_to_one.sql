/*
    Test: assert_attribution_weights_sum_to_one
    
    Validates that attribution weights sum to 1.0 (or very close) per customer.
    Each attribution model should distribute exactly 100% of credit.
*/

WITH weight_sums AS (
    SELECT
        customer_id,
        ROUND(SUM(first_touch_weight), 4) AS first_touch_sum,
        ROUND(SUM(last_touch_weight), 4) AS last_touch_sum,
        ROUND(SUM(linear_weight), 4) AS linear_sum,
        ROUND(SUM(position_based_weight), 4) AS position_based_sum
    FROM {{ ref('int_attribution_touchpoints') }}
    GROUP BY customer_id
)

SELECT
    customer_id,
    first_touch_sum,
    last_touch_sum,
    linear_sum,
    position_based_sum
FROM weight_sums
WHERE
    -- First touch should sum to 1
    ABS(first_touch_sum - 1.0) > 0.01
    -- Last touch should sum to 1
    OR ABS(last_touch_sum - 1.0) > 0.01
    -- Linear should sum to 1
    OR ABS(linear_sum - 1.0) > 0.01
    -- Position-based should sum to 1
    OR ABS(position_based_sum - 1.0) > 0.01
