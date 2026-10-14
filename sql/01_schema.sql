-- ============================================================
-- Personal Finance & Financial Health Dashboard — 01_schema.sql
-- MySQL 8.0+   |   income, expenses, investments, debt
-- Re-runnable: drops and recreates finance_db
-- ============================================================

DROP DATABASE IF EXISTS finance_db;
CREATE DATABASE finance_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE finance_db;

-- ---------- Reference tables ----------

CREATE TABLE accounts (
  account_id      INT AUTO_INCREMENT PRIMARY KEY,
  account_name    VARCHAR(60)  NOT NULL UNIQUE,
  account_type    ENUM('savings','current','credit_card','wallet','cash') NOT NULL,
  opening_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
  category_id   INT AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(50) NOT NULL UNIQUE,
  -- investment = money moved into assets; debt = loan repayments; transfer = between own accounts
  category_type ENUM('income','expense','investment','debt','transfer') NOT NULL,
  is_essential  BOOLEAN NOT NULL DEFAULT FALSE   -- needs vs wants
);

-- Keyword rules used to auto-categorize raw transactions
CREATE TABLE categorization_rules (
  rule_id     INT AUTO_INCREMENT PRIMARY KEY,
  keyword     VARCHAR(60) NOT NULL,
  category_id INT NOT NULL,
  priority    INT NOT NULL DEFAULT 100,   -- lower = checked first
  FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- ---------- Staging: raw exports land here untouched ----------

CREATE TABLE raw_transactions (
  raw_id       INT AUTO_INCREMENT PRIMARY KEY,
  txn_date     VARCHAR(20),      -- text on purpose: validated during cleaning
  description  VARCHAR(255),
  debit        VARCHAR(20),
  credit       VARCHAR(20),
  account_name VARCHAR(60),
  ref_no       VARCHAR(40),
  loaded_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE raw_valuations (     -- month-end holdings statement (e.g. from Groww/Zerodha)
  instrument_name VARCHAR(80),
  valuation_date  VARCHAR(20),
  units_held      VARCHAR(20),
  nav             VARCHAR(20)
);

-- ---------- Clean fact table ----------

CREATE TABLE transactions (
  txn_id       INT AUTO_INCREMENT PRIMARY KEY,
  account_id   INT NOT NULL,
  txn_date     DATE NOT NULL,
  description  VARCHAR(255) NOT NULL,
  amount       DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  direction    ENUM('debit','credit') NOT NULL,
  category_id  INT NULL,                 -- NULL = uncategorized
  ref_no       VARCHAR(40),
  FOREIGN KEY (account_id)  REFERENCES accounts(account_id),
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  UNIQUE KEY uq_dedupe (account_id, txn_date, amount, ref_no),
  INDEX idx_date (txn_date),
  INDEX idx_cat_date (category_id, txn_date)
);

-- ---------- Investments ----------

CREATE TABLE investments (
  investment_id   INT AUTO_INCREMENT PRIMARY KEY,
  instrument_name VARCHAR(80) NOT NULL UNIQUE,
  instrument_type ENUM('mutual_fund','stock','fixed_deposit','gold') NOT NULL,
  platform        VARCHAR(40),
  txn_keyword     VARCHAR(60) NOT NULL   -- links buy transactions to this holding
);

CREATE TABLE investment_valuations (
  valuation_id   INT AUTO_INCREMENT PRIMARY KEY,
  investment_id  INT NOT NULL,
  valuation_date DATE NOT NULL,          -- month-end
  units_held     DECIMAL(14,4) NOT NULL,
  nav            DECIMAL(12,4) NOT NULL,
  market_value   DECIMAL(12,2) AS (ROUND(units_held * nav, 2)) STORED,
  FOREIGN KEY (investment_id) REFERENCES investments(investment_id),
  UNIQUE KEY uq_inv_date (investment_id, valuation_date)
);

-- ---------- Debt ----------

CREATE TABLE loans (
  loan_id        INT AUTO_INCREMENT PRIMARY KEY,
  lender         VARCHAR(60) NOT NULL,
  loan_type      ENUM('consumer','education','personal','credit_card_emi') NOT NULL,
  principal      DECIMAL(12,2) NOT NULL,
  annual_rate    DECIMAL(5,2)  NOT NULL,   -- % p.a.
  tenure_months  INT NOT NULL,
  start_date     DATE NOT NULL,
  emi_amount     DECIMAL(12,2) NOT NULL,
  txn_keyword    VARCHAR(60) NOT NULL      -- links EMI transactions to this loan
);

-- ---------- Planning ----------

CREATE TABLE budgets (
  budget_id     INT AUTO_INCREMENT PRIMARY KEY,
  category_id   INT NOT NULL,
  budget_month  DATE NOT NULL,             -- always the 1st of the month
  budget_amount DECIMAL(12,2) NOT NULL,
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  UNIQUE KEY uq_cat_month (category_id, budget_month)
);

CREATE TABLE savings_goals (
  goal_id       INT AUTO_INCREMENT PRIMARY KEY,
  goal_name     VARCHAR(80) NOT NULL,
  target_amount DECIMAL(12,2) NOT NULL,
  target_date   DATE NOT NULL,
  saved_amount  DECIMAL(12,2) NOT NULL DEFAULT 0
);

-- ---------- Seed reference data ----------

INSERT INTO accounts (account_name, account_type, opening_balance) VALUES
 ('SBI Savings','savings',25000), ('HDFC Credit Card','credit_card',0), ('Paytm Wallet','wallet',500);

INSERT INTO categories (category_name, category_type, is_essential) VALUES
 ('Freelance Income','income',FALSE), ('Stipend','income',FALSE), ('Family Support','income',FALSE),
 ('Dividends & Interest','income',FALSE),
 ('Rent','expense',TRUE), ('Groceries','expense',TRUE), ('Utilities & Recharge','expense',TRUE),
 ('Transport','expense',TRUE), ('Education','expense',TRUE), ('Health','expense',TRUE),
 ('Food Delivery','expense',FALSE), ('Dining Out','expense',FALSE), ('Snacks & Tea','expense',FALSE),
 ('Shopping','expense',FALSE), ('Subscriptions','expense',FALSE), ('Entertainment','expense',FALSE),
 ('Software & Tools','expense',FALSE),
 ('Mutual Fund SIP','investment',FALSE), ('Stocks','investment',FALSE), ('Fixed Deposit','investment',FALSE),
 ('Loan EMI','debt',TRUE),
 ('Card Payment','transfer',FALSE), ('Wallet Top-up','transfer',FALSE);

INSERT INTO categorization_rules (keyword, category_id, priority)
SELECT k.keyword, c.category_id, k.priority FROM (
  SELECT 'CC PAYMENT' keyword,'Card Payment' cat, 5 priority UNION ALL
  SELECT 'PAYMENT RECEIVED','Card Payment',5 UNION ALL
  SELECT 'ADD MONEY','Wallet Top-up',5 UNION ALL
  SELECT 'EMI','Loan EMI',8 UNION ALL
  SELECT 'SIP','Mutual Fund SIP',8 UNION ALL
  SELECT 'ZERODHA','Stocks',8 UNION ALL
  SELECT 'FD BOOKING','Fixed Deposit',8 UNION ALL
  SELECT 'DIVIDEND','Dividends & Interest',9 UNION ALL SELECT 'INT.PD','Dividends & Interest',9 UNION ALL
  SELECT 'CLIENT','Freelance Income',10 UNION ALL SELECT 'UPWORK','Freelance Income',10 UNION ALL
  SELECT 'STIPEND','Stipend',10 UNION ALL
  SELECT 'FROM PAPA','Family Support',10 UNION ALL
  SELECT 'RENT','Rent',20 UNION ALL
  SELECT 'BIGBASKET','Groceries',30 UNION ALL SELECT 'BLINKIT','Groceries',30 UNION ALL SELECT 'ZEPTO','Groceries',30 UNION ALL
  SELECT 'JIO','Utilities & Recharge',30 UNION ALL SELECT 'AIRTEL','Utilities & Recharge',30 UNION ALL SELECT 'TPCODL','Utilities & Recharge',30 UNION ALL
  SELECT 'UBER','Transport',30 UNION ALL SELECT 'RAPIDO','Transport',30 UNION ALL SELECT 'OLA','Transport',30 UNION ALL SELECT 'IRCTC','Transport',30 UNION ALL
  SELECT 'UDEMY','Education',30 UNION ALL SELECT 'COURSERA','Education',30 UNION ALL SELECT 'PEARSON VUE','Education',30 UNION ALL
  SELECT 'APOLLO','Health',30 UNION ALL SELECT 'PHARMEASY','Health',30 UNION ALL
  SELECT 'SWIGGY','Food Delivery',40 UNION ALL SELECT 'ZOMATO','Food Delivery',40 UNION ALL
  SELECT 'TEA STALL','Snacks & Tea',45 UNION ALL SELECT 'CANTEEN','Snacks & Tea',45 UNION ALL SELECT 'BAKERY','Snacks & Tea',45 UNION ALL
  SELECT 'CAFE','Dining Out',50 UNION ALL SELECT 'RESTAURANT','Dining Out',50 UNION ALL
  SELECT 'AMAZON','Shopping',50 UNION ALL SELECT 'FLIPKART','Shopping',50 UNION ALL SELECT 'MYNTRA','Shopping',50 UNION ALL
  SELECT 'NETFLIX','Subscriptions',40 UNION ALL SELECT 'SPOTIFY','Subscriptions',40 UNION ALL SELECT 'YOUTUBE PREMIUM','Subscriptions',40 UNION ALL
  SELECT 'PVR','Entertainment',50 UNION ALL SELECT 'BOOKMYSHOW','Entertainment',50 UNION ALL SELECT 'STEAM','Entertainment',50 UNION ALL
  SELECT 'GITHUB','Software & Tools',40 UNION ALL SELECT 'VERCEL','Software & Tools',40 UNION ALL SELECT 'HOSTINGER','Software & Tools',40
) k JOIN categories c ON c.category_name = k.cat;

INSERT INTO investments (instrument_name, instrument_type, platform, txn_keyword) VALUES
 ('UTI Nifty 50 Index Fund',        'mutual_fund',   'Groww',   'SIP/UTI NIFTY'),
 ('Parag Parikh Flexi Cap Fund',    'mutual_fund',   'Groww',   'SIP/PPFAS FLEXI'),
 ('TCS Ltd',                        'stock',         'Zerodha', 'ZERODHA/TCS'),
 ('ITC Ltd',                        'stock',         'Zerodha', 'ZERODHA/ITC'),
 ('SBI Fixed Deposit 1Y',           'fixed_deposit', 'SBI',     'FD BOOKING');

-- Laptop bought on a consumer loan: 72,000 @ 14% p.a. for 24 months
INSERT INTO loans (lender, loan_type, principal, annual_rate, tenure_months, start_date, emi_amount, txn_keyword) VALUES
 ('Bajaj Finserv', 'consumer', 72000, 14.00, 24, '2025-06-01', 3457.00, 'EMI/BAJAJ');
