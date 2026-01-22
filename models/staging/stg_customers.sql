/*
    Staging Model: stg_customers
    
    Source: raw.customers
    Description: Cleaned and standardized customer data
    
    Transformations:
    - Standardize column names to snake_case
    - Cast data types appropriately
    - Parse dates from strings
    - Add source tracking metadata
*/

WITH source AS (
    SELECT * FROM {{ source('raw', 'customers') }}
),

cleaned AS (
    SELECT
        -- Primary Key
        customer_id,
        
        -- Company Information
        company_name,
        UPPER(TRIM(industry)) AS industry,
        company_size,
        UPPER(TRIM(country)) AS country,
        
        -- Contact Information
        LOWER(TRIM(email)) AS email,
        
        -- Acquisition Information
        CAST(acquisition_channel_id AS INT64) AS acquisition_channel_id,
        CAST(initial_plan_id AS INT64) AS initial_plan_id,
        
        -- Trial Information
        CASE 
            WHEN LOWER(is_trial) IN ('true', '1', 'yes') THEN TRUE
            WHEN LOWER(is_trial) IN ('false', '0', 'no') THEN FALSE
            ELSE NULL
        END AS is_trial,
        SAFE.PARSE_DATE('%Y-%m-%d', trial_end_date) AS trial_end_date,
        
        -- Timestamps
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', signup_date) AS signed_up_at,
        DATE(SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', signup_date)) AS signup_date,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at

    FROM source
    WHERE customer_id IS NOT NULL
)

SELECT * FROM cleaned
