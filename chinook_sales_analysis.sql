/* Create a view to streamline queries */

create view staging.sales_analysis_view as (

select
	g.genreid,
	g.name as genre,
	t.trackid,
	t.name as track,
	al.albumid,
	al.title as album,
	ar.artistid,
	ar.name as artist,
	il.invoicelineid,
	i.total as sales,
	i.invoicedate
from
	invoiceline il
	join invoice i on il.invoiceid = i.invoiceid
	join track t on il.trackid = t.trackid
	join album al on t.albumid = al.albumid
	join artist ar on al.artistid = ar.artistid
	join genre g on t.genreid = g.genreid;
)

/* Q: Which genres generate the highest revenue?*/

select
	genre,
	sum(sales) as total_sales
from
	staging.sales_analysis_view
group by genre
order by total_sales desc;

/* Q: Which artists generate the highest revenue?*/

select
	artist,
	sum(sales) as total_sales
from
	staging.sales_analysis_view
group by artist
order by total_sales desc
limit 25;

/* What are the top-selling albums per genre? */

with album_by_genre as (
select
	genre,
	album,
	artist,
	sum(sales) as total_sales,
	rank() over (partition by genre order by sum(sales) desc) as genre_rank
from
	staging.sales_analysis_view
group by genre, album, artist
order by genre, total_sales desc
)
select *
from album_by_genre
where genre_rank <= 3;

/* What are the top-selling tracks per genre? */

with tracks_by_genre as (
select
	genre,
	track,
	artist,
	sum(sales) as total_sales,
	rank() over (partition by genre order by sum(sales) desc) as genre_rank
from
	staging.sales_analysis_view
group by genre, track, artist
order by genre, total_sales desc
)
select *
from tracks_by_genre
where genre_rank <= 3;

/* Which specific tracks generated the highest revenue? */

with top_tracks as (
select
	track,
	artist,
	sum(sales) as total_sales,
	rank() over (order by sum(sales) desc) as sales_rank
from
	staging.sales_analysis_view
group by track, artist
order by total_sales desc
)
select 
	*
from top_tracks 
where sales_rank <= 20
order by sales_rank;

/* Classify tracks as high, medium, low performers */

select
	track,
	artist,
	sum(sales) as total_sales,
	case
		when percent_rank() over (order by sum(sales) desc) <.25 then 'High Rev'
		when percent_rank() over (order by sum(sales) desc) <.50 then 'Medium Rev'
		else 'Low Rev'
	end as revenue_rank
from staging.sales_analysis_view
group by track, artist;

/* What are our average monthly sales? */

with monthly_rev as (
select
	sum(sales) as total_sales,
	to_char(invoicedate, 'MM') as month
from staging.sales_analysis_view
group by month
)
select
	min(total_sales) as min_monthly_sales,
	max(total_sales) as max_monthly_sales,
	percentile_cont(.5) within group (order by total_sales) as median_monthly_sales,
	round(avg(total_sales), 2) as avg_monthly_sales,
	round(stddev(total_sales), 2) as stddev_monthly_sales
from monthly_rev;

/* What is the seasonal sales pattern? */

select
	to_char(invoicedate, 'MM') as month,
	round(sum(sales), 2) as sum_sales,
	rank() over (order by sum(sales) desc) as sales_rank	 
from staging.sales_analysis_view
group by month
order by month;

