# Architecture

## 1. Data flow

```
 SOURCES                    MYSQL  (finance_db)                                   EXCEL
 ───────                    ─────────────────────────────────────────────────    ─────────────────────
 data/raw/                  STAGING            CORE                ANALYTICS      Power Query (MySQL
 raw_transactions.csv ──▶   raw_transactions ─▶ transactions ─────▶ vw_* views ─▶ connector) loads views
 raw_valuations.csv   ──▶   raw_valuations  ─▶ investment_         (KPIs,         ─▶ Data sheets (tables)
                            (all VARCHAR,      valuations           trends,        ─▶ PivotTables + charts
 (later: your own           loaded as-is)      transactions_        budgets,       ─▶ Dashboard sheet:
  anonymized bank exports                      rejected             net worth,        KPI tiles, slicers,
  in data/private/)                            + reference tables   health score)     one-click Refresh All
                            ▲                  ▲                    ▲
                            02_load.sql        03_clean.sql         06_views.sql
                                               04_categorize.sql
                                               05_seed_planning.sql
                                                       90_tests.sql validates every layer
```

**Tools:** SQL (MySQL 8) and Excel only. No scripting languages anywhere in the pipeline.

**Why three layers**
- **Staging** stores raw text, so a malformed row never breaks the load and you can always re-run cleaning from the original data.
- **Core** is typed, constrained, deduplicated and categorized. It's the single source of truth.
- **Analytics** is a set of views shaped for Excel, so Excel never has KPI logic duplicated in formulas. Change a definition once in SQL and the dashboard follows on refresh.

## 2. Schema

| Table | Layer | Grain | Key columns | Notes |
|---|---|---|---|---|
| `raw_transactions` | staging | 1 row per exported line | all VARCHAR | 1,152 rows in the shipped dataset |
| `raw_valuations` | staging | instrument × month-end | all VARCHAR | 70 rows |
| `accounts` | reference | 1 per account | account_type | SBI Savings, HDFC Credit Card, Paytm Wallet |
| `categories` | reference | 1 per category | category_type (income/expense/investment/debt/transfer), is_essential | 23 categories |
| `categorization_rules` | reference | keyword → category | priority (lower wins) | 48 rules |
| `transactions` | core | 1 per real transaction | account_id, txn_date, amount>0, direction, category_id | unique (account_id, txn_date, amount, ref_no) |
| `transactions_rejected` | core (Phase 2) | 1 per rejected raw row | raw_id, reason | bad date / missing amount / unknown account |
| `investments` | reference | 1 per holding | instrument_type, txn_keyword | 2 MFs, 2 stocks, 1 FD |
| `investment_valuations` | core | holding × month-end | units_held, nav, market_value (generated) | |
| `loans` | reference | 1 per loan | principal, annual_rate, tenure, emi_amount | laptop loan ₹72,000 @14%, 24 mo, EMI ₹3,457 |
| `budgets` | planning (Phase 4) | category × month | budget_amount | seeded from planning values |
| `savings_goals` | planning (Phase 4) | 1 per goal | target_amount, target_date | |

ER sketch:

```
accounts 1───* transactions *───1 categories 1───* categorization_rules
                    │                  1
                    │                  └───* budgets
investments 1───* investment_valuations          loans (matched to transactions via txn_keyword)
```

## 3. Dataset facts (shipped synthetic data)

- **Persona:** CSE student and freelancer in Bhubaneswar. Covers Apr 2025 to Sep 2026 (18 months).
- **Income:** family support of ₹8,000/mo, 1–3 freelance invoices per month, a ₹10,000 internship stipend in the last 6 months, plus interest and dividends.
- **Expenses:**
  - Fixed: rent ₹6,500, utilities, recharge.
  - Variable: groceries, transport, food delivery (with an Oct–Nov festive spike), snacks, dining, shopping.
  - Subscriptions on the credit card.
  - A one-off CCNA exam (₹25,000, Aug 2026).
- **Investments:** Nifty 50 index SIP of ₹2,000/mo, a flexi-cap SIP of ₹1,000/mo from month 7, TCS and ITC stock buys, and a ₹20,000 FD.
- **Debt:** consumer laptop loan, EMI from Jun 2025.
- **Transfers:** each credit card statement is paid in full the next month, recorded on both sides (debit on SBI, "PAYMENT RECEIVED" on the card). The Paytm wallet is topped up from SBI.
- **Injected data-quality issues:**
  - 25 duplicate rows (same account + ref_no)
  - 6 bad dates (blank, `N/A`, `31-02-2026`)
  - 5 rows missing an amount
  - 35 messy descriptions (lowercase, padded)
  - 3 date formats
  - 4 merchants that no rule matches
- **Reconciliation target:** 1,152 raw = **1,116 clean + 11 rejected + 25 duplicates**.
- **Balance sanity:** the savings account never drops below about ₹6.2k and the wallet never goes negative. The credit card closes Sep 2026 owing ₹5,091. Expected rule coverage is 97.0% (33 uncategorized). Every month has 54–77 clean transactions.

## 4. Analytics views (Phase 5: `sql/06_views.sql`)

| View | Grain | Purpose / SQL technique |
|---|---|---|
| `vw_txn_enriched` | transaction | Joins category, type, essential flag, `month` (first of month), and `UPPER(TRIM)` description. Base for everything else |
| `vw_monthly_cashflow` | month | income, expenses, debt_service, invested, transfers_excluded, net_cash_flow (conditional aggregation) |
| `vw_category_monthly` | month × category | spend per category, share of month (window `SUM() OVER (PARTITION BY month)`) |
| `vw_mom_change` | month × category | `LAG()` month-over-month change, absolute and % |
| `vw_budget_vs_actual` | month × category | budget, actual, variance, variance_pct, status (Under/On track/Over) |
| `vw_account_balances` | account × day | running balance = opening + `SUM(signed_amount) OVER (ORDER BY txn_date, txn_id)` |
| `vw_month_end_balances` | account × month | last running balance per month (`ROW_NUMBER()` desc) |
| `vw_recurring_payments` | merchant | detects subscriptions and EMIs: same normalized merchant on ≥3 consecutive months with amount within ±10% (CTE + `LAG` on month) |
| `vw_loan_schedule` | loan × installment | amortization via **recursive CTE**: opening, interest, principal, closing balance |
| `vw_portfolio_monthly` | holding × month | cost basis to date (buys matched via `txn_keyword`), market value, unrealized gain |
| `vw_investment_cashflows` | dated cash flow | buys as negative, latest market value as positive (feeds Excel `XIRR`) |
| `vw_net_worth_monthly` | month | liquid + investments − card outstanding − loan outstanding |
| `vw_kpi_monthly` | month | all KPIs below, one row per month (the main dashboard feed) |
| `vw_kpi_summary` | 1 row | trailing-12-month and all-time headline KPIs for the tiles |
| `vw_health_score` | month | composite 0–100 score and its components |
| `vw_data_quality` | 1 row | raw / clean / rejected / duplicate counts, categorization coverage % |
| `vw_uncategorized_review` | merchant | uncategorized merchants by count and amount (feeds new rules) |

## 5. KPI definitions (single source of truth)

Monthly aggregates from `vw_monthly_cashflow`, where `month = DATE_FORMAT(txn_date,'%Y-%m-01')`:
- `income` = credits where category_type = 'income'
- `expenses` = debits where category_type = 'expense', plus uncategorized debits
- `debt_service` = debits where category_type = 'debt'
- `invested` = debits where category_type = 'investment'
- Transfers are excluded everywhere.

| # | KPI | Formula | Healthy band (for colour rules) |
|---|---|---|---|
| 1 | Savings Rate | (income − expenses − debt_service) / income | ≥ 20% green, 10–20% amber, < 10% red |
| 2 | Expense-to-Income | expenses / income | ≤ 70% |
| 3 | Debt-to-Income (DTI) | debt_service / income | ≤ 15% green, > 35% red |
| 4 | Investment Rate | invested / income | ≥ 10% |
| 5 | Net Cash Flow | income − expenses − debt_service − invested | > 0 |
| 6 | Essential Spend Share | essential expenses / expenses | ~50–60% |
| 7 | Emergency Fund Coverage (months) | month-end liquid balance (savings + wallet) / avg(essential expenses + debt_service, trailing 3 mo) | ≥ 6 |
| 8 | Budget Variance % | (actual − budget) / budget, per category and total | ≤ 0% |
| 9 | MoM Expense Growth | (expenses − LAG(expenses)) / LAG(expenses) | — |
| 10a | Recurring Burn | monthly sum of all detected recurring non-EMI payments | — |
| 10b | Subscription Burn | recurring non-EMI payments in **non-essential** categories only | — |
| 11 | Investment Return (absolute) | (market value − cost basis) / cost basis | — |
| 12 | Investment XIRR | Excel `XIRR()` over `vw_investment_cashflows` | — |
| 13 | Loan Payoff Progress | principal repaid / principal | — |
| 14 | Net Worth | liquid + investment market value − card outstanding − loan outstanding | rising |
| 15 | Financial Health Score | weighted 0–100, see below | ≥ 70 good |

**Recurring vs subscription burn.** The recurrence detector (`vw_recurring_payments`) finds
every merchant billing a stable amount for 3+ consecutive months, which legitimately includes
rent and the phone recharge. Reporting that total as "Subscription Burn" would put ₹6,500 of
rent inside a tile people read as cancellable spend, so the KPI is split: `recurring_burn` is
the full figure, `subscription_burn` keeps only non-essential categories — the discretionary
spend you could actually cancel. On the shipped data that is ₹8,007 vs ₹1,158.

**Financial Health Score.** Each component is linearly clamped to 0–1, then weighted:
- Savings rate: 25 pts. Full at ≥ 20%, zero at ≤ 0%.
- DTI: 20 pts. Full at ≤ 10%, zero at ≥ 40%.
- Emergency months: 25 pts. Full at ≥ 6, zero at 0.
- Investment rate: 15 pts. Full at ≥ 15%, zero at 0%.
- Budget adherence: 15 pts, measured as the share of budgeted categories at or under budget.

Use `NULLIF(income,0)` in every ratio.

## 6. Excel dashboard design (Phase 7)

**Workbook:** `excel/finance_dashboard.xlsx`.

| Sheet | Contents |
|---|---|
| `Dashboard` | Header row with a period slicer (Timeline on month) and account/category slicers. Row of 6 KPI tiles: Savings Rate, DTI, Emergency Months, Net Worth, Investment XIRR, Health Score. Each tile shows the current value, delta vs previous month, and conditional-format colour from the healthy bands. Charts: (1) Income vs Expenses vs Net Cash Flow clustered column + line; (2) Spend by category donut or bar for the selected month; (3) Budget vs Actual bar with variance colour; (4) Net Worth line, stacked by component; (5) Portfolio cost vs market value line; (6) Health score trend line. Plus a top-10 merchants table |
| `Budget` | PivotTable on `vw_budget_vs_actual` with icon sets |
| `Investments` | portfolio table, XIRR cell, `vw_loan_schedule` amortization table |
| `Data_*` | one sheet per Power Query table (loaded as Excel Tables, hidden or grouped) |
| `Data_Quality` | `vw_data_quality` and `vw_uncategorized_review` |
| `About` | KPI definitions, refresh steps, data source note ("synthetic 18-month dataset, see docs/DATA_INVENTORY.md") |

**Connection.** Excel → Data → Get Data → From Database → From MySQL Database, `localhost`, database `finance_db`. Select the `vw_*` views and load each as a Table. Data → Refresh All updates everything.
