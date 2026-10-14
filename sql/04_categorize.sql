-- ============================================================
-- 04_categorize.sql — keyword rules -> transactions.category_id
--   mysql --login-path=finance finance_db < sql/04_categorize.sql
--
-- For the shipped dataset: 1083 of 1116 categorized = 97.04%,
-- 33 left over, all from 4 merchants no rule covers.
--
-- A NULL category_id is the uncategorized marker and is kept in core
-- rather than pointed at a placeholder category row. The analytics
-- layer buckets uncategorized debits as "Uncategorized" expenses
-- (CLAUDE.md), so the bucket is a presentation concern, not a fact.
-- ============================================================
USE finance_db;

DROP PROCEDURE IF EXISTS sp_categorize;

DELIMITER $$

-- ------------------------------------------------------------
-- sp_categorize — assign one category per transaction.
--
-- Rules are substring matches against the NORMALIZED description
-- (03_clean.sql already upper-cased, trimmed and collapsed internal
-- whitespace), so the LIKE never has to cope with casing or padding.
--
-- A transaction can match several rules, so the winner is ranked:
--   1. priority ASC      -- lower wins, per the schema comment
--   2. LENGTH(keyword)   -- longer keyword = more specific merchant
--   3. rule_id           -- stable tie-break, so runs are repeatable
--
-- On the shipped data no transaction matches more than one rule, so
-- ranks 2 and 3 never fire. They exist because Satayu Dhal will add rules and
-- Phase 9 brings real statements, where overlap is the norm:
-- without a deterministic order the same input could categorize
-- differently between runs.
--
-- Idempotent: clears every category first, so re-running after a rule
-- change recategorizes from scratch instead of layering on stale
-- assignments.
-- ------------------------------------------------------------
CREATE PROCEDURE sp_categorize()
BEGIN
  UPDATE transactions SET category_id = NULL;

  DROP TEMPORARY TABLE IF EXISTS tmp_match;
  CREATE TEMPORARY TABLE tmp_match (txn_id INT PRIMARY KEY, category_id INT NOT NULL)
  SELECT txn_id, category_id
  FROM (
    SELECT t.txn_id,
           r.category_id,
           ROW_NUMBER() OVER (PARTITION BY t.txn_id
                              ORDER BY r.priority, LENGTH(r.keyword) DESC, r.rule_id) AS rn
    FROM transactions t
    JOIN categorization_rules r
      ON t.description LIKE CONCAT('%', r.keyword, '%')
  ) ranked
  WHERE rn = 1;

  UPDATE transactions t
    JOIN tmp_match m ON m.txn_id = t.txn_id
     SET t.category_id = m.category_id;

  DROP TEMPORARY TABLE IF EXISTS tmp_match;
END$$

DELIMITER ;

CALL sp_categorize();

-- ------------------------------------------------------------
-- vw_uncategorized_review — what to write the next rules against.
-- Excel-friendly: snake_case, no NULL numerics.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_uncategorized_review AS
SELECT t.description                                                          AS merchant,
       COUNT(*)                                                               AS txn_count,
       COALESCE(SUM(t.amount), 0)                                             AS total_amount,
       COALESCE(ROUND(AVG(t.amount), 2), 0)                                   AS avg_amount,
       COALESCE(SUM(CASE WHEN t.direction = 'debit'  THEN t.amount END), 0)   AS debit_amount,
       COALESCE(SUM(CASE WHEN t.direction = 'credit' THEN t.amount END), 0)   AS credit_amount,
       MIN(t.txn_date)                                                        AS first_seen,
       MAX(t.txn_date)                                                        AS last_seen
FROM transactions t
WHERE t.category_id IS NULL
GROUP BY t.description
ORDER BY txn_count DESC, total_amount DESC;

-- ---------- coverage profile ----------
SELECT COUNT(*)                                                      AS total_txns,
       SUM(category_id IS NOT NULL)                                  AS categorized,
       SUM(category_id IS NULL)                                      AS uncategorized,
       ROUND(100.0 * SUM(category_id IS NOT NULL) / COUNT(*), 2)     AS coverage_pct
FROM transactions;

SELECT c.category_type,
       c.category_name,
       COUNT(*)        AS txns,
       SUM(t.amount)   AS total_amount
FROM transactions t
JOIN categories c ON c.category_id = t.category_id
GROUP BY c.category_type, c.category_name
ORDER BY c.category_type, total_amount DESC;

-- ---------- acceptance checks ----------
-- Both legs of every card payment must land in the transfer category
-- and cancel out, otherwise a transfer leaks into the expense KPIs.
SELECT 'CC PAYMENT (SBI debit leg)'        AS leg,
       COUNT(*) AS txns, SUM(amount) AS total
FROM transactions WHERE description LIKE '%CC PAYMENT%'
UNION ALL
SELECT 'PAYMENT RECEIVED (card credit leg)',
       COUNT(*), SUM(amount)
FROM transactions WHERE description LIKE '%PAYMENT RECEIVED%';

-- Every investment and debt keyword must reach the right category_type.
SELECT 'SIP -> investment'     AS rule_check,
       SUM(c.category_type <> 'investment') AS wrong
FROM transactions t JOIN categories c ON c.category_id = t.category_id
WHERE t.description LIKE '%SIP%'
UNION ALL
SELECT 'ZERODHA -> investment', SUM(c.category_type <> 'investment')
FROM transactions t JOIN categories c ON c.category_id = t.category_id
WHERE t.description LIKE '%ZERODHA%'
UNION ALL
SELECT 'FD BOOKING -> investment', SUM(c.category_type <> 'investment')
FROM transactions t JOIN categories c ON c.category_id = t.category_id
WHERE t.description LIKE '%FD BOOKING%'
UNION ALL
SELECT 'EMI -> Loan EMI', SUM(c.category_name <> 'Loan EMI')
FROM transactions t JOIN categories c ON c.category_id = t.category_id
WHERE t.description LIKE '%EMI%';

SELECT * FROM vw_uncategorized_review;
