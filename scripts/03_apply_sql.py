"""
03_apply_sql.py — TTC Transit Reliability Analytics, Stage 3

Applies the dimension and reporting-view SQL files to the
`ttc_reliability` Postgres database, then verifies that each new
object exists and reports its row count.

Files applied (in this order):
  sql/03_create_dimensions.sql   -> dim_date, dim_mode, dim_delay_cause
  sql/05_reporting_views.sql     -> 7 vw_* reporting views

Both files are idempotent (DROP TABLE IF EXISTS / CREATE OR REPLACE
VIEW), so running this script multiple times is safe.

Usage (from anywhere):
  .venv/Scripts/python.exe scripts/03_apply_sql.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_FILES = [
    PROJECT_ROOT / "sql" / "03_create_dimensions.sql",
    PROJECT_ROOT / "sql" / "05_reporting_views.sql",
]


def fatal(msg: str) -> int:
    print(f"FATAL: {msg}", file=sys.stderr)
    return 1


def apply_file(engine, path: Path) -> None:
    """Run a multi-statement SQL file via the underlying psycopg2 driver.

    SQLAlchemy's `text()` only supports single-statement execution. To run
    a whole `.sql` file in one go we grab the raw psycopg2 connection's
    cursor, which accepts multi-statement strings.
    """
    sql = path.read_text(encoding="utf-8")
    raw_conn = engine.raw_connection()
    try:
        cur = raw_conn.cursor()
        cur.execute(sql)
        raw_conn.commit()
    except Exception:
        raw_conn.rollback()
        raise
    finally:
        raw_conn.close()


def main() -> int:
    load_dotenv(PROJECT_ROOT / ".env")
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        return fatal("DATABASE_URL not set. Make sure .env exists at project root.")

    engine = create_engine(database_url, future=True)
    print("Connecting to Postgres ...")
    with engine.connect() as conn:
        db_name = conn.execute(text("SELECT current_database()")).scalar()
    print(f"  connected to '{db_name}'")

    # 1. Apply each SQL file in order ---------------------------------------
    for path in SQL_FILES:
        if not path.exists():
            return fatal(f"SQL file missing: {path}")
        print(f"\nApplying {path.relative_to(PROJECT_ROOT)} ...")
        try:
            apply_file(engine, path)
            print(f"  ok")
        except Exception as e:
            return fatal(f"failed applying {path.name}: {e}")

    # 2. Verify dimensions --------------------------------------------------
    print("\nVerification — dimensions:")
    with engine.connect() as conn:
        for tbl in ("dim_date", "dim_mode", "dim_delay_cause"):
            n = conn.execute(text(f"SELECT COUNT(*) FROM public.{tbl}")).scalar()
            print(f"  public.{tbl:18s}  rows = {n:,}")

    # 3. Verify views by selecting one row each -----------------------------
    print("\nVerification — reporting views (row counts):")
    views = [
        "vw_kpi_summary",
        "vw_incidents_by_mode_year_month",
        "vw_top_causes_by_mode",
        "vw_top_hotspots_by_mode",
        "vw_incidents_by_hour",
        "vw_incidents_by_dow",
        "vw_priority_matrix",
    ]
    with engine.connect() as conn:
        for v in views:
            n = conn.execute(text(f"SELECT COUNT(*) FROM public.{v}")).scalar()
            print(f"  public.{v:34s}  rows = {n:,}")

    # 4. Spot-check the KPI summary -----------------------------------------
    print("\nKPI summary spot-check:")
    with engine.connect() as conn:
        row = conn.execute(text("SELECT * FROM public.vw_kpi_summary")).mappings().one()
    for k, v in row.items():
        print(f"  {k:35s} = {v}")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
