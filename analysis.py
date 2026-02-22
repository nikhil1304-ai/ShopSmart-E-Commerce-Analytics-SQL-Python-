"""
ShopSmart E-Commerce Analytics — Python Analysis
=================================================
Requirements:
    pip install pandas sqlalchemy pymysql matplotlib seaborn

Usage:
    1. Update credentials in the CONFIG block below.
    2. Run: python analysis.py
    3. Plots are saved as PNG files in the same directory.
"""

# ─────────────────────────────────────────────
# 0. IMPORTS & CONFIG
# ─────────────────────────────────────────────
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns
from sqlalchemy import create_engine, text
from datetime import date
from urllib.parse import quote_plus


# ── Edit these ──
USER     = "*****"
PASSWORD = quote_plus("******")
HOST     = "127.0.0.1"
PORT     = 3306
DB       = "shopsmart"
# ────────────────

engine = create_engine(
    f"mysql+pymysql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DB}",
    connect_args={"charset": "utf8mb4"}
)

# Quick connectivity check
with engine.connect() as conn:
    ver = conn.execute(text("SELECT VERSION()")).fetchone()[0]
    print(f"✅ Connected to MySQL {ver}")

sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams["figure.dpi"] = 130


# ─────────────────────────────────────────────
# C1-A. Pull Wide Fact Table
# ─────────────────────────────────────────────
print("\n📦 Loading fact table...")

fact_sql = """
SELECT
    o.order_id,
    o.order_date,
    o.order_status,
    o.channel,
    o.ship_carrier,
    o.delivered_date,

    c.customer_id,
    c.full_name,
    c.city,
    c.state,
    c.age,
    c.segment,
    c.signup_date,

    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    p.brand,
    p.unit_cost,

    i.line_no,
    i.quantity,
    i.list_price   AS item_list_price,
    i.discount_amount,
    i.unit_price,

    pay.grand_total,
    pay.tax_amount,
    pay.shipping_fee,
    pay.payment_status,
    pay.payment_method

FROM orders o
JOIN customers   c   ON c.customer_id = o.customer_id
JOIN order_items i   ON i.order_id    = o.order_id
JOIN products    p   ON p.product_id  = i.product_id
JOIN payments    pay ON pay.order_id  = o.order_id;
"""

df = pd.read_sql(fact_sql, engine, parse_dates=["order_date", "delivered_date", "signup_date"])
print(f"   Rows: {len(df):,}   |   Columns: {df.shape[1]}")


# ─────────────────────────────────────────────
# C1-B. Data Cleaning & Type Fixes
# ─────────────────────────────────────────────
print("\n🔧 Cleaning data...")

# Derived columns
df["revenue"]      = (df["unit_price"] * df["quantity"]).round(2)
df["profit"]       = ((df["unit_price"] - df["unit_cost"]) * df["quantity"]).round(2)
df["discount_pct"] = (df["discount_amount"] / df["item_list_price"].replace(0, pd.NA) * 100).round(2)
df["delivery_days"]= (df["delivered_date"] - df["order_date"]).dt.days
df["order_month"]  = df["order_date"].dt.to_period("M")

# Null summary
nulls = df.isna().sum()
nulls = nulls[nulls > 0]
print("   Nulls detected:")
print(nulls.to_string())

print("\n   Order status distribution:")
print(df.drop_duplicates("order_id")["order_status"].value_counts().to_string())


# ─────────────────────────────────────────────
# C1-C. RFM Analysis
# ─────────────────────────────────────────────
print("\n📊 Computing RFM...")

# Use only Delivered + Paid orders for RFM
rfm_base = df[
    (df["order_status"] == "Delivered") &
    (df["payment_status"] == "Paid")
].copy()

# Reference date = day after the latest order date in the data
ref_date = rfm_base["order_date"].max() + pd.Timedelta(days=1)

rfm = (
    rfm_base
    .groupby("customer_id")
    .agg(
        last_order  = ("order_date",  "max"),
        frequency   = ("order_id",    "nunique"),
        monetary    = ("grand_total",  "sum")           # grand_total is per-order, so need unique
    )
    .reset_index()
)

# Re-compute monetary correctly (grand_total repeated per line item — take order-level)
order_spend = (
    rfm_base
    .drop_duplicates(subset=["order_id", "customer_id"])
    .groupby("customer_id")["grand_total"]
    .sum()
    .reset_index()
    .rename(columns={"grand_total": "monetary"})
)

rfm = rfm.drop(columns="monetary").merge(order_spend, on="customer_id")
rfm["recency"] = (ref_date - rfm["last_order"]).dt.days

print(rfm[["recency", "frequency", "monetary"]].describe().round(2))


# ─────────────────────────────────────────────
# C1-D. RFM Scoring & Segmentation (4 buckets)
# ─────────────────────────────────────────────
# Score each metric 1-4 using quartiles
rfm["R_score"] = pd.qcut(rfm["recency"],   q=4, labels=[4, 3, 2, 1]).astype(int)   # lower recency = better
rfm["F_score"] = pd.qcut(rfm["frequency"].rank(method="first"), q=4, labels=[1, 2, 3, 4]).astype(int)
rfm["M_score"] = pd.qcut(rfm["monetary"].rank(method="first"),  q=4, labels=[1, 2, 3, 4]).astype(int)
rfm["RFM_score"] = rfm["R_score"] + rfm["F_score"] + rfm["M_score"]

def segment(row):
    if row["RFM_score"] >= 10:
        return "Champions"
    elif row["RFM_score"] >= 8:
        return "Loyal"
    elif row["RFM_score"] >= 5:
        return "Potential"
    else:
        return "At-Risk"

rfm["segment"] = rfm.apply(segment, axis=1)

seg_summary = rfm.groupby("segment").agg(
    customers   = ("customer_id", "count"),
    avg_revenue = ("monetary",    "mean"),
    avg_orders  = ("frequency",   "mean")
).round(2).sort_values("customers", ascending=False)

print("\n   RFM Segments:")
print(seg_summary.to_string())


# ─────────────────────────────────────────────
# PLOT 1: Monthly Revenue Line Chart
# ─────────────────────────────────────────────
print("\n📈 Plot 1: Monthly Revenue...")

monthly_rev = (
    df[df["order_status"].isin(["Delivered", "Returned"]) & (df["payment_status"] == "Paid")]
    .drop_duplicates(subset=["order_id"])
    .groupby("order_month")["grand_total"]
    .sum()
    .reset_index()
)
monthly_rev["order_month_dt"] = monthly_rev["order_month"].dt.to_timestamp()

fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(monthly_rev["order_month_dt"], monthly_rev["grand_total"], marker="o", linewidth=2.2, color="#2563EB")
ax.fill_between(monthly_rev["order_month_dt"], monthly_rev["grand_total"], alpha=0.12, color="#2563EB")
ax.set_title("Monthly Revenue (Delivered + Paid Orders)", fontsize=14, fontweight="bold", pad=12)
ax.set_xlabel("Month")
ax.set_ylabel("Revenue (₹)")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"₹{x/1e6:.1f}M"))
plt.xticks(rotation=30, ha="right")
plt.tight_layout()
plt.savefig("plot1_monthly_revenue.png")
plt.close()
print("   Saved → plot1_monthly_revenue.png")


# ─────────────────────────────────────────────
# PLOT 2: Top Categories — Revenue & Quantity
# ─────────────────────────────────────────────
print("\n📊 Plot 2: Top Categories...")

cat_stats = (
    df[df["order_status"] == "Delivered"]
    .groupby("category")
    .agg(revenue=("revenue", "sum"), quantity=("quantity", "sum"))
    .sort_values("revenue", ascending=False)
    .head(8)
    .reset_index()
)

fig, axes = plt.subplots(1, 2, figsize=(13, 5))

# Revenue
axes[0].barh(cat_stats["category"], cat_stats["revenue"] / 1e6, color="#7C3AED")
axes[0].set_xlabel("Revenue (₹ M)")
axes[0].set_title("Top Categories by Revenue", fontweight="bold")
axes[0].invert_yaxis()

# Quantity
axes[1].barh(cat_stats["category"], cat_stats["quantity"], color="#059669")
axes[1].set_xlabel("Units Sold")
axes[1].set_title("Top Categories by Quantity", fontweight="bold")
axes[1].invert_yaxis()

plt.tight_layout()
plt.savefig("plot2_top_categories.png")
plt.close()
print("   Saved → plot2_top_categories.png")


# ─────────────────────────────────────────────
# PLOT 3: Return Rate by Carrier
# ─────────────────────────────────────────────
print("\n📦 Plot 3: Return Rate by Carrier...")

carrier_df = (
    df.drop_duplicates("order_id")[["ship_carrier", "order_status"]]
)
carrier_df["is_returned"] = (carrier_df["order_status"] == "Returned").astype(int)

return_rate = (
    carrier_df
    .groupby("ship_carrier")
    .agg(total=("order_status", "count"), returned=("is_returned", "sum"))
    .reset_index()
)
return_rate["return_rate_%"] = (return_rate["returned"] / return_rate["total"] * 100).round(2)
return_rate = return_rate.sort_values("return_rate_%", ascending=False)

fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.bar(return_rate["ship_carrier"], return_rate["return_rate_%"], color="#DC2626", edgecolor="white")
ax.bar_label(bars, fmt="%.1f%%", padding=3, fontsize=9)
ax.set_title("Return Rate by Carrier", fontsize=14, fontweight="bold", pad=12)
ax.set_xlabel("Carrier")
ax.set_ylabel("Return Rate (%)")
ax.set_ylim(0, return_rate["return_rate_%"].max() * 1.2)
plt.tight_layout()
plt.savefig("plot3_return_rate_carrier.png")
plt.close()
print("   Saved → plot3_return_rate_carrier.png")


# ─────────────────────────────────────────────
# PLOT 4: RFM Segment Distribution (Bonus)
# ─────────────────────────────────────────────
print("\n🏷️  Plot 4: RFM Segments...")

seg_colors = {"Champions": "#16A34A", "Loyal": "#2563EB", "Potential": "#D97706", "At-Risk": "#DC2626"}
seg_cnt = rfm["segment"].value_counts().reset_index()
seg_cnt.columns = ["segment", "count"]

fig, ax = plt.subplots(figsize=(7, 5))
bars = ax.bar(seg_cnt["segment"], seg_cnt["count"],
              color=[seg_colors[s] for s in seg_cnt["segment"]], edgecolor="white")
ax.bar_label(bars, padding=3, fontsize=10)
ax.set_title("Customer Segments (RFM)", fontsize=14, fontweight="bold", pad=12)
ax.set_xlabel("Segment")
ax.set_ylabel("Number of Customers")
plt.tight_layout()
plt.savefig("plot4_rfm_segments.png")
plt.close()
print("   Saved → plot4_rfm_segments.png")


# ─────────────────────────────────────────────
# EXPORT RFM Table
# ─────────────────────────────────────────────
rfm.to_csv("rfm_output.csv", index=False)
print("\n✅ RFM table saved → rfm_output.csv")

print("\n🎉 All done! Files generated:")
print("   plot1_monthly_revenue.png")
print("   plot2_top_categories.png")
print("   plot3_return_rate_carrier.png")
print("   plot4_rfm_segments.png")
print("   rfm_output.csv")