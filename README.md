# Customer Lifecycle and Revenue Intelligence System

An end-to-end business intelligence project that transforms two years of raw transactional data from a UK-based online retailer into a structured analytical system covering data preprocessing, relational SQL analysis, and an interactive four-page Power BI dashboard. The project demonstrates a complete data pipeline from uncleaned Excel input through cohort retention analysis, RFM customer segmentation, and revenue intelligence reporting.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Dataset](#2-dataset)
3. [Technology Stack](#3-technology-stack)
4. [Repository Structure](#4-repository-structure)
5. [Pipeline Architecture](#5-pipeline-architecture)
6. [Stage 1: Python Data Preprocessing](#6-stage-1-python-data-preprocessing)
7. [Stage 2: SQL Analytical Layer](#7-stage-2-sql-analytical-layer)
8. [Stage 3: Power BI Dashboard](#8-stage-3-power-bi-dashboard)
9. [Key Findings and Business Insights](#9-key-findings-and-business-insights)
10. [Limitations and Known Gaps](#10-limitations-and-known-gaps)
11. [Potential Improvements](#11-potential-improvements)
12. [How to Reproduce](#12-how-to-reproduce)
13. [Citation](#13-citation)

---

## 1. Project Overview

This project is designed as a comprehensive, end-to-end business intelligence case study focused on transforming real-world transactional data into actionable insights about customer behavior, retention patterns, and revenue generation. The dataset originates from a UK-based non-store online retailer specializing in occasion gift-ware, where a significant proportion of the customer base consists of wholesale buyers.

The analytical objectives are organized around three interconnected themes:

**Customer Lifecycle:** Understanding when customers are acquired, how long they stay active, and at what rate they churn using cohort-based retention analysis.

**Revenue Intelligence:** Tracking monthly revenue trends, measuring growth rates, and identifying how revenue is distributed between new and returning customers.

**Customer Segmentation:** Scoring every customer on Recency, Frequency, and Monetary dimensions to group them into behaviorally distinct segments, enabling prioritized CRM and retention actions.

The implementation follows a structured multi-tool pipeline: Python for preprocessing and feature engineering, SQLite via DBeaver for relational analytical logic, and Power BI for interactive visualization and communication.

---

## 2. Dataset

**Name:** Online Retail II  
**Source:** UCI Machine Learning Repository  
**DOI:** https://doi.org/10.24432/C5CG6D  
**Citation:** Chen, D. (2012). Online Retail II [Dataset]. UCI Machine Learning Repository.

The dataset covers all transactions of a UK-based, non-store online retailer between December 1, 2009 and December 9, 2011. The raw file is provided as a single Excel workbook containing two sheets covering separate annual periods.

| Sheet | Period | Raw Rows |
|---|---|---|
| Year 2009-2010 | Dec 2009 to Dec 2010 | 525,461 |
| Year 2010-2011 | Dec 2010 to Dec 2011 | 541,910 |
| **Combined** | **Dec 2009 to Dec 2011** | **1,067,371** |

**Variable Descriptions:**

| Field | Type | Description |
|---|---|---|
| Invoice | Nominal | 6-digit transaction identifier. Prefix "C" indicates cancellation. |
| StockCode | Nominal | 5-digit product identifier |
| Description | Nominal | Product name |
| Quantity | Numeric | Units purchased per line item |
| InvoiceDate | Datetime | Transaction timestamp |
| Price | Numeric | Unit price in GBP |
| Customer ID | Nominal | 5-digit customer identifier (contains missing values) |
| Country | Nominal | Customer residence country |

**Known data quality issues declared in the source:**
- Missing values are present (Customer ID is missing for 22.77% of all raw rows)
- Cancellation records are mixed into the main transaction log
- Negative quantity and price values exist from return/adjustment entries

---

## 3. Technology Stack

| Tool | Role | Notes |
|---|---|---|
| Python 3.10+ | Data preprocessing and EDA | Executed via Jupyter Notebook in VS Code |
| pandas | DataFrame manipulation and export | Core transformation library |
| matplotlib + seaborn | Exploratory visualizations and cohort heatmap | Charts saved as PNG to `outputs/` |
| openpyxl | Excel file reading | Required backend for `pd.read_excel` |
| DBeaver Community | SQL IDE | Used with a local SQLite file connection |
| SQLite | Analytical database engine | Lightweight, serverless, file-based |
| SQL (CTEs, window functions) | Analytical logic layer | Cohort, RFM, revenue trend queries |
| Power BI Desktop | Dashboard and visualization | No subscription; free desktop edition |
| DAX | Calculated measures in Power BI | Custom KPI and segment measures |

---

## 4. Repository Structure

```
Customer-Lifecycle-and-Revenue-Intelligence-System/
│
├── online_retail_II.xlsx                                             # Raw source dataset (not tracked by Git due to size)
│
├── Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_
│   Intelligence_System_Cleaning.ipynb                               # Python notebook: preprocessing and EDA
│
├── Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_
│   Intelligence_System_Dashboard.pbix                               # Power BI dashboard file
│
├── Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_
│   Intelligence_System_Dashboard.pdf                                # Dashboard exported as PDF
│
├── retail_analytics.db                                               # SQLite database (DBeaver)
│
├── sql/
│   ├── schema_setup.sql                                             # Indexes and validation after CSV import
│   ├── analysis_query.sql                                           # Full analytical queries by theme
│   └── export_queries.sql                                           # Finalized export queries producing 9 CSVs
│
├── data/
│   ├── transactions.csv                                             # Python output: 790,717 line items
│   ├── orders.csv                                                   # Python output: 36,607 invoices
│   ├── customers.csv                                                # Python output: 5,864 customers
│   └── cohort_retention_python.csv                                  # Python output: cohort matrix (325 rows)
│
├── sql_exports/
│   ├── kpi_summary.csv                                              # Single-row executive KPIs
│   ├── monthly_revenue.csv                                          # Monthly revenue with MoM growth
│   ├── new_vs_returning.csv                                         # New vs returning by month
│   ├── cohort_retention.csv                                         # Full cohort-period matrix
│   ├── cohort_avg_curve.csv                                         # Average retention curve
│   ├── rfm_segments.csv                                             # Full RFM-scored customer list
│   ├── customer_frequency.csv                                       # Purchase frequency buckets
│   ├── country_revenue.csv                                          # Revenue by country
│   └── product_performance.csv                                      # Top 200 products by revenue
│
└── outputs/
    ├── cohort_retention_heatmap.png
    ├── ltv_distribution.png
    ├── monthly_revenue_trend.png
    ├── revenue_by_day_of_week.png
    └── top_countries_revenue.png
```

> The raw Excel file `online_retail_II.xlsx` is not tracked in this repository due to its size. It can be downloaded directly from the UCI Machine Learning Repository at https://doi.org/10.24432/C5CG6D.

---

## 5. Pipeline Architecture

```
[Raw Excel: online_retail_II.xlsx]
      |
      | Stage 1: Python (Jupyter Notebook in VS Code)
      |   Load both sheets -> Merge -> Exploratory scan
      |   -> Systematic cleaning -> Feature engineering
      |   -> Build 3 analytical tables -> Export CSV + PNG charts
      |
      v
[data/transactions.csv + orders.csv + customers.csv]
      |
      | Stage 2: SQL (DBeaver + SQLite)
      |   Import 3 CSVs as tables -> Add indexes
      |   -> Run analytical queries (CTEs, window functions)
      |   -> KPIs, cohort retention, RFM, revenue trends
      |   -> Export 9 analytical CSVs to sql_exports/
      |
      v
[sql_exports/*.csv  (9 files)]
      |
      | Stage 3: Power BI Desktop
      |   Import 9 CSVs -> Define measures in DAX
      |   -> Build 4-page dashboard
      |   -> Export as PDF
      |
      v
[Dashboard: .pbix + .pdf]
```

Each stage is self-contained. The Python notebook produces clean CSVs that the SQL layer consumes. The SQL layer produces analytically validated exports that Power BI consumes. No raw data enters Power BI directly.

---

## 6. Stage 1: Python Data Preprocessing

**File:** `Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_Intelligence_System_Cleaning.ipynb`

### 6.1 Loading and Merging

Both sheets were loaded using `pandas.read_excel` with `dtype={"Customer ID": str}` to prevent numeric coercion of the identifier field. A `source_sheet` column was appended before concatenation to preserve traceability. The merged dataset contains 1,067,371 rows across 8 original columns plus the source tag.

### 6.2 Initial Exploratory Scan

Before applying any transformation, a diagnostic pass documented the state of the raw data:

| Issue | Count | Share of Raw Rows |
|---|---|---|
| Missing Customer ID | 243,007 | 22.77% |
| Fully duplicated rows | 12,133 | 1.14% |
| Cancellation records (prefix "C") | 19,494 | 1.83% |
| Rows with quantity <= 0 | 22,950 | 2.15% |
| Rows with price <= 0 | 6,207 | 0.58% |
| Non-product stock codes | 5,761 | 0.54% |

Missing Customer ID was the largest quality issue by far, affecting nearly one quarter of all records. These rows cannot contribute to any customer-level analysis including cohort retention, RFM scoring, or lifetime value calculation, so their removal is analytically necessary rather than arbitrary.

### 6.3 Systematic Cleaning Pipeline

Filters were applied sequentially to provide a transparent, auditable log of each removal step:

| Step | Rows After | Removed |
|---|---|---|
| Raw combined dataset | 1,067,371 | |
| Remove fully duplicated rows | 1,055,238 | 12,133 |
| Remove cancellations (prefix "C") | 1,035,805 | 19,433 |
| Remove missing customer_id | 793,680 | 242,125 |
| Remove quantity <= 0 | 793,680 | 0 |
| Remove price <= 0 | 793,609 | 71 |
| Remove non-product stock codes | 790,717 | 2,892 |
| **Final clean dataset** | **790,717** | **276,654 (25.9%)** |

After removing cancellations, the quantity filter found zero additional rows to remove. This is expected because cancellation invoices carry the negative quantities, and they were already excluded in the prior step.

Non-product stock codes excluded include: POST, DOT, D, M, BANK CHARGES, PADS, CRUK, S, ADJUST, and C2. These represent postage fees, manual discounts, bank charges, and internal administrative entries.

### 6.4 Feature Engineering

Six new columns were created on the cleaned dataset:

| Feature | Derivation | Purpose |
|---|---|---|
| `revenue` | `quantity * price` | Core financial metric for all aggregations |
| `invoice_date_only` | Date portion of `invoice_date` | Enables date-based joins and period math |
| `invoice_year` | `.dt.year` | Annual grouping and YoY comparison |
| `invoice_month` | `.dt.month` | Monthly grouping |
| `invoice_yearmonth` | `.dt.to_period("M").astype(str)` | Period key in YYYY-MM format for SQL joins |
| `day_of_week` | `.dt.day_name()` | Intra-week revenue pattern analysis |

Revenue range after cleaning: £0.06 to £168,469.60. The maximum reflects large wholesale bulk orders typical for this type of retailer.

### 6.5 Three Analytical Tables

**Table 1: transactions (line-item level)**
- 790,717 rows
- One row per invoice line item
- Columns: invoice, stock_code, description, quantity, price, revenue, all date fields, customer_id, country
- File size: approximately 97 MB

**Table 2: orders (invoice level)**
- 36,607 rows
- One row per invoice, aggregating all line items within it
- Key derived columns: line_item_count, distinct_products, total_quantity, order_revenue
- Sanity check: order revenue sums match transactions exactly

**Table 3: customers (customer level)**
- 5,864 rows
- One row per customer, summarizing their full lifetime behavior
- Key derived columns: total_orders, active_months, lifetime_revenue, avg_order_value, recency_days
- Reference date for recency: 2011-12-10 (one day after the last recorded transaction)

**Sanity check result:** All three tables produce the same total revenue of £17,377,841.89 confirming no data was lost or duplicated across aggregation levels.

### 6.6 Exploratory Visualizations (outputs/)

Five charts were generated and saved to the `outputs/` folder:

**Monthly Revenue Trend (`monthly_revenue_trend.png`):** Revenue was relatively stable between £490,000 and £680,000 for the first half of the observation window. Starting in September 2010, a strong upward trend emerged, peaking at approximately £1.16M in November 2010. After a significant drop in December 2010, revenue recovered steadily through 2011, reaching a second peak near £1.13M in November 2011 before declining sharply in December 2011. The November peak pattern across both years indicates strong Q4 seasonality consistent with holiday gifting demand.

**Customer Lifetime Revenue Distribution (`ltv_distribution.png`):** The distribution is heavily right-skewed. The median lifetime revenue is £873 while the mean is £2,963, reflecting that a small group of high-value wholesale buyers significantly elevates the average. The bulk of customers fall below £1,500 in lifetime spend, confirming a classic long-tail distribution pattern common in B2B-inclusive retail environments.

**Top 10 Countries by Revenue (`top_countries_revenue.png`):** The United Kingdom accounts for an overwhelming majority of revenue (approximately £14.4M out of £17.4M total). The next four international markets are EIRE (Ireland), Netherlands, Germany, and France, but their combined revenue represents only a small fraction of the UK total. The scale difference makes international diversification an obvious area of strategic opportunity.

**Revenue by Day of Week (`revenue_by_day_of_week.png`):** Thursday generates the highest cumulative revenue across the full dataset period, followed by Tuesday and Wednesday. Saturday shows zero revenue, indicating the business does not process transactions on Saturdays. Sunday is the second lowest day. The Tuesday-to-Thursday window is clearly the primary operating window for high-value activity.

**Cohort Retention Heatmap (`cohort_retention_heatmap.png`):** The heatmap covers cohorts from December 2009 through October 2011. Month 0 is always 100% by definition. Month 1 retention across all cohorts ranges from approximately 9% to 35%, with the December 2009 cohort (the oldest and likely most established) showing the highest early retention at 35.1%. Retention stabilizes in the 10% to 25% range from Month 2 onward, with mild upticks visible in later months for older cohorts, which may reflect seasonal re-engagement.

---

## 7. Stage 2: SQL Analytical Layer

**Tool:** DBeaver Community Edition  
**Database engine:** SQLite  
**Database file:** `retail_analytics.db`

### 7.1 Import Procedure

The three CSV files produced by the Python notebook were imported into DBeaver as separate SQLite tables using the Import Data wizard. Table names match exactly: `transactions`, `orders`, `customers`.

### 7.2 Schema Setup (`schema_setup.sql`)

After import, ten indexes were added across the three tables to accelerate GROUP BY and JOIN operations on large datasets. The key indexes cover `customer_id`, `invoice`, `invoice_yearmonth`, `invoice_date_only`, `country`, and `stock_code` on the transactions table, and corresponding foreign key columns on orders and customers.

A validation query confirmed row counts and date ranges:
- transactions: earliest date 2009-12-01, latest date 2011-12-09
- Revenue cross-check across all three tables: £17,377,841.89 (match confirmed)

### 7.3 Analytical Queries (`analysis_query.sql`)

The full analysis file is organized into seven thematic sections:

**Section 1: Executive KPIs** covers the full-period summary, year-over-year comparison, and LTV percentile distribution. The repeat purchase rate is derived by counting customers with more than one order relative to the total distinct customer count.

**Section 2: Monthly Revenue Analysis** uses the LAG() window function to compute month-over-month growth rates and classifies each month as Strong Growth (greater than 20% increase), Growth, Flat, or Decline. A rolling 3-month average smooths volatility to surface the underlying trend direction. A day-of-week breakdown uses SQLite's `strftime('%w')` function since SQLite does not provide a native DAYNAME equivalent.

**Section 3: Customer Acquisition and Retention** identifies each customer's first purchase period using a MIN aggregation, classifies orders as New or Returning accordingly, and computes the average inter-purchase gap using LAG() across ordered purchase histories within each customer partition.

**Section 4: Cohort Retention Analysis** uses a three-CTE chain. The first CTE assigns each customer their cohort month. The second joins every transaction to its customer's cohort and computes the month offset using SQLite-compatible year and month arithmetic (year difference times 12 plus month difference). The third aggregates distinct active customers per cohort per month offset. Retention rates are then computed against each cohort's size.

**Section 5: RFM Segmentation** applies three independent NTILE(5) window functions scoring customers on Recency, Frequency, and Monetary dimensions, each on a 1-to-5 scale. The segment assignment uses a CASE WHEN block with 11 named behavioral categories based on R and F score combinations.

**Section 6: Product Intelligence** ranks products by revenue and customer reach, and tracks monthly revenue for the top 10 products to identify seasonal concentration.

**Section 7: Geographic Analysis** ranks countries by revenue share, tracks international revenue by quarter, and identifies the highest average LTV international markets among returning customers with sufficient sample size.

### 7.4 Export Queries (`export_queries.sql`)

Nine CSV files were exported from DBeaver using the Export Results feature after running each numbered query block:

| File | Rows | Content |
|---|---|---|
| kpi_summary.csv | 1 | Single-row executive KPIs |
| monthly_revenue.csv | 25 | Monthly revenue, orders, MoM growth |
| new_vs_returning.csv | 50 | Period x customer type combinations |
| cohort_retention.csv | 325 | Cohort x month number matrix |
| cohort_avg_curve.csv | 13 | Average retention rate per month offset |
| rfm_segments.csv | 5,864 | Full customer list with RFM scores and segments |
| customer_frequency.csv | 5 | Frequency bucket summary |
| country_revenue.csv | 41 | Revenue and LTV by country |
| product_performance.csv | 200 | Top 200 products by revenue |

---

## 8. Stage 3: Power BI Dashboard

**File:** `Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_Intelligence_System_Dashboard.pbix`  
**PDF export:** `Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_Intelligence_System_Dashboard.pdf`

The dashboard is built entirely from the nine SQL export CSVs. No raw or intermediate data enters Power BI directly. The dashboard consists of four pages, each focused on a distinct analytical question.

### Page 1: Executive Overview

**Purpose:** Provide top-line business performance metrics at a glance.

**Visuals:**
- Five KPI cards: Total Revenue, Total Customers, Total Orders, Avg Order Value, Repeat Purchase Rate
- Line and column combo chart: Monthly Revenue (bars) with Average Order Value overlay (line), grouped by year
- Donut chart: Distribution of months by growth label (Decline, Growth, Strong Growth, Baseline)
- Horizontal bar chart: Countries ranked by total revenue
- Year slicer: filters all visuals to 2009, 2010, or 2011

**Key numbers displayed:**
| Metric | Value |
|---|---|
| Total Revenue | £17.378M |
| Total Customers | 5,852 |
| Total Orders | 36,607 |
| Avg Order Value | £476.04 |
| Repeat Purchase Rate | 72.32% |

The revenue chart aggregated to annual bars reveals that 2010 produced the highest total revenue across the three years. The donut chart shows that roughly 35% of months experienced Growth, 35% experienced Decline, 27% experienced Strong Growth, and only one month represented the Baseline (the first period with no prior month to compare against).

### Page 2: Cohort Retention

**Purpose:** Track how customer cohorts retain engagement over time.

**Visuals:**
- Matrix table (heatmap): Cohort month (rows) by month number 0-12 (columns), values showing retention rate with green-to-red conditional formatting
- Line chart: Average retention curve across all cohorts, with minimum retention curve shown in red
- Bar chart: Cohort size by acquisition year

**Key observations from the Power BI matrix:**

The matrix aggregates retention values by year in the default collapsed view. Expanding to individual cohort months in the Python-generated heatmap reveals the full granularity. The average retention curve shows a steep drop from 100% at Month 0 to approximately 20-22% at Month 1, then a gradual plateau in the 15-20% range from Month 2 onward. The minimum retention curve confirms that some cohorts experienced near-zero retention in certain months, highlighting the heterogeneity across acquisition periods.

The 2010 year cohort produced the largest cohort size (approximately 3,300 customers acquired that year), while 2009 (covering only December) and 2011 produced smaller cohort pools.

### Page 3: Customer Behavior

**Purpose:** Analyze the dynamics between new and returning customers and characterize purchase frequency patterns.

**Visuals:**
- Stacked bar chart: Annual revenue contribution split between New and Returning customers
- Line chart: Annual count of New vs Returning customers over time
- Donut chart: Full-period revenue split between New and Returning
- Column chart: Customer count by purchase frequency bucket

**Key numbers displayed:**
| Metric | Value |
|---|---|
| Returning Customer Revenue Share | 83.03% |
| One-Time Buyer Share | 27.73% |
| New customer revenue (full period) | £2.95M (16.97%) |
| Returning customer revenue (full period) | £14.43M (83.03%) |

The frequency distribution chart shows that One-Time buyers (approximately 1,620 customers) and Occasional buyers with 2-3 orders (approximately 1,600 customers) are the two largest groups. Regular (4-6 orders), Frequent (7-12 orders), and High Frequency (13+ orders) groups each decline in count but contribute disproportionately large revenue shares.

### Page 4: Customer Segmentation

**Purpose:** Present RFM-based customer segments and their revenue contributions.

**Visuals:**
- Three KPI cards: Champions Revenue, At Risk Revenue, High Value Customers
- Scatter chart: Frequency (x-axis) vs Lifetime Revenue (y-axis), bubble size representing Recency, colored by segment
- Donut chart: Revenue share by segment
- Horizontal bar chart: Total revenue contribution by segment
- Summary table: Segment, customer count, total revenue, avg LTV, avg orders, avg days since last purchase

**Key numbers displayed:**
| Metric | Value |
|---|---|
| Champions Revenue | £1.19M |
| At Risk Revenue | £12.07M |
| High Value Customers | 1,614 |

**Full segment breakdown:**

| Segment | Customers | Total Revenue | Avg LTV | Avg Orders | Avg Days Since Last Purchase |
|---|---|---|---|---|---|
| At Risk | 1,471 | £12,069,737.80 | £8,205.12 | 15.52 | 19.42 |
| Loyal Customers | 1,260 | £2,622,965.65 | £2,081.72 | 5.27 | 208.06 |
| Potential Loyalists | 682 | £390,147.20 | £572.06 | 1.57 | 427.44 |
| Needs Attention | 644 | £489,302.61 | £759.79 | 2.23 | 60.58 |
| New Customers | 543 | £98,245.12 | £180.93 | 1.00 | 569.99 |
| (Others) | 1,264 | remaining | | | |
| **Total** | **5,864** | **£17,377,841.89** | **£2,963.48** | **6.24** | **199.90** |

---

## 9. Key Findings and Business Insights

### 9.1 Revenue Concentration and Seasonality

Total revenue over the two-year observation window was £17,377,841.89 across 36,607 invoices and 5,852 unique customers. Revenue shows a clear and consistent seasonal pattern with peaks in November of both 2010 and 2011, reaching approximately £1.16M and £1.13M respectively. December follows with a sharp decline in both years, suggesting that orders placed in November are dispatched before the retail Christmas cut-off and that December itself represents the tail-end of the peak cycle rather than its center.

The midyear trough visible between January and August of both years suggests that the business operates with significant seasonality risk. A narrow four-month window from September to November generates a disproportionate share of annual revenue.

### 9.2 The Returning Customer Dependency

Returning customers generated £14.43M out of the total £17.38M, representing 83.03% of all revenue. New customers contributed only £2.95M (16.97%). This is the single most important finding in the dataset. The business is structurally dependent on repeat purchasing rather than continuous new customer acquisition. The 72.32% repeat purchase rate confirms that most customers who are retained do come back, but the challenge is that a large share of the customer base (27.73% are one-time buyers) never returns at all.

The implication is that retention investment produces a much higher revenue return than acquisition-focused spending in this business context.

### 9.3 Cohort Retention: The First-Month Cliff

The cohort retention heatmap reveals a consistent and steep decline from Month 0 to Month 1 across all acquisition cohorts. Month 1 retention rates range from approximately 9.2% (the December 2010 cohort) to 35.1% (the December 2009 cohort). The average across all cohorts at Month 1 is approximately 20-22%. This means that roughly 78-80% of customers who made their first purchase did not return the following month.

After Month 1, the decline slows considerably. From Month 2 onward, retention plateaus in the 10-20% range for most cohorts, with minor fluctuations that likely reflect seasonal purchasing patterns rather than sustained engagement improvements. This plateau suggests that customers who survive beyond their first month develop a more durable purchasing habit.

The December 2009 cohort consistently shows higher retention rates than later cohorts across all months observed, which may reflect the fact that the earliest customers represent the most engaged and established wholesale buyers.

### 9.4 The At Risk Segment: A Critical Business Problem

The RFM segmentation reveals that the At Risk segment contains 1,471 customers (25.1% of the customer base) and accounts for £12,069,737.80 in total revenue, which is 69.5% of all lifetime revenue generated. These customers have high frequency scores (average of 15.52 orders) and very low recency (average of only 19.42 days since last purchase as of the reference date of December 10, 2011), which means they were recently active but scored low on Recency relative to the scoring window.

This counterintuitive result deserves careful interpretation. The At Risk label is generated by the RFM scoring logic where a low R score reflects a longer gap since last purchase relative to the most recent buyers in the dataset. Given that many of these high-frequency customers last purchased in late 2011, the scoring window may be placing them in lower recency quintiles relative to customers who purchased in the final weeks of the dataset. The business should investigate the actual absolute recency values rather than relying solely on the quintile-based score to determine true churn risk.

Champions generated only £1.19M, which reflects that this segment is a small group of very recently active high-frequency buyers. The Loyal Customers segment (1,260 customers, £2.62M) represents a more established and strategically important cohort for maintenance campaigns.

### 9.5 UK Market Concentration

The United Kingdom accounts for the vast majority of revenue (approximately £14.4M or 82.8% of the total). The next largest market, EIRE (Ireland), contributes a small fraction of that. Germany, Netherlands, and France are present but represent negligible revenue shares individually. The business is effectively a domestic UK operation with incidental international sales rather than a genuinely international retailer.

### 9.6 LTV Distribution and the Wholesale Effect

The customer lifetime revenue distribution is heavily right-skewed with a median of £873 and a mean of £2,963. The gap between these two measures (a factor of 3.4x) indicates the presence of a small number of very high-value buyers who significantly inflate the mean. These are likely wholesale buyers purchasing in bulk quantities for resale. The maximum single-customer revenue in the dataset is well above £100,000. Treating the mean as representative of the typical customer would substantially overstate expected LTV for planning purposes.

### 9.7 Day-of-Week Operating Pattern

Transactions occur exclusively on Monday through Sunday, but Saturday shows zero revenue. This is consistent with a business that does not accept or process orders on Saturdays. Thursday is the highest-revenue day, followed by Tuesday and Wednesday. The Mon-Fri operating pattern with a Thursday peak suggests that wholesale buyers tend to place their largest orders mid-to-late in the working week.

---

## 10. Limitations and Known Gaps

**Missing customer data (22.77% of raw rows excluded):** The removal of 242,125 rows with missing Customer ID is analytically necessary but introduces a selection bias. The customers represented by these anonymous transactions may behave differently from those with identifiable records. All customer-level analyses in this project reflect only the identifiable subset of transactions.

**No true customer-level demographic data:** The dataset contains only country as a geographic identifier. No age, channel, device, or acquisition source information is available. Segmentation is therefore limited to transactional behavior and cannot incorporate demographic or channel dimensions.

**Cohort retention uses monthly granularity:** Monthly cohort windows are coarser than weekly. A customer who last purchased on the final day of Month 1 and next purchased on the first day of Month 2 would register a gap of zero months in the month-offset calculation. This can slightly overstate retention rates for cohorts with tight purchase clusters.

**RFM scores are relative, not absolute:** NTILE quintile scoring assigns each customer a score relative to all other customers in the dataset. A customer in the top quintile for recency is simply more recent than 80% of others, not necessarily recent in an absolute sense. The At Risk segment anomaly described in Section 9.4 is a direct consequence of this relative scoring approach.

**No statistical testing:** All findings are descriptive. No hypothesis tests, confidence intervals, or significance levels are reported. Observed differences in cohort retention rates or segment revenue shares may reflect sampling variation rather than true behavioral differences.

**No forecasting or predictive modeling:** This project does not include churn prediction, LTV forecasting, or propensity scoring. The analysis is entirely retrospective and descriptive.

**Power BI cohort matrix shows year-level aggregation by default:** The Matrix visual in Power BI aggregates retention rates by year in the default collapsed state. The values displayed (e.g., 1,200 for Year 2010) are sums of monthly retention rates across cohorts in that year, not actual percentages. The Python-generated heatmap (`cohort_retention_heatmap.png`) is the correct visual reference for reading individual cohort-month retention rates.

**No product category dimension:** Products are identified only by stock code and free-text description. There is no structured product taxonomy, so product-level analysis cannot be aggregated to meaningful category groupings without additional manual labeling.

---

## 11. Potential Improvements

**Predictive churn modeling:** The cohort and RFM data provide a strong foundation for training a binary classifier to predict which customers are likely to churn before the next purchase window. Logistic regression or a gradient-boosted tree model using recency, frequency, average order value, and active months as features could produce individual-level churn probabilities.

**Customer LTV forecasting:** Using the BG/NBD (Beta-Geometric Negative Binomial Distribution) model combined with the Gamma-Gamma monetary model (available in the Python `lifetimes` library) would allow forward-looking customer LTV estimates. This would transform the current retrospective LTV into a predictive planning tool.

**Absolute recency thresholds in segmentation:** The current RFM model uses relative quintile scoring. Adding absolute recency rules (for example, flagging any customer who has not purchased in 90 days as truly at risk regardless of their quintile rank) would produce more actionable segment assignments.

**Product association analysis (Market Basket Analysis):** Using the Apriori or FP-Growth algorithm on the line-item data, frequently co-purchased products could be identified. This would support cross-sell recommendations and bundle pricing strategies.

**Structured product taxonomy:** Manually or semi-automatically assigning products to categories (for example, Christmas, home decor, kitchen) based on description keywords would enable category-level revenue and margin analysis.

**Time series decomposition and forecasting:** Applying STL (Seasonal-Trend decomposition using LOESS) to the monthly revenue series would formally separate the seasonal component from the trend, quantifying the exact magnitude of the November peak effect and enabling more robust revenue forecasts.

**Statistical cohort comparison:** Applying survival analysis techniques (Kaplan-Meier curves per cohort) would provide statistically grounded comparisons of retention between cohorts, with confidence intervals around each retention estimate.

**Power BI cohort heatmap improvement:** Replacing the Matrix visual (which aggregates by default) with a custom Python visual or an R visual inside Power BI would render the heatmap with proper color scale and individual cell formatting, eliminating the year-aggregation display issue.

**Automated pipeline:** Replacing the manual CSV export workflow in DBeaver with an automated Python script using the `sqlite3` or `duckdb` library would make the pipeline fully reproducible with a single command, removing the manual step of running and exporting queries from DBeaver.

**Dashboard deployment:** Publishing the Power BI file to Power BI Service (requires a Pro or Premium license) would enable scheduled data refresh, sharing via URL, and embedding in a web page or portfolio site.

---

## 12. How to Reproduce

### Prerequisites

- Python 3.10 or newer
- Visual Studio Code with the Python and Jupyter extensions installed
- DBeaver Community Edition (https://dbeaver.io)
- Power BI Desktop (https://powerbi.microsoft.com/en-us/desktop, free)
- The raw dataset downloaded from https://doi.org/10.24432/C5CG6D

### Step 1: Python Preprocessing

1. Place `online_retail_II.xlsx` in the project root folder.
2. Open VS Code and navigate to the project root.
3. Open `Victor_Sunarko_Projects_Customer_Lifecycle_and_Revenue_Intelligence_System_Cleaning.ipynb`.
4. Update the `BASE_DIR` variable in Section 0 to match your local project path.
5. Install dependencies: `pip install pandas openpyxl matplotlib seaborn numpy`
6. Run all cells in order from top to bottom using Shift+Enter.
7. Confirm the following files exist in `data/` after Section 9 completes:
   - `transactions.csv` (approximately 790,717 rows)
   - `orders.csv` (approximately 36,607 rows)
   - `customers.csv` (approximately 5,864 rows)
   - `cohort_retention_python.csv` (325 rows)
8. Confirm the following PNG files exist in `outputs/` after Section 8 completes.

### Step 2: SQL in DBeaver

1. Open DBeaver Community.
2. Create a new SQLite connection pointing to `retail_analytics.db` in the project data directory.
3. Import `transactions.csv`, `orders.csv`, and `customers.csv` as tables using DBeaver's Import Data wizard.
4. Open `sql/schema_setup.sql` and run all statements to create indexes and validate the import.
5. Open `sql/analysis_query.sql` and run sections as needed for exploration.
6. Open `sql/export_queries.sql` and run each numbered export query block.
7. After each query, click the export icon in the Results panel, choose CSV, and save to `sql_exports/` with the filename specified in the SQL comment.
8. Confirm all nine CSV files are present in `sql_exports/` before proceeding.

### Step 3: Power BI Dashboard

1. Open Power BI Desktop.
2. Use Get Data > Text/CSV to import all nine CSV files from `sql_exports/`.
3. Verify column data types for each table (numeric columns should be Decimal or Whole Number).
4. Create DAX measures as documented in `powerbi/dax_measures.md`.
5. Build the four pages as described in Section 8 of this README.
6. Save the file as `.pbix` to the project root.

---

## 13. Citation

```
Chen, D. (2012). Online Retail II [Dataset].
UCI Machine Learning Repository.
https://doi.org/10.24432/C5CG6D
```

---

*This project was developed as part of a data analytics portfolio demonstrating end-to-end proficiency across data cleaning, relational SQL analysis, and business intelligence visualization.*
