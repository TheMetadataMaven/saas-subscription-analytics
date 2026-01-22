# SaaS Subscription Analytics

A complete analytics engineering project demonstrating data modeling, SQL transformations, and business intelligence for a subscription-based software company.

## 🎯 Project Overview

This project simulates the analytics infrastructure for **CloudSync Pro**, a fictional B2B SaaS company offering cloud storage and collaboration tools. It showcases how to transform raw transactional data into actionable business insights across marketing, operations, and executive leadership.

### Business Questions Answered

- **Marketing:** Which acquisition channels drive the highest-value customers? What's our CAC payback period by channel?
- **Operations:** Where are customers churning in their lifecycle? Which plan tiers have the strongest retention?
- **Executive:** What's our current MRR trajectory? How does cohort performance compare month-over-month?

---

## 📁 Project Structure

```
saas-subscription-analytics/
│
├── data/
│   ├── raw/                          # Simulated source data (CSV)
│   │   ├── customers.csv             # 750 customer records
│   │   ├── subscriptions.csv         # Subscription records
│   │   ├── subscription_events.csv   # 1,464 lifecycle events
│   │   ├── payments.csv              # 6,731 payment transactions
│   │   └── marketing_touches.csv     # 3,405 marketing touchpoints
│   │
│   └── seeds/                        # Reference/lookup tables
│       ├── plan_tiers.csv
│       └── marketing_channels.csv
│
├── models/
│   ├── staging/                      # 1:1 source cleaning
│   │   ├── sources.yml               # Source definitions
│   │   ├── staging.yml               # Model documentation
│   │   ├── stg_customers.sql
│   │   ├── stg_subscriptions.sql
│   │   ├── stg_subscription_events.sql
│   │   ├── stg_payments.sql
│   │   └── stg_marketing_touches.sql
│   │
│   ├── intermediate/                 # Business logic joins
│   │   ├── intermediate.yml          # Model documentation
│   │   ├── int_customer_subscription_history.sql
│   │   ├── int_mrr_movements.sql
│   │   └── int_attribution_touchpoints.sql
│   │
│   └── marts/                        # Analysis-ready tables
│       ├── marts.yml                 # Model documentation
│       ├── fct_mrr.sql
│       ├── fct_subscription_events.sql
│       ├── dim_customers.sql
│       ├── dim_subscriptions.sql
│       └── rpt_cohort_retention.sql
│
├── analysis/                         # Ad-hoc analysis queries
│   ├── cohort_analysis.sql
│   ├── churn_deep_dive.sql
│   └── channel_attribution.sql
│
├── macros/                           # Reusable SQL macros
│   └── saas_metrics.sql
│
├── tests/                            # Custom data quality tests
│   ├── assert_mrr_movements_balance.sql
│   ├── assert_cohort_retention_valid.sql
│   └── assert_attribution_weights_sum_to_one.sql
│
├── scripts/
│   └── generate_sample_data.py       # Data generation script
│
├── docs/
│   ├── data_dictionary.md            # Field-level documentation
│   ├── metric_definitions.md         # Business metric definitions
│   └── schema_diagram.md             # Visual ERD (Mermaid)
│
├── dbt_project.yml                   # dbt configuration
├── profiles.yml.example              # Sample dbt profile
├── Makefile                          # Build automation
├── .gitignore
└── README.md
```

---

## 🔄 Data Model

### Conceptual Overview

```
                    ┌─────────────────┐
                    │   dim_customers │
                    └────────┬────────┘
                             │
    ┌────────────────────────┼────────────────────────┐
    │                        │                        │
    ▼                        ▼                        ▼
┌─────────┐         ┌───────────────┐         ┌─────────────┐
│ fct_mrr │         │dim_subscriptions│        │fct_sub_events│
└─────────┘         └───────────────┘         └─────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │rpt_cohort_retention│
                    └─────────────────┘
```

### Key Entities

| Table | Type | Description |
|-------|------|-------------|
| `dim_customers` | Dimension | Customer attributes, acquisition channel, signup date |
| `dim_subscriptions` | Dimension | Plan details, pricing, subscription status |
| `fct_mrr` | Fact | Monthly recurring revenue by customer, with MRR movements |
| `fct_subscription_events` | Fact | Lifecycle events (started, upgraded, downgraded, churned) |
| `rpt_cohort_retention` | Report | Pre-aggregated cohort retention matrix |

---

## 📊 Key Metrics

### MRR Metrics
- **MRR (Monthly Recurring Revenue):** Sum of all active subscription values
- **New MRR:** Revenue from first-time subscriptions this period
- **Expansion MRR:** Revenue increase from upgrades
- **Contraction MRR:** Revenue decrease from downgrades
- **Churned MRR:** Revenue lost from cancellations
- **Net New MRR:** New + Expansion - Contraction - Churned

### Customer Metrics
- **Active Customers:** Customers with active subscriptions
- **Gross Churn Rate:** Churned customers / Beginning customers
- **Net Revenue Retention:** (Beginning MRR + Expansion - Contraction - Churn) / Beginning MRR
- **CAC Payback Period:** CAC / (ARPU × Gross Margin)

### Cohort Metrics
- **M0-M12 Retention:** Percentage of cohort still active at month N
- **LTV by Cohort:** Predicted lifetime value based on retention curves

---

## 🛠️ Technical Highlights

### SQL Techniques Demonstrated

**Window Functions for MRR Movement Tracking**
```sql
-- Calculating MRR changes month-over-month
WITH mrr_changes AS (
  SELECT
    customer_id,
    mrr_month,
    mrr_amount,
    LAG(mrr_amount) OVER (
      PARTITION BY customer_id 
      ORDER BY mrr_month
    ) AS previous_mrr,
    FIRST_VALUE(mrr_month) OVER (
      PARTITION BY customer_id 
      ORDER BY mrr_month
    ) AS first_mrr_month
  FROM monthly_mrr
)
SELECT
  customer_id,
  mrr_month,
  mrr_amount,
  CASE
    WHEN previous_mrr IS NULL THEN 'new'
    WHEN mrr_amount > previous_mrr THEN 'expansion'
    WHEN mrr_amount < previous_mrr AND mrr_amount > 0 THEN 'contraction'
    WHEN mrr_amount = 0 AND previous_mrr > 0 THEN 'churn'
    ELSE 'unchanged'
  END AS mrr_movement_type
FROM mrr_changes
```

**Cohort Retention Matrix**
```sql
-- Building a retention matrix by signup cohort
WITH cohort_base AS (
  SELECT
    customer_id,
    DATE_TRUNC(signup_date, MONTH) AS cohort_month,
    DATE_TRUNC(activity_date, MONTH) AS activity_month
  FROM customer_activity
),
cohort_size AS (
  SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
  FROM cohort_base
  GROUP BY cohort_month
)
SELECT
  cb.cohort_month,
  DATE_DIFF(cb.activity_month, cb.cohort_month, MONTH) AS months_since_signup,
  COUNT(DISTINCT cb.customer_id) AS active_customers,
  cs.cohort_customers,
  ROUND(COUNT(DISTINCT cb.customer_id) / cs.cohort_customers * 100, 1) AS retention_pct
FROM cohort_base cb
JOIN cohort_size cs ON cb.cohort_month = cs.cohort_month
GROUP BY 1, 2, 4
ORDER BY 1, 2
```

**Multi-Touch Attribution**
```sql
-- First-touch and last-touch attribution
WITH touchpoints AS (
  SELECT
    customer_id,
    channel,
    touch_timestamp,
    FIRST_VALUE(channel) OVER (
      PARTITION BY customer_id 
      ORDER BY touch_timestamp
    ) AS first_touch_channel,
    LAST_VALUE(channel) OVER (
      PARTITION BY customer_id 
      ORDER BY touch_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_touch_channel
  FROM marketing_touches
  WHERE touch_timestamp <= conversion_timestamp
)
SELECT DISTINCT
  customer_id,
  first_touch_channel,
  last_touch_channel
FROM touchpoints
```

---

## 📈 Dashboards

### Executive Dashboard (Power BI / Tableau / Looker)

Each dashboard includes:

1. **MRR Overview** — Current MRR, trend, and waterfall of movements
2. **Cohort Retention Heatmap** — Visual retention matrix by signup month
3. **Channel Performance** — CAC, conversion rates, and LTV by acquisition source
4. **Churn Analysis** — Churn by plan tier, tenure, and leading indicators

Screenshots and interactive demos available in `/dashboards` folder.

---

## 🚀 Getting Started

### Prerequisites
- BigQuery (or compatible SQL environment)
- dbt Core 1.0+ (`pip install dbt-bigquery`)
- Python 3.8+ (for data generation)
- Power BI Desktop / Tableau Desktop / Looker access (for dashboards)

### Quick Start

1. **Clone this repository**
```bash
git clone https://github.com/CWalters1982/saas-subscription-analytics.git
cd saas-subscription-analytics
```

2. **Configure your dbt profile**
```bash
# Copy the example profile
cp profiles.yml.example ~/.dbt/profiles.yml

# Edit with your BigQuery credentials
nano ~/.dbt/profiles.yml
```

3. **Generate sample data** (optional - data included)
```bash
python scripts/generate_sample_data.py
```

4. **Load raw data to BigQuery**
```bash
# Option 1: Using make
make bq-load BQ_PROJECT=your-project-id

# Option 2: Manual load
bq load --source_format=CSV --autodetect \
  your-project:raw.customers data/raw/customers.csv
```

5. **Run dbt models**
```bash
# Install dependencies and run
dbt deps
dbt seed    # Load reference tables
dbt run     # Run all models
dbt test    # Validate data quality
```

6. **Generate documentation**
```bash
dbt docs generate
dbt docs serve
```

### Using Make Commands

```bash
make help           # Show all available commands
make setup          # Install dependencies
make generate-data  # Generate new sample data
make run            # Run all dbt models
make test           # Run data quality tests
make docs           # Generate and serve documentation
make fresh          # Clean rebuild everything
```

---

## 📚 Documentation

- **[Data Dictionary](/docs/data_dictionary.md)** — Field-level documentation for all tables
- **[Metric Definitions](/docs/metric_definitions.md)** — Business logic behind each KPI
- **[Schema Diagram](/docs/schema_diagram.png)** — Visual entity-relationship diagram

---

## 💡 Lessons & Design Decisions

### Why this structure?

**Staging → Intermediate → Marts** mirrors how modern data teams operate. It creates clear separation between:
- Source cleaning (staging)
- Business logic (intermediate)
- Consumer-ready outputs (marts)

**Multiple BI tools** demonstrate platform-agnostic thinking. Real-world teams often inherit tools or need to support multiple stakeholders with different preferences.

**Documented metrics** prevent the "which number is right?" problem. When Marketing and Finance disagree on churn rate, the answer is in `metric_definitions.md`.

---

## 🔮 Future Enhancements

- [ ] Add dbt tests for data quality
- [ ] Implement incremental loading patterns
- [ ] Build predictive churn model (Python)
- [ ] Add Metabase dashboard variant

---

## 📬 Contact

Built by **Catrina Walters** — [LinkedIn](https://www.linkedin.com/in/catrina-walters-a6a123172) | [GitHub](https://github.com/CWalters1982)

Questions or feedback? Open an issue or reach out directly.
