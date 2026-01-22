/*
    Intermediate Model: int_customer_subscription_history
    
    Description: Complete customer subscription journey with timeline
    
    Business Logic:
    - Joins customer data with subscription events
    - Calculates customer tenure at each event
    - Tracks plan progression over time
    - Identifies key lifecycle milestones
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

plan_tiers AS (
    SELECT * FROM {{ ref('plan_tiers') }}
),

-- Build customer timeline with all events
customer_events AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.industry,
        c.company_size,
        c.country,
        c.signup_date,
        c.acquisition_channel_id,
        c.is_trial,
        
        e.event_id,
        e.subscription_id,
        e.event_type,
        e.event_category,
        e.event_date,
        e.event_at,
        e.plan_id,
        e.mrr_change,
        e.mrr_after,
        
        -- Plan details at time of event
        p.plan_name,
        p.plan_tier,
        p.monthly_price AS plan_price,
        
        -- Calculate tenure at time of event
        DATE_DIFF(e.event_date, c.signup_date, DAY) AS days_since_signup,
        DATE_DIFF(e.event_date, c.signup_date, MONTH) AS months_since_signup,
        
        -- Event sequence
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY e.event_at
        ) AS event_sequence,
        
        -- Previous and next events for context
        LAG(e.event_type) OVER (
            PARTITION BY c.customer_id 
            ORDER BY e.event_at
        ) AS previous_event_type,
        
        LAG(e.plan_id) OVER (
            PARTITION BY c.customer_id 
            ORDER BY e.event_at
        ) AS previous_plan_id,
        
        LEAD(e.event_type) OVER (
            PARTITION BY c.customer_id 
            ORDER BY e.event_at
        ) AS next_event_type,
        
        LEAD(e.event_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY e.event_at
        ) AS next_event_date

    FROM customers c
    INNER JOIN events e 
        ON c.customer_id = e.customer_id
    LEFT JOIN plan_tiers p 
        ON e.plan_id = p.plan_id
),

-- Add lifecycle stage flags
with_lifecycle_flags AS (
    SELECT
        *,
        
        -- First paid conversion (excluding free tier starts)
        CASE 
            WHEN event_sequence = 1 
                AND event_category = 'acquisition' 
                AND plan_id > 1 
            THEN TRUE
            WHEN event_sequence = 2 
                AND previous_plan_id = 1 
                AND plan_id > 1 
            THEN TRUE
            ELSE FALSE
        END AS is_first_paid_conversion,
        
        -- Identify if customer has ever churned
        MAX(CASE WHEN event_category = 'churn' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id
        ) AS has_ever_churned,
        
        -- Identify if customer has ever upgraded
        MAX(CASE WHEN event_category = 'expansion' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id
        ) AS has_ever_upgraded,
        
        -- Days until next event (for tenure analysis)
        DATE_DIFF(next_event_date, event_date, DAY) AS days_until_next_event

    FROM customer_events
)

SELECT * FROM with_lifecycle_flags
