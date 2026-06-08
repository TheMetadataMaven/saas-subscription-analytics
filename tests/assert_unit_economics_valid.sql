/*
    Test: assert_unit_economics_valid

    Validates the integrity of rpt_unit_economics:
    1. No channel reports more active or churned customers than it acquired
    2. Spend, CAC, and payback are never negative
    3. observed_churn_rate stays within [0, 1]

    Any returned row is a failure.
*/

SELECT
    acquisition_channel,
    customers_acquired,
    active_paying_customers,
    churned_customers,
    cac,
    total_acquisition_spend,
    cac_payback_months,
    observed_churn_rate
FROM {{ ref('rpt_unit_economics') }}
WHERE acquisition_channel != 'ALL CHANNELS'
  AND (
        active_paying_customers > customers_acquired
        OR churned_customers > customers_acquired
        OR cac < 0
        OR total_acquisition_spend < 0
        OR cac_payback_months < 0
        OR observed_churn_rate < 0
        OR observed_churn_rate > 1
      )
