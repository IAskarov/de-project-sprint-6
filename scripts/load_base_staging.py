"""Load the source columns needed to bootstrap a clean training stand."""
import csv
from pathlib import Path
from tempfile import TemporaryDirectory

import boto3
import vertica_python
from airflow.hooks.base import BaseHook
from botocore import UNSIGNED
from botocore.config import Config

SCHEMA = "VT261117917969__STAGING"
SOURCES = {
    "users": (("id",), "id INT NOT NULL"),
    "groups": (("id", "registration_dt"), "id INT NOT NULL, registration_dt TIMESTAMP(6)"),
    "dialogs": (
        ("message_id", "message_from", "message_group"),
        "message_id INT NOT NULL, message_from INT, message_group INT",
    ),
}


def main():
    s3 = boto3.client(
        "s3",
        endpoint_url="https://storage.yandexcloud.net",
        config=Config(signature_version=UNSIGNED),
    )
    conn = BaseHook.get_connection("sprint6_vertica")

    with TemporaryDirectory() as folder:
        folder = Path(folder)
        for table, (columns, _) in SOURCES.items():
            print(f"Скачиваю {table}.csv", flush=True)
            raw = folder / f"{table}.csv"
            s3.download_file("sprint6", raw.name, str(raw))
            with raw.open(encoding="utf-8-sig", newline="") as source:
                with (folder / f"{table}.txt").open("w", encoding="utf-8") as target:
                    for row in csv.DictReader(source):
                        values = [(row[col] or "").strip() for col in columns]
                        target.write("|".join(values) + "\n")

        with vertica_python.connect(
            host=conn.host, port=conn.port or 5433,
            user=conn.login, password=conn.password, database=conn.schema,
            autocommit=False,
        ) as db:
            cursor = db.cursor()
            for table, (_, definition) in SOURCES.items():
                cursor.execute(f"CREATE TABLE IF NOT EXISTS {SCHEMA}.{table} ({definition})")
            for table, (columns, _) in SOURCES.items():
                table_name = f"{SCHEMA}.{table}"
                cursor.execute(f"DELETE FROM {table_name}")
                with (folder / f"{table}.txt").open("rb") as source:
                    cursor.copy(
                        f"COPY {table_name} ({', '.join(columns)}) FROM STDIN "
                        "DELIMITER '|' NULL AS '' ABORT ON ERROR NO COMMIT",
                        source,
                    )
                cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                count = cursor.fetchone()[0]
                if not count:
                    raise RuntimeError(f"Пустая таблица {table_name}")
                print(f"{table}: {count:,} строк", flush=True)
            db.commit()
    print("Загрузка завершена", flush=True)


if __name__ == "__main__":
    main()
