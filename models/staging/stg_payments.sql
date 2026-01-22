/*
    Staging Model: stg_payments
    
    Source: raw.payments
    Description: Cleaned payment transaction data
    
    Transformations:
    - Standardize payment status and method values
    - Cast amounts to appropriate numeric precision
    - Add payment success flags
*/

WITH source AS (
    SELECT * FROM {{ source('raw', 'payments') }}
),

cleaned AS (
    SELECT
        -- Primary Key
        payment_id,
        
        -- Foreign Keys
        subscription_id,
        customer_id,
        
        -- Payment Details
        CAST(amount AS NUMERIC) AS amount,
        UPPER(TRIM(currency)) AS currency,
        LOWER(TRIM(payment_method)) AS payment_method,
        LOWER(TRIM(status)) AS status,
        
        -- Status Flags
        CASE 
            WHEN LOWER(TRIM(status)) = 'succeeded' THEN TRUE
            ELSE FALSE
        END AS is_successful,
        
        CASE 
            WHEN LOWER(TRIM(status)) = 'failed' THEN TRUE
            ELSE FALSE
        END AS is_failed,
        
        -- Dates
        SAFE.PARSE_DATE('%Y-%m-%d', payment_date) AS payment_date,
        FORMAT_DATE('%Y-%m', SAFE.PARSE_DATE('%Y-%m-%d', payment_date)) AS payment_month_key,
        
        -- Timestamps
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', created_at) AS created_at,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _loaded_at

    FROM source
    WHERE payment_id IS NOT NULL
)

SELECT * FROM cleaned
