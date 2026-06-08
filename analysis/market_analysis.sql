/*
    Analysis: Market & Segment

    Purpose: Understand the customer base by market dimensions — industry,
             company size, geography, and plan tier — to find where the
             product wins and where there is whitespace.

    Demonstrates:
    - Segment revenue concentration
    - Penetration and ARPU by company size
    - Geographic distribution
    - Industry x plan affinity
*/

-- ============================================================================
-- SECTION 1: Revenue Concentration by Industry
-- ============================================================================

SELECT
    industry,
    COUNT(*) AS customers,
    COUNT(CASE WHEN customer_status = 'active_paying' THEN 1 END) AS active_paying,
    ROUND(SUM(current_mrr), 2) AS current_mrr,
    ROUND(SUM(current_mrr) / SUM(SUM(current_mrr)) OVER () * 100, 1) AS pct_of_mrr,
    ROUND(AVG(current_mrr), 2) AS avg_mrr,
    ROUND(AVG(lifetime_revenue), 2) AS avg_ltv
FROM dim_customers
GROUP BY industry
ORDER BY current_mrr DESC;


-- ============================================================================
-- SECTION 2: ARPU and Penetration by Company Size
-- ============================================================================

SELECT
    company_size,
    COUNT(*) AS customers,
    ROUND(SAFE_DIVIDE(COUNT(CASE WHEN customer_status = 'active_paying' THEN 1 END), COUNT(*)) * 100, 1) AS paying_rate_pct,
    ROUND(AVG(current_mrr), 2) AS arpu,
    ROUND(SUM(current_mrr), 2) AS segment_mrr,
    ROUND(AVG(lifetime_revenue), 2) AS avg_ltv
FROM dim_customers
GROUP BY company_size
ORDER BY arpu DESC;


-- ============================================================================
-- SECTION 3: Geographic Distribution
-- ============================================================================

SELECT
    country,
    COUNT(*) AS customers,
    ROUND(SUM(current_mrr), 2) AS current_mrr,
    ROUND(SUM(current_mrr) / SUM(SUM(current_mrr)) OVER () * 100, 1) AS pct_of_mrr,
    ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 1) AS churn_rate_pct
FROM dim_customers
GROUP BY country
ORDER BY current_mrr DESC;


-- ============================================================================
-- SECTION 4: Industry x Plan Tier Affinity
-- ============================================================================
-- Which industries gravitate to which plan tiers?

SELECT
    industry,
    current_plan_tier,
    COUNT(*) AS customers,
    ROUND(
        COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY industry) * 100, 1
    ) AS pct_within_industry,
    ROUND(SUM(current_mrr), 2) AS current_mrr
FROM dim_customers
WHERE current_plan_tier IS NOT NULL
GROUP BY industry, current_plan_tier
ORDER BY industry, current_mrr DESC;


-- ============================================================================
-- SECTION 5: Segment Health & Whitespace
-- ============================================================================
-- High-MRR but high-churn segments are at-risk; low-penetration but
-- high-ARPU segments are expansion whitespace.

WITH segment AS (
    SELECT
        company_size,
        industry,
        COUNT(*) AS customers,
        ROUND(AVG(current_mrr), 2) AS arpu,
        ROUND(AVG(CASE WHEN has_churned THEN 1 ELSE 0 END) * 100, 1) AS churn_rate_pct,
        ROUND(SUM(current_mrr), 2) AS segment_mrr
    FROM dim_customers
    GROUP BY company_size, industry
    HAVING COUNT(*) >= 10
)

SELECT
    company_size,
    industry,
    customers,
    arpu,
    churn_rate_pct,
    segment_mrr,
    CASE
        WHEN churn_rate_pct >= 40 THEN 'at_risk'
        WHEN arpu >= 50 AND customers < 30 THEN 'whitespace'
        WHEN segment_mrr >= 1000 THEN 'core'
        ELSE 'steady'
    END AS segment_label
FROM segment
ORDER BY segment_mrr DESC;
