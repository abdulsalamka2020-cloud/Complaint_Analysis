# KPI Definitions and Calculations

**Table:** `complaints_clean` (Power BI name: `'complaints_db complaints_clean'`)
**Period:** 1 May 2017 to 28 Aug 2023. 2017 and 2023 are partial years.
All values below are for all years with no filters, and were validated against an independent calculation.

## Shared definitions

| Term | Definition |
|---|---|
| Complaint | One record (one Complaint ID). A consumer-reported issue, not proof of misconduct |
| Complaint volume | Count of Complaint IDs, by `date_cfpb_received` (the date the CFPB received the complaint) |
| Product / issue | `product` (shown as `product_short`) and `issue` as recorded by the CFPB |
| Company response | `company_response` category as recorded; not proof of satisfactory resolution |
| Timely response | `timely_status` = Yes, No, or Not recorded. Not recorded = blank, all "In progress" |
| Forwarding interval | `date_sent_to_company` - `date_cfpb_received`, in days. CFPB processing time, not company response time |
| Long interval | Forwarding interval > 14 days (`long_interval_flag` = 1) |

---

## The 12 required KPIs

### 1. Total complaints
Count of Complaint IDs.
- SQL: `SELECT COUNT(*) FROM complaints_clean;`
- DAX: `Total Complaints = COUNTROWS ( 'complaints_db complaints_clean' )`
- **Value: 62,516**

### 2. Annual complaint volume
Total complaints grouped by `complaint_year`.

| Year | 2017* | 2018 | 2019 | 2020 | 2021 | 2022 | 2023** |
|---|---:|---:|---:|---:|---:|---:|---:|
| Complaints | 5,394 | 7,872 | 7,075 | 8,942 | 11,149 | 12,953 | 9,131 |

\* from 1 May 2017  \*\* to 28 Aug 2023

### 3. Monthly complaint volume
Total complaints grouped by `year_month_start`. Highest month: July 2023 (1,749). Lowest: February 2019 (356).

### 4. Complaints by financial product and 7. Percentage contribution to total
`Product % of Total = DIVIDE ( [Total Complaints], CALCULATE ( [Total Complaints], ALL ( product_short ) ) )`

| Product | Complaints | % of total |
|---|---:|---:|
| Checking or savings account | 24,814 | 39.69% |
| Credit card or prepaid card | 16,197 | 25.91% |
| Credit reporting and related | 7,710 | 12.33% |
| Mortgage | 6,601 | 10.56% |
| Money transfer, virtual currency or money service | 3,453 | 5.52% |
| Debt collection | 2,736 | 4.38% |
| Vehicle loan or lease | 633 | 1.01% |
| Payday, title or personal loan | 333 | 0.53% |
| Student loan | 39 | 0.06% |

### 5. Complaints by reported issue (top 10 of 76)

| Issue | Complaints | % of total |
|---|---:|---:|
| Managing an account | 15,109 | 24.17% |
| Incorrect information on your report | 4,931 | 7.89% |
| Problem with a purchase shown on your statement | 4,415 | 7.06% |
| Closing an account | 2,953 | 4.72% |
| Trouble during payment process | 2,827 | 4.52% |
| Opening an account | 2,725 | 4.36% |
| Problem with a lender or other company charging your account | 2,493 | 3.99% |
| Fraud or scam | 1,987 | 3.18% |
| Struggling to pay mortgage | 1,904 | 3.05% |
| Problem with a credit reporting company's investigation into an existing problem | 1,876 | 3.00% |

### 6. Complaints by sub-product and sub-issue
Top sub-products: Checking account 20,768; General-purpose credit card or charge card 13,404; Credit reporting 7,340; Conventional home mortgage 3,767; Other banking product or service 2,568; Government benefit card 2,429; Domestic (US) money transfer 1,773; Credit card debt 1,697; Savings account 1,239; Home equity loan or line of credit 1,105.

Top sub-issues: Not specified 10,858 (blank, 17.4%); Deposits and withdrawals 5,596; Problem using a debit or ATM card 3,356; Credit card company isn't resolving a dispute about a purchase on your statement 2,770; Information belongs to someone else 2,401.

### 8. Company response category distribution

| Response | Complaints | % |
|---|---:|---:|
| Closed with explanation | 41,044 | 65.65% |
| Closed with monetary relief | 14,697 | 23.51% |
| Closed with non-monetary relief | 5,273 | 8.43% |
| In progress | 1,494 | 2.39% |
| Closed | 8 | 0.01% |

Public response: 60,311 "Company has responded to the consumer and the CFPB and chooses not to provide a public response"; 2,175 blank; 30 other recorded statements (for example 12 "opportunity to answer consumer's questions", 7 "misunderstanding", 6 "acted appropriately as authorized by contract or law").

### 9. Percentage of complaints with a timely response
Only records with a valid Yes or No are in the denominator. Excluded records are reported separately.

```dax
Timely Response % =
DIVIDE (
    CALCULATE ( [Total Complaints], timely_status = "Yes" ),
    CALCULATE ( [Total Complaints], timely_status IN { "Yes", "No" } )
)
```
- Yes 58,619; No 2,403; valid denominator 61,022; **excluded (Not recorded) 1,494**
- **Value: 96.06%**

By year (valid records only): 2017 99.83%, 2018 99.85%, 2019 99.90%, 2020 99.31%, 2021 89.02%, 2022 95.62%, 2023 YTD 93.16%.

### 10. Complaints marked In progress
`CALCULATE ( [Total Complaints], company_response = "In progress" )`
- **Value: 1,494** (all from May to Aug 2023; 16.4% of 2023 complaints)

### 11. Average and median forwarding interval
- Average: `AVERAGE ( forwarding_interval_days )` = **1.22 days**
- Median: `MEDIAN ( forwarding_interval_days )` = **0 days**
- 95th percentile = 5 days; maximum = 275 days

| Bucket | Complaints | % |
|---|---:|---:|
| Same day | 49,634 | 79.39% |
| 1-3 days | 8,431 | 13.49% |
| 4-7 days | 2,008 | 3.21% |
| 8-14 days | 937 | 1.50% |
| 15+ days | 1,506 | 2.41% |

Because the distribution is highly skewed (median 0, average 1.22), report the median and the share over 14 days alongside the average.

### 12. Year-over-year complaint volume change
`YoY % = (Current year - Prior year) / Prior year`

| Year | Complaints | YoY change |
|---|---:|---:|
| 2018 vs 2017* | 7,872 | +45.9% (2017 is partial) |
| 2019 | 7,075 | -10.1% |
| 2020 | 8,942 | +26.4% |
| 2021 | 11,149 | +24.7% |
| 2022 | 12,953 | +16.2% |
| 2023 YTD vs 2022 same period (1 Jan-28 Aug) | 9,131 vs 8,201 | **+11.3%** |

---

## Dashboard KPI card measures (year-to-date comparison)

| Card | 2023 YTD | 2022 YTD | Change | Favourable when |
|---|---:|---:|---:|---|
| Total complaints | 9,131 | 8,201 | +11.3% | Lower |
| Timely response % | 93.2% | 96.8% | -3.6 pts | Higher |
| Average forwarding interval (days) | 1.08 | 1.12 | -2.8% | Lower |
| Delayed (>14 days) % | 3.1% | 3.0% | +0.04 pts | Lower |
| Same-day forwarded % (optional card) | 91.5% | 83.4% | +8.1 pts | Higher |

Cutoff date is the latest date in the data; the prior-year period is the same dates one year earlier. Green = favourable change, red = unfavourable.
