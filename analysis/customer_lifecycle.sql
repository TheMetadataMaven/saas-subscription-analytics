/*
    Analysis: Customer Lifecycle

    Purpose: Trace customers through the full lifecycle — acquisition, activation,
             expansion, and churn — and quantify movement between stages.

    Demonstrates:
    - Lifecycle stage segmentation
    - Trial-to-paid conversion
    - Time-to-value and time-to-churn
    - Plan progression (upgrade / downgrade paths)
*/

-- ============================================================================
-- SECTION 1: Lifecycle Stage Distribution
-- ============================================================================
-- How customers are distributed across lifecycle stages right now.

WITH lifecycle_stage AS (
    SELECT
        customer_id,
        current_mrr,
        CASE
            WHEN customer_status = 'churned' THEN '5_churned'
            WHEN upgrade_count > 0 THEN '4_expansion'
            WHEN customer_status = 'active_paying' THEN '3_paying'
            WHEN customer_status = 'active_free' THEN '2_activated_free'
            ELSE '1_signed_up'
        END AS lifecycle_stage
    FROM dim_customers
)

SELECT
    lifecycle_stage,
    COUNT(*) AS customers,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct_of_base,
    ROUND(SUM(current_mrr), 2) AS stage_mrr,
    ROUND(AVG(current_mrr), 2) AS avg_mrr
FROM lifecycle_stage
GROUP BY lifecycle_stage
ORDER BY lifecycle_stage;


-- ============================================================================
-- SECTION 2: Trial-to-Paid Conversion
-- ============================================================================

SELECT
    is_trial,
    COUNT(*) AS customers,
    COUNT(CASE WHEN converted_from_trial THEN 1 END) AS converted,
    ROUND(
        SAFE_DIVIDE(COUNT(CASE WHEN converted_from_trial THEN 1 END), COUNT(*)) * 100,
        1
    ) AS trial_conversion_rate_pct,
    ROUND(AVG(current_mrr), 2) AS avg_mrr
FROM dim_customers
GROUP BY is_trial;


-- ============================================================================
-- SECTION 3: Time-to-Value and Time-to-Churn
-- ============================================================================
-- How long until the first paid conversion, and how long before churn.

WITH milestones AS (
    SELECT
        customer_id,
        MIN(CASE WHEN is_first_paid_conversion THEN days_since_signup END) AS days_to_paid,
        MAX(CASE WHEN event_category = 'churn' THEN days_since_signup END) AS days_to_churn,
        has_ever_churned,
        has_ever_upgraded
    FROM int_customer_subscription_history
    GROUP BY customer_id, has_ever_churned, has_ever_upgraded
)

SELECT
    COUNT(*) AS customers,
    ROUND(AVG(days_to_paid), 1) AS avg_days_to_paid,
    ROUND(APPROX_QUANTILES(days_to_paid, 100)[OFFSET(50)], 0) AS median_days_to_paid,
    ROUND(AVG(CASE WHEN has_ever_churned = 1 THEN days_to_churn END), 1) AS avg_days_to_churn,
    SUM(has_ever_upgraded) AS customers_who_upgraded,
    SUM(has_ever_churned) AS customers_who_churned
FROM milestones;


-- ============================================================================
-- SECTION 4: Plan Progression Paths
-- ============================================================================
-- Net upgrade vs downgrade behavior by starting plan.

SELECT
    initial_plan_name,
    current_plan_name,
    COUNT(*) AS customers,
    ROUND(AVG(current_mrr), 2) AS avg_current_mrr,
    ROUND(AVG(upgrade_count), 2) AS avg_upgrades,
    ROUND(AVG(downgrade_count), 2) AS avg_downgrades
FROM dim_customers
WHERE initial_plan_name IS NOT NULL
GROUP BY initial_plan_name, current_plan_name
HAVING COUNT(*) >= 5
ORDER BY initial_plan_name, customers DESC;


-- ============================================================================
-- SECTION 5: Tenure Cohort Survival
-- ============================================================================
-- Share of customers surviving into each tenure band.

SELECT
    tenure_bucket,
    COUNT(*) AS customers,
    COUNT(CASE WHEN customer_status != 'churned' THEN 1 END) AS still_active,
    ROUND(
        SAFE_DIVIDE(COUNT(CASE WHEN customer_status != 'churned' THEN 1 END), COUNT(*)) * 100,
        1
    ) AS survival_rate_pct,
    ROUND(AVG(lifetime_revenue), 2) AS avg_lifetime_revenue
FROM dim_customers
GROUP BY tenure_bucket
ORDER BY
    CASE tenure_bucket
        WHEN '0-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181-365 days' THEN 4
        ELSE 5
    END;
