# Measured Metrics

**Project author: Satayu Dhal**

Every number used in the README or on the resume must appear here with the query that produced it.
Claude Code appends to this file at the end of each phase.

Environment: MySQL 8.0.46 on Windows 11, database `finance_db`, user `finance_app@localhost`.
Rebuild command (from repo root): `mysql --login-path=finance --local-infile=1 < sql/00_run_all.sql`

| Phase | Metric | Value | Query / source | Date measured |
|---|---|---|---|---|
| 1 | Raw transactions loaded | 1,152 | Q1 | 2026-10-07 |
| 1 | Raw valuations loaded | 70 | Q2 | 2026-10-07 |
| 1 | Duplicate rows on (account_name, ref_no) | 25 | Q3 | 2026-10-07 |
| 1 | Rows with an unparseable or impossible date | 6 | Q4 | 2026-10-07 |
| 1 | Rows missing both debit and credit | 5 | Q5 | 2026-10-07 |
| 1 | Rows with an unknown account name | 0 | Q6 | 2026-10-07 |
| 1 | Rejectable rows total (date + amount + account) | 11 | Q7 | 2026-10-07 |
| 1 | Expected clean rows (1152 − 25 − 11) | 1,116 | Q8 | 2026-10-07 |
| 1 | Distinct date formats present in source | 3 | Q9 | 2026-10-07 |
| 1 | Accounts / categories / rules / investments / loans seeded | 3 / 23 / 48 / 5 / 1 | Q10 | 2026-10-07 |
| 1 | Distinct instruments valued | 5 | Q11 | 2026-10-07 |
| 1 | Distinct month-ends valued | 18 | Q11 | 2026-10-07 |
| 1 | Test assertions run / failures | 24 / 0 | `sql/90_tests.sql` | 2026-10-07 |

| 2 | Clean transactions in core | 1,116 | Q12 | 2026-10-07 |
| 2 | Rejected rows | 11 | Q12 | 2026-10-07 |
| 2 | Rows dropped as duplicates | 25 | Q12 | 2026-10-07 |
| 2 | Investment valuations loaded | 70 | Q12 | 2026-10-07 |
| 2 | Rejection reasons: bad_date / missing_amount | 6 / 5 | Q13 | 2026-10-07 |
| 2 | Sum of clean transaction amounts | 17,28,976.00 | Q14 | 2026-10-07 |
| 2 | Total portfolio market value, all month-ends | 8,26,109.26 | Q14 | 2026-10-07 |
| 2 | Months covered | 18 (Apr 2025 – Sep 2026) | Q15 | 2026-10-07 |
| 2 | Idempotency fingerprint (MD5 over all 1,116 rows) | `3d1a9663d80c040041f12f42f1320982`, identical across 3 runs | Q16 | 2026-10-07 |
| 2 | Test assertions run / failures | 42 / 0 | `sql/90_tests.sql` | 2026-10-07 |

| 3 | Transactions categorized | 1,083 | Q17 | 2026-10-07 |
| 3 | Transactions left uncategorized | 33 | Q17 | 2026-10-07 |
| 3 | **Categorization coverage** | **97.04%** | Q17 | 2026-10-07 |
| 3 | Distinct uncategorized merchants | 4 | Q18 | 2026-10-07 |
| 3 | Uncategorized value (all debits) | 10,990.00 | Q18 | 2026-10-07 |
| 3 | Transactions matching more than one rule | 0 | Q19 | 2026-10-07 |
| 3 | Card payment legs (SBI debit / card credit) | 17 txns, 1,46,235.00 each side | Q20 | 2026-10-07 |
| 3 | Wallet top-up legs (SBI debit / wallet credit) | 18 txns, 8,687.00 each side | Q20 | 2026-10-07 |
| 3 | Net of all transfer legs | 0.00 | Q20 | 2026-10-07 |
| 3 | Loan EMI instalments | 16 × 3,457 = 55,312.00 | Q21 | 2026-10-07 |
| 3 | Mutual Fund SIP invested | 30 txns, 48,000.00 | Q21 | 2026-10-07 |
| 3 | Income transactions / value | 62 txns, 7,63,885.00 | Q21 | 2026-10-07 |
| 3 | Test assertions run / failures | 57 / 0 | `sql/90_tests.sql` | 2026-10-07 |

| 4 | Budget rows (18 months × 13 categories) | 234 | Q22 | 2026-10-07 |
| 4 | Budget months / categories | 18 / 13 | Q22 | 2026-10-07 |
| 4 | Monthly budgeted spend | 26,000.00 | Q22 | 2026-10-07 |
| 4 | Total budgeted across the period | 4,68,000.00 | Q22 | 2026-10-07 |
| 4 | Actual average monthly spend (budgeted categories only) | ≈27,932 | Q23 | 2026-10-07 |
| 4 | Aggregate budget vs actual | +7.4% actual over plan | Q23 | 2026-10-07 |
| 4 | Categories over budget / under budget | 6 / 7 | Q23 | 2026-10-07 |
| 4 | Savings goals seeded / combined target | 2 / 2,10,000.00 | Q24 | 2026-10-07 |
| 4 | Test assertions run / failures | 72 / 0 | `sql/90_tests.sql` | 2026-10-07 |

| 5 | Analytics views built | 17 | Q25 | 2026-10-07 |
| 5 | Views with a NULL in any column | 0 of 17 | Q26 | 2026-10-07 |
| 5 | **Net worth, Sep 2026** | **2,02,249.33** | Q27 | 2026-10-07 |
| 5 | Net worth range over 18 months | −17,213.50 → 2,02,249.33 | Q27 | 2026-10-07 |
| 5 | **Health score, Sep 2026** | **82.82 / 100** | Q28 | 2026-10-07 |
| 5 | Health score range (min / avg / max) | 39.81 / 72.27 / 95.98 | Q28 | 2026-10-07 |
| 5 | TTM savings rate | 31.18% | Q29 | 2026-10-07 |
| 5 | TTM debt-to-income | 7.36% | Q29 | 2026-10-07 |
| 5 | TTM investment rate | 12.11% | Q29 | 2026-10-07 |
| 5 | All-time savings rate | 25.50% | Q29 | 2026-10-07 |
| 5 | Emergency fund coverage, Sep 2026 | 5.72 months | Q29 | 2026-10-07 |
| 5 | Investment cost basis / market value | 86,156.00 / 94,368.29 (+9.53%) | Q29 | 2026-10-07 |
| 5 | Loan payoff progress | 63.53% (26,256.96 outstanding) | Q29 | 2026-10-07 |
| 5 | Card outstanding, Sep 2026 | 5,091.00 | Q29 | 2026-10-07 |
| 5 | Recurring burn / subscription burn | 8,007.00 / 1,158.00 per month | Q30 | 2026-10-07 |
| 5 | Loan schedule rows / final closing balance | 24 / −1.98 | Q31 | 2026-10-07 |
| 5 | Heaviest views (`vw_kpi_summary` / `vw_kpi_monthly`) | 855 ms / 194 ms | Q32 | 2026-10-07 |
| 5 | Test assertions run / failures | 97 / 0 | `sql/90_tests.sql` | 2026-10-07 |

| 6 | **Total assertions / failures** | **99 / 0** | `sql/90_tests.sql` | 2026-10-07 |
| 6 | Assertions by phase (1/2/3/4/5/6) | 24 / 18 / 15 / 15 / 25 / 2 | Q33 | 2026-10-07 |
| 6 | Views executed by the selectability check | 17 | Q34 | 2026-10-07 |
| 6 | Exit code, green rebuild | 0 | Q35 | 2026-10-07 |
| 6 | Exit code, any failed assertion | 1 (SQLSTATE 45000) | Q35 | 2026-10-07 |
| 6 | One-command rebuild | `mysql --login-path=finance --local-infile=1 < sql/00_run_all.sql` | — | 2026-10-07 |

| 7 | **Portfolio XIRR** | **≈13.05% p.a.** | Q36 | 2026-10-07 |
| 7 | Portfolio absolute return | +9.53% (86,156 → 94,368.29) | Q29 | 2026-10-07 |
| 7 | Investment cash flows feeding XIRR | 37 buys (−86,156.00) + 5 terminal valuations (+94,368.29) | Q36 | 2026-10-07 |
| 7 | Views loaded into the workbook | 14 of 17 | `docs/EXCEL_GUIDE.md` §1 | 2026-10-07 |
| 7 | Top expense merchant | UPI/RENT/PG BHUBANESWAR, 18 txns, 1,17,000 | Q37 | 2026-10-07 |
| 7 | Food delivery (Zomato + Swiggy) | 215 orders, 83,840 | Q37 | 2026-10-07 |

| 8 | Final suite state | 99 assertions / 0 failures, exit 0 | `sql/00_run_all.sql` | 2026-10-13 |
| 8 | SQL written across 6 numbered scripts | ~1,400 lines | `wc -l sql/*.sql` | 2026-10-13 |
| 8 | Workbook state | 3.0 MB, 19 sheets, 17 views loaded + Data Model | Q38 | 2026-10-13 |
| 8 | Excel connection method | ODBC (native MySQL connector unavailable) | Q39 | 2026-10-13 |

## Phase 1 notes

**Reconciliation holds on the input.** 1,152 raw rows partition exactly into
1,116 clean + 11 rejectable + 25 duplicates. The three rejection reasons and the
duplicate groups were verified disjoint (Q7 cross-check in `90_tests.sql`): no
rejectable row sits inside a duplicate group, and no row is both bad-date and
missing-amount. Phase 2 asserts the *realised* counts after `sp_clean_transactions()`.

**Date validation avoids `STR_TO_DATE` on invalid input.** The first test run aborted with
`ERROR 1411: Incorrect datetime value: '31-02-2026' for function str_to_date`.
`STR_TO_DATE` returns NULL and warns inside a plain `SELECT`, but under strict
`sql_mode` the identical call raises a fatal error inside `INSERT`/`UPDATE`/`CREATE..SELECT` —
so the check aborted on the exact row it existed to detect. Validation is now pure
integer arithmetic: REGEXP picks the format, month is range-checked, days-in-month comes from
`LAST_DAY()` of the 1st of that month (valid by construction, so it cannot throw), and the day
is bounded by that length. Phase 2 reuses this as a stored function, since
`sp_clean_transactions()` inserts parsed dates and would hit the same error.

**Re-runnability confirmed.** `00_run_all.sql` was executed twice end to end; `01_schema.sql`
drops and recreates the database, and both runs produced identical counts.

**Known gap.** Connector/NET is not installed. It is not needed for Phases 1–6 but Excel's
*Get Data → From MySQL Database* will not appear without it in Phase 7.

## Queries

```sql
-- Q1
SELECT COUNT(*) FROM raw_transactions;
-- Q2
SELECT COUNT(*) FROM raw_valuations;
-- Q3
SELECT COUNT(*) - COUNT(DISTINCT account_name, ref_no) FROM raw_transactions;
```

Q4 and Q7–Q9 share the date-validation CTE chain (`parts` → `checked` → `bad_date`)
defined in `sql/90_tests.sql`; it is reproduced here in full rather than paraphrased.

```sql
-- Q4: rows whose date cannot be parsed or does not exist on the calendar
WITH parts AS (
  SELECT raw_id, txn_date,
         CASE WHEN txn_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN '%d-%m-%Y'
              WHEN txn_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN '%d/%m/%Y'
              WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN '%Y-%m-%d'
         END AS fmt,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'       THEN CAST(SUBSTRING(txn_date,1,4) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,7,4) AS UNSIGNED)
         END AS yy,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'       THEN CAST(SUBSTRING(txn_date,6,2) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,4,2) AS UNSIGNED)
         END AS mm,
         CASE WHEN txn_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'       THEN CAST(SUBSTRING(txn_date,9,2) AS UNSIGNED)
              WHEN txn_date REGEXP '^[0-9]{2}[-/][0-9]{2}[-/][0-9]{4}$' THEN CAST(SUBSTRING(txn_date,1,2) AS UNSIGNED)
         END AS dd
  FROM raw_transactions
),
checked AS (
  SELECT raw_id, fmt, yy, mm, dd,
         CASE WHEN fmt IS NOT NULL AND mm BETWEEN 1 AND 12 AND yy BETWEEN 1900 AND 2999
              THEN DAY(LAST_DAY(DATE(CONCAT(yy,'-',LPAD(mm,2,'0'),'-01'))))
         END AS dim
  FROM parts
)
SELECT COUNT(*) FROM checked
WHERE fmt IS NULL
   OR yy IS NULL OR yy NOT BETWEEN 1900 AND 2999
   OR mm IS NULL OR mm NOT BETWEEN 1 AND 12
   OR dd IS NULL OR dim IS NULL OR dd < 1 OR dd > dim;

-- Q5: rows carrying neither a debit nor a credit
SELECT COUNT(*) FROM raw_transactions
WHERE NULLIF(TRIM(debit),'') IS NULL AND NULLIF(TRIM(credit),'') IS NULL;

-- Q6: account names in the export that match no seeded account
SELECT COUNT(*) FROM raw_transactions r
LEFT JOIN accounts a ON a.account_name = TRIM(r.account_name)
WHERE a.account_id IS NULL;

-- Q7  = COUNT of the UNION of Q4, Q5 and Q6 raw_ids            -> 11
-- Q8  = Q1 - Q3 - Q7                                           -> 1116
-- Q9  = SELECT COUNT(DISTINCT fmt) FROM checked                -> 3

-- Q10: reference seed volumes
SELECT (SELECT COUNT(*) FROM accounts)             AS accounts,
       (SELECT COUNT(*) FROM categories)           AS categories,
       (SELECT COUNT(*) FROM categorization_rules) AS rules,
       (SELECT COUNT(*) FROM investments)          AS investments,
       (SELECT COUNT(*) FROM loans)                AS loans;

-- Q11: valuation coverage
SELECT COUNT(DISTINCT instrument_name) AS instruments,
       COUNT(DISTINCT valuation_date)  AS month_ends
FROM raw_valuations;
```

## Phase 2 notes

**Reconciliation closes exactly.** 1,152 raw = 1,116 clean + 11 rejected + 25 duplicates.
The duplicate term is cross-checked independently in `90_tests.sql`: it is recomputed from
staging as `COUNT(*) - COUNT(DISTINCT account_name, ref_no)` rather than inferred by
subtraction, so the test fails if cleaning silently drops or invents a row.

**The 11 rejects split 6 bad dates + 5 missing amounts**, matching the injected defects
exactly. Reasons are assigned first-failing-check-wins, so every rejected row carries exactly
one reason and the reason counts sum to the total.

**Two of the six bad dates are the credit-card rows that explain the closing balance.**
`SPOTIFY INDIA` ₹119 and `FLIPKART/ORDER` ₹2,947 are both on HDFC Credit Card and both carry
an unparseable date, so they never reach the clean table. They were billed and paid in reality,
which is why the Sep 2026 card outstanding lands at ₹5,091 rather than matching September card
spend of ₹8,157 (8,157 − 119 − 2,947 = 5,091). Phase 5 asserts that figure.

**Idempotency is proven by fingerprint, not just by row count.** An MD5 over every column of
all 1,116 rows ordered by `txn_id` returns `3d1a9663d80c040041f12f42f1320982` after the first
run, after calling the procedures a second time, and after a full drop-and-rebuild via
`00_run_all.sql`. Identical `txn_id`s included, because the procedure truncates rather than
deletes.

**No stored functions, by necessity and then by preference.** The first version factored date
parsing into `fn_parse_txn_date()`, which failed with
`ERROR 1419: You do not have the SUPER privilege and binary logging is enabled`. MySQL blocks
`CREATE FUNCTION` under binary logging unless the account holds `SUPER`/`SET_USER_ID` or the
server sets `log_bin_trust_function_creators`. Rather than ask for either, the logic was
inlined into the procedures — the repo now rebuilds on any MySQL 8 with an ordinary account
and no server-side configuration. Stored procedures are not subject to this restriction.

**Date parsing runs as four separate statements** (split y/m/d by REGEXP → range-check month
and year, take month length from `LAST_DAY()` → build the DATE → assign reasons) so that
evaluation order is guaranteed. Folding it into one expression would leave the engine free to
evaluate a cast before its guard, which is exactly how the Phase 1 `STR_TO_DATE` failure
happened.

**Deduplication keeps the valid copy.** `ROW_NUMBER() OVER (PARTITION BY account_id, ref_no
ORDER BY is_valid DESC, raw_id)` ranks a good row ahead of a defective twin, with `raw_id`
breaking ties so the choice is stable. Rows with a NULL key are forced to rank 1, because SQL
window partitions group all NULLs together and would otherwise mark every key-less row after
the first as a duplicate of an unrelated row. The shipped data has no NULL keys, but real bank
exports in Phase 9 will.

## Queries (Phase 2)

```sql
-- Q12: reconciliation profile (also printed at the end of 03_clean.sql)
SELECT (SELECT COUNT(*) FROM raw_transactions)        AS raw_rows,
       (SELECT COUNT(*) FROM transactions)            AS clean_rows,
       (SELECT COUNT(*) FROM transactions_rejected)   AS rejected_rows,
       (SELECT COUNT(*) FROM raw_transactions)
       - (SELECT COUNT(*) FROM transactions)
       - (SELECT COUNT(*) FROM transactions_rejected) AS duplicate_rows,
       (SELECT COUNT(*) FROM investment_valuations)   AS valuation_rows;

-- Q13: rejection reasons
SELECT reason, COUNT(*) AS rows_rejected
FROM transactions_rejected GROUP BY reason ORDER BY rows_rejected DESC, reason;

-- Q14: value totals
SELECT SUM(amount) FROM transactions;
SELECT SUM(market_value) FROM investment_valuations;

-- Q15: period covered
SELECT MIN(txn_date) AS first_txn, MAX(txn_date) AS last_txn,
       COUNT(DISTINCT DATE_FORMAT(txn_date,'%Y-%m-01')) AS months
FROM transactions;

-- Q16: idempotency fingerprint. Run it, CALL both procedures again,
-- run it a second time; the two fingerprints must match.
SET SESSION group_concat_max_len = 100000000;
SELECT COUNT(*) AS rows_, SUM(amount) AS total_amount,
       MD5(GROUP_CONCAT(txn_id,':',account_id,':',txn_date,':',amount,':',
                        direction,':',description,':',IFNULL(ref_no,'')
                        ORDER BY txn_id SEPARATOR '|')) AS fingerprint
FROM transactions;

-- The two rejected credit-card rows behind the Sep 2026 card balance
SELECT r.raw_id, r.reason, x.account_name, TRIM(x.description) AS descr, x.debit
FROM transactions_rejected r
JOIN raw_transactions x ON x.raw_id = r.raw_id
WHERE TRIM(x.account_name) = 'HDFC Credit Card';
```

## Phase 3 notes

**Coverage is 97.04%** — 1,083 of 1,116 transactions matched by the 48 seeded rules, with 33
left over. Those 33 come from exactly 4 merchants, worth ₹10,990, every one a debit. That
matters because uncategorized debits are counted as expenses downstream, so an uncategorized
*credit* would silently disappear from income instead; `90_tests.sql` asserts there are none.

**No transaction matches more than one rule.** Measured, not assumed. The ranking in
`sp_categorize()` (priority, then longer keyword, then `rule_id`) therefore never has to break a
tie on this dataset. It is still implemented, because Satayu Dhal will add rules and Phase 9 brings real
statements where overlapping keywords are normal — without a deterministic order the same input
could categorize differently between runs, which would break the idempotency guarantee from
Phase 2.

**Transfers are provably contained.** Every transfer is recorded on both sides, so the two legs
must cancel. They do, exactly: card payments are ₹1,46,235 on each side (17 transactions each),
wallet top-ups ₹8,687 on each side (18 each), and the net across the whole transfer category is
₹0.00. This is the guarantee that `Card Payment` and `Wallet Top-up` cannot inflate expenses in
any KPI.

**Keyword routing verified by category_type, not by eyeball.** Every `SIP`, `ZERODHA` and
`FD BOOKING` row lands in an investment category and every `EMI` row in `Loan EMI` — asserted as
counts of violations, so the tests fail if a future rule steals one of these.

**Two totals are pinned as regression anchors.** Loan EMI is 16 instalments × ₹3,457 = ₹55,312
(Jun 2025 → Sep 2026 is 16 of the loan's 24 months, the rest falling past the dataset), and
Mutual Fund SIP is ₹48,000 (₹2,000/mo × 18 for the Nifty index fund, plus ₹1,000/mo × 12 for the
flexi-cap starting in month 7). Both are independently derivable from
`docs/ARCHITECTURE.md` §3, so if a rule change shifts them the suite catches it.

**`category_id` stays NULL for uncategorized rows** rather than pointing at a placeholder
category. The "Uncategorized" bucket is created in the analytics layer, where
`COALESCE` turns NULL into that label — so the bucket is a presentation decision and the core
table keeps recording only what is actually known.

### Proposed rules for the unmatched merchants — NOT applied, Satayu Dhal decides

| Merchant | Txns | Value | Read | Suggested category |
|---|---|---|---|---|
| `UPI/M S TRADERS` | 9 | ₹3,142 | "Traders" + ~₹349 average reads as a local general store | Groceries |
| `UPI/SHOP 24X7` | 5 | ₹1,743 | Convenience store, ~₹349 average | Groceries |
| `UPI/RAMESH KUMAR` | 11 | ₹3,400 | Individual payee, ~₹309 average, roughly monthly across 13 months — reads as a milk or tiffin vendor | Groceries |
| `UPI/PAY*9348XXXXXX` | 8 | ₹2,705 | A masked phone-number UPI handle. The merchant is genuinely unknowable from the data | **leave uncategorized** |

Adding the first three would move coverage from **97.04% to 99.28%** (1,108 of 1,116), leaving
only the 8 masked-handle rows. Leaving the fourth alone is the defensible choice: inventing a
category for a payee that cannot be identified would make the number look better while making
the data less true, and "what did you do about the rows you could not classify?" is a fair
interview question.

To apply them, add to `sql/01_schema.sql` beside the other rules and re-run
`sql/00_run_all.sql`, then record coverage before and after:

```sql
INSERT INTO categorization_rules (keyword, category_id, priority)
SELECT k.keyword, c.category_id, k.priority FROM (
  SELECT 'M S TRADERS' AS keyword, 'Groceries' AS cat, 35 AS priority UNION ALL
  SELECT 'SHOP 24X7',   'Groceries', 35 UNION ALL
  SELECT 'RAMESH KUMAR','Groceries', 35
) k JOIN categories c ON c.category_name = k.cat;
```

The Phase 3 expectations in `sql/90_tests.sql` (1,083 categorized / 33 uncategorized / 4
merchants) are pinned to the current rule set and must be updated in the same commit, or the
suite will correctly report a failure.

## Queries (Phase 3)

```sql
-- Q17: coverage profile (also printed at the end of 04_categorize.sql)
SELECT COUNT(*)                                                  AS total_txns,
       SUM(category_id IS NOT NULL)                              AS categorized,
       SUM(category_id IS NULL)                                  AS uncategorized,
       ROUND(100.0 * SUM(category_id IS NOT NULL) / COUNT(*), 2) AS coverage_pct
FROM transactions;

-- Q18: what is left over, and what to write rules against
SELECT * FROM vw_uncategorized_review;

-- Q19: how many transactions more than one rule claims
SELECT COUNT(*) FROM (
  SELECT t.txn_id
  FROM transactions t
  JOIN categorization_rules r ON t.description LIKE CONCAT('%', r.keyword, '%')
  GROUP BY t.txn_id HAVING COUNT(*) > 1
) z;

-- Q20: transfer legs must cancel
SELECT a.account_name, t.direction, c.category_name,
       COUNT(*) AS txns, SUM(t.amount) AS total
FROM transactions t
JOIN accounts   a ON a.account_id  = t.account_id
JOIN categories c ON c.category_id = t.category_id
WHERE c.category_type = 'transfer'
GROUP BY a.account_name, t.direction, c.category_name
ORDER BY c.category_name, a.account_name;

SELECT SUM(CASE WHEN t.direction = 'debit' THEN t.amount ELSE -t.amount END) AS net
FROM transactions t JOIN categories c ON c.category_id = t.category_id
WHERE c.category_type = 'transfer';

-- Q21: value by category, the anchors the tests pin
SELECT c.category_type, c.category_name, COUNT(*) AS txns, SUM(t.amount) AS total_amount
FROM transactions t JOIN categories c ON c.category_id = t.category_id
GROUP BY c.category_type, c.category_name
ORDER BY c.category_type, total_amount DESC;
```

## Phase 4 notes

**234 budget rows generated, not typed.** A recursive CTE walks the month axis and
`CROSS JOIN`s it against a 13-row plan CTE, so the budget figures live in exactly one place. A
value change is a one-line edit in `05_seed_planning.sql`, not 18 edits.

**The month axis is derived from the data, not hardcoded.** The recursion anchors on
`MIN(txn_date)` and stops at `MAX(txn_date)`. Loading a longer statement history in Phase 9
extends the budget automatically, instead of leaving the new months unbudgeted — which would
show on the dashboard as a 100% favourable variance rather than as missing data. Two tests
assert the budget months and the transaction months are the same set, in both directions.

**Budgets apply to expense categories only.** A budget attached to an income or transfer
category would corrupt the budget-adherence component of the health score (15 of 100 points),
so that is asserted too.

**`saved_amount` on savings goals is left at 0 deliberately.** Progress is derived in the
analytics layer from actual balances. Storing it would create a second copy of a number that
already exists in `transactions`, free to drift from it.

### Budget realism

The budget was tightened once, before Phase 5, after measuring it against actuals. Entertainment
(800 → 300), Health (500 → 200) and Subscriptions (1,200 → 400) were budgeted 3–4× their real
spend, which made them impossible to breach. Budget adherence is the share of budgeted categories
at or under budget and carries 15 of the 100 health-score points, so three unbreachable
categories were three free points: the score would have read better than the behaviour justified.
`docs/BUILD_PLAN.md` Phase 4 carries the revised figures.

Final plan: **₹26,000/month**, ₹4,68,000 across the period, against roughly ₹27,932 of actual
average monthly spend — so actual runs **+7.4%** over plan in aggregate.

| Category | Budget/mo | Actual avg/mo | Variance |
|---|---|---|---|
| Education | 1,000 | 1,691 | +69.1% |
| Shopping | 3,000 | 4,524 | +50.8% |
| Food Delivery | 4,000 | 4,658 | +16.4% |
| Software & Tools | 1,500 | 1,640 | +9.3% |
| Dining Out | 1,200 | 1,234 | +2.8% |
| Transport | 1,800 | 1,811 | +0.6% |
| Rent | 6,500 | 6,500 | 0.0% |
| Snacks & Tea | 800 | 788 | −1.6% |
| Utilities & Recharge | 1,300 | 1,107 | −14.8% |
| Groceries | 4,000 | 3,291 | −17.7% |
| Entertainment | 300 | 240 | −20.1% |
| Subscriptions | 400 | 311 | −22.2% |
| Health | 200 | 137 | −31.3% |

Six categories run over plan and seven at or under, and every one of the seven is now a result
rather than an artefact of a slack target.

**Education's +69% is one event, not a habit.** The ₹25,000 CCNA exam in Aug 2026
(ARCHITECTURE §3) is a single payment spread across an 18-month average. Month-level budget
variance will show one large breach and seventeen quiet months, which is the honest picture; the
annual average is the misleading one. Expect the health score to dip sharply in that month.

## Queries (Phase 4)

```sql
-- Q22: budget grid profile (also printed at the end of 05_seed_planning.sql)
SELECT COUNT(*)                     AS budget_rows,
       COUNT(DISTINCT budget_month) AS months,
       COUNT(DISTINCT category_id)  AS categories,
       MIN(budget_month)            AS first_month,
       MAX(budget_month)            AS last_month,
       SUM(budget_amount)           AS total_budgeted
FROM budgets;

-- Q23: budget vs actual average monthly spend.
-- The two sides are aggregated SEPARATELY before joining: joining
-- budgets straight to transactions fans each transaction out across
-- the 18 budget rows for its category and inflates every total 18x.
WITH actual AS (
  SELECT category_id, SUM(amount) / 18 AS avg_pm FROM transactions GROUP BY category_id
),
budget AS (
  SELECT category_id, MAX(budget_amount) AS budget_pm FROM budgets GROUP BY category_id
)
SELECT c.category_name, b.budget_pm,
       ROUND(COALESCE(a.avg_pm, 0), 0) AS actual_avg_pm,
       ROUND(100 * (COALESCE(a.avg_pm, 0) - b.budget_pm) / b.budget_pm, 1) AS variance_pct
FROM budget b
JOIN categories c ON c.category_id = b.category_id
LEFT JOIN actual a ON a.category_id = b.category_id
ORDER BY variance_pct DESC;

-- Q24: savings goals
SELECT goal_name, target_amount, target_date FROM savings_goals ORDER BY target_date;
```

## Phase 5 notes

**All 17 views build, and no column in any of them returns NULL.** Checked by generating the
check from `information_schema.COLUMNS` rather than by inspection, so it covers all 17 views and
every column, not the ones that came to mind. That is the Power Query contract: Excel typing a
column as text because the first rows are NULL is one of the harder dashboard bugs to spot.

**The credit-card sign convention is fixed in one place and asserted.** `signed_amount` is
`+amount` for a credit and `-amount` for a debit, so card spending drives the balance negative
and the amount owed is `-balance`. `vw_net_worth_monthly` performs that negation exactly once.
Getting it backwards would silently invert net worth — it would still produce plausible-looking
numbers, which is what makes it dangerous. The Sep 2026 card balance of −5,091.00 pins it.

**The ₹5,091 card balance ties the whole pipeline together.** September card spend is ₹8,157;
the two card rows rejected back in Phase 2 for unparseable dates (`SPOTIFY INDIA` ₹119 and
`FLIPKART/ORDER` ₹2,947) were billed and paid in reality but never reached the clean table.
8,157 − 119 − 2,947 = 5,091. A Phase 2 data-quality decision is still visible, and explainable,
in a Phase 5 balance-sheet figure.

**Loan amortization closes at −1.98** after 24 recursive steps. The residue is the EMI being
rounded to ₹3,457 from a true ₹3,456.60, not drift in the recursion — `interest +
principal_paid = emi_amount` is asserted on every one of the 24 rows.

**`vw_mom_change` is densified before `LAG()`.** Entertainment has 4 transactions across 18
months. Without a dense month × category grid, `LAG` would step over the quiet months and
compare, say, March with January while labelling it "month over month". The grid makes the
absent months explicit zeros.

**Trailing-twelve-month ratios are computed from sums, not averaged from monthly ratios.**
Averaging ratios would weight a ₹23,000 month the same as a ₹60,000 one, which materially
overstates a lumpy freelance income. TTM savings rate is 31.18% computed properly; the naive
average of the twelve monthly rates is a different and wrong number.

### Two findings worth raising

**1. Net worth is negative from Jun 2025 to Oct 2025, and that is the formula working, not a
bug.** The ₹72,000 laptop loan appears as a liability the month it starts, but the laptop it
financed is not an asset in this data model — the lender paid the vendor, so no transaction ever
lands in an account. Net worth therefore drops by the full principal with nothing on the other
side, bottoming at −17,213.50 in Sep 2025 before recovering to +2,02,249.33 by Sep 2026.
`ARCHITECTURE.md` §5 KPI 14 defines net worth as liquid + investments − card − loan, and that is
exactly what is computed. Worth deciding before Phase 7 whether the dashboard should carry a
depreciating asset for loan-financed purchases, or simply annotate the dip. Annotating is the
honest, cheaper option and makes a good talking point.

**2. "Subscription Burn" as specified included rent.** The recurrence detector correctly finds
every merchant billing a stable amount for 3+ consecutive months — which legitimately means
rent (₹6,500), the Jio recharge (₹349) and GitHub (₹840) alongside Netflix and Spotify. The
literal KPI 10 definition summed all of them to ₹8,007 and labelled it subscriptions, putting
rent inside a tile people read as cancellable spend. The KPI is now split:

| | Definition | Sep 2026 |
|---|---|---|
| `recurring_burn` | all detected non-EMI recurring payments | ₹8,007 |
| `subscription_burn` | the same, restricted to **non-essential** categories | ₹1,158 |

`subscription_burn` reuses the `is_essential` flag already in `categories`, so it is the spend
genuinely available to cancel: GitHub 840 + Netflix 199 + Spotify 119. `ARCHITECTURE.md` §5 was
updated to carry both as KPI 10a and 10b.

### Performance: no index was added, deliberately

The build plan asks for `EXPLAIN` notes on the two heaviest views and an index "if one helps".
Measured in a single session, after warm-up:

| View | Time |
|---|---|
| `vw_kpi_summary` | 855 ms |
| `vw_kpi_monthly` | 194 ms |
| `vw_net_worth_monthly` | 80 ms |
| `vw_month_end_balances` | 52 ms |
| `vw_portfolio_monthly` | 26 ms |

`vw_kpi_summary` is slowest because it evaluates `vw_kpi_monthly` five times over (trailing
twelve months, all-time, latest month, and again via `vw_health_score`), each of which is itself
a six-way join of CTEs.

Two candidate indexes were built and benchmarked — `(account_id, txn_date, txn_id)` for the
month-end balance lookup, and a prefix index on `description` for the recurring-merchant join:

| | `vw_kpi_monthly` | `vw_kpi_summary` |
|---|---|---|
| With both indexes | 190 / 214 ms | 900 / 874 ms |
| Without | 189 / 178 ms | 797 / 805 ms |

**Neither helped; without them is marginally faster.** `transactions` is 1,116 rows and sits
entirely in the buffer pool, so nothing is ever waiting on a lookup — the time goes to CPU on
window functions and repeated CTE materialization, which an index cannot touch. Both were
dropped rather than shipped: an unused index costs write time on every rebuild and implies a
tuning decision that was never justified. The real lever would be materializing
`vw_kpi_monthly`, which is not worth it for a dashboard refreshed by hand at under a second.

## Queries (Phase 5)

```sql
-- Q25: the view inventory
SELECT TABLE_NAME FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'finance_db' ORDER BY TABLE_NAME;

-- Q26: generate a NULL check for every column of every view, then run
-- the output. Generated rather than hand-written so nothing is missed.
SET SESSION group_concat_max_len = 1000000;
SELECT CONCAT('SELECT ''', TABLE_NAME, ''' AS view_name, COUNT(*) AS rows_with_null FROM ',
              TABLE_NAME, ' WHERE ',
              GROUP_CONCAT(CONCAT('`', COLUMN_NAME, '` IS NULL') SEPARATOR ' OR '), ' UNION ALL')
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'finance_db' AND TABLE_NAME LIKE 'vw\_%'
GROUP BY TABLE_NAME;

-- Q27: net worth and its components
SELECT month, liquid_balance, investment_value, card_outstanding,
       loan_outstanding, net_worth
FROM vw_net_worth_monthly ORDER BY month;

-- Q28: health score and its five components
SELECT month, pts_savings_rate, pts_dti, pts_emergency_fund,
       pts_investment_rate, pts_budget_adherence, health_score
FROM vw_health_score ORDER BY month;

-- Q29: the dashboard tiles
SELECT * FROM vw_kpi_summary;

-- Q30: recurring vs subscription burn
SELECT * FROM vw_recurring_payments ORDER BY is_emi, avg_amount DESC;
SELECT month, recurring_burn, subscription_burn FROM vw_kpi_monthly ORDER BY month;

-- Q31: amortization endpoints
SELECT installment_no, due_date, opening_balance, interest,
       principal_paid, closing_balance
FROM vw_loan_schedule WHERE installment_no IN (1, 2, 23, 24);

-- Q32: per-view timing in one session (process start-up excluded)
SET @t := NOW(6); SELECT COUNT(*) INTO @a FROM vw_kpi_summary;
SELECT TIMESTAMPDIFF(MICROSECOND, @t, NOW(6)) / 1000 AS ms;
```

## Phase 6 notes

The suite and the rebuild script were grown phase by phase rather than written at the end, so
Phase 6 was a consolidation pass: audit the Phase 6 checklist in `BUILD_PLAN.md`, close what was
missing, and make failure impossible to miss.

**Checklist coverage**

| Required check | Where |
|---|---|
| reconciliation counts | Phase 1 + 2 |
| no duplicates in core | Phase 2 |
| coverage ≥ 95% | Phase 3 |
| transfer pairs balance | Phase 3 |
| non-negative liquid balances | Phase 5 |
| loan schedule ends at ≈ 0 | Phase 5 |
| 18 KPI rows | Phase 5 |
| budget rows = 234 | Phase 4 |
| every view selectable | **added in Phase 6** |

**"Every view selectable" needed executing, not counting.** A view can sit in
`information_schema.VIEWS` and still fail the moment it is queried — a renamed column
underneath it, a dropped dependency, a stale definition after a partial rebuild.
`sp_check_views_selectable()` walks a cursor over every view in the schema and runs
`SELECT COUNT(*) INTO @var FROM <view>` through `PREPARE`/`EXECUTE`, with a `CONTINUE HANDLER`
so one broken view is recorded and the loop carries on. `COUNT(*) INTO` is used rather than
`SELECT ... LIMIT 1` for two reasons: it returns no result set, keeping the suite output clean,
and it always returns exactly one row, so an empty view cannot trip the cursor's `NOT FOUND`
handler and end the loop early. A second assertion pins the number of views exercised at 17, so
the check cannot pass vacuously by iterating over nothing.

**A failed assertion now fails the process.** Previously `mysql` exited 0 no matter what the
result table said, so a broken rebuild looked successful to any script and to anyone skimming
100+ rows of output. `sp_assert_suite_passed()` raises `SQLSTATE 45000` when any row mismatches,
which gives the client a non-zero exit code.

**Both failure paths were tested by deliberately breaking things, not assumed.**

1. A bogus failing row into `tmp_results` → `ERROR 1644 (45000) ... 1 assertion(s) FAILED`,
   exit code **1**. Green rebuild still exits **0**.
2. A view whose underlying table was dropped → detected, and the roll-up reported 18 views
   exercised against an expected 17.

That second test found a real bug in the first version of the checker. It incremented a counter
inside the exception handler, but a broken view fails three times over — `PREPARE` fails, then
`EXECUTE` and `DEALLOCATE` each fail again on the handler that was never created — so one bad
view was scored as **three**. It is now a flag per iteration, guarded so `EXECUTE`/`DEALLOCATE`
are skipped when `PREPARE` already failed, which also avoids leaking a prepared statement when
`EXECUTE` is the thing that failed. Re-tested: one broken view now scores exactly 1.

**The suite is self-describing.** Output is the full assertion table (phase, test, actual,
expected, result), then a per-phase roll-up via `GROUP BY ... WITH ROLLUP`, then the verdict.
Each assertion prints what it measured next to what it expected, so a failure says what the
number actually was rather than only that something is wrong.

## Queries (Phase 6)

```sql
-- Q33: per-phase roll-up (printed at the end of every run)
SELECT phase, COUNT(*) AS tests,
       SUM(actual =  expected) AS passed,
       SUM(actual <> expected) AS failed
FROM tmp_results GROUP BY phase WITH ROLLUP;

-- Q34: views actually executed
CALL sp_check_views_selectable();

-- Q35: exit code of a full rebuild (0 when green, 1 when anything failed)
--   mysql --login-path=finance --local-infile=1 < sql/00_run_all.sql ; echo $?
```

## Phase 7 notes

`docs/EXCEL_GUIDE.md` is the deliverable from this side; the workbook itself is Satayu Dhal's build, by
design — "I built an Excel dashboard" is the claim an interviewer tests, so the clicks have to
be his.

**XIRR was computed in SQL purely to give the build a target.** Excel owns this KPI
(ARCHITECTURE §5 KPI 12), but a wrong `XIRR()` is quiet: hand it an aggregate instead of dated
flows, or lose the sign convention, and it still returns a plausible-looking percentage. The
value was bracketed by evaluating NPV across candidate rates and interpolating the zero
crossing: NPV is +27.74 at 13.00% and −232.18 at 13.50%, giving **≈13.05%**.

That the XIRR (13.05%) materially exceeds the absolute return (9.53%) is the correct behaviour
and the check that matters: the money went in through SIPs over 18 months, so the average rupee
was invested well under the full period, and the annualized return on time-weighted capital is
higher than the simple return on the total contributed. An XIRR landing near 9.5% means the
formula was handed totals rather than the dated cash flows.

**The data model is the part most likely to be skipped and most likely to break the build.**
The acceptance criterion "the slicers filter all charts" cannot be met by loading each view as
an independent worksheet table — a slicer only filters tables it is related to. The guide
builds a `dim_month` date dimension, marks it as a Date Table, and relates it one-to-many to all
eight month-grain fact tables, which is what makes a single timeline drive the whole dashboard.

**Slicer scope is documented honestly rather than papered over.** The category and account
slicers deliberately do *not* filter the KPI tiles, net worth or health score. Those views are
monthly grain with no account or category dimension, and "savings rate for only the SBI account"
is not a defined quantity — income and expenses are classified by category type, not by which
account the money sat in. The guide says so and tells Satayu Dhal to place those slicers next to the
charts they actually control, so the layout does not imply a filter that cannot exist.

**Three known-confusing numbers are pre-explained in the guide**, each with a cell note, so they
read as findings rather than defects:

- Net worth is negative Jun–Oct 2025 (laptop loan with no corresponding asset)
- Loan row 24 closes at −1.98 (EMI rounded to ₹3,457 from ₹3,456.60)
- August 2026 budget variance is +84.38% (the ₹25,000 CCNA exam)

**A provenance note on the About sheet is mandatory, not decorative.** A finance dashboard
published without one invites the reader to assume the balances are real.

## Queries (Phase 7)

```sql
-- Q36: XIRR by NPV bracketing. Excel owns this KPI; this exists only
-- to give the workbook a verification target.
WITH cf AS (
  SELECT cash_flow_date AS d, cash_flow AS a,
         (SELECT MIN(cash_flow_date) FROM vw_investment_cashflows) AS d0
  FROM vw_investment_cashflows
),
rates AS (SELECT 0.12 r UNION SELECT 0.13 UNION SELECT 0.135 UNION SELECT 0.14)
SELECT ROUND(r * 100, 2) AS rate_pct,
       ROUND(SUM(a / POW(1 + r, DATEDIFF(d, d0) / 365)), 2) AS npv
FROM cf CROSS JOIN rates GROUP BY r ORDER BY r;
-- NPV crosses zero between 13.00% (+27.74) and 13.50% (-232.18) -> 13.05%

-- Q37: top expense merchants, the dashboard's top-10 table
SELECT description AS merchant, category_name,
       COUNT(*) AS txns, SUM(amount) AS total
FROM vw_txn_enriched
WHERE direction = 'debit' AND category_type = 'expense'
GROUP BY description, category_name
ORDER BY total DESC LIMIT 10;
```

## Phase 8 notes — ship state

**The SQL half is complete and green.** `sql/00_run_all.sql` rebuilds `finance_db` from an empty
server through six layers and 99 assertions, exiting non-zero on any failure. Last verified
2026-10-13: `ALL TESTS PASS`, 99/99, exit 0.

**Documentation written this phase**

| File | Purpose |
|---|---|
| `README.md` | Pitch, results, Mermaid ERD, setup, SQL techniques, known limitations |
| `docs/FINANCE_PRIMER.md` | Every KPI in plain English, for a reader with no finance background |
| `docs/RESUME_BULLETS.md` | Bullets drawn only from this file, plus the questions they invite |

The ERD is emitted as **Mermaid inside `README.md`**, which GitHub renders natively, rather than
a `docs/erd.png` exported from Workbench. One less binary to keep in sync with the schema.

### Excel workbook — partial

`excel/finance_dashboard.xlsx`, 3.0 MB, 19 sheets. Built and verified:

- Live connection to MySQL, **over ODBC** (see below)
- All 17 views loaded as worksheet tables **and** into the Data Model
  (`xl/model/item.data`)
- Row counts verified against SQL on load: 1,116 / 252 / 234 / 212 / 90 / 54 / 42 / 24 / 18 / 6 / 4 / 1
- **8 Data Model relationships**, all Active, every month-grain fact table joined to
  `vw_monthly_cashflow[month]`: `vw_budget_vs_actual`, `vw_category_monthly`, `vw_health_score`,
  `vw_kpi_monthly`, `vw_month_end_balances`, `vw_net_worth_monthly`, `vw_portfolio_monthly`,
  `vw_txn_enriched`
- **Six PivotCharts on the `Dashboard` sheet**, all from the Data Model:
  1. Income vs expenses vs net cash flow, by month (`vw_kpi_monthly`)
  2. Net worth by month (`vw_net_worth_monthly`) — shows the 2025 dip and recovery to ~202k
  3. Health score by month (`vw_health_score`) — range ~40 to ~96
  4. Spend by category (`vw_category_monthly`) — 14 categories, Rent highest at ~117k
  5. Budget vs actual by category (`vw_budget_vs_actual`)
  6. Portfolio cost basis vs market value by month (`vw_portfolio_monthly`)
- **A month timeline on `vw_monthly_cashflow[month]`**, connected to **all six** charts

The connection is machine-verifiable rather than a claim: `xl/timelineCaches/timelineCache1.xml`
carries `sourceName="[vw_monthly_cashflow].[month]"` and six `<pivotTable>` entries
(`PivotChartTable1` … `PivotChartTable6`).

**The timeline was verified to filter through the relationships, twice.** Setting it to
Aug 2026 reduced chart 1 to income 55,000 / expenses 48,309 / net cash flow 234 — matching
`vw_kpi_monthly` for that month exactly. Setting it to Aug 2025 moved chart 1 *and* the category
chart together (income 23,000, expenses 27,604).

That is the check that matters: the timeline sits on the *one* side of the relationship and the
filter propagates to fact tables on the *many* side. It proves the star schema works end to end,
and it is the acceptance criterion "the slicers filter all charts".

Workbook parts on disk confirm it: `xl/charts/chart1–4.xml`, four `pivotTable*.xml`, five
`pivotCache*` definitions, `timeline1.xml` + `timelineCache1.xml`, and `xl/model/item.data` at
2,875,392 bytes.

**Six KPI tiles on the `Dashboard` sheet** (rows 3–5), each verified against `METRICS.md`:

| Tile | Formula source | Value | Δ vs Aug 2026 |
|---|---|---|---|
| Savings Rate | `vw_kpi_monthly` J | 46.56 | +40.68 |
| Debt-to-Income | `vw_kpi_monthly` L | 5.49 | −0.80 |
| Emergency Fund (mo) | `vw_kpi_monthly` Q | 5.72 | +0.13 |
| Net Worth | `vw_kpi_monthly` AG | 202,249 | +37,690.5 |
| Portfolio XIRR | `XIRR()` over `vw_investment_cashflows` | **0.13053** | n/a |
| Health Score | `vw_health_score` L | 82.82 | +15.19 |

Excel's own `XIRR` returns **13.053%**, matching the NPV-bracketing estimate computed
independently in SQL (Q36, ≈13.05%) to three decimal places. Two different methods, two
different engines, same answer — the strongest single check in the project.

**An `About` sheet** carrying the provenance note ("Synthetic data. NOT real balances."), the
refresh instruction, pointers to `FINANCE_PRIMER.md` and `METRICS.md`, and the reconciliation
identity including the ₹5,091 card arithmetic.

**A top-10 merchants PivotTable** at `Dashboard!A50`, from the Data Model: rows = description,
values = Sum of amount, report filters pinned to `category_type = expense` and
`direction = debit`, with a Top 10 value filter sorted descending. Output matches the SQL
exactly — Rent 1,17,000 · Zomato 43,555 · Swiggy 40,285 · Myntra 33,992 · Amazon Pay 26,435 ·
CCNA exam 25,000 · Blinkit 22,283 · BigBasket 22,104 · Flipkart 21,012 · GitHub 15,120.

**Two slicers:** `category_name` (connected to the spend-by-category chart) and `account_name`
(connected to the merchants table).

The category slicer is deliberately *not* wired to the budget chart. It sits on
`vw_category_monthly[category_name]`, and no category dimension relates that table to
`vw_budget_vs_actual` — both join only to `vw_monthly_cashflow` on month. Connecting them would
look right and filter wrongly. Making it work properly means adding a `dim_category` view in SQL
and a second relationship: a model change, not a click.

**Conditional formatting** on the tiles, per the healthy bands in ARCHITECTURE §5 — 48 rule
entries and 73 differential formats in the package. Emergency Fund displays **amber**, which is
the correct reading: 5.72 months against a 6-month target.

Final workbook: **3.5 MB** — 6 charts, 7 pivot tables, 2 slicers, 1 timeline wired to all six
charts, 6 KPI tiles, conditional formatting, and an About sheet.

Outstanding, all cosmetic: chart and slicer positions overlap in places, and there is an empty
leftover `Sheet1`. `docs/EXCEL_GUIDE.md` covers the layout.

### Typing into Excel: the clipboard is not safe on this machine

The computer-use `type` action keystrokes strings up to ~4 characters directly but switches to a
clipboard paste beyond that. A clipboard manager running on this machine (Wispr Flow) repeatedly
overwrote the clipboard between the write and the paste, so longer strings either pasted
unrelated text ("5 V 40 mm blower fan") or silently did nothing — roughly half the attempts.
Every bad paste was caught by reading the cell back and undone with `Ctrl+Z`.

The workaround that made cell entry reliable: **type every formula in ≤6-character chunks**, so
each `type` stays on the direct-keystroke path and never touches the clipboard. A 33-character
formula becomes six chunks. Slower, but deterministic — and it is the only reason the tiles
exist.

### Techniques that made GUI automation viable

Three findings, after an earlier session failed to create a single relationship:

1. **The Manage Relationships dialog takes ~20 seconds** to load a 2.8 MB Data Model. Earlier
   attempts screenshotted after 5 and concluded nothing had opened.
2. **Dropdown entries render as `Data Model Table: <name>`**, so pressing `d` repeatedly cycles
   through exactly those in alphabetical order, skipping the `Worksheet Table:` duplicates —
   turning an unreliable click into a countable keypress. Column lists respond the same way to
   the first letter (`m` twice reaches `month` past `market_value`).
3. **PivotCharts put a date field in Legend, not Axis**, auto-expanded into a Year/Quarter/Month
   hierarchy. The fix is the field's own dropdown → *Remove Field* on the three generated levels,
   then *Move to Axis Fields* on the remaining one. Adding a measure before the date does not
   prevent it.

### The native MySQL connector does not work; ODBC does

Excel's **Data → Get Data → From Database → From MySQL Database** entry never appears, despite:

| Check | Result |
|---|---|
| Excel platform | x64 |
| `MySql.Data` in GAC | 26.7.0.0 |
| `DbProviderFactories` in 64-bit `machine.config` | registered as `MySql.Data.MySqlClient` |

This is a long-standing, unresolved detection failure
([MySQL bug #79616](https://bugs.mysql.com/bug.php?id=79616), 2015; Microsoft community thread,
2017), and Connector/NET's year-based 26.x versioning likely falls outside the assembly range
Power Query probes. Microsoft's connector documentation names Connector/NET as a prerequisite but
publishes no version requirement.

**Resolution:** MySQL Connector/ODBC 26.7 (64-bit), connected through
*Get Data → From Other Sources → From ODBC* with DSN `(None)` and the connection string

```
Driver={MySQL ODBC 26.7 Unicode Driver};SERVER=localhost;PORT=3306;DATABASE=finance_db;
```

Functionally identical for this project: refresh, Data Model, PivotCharts, slicers and query
folding all behave the same. The **Unicode** driver is required — ANSI mangles the ₹ symbol.
The driver version is embedded in the string, so a driver upgrade means editing it, or switching
to a named DSN.

### Phase 7 is where automation stopped paying

The SQL layers were built end to end from the terminal. The workbook was driven through the Excel
GUI by screenshot automation, which carried the connection and data load but failed repeatedly on
the Data Model relationships: combo dropdowns type-ahead on a single character only, inspecting a
list closes it, `Escape` discards the whole dialog rather than one control, and one mistargeted
click sent keystrokes into the grid and overwrote a column header (caught and undone, verified
restored).

The remaining work is layout, which is faster by hand — and is exactly what `EXCEL_GUIDE.md`
exists for.

## Queries (Phase 8)

```sql
-- Q38: workbook contents, inspected from the shell (an .xlsx is a zip)
--   unzip -l excel/finance_dashboard.xlsx | grep -E "worksheets/sheet|model/item|connections"
-- xl/model/item.data is the tabular Data Model; its presence is what
-- distinguishes a live workbook from a static export.

-- Q39: ODBC drivers registered on the machine (PowerShell)
--   Get-OdbcDriver | Where-Object { $_.Name -like "*MySQL*" }
-- Expect: MySQL ODBC 26.7 Unicode Driver, Platform 64-bit
```
