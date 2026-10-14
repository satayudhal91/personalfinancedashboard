# Prompts for Claude Code

Start each session from the repo root (`claude`, with Opus selected). Paste one prompt per phase.
CLAUDE.md already tells Claude Code the project is SQL + Excel only.
Review the diff and test output before committing, then commit after every phase
(`git commit -m "phase N: ..."`).

---

## Session 1 — orientation + Phase 1

```
Read CLAUDE.md, docs/ARCHITECTURE.md, docs/BUILD_PLAN.md and docs/DATA_INVENTORY.md.
Then:
1. Summarize the architecture back to me in 5 bullets and list anything in the docs that is
   contradictory or that you'd change, with reasons. Don't change files yet.
2. Phase 1: run sql/01_schema.sql then sql/02_load.sql with the commands in CLAUDE.md.
   Compare the load profile to the expected values in the comments. If anything differs,
   find out why before continuing.
3. Create sql/90_tests.sql with the Phase 1 checks and run it.
4. Create docs/METRICS.md and record the Phase 1 numbers with the queries that produced them.
Stop after Phase 1 and show me the results.
```

## Phase 2 — cleaning

```
Do Phase 2 from docs/BUILD_PLAN.md exactly. Write sql/03_clean.sql (stored procedures,
transactions_rejected table), run it twice to prove it's idempotent, extend sql/90_tests.sql
with the reconciliation checks, run all tests, and update docs/METRICS.md.
Explain the dedupe and date-validation logic to me in plain words — I need to be able to
explain it in an interview.
```

## Phase 3 — categorization

```
Do Phase 3. Write sql/04_categorize.sql, run it, show coverage % and the
vw_uncategorized_review output. Extend tests, update METRICS.md.
Then propose 2–3 new rules for the unmatched merchants but don't add them — I'll decide.
```

## Phase 4 — planning data

```
Do Phase 4 using the budget and goal values currently in docs/BUILD_PLAN.md.
Generate budget rows with a recursive CTE over months. Extend tests, update METRICS.md.
```

## Phase 5 — analytics views

```
Do Phase 5. Implement every view in docs/ARCHITECTURE.md §4 in sql/06_views.sql, following the
KPI formulas in §5 exactly. Build them in the order given in BUILD_PLAN.md and test each before
moving on. Show me vw_kpi_monthly and vw_kpi_summary when done, plus the acceptance checks.
Comment each view with the technique it demonstrates (window function, recursive CTE, etc.).
```

## Phase 6 — tests + one-command rebuild

```
Do Phase 6. Finish sql/90_tests.sql and write sql/00_run_all.sql — a SQL-only master script
that uses SOURCE to run 01 → 06 then the tests, and ends with a single summary row
(total checks, passed, failed). Run it from scratch. SQL only — no shell scripts.
```

## Phase 7 — Excel guide

```
Do the 🤖 part of Phase 7: write docs/EXCEL_GUIDE.md, a click-by-click guide for me to build
excel/finance_dashboard.xlsx in Excel (Microsoft 365, Windows) per ARCHITECTURE.md §6:
Power Query connection to MySQL, which views to load, each PivotTable/chart with exact
settings, conditional-format rules from the healthy bands, the XIRR formula, slicers/timeline
connected to all pivots, and a checklist to verify tile values against vw_kpi_summary.
Do not build the workbook yourself.
```

## Phase 8 — ship

```
Do Phase 8. Write README.md (pitch, architecture diagram, setup with sql/00_run_all.sql, KPI table,
top 5 findings from the data with the queries behind them, screenshots placeholders).
Finalize docs/METRICS.md. Then draft 4 resume bullets using ONLY numbers in METRICS.md and
tell me which metric each number comes from.
```

---

## If something goes wrong

- **`ERROR 3948 / 2068 loading local data is disabled`:** run `SET GLOBAL local_infile = 1;` as root, and use `--local-infile=1` on the client.
- **`Access denied`:** check `mysql_config_editor print --all`, and confirm the grants from Phase 0.
- **Excel can't find the MySQL connector:** install Connector/NET (B1), restart Excel, and retry Data → Get Data → From Database → From MySQL Database.
