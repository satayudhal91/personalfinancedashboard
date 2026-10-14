# Finance Primer

What every number in this project means, in plain English, and why it is calculated the way it
is. No finance background assumed.

`ARCHITECTURE.md` §5 holds the formulas. This file explains the *reasoning* — which is what you
need to answer "why did you define it that way?"

---

## 1. The vocabulary

**Debit and credit.** From the account holder's point of view: a **debit** is money leaving an
account, a **credit** is money arriving. Bank statements show them in separate columns, which
is why the raw CSV has a `debit` and a `credit` column and only ever one is filled.

**The four kinds of money movement.** Every transaction is classified into exactly one:

| Type | Meaning | Examples here |
|---|---|---|
| **Income** | Money entering your finances from outside | Freelance invoices, stipend, family support, interest |
| **Expense** | Money leaving and not coming back | Rent, groceries, food delivery, subscriptions |
| **Investment** | Money moved into an asset — still yours, just not cash | SIPs, stock purchases, the fixed deposit |
| **Debt** | Repaying borrowed money | The laptop loan EMI |
| **Transfer** | Money moving between your *own* accounts | Paying the credit card, topping up the wallet |

**Why transfers must be excluded from everything.** This is the single most important idea in
the project. If you move ₹10,000 from your savings account to pay your credit card, nothing has
actually happened to your wealth — you have less cash and less debt, netting to zero. But the
raw data records it twice: a debit on savings and a credit on the card.

Count that as spending and you have invented ₹10,000 of expenses that never existed. Over 18
months this dataset moves ₹1,46,235 in card payments alone. Including them would inflate
reported expenses by roughly 28% and make every ratio wrong.

So transfers are excluded from every KPI — and the project *proves* it rather than claiming it:
both legs of every transfer are summed and must net to exactly ₹0.00. A test enforces this.

**Essential vs discretionary.** Rent, groceries, utilities, transport, health and education are
flagged essential — things you cannot stop paying next month. Food delivery, shopping,
subscriptions and entertainment are discretionary. This distinction drives two KPIs and is the
difference between "how much do I spend" and "how much could I stop spending".

---

## 2. The KPIs

### Savings Rate — `(income − expenses − debt_service) ÷ income`

**What it means.** The share of what you earned that you did not have to spend. The headline
measure of whether your finances work.

**Why it's defined this way.** Investments are deliberately *not* subtracted. Money you put
into a mutual fund is still yours — it is saving, not spending. Debt repayment *is* subtracted,
because that money is genuinely gone.

**Good:** ≥ 20%. **This dataset:** 31.18% over the trailing twelve months.

### Expense-to-Income — `expenses ÷ income`

**What it means.** The mirror image, and often easier to grasp: 61.46% means roughly 61 paise of
every rupee earned went on living costs.

**Good:** ≤ 70%.

### Debt-to-Income (DTI) — `debt_service ÷ income`

**What it means.** The share of income committed to loan repayments before you do anything else.
Lenders use this to decide if you can afford to borrow more.

**Why it matters.** It measures *fragility*. High DTI means a drop in income immediately becomes
a missed payment, because EMIs do not pause when your invoices do.

**Good:** ≤ 15%, concerning above 35%. **This dataset:** 7.36% — comfortable.

### Investment Rate — `invested ÷ income`

**What it means.** The share of income being converted into assets. Distinct from savings rate:
you can have a high savings rate and still leave everything sitting in a current account doing
nothing.

**Good:** ≥ 10%. **This dataset:** 12.11%.

### Net Cash Flow — `income − expenses − debt_service − invested`

**What it means.** Actual cash left at month end after everything, including investing.
Can legitimately be negative in a month you invested heavily.

### Essential Spend Share — `essential expenses ÷ total expenses`

**What it means.** How much of your spending is unavoidable. A low share looks like discipline
but means little room to cut in a bad month; a very high share means you are already at the
floor.

**Healthy:** roughly 50–60%.

### Emergency Fund Coverage — `liquid balance ÷ average monthly essential outflow`

**What it means.** How many months you could survive with zero income, expressed in months
rather than rupees — because ₹1,00,000 means something very different to someone spending
₹10,000 a month than to someone spending ₹50,000.

**Why the denominator is a 3-month average.** A single month is too noisy. And it counts only
essentials *plus debt service*, because in a genuine emergency you stop ordering food delivery
but the rent and the EMI still arrive.

**Good:** ≥ 6 months. **This dataset:** 5.72 — nearly there.

### Budget Variance — `(actual − budget) ÷ budget`

**What it means.** How far spending ran from plan. Negative is good: under budget.

**Watch for:** one-off events distorting it. August 2026 shows +84.38%, which is entirely a
₹25,000 certification exam, not a change in habits. This is why the dashboard shows variance
per month rather than as an annual average — the average hides the shape.

### Month-over-Month Expense Growth

**What it means.** Is spending trending up? The honest version requires care: if a category had
no spending in a month, a naive calculation compares March to January while calling it
"month over month". The project fills in the missing months as explicit zeros first.

### Recurring Burn vs Subscription Burn

**What they mean.** Recurring burn is every payment that arrives on a stable schedule — rent,
phone, GitHub, Netflix, Spotify: **₹8,007/month** here. Subscription burn narrows that to the
*non-essential* ones: **₹1,158/month**.

**Why they are separate.** The original specification called the first one "Subscription Burn",
which would have put ₹6,500 of rent inside a dashboard tile people read as *cancellable spend*.
The number was technically correct and practically misleading, so it was split. The second
figure is the one you can actually act on.

**How it's detected.** No hardcoded list of subscriptions. The SQL looks for any merchant
charging a stable amount (within ±10%) for three or more consecutive months. It found all six
correctly, including one that started mid-dataset.

### Investment Return (absolute) vs XIRR — the one that confuses everyone

**Absolute return** — `(market value − cost basis) ÷ cost basis` — is **+9.53%** here:
₹86,156 invested is now worth ₹94,368.

**XIRR** is **13.05%**, and the gap is not an error.

Absolute return treats all the money as though it had been invested the whole time. It wasn't.
The SIPs put money in gradually over 18 months — the first instalment has been working for the
full period, last month's for a few weeks. The *average rupee* was invested for well under 18
months.

XIRR accounts for **when** each rupee arrived and answers a different question: "what annual
rate of return would produce these results, given this exact schedule of payments?" Because the
money was invested for less time than the absolute figure implies, the annualized rate must be
higher to produce the same gain.

**Rule of thumb:** for a regular SIP, XIRR should come out meaningfully *above* the absolute
return. If they are nearly equal, the calculation has probably been handed totals instead of
dated cash flows.

### Loan Payoff Progress — `principal repaid ÷ original principal`

**What it means.** How much of the ₹72,000 you actually own back. **63.53%** here.

**The thing worth understanding:** an EMI is a fixed payment split between interest and
principal, and the split shifts every month. Instalment 1 is ₹840 interest and ₹2,617
principal; instalment 24 is ₹40 interest and ₹3,417 principal. Early payments mostly service
interest, later ones mostly reduce the debt. That is why paying a loan off early saves so much —
you skip the payments that are nearly all principal reduction, having already paid the interest.

The amortization table in `vw_loan_schedule` computes this month by month and lands within ₹2
of zero after 24 instalments. The residue is the EMI being rounded to ₹3,457 from a true
₹3,456.60.

### Net Worth — `liquid + investments − card outstanding − loan outstanding`

**What it means.** Everything you own minus everything you owe. The only number that captures
the whole picture.

**Why it goes negative here.** From June to October 2025 it is negative, bottoming at
−₹17,214. That is not a bug. The ₹72,000 laptop loan appears as a liability the month it
starts — but the laptop it bought is not an asset in this model, because the lender paid the
vendor directly and no transaction ever lands in an account. So the debt is counted and the
thing it bought is not.

A full personal balance sheet would carry the laptop as a depreciating asset. This one does not,
and the honest response is to annotate the dip rather than quietly adjust the formula. It
recovers to +₹2,02,249 by September 2026.

### Financial Health Score — 0 to 100

A single weighted number, so the dashboard can show one headline figure:

| Component | Points | Full marks at | Zero at |
|---|---|---|---|
| Savings rate | 25 | ≥ 20% | ≤ 0% |
| Debt-to-income | 20 | ≤ 10% | ≥ 40% |
| Emergency fund | 25 | ≥ 6 months | 0 months |
| Investment rate | 15 | ≥ 15% | 0% |
| Budget adherence | 15 | all categories within budget | none |

Each component scales linearly between those bounds and is capped, so an exceptional month in
one area cannot mask a failure in another.

**Why these weights.** Savings rate and emergency fund carry half the score between them
because they are what determine whether a financial shock is an inconvenience or a crisis.
Investing is weighted lowest — it matters, but investing while having no buffer is the wrong
order of operations.

**This dataset:** 82.82 at September 2026, ranging 39.81 to 95.98. The low point is September
2025, when income dropped to ₹23,000 while expenses stayed near ₹30,000.

---

## 3. Two implementation details that look like bugs

**Credit card balances are negative.** The convention is `+amount` for credits and `−amount`
for debits across all accounts. On a savings account that behaves intuitively. On a credit card
it means spending drives the balance *negative* and paying it off moves it back towards zero —
so the amount owed is the negation of the balance. The card closes at −₹5,091, meaning ₹5,091
owed. Getting this backwards would invert net worth while still producing plausible-looking
numbers, which is exactly what makes it dangerous, so the project negates in one place only.

**Percentages are stored pre-multiplied.** `savings_rate_pct` holds `46.56` meaning 46.56%, not
`0.4656`. In Excel these need the custom format `0.0"%"` — applying Excel's `%` format would
multiply by 100 again and display 4656%. XIRR is the exception: it returns a true fraction, so
the normal `%` format is correct there.

---

## 4. Likely questions, and the answers

**"Why is the savings rate negative in some months?"** Expenses plus debt exceeded income.
July–September 2025 income fell to ₹23,000–33,000 while expenses stayed near ₹30,000. Real
freelance income is lumpy, and the dataset reflects that rather than smoothing it.

**"Why doesn't the account slicer filter the KPI tiles?"** Because "savings rate for the SBI
account" is not a defined quantity. Income and expenses are classified by *category type*, not
by which account the money passed through. The slicer only filters what is genuinely
account-level: transactions and balances.

**"Why 33 uncategorized transactions instead of 100% coverage?"** Three of the four unmatched
merchants could be captured with new rules, taking coverage from 97.04% to 99.28%. The fourth
is a masked UPI handle — the merchant genuinely cannot be identified from the data. Assigning
it a category would improve the metric and make the data less true.

**"Is this real data?"** No. Synthetic, 18 months, simulated NAVs rather than real market
prices. See `docs/DATA_INVENTORY.md`.
