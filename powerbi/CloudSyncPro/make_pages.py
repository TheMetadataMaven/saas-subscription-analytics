"""
Render per-page mockups of the 3-page Power BI report (Executive / Unit
Economics & Risk / Market & Segments), in dark and light color-blind-safe
themes, from the sample data.

Run:  py make_pages.py   (needs: matplotlib)
Output (in ../):  page_executive[_light].png, page_unit_economics[_light].png,
                  page_market[_light].png
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
OUTDIR = HERE.parent

DARK = dict(name="dark", bg="#0f172a", surf="#1e293b", text="#e2e8f0", muted="#94a3b8",
            grid="#334155", accent="#2dd4bf", pos="#56b4e9", neg="#e69f00", warn="#f0e442",
            crit="#d55e00", blues=["#0f2740", "#38bdf8"], hi_text="#0f172a", lo_text="#e2e8f0", thr=80, sfx="")
LIGHT = dict(name="light", bg="#f1f5f9", surf="#ffffff", text="#0f172a", muted="#475569",
             grid="#cbd5e1", accent="#0d9488", pos="#0072b2", neg="#d55e00", warn="#e69f00",
             crit="#a33800", blues=["#e0f2fe", "#0072b2"], hi_text="#ffffff", lo_text="#0f172a", thr=70, sfx="_light")


def read(name):
    with (SRC / f"{name}.csv").open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


mrr = read("fct_mrr")
ue = read("rpt_unit_economics")
risk = read("rpt_churn_risk")
cust = read("dim_customers")
subs = read("dim_subscriptions")

months = [r["month_key"][2:] for r in mrr]
ending = [float(r["ending_mrr"]) for r in mrr]
active = [int(r["active_customers"]) for r in mrr]
last, prev = mrr[-1], mrr[-2]

# unit economics
ue_sorted = sorted(ue, key=lambda r: float(r["ltv_to_cac_ratio"]))
ch = [r["acquisition_channel"] for r in ue_sorted]
ltvcac = [float(r["ltv_to_cac_ratio"]) for r in ue_sorted]
cac = [float(r["cac"]) for r in ue_sorted]
rltv = [float(r["realized_ltv"]) for r in ue_sorted]
roi = [float(r["acquisition_roi_pct"]) for r in ue_sorted]
avg_ltvcac = sum(float(r["ltv_to_cac_ratio"]) for r in ue) / len(ue)
avg_payback = sum(float(r["cac_payback_months"]) for r in ue) / len(ue)
avg_roi = sum(float(r["acquisition_roi_pct"]) for r in ue) / len(ue)

# churn risk
band_order = ["low", "medium", "high", "critical"]
band_ct = OrderedDict((b, 0) for b in band_order)
for r in risk:
    band_ct[r["risk_band"]] += 1
at_risk = band_ct["high"] + band_ct["critical"]
mrr_at_risk = sum(float(r["mrr_at_risk"]) for r in risk)

# customers / market
total_cust = len(cust)
paying = sum(1 for r in cust if r["customer_status"] == "active_paying")
total_mrr = sum(float(r["current_mrr"]) for r in cust)
arpu_all = total_mrr / total_cust
size_order = ["1-10", "11-50", "51-200", "201-500", "500+"]
size_sum, size_n = defaultdict(float), defaultdict(int)
ind_mrr = defaultdict(float)
ctry_mrr = defaultdict(float)
tier_order = ["free", "professional", "business", "enterprise"]
inds = sorted({r["industry"] for r in cust})
itmat = [[0] * len(tier_order) for _ in inds]
for r in cust:
    size_sum[r["company_size"]] += float(r["current_mrr"]); size_n[r["company_size"]] += 1
    ind_mrr[r["industry"]] += float(r["current_mrr"])
    ctry_mrr[r["country"]] += float(r["current_mrr"])
    itmat[inds.index(r["industry"])][tier_order.index(r["current_plan_tier"])] += 1
arpu = [size_sum[s] / size_n[s] if size_n[s] else 0 for s in size_order]

# ARR by plan tier (active subscriptions)
tier_mrr = defaultdict(float)
for r in subs:
    if r["status"] == "active":
        tier_mrr[r["plan_tier"]] += float(r["mrr"])
tier_arr = [tier_mrr[t] * 12 for t in tier_order]

# MRR movement waterfall (latest month)
nw, ex, co, cu, nn = (float(last[k]) for k in
                      ("new_mrr", "expansion_mrr", "contraction_mrr", "churned_mrr", "net_new_mrr"))


def fmt_money(v):
    return f"${v/1e6:.2f}M" if v >= 1e6 else (f"${v/1000:.1f}K" if v >= 1000 else f"${v:,.0f}")


def header(fig, T, title, sub):
    fig.text(0.05, 0.955, title, fontsize=17, fontweight="bold", color=T["text"])
    fig.text(0.05, 0.925, sub, fontsize=9.5, color=T["muted"])
    fig.text(0.97, 0.945, "FY2024 · as of Dec 2024", fontsize=10, color=T["muted"], ha="right", va="center")


def cards(fig, T, items):
    n, Lx, Rx, gap = len(items), 0.05, 0.97, 0.018
    w = (Rx - Lx - (n - 1) * gap) / n
    for i, (label, val, delta, sent) in enumerate(items):
        ax = fig.add_axes([Lx + i * (w + gap), 0.77, w, 0.115])
        ax.set_facecolor(T["surf"])
        for s in ax.spines.values():
            s.set_color(T["grid"])
        ax.set_xticks([]); ax.set_yticks([])
        ax.text(0.5, 0.72, val, ha="center", va="center", fontsize=17, fontweight="bold", color=T["text"])
        ax.text(0.5, 0.42, label.upper(), ha="center", va="center", fontsize=7.5, color=T["muted"])
        ax.text(0.5, 0.14, delta, ha="center", va="center", fontsize=8, color=T[sent])


def style(ax, T, title):
    ax.set_facecolor(T["surf"])
    ax.set_title(title, color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
    for s in ax.spines.values():
        s.set_color(T["grid"])
    ax.tick_params(colors=T["muted"])
    ax.grid(color=T["grid"], alpha=0.5, linewidth=0.6)


def new_fig(T):
    plt.rcParams.update({"text.color": T["text"], "axes.labelcolor": T["muted"],
                         "xtick.color": T["muted"], "ytick.color": T["muted"], "font.size": 9})
    fig = plt.figure(figsize=(15, 8.6), dpi=120, facecolor=T["bg"])
    gs = GridSpec(2, 6, figure=fig, hspace=0.5, wspace=0.75,
                  left=0.06, right=0.96, top=0.72, bottom=0.08)
    return fig, gs


def save(fig, T, stem):
    out = OUTDIR / f"{stem}{T['sfx']}.png"
    fig.savefig(out, facecolor=T["bg"], bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {out}")


# ---------------- Page 1: Executive ----------------
def page_executive(T):
    fig, gs = new_fig(T)
    header(fig, T, "Executive Overview", "Revenue health, growth, and retention at a glance")
    mom = (float(last["ending_mrr"]) - float(prev["ending_mrr"])) / float(prev["ending_mrr"]) * 100
    nrr = float(last["nrr_pct"]); qr, qrp = float(last["quick_ratio"]), float(prev["quick_ratio"])
    ac, acp = active[-1], active[-2]
    cards(fig, T, [
        ("MRR", fmt_money(ending[-1]), f"▲ {mom:.1f}% MoM", "pos"),
        ("ARR", fmt_money(ending[-1] * 12), f"▲ {mom:.1f}% MoM", "pos"),
        ("Net Rev Retention", f"{nrr:.1f}%", "▼ below 100% target", "neg"),
        ("Quick Ratio", f"{qr:.1f}", f"▼ from {qrp:.1f} last mo", "neg"),
        ("Active Customers", f"{ac:,}", f"▲ {ac-acp} MoM", "pos"),
    ])
    ax = fig.add_subplot(gs[0, 0:3]); style(ax, T, "MRR Trajectory")
    ax.plot(months, ending, color=T["accent"], linewidth=2.2)
    ax.fill_between(range(len(months)), ending, color=T["accent"], alpha=0.15)
    ax.set_ylim(0, max(ending) * 1.12)
    ax.set_xticks(range(0, len(months), 2)); ax.set_xticklabels(months[::2])
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t/1000)}K" for t in ax.get_yticks()]); ax.set_ylim(0, max(ending) * 1.12)

    ax = fig.add_subplot(gs[0, 3:6]); style(ax, T, "MRR Movement Waterfall — Dec 2024")
    labels = ["New", "Expansion", "Contraction", "Churn", "Net New"]
    heights = [nw, ex, co, cu, nn]
    bottoms = [0, nw, nw + ex - co, nn, 0]
    colors = [T["pos"], T["pos"], T["neg"], T["neg"], T["accent"]]
    ax.bar(labels, heights, bottom=bottoms, color=colors)
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t/1000)}K" for t in ax.get_yticks()])
    ax.tick_params(axis="x", labelsize=8)

    ax = fig.add_subplot(gs[1, 0:3]); style(ax, T, "ARR by Plan Tier")
    ax.bar([t.title() for t in tier_order], tier_arr, color=T["pos"])
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t/1000)}K" for t in ax.get_yticks()])

    ax = fig.add_subplot(gs[1, 3:6]); style(ax, T, "Active Customers by Month")
    ax.plot(months, active, color=T["accent"], linewidth=2.2, marker="o", markersize=3)
    ax.set_ylim(0, max(active) * 1.15)
    ax.set_xticks(range(0, len(months), 2)); ax.set_xticklabels(months[::2])
    save(fig, T, "page_executive")


# ---------------- Page 2: Unit Economics & Risk ----------------
def page_unit_economics(T):
    fig, gs = new_fig(T)
    header(fig, T, "Unit Economics & Risk", "Acquisition efficiency and churn exposure by channel")
    cards(fig, T, [
        ("Avg LTV : CAC", f"{avg_ltvcac:.1f}x", "✓ above 3.0 target", "pos"),
        ("Avg CAC Payback", f"{avg_payback:.1f} mo", "✓ under 12 mo", "pos"),
        ("Avg Acq ROI", f"{avg_roi:.0f}%", "blended, realized", "pos"),
        ("Customers At Risk", f"{at_risk}", "high + critical bands", "neg"),
        ("MRR At Risk", fmt_money(mrr_at_risk), f"{mrr_at_risk/total_mrr*100:.0f}% of MRR", "neg"),
    ])
    ax = fig.add_subplot(gs[0, 0:3]); style(ax, T, "LTV : CAC by Channel  (blue = 3.0+ target)")
    ax.barh(ch, ltvcac, color=[T["pos"] if v >= 3 else T["warn"] for v in ltvcac])
    ax.axvline(3.0, color=T["muted"], linestyle="--", linewidth=1); ax.tick_params(axis="y", labelsize=7.5)

    ax = fig.add_subplot(gs[0, 3:6]); style(ax, T, "CAC vs Realized LTV by Channel")
    y = range(len(ch)); hh = 0.4
    ax.barh([i + hh/2 for i in y], rltv, height=hh, color=T["pos"], label="Realized LTV")
    ax.barh([i - hh/2 for i in y], cac, height=hh, color=T["neg"], label="CAC")
    ax.set_yticks(list(y)); ax.set_yticklabels(ch, fontsize=7.5)
    ax.legend(facecolor=T["surf"], edgecolor=T["grid"], labelcolor=T["text"], fontsize=8)
    ax.set_xticks(ax.get_xticks()); ax.set_xticklabels([f"${int(t)}" for t in ax.get_xticks()])

    ax = fig.add_subplot(gs[1, 0:3]); style(ax, T, "Acquisition ROI % by Channel")
    ax.barh(ch, roi, color=T["accent"]); ax.tick_params(axis="y", labelsize=7.5)
    ax.set_xticks(ax.get_xticks()); ax.set_xticklabels([f"{int(t)}%" for t in ax.get_xticks()])

    ax = fig.add_subplot(gs[1, 3:6]); ax.set_facecolor(T["surf"])
    ax.set_title("Churn Risk Distribution", color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
    band_cols = {"low": T["pos"], "medium": T["warn"], "high": T["neg"], "critical": T["crit"]}
    ax.pie(list(band_ct.values()), colors=[band_cols[b] for b in band_order], startangle=90,
           wedgeprops=dict(width=0.42, edgecolor=T["bg"]),
           labels=[f"{b}\n{m}" for b, m in band_ct.items()], textprops=dict(color=T["text"], fontsize=8))
    save(fig, T, "page_unit_economics")


# ---------------- Page 3: Market & Segments ----------------
def page_market(T):
    fig, gs = new_fig(T)
    header(fig, T, "Market & Segments", "Where the product wins — by industry, size, and geography")
    cards(fig, T, [
        ("Total Customers", f"{total_cust}", "in sample", "pos"),
        ("Paying Customers", f"{paying}", f"{paying/total_cust*100:.0f}% of base", "pos"),
        ("Total MRR", fmt_money(total_mrr), "current book", "pos"),
        ("Avg ARPU", f"${arpu_all:,.0f}", "per customer", "pos"),
        ("Top Industry", max(ind_mrr, key=ind_mrr.get), f"{fmt_money(max(ind_mrr.values()))} MRR", "pos"),
    ])
    ax = fig.add_subplot(gs[0, 0:3]); style(ax, T, "MRR by Industry")
    items = sorted(ind_mrr.items(), key=lambda kv: kv[1])
    ax.barh([k for k, _ in items], [v for _, v in items], color=T["accent"])
    ax.set_xticks(ax.get_xticks()); ax.set_xticklabels([f"${int(t)}" for t in ax.get_xticks()])

    ax = fig.add_subplot(gs[0, 3:6]); style(ax, T, "MRR by Country")
    items = sorted(ctry_mrr.items(), key=lambda kv: kv[1])
    ax.barh([k for k, _ in items], [v for _, v in items], color=T["pos"])
    ax.set_xticks(ax.get_xticks()); ax.set_xticklabels([f"${int(t)}" for t in ax.get_xticks()])

    ax = fig.add_subplot(gs[1, 0:3]); style(ax, T, "ARPU by Company Size")
    ax.bar(size_order, arpu, color=T["accent"])
    ax.set_xticks(range(len(size_order))); ax.set_xticklabels(size_order, fontsize=8)
    ax.set_yticks(ax.get_yticks()); ax.set_yticklabels([f"${int(t)}" for t in ax.get_yticks()])

    ax = fig.add_subplot(gs[1, 3:6]); ax.set_facecolor(T["surf"])
    ax.set_title("Customers by Industry × Plan Tier", color=T["text"], fontsize=10.5, fontweight="bold", loc="left", pad=8)
    cmap = LinearSegmentedColormap.from_list("cvdblue", T["blues"])
    mx = max(max(row) for row in itmat) or 1
    ax.imshow(itmat, cmap=cmap, aspect="auto", vmin=0, vmax=mx)
    ax.set_xticks(range(len(tier_order))); ax.set_xticklabels([t.title() for t in tier_order], fontsize=8)
    ax.set_yticks(range(len(inds))); ax.set_yticklabels(inds, fontsize=8)
    for i in range(len(inds)):
        for j in range(len(tier_order)):
            v = itmat[i][j]
            if v:
                ax.text(j, i, str(v), ha="center", va="center", fontsize=8,
                        color=T["hi_text"] if v >= mx * 0.6 else T["lo_text"])
    for s in ax.spines.values():
        s.set_color(T["grid"])
    save(fig, T, "page_market")


if __name__ == "__main__":
    for T in (DARK, LIGHT):
        page_executive(T)
        page_unit_economics(T)
        page_market(T)
