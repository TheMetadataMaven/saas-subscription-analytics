/*
    Mart Model: fct_mrr
    
    Description: Monthly MRR fact table with complete movement breakdown
    
    Grain: One row per month
    
    Use Cases:
    - Executive MRR dashboards
    - Monthly financial reporting
    - Growth trend analysis
    - Net revenue retention calculations
*/

WITH mrr_movements AS (
    SELECT * FROM {{ ref('int_mrr_movements') }}
),

-- Aggregate to monthly level
monthly_mrr AS (
    SELECT
        month_date,
        month_key,
        
        -- Customer Counts
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(DISTINCT CASE WHEN ending_mrr > 0 THEN customer_id END) AS active_customers,
        COUNT(DISTINCT CASE WHEN movement_type = 'new' THEN customer_id END) AS new_customers,
        COUNT(DISTINCT CASE WHEN movement_type = 'churn' THEN customer_id END) AS churned_customers,
        COUNT(DISTINCT CASE WHEN movement_type = 'resurrection' THEN customer_id END) AS resurrected_customers,
        COUNT(DISTINCT CASE WHEN movement_type = 'expansion' THEN customer_id END) AS expanded_customers,
        COUNT(DISTINCT CASE WHEN movement_type = 'contraction' THEN customer_id END) AS contracted_customers,
        
        -- MRR Totals
        SUM(ending_mrr) AS ending_mrr,
        SUM(CASE WHEN movement_type != 'churn' THEN ending_mrr ELSE 0 END) AS active_mrr,
        
        -- MRR Movements
        SUM(new_mrr) AS new_mrr,
        SUM(expansion_mrr) AS expansion_mrr,
        SUM(contraction_mrr) AS contraction_mrr,
        SUM(churned_mrr) AS churned_mrr,
        
        -- Net Calculations
        SUM(new_mrr) + SUM(expansion_mrr) AS gross_new_mrr,
        SUM(contraction_mrr) + SUM(churned_mrr) AS gross_lost_mrr,
        SUM(new_mrr) + SUM(expansion_mrr) - SUM(contraction_mrr) - SUM(churned_mrr) AS net_new_mrr

    FROM mrr_movements
    GROUP BY month_date, month_key
),

-- Add previous month for calculations
with_previous AS (
    SELECT
        *,
        
        LAG(ending_mrr) OVER (ORDER BY month_date) AS previous_month_mrr,
        LAG(active_customers) OVER (ORDER BY month_date) AS previous_month_customers,
        
        -- Running totals
        SUM(new_mrr) OVER (ORDER BY month_date) AS cumulative_new_mrr,
        SUM(churned_mrr) OVER (ORDER BY month_date) AS cumulative_churned_mrr

    FROM monthly_mrr
),

-- Calculate key SaaS metrics
final AS (
    SELECT
        month_date,
        month_key,
        
        -- Customer Metrics
        total_customers,
        active_customers,
        new_customers,
        churned_customers,
        resurrected_customers,
        expanded_customers,
        contracted_customers,
        
        -- MRR Metrics
        ROUND(ending_mrr, 2) AS ending_mrr,
        ROUND(active_mrr, 2) AS active_mrr,
        ROUND(new_mrr, 2) AS new_mrr,
        ROUND(expansion_mrr, 2) AS expansion_mrr,
        ROUND(contraction_mrr, 2) AS contraction_mrr,
        ROUND(churned_mrr, 2) AS churned_mrr,
        ROUND(gross_new_mrr, 2) AS gross_new_mrr,
        ROUND(gross_lost_mrr, 2) AS gross_lost_mrr,
        ROUND(net_new_mrr, 2) AS net_new_mrr,
        
        -- Growth Rates
        ROUND(
            SAFE_DIVIDE(ending_mrr - previous_month_mrr, previous_month_mrr) * 100, 
            2
        ) AS mrr_growth_rate_pct,
        
        ROUND(
            SAFE_DIVIDE(active_customers - previous_month_customers, previous_month_customers) * 100,
            2
        ) AS customer_growth_rate_pct,
        
        -- Churn Rates
        ROUND(
            SAFE_DIVIDE(churned_mrr, previous_month_mrr) * 100,
            2
        ) AS gross_mrr_churn_rate_pct,
        
        ROUND(
            SAFE_DIVIDE(churned_customers, previous_month_customers) * 100,
            2
        ) AS gross_customer_churn_rate_pct,
        
        -- Net Revenue Retention (NRR)
        ROUND(
            SAFE_DIVIDE(
                previous_month_mrr + expansion_mrr - contraction_mrr - churned_mrr,
                previous_month_mrr
            ) * 100,
            2
        ) AS net_revenue_retention_pct,
        
        -- Quick Ratio (Growth Efficiency)
        ROUND(
            SAFE_DIVIDE(
                new_mrr + expansion_mrr,
                contraction_mrr + churned_mrr
            ),
            2
        ) AS quick_ratio,
        
        -- Average Revenue Per Customer
        ROUND(
            SAFE_DIVIDE(active_mrr, active_customers),
            2
        ) AS arpc,
        
        -- Running Totals
        ROUND(cumulative_new_mrr, 2) AS cumulative_new_mrr,
        ROUND(cumulative_churned_mrr, 2) AS cumulative_churned_mrr,
        
        -- ARR Metrics (MRR * 12)
        ROUND(active_mrr * 12, 2) AS arr,
        ROUND(net_new_mrr * 12, 2) AS net_new_arr,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM with_previous
)

SELECT * FROM final
ORDER BY month_date
