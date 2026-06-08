# Power BI Report — CloudSync Pro Analytics

This folder contains everything needed to build the executive Power BI report
on top of the dbt marts, plus a live visual preview.

## Contents

| File | What it is |
|---|---|
| [`dashboard_preview.html`](dashboard_preview.html) | **Open in a browser** — interactive preview of the Executive Overview page (Chart.js). Uses representative sample figures to show layout, theme, and chart types. |
| [`report_spec.md`](report_spec.md) | Page-by-page build sheet: 5 pages, every visual, its type, and the measure/field it binds to. |
| [`measures.dax`](measures.dax) | Complete DAX measure library — all primary enterprise KPIs (MRR, ARR, NRR, GRR, churn, Quick Ratio, ARPC, CAC, LTV, LTV:CAC, payback, ROI, Rule of 40, Magic Number, churn-risk, cohort). |
| [`model_guide.md`](model_guide.md) | How to connect Power BI to the BigQuery marts, the date table, and the star-schema relationships. |
| [`theme.json`](theme.json) | Color-blind-safe Power BI theme (blue/orange sentiment, dark surface). Import via **View → Themes → Browse for themes**. |
| [`CloudSyncPro/`](CloudSyncPro) | **Loadable Power BI project (PBIP)** — open `CloudSyncPro.pbip` in Power BI Desktop. Includes the semantic model, sample data, and all measures. See [`CloudSyncPro/HOW_TO_OPEN.md`](CloudSyncPro/HOW_TO_OPEN.md). |

## Build in ~30 minutes

1. **Connect** Power BI Desktop to BigQuery and load the six mart tables
   (`model_guide.md` §1).
2. **Date table** — add the `Calendar` table and mark it (`model_guide.md` §2).
3. **Relationships** — wire the star schema (`model_guide.md` §3).
4. **Measures** — create a `_Measures` table and paste `measures.dax`.
5. **Pages** — build pages 1–5 from `report_spec.md`.

## KPIs covered

**Revenue:** MRR · ARR · New/Expansion/Contraction/Churned/Net-New MRR ·
MRR growth.
**Retention:** Net Revenue Retention · Gross Revenue Retention · Gross MRR
churn · Logo churn · Quick Ratio.
**Customers:** Active/Paying customers · ARPC/ARPU · ARPA.
**Unit economics:** CAC · Realized & Predicted LTV · LTV:CAC · CAC payback ·
Acquisition ROI · Revenue per spend $.
**Board/efficiency:** Rule of 40 · Magic Number · Burn multiple.
**Risk & cohorts:** Customers at risk · MRR at risk · cohort retention.

## Accessibility

Colors follow a **color-blind-safe** scheme: sentiment is **blue (good) / orange
(bad)** rather than green/red, so it's legible for red-green color vision
deficiency (~8% of men). Severity ramps also vary in lightness so they read in
grayscale, and every color cue is paired with a second signal (▲/▼ arrow, data
label, or text status). Apply `theme.json` and keep that pairing when adding
visuals.

## Note on file format

This is the **source-and-spec** package (DAX + report definition + live HTML
preview) rather than a binary `.pbix`. It's intentionally text-based so it
diffs cleanly in git and rebuilds in minutes against your own warehouse. If you
prefer a committed `.pbix`/PBIP project file, build it once from this spec and
save it here.
