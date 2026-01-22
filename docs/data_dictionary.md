# Data Dictionary

## Overview

This document provides field-level documentation for all tables in the SaaS Subscription Analytics data model. Tables are organized by layer: raw sources, staging, intermediate, and marts.

---

## Raw Data Sources

### customers.csv
Customer account information captured at signup.

| Field | Type | Description |
|-------|------|-------------|
| customer_id | STRING | Unique identifier for each customer (PK) |
| company_name | STRING | Legal name of the customer's company |
| industry | STRING | Industry vertical classification |
| company_size | STRING | Employee count range (1-10, 11-50, etc.) |
| country | STRING | ISO 2-letter country code |
| signup_date | TIMESTAMP | Date and time of account creation |
| email | STRING | Primary contact email address |
| acquisition_channel_id | INTEGER | FK to marketing_channels |
| initial_plan_id | INTEGER | FK to plan_tiers - first plan selected |
| is_trial | BOOLEAN | Whether customer started with a trial |
| trial_end_date | DATE | Trial expiration date (null if no trial) |

### subscriptions.csv
Subscription records tracking plan enrollment.

| Field | Type | Description |
|-------|------|-------------|
| subscription_id | STRING | Unique identifier for each subscription (PK) |
| customer_id | STRING | FK to customers |
| plan_id | INTEGER | FK to plan_tiers |
| status | STRING | Current status: 'active' or 'churned' |
| billing_cycle | STRING | 'monthly' or 'annual' |
| mrr | NUMERIC | Current monthly recurring revenue |
| start_date | DATE | Subscription start date |
| end_date | DATE | Subscription end date (null if active) |
| created_at | TIMESTAMP | Record creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### subscription_events.csv
Lifecycle events for each subscription.

| Field | Type | Description |
|-------|------|-------------|
| event_id | STRING | Unique event identifier (PK) |
| subscription_id | STRING | FK to subscriptions |
| customer_id | STRING | FK to customers |
| event_type | STRING | Event classification (see Event Types below) |
| event_date | TIMESTAMP | When the event occurred |
| plan_id | INTEGER | Plan ID after this event |
| mrr_change | NUMERIC | Change in MRR (positive or negative) |
| mrr_after | NUMERIC | MRR after this event |

**Event Types:**
- `subscription_started` - New subscription created
- `subscription_upgraded` - Plan tier increased
- `subscription_downgraded` - Plan tier decreased
- `subscription_churned` - Subscription cancelled
- `subscription_reactivated` - Previously churned customer returned

### payments.csv
Payment transaction records.

| Field | Type | Description |
|-------|------|-------------|
| payment_id | STRING | Unique payment identifier (PK) |
| subscription_id | STRING | FK to subscriptions |
| customer_id | STRING | FK to customers |
| amount | NUMERIC | Payment amount |
| currency | STRING | ISO currency code (USD) |
| payment_date | DATE | Date payment was processed |
| payment_method | STRING | 'credit_card', 'ach', or 'wire' |
| status | STRING | 'succeeded' or 'failed' |
| created_at | TIMESTAMP | Record creation timestamp |

### marketing_touches.csv
Marketing touchpoints before conversion.

| Field | Type | Description |
|-------|------|-------------|
| touch_id | STRING | Unique touchpoint identifier (PK) |
| customer_id | STRING | FK to customers |
| channel_id | INTEGER | FK to marketing_channels |
| touch_date | TIMESTAMP | When the interaction occurred |
| touch_type | STRING | Type of interaction (see below) |
| landing_page | STRING | Page URL path |
| utm_campaign | STRING | Campaign identifier (null for organic) |
| conversion_date | TIMESTAMP | When customer signed up |

**Touch Types:**
- `visit` - Website visit
- `click` - Ad or email click
- `form_submit` - Form submission
- `content_download` - Asset download
- `demo_request` - Demo scheduling

---

## Seed/Reference Tables

### plan_tiers.csv
Product plan definitions.

| Field | Type | Description |
|-------|------|-------------|
| plan_id | INTEGER | Unique plan identifier (PK) |
| plan_name | STRING | Display name (Starter, Pro, Team, Enterprise) |
| plan_tier | STRING | Tier classification (free, professional, business, enterprise) |
| monthly_price | NUMERIC | Monthly billing price |
| annual_price | NUMERIC | Annual billing price (discounted) |
| storage_gb | INTEGER | Storage allocation in GB |
| max_users | INTEGER | Maximum users allowed |
| features | STRING | Comma-separated feature list |

### marketing_channels.csv
Marketing channel reference data.

| Field | Type | Description |
|-------|------|-------------|
| channel_id | INTEGER | Unique channel identifier (PK) |
| channel_name | STRING | Channel identifier (google_ads, organic_search, etc.) |
| channel_category | STRING | Category grouping (paid_search, organic, direct, etc.) |
| is_paid | BOOLEAN | Whether this is a paid channel |
| typical_cac | NUMERIC | Typical customer acquisition cost |

---

## Staging Models

Staging models clean and standardize raw data. They follow a 1:1 relationship with source tables.

### stg_customers
Cleaned customer data with standardized formats.

| Field | Type | Transformation |
|-------|------|----------------|
| customer_id | STRING | Pass-through |
| company_name | STRING | Pass-through |
| industry | STRING | Uppercase, trimmed |
| company_size | STRING | Pass-through |
| country | STRING | Uppercase, trimmed |
| email | STRING | Lowercase, trimmed |
| acquisition_channel_id | INT64 | Cast from string |
| initial_plan_id | INT64 | Cast from string |
| is_trial | BOOLEAN | Parsed from various formats |
| trial_end_date | DATE | Parsed from string |
| signed_up_at | TIMESTAMP | Parsed from string |
| signup_date | DATE | Extracted from timestamp |
| _loaded_at | TIMESTAMP | ETL metadata |

### stg_subscriptions
Cleaned subscription data with calculated tenure.

| Field | Type | Transformation |
|-------|------|----------------|
| subscription_id | STRING | Pass-through |
| customer_id | STRING | Pass-through |
| plan_id | INT64 | Cast from string |
| status | STRING | Lowercase, trimmed |
| billing_cycle | STRING | Lowercase, trimmed |
| mrr | NUMERIC | Cast from string |
| start_date | DATE | Parsed from string |
| end_date | DATE | Parsed from string |
| subscription_length_days | INTEGER | Calculated: end_date - start_date |
| created_at | TIMESTAMP | Parsed from string |
| updated_at | TIMESTAMP | Parsed from string |
| _loaded_at | TIMESTAMP | ETL metadata |

### stg_subscription_events
Cleaned events with categorization.

| Field | Type | Transformation |
|-------|------|----------------|
| event_id | STRING | Pass-through |
| subscription_id | STRING | Pass-through |
| customer_id | STRING | Pass-through |
| plan_id | INT64 | Cast from string |
| event_type | STRING | Lowercase, trimmed |
| event_category | STRING | Derived: acquisition/expansion/contraction/churn |
| mrr_change | NUMERIC | Cast from string |
| mrr_after | NUMERIC | Cast from string |
| event_at | TIMESTAMP | Parsed from string |
| event_date | DATE | Extracted from timestamp |
| event_year | INTEGER | Extracted from timestamp |
| event_month | INTEGER | Extracted from timestamp |
| event_month_key | STRING | Format: YYYY-MM |
| _loaded_at | TIMESTAMP | ETL metadata |

### stg_payments
Cleaned payment data with success flags.

| Field | Type | Transformation |
|-------|------|----------------|
| payment_id | STRING | Pass-through |
| subscription_id | STRING | Pass-through |
| customer_id | STRING | Pass-through |
| amount | NUMERIC | Cast from string |
| currency | STRING | Uppercase, trimmed |
| payment_method | STRING | Lowercase, trimmed |
| status | STRING | Lowercase, trimmed |
| is_successful | BOOLEAN | Derived: status = 'succeeded' |
| is_failed | BOOLEAN | Derived: status = 'failed' |
| payment_date | DATE | Parsed from string |
| payment_month_key | STRING | Format: YYYY-MM |
| created_at | TIMESTAMP | Parsed from string |
| _loaded_at | TIMESTAMP | ETL metadata |

### stg_marketing_touches
Cleaned touchpoints with time-to-conversion.

| Field | Type | Transformation |
|-------|------|----------------|
| touch_id | STRING | Pass-through |
| customer_id | STRING | Pass-through |
| channel_id | INT64 | Cast from string |
| touch_type | STRING | Lowercase, trimmed |
| landing_page | STRING | Lowercase, trimmed |
| utm_campaign | STRING | Trimmed, nullified if empty |
| touched_at | TIMESTAMP | Parsed from string |
| touch_date | DATE | Extracted from timestamp |
| converted_at | TIMESTAMP | Parsed from string |
| conversion_date | DATE | Extracted from timestamp |
| days_to_conversion | INTEGER | Calculated: conversion - touch |
| hours_to_conversion | INTEGER | Calculated: conversion - touch |
| _loaded_at | TIMESTAMP | ETL metadata |

---

## Intermediate Models

Intermediate models apply business logic and join related entities.

### int_customer_subscription_history
Complete customer timeline with events.

| Field | Type | Description |
|-------|------|-------------|
| customer_id | STRING | Customer identifier |
| company_name | STRING | Company name |
| industry | STRING | Industry classification |
| company_size | STRING | Company size band |
| country | STRING | Country code |
| signup_date | DATE | Customer signup date |
| acquisition_channel_id | INT64 | Acquisition channel FK |
| is_trial | BOOLEAN | Trial flag |
| event_id | STRING | Event identifier |
| subscription_id | STRING | Subscription identifier |
| event_type | STRING | Event type |
| event_category | STRING | Event category |
| event_date | DATE | Event date |
| event_at | TIMESTAMP | Event timestamp |
| plan_id | INT64 | Plan at time of event |
| mrr_change | NUMERIC | MRR change |
| mrr_after | NUMERIC | MRR after event |
| plan_name | STRING | Plan name |
| plan_tier | STRING | Plan tier |
| plan_price | NUMERIC | Plan monthly price |
| days_since_signup | INTEGER | Tenure at event time |
| months_since_signup | INTEGER | Tenure in months |
| event_sequence | INTEGER | Event order for customer |
| previous_event_type | STRING | Prior event type |
| previous_plan_id | INT64 | Prior plan |
| next_event_type | STRING | Following event type |
| next_event_date | DATE | Following event date |
| is_first_paid_conversion | BOOLEAN | First paid subscription flag |
| has_ever_churned | BOOLEAN | Customer has churned historically |
| has_ever_upgraded | BOOLEAN | Customer has upgraded historically |
| days_until_next_event | INTEGER | Days to next event |

### int_mrr_movements
Monthly MRR tracking with movement types.

| Field | Type | Description |
|-------|------|-------------|
| customer_id | STRING | Customer identifier |
| month_date | DATE | First day of month |
| month_key | STRING | Month key (YYYY-MM) |
| beginning_mrr | NUMERIC | MRR at start of month |
| ending_mrr | NUMERIC | MRR at end of month |
| net_mrr_change | NUMERIC | Total MRR change |
| new_mrr | NUMERIC | MRR from new customers |
| expansion_mrr | NUMERIC | MRR from upgrades |
| contraction_mrr | NUMERIC | MRR lost to downgrades |
| churned_mrr | NUMERIC | MRR lost to churn |
| movement_type | STRING | Primary movement classification |
| had_acquisition | INTEGER | Flag: acquisition in month |
| had_expansion | INTEGER | Flag: expansion in month |
| had_contraction | INTEGER | Flag: contraction in month |
| had_churn | INTEGER | Flag: churn in month |
| customer_month_number | INTEGER | Nth month for customer |

### int_attribution_touchpoints
Marketing attribution with multiple models.

| Field | Type | Description |
|-------|------|-------------|
| touch_id | STRING | Touchpoint identifier |
| customer_id | STRING | Customer identifier |
| channel_id | INT64 | Channel FK |
| channel_name | STRING | Channel name |
| channel_category | STRING | Channel category |
| is_paid | BOOLEAN | Paid channel flag |
| typical_cac | NUMERIC | Typical CAC for channel |
| touch_type | STRING | Touch interaction type |
| landing_page | STRING | Landing page path |
| utm_campaign | STRING | Campaign identifier |
| touched_at | TIMESTAMP | Touch timestamp |
| touch_date | DATE | Touch date |
| converted_at | TIMESTAMP | Conversion timestamp |
| conversion_date | DATE | Conversion date |
| days_to_conversion | INTEGER | Days from touch to conversion |
| company_size | STRING | Customer company size |
| industry | STRING | Customer industry |
| initial_mrr | NUMERIC | Customer initial MRR |
| touch_sequence | INTEGER | Touch order (1 = first) |
| total_touches | INTEGER | Total touches for customer |
| first_touch_at | TIMESTAMP | First touch timestamp |
| last_touch_at | TIMESTAMP | Last touch timestamp |
| first_touch_weight | FLOAT | First-touch attribution weight |
| last_touch_weight | FLOAT | Last-touch attribution weight |
| linear_weight | FLOAT | Linear attribution weight |
| time_decay_weight | FLOAT | Time-decay attribution weight |
| position_based_weight | FLOAT | Position-based attribution weight |
| is_first_touch | BOOLEAN | Is first touch flag |
| is_last_touch | BOOLEAN | Is last touch flag |
| first_touch_revenue | NUMERIC | Revenue via first-touch model |
| last_touch_revenue | NUMERIC | Revenue via last-touch model |
| linear_revenue | NUMERIC | Revenue via linear model |
| time_decay_revenue | NUMERIC | Revenue via time-decay model |
| position_based_revenue | NUMERIC | Revenue via position-based model |
| journey_stage | STRING | awareness/consideration/decision |

---

## Mart Models

Mart models are analysis-ready tables optimized for specific use cases.

### fct_mrr
Monthly MRR metrics for financial reporting.

**Grain:** One row per month

| Field | Type | Description |
|-------|------|-------------|
| month_date | DATE | First day of month |
| month_key | STRING | Month key (YYYY-MM) |
| total_customers | INTEGER | All customers with activity |
| active_customers | INTEGER | Customers with MRR > 0 |
| new_customers | INTEGER | First-time customers |
| churned_customers | INTEGER | Customers who churned |
| resurrected_customers | INTEGER | Returning customers |
| expanded_customers | INTEGER | Customers who upgraded |
| contracted_customers | INTEGER | Customers who downgraded |
| ending_mrr | NUMERIC | Total MRR at month end |
| active_mrr | NUMERIC | MRR from active customers |
| new_mrr | NUMERIC | MRR from new customers |
| expansion_mrr | NUMERIC | MRR from upgrades |
| contraction_mrr | NUMERIC | MRR lost to downgrades |
| churned_mrr | NUMERIC | MRR lost to churn |
| gross_new_mrr | NUMERIC | new_mrr + expansion_mrr |
| gross_lost_mrr | NUMERIC | contraction_mrr + churned_mrr |
| net_new_mrr | NUMERIC | gross_new - gross_lost |
| mrr_growth_rate_pct | FLOAT | MoM MRR growth |
| customer_growth_rate_pct | FLOAT | MoM customer growth |
| gross_mrr_churn_rate_pct | FLOAT | Churned MRR / Beginning MRR |
| gross_customer_churn_rate_pct | FLOAT | Churned / Beginning customers |
| net_revenue_retention_pct | FLOAT | NRR percentage |
| quick_ratio | FLOAT | (New + Expansion) / (Contraction + Churn) |
| arpc | NUMERIC | Average revenue per customer |
| cumulative_new_mrr | NUMERIC | Running total new MRR |
| cumulative_churned_mrr | NUMERIC | Running total churned MRR |
| arr | NUMERIC | Annualized recurring revenue |
| net_new_arr | NUMERIC | Annualized net new MRR |
| _generated_at | TIMESTAMP | Model run timestamp |

### fct_subscription_events
Enriched subscription lifecycle events.

**Grain:** One row per subscription event

| Field | Type | Description |
|-------|------|-------------|
| event_id | STRING | Event identifier (PK) |
| subscription_id | STRING | Subscription FK |
| customer_id | STRING | Customer FK |
| event_type | STRING | Event type |
| event_category | STRING | Event category |
| event_date | DATE | Event date |
| event_at | TIMESTAMP | Event timestamp |
| plan_id | INT64 | Plan FK |
| plan_name | STRING | Plan name |
| plan_tier | STRING | Plan tier |
| plan_price | NUMERIC | Plan price |
| mrr_change | NUMERIC | MRR change |
| mrr_after | NUMERIC | MRR after event |
| mrr_impact_absolute | NUMERIC | Absolute MRR impact |
| company_name | STRING | Customer company |
| industry | STRING | Customer industry |
| company_size | STRING | Customer size |
| country | STRING | Customer country |
| signup_date | DATE | Customer signup date |
| is_trial | BOOLEAN | Trial flag |
| acquisition_channel_id | INT64 | Acquisition channel FK |
| acquisition_channel | STRING | Acquisition channel name |
| acquisition_channel_category | STRING | Channel category |
| is_paid_acquisition | BOOLEAN | Paid acquisition flag |
| days_since_signup | INTEGER | Customer tenure at event |
| months_since_signup | INTEGER | Tenure in months |
| tenure_bucket | STRING | Tenure band |
| event_sequence | INTEGER | Event order |
| previous_event_type | STRING | Prior event |
| previous_plan_id | INT64 | Prior plan |
| next_event_type | STRING | Next event |
| next_event_date | DATE | Next event date |
| days_until_next_event | INTEGER | Days to next event |
| is_first_paid_conversion | BOOLEAN | First paid flag |
| has_ever_churned | BOOLEAN | Ever churned flag |
| has_ever_upgraded | BOOLEAN | Ever upgraded flag |
| event_year | INTEGER | Event year |
| event_month | INTEGER | Event month |
| event_quarter | INTEGER | Event quarter |
| event_month_key | STRING | YYYY-MM |
| event_quarter_key | STRING | YYYY-QN |
| event_day_of_week | STRING | Day name |
| signup_cohort_month | STRING | Signup YYYY-MM |
| signup_cohort_quarter | STRING | Signup YYYY-QN |
| _generated_at | TIMESTAMP | Model run timestamp |

### dim_customers
Customer dimension with current state and lifetime metrics.

**Grain:** One row per customer

See full field list in model file. Key fields include:
- Customer identifiers and attributes
- Acquisition information
- Current subscription state
- Lifetime metrics (LTV, payments, events)
- Health indicators
- Cohort keys

### dim_subscriptions
Subscription dimension with plan details.

**Grain:** One row per subscription

See full field list in model file. Key fields include:
- Subscription identifiers
- Plan details
- Financial metrics
- Duration and status
- Churn timing classification

### rpt_cohort_retention
Pre-aggregated cohort retention matrix.

**Grain:** One row per cohort-month combination

| Field | Type | Description |
|-------|------|-------------|
| cohort_month | DATE | Signup cohort month |
| cohort_month_key | STRING | YYYY-MM format |
| cohort_month_name | STRING | Display name (Jan 2024) |
| months_since_signup | INTEGER | Period number (0-24) |
| period_label | STRING | Display label (M0, M1, etc.) |
| cohort_size | INTEGER | Original cohort size |
| active_customers | INTEGER | Customers active in period |
| retention_rate | FLOAT | active / cohort_size |
| retained_mrr | NUMERIC | Total MRR in period |
| avg_mrr_per_customer | NUMERIC | Average MRR |
| retention_from_m0 | FLOAT | Retention vs M0 customers |
| mrr_retention_from_m0 | FLOAT | MRR retention vs M0 |
| churned_customers | INTEGER | Cumulative churned |
| cumulative_churn_rate | FLOAT | Cumulative churn % |
| previous_period_customers | INTEGER | Prior period customers |
| customers_change | INTEGER | Period-over-period change |
| _generated_at | TIMESTAMP | Model run timestamp |

---

## Data Quality Notes

1. **Null Handling:** All staging models filter out records with null primary keys
2. **Date Parsing:** Uses SAFE.PARSE functions to handle malformed dates
3. **Numeric Precision:** Monetary values cast to NUMERIC for precision
4. **Case Sensitivity:** All categorical fields standardized to lowercase
5. **Timezone:** All timestamps assume UTC unless specified
