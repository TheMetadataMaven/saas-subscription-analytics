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

**Measures** (on `fct_mrr`): MRR, ARR, Net New MRR, Net Revenue Retention %,
Quick Ratio, Active Customers, ARPC, LTV : CAC, CAC Payback (months),
Acquisition ROI %, CAC, Customers At Risk, MRR At Risk.

## 5. Build the Executive page (≈5 min)

The page **Executive Overview** is intentionally empty. Drag these on:

| Visual | Field / measure |
|---|---|
| Card | `MRR` |
| Card | `ARR` |
| Card | `Net Revenue Retention %` |
| Card | `LTV : CAC` |
| Line chart | Axis `month_key`, Values `MRR` (or `ending_mrr`) |
| Clustered bar | Axis `acquisition_channel`, Values `ltv_to_cac_ratio` |
| Donut | Legend `risk_band`, Values count of `customer_id` |

Then **View → Themes → Browse for themes → `../theme.json`** for the
color-blind-safe palette. The full 5-page layout is in `../report_spec.md`.

## Notes

- This was authored as text and **could not be test-opened in the environment
  that generated it**. If Power BI reports a schema error on open, tell me the
  exact message and I'll correct the offending file — PBIP is strict about its
  format and versions.
- The sample data is illustrative. To use **real** data, repoint each table's
  Power Query source from the CSVs to your BigQuery marts (see
  `../model_guide.md`); the measures stay the same.
