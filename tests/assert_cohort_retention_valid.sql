/*
    Test: assert_cohort_retention_valid
    
    Validates cohort retention logic:
    1. M0 retention should always be 100% (or close to it)
    2. Retention should never exceed 100% for customer counts
    3. Active customers should never exceed cohort size
*/

SELECT
    cohort_month,
    months_since_signup,
    cohort_size,
    active_customers,
    retention_rate
FROM {{ ref('rpt_cohort_retention') }}
WHERE 
    -- M0 should be ~100%
    (months_since_signup = 0 AND retention_rate < 95)
    -- Customer retention can't exceed 100%
    OR retention_rate > 100
    -- Active customers can't exceed cohort
    OR active_customers > cohort_size
    -- Negative values indicate data issues
    OR active_customers < 0
    OR retention_rate < 0
