# Automated Crypto Analytics & Intelligence Pipeline 🚀

An end-to-end data engineering and quantitative analytics platform built with **Apache Airflow**, **PostgreSQL**, **Python (Pandas, Requests)**, and the **Telegram Bot API**. This system automates ingestion from CoinGecko, persistent multi-variable storage, and advanced statistical modeling via relational database views—feeding a live **Power BI** dashboard and real-time alerting system.

---

## 🏗️ Architecture & Tech Stack

* **Orchestration:** Apache Airflow (`SequentialExecutor` running inside Docker)
* **Data Storage & Analytics:** PostgreSQL (15-alpine) packed with complex analytical SQL Views (Moving Averages, Volatility, Z-Score, RSI, and Asset Correlations)
* **Data Ingestion:** Python, Pandas, SQLAlchemy, Requests
* **Notification System:** Telegram Bot API (Automated Anomaly Dispatcher)
* **Reporting Layer:** Power BI (Interactive Dashboard tracking live pricing, trends, anomalies, and risk metrics)
* **Containerization:** Docker & Docker Compose

---

## 📂 Project Structure

```text
crypto_automated_pipeline/
│
├── dags/
│   ├── crypto_dag.py       # ETL Pipeline: Ingests top market data from CoinGecko -> PostgreSQL
│   └── send_alerts.py      # Alert Pipeline: Evaluates anomaly thresholds & triggers Telegram webhooks
│
├── sql_analytics/
│   └── sql_views_analysis.sql # Advanced analytical SQL views (MA, Volatility, Z-Score, RSI, Correlation)
│
├── power_bi/
│   └── crypto_prices.pbix      # Power BI analytical dashboard file
│
└── docker-compose.yaml     # Local multi-container infrastructure (Airflow & PostgreSQL)

```

---

## ⚙️ Core Components & Infrastructure

### 1. Infrastructure Setup (`docker-compose.yaml`)

Deploys isolated services for database storage and workflow management:

* **PostgreSQL (`crypto_postgres`)**: Persists historical pricing data, market capitalizations, and high/low ranges on an isolated volume.
* **Airflow (`crypto_airflow`)**: Automates scheduling, executing independent DAG files, and managing runtime dependencies (`pandas`, `sqlalchemy`, `psycopg2-binary`, `requests`).

### 2. Automated Ingestion Pipeline (`crypto_dag.py`)

* **DAG ID:** `crypto_etl_pipeline`
* **Schedule Interval:** Every 5 minutes (`*/5 * * * *`)
* **Workflow:** Extracts top cryptocurrencies by market capitalization from the **CoinGecko API**, maps attributes (`coin_id`, `symbol`, `price_usd`, `market_cap_usd`, `high_24h`, `low_24h`, `total_volume`), appends a UTC timestamp (`fetched_at`), and loads records directly into the `crypto_prices` relational table.

---

## 📊 Advanced SQL Analytics Layer

The core analytical engine relies on pre-aggregated **PostgreSQL Views**, designed to compute financial metrics natively on the database server before visualization layers query them:

* **`latest_crypto_prices`**: Filters and exposes only the most recent market snapshot per coin.
* **`total_crypto_analysis`**: Aggregates comprehensive historical metrics (`total_records`, `max_price`, `min_price`, `avg_price`) grouped by asset.
* **`present_last_price_change_precent`**: Tracks tick-by-tick or interval-by-interval percentage changes utilizing window functions (`LAG`).
* **`ma_function` (Moving Averages)**: Computes multi-window moving averages (`ma_5`, `ma_10`, `ma_20`) across time partitions to support trend analysis.
* **`volatility_function`**: Measures historical price returns and computes standardized percentage volatility alongside price boundaries.
* **`z_score` (Anomaly Detection)**: Evaluates statistical deviation against historical moving norms to flag sudden market shocks, labeling them as **Spike (Pump)** or **Drop (Dump)** when `ABS(z_score) > 2`.
* **`correlation`**: Computes rolling return correlations (`CORR`) across different cryptocurrency pairs to evaluate market co-movement.
* **`rsi_indicator` (Relative Strength Index)**: Implements multi-layered CTE processing using Wilder's smoothing logic over a 14-period window to evaluate overbought/oversold momentum dynamics.

---

## 🚨 Automated Telegram Alerting (`send_alerts.py`)

* **DAG ID:** `crypto_alerts_pipeline`
* **Schedule Interval:** Every 5 minutes (`*/5 * * * *`)
* **Workflow:** Continuously polls the PostgreSQL `z_score` anomaly view (`SELECT * FROM z_score WHERE ABS(z_score) > 2;`). If volatile market deviations occur, it builds rich Markdown payloads augmented with conditional emojis (`🚀` for pumps, `💥` for dumps) and pushes real-time webhooks straight to the target **Telegram Chat**.

---

## 📈 Power BI Intelligence Dashboard

Connected directly to the PostgreSQL data warehouse via live views, the **Power BI Dashboard** visualizes the data through multiple components:

* **Real-Time KPIs & Cards:** Instant tracking of current asset prices, latest interval percentage changes, and asset volatility.
* **Trend Analysis & Moving Averages:** Multi-series charts mapping actual prices against 5, 10, and 20-period moving averages (`ma_function`).
* **Anomaly & Event Logs:** Dedicated analytical data grids tracking historical pump and dump alerts directly from the `z_score` view.
* **Market Aggregations:** Summary cards displaying minimum, maximum, and average historical pricing ranges per asset.