-- step - 6
drop schema if exists availability_mart cascade;

create schema availability_mart;

select '==== building dim_date ====' as info;
-- 1. empty table
create table availability_mart.dim_date (
    calender_date   date primary key,
    year            integer,
    month           integer,
    iso_day_of_week integer,
    day_name        varchar,
    is_weekend      boolean,
    week_start_date date
);

-- 2. one row per calendar day
insert into availability_mart.dim_date
select
    calender_date,
    extract(year from calender_date),                                    
    extract(month from calender_date),                                  
    isodow(calender_date),                                               
    dayname(calender_date),                                             
    case when isodow(calender_date) in (6, 7) then true else false end,  
    date_trunc('week', calender_date)::date                              
from (select distinct calender_date from calender_fact);

-- 3. check: both numbers must be the same (about 365)
select
    (select count(*) from availability_mart.dim_date)          as dim_days,
    (select count(distinct calender_date) from calender_fact)  as calender_days;

select * from availability_mart.dim_date order by calender_date limit 7;


select '==== availability dim_neighbourhood ====' as info;
create table availability_mart.dim_neighbourhood(
    neighbourhood_id integer primary key,
    neighbourhood varchar(255)
);

insert into availability_mart.dim_neighbourhood(neighbourhood_id, neighbourhood)
select neighbourhood_id, neighbourhood from neighbourhood_dim;

select (select count(*)from availability_mart.dim_neighbourhood) as mart_rows,
    (select count(*) from neighbourhood_dim) as warehouse_rows;


create table availability_mart.fact_availability_dialy(
    neighbourhood_id integer,
    room_type varchar(255),
    calender_date date,
    listings_count integer,
    available_count integer,
    price_available_count integer,
    available_price_sum decimal(10, 2),
    PRIMARY KEY (neighbourhood_id, room_type, calender_date),
    foreign key (neighbourhood_id) references availability_mart.dim_neighbourhood (neighbourhood_id),
    foreign key (calender_date) references availability_mart.dim_date (calender_date)
);

insert into availability_mart.fact_availability_dialy
select
    l.neighbourhood_id,
    l.room_type,
    c.calender_date,
    count(*),                                                -- listings_count
    count(*) filter (where c.is_available),                  -- available_count
    count(l.price_per_night) filter (where c.is_available),  -- price_available_count
    sum(l.price_per_night) filter (where c.is_available)     -- available_price_sum
from calender_fact as c
join listing_dim as l on c.listing_id = l.listing_id
group by l.neighbourhood_id, l.room_type, c.calender_date;

-- step 4: check that nothing was lost
select
    (select sum(listings_count)  from availability_mart.fact_availability_dialy) as mart_rows,
    (select count(*)             from calender_fact)                             as calender_rows,
    (select sum(available_count) from availability_mart.fact_availability_dialy) as mart_available,
    (select count(*)             from calender_fact where is_available)          as calender_available;


-- q1: share of free house-days per neighbourhood, next 30 days
-- 0.667 means 2 of every 3 house-days are free
select n.neighbourhood,
       round(sum(f.available_count) / sum(f.listings_count), 3) as share_next_30
from availability_mart.fact_availability_dialy as f
join availability_mart.dim_neighbourhood n
on f.neighbourhood_id = n.neighbourhood_id
where f.calender_date < (select min(calender_date)
from availability_mart.fact_availability_dialy) + 30
group by n.neighbourhood
order by share_next_30 desc;

-- q2: weekends vs weekdays
-- a lower weekend share means weekends get booked more
select case when d.is_weekend then 'weekend' else 'weekday' end as day_type,
       round(sum(f.available_count) / sum(f.listings_count), 3) as share
from availability_mart.fact_availability_dialy as f
join availability_mart.dim_date d 
on f.calender_date = d.calender_date
group by day_type;

-- q3: average price per free night, per neighbourhood
-- total price / number of priced free nights
select n.neighbourhood,
       round(sum(f.available_price_sum) / nullif(sum(f.price_available_count), 0), 2) as avg_price_per_night
from availability_mart.fact_availability_dialy as f
join availability_mart.dim_neighbourhood n 
on f.neighbourhood_id = n.neighbourhood_id
group by n.neighbourhood
order by avg_price_per_night desc;