# Power BI — Connection & Data Model Guide

How to point Power BI at the dbt marts and wire up the star schema.

---

## 1. Connect to the warehouse

The dbt models build into BigQuery (default profile in `profiles.yml.example`).
After `dbt run`, the marts live in the `marts` dataset.

**Power BI Desktop → Get Data → Google BigQuery**
1. Sign in with the Google account that has access to the project.
2. Navigate to `your-project` → `marts` dataset.
3. Select the tables below. **Import** mode is recommended for this dataset
   size (sub-million rows); use **DirectQuery** only if near-real-time is required.

### Tables to load

| Table | Role | Grain |
|---|---|---|
| `fct_mrr` | Fact | one row per month |
| `fct_subscription_events` | Fact | one row per lifecycle event |
| `dim_customers` | Dimension | one row per customer |
| `dim_subscriptions` | Dimension | one row per subscription |
| `rpt_unit_economics` | Report/fact | one row per channel (+ blended) |
| `rpt_cohort_retention` | Report/fact | one row per cohort × period |
| `rpt_churn_risk` | Report | one row per active customer |

> Not connecting to BigQuery yet? You can prototype by importing the CSVs in
> `data/raw/` and the dbt seed CSVs, but the marts (above) are the intended source.

---

## 2. Date table

Mark a date table so time-intelligence (`PREVIOUSMONTH`, `LASTDATE`) works:

- Simplest: use `fct_mrr[month_date]` and **Mark as date table**.
- Better: create a dedicated `Calendar` table and relate it to
  `fct_mrr[month_date]`, `fct_subscription_events[event_date]`,
  `dim_customers[signup_date]`:

```dax
Calendar =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2023, 1, 1 ), DATE ( 2024, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month", FORMAT ( [Date], "YYYY-MM" ),
    "MonthStart", DATE ( YEAR ( [Date] ), MONTH ( [Date] ), 1 ),
    "Quarter", FORMAT ( [Date], "YYYY-\QQ" )
)
```

---

## 3. Relationships (star schema)

```
                       ┌──────────────┐
                       │   Calendar   │
                       └──────┬───────┘
            ┌─────────────────┼──────────────────┐
            ▼                 ▼                   ▼
      ┌──────────┐      ┌─────────────┐   ┌──────────────────────┐
      │ fct_mrr  │      │ fct_sub_... │   │ dim_customers (1) ◄── │
      └────┬─────┘      └──────┬──────┘   └──────────┬───────────┘
           │                   │                     │
           │ customer_id       │ customer_id         │ customer_id
           ▼                   ▼                     ▼
   ┌───────────────┐   ┌──────────────┐   ┌────────────────────┐
   │ dim_customers │   │dim_customers │   │  rpt_churn_risk     │
   └───────────────┘   └──────────────┘   └────────────────────┘
```

| From (many) | To (one) | Key | Cross-filter |
|---|---|---|---|
| `fct_mrr` | `Calendar` | `month_date` → `MonthStart` | single |
| `fct_subscription_events` | `Calendar` | `event_date` → `Date` | single |
| `fct_subscription_events` | `dim_customers` | `customer_id` | single |
| `fct_subscription_events` | `dim_subscriptions` | `subscription_id` | single |
| `dim_subscriptions` | `dim_customers` | `customer_id` | single |
| `rpt_churn_risk` | `dim_customers` | `customer_id` | single |

Notes:
- `fct_mrr` is monthly aggregate (no `customer_id`); filter it via `Calendar`,
  plan tier comes from joining through events/subscriptions or use it standalone.
- `rpt_unit_economics` and `rpt_cohort_retention` are pre-aggregated report
  tables — keep them **standalone** (no relationship) or relate
  `rpt_unit_economics[acquisition_channel]` to a channel dimension if you add one.

---

## 4. Refresh

- **Import mode:** schedule refresh in the Power BI Service after `dbt run`
  completes (e.g., orchestrate dbt nightly, then trigger dataset refresh).
- Align the report refresh to the dbt run so KPIs are consistent with
  `_generated_at` on each mart.
