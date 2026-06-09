/*
    Analysis: Business Performance

    Purpose: Executive performance view — MRR/ARR trajectory, growth efficiency,
             retention quality, and the headline enterprise KPIs over time.

    Demonstrates:
    - Period-over-period growth and CAGR-style trends
    - Growth-efficiency metrics (Quick Ratio, Rule of 40 proxy)
    - Retention quality (NRR, gross churn)
*/

-- ============================================================================
-- SECTION 1: Headline KPI Snapshot (latest month)
-- ============================================================================

SELECT
    month_key,
    active_customers,
    ending_mrr,
    arr,
    arpc,
    ROUND(net_revenue_retention_pct, 1) AS nrr_pct,
    ROUND(gross_mrr_churn_rate_pct, 1) AS gross_mrr_churn_pct,
    quick_ratio,
    ROUND(mrr_growth_rate_pct, 1) AS mrr_growth_pct
FROM fct_mrr
QUALIFY ROW_NUMBER() OVER (ORDER BY month_date DESC) = 1;


-- ============================================================================
-- SECTION 2: MRR Trajectory and Movement Waterfall
-- ============================================================================

SELECT
    month_key,
    ending_mrr,
    new_mrr,
    expansion_mrr,
    -contraction_mrr AS contraction_mrr,
    -churned_mrr AS churned_mrr,
    net_new_mrr,
    ROUND(mrr_growth_rate_pct, 1) AS mrr_growth_pct
FROM fct_mrr
ORDER BY month_date;


-- ============================================================================
-- SECTION 3: Growth Efficiency Trend
-- ============================================================================
-- Quick Ratio and a Rule-of-40 proxy (growth% + a margin proxy).
-- Margin is approximated by NRR-100 here as a directional proxy only.

SELECT
    month_key,
    ROUND(mrr_growth_rate_pct, 1) AS mrr_growth_pct,
    quick_ratio,
    ROUND(net_revenue_retention_pct, 1) AS nrr_pct,
    ROUND(mrr_growth_rate_pct + (net_revenue_retention_pct - 100), 1) AS rule_of_40_proxy
FROM fct_mrr
WHERE mrr_growth_rate_pct IS NOT NULL
ORDER BY month_date;


-- ============================================================================
-- SECTION 4: Quarter-over-Quarter Performance
-- ============================================================================

WITH quarterly AS (
    SELECT
        FORMAT_DATE('%Y-Q%Q', month_date) AS quarter,
        MAX(ending_mrr) AS quarter_end_mrr,
        SUM(new_mrr) AS new_mrr,
        SUM(expansion_mrr) AS expansion_mrr,
        SUM(churned_mrr) AS churned_mrr,
        SUM(net_new_mrr) AS net_new_mrr
    FROM fct_mrr
    GROUP BY quarter
)

SELECT
    quarter,
    ROUND(quarter_end_mrr, 2) AS quarter_end_mrr,
    ROUND(quarter_end_mrr * 12, 2) AS arr,
    ROUND(net_new_mrr, 2) AS net_new_mrr,
    ROUND(
        SAFE_DIVIDE(
            quarter_end_mrr - LAG(quarter_end_mrr) OVER (ORDER BY quarter),
            LAG(quarter_end_mrr) OVER (ORDER BY quarter)
        ) * 100, 1
    ) AS qoq_growth_pct
FROM quarterly
ORDER BY quarter;


-- ============================================================================
-- SECTION 5: Performance by Plan Tier
-- ============================================================================

SELECT
    plan_tier,
    COUNT(DISTINCT subscription_id) AS subscriptions,
    COUNT(DISTINCT CASE WHEN is_active THEN subscription_id END) AS active_subscriptions,
    ROUND(SUM(CASE WHEN is_active THEN mrr ELSE 0 END), 2) AS active_mrr,
    ROUND(AVG(mrr), 2) AS avg_mrr,
    ROUND(AVG(subscription_length_days), 0) AS avg_tenure_days,
    ROUND(
        SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN is_churned THEN subscription_id END),
                    COUNT(DISTINCT subscription_id)) * 100, 1
    ) AS churn_rate_pct
FROM dim_subscriptions
GROUP BY plan_tier
ORDER BY active_mrr DESC;
