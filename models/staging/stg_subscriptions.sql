/*
    Staging Model: stg_subscriptions
    
    Source: raw.subscriptions
    Description: Cleaned and standardized subscription data
    
    Transformations:
    - Standardize status values
    - Cast monetary values to appropriate precision
    - Parse dates consistently
*/

WITH source AS (
    SELECT * FROM {{ source('raw', 'subscriptions') }}
),

cleaned AS (
    SELECT
        -- Primary Key
        subscription_id,
        
        -- Foreign Keys
        customer_id,
        CAST(plan_id AS INT64) AS plan_id,
        
        -- Subscription Details
        LOWER(TRIM(status)) AS status,
        LOWER(TRIM(billing_cycle)) AS billing_cycle,
        
        -- Financial
        CAST(mrr AS NUMERIC) AS mrr,
        
        -- Dates
        SAFE.PARSE_DATE('%Y-%m-%d', start_date) AS start_date,
        SAFE.PARSE_DATE('%Y-%m-%d', end_date) AS end_date,
        
        -- Calculated Fields
        CASE 
            WHEN end_date IS NOT NULL 
            THEN DATE_DIFF(
                SAFE.PARSE_DATE('%Y-%m-%d', end_date),
                SAFE.PARSE_DATE('%Y-%m-%d', start_date),
                DAY
            )
            ELSE DATE_DIFF(
                CURRENT_DATE(),
                SAFE.PARSE_DATE('%Y-%m-%d', start_date),
                DAY
            )
        END AS subscription_length_days,
        
        -- Timestamps
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created_at) AS created_at,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', updated_at) AS updated_at,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at

    FROM source
    WHERE subscription_id IS NOT NULL
)

SELECT * FROM cleaned
