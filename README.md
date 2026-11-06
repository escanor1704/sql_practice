# Amsterdam — Data Warehouse & Marts

A practice data engineering project built with **DuckDB** and **SQL**.
It loads real Airbnb data for Amsterdam into a small data warehouse, checks it, and builds five marts that answer common business questions.

## The problem

NestFinder helps people find short-stay homes in Amsterdam. The raw data is messy (prices stored as text like `$1,234.00`, amenities stored as JSON lists, repeated review IDs). The goal is to:

1. load the raw files into a clean warehouse,
2. check the warehouse against a second source,
3. build marts so questions can be answered quickly and simply,
4. rebuild everything with one command.

## Data source

- **Inside Airbnb**, Amsterdam snapshot of **16 September 2026**
- Files used: `listings.csv.gz`, `reviews.csv.gz`, `calendar.csv.gz`, `neighbourhoods.csv`, `neighbourhoods.geojson`, and the summary `listings.csv` / `reviews.csv` (for validation only)
- Files are read straight from their URLs with `read_csv` / `read_json`

> Data: Inside Airbnb (insideairbnb.com), CC BY 4.0

## Tech stack

- DuckDB 1.4+ (CLI)
- SQL only
- Git + GitHub

## Repository

```
sql_practice/
├── 01_create_tables_dw.sql          # Warehouse tables (DDL)
├── 02_load_schema_dw.sql            # Read URLs, clean, load
├── 03_validate_sources.sql          # Compare warehouse with summary files
├── 04_create_flat_mart.sql          # Flat mart
├── 05_create_review_mart.sql        # Monthly review mart
├── 06_create_availability_mart.sql  # Daily availability mart
├── 07_create_priority_mart.sql      # Priority mart (snapshot)
├── 08_update_priority_mart.sql      # Update the snapshot with MERGE
├── 09_create_host_mart.sql          # Host mart
├── build_dw_mart.sql                # Runs 01 → 09 in order
└── README.md
```

## How to run

```bash
rm -f sql_practice.duckdb
duckdb sql_practice.duckdb -c ".read build_dw_mart.sql"
echo $?        # 0 = success, 1 = a step or a validation failed
```

The build needs internet (it reads the files from Inside Airbnb).
It stops at the first error (`.bail on`) or failed hard check (`error()` in 03), so no mart is built from bad data.
Running it twice gives the same result.

## Warehouse design

A **constellation schema**: two fact tables that share the same dimensions.

| Table | Type | One row = |
|---|---|---|
| `neighbourhood_dim` | dimension | one area |
| `host_dim` | dimension | one host |
| `listing_dim` | dimension | one listing (house) |
| `amenity_dim` | dimension | one amenity |
| `listing_amenity_bridge` | bridge | one listing + one amenity |
| `review_fact` | fact | one review |
| `calender_fact` | fact | one listing on one day |

## Marts

| Mart | Design | One row = | Answers |
|---|---|---|---|
| `flat_mart.listings` | flat (wide) table | one listing | everything about a listing, no joins needed |
| `review_mart` | star | area + room type + month | reviews per year and per area |
| `availability_mart` | star | area + room type + day | how free each area is, weekends vs weekdays |
| `priority_mart` | snapshot | one wanted listing | where the client's wanted homes are, and a top-10 shortlist |
| `host_mart` | star + 2 bridges | host + room type + area + month | busiest hosts, hosts working in many areas |

## Baseline counts

| Table | Rows |
|---|---|
| `neighbourhood_dim` | 22 |
| `host_dim` | 9,231 |
| `listing_dim` | 10,612 |
| `amenity_dim` | 3,034 |
| `listing_amenity_bridge` | 341,939 |
| `review_fact` | 554,973 |
| `calender_fact` | 3,873,380 |

## Validation (03)

| Check | Result |
|---|---|
| Same number of listings as the summary file | 10,612 = 10,612 ✅ |
| No listing missing on either side | 0 and 0 ✅ |
| Prices match the summary file | compared after rounding (the summary file rounds prices to whole euros) |
| Reviews vs summary reviews | 554,973 vs 571,927 (difference explained below) |

## Notes about the data

- **Calendar prices:** the calendar file in this snapshot has no price column, so calendar prices are empty.
- **Repeated review IDs:** the reviews file has 6,552 IDs that appear more than once. One row per ID is kept.
- **Review difference:** the warehouse has fewer reviews than the summary file because of the removed repeats and reviews of listings that are missing.
- **Survivorship bias:** reviews only exist for listings that are still online, so older years look smaller than they really were.
- **COVID-19:** reviews dropped from 46,430 (2019) to 16,785 (2020) and recovered only partly in 2021 (23,048).
