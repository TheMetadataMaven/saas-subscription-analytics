/*
    Intermediate Model: int_attribution_touchpoints
    
    Description: Marketing attribution analysis with multiple models
    
    Attribution Models Implemented:
    - First Touch: 100% credit to first interaction
    - Last Touch: 100% credit to last interaction before conversion
    - Linear: Equal credit across all touchpoints
    - Time Decay: More credit to touches closer to conversion
    - Position Based (U-Shaped): 40% first, 40% last, 20% distributed to middle
    
    Business Value:
    - Understand which channels initiate customer journeys
    - Identify channels that close deals
    - Optimize marketing spend allocation
*/

WITH touches AS (
    SELECT * FROM {{ ref('stg_marketing_touches') }}
),

channels AS (
    SELECT * FROM {{ ref('marketing_channels') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

subscriptions AS (
    SELECT * FROM {{ ref('stg_subscriptions') }}
),

-- Get first subscription value for each customer
customer_value AS (
    SELECT
        customer_id,
        MIN(start_date) AS first_subscription_date,
        MAX(mrr) AS initial_mrr
    FROM subscriptions
    GROUP BY customer_id
),

-- Enrich touches with channel details
enriched_touches AS (
    SELECT
        t.touch_id,
        t.customer_id,
        t.channel_id,
        ch.channel_name,
        ch.channel_category,
        ch.is_paid,
        ch.typical_cac,
        t.touch_type,
        t.landing_page,
        t.utm_campaign,
        t.touched_at,
        t.touch_date,
        t.converted_at,
        t.conversion_date,
        t.days_to_conversion,
        
        -- Customer context
        c.company_size,
        c.industry,
        cv.initial_mrr,
        
        -- Touchpoint sequence
        ROW_NUMBER() OVER (
            PARTITION BY t.customer_id 
            ORDER BY t.touched_at
        ) AS touch_sequence,
        
        COUNT(*) OVER (
            PARTITION BY t.customer_id
        ) AS total_touches,
        
        -- Time-based calculations
        FIRST_VALUE(t.touched_at) OVER (
            PARTITION BY t.customer_id 
            ORDER BY t.touched_at
        ) AS first_touch_at,
        
        LAST_VALUE(t.touched_at) OVER (
            PARTITION BY t.customer_id 
            ORDER BY t.touched_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_touch_at

    FROM touches t
    LEFT JOIN channels ch ON t.channel_id = ch.channel_id
    LEFT JOIN customers c ON t.customer_id = c.customer_id
    LEFT JOIN customer_value cv ON t.customer_id = cv.customer_id
),

-- Calculate attribution weights
with_attribution AS (
    SELECT
        *,
        
        -- First Touch Attribution
        CASE 
            WHEN touch_sequence = 1 THEN 1.0 
            ELSE 0.0 
        END AS first_touch_weight,
        
        -- Last Touch Attribution
        CASE 
            WHEN touch_sequence = total_touches THEN 1.0 
            ELSE 0.0 
        END AS last_touch_weight,
        
        -- Linear Attribution
        1.0 / NULLIF(total_touches, 0) AS linear_weight,
        
        -- Time Decay Attribution (7-day half-life)
        -- More recent touches get more credit
        CASE 
            WHEN days_to_conversion IS NOT NULL AND days_to_conversion >= 0
            THEN POW(0.5, days_to_conversion / 7.0) / 
                 SUM(POW(0.5, days_to_conversion / 7.0)) OVER (PARTITION BY customer_id)
            ELSE 1.0 / NULLIF(total_touches, 0)
        END AS time_decay_weight,
        
        -- Position Based (U-Shaped): 40% first, 40% last, 20% middle
        CASE
            WHEN total_touches = 1 THEN 1.0
            WHEN total_touches = 2 AND touch_sequence = 1 THEN 0.5
            WHEN total_touches = 2 AND touch_sequence = 2 THEN 0.5
            WHEN touch_sequence = 1 THEN 0.4
            WHEN touch_sequence = total_touches THEN 0.4
            ELSE 0.2 / NULLIF(total_touches - 2, 0)
        END AS position_based_weight,
        
        -- Is this a first/last touch flag
        touch_sequence = 1 AS is_first_touch,
        touch_sequence = total_touches AS is_last_touch

    FROM enriched_touches
),

-- Calculate attributed value
final AS (
    SELECT
        *,
        
        -- Attributed revenue by model
        COALESCE(initial_mrr, 0) * first_touch_weight AS first_touch_revenue,
        COALESCE(initial_mrr, 0) * last_touch_weight AS last_touch_revenue,
        COALESCE(initial_mrr, 0) * linear_weight AS linear_revenue,
        COALESCE(initial_mrr, 0) * time_decay_weight AS time_decay_revenue,
        COALESCE(initial_mrr, 0) * position_based_weight AS position_based_revenue,
        
        -- Journey stage
        CASE
            WHEN touch_sequence = 1 THEN 'awareness'
            WHEN touch_sequence = total_touches THEN 'decision'
            WHEN touch_sequence <= total_touches / 2 THEN 'consideration_early'
            ELSE 'consideration_late'
        END AS journey_stage

    FROM with_attribution
)

SELECT * FROM final
