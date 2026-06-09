/*
    Report Model: rpt_unit_economics

    Description: Channel-level unit economics — CAC, LTV, LTV:CAC, CAC payback,
                 and acquisition ROI. The core input for ROI and market analysis.

    Grain: One row per acquisition channel (plus a blended 'ALL CHANNELS' row)

    Use Cases:
    - Marketing spend allocation (which channels return the most per dollar)
    - Board / investor unit-economics reporting (LTV:CAC, payback)
    - ROI analysis by acquisition source

    Key formulas (see docs/metric_definitions.md):
    - CAC                = assumed cost per acquisition (seed: typical_cac)
    - Realized LTV       = AVG(lifetime_revenue collected per customer)
    - Predicted LTV      = ARPC * gross_margin / monthly_logo_churn_rate
    - LTV:CAC ratio      = LTV / CAC          (healthy >= 3.0)
    - CAC payback months = CAC / (ARPC * gross_margin)
    - Acquisition ROI %  = (realized_ltv - CAC) / CAC * 100
*/

{% set gross_margin = var('gross_margin') %}
{% set min_churn = var('min_monthly_churn_rate') %}

WITH customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

channels AS (
    SELECT * FROM {{ ref('marketing_channels') }}
),

-- Aggregate customer outcomes per acquisition channel.
channel_rollup AS (
    SELECT
        c.acquisition_channel,
        c.acquisition_channel_category,
        c.is_paid_acquisition,

        COUNT(DISTINCT c.customer_id) AS customers_acquired,
        COUNT(DISTINCT CASE WHEN c.customer_status = 'active_paying' THEN c.customer_id END) AS active_paying_customers,
        COUNT(DISTINCT CASE WHEN c.has_churned THEN c.customer_id END) AS churned_customers,

        SUM(c.lifetime_revenue) AS total_lifetime_revenue,
        SUM(c.current_mrr) AS current_mrr,
        AVG(c.lifetime_revenue) AS avg_lifetime_revenue,
        AVG(NULLIF(c.current_mrr, 0)) AS arpc,
        AVG(c.days_since_signup) AS avg_tenure_days
    FROM customers c
    GROUP BY 1, 2, 3
),

-- Attach the assumed CAC from the channel seed.
with_cac AS (
    SELECT
        r.*,
        ch.typical_cac AS cac
    FROM channel_rollup r
    LEFT JOIN channels ch ON r.acquisition_channel = ch.channel_name
),

-- Derive economics per channel.
channel_economics AS (
    SELECT
        acquisition_channel,
        acquisition_channel_category,
        is_paid_acquisition,
        customers_acquired,
        active_paying_customers,
        churned_customers,

        -- Logo churn rate over the observed window, floored so LTV stays finite.
        GREATEST(
            SAFE_DIVIDE(churned_customers, customers_acquired),
            {{ min_churn }}
        ) AS observed_churn_rate,

        ROUND(cac, 2) AS cac,
        ROUND(total_lifetime_revenue, 2) AS total_lifetime_revenue,
        ROUND(current_mrr, 2) AS current_mrr,
        ROUND(arpc, 2) AS arpc,
        ROUND(avg_lifetime_revenue, 2) AS realized_ltv,

        -- Total acquisition spend = customers * assumed CAC.
        ROUND(customers_acquired * cac, 2) AS total_acquisition_spend,

        -- Predicted LTV = ARPC * gross_margin / monthly churn.
        ROUND(
            SAFE_DIVIDE(
                arpc * {{ gross_margin }},
                GREATEST(SAFE_DIVIDE(churned_customers, customers_acquired), {{ min_churn }})
            ),
            2
        ) AS predicted_ltv,

        -- LTV:CAC on realized LTV.
        ROUND(SAFE_DIVIDE(avg_lifetime_revenue, cac), 2) AS ltv_to_cac_ratio,

        -- CAC payback in months = CAC / (ARPC * gross_margin).
        ROUND(SAFE_DIVIDE(cac, arpc * {{ gross_margin }}), 1) AS cac_payback_months,

        -- Acquisition ROI on realized revenue.
        ROUND(SAFE_DIVIDE(avg_lifetime_revenue - cac, cac) * 100, 1) AS acquisition_roi_pct,

        ROUND(avg_tenure_days, 0) AS avg_tenure_days,
        ROUND(SAFE_DIVIDE(active_paying_customers, customers_acquired) * 100, 1) AS active_rate_pct,
        ROUND(SAFE_DIVIDE(churned_customers, customers_acquired) * 100, 1) AS churn_rate_pct
    FROM with_cac
),

-- Blended row across all channels (spend-weighted CAC).
blended AS (
    SELECT
        'ALL CHANNELS' AS acquisition_channel,
        'blended' AS acquisition_channel_category,
        CAST(NULL AS BOOL) AS is_paid_acquisition,
        SUM(customers_acquired) AS customers_acquired,
        SUM(active_paying_customers) AS active_paying_customers,
        SUM(churned_customers) AS churned_customers,
        GREATEST(SAFE_DIVIDE(SUM(churned_customers), SUM(customers_acquired)), {{ min_churn }}) AS observed_churn_rate,
        ROUND(SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)), 2) AS cac,
        ROUND(SUM(total_lifetime_revenue), 2) AS total_lifetime_revenue,
        ROUND(SUM(current_mrr), 2) AS current_mrr,
        ROUND(SAFE_DIVIDE(SUM(current_mrr), SUM(active_paying_customers)), 2) AS arpc,
        ROUND(SAFE_DIVIDE(SUM(total_lifetime_revenue), SUM(customers_acquired)), 2) AS realized_ltv,
        ROUND(SUM(total_acquisition_spend), 2) AS total_acquisition_spend,
        ROUND(
            SAFE_DIVIDE(
                SAFE_DIVIDE(SUM(current_mrr), SUM(active_paying_customers)) * {{ gross_margin }},
                GREATEST(SAFE_DIVIDE(SUM(churned_customers), SUM(customers_acquired)), {{ min_churn }})
            ), 2
        ) AS predicted_ltv,
        ROUND(SAFE_DIVIDE(SUM(total_lifetime_revenue), SUM(customers_acquired)) /
              NULLIF(SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)), 0), 2) AS ltv_to_cac_ratio,
        ROUND(SAFE_DIVIDE(
              SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)),
              SAFE_DIVIDE(SUM(current_mrr), SUM(active_paying_customers)) * {{ gross_margin }}), 1) AS cac_payback_months,
        ROUND(SAFE_DIVIDE(
              SAFE_DIVIDE(SUM(total_lifetime_revenue), SUM(customers_acquired)) -
              SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)),
              NULLIF(SAFE_DIVIDE(SUM(total_acquisition_spend), SUM(customers_acquired)), 0)) * 100, 1) AS acquisition_roi_pct,
        ROUND(AVG(avg_tenure_days), 0) AS avg_tenure_days,
        ROUND(SAFE_DIVIDE(SUM(active_paying_customers), SUM(customers_acquired)) * 100, 1) AS active_rate_pct,
        ROUND(SAFE_DIVIDE(SUM(churned_customers), SUM(customers_acquired)) * 100, 1) AS churn_rate_pct
    FROM channel_economics
),

final AS (
    SELECT *, CURRENT_TIMESTAMP() AS _generated_at FROM channel_economics
    UNION ALL
    SELECT *, CURRENT_TIMESTAMP() AS _generated_at FROM blended
)

SELECT * FROM final
ORDER BY
    CASE WHEN acquisition_channel = 'ALL CHANNELS' THEN 1 ELSE 0 END,
    ltv_to_cac_ratio DESC
