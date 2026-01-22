/*
    Analysis: Marketing Channel Attribution
    
    Purpose: Evaluate marketing channel performance and optimize spend allocation
    
    This query demonstrates:
    - Multiple attribution model comparisons
    - CAC and LTV calculations by channel
    - Channel efficiency metrics
    - Customer journey analysis
*/

-- ============================================================================
-- SECTION 1: Channel Performance Overview
-- ============================================================================

WITH channel_customers AS (
    SELECT
        acquisition_channel,
        acquisition_channel_category,
        is_paid_acquisition,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN customer_status = 'active_paying' THEN customer_id END) AS active_customers,
        COUNT(DISTINCT CASE WHEN has_churned THEN customer_id END) AS churned_customers,
        SUM(lifetime_revenue) AS total_revenue,
        SUM(current_mrr) AS current_mrr,
        AVG(lifetime_revenue) AS avg_ltv,
        AVG(current_mrr) AS avg_mrr
    FROM dim_customers
    GROUP BY 1, 2, 3
)

SELECT
    acquisition_channel,
    acquisition_channel_category,
    is_paid_acquisition,
    total_customers,
    active_customers,
    ROUND(active_customers / total_customers * 100, 1) AS retention_rate,
    churned_customers,
    ROUND(churned_customers / total_customers * 100, 1) AS churn_rate,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(current_mrr, 2) AS current_mrr,
    ROUND(avg_ltv, 2) AS avg_ltv,
    ROUND(avg_mrr, 2) AS avg_mrr
FROM channel_customers
ORDER BY total_revenue DESC;


-- ============================================================================
-- SECTION 2: Attribution Model Comparison
-- ============================================================================
-- Compare how different attribution models value each channel

WITH attribution_summary AS (
    SELECT
        channel_name,
        channel_category,
        is_paid,
        
        -- Customer counts by attribution
        COUNT(DISTINCT CASE WHEN is_first_touch THEN customer_id END) AS first_touch_customers,
        COUNT(DISTINCT CASE WHEN is_last_touch THEN customer_id END) AS last_touch_customers,
        COUNT(DISTINCT customer_id) AS any_touch_customers,
        
        -- Revenue by attribution model
        SUM(first_touch_revenue) AS first_touch_revenue,
        SUM(last_touch_revenue) AS last_touch_revenue,
        SUM(linear_revenue) AS linear_revenue,
        SUM(time_decay_revenue) AS time_decay_revenue,
        SUM(position_based_revenue) AS position_based_revenue,
        
        -- Touch metrics
        COUNT(*) AS total_touches,
        AVG(days_to_conversion) AS avg_days_to_conversion
        
    FROM int_attribution_touchpoints
    GROUP BY 1, 2, 3
)

SELECT
    channel_name,
    channel_category,
    is_paid,
    
    -- Customer attribution
    first_touch_customers,
    last_touch_customers,
    any_touch_customers,
    
    -- Revenue comparison across models
    ROUND(first_touch_revenue, 2) AS first_touch_revenue,
    ROUND(last_touch_revenue, 2) AS last_touch_revenue,
    ROUND(linear_revenue, 2) AS linear_revenue,
    ROUND(time_decay_revenue, 2) AS time_decay_revenue,
    ROUND(position_based_revenue, 2) AS position_based_revenue,
    
    -- Variance between models
    ROUND(first_touch_revenue - last_touch_revenue, 2) AS first_vs_last_delta,
    
    -- Journey metrics
    total_touches,
    ROUND(avg_days_to_conversion, 1) AS avg_days_to_conversion

FROM attribution_summary
ORDER BY position_based_revenue DESC;


-- ============================================================================
-- SECTION 3: Channel Journey Position Analysis
-- ============================================================================
-- Understand which channels appear at different stages of the journey

WITH journey_positions AS (
    SELECT
        channel_name,
        journey_stage,
        COUNT(*) AS touches,
        COUNT(DISTINCT customer_id) AS unique_customers,
        AVG(initial_mrr) AS avg_customer_value
    FROM int_attribution_touchpoints
    GROUP BY 1, 2
)

SELECT
    channel_name,
    journey_stage,
    touches,
    unique_customers,
    ROUND(avg_customer_value, 2) AS avg_customer_value,
    ROUND(touches / SUM(touches) OVER (PARTITION BY channel_name) * 100, 1) AS pct_of_channel_touches
FROM journey_positions
ORDER BY channel_name, 
    CASE journey_stage 
        WHEN 'awareness' THEN 1 
        WHEN 'consideration_early' THEN 2
        WHEN 'consideration_late' THEN 3
        WHEN 'decision' THEN 4
    END;


-- ============================================================================
-- SECTION 4: Multi-Touch Journey Analysis
-- ============================================================================
-- Analyze customer journeys with multiple touchpoints

WITH journey_summary AS (
    SELECT
        customer_id,
        total_touches,
        MIN(CASE WHEN is_first_touch THEN channel_name END) AS first_channel,
        MAX(CASE WHEN is_last_touch THEN channel_name END) AS last_channel,
        STRING_AGG(channel_name, ' → ' ORDER BY touch_sequence) AS journey_path,
        MAX(initial_mrr) AS customer_value,
        MAX(days_to_conversion) AS total_journey_days
    FROM int_attribution_touchpoints
    GROUP BY customer_id, total_touches
)

SELECT
    total_touches,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(AVG(customer_value), 2) AS avg_customer_value,
    ROUND(AVG(total_journey_days), 1) AS avg_journey_days
FROM journey_summary
GROUP BY total_touches
ORDER BY total_touches;


-- ============================================================================
-- SECTION 5: Channel Combination Performance
-- ============================================================================
-- Which first-touch + last-touch combinations perform best?

WITH journey_combos AS (
    SELECT
        customer_id,
        MIN(CASE WHEN is_first_touch THEN channel_name END) AS first_channel,
        MAX(CASE WHEN is_last_touch THEN channel_name END) AS last_channel,
        MAX(initial_mrr) AS customer_mrr
    FROM int_attribution_touchpoints
    GROUP BY customer_id
)

SELECT
    first_channel,
    last_channel,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(customer_mrr), 2) AS total_mrr,
    ROUND(AVG(customer_mrr), 2) AS avg_mrr
FROM journey_combos
GROUP BY first_channel, last_channel
HAVING COUNT(DISTINCT customer_id) >= 5
ORDER BY total_mrr DESC
LIMIT 20;


-- ============================================================================
-- SECTION 6: Channel Efficiency by Customer Segment
-- ============================================================================
-- How do channels perform across different customer segments?

WITH channel_segments AS (
    SELECT
        c.acquisition_channel,
        c.company_size,
        c.industry,
        COUNT(DISTINCT c.customer_id) AS customers,
        AVG(c.lifetime_revenue) AS avg_ltv,
        AVG(c.current_mrr) AS avg_mrr,
        AVG(CASE WHEN c.has_churned THEN 0 ELSE 1 END) AS retention_rate
    FROM dim_customers c
    GROUP BY 1, 2, 3
)

SELECT
    acquisition_channel,
    company_size,
    customers,
    ROUND(avg_ltv, 2) AS avg_ltv,
    ROUND(avg_mrr, 2) AS avg_mrr,
    ROUND(retention_rate * 100, 1) AS retention_rate_pct
FROM channel_segments
WHERE customers >= 10
ORDER BY acquisition_channel, avg_ltv DESC;


-- ============================================================================
-- SECTION 7: Paid vs Organic Performance
-- ============================================================================

SELECT
    CASE WHEN is_paid_acquisition THEN 'Paid' ELSE 'Organic' END AS channel_type,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(AVG(lifetime_revenue), 2) AS avg_ltv,
    ROUND(AVG(current_mrr), 2) AS avg_current_mrr,
    ROUND(SUM(lifetime_revenue), 2) AS total_revenue,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 1) AS churn_rate,
    ROUND(AVG(upgrade_count), 2) AS avg_upgrades,
    ROUND(AVG(days_since_signup), 0) AS avg_tenure_days
FROM dim_customers
GROUP BY 1;
