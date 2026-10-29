-- step - 1

drop table if exists calender_fact;
drop table if exists review_fact;
drop table if exists listing_amenity_bridge;
drop table if exists listing_dim;
drop table if exists host_dim;
drop table if exists neighbourhood_dim;
drop table if exists amenity_dim;

CREATE OR REPLACE TABLE neighbourhood_dim (
    neighbourhood_id     INTEGER PRIMARY KEY,      
    neighbourhood        VARCHAR NOT NULL UNIQUE,  
    neighbourhood_group  VARCHAR,
    geometry             JSON
);

create or replace table host_dim(
    host_id bigint primary key,
    host_name varchar,
    host_since date,
    host_is_superhost boolean,
    host_listings_count integer
);

create or replace table amenity_dim(
    amenity_id integer primary key,
    amenity varchar
);

CREATE OR REPLACE TABLE listing_dim (
    listing_id        BIGINT PRIMARY KEY,
    host_id           BIGINT REFERENCES host_dim (host_id),
    neighbourhood_id  INTEGER REFERENCES neighbourhood_dim (neighbourhood_id),
    listing_name      VARCHAR,
    property_type     VARCHAR,
    room_type         VARCHAR,
    latitude          DOUBLE,
    longitude         DOUBLE,
    accommodates      INTEGER,
    bedrooms          INTEGER,
    price_per_night   DECIMAL(10,2),
    minimum_nights    INTEGER,
    rating            DOUBLE,
    instant_bookable  BOOLEAN
);

CREATE TABLE listing_amenity_bridge (
listing_id BIGINT,
amenity_id INTEGER,
PRIMARY KEY (listing_id, amenity_id),
FOREIGN KEY (listing_id) REFERENCES listing_dim (listing_id),
FOREIGN KEY (amenity_id) REFERENCES amenity_dim (amenity_id)
);

CREATE TABLE review_fact (
review_id BIGINT PRIMARY KEY,
listing_id BIGINT,
host_id BIGINT,
neighbourhood_id INTEGER,
review_date DATE,
comment_length INTEGER,
FOREIGN KEY (listing_id) REFERENCES listing_dim (listing_id),
FOREIGN KEY (host_id) REFERENCES host_dim (host_id),
FOREIGN KEY (neighbourhood_id) REFERENCES neighbourhood_dim (neighbourhood_id)
);

CREATE TABLE calender_fact (
listing_id BIGINT,
calender_date DATE,
is_available BOOLEAN,
minimum_nights INTEGER,
maximum_nights INTEGER,
PRIMARY KEY (listing_id, calender_date),
FOREIGN KEY (listing_id) REFERENCES listing_dim (listing_id)
);

SELECT table_name
FROM information_schema.tables
WHERE table_catalog = 'sql_practice'
  AND table_schema  = 'main'
ORDER BY table_name;