/*
    Analysis: Churn Deep Dive
    
    Purpose: Identify churn patterns, risk factors, and intervention opportunities
    
    This query demonstrates:
    - Churn segmentation by multiple dimensions
    - Leading indicator identification
    - At-risk customer scoring
    - Churn timing analysis
*/

-- ============================================================================
-- SECTION 1: Churn Overview by Time Period
-- ============================================================================

WITH monthly_churn AS (
    SELECT
        event_month_key,
        COUNT(DISTINCT customer_id) AS churned_customers,
        SUM(ABS(mrr_change)) AS churned_mrr
    FROM fct_subscription_events
    WHERE event_category = 'churn'
    GROUP BY 1
),

monthly_base AS (
    SELECT
        month_key,
        active_customers AS beginning_customers,
        active_mrr AS beginning_mrr
    FROM fct_mrr
)

SELECT
    mc.event_month_key AS month,
    mc.churned_customers,
    mb.beginning_customers,
    ROUND(mc.churned_customers / mb.beginning_customers * 100, 2) AS customer_churn_rate,
    ROUND(mc.churned_mrr, 2) AS churned_mrr,
    ROUND(mb.beginning_mrr, 2) AS beginning_mrr,
    ROUND(mc.churned_mrr / mb.beginning_mrr * 100, 2) AS mrr_churn_rate
FROM monthly_churn mc
LEFT JOIN monthly_base mb ON mc.event_month_key = mb.month_key
ORDER BY mc.event_month_key;


-- ============================================================================
-- SECTION 2: Churn by Customer Segment
-- ============================================================================

SELECT
    -- Segment dimensions
    industry,
    company_size,
    initial_plan_name,
    acquisition_channel,
    is_paid_acquisition,
    
    -- Metrics
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN has_churned THEN 1 END) AS churned_customers,
    ROUND(COUNT(CASE WHEN has_churned THEN 1 END) / COUNT(*) * 100, 1) AS churn_rate,
    ROUND(AVG(CASE WHEN has_churned THEN days_since_signup END), 0) AS avg_days_to_churn,
    ROUND(AVG(CASE WHEN has_churned THEN lifetime_revenue END), 2) AS avg_churned_ltv,
    ROUND(AVG(CASE WHEN NOT has_churned THEN lifetime_revenue END), 2) AS avg_retained_ltv
FROM dim_customers
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) >= 10
ORDER BY churn_rate DESC;


-- ============================================================================
-- SECTION 3: Churn Timing Analysis
-- ============================================================================
-- When do customers churn in their lifecycle?

WITH churn_events AS (
    SELECT
        customer_id,
        event_date AS churn_date,
        days_since_signup,
        tenure_bucket,
        mrr_change,
        plan_name,
        acquisition_channel
    FROM fct_subscription_events
    WHERE event_category = 'churn'
)

SELECT
    tenure_bucket,
    COUNT(*) AS churn_count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_total_churn,
    ROUND(AVG(ABS(mrr_change)), 2) AS avg_mrr_lost,
    ROUND(SUM(ABS(mrr_change)), 2) AS total_mrr_lost
FROM churn_events
GROUP BY tenure_bucket
ORDER BY 
    CASE tenure_bucket
        WHEN '0-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181-365 days' THEN 4
        ELSE 5
    END;


-- ============================================================================
-- SECTION 4: Churn Preceding Events
-- ============================================================================
-- What happens before customers churn?

WITH churn_events AS (
    SELECT
        customer_id,
        event_id,
        event_date AS churn_date,
        previous_event_type,
        days_since_signup
    FROM fct_subscription_events
    WHERE event_category = 'churn'
),

pre_churn_activity AS (
    SELECT
        ce.customer_id,
        ce.churn_date,
        e.event_type,
        e.event_date,
        DATE_DIFF(ce.churn_date, e.event_date, DAY) AS days_before_churn
    FROM churn_events ce
    INNER JOIN fct_subscription_events e 
        ON ce.customer_id = e.customer_id
        AND e.event_date < ce.churn_date
        AND e.event_date >= DATE_SUB(ce.churn_date, INTERVAL 90 DAY)
)

SELECT
    CASE
        WHEN days_before_churn <= 7 THEN '0-7 days before'
        WHEN days_before_churn <= 30 THEN '8-30 days before'
        WHEN days_before_churn <= 60 THEN '31-60 days before'
        ELSE '61-90 days before'
    END AS timing,
    event_type,
    COUNT(*) AS occurrence_count,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM pre_churn_activity
GROUP BY 1, 2
ORDER BY 
    CASE
        WHEN days_before_churn <= 7 THEN 1
        WHEN days_before_churn <= 30 THEN 2
        WHEN days_before_churn <= 60 THEN 3
        ELSE 4
    END,
    occurrence_count DESC;


-- ============================================================================
-- SECTION 5: At-Risk Customer Identification
-- ============================================================================
-- Score active customers for churn risk

WITH customer_signals AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.current_mrr,
        c.days_since_signup,
        c.downgrade_count,
        c.upgrade_count,
        c.failed_payments,
        c.successful_payments,
        c.last_payment_date,
        DATE_DIFF(CURRENT_DATE(), c.last_payment_date, DAY) AS days_since_last_payment,
        
        -- Risk signals
        CASE WHEN c.downgrade_count > 0 THEN 20 ELSE 0 END AS downgrade_risk,
        CASE WHEN c.failed_payments > 0 THEN 15 ELSE 0 END AS payment_risk,
        CASE 
            WHEN DATE_DIFF(CURRENT_DATE(), c.last_payment_date, DAY) > 45 THEN 25
            WHEN DATE_DIFF(CURRENT_DATE(), c.last_payment_date, DAY) > 30 THEN 10
            ELSE 0 
        END AS recency_risk,
        CASE 
            WHEN c.days_since_signup <= 90 THEN 15  -- New customers higher risk
            ELSE 0 
        END AS tenure_risk,
        
        -- Positive signals
        CASE WHEN c.upgrade_count > 0 THEN -15 ELSE 0 END AS upgrade_bonus,
        CASE 
            WHEN c.current_plan_tier = 'enterprise' THEN -10
            WHEN c.current_plan_tier = 'business' THEN -5
            ELSE 0
        END AS plan_bonus
        
    FROM dim_customers c
    WHERE c.customer_status = 'active_paying'
),

risk_scored AS (
    SELECT
        *,
        downgrade_risk + payment_risk + recency_risk + tenure_risk + 
        upgrade_bonus + plan_bonus AS risk_score
    FROM customer_signals
)

SELECT
    customer_id,
    company_name,
    current_mrr,
    days_since_signup,
    days_since_last_payment,
    downgrade_count,
    failed_payments,
    risk_score,
    CASE
        WHEN risk_score >= 40 THEN 'High Risk'
        WHEN risk_score >= 20 THEN 'Medium Risk'
        WHEN risk_score >= 0 THEN 'Low Risk'
        ELSE 'Healthy'
    END AS risk_category
FROM risk_scored
WHERE risk_score > 0
ORDER BY risk_score DESC, current_mrr DESC
LIMIT 100;


-- ============================================================================
-- SECTION 6: Churn vs Retention Factor Analysis
-- ============================================================================
-- Compare characteristics of churned vs retained customers

SELECT
    'Churned' AS segment,
    COUNT(*) AS customers,
    ROUND(AVG(days_since_signup), 0) AS avg_tenure_days,
    ROUND(AVG(lifetime_revenue), 2) AS avg_lifetime_revenue,
    ROUND(AVG(upgrade_count), 2) AS avg_upgrades,
    ROUND(AVG(downgrade_count), 2) AS avg_downgrades,
    ROUND(AVG(CASE WHEN is_paid_acquisition THEN 1 ELSE 0 END) * 100, 1) AS pct_paid_acquisition,
    ROUND(AVG(CASE WHEN is_trial THEN 1 ELSE 0 END) * 100, 1) AS pct_started_trial,
    ROUND(AVG(CASE WHEN converted_from_trial THEN 1 ELSE 0 END) * 100, 1) AS pct_trial_converted
FROM dim_customers
WHERE has_churned = TRUE

UNION ALL

SELECT
    'Retained' AS segment,
    COUNT(*) AS customers,
    ROUND(AVG(days_since_signup), 0) AS avg_tenure_days,
    ROUND(AVG(lifetime_revenue), 2) AS avg_lifetime_revenue,
    ROUND(AVG(upgrade_count), 2) AS avg_upgrades,
    ROUND(AVG(downgrade_count), 2) AS avg_downgrades,
    ROUND(AVG(CASE WHEN is_paid_acquisition THEN 1 ELSE 0 END) * 100, 1) AS pct_paid_acquisition,
    ROUND(AVG(CASE WHEN is_trial THEN 1 ELSE 0 END) * 100, 1) AS pct_started_trial,
    ROUND(AVG(CASE WHEN converted_from_trial THEN 1 ELSE 0 END) * 100, 1) AS pct_trial_converted
FROM dim_customers
WHERE has_churned = FALSE AND customer_status = 'active_paying';
