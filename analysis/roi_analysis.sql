/*
    Analysis: Marketing & Acquisition ROI

    Purpose: Quantify the return on acquisition spend by channel and segment,
             using the rpt_unit_economics mart as the backbone.

    Demonstrates:
    - LTV:CAC and payback ranking
    - Spend efficiency and ROI by channel
    - Paid vs organic return
    - Where incremental spend is most/least efficient
*/

-- ============================================================================
-- SECTION 1: Channel ROI Scorecard
-- ============================================================================

SELECT
    acquisition_channel,
    acquisition_channel_category,
    customers_acquired,
    cac,
    realized_ltv,
    predicted_ltv,
    ltv_to_cac_ratio,
    cac_payback_months,
    acquisition_roi_pct,
    total_acquisition_spend,
    total_lifetime_revenue,
    CASE
        WHEN ltv_to_cac_ratio >= 3 AND cac_payback_months <= 12 THEN 'scale'
        WHEN ltv_to_cac_ratio >= 1 THEN 'optimize'
        ELSE 'reduce'
    END AS recommended_action
FROM rpt_unit_economics
WHERE acquisition_channel != 'ALL CHANNELS'
ORDER BY ltv_to_cac_ratio DESC;


-- ============================================================================
-- SECTION 2: Paid vs Organic Return
-- ============================================================================

SELECT
    CASE WHEN is_paid_acquisition THEN 'Paid' ELSE 'Organic' END AS channel_type,
    SUM(customers_acquired) AS customers,
    ROUND(SUM(total_acquisition_spend), 2) AS total_spend,
    ROUND(SUM(total_lifetime_revenue), 2) AS total_revenue,
    ROUND(SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)), 2) AS blended_cac,
    ROUND(SAFE_DIVIDE(SUM(total_lifetime_revenue), SUM(customers_acquired)), 2) AS blended_ltv,
    ROUND(
        SAFE_DIVIDE(
            SUM(total_lifetime_revenue) - SUM(total_acquisition_spend),
            NULLIF(SUM(total_acquisition_spend), 0)
        ) * 100, 1
    ) AS blended_roi_pct
FROM rpt_unit_economics
WHERE acquisition_channel != 'ALL CHANNELS'
GROUP BY channel_type;


-- ============================================================================
-- SECTION 3: Spend Efficiency Frontier
-- ============================================================================
-- Revenue returned per $1 of acquisition spend, ranked.

SELECT
    acquisition_channel,
    total_acquisition_spend,
    total_lifetime_revenue,
    ROUND(SAFE_DIVIDE(total_lifetime_revenue, NULLIF(total_acquisition_spend, 0)), 2) AS revenue_per_dollar,
    ROUND(
        total_lifetime_revenue / SUM(total_lifetime_revenue) OVER () * 100, 1
    ) AS pct_of_total_revenue,
    ROUND(
        total_acquisition_spend / SUM(total_acquisition_spend) OVER () * 100, 1
    ) AS pct_of_total_spend
FROM rpt_unit_economics
WHERE acquisition_channel != 'ALL CHANNELS'
ORDER BY revenue_per_dollar DESC;


-- ============================================================================
-- SECTION 4: ROI by Channel x Plan Tier Mix
-- ============================================================================
-- Which channels bring high-value (enterprise/business) customers?

SELECT
    c.acquisition_channel,
    c.current_plan_tier,
    COUNT(*) AS customers,
    ROUND(AVG(c.lifetime_revenue), 2) AS avg_ltv,
    ROUND(SUM(c.current_mrr), 2) AS current_mrr
FROM dim_customers c
WHERE c.current_plan_tier IS NOT NULL
GROUP BY c.acquisition_channel, c.current_plan_tier
HAVING COUNT(*) >= 5
ORDER BY c.acquisition_channel, avg_ltv DESC;
