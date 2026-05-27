-- ============================================================
--   ASSIGNMENT 04 — SET OPERATORS, CTEs, CONSTRAINTS & CASES
--   Database  : BikeStores
--   Topics    : UNION / UNION ALL / INTERSECT / EXCEPT
--               CTEs (Single & Multiple)
--               Constraints (PK, FK, NOT NULL, UNIQUE, CHECK)
--               CASE Expressions
-- ============================================================


-- ============================================================
--  SECTION A — SET OPERATORS
-- ============================================================

-- Q1.
-- The marketing team wants a single contact list of everyone in the system
-- — both staff members and customers.
-- Build a unified list showing full name and email for all of them.
-- Make sure no one is accidentally listed twice.

SELECT
	CONCAT(first_name, ' ' ,last_name),
	email
FROM
	sales.customers
UNION	
SELECT
	CONCAT(first_name, ' ' ,last_name),
	email
FROM sales.staffs



-- Q2.
-- The logistics team wants to know which states have BOTH
-- a store location AND customers living there.
-- Find those states.

SELECT
	state
FROM sales.customers
INTERSECT
SELECT
	state
FROM sales.stores;





-- Q3.
-- Management wants to identify stores that received zero orders
-- in the year 2018.
-- Find the store_ids that appear in sales.stores but did NOT
-- receive any orders in 2018.

select
	store_id
from sales.stores
except
select
	store_id
from sales.orders 
where 
	YEAR(order_date) = 2018




-- ============================================================
--  SECTION B — CTEs
-- ============================================================

-- Q4.
-- The pricing team wants to flag overpriced products.
-- For each category, find all products whose list_price is
-- higher than the average list_price of their own category.
-- Show category_id, product_name, list_price, and the category average.


WITH cte_avg_price AS (
	SELECT
		category_id,
		AVG(list_price) as category_avg
	FROM production.products
	group by category_id
)
select
	p.category_id,
	p.product_name,
	p.list_price,
	c.category_avg
from production.products p
inner join cte_avg_price c
on p.category_id = c.category_id
where p.list_price > c.category_avg



-- Q5.
-- HR wants to reward the hardest-working staff member.
-- Find all staff members whose order count is higher than
-- the average order count across all staff.
-- Show staff_id and their order_count.

WITH cte_staff_orders 
AS (
	select
		staff_id,
		count(order_id) as order_count
	from sales.orders
	GROUP BY 
		staff_id
)
select
	staff_id,
	order_count
from cte_staff_orders
where order_count > (
		select
			avg(order_count)
		from cte_staff_orders
	)




-- Q6.
-- The finance team needs a yearly performance report per store.
-- For each store and each year, calculate total revenue.
-- Then find only the years where a store's revenue
-- exceeded $1,000,000.
-- Show store_id, year, and total_revenue.


with cte_store_revenue
as
(
	select
		o.store_id,
		YEAR(o.order_date) AS year,
		SUM(oi.quantity * oi.list_price * (1 - oi.discount)) as total_revenue
	from sales.orders as o
	inner join sales.order_items as oi
	on o.order_id = oi.order_id
	group by
		o.store_id,
		YEAR(o.order_date)
)
select
	*
from cte_store_revenue
where total_revenue > 1000000


-- ============================================================
--  SECTION C — CONSTRAINTS (DDL)
-- ============================================================

-- Q7.
-- The business wants to launch a customer loyalty program.
-- Below is the table structure. Your job is to add the correct constraints:
--   - Each card must have a unique card number (not auto-generated).
--   - The card must be linked to a valid customer in sales.customers.
--   - Points balance cannot be negative.
--   - Tier must be one of: 'Bronze', 'Silver', or 'Gold'.
--   - Join date is required and cannot be empty.
--   - If a customer is deleted, their loyalty card record should also be deleted.
--
-- Starter table (add your constraints here):
--
CREATE TABLE sales.loyalty_cards (
     card_number   INT PRIMARY KEY,
     customer_id   INT,
     points        INT CHECK (points >= 0),
     tier          VARCHAR(10) check (tier in ('Bronze', 'Silver', 'Gold')),
     join_date     DATE NOT NULL,
	 CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES sales.customers ON DELETE CASCADE
);

-- Once the table is created, run these inserts to verify your constraints work:
--
INSERT INTO sales.loyalty_cards VALUES (1001, 1,  500,  'Gold',   '2024-01-15');
INSERT INTO sales.loyalty_cards VALUES (1002, 2,  150,  'Silver', '2024-03-22');
INSERT INTO sales.loyalty_cards VALUES (1003, 3,  0,    'Bronze', '2024-06-01');
--
-- Also try these to confirm your constraints REJECT bad data:
INSERT INTO sales.loyalty_cards VALUES (1001, 4,  100,  'Gold',   '2024-07-01'); -- duplicate card_number
INSERT INTO sales.loyalty_cards VALUES (1004, 1,  -50,  'Silver', '2024-08-01'); -- negative points
INSERT INTO sales.loyalty_cards VALUES (1005, 5,  200,  'Diamond','2024-09-01'); -- invalid tier



-- Q8.
-- The operations team realized that some orders in the database have
-- a shipped_date that is earlier than the order_date, which is impossible.
-- Add a rule to the table below that prevents this from happening.
-- Then try inserting a valid row and an invalid row to confirm it works.
--
-- Run this setup first:
--
CREATE TABLE test_orders (
    order_id      INT PRIMARY KEY,
    order_date    DATE NOT NULL,
    shipped_date  DATE,
	CHECK (shipped_date > order_date)
);
--
INSERT INTO test_orders VALUES (1, '2024-01-10', '2024-01-13');
INSERT INTO test_orders VALUES (2, '2024-02-05', '2024-02-07');
INSERT INTO test_orders VALUES (3, '2024-03-01', NULL);
--
-- Now add the constraint using ALTER TABLE (do not recreate the table).
-- After adding it, test with:
INSERT INTO test_orders VALUES (4, '2024-04-10', '2024-04-08'); -- should FAIL
INSERT INTO test_orders VALUES (5, '2024-04-10', '2024-04-15'); -- should PASS



-- ============================================================
--  SECTION D — CASE EXPRESSIONS
-- ============================================================

-- Q9.
-- The sales team wants to see how quickly each order was shipped.
-- Using the difference between shipped_date and order_date:
--   - 'Fast'     — shipped within 2 days
--   - 'Normal'   — shipped in 3 to 5 days
--   - 'Delayed'  — shipped after 5 days
--   - 'Pending'  — not yet shipped (shipped_date is NULL)
-- Show order_id, order_date, shipped_date, and shipping_speed.

select
	order_id,
	order_date,
	shipped_date,
	CASE
		WHEN DATEDIFF(DAY, order_date, shipped_date) <= 2 THEN 'FAST'
		WHEN DATEDIFF(DAY, order_date, shipped_date) <= 5 THEN 'NORMAL'
		WHEN DATEDIFF(DAY, order_date, shipped_date) > 5 THEN 'DELAYED'
		ELSE 'PENDING'
	END AS shipping_speed
from sales.orders




-- Q10.
-- The warehouse team wants to label stock levels for each product per store.
-- Using production.stocks:
--   - 'Out of Stock'  — quantity = 0
--   - 'Low Stock'     — quantity between 1 and 10
--   - 'Sufficient'    — quantity between 11 and 50
--   - 'Well Stocked'  — quantity above 50
-- Show store_id, product_id, quantity, and stock_status.
-- Sort by store_id, then quantity ascending.

SELECT
	store_id,
	product_id,
	quantity,
	CASE	
		WHEN quantity <= 10 THEN 'Low Stock'
		WHEN quantity >= 11 and quantity <= 50 THEN 'Sufficient'
		WHEN quantity > 50  THEN 'Well Stocked'
		ELSE 'Out of stock'
	END AS stock_status
FROM production.stocks
ORDER BY 
	store_id,
	quantity desc


-- ============================================================
--  END OF ASSIGNMENT 04
-- ============================================================