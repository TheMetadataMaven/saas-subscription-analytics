/*
    Report Model: rpt_churn_risk

    Description: Customer-level churn-risk scorecard for active customers.
                 A transparent, rules-based alternative to a black-box ML model:
                 each customer accrues weighted points across leading churn
                 indicators, producing a 0-100 risk score and a risk band.

    Grain: One row per active customer (active_paying or active_free)

    Use Cases:
    - Customer Success "save" prioritization (work the highest scores first)
    - Churn Analysis dashboard (risk distribution, MRR at risk by band)
    - Leading-indicator monitoring before churn shows up in fct_mrr

    Scoring (additive, capped at 100):
    - Payment failures        up to 25 pts   (failed payments erode trust/access)
    - Stale payment           up to 20 pts   (no successful payment in 45/60+ days)
    - Net downgrade behavior  up to 15 pts   (more downgrades than upgrades)
    - MRR erosion from peak   up to 20 pts   (current_mrr well below peak_mrr)
    - Prior churn history     up to 10 pts   (previously churned / resurrected)
    - Early-tenure fragility  up to 10 pts   (first 90 days carry elevated risk)

    Risk bands: low (0-24), medium (25-49), high (50-74), critical (75-100)
*/

WITH customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

-- Only active customers can churn; churned accounts are excluded.
active_customers AS (
    SELECT *
    FROM customers
    WHERE customer_status IN ('active_paying', 'active_free')
),

-- Translate raw attributes into normalized risk components.
risk_components AS (
    SELECT
        customer_id,
        company_name,
        industry,
        company_size,
        acquisition_channel,
        current_plan_tier,
        customer_status,
        current_mrr,
        current_arr,
        peak_mrr,
        days_since_signup,
        months_since_signup,
        tenure_bucket,
        signup_cohort_month,
        health_status,
        upgrade_count,
        downgrade_count,
        failed_payments,
        successful_payments,
        payment_success_rate,
        times_churned,
        is_resurrected,
        last_payment_date,

        -- Days since the most recent payment (proxy for billing recency).
        DATE_DIFF(CURRENT_DATE(), last_payment_date, DAY) AS days_since_last_payment,

        -- Share of MRR lost relative to the customer's historical peak.
        ROUND(
            SAFE_DIVIDE(peak_mrr - current_mrr, peak_mrr) * 100,
            1
        ) AS mrr_erosion_pct,

        -- 1) Payment failures: scale failed payments, cap contribution at 25.
        LEAST(failed_payments * 8, 25) AS pts_payment_failures,

        -- 2) Stale payment: graduated penalty for billing silence.
        CASE
            WHEN current_mrr = 0 THEN 0  -- free accounts have no expected payment
            WHEN DATE_DIFF(CURRENT_DATE(), last_payment_date, DAY) > 60 THEN 20
            WHEN DATE_DIFF(CURRENT_DATE(), last_payment_date, DAY) > 45 THEN 12
            WHEN last_payment_date IS NULL THEN 15
            ELSE 0
        END AS pts_stale_payment,

        -- 3) Net downgrade behavior: more contractions than expansions.
        CASE
            WHEN downgrade_count > upgrade_count
            THEN LEAST((downgrade_count - upgrade_count) * 8, 15)
            ELSE 0
        END AS pts_downgrades,

        -- 4) MRR erosion from peak (only meaningful when a peak existed).
        CASE
            WHEN peak_mrr > 0 AND current_mrr < peak_mrr
            THEN LEAST(
                CAST(ROUND(SAFE_DIVIDE(peak_mrr - current_mrr, peak_mrr) * 20) AS INT64),
                20
            )
            ELSE 0
        END AS pts_mrr_erosion,

        -- 5) Prior churn history: resurrected or repeat customers churn again.
        CASE
            WHEN is_resurrected THEN 10
            WHEN times_churned > 0 THEN 6
            ELSE 0
        END AS pts_prior_churn,

        -- 6) Early-tenure fragility: the first 90 days carry elevated risk.
        CASE
            WHEN days_since_signup <= 30 THEN 10
            WHEN days_since_signup <= 90 THEN 6
            ELSE 0
        END AS pts_early_tenure

    FROM active_customers
),

-- Combine components into a single capped score.
scored AS (
    SELECT
        *,
        LEAST(
            pts_payment_failures
            + pts_stale_payment
            + pts_downgrades
            + pts_mrr_erosion
            + pts_prior_churn
            + pts_early_tenure,
            100
        ) AS churn_risk_score
    FROM risk_components
),

final AS (
    SELECT
        -- Identifiers & context
        customer_id,
        company_name,
        industry,
        company_size,
        acquisition_channel,
        current_plan_tier,
        customer_status,
        signup_cohort_month,
        tenure_bucket,
        health_status,

        -- Financials
        current_mrr,
        current_arr,
        peak_mrr,
        mrr_erosion_pct,

        -- Behavioral inputs (kept for dashboard drill-downs)
        upgrade_count,
        downgrade_count,
        failed_payments,
        successful_payments,
        payment_success_rate,
        days_since_last_payment,
        times_churned,
        is_resurrected,

        -- Score component breakdown (explains the score)
        pts_payment_failures,
        pts_stale_payment,
        pts_downgrades,
        pts_mrr_erosion,
        pts_prior_churn,
        pts_early_tenure,

        -- Composite score & band
        churn_risk_score,
        CASE
            WHEN churn_risk_score >= 75 THEN 'critical'
            WHEN churn_risk_score >= 50 THEN 'high'
            WHEN churn_risk_score >= 25 THEN 'medium'
            ELSE 'low'
        END AS risk_band,

        -- MRR exposed in each band (for "MRR at risk" reporting)
        CASE
            WHEN churn_risk_score >= 50 THEN ROUND(current_mrr, 2)
            ELSE 0
        END AS mrr_at_risk,

        -- Metadata
        CURRENT_TIMESTAMP() AS _generated_at

    FROM scored
)

SELECT * FROM final
ORDER BY churn_risk_score DESC, current_mrr DESC
