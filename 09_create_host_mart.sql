-- final step
drop schema if exists host_mart cascade;

create schema host_mart;

select '==== host mart ====' as info;
create table host_mart.dim_host(
    host_id BIGINT primary key,
    host_name varchar(255),
    host_is_superhost boolean
);
insert into host_mart.dim_host
select host_id, host_name, host_is_superhost from host_dim;

create table host_mart.dim_neighbourhood(
    neighbourhood_id integer primary key,
    neighbourhood varchar(255)
);
insert into host_mart.dim_neighbourhood
select neighbourhood_id, neighbourhood from neighbourhood_dim;

create table host_mart.dim_room_type(
    room_type_id integer primary key,
    room_type varchar(255)
);
insert into host_mart.dim_room_type
select row_number() over(order by room_type),
room_type from(
select distinct room_type from listing_dim
);

create table host_mart.dim_property_type(
    property_type_id integer primary key,
    property_type varchar(255)
);
insert into host_mart.dim_property_type
select row_number() over(order by property_type),
property_type from(
select distinct property_type from listing_dim
);

create table host_mart.dim_date_month(
    month_start_date date primary key,
    year integer,
    month integer
);
insert into host_mart.dim_date_month
select
    month_start_date,
    extract(year    from month_start_date),                    -- 2025
    extract(month   from month_start_date)                     -- 4
from (
    select distinct date_trunc('month', review_date)::date as month_start_date
    from review_fact
);

select '==== bridge table host and area ====' as info;
create table host_mart.bridge_host_neighbourhood(
    host_id BIGINT,
    neighbourhood_id integer,
    PRIMARY KEY (host_id, neighbourhood_id),
    FOREIGN KEY (host_id) REFERENCES host_mart.dim_host(host_id),
    FOREIGN KEY (neighbourhood_id) REFERENCES host_mart.dim_neighbourhood(neighbourhood_id)
);
insert into host_mart.bridge_host_neighbourhood
select distinct host_id, neighbourhood_id from listing_dim;

select '==== bridge table for room type and property type ====' as info;
create table host_mart.bridge_host_neighourhood(
    room_type_id integer,
    property_type_id integer,
    PRIMARY KEY (room_type_id, property_type_id),
    FOREIGN KEY (room_type_id) REFERENCES host_mart.dim_room_type(room_type_id),
    FOREIGN KEY (property_type_id) REFERENCES host_mart.dim_property_type(property_type_id)
);
insert into host_mart.bridge_host_neighourhood
select distinct
rt.room_type_id,
pt.property_type_id
from listing_dim l
join host_mart.dim_room_type rt
on l.room_type = rt.room_type
join host_mart.dim_property_type pt
on l.property_type = pt.property_type;

select '==== fact table for host mart ====' as info;
create table host_mart.fact_host_reviews_monthly (
    host_id                 bigint,
    room_type_id            integer,
    neighbourhood_id        integer,
    month_start_date        date,
    reviews_count           integer,
    listings_reviewed       integer,
    median_price            decimal(10,2),
    min_price               decimal(10,2),
    max_price               decimal(10,2),
    instant_bookable_share  double,
    avg_rating              double,
    primary key (host_id, room_type_id, neighbourhood_id, month_start_date),
    foreign key (host_id)          references host_mart.dim_host (host_id),
    foreign key (room_type_id)     references host_mart.dim_room_type (room_type_id),
    foreign key (neighbourhood_id) references host_mart.dim_neighbourhood (neighbourhood_id),
    foreign key (month_start_date) references host_mart.dim_date_month (month_start_date)
);

insert into host_mart.fact_host_reviews_monthly
with prepared as (            -- one row per review, with everything needed
    select r.host_id,
           rt.room_type_id,
           r.neighbourhood_id,
           date_trunc('month', r.review_date)::date as month_start_date,
           r.listing_id,
           l.price_per_night,
           l.rating,
           case when l.instant_bookable then 1.0 else 0.0 end as instant_flag
    from review_fact as r
    join listing_dim as l on r.listing_id = l.listing_id
    join host_mart.dim_room_type as rt on l.room_type = rt.room_type
)
select host_id, room_type_id, neighbourhood_id, month_start_date,   -- then group
       count(*),
       count(distinct listing_id),
       median(price_per_night),
       min(price_per_night),
       max(price_per_night),
       avg(instant_flag),
       avg(rating)
from prepared
group by host_id, room_type_id, neighbourhood_id, month_start_date;

--- output
select (select sum(reviews_count) from host_mart.fact_host_reviews_monthly) as mart_reviews,
       (select count(*) from host_mart.fact_host_reviews_monthly) as warehouse_reiviews;


select '==== top 10 hosts(based on 2 questions) ====' as info;
-- Busiest hosts in 2025
select
h.host_name,
h.host_is_superhost,
sum(f.reviews_count) as review_2025
from host_mart.fact_host_reviews_monthly f
join host_mart.dim_host h
on f.host_id = h.host_id
join host_mart.dim_date_month d
on f.month_start_date = d.month_start_date
where d.year = 2025
group by h.host_id, h.host_name, h.host_is_superhost
order by review_2025 desc
limit 10;

-- Hosts with listings in the most areas
select
h.host_name,
count(*) as neighbourhoods
from host_mart.bridge_host_neighbourhood b
join host_mart.dim_host h
on b.host_id = h.host_id
group by h.host_id, h.host_name
order by neighbourhoods desc
limit 10;