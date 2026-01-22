/*
    Mart Model: fct_subscription_events
    
    Description: Enriched subscription lifecycle events for analysis
    
    Grain: One row per subscription event
    
    Use Cases:
    - Churn analysis
    - Upgrade/downgrade patterns
    - Customer lifecycle tracking
    - Cohort behavior analysis
*/

WITH history AS (
    SELECT * FROM {{ ref('int_customer_subscription_history') }}
),

channels AS (
    SELECT * FROM {{ ref('marketing_channels') }}
),

final AS (
    SELECT
        -- Event Identifiers
        h.event_id,
        h.subscription_id,
        h.customer_id,
        
        -- Event Details
        h.event_type,
        h.event_category,
        h.event_date,
        h.event_at,
        
        -- Plan Information
        h.plan_id,
        h.plan_name,
        h.plan_tier,
        h.plan_price,
        
        -- Financial Impact
        ROUND(h.mrr_change, 2) AS mrr_change,
        ROUND(h.mrr_after, 2) AS mrr_after,
        ROUND(ABS(h.mrr_change), 2) AS mrr_impact_absolute,
        
        -- Customer Context
        h.company_name,
        h.industry,
        h.company_size,
        h.country,
        h.signup_date,
        h.is_trial,
        
        -- Acquisition Context
        h.acquisition_channel_id,
        ch.channel_name AS acquisition_channel,
        ch.channel_category AS acquisition_channel_category,
        ch.is_paid AS is_paid_acquisition,
        
        -- Tenure Metrics
        h.days_since_signup,
        h.months_since_signup,
        
        -- Tenure Buckets
        CASE
            WHEN h.days_since_signup <= 30 THEN '0-30 days'
            WHEN h.days_since_signup <= 90 THEN '31-90 days'
            WHEN h.days_since_signup <= 180 THEN '91-180 days'
            WHEN h.days_since_signup <= 365 THEN '181-365 days'
            ELSE '365+ days'
        END AS tenure_bucket,
        
        -- Event Sequence
        h.event_sequence,
        h.previous_event_type,
        h.previous_plan_id,
        h.next_event_type,
        h.next_event_date,
        h.days_until_next_event,
        
        -- Lifecycle Flags
        h.is_first_paid_conversion,
        h.has_ever_churned,
        h.has_ever_upgraded,
        
        -- Time Dimensions
        EXTRACT(YEAR FROM h.event_date) AS event_year,
        EXTRACT(MONTH FROM h.event_date) AS event_month,
        EXTRACT(QUARTER FROM h.event_date) AS event_quarter,
        FORMAT_DATE('%Y-%m', h.event_date) AS event_month_key,
        FORMAT_DATE('%Y-Q%Q', h.event_date) AS event_quarter_key,
        FORMAT_DATE('%A', h.event_date) AS event_day_of_week,
        
        -- Cohort Keys
        FORMAT_DATE('%Y-%m', h.signup_date) AS signup_cohort_month,
        FORMAT_DATE('%Y-Q%Q', h.signup_date) AS signup_cohort_quarter,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM history h
    LEFT JOIN channels ch 
        ON h.acquisition_channel_id = ch.channel_id
)

SELECT * FROM final
