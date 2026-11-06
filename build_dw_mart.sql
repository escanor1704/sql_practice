-- duckdb sql_practice.duckdb -c ".read build_dw_mart.sql"
.timer on -- to record time taken for each step

SELECT 'Step 1: create warehouse tables' AS progress;
.read 01_create_tables_dw.sql

SELECT 'Step 2: load warehouse from Inside Airbnb' AS progress;
.read 02_load_schema_dw.sql

SELECT 'Step 3: validate against summary files' AS progress;
.read 03_validate_sources.sql

SELECT 'Step 4: flat mart' AS progress;
.read 04_create_flat_mart.sql

SELECT 'Step 5: review mart' AS progress;
.read 05_create_review_mart.sql

SELECT 'Step 6: availability mart' AS progress;
.read 06_create_availability_mart.sql

SELECT 'Step 7: priority mart' AS progress;
.read 07_create_priority_mart.sql

SELECT 'Step 8: update priority mart (MERGE)' AS progress;
.read 08_update_priority_mart.sql

SELECT 'Step 9: host mart' AS progress;
.read 09_create_host_mart.sql

SELECT 'Build finished' AS progress;