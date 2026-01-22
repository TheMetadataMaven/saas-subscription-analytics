/*
    Intermediate Model: int_mrr_movements
    
    Description: Monthly MRR tracking with movement categorization
    
    Business Logic:
    - Calculates MRR at customer level by month
    - Categorizes MRR movements (new, expansion, contraction, churn, resurrection)
    - Tracks beginning and ending MRR for each customer-month
    
    Key SaaS Metric Definitions:
    - New MRR: First-time subscription revenue
    - Expansion MRR: Revenue increase from existing customers
    - Contraction MRR: Revenue decrease from existing customers (excluding churn)
    - Churned MRR: Revenue lost from customer cancellations
    - Resurrection MRR: Revenue from previously churned customers returning
*/

WITH events AS (
    SELECT * FROM {{ ref('stg_subscription_events') }}
),

-- Generate month spine for complete timeline
month_spine AS (
    SELECT DISTINCT 
        DATE_TRUNC(event_date, MONTH) AS month_date,
        FORMAT_DATE('%Y-%m', event_date) AS month_key
    FROM events
),

-- Get MRR state at end of each month per customer
customer_monthly_mrr AS (
    SELECT
        customer_id,
        DATE_TRUNC(event_date, MONTH) AS month_date,
        
        -- Get the last MRR value for the month
        LAST_VALUE(mrr_after) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
            ORDER BY event_at
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS ending_mrr,
        
        -- Sum of positive changes (new + expansion)
        SUM(CASE WHEN mrr_change > 0 THEN mrr_change ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS gross_positive_mrr,
        
        -- Sum of negative changes (contraction + churn)
        SUM(CASE WHEN mrr_change < 0 THEN ABS(mrr_change) ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS gross_negative_mrr,
        
        -- Track event types in month
        MAX(CASE WHEN event_category = 'acquisition' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS had_acquisition,
        
        MAX(CASE WHEN event_category = 'expansion' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS had_expansion,
        
        MAX(CASE WHEN event_category = 'contraction' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS had_contraction,
        
        MAX(CASE WHEN event_category = 'churn' THEN 1 ELSE 0 END) OVER (
            PARTITION BY customer_id, DATE_TRUNC(event_date, MONTH)
        ) AS had_churn

    FROM events
),

-- Deduplicate to one row per customer-month
customer_month_unique AS (
    SELECT DISTINCT
        customer_id,
        month_date,
        ending_mrr,
        gross_positive_mrr,
        gross_negative_mrr,
        had_acquisition,
        had_expansion,
        had_contraction,
        had_churn
    FROM customer_monthly_mrr
),

-- Add previous month context
with_previous_month AS (
    SELECT
        *,
        
        LAG(ending_mrr, 1) OVER (
            PARTITION BY customer_id 
            ORDER BY month_date
        ) AS previous_month_mrr,
        
        LAG(month_date, 1) OVER (
            PARTITION BY customer_id 
            ORDER BY month_date
        ) AS previous_active_month,
        
        -- Check if this is first month ever
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY month_date
        ) AS customer_month_number
        
    FROM customer_month_unique
),

-- Categorize MRR movements
mrr_movements AS (
    SELECT
        customer_id,
        month_date,
        FORMAT_DATE('%Y-%m', month_date) AS month_key,
        
        -- MRR States
        COALESCE(previous_month_mrr, 0) AS beginning_mrr,
        ending_mrr,
        ending_mrr - COALESCE(previous_month_mrr, 0) AS net_mrr_change,
        
        -- Movement Categories
        CASE
            -- New: First time this customer has MRR
            WHEN customer_month_number = 1 AND ending_mrr > 0 
            THEN ending_mrr
            -- Resurrection: Customer had churned (previous MRR = 0 or gap in months) and is back
            WHEN COALESCE(previous_month_mrr, 0) = 0 
                AND ending_mrr > 0 
                AND customer_month_number > 1
            THEN ending_mrr
            ELSE 0
        END AS new_mrr,
        
        CASE
            -- Expansion: MRR increased for existing customer
            WHEN previous_month_mrr > 0 
                AND ending_mrr > previous_month_mrr 
            THEN ending_mrr - previous_month_mrr
            ELSE 0
        END AS expansion_mrr,
        
        CASE
            -- Contraction: MRR decreased but customer still active
            WHEN previous_month_mrr > 0 
                AND ending_mrr < previous_month_mrr 
                AND ending_mrr > 0
            THEN previous_month_mrr - ending_mrr
            ELSE 0
        END AS contraction_mrr,
        
        CASE
            -- Churn: Customer went to $0 MRR
            WHEN COALESCE(previous_month_mrr, 0) > 0 
                AND ending_mrr = 0
            THEN previous_month_mrr
            ELSE 0
        END AS churned_mrr,
        
        -- Movement type classification
        CASE
            WHEN customer_month_number = 1 AND ending_mrr > 0 THEN 'new'
            WHEN COALESCE(previous_month_mrr, 0) = 0 AND ending_mrr > 0 AND customer_month_number > 1 THEN 'resurrection'
            WHEN previous_month_mrr > 0 AND ending_mrr > previous_month_mrr THEN 'expansion'
            WHEN previous_month_mrr > 0 AND ending_mrr < previous_month_mrr AND ending_mrr > 0 THEN 'contraction'
            WHEN COALESCE(previous_month_mrr, 0) > 0 AND ending_mrr = 0 THEN 'churn'
            ELSE 'unchanged'
        END AS movement_type,
        
        -- Flags
        had_acquisition,
        had_expansion,
        had_contraction,
        had_churn,
        customer_month_number

    FROM with_previous_month
)

SELECT * FROM mrr_movements
