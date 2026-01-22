/*
    Mart Model: dim_customers
    
    Description: Customer dimension with current state and lifetime metrics
    
    Grain: One row per customer
    
    Use Cases:
    - Customer segmentation
    - LTV analysis
    - Health scoring
    - Account-level dashboards
*/

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

subscriptions AS (
    SELECT * FROM {{ ref('stg_subscriptions') }}
),

events AS (
    SELECT * FROM {{ ref('stg_subscription_events') }}
),

payments AS (
    SELECT * FROM {{ ref('stg_payments') }}
),

channels AS (
    SELECT * FROM {{ ref('marketing_channels') }}
),

plan_tiers AS (
    SELECT * FROM {{ ref('plan_tiers') }}
),

-- Current subscription state
current_subscription AS (
    SELECT
        customer_id,
        subscription_id AS current_subscription_id,
        plan_id AS current_plan_id,
        status AS current_status,
        billing_cycle AS current_billing_cycle,
        mrr AS current_mrr,
        start_date AS current_subscription_start,
        subscription_length_days AS current_subscription_tenure_days
    FROM subscriptions
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY customer_id 
        ORDER BY created_at DESC
    ) = 1
),

-- Subscription history aggregates
subscription_history AS (
    SELECT
        customer_id,
        COUNT(DISTINCT subscription_id) AS total_subscriptions,
        MIN(start_date) AS first_subscription_date,
        MAX(start_date) AS latest_subscription_date,
        SUM(CASE WHEN status = 'churned' THEN 1 ELSE 0 END) AS churn_count
    FROM subscriptions
    GROUP BY customer_id
),

-- Event aggregates
event_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS total_events,
        COUNT(CASE WHEN event_category = 'expansion' THEN 1 END) AS upgrade_count,
        COUNT(CASE WHEN event_category = 'contraction' THEN 1 END) AS downgrade_count,
        COUNT(CASE WHEN event_category = 'churn' THEN 1 END) AS churn_events,
        MAX(CASE WHEN event_category = 'expansion' THEN event_date END) AS last_upgrade_date,
        MAX(CASE WHEN event_category = 'churn' THEN event_date END) AS last_churn_date,
        MAX(mrr_after) AS peak_mrr
    FROM events
    GROUP BY customer_id
),

-- Payment aggregates
payment_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS total_payments,
        COUNT(CASE WHEN is_successful THEN 1 END) AS successful_payments,
        COUNT(CASE WHEN is_failed THEN 1 END) AS failed_payments,
        SUM(CASE WHEN is_successful THEN amount ELSE 0 END) AS lifetime_revenue,
        AVG(CASE WHEN is_successful THEN amount END) AS avg_payment_amount,
        MIN(payment_date) AS first_payment_date,
        MAX(payment_date) AS last_payment_date
    FROM payments
    GROUP BY customer_id
),

final AS (
    SELECT
        -- Customer Identifiers
        c.customer_id,
        c.company_name,
        c.email,
        
        -- Company Attributes
        c.industry,
        c.company_size,
        c.country,
        
        -- Acquisition Attributes
        c.signup_date,
        c.signed_up_at,
        c.acquisition_channel_id,
        ch.channel_name AS acquisition_channel,
        ch.channel_category AS acquisition_channel_category,
        ch.is_paid AS is_paid_acquisition,
        c.initial_plan_id,
        ip.plan_name AS initial_plan_name,
        
        -- Trial Information
        c.is_trial,
        c.trial_end_date,
        CASE
            WHEN c.is_trial AND cs.current_status = 'active' AND cs.current_mrr > 0 
            THEN TRUE
            ELSE FALSE
        END AS converted_from_trial,
        
        -- Current State
        cs.current_subscription_id,
        cs.current_plan_id,
        cp.plan_name AS current_plan_name,
        cp.plan_tier AS current_plan_tier,
        cs.current_status,
        cs.current_billing_cycle,
        ROUND(COALESCE(cs.current_mrr, 0), 2) AS current_mrr,
        ROUND(COALESCE(cs.current_mrr, 0) * 12, 2) AS current_arr,
        cs.current_subscription_start,
        cs.current_subscription_tenure_days,
        
        -- Lifecycle Status
        CASE
            WHEN cs.current_status = 'active' AND cs.current_mrr > 0 THEN 'active_paying'
            WHEN cs.current_status = 'active' AND cs.current_mrr = 0 THEN 'active_free'
            WHEN cs.current_status = 'churned' THEN 'churned'
            ELSE 'unknown'
        END AS customer_status,
        
        -- Tenure Metrics
        DATE_DIFF(CURRENT_DATE(), c.signup_date, DAY) AS days_since_signup,
        DATE_DIFF(CURRENT_DATE(), c.signup_date, MONTH) AS months_since_signup,
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), c.signup_date, DAY) <= 30 THEN '0-30 days'
            WHEN DATE_DIFF(CURRENT_DATE(), c.signup_date, DAY) <= 90 THEN '31-90 days'
            WHEN DATE_DIFF(CURRENT_DATE(), c.signup_date, DAY) <= 180 THEN '91-180 days'
            WHEN DATE_DIFF(CURRENT_DATE(), c.signup_date, DAY) <= 365 THEN '181-365 days'
            ELSE '365+ days'
        END AS tenure_bucket,
        
        -- Subscription History
        COALESCE(sh.total_subscriptions, 0) AS total_subscriptions,
        sh.first_subscription_date,
        sh.latest_subscription_date,
        COALESCE(sh.churn_count, 0) AS times_churned,
        sh.churn_count > 0 AS has_churned,
        sh.churn_count > 0 AND cs.current_status = 'active' AS is_resurrected,
        
        -- Event Metrics
        COALESCE(em.total_events, 0) AS total_events,
        COALESCE(em.upgrade_count, 0) AS upgrade_count,
        COALESCE(em.downgrade_count, 0) AS downgrade_count,
        em.last_upgrade_date,
        em.last_churn_date,
        ROUND(COALESCE(em.peak_mrr, 0), 2) AS peak_mrr,
        
        -- Payment Metrics
        COALESCE(pm.total_payments, 0) AS total_payments,
        COALESCE(pm.successful_payments, 0) AS successful_payments,
        COALESCE(pm.failed_payments, 0) AS failed_payments,
        ROUND(COALESCE(pm.lifetime_revenue, 0), 2) AS lifetime_revenue,
        ROUND(COALESCE(pm.avg_payment_amount, 0), 2) AS avg_payment_amount,
        pm.first_payment_date,
        pm.last_payment_date,
        
        -- Payment Health
        ROUND(
            SAFE_DIVIDE(pm.successful_payments, pm.total_payments) * 100, 
            2
        ) AS payment_success_rate,
        
        -- Cohort Keys
        FORMAT_DATE('%Y-%m', c.signup_date) AS signup_cohort_month,
        FORMAT_DATE('%Y-Q%Q', c.signup_date) AS signup_cohort_quarter,
        EXTRACT(YEAR FROM c.signup_date) AS signup_year,
        
        -- Health Indicators
        CASE
            WHEN cs.current_status = 'churned' THEN 'churned'
            WHEN em.downgrade_count > em.upgrade_count THEN 'at_risk'
            WHEN pm.failed_payments > 0 AND pm.failed_payments >= pm.successful_payments * 0.1 THEN 'at_risk'
            WHEN em.upgrade_count > 0 THEN 'healthy'
            WHEN DATE_DIFF(CURRENT_DATE(), pm.last_payment_date, DAY) > 45 THEN 'at_risk'
            ELSE 'stable'
        END AS health_status,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM customers c
    LEFT JOIN current_subscription cs ON c.customer_id = cs.customer_id
    LEFT JOIN subscription_history sh ON c.customer_id = sh.customer_id
    LEFT JOIN event_metrics em ON c.customer_id = em.customer_id
    LEFT JOIN payment_metrics pm ON c.customer_id = pm.customer_id
    LEFT JOIN channels ch ON c.acquisition_channel_id = ch.channel_id
    LEFT JOIN plan_tiers ip ON c.initial_plan_id = ip.plan_id
    LEFT JOIN plan_tiers cp ON cs.current_plan_id = cp.plan_id
)

SELECT * FROM final
