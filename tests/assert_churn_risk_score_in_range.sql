/*
    Test: assert_churn_risk_score_in_range

    Validates the integrity of the rpt_churn_risk scorecard:
    1. churn_risk_score is always within 0-100
    2. the risk_band matches the score (no band/score mismatch)

    Any returned row is a failure.
*/

WITH checks AS (
    SELECT
        customer_id,
        churn_risk_score,
        risk_band,

        -- Recompute the band the score should map to.
        CASE
            WHEN churn_risk_score >= 75 THEN 'critical'
            WHEN churn_risk_score >= 50 THEN 'high'
            WHEN churn_risk_score >= 25 THEN 'medium'
            ELSE 'low'
        END AS expected_band
    FROM {{ ref('rpt_churn_risk') }}
)

SELECT
    customer_id,
    churn_risk_score,
    risk_band,
    expected_band
FROM checks
WHERE churn_risk_score < 0
    OR churn_risk_score > 100
    OR risk_band != expected_band
