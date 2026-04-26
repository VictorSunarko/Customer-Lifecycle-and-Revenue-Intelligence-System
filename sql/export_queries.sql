-- CUSTOMER LIFECYCLE AND REVENUE INTELLIGENCE SYSTEM
-- SQL File 3: Export Queries for Power BI

-- Purpose  : Finalized queries and exporting each as a CSV file.

-- FILES TO EXPORT:
--   kpi_summary.csv
--   monthly_revenue.csv
--   new_vs_returning.csv
--   cohort_retention.csv
--   cohort_avg_curve.csv
--   rfm_segments.csv
--   customer_frequency.csv
--   country_revenue.csv
--   product_performance.csv

-- Export 1: kpi_summary.csv
-- Single-row executive KPI card values for the Overview dashboard page.
SELECT
    COUNT(DISTINCT t.invoice)                                               AS total_orders,
    COUNT(DISTINCT t.customer_id)                                           AS total_customers,
    COUNT(DISTINCT t.stock_code)                                            AS total_products,
    ROUND(SUM(CAST(t.revenue AS REAL)), 2)                                  AS total_revenue,
    ROUND(SUM(CAST(t.revenue AS REAL)) / COUNT(DISTINCT t.invoice), 2)     AS avg_order_value,
    ROUND(SUM(CAST(t.revenue AS REAL)) / COUNT(DISTINCT t.customer_id), 2) AS avg_revenue_per_customer,
    ROUND(
        100.0
        * COUNT(DISTINCT CASE WHEN CAST(c.total_orders AS INTEGER) > 1 THEN c.customer_id END)
        / COUNT(DISTINCT c.customer_id),
        2
    )                                                                       AS repeat_purchase_rate_pct,
    MIN(t.invoice_date_only)                                                AS dataset_start_date,
    MAX(t.invoice_date_only)                                                AS dataset_end_date
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id;


-- Export 2: monthly_revenue.csv
-- Monthly aggregates with MoM growth rate and trend label.
-- Used for the Revenue Trend line chart and KPI cards.
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
        LAG(total_revenue) OVER (ORDER BY period) AS prev_month_revenue
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
    END AS mom_growth_pct,
    CASE
        WHEN prev_month_revenue IS NULL                  THEN 'Baseline'
        WHEN total_revenue > prev_month_revenue * 1.20  THEN 'Strong Growth'
        WHEN total_revenue > prev_month_revenue          THEN 'Growth'
        WHEN total_revenue = prev_month_revenue          THEN 'Flat'
        ELSE                                                  'Decline'
    END AS growth_label,
    ROUND(
        SUM(total_revenue) OVER (ORDER BY period ROWS UNBOUNDED PRECEDING), 2
    )   AS cumulative_revenue
FROM monthly_with_lag
ORDER BY period;


-- Export 3: new_vs_returning.csv
-- Monthly breakdown of new vs returning customer count and revenue.
-- Used for the stacked bar chart and revenue mix donut/pie.
WITH customer_first_period AS (
    SELECT customer_id, MIN(invoice_yearmonth) AS first_period
    FROM orders GROUP BY customer_id
),
order_classified AS (
    SELECT
        o.invoice,
        o.customer_id,
        o.invoice_yearmonth                    AS period,
        CAST(o.order_revenue AS REAL)          AS order_revenue,
        CASE
            WHEN o.invoice_yearmonth = f.first_period THEN 'New'
            ELSE 'Returning'
        END                                    AS customer_type
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


-- Export 4: cohort_retention.csv
-- Full cohort-period retention matrix.
-- Used to build the retention heatmap in Power BI (Matrix visual).
WITH customer_cohorts AS (
    SELECT customer_id, MIN(strftime('%Y-%m', invoice_date_only)) AS cohort_month
    FROM transactions GROUP BY customer_id
),
customer_activity AS (
    SELECT
        t.customer_id,
        cc.cohort_month,
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
)
SELECT
    r.cohort_month,
    r.month_number,
    r.active_customers,
    cs.cohort_size,
    ROUND(100.0 * r.active_customers / cs.cohort_size, 2) AS retention_rate
FROM retention_counts r
JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
WHERE r.month_number BETWEEN 0 AND 12
ORDER BY r.cohort_month, r.month_number;


-- Export 5: cohort_avg_curve.csv
-- Average retention rate per month number across all cohorts.
-- Used for the Avg Retention Curve line chart in Power BI.
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
retention_with_rate AS (
    SELECT
        r.cohort_month, r.month_number, r.active_customers, cs.cohort_size,
        ROUND(100.0 * r.active_customers / cs.cohort_size, 2) AS retention_rate
    FROM retention_counts r
    JOIN cohort_sizes cs ON r.cohort_month = cs.cohort_month
)
SELECT
    month_number,
    COUNT(DISTINCT cohort_month)     AS cohorts_counted,
    ROUND(AVG(retention_rate), 2)    AS avg_retention_pct,
    ROUND(MIN(retention_rate), 2)    AS min_retention_pct,
    ROUND(MAX(retention_rate), 2)    AS max_retention_pct
FROM retention_with_rate
WHERE month_number BETWEEN 0 AND 12
GROUP BY month_number
ORDER BY month_number;


-- Export 6: rfm_segments.csv
-- Full RFM-scored and segmented customer list.
-- Used for the Segmentation page: donut chart, scatter plot, and table.
WITH rfm_scored AS (
    SELECT
        customer_id,
        country,
        CAST(lifetime_revenue AS REAL) AS monetary,
        total_orders                   AS frequency,
        CAST(recency_days AS INTEGER)  AS recency,
        NTILE(5) OVER (ORDER BY CAST(recency_days    AS INTEGER) ASC) AS r_score,
        NTILE(5) OVER (ORDER BY total_orders                    ASC) AS f_score,
        NTILE(5) OVER (ORDER BY CAST(lifetime_revenue AS REAL)  ASC) AS m_score
    FROM customers
)
SELECT
    customer_id,
    country,
    ROUND(monetary, 2) AS lifetime_revenue,
    frequency          AS total_orders,
    recency            AS days_since_last_purchase,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total_score,
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
        ELSE                                                          'Lost'
    END AS segment
FROM rfm_scored
ORDER BY rfm_total_score DESC, monetary DESC;


-- Export 7: customer_frequency.csv
-- Frequency bucket distribution showing how orders are spread across customers.
-- Used for the bar chart on the Customer Behavior page.
SELECT
    CASE
        WHEN CAST(total_orders AS INTEGER)  = 1   THEN '1 - One-Time'
        WHEN CAST(total_orders AS INTEGER) <= 3   THEN '2 - Occasional (2-3)'
        WHEN CAST(total_orders AS INTEGER) <= 6   THEN '3 - Regular (4-6)'
        WHEN CAST(total_orders AS INTEGER) <= 12  THEN '4 - Frequent (7-12)'
        ELSE                                           '5 - High Frequency (13+)'
    END                                                           AS frequency_bucket,
    COUNT(customer_id)                                            AS customers,
    ROUND(SUM(CAST(lifetime_revenue AS REAL)), 2)                 AS total_revenue,
    ROUND(AVG(CAST(lifetime_revenue AS REAL)), 2)                 AS avg_ltv,
    ROUND(AVG(CAST(avg_order_value  AS REAL)), 2)                 AS avg_order_value,
    ROUND(100.0 * COUNT(customer_id)
          / SUM(COUNT(customer_id)) OVER (), 1)                   AS customer_share_pct,
    ROUND(100.0 * SUM(CAST(lifetime_revenue AS REAL))
          / SUM(SUM(CAST(lifetime_revenue AS REAL))) OVER (), 1)  AS revenue_share_pct
FROM customers
GROUP BY frequency_bucket
ORDER BY frequency_bucket;


-- Export 8: country_revenue.csv
-- Revenue, customers, and order metrics by country.
-- Used for the filled map visual and country comparison table.
SELECT
    country,
    COUNT(DISTINCT customer_id)                                            AS customers,
    COUNT(DISTINCT invoice)                                                AS orders,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                                   AS total_revenue,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT invoice), 2)         AS avg_order_value,
    ROUND(SUM(CAST(revenue AS REAL)) / COUNT(DISTINCT customer_id), 2)     AS avg_ltv,
    ROUND(100.0 * SUM(CAST(revenue AS REAL))
          / SUM(SUM(CAST(revenue AS REAL))) OVER (), 2)                    AS revenue_share_pct,
    RANK() OVER (ORDER BY SUM(CAST(revenue AS REAL)) DESC)                 AS revenue_rank
FROM transactions
GROUP BY country
ORDER BY total_revenue DESC;


-- Export 9: product_performance.csv
-- Top 200 products by total revenue with reach and price metrics.
-- Used for the product table and Top N bar chart.
SELECT
    stock_code,
    MAX(description)                                                       AS description,
    COUNT(DISTINCT invoice)                                                AS orders,
    SUM(CAST(quantity AS INTEGER))                                         AS total_quantity,
    ROUND(SUM(CAST(revenue AS REAL)), 2)                                   AS total_revenue,
    ROUND(AVG(CAST(price   AS REAL)), 2)                                   AS avg_unit_price,
    COUNT(DISTINCT customer_id)                                            AS distinct_customers,
    ROUND(100.0 * SUM(CAST(revenue AS REAL))
          / SUM(SUM(CAST(revenue AS REAL))) OVER (), 3)                    AS revenue_share_pct
FROM transactions
GROUP BY stock_code
ORDER BY total_revenue DESC
LIMIT 200;