-- step 3 - data validation
select '==== validation check ====' as info;
drop schema if exists validation cascade;

create schema validation;

create table validation.check_results(
    check_name VARCHAR,
    expected BIGINT,
    actual BIGINT,
    passed BOOLEAN,
    checked_at TIMESTAMP
);

-- temp table and the its output
create or replace temp table summary_listings as
select id, price, number_of_reviews, availability_365
from read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/visualisations/listings.csv');

create or replace temp table summary_reviews as
select listing_id
from read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/visualisations/reviews.csv');

select (select count(*) from summary_listings) as summary_listings_rows,
    (select count(*) from summary_reviews)  as summary_reviews_rows;

-- Listing row-count and ID checks using temp table
insert into validation.check_results
select 'listing_rows_match', expected, actual, expected = actual, current_timestamp
from (select (select count(*) from summary_listings) as expected,
             (select count(*) from listing_dim) as actual);

insert into validation.check_results
select 'listings_missing_in_warehouse', 0, count(*), count(*) = 0, current_timestamp
from summary_listings as s
left join listing_dim as l on s.id = l.listing_id
where l.listing_id is null;

insert into validation.check_results
select 'listings_missing_in_summary', 0, count(*), count(*) = 0, current_timestamp
from listing_dim as l
left join summary_listings as s on l.listing_id = s.id
where s.id is null;

select * from validation.check_results;

-- price accuracy check
insert into validation.check_results
select 'price_matches_summary', 0, count(*), count(*) = 0, current_timestamp
from summary_listings as s
join listing_dim as l on s.id = l.listing_id
where try_cast(s.price as decimal(10,2)) is distinct from l.price_per_night;

select s.id, s.price as summary_price, l.price_per_night as warehouse_price
from summary_listings as s
join listing_dim as l on s.id = l.listing_id
where try_cast(s.price as decimal(10,2)) is distinct from l.price_per_night
limit 10;

-- informational check: passed = null
insert into validation.check_results
select 'review_count_vs_summary', expected, actual, null, current_timestamp
from (select (select count(*) from summary_reviews) as expected,
             (select count(*) from review_fact)     as actual);

-- see all results
select check_name, expected, actual, passed from validation.check_results;
