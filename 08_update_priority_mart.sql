-- step - 8
select '=== updateing the listing ===' as info;

update priority_mart.priority_room_type
set priority_lvl = 1
where room_type = 'Private room';

delete from priority_mart.priority_room_type
where room_type = 'Entire home/apt';

insert or replace into priority_mart.priority_room_type
values (3, 'hotel room', 2);

select * from priority_mart.priority_room_type;

select ' ==== merging ====' as info;
merge into priority_mart.priority_listing as t
using(
    select
    l.listing_id,
    l.room_type,
    n.neighbourhood,
    h.host_name,
    l.price_per_night,
    l.rating,
    p.priority_lvl
    from listing_dim l
    join priority_mart.priority_room_type p
    on l.room_type = p.room_type
    join neighbourhood_dim n
    on l.neighbourhood_id = n.neighbourhood_id
    join host_dim h
    on l.host_id = h.host_id
) as s
on t.listing_id = s.listing_id
when matched and t.priority_lvl <> s.priority_lvl then                      -- private room
update set priority_lvl = s.priority_lvl, updated_at = current_timestamp
when not matched then                                                       --hotel room
insert (listing_id, room_type, neighbourhood, host_name, price_per_night, rating, priority_lvl, updated_at)
values (s.listing_id, s.room_type, s.neighbourhood, s.host_name, s.price_per_night, s.rating, s.priority_lvl, current_timestamp)
when not matched by source then                                             -- entire home/apt
delete;

select '=== updateded list ===' as info;
select 
priority_lvl,
count(*) as listings,
median(price_per_night) as median_price
from priority_mart.priority_listing
group by priority_lvl
order by priority_lvl;
