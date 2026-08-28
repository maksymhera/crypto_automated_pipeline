CREATE TABLE IF NOT EXISTS crypto_prices (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    coin_id VARCHAR(32),
    symbol VARCHAR(32),
    price_usd NUMERIC,
    market_cap_usd BIGINT,
    fetched_at TIMESTAMP,
    total_volume NUMERIC,
    high_24h NUMERIC,
    low_24h NUMERIC
);


CREATE OR REPLACE VIEW latest_crypto_prices AS
SELECT coin_id, symbol, price_usd, fetched_at
FROM crypto_prices
WHERE fetched_at = (
    SELECT MAX(fetched_at)
    FROM crypto_prices
);


CREATE OR REPLACE VIEW total_crypto_analysis AS
SELECT coin_id,
       COUNT(*) AS total_records,
       MAX(price_usd) AS max_price,
       MIN(price_usd) AS min_price,
       ROUND(AVG(price_usd)::numeric, 2) AS avg_price
FROM crypto_prices
GROUP BY coin_id;


CREATE OR REPLACE VIEW present_last_price_change_precent AS
SELECT 
    coin_id,
    fetched_at,
    price_usd,
    last_price,
    ROUND((((price_usd - last_price) / NULLIF(last_price, 0)) * 100)::numeric, 2) AS percent_price_change
FROM (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        LAG(price_usd) OVER (
            PARTITION BY coin_id
            ORDER BY fetched_at
        ) AS last_price
    FROM crypto_prices
) AS sub
ORDER BY fetched_at DESC, coin_id;


CREATE OR REPLACE VIEW ma_function AS
WITH moving_averages AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        ROUND(AVG(price_usd) OVER (
            PARTITION BY coin_id 
            ORDER BY fetched_at 
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        )::numeric, 2) AS ma_5,
        ROUND(AVG(price_usd) OVER (
            PARTITION BY coin_id 
            ORDER BY fetched_at 
            ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
        )::numeric, 2) AS ma_10,
        ROUND(AVG(price_usd) OVER (
            PARTITION BY coin_id 
            ORDER BY fetched_at 
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        )::numeric, 2) AS ma_20
    FROM crypto_prices
)
SELECT DISTINCT ON (coin_id)
    coin_id,
    price_usd,
    ma_5,
    ma_10,
    ma_20,
    fetched_at AS last_updated
FROM moving_averages
ORDER BY coin_id, fetched_at DESC;


CREATE OR REPLACE VIEW volatility_function AS
WITH price_returns AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        (price_usd - LAG(price_usd) OVER (PARTITION BY coin_id ORDER BY fetched_at)) 
        / NULLIF(LAG(price_usd) OVER (PARTITION BY coin_id ORDER BY fetched_at), 0) AS pct_return
    FROM crypto_prices
)
SELECT 
    coin_id,
    COUNT(pct_return) AS data_points,
    ROUND((STDDEV(pct_return) * 100)::numeric, 4) AS volatility_pct,
    ROUND(MIN(price_usd)::numeric, 2) AS min_price,
    ROUND(MAX(price_usd)::numeric, 2) AS max_price
FROM price_returns
WHERE pct_return IS NOT NULL
GROUP BY coin_id
ORDER BY volatility_pct DESC;


CREATE OR REPLACE VIEW z_score AS
WITH stats AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        AVG(price_usd) OVER (PARTITION BY coin_id) AS avg_price,
        STDDEV(price_usd) OVER (PARTITION BY coin_id) AS stddev_price
    FROM crypto_prices
),
z_scores AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        ROUND(avg_price::numeric, 2) AS avg_price,
        ROUND(((price_usd - avg_price) / NULLIF(stddev_price, 0))::numeric, 2) AS z_score
    FROM stats
)
SELECT 
    coin_id,
    fetched_at,
    price_usd,
    avg_price,
    z_score,
    CASE 
        WHEN z_score > 2 THEN 'Spike (Pump)'
        WHEN z_score < -2 THEN 'Drop (Dump)'
        ELSE 'Normal'
    END AS anomaly_type
FROM z_scores
WHERE ABS(z_score) > 2 
ORDER BY fetched_at DESC;

CREATE OR REPLACE VIEW correlation AS
WITH returns AS (
    SELECT
        fetched_at,
        coin_id,
        price_usd / LAG(price_usd) OVER (
            PARTITION BY coin_id
            ORDER BY fetched_at
        ) - 1 AS return
    FROM crypto_prices
)
SELECT
    a.coin_id AS coin_1,
    b.coin_id AS coin_2,
    CORR(a.return, b.return) AS correlation
FROM returns a
JOIN returns b
    ON a.fetched_at = b.fetched_at
   AND a.coin_id < b.coin_id
WHERE a.return IS NOT NULL
  AND b.return IS NOT NULL
GROUP BY
    a.coin_id,
    b.coin_id
ORDER BY
    correlation DESC;

CREATE OR REPLACE VIEW rsi_indicator AS
WITH price_changes AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        price_usd - LAG(price_usd, 1)
            OVER (PARTITION BY coin_id
                ORDER BY fetched_at) AS price_change
    FROM crypto_prices
),
gains_loses AS (
    SELECT 
        coin_id,
        fetched_at,
        price_usd,
        COALESCE(NULLIF(price_change, 0), 0) AS price_change,
        CASE 
            WHEN price_change > 0 THEN price_change 
            ELSE 0 
        END AS gain,
        CASE
            WHEN price_change < 0 THEN ABS(price_change) 
            ELSE 0 
        END AS loss
    FROM price_changes
),
smoothed_averages AS (
    SELECT
        coin_id,
        fetched_at,
        price_usd,
        AVG(gain) OVER (
            PARTITION BY coin_id
            ORDER BY fetched_at 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW	
        ) AS avg_gain,
        AVG(loss) OVER (
            PARTITION BY coin_id
            ORDER BY fetched_at 
            ROWS BETWEEN 13 PRECEDING AND CURRENT ROW	
        ) AS avg_loss
    FROM gains_loses
),
rsi_calculation AS (
    SELECT
        coin_id,
        fetched_at,
        price_usd,
        avg_gain,
        avg_loss,
        CASE 
            WHEN avg_loss = 0 THEN 100
            WHEN avg_gain = 0 THEN 0
            ELSE 100 - (100 / (1 + (avg_gain / NULLIF(avg_loss, 0))))
        END AS rsi
    FROM smoothed_averages
)
SELECT 
    coin_id,
    fetched_at,
    price_usd,
    ROUND(rsi::numeric, 2) AS rsi
FROM rsi_calculation;

SELECT * 
FROM crypto_prices 
ORDER BY fetched_at DESC 
