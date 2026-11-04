-- load schema and extract step -2

select '==== loading schema ====' as info;

select '==== loading neighbourhood_dim===='as info;
INSERT INTO neighbourhood_dim (neighbourhood_id, neighbourhood, neighbourhood_group, geometry)
SELECT
    ROW_NUMBER() OVER (ORDER BY f.properties.neighbourhood),
    f.properties.neighbourhood,
    f.properties.neighbourhood_group,
    to_json(f.geometry)
FROM (SELECT UNNEST(features) AS f
      FROM read_json('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/visualisations/neighbourhoods.geojson'));

select * from neighbourhood_dim limit 5;
-- select count(*) from neighbourhood_dim;


select '==== loading host_dim===='as info;
insert into host_dim(host_id, host_name, host_since, host_is_superhost, host_listings_count)
select
host_id,
ANY_VALUE(host_name),
ANY_VALUE(host_since),
ANY_VALUE(host_is_superhost),
MAX(host_listings_count)
from read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/listings.csv.gz')
GROUP BY host_id;

select * from host_dim limit 5;
-- select count(*) from host_dim;


select '==== loading listing_dim===='as info;
insert into listing_dim(
    listing_id, host_id, neighbourhood_id, listing_name, property_type, room_type,
    latitude, longitude, accommodates, bedrooms, price_per_night, minimum_nights,
    rating, instant_bookable
)
select 
l.id,
l.host_id,
n.neighbourhood_id,
l.name,
l.property_type,
l.room_type,
l.latitude,
l.longitude,
l.accommodates,
TRY_CAST(l.bedrooms AS INTEGER),
TRY_CAST(REPLACE(REPLACE(l.price, '$', ''), ',', '') AS DECIMAL(10,2)),
l.minimum_nights,
TRY_CAST(l.review_scores_rating AS DOUBLE),
TRY_CAST(l.instant_bookable AS BOOLEAN)
FROM read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/listings.csv.gz') AS l
JOIN neighbourhood_dim AS n
ON l.neighbourhood_cleansed = n.neighbourhood;

select * from listing_dim limit 5;
-- select count(*) from listing_dim;


select '==== loading amenity_dim===='as info;
insert into amenity_dim(amenity_id, amenity)
select
row_number() over(order by amenity) as amenity_id,
amenity
from(
    select distinct UNNEST(from_json(amenities, '["VARCHAR"]')) AS amenity
    FROM read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/listings.csv.gz')
);

select * from amenity_dim limit 5;
-- select count(*) from amenity_dim;


select '==== loading listing_amenity_bridge===='as info;
insert into listing_amenity_bridge(listing_id, amenity_id)
select distinct
l.listing_id,
a.amenity_id
FROM (
SELECT id AS listing_id,
UNNEST(from_json(amenities, '["VARCHAR"]')) AS amenity
FROM read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/listings.csv.gz')
) AS l
JOIN amenity_dim AS a ON a.amenity = l.amenity;

select * from listing_amenity_bridge limit 5;
-- select count(*) from listing_amenity_bridge;


select '==== loading review_fact===='as info;
INSERT INTO review_fact (review_id, listing_id, host_id, neighbourhood_id, review_date, comment_length)
SELECT
  r.id,
  r.listing_id,
  l.host_id,
  l.neighbourhood_id,
  r.date,
  LENGTH(r.comments)
FROM read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/reviews.csv.gz') AS r
JOIN listing_dim AS l ON r.listing_id = l.listing_id
QUALIFY ROW_NUMBER() OVER (PARTITION BY r.id ORDER BY r.listing_id) = 1;

select * from review_fact limit 5;
-- select count(*) from review_fact;


select '==== loading calendar_fact===='as info;
insert into calender_fact(
    listing_id,
    calender_date,
    is_available,
    minimum_nights,
    maximum_nights
)
select
listing_id,
date,
TRY_CAST(available AS BOOLEAN),
minimum_nights,
maximum_nights
FROM read_csv('https://data.insideairbnb.com/the-netherlands/north-holland/amsterdam/2026-09-16/data/calendar.csv.gz')
WHERE listing_id IN (SELECT listing_id FROM listing_dim);

select * from calender_fact limit 5;
-- select count(*) from calender_fact;

select 'total count for every table' as info;
select 'neighbourhood_dim' as table_name, count(*) as row_count from neighbourhood_dim
union all
select 'host_dim', count(*) from host_dim
union all
select 'listing_dim', count(*) from listing_dim
union all
select 'amenity_dim', count(*) from amenity_dim
union all
select 'listing_amenity_bridge', count(*) from listing_amenity_bridge
union all
select 'review_fact', count(*) from review_fact
union all
select 'calendar_fact', count(*) from calender_fact;

select 'duplicate check' as info;
select 'neighbourhood_dim' as table_name, count(*) - count(distinct neighbourhood_id) as duplicates from neighbourhood_dim
union all
select 'host_dim', count(*) - count(distinct host_id) from host_dim
union all
select 'listing_dim', count(*) - count(distinct listing_id) from listing_dim
union all
select 'amenity_dim', count(*) - count(distinct amenity_id) from amenity_dim
union all
select 'listing_amenity_bridge', count(*) - count(distinct (listing_id, amenity_id)) from listing_amenity_bridge
union all
select 'review_fact', count(*) - count(distinct review_id) from review_fact
union all
select 'calendar_fact', count(*) - count(distinct (listing_id, calender_date)) from calender_fact;