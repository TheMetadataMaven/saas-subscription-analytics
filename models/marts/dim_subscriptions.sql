/*
    Mart Model: dim_subscriptions
    
    Description: Subscription dimension with plan details and lifecycle state
    
    Grain: One row per subscription
    
    Use Cases:
    - Subscription mix analysis
    - Plan performance reporting
    - Billing cycle analysis
    - Revenue forecasting
*/

WITH subscriptions AS (
    SELECT * FROM {{ ref('stg_subscriptions') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

plan_tiers AS (
    SELECT * FROM {{ ref('plan_tiers') }}
),

events AS (
    SELECT * FROM {{ ref('stg_subscription_events') }}
),

-- Get event counts per subscription
subscription_events AS (
    SELECT
        subscription_id,
        COUNT(*) AS total_events,
        MIN(event_at) AS first_event_at,
        MAX(event_at) AS last_event_at,
        COUNT(CASE WHEN event_category = 'expansion' THEN 1 END) AS upgrade_count,
        COUNT(CASE WHEN event_category = 'contraction' THEN 1 END) AS downgrade_count
    FROM events
    GROUP BY subscription_id
),

final AS (
    SELECT
        -- Subscription Identifiers
        s.subscription_id,
        s.customer_id,
        
        -- Customer Context
        c.company_name,
        c.industry,
        c.company_size,
        c.country,
        
        -- Plan Details
        s.plan_id,
        p.plan_name,
        p.plan_tier,
        p.monthly_price AS plan_monthly_price,
        p.annual_price AS plan_annual_price,
        p.storage_gb AS plan_storage_gb,
        p.max_users AS plan_max_users,
        
        -- Subscription State
        s.status,
        s.billing_cycle,
        ROUND(s.mrr, 2) AS mrr,
        ROUND(s.mrr * 12, 2) AS arr,
        
        -- Effective Price (accounting for billing cycle)
        CASE
            WHEN s.billing_cycle = 'annual' 
            THEN ROUND(p.annual_price / 12, 2)
            ELSE p.monthly_price
        END AS effective_monthly_price,
        
        -- Discount indicator
        CASE
            WHEN s.billing_cycle = 'annual' 
            THEN ROUND((1 - (p.annual_price / 12) / NULLIF(p.monthly_price, 0)) * 100, 1)
            ELSE 0
        END AS annual_discount_pct,
        
        -- Dates
        s.start_date,
        s.end_date,
        s.created_at,
        s.updated_at,
        
        -- Duration Metrics
        s.subscription_length_days,
        ROUND(s.subscription_length_days / 30.44, 1) AS subscription_length_months,
        
        -- Duration Buckets
        CASE
            WHEN s.subscription_length_days <= 30 THEN '0-1 month'
            WHEN s.subscription_length_days <= 90 THEN '1-3 months'
            WHEN s.subscription_length_days <= 180 THEN '3-6 months'
            WHEN s.subscription_length_days <= 365 THEN '6-12 months'
            ELSE '12+ months'
        END AS tenure_bucket,
        
        -- Event Metrics
        COALESCE(se.total_events, 0) AS total_events,
        COALESCE(se.upgrade_count, 0) AS upgrade_count,
        COALESCE(se.downgrade_count, 0) AS downgrade_count,
        se.first_event_at,
        se.last_event_at,
        
        -- Status Flags
        s.status = 'active' AS is_active,
        s.status = 'churned' AS is_churned,
        s.billing_cycle = 'annual' AS is_annual,
        s.mrr > 0 AS is_paying,
        p.plan_tier = 'free' AS is_free_tier,
        p.plan_tier = 'enterprise' AS is_enterprise,
        
        -- Cohort Keys
        FORMAT_DATE('%Y-%m', s.start_date) AS subscription_cohort_month,
        FORMAT_DATE('%Y-Q%Q', s.start_date) AS subscription_cohort_quarter,
        
        -- Churn Analysis
        CASE
            WHEN s.status = 'churned' AND s.subscription_length_days <= 30 THEN 'early_churn'
            WHEN s.status = 'churned' AND s.subscription_length_days <= 90 THEN 'standard_churn'
            WHEN s.status = 'churned' THEN 'late_churn'
            ELSE NULL
        END AS churn_timing,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM subscriptions s
    LEFT JOIN customers c ON s.customer_id = c.customer_id
    LEFT JOIN plan_tiers p ON s.plan_id = p.plan_id
    LEFT JOIN subscription_events se ON s.subscription_id = se.subscription_id
)

SELECT * FROM final
