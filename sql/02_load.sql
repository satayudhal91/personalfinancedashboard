-- ============================================================
-- 02_load.sql — load raw CSVs into staging tables, untouched.
-- Run FROM THE REPO ROOT so the relative paths resolve:
--   mysql --login-path=finance --local-infile=1 finance_db < sql/02_load.sql
-- One-time server setting (as root):  SET GLOBAL local_infile = 1;
-- ============================================================
USE finance_db;

TRUNCATE TABLE raw_transactions;
TRUNCATE TABLE raw_valuations;

LOAD DATA LOCAL INFILE 'data/raw/raw_transactions.csv'
INTO TABLE raw_transactions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(txn_date, description, debit, credit, account_name, ref_no);

LOAD DATA LOCAL INFILE 'data/raw/raw_valuations.csv'
INTO TABLE raw_valuations
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(instrument_name, valuation_date, units_held, nav);

-- ---------- Load profile (expected values for the shipped dataset in comments) ----------
SELECT COUNT(*) AS raw_rows FROM raw_transactions;                              -- 1152
SELECT COUNT(*) AS valuation_rows FROM raw_valuations;                          -- 70
SELECT COUNT(*) - COUNT(DISTINCT account_name, ref_no) AS duplicate_rows
FROM raw_transactions;                                                          -- 25
WITH fmt AS (
  SELECT txn_date,
         CASE WHEN txn_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN '%d-%m-%Y'
              WHEN txn_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN '%d/%m/%Y'
              WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN '%Y-%m-%d' END AS f
  FROM raw_transactions
)
SELECT COUNT(*) AS bad_date_rows FROM fmt
WHERE f IS NULL
   OR STR_TO_DATE(txn_date, f) IS NULL
   OR DATE_FORMAT(STR_TO_DATE(txn_date, f), f) <> txn_date;                    -- 6 (blank, 'N/A', '31-02-2026')
SELECT COUNT(*) AS missing_amount_rows FROM raw_transactions
WHERE NULLIF(debit,'') IS NULL AND NULLIF(credit,'') IS NULL;                   -- 5
SELECT COUNT(*) AS stray_cr FROM raw_transactions WHERE ref_no LIKE '%\r';      -- must be 0
