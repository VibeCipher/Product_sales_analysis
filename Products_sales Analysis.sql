SELECT 
    YEAR(order_date),
    MONTH(order_date),
    SUM(sales_amount) AS total_sales,
    SUM(quantity),
    COUNT(DISTINCT customer_key) AS Total_customer
FROM
    fact_sales
WHERE
    order_date IS NOT NULL
GROUP BY MONTH(order_date) , YEAR(order_date)
ORDER BY MONTH(order_date) , YEAR(order_date);

-- Calculate the sales for each year and also the running total sales over time

select
o_date,total_sales,
sum(total_sales)over(order by o_date) as running_total_sales,
avg(avg_price)over(order by o_date) as cummulative_avg
from
(select year(order_date) as o_date,sum(sales_amount) as total_sales,
round(avg(price),0) as avg_price
 from fact_sales
where order_date is not null
group by year(order_date) ) as sales_summary;

-- Analyse the yearly performance of the product by 
-- comparing to the average sales and previous year's sales

with yearly_product_sales as(
select 
dim_products.product_name,
year(fact_sales.order_date) as order_date,
sum(fact_sales.sales_amount) as current_sales
from
fact_sales join dim_products on fact_sales.product_key=dim_products.product_key
where order_date is not null
group by
year(fact_sales.order_date),dim_products.product_name)
select 
order_date, product_name, current_sales,
avg(current_sales) over (partition by product_name) as avg_sales,
current_sales-avg(current_sales) over (partition by product_name) as avg_diff,
case when current_sales-avg(current_sales) over (partition by product_name)<0 then "Below Avg"
	when current_sales-avg(current_sales) over (partition by product_name)>0 then "Above Avg"
    else "Average"
end as avg_change,
lag(order_date) over (partition by product_name order by order_date) as previous_years_sales,
current_sales-lag(order_date) over (partition by product_name order by order_date) as sales_diff,
case when current_sales-lag(order_date) over (partition by product_name order by order_date)<0 then "Decrease Sales"
	when current_sales-lag(order_date) over (partition by product_name order by order_date)>0 then "Increase Sales"
    else "Same"
end as sales_change
from yearly_product_sales
order by product_name,order_date;

-- Segment products into cost range
-- and count how many products falls into each segments

with product_segments as(
select
product_key,product_name, cost, 
case when cost<200 then "Below 200"
	when cost between 200 and 800 then "200 to 800"
    else "Above 800"
end cost_range
from dim_products)
select
cost_range,count(product_key) total_products
from product_segments
group by(cost_range)
order by(total_products) desc;

-- Group customers into their spending segments:
-- VIP, Regular and New (wrt their spending lifespan)
-- and find the total number in each group

with customer_spending as(
select 
c.customer_key,sum(f.sales_amount) as total_spending,
min(f.order_date) as first_order,
max(f.order_date) as last_order,
datediff(max(f.order_date),min(f.order_date)) as lifespan
from
fact_sales f join dim_customers c
on f.customer_key=c.customer_key
group by c.customer_key)
select 
customer_types,
count(customer_key) as customer_count
from
(select
customer_key,
case when lifespan>=365 and total_spending>5000 then "VIP"
	when lifespan>=365 and total_spending<=5000 then "Regular"
    else "New"
end as customer_types
from customer_spending) as t
group by customer_types
