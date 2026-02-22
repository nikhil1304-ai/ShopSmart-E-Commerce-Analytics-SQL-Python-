-- SQL Assignment Dataset: "ShopSmart" (E-commerce analytics)
-- Target DB: MySQL 8+
-- Author: (Your Name)
-- Steps:
-- 1) Create database and tables.
-- 2) Load data using either:
--    (A) LOAD DATA LOCAL INFILE from CSVs (recommended), OR
--    (B) INSERT statements (provided, but larger).
-- 3) Run EDA queries.

DROP DATABASE IF EXISTS shopsmart;
CREATE DATABASE shopsmart;
USE shopsmart;

-- Customers
CREATE TABLE customers (
  customer_id   VARCHAR(5)  PRIMARY KEY,
  full_name     VARCHAR(80) NOT NULL,
  email         VARCHAR(120) UNIQUE,
  city          VARCHAR(40),
  state         VARCHAR(10),
  age           INT,
  segment       VARCHAR(20),
  signup_date   DATE,
  is_active     TINYINT(1) DEFAULT 1
);

-- Products
CREATE TABLE products (
  product_id       VARCHAR(5) PRIMARY KEY,
  sku              VARCHAR(20) UNIQUE,
  product_name     VARCHAR(120) NOT NULL,
  category         VARCHAR(40),
  sub_category     VARCHAR(40),
  brand            VARCHAR(40),
  list_price       DECIMAL(10,2),
  unit_cost        DECIMAL(10,2),
  launch_date      DATE,
  is_discontinued  TINYINT(1) DEFAULT 0
);

-- Orders (header)
CREATE TABLE orders (
  order_id        VARCHAR(7) PRIMARY KEY,
  customer_id     VARCHAR(5) NOT NULL,
  order_date      DATE NOT NULL,
  channel         VARCHAR(20),
  payment_method  VARCHAR(20),
  ship_carrier    VARCHAR(30),
  order_status    VARCHAR(20),
  delivered_date  DATE NULL,
  ship_city       VARCHAR(40),
  ship_state      VARCHAR(10),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Order items (line level)
CREATE TABLE order_items (
  order_id        VARCHAR(7) NOT NULL,
  line_no         INT NOT NULL,
  product_id      VARCHAR(5) NOT NULL,
  quantity        INT NOT NULL,
  list_price      DECIMAL(10,2),
  discount_amount DECIMAL(10,2),
  unit_price      DECIMAL(10,2),
  PRIMARY KEY (order_id, line_no),
  CONSTRAINT fk_items_order   FOREIGN KEY (order_id) REFERENCES orders(order_id),
  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Payments (one row per order)
CREATE TABLE payments (
  order_id        VARCHAR(7) PRIMARY KEY,
  payment_method  VARCHAR(20),
  subtotal        DECIMAL(12,2),
  tax_amount      DECIMAL(12,2),
  shipping_fee    DECIMAL(12,2),
  grand_total     DECIMAL(12,2),
  payment_status  VARCHAR(20),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Helpful indexes for analytics
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE INDEX idx_products_cat ON products(category, sub_category);
