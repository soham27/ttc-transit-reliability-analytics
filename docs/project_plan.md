# Project Plan — TTC Transit Reliability Analytics

This is the full design document. It is **not** loaded into every Claude Code session by
default — read it when working on the relevant stage. Operating rules and locked decisions
live in the lean `CLAUDE.md`; the rationale behind decisions lives in `docs/decisions.md`.

Working title: **TTC Transit Reliability Analytics: Delay Hotspots, Root Causes, and
Service Impact Dashboard**

---

## 1. Business goal

Simulate the work of a data analyst supporting transit-operations leadership. The final
output should help a non-technical stakeholder understand:

- which transit modes experience the most delay incidents;
- which modes create the most total lost service time;
- which routes, stations, lines, or locations are the biggest delay hotspots;
- which delay causes contribute most to total delay minutes;
- when delays are most common (month, weekday, hour);
- which high-impact problem areas should be prioritised first;
- whether the core issue is frequency, severity, or both.

The point is not just to count delays, but to separate **frequent low-impact**, **rare
high-impact**, **high-frequency high-impact**, and **low-priority low-impact** delays —
leading to an action-priority framework.

---

## 2. Scope

**Version 1 uses 2022 onward.** Deliberately excludes 2020–2021 (COVID distortion) and
2018–2019 (pre-COVID structural break). See `docs/decisions.md` (Decision 1) for the full
reasoning and the interview talking point.

Possible future extension: a separate "five-year view including the COVID shock" as a
deliberate historical/policy analysis — *not* part of V1.

---

## 3. Datasets

All data downloaded from official Toronto Open Data pages.

### Core delay event data
| Mode | 2025+ format | 2022–2024 format | Purpose |
|------|--------------|------------------|---------|
| Subway | CSV | XLSX | Subway delay events |
| Bus | CSV | XLSX | Bus delay events |
| Streetcar | CSV | XLSX | Streetcar delay events |

> The 2022–2024 files are Excel. Read them natively; watch for multi-sheet (one-tab-per-month)
> workbooks. See `CLAUDE.md` → *Data notes*.

### Code description / lookup data (CSV, all modes)
Maps delay codes to human-readable descriptions/categories: `subway_code_descriptions.csv`,
`bus_code_descriptions.csv`, `streetcar_code_descriptions.csv`. Prefer CSV across all three
modes for pipeline consistency. The subway `ttc-subway-delay-codes.xlsx` is **reference only**.

### Readme / metadata
Subway Delay Data Readme (XLSX) — explains subway columns/definitions. Keep any equivalent
bus/streetcar readmes if present; otherwise proceed without them.

### Dataset pages
- Subway: https://open.toronto.ca/dataset/ttc-subway-delay-data/
- Bus: https://open.toronto.ca/dataset/ttc-bus-delay-data/
- Streetcar: https://open.toronto.ca/dataset/ttc-streetcar-delay-data/

Optional future enrichments (not in the first cleaning pass):
- GTFS routes/schedules: https://open.toronto.ca/dataset/ttc-routes-and-schedules/
- Merged GTFS: https://open.toronto.ca/dataset/merged-gtfs-ttc-routes-and-schedules/
- Environment Canada climate data: https://climate.weather.gc.ca/

---

## 4. Data audit checklist

For **each delay event dataset** (per mode, per year/format):
- first 5 rows; column names; shape / row count; data types;
- missing-value count and percentage; date min and max;
- unique values for key categorical fields; top 20 delay codes;
- top 20 locations/stations/routes (where applicable);
- impossible-value checks: negative delay/gap minutes, implausibly large delays, unexpected zeros/nulls;
- **(Excel-specific)** sheet count and names; whether sheets are monthly tabs; whether codes
  lost leading zeros; whether dates parsed as serials.

For **each code description dataset**:
- first 5 rows; columns; shape; unique codes; duplicate codes; missing descriptions;
- compare code values against the corresponding delay event file (join feasibility).

Cross-mode questions to answer in the audit:
- Which delay-code column should be used for joins?
- Do code descriptions match the event-file code values?
- Can subway, bus, and streetcar be standardized into one combined fact table?
- Which fields are common across modes? Which are mode-specific?
- Did column headers drift between the XLSX years and the CSV years?

---

## 5. Target data model

One standardized fact table — the consistent reporting layer. Not every mode will have
every field; set missing mode-specific fields to null rather than forcing symmetry.

### `fact_delay_events`
```
event_id, transit_mode, event_date, event_time, event_datetime,
year, month, month_name, day_of_week, hour,
route, line, location, station, direction, vehicle,
delay_code, delay_description, delay_category,
delay_minutes, gap_minutes, is_major_delay, source_file
```

### Dimension tables (SQL stage — confirm against real columns first)
- **`dim_date`**: date_key, event_date, year, quarter, month, month_name, week_of_year,
  day_of_week, is_weekend, season
- **`dim_time`**: time_key, hour, time_period, is_rush_hour
  *(time periods: Early Morning, Morning Rush, Midday, Afternoon Rush, Evening, Late Night)*
- **`dim_mode`**: mode_key, transit_mode *(Subway, Bus, Streetcar)*
- **`dim_delay_cause`**: cause_key, transit_mode, delay_code, delay_description, delay_category
- **`dim_route_location`**: route_location_key, transit_mode, route, line, station, location,
  direction — **do not over-engineer; inspect raw columns first.**

---

## 6. Business questions

**Executive / operations:** most delay incidents by mode; most total delay minutes by mode;
frequency vs severity; top causes by minutes and by count; worst hotspots; time-of-day
burden; worst weekdays; seasonality; concentration (do a few causes/locations drive most
delay minutes?).

**Prioritisation:** which areas are high-frequency *and* high-severity; which causes are rare
but severe; which are common but low-impact; which routes/stations to investigate first;
what leadership should prioritise.

**Dashboard:** headline reliability KPIs; most recent trend change; the category needing most
attention; the mode contributing most system-wide delay; the 30-second executive story.

---

## 7. Analysis ideas (use only where the data supports them)

- **Core:** incidents by mode; total/average/median delay minutes by mode; top causes; top
  stations/routes/locations; patterns by month / weekday / hour; rush-hour vs off-peak.
- **Impact / priority matrix:** frequency (incident count) × severity (avg delay minutes),
  with total impact (total delay minutes). Classify into urgent priority (high freq + high
  sev), process improvement (high freq + low sev), risk monitoring (low freq + high sev),
  lower priority (low freq + low sev).
- **Pareto:** do the top 10–20 causes/routes/locations account for a large share of total
  delay minutes?
- **Trend:** monthly changes, spikes, seasonal effects, outlier days, weekday vs weekend.
- **Optional later:** GTFS stop/route metadata for mapping; weather effects (snow/rain/extreme
  temps); delay-volume forecasting; anomaly detection for bad-service days.

---

## 8. Power BI dashboard plan

Eventual pages (V1 can be a focused subset):
1. **Executive Summary** — KPI cards (total incidents, total delay minutes, avg delay/incident,
   major-delay count, worst mode), monthly trend, delay minutes by mode, top 5 causes, top 5 hotspots.
2. **Mode Comparison** — incidents, total minutes, avg delay, monthly trend, and share of total
   burden by mode.
3. **Root Cause Analysis** — delay minutes and incident count by cause category, avg severity by
   cause, top codes/descriptions, Pareto chart.
4. **Hotspot Analysis** — top stations/routes/locations by minutes and by count, frequency-vs-
   severity scatter, optional map if location data supports it.
5. **Time Patterns** — by month, weekday, hour; rush-hour vs off-peak; heatmap if useful.
6. **Action Priority Matrix** — frequency × severity matrix, ranked priority list, recommended
   operational focus areas.

---

## 9. SQL direction (PostgreSQL)

Load cleaned CSVs into Postgres from Python (pandas → SQLAlchemy). The SQL layer should
demonstrate clean table creation, a loading workflow, analytical views, and reusable
reporting queries.

Likely files (create only after the audit clarifies real columns):
```
sql/01_create_schema.sql
sql/02_load_cleaned_data.sql
sql/03_create_dimensions.sql
sql/04_create_fact_table.sql
sql/05_reporting_views.sql
sql/06_analysis_queries.sql
```

---

## 10. README direction (public)

Eventually include: project overview, business problem, data sources, tools used, methodology,
data model, dashboard screenshots, key insights, business recommendations, limitations, next
steps. The README should explain **what was learned and what a stakeholder should do** — not
just what was built.

---

## 11. Resume positioning (finalise only once real metrics exist)

Target bullets (placeholders until results are known):
- Built an end-to-end transit-reliability analytics project (Python, SQL, Power BI) analysing
  TTC delay patterns, identifying operational hotspots, and prioritising high-impact causes.
- Analysed 2022–2026 TTC subway, bus, and streetcar delay data to compare incident frequency,
  delay severity, root causes, and time-based reliability trends across modes.
- Developed an executive Power BI dashboard ranking delay hotspots, root causes, and
  service-impact priorities to support data-driven operations decisions.

---

## 12. First files to create (in order)

1. `docs/data_inventory.md` — human-readable file list (during the audit).
2. `notebooks/01_data_audit.ipynb` — raw data structure & quality audit.
3. `scripts/01_clean_delay_data.py` — only after the audit is complete.
4. `data/processed/` — cleaned intermediate CSVs.
5. `sql/` — schema + reporting queries, later.

---

## 13. Python stack

First audit needs only: `pandas`, `pathlib` (plus `openpyxl` to read the XLSX files).
Broader stack: `pandas`, `numpy`, `matplotlib`, `seaborn`, `openpyxl`, `pathlib`.
Optional later: `sqlalchemy` (loading to Postgres), `duckdb`, `geopandas`, `plotly`.
