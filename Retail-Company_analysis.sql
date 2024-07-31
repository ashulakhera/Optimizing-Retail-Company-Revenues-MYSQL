create database sports;
use sports;

CREATE TABLE info (
    product_name VARCHAR(100),
    product_id VARCHAR(10) PRIMARY KEY,
    description VARCHAR(700)
);

CREATE TABLE brands (
    product_id VARCHAR(10) PRIMARY KEY,
    brand VARCHAR(10)
);

CREATE TABLE finance (
    product_id VARCHAR(10) PRIMARY KEY,
    listing_price FLOAT,
    sale_price FLOAT,
    discount FLOAT,
    revenue FLOAT
);

CREATE TABLE reviews (
    product_id VARCHAR(10) PRIMARY KEY,
    rating FLOAT,
    reviews FLOAT
);

CREATE TABLE traffic (
    product_id VARCHAR(10) PRIMARY KEY,
    last_visited DATETIME
);

-- Importing CSV Data file('file_name.csv')into MySQL Table. Right-click on the table of the database and select Table Data Import Wizard.
-- Select your CSV file** (`file_name.csv`) from your filesystem.
-- Map the columns** in your CSV file to the columns in your MySQL table, if necessary.
-- Execute the import** process by clicking on the `Next` button and following the prompts.

-- Analysis 

-- 1.Counting missing values

SELECT 
    COUNT(*) AS total_rows,
    COUNT(i.description) AS count_descriptiom,
    COUNT(f.listing_price) AS count_listing_price,
    COUNT(t.last_visited) AS count_last_visited
FROM
    info i
        JOIN
    finance f ON i.product_id = f.product_id
        JOIN
    traffic t ON i.product_id = t.product_id;

#select distinct(brand) from brands;

-- 2.NIKE VS ADIDAS pricing

SELECT 
    b.brand,
    CAST(f.listing_price AS SIGNED) AS listing_price,
    COUNT(*) AS total_count
FROM
    brands b
        JOIN
    finance f ON b.product_id = f.product_id
WHERE
    f.listing_price > 0
GROUP BY b.brand , CAST(f.listing_price AS SIGNED)
ORDER BY listing_price DESC;

-- 3. Labeling price ranges

SELECT 
    b.brand,
    COUNT(*) AS total_count,
    ROUND(SUM(f.revenue), 0) AS total_revenue,
    CASE
        WHEN f.listing_price < 48 THEN 'Budget'
        WHEN
            f.listing_price >= 48
                AND f.listing_price < 72
        THEN
            'Average'
        WHEN
            f.listing_price > 72
                AND f.listing_price < 150
        THEN
            'Expensive'
        ELSE 'Elite'
    END AS price_category
FROM
    brands b
        JOIN
    finance f ON b.product_id = f.product_id
WHERE
    b.brand IS NOT NULL
GROUP BY b.brand , price_category
ORDER BY total_revenue DESC;

-- 4. Average discount by brand

SELECT 
    b.brand, AVG(discount) * 100 AS average_discount
FROM
    brands b
        JOIN
    finance f ON b.product_id = f.product_id
WHERE
    b.brand IS NOT NULL
GROUP BY b.brand;

-- 5. Correlation between revenue and reviews

WITH stats AS (
    SELECT
        AVG(f.revenue) AS mean_revenue,
        AVG(r.reviews) AS mean_reviews,
        COUNT(*) AS n
    FROM finance f
    JOIN reviews r
    ON f.product_id = r.product_id
),
sums AS (
    SELECT
        SUM((f.revenue - stats.mean_revenue) * (r.reviews - stats.mean_reviews)) AS numerator,
        SQRT(SUM(POWER(f.revenue - stats.mean_revenue, 2))) AS stddev_revenue,
        SQRT(SUM(POWER(r.reviews - stats.mean_reviews, 2))) AS stddev_reviews
    FROM finance f
    JOIN reviews r
    ON f.product_id = r.product_id
    CROSS JOIN stats
)
SELECT 
    numerator / (stddev_revenue * stddev_reviews) AS correlation
FROM sums;

-- 6. Ratings and reviews by product description length

SELECT 
    FLOOR(LENGTH(description) / 100.0) * 100 AS description_length,
    ROUND(AVG(CAST(r.rating AS DECIMAL (10 , 2 ))),
            2) AS average_rating
FROM
    info i
        JOIN
    reviews r ON i.product_id = r.product_id
WHERE
    i.description IS NOT NULL
GROUP BY description_length
ORDER BY description_length;

-- 7.Reviews by month and brand

SELECT 
    b.brand,
    MONTH(t.last_visited) AS month,
    COUNT(*) AS num_reviews
FROM
    brands b
        JOIN
    traffic t ON b.product_id = t.product_id
        JOIN
    reviews r ON r.product_id = t.product_id
WHERE
    b.brand IS NOT NULL
GROUP BY b.brand , MONTH(t.last_visited)
ORDER BY b.brand , MONTH(t.last_visited);

-- 8. Top Revenue Generated Products with Brands

WITH highest_revenue_product AS
(  
   SELECT i.product_name, b.brand, revenue
   FROM finance f
   JOIN info i ON f.product_id = i.product_id
   JOIN brands b ON b.product_id = i.product_id
   WHERE product_name IS NOT NULL 
     AND revenue IS NOT NULL 
     AND brand IS NOT NULL
)
SELECT product_name, brand, revenue,
        RANK() OVER (ORDER BY revenue DESC) AS product_rank
FROM highest_revenue_product
LIMIT 10;

-- 9.  Footwear product performance

WITH footwear AS 
(
  SELECT i.description, 
         f.revenue
  FROM info i
  INNER JOIN finance f ON i.product_id = f.product_id
  WHERE (LOWER(i.description) LIKE '%shoe%' 
         OR LOWER(i.description) LIKE '%trainer%' 
         OR LOWER(i.description) LIKE '%foot%')
    AND i.description IS NOT NULL
),
ordered_footwear AS 
(
  SELECT revenue,
         ROW_NUMBER() OVER (ORDER BY revenue) AS row_num,
         COUNT(*) OVER () AS total_count
  FROM footwear
)
SELECT COUNT(*) AS num_footwear_products,
       AVG(revenue) AS median_footwear_revenue
FROM ordered_footwear
WHERE row_num IN ((total_count + 1) DIV 2, (total_count + 2) DIV 2);

-- 10. Clothing product performance

WITH footwear AS 
(
  SELECT i.description, 
         f.revenue
  FROM info i
  INNER JOIN finance f ON i.product_id = f.product_id
  WHERE (LOWER(i.description) LIKE '%shoe%' 
         OR LOWER(i.description) LIKE '%trainer%' 
         OR LOWER(i.description) LIKE '%foot%')
    AND i.description IS NOT NULL
),
clothing AS
(
  SELECT i.description, 
         f.revenue
  FROM info i
  INNER JOIN finance f ON i.product_id = f.product_id
  WHERE LOWER(i.description) NOT LIKE '%shoe%' 
        AND LOWER(i.description) NOT LIKE '%trainer%' 
        AND LOWER(i.description) NOT LIKE '%foot%'
    AND i.description IS NOT NULL
),
ordered_clothing AS
(
  SELECT revenue,
         ROW_NUMBER() OVER (ORDER BY revenue) AS row_num,
         COUNT(*) OVER () AS total_count
  FROM clothing
)
SELECT COUNT(*) AS num_clothing_products,
       AVG(revenue) AS median_clothing_revenue
FROM ordered_clothing
WHERE row_num IN (FLOOR((total_count + 1) / 2), CEIL((total_count + 1) / 2));
