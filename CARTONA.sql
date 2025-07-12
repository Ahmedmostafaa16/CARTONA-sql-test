
-- 1.Retrieve Active Retailers in the last 30 days rolling? (Active Retailers : did at least 1 Delivered order)
select distinct o.retailer_id , r.full_name
from orders as o
INNER join retailers as r 
on o.retailer_id = r.id
where `status` = 'Delivered' And o.created_at >= (select max(created_at) from orders) - interval 30 day ;   -- i did no use current_date ,as the data set may be old  

-- 2.Sign up Retailers in the last 30 days (Signed up within the last 30 days)
select id,full_name
from retailers
where created_at >= (select max(created_at) from retailers) -  interval 30 day ;

-- 3.New Retailers in the last 30 days (Made his first order within the last 30 days)
with old_orders as (select retailer_id from orders where created_at < (select max(created_at) from orders) - interval 30 day) -- cte for old orders to filter from 

select distinct o.retailer_id 
from orders as o
LEFT join old_orders as ol    -- to display all data from left table then filter those unmacthed or nulls
on o.retailer_id = ol.retailer_id
where ol.retailer_id is null ;
 
 
-- 4.Churned Retailers who didn't do any delivered order in the last 30 days and their total GMV lifetime is above 3000
with total_churn_table as (select retailer_id , sum(GMV)  from orders 
                             group by 1 
                             having sum(GMV) > 3000) 
	
select tct.retailer_id
from total_churn_table AS tct
WHERE NOT EXISTS (
    SELECT *
    from orders o
    where o.retailer_id = tct.retailer_id
      and o.status = 'Delivered'
      and o.created_at >= (SELECT MAX(created_at) FROM orders) - INTERVAL 30 DAY
);
                             





-- 5.Retailers whom their last order was between 60 days and 30 days
with cte as (select retailer_id, max(created_at) as last_order from orders group by retailer_id)

select retailer_id 
FROM cte
where last_order < (select max(created_at) from orders) - interval 30 day  AND last_order > (select max(created_at) from orders) - interval 60 day ;

 -- 6.Retailers who didn't create any orders
 select r.id ,r.full_name
 from retailers as r
 left join orders as o
 on o.retailer_id = r.id
 where o.id is null ;
 
 
 -- 7.Retailers who created orders but not delivered
 select retailer_id ,count(*) number_of_pending_orders  -- may be one reatailer has more than one pending order this why i added count all
 from orders
 where `status` != 'delivered' and `status` is not  null
 group by retailer_id 
 ;
 
-- 8.Retailers who did more than 5 delivered orders in the last 30 days with their total GMV
with cte as (select retailer_id , count(*) as number_of_orders , SUM(GMV) as total_gmv 
			
             from orders  
             where `status` = 'delivered' AND created_at >= (select max(created_at) from orders) - interval 30 day 
             group by 1 
             having count(*) > 5 )
select retailer_id , number_of_orders, total_gmv
from cte 
;
-- 9.How many Retailers who were active last month and still active this month


select count(DISTINCT retailer_id) as active_both_months
from orders o
where retailer_id in (
        select retailer_id
        from orders
        where date_format(created_at, '%Y-%m') = date_format((SELECT MAX(created_at) FROM orders), '%Y-%m')
    )
AND retailer_id in (
        select retailer_id
        from orders
        where date_format(created_at, '%Y-%m') = DATE_FORMAT(DATE_SUB((SELECT MAX(created_at) FROM orders), INTERVAL 1 MONTH), '%Y-%m')
    );



-- 10. How many orders have more than 5 Products
select count(order_id) as number_of_orders_have_more_than_5_products

from(
		select order_id , sum(amount) as total 
		from order_details
		group by order_id
		having sum(amount) > 5 ) subqurey ;
        
        
        
-- 11. Average of number of items in orders
with total_items_cte as(select order_id , sum(amount) as total_items
							from order_details
							group by order_id )
select avg(total_items)
from total_items_cte ;

-- 12. Count of orders and retailers per Area
select a.area,count(id) as number_of_orders , count( distinct retailer_id) as number_of_retailers
from orders as o
inner join retailers as r
on o.retailer_id = r.id                -- joined 3 tables as orders tbale does not has areas id
inner join areas as a
on a.id = r.area_id
group by 1 
order by 2 ;



-- 13.*Number of orders for each retailer in his first 30 days

with first_month_order_table as (select  retailer_id ,min(created_at) as first_order_date, (min(created_at)+ interval 30 day) as first_month_order_date from orders group by 1 )

select o.retailer_id ,count(*)
from orders as o
join first_month_order_table as cte 
using(retailer_id)
where o.created_at between cte.first_order_date AND cte.first_month_order_date
group by 1 ;




-- 14. *Retention Rate per month in year 2020 (Retention means Retailers who were active last month and still active this month)

with cte as (
    select retailer_id, year(created_at) as year, month(created_at) as month
    from orders
    where year(created_at) = 2020
) 

, retailers_per_month as (
    select month, retailer_id
    from cte
    group by month, retailer_id
),
retention as (
    select curr.month,
           count(distinct curr.retailer_id) as current_active,
           count(distinct prev.retailer_id) as previous_active,
           count(distinct case when prev.retailer_id is not null then curr.retailer_id end) as retained
    from retailers_per_month curr
    left join retailers_per_month prev
      on curr.retailer_id = prev.retailer_id
     and curr.month = prev.month + 1
    group by curr.month
)
select month,
       retained,
       previous_active,
       (retained * 100.0 / previous_active) as retention_rate
from retention
where month > 1
order by month ;



-- EXPECT HIGH RETENTION RATE DURING 3,4,5 MONTHS BECAUSE OF QUARNTINE AND RAMADAN



-- 15.GMV of the first order per Retailer
with first_order_table AS (select retailer_id,min(created_at) first_date FROM orders 
							group by 1 ) 
select o.retailer_id, o.gmv AS gmv_of_first_order
from orders o
join first_order_table f
on o.retailer_id = f.retailer_id AND o.created_at = f.first_date  ;

 
 
