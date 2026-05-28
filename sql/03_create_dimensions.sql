-- sql/03_create_dimensions.sql
-- TTC Transit Reliability Analytics — Stage 3
--
-- Creates and populates three dimension tables that the reporting views
-- (sql/05_reporting_views.sql) and Power BI will join the fact table to:
--
--   dim_date          — full calendar 2022-01-01 to 2027-12-31, with
--                       derived attributes (quarter, month, week, weekend
--                       flag, season). Generated via generate_series.
--   dim_mode          — three rows, one per transit mode. Trivial in
--                       content but completes the star-schema pattern.
--   dim_delay_cause   — one row per unique (transit_mode, delay_code,
--                       delay_description) combination seen in the fact.
--                       Populated by SELECT DISTINCT from the fact table.
--                       delay_category is left NULL for V1 — see the
--                       Stage 2 deferral in docs/decisions.md.
--
-- Two dimensions deliberately omitted from V1 per the project plan:
--   dim_time          — only 24 distinct hours; `hour` is already in the
--                       fact, and `is_rush_hour` lives as a CASE in views.
--   dim_route_location — project_plan.md §5 says "do not over-engineer".
--
-- This script is idempotent (DROP TABLE IF EXISTS at the top of each
-- block, then CREATE + INSERT).

-- =========================================================================
-- 1. dim_date
-- =========================================================================
DROP TABLE IF EXISTS public.dim_date;

CREATE TABLE public.dim_date (
    date_key            INTEGER     PRIMARY KEY,   -- YYYYMMDD form, e.g. 20220101
    event_date          DATE        NOT NULL UNIQUE,
    year                INTEGER     NOT NULL,
    quarter             INTEGER     NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month               INTEGER     NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name          TEXT        NOT NULL,
    week_of_year        INTEGER     NOT NULL,
    day_of_week         TEXT        NOT NULL,
    day_of_week_num     INTEGER     NOT NULL CHECK (day_of_week_num BETWEEN 1 AND 7),
    is_weekend          BOOLEAN     NOT NULL,
    season              TEXT        NOT NULL CHECK (season IN ('Winter', 'Spring', 'Summer', 'Fall'))
);

COMMENT ON TABLE public.dim_date IS
    'Calendar dimension covering 2022-2027. One row per calendar date.';

INSERT INTO public.dim_date (
    date_key, event_date, year, quarter, month, month_name,
    week_of_year, day_of_week, day_of_week_num, is_weekend, season
)
SELECT
    CAST(TO_CHAR(d::date, 'YYYYMMDD') AS INTEGER)   AS date_key,
    d::date                                          AS event_date,
    EXTRACT(YEAR    FROM d)::INTEGER                 AS year,
    EXTRACT(QUARTER FROM d)::INTEGER                 AS quarter,
    EXTRACT(MONTH   FROM d)::INTEGER                 AS month,
    TRIM(TO_CHAR(d, 'Month'))                        AS month_name,
    EXTRACT(WEEK    FROM d)::INTEGER                 AS week_of_year,
    TRIM(TO_CHAR(d, 'Day'))                          AS day_of_week,
    EXTRACT(ISODOW  FROM d)::INTEGER                 AS day_of_week_num,
    EXTRACT(ISODOW  FROM d) IN (6, 7)                AS is_weekend,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM d) IN (3,  4, 5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM d) IN (6,  7, 8) THEN 'Summer'
        ELSE                                          'Fall'
    END                                              AS season
FROM generate_series(
    '2022-01-01'::date,
    '2027-12-31'::date,
    '1 day'::interval
) AS d;


-- =========================================================================
-- 2. dim_mode
-- =========================================================================
DROP TABLE IF EXISTS public.dim_mode;

CREATE TABLE public.dim_mode (
    mode_key        SMALLINT    PRIMARY KEY,
    transit_mode    TEXT        NOT NULL UNIQUE
                                CHECK (transit_mode IN ('Subway', 'Bus', 'Streetcar'))
);

COMMENT ON TABLE public.dim_mode IS
    'Transit mode dimension. Three rows. Joined to fact.transit_mode.';

INSERT INTO public.dim_mode (mode_key, transit_mode) VALUES
    (1, 'Subway'),
    (2, 'Bus'),
    (3, 'Streetcar');


-- =========================================================================
-- 3. dim_delay_cause
-- =========================================================================
-- One row per unique (transit_mode, delay_code, delay_description). The
-- (mode, code) pair joins the fact for the coded-era rows; for the
-- bus/streetcar 2022-2024 text-only rows, delay_code is NULL and the
-- join must include delay_description (or queries can just GROUP BY
-- fact.delay_description directly, which is what most views do).
--
-- delay_category is reserved for a future hand-built mapping (mechanical
-- / operations / incident / passenger / external / unknown). Left NULL
-- for V1 — see docs/decisions.md notes on deferred derived columns.
DROP TABLE IF EXISTS public.dim_delay_cause;

CREATE TABLE public.dim_delay_cause (
    cause_key           SERIAL      PRIMARY KEY,
    transit_mode        TEXT        NOT NULL
                                    CHECK (transit_mode IN ('Subway', 'Bus', 'Streetcar')),
    delay_code          TEXT,        -- nullable: text-only era rows have no code
    delay_description   TEXT        NOT NULL,
    delay_category      TEXT,        -- reserved for V2 categorisation
    UNIQUE NULLS NOT DISTINCT (transit_mode, delay_code, delay_description)
);

COMMENT ON TABLE public.dim_delay_cause IS
    'Delay-cause dimension. One row per unique (transit_mode, delay_code, delay_description). delay_category reserved for V2.';

INSERT INTO public.dim_delay_cause (transit_mode, delay_code, delay_description)
SELECT DISTINCT
    transit_mode,
    delay_code,
    delay_description
FROM public.fact_delay_events;
