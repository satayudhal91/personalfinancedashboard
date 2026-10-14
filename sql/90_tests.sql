-- ============================================================
-- 90_tests.sql — assertion suite for finance_db
--
-- Run:  mysql --login-path=finance finance_db < sql/90_tests.sql
-- EVERY row of the output must read PASS. The last query prints
-- the failure count, so a non-zero value there fails the phase.
--
-- One block per build phase; each new phase appends its block:
--   Phase 1  staging load + reference seed    <- present
--   Phase 2  cleaning / reconciliation       <- present
--   Phase 3  categorization coverage         <- present
--   Phase 4  planning data                   <- present
--   Phase 5  analytics views                 <- present
--   Phase 6  view selectability + hard fail   <- present
-- ============================================================
USE finance_db;

-- Expected values below are the shipped-dataset figures from
-- docs/ARCHITECTURE.md §3, verified against data/raw/ before use.

DROP TEMPORARY TABLE IF EXISTS tmp_results;
CREATE TEMPORARY TABLE tmp_results (
  phase    VARCHAR(10),
  test     VARCHAR(60),
  actual   BIGINT,
  expected BIGINT
);

DROP PROCEDURE IF EXISTS sp_check_views_selectable;
DROP PROCEDURE IF EXISTS sp_assert_suite_passed;

DELIMITER $$

-- ------------------------------------------------------------
-- sp_check_views_selectable — "every view selectable" (Phase 6).
--
-- A view can exist in information_schema and still fail the moment it
-- is queried: a column renamed underneath it, a dropped dependency, a
-- stale definition after a partial rebuild. Counting rows in
-- information_schema.VIEWS proves none of that, so every view is
-- actually executed here.
--
-- COUNT(*) INTO is used rather than SELECT ... LIMIT 1 for two
-- reasons: it returns no result set to the client (so the suite's
-- output stays clean), and it always returns exactly one row, so an
-- empty view cannot trip the cursor's NOT FOUND handler and end the
-- loop early.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_check_views_selectable()
BEGIN
  DECLARE v_done    INT DEFAULT 0;
  DECLARE v_checked INT DEFAULT 0;
  DECLARE v_failed  INT DEFAULT 0;
  DECLARE v_name    VARCHAR(64);
  DECLARE cur CURSOR FOR
    SELECT TABLE_NAME FROM information_schema.VIEWS
    WHERE TABLE_SCHEMA = DATABASE()
    ORDER BY TABLE_NAME;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  OPEN cur;
  view_loop: LOOP
    FETCH cur INTO v_name;
    IF v_done = 1 THEN
      LEAVE view_loop;
    END IF;

    SET v_checked = v_checked + 1;

    BEGIN
      -- Scoped to this iteration, so one broken view is recorded and
      -- the loop carries on to test the rest.
      -- v_err is a FLAG, not a counter: a broken view fails PREPARE,
      -- and EXECUTE and DEALLOCATE would then each fail again on the
      -- missing handler, scoring one bad view as three. Guarding on
      -- the flag also avoids leaking a prepared statement when
      -- EXECUTE is the thing that failed.
      DECLARE v_err INT DEFAULT 0;
      DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_err = 1;
      SET @stmt = CONCAT('SELECT COUNT(*) INTO @view_rows FROM `', v_name, '`');
      PREPARE ps FROM @stmt;
      IF v_err = 0 THEN
        EXECUTE ps;
        DEALLOCATE PREPARE ps;
      END IF;
      SET v_failed = v_failed + v_err;
    END;
  END LOOP;
  CLOSE cur;

  INSERT INTO tmp_results (phase, test, actual, expected)
  VALUES ('6', 'every view executes without error', v_failed,  0),
         ('6', 'views exercised by the selectability check', v_checked, 17);
END$$

-- ------------------------------------------------------------
-- sp_assert_suite_passed — make a failure fail the PROCESS.
--
-- Without this the client exits 0 whatever the table said, so a
-- broken rebuild looks successful to any script, CI step or anyone
-- skimming 100+ rows of output. SIGNAL raises a real error, which
-- gives mysql a non-zero exit code.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_assert_suite_passed()
BEGIN
  DECLARE v_failures INT;
  DECLARE v_msg      VARCHAR(255);

  SELECT COUNT(*) INTO v_failures FROM tmp_results WHERE actual <> expected;

  IF v_failures > 0 THEN
    SET v_msg = CONCAT('90_tests.sql: ', v_failures,
                       ' assertion(s) FAILED - see the result table above');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

DELIMITER ;

INSERT INTO tmp_results (phase, test, actual, expected)
-- Date validation WITHOUT STR_TO_DATE.
--
-- Why: STR_TO_DATE('31-02-2026','%d-%m-%Y') returns NULL and raises a
-- warning inside a plain SELECT, but under strict sql_mode the same
-- call raises ERROR 1411 inside INSERT/UPDATE/CREATE..SELECT. A
-- validity check that aborts on the invalid row it is meant to detect
-- is useless, so we decide validity with pure integer arithmetic and
-- only ever construct dates that are already known to be real.
--
--   1. REGEXP picks the format and tells us where y/m/d sit
--   2. month must be 1-12, year must be sane
--   3. days-in-month comes from LAST_DAY() of the 1st of that month,
--      a date that is valid by construction, so it can never throw
--   4. day must be within that month's length
--
-- 03_clean.sql reuses this logic, factored into a stored function.
WITH parts AS (
  SELECT raw_id, txn_date,
         CASE WHEN txn_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN '%d-%m-%Y'
              WHEN txn_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN '%d/%m/%Y'
              WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN '%Y-%m-%d'
         END AS fmt,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN CAST(SUBSTRING(txn_date,1,4) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,7,4) AS UNSIGNED)
         END AS yy,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN CAST(SUBSTRING(txn_date,6,2) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,4,2) AS UNSIGNED)
         END AS mm,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'    THEN CAST(SUBSTRING(txn_date,9,2) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,1,2) AS UNSIGNED)
         END AS dd
  FROM raw_transactions
),
checked AS (
  SELECT raw_id, txn_date, fmt, yy, mm, dd,
         CASE WHEN fmt IS NOT NULL
                   AND mm BETWEEN 1 AND 12
                   AND yy BETWEEN 1900 AND 2999
              THEN DAY(LAST_DAY(DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-01'))))
         END AS dim
  FROM parts
),
bad_date AS (
  SELECT raw_id FROM checked
  WHERE fmt IS NULL
     OR yy IS NULL OR yy NOT BETWEEN 1900 AND 2999
     OR mm IS NULL OR mm NOT BETWEEN 1 AND 12
     OR dd IS NULL OR dim IS NULL
     OR dd < 1 OR dd > dim
),
no_amount AS (
  SELECT raw_id FROM raw_transactions
  WHERE NULLIF(TRIM(debit),'') IS NULL
    AND NULLIF(TRIM(credit),'') IS NULL
),
unknown_acct AS (
  SELECT r.raw_id FROM raw_transactions r
  LEFT JOIN accounts a ON a.account_name = TRIM(r.account_name)
  WHERE a.account_id IS NULL
),
rejectable AS (
  SELECT raw_id FROM bad_date
  UNION SELECT raw_id FROM no_amount
  UNION SELECT raw_id FROM unknown_acct
),
dup_keys AS (
  SELECT account_name, ref_no FROM raw_transactions
  GROUP BY account_name, ref_no HAVING COUNT(*) > 1
)

-- ---------- staging volumes ----------
SELECT '1', 'raw_transactions loaded',
       (SELECT COUNT(*) FROM raw_transactions), 1152
UNION ALL SELECT '1', 'raw_valuations loaded',
       (SELECT COUNT(*) FROM raw_valuations), 70

-- ---------- injected data-quality issues ----------
UNION ALL SELECT '1', 'duplicate rows on (account_name, ref_no)',
       (SELECT COUNT(*) - COUNT(DISTINCT account_name, ref_no) FROM raw_transactions), 25
UNION ALL SELECT '1', 'bad date rows',
       (SELECT COUNT(*) FROM bad_date), 6
UNION ALL SELECT '1', 'missing amount rows',
       (SELECT COUNT(*) FROM no_amount), 5
UNION ALL SELECT '1', 'rows with an unknown account name',
       (SELECT COUNT(*) FROM unknown_acct), 0
UNION ALL SELECT '1', 'rejectable rows total',
       (SELECT COUNT(*) FROM rejectable), 11
UNION ALL SELECT '1', 'distinct date formats seen',
       (SELECT COUNT(DISTINCT fmt) FROM checked), 3

-- ---------- load hygiene ----------
-- A stray \r means the CSV was committed with CRLF endings while
-- 02_load.sql terminates lines on \n, which silently corrupts ref_no.
UNION ALL SELECT '1', 'no stray CR in ref_no',
       (SELECT COUNT(*) FROM raw_transactions WHERE ref_no LIKE '%\r'), 0
UNION ALL SELECT '1', 'no empty ref_no (dedupe key must be usable)',
       (SELECT COUNT(*) FROM raw_transactions WHERE NULLIF(TRIM(ref_no),'') IS NULL), 0

-- ---------- reconciliation identity ----------
-- The partition the whole project rests on:
--   1152 raw = 1116 clean + 11 rejected + 25 duplicates.
-- Verified disjoint: no rejectable row sits inside a duplicate group,
-- and no row is both bad-date and missing-amount. Phase 2 asserts the
-- realised counts; here we prove the arithmetic holds on the input.
UNION ALL SELECT '1', 'reconciliation: raw - dupes - rejects = 1116',
       (SELECT COUNT(*) FROM raw_transactions)
       - (SELECT COUNT(*) - COUNT(DISTINCT account_name, ref_no) FROM raw_transactions)
       - (SELECT COUNT(*) FROM rejectable), 1116
UNION ALL SELECT '1', 'rejects and duplicate groups are disjoint',
       (SELECT COUNT(*) FROM rejectable j
          JOIN raw_transactions r ON r.raw_id = j.raw_id
          JOIN dup_keys d ON d.account_name = r.account_name
                         AND d.ref_no       = r.ref_no), 0

-- ---------- reference seed data ----------
UNION ALL SELECT '1', 'accounts seeded',             (SELECT COUNT(*) FROM accounts), 3
UNION ALL SELECT '1', 'categories seeded',           (SELECT COUNT(*) FROM categories), 23
UNION ALL SELECT '1', 'categorization rules seeded', (SELECT COUNT(*) FROM categorization_rules), 48
UNION ALL SELECT '1', 'investments seeded',          (SELECT COUNT(*) FROM investments), 5
UNION ALL SELECT '1', 'loans seeded',                (SELECT COUNT(*) FROM loans), 1

-- Each category_type must exist, or the KPI views lose a whole branch.
UNION ALL SELECT '1', 'all 5 category types present',
       (SELECT COUNT(DISTINCT category_type) FROM categories), 5
-- Transfers are excluded from every KPI, so both legs must be classified.
UNION ALL SELECT '1', 'transfer categories = Card Payment + Wallet Top-up',
       (SELECT COUNT(*) FROM categories WHERE category_type = 'transfer'), 2
-- Rules with no reachable category would silently never fire.
UNION ALL SELECT '1', 'every rule points at a real category',
       (SELECT COUNT(*) FROM categorization_rules r
         LEFT JOIN categories c ON c.category_id = r.category_id
        WHERE c.category_id IS NULL), 0
UNION ALL SELECT '1', 'no duplicate rule keywords',
       (SELECT COUNT(*) - COUNT(DISTINCT keyword) FROM categorization_rules), 0

-- ---------- valuations line up with holdings ----------
UNION ALL SELECT '1', 'valuation instruments resolve to investments',
       (SELECT COUNT(*) FROM raw_valuations v
         LEFT JOIN investments i ON i.instrument_name = TRIM(v.instrument_name)
        WHERE i.investment_id IS NULL), 0
UNION ALL SELECT '1', 'distinct instruments valued',
       (SELECT COUNT(DISTINCT instrument_name) FROM raw_valuations), 5
UNION ALL SELECT '1', 'distinct month-ends valued (18-month window)',
       (SELECT COUNT(DISTINCT valuation_date) FROM raw_valuations), 18
;

-- ============================================================
-- Phase 2 — cleaning: reconciliation, typing, normalization
-- ============================================================
INSERT INTO tmp_results (phase, test, actual, expected)

-- ---------- reconciliation ----------
SELECT '2', 'clean transactions loaded',
       (SELECT COUNT(*) FROM transactions), 1116
UNION ALL SELECT '2', 'rejected rows recorded',
       (SELECT COUNT(*) FROM transactions_rejected), 11
UNION ALL SELECT '2', 'rows dropped as duplicates',
       (SELECT COUNT(*) FROM raw_transactions)
       - (SELECT COUNT(*) FROM transactions)
       - (SELECT COUNT(*) FROM transactions_rejected), 25
-- Independent cross-check: the duplicate term is recomputed straight
-- from staging rather than inferred by subtraction, so this fails if
-- cleaning silently drops or invents a row.
UNION ALL SELECT '2', 'clean + rejected + raw duplicates = raw total',
       (SELECT COUNT(*) FROM transactions)
       + (SELECT COUNT(*) FROM transactions_rejected)
       + (SELECT COUNT(*) - COUNT(DISTINCT account_name, ref_no) FROM raw_transactions), 1152

-- ---------- core table integrity ----------
UNION ALL SELECT '2', 'no duplicate (account_id, ref_no) in core',
       (SELECT COUNT(*) - COUNT(DISTINCT account_id, ref_no) FROM transactions), 0
UNION ALL SELECT '2', 'no non-positive amounts',
       (SELECT COUNT(*) FROM transactions WHERE amount <= 0), 0
UNION ALL SELECT '2', 'no NULL ref_no in core',
       (SELECT COUNT(*) FROM transactions WHERE ref_no IS NULL), 0
-- Descriptions drive every categorization rule, so the normalized
-- form must be exact: upper case, trimmed, no internal double spaces.
UNION ALL SELECT '2', 'descriptions fully normalized',
       (SELECT COUNT(*) FROM transactions
         WHERE description <> UPPER(description)
            OR description <> TRIM(description)
            OR description REGEXP '  '), 0
UNION ALL SELECT '2', 'all dates inside Apr 2025 - Sep 2026',
       (SELECT COUNT(*) FROM transactions
         WHERE txn_date NOT BETWEEN '2025-04-01' AND '2026-09-30'), 0
UNION ALL SELECT '2', 'months covered',
       (SELECT COUNT(DISTINCT DATE_FORMAT(txn_date,'%Y-%m-01')) FROM transactions), 18

-- ---------- rejections ----------
UNION ALL SELECT '2', 'every rejected raw_id is a real staging row',
       (SELECT COUNT(*) FROM transactions_rejected r
         LEFT JOIN raw_transactions x ON x.raw_id = r.raw_id
        WHERE x.raw_id IS NULL), 0
UNION ALL SELECT '2', 'rejection reasons come from the known set',
       (SELECT COUNT(*) FROM transactions_rejected
         WHERE reason NOT IN ('bad_date','missing_amount','non_positive_amount',
                              'unknown_account','blank_description','missing_ref_no')), 0
UNION ALL SELECT '2', 'rejected: bad_date',
       (SELECT COUNT(*) FROM transactions_rejected WHERE reason = 'bad_date'), 6
UNION ALL SELECT '2', 'rejected: missing_amount',
       (SELECT COUNT(*) FROM transactions_rejected WHERE reason = 'missing_amount'), 5

-- ---------- valuations ----------
UNION ALL SELECT '2', 'investment_valuations loaded',
       (SELECT COUNT(*) FROM investment_valuations), 70
UNION ALL SELECT '2', 'market_value generated for every valuation',
       (SELECT COUNT(*) FROM investment_valuations
         WHERE market_value IS NULL OR market_value <= 0), 0
UNION ALL SELECT '2', 'valuations unique per (holding, month-end)',
       (SELECT COUNT(DISTINCT investment_id, valuation_date) FROM investment_valuations), 70
UNION ALL SELECT '2', 'valuation instruments / month-ends preserved',
       (SELECT COUNT(DISTINCT investment_id) * 100 + COUNT(DISTINCT valuation_date)
          FROM investment_valuations), 518
;

-- ============================================================
-- Phase 3 — categorization: coverage and transfer integrity
-- ============================================================
INSERT INTO tmp_results (phase, test, actual, expected)

-- ---------- coverage ----------
SELECT '3', 'transactions categorized',
       (SELECT SUM(category_id IS NOT NULL) FROM transactions), 1083
UNION ALL SELECT '3', 'transactions left uncategorized',
       (SELECT SUM(category_id IS NULL) FROM transactions), 33
UNION ALL SELECT '3', 'coverage at or above the 95% floor',
       (SELECT IF(100.0 * SUM(category_id IS NOT NULL) / COUNT(*) >= 95, 1, 0)
          FROM transactions), 1
UNION ALL SELECT '3', 'distinct uncategorized merchants',
       (SELECT COUNT(*) FROM vw_uncategorized_review), 4
-- Uncategorized debits are counted as expenses downstream, so a stray
-- uncategorized CREDIT would silently vanish from income instead.
UNION ALL SELECT '3', 'no uncategorized credits',
       (SELECT COUNT(*) FROM transactions
         WHERE category_id IS NULL AND direction = 'credit'), 0

-- ---------- transfers must not leak into expense KPIs ----------
-- Every transfer is recorded on both sides, so debits and credits
-- across the whole transfer category must cancel exactly.
UNION ALL SELECT '3', 'all transfer legs net to zero',
       (SELECT CAST(COALESCE(SUM(CASE WHEN t.direction = 'debit'
                                      THEN t.amount ELSE -t.amount END), 0) AS SIGNED)
          FROM transactions t
          JOIN categories c ON c.category_id = t.category_id
         WHERE c.category_type = 'transfer'), 0
UNION ALL SELECT '3', 'CC PAYMENT total = PAYMENT RECEIVED total',
       (SELECT CAST(SUM(CASE WHEN description LIKE '%CC PAYMENT%'       THEN amount ELSE 0 END)
                  - SUM(CASE WHEN description LIKE '%PAYMENT RECEIVED%' THEN amount ELSE 0 END)
                  AS SIGNED) FROM transactions), 0
UNION ALL SELECT '3', 'wallet top-up legs balance across accounts',
       (SELECT CAST(SUM(CASE WHEN a.account_name = 'SBI Savings'  THEN t.amount ELSE 0 END)
                  - SUM(CASE WHEN a.account_name = 'Paytm Wallet' THEN t.amount ELSE 0 END)
                  AS SIGNED)
          FROM transactions t
          JOIN accounts   a ON a.account_id  = t.account_id
          JOIN categories c ON c.category_id = t.category_id
         WHERE c.category_name = 'Wallet Top-up'), 0
-- The transfer keywords must never land anywhere but the transfer type.
UNION ALL SELECT '3', 'transfer keywords never categorized as expense',
       (SELECT COUNT(*) FROM transactions t
          JOIN categories c ON c.category_id = t.category_id
         WHERE (t.description LIKE '%CC PAYMENT%'
             OR t.description LIKE '%PAYMENT RECEIVED%'
             OR t.description LIKE '%ADD MONEY%')
           AND c.category_type <> 'transfer'), 0

-- ---------- investment and debt keywords reach the right type ----------
UNION ALL SELECT '3', 'SIP rows land in an investment category',
       (SELECT COUNT(*) FROM transactions t
          LEFT JOIN categories c ON c.category_id = t.category_id
         WHERE t.description LIKE '%SIP%'
           AND COALESCE(c.category_type,'') <> 'investment'), 0
UNION ALL SELECT '3', 'ZERODHA rows land in an investment category',
       (SELECT COUNT(*) FROM transactions t
          LEFT JOIN categories c ON c.category_id = t.category_id
         WHERE t.description LIKE '%ZERODHA%'
           AND COALESCE(c.category_type,'') <> 'investment'), 0
UNION ALL SELECT '3', 'FD BOOKING rows land in an investment category',
       (SELECT COUNT(*) FROM transactions t
          LEFT JOIN categories c ON c.category_id = t.category_id
         WHERE t.description LIKE '%FD BOOKING%'
           AND COALESCE(c.category_type,'') <> 'investment'), 0
UNION ALL SELECT '3', 'EMI rows land in Loan EMI',
       (SELECT COUNT(*) FROM transactions t
          LEFT JOIN categories c ON c.category_id = t.category_id
         WHERE t.description LIKE '%EMI%'
           AND COALESCE(c.category_name,'') <> 'Loan EMI'), 0

-- ---------- known totals, so a rule change cannot drift unnoticed ----------
UNION ALL SELECT '3', 'Loan EMI instalments recorded',
       (SELECT COUNT(*) FROM transactions t JOIN categories c ON c.category_id = t.category_id
         WHERE c.category_name = 'Loan EMI'), 16
UNION ALL SELECT '3', 'Mutual Fund SIP total invested',
       (SELECT CAST(COALESCE(SUM(t.amount),0) AS SIGNED) FROM transactions t
          JOIN categories c ON c.category_id = t.category_id
         WHERE c.category_name = 'Mutual Fund SIP'), 48000
;

-- ============================================================
-- Phase 4 — planning data: budgets and savings goals
-- ============================================================
INSERT INTO tmp_results (phase, test, actual, expected)

-- ---------- budget grid ----------
SELECT '4', 'budget rows (18 months x 13 categories)',
       (SELECT COUNT(*) FROM budgets), 234
UNION ALL SELECT '4', 'budget months',
       (SELECT COUNT(DISTINCT budget_month) FROM budgets), 18
UNION ALL SELECT '4', 'budgeted categories',
       (SELECT COUNT(DISTINCT category_id) FROM budgets), 13
-- The unique key already forbids this; the test proves the generator
-- produced a clean grid rather than relying on the constraint to
-- reject a malformed one.
UNION ALL SELECT '4', 'unique (category, month) holds',
       (SELECT COUNT(*) - COUNT(DISTINCT category_id, budget_month) FROM budgets), 0
UNION ALL SELECT '4', 'every budget_month is the 1st of a month',
       (SELECT COUNT(*) FROM budgets WHERE DAY(budget_month) <> 1), 0
UNION ALL SELECT '4', 'no non-positive budget amounts',
       (SELECT COUNT(*) FROM budgets WHERE budget_amount <= 0), 0

-- ---------- values ----------
UNION ALL SELECT '4', 'total budgeted across all months',
       (SELECT CAST(COALESCE(SUM(budget_amount),0) AS SIGNED) FROM budgets), 468000
-- Every month carries the same plan, so there must be exactly one
-- distinct monthly total. A dropped or duplicated row shows up here
-- even when the 234 count happens to still balance.
UNION ALL SELECT '4', 'monthly budget total is constant',
       (SELECT COUNT(DISTINCT s) FROM
          (SELECT SUM(budget_amount) AS s FROM budgets GROUP BY budget_month) z), 1
UNION ALL SELECT '4', 'monthly budget total',
       (SELECT CAST(MAX(s) AS SIGNED) FROM
          (SELECT SUM(budget_amount) AS s FROM budgets GROUP BY budget_month) z), 26000

-- ---------- alignment with the actuals ----------
-- Budget vs actual is only meaningful where both exist. An unbudgeted
-- month would read as a 100% favourable variance on the dashboard.
UNION ALL SELECT '4', 'every budget month has transactions',
       (SELECT COUNT(*) FROM (SELECT DISTINCT budget_month FROM budgets) b
          LEFT JOIN (SELECT DISTINCT CAST(DATE_FORMAT(txn_date,'%Y-%m-01') AS DATE) AS m
                       FROM transactions) t ON t.m = b.budget_month
         WHERE t.m IS NULL), 0
UNION ALL SELECT '4', 'every transaction month has a budget',
       (SELECT COUNT(*) FROM (SELECT DISTINCT CAST(DATE_FORMAT(txn_date,'%Y-%m-01') AS DATE) AS m
                                FROM transactions) t
          LEFT JOIN (SELECT DISTINCT budget_month FROM budgets) b ON b.budget_month = t.m
         WHERE b.budget_month IS NULL), 0
-- Budgets apply to spending only: a budget on an income or transfer
-- category would corrupt the budget-adherence component of the score.
UNION ALL SELECT '4', 'every budgeted category is an expense category',
       (SELECT COUNT(*) FROM budgets b
          JOIN categories c ON c.category_id = b.category_id
         WHERE c.category_type <> 'expense'), 0

-- ---------- savings goals ----------
UNION ALL SELECT '4', 'savings goals seeded',
       (SELECT COUNT(*) FROM savings_goals), 2
UNION ALL SELECT '4', 'savings goals combined target',
       (SELECT CAST(COALESCE(SUM(target_amount),0) AS SIGNED) FROM savings_goals), 210000
UNION ALL SELECT '4', 'savings goal target dates are in the future',
       (SELECT COUNT(*) FROM savings_goals WHERE target_date <= '2026-09-30'), 0
;

-- ============================================================
-- Phase 5 — analytics views: shape, identities and known values
-- ============================================================
INSERT INTO tmp_results (phase, test, actual, expected)

-- ---------- shape ----------
SELECT '5', 'views defined',
       (SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'finance_db'), 17
UNION ALL SELECT '5', 'vw_kpi_monthly has one row per month',
       (SELECT COUNT(*) FROM vw_kpi_monthly), 18
UNION ALL SELECT '5', 'vw_net_worth_monthly covers every month',
       (SELECT COUNT(*) FROM vw_net_worth_monthly), 18
UNION ALL SELECT '5', 'vw_health_score covers every month',
       (SELECT COUNT(*) FROM vw_health_score), 18
UNION ALL SELECT '5', 'vw_kpi_summary is a single row',
       (SELECT COUNT(*) FROM vw_kpi_summary), 1
UNION ALL SELECT '5', 'vw_budget_vs_actual is the full grid',
       (SELECT COUNT(*) FROM vw_budget_vs_actual), 234
UNION ALL SELECT '5', 'vw_portfolio_monthly is 5 holdings x 18 months',
       (SELECT COUNT(*) FROM vw_portfolio_monthly), 90
-- vw_mom_change is densified to 18 months x 14 spending categories
-- (13 budgeted + Uncategorized) so LAG never steps over a quiet month.
UNION ALL SELECT '5', 'vw_mom_change is densified',
       (SELECT COUNT(*) FROM vw_mom_change), 252

-- ---------- loan amortization ----------
UNION ALL SELECT '5', 'vw_loan_schedule covers the full tenure',
       (SELECT COUNT(*) FROM vw_loan_schedule), 24
UNION ALL SELECT '5', 'loan closing balance lands within 5 of zero',
       (SELECT IF(ABS(closing_balance) <= 5, 1, 0) FROM vw_loan_schedule
         WHERE installment_no = 24), 1
UNION ALL SELECT '5', 'loan interest + principal always equals the EMI',
       (SELECT COUNT(*) FROM vw_loan_schedule
         WHERE ABS(interest + principal_paid - emi_amount) > 0.01), 0

-- ---------- balances and the sign convention ----------
UNION ALL SELECT '5', 'no negative savings or wallet month-end balance',
       (SELECT COUNT(*) FROM vw_month_end_balances
         WHERE account_type IN ('savings','wallet') AND month_end_balance < 0), 0
-- The headline data-quality story: Sep 2026 card spend of 8,157 less
-- the two rejected card rows (119 + 2,947) that were billed and paid
-- but never reached the clean table.
UNION ALL SELECT '5', 'card outstanding at Sep 2026',
       (SELECT CAST(card_outstanding AS SIGNED) FROM vw_kpi_monthly
         WHERE month = '2026-09-01'), 5091

-- ---------- identities ----------
UNION ALL SELECT '5', 'net worth = liquid + investments - card - loan',
       (SELECT COUNT(*) FROM vw_net_worth_monthly
         WHERE ABS(net_worth - (liquid_balance + investment_value
                                - card_outstanding - loan_outstanding)) > 0.01), 0
UNION ALL SELECT '5', 'health score equals the sum of its components',
       (SELECT COUNT(*) FROM vw_health_score
         WHERE ABS(health_score - (pts_savings_rate + pts_dti + pts_emergency_fund
                                 + pts_investment_rate + pts_budget_adherence)) > 0.01), 0
UNION ALL SELECT '5', 'health score stays inside 0..100',
       (SELECT COUNT(*) FROM vw_health_score WHERE health_score < 0 OR health_score > 100), 0
-- subscription_burn is the non-essential subset of recurring_burn,
-- so it can never exceed it.
UNION ALL SELECT '5', 'subscription burn never exceeds recurring burn',
       (SELECT COUNT(*) FROM vw_kpi_monthly WHERE subscription_burn > recurring_burn), 0

-- ---------- known totals, transfers excluded throughout ----------
-- These are the anchors that prove transfers never leaked into a KPI:
-- card payments (2 x 1,46,235) and wallet top-ups (2 x 8,687) would
-- be impossible to miss in these figures.
UNION ALL SELECT '5', 'all-time income across vw_kpi_monthly',
       (SELECT CAST(COALESCE(SUM(income),0) AS SIGNED) FROM vw_kpi_monthly), 763885
UNION ALL SELECT '5', 'all-time expenses (incl. uncategorized debits)',
       (SELECT CAST(COALESCE(SUM(expenses),0) AS SIGNED) FROM vw_kpi_monthly), 513779
UNION ALL SELECT '5', 'all-time debt service',
       (SELECT CAST(COALESCE(SUM(debt_service),0) AS SIGNED) FROM vw_kpi_monthly), 55312
UNION ALL SELECT '5', 'all-time invested = portfolio cost basis',
       (SELECT CAST(COALESCE(SUM(invested),0) AS SIGNED) FROM vw_kpi_monthly), 86156
UNION ALL SELECT '5', 'uncategorized spend reaches the expense total',
       (SELECT CAST(COALESCE(SUM(uncategorized_spend),0) AS SIGNED) FROM vw_kpi_monthly), 10990

-- ---------- recurrence detection ----------
UNION ALL SELECT '5', 'recurring merchants detected',
       (SELECT COUNT(*) FROM vw_recurring_payments), 6
UNION ALL SELECT '5', 'exactly one detected run is an EMI',
       (SELECT COUNT(*) FROM vw_recurring_payments WHERE is_emi = 1), 1

-- ---------- data quality view agrees with the core tables ----------
UNION ALL SELECT '5', 'vw_data_quality reconciles to 1152 raw rows',
       (SELECT clean_rows + rejected_rows + duplicate_rows FROM vw_data_quality), 1152
;

-- ============================================================
-- Phase 6 — every view must actually execute, not merely exist
-- ============================================================
CALL sp_check_views_selectable();

-- ---------- report ----------
SELECT phase,
       test,
       actual,
       expected,
       IF(actual = expected, 'PASS', 'FAIL') AS result
FROM tmp_results
ORDER BY phase, test;

SELECT COUNT(*) AS failures,
       IF(COUNT(*) = 0, 'ALL TESTS PASS', 'SUITE FAILED') AS verdict
FROM tmp_results
WHERE actual <> expected;

-- ---------- per-phase roll-up ----------
SELECT phase,
       COUNT(*)                  AS tests,
       SUM(actual =  expected)   AS passed,
       SUM(actual <> expected)   AS failed
FROM tmp_results
GROUP BY phase WITH ROLLUP;

-- Raises SQLSTATE 45000 when anything failed, so the mysql client
-- exits non-zero and a broken rebuild cannot be mistaken for a good
-- one. Prints nothing when the suite is green.
CALL sp_assert_suite_passed();
