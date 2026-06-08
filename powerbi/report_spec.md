# Power BI Report Specification — CloudSync Pro Analytics

A five-page executive report built on the dbt marts. Each page lists its
purpose, the visuals, the measures/fields they bind to, and the slicers.
Use this as the build sheet in Power BI Desktop. A live HTML preview of the
intended look is in [`dashboard_preview.html`](dashboard_preview.html).

> **Theme:** dark slate background (`#0f172a`), accent teal (`#2dd4bf`),
> positive green (`#34d399`), negative red (`#f87171`), card surface `#1e293b`.
> Font: Segoe UI. KPI cards across the top, detail visuals below.

---

## Global elements (all pages)

- **Slicers (sync across pages):** Month (from `fct_mrr[month_date]`),
  Plan Tier, Acquisition Channel, Industry, Company Size.
- **Header band:** report title + last-refresh timestamp
  (`MAX(fct_mrr[_generated_at])`).
- **Navigation:** page buttons — Executive · Lifecycle · Unit Economics ·
  Market · Churn & Retention.

---

## Page 1 — Executive Overview

**Purpose:** The board-level snapshot of revenue health and growth.

| Visual | Type | Binds to |
|---|---|---|
| MRR | KPI card | `[MRR]` (vs prior month `[MRR MoM %]`) |
| ARR | KPI card | `[ARR]` |
| Net Revenue Retention | KPI card + `[NRR Status]` color | `[Net Revenue Retention %]` |
| Quick Ratio | KPI card | `[Quick Ratio]` |
| Active Customers | KPI card | `[Active Customers]` |
| MRR trend | Line chart | `[MRR]` by `fct_mrr[month_date]` |
| MRR movement waterfall | Waterfall | New / Expansion / Contraction / Churn → `[Net New MRR]` |
| ARR by plan tier | Stacked column | `[Active MRR]`×12 by `dim_subscriptions[plan_tier]` |
| Rule of 40 / Magic Number | Two KPI cards | `[Rule of 40 Proxy]`, `[Magic Number]` |

---

## Page 2 — Customer Lifecycle

**Purpose:** How customers move through acquisition → activation → expansion → churn.

| Visual | Type | Binds to |
|---|---|---|
| Lifecycle funnel | Funnel | customer counts by lifecycle stage (see `analysis/customer_lifecycle.sql` §1) |
| Trial → Paid conversion | KPI card + donut | conversion rate from `dim_customers[converted_from_trial]` |
| Avg days to paid / to churn | Two cards | from `int_customer_subscription_history` milestones |
| Tenure survival curve | Line | survival rate by `dim_customers[tenure_bucket]` |
| Plan progression | Sankey (or matrix) | `initial_plan_name` → `current_plan_name` |
| Expansion vs contraction | Clustered column | `[Expansion MRR]` vs `[Contraction MRR]` by month |

---

## Page 3 — Unit Economics & ROI

**Purpose:** Are we acquiring customers profitably, and where?

| Visual | Type | Binds to |
|---|---|---|
| LTV:CAC | KPI card + `[LTV:CAC Status]` | `[LTV : CAC]` |
| CAC Payback (months) | KPI card + `[Payback Status]` | `[CAC Payback (months)]` |
| Acquisition ROI | KPI card | `[Acquisition ROI %]` |
| LTV:CAC by channel | Bar (ref line at 3.0) | `rpt_unit_economics[ltv_to_cac_ratio]` by channel |
| CAC vs Realized LTV | Clustered bar | `[CAC]` & `[Realized LTV]` by channel |
| Revenue per spend $ | Bar | `[Revenue per Spend $]` by channel |
| Spend vs revenue scatter | Scatter | x=`total_acquisition_spend`, y=`total_lifetime_revenue`, size=`customers_acquired` |
| Channel action table | Table | channel, LTV:CAC, payback, ROI, `recommended_action` (roi_analysis §1) |

---

## Page 4 — Market & Segments

**Purpose:** Where the product wins, and where the whitespace is.

| Visual | Type | Binds to |
|---|---|---|
| MRR by industry | Treemap | `[MRR]` by `dim_customers[industry]` |
| ARPU by company size | Bar | `[ARPC]` by `dim_customers[company_size]` |
| Geographic MRR | Map / bar | `[MRR]` by `dim_customers[country]` |
| Industry × plan tier | Matrix (heat) | customer counts, `current_plan_tier` |
| Segment whitespace | Scatter | x=penetration, y=ARPU, label=segment (market_analysis §5) |

---

## Page 5 — Churn & Retention

**Purpose:** Who is at risk, and how do cohorts retain?

| Visual | Type | Binds to |
|---|---|---|
| Customers at risk | KPI card | `[Customers At Risk]` |
| MRR at risk | KPI card | `[MRR At Risk]`, `[% MRR At Risk]` |
| Risk band distribution | Donut | counts by `rpt_churn_risk[risk_band]` |
| Risk drivers | Stacked bar | avg of `pts_*` columns |
| Cohort retention heatmap | Matrix (color scale) | `rpt_cohort_retention[retention_rate]` by cohort × `months_since_signup` |
| At-risk account list | Table (top by score) | customer, MRR, score, band, top driver |

---

## Build order

1. Connect to the warehouse (see [`model_guide.md`](model_guide.md)).
2. Load the six mart tables; mark `fct_mrr[month_date]` as the date table key.
3. Create relationships (star schema — see model guide).
4. Create a `_Measures` table and paste [`measures.dax`](measures.dax).
5. Build pages 1→5 per the tables above.
6. Apply the theme JSON and sync slicers.
