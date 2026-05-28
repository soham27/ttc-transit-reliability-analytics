"""
02_load_to_postgres.py — TTC Transit Reliability Analytics, Stage 3

Bulk-loads `data/processed/fact_delay_events.csv` (403,155 rows) into the
`public.fact_delay_events` table of the `ttc_reliability` Postgres database.

Prerequisites:
  1. `sql/00_create_database.sql` has been run in pgAdmin (creates the DB).
  2. `sql/01_create_schema.sql` has been run against `ttc_reliability`
     (creates the empty fact table).
  3. A `.env` file exists at the project root with a valid `DATABASE_URL`.
     See `.env.example` for the format.

Behaviour:
  - If the target table already contains rows, this script TRUNCATEs them
    and reloads from the CSV. That is deliberate: the CSV is the canonical
    source, so re-running this script is a safe idempotent operation.
  - Loads in chunks of 10,000 rows using SQLAlchemy + pandas `to_sql`.
    With ~403k rows the load typically completes in 30-90 seconds on a
    local Postgres instance.
  - Aborts with a non-zero exit code if any check fails (missing .env,
    missing table, schema mismatch, row-count mismatch after load).

Usage (from anywhere):
  .venv/Scripts/python.exe scripts/02_load_to_postgres.py
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "processed" / "fact_delay_events.csv"
TABLE_NAME = "fact_delay_events"
SCHEMA = "public"


def fatal(msg: str) -> int:
    print(f"FATAL: {msg}", file=sys.stderr)
    return 1


def main() -> int:
    # 1. Credentials --------------------------------------------------------
    load_dotenv(PROJECT_ROOT / ".env")
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        return fatal(
            "DATABASE_URL is not set. Copy .env.example to .env at the "
            "project root and fill in your Postgres password."
        )

    # 2. Inputs -------------------------------------------------------------
    if not CSV_PATH.exists():
        return fatal(
            f"Input CSV missing: {CSV_PATH}. Run scripts/01_clean_delay_data.py first."
        )

    # 3. Connect ------------------------------------------------------------
    print(f"Connecting to Postgres ...")
    try:
        engine = create_engine(database_url, future=True)
        with engine.connect() as conn:
            server_version = conn.execute(text("SHOW server_version")).scalar()
            db_name = conn.execute(text("SELECT current_database()")).scalar()
        print(f"  connected to '{db_name}', Postgres {server_version}")
    except Exception as e:
        return fatal(f"could not connect: {e}")

    # 4. Verify target table exists -----------------------------------------
    with engine.connect() as conn:
        regclass = conn.execute(
            text(f"SELECT to_regclass('{SCHEMA}.{TABLE_NAME}')")
        ).scalar()
    if regclass is None:
        return fatal(
            f"table {SCHEMA}.{TABLE_NAME} does not exist. "
            f"Run sql/01_create_schema.sql against the {db_name} database first."
        )

    # 5. Read the canonical CSV --------------------------------------------
    print(f"Reading {CSV_PATH.relative_to(PROJECT_ROOT)} ...")
    # Be explicit about text columns so pandas does not try to infer numeric
    # types for codes like '320' (which would round-trip differently).
    df = pd.read_csv(
        CSV_PATH,
        parse_dates=["event_date", "event_datetime"],
        dtype={
            "transit_mode": "string",
            "source_file": "string",
            "event_time": "string",
            "month_name": "string",
            "day_of_week": "string",
            "line": "string",
            "station": "string",
            "bound": "string",
            "delay_code": "string",
            "delay_description": "string",
        },
    )
    # event_date arrives as a Timestamp at midnight; the Postgres column is
    # DATE, so we drop the time component to avoid implicit conversion noise.
    df["event_date"] = df["event_date"].dt.date
    print(f"  {len(df):,} rows, {df.shape[1]} columns")

    # 6. Truncate if non-empty ---------------------------------------------
    with engine.connect() as conn:
        existing = conn.execute(
            text(f"SELECT COUNT(*) FROM {SCHEMA}.{TABLE_NAME}")
        ).scalar()
    print(f"Existing rows in {SCHEMA}.{TABLE_NAME}: {existing:,}")
    if existing:
        print("  truncating before reload (CSV is canonical)")
        with engine.begin() as conn:
            conn.execute(text(f"TRUNCATE {SCHEMA}.{TABLE_NAME}"))

    # 7. Load ---------------------------------------------------------------
    print("Loading (this typically takes 30-90 seconds on local Postgres) ...")
    t0 = time.perf_counter()
    df.to_sql(
        TABLE_NAME,
        engine,
        schema=SCHEMA,
        if_exists="append",
        index=False,
        chunksize=10_000,
        method="multi",
    )
    elapsed = time.perf_counter() - t0
    print(f"  insert completed in {elapsed:.1f}s ({len(df) / elapsed:,.0f} rows/s)")

    # 8. Verify -------------------------------------------------------------
    with engine.connect() as conn:
        loaded = conn.execute(
            text(f"SELECT COUNT(*) FROM {SCHEMA}.{TABLE_NAME}")
        ).scalar()
        min_date, max_date = conn.execute(
            text(f"SELECT MIN(event_date), MAX(event_date) FROM {SCHEMA}.{TABLE_NAME}")
        ).one()
        mode_counts = conn.execute(
            text(
                f"SELECT transit_mode, COUNT(*) AS n "
                f"FROM {SCHEMA}.{TABLE_NAME} "
                f"GROUP BY transit_mode ORDER BY n DESC"
            )
        ).all()

    print(f"\nVerification:")
    print(f"  rows in DB: {loaded:,}  (CSV had {len(df):,})")
    print(f"  date range: {min_date} -> {max_date}")
    print(f"  by mode:    " + ", ".join(f"{m}={n:,}" for m, n in mode_counts))

    if loaded != len(df):
        return fatal(
            f"row-count mismatch after load: DB has {loaded:,}, CSV had {len(df):,}"
        )

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
