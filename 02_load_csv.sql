-- Option A (Recommended): Load CSVs with LOAD DATA LOCAL INFILE
-- Notes:
-- 1) You may need to enable LOCAL INFILE:
--    - In MySQL client: SET GLOBAL local_infile=1;
--    - And in your connector: allow_local_infile=True
-- 2) Update paths below to your local machine paths.
USE shopsmart;

SET FOREIGN_KEY_CHECKS=0;

-- Customers
LOAD DATA LOCAL INFILE 'PATH_TO/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, full_name, email, city, state, age, segment, signup_date, is_active);

-- Products
LOAD DATA LOCAL INFILE 'PATH_TO/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, sku, product_name, category, sub_category, brand, list_price, unit_cost, launch_date, is_discontinued);

-- Orders
LOAD DATA LOCAL INFILE 'PATH_TO/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_date, channel, payment_method, ship_carrier, order_status, delivered_date, ship_city, ship_state);

-- Order Items
LOAD DATA LOCAL INFILE 'PATH_TO/order_items.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, line_no, product_id, quantity, list_price, discount_amount, unit_price);

-- Payments
LOAD DATA LOCAL INFILE 'PATH_TO/payments.csv'
INTO TABLE payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_method, subtotal, tax_amount, shipping_fee, grand_total, payment_status);

SET FOREIGN_KEY_CHECKS=1;
-- Quick sanity checks
SELECT COUNT(*) AS customers FROM customers;
SELECT COUNT(*) AS products FROM products;
SELECT COUNT(*) AS orders FROM orders;
SELECT COUNT(*) AS order_items FROM order_items;
SELECT COUNT(*) AS payments FROM payments;