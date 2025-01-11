/* Create a view to streamline queries */ 

create view staging.customer_analysis as (

with customer_sales as (
    select
        i.customerid,
        CONCAT(c.lastname, ', ', c.firstname) as customer_name,
        sum(i.total) as total_sales
    from invoice i
    join customer c on i.customerid = c.customerid
    group by i.customerid, c.lastname, c.firstname
),
customer_ranked as (
    select
        customerid,
        customer_name,
        total_sales,
        percent_rank() over (order by total_sales desc) as percentile_rank,
        case
            when percent_rank() over (order by total_sales desc) < 0.25 then 'High Value'
            else 'All Others'
        end as customer_tier
    from customer_sales
)
select
    i.customerid,
    CONCAT(c.lastname, ', ', c.firstname) as customer_name,
    c.company,
    c.country,
    case
        when country in ('USA', 'Canada') then 'North America'
        when country in ('Argentina', 'Chile', 'Brazil') then 'South America'
        when country in (
            'Spain', 'Italy', 'Hungary', 'Belgium', 'Czech Republic', 
            'Sweden', 'Norway', 'France', 'Netherlands', 'Austria', 
            'Poland', 'Ireland', 'Germany', 'Denmark', 'Finland', 
            'Portugal', 'United Kingdom'
        ) THEN 'Europe'
        when country in ('India') then 'Asia'
        when country in ('Australia') then 'Oceania'
    end as continent,
    i.invoiceid,
    i.invoicedate,
    i.total as sales,
    il.trackid,
    t.name as track,
    al.title as album,
    ar.name as artist,
    g.name as genre,
    cr.total_sales,
    cr.percentile_rank,
    cr.customer_tier
from
    invoiceline il
    join invoice i on il.invoiceid = i.invoiceid
    join customer c on i.customerid = c.customerid
    join track t on il.trackid = t.trackid
    join album al on t.albumid = al.albumid
    join artist ar on al.artistid = ar.artistid
    join genre g on t.genreid = g.genreid
    join customer_ranked cr on i.customerid = cr.customerid);

/* Which regions are the most profitable? */ 

select 
	country,
	continent,
	count(invoiceid) as total_orders,
	sum(sales) as total_sales	
from staging.customer_analysis
group by country, continent
order by sum(sales) desc;

/* Do genre-buying patterns differ by region? */

select
	continent,
	genre,
	sum(sales) as total_sales
from staging.customer_analysis
group by cube (continent, genre)
order by continent, total_sales desc;

/* What is the average revenue per customer? */

with sales_per_customer as (
select
	customerid,
	sum(sales) as total_sales
from staging.customer_analysis
group by customerid
)
select
	round(avg(total_sales), 2) as avg_sales_per_customer,
	round(stddev(total_sales), 2) as std_dev
from sales_per_customer;

/* What genres do top customers buy? */ 

select
	customer_tier,
	genre,
	sum(sales) as total_sales
from staging.customer_analysis
group by customer_tier, genre
order by customer_tier, total_sales desc;

/* How do customer orders vary by top-tier customers?
   Q1: In avg number of orders and avg sales? */

with customer_order_count as (
select
	customerid,
	customer_tier,
	count(invoiceid) as num_orders,
	sum(sales) as total_sales
from staging.customer_analysis
group by customerid, customer_tier
)
select
	customer_tier,
	round(avg(num_orders), 2) as avg_num_orders,
	round(avg(total_sales), 2) as avg_sales
from customer_order_count
group by customer_tier;

/* How do customer orders vary by top-tier customers?
   Q2: In avg tracks per order? */

with tracks_per_order as (
select
	customer_tier,
	invoiceid,
	count(trackid) as num_tracks
from staging.customer_analysis
group by invoiceid, customer_tier
)
select
	customer_tier,
	avg(num_tracks) as avg_track_per_order
from tracks_per_order
group by customer_tier;
	
	