import requests
import pandas as pd
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from sqlalchemy import create_engine

TELEGRAM_BOT_TOKEN = '8955209744:AAFpUecPAfxU8fUX7CGWBEjHWRz2CQN6DqM'
TELEGRAM_CHAT_ID = '6804234256'
DB_URL = 'postgresql://postgres:postgres@crypto_postgres:5432/crypto_db'

def send_telegram_alerts():
    engine = create_engine(DB_URL)
    query = "SELECT * FROM z_score WHERE ABS(z_score) > 2;"
    df = pd.read_sql(query, engine)
    
    if not df.empty:
        for _, row in df.iterrows():
            emoji = "🚀" if row['z_score'] > 0 else "💥"
            message = (
                f"{emoji} *CRYPTO ANOMALY DETECTED* {emoji}\n\n"
                f"• *Coin:* `{row['coin_id'].upper()}`\n"
                f"• *Type:* {row['anomaly_type']}\n"
                f"• *Price:* ${row['price_usd']}\n"
                f"• *Z-Score:* {row['z_score']}\n"
                f"• *Time:* {row['fetched_at']}"
            )
            url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
            requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message, "parse_mode": "Markdown"})

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2026, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    'crypto_alerts_pipeline', # Имя изменено во избежание конфликта
    default_args=default_args,
    schedule='*/5 * * * *', 
    catchup=False
) as dag:

    task_alert = PythonOperator(
        task_id='send_crypto_alerts',
        python_callable=send_telegram_alerts
    )