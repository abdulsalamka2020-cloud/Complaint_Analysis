# Data Quality Report

**Project:** Consumer Complaint Monitoring and Response Dashboard (AnalystLab Africa, Week 4, Data Analytics)
**Source file:** `Consumer_Complaints.xlsx`, sheet `Data` (62,516 rows, 12 columns)
**Processing:** MySQL 8.0 (`complaints_raw` to `complaints_clean`), cross-checked with Python (pandas)
**Script:** `sql/01_cleaning_and_kpis_mysql.sql`

---

## 1. Summary

The dataset is in good condition for analysis. Complaint ID is unique, dates are valid and logical, and no category needed repairing. The quality issues are mostly **meaningful blanks** (fields not applicable or not recorded) that must be handled by meaning rather than deleted or filled in. No rows were removed during cleaning (62,516 in, 62,516 out).

| Area | Result |
|---|---|
| Structure | 62,516 rows, 12 columns, one worksheet |
| Primary key (Complaint ID) | Unique; 0 duplicates; 0 blanks |
| Date validity | No blank or unparseable dates; no negative intervals |
| Reporting period | 1 May 2017 to 28 Aug 2023 (first and last years are partial) |
| Whitespace issues | None found in text columns |
| Blank values | 4 columns affected (see section 3) |
| Rows removed | 0 |

---

## 2. Checks performed

| # | Check (from the brief) | Method | Result | Action |
|---|---|---|---|---|
| 1 | Inspect structure and types | Table and column review | 12 text/date columns; dates stored as dates in Excel, exported as `YYYY-MM-DD` | Loaded as text into `complaints_raw`, converted with `STR_TO_DATE` in the clean table |
| 2 | Uniqueness of Complaint ID | `COUNT(*)` vs `COUNT(DISTINCT)` | 62,516 distinct = 62,516 rows | Set as primary key of `complaints_clean` |
| 3 | Duplicate records | Duplicate ID query | 0 duplicate IDs | `ROW_NUMBER()` safeguard kept in the script |
| 4 | Missing values | Blank count per column | See section 3 | Handled by meaning |
| 5 | Validate date columns | Parse test, min/max, `date_received < date_submitted` | All dates parse; range 1 May 2017 to 28 Aug 2023; **0 negative intervals** | None needed |
| 6 | Standardise categories | `DISTINCT` and frequency review | 9 products, 46 sub-products, 76 issues, 158 sub-issues, 51 states (50 plus DC), 7 submission channels; no spelling or whitespace variants within a column | Product short labels added; see section 4 |
| 7 | Unusual or inconsistent values | Frequency, cross-tab and interval review | Items in section 4 | Documented, not changed |
| 8 | Document cleaning decisions | This document | See section 5 | |
| 9 | Validate calculations after cleaning | Row counts, KPI cross-checks vs Python | All matched (README section 8) | |
| 10 | Preserve the original | Original workbook untouched; `complaints_raw` is an exact text copy | Preserved | |

---

## 3. Missing values

| Column | Blank count | % of rows | Meaning | Treatment in `complaints_clean` |
|---|---:|---:|---|---|
| Complaint ID, Submitted via, Date submitted, Date received, State, Product, Issue, Company response to consumer | 0 | 0% | Complete | None |
| Sub-product | 7 | 0.01% | Not recorded | "Not specified" |
| Sub-issue | 10,858 | 17.37% | No detailed sub-issue was provided or applicable | "Not specified" |
| Company public response | 2,175 | 3.48% | Not recorded. 1,494 belong to "In progress" complaints; 681 to closed complaints (469 closed with explanation, 164 monetary relief, 40 non-monetary relief, 8 "Closed") | "Blank / not recorded" |
| Timely response? | 1,494 | 2.39% | **All 1,494 are "In progress"**, so no timeliness has been recorded yet | "Not recorded". **Not treated as "No"** |

**Why not delete or fill?** Removing these rows would drop real complaints (for example, every in-progress complaint) and filling them would invent information. They are kept and labelled so analysts can include or exclude them knowingly.

**Timely-response rule.** The timely percentage uses only records with a valid Yes or No (61,022). The 1,494 "Not recorded" records are reported separately, never counted as "No".

---

## 4. Unusual or inconsistent values (documented, not altered)

| # | Finding | Detail | Decision |
|---|---|---|---|
| 1 | "Closed" response category | 8 complaints are "Closed" (not "Closed with explanation"). All 8 have timely = No and a blank public response | Kept as its own category; meaning not confirmed in the data dictionary |
| 2 | Submission channel labels | "Web Referral" (90) appears next to "Referral" (10,766); "Email" has only 2 records | Kept as supplied; not merged because the data dictionary does not define them. Flag for the data owner |
| 3 | Sub-product and issue mismatch | The 7 blank sub-product rows are all "Checking or savings account" with credit-reporting issues (5 "Incorrect information on your report", 2 "Problem with a credit reporting company's investigation") | Kept; possible product mis-classification at source |
| 4 | Rows identical except ID | 1,494 rows have the same attribute values as another row but a different Complaint ID | Treated as separate complaints because IDs are unique and the data has no narrative or company-level detail to tell them apart |
| 5 | Very long forwarding intervals | 1,506 complaints (2.4%) take more than 14 days; the longest is 275 days (a debt collection complaint received 22 Jun 2021 and forwarded 24 Mar 2022) | Kept and flagged with `long_interval_flag`; shown in the page 4 table |
| 6 | In-progress complaints are all recent | All 1,494 are from May to Aug 2023 (16.4% of 2023 year-to-date complaints) | Excluded from the timely denominator; will bias any 2023 response analysis |
| 7 | Partial years | 2017 starts 1 May; 2023 ends 28 Aug | `partial_year` flag; year-to-date logic for year-over-year KPIs |
| 8 | Very small product groups | Student loan has 39 complaints; payday/title/personal loan 333 | Shown but not used for percentage-based conclusions |

---

## 5. Cleaning decisions log

| # | Step | Detail |
|---|---|---|
| 1 | Stage raw data | `complaints_raw`, every column as text, loaded from `Consumer_Complaints_raw.csv` |
| 2 | Trim text | `TRIM()` on all text columns; state upper-cased |
| 3 | Convert types | Dates via `STR_TO_DATE(LEFT(TRIM(x),10),'%Y-%m-%d')`; Complaint ID to unsigned integer |
| 4 | Deduplicate safeguard | `ROW_NUMBER() OVER (PARTITION BY complaint_id)` keeps the first row (removed 0) |
| 5 | Handle blanks by meaning | Sub-product and sub-issue "Not specified"; public response "Blank / not recorded"; timely "Not recorded" |
| 6 | Standardise timely field | Yes / No / Not recorded (blank is not No) |
| 7 | Shorten product labels | `product_short` (4 long names shortened; original `product` kept) |
| 8 | Derived fields | `complaint_year`, `complaint_quarter`, `month_num`, `month_name`, `year_month_start`, `forwarding_interval_days`, `interval_bucket`, `long_interval_flag` (>14 days), `partial_year` |
| 9 | Primary key | `ALTER TABLE complaints_clean ADD PRIMARY KEY (complaint_id)` |
| 10 | Validate | Row counts, unique IDs, timely counts, interval range and KPI cross-checks |

**Data-type requirement in Power BI:** `date_cfpb_received` and `date_sent_to_company` must be **Date**; `forwarding_interval_days`, `complaint_year`, `long_interval_flag` must be **Whole number**. If a date column is loaded as text, date filters in the KPI cards stop working and show all-time totals.

---

## 6. Field mapping (raw to clean)

| Raw column | Clean column |
|---|---|
| Complaint ID | `complaint_id` |
| Submitted via | `submitted_via` |
| Date submitted (CFPB received) | `date_cfpb_received` |
| Date received (sent to company) | `date_sent_to_company` |
| State | `state` |
| Product | `product`, `product_short` |
| Sub-product | `sub_product` |
| Issue | `issue` |
| Sub-issue | `sub_issue` |
| Company public response | `company_public_response` |
| Company response to consumer | `company_response` |
| Timely response? | `timely_status` |

---

## 7. Residual risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Blank timely values read as "No" | Medium | High | Denominator rule documented; "Not recorded" label used |
| Forwarding interval read as company response time | Medium | High | Definition repeated on dashboard and in KPI document |
| Partial-year comparisons | High | Medium | Year-to-date logic and notes |
| Wrong counts after a data-type error in Power BI | Medium | High | Validation values in README section 8 |
| Misinterpreting complaints as misconduct | Medium | High | Disclaimer on dashboard and README |
