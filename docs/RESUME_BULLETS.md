# Resume Bullets

**Project author: Satayu Dhal**

Every figure below appears in [`METRICS.md`](METRICS.md) with the query that produced it. Nothing
here is rounded up, estimated, or remembered — if a number cannot be reproduced by running
`sql/00_run_all.sql`, it does not belong on a CV.

Pick **three or four**, not all of them. Match them to the role.

---

## The section, ready to paste

**Personal Finance and Financial Health Analytics Dashboard** | MySQL, Excel (Power Query,
Power Pivot)

- Analysed **1,152 bank, card and wallet transactions across 18 months** to evaluate income,
  expenses, savings and spending patterns, reconciling to **1,116 clean records** after removing
  25 duplicates and rejecting 11 malformed rows.
- Wrote SQL views to aggregate transactions **by category and month** and auto-categorise them
  against 48 keyword rules (**97% coverage**), finding **rent the largest expense at ₹1.17L —
  22.8% of spending and 15.3% of income** — and **food delivery the largest discretionary
  category at ₹83,840 across 215 orders (16.3%)**.
- Calculated **savings rate (31.2%), debt-to-income (7.4%) and expense-to-income (61.5%)** to
  assess financial health; all three sat inside healthy bands, but **emergency-fund coverage
  reached only 5.7 months against a 6-month benchmark** — the single amber indicator on a
  composite health score of **82.8/100**.
- Built an interactive Excel dashboard over the SQL views using **Power Query, a Power Pivot
  data model (8 relationships), 6 PivotCharts, a month timeline and 2 slicers, 6 KPI tiles
  driven by XLOOKUP, and XIRR for portfolio return (13.1%)**, with conditional formatting on
  healthy-band thresholds.

**Do not add Power BI to the tech list.** It was not used. The architecture is deliberately
MySQL for logic and Excel for presentation, and claiming a tool that is not in the repo is the
easiest kind of CV claim for an interviewer to test.

### Where each figure comes from

| Figure | Source |
|---|---|
| 1,152 raw / 1,116 clean / 25 duplicates / 11 rejected | Phase 1–2, Q12 |
| 48 rules, 97.04% coverage | Phase 3, Q17 |
| Rent ₹1,17,000 — 22.8% of expenses, 15.3% of income | Q40 |
| Food delivery ₹83,840, 215 orders, 16.3% | Q40 |
| Savings rate 31.18%, DTI 7.36%, expense-to-income 61.46% (TTM) | Phase 5, Q29 |
| Emergency fund 5.72 months | Phase 5, Q29 |
| Health score 82.82 | Phase 5, Q28 |
| 8 relationships, 6 PivotCharts, 2 slicers, 6 tiles | Phase 8, workbook parts |
| Portfolio XIRR 13.05% | Phase 7, Q36 and Excel `XIRR()` |

```sql
-- Q40: largest expense categories by share of spending and income
SET @inc = (SELECT SUM(income)   FROM vw_kpi_monthly);
SET @exp = (SELECT SUM(expenses) FROM vw_kpi_monthly);

SELECT c.category_name,
       SUM(t.amount)                       AS total,
       ROUND(100 * SUM(t.amount) / @exp, 1) AS pct_of_expenses,
       ROUND(100 * SUM(t.amount) / @inc, 1) AS pct_of_income
FROM vw_txn_enriched t
JOIN categories c ON c.category_id = t.category_id
WHERE t.direction = 'debit' AND t.category_type = 'expense'
GROUP BY c.category_name
ORDER BY total DESC;

-- Food delivery order count behind the 215 figure
SELECT COUNT(*) AS orders, SUM(amount) AS total
FROM vw_txn_enriched
WHERE description IN ('UPI/ZOMATO/FOOD', 'UPI/SWIGGY/FOOD');
```

Full category breakdown, for picking a different angle:

| Category | Total | % of expenses | % of income |
|---|---|---|---|
| Rent | 1,17,000 | 22.8% | 15.3% |
| Food Delivery | 83,840 | 16.3% | 11.0% |
| Shopping | 81,439 | 15.9% | 10.7% |
| Groceries | 59,231 | 11.5% | 7.8% |

---


## For a data analyst role

- Built an 18-month personal-finance analytics stack in **MySQL 8 and Excel only**, where all
  cleaning, categorization and KPI logic lives in SQL views and Excel is a pure presentation
  layer refreshed through Power Query — so a KPI definition exists in exactly one place.
- Cleaned a deliberately messy 1,152-row dataset into **1,116 validated transactions, 11 rejected
  and 25 duplicates removed**, reconciling to the row with an independently cross-checked
  identity.
- Auto-categorized transactions against 48 keyword rules to **97.04% coverage**, tracing all 33
  remaining rows to 4 unmatched merchants and quantifying the available improvement at 99.28%.
- Modelled **15 financial KPIs** across 17 SQL views — savings rate, debt-to-income, emergency-fund
  coverage, budget variance, XIRR and a weighted 0–100 health score — feeding a refreshable Excel
  dashboard.

## For an analytics / data engineering role

- Designed a three-layer warehouse pattern (**staging → core → analytics**) in MySQL 8: raw text
  staging so a malformed row can never break a load, a typed and constrained core, and 17
  Excel-shaped views carrying every KPI definition.
- Wrote a **99-assertion regression suite** covering reconciliation, referential integrity,
  categorization coverage, transfer netting and view executability; the suite raises
  `SQLSTATE 45000` on failure so a broken rebuild exits non-zero instead of looking successful.
- Made the pipeline **provably idempotent** — an MD5 fingerprint over all 1,116 rows is identical
  across repeated runs and full teardowns, including surrogate keys.
- Replaced `STR_TO_DATE`-based validation after finding it raises a **fatal error inside
  `INSERT` under strict `sql_mode`** while only warning inside `SELECT`; rewrote date parsing as
  staged integer arithmetic so the check cannot abort on the very row it exists to catch.
- Benchmarked the two heaviest views and **rejected both candidate indexes** after measuring no
  improvement — at 1,116 rows the table is buffer-pool resident and the cost is CPU on window
  functions, not lookups.

## For a backend / SQL-focused role

- Implemented deduplication with `ROW_NUMBER() OVER (PARTITION BY account, ref_no ORDER BY
  is_valid DESC, raw_id)` to retain the **valid copy** of a duplicated transaction with a stable
  tie-break, and guarded the NULL-key case that would otherwise collapse unrelated rows into one
  partition.
- Built a 24-instalment **loan amortization schedule with a recursive CTE**, closing within ₹2 of
  zero, and asserted `interest + principal = EMI` on every row.
- Detected recurring subscriptions with a **gaps-and-islands** pattern — merchants billing a
  stable amount (±10%) across 3+ consecutive months — identifying all 6 without a hardcoded list.
- Generated a 234-row budget grid (18 months × 13 categories) from a **recursive CTE** with the
  month axis derived from the data, so a longer statement history extends the plan automatically
  rather than leaving months silently unbudgeted.

## Findings worth quoting in an interview

- Reconciled a **₹5,091 closing credit-card balance** to a cleaning decision four layers upstream:
  September card spend of ₹8,157 minus two rows (₹119 and ₹2,947) rejected for unparseable dates,
  which were billed and paid in reality but never reached the clean table.
- Identified that the specified "Subscription Burn" KPI summed **₹8,007/month including rent**,
  and split it into recurring burn versus a ₹1,158 discretionary figure that reflects what is
  actually cancellable.
- Surfaced ₹83,840 of food-delivery spend across **215 orders** in 18 months — the single largest
  discretionary category.

---

## The numbers, and where they come from

| Claim | Value | METRICS.md phase |
|---|---|---|
| Raw rows / clean / rejected / duplicates | 1,152 / 1,116 / 11 / 25 | 1, 2 |
| Categorization coverage | 97.04% | 3 |
| Budget rows | 234 (18 × 13) | 4 |
| Analytics views | 17 | 5 |
| Test assertions | 99, zero failures | 6 |
| Net worth, Sep 2026 | ₹2,02,249.33 | 5 |
| Health score, Sep 2026 | 82.82 / 100 | 5 |
| TTM savings rate | 31.18% | 5 |
| Portfolio XIRR | 13.05% | 7 |
| Card outstanding | ₹5,091 | 5 |
| Loan repaid | 63.53% | 5 |

---

## Before using any of these — questions you must be able to answer

A portfolio project earns nothing if you cannot talk through it. These are the questions this
work invites. [`FINANCE_PRIMER.md`](FINANCE_PRIMER.md) answers the financial ones;
[`METRICS.md`](METRICS.md) answers the technical ones.

1. **"Why is `STR_TO_DATE` not in your pipeline?"** Because under strict `sql_mode` it raises a
   fatal error inside `INSERT` while only warning inside `SELECT` — so the validity check died on
   `31-02-2026`, the exact row it existed to catch. Validation is integer arithmetic instead.
2. **"Why does the card show ₹5,091 and not ₹8,157?"** Two card rows were rejected for bad dates.
   Explain the arithmetic.
3. **"Why is net worth negative in 2025?"** The ₹72,000 laptop loan is a liability from day one,
   but the laptop is not an asset in this model. The formula is right; the model is incomplete.
4. **"Why is XIRR 13.05% when the return is 9.53%?"** SIP money went in gradually, so the average
   rupee was invested well under 18 months.
5. **"Why didn't you add an index?"** Both candidates were benchmarked and neither helped.
6. **"What did you do about rows you couldn't categorize?"** Three of four merchants could be
   matched with new rules; the fourth is a masked UPI handle that genuinely cannot be identified,
   and inventing a category would improve the metric while degrading the data.
7. **"What would you do differently?"** Port the views to dbt — the assertions map almost directly
   onto dbt tests — and carry loan-financed purchases as depreciating assets so net worth reflects
   a complete balance sheet.

If any of those answers are not yours yet, read the primer before the interview, not after.
