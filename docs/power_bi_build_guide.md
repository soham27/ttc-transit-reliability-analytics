# Power BI Build Guide — TTC Transit Reliability Analytics (Stage 5)

Click-by-click playbook for building the dashboard. Assumes **Power BI
Desktop version 2.154.956.0 64-bit (May 2026)** and **no prior Power BI
experience**.

You drive Power BI Desktop. Each section below tells you exactly
which button to click, which field to drag where, and what the result
should look like. Save the `.pbix` to `powerbi/ttc_delay_analytics.pbix`
when done.

Two priorities trump everything else:
1. **Every visual must be defensible in an interview** — you should be
   able to say "this chart answers question X using view Y."
2. **The hotspot caveat must be on the dashboard itself**, not buried
   in the README. Bus and streetcar "hotspots" are measurement
   artifacts (see notebook `03_exploratory_analysis.ipynb` §4).

If the UI doesn't match what's written, paste a screenshot to me and
I'll update the guide.

---

## 0. Power BI Desktop UI tour (read this once before you start)

Before any clicking, get your bearings. Open Power BI Desktop and
identify each of these regions.

### The four view icons (far left side of the window)

A vertical strip of small icons. Top to bottom:
1. **Report view** (chart icon) — where you build visuals on a canvas.
2. **Table view** (icon that looks like a spreadsheet/grid) — lets you
   browse the raw imported data.
3. **Model view** (icon that looks like three connected tables) —
   where you set up relationships between tables.
4. **DAX query view** (newer, fx icon) — you won't use this.

You'll spend ~95% of your time in **Report view**.

### The ribbon (top of the window)

Tabs across the top: **Home**, **Insert**, **Modeling**, **View**,
**Optimize**, **Help**, plus context-sensitive tabs that appear when
you click certain things (e.g., **Column tools** appears when you
click a column name; **Format** appears when you click a visual).

### The three panes on the right side of Report view

From right to left, when in Report view:

1. **Visualizations pane** (rightmost). Top section has a grid of
   visual-type icons (Stacked bar, Line chart, Card, etc. — hover over
   each for the name). Below that are three small icons that switch
   the pane's mode:
   - **Build visual** (looks like a column chart, default) — shows
     "field wells" (X-axis, Y-axis, Legend, etc.) where you drop fields.
   - **Format your visual** (paintbrush icon) — shows styling options
     for the currently selected visual.
   - **Add further analyses** (magnifying glass on a chart) — for
     trend lines, constant lines. You'll use this once.

2. **Filters pane** (middle of the three) — appears between the
   canvas and the Visualizations pane. Three sections:
   - *Filters on this visual* (the one currently selected)
   - *Filters on this page*
   - *Filters on all pages*

3. **Data pane** (leftmost of the three, sometimes called "Fields"
   in older docs) — lists all the imported tables and views. Click the
   ► triangle next to a view name to expand it and see its columns.

If a pane is missing, go to the **View** ribbon and toggle it on.

### The canvas

The white area in the middle. This is the dashboard page you're
building. Drag visuals here, position them, resize them.

### Page tabs (bottom of the canvas)

Like Excel sheet tabs. Each tab is a dashboard page. Right-click a
tab to rename, duplicate, or delete a page. The **+** button at the
left of the tabs adds a new page.

### Two interaction modes to know about

- **On-object interaction** — when you click a visual, a small toolbar
  appears *on* the visual itself with quick shortcuts. This is on by
  default in v2.154. Ignore it for now; use the right-side panes
  instead because they're more reliable.
- **Hold Ctrl and drag** — moves a visual without selecting things
  underneath it.

That's the orientation. Now let's connect to Postgres.

---

## 1. Connect to Postgres and import the views (10 min)

### 1.1 Open the connector

1. *Home* ribbon → **Get data** → **More…**
2. In the dialog, type `PostgreSQL` in the search box → click
   **PostgreSQL database** → click **Connect**.
3. If you've never connected to Postgres before, Power BI may say
   *"This connector requires one or more additional components to be
   installed."* Click **Learn more** to get the **Npgsql** download
   link, install it (close Power BI first, install, reopen), and
   retry step 1.

### 1.2 Enter connection details

1. **Server:** type `localhost:5432`
2. **Database:** type `ttc_reliability`
3. **Data Connectivity mode:** select **Import** (radio button).
4. Click **OK**.

### 1.3 Provide credentials

A credentials dialog opens. On the left, the choices are *Windows*,
*Database*, *Microsoft account*.

1. Click **Database** (in the left list).
2. **User name:** `postgres`
3. **Password:** the password from your `.env` file (copy-paste from
   there).
4. Leave *Select which level to apply these settings to* on its
   default.
5. Click **Connect**.

If you see a privacy-level warning, choose **None** or **Organization**
and continue.

### 1.4 Pick the tables to import

The **Navigator** dialog opens. On the left, you see a tree:
`ttc_reliability → public`. Expand `public` if not already.

Tick the checkbox next to each of these eight items:

| Item | What it's for |
|---|---|
| `dim_mode` | The cross-page mode slicer |
| `vw_kpi_summary` | Executive page KPI cards |
| `vw_incidents_by_mode_year_month` | Monthly trend chart |
| `vw_top_causes_by_mode` | Root cause + executive top-5 |
| `vw_top_hotspots_by_mode` | Hotspot page |
| `vw_incidents_by_hour` | Time patterns (hour) |
| `vw_incidents_by_dow` | Time patterns (weekday) |
| `vw_priority_matrix` | Action priority matrix |

Click **Load** (lower right) — not **Transform Data**. Wait ~10–15 sec
for the import to finish.

### 1.5 Verify

In the **Data pane** (right side), you should see all 8 items listed.
Click the ► triangle next to each to verify columns are there. The
status bar at the bottom may show "Loading… 1 of 8 queries" briefly.

> **If `fact_delay_events` shows up in your import list:** don't tick
> it. Every chart should read from a view, not the fact table — see
> CLAUDE.md.

---

## 2. Set up the data model (10 min)

### 2.1 Open Model view

Click the **Model view** icon (third one down on the far-left
sidebar). The canvas changes to show all 8 imported tables as boxes,
floating with no connections.

### 2.2 Drag `dim_mode` to the center

Click the title bar of the `dim_mode` box and drag it to roughly the
middle of the canvas. The seven views should be arranged around it.

### 2.3 Create six one-to-many relationships

You'll make **six** relationships, not seven. `vw_kpi_summary` has
only one row and a different column shape — it doesn't need a
relationship.

For each of the six views below:

| View to connect |
|---|
| `vw_incidents_by_mode_year_month` |
| `vw_top_causes_by_mode` |
| `vw_top_hotspots_by_mode` |
| `vw_incidents_by_hour` |
| `vw_incidents_by_dow` |
| `vw_priority_matrix` |

**To create one relationship:**

1. In the `dim_mode` box, find the `transit_mode` column.
2. **Click and hold** on `dim_mode.transit_mode`, then drag the
   cursor onto the `transit_mode` column inside one of the view boxes
   (e.g., `vw_top_causes_by_mode.transit_mode`). Release the mouse
   button.
3. A **Create relationship** dialog appears. Verify:
   - **From table:** `dim_mode`, column **transit_mode**
   - **To table:** the view you dropped onto, column **transit_mode**
   - **Cardinality:** One to many (1:*)
   - **Cross filter direction:** Single
   - **Make this relationship active** is ticked.
4. Click **OK**.
5. A solid line appears between `dim_mode` and the view, with a `1`
   on the dim_mode side and a `*` on the view side.

Repeat for all six views.

### 2.4 Verify

When you're done, your model should look like a star with `dim_mode`
in the middle and **six solid lines** fanning out to the six views.
`vw_kpi_summary` should sit by itself, with no lines connecting to
it. That's correct.

Hover over each relationship line — the tooltip should say
*"dim_mode (1) → vw_xxx (*)"* with **Cross filter direction: Single**.
If any tooltip says **Both**, double-click the line and change the
cross-filter direction to *Single*.

---

## 3. Apply a consistent theme (5 min)

### 3.1 Open the theme editor

1. Click the **Report view** icon (top icon on the far-left sidebar)
   to return to the canvas.
2. *View* ribbon → **Themes** group → click the small dropdown arrow
   under "Themes" → **Customize current theme**.

### 3.2 Set the mode colors as theme colors 1, 2, 3

A **Customize theme** dialog opens. On the left, click **Name and
colors** → **Theme colors**.

You'll see 8 color slots labeled Color 1 through Color 8. Click
**Color 1** → in the color picker, click the **Custom color** option
(or the hex input field) → type `E60050` → click outside the picker.

Repeat:
- **Color 2:** `0066CC` (Bus blue)
- **Color 3:** `F39200` (Streetcar orange)

Leave Colors 4–8 at their defaults.

### 3.3 Apply

Click **Apply** at the bottom of the dialog.

The theme colors will now be used as the *default* palette for any
new visual that splits by mode. **However**, Power BI assigns theme
colors in the order series appear in the data, which is alphabetical
by default — so Bus (alphabetically first) gets Color 1 (red), not
the blue we want. We'll fix this **per visual** in the format steps
below by setting Data colors explicitly per series.

> **Why we still bother setting the theme:** new visuals start with
> sensible defaults, and any "miscellaneous" colors (e.g., quadrant
> lines, accent bars) pull from the theme palette correctly.

---

## 4. Pages

Each page below has the same structure: **purpose, layout sketch,
visuals (numbered with full click-by-click), captions, done-when**.

Build pages in this order — later pages reuse patterns from earlier
ones.

> **Renaming a page:** at the bottom of the canvas you'll see a tab
> labelled "Page 1" by default. Right-click the tab → **Rename** →
> type the new name → Enter.

---

### Page 1 — Executive Summary

**Purpose:** the 30-second story. Answers *"how big is the problem,
which mode owns it, is it changing?"*

**Rename the default "Page 1" tab to `Executive Summary` now.**

**Layout sketch (approximate):**
```
+--------+--------+--------+--------+ +----------+
| Card 1 | Card 2 | Card 3 | Card 4 | | Slicer   |
| Incid. | Min.   | Avg.   | Worst  | | Mode     |
+--------+--------+--------+--------+ +----------+
|                                                |
|  Line chart — Monthly delay minutes by mode    |
|                                                |
+----------------------+-------------------------+
|  Bar — Incidents by  |  Table — Top 5 causes  |
|  mode                |                         |
+----------------------+-------------------------+
|                Caption text box                 |
+-------------------------------------------------+
```

---

#### Visual 1 — Card: Total incidents *(top-left)*

**Create the visual:**

1. Click on an empty area of the canvas (so nothing else is selected).
2. In the **Visualizations pane** (right side, top), find the **Card**
   icon — it looks like a small rectangle with the number `123` inside.
   Hover over icons until the tooltip says "Card". Click it once.
3. A blank card visual appears on the canvas, in the top-left area.

**Drag the field:**

4. In the **Data pane** (right side, below Visualizations), click the
   ► triangle next to `vw_kpi_summary` to expand it.
5. Find `total_incidents`. Click and drag it onto the **Fields**
   well in the Visualizations pane (under "Build visual"). The well
   says *"Add data fields here"* before anything is dropped.
6. The card now shows `403155`.

**Format — set callout text and title:**

7. With the card selected, click the **paintbrush icon** (Format your
   visual) at the top of the Visualizations pane.
8. Scroll down and expand **Callout value** → set **Font size** to
   28pt (or whatever looks readable; Power BI's default is 45pt).
9. Scroll to **Category label** → check that it shows "Total incidents"
   — if not, type that in. Set **Font size** to 11pt.
10. Scroll to **Title** → toggle **Title** to **On** → click the
    **Text** field → type `Total incidents` → press Enter.

**Resize & position:**

11. Click and drag the corners/edges of the card to resize it to
    roughly 200 × 100 px. Drag it to the top-left corner of the
    canvas.

**Verify:** card shows **403,155** with the label "Total incidents".

---

#### Visual 2 — Card: Total delay minutes *(next to Visual 1)*

1. Click an empty area of the canvas to deselect Visual 1.
2. In Visualizations pane → click the **Card** icon.
3. Expand `vw_kpi_summary` in the Data pane → drag
   `total_delay_minutes` onto the **Fields** well.
4. Click the **paintbrush icon** → scroll to **Callout value** →
   expand **Display units** → set to **Millions** (the dropdown lets
   you pick None / Thousands / Millions / Billions). The card now
   shows `6.30M`.
5. **Decimal places:** set to 2 (under the Display units area).
6. Scroll to **Title** → toggle **On** → text: `Total delay minutes`.
7. Resize to ~200 × 100 px, position to the right of Visual 1.

**Verify:** card shows **6.30M** with the label "Total delay minutes".

---

#### Visual 3 — Card: Avg delay per incident *(next, with " min" suffix)*

1. Click an empty area to deselect.
2. Visualizations pane → click **Card** icon.
3. Drag `vw_kpi_summary.avg_delay_minutes_per_incident` onto the
   **Fields** well.
4. The card initially shows `15.62`. We want it to show `15.62 min`.
5. **In the Data pane**, find `avg_delay_minutes_per_incident`
   (still under `vw_kpi_summary`). Click directly on the field name —
   the top ribbon switches to **Column tools**.
6. In the **Formatting** group of the Column tools ribbon, find the
   **Format** dropdown (the one that currently says "General" or
   "Decimal number"). Click it → select **Custom**.
7. In the **Format** text input that appears, type exactly:
   `0.00" min"` (zero-zero-decimal-zero-zero space quotes-space-m-i-n-quotes).
   Press Enter.
8. The card now shows **15.62 min**.
9. Click the card → **paintbrush** → **Title** toggle **On** →
   text: `Avg delay per incident`.
10. Resize and position next to Visual 2.

---

#### Visual 4 — Card: Worst mode by total delay *(rightmost card)*

1. Deselect → Visualizations pane → **Card** icon.
2. Drag `vw_kpi_summary.worst_mode_by_total_delay` onto **Fields**.
3. Power BI auto-aggregates to "First" or shows the raw text. The
   card displays **Bus**.
4. **Paintbrush** → **Callout value** → set Font size 28pt.
5. **Title** → toggle **On** → text: `Worst mode (by delay min.)`.
6. Resize and position.

> **If the card shows a number instead of "Bus":** click the small
> dropdown arrow next to the field name in the Fields well → change
> aggregation from *Count* to **First** (or **Don't summarize**).

---

#### Visual 5 — Line chart: Monthly delay minutes by mode *(middle row, full width)*

This is the visual we already debugged together. Step-by-step from
scratch:

**Create:**

1. Click an empty canvas area to deselect.
2. Visualizations pane → click the **Line chart** icon (looks like a
   wavy line going up).
3. A blank line chart appears.

**Bind fields:**

4. Expand `vw_incidents_by_mode_year_month` in the Data pane.
5. Drag `month_start` onto **X-axis**.
6. **Critical:** in the X-axis well, you'll see "Date hierarchy"
   below `month_start`. Click the **small "x" next to "Date hierarchy"**
   if it auto-appears (some versions stack the hierarchy). You want
   just the raw `month_start` field, not the Year/Quarter/Month/Day
   hierarchy. *Alternative path:* click the dropdown arrow on
   `month_start` in the X-axis well → select **month_start** (the
   plain version, not the hierarchy).
7. Drag `total_delay_minutes` onto **Y-axis**.
8. Drag `transit_mode` onto **Legend**.

**Format — title, axis titles, axis labels, data colors:**

9. Click the **paintbrush icon**.
10. **Title:** scroll to *Title* section → toggle **On** → text:
    `Monthly delay minutes by mode`. Set Font size to 14pt.
11. **X-axis title:** scroll to **X-axis** → expand the section →
    find the sub-section **Title** → toggle **On** → in the **Title
    text** field, type `Month`. (If Power BI auto-fills "month_start",
    overwrite it.)
12. **Y-axis title:** scroll to **Y-axis** → expand → **Title** →
    toggle **On** → **Title text** → type `Total delay minutes`.
13. **Y-axis display units:** still in Y-axis → expand **Values** →
    set **Display units** to **Thousands** so labels read like `150K`
    instead of `150,000`.
14. **Data colors per series:** find **Lines** section → expand →
    expand **Colors** sub-section. You'll see three rows, one per
    mode:
    - **Bus** → click the colored circle → Custom color → hex `0066CC`
    - **Streetcar** → click circle → hex `F39200`
    - **Subway** → click circle → hex `E60050`
15. **Line stroke width:** under **Lines → Stroke width**, set to 2.5
    or 3 for legibility.

**Resize & position:**

16. Drag to span the middle row, full width.

**Verify:** line chart with monthly granularity (~49 points across
2022-2026), three lines clearly colored Bus blue, Streetcar orange,
Subway red. Bus oscillates around 100K, streetcar around 20K, subway
near 5–10K.

---

#### Visual 6 — Stacked column chart: Incidents by mode *(bottom-left)*

> **Correction from the original guide:** this visual uses
> `vw_incidents_by_mode_year_month` (not `vw_kpi_summary` — that view
> has only one row and can't drive a per-mode bar chart).

**Create:**

1. Deselect → Visualizations pane → click **Stacked column chart**
   icon (looks like vertical bars stacked).

**Bind fields:**

2. Expand `vw_incidents_by_mode_year_month` in the Data pane.
3. Drag `transit_mode` onto **X-axis**.
4. Drag `incident_count` onto **Y-axis**. (Power BI auto-applies
   **Sum** — that's what we want; it sums all 49 monthly buckets
   into one total per mode.)

**Format:**

5. **Paintbrush** → **Title** → toggle On → text:
   `Total incidents by mode, 2022–2026`.
6. **X-axis** → **Title** → toggle On → text: `Transit mode`.
7. **Y-axis** → **Title** → toggle On → text: `Incidents`.
8. **Y-axis** → **Values** → **Display units** → **Thousands**.
9. **Columns** section → expand → expand **Colors** sub-section →
   you'll see three rows:
   - Bus → `0066CC`
   - Streetcar → `F39200`
   - Subway → `E60050`
10. **Data labels:** scroll to **Data labels** section → toggle **On**
    so each column shows its value at the top.

**Resize & position:** bottom-left, ~half-width.

**Verify:** three bars, Bus tallest at ~244K, Subway at ~98K,
Streetcar at ~62K.

---

#### Visual 7 — Table: Top 5 causes globally *(bottom-right)*

**Create:**

1. Deselect → Visualizations pane → **Table** icon (looks like a
   grid).

**Bind fields:**

2. Expand `vw_top_causes_by_mode` in the Data pane.
3. Drag these fields, **one at a time**, onto the **Columns** well
   (in this order):
   - `transit_mode`
   - `delay_description`
   - `incident_count`
   - `total_delay_minutes`
   - `pct_of_mode_delay_minutes`
4. For `incident_count` and `total_delay_minutes`: the default
   aggregation is **Sum** — that's fine for a table where rank
   filtering keeps the rows unique. If you see a Σ symbol next to
   them in the well, that means they're aggregated. Click the
   dropdown arrow on each → change aggregation to **Don't summarize**
   so we get the literal per-row values from the view, not summed.

**Filter to top 5:**

5. **Filters pane** (between canvas and Visualizations).
6. Under *Filters on this visual*, drag `rank_by_total_delay` from
   the Data pane (still under `vw_top_causes_by_mode`) into the
   filter area.
7. Filter type: **is less than or equal to** → value: `5` → click
   **Apply filter**.

**Sort:**

8. Click the column header `total_delay_minutes` in the table to sort
   descending. (You may need to click the *transit_mode* column
   header first, then `rank_by_total_delay`, to get sorted by mode
   then rank.)
9. Cleaner: click the **"…"** (three dots) on the table → **Sort
   axis → Sort by → transit_mode** → **Sort ascending**. Then again
   → **Sort by → rank_by_total_delay** → **Sort ascending**.

**Format:**

10. **Paintbrush** → **Title** → toggle On → text:
    `Top 5 causes per mode (by delay minutes)`.
11. **Column headers** section → bump **Font size** to 11pt for
    readability.

**Verify:** ~15 rows (5 per mode × 3 modes). Bus rows show
"Diversion", "Mechanical", etc.

---

#### Visual 8 — Slicer: Transit mode *(top-right of page)*

**Create:**

1. Deselect → Visualizations pane → **Slicer** icon (looks like a
   funnel with checkboxes).

**Bind field:**

2. Expand `dim_mode` in the Data pane.
3. Drag `transit_mode` onto the **Field** well.

**Format:**

4. **Paintbrush** → **Slicer settings** → **Style** → choose
   **Tile** (or "Horizontal") so the three modes show as side-by-side
   buttons instead of a vertical list.
5. **Slicer header** → toggle Off (cleaner — the title "transit_mode"
   header is redundant; we'll add a clean visual title instead).
6. **Title** → toggle On → text: `Filter by mode` → Font size 11pt.

**Resize & position:** top-right corner, small (about 250 × 100 px).

**Test it:** click "Bus" in the slicer. Every other visual on the
page (except the cards from `vw_kpi_summary`, which aren't connected
to dim_mode) should filter to bus data. Click the eraser icon on the
slicer to clear the filter.

> **Why the cards don't filter:** `vw_kpi_summary` has no relationship
> to `dim_mode`. That's deliberate — the four cards always show the
> global total regardless of which mode is selected, which is what an
> "executive summary" page should do.

---

#### Visual 9 — Text box: Caption *(very bottom of page)*

**Create:**

1. *Insert* ribbon → **Text box**.
2. A small text box appears on the canvas. Click inside it and type:

```
Source: TTC Open Data, 2022-01-01 to 2026-01-31 (403,155 events).
All figures are pre-aggregated in the Postgres view layer; this dashboard is read-only against ttc_reliability.public.vw_*.
```

3. Highlight the text → set font size to 9pt, italic. Use the
   in-place formatting toolbar that appears on the text box.

**Resize & position:** stretch to full page width along the very
bottom.

**Done-when check for Page 1:**

- Four cards show **403,155 / 6.30M / 15.62 min / Bus**.
- Line chart has monthly granularity, three colored lines (Bus blue,
  Streetcar orange, Subway red).
- Bar chart shows three bars in the correct colors.
- Table shows ~15 rows of top 5 causes per mode.
- Slicer filters all visuals except the cards.
- Caption is visible at the bottom.

When that's all in place, **save the file** (Ctrl+S) → save as
`powerbi/ttc_delay_analytics.pbix`. Tell me when Page 1 is done and
I'll signal start on Page 2.

---

### Page 2 — Mode Comparison

**Purpose:** *"how do the three modes compare on volume, severity, and
share-of-burden?"*

**Create the page:**

1. At the bottom of the canvas, click the **+** button to add a new
   page. Power BI creates "Page 2" tab.
2. Right-click the tab → **Rename** → `Mode Comparison`.

**Layout sketch:**
```
+-------------------------+-------------------------+
| Clustered column —      | Clustered column —      |
| Incidents per year      | Delay minutes per year  |
+-------------------------+-------------------------+
| 100% stacked bar — Share of delay minutes by mode |
+---------------------------------------------------+
| Line chart — Monthly trend per mode (full width)  |
+---------------------------------------------------+
| Slicer: Year                                      |
+---------------------------------------------------+
```

---

#### Visual 1 — Clustered column: Incidents per year by mode *(top-left)*

1. Click empty canvas → Visualizations pane → **Clustered column
   chart** icon (looks like grouped bars).
2. Expand `vw_incidents_by_mode_year_month` in Data pane.
3. Drag `year` → **X-axis**.
4. Drag `incident_count` → **Y-axis** (default aggregation Sum).
5. Drag `transit_mode` → **Legend**.
6. **Paintbrush**:
   - Title → On → `Annual incidents by mode`.
   - X-axis → Title → On → `Year`.
   - Y-axis → Title → On → `Incidents`. Display units → **Thousands**.
   - Columns → Colors: Bus `0066CC`, Streetcar `F39200`, Subway `E60050`.

**Resize:** top-left, ~half-width.

---

#### Visual 2 — Clustered column: Delay minutes per year by mode *(top-right)*

1. Click empty canvas → **Clustered column chart** icon.
2. Same `vw_incidents_by_mode_year_month`:
   - `year` → X-axis
   - `total_delay_minutes` → Y-axis (Sum)
   - `transit_mode` → Legend
3. **Paintbrush**:
   - Title → `Annual delay minutes by mode`.
   - X-axis → Title → `Year`.
   - Y-axis → Title → `Total delay minutes`. Display units → **Millions**.
   - Columns → Colors: Bus `0066CC`, Streetcar `F39200`, Subway `E60050`.

**Resize:** top-right, ~half-width.

---

#### Visual 3 — 100% stacked bar: Share of delay minutes by mode *(middle row, full width)*

1. Click empty canvas → **100% Stacked bar chart** icon (looks like
   horizontal bars all the same length).
2. Bind fields:
   - X-axis: leave empty (we want a single combined bar)
   - Y-axis: drag `total_delay_minutes` (Sum) from
     `vw_incidents_by_mode_year_month`.
   - Legend: drag `transit_mode` from same view.

   > If Power BI insists on an X-axis: drag a dummy field — easiest
   > path is to drag a measure-style field like `incident_count`
   > onto X-axis instead, but actually for "single stacked bar" the
   > cleanest is to use a *donut chart* or *100% Stacked column*
   > instead. **Use the Donut chart** as a substitute: drag
   > `transit_mode` → Legend; `total_delay_minutes` → Values. Donut
   > works without an X-axis.

3. If using donut: **Paintbrush**:
   - Title → `Share of total delay minutes by mode`.
   - Slices → Colors: Bus `0066CC`, Streetcar `F39200`, Subway `E60050`.
   - Detail labels → toggle On → set **Label contents** to **Category,
     percent of total**.

**Resize:** middle row, full width but only ~250 px tall.

---

#### Visual 4 — Line chart: Monthly trend per mode *(bottom, full width)*

This is identical to Page 1 Visual 5. Easiest path: go to Page 1,
right-click Visual 5 → **Copy visual**. Switch to Page 2 →
**Ctrl+V** to paste. Power BI will keep all formatting and data
bindings.

If pasting doesn't work cleanly, recreate following the same steps as
Page 1 Visual 5.

---

#### Visual 5 — Slicer: Year *(below visual 4 or top of page)*

1. Click empty canvas → Visualizations → **Slicer** icon.
2. Drag `vw_incidents_by_mode_year_month.year` → **Field** well.
3. **Paintbrush** → Slicer settings → Style → **Dropdown** (because
   there are 5 year values; tile would be fine too).
4. Slicer header → Off. Title → On → text: `Filter by year`.

**Caption (text box at bottom):**

> "Bus accounts for ~80% of total delay minutes despite ~60% of
> incidents — its delays are both more frequent and longer on
> average. 2026 shows only January; do not read year-end 2026 from
> this view."

**Done-when:** the donut visually screams Bus (~78–80% slice); the
two column charts show bus rising while subway/streetcar are flat.

---

### Page 3 — Root Cause Analysis

**Purpose:** *"which delay causes are most impactful per mode?"* The
Pareto page.

**Add page** → rename to `Root Cause`.

**Layout sketch:**
```
+----------------------------------+---------------+
|  Table — Top 10 causes per mode  | Card —        |
|                                  | "Causes to    |
|                                  | 80%"          |
|                                  +---------------+
|                                  | Slicer:       |
|                                  | Transit mode  |
+----------------------------------+---------------+
|  Pareto chart (one mode at a time)               |
+--------------------------------------------------+
```

---

#### Visual 1 — Table: Top 10 causes per mode *(left two-thirds)*

1. Empty canvas → **Table** icon.
2. Expand `vw_top_causes_by_mode`. Drag onto **Columns**, in order:
   - `transit_mode`
   - `rank_by_total_delay`
   - `delay_description`
   - `incident_count` (change aggregation to *Don't summarize* via
     the dropdown in the well)
   - `total_delay_minutes` (Don't summarize)
   - `avg_delay_minutes` (Don't summarize)
   - `pct_of_mode_delay_minutes` (Don't summarize)
   - `cumulative_pct_of_mode_delay_minutes` (Don't summarize)
3. **Filters pane** → Filters on this visual → drag
   `rank_by_total_delay` → filter type **is less than or equal to**
   → value `10` → Apply.
4. Sort: click "…" on the table → Sort axis → Sort by
   `transit_mode`, ascending. Then again → Sort by
   `rank_by_total_delay`, ascending. (Power BI 2024+ may sort by
   multiple keys when you re-click; if it overrides, set the most
   important sort last.)
5. **Paintbrush** → Title → On → `Top 10 delay causes per mode`.
6. **Conditional formatting on cumulative %:**
   - With the table selected, in the Visualizations pane click the
     dropdown arrow next to `cumulative_pct_of_mode_delay_minutes`
     in the Columns well → **Conditional formatting** → **Data bars**.
   - Accept defaults (positive value bar) and click **OK**.

**Resize:** left two-thirds, top half.

---

#### Visual 2 — Card: Causes to 80% *(top-right)*

This requires a small DAX measure.

**Create the measure:**

1. In the Data pane, right-click `vw_top_causes_by_mode` → **New
   measure**.
2. A formula bar opens at the top. Replace any placeholder text with:

   ```
   Causes to 80% = CALCULATE(
       COUNTROWS(vw_top_causes_by_mode),
       FILTER(vw_top_causes_by_mode,
              vw_top_causes_by_mode[cumulative_pct_of_mode_delay_minutes] <= 80)
   )
   ```

3. Press Enter / click the checkmark to save.
4. A new "Causes to 80%" field appears under `vw_top_causes_by_mode`
   in the Data pane (marked with a calculator icon — that's a measure).

**Add the card visual:**

5. Empty canvas → **Card** icon.
6. Drag the new **Causes to 80%** measure onto the Fields well.
7. The card shows **8**, **12**, or **31** depending on the mode
   slicer (or **51-ish** if no mode is selected — it's counting
   across all modes; that's fine, it'll filter to a single number
   once you add the slicer below).
8. **Paintbrush** → Title → On → `Causes to reach 80% of delay`.
   Font size 11pt.
9. **Callout value** → Font size 28pt.

**Resize:** top-right corner, narrow.

---

#### Visual 3 — Slicer: Transit mode *(top-right under the card)*

Identical to Page 1 Visual 8 — fastest path: copy Page 1's slicer →
paste on Page 3.

If you copy-paste: the slicer should still work because both pages
share the `dim_mode` relationship.

---

#### Visual 4 — Line + clustered column: Pareto chart *(bottom, full width)*

1. Empty canvas → Visualizations pane → look for **Line and clustered
   column chart** icon (looks like a column chart with a line on top).
   It's usually in the second row of icons.
2. Bind fields:
   - **Shared axis:** drag `vw_top_causes_by_mode.delay_description`.
   - **Column y-axis:** drag `vw_top_causes_by_mode.total_delay_minutes`
     (Don't summarize).
   - **Line y-axis:** drag
     `vw_top_causes_by_mode.cumulative_pct_of_mode_delay_minutes`
     (Don't summarize).
3. **Filter to one mode at a time:** drag `transit_mode` from
   `vw_top_causes_by_mode` to the **Filters on this visual** area.
   Filter type: **Basic filtering** → tick **Bus** only. (You'll
   change this back and forth or rely on the page slicer.)
4. **Filter to top 15:** in Filters on this visual, drag
   `rank_by_total_delay` → filter type **is less than or equal to**
   → value `15`.
5. **Add the 80% reference line:**
   - With the visual selected, click the **magnifying-glass icon**
     in the Visualizations pane (Add further analyses).
   - Find **Constant line** → click **+ Add** → name it "80%".
   - **Value:** 80.
   - **Line color:** grey.
   - **Apply to:** the line series (cumulative %), not the columns.
   - **Style:** Dashed.
6. **Paintbrush:**
   - Title → On → `Pareto: cumulative % of delay minutes by cause`.
   - X-axis → Title → On → `Delay cause` → Labels → Font size 8pt,
     rotate –45° if labels overlap.
   - Y-axis (column) → Title → On → `Total delay minutes` →
     Display units → Thousands.
   - Secondary Y-axis (line) → Title → On → `Cumulative %` →
     **Max** value 105 (so the line is fully visible).

**Caption (text box at bottom):**

> "Bus and streetcar reliability is Pareto-concentrated — fix a
> handful of causes (diversion-related processes in particular) and
> you move 80% of the lost service time. Subway has no Pareto
> shortcut: 31 distinct causes contribute to its top 80%."

**Done-when:** sliding the mode slicer flips the "Causes to 80%"
card between **8 / 12 / 31** (Bus / Streetcar / Subway) and the
Pareto chart redraws to match.

---

### Page 4 — Hotspot Analysis (read the caveat box first)

**Purpose:** *"where do delays cluster — and what's the caveat?"*

**Add page** → rename to `Hotspots`.

**Layout sketch:**
```
+--------------------------------------------------+
|  Big yellow caveat text box (read this first!)   |
+--------------------------------+-----------------+
|  Horizontal bar — Top 15       | Table — Same    |
|  hotspots per mode              | data with %    |
+--------------------------------+-----------------+
|  Slicer: Transit mode                            |
+--------------------------------------------------+
```

---

#### Visual 1 — Text box: the artifact warning *(top of page, prominent)*

**This is the most important visual on this page. Do it first.**

1. *Insert* → **Text box**.
2. Type:

```
Important: bus and streetcar "hotspots" are measurement artifacts.

Surface-route delays are logged at the next major stop — almost always a subway interchange station like Kennedy, Kipling, or Eglinton. The geographic concentration you see here reflects WHERE DELAYS ARE REPORTED, not where they originate. Subway hotspots are less ambiguous (transfer-heavy or terminus stations). For genuine geographic targeting, this dashboard needs GTFS route/stop enrichment (V2).
```

3. Highlight the first line ("Important: ...") → make it **bold**,
   font size 14pt.
4. Highlight the rest → font size 10pt.
5. With the text box selected → **paintbrush** → **General** tab
   (top of the format pane) → **Effects** → **Background** → toggle
   On → set color to `#FFE4B2` (a warm pale orange). Border → toggle
   On → color `#F39200` (matching).

**Resize:** stretch across the top of the page, roughly 150 px tall.

> Goal: a recruiter who lands on this page should see the caveat
> before they see the bar chart. If they can scroll past it
> accidentally, make it bigger.

---

#### Visual 2 — Horizontal bar chart: Top 15 hotspots *(left two-thirds)*

1. Empty canvas → **Stacked bar chart** (horizontal bars) icon.
2. Bind:
   - **Y-axis:** `vw_top_hotspots_by_mode.station`
   - **X-axis:** `vw_top_hotspots_by_mode.total_delay_minutes` (Sum)
3. **Filters on this visual:**
   - `rank_by_total_delay` → **is less than or equal to** → `15` →
     Apply.
4. **Single-mode slicer (added below):** the page slicer will filter
   this; no separate filter here.
5. **Paintbrush:**
   - Title → `Top 15 hotspots by total delay minutes`.
   - Y-axis → Title → On → `Station / location`.
   - X-axis → Title → On → `Total delay minutes`. Display units →
     Thousands.
   - Bars → Colors → set to the active mode color (start with Bus
     `0066CC`; the user changes mode via the slicer and the color
     stays — that's fine for V1).
   - Data labels → toggle On.

**Resize:** left two-thirds, below the caveat box.

---

#### Visual 3 — Table: Hotspot detail *(right one-third)*

1. Empty canvas → **Table** icon.
2. Bind, in order:
   - `station`
   - `incident_count` (Don't summarize)
   - `total_delay_minutes` (Don't summarize)
   - `avg_delay_minutes` (Don't summarize)
   - `pct_of_mode_delay_minutes` (Don't summarize)
3. Filter: `rank_by_total_delay <= 15` on this visual.
4. **Paintbrush** → Title → `Hotspot detail`.

---

#### Visual 4 — Slicer: Transit mode *(bottom of page)*

Same as Page 1's slicer. Copy-paste from Page 1 → place at the
bottom or in a corner.

**Done-when:** the caveat box is the most prominent thing on the
page. Changing the mode slicer redraws the bar chart and table to
show that mode's top 15 stations.

---

### Page 5 — Time Patterns

**Purpose:** *"when do delays happen — across the day, week, and
year?"*

**Add page** → rename `Time Patterns`.

**Layout sketch:**
```
+---------------------------+-------------------------+
| Line — Monthly            | Column — Incidents      |
| seasonality (indexed)     | by hour                 |
+---------------------------+-------------------------+
| Column — Avg delay        | Column — Day of week    |
| per incident by hour      |                         |
+---------------------------+-------------------------+
| Slicer: Transit mode                                |
+-----------------------------------------------------+
```

---

#### Visual 1 — Line chart: Monthly seasonality *(top-left)*

1. Empty canvas → **Line chart** icon.
2. Bind:
   - **X-axis:** `vw_incidents_by_mode_year_month.month` (the
     integer 1–12; not month_name, because month_name sorts
     alphabetically by default).
   - **Y-axis:** `vw_incidents_by_mode_year_month.total_delay_minutes`
     → change aggregation from Sum to **Average** (click dropdown
     arrow in well → Average). This averages each month across all
     four years.
   - **Legend:** `transit_mode`.
3. **Paintbrush:**
   - Title → `Monthly seasonality — avg total delay by mode across years`.
   - X-axis → Title → `Month (1=Jan, 12=Dec)`.
   - Y-axis → Title → `Avg total delay minutes per month`. Display units → Thousands.
   - Lines → Colors: Bus `0066CC`, Streetcar `F39200`, Subway `E60050`.

**Verify:** bus line peaks in July-August; streetcar peaks in
January-February. Subway is flat.

---

#### Visual 2 — Clustered column: Incidents by hour *(top-right)*

1. Empty canvas → **Clustered column chart**.
2. Bind:
   - **X-axis:** `vw_incidents_by_hour.hour`
   - **Y-axis:** `vw_incidents_by_hour.incident_count` (Sum)
   - **Legend:** `transit_mode`
3. **Paintbrush:**
   - Title → `Incidents by hour of day`.
   - X-axis → Title → `Hour (24-hour)`.
   - Y-axis → Title → `Incidents`. Display units → Thousands.
   - Columns → Colors per mode (Bus blue, Streetcar orange, Subway red).

---

#### Visual 3 — Clustered column: Avg delay per incident by hour *(bottom-left)*

1. Empty canvas → **Clustered column chart**.
2. Bind:
   - X-axis: `vw_incidents_by_hour.hour`
   - Y-axis: `vw_incidents_by_hour.avg_delay_minutes` → change
     aggregation to **Average**.
   - Legend: `transit_mode`
3. Format identical to Visual 2 but title:
   `Avg delay per incident by hour`. Y-axis title: `Avg minutes per incident`.

---

#### Visual 4 — Clustered column: Day of week *(bottom-right)*

1. Empty canvas → **Clustered column chart**.
2. Bind:
   - X-axis: `vw_incidents_by_dow.day_of_week`
   - Y-axis: `vw_incidents_by_dow.incident_count` (Sum)
   - Legend: `transit_mode`
3. **Sort by day_of_week_num** (so Monday comes first):
   - Click the "…" on the visual → **Sort axis** → **Sort by** →
     `day_of_week_num` (you may need to scroll the list).
   - Then **Sort ascending**.
4. **Paintbrush:**
   - Title → `Incidents by day of week`.
   - X-axis → Title → `Day`.
   - Y-axis → Title → `Incidents`. Display units → Thousands.
   - Columns → Colors per mode.

---

#### Visual 5 — Slicer: Transit mode *(bottom)*

Copy from any previous page.

**Caption (text box):**

> "Bus and streetcar have opposite seasonality (bus peaks summer,
> streetcar peaks winter). The weekday-vs-weekend gap is volume, not
> severity — per-incident delays are similar. Bus morning rush has
> the highest *per-incident* severity, even though midday has the
> highest volume."

**Done-when:** the seasonality line shows bus rising in summer and
streetcar rising in winter; the day-of-week chart clearly shows
Monday–Friday taller than Saturday/Sunday.

---

### Page 6 — Action Priority Matrix

**Purpose:** *"what should leadership intervene on first?"*

**Add page** → rename `Action Priority`.

**Layout sketch:**
```
+----------------------------------+----------------+
|  Scatter plot — Priority matrix  | Table — Urgent |
|  (frequency × severity)          | quadrant       |
+----------------------------------+----------------+
|  Slicer: Transit mode (single-select)            |
+---------------------------------------------------+
|  Recommendation text box                          |
+---------------------------------------------------+
```

---

#### Visual 1 — Scatter plot: Priority matrix *(left two-thirds)*

1. Empty canvas → Visualizations → **Scatter chart** icon.
2. Bind:
   - **Values / Details:** drag
     `vw_priority_matrix.delay_description`. (This makes Power BI
     plot one dot per cause instead of one giant blob.)
   - **X-axis:** `vw_priority_matrix.incident_count` (Sum)
   - **Y-axis:** `vw_priority_matrix.avg_delay_minutes` (Average)
   - **Size:** `vw_priority_matrix.total_delay_minutes` (Sum)
   - **Legend:** `vw_priority_matrix.priority_quadrant` (so the
     four quadrants get distinct colors).
3. **Filter to one mode at a time:** drag
   `vw_priority_matrix.transit_mode` → Filters on this visual →
   Basic filtering → tick **Bus** to start.
4. **Switch X and Y to log scale:**
   - Paintbrush → **X-axis** → expand → find **Scale type** → set to
     **Log**.
   - Paintbrush → **Y-axis** → expand → **Scale type** → **Log**.
5. **Add the threshold reference lines:**
   - Click the **magnifying glass icon** in Visualizations pane.
   - **X-axis constant line** → + Add → name "Freq threshold".
     - Value: 3404 (for Bus). For Streetcar use 172; for Subway use 240.
     - Line style: Dashed; Color: grey.
   - **Y-axis constant line** → + Add → name "Severity threshold".
     - Value: 18.41 (for Bus). For Streetcar use 17.27; for Subway use 8.56.
     - Line style: Dashed; Color: grey.

   > To save effort, build the scatter for Bus thresholds first. To
   > re-target it for another mode, manually update the two constant
   > line values, OR build three separate scatter visuals (one per
   > mode) and stack them.

6. **Paintbrush:**
   - Title → `Bus: priority matrix (frequency × severity, P75 thresholds within mode)`.
   - X-axis → Title → `Incidents (log scale)`.
   - Y-axis → Title → `Avg delay minutes per incident (log scale)`.
   - Markers → Size → set to a moderate size (~50–80 px) so dots are
     visible but not overlapping.

**Resize:** left two-thirds.

---

#### Visual 2 — Table: Urgent priority causes *(right one-third)*

1. Empty canvas → **Table** icon.
2. Bind:
   - `transit_mode`
   - `delay_description`
   - `incident_count` (Don't summarize)
   - `total_delay_minutes` (Don't summarize)
   - `avg_delay_minutes` (Don't summarize)
3. Filter: `priority_quadrant` → Basic filtering → tick only
   **"Urgent Priority"**.
4. Sort by `transit_mode` ascending, then `total_delay_minutes`
   descending.
5. **Paintbrush** → Title → `Urgent priority causes — leadership focus list`.

---

#### Visual 3 — Slicer: Transit mode *(bottom)*

1. Empty canvas → **Slicer**.
2. Bind: `dim_mode.transit_mode`.
3. Paintbrush → Slicer settings → **Selection** → toggle **Single
   select** to **On** (this page is most useful one mode at a time).

---

#### Visual 4 — Text box: Recommendation summary *(below scatter, full width)*

1. *Insert* → Text box.
2. Type:

```
Bus (3 urgent causes): Diversion-recovery process is the single largest lever — ~37% of bus delay minutes. Fix this before anything else.

Streetcar (13 urgent causes): No single dominant fix; diversion + collision + overhead-wire issues are the cluster.

Subway (7 urgent causes): Customer-facing (medical, security, weather), not mechanical. Engineering-led improvements won't move the needle here — operational response protocols will.
```

3. Bold each mode name; font size 11pt.

**Done-when:** scatter dots cluster visibly in the top-right
quadrant for each mode; the urgent table updates as you change the
slicer; the recommendation text is readable.

---

## 5. Final touches (10 min)

### 5.1 Page navigation buttons

To make navigation between pages friendlier than clicking the tabs at
the bottom:

1. Go to the first page (Executive Summary).
2. *Insert* → **Buttons** → **Navigator** → **Page navigator**.
3. A row of buttons appears, one per page. Drag it to the top or
   side of the page.
4. Right-click the navigator → **Copy visual**. Go to Page 2 →
   Ctrl+V. Repeat for every page so users can jump.

### 5.2 Set default landing page

1. Right-click the **Executive Summary** tab at the bottom of the
   canvas → **Move → To Beginning**. This makes it the first page
   opened when the .pbix is reopened.

### 5.3 Hide model-only columns

In **Model view**, right-click each of these columns → **Hide in
report view**:
- `dim_mode.mode_key`
- All `rank_by_*` columns across the views (they're filters, not
  user-facing).

### 5.4 Refresh and save

1. *Home* → **Refresh** (round arrows icon). Wait ~15 sec.
2. Verify the cards on Page 1 still show 403,155 / 6.30M / 15.62 / Bus.
3. **Ctrl+S** → save to `powerbi/ttc_delay_analytics.pbix`.

### 5.5 Screenshots for README

For each page:
1. Use **Win + Shift + S** to capture a screenshot of the canvas.
2. Save to `powerbi/screenshots/page_N_<name>.png`.

These go into the README in Stage 6.

---

## 6. Troubleshooting

Three things will trip you up:

### "The PostgreSQL connector requires Npgsql"
Accept the install prompt. If suppressed, download manually from
<https://github.com/npgsql/npgsql/releases>. Pick the x64 installer
matching your Power BI Desktop architecture.

### Relationship cardinality is wrong / says "many-to-many"
Edit the relationship (double-click the line in Model view) →
cardinality **One to many** with `dim_mode` on the *one* side →
direction **Single**.

### Slicer doesn't filter a particular visual
Check that the visual's source view has a relationship to `dim_mode`
(Model view → look for a line). `vw_kpi_summary` is intentionally
unrelated, so its cards don't filter — that's expected.

### Scatter plot on Page 6 shows one giant blob
You forgot to drag `delay_description` to the **Details / Values**
well. Without it, Power BI plots a single aggregated point.

### "Causes to 80%" card shows ~51, not 8/12/31
That means no mode slicer is filtering. Add the slicer (Visual 3 on
Page 3) or directly add a visual-level filter for `transit_mode`.

### Date hierarchy keeps reappearing on the X-axis
After dragging a date field, expand it in the well — there's a
sub-item "Date Hierarchy" with a sub-tree of Year/Quarter/Month/Day.
Click the "X" next to the hierarchy or use the dropdown arrow on the
field name → choose the bare field instead.

### Custom format string (`0.00" min"`) doesn't take
Make sure you selected the **column** (clicked its name in the Data
pane) and that the **Column tools** tab is showing at the top, not
"Measure tools" — measures have separate format rules.

Tell me the error message or paste a screenshot for anything not
covered.

---

## 7. After it's saved

1. Update `docs/progress.md` — tick Stage 5 items.
2. Move to Stage 6 (README writeup). The seven findings from
   `notebooks/03_exploratory_analysis.ipynb` §8 go into the README's
   "Key Insights" section verbatim, with the Page-4 caveat reproduced
   prominently.
