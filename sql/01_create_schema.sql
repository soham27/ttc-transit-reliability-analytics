-- sql/01_create_schema.sql
-- TTC Transit Reliability Analytics — Stage 3
--
-- Defines the fact_delay_events table in the public schema of the
-- ttc_reliability database. Column types match the canonical cleaned CSV
-- written by `scripts/01_clean_delay_data.py`
-- (data/processed/fact_delay_events.csv, 403,155 rows × 19 columns).
--
-- Prerequisites: run `sql/00_create_database.sql` first, then connect
-- pgAdmin's Query Tool to the `ttc_reliability` database before running
-- this file.
--
-- This script is idempotent: it drops the table if it already exists.
-- That is safe because the canonical source is the CSV — re-running the
-- loader rebuilds the table identically.

DROP TABLE IF EXISTS public.fact_delay_events;

CREATE TABLE public.fact_delay_events (
    -- Surrogate primary key assigned by the cleaning script (1..N over the
    -- combined fact). Used as the join key for future dimension tables.
    event_id            INTEGER     PRIMARY KEY,

    -- Provenance: which mode and which raw file each row came from.
    transit_mode        TEXT        NOT NULL
                                    CHECK (transit_mode IN ('Subway', 'Bus', 'Streetcar')),
    source_file         TEXT        NOT NULL,

    -- Event timing. event_date + event_time are the raw fields; the rest
    -- are derived in cleaning so SQL doesn't have to repeat the EXTRACT
    -- calls in every query. event_time is kept as TEXT 'HH:MM' rather
    -- than TIME because TTC files vary in precision (no seconds).
    event_date          DATE        NOT NULL,
    event_time          TEXT        NOT NULL,
    event_datetime      TIMESTAMP   NOT NULL,
    year                INTEGER     NOT NULL,
    month               INTEGER     NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name          TEXT        NOT NULL,
    day_of_week         TEXT        NOT NULL,
    hour                INTEGER     NOT NULL CHECK (hour BETWEEN 0 AND 23),

    -- Where the delay happened. All three are nullable because the raw
    -- TTC data legitimately omits them for some events (notably ~22% of
    -- rows have no `bound`; see audit notebook §9.7).
    line                TEXT,
    station             TEXT,
    bound               TEXT,

    -- Why the delay happened. delay_code is null for the 174,557 +
    -- 46,274 bus/streetcar 2022-2024 rows (which only carried free text)
    -- and for the 16 XXXXX-placeholder rows the cleaner scrubbed.
    -- delay_description is always populated — either copied from the
    -- raw Incident column, or joined from Code Descriptions.csv, or
    -- filled with 'Unknown (CODE)' for any code missing from the lookup.
    delay_code          TEXT,
    delay_description   TEXT        NOT NULL,

    -- Magnitude. delay_minutes is the customer-facing impact;
    -- gap_minutes is the service-gap on the line.
    delay_minutes       INTEGER     NOT NULL CHECK (delay_minutes >= 0),
    gap_minutes         INTEGER     NOT NULL CHECK (gap_minutes >= 0),

    -- TTC vehicle ID. A value of 0 means "no specific vehicle"; not nullable.
    vehicle             INTEGER     NOT NULL
);

COMMENT ON TABLE public.fact_delay_events IS
    'TTC delay events, all three modes (subway/bus/streetcar), 2022 -> present. One row per recorded delay.';

-- Indexes are intentionally minimal here. With ~403k rows Postgres can
-- seq-scan in well under a second, and premature indexes slow inserts and
-- waste disk. Add indexes (see sql/05_reporting_views.sql later) only
-- when specific queries are measurably slow.
