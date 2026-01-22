/*
    Staging Model: stg_marketing_touches
    
    Source: raw.marketing_touches
    Description: Cleaned marketing touchpoint data for attribution analysis
    
    Transformations:
    - Standardize channel and touch type values
    - Parse timestamps
    - Calculate time to conversion
*/

WITH source AS (
    SELECT * FROM {{ source('raw', 'marketing_touches') }}
),

cleaned AS (
    SELECT
        -- Primary Key
        touch_id,
        
        -- Foreign Keys
        customer_id,
        CAST(channel_id AS INT64) AS channel_id,
        
        -- Touch Details
        LOWER(TRIM(touch_type)) AS touch_type,
        LOWER(TRIM(landing_page)) AS landing_page,
        NULLIF(TRIM(utm_campaign), '') AS utm_campaign,
        
        -- Timestamps
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', touch_date) AS touched_at,
        DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', touch_date)) AS touch_date,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversion_date) AS converted_at,
        DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversion_date)) AS conversion_date,
        
        -- Time to Conversion
        TIMESTAMP_DIFF(
            SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversion_date),
            SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', touch_date),
            DAY
        ) AS days_to_conversion,
        
        TIMESTAMP_DIFF(
            SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversion_date),
            SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', touch_date),
            HOUR
        ) AS hours_to_conversion,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at

    FROM source
    WHERE touch_id IS NOT NULL
)

SELECT * FROM cleaned
