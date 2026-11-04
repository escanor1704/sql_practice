-- step - 5 review_mart
drop schema if exists review_mart cascade;

create schema review_mart;

-- why not cts? answer cannot handle primary key and foreign key constraints
select '==== building dim_neighbourhood ====' as info;
create table review_mart.dim_neighbourhood(
    neighbourhood_id integer primary key,
    neighbourhood varchar(255)
);

insert into review_mart.dim_neighbourhood(neighbourhood_id, neighbourhood)
select neighbourhood_id, neighbourhood from neighbourhood_dim;

select (select count(*)from review_mart.dim_neighbourhood) as mart_rows,
    (select count(*) from neighbourhood_dim) as warehouse_rows;




select '==== building dim_date ====' as info;
create table review_mart.dim_date_month(
    month_start_date date primary key,
    year integer,
    month integer,
    quarter integer,
    quarter_name varchar(10),
    year_quarter varchar(10)
);

insert into review_mart.dim_date_month
select
    month_start_date,
    extract(year    from month_start_date),                    -- 2025
    extract(month   from month_start_date),                    -- 4
    extract(quarter from month_start_date),                    -- 2
    concat('Q', extract(quarter from month_start_date)),       -- Q2
    concat(extract(year from month_start_date), '-Q',
           extract(quarter from month_start_date))             -- 2025-Q2
from (
    select distinct date_trunc('month', review_date)::date as month_start_date
    from review_fact
);

SELECT * FROM review_mart.dim_date_month ORDER BY month_start_date LIMIT 5;



select '==== one row per area + room type + month ====' as info;
create table review_mart.fact_review_monthly(
    neighbourhood_id integer,
    room_type varchar(255),
    month_start_date date,
    review_count integer,
    superhost_review_count integer,
    instant_bookable_review_count integer,
    total_comment_length bigint,
    listings_reviewed integer,
    PRIMARY KEY (neighbourhood_id, room_type, month_start_date),
    FOREIGN KEY (neighbourhood_id) REFERENCES review_mart.dim_neighbourhood(neighbourhood_id),
    FOREIGN KEY (month_start_date) REFERENCES review_mart.dim_date_month(month_start_date)
);

insert into
review_mart.fact_review_monthly
SELECT
r.neighbourhood_id,
l.room_type,
DATE_TRUNC('month', r.review_date)::DATE AS month_start_date,
COUNT(*), -- all reviews
SUM(CASE WHEN h.host_is_superhost THEN 1 ELSE 0 END), -- reviews of superhosts
SUM(CASE WHEN l.instant_bookable THEN 1 ELSE 0 END), -- reviews of instant-book listings
SUM(r.comment_length),
COUNT(DISTINCT r.listing_id) -- different listings reviewed
FROM review_fact AS r
JOIN listing_dim AS l ON r.listing_id = l.listing_id
JOIN host_dim AS h ON r.host_id = h.host_id
GROUP BY r.neighbourhood_id, l.room_type, month_start_date;

select (select count(*) from review_mart.fact_review_monthly) as mart_rows,
    (select count(*) from review_fact) as warehouse_rows;


select '==== review counts ====' as info;
select '== review count per year ==' as info;
select d.year,
sum(f.review_count) as review_count,
from review_mart.fact_review_monthly f
join review_mart.dim_date_month d
on f.month_start_date = d.month_start_date
group by d.year
order by d.year;

select '== review count per neighbourhood for latest year(2026 not completed) ==' as info;
select
n.neighbourhood,
sum(f.review_count) as review_count,
from review_mart.fact_review_monthly f
join review_mart.dim_neighbourhood n
on f.neighbourhood_id = n.neighbourhood_id
join review_mart.dim_date_month d
on f.month_start_date = d.month_start_date
where d.year = 2025
group by n.neighbourhood
order by review_count desc;

select '== compare review count for 2019, 2020, 2021 ==' as info;
select d.year,
sum(f.review_count) as review_count,
from review_mart.fact_review_monthly f
join review_mart.dim_date_month d
on f.month_start_date = d.month_start_date
where d.year in (2019, 2020, 2021)
group by d.year
order by d.year;

select '== review count compare ==' as info;
select
sum(listings_reviewed) as mart_sum,
from review_mart.fact_review_monthly f
join review_mart.dim_date_month d
on f.month_start_date = d.month_start_date
where d.year = 2025;

select
count(distinct listing_id) as real_listings
from review_fact
where extract(year from review_date) = 2025;
