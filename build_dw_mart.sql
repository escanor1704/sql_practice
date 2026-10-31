-- duckdb sql_practice.duckdb -c ".read build_dw_mart.sql"

-- step - 1
.read 01_create_tables_dw.sql

-- step - 2
.read 02_load_schema_dw.sql

-- step - 3
.read 03_validate_sources.sql

-- step - 4
.read 04_create_flat_mart.sql