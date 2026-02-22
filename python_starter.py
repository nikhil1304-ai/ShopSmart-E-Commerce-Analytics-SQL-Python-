"""ShopSmart SQL Assignment - Python Starter

Prereqs:
  pip install pandas sqlalchemy pymysql matplotlib

Recommended: use SQLAlchemy engine + pandas.read_sql for analysis.
"""

import pandas as pd
from sqlalchemy import create_engine, text

# 1) Connection string (edit username/password/host/port)
USER = "root"
PASSWORD = "your_password"
HOST = "127.0.0.1"
PORT = 3306
DB = "shopsmart"

# MySQL connection URL (PyMySQL driver)
engine = create_engine(f"mysql+pymysql://{USER}:{PASSWORD}@{HOST}:{PORT}/{DB}")

# 2) Quick test
with engine.connect() as conn:
    print(conn.execute(text("SELECT VERSION()")).fetchone())

# 3) Example: load a query result into a DataFrame
q = """
SELECT o.order_id, o.order_date, o.order_status,
       c.customer_id, c.city, c.segment,
       p.category,
       i.quantity, i.unit_price,
       pay.grand_total
FROM orders o
JOIN customers c   ON c.customer_id = o.customer_id
JOIN order_items i ON i.order_id = o.order_id
JOIN products p    ON p.product_id = i.product_id
JOIN payments pay  ON pay.order_id = o.order_id
LIMIT 1000;
"""

df = pd.read_sql(q, engine)
print(df.head())

# 4) Simple Python EDA examples
print("Rows:", len(df))
print(df.isna().sum())

# Aggregation
daily_sales = pd.read_sql("""
SELECT order_date, ROUND(SUM(grand_total),2) AS revenue
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status IN ('Delivered','Returned') AND p.payment_status='Paid'
GROUP BY order_date
ORDER BY order_date;
""", engine)

print(daily_sales.head())

# Optional plot (matplotlib)
import matplotlib.pyplot as plt
plt.figure()
plt.plot(pd.to_datetime(daily_sales['order_date']), daily_sales['revenue'])
plt.xticks(rotation=45)
plt.tight_layout()
plt.title("Daily Revenue")
plt.show()
