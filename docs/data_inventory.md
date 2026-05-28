# Data Inventory — TTC Transit Reliability Analytics

A human-readable list of every raw file currently in `data/raw/`, what mode and
years it covers, its format, and what role it plays in the project.

This is a planning/reference artifact written during the Raw Data Audit
(Stage 1). Deeper structural findings (sheet counts, column lists, row counts,
date ranges, missing values, schema drift) live in `notebooks/01_data_audit.ipynb`
and the audit summary at the end of that notebook.

_Last updated: 2026-05-26 (audit stage)._

---

## Summary

- **3 modes**: subway, bus, streetcar.
- **Years covered**: 2022, 2023, 2024 (one XLSX per year per mode) +
  2025-onward "since 2025" CSV per mode = effectively 2022 → present.
- **Format split**: 2022–2024 are Excel (`.xlsx`); 2025-onward are `.csv`.
  This mirrors a real-world change in how Toronto Open Data publishes the
  feed and is resolved at the raw → processed boundary (see
  [Decision 6](decisions.md)).
- **Code lookup**: each mode ships its own `Code Descriptions.csv`. The
  subway also has a reference-only `ttc-subway-delay-codes.xlsx` — kept on
  disk for traceability, **not** used in the pipeline (see Decision 5).
- **Filename inconsistency**: 2025+ CSVs use spaces and Title Case
  (`TTC Subway Delay Data since 2025.csv`); the XLSX files use lowercase
  hyphens (`ttc-subway-delay-data-2022.xlsx`). Handled in code via
  `pathlib`; raw files are not renamed (renaming would break
  reproducibility from the original Open Data download).

---

## Subway — `data/raw/subway/`

| Filename | Format | Year(s) | Role |
|---|---|---|---|
| `ttc-subway-delay-data-2022.xlsx` | XLSX | 2022 | Delay events |
| `ttc-subway-delay-data-2023.xlsx` | XLSX | 2023 | Delay events |
| `ttc-subway-delay-data-2024.xlsx` | XLSX | 2024 | Delay events |
| `TTC Subway Delay Data since 2025.csv` | CSV | 2025–present | Delay events |
| `Code Descriptions.csv` | CSV | n/a | Delay-code → description lookup (canonical) |
| `ttc-subway-delay-codes.xlsx` | XLSX | n/a | Reference only — not used in pipeline (Decision 5) |
| `ttc-subway-delay-data-readme.xlsx` | XLSX | n/a | Field/definition readme published by TTC |

Source: <https://open.toronto.ca/dataset/ttc-subway-delay-data/>

## Bus — `data/raw/bus/`

| Filename | Format | Year(s) | Role |
|---|---|---|---|
| `ttc-bus-delay-data-2022.xlsx` | XLSX | 2022 | Delay events |
| `ttc-bus-delay-data-2023.xlsx` | XLSX | 2023 | Delay events |
| `ttc-bus-delay-data-2024.xlsx` | XLSX | 2024 | Delay events |
| `TTC Bus Delay Data since 2025.csv` | CSV | 2025–present | Delay events |
| `Code Descriptions.csv` | CSV | n/a | Delay-code → description lookup |
| `ttc-bus-delay-data-readme.xlsx` | XLSX | n/a | Field/definition readme published by TTC |

Source: <https://open.toronto.ca/dataset/ttc-bus-delay-data/>

## Streetcar — `data/raw/streetcar/`

| Filename | Format | Year(s) | Role |
|---|---|---|---|
| `ttc-streetcar-delay-data-2022.xlsx` | XLSX | 2022 | Delay events |
| `ttc-streetcar-delay-data-2023.xlsx` | XLSX | 2023 | Delay events |
| `ttc-streetcar-delay-data-2024.xlsx` | XLSX | 2024 | Delay events |
| `TTC Streetcar Delay Data since 2025.csv` | CSV | 2025–present | Delay events |
| `Code Descriptions.csv` | CSV | n/a | Delay-code → description lookup |
| `ttc-streetcar-delay-data-readme.xlsx` | XLSX | n/a | Field/definition readme published by TTC |

Source: <https://open.toronto.ca/dataset/ttc-streetcar-delay-data/>

---

## Notes for the audit

Items to verify in `notebooks/01_data_audit.ipynb`:

1. **Multi-sheet workbooks** — TTC has historically shipped one Excel tab
   per month. Each `*-202X.xlsx` must be read with `sheet_name=None` and
   all sheets stacked before any column-level inspection.
2. **Header drift** — column names may change between the XLSX years and
   the 2025 CSV (e.g. `Min Delay` vs `Delay Minutes`). The audit must
   compare headers year-by-year per mode.
3. **Delay-code integrity** — Excel sometimes strips leading zeros (a code
   like `0123` becomes integer `123`). Confirm the delay-code column is
   read as string and matches the values in `Code Descriptions.csv`.
4. **Date integrity** — Excel may serialise dates as numeric serials
   (e.g. `44927`). Confirm dates parse as real datetimes.
5. **Code-description coverage** — for each mode, every code present in
   the event files should appear in that mode's `Code Descriptions.csv`.
6. **Cross-mode standardisation** — identify which columns are common
   (date, time, code, delay minutes, location-ish) versus mode-specific
   (subway has stations/lines; bus and streetcar have routes/directions).
