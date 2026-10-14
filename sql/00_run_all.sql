-- ============================================================
-- 00_run_all.sql — rebuild finance_db from scratch, then assert.
--
-- Run FROM THE REPO ROOT. Both SOURCE and LOAD DATA LOCAL INFILE
-- resolve their paths against the client's working directory:
--
--   mysql --login-path=finance --local-infile=1 < sql/00_run_all.sql
--
-- No database is named on the command line, on purpose:
-- 01_schema.sql drops and recreates finance_db, so passing finance_db
-- as the default schema fails with "Unknown database" on a fresh
-- machine, before a single statement runs.
--
-- SOURCE lines take no trailing semicolon -- it would be read as part
-- of the filename.
-- ============================================================

SELECT '== 01_schema : drop + create finance_db, seed reference data ==' AS step;
SOURCE sql/01_schema.sql

SELECT '== 02_load   : raw CSVs -> staging tables ==' AS step;
SOURCE sql/02_load.sql

SELECT '== 03_clean  : staging -> core, dedupe + reject ==' AS step;
SOURCE sql/03_clean.sql

SELECT '== 04_categ  : keyword rules -> category_id ==' AS step;
SOURCE sql/04_categorize.sql

SELECT '== 05_plan   : budgets (recursive CTE) + goals ==' AS step;
SOURCE sql/05_seed_planning.sql

SELECT '== 06_views  : 17 analytics views ==' AS step;
SOURCE sql/06_views.sql


SELECT '== 90_tests  : assertions, every row must read PASS ==' AS step;
SOURCE sql/90_tests.sql
