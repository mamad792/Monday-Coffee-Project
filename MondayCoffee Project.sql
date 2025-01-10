-- Monday Coffee SCHEMAS

-- Import Rules
-- 1st import to city
-- 2nd import to products
-- 3rd import to customers
-- 4th import to sales


CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);


CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);


-CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- END of SCHEMAS

-- Monday Coffee Data Analysis 
SELECT * FROM sales;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM city;

-- Q-1 Coffee COnsumers Count 
-- How many people in each city are estimated to consume coffee, given that 25% of the population does? 
SELECT city_name, ROUND((population * 0.25)/1000000,2) AS number_of_consumer_in_millions FROM city
ORDER BY 2 DESC;

--  Q-2 Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT city.city_name, SUM(total) AS sales_last_quarter2023 FROM sales 
INNER JOIN customers ON sales.customer_id = customers.customer_id
INNER JOIN city ON city.city_id = customers.city_id
WHERE EXTRACT(YEAR FROM sale_date) = 2023 AND EXTRACT(quarter FROM sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC;

-- Q-3 Sales Count for Each Product
-- How many units of each coffee product have been sold?
SELECT product_name, COUNT(product_name) AS total_sale
FROM products LEFT JOIN sales ON products.product_id = sales.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q-4 Average Sales Amount per City
-- What is the average sales amount per customer in each city?
SELECT city.city_name, SUM(total) AS total_revenue,
COUNT(DISTINCT(customers.customer_name)) AS number_of_customer_per_city,
ROUND (SUM(total)::NUMERIC / COUNT(DISTINCT(customers.customer_name))::NUMERIC,2) AS average_sale_per_customer_per_city
FROM sales 
INNER JOIN customers ON sales.customer_id = customers.customer_id
INNER JOIN city ON city.city_id = customers.city_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q-5 City Population and Coffee Consumers
-- Provide a list of cities along with their populations and estimated coffee consumers.
SELECT city.city_name, ROUND((city.population * 0.25)/1000000,2) AS number_of_coffee_consumers,
COUNT(DISTINCT customers.customer_name) AS number_of_customers
FROM city INNER JOIN customers ON city.city_id = customers.city_id
GROUP BY 1,2
ORDER BY 3 DESC;

-- Q-6 Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?
SELECT * FROM 
	( SELECT  city_name, product_name, COUNT(sales.sale_id), DENSE_RANK() OVER(PARTITION BY city_name ORDER BY COUNT(sales.sale_id) DESC) as rank
	FROM products 
	INNER JOIN sales ON products.product_id = sales.product_id
	INNER JOIN customers ON sales.customer_id = customers.customer_id 
	INNER JOIN city ON customers.city_id = city.city_id
	GROUP BY 1,2 )
WHERE rank <=3;

-- Q-7 Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?
SELECT city.city_name, COUNT(DISTINCT customers.customer_id) AS number_of_unique_customers  FROM sales 
INNER JOIN customers ON sales.customer_id = customers.customer_id 
INNER JOIN city ON city.city_id = customers.city_id
INNER JOIN products ON products.product_id = sales.product_id
WHERE products.product_id >=1 AND products.product_id <=14 
GROUP BY city.city_name
ORDER BY 2 DESC;

-- Q-8 Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer
WITH city_table AS 
(
	SELECT city.city_name, 
	ROUND((SUM(total)::NUMERIC / COUNT(DISTINCT customers.customer_id)::NUMERIC),2) AS average_sale_per_customer,
	COUNT(DISTINCT customers.customer_id) AS number_of_customers
	FROM city 
	INNER JOIN customers ON city.city_id = customers.city_id 
	INNER JOIN sales ON sales.customer_id = customers.customer_id
	GROUP BY 1, estimated_rent
	ORDER BY 2 DESC
), 
city_rent_table AS 
(
SELECT city_name, estimated_rent FROM city
)

SELECT city_table.city_name,
city_rent_table.estimated_rent, 
number_of_customers,
average_sale_per_customer, 
ROUND((city_rent_table.estimated_rent::NUMERIC / number_of_customers),2) AS average_rent_per_customer
FROM city_table INNER JOIN city_rent_table ON city_table.city_name = city_rent_table.city_name
ORDER BY 5 DESC;


-- Q-9 Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).

SELECT * FROM 
(
SELECT city.city_name, 
EXTRACT(MONTH FROM sale_date) AS month, 
EXTRACT(YEAR FROM sale_date) AS year,
SUM(total) AS revenue_per_month,
LAG(SUM(total)) OVER(PARTITION BY city.city_name, EXTRACT(YEAR FROM sale_date) ORDER BY EXTRACT(MONTH FROM sale_date)) as previous_month_sales,
ROUND((((SUM(total)::NUMERIC - LAG(SUM(total)) OVER(PARTITION BY city.city_name, EXTRACT(YEAR FROM sale_date) ORDER BY EXTRACT(MONTH FROM sale_date))::NUMERIC) / (LAG(SUM(total)) OVER(PARTITION BY city.city_name, EXTRACT(YEAR FROM sale_date) ORDER BY EXTRACT(MONTH FROM sale_date)))::NUMERIC) * 100 ),2) AS sales_growth_rate
FROM sales 
INNER JOIN customers ON customers.customer_id = sales.customer_id 
INNER JOIN city ON city.city_id = customers.city_id
GROUP BY 1, 2, 3
ORDER BY 1, 3, 2
)
WHERE sales_growth_rate IS NOT NULL;

--  Q-10 Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

WITH sales_per_city AS 
(
	SELECT city.city_name,
	SUM(total) as total_sales_per_city
	FROM sales 
	INNER JOIN customers ON sales.customer_id = customers.customer_id
	INNER JOIN city ON city.city_id = customers.city_id
	GROUP BY city.city_name
	ORDER BY SUM(total) DESC
	LIMIT 3
),
city_rent AS
(
	SELECT city_name, estimated_rent AS total_rent FROM city
),
total_customers AS
(
	SELECT city.city_name, COUNT(DISTINCT customer_id) AS total_customers FROM customers INNER JOIN city on customers.city_id = city.city_id
	GROUP BY 1
),
coffee_consumers AS 
(
	SELECT city_name, ROUND(((population * 0.25) / 1000000),3) AS estimated_coffee_consumers_in_million FROM city
)

SELECT sales_per_city.city_name,
sales_per_city.total_sales_per_city,
city_rent.total_rent,
total_customers.total_customers, 
coffee_consumers.estimated_coffee_consumers_in_million
FROM sales_per_city 
LEFT JOIN city_rent ON sales_per_city.city_name = city_rent.city_name
JOIN total_customers ON sales_per_city.city_name = total_customers.city_name
JOIN coffee_consumers ON sales_per_city.city_name = coffee_consumers.city_name
ORDER BY 2 DESC










