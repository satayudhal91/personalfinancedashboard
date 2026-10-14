# Personal Finance & Financial Health Analytics Dashboard

Excel + MySQL analytics project. MySQL does all storage, cleaning, categorization and KPI
logic; Excel (Power Query → PivotTables/charts/slicers) is the presentation layer.
Author: Satayu Dhal (B.Tech CSE). This is a portfolio project — every number it reports must be
reproducible from the SQL in this repo.

## Read first
- `docs/ARCHITECTURE.md` — layers, schema, views, KPI formulas (source of truth for definitions)
- `docs/BUILD_PLAN.md` — phases, tasks, acceptance criteria. Work one phase at a time.
- `docs/DATA_INVENTORY.md` — what data exists and where it came from

## Environment
- Windows 11, MySQL 8.0 Community Server (CLI + Workbench), Excel (Microsoft 365, desktop).
- Run SQL with the CLI from the repo root:
  `mysql --login-path=finance finance_db < sql/<file>.sql`
  (`--local-infile=1` for 02_load.sql). Credentials live in the login path — never ask for,
  print, or commit a password.
- Database name: `finance_db`. Scripts must be re-runnable (idempotent).

## Rules
- **The only tools in this project are SQL (MySQL) and Excel.** Do not write or suggest
  Python, PowerShell, batch files, JavaScript, VBA or any other language. Automation is done
  with SQL scripts (`SOURCE`, stored procedures) and Excel features (Power Query, PivotTables,
  formulas). If something seems to need another tool, say so and propose a SQL/Excel way.
- Never edit files in `data/raw/`; they are the fixed source dataset.
- SQL files are numbered and run in order: `00_run_all` (runs everything) · `01_schema` → `02_load` → `03_clean` → `04_categorize`
  → `05_seed_planning` → `06_views` → `90_tests`. A new phase adds a new numbered file.
- Descriptions arrive in mixed case with stray whitespace: always match on `UPPER(TRIM(description))`.
- Dates arrive in 3 formats (`dd-mm-yyyy`, `dd/mm/yyyy`, `yyyy-mm-dd`) plus junk. Pick the
  format with REGEXP, parse with STR_TO_DATE, and reject anything that does not round-trip
  (e.g. `31-02-2026`).
- Deduplicate on `(account_name, ref_no)`; keep the valid copy.
- Transfers (`Card Payment`, `Wallet Top-up`) are excluded from income/expense KPIs.
  Uncategorized debits count as expenses (bucket "Uncategorized").
- Every phase ends by running `sql/90_tests.sql`; all checks must return PASS.
- After each phase, append the measured numbers (row counts, coverage %, KPI values) to
  `docs/METRICS.md` with the query that produced them. Resume bullets are written only from
  that file.
- Keep views Excel-friendly: one row per month (or per month × category), `month` as a DATE,
  no NULL numeric columns (use COALESCE), snake_case column names.
