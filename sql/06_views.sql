-- ============================================================
-- 06_views.sql — the analytics layer. Re-runnable.
--   mysql --login-path=finance finance_db < sql/06_views.sql
--
-- 17 views, built bottom-up so each only depends on earlier ones:
--   enriched base -> cashflow/category -> balances -> loan
--   -> portfolio -> net worth -> KPIs -> health score -> QA
--
-- Excel contract (CLAUDE.md): one row per month (or month x category),
-- `month` is a real DATE on the 1st, every numeric column is
-- COALESCEd so Power Query never sees NULL, names are snake_case.
--
-- SIGN CONVENTION, fixed here once and relied on everywhere:
--   signed_amount = +amount for a credit, -amount for a debit.
-- For a credit card that means spending drives the balance NEGATIVE
-- and a payment moves it back towards zero, so the amount owed is
-- -balance. The shipped data closes at -5091.00 on the card, i.e.
-- 5,091 outstanding. Getting this backwards silently inverts net
-- worth, so vw_net_worth_monthly negates in exactly one place.
-- ============================================================
USE finance_db;

-- ------------------------------------------------------------
-- 1. vw_txn_enriched — one row per transaction, everything
--    downstream needs, resolved once.
--
-- Uncategorized DEBITS are reported as expenses in the
-- "Uncategorized" bucket (CLAUDE.md). The bucket lives here in the
-- analytics layer, not in `transactions`, so the core table keeps
-- recording only what is actually known.
--
-- Uncategorized CREDITS would fall to income. There are none, and
-- 90_tests.sql asserts that, so the branch is a safe default rather
-- than a silent guess.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_txn_enriched AS
SELECT t.txn_id,
       t.txn_date,
       CAST(DATE_FORMAT(t.txn_date, '%Y-%m-01') AS DATE)              AS month,
       t.account_id,
       a.account_name,
       a.account_type,
       t.description,
       t.amount,
       t.direction,
       CASE WHEN t.direction = 'credit' THEN t.amount ELSE -t.amount END AS signed_amount,
       COALESCE(t.category_id, 0)                                     AS category_id,
       COALESCE(c.category_name, 'Uncategorized')                     AS category_name,
       COALESCE(c.category_type,
                CASE WHEN t.direction = 'debit' THEN 'expense' ELSE 'income' END) AS category_type,
       COALESCE(c.is_essential, FALSE)                                AS is_essential,
       t.ref_no
FROM transactions t
JOIN accounts a       ON a.account_id  = t.account_id
LEFT JOIN categories c ON c.category_id = t.category_id;

-- ------------------------------------------------------------
-- 2. vw_monthly_cashflow — the KPI numerators and denominators.
--    Transfers are excluded from every total here (they are only
--    reported, in transfers_excluded, so the dashboard can show how
--    much was moved without it touching a ratio).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_cashflow AS
SELECT month,
       COALESCE(SUM(CASE WHEN category_type = 'income'     AND direction = 'credit' THEN amount END), 0) AS income,
       COALESCE(SUM(CASE WHEN category_type = 'expense'    AND direction = 'debit'  THEN amount END), 0) AS expenses,
       COALESCE(SUM(CASE WHEN category_type = 'expense'    AND direction = 'debit'
                          AND is_essential                 THEN amount END), 0)                         AS essential_expenses,
       COALESCE(SUM(CASE WHEN category_type = 'debt'       AND direction = 'debit'  THEN amount END), 0) AS debt_service,
       COALESCE(SUM(CASE WHEN category_type = 'investment' AND direction = 'debit'  THEN amount END), 0) AS invested,
       COALESCE(SUM(CASE WHEN category_type = 'transfer'   AND direction = 'debit'  THEN amount END), 0) AS transfers_excluded,
       COALESCE(SUM(CASE WHEN category_name = 'Uncategorized' AND direction = 'debit' THEN amount END), 0) AS uncategorized_spend,
       COALESCE(SUM(CASE WHEN category_type = 'income'     AND direction = 'credit' THEN amount END), 0)
     - COALESCE(SUM(CASE WHEN category_type = 'expense'    AND direction = 'debit'  THEN amount END), 0)
     - COALESCE(SUM(CASE WHEN category_type = 'debt'       AND direction = 'debit'  THEN amount END), 0)
     - COALESCE(SUM(CASE WHEN category_type = 'investment' AND direction = 'debit'  THEN amount END), 0) AS net_cash_flow
FROM vw_txn_enriched
GROUP BY month;

-- ------------------------------------------------------------
-- 3. vw_category_monthly — spend per category per month, plus each
--    category's share of that month (window aggregate over an
--    aggregate: SUM(SUM(..)) OVER (PARTITION BY month)).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_category_monthly AS
SELECT month,
       category_id,
       category_name,
       is_essential,
       COUNT(*)                   AS txn_count,
       COALESCE(SUM(amount), 0)   AS amount,
       COALESCE(ROUND(100.0 * SUM(amount)
                / NULLIF(SUM(SUM(amount)) OVER (PARTITION BY month), 0), 2), 0) AS share_of_month_pct
FROM vw_txn_enriched
WHERE category_type = 'expense' AND direction = 'debit'
GROUP BY month, category_id, category_name, is_essential;

-- ------------------------------------------------------------
-- 4. vw_mom_change — month-over-month movement per category.
--
-- The grid is densified first. Without it LAG() would step over a
-- month in which a category had no spend and compare, say, March to
-- January while labelling the result "month over month". Entertainment
-- has 4 transactions in 18 months, so the gaps are real.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mom_change AS
WITH grid AS (
  SELECT m.month, c.category_id, c.category_name
  FROM      (SELECT DISTINCT month FROM vw_category_monthly) m
  CROSS JOIN (SELECT DISTINCT category_id, category_name FROM vw_category_monthly) c
),
dense AS (
  SELECT g.month, g.category_id, g.category_name,
         COALESCE(v.amount, 0) AS amount
  FROM grid g
  LEFT JOIN vw_category_monthly v
         ON v.month = g.month AND v.category_id = g.category_id
)
SELECT month,
       category_id,
       category_name,
       amount,
       COALESCE(LAG(amount) OVER w, 0)                AS prev_amount,
       amount - COALESCE(LAG(amount) OVER w, 0)       AS change_amount,
       COALESCE(ROUND(100.0 * (amount - LAG(amount) OVER w)
                / NULLIF(LAG(amount) OVER w, 0), 2), 0) AS change_pct
FROM dense
WINDOW w AS (PARTITION BY category_id ORDER BY month);

-- ------------------------------------------------------------
-- 5. vw_budget_vs_actual — plan against reality.
--
-- The actual side is aggregated to (month, category) BEFORE the join.
-- Joining budgets straight to transactions would fan every
-- transaction across the 18 budget rows for its category and inflate
-- every actual 18x.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_budget_vs_actual AS
SELECT b.budget_month                                   AS month,
       b.category_id,
       c.category_name,
       b.budget_amount                                  AS budget,
       COALESCE(a.actual, 0)                            AS actual,
       COALESCE(a.actual, 0) - b.budget_amount          AS variance,
       COALESCE(ROUND(100.0 * (COALESCE(a.actual, 0) - b.budget_amount)
                / NULLIF(b.budget_amount, 0), 2), 0)    AS variance_pct,
       CASE WHEN COALESCE(a.actual, 0) >  b.budget_amount        THEN 'Over'
            WHEN COALESCE(a.actual, 0) >= b.budget_amount * 0.90 THEN 'On track'
            ELSE 'Under' END                            AS status
FROM budgets b
JOIN categories c ON c.category_id = b.category_id
LEFT JOIN (
  SELECT month, category_id, SUM(amount) AS actual
  FROM vw_category_monthly
  GROUP BY month, category_id
) a ON a.month = b.budget_month AND a.category_id = b.category_id;

-- ------------------------------------------------------------
-- 6. vw_account_balances — running balance per account per
--    transaction. Transfers ARE included: they are excluded from the
--    KPI ratios, but a balance that ignored them would be wrong.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_account_balances AS
SELECT t.account_id,
       t.account_name,
       t.account_type,
       t.txn_date,
       t.month,
       t.txn_id,
       t.description,
       t.amount,
       t.direction,
       t.signed_amount,
       a.opening_balance
     + SUM(t.signed_amount) OVER (PARTITION BY t.account_id
                                  ORDER BY t.txn_date, t.txn_id
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_balance
FROM vw_txn_enriched t
JOIN accounts a ON a.account_id = t.account_id;

-- ------------------------------------------------------------
-- 7. vw_month_end_balances — closing balance per account per month.
--
-- Built as a full account x month grid carrying forward the last
-- known balance, rather than picking the final row of each month.
-- Every account transacts in all 18 months of the shipped data, so
-- the two agree today; real statements in Phase 9 will have quiet
-- months, and the grid version reports the balance carried into them
-- instead of dropping the row and breaking net worth.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_month_end_balances AS
SELECT g.month,
       g.account_id,
       g.account_name,
       g.account_type,
       COALESCE((SELECT b.running_balance
                   FROM vw_account_balances b
                  WHERE b.account_id = g.account_id
                    AND b.txn_date <= LAST_DAY(g.month)
                  ORDER BY b.txn_date DESC, b.txn_id DESC
                  LIMIT 1), g.opening_balance) AS month_end_balance
FROM (
  SELECT m.month, a.account_id, a.account_name, a.account_type, a.opening_balance
  FROM      (SELECT DISTINCT month FROM vw_monthly_cashflow) m
  CROSS JOIN accounts a
) g;

-- ------------------------------------------------------------
-- 8. vw_recurring_payments — subscriptions and EMIs, detected rather
--    than listed.
--
-- A merchant qualifies on >= 3 CONSECUTIVE months with the amount
-- stable inside +/-10%. Consecutive runs are found with gaps-and-
-- islands: turn each month into an integer, subtract its row number
-- within the merchant, and every unbroken run collapses to a constant
-- group key. The longest qualifying run per merchant is reported.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_recurring_payments AS
WITH monthly AS (
  SELECT description AS merchant, category_name, month, SUM(amount) AS amount
  FROM vw_txn_enriched
  WHERE direction = 'debit'
    AND category_type IN ('expense', 'debt')
  GROUP BY description, category_name, month
),
islands AS (
  SELECT merchant, category_name, month, amount,
         PERIOD_DIFF(DATE_FORMAT(month, '%Y%m'), '200001')
       - ROW_NUMBER() OVER (PARTITION BY merchant ORDER BY month) AS run_key
  FROM monthly
),
runs AS (
  SELECT merchant, category_name, run_key,
         COUNT(*)      AS months_in_run,
         MIN(month)    AS first_month,
         MAX(month)    AS last_month,
         ROUND(AVG(amount), 2) AS avg_amount,
         MIN(amount)   AS min_amount,
         MAX(amount)   AS max_amount
  FROM islands
  GROUP BY merchant, category_name, run_key
  HAVING COUNT(*) >= 3
     AND MAX(amount) <= MIN(amount) * 1.10
),
ranked AS (
  SELECT r.*, ROW_NUMBER() OVER (PARTITION BY merchant
                                 ORDER BY months_in_run DESC, first_month) AS rn
  FROM runs r
)
SELECT merchant,
       category_name,
       months_in_run,
       first_month,
       last_month,
       avg_amount,
       min_amount,
       max_amount,
       CASE WHEN merchant LIKE '%EMI%' THEN 1 ELSE 0 END AS is_emi
FROM ranked
WHERE rn = 1;

-- ------------------------------------------------------------
-- 9. vw_loan_schedule — amortization by RECURSIVE CTE.
--
-- Each installment: interest = opening x annual_rate/12, principal
-- repaid = EMI - interest, closing = opening - principal repaid. The
-- recursion carries the closing balance into the next row and stops
-- at tenure_months. 24 rows for the shipped laptop loan, closing
-- within a few rupees of zero because the EMI is rounded to 3457.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_loan_schedule AS
WITH RECURSIVE sched AS (
  SELECT l.loan_id,
         l.lender,
         l.annual_rate,
         l.tenure_months,
         l.emi_amount,
         1                                                             AS installment_no,
         l.start_date                                                  AS due_date,
         l.principal                                                   AS opening_balance,
         ROUND(l.principal * l.annual_rate / 1200, 2)                  AS interest,
         ROUND(l.emi_amount - l.principal * l.annual_rate / 1200, 2)   AS principal_paid,
         ROUND(l.principal
               - (l.emi_amount - l.principal * l.annual_rate / 1200), 2) AS closing_balance
  FROM loans l
  UNION ALL
  SELECT s.loan_id,
         s.lender,
         s.annual_rate,
         s.tenure_months,
         s.emi_amount,
         s.installment_no + 1,
         s.due_date + INTERVAL 1 MONTH,
         s.closing_balance,
         ROUND(s.closing_balance * s.annual_rate / 1200, 2),
         ROUND(s.emi_amount - s.closing_balance * s.annual_rate / 1200, 2),
         ROUND(s.closing_balance
               - (s.emi_amount - s.closing_balance * s.annual_rate / 1200), 2)
  FROM sched s
  WHERE s.installment_no < s.tenure_months
)
SELECT loan_id,
       lender,
       installment_no,
       due_date,
       CAST(DATE_FORMAT(due_date, '%Y-%m-01') AS DATE) AS month,
       opening_balance,
       emi_amount,
       interest,
       principal_paid,
       closing_balance
FROM sched;

-- ------------------------------------------------------------
-- 10. vw_portfolio_monthly — cost basis vs market value per holding.
--
-- Buys are matched to a holding through investments.txn_keyword
-- against the normalized description. The month grid is densified so
-- a holding keeps reporting its cost basis in months with no SIP, and
-- cost basis accumulates with a running SUM() rather than being
-- recomputed per month.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_portfolio_monthly AS
WITH buys AS (
  SELECT i.investment_id, t.month, SUM(t.amount) AS invested
  FROM vw_txn_enriched t
  JOIN investments i ON t.description LIKE CONCAT('%', i.txn_keyword, '%')
  WHERE t.direction = 'debit'
  GROUP BY i.investment_id, t.month
),
grid AS (
  SELECT m.month, i.investment_id, i.instrument_name, i.instrument_type, i.platform
  FROM      (SELECT DISTINCT month FROM vw_monthly_cashflow) m
  CROSS JOIN investments i
),
cum AS (
  SELECT g.month, g.investment_id, g.instrument_name, g.instrument_type, g.platform,
         COALESCE(b.invested, 0) AS invested_this_month,
         SUM(COALESCE(b.invested, 0)) OVER (PARTITION BY g.investment_id
                                            ORDER BY g.month
                                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cost_basis
  FROM grid g
  LEFT JOIN buys b ON b.investment_id = g.investment_id AND b.month = g.month
)
SELECT c.month,
       c.investment_id,
       c.instrument_name,
       c.instrument_type,
       c.platform,
       c.invested_this_month,
       c.cost_basis,
       COALESCE(v.units_held, 0)                                   AS units_held,
       COALESCE(v.nav, 0)                                          AS nav,
       COALESCE(v.market_value, 0)                                 AS market_value,
       COALESCE(v.market_value, 0) - c.cost_basis                  AS unrealized_gain,
       COALESCE(ROUND(100.0 * (COALESCE(v.market_value, 0) - c.cost_basis)
                / NULLIF(c.cost_basis, 0), 2), 0)                  AS return_pct
FROM cum c
LEFT JOIN investment_valuations v
       ON v.investment_id = c.investment_id
      AND v.valuation_date = LAST_DAY(c.month);

-- ------------------------------------------------------------
-- 11. vw_investment_cashflows — feeds Excel's XIRR().
-- Buys are negative (money leaving), the latest valuation of each
-- holding is a positive terminal inflow.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_investment_cashflows AS
SELECT t.txn_date          AS cash_flow_date,
       i.instrument_name,
       i.instrument_type,
       -t.amount           AS cash_flow,
       'buy'               AS flow_type
FROM vw_txn_enriched t
JOIN investments i ON t.description LIKE CONCAT('%', i.txn_keyword, '%')
WHERE t.direction = 'debit'
UNION ALL
SELECT v.valuation_date,
       i.instrument_name,
       i.instrument_type,
       v.market_value,
       'valuation'
FROM investment_valuations v
JOIN investments i ON i.investment_id = v.investment_id
WHERE v.valuation_date = (SELECT MAX(v2.valuation_date)
                            FROM investment_valuations v2
                           WHERE v2.investment_id = v.investment_id);

-- ------------------------------------------------------------
-- 12. vw_net_worth_monthly — liquid + investments - card - loan.
--
-- card_outstanding negates the card balance in THIS ONE PLACE. Under
-- the sign convention a card balance is <= 0, so -balance is the
-- amount owed and subtracting it reduces net worth.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_net_worth_monthly AS
WITH liq AS (
  SELECT month,
         COALESCE(SUM(CASE WHEN account_type IN ('savings','wallet','cash','current')
                           THEN month_end_balance END), 0)  AS liquid_balance,
         COALESCE(-SUM(CASE WHEN account_type = 'credit_card'
                            THEN month_end_balance END), 0) AS card_outstanding
  FROM vw_month_end_balances
  GROUP BY month
),
inv AS (
  SELECT month, COALESCE(SUM(market_value), 0) AS investment_value
  FROM vw_portfolio_monthly GROUP BY month
),
lo AS (
  SELECT month, COALESCE(SUM(closing_balance), 0) AS loan_outstanding
  FROM vw_loan_schedule GROUP BY month
)
SELECT l.month,
       l.liquid_balance,
       COALESCE(i.investment_value, 0)   AS investment_value,
       l.card_outstanding,
       COALESCE(lo.loan_outstanding, 0)  AS loan_outstanding,
       l.liquid_balance
     + COALESCE(i.investment_value, 0)
     - l.card_outstanding
     - COALESCE(lo.loan_outstanding, 0)  AS net_worth
FROM liq l
LEFT JOIN inv i  ON i.month  = l.month
LEFT JOIN lo     ON lo.month = l.month;

-- ------------------------------------------------------------
-- 13. vw_kpi_monthly — the dashboard feed. One row per month,
--     every KPI from ARCHITECTURE.md section 5.
--
-- Every ratio divides through NULLIF(x, 0) and is then COALESCEd, so
-- a month with no income yields 0 rather than NULL or a division
-- error.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_kpi_monthly AS
WITH ess AS (
  SELECT month,
         essential_expenses + debt_service AS essential_outflow,
         AVG(essential_expenses + debt_service) OVER (ORDER BY month
                                                      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
           AS avg3_essential_outflow
  FROM vw_monthly_cashflow
),
adh AS (
  SELECT month,
         COUNT(*)                                        AS budgeted_categories,
         SUM(actual <= budget)                           AS categories_within_budget,
         COALESCE(ROUND(100.0 * SUM(actual <= budget) / NULLIF(COUNT(*), 0), 2), 0)
                                                         AS budget_adherence_pct,
         SUM(budget)                                     AS budget_total,
         SUM(actual)                                     AS actual_total
  FROM vw_budget_vs_actual
  GROUP BY month
),
subs AS (
  -- recurring_burn is every detected non-EMI recurring payment, the
  -- literal ARCHITECTURE.md KPI 10. subscription_burn narrows that to
  -- NON-ESSENTIAL ones: rent and the phone recharge recur every month
  -- but nobody calls them subscriptions, and the actionable number is
  -- the discretionary one you could actually cancel.
  SELECT t.month,
         COALESCE(SUM(t.amount), 0)                                      AS recurring_burn,
         COALESCE(SUM(CASE WHEN t.is_essential = 0 THEN t.amount END), 0) AS subscription_burn
  FROM vw_txn_enriched t
  JOIN (SELECT merchant FROM vw_recurring_payments WHERE is_emi = 0) r
    ON r.merchant = t.description
  WHERE t.direction = 'debit'
  GROUP BY t.month
),
port AS (
  SELECT month,
         COALESCE(SUM(cost_basis), 0)   AS investment_cost_basis,
         COALESCE(SUM(market_value), 0) AS investment_market_value
  FROM vw_portfolio_monthly GROUP BY month
),
loan AS (
  SELECT s.month,
         COALESCE(SUM(s.closing_balance), 0) AS loan_outstanding,
         COALESCE(ROUND(100.0 * SUM(l.principal - s.closing_balance)
                  / NULLIF(SUM(l.principal), 0), 2), 0) AS loan_payoff_pct
  FROM vw_loan_schedule s
  JOIN loans l ON l.loan_id = s.loan_id
  GROUP BY s.month
)
SELECT cf.month,
       -- cash flow
       cf.income,
       cf.expenses,
       cf.essential_expenses,
       cf.debt_service,
       cf.invested,
       cf.transfers_excluded,
       cf.uncategorized_spend,
       cf.net_cash_flow,
       -- ratios
       COALESCE(ROUND(100.0 * (cf.income - cf.expenses - cf.debt_service)
                / NULLIF(cf.income, 0), 2), 0)                      AS savings_rate_pct,
       COALESCE(ROUND(100.0 * cf.expenses     / NULLIF(cf.income, 0), 2), 0) AS expense_to_income_pct,
       COALESCE(ROUND(100.0 * cf.debt_service / NULLIF(cf.income, 0), 2), 0) AS dti_pct,
       COALESCE(ROUND(100.0 * cf.invested     / NULLIF(cf.income, 0), 2), 0) AS investment_rate_pct,
       COALESCE(ROUND(100.0 * cf.essential_expenses
                / NULLIF(cf.expenses, 0), 2), 0)                    AS essential_share_pct,
       -- liquidity
       COALESCE(nw.liquid_balance, 0)                               AS liquid_balance,
       COALESCE(ROUND(e.avg3_essential_outflow, 2), 0)              AS avg3_essential_outflow,
       COALESCE(ROUND(nw.liquid_balance
                / NULLIF(e.avg3_essential_outflow, 0), 2), 0)       AS emergency_months,
       -- budget
       COALESCE(adh.budget_total, 0)                                AS budget_total,
       COALESCE(adh.actual_total, 0)                                AS budget_actual_total,
       COALESCE(ROUND(100.0 * (adh.actual_total - adh.budget_total)
                / NULLIF(adh.budget_total, 0), 2), 0)               AS budget_variance_pct,
       COALESCE(adh.budgeted_categories, 0)                         AS budgeted_categories,
       COALESCE(adh.categories_within_budget, 0)                    AS categories_within_budget,
       COALESCE(adh.budget_adherence_pct, 0)                        AS budget_adherence_pct,
       -- trend and burn
       COALESCE(ROUND(100.0 * (cf.expenses - LAG(cf.expenses) OVER (ORDER BY cf.month))
                / NULLIF(LAG(cf.expenses) OVER (ORDER BY cf.month), 0), 2), 0)
                                                                    AS mom_expense_growth_pct,
       COALESCE(s.recurring_burn, 0)                                AS recurring_burn,
       COALESCE(s.subscription_burn, 0)                             AS subscription_burn,
       -- investments
       COALESCE(p.investment_cost_basis, 0)                         AS investment_cost_basis,
       COALESCE(p.investment_market_value, 0)                       AS investment_market_value,
       COALESCE(ROUND(100.0 * (p.investment_market_value - p.investment_cost_basis)
                / NULLIF(p.investment_cost_basis, 0), 2), 0)        AS investment_return_pct,
       -- debt and net worth
       COALESCE(l.loan_outstanding, 0)                              AS loan_outstanding,
       COALESCE(l.loan_payoff_pct, 0)                               AS loan_payoff_pct,
       COALESCE(nw.card_outstanding, 0)                             AS card_outstanding,
       COALESCE(nw.net_worth, 0)                                    AS net_worth
FROM vw_monthly_cashflow cf
LEFT JOIN ess  e   ON e.month   = cf.month
LEFT JOIN adh      ON adh.month = cf.month
LEFT JOIN subs s   ON s.month   = cf.month
LEFT JOIN port p   ON p.month   = cf.month
LEFT JOIN loan l   ON l.month   = cf.month
LEFT JOIN vw_net_worth_monthly nw ON nw.month = cf.month;

-- ------------------------------------------------------------
-- 14. vw_health_score — weighted 0-100, per ARCHITECTURE.md
--     section 5. Each component is clamped to 0..1 with
--     GREATEST/LEAST, then weighted:
--       savings 25  (full at >=20%, zero at <=0%)
--       DTI     20  (full at <=10%, zero at >=40%)
--       buffer  25  (full at >=6 months, zero at 0)
--       invest  15  (full at >=15%, zero at 0%)
--       budget  15  (share of categories at or under budget)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_health_score AS
SELECT month,
       savings_rate_pct,
       dti_pct,
       emergency_months,
       investment_rate_pct,
       budget_adherence_pct,
       ROUND(25 * LEAST(1, GREATEST(0, savings_rate_pct      / 20)), 2) AS pts_savings_rate,
       ROUND(20 * LEAST(1, GREATEST(0, (40 - dti_pct)        / 30)), 2) AS pts_dti,
       ROUND(25 * LEAST(1, GREATEST(0, emergency_months      /  6)), 2) AS pts_emergency_fund,
       ROUND(15 * LEAST(1, GREATEST(0, investment_rate_pct   / 15)), 2) AS pts_investment_rate,
       ROUND(15 * LEAST(1, GREATEST(0, budget_adherence_pct  / 100)), 2) AS pts_budget_adherence,
       ROUND(25 * LEAST(1, GREATEST(0, savings_rate_pct      / 20))
           + 20 * LEAST(1, GREATEST(0, (40 - dti_pct)        / 30))
           + 25 * LEAST(1, GREATEST(0, emergency_months      /  6))
           + 15 * LEAST(1, GREATEST(0, investment_rate_pct   / 15))
           + 15 * LEAST(1, GREATEST(0, budget_adherence_pct  / 100)), 2) AS health_score
FROM vw_kpi_monthly;

-- ------------------------------------------------------------
-- 15. vw_kpi_summary — one row for the dashboard tiles.
--
-- Trailing-12-month ratios are computed from SUMS, not as the average
-- of twelve monthly ratios: averaging ratios weights a month with
-- 8,000 of income the same as one with 60,000 and quietly overstates
-- a lumpy freelance year.
--
-- Defined after vw_health_score because it reads the latest score.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_kpi_summary AS
WITH b AS (
  SELECT MAX(month) AS last_month FROM vw_kpi_monthly
),
ttm AS (
  SELECT COALESCE(SUM(k.income), 0)       AS income,
         COALESCE(SUM(k.expenses), 0)     AS expenses,
         COALESCE(SUM(k.debt_service), 0) AS debt_service,
         COALESCE(SUM(k.invested), 0)     AS invested,
         COALESCE(SUM(k.net_cash_flow), 0) AS net_cash_flow
  FROM vw_kpi_monthly k, b
  WHERE k.month >= b.last_month - INTERVAL 11 MONTH
),
alltime AS (
  SELECT COALESCE(SUM(income), 0)        AS income,
         COALESCE(SUM(expenses), 0)      AS expenses,
         COALESCE(SUM(debt_service), 0)  AS debt_service,
         COALESCE(SUM(invested), 0)      AS invested,
         COALESCE(SUM(net_cash_flow), 0) AS net_cash_flow,
         COUNT(*)                        AS months_covered
  FROM vw_kpi_monthly
),
latest AS (
  SELECT k.* FROM vw_kpi_monthly k, b WHERE k.month = b.last_month
),
latest_score AS (
  SELECT h.health_score FROM vw_health_score h, b WHERE h.month = b.last_month
)
SELECT (SELECT last_month FROM b)                                       AS as_of_month,
       a.months_covered,
       -- trailing twelve months
       t.income                                                         AS ttm_income,
       t.expenses                                                       AS ttm_expenses,
       t.debt_service                                                   AS ttm_debt_service,
       t.invested                                                       AS ttm_invested,
       t.net_cash_flow                                                  AS ttm_net_cash_flow,
       COALESCE(ROUND(100.0 * (t.income - t.expenses - t.debt_service)
                / NULLIF(t.income, 0), 2), 0)                           AS ttm_savings_rate_pct,
       COALESCE(ROUND(100.0 * t.expenses     / NULLIF(t.income, 0), 2), 0) AS ttm_expense_to_income_pct,
       COALESCE(ROUND(100.0 * t.debt_service / NULLIF(t.income, 0), 2), 0) AS ttm_dti_pct,
       COALESCE(ROUND(100.0 * t.invested     / NULLIF(t.income, 0), 2), 0) AS ttm_investment_rate_pct,
       -- all time
       a.income                                                         AS alltime_income,
       a.expenses                                                       AS alltime_expenses,
       a.net_cash_flow                                                  AS alltime_net_cash_flow,
       COALESCE(ROUND(100.0 * (a.income - a.expenses - a.debt_service)
                / NULLIF(a.income, 0), 2), 0)                           AS alltime_savings_rate_pct,
       -- latest month snapshot, for the tiles
       l.liquid_balance                                                 AS latest_liquid_balance,
       l.emergency_months                                               AS latest_emergency_months,
       l.investment_cost_basis                                          AS latest_investment_cost_basis,
       l.investment_market_value                                        AS latest_investment_market_value,
       l.investment_return_pct                                          AS latest_investment_return_pct,
       l.card_outstanding                                               AS latest_card_outstanding,
       l.loan_outstanding                                               AS latest_loan_outstanding,
       l.loan_payoff_pct                                                AS latest_loan_payoff_pct,
       l.recurring_burn                                                 AS latest_recurring_burn,
       l.subscription_burn                                              AS latest_subscription_burn,
       l.net_worth                                                      AS latest_net_worth,
       COALESCE((SELECT health_score FROM latest_score), 0)             AS latest_health_score
FROM ttm t, alltime a, latest l;

-- ------------------------------------------------------------
-- 16. vw_data_quality — the reconciliation story, one row, so the
--     dashboard can state plainly what was dropped and why.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_data_quality AS
SELECT (SELECT COUNT(*) FROM raw_transactions)                                  AS raw_rows,
       (SELECT COUNT(*) FROM transactions)                                      AS clean_rows,
       (SELECT COUNT(*) FROM transactions_rejected)                             AS rejected_rows,
       (SELECT COUNT(*) FROM raw_transactions)
     - (SELECT COUNT(*) FROM transactions)
     - (SELECT COUNT(*) FROM transactions_rejected)                             AS duplicate_rows,
       (SELECT COUNT(*) FROM transactions WHERE category_id IS NOT NULL)        AS categorized_rows,
       (SELECT COUNT(*) FROM transactions WHERE category_id IS NULL)            AS uncategorized_rows,
       COALESCE(ROUND(100.0 * (SELECT COUNT(*) FROM transactions WHERE category_id IS NOT NULL)
                / NULLIF((SELECT COUNT(*) FROM transactions), 0), 2), 0)        AS coverage_pct,
       (SELECT COUNT(*) FROM transactions_rejected WHERE reason = 'bad_date')       AS rejected_bad_date,
       (SELECT COUNT(*) FROM transactions_rejected WHERE reason = 'missing_amount') AS rejected_missing_amount,
       (SELECT COUNT(*) FROM investment_valuations)                             AS valuation_rows,
       (SELECT COUNT(*) FROM vw_uncategorized_review)                           AS uncategorized_merchants;

-- 17. vw_uncategorized_review is created in 04_categorize.sql, where
--     the rules that leave it non-empty are defined.

-- ---------- view inventory ----------
SELECT TABLE_NAME AS view_name
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'finance_db'
ORDER BY TABLE_NAME;
