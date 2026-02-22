-- ========================================
-- ShopSmart SQL Assignment - Answers
-- Part B: SQL EDA Tasks (B1-B18)
-- ========================================

USE shopsmart;

-- ========================================
-- B1) BASIC SANITY CHECKS
-- ========================================

-- B1.1) Are there duplicate customer emails?
SELECT email, COUNT(*) AS count
FROM customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;

-- Interpretation: This checks for duplicate emails. 
-- If result is empty, all emails are unique (good data quality).


-- B1.2) Null checks for delivered_date by status
SELECT 
    order_status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN delivered_date IS NULL THEN 1 ELSE 0 END) AS null_delivered_date,
    SUM(CASE WHEN delivered_date IS NOT NULL THEN 1 ELSE 0 END) AS has_delivered_date
FROM orders
GROUP BY order_status
ORDER BY order_status;

-- Interpretation: Delivered orders should have delivered_date filled.
-- Cancelled/Returned might have nulls (which is expected).


-- B1.3) Orders by status distribution
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- Interpretation: Shows the proportion of Delivered vs Cancelled vs Returned orders.
-- Helps understand order fulfillment success rate.


-- ========================================
-- B2) REVENUE & GROWTH
-- ========================================

-- B2.4) Total revenue (grand_total) for Delivered orders only
SELECT 
    ROUND(SUM(p.grand_total), 2) AS total_revenue
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE o.order_status = 'Delivered'
  AND p.payment_status = 'Paid';

-- Interpretation: This is the actual realized revenue (only paid + delivered).
-- Excludes cancelled/returned orders.


-- B2.5) Monthly revenue trend (YYYY-MM)
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(SUM(p.grand_total), 2) AS monthly_revenue
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND p.payment_status = 'Paid'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- Interpretation: Shows revenue trend over time.
-- Useful to identify growth, seasonality, or declining months.


-- B2.6) Channel-wise revenue split per month
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    o.channel,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(p.grand_total), 2) AS revenue
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND p.payment_status = 'Paid'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m'), o.channel
ORDER BY month, revenue DESC;

-- Interpretation: Shows which channel (Web/Mobile/Marketplace) drives revenue each month.
-- Helps allocate marketing budget.


-- ========================================
-- B3) CUSTOMER ANALYTICS
-- ========================================

-- B3.7) Top 10 customers by lifetime revenue
SELECT 
    c.customer_id,
    c.full_name,
    c.city,
    c.segment,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.grand_total), 2) AS lifetime_revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND p.payment_status = 'Paid'
GROUP BY c.customer_id, c.full_name, c.city, c.segment
ORDER BY lifetime_revenue DESC
LIMIT 10;

-- Interpretation: These are VIP customers. 
-- Focus retention efforts here (loyalty programs, personalized offers).


-- B3.8) Repeat purchase rate
WITH customer_orders AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) AS repeat_customers,
    COUNT(*) AS total_customers,
    ROUND(SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_rate_pct
FROM customer_orders;

-- Interpretation: % of customers who made 2+ purchases.
-- Higher repeat rate = better customer loyalty.


-- B3.9) Cohort retention (signup month → ordering months after)
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month
    FROM customers
),
customer_activity AS (
    SELECT 
        o.customer_id,
        cc.cohort_month,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        TIMESTAMPDIFF(MONTH, 
            STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'),
            STR_TO_DATE(CONCAT(DATE_FORMAT(o.order_date, '%Y-%m'), '-01'), '%Y-%m-%d')
        ) AS months_since_signup
    FROM orders o
    JOIN customer_cohorts cc ON cc.customer_id = o.customer_id
    WHERE o.order_status = 'Delivered'
)
SELECT 
    cohort_month,
    months_since_signup,
    COUNT(DISTINCT customer_id) AS active_customers
FROM customer_activity
GROUP BY cohort_month, months_since_signup
ORDER BY cohort_month, months_since_signup;

-- Interpretation: Shows how many customers from each signup cohort remain active over time.
-- Month 0 = orders in signup month, Month 1 = next month, etc.


-- ========================================
-- B4) PRODUCT & CATEGORY ANALYTICS
-- ========================================

-- B4.10) Top categories by revenue and by quantity
-- By Revenue
SELECT 
    p.category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.quantity) AS total_quantity,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS category_revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY category_revenue DESC;

-- By Quantity
SELECT 
    p.category,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS category_revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category
ORDER BY total_quantity_sold DESC;

-- Interpretation: High revenue category ≠ high volume category.
-- Electronics might be high revenue but low volume (expensive items).
-- Grocery might be high volume but lower revenue (cheap items).


-- B4.11) Discount impact (avg discount % by category and brand)
SELECT 
    p.category,
    p.brand,
    COUNT(*) AS line_items,
    ROUND(AVG(oi.discount_amount / oi.list_price * 100), 2) AS avg_discount_pct,
    ROUND(SUM(oi.discount_amount), 2) AS total_discount_given
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND oi.list_price > 0
GROUP BY p.category, p.brand
ORDER BY avg_discount_pct DESC;

-- Interpretation: Shows which categories/brands have highest discounts.
-- High discounts might indicate pricing issues or competitive pressure.


-- B4.12) Profit estimate (top 10 products by profit)
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM((oi.unit_price - p.unit_cost) * oi.quantity), 2) AS estimated_profit
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY estimated_profit DESC
LIMIT 10;

-- Interpretation: These are the most profitable products.
-- Consider promoting them more or increasing inventory.


-- ========================================
-- B5) OPERATIONS & DELIVERY
-- ========================================

-- B5.13) Avg delivery days by carrier
SELECT 
    ship_carrier,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(DATEDIFF(delivered_date, order_date)), 2) AS avg_delivery_days,
    MIN(DATEDIFF(delivered_date, order_date)) AS min_days,
    MAX(DATEDIFF(delivered_date, order_date)) AS max_days
FROM orders
WHERE order_status = 'Delivered'
  AND delivered_date IS NOT NULL
GROUP BY ship_carrier
ORDER BY avg_delivery_days;

-- Interpretation: Shows which carrier is fastest.
-- Use this to negotiate better rates or switch carriers.


-- B5.14) Return rate by carrier and by category
-- By Carrier
SELECT 
    ship_carrier,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM orders
WHERE order_status IN ('Delivered', 'Returned')
GROUP BY ship_carrier
ORDER BY return_rate_pct DESC;

-- By Category
SELECT 
    p.category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS return_rate_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_status IN ('Delivered', 'Returned')
GROUP BY p.category
ORDER BY return_rate_pct DESC;

-- Interpretation: High return rates indicate quality issues or mismatched expectations.


-- B5.15) COD vs prepaid: compare cancellation rate
SELECT 
    payment_method,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct
FROM orders
GROUP BY payment_method
ORDER BY cancellation_rate_pct DESC;

-- Interpretation: COD typically has higher cancellation rate (customers change mind).
-- Prepaid (UPI/Wallet/Card) has lower cancellation.


-- ========================================
-- B6) ADVANCED SQL (WINDOW FUNCTIONS)
-- ========================================

-- B6.16) Rank categories by revenue per month
WITH monthly_category_revenue AS (
    SELECT 
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        p.category,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'Delivered'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m'), p.category
)
SELECT 
    month,
    category,
    revenue,
    DENSE_RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS revenue_rank
FROM monthly_category_revenue
ORDER BY month, revenue_rank;

-- Interpretation: Shows which categories lead each month.
-- Helps identify shifting trends (e.g., Electronics spike in festival months).


-- B6.17) Customer first order, last order, days since last, running total
WITH customer_order_history AS (
    SELECT 
        c.customer_id,
        c.full_name,
        o.order_id,
        o.order_date,
        p.grand_total,
        ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY o.order_date) AS order_number,
        FIRST_VALUE(o.order_date) OVER (PARTITION BY c.customer_id ORDER BY o.order_date) AS first_order_date,
        LAST_VALUE(o.order_date) OVER (PARTITION BY c.customer_id ORDER BY o.order_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_order_date,
        SUM(p.grand_total) OVER (PARTITION BY c.customer_id ORDER BY o.order_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN payments p ON p.order_id = o.order_id
    WHERE o.order_status = 'Delivered'
      AND p.payment_status = 'Paid'
)
SELECT 
    customer_id,
    full_name,
    first_order_date,
    last_order_date,
    DATEDIFF(CURDATE(), last_order_date) AS days_since_last_order,
    MAX(order_number) AS total_orders,
    ROUND(MAX(running_total_spend), 2) AS lifetime_value
FROM customer_order_history
GROUP BY customer_id, full_name, first_order_date, last_order_date
ORDER BY lifetime_value DESC;

-- Interpretation: Identifies customers at risk of churn (high days_since_last_order).
-- Use this for win-back campaigns.


-- B6.18) Basket analysis (top 20 category pairs in same order)
WITH order_categories AS (
    SELECT DISTINCT
        oi.order_id,
        p.category
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
),
category_pairs AS (
    SELECT 
        oc1.category AS category_1,
        oc2.category AS category_2,
        COUNT(DISTINCT oc1.order_id) AS pair_count
    FROM order_categories oc1
    JOIN order_categories oc2 
        ON oc1.order_id = oc2.order_id 
        AND oc1.category < oc2.category  -- Avoid duplicates (A,B) vs (B,A)
    GROUP BY oc1.category, oc2.category
)
SELECT 
    category_1,
    category_2,
    pair_count,
    ROUND(pair_count * 100.0 / (SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status = 'Delivered'), 2) AS pct_of_orders
FROM category_pairs
ORDER BY pair_count DESC
LIMIT 20;

-- Interpretation: Shows which categories are frequently bought together.
-- Use for cross-sell recommendations (e.g., "Customers who bought Electronics also bought Beauty").


-- ========================================
-- END OF ANSWERS.SQL
-- ========================================