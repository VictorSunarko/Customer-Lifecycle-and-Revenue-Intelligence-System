-- CUSTOMER LIFECYCLE AND REVENUE INTELLIGENCE SYSTEM
-- SQL File 2: Full Analytical Queries

-- Database : retail_analytics.db
-- Dialect  : SQLite 3.25+ (window functions supported)
-- Purpose  : This file contains all analytical queries organized into thematic sections.

-- NOTE ON SQLite DATE FUNCTIONS:
--   SQLite stores dates as TEXT in ISO format (YYYY-MM-DD).
--   Date arithmetic uses julianday() which returns a float.
--   Period math (months between) uses: (year2 - year1)*12 + (month2 - month1)
--   strftime('%Y-%m', date) returns the year-month period string.
--   strftime('%Y', date) and strftime('%m', date) extract year and month.


-- Section 1: Executive KPI Summary

-- 1.1 Full-Period Business Overview
-- Single-row summary of the entire dataset covering all KPIs.
SELECT
    COUNT(DISTINCT t.invoice)                                              AS total_orders,
    COUNT(DISTINCT t.customer_id)                                          AS total_customers,
    COUNT(DISTINCT t.stock_code)                                           AS total_products,
    ROUND(SUM(CAST(t.revenue AS REAL)), 2)                                 AS total_revenue,
    ROUND(SUM(CAST(t.revenue AS REAL)) / COUNT(DISTINCT t.invoice), 2)     AS avg_order_value,
    ROUND(SUM(CAST(t.revenue AS REAL)) / COUNT(DISTINCT t.customer_id), 2) AS avg_revenue_per_customer,
    ROUND(
        100.0
        * COUNT(DISTINCT CASE WHEN c.total_orders > 1 THEN c.customer_id END)
        / COUNT(DISTINCT c.customer_id),
        2
    )                                                                      AS repeat_purchase_rate_pct
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id;

-- 1.2 Year-over-Year Performance Comparison
-- Compares 2010 and 2011 side by side. December 2009 is excluded because
-- it represents only a partial period at the start of the dataset.
SELECT
    CAST(invoice_year AS INTEGER)                                              AS year,
    COUNT(DISTINCT invoice)                                                    AS total_orders,
    COUNT(DISTINCT customer_id)                                                AS total_customers,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                                       AS total_revenue,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT invoice), 2)             AS avg_order_value,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT customer_id), 2)         AS avg_revenue_per_customer
FROM transactions
WHERE CAST(invoice_year AS INTEGER) IN (2010, 2011)
GROUP BY invoice_year
ORDER BY invoice_year;

-- 1.3 Customer Lifetime Value Percentile Distribution
-- SQLite does not support PERCENTILE_CONT natively.
-- We replicate percentiles using the following pattern: P50 = median via a count-based window row selection.
-- For simplicity we compute min, max, avg, and approx quartiles.
SELECT
    COUNT(*)                                                AS total_customers,
    ROUND(MIN(ltv), 2)          				AS min_ltv,
    ROUND(AVG(ltv), 2)          				AS avg_ltv,
    ROUND(MAX(ltv), 2)        				   	AS max_ltv,
    -- Approximate quartiles using NTILE window function
    ROUND(AVG(CASE WHEN ltv_tile = 1 THEN ltv END), 2)     	AS approx_p25,
    ROUND(AVG(CASE WHEN ltv_tile = 2 THEN ltv END), 2)     	AS approx_p50,
    ROUND(AVG(CASE WHEN ltv_tile = 3 THEN ltv END), 2)     	AS approx_p75,
    ROUND(AVG(CASE WHEN ltv_tile >= 4 THEN ltv END), 2)    	AS approx_p90_plus
FROM (
    SELECT 
		lifetime_revenue AS ltv,
    	NTILE(4) OVER (ORDER BY lifetime_revenue) AS ltv_tile
    FROM customers
) t;


-- Section 2: Monthly Revenue Analysis

-- 2.1 Monthly Revenue with Month-over-Month Growth
-- Uses LAG() window function to compare each month to the previous one.
-- The growth_label classifies each month by its revenue trend direction.
WITH monthly AS (
    SELECT
        invoice_yearmonth                                                AS period,
        COUNT(DISTINCT invoice)                                          AS total_orders,
        COUNT(DISTINCT customer_id)                                      AS total_customers,
        ROUND(SUM(CAST(revenue AS REAL)), 2)                             AS total_revenue,
        ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT invoice), 2)  AS avg_order_value
    FROM transactions
    GROUP BY invoice_yearmonth
),
monthly_with_lag AS (
    SELECT
        period,
        total_orders,
        total_customers,
        total_revenue,
        avg_order_value,
        LAG(total_revenue) OVER (ORDER BY period)  AS prev_month_revenue
    FROM monthly
)
SELECT
    period,
    total_orders,
    total_customers,
    total_revenue,
    avg_order_value,
    prev_month_revenue,
    CASE
        WHEN prev_month_revenue IS NULL THEN NULL
        ELSE ROUND(100.0 * (total_revenue - prev_month_revenue) / prev_month_revenue, 2)
    END                                                                   AS mom_growth_pct,
    CASE
        WHEN prev_month_revenue IS NULL THEN 'Baseline'
        WHEN total_revenue > prev_month_revenue * 1.20 THEN 'Strong Growth'
        WHEN total_revenue > prev_month_revenue        THEN 'Growth'
        WHEN total_revenue = prev_month_revenue        THEN 'Flat'
        ELSE 'Decline'
    END                                                                   AS growth_label
FROM monthly_with_lag
ORDER BY period;

-- 2.2 Rolling 3-Month Average Revenue
-- Smooths monthly volatility to surface the underlying trend.
-- A 3-row window uses the current month plus the two months preceding it.
WITH monthly AS (
    SELECT
        invoice_yearmonth                              AS period,
        ROUND(SUM(CAST(revenue AS REAL)), 2)           AS total_revenue
    FROM transactions
    GROUP BY invoice_yearmonth
)
SELECT
    period,
    total_revenue,
    ROUND(
        AVG(total_revenue) OVER (
            ORDER BY period
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    )                                                  AS revenue_3m_rolling_avg,
    ROUND(
        SUM(total_revenue) OVER (
            ORDER BY period
            ROWS UNBOUNDED PRECEDING
        ), 2
    )                                                  AS cumulative_revenue
FROM monthly
ORDER BY period;

-- 2.3 Revenue and Order Volume by Day of Week
-- Identifies which days drive the most transaction activity.
-- Useful for scheduling promotions and operational staffing.
-- SQLite strftime('%w') returns: 0=Sunday, 1=Monday, ..., 6=Saturday
SELECT
    CAST(strftime('%w', invoice_date_only) AS INTEGER)   AS day_number,
    CASE strftime('%w', invoice_date_only)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END                                                  AS day_name,
    COUNT(DISTINCT invoice)                              AS orders,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                 AS total_revenue,
    ROUND(AVG(CAST(revenue AS REAL)), 2)                 AS avg_revenue_per_line,
    ROUND(
        100.0 * SUM(CAST(revenue AS REAL))
        / SUM(SUM(CAST(revenue AS REAL))) OVER (), 1
    )                                                    AS revenue_share_pct
FROM transactions
GROUP BY strftime('%w', invoice_date_only)
ORDER BY day_number;


-- Section 3: Customer Acquisition and Retention

-- 3.1 Monthly New Customer Acquisition
-- Counts first-time buyers each month by identifying the minimum period in which each customer appeared.
WITH first_purchases AS (
    SELECT
        customer_id,
        MIN(invoice_yearmonth) AS first_period
    FROM transactions
    GROUP BY customer_id
)
SELECT
    first_period         AS acquisition_month,
    COUNT(customer_id)   AS new_customers
FROM first_purchases
GROUP BY first_period
ORDER BY first_period;

-- 3.2 New vs Returning Customers and Revenue by Month
-- Classifies each invoice as belonging to a new customer (first purchase in that month) or a returning customer (subsequent purchase).
-- The revenue_share_pct uses a window SUM partitioned by period to express each type's contribution within the same month.
WITH customer_first_period AS (
    SELECT
        customer_id,
        MIN(invoice_yearmonth) AS first_period
    FROM orders
    GROUP BY customer_id
),
order_classified AS (
    SELECT
        o.invoice,
        o.customer_id,
        o.invoice_yearmonth                                          AS period,
        CAST(o.order_revenue AS REAL)                                AS order_revenue,
        CASE
            WHEN o.invoice_yearmonth = f.first_period THEN 'New'
            ELSE 'Returning'
        END                                                          AS customer_type
    FROM orders o
    JOIN customer_first_period f ON o.customer_id = f.customer_id
)
SELECT
    period,
    customer_type,
    COUNT(DISTINCT customer_id)                                      AS customers,
    COUNT(DISTINCT invoice)                                          AS orders,
    ROUND(SUM(order_revenue), 2)                                     AS revenue,
    ROUND(
        100.0 * SUM(order_revenue)
        / SUM(SUM(order_revenue)) OVER (PARTITION BY period), 2
    )                                                                AS revenue_share_pct
FROM order_classified
GROUP BY period, customer_type
ORDER BY period, customer_type;

-- 3.3 Average Gap Between Consecutive Orders (Days)
-- Computes the inter-purchase interval using LAG() on each customer's order history. 
-- julianday() converts date strings to a real number so subtraction yields the gap in days.
WITH order_sequences AS (
    SELECT
        customer_id,
        invoice_date_only,
        LAG(invoice_date_only) OVER (
            PARTITION BY customer_id
            ORDER BY invoice_date_only
        ) AS prev_order_date
    FROM orders
),
gap_days AS (
    SELECT
        customer_id,
        CAST(
            julianday(invoice_date_only) - julianday(prev_order_date)
        AS INTEGER) AS gap
    FROM order_sequences
    WHERE prev_order_date IS NOT NULL
      AND julianday(invoice_date_only) - julianday(prev_order_date) > 0
)
SELECT
    ROUND(AVG(gap), 1)      AS avg_gap_days,
    MIN(gap)                AS min_gap_days,
    MAX(gap)                AS max_gap_days,
    COUNT(*)                AS total_repeat_purchase_events,
    COUNT(DISTINCT customer_id) AS repeat_customers
FROM gap_days;

-- 3.4 Customer Frequency Segmentation
-- Buckets customers into purchase frequency tiers to understand the distribution of one-time buyers versus regular and power customers.
-- Revenue concentration per bucket identifies where LTV is concentrated.
SELECT
    CASE
        WHEN total_orders = 1    THEN '01 | One-Time (1 order)'
        WHEN total_orders <= 3   THEN '02 | Occasional (2-3 orders)'
        WHEN total_orders <= 6   THEN '03 | Regular (4-6 orders)'
        WHEN total_orders <= 12  THEN '04 | Frequent (7-12 orders)'
        ELSE                          '05 | High Frequency (13+ orders)'
    END                                                              AS frequency_bucket,
    COUNT(customer_id)                                               AS customers,
    ROUND(SUM(CAST(lifetime_revenue AS REAL)), 2)                    AS total_revenue,
    ROUND(AVG(CAST(lifetime_revenue AS REAL)), 2)                    AS avg_ltv,
    ROUND(AVG(CAST(avg_order_value  AS REAL)), 2)                    AS avg_order_value,
    ROUND(
        100.0 * COUNT(customer_id)
        / SUM(COUNT(customer_id)) OVER (), 1
    )                                                                AS customer_share_pct,
    ROUND(
        100.0 * SUM(CAST(lifetime_revenue AS REAL))
        / SUM(SUM(CAST(lifetime_revenue AS REAL))) OVER (), 1
    )                                                                AS revenue_share_pct
FROM customers
GROUP BY frequency_bucket
ORDER BY frequency_bucket;


-- Section 4: Cohort Retention Analysis
-- Cohort analysis groups customers by their acquisition month and tracks how many remain active in each subsequent month. 
-- The result is a matrix where rows = cohorts, columns = months since first purchase,
-- and cells = the retention rate (% of the cohort still active).

-- 4.1 Cohort Retention Matrix
-- Each row is a cohort-month combination. 
-- retention_rate is the percentage of the original cohort size that was active in that particular month.
WITH customer_cohorts AS (
    -- Assign each customer their first purchase month
    SELECT
        customer_id,
        MIN(strftime('%Y-%m', invoice_date_only)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),
customer_activity AS (
    -- For every transaction, compute the month offset from the cohort month.
    -- SQLite month math: (year_diff * 12) + month_diff
    SELECT
        t.customer_id,
        cc.cohort_month,
        strftime('%Y-%m', t.invoice_date_only)              AS activity_month,
        (
            CAST(strftime('%Y', t.invoice_date_only) AS INTEGER)
            - CAST(strftime('%Y', cc.cohort_month || '-01') AS INTEGER)
        ) * 12
        + (
            CAST(strftime('%m', t.invoice_date_only) AS INTEGER)
            - CAST(strftime('%m', cc.cohort_month || '-01') AS INTEGER)
        )                                                   AS month_number
    FROM transactions t
    JOIN customer_cohorts cc ON t.customer_id = cc.customer_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
retention_counts AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, month_number
)
SELECT
    r.cohort_month,
    r.month_number,
    r.active_customers,
    cs.cohort_size,
    ROUND(100.0 * r.active_customers / cs.cohort_size, 2)  AS retention_rate
FROM retention_counts r
JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
ORDER BY r.cohort_month, r.month_number;

-- 4.2 Average Retention Curve Across All Cohorts
-- Collapses the full matrix into a single representative curve by averaging retention rates across all cohorts for each month offset.
WITH customer_cohorts AS (
    SELECT
        customer_id,
        MIN(strftime('%Y-%m', invoice_date_only)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),
customer_activity AS (
    SELECT
        t.customer_id,
        cc.cohort_month,
        (
            CAST(strftime('%Y', t.invoice_date_only) AS INTEGER)
            - CAST(strftime('%Y', cc.cohort_month || '-01') AS INTEGER)
        ) * 12
        + (
            CAST(strftime('%m', t.invoice_date_only) AS INTEGER)
            - CAST(strftime('%m', cc.cohort_month || '-01') AS INTEGER)
        ) AS month_number
    FROM transactions t
    JOIN customer_cohorts cc ON t.customer_id = cc.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
retention_counts AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, month_number
),
retention_with_rate AS (
    SELECT
        r.cohort_month,
        r.month_number,
        r.active_customers,
        cs.cohort_size,
        ROUND(100.0 * r.active_customers / cs.cohort_size, 2) AS retention_rate
    FROM retention_counts r
    JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
)
SELECT
    month_number,
    COUNT(DISTINCT cohort_month)           AS cohorts_with_data,
    ROUND(AVG(active_customers), 1)        AS avg_active_customers,
    ROUND(AVG(retention_rate), 2)          AS avg_retention_pct,
    ROUND(MIN(retention_rate), 2)          AS min_retention_pct,
    ROUND(MAX(retention_rate), 2)          AS max_retention_pct
FROM retention_with_rate
GROUP BY month_number
ORDER BY month_number;

-- 4.3 Cohort Quality Ranking
-- Extracts retention at milestone months (1, 3, 6, 12) per cohort.
-- Cohorts are ranked by 3-month and 6-month retention to identify which acquisition periods produced the most durable customer relationships.
WITH customer_cohorts AS (
    SELECT customer_id, MIN(strftime('%Y-%m', invoice_date_only)) AS cohort_month
    FROM transactions GROUP BY customer_id
),
customer_activity AS (
    SELECT
        t.customer_id, cc.cohort_month,
        (CAST(strftime('%Y', t.invoice_date_only) AS INTEGER)
         - CAST(strftime('%Y', cc.cohort_month || '-01') AS INTEGER)) * 12
        + (CAST(strftime('%m', t.invoice_date_only) AS INTEGER)
           - CAST(strftime('%m', cc.cohort_month || '-01') AS INTEGER)) AS month_number
    FROM transactions t
    JOIN customer_cohorts cc ON t.customer_id = cc.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts GROUP BY cohort_month
),
retention_counts AS (
    SELECT cohort_month, month_number, COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_activity GROUP BY cohort_month, month_number
),
milestones AS (
    SELECT
        r.cohort_month,
        cs.cohort_size,
        MAX(CASE WHEN r.month_number = 1  THEN ROUND(100.0 * r.active_customers / cs.cohort_size, 2) END) AS ret_m1,
        MAX(CASE WHEN r.month_number = 3  THEN ROUND(100.0 * r.active_customers / cs.cohort_size, 2) END) AS ret_m3,
        MAX(CASE WHEN r.month_number = 6  THEN ROUND(100.0 * r.active_customers / cs.cohort_size, 2) END) AS ret_m6,
        MAX(CASE WHEN r.month_number = 12 THEN ROUND(100.0 * r.active_customers / cs.cohort_size, 2) END) AS ret_m12
    FROM retention_counts r
    JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
    GROUP BY r.cohort_month, cs.cohort_size
)
SELECT
    cohort_month,
    cohort_size,
    ret_m1   AS retention_month_1_pct,
    ret_m3   AS retention_month_3_pct,
    ret_m6   AS retention_month_6_pct,
    ret_m12  AS retention_month_12_pct,
    RANK() OVER (ORDER BY COALESCE(ret_m3,  0) DESC) AS rank_by_month_3,
    RANK() OVER (ORDER BY COALESCE(ret_m6,  0) DESC) AS rank_by_month_6
FROM milestones
ORDER BY cohort_month;


-- Section 5: RFM Customer Segmentation
-- R = Recency   : days since last purchase (lower = more recent = higher score)
-- F = Frequency : number of distinct orders placed
-- M = Monetary  : total lifetime revenue
-- Each dimension is scored 1-5 using NTILE(5).
-- Segment labels are assigned based on R and F score combinations.

-- 5.1 Full RFM Scored and Segmented Customer List
WITH rfm_scored AS (
    SELECT
        customer_id,
        country,
        CAST(lifetime_revenue AS REAL)                                         AS monetary,
        total_orders                                                            AS frequency,
        CAST(recency_days AS INTEGER)                                           AS recency,
        NTILE(5) OVER (ORDER BY CAST(recency_days    AS INTEGER) ASC)           AS r_score,
        NTILE(5) OVER (ORDER BY total_orders                     ASC)           AS f_score,
        NTILE(5) OVER (ORDER BY CAST(lifetime_revenue AS REAL)   ASC)           AS m_score
    FROM customers
)
SELECT
    customer_id,
    country,
    ROUND(monetary, 2)   AS lifetime_revenue,
    frequency            AS total_orders,
    recency              AS days_since_last_purchase,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4                         THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                         THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3              THEN 'Potential Loyalists'
        WHEN r_score  = 5 AND f_score  = 1                         THEN 'New Customers'
        WHEN r_score BETWEEN 3 AND 4 AND f_score <= 1              THEN 'Promising'
        WHEN r_score BETWEEN 2 AND 3 AND f_score BETWEEN 2 AND 3   THEN 'Needs Attention'
        WHEN r_score BETWEEN 2 AND 3 AND f_score <= 1              THEN 'About to Sleep'
        WHEN r_score <= 2 AND f_score >= 4                         THEN 'At Risk'
        WHEN r_score  = 1 AND f_score >= 4 AND m_score >= 4        THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score BETWEEN 2 AND 3              THEN 'Hibernating'
        ELSE                                                             'Lost'
    END                  AS segment
FROM rfm_scored
ORDER BY rfm_total_score DESC, monetary DESC;

-- 5.2 Segment-Level Revenue and Behavioral Summary
-- Aggregate metrics per segment: count, revenue share, and behavioral averages.
-- The revenue_share_pct column is critical for CRM prioritization.
WITH rfm_scored AS (
    SELECT
        customer_id,
        CAST(lifetime_revenue AS REAL) AS monetary,
        total_orders AS frequency,
        CAST(recency_days AS INTEGER)  AS recency,
        NTILE(5) OVER (ORDER BY CAST(recency_days    AS INTEGER) ASC) AS r_score,
        NTILE(5) OVER (ORDER BY total_orders                    ASC) AS f_score,
        NTILE(5) OVER (ORDER BY CAST(lifetime_revenue AS REAL)  ASC) AS m_score
    FROM customers
),
segments AS (
    SELECT
        customer_id, monetary, frequency, recency,
        r_score, f_score, m_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4                       THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                       THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3            THEN 'Potential Loyalists'
            WHEN r_score  = 5 AND f_score  = 1                       THEN 'New Customers'
            WHEN r_score BETWEEN 3 AND 4 AND f_score <= 1            THEN 'Promising'
            WHEN r_score BETWEEN 2 AND 3 AND f_score BETWEEN 2 AND 3 THEN 'Needs Attention'
            WHEN r_score BETWEEN 2 AND 3 AND f_score <= 1            THEN 'About to Sleep'
            WHEN r_score <= 2 AND f_score >= 4                       THEN 'At Risk'
            WHEN r_score  = 1 AND f_score >= 4 AND m_score >= 4      THEN 'Cannot Lose Them'
            WHEN r_score <= 2 AND f_score BETWEEN 2 AND 3            THEN 'Hibernating'
            ELSE 'Lost'
        END AS segment
    FROM rfm_scored
)
SELECT
    segment,
    COUNT(customer_id)                                            AS customers,
    ROUND(SUM(monetary), 2)                                       AS total_revenue,
    ROUND(AVG(monetary), 2)                                       AS avg_ltv,
    ROUND(AVG(CAST(frequency AS REAL)), 1)                        AS avg_orders,
    ROUND(AVG(CAST(recency   AS REAL)), 0)                        AS avg_recency_days,
    ROUND(100.0 * COUNT(customer_id)
          / SUM(COUNT(customer_id)) OVER (), 1)                   AS customer_share_pct,
    ROUND(100.0 * SUM(monetary)
          / SUM(SUM(monetary)) OVER (), 1)                        AS revenue_share_pct
FROM segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- 5.3 Revenue Concentration by Customer Decile (Pareto Analysis)
-- Divides customers into 10 equal groups ranked by descending lifetime revenue.
-- Reveals whether the 80/20 pattern holds in this dataset.
WITH deciles AS (
    SELECT
        customer_id,
        CAST(lifetime_revenue AS REAL) AS monetary,
        NTILE(10) OVER (ORDER BY CAST(lifetime_revenue AS REAL) DESC) AS revenue_decile
    FROM customers
)
SELECT
    revenue_decile,
    COUNT(customer_id)                                                    AS customers,
    ROUND(SUM(monetary), 2)                                               AS revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)          AS revenue_pct,
    ROUND(
        100.0
        * SUM(SUM(monetary)) OVER (ORDER BY revenue_decile
                                   ROWS UNBOUNDED PRECEDING)
        / SUM(SUM(monetary)) OVER (), 1
    )                                                                      AS cumulative_revenue_pct
FROM deciles
GROUP BY revenue_decile
ORDER BY revenue_decile;


-- Section 6: Product Intelligence

-- 6.1 Top 20 Products by Total Revenue
SELECT
    stock_code,
    MAX(description)                                              AS description,
    COUNT(DISTINCT invoice)                                       AS orders,
    SUM(CAST(quantity AS INTEGER))                                AS total_quantity,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                          AS total_revenue,
    ROUND(AVG(CAST(price AS REAL)), 2)                            AS avg_unit_price,
    COUNT(DISTINCT customer_id)                                   AS distinct_customers,
    ROUND(
        100.0 * SUM(CAST(revenue AS REAL))
        / SUM(SUM(CAST(revenue AS REAL))) OVER (), 3
    )                                                             AS revenue_share_pct
FROM transactions
GROUP BY stock_code
ORDER BY total_revenue DESC
LIMIT 20;

-- 6.2 Top 20 Products by Customer Reach
-- Products that appear in the most unique customer baskets.
-- High reach with low revenue may signal gateway or habitual products.
SELECT
    stock_code,
    MAX(description)                       AS description,
    COUNT(DISTINCT customer_id)            AS distinct_customers,
    COUNT(DISTINCT invoice)                AS orders,
    SUM(CAST(quantity AS INTEGER))         AS total_quantity,
    ROUND(SUM(CAST(revenue AS REAL)), 2)   AS total_revenue,
    ROUND(AVG(CAST(price   AS REAL)), 2)   AS avg_unit_price
FROM transactions
GROUP BY stock_code
ORDER BY distinct_customers DESC
LIMIT 20;

-- 6.3 Monthly Revenue for Top 10 Products
-- Tracks how individual high-revenue products perform month by month.
-- Seasonal spikes or consistent performance can guide inventory planning.
WITH top_products AS (
    SELECT stock_code
    FROM transactions
    GROUP BY stock_code
    ORDER BY SUM(CAST(revenue AS REAL)) DESC
    LIMIT 10
)
SELECT
    t.invoice_yearmonth                       AS period,
    t.stock_code,
    MAX(t.description)                        AS description,
    COUNT(DISTINCT t.invoice)                 AS orders,
    ROUND(SUM(CAST(t.revenue AS REAL)), 2)    AS monthly_revenue
FROM transactions t
WHERE t.stock_code IN (SELECT stock_code FROM top_products)
GROUP BY t.invoice_yearmonth, t.stock_code
ORDER BY t.invoice_yearmonth, monthly_revenue DESC;


-- Section 7: Geographic Analysis

-- 7.1 Revenue and Customer Metrics by Country
SELECT
    country,
    COUNT(DISTINCT customer_id)                                           AS customers,
    COUNT(DISTINCT invoice)                                               AS orders,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                                  AS total_revenue,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT invoice), 2)        AS avg_order_value,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT customer_id), 2)    AS avg_ltv,
    ROUND(
        100.0 * SUM(CAST(revenue AS REAL))
        / SUM(SUM(CAST(revenue AS REAL))) OVER (), 2
    )                                                                     AS revenue_share_pct,
    RANK() OVER (ORDER BY SUM(CAST(revenue AS REAL)) DESC)                AS revenue_rank
FROM transactions
GROUP BY country
ORDER BY total_revenue DESC;

-- 7.2 International Revenue by Quarter
-- Isolates non-UK transactions grouped by year and quarter.
-- SQLite does not have a QUARTER() function; we derive it from the month.
SELECT
    CAST(invoice_year AS INTEGER)                            AS year,
    CASE
        WHEN CAST(invoice_month AS INTEGER) BETWEEN 1 AND 3  THEN 'Q1'
        WHEN CAST(invoice_month AS INTEGER) BETWEEN 4 AND 6  THEN 'Q2'
        WHEN CAST(invoice_month AS INTEGER) BETWEEN 7 AND 9  THEN 'Q3'
        ELSE                                                      'Q4'
    END                                                      AS quarter,
    COUNT(DISTINCT customer_id)                              AS international_customers,
    COUNT(DISTINCT invoice)                                  AS international_orders,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                     AS international_revenue,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT invoice), 2) AS avg_order_value
FROM transactions
WHERE country != 'United Kingdom'
GROUP BY invoice_year, quarter
ORDER BY invoice_year, quarter;

-- 7.3 Top International Markets by Average LTV
-- Shows which non-UK countries produce the highest-value customers.
-- Filtered to returning customers (>=2 orders) and markets with at least 5 qualifying customers for statistical reliability.
SELECT
    c.country,
    COUNT(DISTINCT c.customer_id)                        AS customers,
    ROUND(AVG(CAST(c.lifetime_revenue AS REAL)), 2)      AS avg_ltv,
    ROUND(AVG(CAST(c.total_orders     AS REAL)), 1)      AS avg_orders,
    ROUND(AVG(CAST(c.avg_order_value  AS REAL)), 2)      AS avg_order_value,
    ROUND(AVG(CAST(c.recency_days     AS REAL)), 0)      AS avg_recency_days
FROM customers c
WHERE c.country != 'United Kingdom'
  AND CAST(c.total_orders AS INTEGER) >= 2
GROUP BY c.country
HAVING COUNT(DISTINCT c.customer_id) >= 5
ORDER BY avg_ltv DESC
LIMIT 15;