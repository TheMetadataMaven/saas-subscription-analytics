/*
    Analysis: Cohort Analysis Deep Dive
    
    Purpose: Comprehensive cohort analysis for executive reporting
    
    This query demonstrates:
    - Cohort construction from raw data
    - Retention calculation across multiple dimensions
    - Revenue retention vs customer retention comparison
    - Trend identification across cohorts
*/

-- ============================================================================
-- SECTION 1: Basic Cohort Retention Matrix
-- ============================================================================
-- Classic retention matrix showing % of customers retained by month

WITH cohort_base AS (
    SELECT
        customer_id,
        DATE_TRUNC(signup_date, MONTH) AS cohort_month,
        signup_date
    FROM dim_customers
),

monthly_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC(event_date, MONTH) AS activity_month
    FROM fct_subscription_events
    WHERE mrr_after > 0  -- Customer was paying
),

retention_data AS (
    SELECT
        cb.cohort_month,
        ma.activity_month,
        DATE_DIFF(ma.activity_month, cb.cohort_month, MONTH) AS month_number,
        COUNT(DISTINCT cb.customer_id) AS active_customers
    FROM cohort_base cb
    INNER JOIN monthly_activity ma 
        ON cb.customer_id = ma.customer_id
        AND ma.activity_month >= cb.cohort_month
    GROUP BY 1, 2, 3
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohort_base
    GROUP BY 1
)

SELECT
    FORMAT_DATE('%Y-%m', rd.cohort_month) AS cohort,
    cs.cohort_size,
    rd.month_number,
    rd.active_customers,
    ROUND(rd.active_customers / cs.cohort_size * 100, 1) AS retention_pct
FROM retention_data rd
JOIN cohort_sizes cs ON rd.cohort_month = cs.cohort_month
WHERE rd.month_number <= 12
ORDER BY rd.cohort_month, rd.month_number;


-- ============================================================================
-- SECTION 2: Revenue Retention by Cohort
-- ============================================================================
-- Compares customer retention to MRR retention (can be >100% with expansion)

WITH cohort_mrr AS (
    SELECT
        c.signup_cohort_month AS cohort_month,
        DATE_TRUNC(e.event_date, MONTH) AS mrr_month,
        DATE_DIFF(DATE_TRUNC(e.event_date, MONTH), 
                  DATE_TRUNC(PARSE_DATE('%Y-%m', c.signup_cohort_month), MONTH), 
                  MONTH) AS month_number,
        SUM(e.mrr_after) AS total_mrr,
        COUNT(DISTINCT c.customer_id) AS active_customers
    FROM dim_customers c
    INNER JOIN fct_subscription_events e 
        ON c.customer_id = e.customer_id
    WHERE e.mrr_after > 0
    GROUP BY 1, 2, 3
),

baseline AS (
    SELECT
        cohort_month,
        total_mrr AS m0_mrr,
        active_customers AS m0_customers
    FROM cohort_mrr
    WHERE month_number = 0
)

SELECT
    cm.cohort_month,
    cm.month_number,
    cm.active_customers,
    b.m0_customers,
    ROUND(cm.active_customers / b.m0_customers * 100, 1) AS customer_retention_pct,
    ROUND(cm.total_mrr, 2) AS mrr,
    ROUND(b.m0_mrr, 2) AS m0_mrr,
    ROUND(cm.total_mrr / b.m0_mrr * 100, 1) AS net_revenue_retention_pct
FROM cohort_mrr cm
JOIN baseline b ON cm.cohort_month = b.cohort_month
WHERE cm.month_number BETWEEN 0 AND 12
ORDER BY cm.cohort_month, cm.month_number;


-- ============================================================================
-- SECTION 3: Cohort Performance Comparison
-- ============================================================================
-- Compare key metrics across cohorts to identify trends

WITH cohort_metrics AS (
    SELECT
        signup_cohort_month AS cohort,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN customer_status = 'active_paying' THEN customer_id END) AS active_customers,
        COUNT(DISTINCT CASE WHEN has_churned THEN customer_id END) AS churned_customers,
        ROUND(AVG(lifetime_revenue), 2) AS avg_ltv,
        ROUND(AVG(CASE WHEN customer_status = 'active_paying' THEN current_mrr END), 2) AS avg_current_mrr,
        ROUND(AVG(days_since_signup), 0) AS avg_tenure_days,
        COUNT(DISTINCT CASE WHEN upgrade_count > 0 THEN customer_id END) AS customers_upgraded,
        COUNT(DISTINCT CASE WHEN converted_from_trial THEN customer_id END) AS trial_conversions
    FROM dim_customers
    GROUP BY 1
)

SELECT
    cohort,
    total_customers,
    active_customers,
    ROUND(active_customers / total_customers * 100, 1) AS current_retention_pct,
    churned_customers,
    ROUND(churned_customers / total_customers * 100, 1) AS churn_pct,
    avg_ltv,
    avg_current_mrr,
    avg_tenure_days,
    customers_upgraded,
    ROUND(customers_upgraded / total_customers * 100, 1) AS upgrade_pct,
    trial_conversions,
    ROUND(trial_conversions / NULLIF(total_customers, 0) * 100, 1) AS trial_conversion_pct
FROM cohort_metrics
ORDER BY cohort;


-- ============================================================================
-- SECTION 4: Cohort Behavior Patterns
-- ============================================================================
-- Identify behavioral patterns that correlate with retention

WITH customer_behavior AS (
    SELECT
        c.customer_id,
        c.signup_cohort_month,
        c.customer_status,
        c.has_churned,
        c.days_since_signup,
        c.upgrade_count,
        c.downgrade_count,
        c.is_paid_acquisition,
        c.initial_plan_name,
        c.current_plan_name,
        c.company_size,
        c.is_trial,
        c.converted_from_trial,
        -- Calculate engagement score
        CASE
            WHEN c.upgrade_count > 0 THEN 3
            WHEN c.downgrade_count = 0 AND c.customer_status = 'active_paying' THEN 2
            WHEN c.customer_status = 'active_paying' THEN 1
            ELSE 0
        END AS engagement_score
    FROM dim_customers c
)

SELECT
    initial_plan_name,
    company_size,
    is_paid_acquisition,
    is_trial,
    COUNT(*) AS customers,
    ROUND(AVG(CASE WHEN NOT has_churned THEN 1 ELSE 0 END) * 100, 1) AS retention_rate,
    ROUND(AVG(engagement_score), 2) AS avg_engagement_score,
    ROUND(AVG(CASE WHEN converted_from_trial THEN 1 ELSE 0 END) * 100, 1) AS trial_conversion_rate
FROM customer_behavior
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) >= 10  -- Minimum sample size
ORDER BY retention_rate DESC;
