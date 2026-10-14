# Data & Inputs Inventory

Tools used in this project: **SQL (MySQL 8) and Excel only.**

Legend:
- ✅ **In this kit**: already provided
- ⬇️ **Download / install**: get it yourself
- 🧑 **You decide / provide**: only you can supply it
- 🤖 **Claude Code generates**: produced during the build

## A. Data and code already in this kit ✅

| # | Item | Path | Contents | Used in |
|---|---|---|---|---|
| A1 | Raw transactions | `data/raw/raw_transactions.csv` | 1,152 rows, Apr 2025–Sep 2026, 3 accounts. Columns: txn_date, description, debit, credit, account_name, ref_no. Deliberately messy | Phase 1–2 |
| A2 | Raw valuations | `data/raw/raw_valuations.csv` | 70 rows: month-end units + NAV for 5 holdings | Phase 2, 5 |
| A4 | Schema + seed data | `sql/01_schema.sql` | 11 tables (Phase 2 adds `transactions_rejected`). 3 accounts, 23 categories, 48 categorization rules, 5 investments, 1 loan | Phase 1 |
| A5 | Load script | `sql/02_load.sql` | `LOAD DATA LOCAL INFILE` + load profile with expected counts | Phase 1 |
| A6 | Project rules for Claude Code | `CLAUDE.md` | Stack limits, conventions, run commands | every session |
| A7 | Architecture | `docs/ARCHITECTURE.md` | Layers, schema, 17 views, 15 KPI formulas, Excel layout | Phase 2–7 |
| A8 | Build plan | `docs/BUILD_PLAN.md` | 10 phases with acceptance numbers | every session |
| A9 | Kickoff prompts | `docs/KICKOFF_PROMPT.md` | Copy-paste prompts per phase | every session |
| A10 | Metrics log | `docs/METRICS.md` | Empty template. Claude Code fills it with measured numbers | Phase 1–8 |

**Reference values baked into the seed data** (all editable):

| Item | Value |
|---|---|
| Opening balances | SBI Savings ₹25,000 · HDFC Credit Card ₹0 · Paytm Wallet ₹500 |
| Loan | Bajaj Finserv laptop loan ₹72,000 @ 14% p.a., 24 months, from 2025-06-01, EMI ₹3,457 |
| Holdings | UTI Nifty 50 Index Fund, Parag Parikh Flexi Cap (Groww) · TCS, ITC (Zerodha) · SBI 1-yr FD |
| Prices | Simulated monthly NAV/price paths, not real market prices. See E2 to use real NAVs |

## B. Software to download and install ⬇️ (Windows)

| # | What | Where | Why |
|---|---|---|---|
| B1 | MySQL Installer 8.0 (Community): **Server, Workbench, Shell, Connector/NET** | dev.mysql.com/downloads/installer | Database. Workbench for ERD + browsing. Connector/NET is required by Excel's MySQL connector |
| B2 | Microsoft Excel desktop (Microsoft 365, Windows) | you likely have it via the university/Office | Power Query, PivotTables, slicers, XIRR. Excel for Mac has no MySQL connector |
| B4 | (optional) Git + GitHub account | git-scm.com | Only to publish the finished project; not part of the build |
| B5 | Claude Code | per Anthropic's install docs | The builder |

No datasets need downloading. Everything required is in section A.

## C. Things only you provide 🧑

| # | Input | Needed by | Default if you don't decide |
|---|---|---|---|
| C1 | MySQL app user + password, stored with `mysql_config_editor` (login path `finance`) | Phase 0 | none, required. **Never paste the password into Claude Code** |
| C2 | Repo location on disk (e.g. `C:\Users\<you>\Projects\finance-dashboard`) | Phase 0 | — |
| C3 | Monthly budget per category | Phase 4 | table in BUILD_PLAN.md Phase 4 |
| C4 | Savings goals | Phase 4 | Emergency Fund ₹1.5L by Mar 2027, Laptop Fund ₹60k by Jun 2027 |
| C5 | KPI "healthy bands" + health-score weights | Phase 5, 7 | ARCHITECTURE.md §5 |
| C6 | Dashboard look (colours, font) | Phase 7 | Clean neutral + one accent colour |
| C7 | The Excel workbook itself (built by hand from the guide) | Phase 7 | — |
| C8 | Dashboard screenshots + ERD export | Phase 8 | — |
| C9 | (optional) Your own anonymized statement exports in `data/private/` | Phase 9 | synthetic data only |

## D. What to give Claude Code (Opus) to start

| # | Give it | How |
|---|---|---|
| D1 | This whole folder as the working directory | `cd` into the repo, then start `claude` |
| D2 | `CLAUDE.md` | Loaded automatically from the repo root |
| D3 | The phase you're on | Paste the matching prompt from `docs/KICKOFF_PROMPT.md` |
| D4 | Environment facts | Already in CLAUDE.md. Correct them if your MySQL/Excel versions differ |
| D5 | Output of the previous phase's tests | Claude Code runs them itself. If something failed on your side, paste the error |
| D6 | Your decisions from section C | Edit the tables in BUILD_PLAN.md before Phase 4 |

**Never give it:** your MySQL password, real bank statements with account numbers, or your real balances in committed files.

## E. Optional real-world data (makes the project stronger)

| # | Source | What | Where it goes |
|---|---|---|---|
| E1 | Your bank (SBI YONO / net banking → statement → Excel/CSV), card portal, UPI app history | 6–12 months of your own transactions, anonymized | `data/private/` (gitignored) → `sql/02b_load_private.sql` |
| E2 | AMFI NAV history (amfiindia.com → NAV history) for the two funds | Real monthly NAVs to replace simulated ones | `data/raw/real_nav.csv` → update `raw_valuations` |
| E3 | NSE/BSE historical closes for TCS and ITC | Real month-end prices | same as E2 |

## F. Generated during the build 🤖

| File | Phase |
|---|---|
| `sql/03_clean.sql` (procedures, rejected table) | 2 |
| `sql/04_categorize.sql` | 3 |
| `sql/05_seed_planning.sql` | 4 |
| `sql/06_views.sql` (17 views) | 5 |
| `sql/90_tests.sql` | 1 → 6 |
| `sql/00_run_all.sql` (rebuild everything in one command, SQL `SOURCE`) | 6 |
| `docs/EXCEL_GUIDE.md` | 7 |
| `excel/finance_dashboard.xlsx` (built by you) | 7 |
| `README.md`, `docs/erd.png`, `docs/img/*.png`, final `docs/METRICS.md` | 8 |
