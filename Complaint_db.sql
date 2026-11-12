CREATE DATABASE IF NOT EXISTS complaints_db;
USE complaints_db;
DROP TABLE IF EXISTS complaints_raw;
CREATE TABLE complaints_raw (
    complaint_id                  VARCHAR(20),
    submitted_via                 VARCHAR(50),
    date_submitted                VARCHAR(30),   
    date_received                 VARCHAR(30),   
    state                         VARCHAR(10),
    product                       VARCHAR(150),
    sub_product                   VARCHAR(150),
    issue                         VARCHAR(255),
    sub_issue                     VARCHAR(255),
    company_public_response       VARCHAR(400),
    company_response_to_consumer  VARCHAR(100),
    timely_response               VARCHAR(10)
);
SET GLOBAL local_infile = 1;
TRUNCATE TABLE complaints_raw;
LOAD DATA LOCAL INFILE "C:/Users/PC/Downloads/Consumer_Complaints_raw.csv"
INTO TABLE complaints_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
select * FROM complaints_raw;


-- 1. INSPECTION
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT complaint_id) AS unique_ids,
       COUNT(*) - COUNT(DISTINCT complaint_id) AS duplicate_ids
FROM complaints_raw;

SELECT complaint_id, COUNT(*) AS n
FROM complaints_raw GROUP BY complaint_id HAVING COUNT(*) > 1;

-- Blank values per column
SELECT
    SUM(NULLIF(TRIM(complaint_id),'') IS NULL)                  AS blank_id,
    SUM(NULLIF(TRIM(submitted_via),'') IS NULL)                 AS blank_channel,
    SUM(NULLIF(TRIM(date_submitted),'') IS NULL)                AS blank_date_submitted,
    SUM(NULLIF(TRIM(date_received),'') IS NULL)                 AS blank_date_received,
    SUM(NULLIF(TRIM(state),'') IS NULL)                         AS blank_state,
    SUM(NULLIF(TRIM(product),'') IS NULL)                       AS blank_product,
    SUM(NULLIF(TRIM(sub_product),'') IS NULL)                   AS blank_sub_product,
    SUM(NULLIF(TRIM(issue),'') IS NULL)                         AS blank_issue,
    SUM(NULLIF(TRIM(sub_issue),'') IS NULL)                     AS blank_sub_issue,
    SUM(NULLIF(TRIM(company_public_response),'') IS NULL)       AS blank_public_response,
    SUM(NULLIF(TRIM(company_response_to_consumer),'') IS NULL)  AS blank_company_response,
    SUM(NULLIF(TRIM(timely_response),'') IS NULL)               AS blank_timely
FROM complaints_raw;

-- What do the blank timely / blank public-response values line up with?
SELECT company_response_to_consumer,
       COALESCE(NULLIF(TRIM(timely_response),''), '<blank>')         AS timely,
       SUM(NULLIF(TRIM(company_public_response),'') IS NULL)         AS blank_public_response,
       COUNT(*)                                                      AS n
FROM complaints_raw
GROUP BY 1, 2 ORDER BY n DESC;

-- Category spellings
SELECT submitted_via, COUNT(*) FROM complaints_raw GROUP BY 1 ORDER BY 2 DESC;  -- note "Web Referral" vs "Referral"
SELECT company_response_to_consumer, COUNT(*) FROM complaints_raw GROUP BY 1 ORDER BY 2 DESC;  -- note 8 "Closed"
SELECT product, COUNT(*) FROM complaints_raw GROUP BY 1 ORDER BY 2 DESC;
SELECT COUNT(DISTINCT state) AS states FROM complaints_raw;                      

-- Date validity
SELECT SUM(STR_TO_DATE(LEFT(TRIM(date_submitted),10),'%Y-%m-%d') IS NULL) AS bad_date_submitted,
       SUM(STR_TO_DATE(LEFT(TRIM(date_received),10),'%Y-%m-%d')  IS NULL) AS bad_date_received,
       MIN(STR_TO_DATE(LEFT(TRIM(date_submitted),10),'%Y-%m-%d')) AS min_date,
       MAX(STR_TO_DATE(LEFT(TRIM(date_submitted),10),'%Y-%m-%d')) AS max_date
FROM complaints_raw;

SELECT COUNT(*) AS negative_intervals
FROM complaints_raw
WHERE STR_TO_DATE(LEFT(TRIM(date_received),10),'%Y-%m-%d')
    < STR_TO_DATE(LEFT(TRIM(date_submitted),10),'%Y-%m-%d');

-- Inconsistent product/issue combinations (7 blank sub-products are all of this kind)
SELECT product, issue, COUNT(*) AS n
FROM complaints_raw
WHERE NULLIF(TRIM(sub_product),'') IS NULL
GROUP BY 1,2;

-- 2. CLEANING
CREATE TABLE complaints_clean AS
SELECT
    b.*,
    CASE b.product
        WHEN 'Credit reporting, credit repair services, or other personal consumer reports' THEN 'Credit reporting'
        WHEN 'Money transfer, virtual currency, or money service'                          THEN 'Money transfer / services'
        WHEN 'Payday loan, title loan, or personal loan'                                   THEN 'Payday / title / personal loan'
        WHEN 'Credit card or prepaid card'                                                 THEN 'Credit / prepaid card'
        ELSE b.product
    END                                                           AS product_short,
    YEAR(b.date_cfpb_received)                                    AS complaint_year,
    QUARTER(b.date_cfpb_received)                                 AS complaint_quarter,
    MONTH(b.date_cfpb_received)                                   AS month_num,
    DATE_FORMAT(b.date_cfpb_received, '%b')                       AS month_name,
    DATE_FORMAT(b.date_cfpb_received, '%Y-%m-01')                 AS year_month_start,
    DATEDIFF(b.date_sent_to_company, b.date_cfpb_received)        AS forwarding_interval_days,
    CASE
        WHEN DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) < 0  THEN 'Invalid (negative)'
        WHEN DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) = 0  THEN 'Same day'
        WHEN DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) <= 3 THEN '1-3 days'
        WHEN DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) <= 7 THEN '4-7 days'
        WHEN DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) <= 14 THEN '8-14 days'
        ELSE '15+ days'
    END                                                           AS interval_bucket,
    (DATEDIFF(b.date_sent_to_company, b.date_cfpb_received) > 14) AS long_interval_flag,   
    (YEAR(b.date_cfpb_received) IN (2017, 2023))                  AS partial_year          
FROM (
    SELECT
        CAST(TRIM(r.complaint_id) AS UNSIGNED)                                    AS complaint_id,
        TRIM(r.submitted_via)                                                     AS submitted_via,
        STR_TO_DATE(LEFT(TRIM(r.date_submitted),10), '%Y-%m-%d')                  AS date_cfpb_received,
        STR_TO_DATE(LEFT(TRIM(r.date_received),10),  '%Y-%m-%d')                  AS date_sent_to_company,
        UPPER(TRIM(r.state))                                                      AS state,
        TRIM(r.product)                                                           AS product,
        COALESCE(NULLIF(TRIM(r.sub_product),''), 'Not specified')                 AS sub_product,
        TRIM(r.issue)                                                             AS issue,
        COALESCE(NULLIF(TRIM(r.sub_issue),''), 'Not specified')                   AS sub_issue,
        COALESCE(NULLIF(TRIM(r.company_public_response),''), 'Blank / not recorded') AS company_public_response,
        TRIM(r.company_response_to_consumer)                                      AS company_response,
        CASE
            WHEN UPPER(TRIM(r.timely_response)) = 'YES' THEN 'Yes'
            WHEN UPPER(TRIM(r.timely_response)) = 'NO'  THEN 'No'
            ELSE 'Not recorded'          -- blank is NOT "No"; all are "In progress"
        END                                                                       AS timely_status
    FROM (
        SELECT x.*, ROW_NUMBER() OVER (PARTITION BY TRIM(x.complaint_id) ORDER BY x.complaint_id) AS rn
        FROM complaints_raw x
    ) r
    WHERE r.rn = 1                       
) b;

ALTER TABLE complaints_clean ADD PRIMARY KEY (complaint_id);

-- 3. VALIDATION AFTER CLEANING -----------------------------------------
SELECT COUNT(*) AS clean_rows, COUNT(DISTINCT complaint_id) AS unique_ids FROM complaints_clean;
SELECT (SELECT COUNT(*) FROM complaints_raw) - (SELECT COUNT(*) FROM complaints_clean) AS rows_removed;   
SELECT timely_status, COUNT(*) FROM complaints_clean GROUP BY 1;
SELECT interval_bucket, COUNT(*) FROM complaints_clean GROUP BY 1 ORDER BY 2 DESC;
SELECT MIN(forwarding_interval_days), MAX(forwarding_interval_days),
       SUM(date_cfpb_received IS NULL OR date_sent_to_company IS NULL) AS null_dates
FROM complaints_clean;

-- 4. KPI QUERIES 
-- 4.1 Total complaints
SELECT COUNT(*) AS total_complaints FROM complaints_clean;

-- 4.2 / 4.12 Annual volume + YoY change (2017 and 2023 are partial years)
SELECT complaint_year, COUNT(*) AS complaints,
       LAG(COUNT(*)) OVER (ORDER BY complaint_year) AS prev_year,
       ROUND(100.0 * (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY complaint_year))
             / NULLIF(LAG(COUNT(*)) OVER (ORDER BY complaint_year), 0), 1) AS yoy_pct
FROM complaints_clean GROUP BY complaint_year ORDER BY complaint_year;

-- 4.3 Monthly volume
SELECT year_month_start, COUNT(*) AS complaints
FROM complaints_clean GROUP BY year_month_start ORDER BY year_month_start;

-- 4.4 / 4.7 Product volume and % of total
SELECT product, COUNT(*) AS complaints,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM complaints_clean GROUP BY product ORDER BY complaints DESC;

-- 4.5 Issues
SELECT issue, COUNT(*) AS complaints,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM complaints_clean GROUP BY issue ORDER BY complaints DESC;

-- 4.6 Sub-product and sub-issue
SELECT product, sub_product, COUNT(*) AS complaints
FROM complaints_clean GROUP BY 1,2 ORDER BY complaints DESC;
SELECT issue, sub_issue, COUNT(*) AS complaints
FROM complaints_clean GROUP BY 1,2 ORDER BY complaints DESC;

-- 4.8 Company response distribution
SELECT company_response, COUNT(*) AS complaints,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM complaints_clean GROUP BY 1 ORDER BY 2 DESC;

-- Public response categories
SELECT company_public_response, COUNT(*) AS complaints
FROM complaints_clean GROUP BY 1 ORDER BY 2 DESC;

-- 4.9 Timely-response % (denominator = Yes + No only); excluded records reported separately
SELECT SUM(timely_status = 'Yes')                       AS timely_yes,
       SUM(timely_status = 'No')                        AS timely_no,
       SUM(timely_status IN ('Yes','No'))               AS valid_denominator,
       SUM(timely_status = 'Not recorded')              AS excluded_not_recorded,
       ROUND(100.0 * SUM(timely_status = 'Yes')
             / NULLIF(SUM(timely_status IN ('Yes','No')), 0), 2) AS timely_pct
FROM complaints_clean;

-- 4.10 In progress
SELECT COUNT(*) AS in_progress FROM complaints_clean WHERE company_response = 'In progress';

-- 4.11 Average and median forwarding interval (CFPB -> company; NOT company response time)
SELECT ROUND(AVG(forwarding_interval_days), 2) AS avg_days,
       MAX(forwarding_interval_days)           AS max_days
FROM complaints_clean;

-- Median (MySQL has no PERCENTILE_CONT)
SELECT AVG(forwarding_interval_days) AS median_days
FROM (
    SELECT forwarding_interval_days,
           ROW_NUMBER() OVER (ORDER BY forwarding_interval_days) AS rn,
           COUNT(*) OVER ()                                      AS cnt
    FROM complaints_clean
) t
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2));

-- 95th percentile
SELECT forwarding_interval_days AS p95_days
FROM (
    SELECT forwarding_interval_days,
           ROW_NUMBER() OVER (ORDER BY forwarding_interval_days) AS rn,
           COUNT(*) OVER ()                                      AS cnt
    FROM complaints_clean
) t
WHERE rn = CEIL(0.95 * cnt);

-- Interval by product (average + median)
SELECT product_short,
       COUNT(*) AS complaints,
       ROUND(AVG(forwarding_interval_days), 2) AS avg_days,
       AVG(CASE WHEN rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
                THEN forwarding_interval_days END) AS median_days
FROM (
    SELECT product_short, forwarding_interval_days,
           ROW_NUMBER() OVER (PARTITION BY product_short ORDER BY forwarding_interval_days) AS rn,
           COUNT(*)     OVER (PARTITION BY product_short)                                    AS cnt
    FROM complaints_clean
) t
GROUP BY product_short ORDER BY avg_days DESC;

-- Unusually long intervals
SELECT complaint_id, product_short, date_cfpb_received, date_sent_to_company, forwarding_interval_days
FROM complaints_clean
WHERE long_interval_flag = 1
ORDER BY forwarding_interval_days DESC
LIMIT 50;

-- Product x issue matrix
SELECT product_short, issue, COUNT(*) AS complaints
FROM complaints_clean GROUP BY 1,2 ORDER BY complaints DESC;
