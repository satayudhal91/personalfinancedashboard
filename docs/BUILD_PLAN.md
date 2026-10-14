# Build Plan

Each phase has the same fields:
- **Who:** 🧑 Satayu Dhal, or 🤖 Claude Code
- **Files** it produces
- **Done when:** acceptance criteria

Claude Code works one phase per session or prompt. At the end of each phase it runs `sql/90_tests.sql` and appends results to `docs/METRICS.md`.

---

## Phase 0 — Environment setup 🧑 (≈1 hr)
1. Install MySQL 8.0 Community (MySQL Installer for Windows):
   - Choose Server, Workbench, Shell, and **Connector/NET** (Excel needs it).
   - Set a root password.
   - Add `C:\Program Files\MySQL\MySQL Server 8.0\bin` to PATH.
2. Create an app user and a login path, so Claude Code never sees a password:
   ```sql
   -- in Workbench as root
   CREATE USER 'finance_app'@'localhost' IDENTIFIED BY '<choose-one>';
   GRANT ALL PRIVILEGES ON finance_db.* TO 'finance_app'@'localhost';
   GRANT CREATE ON *.* TO 'finance_app'@'localhost';   -- lets 01_schema create the db
   SET GLOBAL local_infile = 1;
   ```
   ```text
   mysql_config_editor set --login-path=finance --host=localhost --user=finance_app --password
   mysql --login-path=finance -e "SELECT VERSION();"
   ```
3. Confirm Excel desktop (Microsoft 365, Windows) is installed. (Git/GitHub is optional, only for publishing the repo.)
4. Unzip this kit to e.g. `C:\Users\<you>\Projects\finance-dashboard`, then run `git init` and make the first commit.
5. Create a **private** GitHub repo `finance-dashboard` under @dexisworking. Make it public only once it's finished.

**Done when:** `mysql --login-path=finance -e "SELECT 1"` works from the repo folder, and in Excel
Data → Get Data → From Database → **From MySQL Database** opens the server/database dialog
without a "connector not installed" error.

## Phase 1 — Foundation (schema + load) 🤖
- **Files:** `sql/01_schema.sql` (provided), `sql/02_load.sql` (provided).
- **Tasks:** run both. Fix anything that fails on Satayu Dhal's MySQL version.
- **Done when** the load profile prints 1152 / 70 / 25 / 6 / 5 / 0 (see the comments in 02_load.sql).

## Phase 2 — Cleaning 🤖
- **Files:** `sql/03_clean.sql`.
- **Tasks:**
  1. Create `transactions_rejected (raw_id, reason, rejected_at)`.
  2. Write stored procedure `sp_clean_transactions()`:
     - TRUNCATE core tables.
     - Parse dates (REGEXP picks the format, STR_TO_DATE parses, round-trip validates).
     - Derive `amount` and `direction` from debit or credit.
     - Map `account_name` → `account_id`.
     - Normalize descriptions with `UPPER(TRIM())` and collapse double spaces.
     - Dedupe with `ROW_NUMBER() OVER (PARTITION BY account_name, ref_no ORDER BY <valid first>, raw_id)`.
     - Insert valid rows into `transactions`, and invalid rows into `transactions_rejected` with a reason.
  3. Write `sp_clean_valuations()`: `raw_valuations` → `investment_valuations` (join on instrument_name).
- **Done when:** clean = 1116, rejected = 11, duplicates = 25, and raw 1152 = clean + rejected + duplicates. investment_valuations has 70 rows. Re-running the procedure gives identical counts.

## Phase 3 — Categorization 🤖
- **Files:** `sql/04_categorize.sql`.
- **Tasks:** write `sp_categorize()`:
  - Join `transactions` to `categorization_rules` on `description LIKE CONCAT('%', keyword, '%')`.
  - Pick the lowest priority per txn with `ROW_NUMBER()`.
  - UPDATE `category_id`.
  - Create `vw_uncategorized_review`.
- **Done when:** coverage is about 97% (roughly 33 uncategorized, all from the 4 unmatched merchants). No transfer is mis-categorized as expense: CC PAYMENT total equals PAYMENT RECEIVED total. Every SIP, ZERODHA and FD row lands in an investment category, and every EMI row in Loan EMI.
- **Optional:** Satayu Dhal adds 2–3 rules for the unmatched merchants and records coverage before and after. That's a good resume line.

## Phase 4 — Planning data 🤖 (values chosen by 🧑)
- **Files:** `sql/05_seed_planning.sql`.
- **Monthly budgets** for all 18 months (₹). Satayu Dhal may edit these:

  | Category | Budget | Category | Budget |
  |---|---|---|---|
  | Rent | 6,500 | Shopping | 3,000 |
  | Groceries | 4,000 | Subscriptions | 400 |
  | Utilities & Recharge | 1,300 | Entertainment | 300 |
  | Transport | 1,800 | Software & Tools | 1,500 |
  | Food Delivery | 4,000 | Education | 1,000 |
  | Dining Out | 1,200 | Health | 200 |
  | Snacks & Tea | 800 | | |

  Generate the 18 × 13 rows with a recursive CTE over months, not hand-typed INSERTs.
- **Savings goals:** Emergency Fund ₹1,50,000 by 2027-03-31, New Laptop Upgrade Fund ₹60,000 by 2027-06-30.
- **Done when:** budgets has 234 rows and the unique (category, month) key holds.

## Phase 5 — Analytics views 🤖
- **Files:** `sql/06_views.sql`. Every view is listed in ARCHITECTURE.md §4, and the KPIs follow §5 exactly.
- **Order:** `vw_txn_enriched` → cashflow/category → balances → loan schedule (recursive CTE) → portfolio → net worth → KPI monthly/summary → health score → data quality.
- **Done when:**
  - Each view returns rows with no NULL numerics, and `vw_kpi_monthly` has 18 rows.
  - `vw_loan_schedule` has 24 rows, and the closing balance of row 24 is within ₹5 of 0.
  - Month-end SBI and wallet balances are never negative.
  - Card outstanding at the end is ₹5,091. That's September 2026 card spend (₹8,157) minus two rejected card rows (₹119 + ₹2,947) that were billed and paid but never reached the clean table. Being able to explain this is a strong interview story about data quality.
  - Net worth is computed for all 18 months.
- Also add `EXPLAIN` notes for the 2 heaviest views to METRICS.md, and an index if one helps.

## Phase 6 — Test suite + one-command rebuild 🤖 (tests grow every phase)
- **Files:** `sql/90_tests.sql`, a list of `SELECT '<name>' AS test, IF(<condition>,'PASS','FAIL') AS result` checks.
- **Covers:** reconciliation counts, no duplicates in core, coverage ≥ 95%, transfer pairs balance, non-negative liquid balances, loan schedule ends at about 0, 18 KPI rows, budget rows = 234, and every view selectable.
- **Also:** `sql/00_run_all.sql`, a master script that runs 01 → 06 then 90 via `SOURCE` commands.
  Run it with: `mysql --login-path=finance --local-infile=1 < sql/00_run_all.sql`
- **Done when:** all PASS on a fresh run of `00_run_all.sql`.

## Phase 7 — Excel dashboard 🧑 (with a 🤖 build guide)
Do this yourself in Excel. "Built an Excel dashboard" is the claim interviewers test, so you need to know every click.
- 🤖 writes `docs/EXCEL_GUIDE.md`: a click-by-click guide for the ARCHITECTURE.md §6 layout. It covers:
  - which views to load
  - PivotTable and chart settings
  - conditional-format rules from the healthy bands
  - the XIRR formula over `vw_investment_cashflows`
  - slicer and timeline wiring, and a colour palette
- 🧑 builds `excel/finance_dashboard.xlsx`. Connect with Data → Get Data → From Database → From MySQL Database (needs Connector/NET from Phase 0).
- **Done when:** Refresh All updates every sheet. The slicers filter all charts. Tile values match `vw_kpi_summary`. You can explain each KPI.

## Phase 8 — Ship 🤖 + 🧑
- 🤖:
  - `README.md` with the project pitch, architecture diagram, setup steps (`sql/00_run_all.sql` rebuilds 01 → 06 + tests), KPI table, and findings.
  - ER diagram: Satayu Dhal exports it from Workbench (Database → Reverse Engineer) to `docs/erd.png`.
  - `docs/METRICS.md` finalized.
- 🧑: screenshots of the dashboard into `docs/img/`, make the repo public, and pin it on GitHub.
- **Resume:** fill the bullet templates using **only** values from `docs/METRICS.md`.

## Phase 9 — Real data (optional, stronger story) 🧑 + 🤖
- Export 6–12 months of your own SBI, card and UPI statements (CSV or XLS) into `data/private/` (gitignored).
- 🤖 writes `sql/02b_load_private.sql` mapping your bank's columns into `raw_transactions`, then you re-run 03 → 06.
- Never commit real data or screenshots that show real balances.
