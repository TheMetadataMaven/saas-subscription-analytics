/*
    Report Model: rpt_cohort_retention
    
    Description: Pre-aggregated cohort retention matrix
    
    Grain: One row per cohort-month combination
    
    Use Cases:
    - Retention heatmaps in dashboards
    - Cohort comparison analysis
    - Retention trend tracking
    - LTV modeling inputs
    
    Output Structure:
    - Rows: Signup cohort months
    - Columns: Months since signup (M0, M1, M2, ... M12+)
    - Values: Retention rate, active customers, MRR retained
*/

WITH customers AS (
    SELECT 
        customer_id,
        signup_date,
        DATE_TRUNC(signup_date, MONTH) AS cohort_month
    FROM {{ ref('stg_customers') }}
),

mrr_movements AS (
    SELECT * FROM {{ ref('int_mrr_movements') }}
),

-- Get cohort sizes
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customers
    GROUP BY cohort_month
),

-- Get monthly activity per customer with cohort context
customer_monthly_activity AS (
    SELECT
        m.customer_id,
        c.cohort_month,
        m.month_date AS activity_month,
        DATE_DIFF(m.month_date, c.cohort_month, MONTH) AS months_since_signup,
        m.ending_mrr,
        m.ending_mrr > 0 AS is_active
    FROM mrr_movements m
    INNER JOIN customers c ON m.customer_id = c.customer_id
    WHERE m.ending_mrr > 0  -- Only count months where customer had MRR
),

-- Aggregate retention by cohort and period
cohort_retention_raw AS (
    SELECT
        cohort_month,
        months_since_signup,
        COUNT(DISTINCT customer_id) AS active_customers,
        SUM(ending_mrr) AS total_mrr,
        AVG(ending_mrr) AS avg_mrr
    FROM customer_monthly_activity
    WHERE months_since_signup >= 0
        AND months_since_signup <= 24  -- Cap at 24 months
    GROUP BY cohort_month, months_since_signup
),

-- Join with cohort sizes and calculate retention
cohort_retention AS (
    SELECT
        cr.cohort_month,
        FORMAT_DATE('%Y-%m', cr.cohort_month) AS cohort_month_key,
        FORMAT_DATE('%b %Y', cr.cohort_month) AS cohort_month_name,
        cr.months_since_signup,
        CONCAT('M', cr.months_since_signup) AS period_label,
        cs.cohort_size,
        cr.active_customers,
        
        -- Retention Rates
        ROUND(cr.active_customers / cs.cohort_size * 100, 1) AS retention_rate,
        
        -- MRR Metrics
        ROUND(cr.total_mrr, 2) AS retained_mrr,
        ROUND(cr.avg_mrr, 2) AS avg_mrr_per_customer,
        
        -- Comparison to M0
        FIRST_VALUE(cr.active_customers) OVER (
            PARTITION BY cr.cohort_month 
            ORDER BY cr.months_since_signup
        ) AS m0_customers,
        
        FIRST_VALUE(cr.total_mrr) OVER (
            PARTITION BY cr.cohort_month 
            ORDER BY cr.months_since_signup
        ) AS m0_mrr

    FROM cohort_retention_raw cr
    INNER JOIN cohort_sizes cs ON cr.cohort_month = cs.cohort_month
),

-- Add derived metrics
final AS (
    SELECT
        cohort_month,
        cohort_month_key,
        cohort_month_name,
        months_since_signup,
        period_label,
        cohort_size,
        active_customers,
        retention_rate,
        retained_mrr,
        avg_mrr_per_customer,
        
        -- Retention relative to M0 (not cohort size)
        ROUND(active_customers / NULLIF(m0_customers, 0) * 100, 1) AS retention_from_m0,
        
        -- MRR Retention (Net Revenue Retention approximation)
        ROUND(retained_mrr / NULLIF(m0_mrr, 0) * 100, 1) AS mrr_retention_from_m0,
        
        -- Churn at this period
        cohort_size - active_customers AS churned_customers,
        ROUND((cohort_size - active_customers) / cohort_size * 100, 1) AS cumulative_churn_rate,
        
        -- Period-over-period change
        LAG(active_customers) OVER (
            PARTITION BY cohort_month 
            ORDER BY months_since_signup
        ) AS previous_period_customers,
        
        active_customers - LAG(active_customers) OVER (
            PARTITION BY cohort_month 
            ORDER BY months_since_signup
        ) AS customers_change,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM cohort_retention
)

SELECT * FROM final
ORDER BY cohort_month DESC, months_since_signup
