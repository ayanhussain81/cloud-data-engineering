-- ============================================================
--   ASSIGNMENT 05 — INDEXES, VIEWS & WINDOW FUNCTIONS
--   Database  : BikeStores
--   Topics    : Indexes (Clustered & Non-Clustered)
--               Views
--               ROW_NUMBER / RANK / DENSE_RANK
--               LAG / LEAD
--               COALESCE
-- ============================================================


-- ============================================================
--  SECTION A — INDEXES
-- ============================================================

-- Q1.
-- The marketing team frequently runs campaigns filtered by brand.
-- They search products like this:
--
--   SELECT product_id, product_name, list_price
--   FROM production.products
--   WHERE brand_id = 3;
--
-- This query is slow. Create an appropriate index to fix it.
-- Then run the query to confirm it returns results correctly.

CREATE INDEX ix_brand_id
ON production.products(brand_id)


-- Q2.
-- The finance team runs a monthly report that filters orders
-- by a date range, for example:
--
--   SELECT order_id, customer_id, order_date
--   FROM sales.orders
--   WHERE order_date BETWEEN '2018-01-01' AND '2018-06-30';
--
-- Create an index to make this query more efficient.
CREATE INDEX ix_order_date
ON sales.orders(order_date, customer_id)


-- ============================================================
--  SECTION B — VIEWS
-- ============================================================

-- Q3.
-- The customer support team needs a daily list of all
-- pending and processing orders so they can follow up.
-- Create a view that shows:
--   order_id, customer full name, phone, email,
--   order_date, and order status as a readable label
--   (not a number — use 1=Pending, 2=Processing).
-- After creating it, query the view to see today's workload.

CREATE VIEW sales.vw_order_details
AS(
	select
		o.order_id,
		CONCAT(C.first_name, ' ', C.last_name) AS full_name,
		c.phone,
		c.email,
		o.order_date,
		CASE
			WHEN o.order_status = 1 THEN 'Pending'
			WHEN o.order_status = 2 THEN 'Processing'
		END AS order_status
	from sales.orders AS o 
	inner join  sales.customers AS c
	on c.customer_id = o.customer_id
	where
	o.order_status in (1, 2)
)

-- Q4.
-- The inventory manager wants a single view to monitor stock
-- across all stores without writing complex joins every time.
-- Create a view that shows:
--   store_name, product_name, brand_name, category_name, quantity
-- After creating it, query the view to find all products
-- that have fewer than 3 units remaining in any store.

CREATE VIEW production.vw_stock_monitor
AS (
	select
		s.store_name,
		p.product_name,
		b.brand_name,
		c.category_name,
		st.quantity
	from sales.stores s
	inner join production.stocks st
	on s.store_id = st.store_id
	inner join production.products p
	on st.product_id = p.product_id
	inner join production.brands b
	on p.brand_id = b.brand_id
	inner join production.categories c
	on p.category_id = c.category_id
)

select
	*
from production.vw_stock_monitor
where quantity < 3

-- ============================================================
--  SECTION C — ROW_NUMBER, RANK & DENSE_RANK
-- ============================================================

-- Q5.
-- The sales director wants to see the top 2 best-selling products
-- per store based on total quantity sold.
-- Show store_id, product_id, total_quantity, and their rank within the store.
-- Return only rank 1 and rank 2 for each store.

WITH cte_sales_rank AS (
	select
		o.store_id,
		oi.product_id,
		sum(oi.quantity) quantity,
		DENSE_RANK() OVER (PARTITION BY o.store_id ORDER BY sum(oi.quantity) DESC) AS sales_rank
	from sales.orders o
	inner join sales.order_items oi
	on oi.order_id = o.order_id
	group by o.store_id, oi.product_id
)
select
	*
from cte_sales_rank
where sales_rank IN (1, 2)


-- Q6.
-- The pricing team wants to find the 2nd most expensive product
-- in each category.
-- Show category_id, product_name, list_price, and their price rank
-- within the category.
-- Return only the products ranked 2nd in their category.

with cte_price_rank AS (
select
	category_id,
	product_name,
	list_price,
	DENSE_RANK() OVER(PARTITION BY category_id ORDER BY list_price DESC) price_Rank
from production.products
)
select
	*
from cte_price_rank
where price_rank = 2



-- Q7.
-- The data team suspects there are duplicate customer records.
-- Use the test table below (already has duplicates built in).
-- Write a query to identify the duplicate rows
-- (same first_name, last_name, and phone).
-- Return only the duplicates — not the original/first occurrence.
--
-- Run this setup first:
--
CREATE TABLE test_customers (
    customer_id  INT,
    first_name   VARCHAR(50),
    last_name    VARCHAR(50),
    phone        VARCHAR(20),
    city         VARCHAR(50)
);
--
INSERT INTO test_customers VALUES
    (1,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),
    (2,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),
    (3,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),   -- duplicate of 1
    (4,  'Usman',  'Malik',   '0333-3333333', 'Islamabad'),
    (5,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- duplicate of 2
    (6,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- 3rd copy of 2
    (7,  'Hina',   'Raza',    '0312-4444444', 'Peshawar');
--
-- Now write your query to find the duplicate rows.
with cte_duplicates AS (
	select
		*,
	ROW_NUMBER() OVER(PARTITION BY first_name, last_name, phone ORDER BY customer_id ASC) AS row_num
	from test_customers
)
select
	*
from cte_duplicates
where row_num > 1




-- ============================================================
--  SECTION D — LAG, LEAD & COALESCE
-- ============================================================

-- Q8.
-- The finance team wants a month-by-month revenue report for 2017.
-- For each month, show total net sales and how much it grew or
-- dropped compared to the previous month.
-- Show month, net_sales, previous_month_sales, and the difference.
-- Net sales = SUM( quantity * list_price * (1 - discount) )

with cte_monthly_sales AS (
	select
		month(o.order_date) as month,
		sum(quantity * list_price * (1 - discount)) as net_sales,
		lag(sum(quantity * list_price * (1 - discount))) over(order by month(o.order_date)) as previous_month_sales
	from sales.order_items as oi
	inner join sales.orders as o
	on o.order_id = oi.order_id
	where o.order_date between '2017-01-01' and '2017-12-31'
	group by month(o.order_date)
)
select
	month,
	net_sales,
	previous_month_sales,
	net_sales - previous_month_sales as difference
from cte_monthly_sales;
	



-- Q9.
-- The product team wants to see each product's price compared to
-- the next cheaper product in the same category.
-- Show product_name, list_price, and the next lower price
-- in the same category.
-- Sort by category_id and list_price descending.

select
	product_name,
	list_price,
	lead(list_price) over(partition by category_id order by list_price desc) AS next_cheaper_price
from production.products
order by category_id, list_price desc



-- Q10.
-- The CRM team is cleaning up customer records.
-- Some customers have no phone number on file.
-- Show each customer's full name, phone, and email.
-- Replace any missing phone with their email address instead.
-- If both are missing, show 'No Contact Info'.
-- Sort by last_name, first_name.

select
	concat(first_name, ' ', last_name),
	coalesce(phone, email, 'No Contact Info'),
	email
from sales.customers
order by last_name, first_name



-- ============================================================
--  END OF ASSIGNMENT 05
-- ============================================================