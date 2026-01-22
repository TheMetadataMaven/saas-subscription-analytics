/*
    Test: assert_mrr_movements_balance
    
    Validates that MRR movements sum correctly:
    ending_mrr = beginning_mrr + new + expansion - contraction - churned
    
    This test ensures data integrity in MRR calculations.
*/

WITH mrr_check AS (
    SELECT
        month_date,
        ending_mrr,
        COALESCE(LAG(ending_mrr) OVER (ORDER BY month_date), 0) AS calculated_beginning,
        new_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        
        -- Calculate expected ending MRR
        COALESCE(LAG(ending_mrr) OVER (ORDER BY month_date), 0) 
            + new_mrr 
            + expansion_mrr 
            - contraction_mrr 
            - churned_mrr AS expected_ending_mrr
    FROM {{ ref('fct_mrr') }}
)

SELECT
    month_date,
    ending_mrr,
    expected_ending_mrr,
    ABS(ending_mrr - expected_ending_mrr) AS variance
FROM mrr_check
WHERE ABS(ending_mrr - expected_ending_mrr) > 0.01  -- Allow for small rounding differences
