-- step - 4 denormalized flat mart
drop schema if exists flat_mart cascade;

create schema flat_mart;

SELECT '==== building listings ====' AS info;
create table flat_mart.listings as with amenities as(
    select b.listing_id,
    STRING_AGG(a.amenity, ', ' ORDER BY a.amenity) AS amenities_list,
    COUNT() AS amenity_count
    FROM listing_amenity_bridge AS b
    JOIN amenity_dim AS a
    ON a.amenity_id = b.amenity_id
    GROUP BY b.listing_id
),
reviews as(
    select listing_id,
    count() as review_count,
    max(review_date) as last_review_date
    from review_fact
    group by listing_id
),
availability as(
    select listing_id,
    count() filter(where is_available) as available_days_next_365,
    COUNT() FILTER (WHERE is_available and calender_date <(select min(calender_date) from calender_fact) +30) as available_days_next_30
    from calender_fact
    group by listing_id
)
select
    l.*,
    n.neighbourhood,
    h.host_name,
    h.host_is_superhost,
    am.amenities_list,
    coalesce(am.amenity_count, 0) as amenity_count, --replacing null values with 0
    coalesce(r.review_count, 0) as review_count, --replacing null values with 0
    r.last_review_date,
    coalesce(av.available_days_next_30, 0) as available_days_next_30, --replacing null values with 0
    coalesce(av.available_days_next_365, 0) as available_days_next_365 --replacing null values with 0
from listing_dim as l
join neighbourhood_dim as n  on l.neighbourhood_id = n.neighbourhood_id
left join host_dim as h  on l.host_id = h.host_id
left join amenities as am on l.listing_id = am.listing_id
left join reviews  as r on l.listing_id = r.listing_id
left join availability as av on l.listing_id = av.listing_id;

select * from flat_mart.listings limit 5;

select '==== row count verify ====' as info;
select
    (select count(*) from flat_mart.listings) as flat_rows,
    (select count(*) from listing_dim) as listing_rows,
    (select sum(review_count) from flat_mart.listings) as flat_reviews,
    (select count(*) from review_fact) as review_rows,
    (select sum(available_days_next_365) from flat_mart.listings) as flat_available_days,
    (select count(*) from calender_fact where is_available) as calendar_available_rows;

select '==== price per night ====' as info;
select neighbourhood, room_type,
median(price_per_night) as middle_price,
count(*) as listings
from flat_mart.listings
group by neighbourhood, room_type
order by neighbourhood, room_type
limit 5;

select '==== superhost listings and share ===='as info;
select neighbourhood,
count(*) as listings,
count()filter (where host_is_superhost) as superhost_listings,
round(count(*) filter (where host_is_superhost) / count(*), 3) as superhost_share
from flat_mart.listings
group by neighbourhood
order by superhost_share desc;

select '==== most review count ====' as info;
select listing_id,
listing_name,
neighbourhood,
review_count
from flat_mart.listings
order by review_count desc
limit 5;

select '==== count of fully booked rooms ===='as info;
select count(*) as fully_booked,
from flat_mart.listings
where available_days_next_30 = 0
limit 5;