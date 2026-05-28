"""
01_clean_delay_data.py — TTC Transit Reliability Analytics, Stage 2

Reproducible cleaning pipeline. Ports the logic proven in
`notebooks/02_data_cleaning.ipynb` (which is the narrative version) into a
single runnable script.

Reads:
  data/raw/{subway,bus,streetcar}/* (XLSX for 2022-2024, CSV for 2025+)
  data/raw/{mode}/Code Descriptions.csv (delay-code -> description lookup)

Writes:
  data/processed/fact_subway.csv
  data/processed/fact_bus.csv
  data/processed/fact_streetcar.csv
  data/processed/fact_delay_events.csv  (the canonical combined fact)

Usage (from anywhere):
  .venv/Scripts/python.exe scripts/01_clean_delay_data.py

Design notes (see docs/decisions.md for full rationale):
  - Decision 8: every XLSX is read with sheet_name=None and stacked, even
    though the audit found all current files are single-sheet. Cheap
    insurance against TTC reverting to monthly tabs.
  - Decision 9: bus/streetcar 2022-2024 store delay reason as free-text
    `Incident`; 2025+ uses an alphanumeric `Code` that joins to a lookup.
    Both sources are funnelled into a single `delay_description` field.
  - Decision 10: bus/streetcar 2025+ `Line` strings like "102 MARKHAM ROAD"
    are trimmed to just the route number to match the 2022-2024 convention.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import pandas as pd


# --- Paths -------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW = PROJECT_ROOT / "data" / "raw"
PROCESSED = PROJECT_ROOT / "data" / "processed"


# --- Canonical schema --------------------------------------------------------
TARGET_COLUMNS = [
    "event_id",
    "transit_mode",
    "source_file",
    "event_date",
    "event_time",
    "event_datetime",
    "year",
    "month",
    "month_name",
    "day_of_week",
    "hour",
    "line",
    "station",
    "bound",
    "delay_code",
    "delay_description",
    "delay_minutes",
    "gap_minutes",
    "vehicle",
]


# --- Per-mode column renames -------------------------------------------------
SUBWAY_RENAME = {
    "Date": "event_date", "Time": "event_time", "Station": "station",
    "Code": "delay_code", "Min Delay": "delay_minutes", "Min Gap": "gap_minutes",
    "Bound": "bound", "Line": "line", "Vehicle": "vehicle",
}

BUS_RENAME_XLSX = {
    "Date": "event_date", "Route": "line", "Time": "event_time",
    "Location": "station", "Incident": "delay_description",
    "Min Delay": "delay_minutes", "Min Gap": "gap_minutes",
    "Direction": "bound", "Vehicle": "vehicle",
}

BUS_RENAME_CSV = {
    "Date": "event_date", "Line": "line", "Time": "event_time",
    "Station": "station", "Code": "delay_code",
    "Min Delay": "delay_minutes", "Min Gap": "gap_minutes",
    "Bound": "bound", "Vehicle": "vehicle",
}

STREETCAR_RENAME_XLSX = {
    "Date": "event_date", "Time": "event_time", "Line": "line",
    "Location": "station", "Bound": "bound", "Incident": "delay_description",
    "Min Delay": "delay_minutes", "Min Gap": "gap_minutes", "Vehicle": "vehicle",
}

STREETCAR_RENAME_CSV = {
    "Date": "event_date", "Time": "event_time", "Line": "line",
    "Station": "station", "Bound": "bound", "Code": "delay_code",
    "Min Delay": "delay_minutes", "Min Gap": "gap_minutes", "Vehicle": "vehicle",
}


# --- Helpers -----------------------------------------------------------------
_NUM_PREFIX = re.compile(r"^(\d+)")


def read_excel_stacked(path: Path) -> pd.DataFrame:
    """Read every sheet in an XLSX and concatenate. See Decision 8."""
    sheets = pd.read_excel(path, sheet_name=None)
    parts = [s.assign(_sheet=name) for name, s in sheets.items()]
    return pd.concat(parts, ignore_index=True, sort=False)


def extract_route_number(value):
    """'102 MARKHAM ROAD' -> '102'. See Decision 10."""
    if pd.isna(value):
        return value
    s = str(value).strip()
    m = _NUM_PREFIX.match(s)
    return m.group(1) if m else s


def attach_codes(df: pd.DataFrame, lookup: pd.DataFrame) -> pd.DataFrame:
    """Left-join a code-description lookup and fill empty delay_description.
    Rows that already have delay_description (bus/streetcar 2022-2024) are
    untouched."""
    lk = (
        lookup.rename(columns={"CODE": "delay_code", "DESCRIPTION": "_desc_from_lookup"})
              [["delay_code", "_desc_from_lookup"]]
              .drop_duplicates(subset="delay_code")
    )
    out = df.merge(lk, on="delay_code", how="left")
    needs = out["delay_description"].isna() & out["_desc_from_lookup"].notna()
    out.loc[needs, "delay_description"] = out.loc[needs, "_desc_from_lookup"]
    return out.drop(columns=["_desc_from_lookup"])


def add_time_decomposition(df: pd.DataFrame) -> pd.DataFrame:
    """Build event_datetime from date+time and derive year/month/etc."""
    date = pd.to_datetime(df["event_date"], errors="coerce")
    time_str = df["event_time"].astype(str).fillna("00:00")
    dt = pd.to_datetime(date.dt.strftime("%Y-%m-%d") + " " + time_str, errors="coerce")
    return df.assign(
        event_date=date.dt.date,
        event_datetime=dt,
        year=dt.dt.year,
        month=dt.dt.month,
        month_name=dt.dt.month_name(),
        day_of_week=dt.dt.day_name(),
        hour=dt.dt.hour,
    )


def finalise(df: pd.DataFrame) -> pd.DataFrame:
    """Scrub the XXXXX placeholder, label unmatched codes, apply canonical
    column order."""
    placeholder = df["delay_code"] == "XXXXX"
    df.loc[placeholder, "delay_description"] = "Unknown (XXXXX placeholder)"
    df.loc[placeholder, "delay_code"] = pd.NA

    needs_label = df["delay_code"].notna() & df["delay_description"].isna()
    df.loc[needs_label, "delay_description"] = (
        "Unknown (" + df.loc[needs_label, "delay_code"].astype(str) + ")"
    )

    for col in TARGET_COLUMNS:
        if col not in df.columns:
            df[col] = pd.NA
    return df[TARGET_COLUMNS].copy()


# --- Per-mode pipelines ------------------------------------------------------
def clean_subway() -> pd.DataFrame:
    lookup = pd.read_csv(RAW / "subway" / "Code Descriptions.csv")
    paths = [
        RAW / "subway" / "ttc-subway-delay-data-2022.xlsx",
        RAW / "subway" / "ttc-subway-delay-data-2023.xlsx",
        RAW / "subway" / "ttc-subway-delay-data-2024.xlsx",
        RAW / "subway" / "TTC Subway Delay Data since 2025.csv",
    ]
    parts = []
    for p in paths:
        df = read_excel_stacked(p) if p.suffix == ".xlsx" else pd.read_csv(p)
        df = df.rename(columns=SUBWAY_RENAME)
        df["transit_mode"] = "Subway"
        df["source_file"] = p.name
        df["delay_description"] = pd.NA
        parts.append(df)
    df = pd.concat(parts, ignore_index=True, sort=False)
    df = attach_codes(df, lookup)
    df = add_time_decomposition(df)
    return finalise(df)


def clean_bus() -> pd.DataFrame:
    lookup = pd.read_csv(RAW / "bus" / "Code Descriptions.csv")
    xlsx_paths = [
        RAW / "bus" / "ttc-bus-delay-data-2022.xlsx",
        RAW / "bus" / "ttc-bus-delay-data-2023.xlsx",
        RAW / "bus" / "ttc-bus-delay-data-2024.xlsx",
    ]
    csv_path = RAW / "bus" / "TTC Bus Delay Data since 2025.csv"

    parts = []
    for p in xlsx_paths:
        df = read_excel_stacked(p).rename(columns=BUS_RENAME_XLSX)
        df["delay_code"] = pd.NA
        df["line"] = df["line"].astype(str)
        df["transit_mode"] = "Bus"
        df["source_file"] = p.name
        parts.append(df)

    csv = pd.read_csv(csv_path).rename(columns=BUS_RENAME_CSV)
    csv["line"] = csv["line"].apply(extract_route_number)
    csv["delay_description"] = pd.NA
    csv["transit_mode"] = "Bus"
    csv["source_file"] = csv_path.name
    parts.append(csv)

    df = pd.concat(parts, ignore_index=True, sort=False)
    df = attach_codes(df, lookup)
    df = add_time_decomposition(df)
    return finalise(df)


def clean_streetcar() -> pd.DataFrame:
    lookup = pd.read_csv(RAW / "streetcar" / "Code Descriptions.csv")
    xlsx_paths = [
        RAW / "streetcar" / "ttc-streetcar-delay-data-2022.xlsx",
        RAW / "streetcar" / "ttc-streetcar-delay-data-2023.xlsx",
        RAW / "streetcar" / "ttc-streetcar-delay-data-2024.xlsx",
    ]
    csv_path = RAW / "streetcar" / "TTC Streetcar Delay Data since 2025.csv"

    parts = []
    for p in xlsx_paths:
        df = read_excel_stacked(p).rename(columns=STREETCAR_RENAME_XLSX)
        df["delay_code"] = pd.NA
        df["line"] = df["line"].astype(str)
        df["transit_mode"] = "Streetcar"
        df["source_file"] = p.name
        parts.append(df)

    csv = pd.read_csv(csv_path).rename(columns=STREETCAR_RENAME_CSV)
    csv["line"] = csv["line"].apply(extract_route_number)
    csv["delay_description"] = pd.NA
    csv["transit_mode"] = "Streetcar"
    csv["source_file"] = csv_path.name
    parts.append(csv)

    df = pd.concat(parts, ignore_index=True, sort=False)
    df = attach_codes(df, lookup)
    df = add_time_decomposition(df)
    return finalise(df)


# --- Main --------------------------------------------------------------------
def main() -> int:
    PROCESSED.mkdir(parents=True, exist_ok=True)

    print("Reading and cleaning subway...")
    subway = clean_subway()
    print(f"  {len(subway):,} rows")

    print("Reading and cleaning bus...")
    bus = clean_bus()
    print(f"  {len(bus):,} rows")

    print("Reading and cleaning streetcar...")
    streetcar = clean_streetcar()
    print(f"  {len(streetcar):,} rows")

    print("Combining...")
    combined = pd.concat([subway, bus, streetcar], ignore_index=True)
    combined["event_id"] = range(1, len(combined) + 1)
    combined = combined[TARGET_COLUMNS]

    # Lightweight self-check. Failing here means the cleaning regressed and
    # the script should abort rather than overwrite the canonical CSVs.
    expected_total = 403_155
    if len(combined) != expected_total:
        print(
            f"FATAL: combined row count {len(combined):,} != expected {expected_total:,}. "
            f"The raw inputs may have changed — re-run notebooks/01_data_audit.ipynb "
            f"and update this script's expected total."
        )
        return 1

    critical = ["event_date", "event_datetime", "transit_mode", "delay_description"]
    nulls = combined[critical].isna().sum()
    if nulls.any():
        print("FATAL: nulls in critical columns:")
        print(nulls[nulls > 0])
        return 1

    print("Writing CSVs...")
    for mode_name, df in [("subway", subway), ("bus", bus), ("streetcar", streetcar)]:
        out = PROCESSED / f"fact_{mode_name}.csv"
        df.to_csv(out, index=False, date_format="%Y-%m-%d %H:%M:%S")
        print(f"  wrote {out.relative_to(PROJECT_ROOT)}  ({len(df):,} rows)")

    combined_out = PROCESSED / "fact_delay_events.csv"
    combined.to_csv(combined_out, index=False, date_format="%Y-%m-%d %H:%M:%S")
    print(f"  wrote {combined_out.relative_to(PROJECT_ROOT)}  ({len(combined):,} rows)")
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
