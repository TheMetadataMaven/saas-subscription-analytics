"""
Render screenshot-style mockups of the finished Power BI report from the sample
data, using the color-blind-safe palette. Generates BOTH a dark and a light
version showing the whole dashboard.

Run:  py make_mockup.py   (needs: matplotlib)
Output: ../dashboard_mockup.png  and  ../dashboard_mockup_light.png
"""
import csv
from collections import defaultdict, OrderedDict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from matplotlib.colors import LinearSegmentedColormap

HERE = Path(__file__).resolve().parent
SRC = HERE / "sample_data"

# Color-blind-safe themes (blue = good, orange/vermillion = bad)
DARK = dict(
    name="dark", bg="#0f172a", surf="#1e293b", text="#e2e8f0", muted="#94a3b8",
    grid="#334155", accent="#2dd4bf", pos="#56b4e9", neg="#e69f00", warn="#f0e442",
    crit="#d55e00", blues=["#0f2740", "#38bdf8"], hi_text="#0f172a", lo_text="#e2e8f0",
    thr=80, out=HERE.parent / "dashboard_mockup.png",
)
LIGHT = dict(
    name="light", bg="#f1f5f9", surf="#ffffff", text="#0f172a", muted="#475569",
    grid="#cbd5e1", accent="#0d9488", pos="#0072b2", neg="#d55e00", warn="#e69f00",
    crit="#a33800", blues=["#e0f2fe", "#0072b2"], hi_text="#ffffff", lo_text="#0f172a",
    thr=70, out=HERE.parent / "dashboard_mockup_light.png",
)


def read(name):
    with (SRC / f"{name}.csv").open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


# ---------------- data (computed once) ----------------
mrr = read("fct_mrr")
ue = read("rpt_unit_economics")
risk = read("rpt_churn_risk")
cust = read("dim_customers")
cohort = read("rpt_cohort_retention")

months = [r["month_key"][2:] for r in mrr]
ending = [float(r["ending_mrr"]) for r in mrr]
netnew = [float(r["net_new_mrr"]) for r in mrr]
last = mrr[-1]
mrr_v = float(last["ending_mrr"])

# prior-month context for KPI deltas
prev = mrr[-2]
mrr_prev = float(prev["ending_mrr"])
mrr_mom = (mrr_v - mrr_prev) / mrr_prev * 100
nrr_v = float(last["nrr_pct"])
qr_v, qr_prev = float(last["quick_ratio"]), float(prev["quick_ratio"])
ltvcac = sum(float(r["ltv_to_cac_ratio"]) for r in ue) / len(ue)


def arrow(x):
    return "▲" if x >= 0 else "▼"   # ▲ / ▼


# (label, value, delta/status line, sentiment key)
kpis = [
    ("MRR", f"${mrr_v/1000:.1f}K", f"{arrow(mrr_mom)} {abs(mrr_mom):.1f}% MoM", "pos" if mrr_mom >= 0 else "neg"),
    ("ARR", f"${mrr_v*12/1e6:.2f}M", f"{arrow(mrr_mom)} {abs(mrr_mom):.1f}% MoM", "pos" if mrr_mom >= 0 else "neg"),
    ("Net Rev Retention", f"{nrr_v:.1f}%",
     ("▼ below 100% target" if nrr_v < 100 else "▲ above 100%"),
     "neg" if nrr_v < 100 else "pos"),
    ("LTV : CAC", f"{ltvcac:.1f}x", "✓ above 3.0 target", "pos"),
    ("Quick Ratio", f"{qr_v:.1f}", f"{arrow(qr_v - qr_prev)} from {qr_prev:.1f} last mo",
     "pos" if qr_v >= qr_prev else "neg"),
]

ue_sorted = sorted(ue, key=lambda r: float(r["ltv_to_cac_ratio"]))
ue_ch = [r["acquisition_channel"] for r in ue_sorted]
ue_val = [float(r["ltv_to_cac_ratio"]) for r in ue_sorted]

band_order = ["low", "medium", "high", "critical"]
band_ct = OrderedDict((b, 0) for b in band_order)
for r in risk:
    band_ct[r["risk_band"]] += 1

size_order = ["1-10", "11-50", "51-200", "201-500", "500+"]
size_sum, size_n = defaultdict(float), defaultdict(int)
for r in cust:
    size_sum[r["company_size"]] += float(r["current_mrr"])
    size_n[r["company_size"]] += 1
arpu = [size_sum[s] / size_n[s] if size_n[s] else 0 for s in size_order]

periods = ["M0", "M1", "M2", "M3", "M4", "M5", "M6"]
coh_rows = sorted({r["cohort_month_key"] for r in cohort})
mat = [[None] * len(periods) for _ in coh_rows]
for r in cohort:
    mat[coh_rows.index(r["cohort_month_key"])][periods.index(r["period_label"])] = float(r["retention_rate"])


def build(T):
    cmap = LinearSegmentedColormap.from_list("cvdblue", T["blues"])
    plt.rcParams.update({"text.color": T["text"], "axes.labelcolor": T["muted"],
                         "xtick.color": T["muted"], "ytick.color": T["muted"], "font.size": 9})
    fig = plt.figure(figsize=(15, 9.5), dpi=120, facecolor=T["bg"])
    gs = GridSpec(3, 6, figure=fig, height_ratios=[1.1, 1.1, 1.0],
                  hspace=0.55, wspace=0.7, left=0.05, right=0.97, top=0.75, bottom=0.06)

    fig.text(0.05, 0.965, "CloudSync Pro — Executive Analytics", fontsize=17,
             fontweight="bold", color=T["text"])
    fig.text(0.05, 0.943,
             "Sample data preview · color-blind-safe palette (blue = good, orange = caution)",
             fontsize=9.5, color=T["muted"])
    fig.text(0.97, 0.958, "FY2024 · as of Dec 2024", fontsize=10, color=T["muted"],
             ha="right", va="center")

    # KPI cards — evenly distributed, each with a delta / status line
    n, L, R, gap = len(kpis), 0.05, 0.97, 0.018
    w = (R - L - (n - 1) * gap) / n
    for i, (label, val, delta, sentiment) in enumerate(kpis):
        ax = fig.add_axes([L + i * (w + gap), 0.795, w, 0.118])
        ax.set_facecolor(T["surf"])
        for s in ax.spines.values():
            s.set_color(T["grid"])
        ax.set_xticks([]); ax.set_yticks([])
        ax.text(0.5, 0.74, val, ha="center", va="center", fontsize=17, fontweight="bold", color=T["text"])
        ax.text(0.5, 0.44, label.upper(), ha="center", va="center", fontsize=7.5, color=T["muted"])
        ax.text(0.5, 0.16, delta, ha="center", va="center", fontsize=8, color=T[sentiment])

    def style(ax, title):
        ax.set_facecolor(T["surf"])
        ax.set_title(title, color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
        for s in ax.spines.values():
            s.set_color(T["grid"])
        ax.tick_params(colors=T["muted"])
        ax.grid(color=T["grid"], alpha=0.5, linewidth=0.6)

    # MRR trajectory
    ax = fig.add_subplot(gs[0, 0:3]); style(ax, "MRR Trajectory")
    ax.plot(months, ending, color=T["accent"], linewidth=2.2)
    ax.fill_between(range(len(months)), ending, color=T["accent"], alpha=0.15)
    ax.set_ylim(0, max(ending) * 1.12)          # floor at 0 — no negative dead space
    ax.set_xticks(range(0, len(months), 2)); ax.set_xticklabels(months[::2])
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t/1000)}K" for t in ax.get_yticks()])
    ax.set_ylim(0, max(ending) * 1.12)

    # Net New MRR
    ax = fig.add_subplot(gs[0, 3:6]); style(ax, "Net New MRR by Month")
    ax.bar(months, netnew, color=T["pos"])
    ax.set_xticks(range(0, len(months), 2)); ax.set_xticklabels(months[::2])
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t/1000)}K" for t in ax.get_yticks()])

    # LTV:CAC by channel
    ax = fig.add_subplot(gs[1, 0:2]); style(ax, "LTV : CAC by Channel  (blue = 3.0+ target)")
    ax.barh(ue_ch, ue_val, color=[T["pos"] if v >= 3 else T["warn"] for v in ue_val])
    ax.axvline(3.0, color=T["muted"], linestyle="--", linewidth=1)
    ax.tick_params(axis="y", labelsize=7.5)

    # Churn risk donut
    ax = fig.add_subplot(gs[1, 2:4]); ax.set_facecolor(T["surf"])
    ax.set_title("Churn Risk Distribution", color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
    band_cols = {"low": T["pos"], "medium": T["warn"], "high": T["neg"], "critical": T["crit"]}
    ax.pie(list(band_ct.values()), colors=[band_cols[b] for b in band_order], startangle=90,
           wedgeprops=dict(width=0.42, edgecolor=T["bg"]),
           labels=[f"{b}\n{m}" for b, m in band_ct.items()],
           textprops=dict(color=T["text"], fontsize=8))

    # ARPU by company size (2 cols — no cramped rotation)
    ax = fig.add_subplot(gs[1, 4:6]); style(ax, "ARPU by Company Size")
    ax.bar(size_order, arpu, color=T["accent"])
    ax.set_xticks(range(len(size_order))); ax.set_xticklabels(size_order, fontsize=8)
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t)}" for t in ax.get_yticks()])

    # Cohort retention heatmap
    ax = fig.add_subplot(gs[2, 0:6]); ax.set_facecolor(T["surf"])
    ax.set_title("Cohort Retention Heatmap  (% of signup cohort still active)",
                 color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
    plot_mat = [[(v if v is not None else float("nan")) for v in row] for row in mat]
    ax.imshow(plot_mat, cmap=cmap, aspect="auto", vmin=55, vmax=100)
    ax.set_xticks(range(len(periods))); ax.set_xticklabels(periods)
    ax.set_yticks(range(len(coh_rows))); ax.set_yticklabels(coh_rows, fontsize=8)
    for i in range(len(coh_rows)):
        for j in range(len(periods)):
            v = mat[i][j]
            if v is not None:
                ax.text(j, i, f"{v:.0f}", ha="center", va="center",
                        color=T["hi_text"] if v >= T["thr"] else T["lo_text"], fontsize=8)
    for s in ax.spines.values():
        s.set_color(T["grid"])

    fig.savefig(T["out"], facecolor=T["bg"], bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {T['out']}")


if __name__ == "__main__":
    build(DARK)
    build(LIGHT)
