# SQL + Python Assignment (MySQL): ShopSmart E‑Commerce Analytics

## Learning goals
Students will learn to:
1) Create a relational schema and enforce keys
2) Load data into MySQL using CSVs / SQL scripts
3) Write EDA queries (joins, GROUP BY, window functions, CTEs)
4) Pull results into Python (pandas) and continue EDA/visualizations
5) Produce a short insights report

---

## Dataset files (provided)
- customers.csv  (250 rows)
- products.csv   (120 rows)
- orders.csv     (900 rows)
- order_items.csv (2682 rows)
- payments.csv   (900 rows)

SQL scripts:
- 01_schema.sql
- 02_load_csv.sql      (recommended loading path)
- 03_insert_data.sql   (fallback loading path)

--- 

## Part A — MySQL setup (students)
### A1) Create DB + tables
1. Open MySQL Workbench (or CLI).
2. Run `01_schema.sql`.

### A2) Load data (choose one method)
**Method 1 (recommended): CSV load**
1. Place all CSVs in one local folder.
2. Open `02_load_csv.sql` and replace `PATH_TO/` with your folder path.
3. Enable LOCAL INFILE if needed:
   - `SET GLOBAL local_infile=1;`
4. Run `02_load_csv.sql`.

**Method 2 (fallback): INSERT statements**
1. Run `03_insert_data.sql` (takes longer).

### A3) Validate counts
Run:
```sql
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM payments;
```

Expected (approx):
- customers=250
- products=120
- orders=900
- order_items=2682
- payments=900

---

## Part B — SQL EDA tasks (students)
Create a `.sql` file and answer each task with:
- the SQL query
- the output screenshot (or result table exported)
- 1–2 lines of interpretation

### B1) Basic sanity checks
1. Are there duplicate customer emails?
2. Null checks for delivered_date by status.
3. Orders by status distribution.

### B2) Revenue & growth
4. Total revenue (grand_total) for Delivered orders only.
5. Monthly revenue trend (YYYY-MM).
6. Channel-wise revenue split per month.

### B3) Customer analytics
7. Top 10 customers by lifetime revenue.
8. Repeat purchase rate:
   - % customers with >= 2 Delivered orders.
9. Cohort retention:
   - Cohort by signup month; compute active ordering months after signup (0,1,2…).

### B4) Product & category analytics
10. Top categories by revenue and by quantity.
11. Discount impact:
   - avg discount % by category and brand.
12. Profit estimate:
   - profit = (unit_price - unit_cost) * quantity; show top 10 products by profit.

### B5) Operations & delivery
13. Avg delivery days (delivered_date - order_date) by carrier.
14. Return rate by carrier and by category.
15. COD vs prepaid: compare cancellation rate.

### B6) Advanced SQL (window functions)
16. For each month, rank categories by revenue (dense_rank).
17. For each customer, compute:
   - first order date, last order date, days since last order,
   - running total spend over time.
18. Basket analysis (simple):
   - For Delivered orders, top 20 pairs of categories appearing in same order.

---

## Part C — Python + SQL analysis
Use `python_starter.py` (edit credentials).

### C1) Required Python tasks
1. Connect to MySQL with SQLAlchemy.
2. Pull a wide “fact table” via joins (orders + items + customers + products + payments).
3. Handle data types (dates, numeric) and missing values.
4. Compute in pandas:
   - RFM (recency/frequency/monetary) for customers
   - segment customers into 4 buckets (e.g., Champions, Loyal, Potential, At‑Risk)
5. Visualizations (matplotlib):
   - monthly revenue line chart
   - top categories bar chart
   - return rate by carrier bar chart

### C2) Bonus
- Build a small dashboard in Streamlit (optional)
- Create a parameterized SQL query function in Python (date range, channel, category)

---

## Deliverables
1) `answers.sql` with all queries (clearly numbered)
2) `analysis.ipynb` or `analysis.py` with Python EDA + plots
3) `insights.pdf` (1–2 pages):
   - 5 key insights
   - 3 recommendations (business actions)

---

## Evaluation rubric (100)
- Correct DB setup & data load: 10
- SQL correctness & readability: 35
- Analytical depth (insights, not just queries): 20
- Python EDA & plots: 25
- Report quality: 10
