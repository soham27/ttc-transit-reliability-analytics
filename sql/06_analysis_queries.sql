-- sql/06_analysis_queries.sql
-- TTC Transit Reliability Analytics — Stage 3
--
-- A cookbook of analytical SELECTs you can paste into pgAdmin's Query
-- Tool to answer the business questions in docs/project_plan.md §6.
-- Each query is a standalone block; run them one at a time.
--
-- Most of these read from the reporting views (sql/05_reporting_views.sql)
-- so the analytical logic stays in one place (the views) and these queries
-- are just slices and filters on top of that logic.
--
-- Stage 4 (Exploratory Analysis) will run these from a notebook and turn
-- the results into charts, written findings, and Power BI inputs.


-- =========================================================================
-- Q1. Headline numbers (Executive Summary)
-- =========================================================================
SELECT * FROM public.vw_kpi_summary;


-- =========================================================================
-- Q2. Top 10 delay causes per mode, ranked by total delay minutes
--     (this is what feeds the Pareto chart on the Root Cause page)
-- =========================================================================
SELECT
    transit_mode,
    rank_by_total_delay,
    delay_description,
    incident_count,
    total_delay_minutes,
    avg_delay_minutes,
    pct_of_mode_delay_minutes,
    cumulative_pct_of_mode_delay_minutes
FROM public.vw_top_causes_by_mode
WHERE rank_by_total_delay <= 10
ORDER BY transit_mode, rank_by_total_delay;


-- =========================================================================
-- Q3. Pareto answer: how many causes explain 80% of each mode's delay
--     minutes? This is the headline "concentration" insight per mode.
-- =========================================================================
SELECT
    transit_mode,
    COUNT(*) AS causes_explaining_80pct,
    MIN(cumulative_pct_of_mode_delay_minutes) AS first_threshold_pct
FROM public.vw_top_causes_by_mode
WHERE cumulative_pct_of_mode_delay_minutes <= 80
GROUP BY transit_mode
ORDER BY transit_mode;


-- =========================================================================
-- Q4. Top 15 hotspots per mode, ranked by total delay minutes
-- =========================================================================
SELECT
    transit_mode,
    rank_by_total_delay,
    station,
    incident_count,
    total_delay_minutes,
    avg_delay_minutes,
    pct_of_mode_delay_minutes
FROM public.vw_top_hotspots_by_mode
WHERE rank_by_total_delay <= 15
ORDER BY transit_mode, rank_by_total_delay;


-- =========================================================================
-- Q5. Year-over-year totals per mode — is reliability improving or worsening?
-- =========================================================================
SELECT
    transit_mode,
    year,
    SUM(incident_count)       AS incident_count,
    SUM(total_delay_minutes)  AS total_delay_minutes,
    ROUND(AVG(avg_delay_minutes)::numeric, 2) AS avg_avg_delay_minutes
FROM public.vw_incidents_by_mode_year_month
GROUP BY transit_mode, year
ORDER BY transit_mode, year;


-- =========================================================================
-- Q6. Monthly seasonality — average per-month totals across years.
--     (Smooths out year-specific noise to show recurring annual patterns.)
-- =========================================================================
SELECT
    transit_mode,
    month,
    month_name,
    ROUND(AVG(incident_count)::numeric, 0)        AS avg_incidents_per_month,
    ROUND(AVG(total_delay_minutes)::numeric, 0)   AS avg_total_delay_per_month
FROM public.vw_incidents_by_mode_year_month
GROUP BY transit_mode, month, month_name
ORDER BY transit_mode, month;


-- =========================================================================
-- Q7. Rush-hour vs off-peak comparison
-- =========================================================================
SELECT
    transit_mode,
    time_period,
    SUM(incident_count)       AS incident_count,
    SUM(total_delay_minutes)  AS total_delay_minutes,
    ROUND(AVG(avg_delay_minutes)::numeric, 2) AS avg_delay_minutes_per_incident
FROM public.vw_incidents_by_hour
GROUP BY transit_mode, time_period
ORDER BY transit_mode,
         CASE time_period
             WHEN 'Late Night / Early Morning' THEN 1
             WHEN 'Morning Rush'               THEN 2
             WHEN 'Midday'                     THEN 3
             WHEN 'Afternoon Rush'             THEN 4
             WHEN 'Evening'                    THEN 5
         END;


-- =========================================================================
-- Q8. Weekday vs weekend totals per mode
-- =========================================================================
SELECT
    transit_mode,
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    SUM(incident_count)      AS incident_count,
    SUM(total_delay_minutes) AS total_delay_minutes,
    ROUND(AVG(avg_delay_minutes)::numeric, 2) AS avg_delay_minutes_per_incident
FROM public.vw_incidents_by_dow
GROUP BY transit_mode, is_weekend
ORDER BY transit_mode, is_weekend;


-- =========================================================================
-- Q9. Delay-magnitude distribution — percentiles per mode.
--     Lets us pick a defensible "major delay" threshold for V2 later
--     instead of guessing.
-- =========================================================================
SELECT
    transit_mode,
    COUNT(*)                                                                    AS n,
    ROUND(AVG(delay_minutes)::numeric, 2)                                       AS mean,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY delay_minutes)::numeric        AS p50_median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delay_minutes)::numeric        AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delay_minutes)::numeric        AS p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delay_minutes)::numeric        AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY delay_minutes)::numeric        AS p99,
    MAX(delay_minutes)                                                           AS max
FROM public.fact_delay_events
GROUP BY transit_mode
ORDER BY transit_mode;


-- =========================================================================
-- Q10. Urgent-priority causes per mode (top-right quadrant of the matrix)
-- =========================================================================
SELECT
    transit_mode,
    delay_description,
    incident_count,
    total_delay_minutes,
    avg_delay_minutes,
    mode_freq_threshold_p75,
    mode_sev_threshold_p75
FROM public.vw_priority_matrix
WHERE priority_quadrant = 'Urgent Priority'
ORDER BY transit_mode, total_delay_minutes DESC;
