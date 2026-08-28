import requests
import pandas as pd
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from sqlalchemy import create_engine

DB_URL = "postgresql://postgres:postgres@crypto_postgres:5432/crypto_db"

def extract_and_load_crypto():
    url = "https://api.coingecko.com/api/v3/coins/markets"
    params = {
        "vs_currency": "usd",
        "order": "market_cap_desc",
        "per_page": 10,
        "page": 1,
        "sparkline": "false"
    }
    
    response = requests.get(url, params=params, timeout=10)
    response.raise_for_status()
    data = response.json()
    
    raw_df = pd.DataFrame(data)
    
    df = raw_df[[
        "id", "symbol", "current_price", 
        "market_cap", "high_24h", "low_24h", "total_volume"
    ]].copy()
    
    df.columns = [
        "coin_id", "symbol", "price_usd", 
        "market_cap_usd", "high_24h", "low_24h", "total_volume"
    ]
    df["fetched_at"] = datetime.utcnow()
    
    engine = create_engine(DB_URL)
    df.to_sql("crypto_prices", con=engine, if_exists="append", index=False)

default_args = {
    'owner': 'data_analyst',
    'retries': 2,
    'retry_delay': timedelta(minutes=1)
}

dag = DAG(
    dag_id='crypto_etl_pipeline', # Уникальное имя DAG 1
    default_args=default_args,
    start_date=datetime(2026, 1, 1),
    schedule='*/5 * * * *',
    catchup=False
)

task_fetch_crypto = PythonOperator(
    task_id='fetch_crypto_data',
    python_callable=extract_and_load_crypto,
    dag=dag
)