# Open CloudSyncPro in Power BI Desktop

This is a **PBIP** (Power BI Project) — the text-based, git-friendly Power BI
format. It contains a complete semantic model (3 tables, sample data, and all
the KPI measures) and an empty report page ready for you to drop visuals onto.

## 1. Enable the PBIP format (one-time, if not already on)

Recent Power BI Desktop opens `.pbip` directly. If yours doesn't:
**File → Options and settings → Options → Preview features → check
"Power BI Project (.pbip) save option"** → OK → restart Power BI Desktop.

Use an up-to-date Power BI Desktop (2024 or newer).

## 2. Open it

**File → Open report → Browse** and pick **`CloudSyncPro.pbip`**
(double-clicking the `.pbip` in Explorer also works once the format is enabled).

## 3. Load the sample data

The model reads three CSVs from the `sample_data/` folder via a parameter
called **`DataFolder`**, which defaults to this project's path on this machine:

```
...\powerbi\CloudSyncPro\sample_data
```

- If you kept the project where it is, just click **Refresh** — data loads.
- If you moved it: **Transform data → Manage Parameters → DataFolder** and set
  it to the new absolute path to `sample_data`, then **Close & Apply**.

## 4. What you get

**Tables**
- `fct_mrr` — 12 monthly rows (MRR, movements, NRR, Quick Ratio, ARPC)
- `rpt_unit_economics` — 10 channels (CAC, LTV, LTV:CAC, payback, ROI)
- `rpt_churn_risk` — sample at-risk customers by band
- `dim_customers` — 24 customers (industry, size, country, plan, status, MRR)
- `dim_subscriptions` — 24 subscriptions (plan, billing, tenure, status)
- `rpt_cohort_retention` — cohort × period retention matrix

**Measures** include: MRR, ARR, Net New MRR, MRR (monthly), Net Revenue
Retention %, Quick Ratio, Active Customers, ARPC, LTV : CAC, CAC Payback,
Acquisition ROI %, CAC, Customers At Risk, MRR At Risk, Avg LTV:CAC,
Avg Payback (mo), Avg ROI %, Customer Count, Total MRR, ARPU, Total Customers,
Avg Retention %.

**Two relationships** link `dim_subscriptions` and `rpt_churn_risk` to
`dim_customers`.

## 5. The report is pre-built (3 pages)

Visuals are already placed — just open and look:

| Page | Visuals |
|---|---|
| **Executive Overview** | Cards: MRR, ARR, NRR %, Quick Ratio · Line: MRR by month · Column: Net New MRR by month |
| **Unit Economics & Risk** | Cards: Avg LTV:CAC, Avg Payback, Avg ROI % · Bar: LTV:CAC by channel · Donut: customers by risk band |
| **Market & Segments** | Treemap: MRR by industry · Column: ARPU by company size · Bar: MRR by country |

Then **View → Themes → Browse for themes → `../theme.json`** for the
color-blind-safe palette. The full 5-page target layout is in `../report_spec.md`
if you want to extend it (e.g., a cohort heatmap from `rpt_cohort_retention`).

> If a visual opens empty, its field role just needs a nudge — click the visual
> and re-drop the listed field/measure. The data and measures are all present.

## Notes

- This was authored as text and **could not be test-opened in the environment
  that generated it**. If Power BI reports a schema error on open, tell me the
  exact message and I'll correct the offending file — PBIP is strict about its
  format and versions.
- The sample data is illustrative. To use **real** data, repoint each table's
  Power Query source from the CSVs to your BigQuery marts (see
  `../model_guide.md`); the measures stay the same.
