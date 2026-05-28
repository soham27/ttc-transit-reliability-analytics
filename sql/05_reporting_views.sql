-- sql/05_reporting_views.sql
-- TTC Transit Reliability Analytics — Stage 3
--
-- Six reporting views. Each one answers a specific business question from
-- docs/project_plan.md §6 and feeds a Power BI dashboard page (§8).
-- Power BI Desktop connects to ttc_reliability via the Postgres connector
-- and reads these views as if they were tables.
--
-- View                              | Page in Power BI (§8)        | Question answered
-- ----------------------------------|------------------------------|---------------------------------------
-- vw_kpi_summary                    | Executive Summary (cards)    | Total incidents / delay minutes / avg
-- vw_incidents_by_mode_year_month   | Executive + Mode Comparison  | Monthly trend per mode
-- vw_top_causes_by_mode             | Root Cause Analysis (Pareto) | What causes the most delay minutes?
-- vw_top_hotspots_by_mode           | Hotspot Analysis             | Which stations/locations are worst?
-- vw_incidents_by_hour              | Time Patterns (heatmap)      | When during the day are delays worst?
-- vw_incidents_by_dow               | Time Patterns                | Which weekday is worst per mode?
-- vw_priority_matrix                | Action Priority Matrix       | Frequency × severity quadrant
--
-- All views are idempotent (CREATE OR REPLACE).

-- =========================================================================
-- 1. vw_kpi_summary — single-row headline numbers for the Executive page
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_kpi_summary AS
SELECT
    COUNT(*)                                        AS total_incidents,
    SUM(delay_minutes)                              AS total_delay_minutes,
    ROUND(AVG(delay_minutes)::numeric, 2)           AS avg_delay_minutes_per_incident,
    MIN(event_date)                                 AS data_start_date,
    MAX(event_date)                                 AS data_end_date,
    (
        SELECT transit_mode
        FROM public.fact_delay_events
        GROUP BY transit_mode
        ORDER BY SUM(delay_minutes) DESC
        LIMIT 1
    )                                               AS worst_mode_by_total_delay,
    (
        SELECT transit_mode
        FROM public.fact_delay_events
        GROUP BY transit_mode
        ORDER BY COUNT(*) DESC
        LIMIT 1
    )                                               AS worst_mode_by_incident_count
FROM public.fact_delay_events;

COMMENT ON VIEW public.vw_kpi_summary IS
    'One row of headline KPIs for the Executive Summary page.';


-- =========================================================================
-- 2. vw_incidents_by_mode_year_month — monthly trend per mode
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_incidents_by_mode_year_month AS
SELECT
    transit_mode,
    year,
    month,
    month_name,
    MAKE_DATE(year, month, 1)                       AS month_start,  -- friendly axis date for Power BI
    COUNT(*)                                        AS incident_count,
    SUM(delay_minutes)                              AS total_delay_minutes,
    ROUND(AVG(delay_minutes)::numeric, 2)           AS avg_delay_minutes
FROM public.fact_delay_events
GROUP BY transit_mode, year, month, month_name
ORDER BY transit_mode, year, month;

COMMENT ON VIEW public.vw_incidents_by_mode_year_month IS
    'Monthly aggregate per transit mode. ~150 rows (3 modes × 50 months). Drives the trend line chart.';


-- =========================================================================
-- 3. vw_top_causes_by_mode — ranked delay descriptions with Pareto cumulative %
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_top_causes_by_mode AS
SELECT
    transit_mode,
    delay_description,
    delay_code,                                                                     -- null for the 2022-24 text-only era rows
    incident_count,
    total_delay_minutes,
    avg_delay_minutes,
    rank_by_total_delay,
    rank_by_incident_count,
    ROUND(
        100.0 * total_delay_minutes
             / SUM(total_delay_minutes) OVER (PARTITION BY transit_mode),
        2
    )                                                                               AS pct_of_mode_delay_minutes,
    ROUND(
        100.0 * SUM(total_delay_minutes) OVER (
                    PARTITION BY transit_mode
                    ORDER BY total_delay_minutes DESC
                    ROWS UNBOUNDED PRECEDING
                )
             / SUM(total_delay_minutes) OVER (PARTITION BY transit_mode),
        2
    )                                                                               AS cumulative_pct_of_mode_delay_minutes
FROM (
    SELECT
        transit_mode,
        delay_description,
        MIN(delay_code)                                AS delay_code,               -- single representative code per description
        COUNT(*)                                       AS incident_count,
        SUM(delay_minutes)                             AS total_delay_minutes,
        ROUND(AVG(delay_minutes)::numeric, 2)          AS avg_delay_minutes,
        RANK() OVER (PARTITION BY transit_mode ORDER BY SUM(delay_minutes) DESC) AS rank_by_total_delay,
        RANK() OVER (PARTITION BY transit_mode ORDER BY COUNT(*) DESC)           AS rank_by_incident_count
    FROM public.fact_delay_events
    GROUP BY transit_mode, delay_description
) base
ORDER BY transit_mode, rank_by_total_delay;

COMMENT ON VIEW public.vw_top_causes_by_mode IS
    'One row per (transit_mode, delay_description) with ranks and Pareto cumulative %. Power BI filters by rank_by_total_delay <= N for top-N charts.';


-- =========================================================================
-- 4. vw_top_hotspots_by_mode — ranked stations / locations
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_top_hotspots_by_mode AS
SELECT
    transit_mode,
    station,
    COUNT(*)                                                                       AS incident_count,
    SUM(delay_minutes)                                                             AS total_delay_minutes,
    ROUND(AVG(delay_minutes)::numeric, 2)                                          AS avg_delay_minutes,
    RANK() OVER (PARTITION BY transit_mode ORDER BY SUM(delay_minutes) DESC)       AS rank_by_total_delay,
    RANK() OVER (PARTITION BY transit_mode ORDER BY COUNT(*) DESC)                 AS rank_by_incident_count,
    ROUND(
        100.0 * SUM(delay_minutes)
             / SUM(SUM(delay_minutes)) OVER (PARTITION BY transit_mode),
        2
    )                                                                              AS pct_of_mode_delay_minutes
FROM public.fact_delay_events
WHERE station IS NOT NULL
GROUP BY transit_mode, station
ORDER BY transit_mode, rank_by_total_delay;

COMMENT ON VIEW public.vw_top_hotspots_by_mode IS
    'One row per (transit_mode, station). Excludes the 2 rows with null station. Power BI filters by rank for top-N hotspot charts.';


-- =========================================================================
-- 5. vw_incidents_by_hour — hour-of-day rollup
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_incidents_by_hour AS
SELECT
    transit_mode,
    hour,
    CASE
        WHEN hour BETWEEN  7 AND  9 THEN 'Morning Rush'
        WHEN hour BETWEEN 16 AND 18 THEN 'Afternoon Rush'
        WHEN hour BETWEEN 10 AND 15 THEN 'Midday'
        WHEN hour BETWEEN 19 AND 22 THEN 'Evening'
        ELSE                             'Late Night / Early Morning'
    END                                             AS time_period,
    COUNT(*)                                        AS incident_count,
    SUM(delay_minutes)                              AS total_delay_minutes,
    ROUND(AVG(delay_minutes)::numeric, 2)           AS avg_delay_minutes
FROM public.fact_delay_events
GROUP BY transit_mode, hour
ORDER BY transit_mode, hour;

COMMENT ON VIEW public.vw_incidents_by_hour IS
    'Hour-of-day rollup per mode. 72 rows (3 modes × 24 hours). Includes rush-hour bucket label for slicing.';


-- =========================================================================
-- 6. vw_incidents_by_dow — day-of-week rollup, joined to dim_date for is_weekend
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_incidents_by_dow AS
SELECT
    f.transit_mode,
    f.day_of_week,
    d.day_of_week_num,                              -- for stable weekday ordering in Power BI
    d.is_weekend,
    COUNT(*)                                        AS incident_count,
    SUM(f.delay_minutes)                            AS total_delay_minutes,
    ROUND(AVG(f.delay_minutes)::numeric, 2)         AS avg_delay_minutes
FROM public.fact_delay_events f
JOIN public.dim_date          d  ON f.event_date = d.event_date
GROUP BY f.transit_mode, f.day_of_week, d.day_of_week_num, d.is_weekend
ORDER BY f.transit_mode, d.day_of_week_num;

COMMENT ON VIEW public.vw_incidents_by_dow IS
    'Weekday rollup per mode. 21 rows. Joins fact to dim_date so charts can sort Mon..Sun and split weekend vs weekday.';


-- =========================================================================
-- 7. vw_priority_matrix — frequency × severity quadrant per cause per mode
-- =========================================================================
-- Mode-specific thresholds (75th percentile within each mode) so subway,
-- bus and streetcar are compared against their own distributions rather
-- than against each other.
CREATE OR REPLACE VIEW public.vw_priority_matrix AS
WITH cause_stats AS (
    SELECT
        transit_mode,
        delay_description,
        COUNT(*)                                    AS incident_count,
        SUM(delay_minutes)                          AS total_delay_minutes,
        AVG(delay_minutes)                          AS avg_delay_minutes
    FROM public.fact_delay_events
    GROUP BY transit_mode, delay_description
),
thresholds AS (
    SELECT
        transit_mode,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY incident_count)    AS freq_threshold,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_delay_minutes) AS sev_threshold
    FROM cause_stats
    GROUP BY transit_mode
)
SELECT
    c.transit_mode,
    c.delay_description,
    c.incident_count,
    c.total_delay_minutes,
    ROUND(c.avg_delay_minutes::numeric, 2)          AS avg_delay_minutes,
    ROUND(t.freq_threshold::numeric, 2)             AS mode_freq_threshold_p75,
    ROUND(t.sev_threshold::numeric, 2)              AS mode_sev_threshold_p75,
    CASE
        WHEN c.incident_count    >= t.freq_threshold
         AND c.avg_delay_minutes >= t.sev_threshold THEN 'Urgent Priority'
        WHEN c.incident_count    >= t.freq_threshold
         AND c.avg_delay_minutes <  t.sev_threshold THEN 'Process Improvement'
        WHEN c.incident_count    <  t.freq_threshold
         AND c.avg_delay_minutes >= t.sev_threshold THEN 'Risk Monitoring'
        ELSE                                             'Lower Priority'
    END                                             AS priority_quadrant
FROM       cause_stats c
JOIN       thresholds  t ON c.transit_mode = t.transit_mode
ORDER BY   c.transit_mode, c.total_delay_minutes DESC;

COMMENT ON VIEW public.vw_priority_matrix IS
    'Frequency × severity matrix per (transit_mode, delay_description). Quadrant thresholds are mode-specific 75th percentiles so modes are compared to their own distribution.';
