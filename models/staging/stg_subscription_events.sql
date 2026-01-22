/*
    Staging Model: stg_subscription_events
    
    Source: raw.subscription_events
    Description: Cleaned subscription lifecycle events
    
    Transformations:
    - Standardize event type names
    - Parse timestamps
    - Validate MRR values
*/

WITH source AS (
    SELECT * FROM {{ source('raw', 'subscription_events') }}
),

cleaned AS (
    SELECT
        -- Primary Key
        event_id,
        
        -- Foreign Keys
        subscription_id,
        customer_id,
        CAST(plan_id AS INT64) AS plan_id,
        
        -- Event Details
        LOWER(TRIM(event_type)) AS event_type,
        
        -- Categorize event types for analysis
        CASE LOWER(TRIM(event_type))
            WHEN 'subscription_started' THEN 'acquisition'
            WHEN 'subscription_reactivated' THEN 'acquisition'
            WHEN 'subscription_upgraded' THEN 'expansion'
            WHEN 'subscription_downgraded' THEN 'contraction'
            WHEN 'subscription_churned' THEN 'churn'
            ELSE 'other'
        END AS event_category,
        
        -- Financial Impact
        CAST(mrr_change AS NUMERIC) AS mrr_change,
        CAST(mrr_after AS NUMERIC) AS mrr_after,
        
        -- Timestamps
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', event_date) AS event_at,
        DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', event_date)) AS event_date,
        
        -- Time components for analysis
        EXTRACT(YEAR FROM SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', event_date)) AS event_year,
        EXTRACT(MONTH FROM SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', event_date)) AS event_month,
        FORMAT_DATE('%Y-%m', DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', event_date))) AS event_month_key,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at

    FROM source
    WHERE event_id IS NOT NULL
)

SELECT * FROM cleaned
