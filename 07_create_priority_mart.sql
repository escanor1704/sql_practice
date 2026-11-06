-- step - 7
drop schema if exists priority_mart cascade;

create schema priority_mart;

select '==== priority romm type ====' as info;
create table priority_mart.priority_room_type(
    type_id integer primary key,
    room_type varchar(255),
    priority_lvl integer
);

insert into priority_mart.priority_room_type(type_id, room_type, priority_lvl)
values (1, 'Entire home/apt', 1),
       (2, 'Private room', 2);

select '== priority listing ====' as info;
create table priority_mart.priority_listing(
    listing_id  BIGINT primary key,
    room_type varchar(255),
    host_name varchar(255),
    neighbourhood varchar(255),
    price_per_night decimal(10, 2),
    rating double,
    priority_lvl integer,
    updated_at timestamp
);

insert into priority_mart.priority_listing
select
l.listing_id,
l.room_type,
h.host_name,
n.neighbourhood,
l.price_per_night,
l.rating,
p.priority_lvl,
current_timestamp
from listing_dim as l
join priority_mart.priority_room_type as p
on l.room_type = p.room_type
join neighbourhood_dim as n
on l.neighbourhood_id = n.neighbourhood_id
join host_dim as h
on l.host_id = h.host_id;

select (select count(*) from priority_mart.priority_listing) as snapshot_rows,
    (select count(*) from listing_dim
where room_type in ('Entire home/apt', 'Private room')) as wanted_rooms;

select '==== cost of the wanted houses ====' as info;
select neighbourhood,
priority_lvl,
count(*) as listings_count,
median(price_per_night) as median_price,
from priority_mart.priority_listing
group by neighbourhood, priority_lvl
order by listings_count desc;


select '==== short list of top 10 ====' as info;
select
    listing_id,
    neighbourhood,
    host_name,
    rating,
    price_per_night
from priority_mart.priority_listing
where priority_lvl = 1
  and price_per_night <= 200
  and rating is not null
order by rating desc, price_per_night
limit 10;