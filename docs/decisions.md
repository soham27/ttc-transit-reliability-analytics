# Decision Log — TTC Transit Reliability Analytics

A running record of every non-obvious choice on this project. Each entry has the decision,
why it was made, what was considered instead, and a **talking point** you can say almost
verbatim in an interview. Add a new entry whenever you make a real choice — this is your
script for "walk me through your project."

> Format: newest decisions can go at the bottom. Keep the talking points in plain language
> you'd actually say out loud.

---

## Decision 1 — Scope the data to 2022 onward

**Decision:** Use TTC delay data from 2022 to present. Deliberately exclude 2020–2021 and
2018–2019, even though data exists back to 2018.

**Why:**
- **2020–2021 (COVID):** ridership collapsed and service was abnormal, so these years would
  distort every "normal" trend and any seasonality claim.
- **2018–2019 (pre-COVID):** clean, but they sit on the far side of the COVID break, so
  including them means analysing across a structural discontinuity in how the system operated.
- **2022–present:** four+ complete calendar years of comparable, post-COVID operations —
  enough to support credible seasonality and year-over-year analysis, while staying relevant
  to a *current* reliability question.

**Alternatives considered:** (a) 2025-only — too little data for seasonality (~16 months can't
show a recurring annual pattern); (b) full 2018-onward — drags in the COVID shock and a
structural break.

**Talking point:** *"I scoped the data to 2022 onward on purpose. I excluded 2020–2021 because
COVID distorted ridership and service, and I excluded 2018–2019 because they sit before that
break. That left me four-plus comparable years — enough for honest seasonality and
year-over-year analysis without contaminating it with the pandemic. More data isn't
automatically better data."*

---

## Decision 2 — PostgreSQL for the database (not DuckDB)

**Decision:** Build the modelling/reporting layer in PostgreSQL via pgAdmin 4.

**Why:** Already installed and running, so zero new setup friction; "PostgreSQL" is widely
recognised and appears on far more Toronto analyst job descriptions than DuckDB; loading
cleaned CSVs from Python (pandas → SQLAlchemy) is itself a legitimate analyst skill to talk about.

**Alternatives considered:** DuckDB (excellent, modern, zero-config, reads CSVs directly — kept
as an evaluated option and a talking point) and SQLite (acceptable but reads as less serious).

**Talking point:** *"I used PostgreSQL because it's the industry-standard relational database
and the most transferable to the kinds of roles I'm targeting. I did look at DuckDB — it's great
for local analytics — but Postgres was already set up and is more recognisable to employers, so
the trade-off favoured it."*

---

## Decision 3 — Power BI for the dashboard

**Decision:** Build the dashboard in Power BI Desktop.

**Why:** On Windows with Power BI already installed; Toronto is heavily a Microsoft/Power BI
market (banks, insurers, government), so it's the strongest single BI tool to demonstrate here.

**Alternatives considered:** Tableau (strong, but less demanded locally for the target roles) and
Streamlit (kept as an *optional* later Python web-app flourish to pair with the website writeup —
not a dashboard replacement).

**Talking point:** *"I chose Power BI because it's the dominant BI tool in the Toronto market I'm
applying into, so the skill maps directly onto the jobs. Tableau would have been fine too; I
picked the one that matched local demand."*

---

## Decision 4 — Notebooks for analysis, scripts for the proven pipeline

**Decision:** Do exploration and cleaning in Jupyter notebooks with narrative markdown;
convert a step into a reproducible `scripts/` file only after it's proven in a notebook.

**Why:** Notebooks show the *thinking* (a recruiter can read top-to-bottom and follow the
reasoning), which matters because the goal is interview defensibility; scripts then give the
project a reproducible, engineering-mature backbone.

**Talking point:** *"I worked in notebooks so my reasoning is visible at each step, then moved the
proven logic into scripts so the pipeline is reproducible. The notebook is the story; the script
is the product."*

---

## Decision 5 — CSV code-description files for all three modes

**Decision:** Use the CSV code-description lookups for subway, bus, and streetcar. Keep the
subway `ttc-subway-delay-codes.xlsx` as reference only.

**Why:** One consistent format across all three modes keeps the join logic uniform and the
pipeline simple.

**Talking point:** *"I standardised on the CSV code lookups across all three modes so the
join logic was identical everywhere, rather than special-casing one mode's Excel file."*

---

## Decision 6 — Handle mixed file formats without manual conversion

**Decision:** Read 2025+ CSVs and 2022–2024 XLSX files in their native formats inside the
cleaning script (`pd.read_csv` / `pd.read_excel`). Do **not** manually convert the Excel files
to CSV. Resolve all format differences at the raw→processed boundary.

**Why:** Manual conversion is an un-reproducible, error-prone step that lives outside the code.
Reading natively keeps the whole pipeline reproducible from the original raw files. Format
differences (and Excel quirks like multi-sheet workbooks, stripped leading zeros on codes, and
date serials) get normalised once, into a single standardized schema written to
`data/processed/` — after which nothing downstream knows the source was ever Excel.

**Talking point:** *"My sources were heterogeneous — multi-sheet Excel workbooks for 2022–2024
and CSVs for 2025 onward. Instead of hand-converting the files, I read each in its native format
in code and normalised everything into one standardized fact table. That kept the pipeline fully
reproducible from the raw data and is exactly the kind of messy-input reconciliation real analyst
work involves."*

---

## Decision 7 — Ship a focused V1, then iterate

**Decision:** Deliver a polished V1 (clean pipeline → Postgres model → multi-page Power BI →
README + insights writeup), publish to GitHub, and start applying — before adding weather data,
GTFS mapping, or forecasting.

**Why:** The priority is a *finished* portfolio piece you can apply with and defend soon; a
complete small project beats an impressive-looking half-finished one, especially as a first piece
you'll be questioned on. Enrichments become "ongoing work" talking points.

**Talking point:** *"I deliberately shipped a focused first version end-to-end before adding
enrichments. I'd rather have one complete, defensible project than three half-built ones — and the
extensions like weather and mapping are a natural roadmap I can speak to."*

---

## Decision 8 — Treat XLSX workbooks as single-sheet, but keep the stacked-read helper

**Decision:** Read each `*-202X.xlsx` file with a helper that calls
`pd.read_excel(path, sheet_name=None)` and concatenates every sheet, even though
the audit found that every workbook is currently single-sheet (one tab per year).

**Why:** The audit (notebook `01_data_audit.ipynb`, Section 9.1) empirically
confirmed that each 2022–2024 XLSX has exactly one sheet (named variously
`2022`, `2023`, `Subway`, `Data`). My own planning notes had warned about
per-month tabs based on TTC's older publishing pattern, but that's no longer
how the data ships. Reading with `sheet_name=None` and concatenating costs
effectively nothing on a single-sheet file (it just wraps the one DataFrame),
and it future-proofs the pipeline against TTC reverting to monthly tabs in a
future release.

**Alternatives considered:** (a) plain `pd.read_excel(path)` reads only the
first sheet — simpler but silently loses data if TTC ever ships multi-sheet
files again; (b) hard-coding the known sheet name per year — brittle, and the
names already vary across years.

**Talking point:** *"Before reading the data I checked the workbook structure
with `openpyxl` in read-only mode and confirmed each file was single-sheet.
But I still wrote the loader to read all sheets and concatenate, because the
TTC has changed their export format before and that pattern only costs me
nothing on a single-sheet file. Cheap insurance against a known kind of
silent data loss."*

---

## Decision 9 — Unify the 2022–2024 `Incident` text and the 2025+ `Code` lookup into one `delay_description` field

**Decision:** During cleaning, populate a single `delay_description` column
for every row in the combined fact table. For bus and streetcar 2022–2024, fill
it directly from the existing `Incident` free-text column. For bus and
streetcar 2025+, and for subway every year, fill it by joining the
`Code` column to that mode's `Code Descriptions.csv`. Also keep the original
`delay_code` column where it exists (null for 2022–2024 bus/streetcar) so the
raw code is preserved for traceability.

**Why:** The audit discovered (notebook Section 9.4) that between 2024 and
2025 the TTC silently changed how bus and streetcar delay reasons are
recorded — switching from a human-readable `Incident` text column to an
alphanumeric `Code` column that requires a lookup join. Subway has always
used codes. If we ignored this, half our timeline (2022–2024 bus/streetcar)
would have no joinable code and the other half (2025+) would have no
description without joining. Funnelling both into a single
`delay_description` field lets every downstream analysis (top causes, Pareto
of delay minutes by reason, etc.) work uniformly across all years and modes.

**Alternatives considered:** (a) keep `Incident` and `Code` as separate
columns and let the dashboard handle the union — pushes the inconsistency
downstream into every chart and SQL query; (b) drop bus/streetcar 2022–2024
entirely — throws away three years of usable data and breaks the 2022-onward
scope; (c) reverse-engineer codes for 2022–2024 by string-matching `Incident`
to `Code Descriptions.csv` — speculative, the text doesn't line up cleanly,
and likely fails on phrases like "General Delay".

**Talking point:** *"The audit caught a real ETL discontinuity: bus and
streetcar 2022–2024 record the delay reason as free text, but the 2025+ data
swapped that out for an alphanumeric code that has to be joined against a
lookup. Subway always used codes. I resolved it at the cleaning boundary by
populating a single `delay_description` field — pulled from the text for the
older bus/streetcar data and from the lookup join for everything else. That
made the rest of the pipeline format-agnostic. It's exactly the kind of
upstream-source-changes-without-warning problem real analyst work runs
into."*

---

## Decision 10 — Trim bus/streetcar 2025+ `Line` to the route number only

**Decision:** During cleaning, transform bus and streetcar 2025+ `Line`
values like `"102 MARKHAM ROAD"` or `"504 KING"` into just the leading
route number (`"102"`, `"504"`) before writing to `data/processed/`. The
descriptive route name is discarded.

**Why:** Bus 2022–2024 stores routes as bare numbers in a column called
`Route` (`"320"`, `"325"`). Streetcar 2022–2024 does the same in its `Line`
column (`"504"`, `"501"`). The 2025+ CSVs switched to a "number + name"
format. If we kept the 2025+ format as-is, `GROUP BY line` would treat
`"504"` and `"504 KING"` as two different lines, breaking every
year-over-year aggregation. Stripping to the number unifies the join key
across years at the cost of one decorative field that the dashboard
doesn't need.

**Alternatives considered:** (a) keep the full string and group by
`SUBSTRING_BEFORE_FIRST_SPACE(line)` in SQL — pushes the same logic into
every query, easy to forget; (b) reverse-direction: enrich 2022–2024
numbers with route names — requires a GTFS lookup that V1 doesn't include
and would silently misattribute routes that have been renamed over the
years; (c) keep both `line` (number) and `line_name` (full string) — adds
a column with 100% null for the 2022–2024 rows, complicating SQL types
for no V1 benefit. The route name can come back via a GTFS join in V2 if
the dashboard ever wants to label routes by name.

**Talking point:** *"The 2025+ feed switched bus and streetcar line names
from a bare route number to a 'number + name' string. I trimmed it back
down to the number during cleaning so the same line groups together
across all four years — otherwise route 504 in 2024 and '504 KING' in
2025 would have been treated as two different lines in every aggregation.
It's a small choice but it's the kind of thing that silently corrupts
year-over-year comparisons if you miss it."*

---

## Decision 11 — Build three dimensions in V1; defer the other two

**Decision:** In `sql/03_create_dimensions.sql` build only `dim_date`,
`dim_mode`, and `dim_delay_cause`. Deliberately skip `dim_time` and
`dim_route_location` until V2.

**Why:**
- **`dim_date`** earns its place — virtually every chart slices time
  (year-over-year, monthly seasonality, weekday vs weekend, season). A
  proper date dimension with derived `is_weekend`, `season`, and
  `day_of_week_num` columns means those derivations live once in the
  warehouse, not repeated in every Power BI calculated column.
- **`dim_mode`** has only three rows but completes the star-schema
  pattern in the diagram — an interviewer can see "fact joins to dim_*"
  without having to explain the missing piece.
- **`dim_delay_cause`** has ~400 rows and demonstrates a junk dimension
  with a reserved-but-unfilled `delay_category` column for V2.
- **`dim_time`** would have 24 rows. `hour` is already in the fact, and
  `is_rush_hour` is one `CASE` expression in
  `vw_incidents_by_hour` — building a whole dim for that is
  ceremony, not signal.
- **`dim_route_location`** is what `docs/project_plan.md` §5 itself flags
  as "do not over-engineer; inspect raw columns first." With 34,886
  distinct (mode, station) values — mostly bus-stop-intersection strings —
  a dim would just be a renamed projection of the fact. Real route/stop
  enrichment needs GTFS data, which is a V2 enrichment.

**Alternatives considered:** building all five dimensions for star-schema
"completeness" — would have added two tables that the V1 dashboard
doesn't query and that an interviewer would (correctly) ask "what does
this give you?" about. Better to leave a clean "add GTFS in V2" story
than to ship a clutter dimension.

**Talking point:** *"My dimension model is deliberately three tables,
not five. dim_date does real work — every time-based chart joins to it.
dim_mode and dim_delay_cause complete the star schema. I left dim_time
out because 'hour' is already on the fact, and I left a route/location
dimension out because the V1 data is just stations and intersections —
the moment I bring in GTFS metadata in V2, that dimension will earn its
place. I'd rather ship a focused star than a five-table one that's half
empty."*

---

## Decision 12 — Priority-quadrant thresholds are mode-specific 75th percentiles

**Decision:** In `vw_priority_matrix`, the frequency and severity
thresholds that separate quadrants are computed *within each transit
mode* using `PERCENTILE_CONT(0.75)`, not as global thresholds applied
across all three modes.

**Why:** Subway, bus and streetcar have structurally different delay
profiles. Subway incidents are typically short (a held train, a passenger
incident), bus incidents include long diversions, streetcar incidents
can stretch when a single short-turn cascades. A global "20 minutes is
severe" threshold would classify almost every bus cause as "severe" and
almost nothing on the subway — making the matrix useless for prioritising
*within* a mode. Mode-specific percentile thresholds answer the right
question: "compared to other causes on this mode, is this one above
average in frequency and severity?"

**Alternatives considered:** (a) global absolute thresholds (e.g.,
≥10 incidents/year AND ≥20 min average) — sensitive to the choice of
constants and biased toward the most-recorded mode; (b) global
percentile thresholds — biased the same way, because bus contributes
60% of all rows; (c) mode-specific median (P50) thresholds — would have
classified roughly half of every mode's causes as "Urgent", diluting the
signal. P75 within mode keeps the urgent quadrant small enough to be
actionable (top ~25% × top ~25% per mode).

**Talking point:** *"The priority matrix uses per-mode 75th-percentile
thresholds rather than a global 'major delay' threshold. The reason is
that bus, subway, and streetcar have different delay distributions —
a 20-minute bus delay is routine, but a 20-minute subway delay is
already in the top decile. A global threshold would make every bus
cause look severe and almost nothing on subway. Mode-specific
percentiles let leadership see what's bad *relative to that mode's
own baseline*, which is the actionable comparison."*

---

## Decision 13 — "Major delay" is mode-specific p90, not a single global threshold

**Decision:** Defer adding an `is_major_delay` column to the fact table.
When the dashboard or a future analysis needs to label a delay as
"major," use a **mode-specific p90 threshold**: 7 minutes for subway,
30 minutes for streetcar, 30 minutes for bus. Implement it as a
`CASE` expression in a SQL view (or a Power BI calculated column),
not as a stored column.

**Why:** Stage 4's percentile analysis (`notebooks/03_exploratory_analysis.ipynb`
§6) made the case empirically: the three modes have radically different
delay distributions.

| Mode | p50 | p75 | p90 | p99 |
|------|-----|-----|-----|-----|
| Subway | 0 | 4 | 7 | 29 |
| Streetcar | 10 | 12 | 30 | 138 |
| Bus | 11 | 20 | 30 | 237 |

A single global threshold (e.g., "delay_minutes ≥ 10") would label
~zero subway events as "major" and almost every bus event as "major,"
making the flag useless in cross-mode comparisons. The mode-specific
p90 gives the same semantic — *"the top 10% of delays on this mode" —
but calibrated to each mode's own distribution.

Storing it as a column instead of a view expression would freeze a
specific threshold into the fact table; computing it in a view keeps
it tunable. If TTC's own service standard for "major delay" gets
codified later, we change the view in one place.

**Alternatives considered:** (a) hard-code a global "5 min or 10 min"
threshold — defensible by convention but ignores the data, would
mis-label subway and over-label bus; (b) store an `is_major_delay`
column with mode-specific thresholds at cleaning time — works but
freezes the choice; (c) skip the concept entirely for V1 — viable but
loses a useful filter for the dashboard's "what should ops focus on?"
narrative.

**Talking point:** *"I deferred deciding what 'major delay' meant
until I had the distribution in front of me. Once I plotted it,
it was obvious the three modes are three different distributions:
subway's median is zero minutes, bus's p99 is nearly four hours.
A single threshold would be either meaningless on subway or
trivially-true on bus. I used each mode's own 90th percentile, so
'major' means the same thing semantically on every mode — the top
10% of that mode's own delays — without distorting comparisons."*

---

<!-- Add new decisions below as you make them. Template:

## Decision N — <short title>
**Decision:** …
**Why:** …
**Alternatives considered:** …
**Talking point:** "…"
-->
