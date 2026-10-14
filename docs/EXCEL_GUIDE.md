# Excel Dashboard — Build Guide

Click-by-click build of `excel/finance_dashboard.xlsx`, the presentation layer over the
`vw_*` views. Excel holds **no KPI logic**: every number here comes from SQL, so a definition
change in `sql/06_views.sql` reaches the dashboard through Data → Refresh All.

Layout follows `docs/ARCHITECTURE.md` §6. Every target value below was measured from the
current build and is listed again in [§13 Verification](#13-verification) so you can check your
work.

---

## 0. Before you start

**You need MySQL Connector/ODBC (64-bit), not Connector/NET.** See §1 — the native MySQL
connector does not show up in Excel even when Connector/NET is correctly installed, so this
build connects over ODBC instead.

Confirm the database is green first:

```
Get-Content sql\00_run_all.sql | mysql --login-path=finance --local-infile=1
```

PowerShell has no `<` input redirection — it is a reserved operator — so the pipe above is the
native form. To use the documented syntax verbatim, hand it to cmd instead:

```
cmd /c "mysql --login-path=finance --local-infile=1 < sql\00_run_all.sql"
```

If `mysql` is not on PATH, substitute the full path
`"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"`, or add
`C:\Program Files\MySQL\MySQL Server 8.0\bin` to PATH and open a new terminal.

You want `ALL TESTS PASS` and 99/99. Build the dashboard on a green database or you will spend
your afternoon debugging Excel for a SQL problem.

You will need the `finance_app` password at the connection step — Excel stores it in its own
credential cache, separate from the login path.

---

## 1. Connect and load the views

**Use ODBC, not the native MySQL connector.** Excel's *From Database → From MySQL Database*
entry does not appear even with Connector/NET correctly installed and registered in the GAC and
`machine.config`. This is a long-standing detection failure
([MySQL bug #79616](https://bugs.mysql.com/bug.php?id=79616)), and Connector/NET's new
year-based versioning (26.x) appears not to match the assembly version range Power Query looks
for. ODBC is the documented workaround and is functionally identical — refresh, Data Model,
PivotCharts, slicers and query folding all behave the same.

Install **MySQL Connector/ODBC, 64-bit** (match your Excel bitness) from the MySQL Installer
→ Add, or `dev.mysql.com/downloads/connector/odbc/`. Then:

**Data → Get Data → From Other Sources → From ODBC**

| Field | Value |
|---|---|
| Data source name (DSN) | `(None)` |
| Advanced options → Connection string | `Driver={MySQL ODBC 26.7 Unicode Driver};SERVER=localhost;PORT=3306;DATABASE=finance_db;` |

Use the **Unicode** driver, not ANSI — ANSI mangles the ₹ symbol and anything outside Latin-1.
The driver version is baked into that string, so bump it after a driver upgrade, or create a
named DSN instead (ODBC Data Sources (64-bit) → User DSN → Add) and select it from the dropdown,
which abstracts the version away.

On the credentials prompt choose the **Database** tab on the left (not Windows), user
`finance_app`, and the password you set in Phase 0. Excel caches it against the source, so this
is a one-time step.

In the Navigator, tick **Select multiple items**, then select these 14 views. Expected row
counts are listed so you can spot a failed refresh immediately:

| View | Rows | Used for |
|---|---|---|
| `vw_kpi_summary` | 1 | The six KPI tiles |
| `vw_kpi_monthly` | 18 | Tile deltas, cashflow chart, trends |
| `vw_health_score` | 18 | Health score chart |
| `vw_net_worth_monthly` | 18 | Net worth chart |
| `vw_category_monthly` | 212 | Spend-by-category chart |
| `vw_budget_vs_actual` | 234 | Budget sheet and chart |
| `vw_portfolio_monthly` | 90 | Portfolio chart and table |
| `vw_investment_cashflows` | 42 | `XIRR()` |
| `vw_loan_schedule` | 24 | Amortization table |
| `vw_month_end_balances` | 54 | Balance chart |
| `vw_recurring_payments` | 6 | Subscription table |
| `vw_txn_enriched` | 1,116 | Top-10 merchants, account slicer |
| `vw_data_quality` | 1 | Data_Quality sheet |
| `vw_uncategorized_review` | 4 | Data_Quality sheet |

Click the arrow next to **Load** → **Load To…**

- For **all 14**: tick **Add this data to the Data Model**. This is what lets one timeline
  filter every chart (see §10).
- Additionally choose **Table** (new worksheet) for the seven that formulas read directly:
  `vw_kpi_summary`, `vw_kpi_monthly`, `vw_investment_cashflows`, `vw_loan_schedule`,
  `vw_recurring_payments`, `vw_data_quality`, `vw_uncategorized_review`.
- The rest can be **Only Create Connection** + Data Model. They are consumed by PivotTables,
  not by cell formulas, and keeping 1,116 transaction rows off a worksheet keeps the file small.

Rename each generated sheet to `Data_<name>` (e.g. `Data_KPI_Monthly`). Right-click the sheet
tabs → **Hide** once the dashboard is built, or group them at the right-hand end.

> **Check:** `Data_KPI_Monthly` should have 18 rows and 33 columns, `month` typed as Date and
> every numeric column as Decimal Number. If a numeric column came through as Text, the view is
> fine — click the column header in Power Query and set the type. It will not recur, because
> every view COALESCEs its numerics so Power Query never sees a NULL to guess from.

---

## 2. Build the data model

**Power Pivot → Manage** (if the tab is missing: File → Options → Add-ins → COM Add-ins → Go →
tick *Microsoft Power Pivot for Excel*).

### 2.1 Use `vw_monthly_cashflow` as the date dimension

A timeline needs one date table that every fact table hangs off. Without it a timeline filters
only the table it was created from.

No separate `dim_month` query is needed: **`vw_monthly_cashflow` already has exactly 18 rows,
one per month**, which is precisely what the "one" side of a relationship requires. Using it
saves building a blank query by hand.

### 2.2 Create relationships

**Data → Relationships → New…** (if the button is not visible in Data Tools, the window is too
narrow — use the search box at the top of Excel and pick the *Relationships* action).

Each dropdown lists every table **twice**, once as `Worksheet Table:` and once as
`Data Model Table:`. **Always pick the `Data Model Table:` entry** — relationships only exist in
the model, and choosing the worksheet copy silently does nothing useful.

Create seven, each with Column and Related Column set to `month`:

| Table (many side) | Related Table (one side) |
|---|---|
| `vw_kpi_monthly` | `vw_monthly_cashflow` |
| `vw_health_score` | `vw_monthly_cashflow` |
| `vw_net_worth_monthly` | `vw_monthly_cashflow` |
| `vw_category_monthly` | `vw_monthly_cashflow` |
| `vw_budget_vs_actual` | `vw_monthly_cashflow` |
| `vw_portfolio_monthly` | `vw_monthly_cashflow` |
| `vw_txn_enriched` | `vw_monthly_cashflow` |

Optionally add `vw_month_end_balances` and `vw_mom_change` the same way.
`vw_loan_schedule` extends to May 2027, past the data window — relating it is fine, the extra
months simply fall into a blank member.

> **Note on the field list:** because all 17 views were loaded as *both* worksheet tables and
> Data Model tables, every view appears twice in the PivotChart Fields pane. Harmless, but if
> the clutter bothers you, set the ones you do not read with formulas to *Only Create
> Connection* (Queries & Connections → right-click → Load To…). The seven that formulas do read
> — `vw_kpi_summary`, `vw_kpi_monthly`, `vw_investment_cashflows`, `vw_loan_schedule`,
> `vw_recurring_payments`, `vw_data_quality`, `vw_uncategorized_review` — must stay as tables.

> **Why this matters:** a slicer can only filter tables it is related to. This is the single
> most common reason a dashboard "looks finished but the slicers do nothing".

---

## 3. Sheet plan

Create these in order, left to right:

| Sheet | Contents |
|---|---|
| `Dashboard` | Tiles, six charts, top-10 merchants, slicers |
| `Budget` | Budget vs actual pivot with icon sets |
| `Investments` | Portfolio table, XIRR, loan amortization |
| `Data_Quality` | Reconciliation and uncategorized merchants |
| `About` | KPI definitions and refresh steps |
| `Data_*` | One per loaded table, hidden or grouped |

---

## 4. Dashboard — the six KPI tiles

Lay the tiles across `B3:M8`, each tile two merged cells tall: a label row, a big value, and a
small delta. Six tiles, per ARCHITECTURE §6.

Formulas read the worksheet tables. `Data_KPI_Summary` is one row, so direct references work;
deltas come from `Data_KPI_Monthly` with `XLOOKUP`.

Put the reporting month in a helper cell, say `B1`:

```excel
=MAX(Data_KPI_Monthly[month])
```

Then each tile's **value** and **delta**:

| Tile | Value formula | Delta formula |
|---|---|---|
| Savings Rate | `=XLOOKUP($B$1,Data_KPI_Monthly[month],Data_KPI_Monthly[savings_rate_pct])` | `=C4-XLOOKUP(EDATE($B$1,-1),Data_KPI_Monthly[month],Data_KPI_Monthly[savings_rate_pct])` |
| Debt-to-Income | `=XLOOKUP($B$1,Data_KPI_Monthly[month],Data_KPI_Monthly[dti_pct])` | same shape, `dti_pct` |
| Emergency Months | `=XLOOKUP($B$1,Data_KPI_Monthly[month],Data_KPI_Monthly[emergency_months])` | same shape, `emergency_months` |
| Net Worth | `=XLOOKUP($B$1,Data_KPI_Monthly[month],Data_KPI_Monthly[net_worth])` | same shape, `net_worth` |
| Investment XIRR | `=XIRR(Data_Inv_Cashflows[cash_flow],Data_Inv_Cashflows[cash_flow_date])` | — (period figure, no monthly delta) |
| Health Score | `=XLOOKUP($B$1,Data_Health_Score[month],Data_Health_Score[health_score])` | same shape, `health_score` |

Replace `C4` in the delta formula with whatever cell holds that tile's value.

**Number formats**

- Percentages (`savings_rate_pct`, `dti_pct`): the views return `46.56` meaning 46.56%, already
  multiplied. Use a custom format `0.0"%"` — **not** Excel's `%` format, which would multiply
  by 100 again and show 4656%.
- `emergency_months`: `0.0" mo"`
- XIRR returns a true fraction (0.1305), so here the real `%` format **is** correct: `0.0%`
- Rupee amounts, Indian lakh/crore grouping:
  `[>=10000000]₹ ##\,##\,##\,##0;[>=100000]₹ ##\,##\,##0;₹ ##,##0`
- Deltas: `+0.0;-0.0;0.0` so the sign always shows.

---

## 5. Conditional formatting — the healthy bands

Straight from `ARCHITECTURE.md` §5. Apply to each tile's value cell via **Home → Conditional
Formatting → New Rule → Format only cells that contain**.

| Tile | Green | Amber | Red |
|---|---|---|---|
| Savings Rate | `>= 20` | `10` to `20` | `< 10` |
| Debt-to-Income | `<= 15` | `15` to `35` | `> 35` |
| Emergency Months | `>= 6` | `3` to `6` | `< 3` |
| Investment Rate | `>= 10` | `5` to `10` | `< 5` |
| Net Cash Flow | `> 0` | — | `<= 0` |
| Essential Share | `50` to `60` | `40`–`50` or `60`–`70` | outside 40–70 |
| Budget Variance % | `<= 0` | `0` to `10` | `> 10` |
| Health Score | `>= 70` | `50` to `70` | `< 70` |

Order matters: Excel applies rules top-down and stops at the first match if **Stop If True** is
ticked. Enter red first, then amber, then green, or leave Stop If True off and make the ranges
non-overlapping.

Colour the **font**, not the fill, for the big numbers — a full-bleed red tile reads as an error
state rather than a measurement.

---

## 6. The six charts

All six are PivotCharts built from the **Data Model**, so the timeline in §10 controls them all.
For each: **Insert → PivotChart → Use this workbook's Data Model**.

### 6.1 Income vs Expenses vs Net Cash Flow — combo

- Axis: `dim_month[month]`
- Values: `Sum of income`, `Sum of expenses` (clustered column), `Sum of net_cash_flow` (line,
  secondary axis)
- Source: `vw_kpi_monthly`
- Right-click the net cash flow series → **Change Series Chart Type** → Line with Markers,
  secondary axis.

### 6.2 Spend by category — bar

- Axis: `vw_category_monthly[category_name]`
- Values: `Sum of amount`
- Sort descending by value; filter Top 10 if the bar list gets long.
- A bar chart beats the donut from ARCHITECTURE §6: 14 categories in a donut is unreadable, and
  category comparison is what this chart is for.

### 6.3 Budget vs Actual — clustered bar with variance colour

- Axis: `vw_budget_vs_actual[category_name]`
- Values: `Sum of budget`, `Sum of actual`
- Add `status` as a legend field, or colour the actual series by a conditional-formatted data
  bar in the adjacent pivot table.

### 6.4 Net worth — stacked column + line

- Axis: `dim_month[month]`
- Stacked values: `liquid_balance`, `investment_value`
- Line on secondary axis: `net_worth`
- Note the stack shows assets only; `net_worth` sits below the stack top because the card and
  loan are subtracted. Label the axis "Assets (stacked) vs Net Worth (line)" so the gap reads as
  liabilities rather than an error.

### 6.5 Portfolio — cost basis vs market value

- Axis: `dim_month[month]`
- Values: `Sum of cost_basis`, `Sum of market_value`, both as lines
- Source: `vw_portfolio_monthly`
- The widening gap is the unrealized gain.

### 6.6 Health score trend — line

- Axis: `dim_month[month]`
- Value: `Sum of health_score` (one row per month, so the sum is the value)
- Source: `vw_health_score`
- Add a constant line at 70 (the "good" threshold): add a helper column of 70s, or
  **Chart → Add Chart Element → Lines**.

---

## 7. Top-10 merchants table

PivotTable from the Data Model:

- Rows: `vw_txn_enriched[description]`
- Values: `Sum of amount`, `Count of txn_id`
- Filter: `category_type` = `expense`, `direction` = `debit`
- Value Filters → Top 10 by Sum of amount

Expected (unfiltered, all 18 months):

| Merchant | Category | Txns | Total |
|---|---|---|---|
| UPI/RENT/PG BHUBANESWAR | Rent | 18 | 1,17,000 |
| UPI/ZOMATO/FOOD | Food Delivery | 107 | 43,555 |
| UPI/SWIGGY/FOOD | Food Delivery | 108 | 40,285 |
| MYNTRA/ORDER | Shopping | 18 | 33,992 |
| AMAZON PAY/ORDER | Shopping | 11 | 26,435 |
| PEARSON VUE/CCNA EXAM | Education | 1 | 25,000 |
| UPI/BLINKIT/ORDER | Groceries | 36 | 22,283 |
| UPI/BIGBASKET/ORDER | Groceries | 37 | 22,104 |
| FLIPKART/ORDER | Shopping | 12 | 21,012 |
| GITHUB INC | Software & Tools | 18 | 15,120 |

Zomato and Swiggy together are ₹83,840 across 215 orders — worth calling out on the dashboard,
it is the single most actionable number in the whole workbook.

---

## 8. Budget sheet

PivotTable on `vw_budget_vs_actual`:

- Rows: `category_name`
- Columns: `dim_month[month]` (or filter to one month with the timeline)
- Values: `Sum of budget`, `Sum of actual`, `Max of variance_pct`

On the `variance_pct` column: **Conditional Formatting → Icon Sets → 3 Symbols**, then **Manage
Rules → Edit**, set *Type* to **Number** (not Percentile, which is the default and will give you
nonsense):

| Icon | Rule |
|---|---|
| Red | `> 10` |
| Amber | `0` to `10` |
| Green | `<= 0` |

Expect six categories over plan and seven at or under. August 2026 shows a `budget_variance_pct`
of **+84.38%** — that is the ₹25,000 CCNA exam, not a data problem. Worth a cell comment so you
are not re-diagnosing it in six months.

---

## 9. Investments sheet

### 9.1 Portfolio table

PivotTable on `vw_portfolio_monthly`, filtered to the latest month:

- Rows: `instrument_name`
- Values: `cost_basis`, `market_value`, `unrealized_gain`, `Max of return_pct`

### 9.2 XIRR

```excel
=XIRR(Data_Inv_Cashflows[cash_flow], Data_Inv_Cashflows[cash_flow_date])
```

Format as `0.00%`. **Expected: ≈ 13.05%.**

The view already signs the flows correctly — 37 buys total −₹86,156, and five terminal
valuations total +₹94,368.29. XIRR needs at least one of each sign or it returns `#NUM!`.

Sanity check, and a good interview answer: the absolute return is **+9.53%**
`(94,368 − 86,156) / 86,156`, but XIRR is **13.05%**. XIRR is higher because the money went in
gradually through SIPs — the average rupee was invested for well under 18 months, so the
annualized return on time-weighted capital exceeds the simple return on the total. If your XIRR
comes out near 9.5% you have accidentally handed it the aggregate rather than the dated flows.

### 9.3 Loan amortization

Paste `Data_Loan_Schedule` as a plain table — 24 rows, no pivot needed. Add a data bar on
`closing_balance` to show the payoff curve.

Row 24 closes at **−1.98**, not 0.00. That is the EMI being rounded to ₹3,457 from a true
₹3,456.60, accumulated over 24 months. Put it in a cell note; "why isn't it zero" is a question
worth having the answer to.

---

## 10. Slicers and the timeline

**Select any PivotChart → PivotChart Analyze → Insert Timeline → `dim_month[month]`.**

Then **right-click the timeline → Report Connections** and tick **every** PivotTable and
PivotChart in the workbook. Repeat for each slicer. This step is what the acceptance criterion
"the slicers filter all charts" is actually testing.

Add two slicers the same way:

- **Category** — from `vw_category_monthly[category_name]`
- **Account** — from `vw_txn_enriched[account_name]`

### What each slicer can and cannot filter

This trips people up, so be deliberate:

| Slicer | Filters | Does NOT filter |
|---|---|---|
| Timeline (`dim_month`) | Everything — all eight fact tables relate to it | — |
| Category | Spend chart, budget chart, MoM, top merchants | KPI tiles, net worth, health score |
| Account | Top merchants, balances | KPI tiles, net worth, health score, budget |

The KPI views are **monthly grain with no account or category dimension** — savings rate for
"only the SBI account" is not a defined quantity, because income and expenses are classified by
category type, not by where the money sat. This is a property of the data model, not a bug to
fix. Put the category and account slicers physically next to the charts they control, and leave
a gap between them and the KPI tiles, so the layout tells the truth about what filters what.

---

## 11. Data_Quality and About sheets

### Data_Quality

Paste `Data_Data_Quality` (1 row, 11 columns) and `Data_Uncategorized_Review` (4 rows) directly.

Add a text box with the reconciliation, because this is the most interview-relevant sheet in the
workbook:

> 1,152 raw rows = 1,116 clean + 11 rejected + 25 duplicates.
> 6 rejected for unparseable dates, 5 for a missing amount.
> Categorization coverage 97.04%; the 33 uncategorized rows come from 4 merchants no rule
> matches and are counted as expenses.
> Two of the rejected rows — SPOTIFY INDIA ₹119 and FLIPKART/ORDER ₹2,947 — are credit-card
> charges that were billed and paid in reality but never reached the clean table. That is
> exactly why the card closes September 2026 owing ₹5,091 rather than ₹8,157.

### About

- The KPI table from `ARCHITECTURE.md` §5, including the health-score weights
  (savings 25, DTI 20, buffer 25, investing 15, budget 15).
- Refresh steps: *Data → Refresh All*; if credentials are requested, Data → Get Data → Data
  Source Settings → Edit Permissions.
- Data source note: "Synthetic 18-month dataset (Apr 2025 – Sep 2026). See
  `docs/DATA_INVENTORY.md`. Not real financial data."

That last line matters. A finance dashboard with no provenance note invites the assumption these
are your real balances.

---

## 12. Colour palette

Clean neutral plus one accent (DATA_INVENTORY C6).

| Role | Hex |
|---|---|
| Background | `#FFFFFF` |
| Card / tile fill | `#F7F8FA` |
| Primary text | `#1F2328` |
| Secondary text | `#6B7280` |
| Gridlines, borders | `#E5E7EB` |
| **Accent** (primary series, headers) | `#2563EB` |
| Accent secondary (second series) | `#93C5FD` |
| Good | `#15803D` |
| Warning | `#B45309` |
| Bad | `#B91C1C` |

Rules that keep it from looking like a template: one accent only, categorical colour **never**
used decoratively (colour must encode something), gridlines light grey not black, and no chart
borders or drop shadows. Font: Aptos or Calibri throughout, 20–24pt for tile values, 9pt for
tile labels.

---

## 13. Verification

Build is complete when all of these match. Values are from the current green build
(`docs/METRICS.md`, measured 2026-10-07).

### Tiles — September 2026, with delta vs August

| Tile | Value | Delta |
|---|---|---|
| Savings Rate | **46.56%** | +40.68 pp |
| Debt-to-Income | **5.49%** | −0.80 pp |
| Emergency Months | **5.72 mo** | +0.13 |
| Net Worth | **₹2,02,249.33** | +₹37,690.51 |
| Investment XIRR | **≈13.05%** | — |
| Health Score | **82.82** | +15.19 |

### Against `vw_kpi_summary`

| Field | Value |
|---|---|
| `ttm_savings_rate_pct` | 31.18 |
| `ttm_dti_pct` | 7.36 |
| `ttm_investment_rate_pct` | 12.11 |
| `alltime_savings_rate_pct` | 25.50 |
| `latest_investment_cost_basis` | 86,156.00 |
| `latest_investment_market_value` | 94,368.29 |
| `latest_investment_return_pct` | 9.53 |
| `latest_card_outstanding` | 5,091.00 |
| `latest_loan_payoff_pct` | 63.53 |
| `latest_subscription_burn` | 1,158.00 |
| `latest_recurring_burn` | 8,007.00 |

### Structural

- [ ] Data → **Refresh All** completes with no prompts and no errors
- [ ] Every `Data_*` table shows the row count from §1
- [ ] Timeline set to Sep 2026 → all six charts move
- [ ] Category slicer → spend/budget charts move, KPI tiles do **not** (correct, see §10)
- [ ] Health score chart ranges 39.81 to 95.98
- [ ] Net worth chart dips negative Jun–Oct 2025 (the laptop loan — see §14)
- [ ] XIRR shows ~13.05%, not ~9.5%
- [ ] Loan table row 24 closes at −1.98
- [ ] Budget sheet: 6 categories over, 7 at or under

---

## 14. Troubleshooting

**"From MySQL Database" is missing.** Expected — do not chase it. Even with Connector/NET
installed, in the GAC and registered in `machine.config`, the entry often never appears. Use the
ODBC route in §1 instead.

**"From ODBC" lists no MySQL driver.** Connector/ODBC is not installed, or you installed the
32-bit build against 64-bit Excel. Check with `Get-OdbcDriver` — you want
`MySQL ODBC 26.7 Unicode Driver`, Platform `64-bit`.

**Percentages show as 4656%.** You applied Excel's `%` format to a column that is already
multiplied by 100. Use the custom format `0.0"%"`. XIRR is the one exception — it returns a true
fraction, so `%` is right there.

**Slicer does nothing.** Two causes, in order of likelihood: the relationship to `dim_month` was
never created (§2.2), or **Report Connections** was not ticked for that PivotTable (§10).

**Timeline is greyed out / won't insert.** The PivotTable is not using the Data Model, or
`dim_month` is not marked as a Date Table (§2.1).

**XIRR returns `#NUM!`.** It needs at least one positive and one negative flow, and dates must
be real dates not text. Check `cash_flow_date` is typed Date in Power Query.

**Refresh asks for credentials every time.** Data → Get Data → Data Source Settings → select the
MySQL source → Edit Permissions → Credentials → Edit → re-enter and tick to save.

**A number disagrees with SQL.** Trust the SQL. Re-run `sql/00_run_all.sql`, confirm 99/99, then
Refresh All. If it still differs, the PivotTable is almost certainly aggregating a
pre-aggregated column — `share_of_month_pct` and every `*_pct` column are already computed per
row and must be displayed with **Max** or **Average**, never **Sum**.

**Net worth looks wrong — it is negative in 2025.** It is correct. The ₹72,000 laptop loan is a
liability from June 2025, but the laptop it financed is not an asset in this data model, so net
worth drops by the full principal with nothing on the other side. It bottoms at −₹17,213.50 in
September 2025 and recovers to +₹2,02,249.33 by September 2026. Annotate the dip on the chart;
do not "fix" it.
