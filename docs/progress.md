# Progress — TTC Transit Reliability Analytics

Live status of the project. **Update this at the end of every work session** so continuity
survives between sessions. Mark items `[x]` when done, leave `[ ]` when not.

_Last updated: 2026-05-27 — Stage 4 (Exploratory Analysis) complete._

---

## Current stage: POWER BI DASHBOARD (Stage 5) — ready to start

Stage 4 deliverables completed: executed `notebooks/03_exploratory_analysis.ipynb`
with 34 cells (17 code + 17 markdown), seven business questions
answered with charts and plain-language findings, headline insights
written for the README, and one new entry in `docs/decisions.md`
(Decision 13: mode-specific p90 threshold for "major delay").

Next concrete action: open Power BI Desktop, connect to the
`ttc_reliability` Postgres database (`localhost:5432`, user `postgres`,
password from `.env`), import the seven `vw_*` views as data sources,
and build the six dashboard pages described in `docs/project_plan.md` §8.

---

## Stage 0 — Planning & setup
- [x] Project idea and purpose defined (TTC reliability; differentiate from prior e-commerce project)
- [x] Scope decided: 2022 onward, exclude 2020–2021 and 2018–2019
- [x] Core datasets selected (subway/bus/streetcar delays + CSV code descriptions)
- [x] Tooling decided: Python notebooks, PostgreSQL, Power BI
- [x] All raw data downloaded (2025+ CSV, 2022–2024 XLSX) into `data/raw/`
- [x] CLAUDE.md split into lean operating file + `docs/` design/decision/progress docs
- [x] Repository folder structure verified on disk (working folders created: `data/processed/`, `data/final/`, `notebooks/`, `scripts/`, `sql/`, `powerbi/`)
- [x] Python environment set up (venv with `pandas`, `openpyxl`, `jupyter`, `ipykernel`; kernel registered as "Python (TTC audit)")
- [ ] `README.md` filled out (skeleton exists)

## Stage 1 — Raw data audit
- [x] `docs/data_inventory.md` created (real filenames, source, format, purpose)
- [x] `notebooks/01_data_audit.ipynb` created and run
- [x] Filenames, columns, row counts, data types recorded per dataset
- [x] Date ranges confirmed per dataset (every file covers exactly its year; 2025+ CSV current through 2026-01-31)
- [x] Missing-value summary produced (Bound/Direction missing in 15–37% — structural, not a quality bug)
- [x] Excel checks done: sheet counts/names, monthly-tab structure, code/date integrity (single-sheet workbooks, dates clean, codes are alphanumeric strings — no leading-zero issue)
- [x] Schema drift between XLSX years and CSV years assessed (subway stable; bus and streetcar swap `Incident`-text for `Code` between 2024 and 2025)
- [x] Delay-code join column identified; code descriptions validated against event files (subway: 2 codes missing from lookup — `PUTO` and `XXXXX`)
- [x] Combined-fact-table feasibility confirmed; common vs mode-specific fields listed (11 unified columns after renames)
- [x] Concise audit summary written (notebook Section 8 + plain-English narrative in Section 9)

## Stage 2 — Cleaning
- [x] `notebooks/02_data_cleaning.ipynb` written and executed (narrative-led, proves the pipeline)
- [x] `scripts/01_clean_delay_data.py` written (reads CSV + XLSX natively, normalises schema, includes self-check that aborts on regression)
- [x] Standardized `fact_delay_events` CSV(s) written to `data/processed/` (per-mode + combined; 403,155 rows total)
- [x] Cleaning decisions logged in `docs/decisions.md` (Decision 10 added)

## Stage 3 — SQL modelling (PostgreSQL)
- [x] Database created (`sql/00_create_database.sql` — `ttc_reliability` on Postgres 18.3)
- [x] Schema created (`sql/01_create_schema.sql` — `public.fact_delay_events`, 19 columns, PK on event_id, NOT NULL + CHECK constraints)
- [x] Cleaned data loaded into Postgres (`scripts/02_load_to_postgres.py` — 403,155 rows in 59.8 s via SQLAlchemy `to_sql` chunked inserts)
- [x] Fact table created and populated (counts and date range match the CSV)
- [x] Dimension tables created (`sql/03_create_dimensions.sql` — `dim_date` 2,191 rows, `dim_mode` 3 rows, `dim_delay_cause` 396 rows; populated via SQL + INSERT…SELECT from the fact)
- [x] Reporting views + analysis queries written (`sql/05_reporting_views.sql` — 7 `vw_*` views; `sql/06_analysis_queries.sql` — 10 cookbook queries on top of the views)

## Stage 4 — Exploratory analysis
- [x] Core analysis (by mode / cause / location / time) — `notebooks/03_exploratory_analysis.ipynb` §1, §3, §4, §5
- [x] Priority matrix (frequency × severity) — §7, uses `vw_priority_matrix` with mode-specific P75 thresholds
- [x] Pareto analysis — §3, with cumulative-% line and "causes to reach 80%" answer per mode
- [x] Trend & seasonality analysis — §2 (year-over-year) and §5 (monthly indexed to mode mean, hour-of-day, weekday vs weekend)
- [x] Headline findings drafted for README — §8 of the notebook

## Stage 5 — Power BI dashboard
- [ ] Data model loaded into Power BI
- [ ] Executive Summary page
- [ ] Mode Comparison page
- [ ] Root Cause page
- [ ] Hotspot page
- [ ] Time Patterns page
- [ ] Action Priority Matrix page

## Stage 6 — Writeup & publish
- [ ] Key insights written (in own words)
- [ ] Business recommendations written
- [ ] README completed with screenshots, insights, limitations, next steps
- [ ] Resume bullets finalised with real metrics
- [ ] Published to GitHub

## Future / V2 (optional, after V1 ships)
- [ ] GTFS route/stop metadata for mapping
- [ ] Weather enrichment (snow/rain/extreme temps)
- [ ] Forecasting / anomaly detection
- [ ] Streamlit companion app + website writeup
