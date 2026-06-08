# Metric Definitions

## Overview

This document provides business definitions, calculation methodology, and usage guidance for all metrics in the SaaS Subscription Analytics data model.

---

## MRR Metrics

### Monthly Recurring Revenue (MRR)

**Definition:** The normalized monthly revenue from all active subscriptions.

**Calculation:**
```sql
SUM(subscription_mrr) WHERE subscription_status = 'active'
```

**Notes:**
- Annual subscriptions are normalized to monthly: annual_price / 12
- Excludes one-time fees, setup charges, and usage-based revenue
- Point-in-time snapshot as of month end

**Use Cases:** Primary revenue health indicator, forecasting baseline, valuation metric

---

### New MRR

**Definition:** MRR from customers who subscribed for the first time in the period.

**Calculation:**
```sql
SUM(mrr_after) WHERE customer_month_number = 1 AND ending_mrr > 0
```

**Notes:**
- Includes both direct-to-paid and trial-to-paid conversions
- Does not include reactivations (see Resurrection MRR)

**Use Cases:** Sales/marketing effectiveness, growth rate analysis

---

### Expansion MRR

**Definition:** Additional MRR from existing customers who upgraded their subscription.

**Calculation:**
```sql
SUM(ending_mrr - beginning_mrr) 
WHERE beginning_mrr > 0 
  AND ending_mrr > beginning_mrr
```

**Notes:**
- Includes plan tier upgrades and seat/user additions
- Must have had positive MRR in prior period

**Use Cases:** Customer success effectiveness, upsell opportunity sizing

---

### Contraction MRR

**Definition:** MRR lost from existing customers who downgraded but did not churn.

**Calculation:**
```sql
SUM(beginning_mrr - ending_mrr) 
WHERE beginning_mrr > 0 
  AND ending_mrr > 0 
  AND ending_mrr < beginning_mrr
```

**Notes:**
- Customer must remain active (MRR > 0)
- Includes plan downgrades and seat reductions

**Use Cases:** Early churn warning, pricing/packaging analysis

---

### Churned MRR

**Definition:** MRR lost from customers who cancelled their subscription.

**Calculation:**
```sql
SUM(beginning_mrr) 
WHERE beginning_mrr > 0 
  AND ending_mrr = 0
```

**Notes:**
- Beginning MRR is the value lost
- Customer MRR goes to zero

**Use Cases:** Churn analysis, retention program effectiveness

---

### Resurrection MRR

**Definition:** MRR from previously churned customers who reactivated.

**Calculation:**
```sql
SUM(ending_mrr) 
WHERE customer_month_number > 1 
  AND beginning_mrr = 0 
  AND ending_mrr > 0
```

**Notes:**
- Customer must have had a prior subscription that churned
- Often tracked separately from New MRR

**Use Cases:** Win-back campaign effectiveness, reactivation opportunity sizing

---

### Net New MRR

**Definition:** The net change in MRR from all sources.

**Calculation:**
```sql
new_mrr + expansion_mrr - contraction_mrr - churned_mrr
```

**Alternative:**
```sql
ending_mrr - beginning_mrr
```

**Notes:**
- Primary growth metric
- Positive = growing, negative = shrinking

**Use Cases:** Overall business health, board reporting, forecasting

---

### Gross New MRR

**Definition:** Total positive MRR movements (new + expansion).

**Calculation:**
```sql
new_mrr + expansion_mrr
```

**Use Cases:** Sales capacity planning, gross growth analysis

---

### Gross Lost MRR

**Definition:** Total negative MRR movements (contraction + churn).

**Calculation:**
```sql
contraction_mrr + churned_mrr
```

**Use Cases:** Revenue leakage analysis, retention investment decisions

---

## Recurring Revenue Rates

### MRR Growth Rate

**Definition:** Month-over-month percentage change in MRR.

**Calculation:**
```sql
(ending_mrr - previous_month_mrr) / previous_month_mrr * 100
```

**Benchmarks:**
- Early stage: 15-20%+ monthly
- Growth stage: 5-10% monthly
- Mature: 2-5% monthly

**Use Cases:** Growth trajectory analysis, investor reporting

---

### Gross MRR Churn Rate

**Definition:** Percentage of MRR lost to churn in a period.

**Calculation:**
```sql
churned_mrr / beginning_mrr * 100
```

**Benchmarks:**
- Excellent: <1% monthly
- Good: 1-2% monthly
- Concerning: >3% monthly

**Notes:** Does not account for expansion (see Net Revenue Retention)

**Use Cases:** Churn severity measurement, retention program targeting

---

### Net Revenue Retention (NRR)

**Definition:** Percentage of MRR retained from existing customers after accounting for expansion, contraction, and churn.

**Calculation:**
```sql
(beginning_mrr + expansion_mrr - contraction_mrr - churned_mrr) / beginning_mrr * 100
```

**Benchmarks:**
- Excellent: >120%
- Good: 100-120%
- Concerning: <100%

**Notes:**
- >100% means expansion outpaces churn
- Key metric for investor due diligence
- Also called "Net Dollar Retention" (NDR)

**Use Cases:** Customer success impact measurement, valuation metric

---

### Quick Ratio

**Definition:** Ratio of growth MRR to lost MRR, measuring growth efficiency.

**Calculation:**
```sql
(new_mrr + expansion_mrr) / (contraction_mrr + churned_mrr)
```

**Benchmarks:**
- Excellent: >4
- Good: 2-4
- Concerning: <1

**Notes:**
- Higher is better
- Ratio of 1 = break-even growth
- Undefined when denominator is 0

**Use Cases:** Growth quality assessment, go-to-market efficiency

---

## Customer Metrics

### Active Customers

**Definition:** Customers with an active, paying subscription.

**Calculation:**
```sql
COUNT(DISTINCT customer_id) WHERE current_mrr > 0 AND status = 'active'
```

**Notes:** Excludes free tier users unless separately tracked

---

### Gross Customer Churn Rate

**Definition:** Percentage of customers who cancelled in a period.

**Calculation:**
```sql
churned_customers / beginning_customers * 100
```

**Benchmarks:**
- SMB: 3-5% monthly typical
- Mid-market: 1-2% monthly typical
- Enterprise: <1% monthly typical

---

### Average Revenue Per Customer (ARPC)

**Definition:** Mean MRR across all active customers.

**Calculation:**
```sql
active_mrr / active_customers
```

**Alternative names:** ARPU (Average Revenue Per User), ACV (Annual Contract Value) when annualized

**Use Cases:** Pricing strategy, segment comparison, upsell opportunity

---

### Customer Lifetime Value (LTV)

**Definition:** Total revenue expected from a customer over their relationship.

**Calculation (Simple):**
```sql
ARPC / monthly_churn_rate
```

**Calculation (Historical):**
```sql
SUM(all_payments) per customer
```

**Notes:**
- Simple formula assumes constant churn
- Historical LTV is backward-looking
- Predictive models use cohort curves

**Use Cases:** CAC payback analysis, segment prioritization

---

## Cohort Metrics

### Cohort Retention Rate

**Definition:** Percentage of a signup cohort still active at period N.

**Calculation:**
```sql
active_customers_at_period_n / cohort_size * 100
```

**Notes:**
- Period 0 (M0) is typically 100%
- Can be measured monthly (M1, M2...) or weekly

**Use Cases:** Retention curve analysis, product-market fit assessment

---

### Cohort MRR Retention

**Definition:** Percentage of original MRR retained by a cohort at period N.

**Calculation:**
```sql
mrr_at_period_n / mrr_at_m0 * 100
```

**Notes:**
- Can exceed 100% if expansion > churn
- Key leading indicator for NRR

**Use Cases:** Revenue quality by acquisition period, pricing change impact

---

## Attribution Metrics

### First Touch Attribution

**Definition:** 100% credit assigned to the first marketing interaction.

**Use Cases:** Awareness channel effectiveness, top-of-funnel optimization

---

### Last Touch Attribution

**Definition:** 100% credit assigned to the final marketing interaction before conversion.

**Use Cases:** Conversion channel effectiveness, bottom-of-funnel optimization

---

### Linear Attribution

**Definition:** Equal credit distributed across all touchpoints.

**Calculation:**
```sql
1 / total_touchpoints per touch
```

**Use Cases:** Balanced view of channel contribution

---

### Time Decay Attribution

**Definition:** More credit to touchpoints closer to conversion.

**Calculation:**
```sql
weight = 0.5 ^ (days_to_conversion / half_life)
-- Normalized across all touches
```

**Notes:** Half-life typically 7 days

**Use Cases:** Emphasizes recent influence on conversion

---

### Position-Based Attribution (U-Shaped)

**Definition:** 40% to first touch, 40% to last touch, 20% distributed to middle.

**Calculation:**
```sql
first_touch: 0.40
last_touch: 0.40
middle_touches: 0.20 / (total_touches - 2)
```

**Use Cases:** Balanced view emphasizing initiator and closer

---

### Customer Acquisition Cost (CAC)

**Definition:** Total cost to acquire a customer.

**Calculation:**
```sql
(sales_cost + marketing_cost) / new_customers
```

**Notes:**
- Often calculated by channel
- Should include all associated costs

**Use Cases:** Unit economics, channel efficiency comparison

---

### CAC Payback Period

**Definition:** Months to recover customer acquisition cost.

**Calculation:**
```sql
CAC / (ARPC * gross_margin)
```

**Benchmarks:**
- Excellent: <12 months
- Good: 12-18 months
- Concerning: >24 months

**Use Cases:** Investment efficiency, growth funding requirements

---

## Health Indicators

### Customer Health Score

**Definition:** Composite score indicating likelihood of retention or churn.

**Components (example):**
- Recent payment failures: -15 points
- Downgrade in last 90 days: -20 points
- Days since last payment > 45: -25 points
- New customer (<90 days): -15 points
- Has upgraded: +15 points
- Enterprise tier: +10 points

**Categories:**
- Healthy: Score < 0
- Low Risk: 0-19
- Medium Risk: 20-39
- High Risk: 40+

**Use Cases:** Customer success prioritization, proactive intervention

---

## ARR Metrics

### Annual Recurring Revenue (ARR)

**Definition:** Annualized value of recurring revenue.

**Calculation:**
```sql
MRR * 12
```

**Notes:**
- Standard metric for enterprise SaaS
- Often used in valuations and reporting

---

### Net New ARR

**Definition:** Annualized net MRR change.

**Calculation:**
```sql
net_new_mrr * 12
```

---

## Metric Relationships

```
                    ┌─────────────┐
                    │  New MRR    │
                    └──────┬──────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
    ▼                      ▼                      ▼
┌─────────┐         ┌────────────┐         ┌──────────┐
│Expansion│         │ Contraction│         │  Churn   │
│   MRR   │         │    MRR     │         │   MRR    │
└────┬────┘         └─────┬──────┘         └────┬─────┘
     │                    │                     │
     └────────────────────┼─────────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ Net New MRR  │
                   └──────┬───────┘
                          │
                          ▼
                   ┌──────────────┐
                   │  Ending MRR  │
                   └──────────────┘
```

---

## Common Pitfalls

1. **Comparing NRR across different time periods:** NRR compounds over time; monthly vs annual rates are not comparable without conversion.

2. **Mixing cohort and period metrics:** Cohort retention tracks a fixed group; period metrics include all customers active in that period.

3. **Ignoring seasonality:** Many metrics have seasonal patterns; year-over-year comparisons are more reliable.

4. **Using revenue instead of MRR:** One-time payments inflate revenue but don't represent recurring value.

5. **Not normalizing annual contracts:** Always convert to monthly for consistent MRR calculations.

---

## Metric Governance

| Metric | Owner | Refresh Frequency | Data Source |
|--------|-------|-------------------|-------------|
| MRR | Finance | Daily | fct_mrr |
| NRR | Finance | Monthly | fct_mrr |
| Churn Rate | Customer Success | Weekly | fct_mrr |
| LTV | Finance | Monthly | dim_customers |
| CAC | Marketing | Monthly | External + dim_customers |
| Cohort Retention | Product | Monthly | rpt_cohort_retention |
| Health Score | Customer Success | Daily | dim_customers |
| LTV:CAC / Payback / ROI | Marketing | Monthly | rpt_unit_economics |
| Churn Risk Score | Customer Success | Daily | rpt_churn_risk |
