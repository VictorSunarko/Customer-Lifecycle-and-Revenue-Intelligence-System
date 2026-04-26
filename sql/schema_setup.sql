-- CUSTOMER LIFECYCLE AND REVENUE INTELLIGENCE SYSTEM
-- SQL File 1: Schema Setup and Table Creation

-- Tool        : DBeaver (SQLite connection)
-- Database    : retail_analytics.db  (create a new SQLite file)
-- Purpose     : To add indexes and performes an initial row-count validation

-- BEFORE running this file:
--   1. Open DBeaver
--   2. Create a new SQLite connection pointing to a new .db (retail_analytics.db) file
--   3. Import transactions.csv  as table name: transactions
--   4. Import orders.csv        as table name: orders
--   5. Import customers.csv     as table name: customers
--	 6. Then run this script for indexing and validation.


-- # Section 1: Confirm Table Existence and Row Counts
-- Run each SELECT individually to confirm import succeeded.
-- Expected: transactions ~1,000,000+  orders ~20,000+  customers ~5,000+
SELECT 'transactions' AS table_name, COUNT(*) AS row_count FROM transactions
UNION ALL
SELECT 'orders',                      COUNT(*) FROM orders
UNION ALL
SELECT 'customers',                   COUNT(*) FROM customers;


-- Section 2: Preview Table Structures
-- Preview the first five rows of each table to confirm column alignment.
SELECT * FROM transactions LIMIT 5;
SELECT * FROM orders LIMIT 5;
SELECT * FROM customers LIMIT 5;


-- Section 3: Adding Indexes for Query Performance
-- SQLite does not enforce types strictly, but indexes significantly
-- speed up GROUP BY and JOIN operations on large tables.
CREATE INDEX IF NOT EXISTS idx_tx_customer    ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_tx_invoice     ON transactions(invoice);
CREATE INDEX IF NOT EXISTS idx_tx_yearmonth   ON transactions(invoice_yearmonth);
CREATE INDEX IF NOT EXISTS idx_tx_date        ON transactions(invoice_date_only);
CREATE INDEX IF NOT EXISTS idx_tx_country     ON transactions(country);
CREATE INDEX IF NOT EXISTS idx_tx_stock       ON transactions(stock_code);

CREATE INDEX IF NOT EXISTS idx_ord_customer   ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_ord_invoice    ON orders(invoice);
CREATE INDEX IF NOT EXISTS idx_ord_yearmonth  ON orders(invoice_yearmonth);

CREATE INDEX IF NOT EXISTS idx_cust_customer  ON customers(customer_id);
CREATE INDEX IF NOT EXISTS idx_cust_country   ON customers(country);

SELECT 'Indexes created successfully.' AS status;


-- Section 4: Data Type and Range Validaiton

-- Confirm that numeric columns imported correctly as numbers and that date ranges match the expected dataset window.
SELECT
    MIN(invoice_date_only) AS earliest_date,
    MAX(invoice_date_only) AS latest_date,
    MIN(CAST(quantity AS INTEGER))  AS min_quantity,
    MAX(CAST(quantity AS INTEGER))  AS max_quantity,
    MIN(CAST(price    AS REAL))     AS min_price,
    MAX(CAST(price    AS REAL))     AS max_price,
    MIN(CAST(revenue  AS REAL))     AS min_revenue,
    MAX(CAST(revenue  AS REAL))     AS max_revenue
FROM transactions;

-- Revenue cross-check: all three tables should return the same total.
SELECT
    'transactions'        AS source,
    ROUND(SUM(CAST(revenue       AS REAL)), 2) AS total_revenue
FROM transactions
UNION ALL
SELECT
    'orders',
    ROUND(SUM(CAST(order_revenue AS REAL)), 2)
FROM orders
UNION ALL
SELECT
    'customers',
    ROUND(SUM(CAST(lifetime_revenue AS REAL)), 2)
FROM customers;