-- ============================================================
-- 03_clean.sql — staging -> core. Re-runnable.
--   mysql --login-path=finance finance_db < sql/03_clean.sql
--
-- Produces, for the shipped dataset:
--   transactions           1116
--   transactions_rejected    11
--   dropped as duplicates    25
--   1152 raw = 1116 + 11 + 25
--
-- Uses stored PROCEDURES only, never a stored FUNCTION: with binary
-- logging enabled MySQL refuses CREATE FUNCTION unless the account
-- holds SUPER/SET_USER_ID or the server sets
-- log_bin_trust_function_creators. Keeping to procedures lets this
-- repo rebuild on any MySQL 8 with an ordinary account and no
-- server-side configuration.
-- ============================================================
USE finance_db;

-- ---------- rejected rows ----------
-- One row per raw row that cannot become a transaction, with the
-- reason. Duplicates are NOT recorded here: a duplicate is not a
-- defective row, it is a second copy of one we already kept, and the
-- acceptance criteria count the two separately. The duplicate count
-- stays derivable as raw - clean - rejected.
CREATE TABLE IF NOT EXISTS transactions_rejected (
  raw_id      INT PRIMARY KEY,
  reason      VARCHAR(40) NOT NULL,
  rejected_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_reason (reason)
);

DROP PROCEDURE IF EXISTS sp_clean_transactions;
DROP PROCEDURE IF EXISTS sp_clean_valuations;

DELIMITER $$

-- ------------------------------------------------------------
-- sp_clean_transactions — raw_transactions -> transactions
--                                           + transactions_rejected
--
-- Date handling deliberately avoids STR_TO_DATE. It returns NULL and
-- warns inside a SELECT, but under strict sql_mode the identical call
-- raises ERROR 1411 inside INSERT/UPDATE -- so a validity check built
-- on it aborts on the very row it exists to catch (31-02-2026 matches
-- the dd-mm-yyyy shape but is not a real date).
--
-- Instead the parse runs as four separate statements, so evaluation
-- order is guaranteed and no expression ever sees input it has not
-- already been proven safe for:
--   1. split y/m/d out by REGEXP      (cannot throw: pure SUBSTRING)
--   2. month/year range check, then take the month length from
--      LAST_DAY() of the 1st of that month (valid by construction)
--   3. build the DATE only for rows whose day fits that month
--   4. assign a rejection reason to whatever is left
--
-- Idempotent: truncates both targets first, so repeated runs give
-- identical counts and identical txn_ids.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_clean_transactions()
BEGIN
  TRUNCATE TABLE transactions;
  TRUNCATE TABLE transactions_rejected;

  DROP TEMPORARY TABLE IF EXISTS tmp_staged;
  CREATE TEMPORARY TABLE tmp_staged (
    raw_id      INT PRIMARY KEY,
    account_id  INT           NULL,
    yy          INT           NULL,
    mm          INT           NULL,
    dd          INT           NULL,
    dim         INT           NULL,
    txn_date    DATE          NULL,
    description VARCHAR(255)  NULL,
    amount      DECIMAL(12,2) NULL,
    direction   ENUM('debit','credit') NULL,
    ref_no      VARCHAR(40)   NULL,
    reason      VARCHAR(40)   NULL,
    is_valid    TINYINT       NOT NULL DEFAULT 0,
    INDEX idx_dedupe (account_id, ref_no)
  );

  -- Step 1. Split the date into integers and derive every other typed
  -- field. Each cast is guarded by a REGEXP, so a malformed value
  -- lands as NULL instead of aborting the statement. Separators are
  -- matched strictly: a mixed form like 12-05/2026 is rejected rather
  -- than silently accepted.
  INSERT INTO tmp_staged
        (raw_id, account_id, yy, mm, dd, description, amount, direction, ref_no)
  SELECT r.raw_id,
         a.account_id,
         CASE WHEN TRIM(r.txn_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),1,4) AS UNSIGNED)
              WHEN TRIM(r.txn_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
                OR TRIM(r.txn_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),7,4) AS UNSIGNED)
         END,
         CASE WHEN TRIM(r.txn_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),6,2) AS UNSIGNED)
              WHEN TRIM(r.txn_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
                OR TRIM(r.txn_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),4,2) AS UNSIGNED)
         END,
         CASE WHEN TRIM(r.txn_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),9,2) AS UNSIGNED)
              WHEN TRIM(r.txn_date) REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
                OR TRIM(r.txn_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
                   THEN CAST(SUBSTRING(TRIM(r.txn_date),1,2) AS UNSIGNED)
         END,
         -- UPPER + TRIM + collapse internal whitespace runs to one
         -- space. Every downstream match is on this normalized form.
         NULLIF(REGEXP_REPLACE(UPPER(TRIM(r.description)), '[[:space:]]+', ' '), ''),
         CASE WHEN TRIM(COALESCE(r.debit ,'')) REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(TRIM(r.debit)  AS DECIMAL(12,2))
              WHEN TRIM(COALESCE(r.credit,'')) REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(TRIM(r.credit) AS DECIMAL(12,2))
         END,
         CASE WHEN NULLIF(TRIM(r.debit ),'') IS NOT NULL THEN 'debit'
              WHEN NULLIF(TRIM(r.credit),'') IS NOT NULL THEN 'credit'
         END,
         NULLIF(TRIM(r.ref_no),'')
  FROM raw_transactions r
  LEFT JOIN accounts a ON a.account_name = TRIM(r.account_name);

  -- Step 2. Month length, only for rows whose month/year are sane.
  UPDATE tmp_staged
     SET dim = DAY(LAST_DAY(DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-01'))))
   WHERE mm BETWEEN 1 AND 12
     AND yy BETWEEN 1900 AND 2999;

  -- Step 3. Build the date only where the day fits the month.
  UPDATE tmp_staged
     SET txn_date = DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-',LPAD(dd,2,'0')))
   WHERE dim IS NOT NULL
     AND dd BETWEEN 1 AND dim;

  -- Step 4. First failing check wins, so every rejected row carries
  -- exactly one reason and the reason counts sum to the total.
  UPDATE tmp_staged
     SET reason = CASE
           WHEN txn_date    IS NULL THEN 'bad_date'
           WHEN amount      IS NULL
             OR direction   IS NULL THEN 'missing_amount'
           WHEN amount      <= 0    THEN 'non_positive_amount'
           WHEN account_id  IS NULL THEN 'unknown_account'
           WHEN description IS NULL THEN 'blank_description'
           WHEN ref_no      IS NULL THEN 'missing_ref_no'
         END;
  UPDATE tmp_staged SET is_valid = (reason IS NULL);

  -- Dedupe on (account, ref_no) per CLAUDE.md, keeping the valid copy:
  -- is_valid DESC puts a good row ahead of a defective twin, raw_id
  -- breaks ties so the choice is stable across runs.
  --
  -- Rows with a NULL key are forced to rn = 1: window partitions group
  -- all NULLs together, which would otherwise mark every key-less row
  -- after the first as a duplicate of an unrelated row.
  DROP TEMPORARY TABLE IF EXISTS tmp_ranked;
  CREATE TEMPORARY TABLE tmp_ranked (raw_id INT PRIMARY KEY, rn INT NOT NULL)
  SELECT raw_id,
         CASE WHEN account_id IS NULL OR ref_no IS NULL THEN 1
              ELSE ROW_NUMBER() OVER (PARTITION BY account_id, ref_no
                                      ORDER BY is_valid DESC, raw_id)
         END AS rn
  FROM tmp_staged;

  -- rn = 1 + valid   -> kept
  -- rn = 1 + invalid -> rejected with a reason
  -- rn > 1           -> dropped as a duplicate
  INSERT INTO transactions
        (account_id, txn_date, description, amount, direction, category_id, ref_no)
  SELECT s.account_id, s.txn_date, s.description, s.amount, s.direction, NULL, s.ref_no
  FROM tmp_staged s
  JOIN tmp_ranked k ON k.raw_id = s.raw_id
  WHERE k.rn = 1 AND s.is_valid = 1
  ORDER BY s.raw_id;

  INSERT INTO transactions_rejected (raw_id, reason)
  SELECT s.raw_id, s.reason
  FROM tmp_staged s
  JOIN tmp_ranked k ON k.raw_id = s.raw_id
  WHERE k.rn = 1 AND s.is_valid = 0
  ORDER BY s.raw_id;

  DROP TEMPORARY TABLE IF EXISTS tmp_staged;
  DROP TEMPORARY TABLE IF EXISTS tmp_ranked;
END$$

-- ------------------------------------------------------------
-- sp_clean_valuations — raw_valuations -> investment_valuations
--
-- Same staged approach, so the date and numeric casts are never
-- handed input that has not already passed its guard.
-- market_value is a generated column, so it is never inserted.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_clean_valuations()
BEGIN
  TRUNCATE TABLE investment_valuations;

  DROP TEMPORARY TABLE IF EXISTS tmp_val;
  CREATE TEMPORARY TABLE tmp_val (
    investment_id  INT NOT NULL,
    yy             INT NULL,
    mm             INT NULL,
    dd             INT NULL,
    dim            INT NULL,
    valuation_date DATE NULL,
    units_held     DECIMAL(14,4) NULL,
    nav            DECIMAL(12,4) NULL
  );

  INSERT INTO tmp_val (investment_id, yy, mm, dd, units_held, nav)
  SELECT i.investment_id,
         CASE WHEN TRIM(v.valuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(v.valuation_date),1,4) AS UNSIGNED) END,
         CASE WHEN TRIM(v.valuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(v.valuation_date),6,2) AS UNSIGNED) END,
         CASE WHEN TRIM(v.valuation_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(SUBSTRING(TRIM(v.valuation_date),9,2) AS UNSIGNED) END,
         CASE WHEN TRIM(v.units_held) REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(TRIM(v.units_held) AS DECIMAL(14,4)) END,
         CASE WHEN TRIM(v.nav) REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(TRIM(v.nav) AS DECIMAL(12,4)) END
  FROM raw_valuations v
  JOIN investments i ON i.instrument_name = TRIM(v.instrument_name);

  UPDATE tmp_val
     SET dim = DAY(LAST_DAY(DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-01'))))
   WHERE mm BETWEEN 1 AND 12
     AND yy BETWEEN 1900 AND 2999;

  UPDATE tmp_val
     SET valuation_date = DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-',LPAD(dd,2,'0')))
   WHERE dim IS NOT NULL
     AND dd BETWEEN 1 AND dim;

  INSERT INTO investment_valuations (investment_id, valuation_date, units_held, nav)
  SELECT investment_id, valuation_date, units_held, nav
  FROM tmp_val
  WHERE valuation_date IS NOT NULL
    AND units_held     IS NOT NULL
    AND nav            IS NOT NULL
  ORDER BY investment_id, valuation_date;

  DROP TEMPORARY TABLE IF EXISTS tmp_val;
END$$

DELIMITER ;

CALL sp_clean_transactions();
CALL sp_clean_valuations();

-- ---------- reconciliation profile ----------
SELECT (SELECT COUNT(*) FROM raw_transactions)        AS raw_rows,
       (SELECT COUNT(*) FROM transactions)            AS clean_rows,
       (SELECT COUNT(*) FROM transactions_rejected)   AS rejected_rows,
       (SELECT COUNT(*) FROM raw_transactions)
       - (SELECT COUNT(*) FROM transactions)
       - (SELECT COUNT(*) FROM transactions_rejected) AS duplicate_rows,
       (SELECT COUNT(*) FROM investment_valuations)   AS valuation_rows;

SELECT reason, COUNT(*) AS rows_rejected
FROM transactions_rejected
GROUP BY reason ORDER BY rows_rejected DESC, reason;
