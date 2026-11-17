import logging
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

from airflow import DAG
from airflow.hooks.base import BaseHook
from airflow.models import Variable
from airflow.operators.python import PythonOperator

DATA_FILE = Path(__file__).resolve().parent / "data" / "group_log.csv"


def download_group_log():
    import boto3
    from botocore import UNSIGNED
    from botocore.config import Config

    endpoint = Variable.get(
        "sprint6_s3_endpoint", default_var="https://storage.yandexcloud.net"
    )
    conn_id = Variable.get("sprint6_s3_conn_id", default_var="")
    if conn_id:
        connection = BaseHook.get_connection(conn_id)
        client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            region_name="ru-central1",
            aws_access_key_id=connection.login,
            aws_secret_access_key=connection.password,
        )
    else:
        client = boto3.client(
            "s3", endpoint_url=endpoint, config=Config(signature_version=UNSIGNED)
        )

    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary_file = DATA_FILE.with_suffix(".csv.part")
    client.download_file("sprint6", DATA_FILE.name, str(temporary_file))
    temporary_file.replace(DATA_FILE)


def load_group_log():
    from csv import reader

    import vertica_python

    schema = Variable.get("sprint6_schema_prefix")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", schema):
        raise ValueError("Invalid sprint6_schema_prefix")
    table = f"{schema}__STAGING.group_log"
    connection = BaseHook.get_connection("sprint6_vertica")

    with DATA_FILE.open(encoding="utf-8-sig", newline="") as source:
        header = next(reader(source), None)
    expected = ["group_id", "user_id", "user_id_from", "event", "datetime"]
    if header != expected:
        raise ValueError(f"Unexpected columns: {header}")

    with vertica_python.connect(
        host=connection.host,
        port=connection.port or 5433,
        user=connection.login,
        password=connection.password,
        database=connection.schema,
        autocommit=False,
    ) as database:
        cursor = database.cursor()
        # Keep the old snapshot until the new CSV has loaded successfully.
        cursor.execute(f"DELETE FROM {table}")
        with DATA_FILE.open("rb") as source:
            cursor.copy(
                f"""
                COPY {table} (group_id, user_id, user_id_from, event, event_dt)
                FROM STDIN DELIMITER ',' ENCLOSED BY '"' SKIP 1 NULL AS ''
                ABORT ON ERROR NO COMMIT
                """,
                source,
            )
        cursor.execute(f"SELECT event, COUNT(*) FROM {table} GROUP BY event")
        counts = dict(cursor.fetchall())
        if not counts or counts.keys() - {"create", "add", "leave"}:
            raise ValueError(f"Unexpected events: {counts}")
        database.commit()
    logging.info("Loaded %s events: %s", sum(counts.values()), counts)


with DAG(
    dag_id="sprint6_group_log",
    start_date=datetime(2024, 1, 1, tzinfo=timezone.utc),
    schedule_interval=None,
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=1)},
    tags=["sprint6"],
) as dag:
    download = PythonOperator(task_id="download_group_log", python_callable=download_group_log)
    load = PythonOperator(task_id="load_group_log", python_callable=load_group_log)
    download >> load
